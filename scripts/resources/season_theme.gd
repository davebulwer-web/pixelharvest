class_name SeasonTheme
extends Resource
##
## SeasonTheme — one season of the calendar: its name, how the world looks
## while it lasts (DECISIONS 005, 021, 025), and its weather's odds
## (DECISIONS 046).
##
## GameRules.seasons lists these in calendar order; GameState.season is an
## index into that list. Which crops grow when is NOT here: each crop lists the
## season ids it grows in (CropDef.seasons), so adding a crop never means
## editing four season files.
##
## The rule that makes swapping safe: every season's ground tileset has the
## SAME atlas layout — grass at the same coordinates, tilled soil at the same
## coordinates, and so on — differing only in the pixels. That's exactly what
## image-to-image from one base tileset produces. So the farm can swap the
## tileset and redraw, and every tile lands in the right place.
##

## Crops name seasons by this id (&"spring"), so it must not change once
## crops refer to it. display_name is free to change.
@export var id: StringName
@export var display_name: String

@export var ground_tileset: TileSet

## Different pictures for objects this season, by object id — for
## example &"tree" -> a bare or snowy tree. Buildings are looked up by their
## location id the same way (&"farmhouse" -> the snowy-roofed house), and their
## seasonal picture must be the same size as the normal one. The object's scene must have a
## Sprite2D called "Sprite" (they all do). Anything not listed keeps the
## picture its scene was built with.
@export var object_sprites: Dictionary[StringName, Texture2D] = {}

## Optional scene added to the farm and town while this season lasts, the
## whole season long. Empty for none. (Winter's falling snow used to be this;
## since DECISIONS 046 it's the snow weather's overlay, so it only falls on
## snowy days.)
@export var overlay: PackedScene

## A colour the whole outdoor world is multiplied by this season — white for
## none, a pale blue for winter's chill. Daylight combines it with the time
## of day's colour (DECISIONS 036), since a scene can only have one tint.
@export var light_tint: Color = Color.WHITE

## The weather's odds this season (DECISIONS 046): each kind of weather and
## its weight. {sunny: 6, rain: 3, storm: 1} means sunny six days in ten, on
## average. Empty: always fine (no weather at all).
@export var weather_odds: Dictionary[WeatherDef, int] = {}

## Weather fixed by the day of the season, whatever the odds say: autumn's
## frost on day 28. The day number is the day of the season (1 to 28).
@export var fixed_weather: Dictionary[int, WeatherDef] = {}


## The weather for day `day_of_season` of this season: the fixed one if that
## day has one, otherwise one drawn from weather_odds with `rng`. Null if
## there's no weather this season at all. The odds are walked in id order,
## so the same dice always give the same weather.
func weather_on(day_of_season: int, rng: RandomNumberGenerator) -> WeatherDef:
	if fixed_weather.has(day_of_season) and fixed_weather[day_of_season] != null:
		return fixed_weather[day_of_season]
	var kinds: Array = weather_odds.keys().filter(
			func(w: WeatherDef) -> bool: return w != null and weather_odds[w] > 0)
	if kinds.is_empty():
		return null
	kinds.sort_custom(func(a: WeatherDef, b: WeatherDef) -> bool: return String(a.id) < String(b.id))
	var total := 0
	for kind: WeatherDef in kinds:
		total += weather_odds[kind]
	var roll := rng.randi_range(1, total)
	for kind: WeatherDef in kinds:
		roll -= weather_odds[kind]
		if roll <= 0:
			return kind
	return kinds[-1]
