class_name MusicMarqueeHScrollContainer extends ScrollContainer

## The color to use for song titles.
@export var title_color: Color = Color.MAGENTA
## The color to use for artist names.
@export var artist_color: Color = Color.CORNFLOWER_BLUE
## The color to use for album names.
@export var album_color: Color = Color.GREEN

var rich_text_label: RichTextLabel


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	for node in get_children():
		if node is RichTextLabel:
			rich_text_label = node
	if not rich_text_label:
		rich_text_label = RichTextLabel.new()
		add_child(rich_text_label)
	
	rich_text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich_text_label.scroll_active = false
	rich_text_label.fit_content = true
	rich_text_label.bbcode_enabled = true
	
	MusicManager.song_started.connect(_on_song_started)
	MusicManager.song_stopped.connect(_on_song_stopped)

	if MusicManager.playing and MusicManager.stream:
		var clean_name = MusicManager.stream.resource_path.get_basename().get_file()
		_on_song_started(clean_name)

func _process(_delta: float) -> void:
	if rich_text_label.size.x <= size.x:
		scroll_horizontal = 0
		return
		
	scroll_horizontal += 2
	if scroll_horizontal >= rich_text_label.size.x - size.x:
		scroll_horizontal = 0

func _on_song_started(song_name: String) -> void:
	var color_hex = title_color.to_html(false)
	rich_text_label.text = "[font_size=12][color=#" + color_hex + "]" + "Now playing: " + song_name + "[/color][/font_size]"

	rich_text_label.text = rich_text_label.text.lpad(rich_text_label.text.length() + int(size.x / 4))
	rich_text_label.text = rich_text_label.text.rpad(rich_text_label.text.length() + int(size.x / 4))
	
	scroll_horizontal = 0
	
	rich_text_label.reset_size()

func _on_song_stopped() -> void:
	rich_text_label.text = ""
