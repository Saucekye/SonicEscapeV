class_name SalvageItem
extends Resource
# One kind of Salvage item

# Floor skips stop at floor 16's rest area
const LAST_SKIP_TO := 16

enum Effect { RINGS, MAX_METER, SKIP_FLOORS, FULL_METER_EACH_FLOOR, FASTER_BOOST, BOSS_DAMAGE, EXTRA_LIFE, KEEP_RINGS, RUN_FASTER, JUMP_HIGHER, LESS_METER, SHIELD, STUN, SURVIVE, LONGER_FLIGHT, TRICK_METER }

@export var display_name := "Item"
@export var cost := 5            ## rings it takes to pick up
@export var effect: Effect = Effect.RINGS   ## what it does once you escape with it
@export var amount := 10         ## rings, max meter, floors, % faster boost, extra damage per hit on bosses
@export var description := ""    ## what you see when you're close to it
@export var texture: Texture2D   ## the item's picture
@export var height := 0.5        ## how tall it stands, in metres
@export_group("Placeholder")
@export_enum("square", "circle", "triangle", "diamond") var shape := "square"
@export var color := Color(0.6, 0.6, 0.6)


# What it does, shown when you're close to it
func says() -> String:
	if description != "":
		return description
	match effect:
		Effect.RINGS:
			return "+%d rings" % amount
		Effect.MAX_METER:
			return "+%d max meter" % amount
		Effect.SKIP_FLOORS:
			return "Skip %d floor%s" % [amount, "" if amount == 1 else "s"]
		Effect.FULL_METER_EACH_FLOOR:
			return "Full meter every floor"
		Effect.FASTER_BOOST:
			return "Faster boost"
		Effect.BOSS_DAMAGE:
			return "Hit bosses harder"
		Effect.EXTRA_LIFE:
			return "Extra life" if amount <= 1 else "%d extra lives" % amount
		Effect.KEEP_RINGS:
			return "Lose fewer rings when hit"
		Effect.RUN_FASTER:
			return "Run faster"
		Effect.JUMP_HIGHER:
			return "Jump higher"
		Effect.LESS_METER:
			return "Moves use less meter"
		Effect.SHIELD:
			return "Shield" if amount <= 1 else "%d shields" % amount
		Effect.LONGER_FLIGHT:
			return "Fly %d%% longer" % amount
		Effect.TRICK_METER:
			return "Tricks +%d%% meter" % amount
		Effect.STUN:
			return "Stun hunters (Q)" if amount <= 1 else "Stun hunters x%d (Q)" % amount
		Effect.SURVIVE:
			return "Survive a hunter once" if amount <= 1 else "Survive a hunter %d times" % amount
	return display_name


# Where skipping this many floors from here takes you
static func skipped_to(level: int, floors: int) -> int:
	return mini(level + floors, LAST_SKIP_TO) if level < LAST_SKIP_TO else level


# Can floors still be skipped from here?
static func can_skip(level: int) -> bool:
	return level < LAST_SKIP_TO


# The upgrades that last the rest of the run
func give() -> void:
	if resource_path != "" and effect != Effect.RINGS and effect != Effect.SKIP_FLOORS:
		Test.owned_items.append(resource_path)   # so Rewrite's market can trade it away
	match effect:
		Effect.MAX_METER:
			Test.set_meter_bonus(Test.meter_bonus + amount)
		Effect.FULL_METER_EACH_FLOOR:
			Test.full_meter_each_floor = true
		Effect.FASTER_BOOST:
			Test.boost_bonus += amount
		Effect.BOSS_DAMAGE:
			Test.boss_hits += amount
		Effect.EXTRA_LIFE:
			Test.extra_lives += amount
		Effect.KEEP_RINGS:
			Test.ring_loss_scale *= 1.0 - clampf(amount / 100.0, 0.0, 1.0)
		Effect.RUN_FASTER:
			Test.speed_bonus += amount
		Effect.JUMP_HIGHER:
			Test.jump_bonus += amount
		Effect.LESS_METER:
			Test.meter_scale *= 1.0 - clampf(amount / 100.0, 0.0, 1.0)
		Effect.LONGER_FLIGHT:
			Test.fly_bonus += amount
		Effect.TRICK_METER:
			Test.trick_meter_bonus += amount
		Effect.STUN:
			Test.salvage_stuns += maxi(amount, 1)   # every Salvage visit, this many stuns
		Effect.SURVIVE:
			Test.salvage_saves += maxi(amount, 1)   # used up when a hunter gets you
		Effect.SHIELD:
			# One shield to keep till it's hit
			Test.shield_items += 1
			Test.shields_left += maxi(amount, 1)
			Test.shields_each_floor = 1 if Test.shield_items >= 2 else 0


# Undo give(): traded away at Rewrite's market
func take_back() -> void:
	Test.owned_items.erase(resource_path)
	match effect:
		Effect.MAX_METER:
			Test.set_meter_bonus(maxi(Test.meter_bonus - amount, 0))
		Effect.FULL_METER_EACH_FLOOR:
			Test.full_meter_each_floor = Test.owned_items.any(func(path): return (load(path) as SalvageItem).effect == Effect.FULL_METER_EACH_FLOOR)
		Effect.FASTER_BOOST:
			Test.boost_bonus = maxi(Test.boost_bonus - amount, 0)
		Effect.BOSS_DAMAGE:
			Test.boss_hits = maxi(Test.boss_hits - amount, 1)
		Effect.EXTRA_LIFE:
			Test.extra_lives = maxi(Test.extra_lives - amount, 0)
		Effect.KEEP_RINGS:
			var a := clampf(amount / 100.0, 0.0, 0.99)
			Test.ring_loss_scale = minf(Test.ring_loss_scale / (1.0 - a), 1.0)
		Effect.RUN_FASTER:
			Test.speed_bonus = maxi(Test.speed_bonus - amount, 0)
		Effect.JUMP_HIGHER:
			Test.jump_bonus = maxi(Test.jump_bonus - amount, 0)
		Effect.LESS_METER:
			var a := clampf(amount / 100.0, 0.0, 0.99)
			Test.meter_scale = minf(Test.meter_scale / (1.0 - a), 1.0)
		Effect.LONGER_FLIGHT:
			Test.fly_bonus = maxi(Test.fly_bonus - amount, 0)
		Effect.TRICK_METER:
			Test.trick_meter_bonus = maxi(Test.trick_meter_bonus - amount, 0)
		Effect.STUN:
			Test.salvage_stuns = maxi(Test.salvage_stuns - maxi(amount, 1), 0)
		Effect.SURVIVE:
			Test.salvage_saves = maxi(Test.salvage_saves - maxi(amount, 1), 0)
		Effect.SHIELD:
			Test.shield_items = maxi(Test.shield_items - 1, 0)
			Test.shields_each_floor = 1 if Test.shield_items >= 2 else 0
			Test.shields_left = maxi(Test.shields_left - maxi(amount, 1), 0)


# Can it still be traded away?
func tradeable() -> bool:
	if effect == Effect.EXTRA_LIFE:
		return Test.extra_lives >= amount
	if effect == Effect.SURVIVE:
		return Test.salvage_saves >= maxi(amount, 1)
	return true
