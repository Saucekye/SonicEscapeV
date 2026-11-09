"""Shrinks the game's music so the web export stays small.

Re-encodes every MP3 bigger than MIN_SIZE whose bitrate is above TARGET_KBPS down
to TARGET_KBPS, keeping the SAME file name and format, so nothing in the project
needs changing. Sound effects (small files) are left alone. Originals are copied
to a backup folder next to the project first, and files already at or below the
target are skipped, so it's safe to run more than once.

Run from the project folder (needs ffmpeg on your PATH):
    python tools/shrink_audio.py              # re-encode
    python tools/shrink_audio.py --dry-run    # just list what would change
Then open the project in Godot (it reimports the changed files) and export.
To undo, copy the files back from the backup folder.
"""
import json
import os
import shutil
import subprocess
import sys

TARGET_KBPS = 128          # good quality for game music; 96 saves more
MIN_SIZE = 1_000_000       # bytes; smaller files (sound effects) are left alone
SKIP_DIRS = {".godot", ".git", "tools"}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(os.path.dirname(ROOT), os.path.basename(ROOT) + "_audio_originals")


def bitrate_kbps(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=bit_rate",
                          "-of", "json", path], capture_output=True, text=True)
    try:
        return int(json.loads(out.stdout)["format"]["bit_rate"]) // 1000
    except Exception:
        return 0


def main():
    dry = "--dry-run" in sys.argv
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        sys.exit("ffmpeg / ffprobe not found. Install ffmpeg and try again.")
    before = after = 0
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if not f.lower().endswith(".mp3"):
                continue
            path = os.path.join(root, f)
            size = os.path.getsize(path)
            if size < MIN_SIZE:
                continue
            with open(path, "rb") as fh:
                if fh.read(40).startswith(b"version https://git-lfs"):
                    print("skip (Git LFS pointer, run 'git lfs pull' first):", os.path.relpath(path, ROOT))
                    continue
            kbps = bitrate_kbps(path)
            rel = os.path.relpath(path, ROOT)
            if kbps and kbps <= TARGET_KBPS + 8:
                continue
            print(f"{size / 1e6:6.1f} MB  {kbps:4d} kbps -> {TARGET_KBPS} kbps  {rel}")
            before += size
            if dry:
                continue
            backup = os.path.join(BACKUP, rel)
            if not os.path.exists(backup):
                os.makedirs(os.path.dirname(backup), exist_ok=True)
                shutil.copy2(path, backup)
            tmp = path + ".shrinking.mp3"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-map", "0:a", "-c:a", "libmp3lame",
                            "-b:a", f"{TARGET_KBPS}k", "-map_metadata", "0", tmp], check=True)
            os.replace(tmp, path)
            after += os.path.getsize(path)
    if dry:
        print(f"would re-encode {before / 1e6:.1f} MB of music")
    elif before:
        print(f"music: {before / 1e6:.1f} MB -> {after / 1e6:.1f} MB (originals in {BACKUP})")
    else:
        print("nothing to shrink")


if __name__ == "__main__":
    main()
