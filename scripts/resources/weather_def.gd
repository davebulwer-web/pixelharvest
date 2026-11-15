class_name WeatherDef
extends Resource
##
## WeatherDef — one kind of day's weather: sunny, rain, storm, heatwave, snow,
## frost (Stage 11 session 2, DECISIONS 046).
##
## Each day has one. It's chosen the night before from the season's odds
## (SeasonTheme.weather_odds), or fixed by date (SeasonTheme.fixed_weather:
## autumn's last day is always frost), and the player is told a day ahead:
## the forecast is on the notice board and in the morning summary, and it's
## always right.
##
## What a weather does is all here as plain switches and numbers, so a new
## kind (fog, a blizzard) is a new file in data/weather/ and a line in a
## season's odds, with no code (rule 3). What it *looks* and *sounds* like is
## here too: an overlay scene (falling rain), a tint, a loop of sound.
##
## Must not use the GameState autoload: game_rules.tres preloads the seasons,
## and they preload these (a cycle stops the game starting).
##

## How saves and seasons refer to it (&"rain"). Must not change once used.
@export var id: StringName
## "Rain", for the HUD and the forecast.
@export var display_name: String
## What it means for the farm today, said in the morning summary and on the
## notice board: "Rain all day: every tilled tile is watered."
@export_multiline var today_text: String = ""

# --- What it does ------------------------------------------------------------

## Rain: every tile of tilled soil is watered in the morning, so the crops
## grow tonight without the watering can.
@export var waters_farm: bool = false

## How many nights' thirst an unwatered crop gains tonight. 1 is normal; a
## heatwave's 2 makes a crop wilt after one dry night instead of two.
@export_range(1, 3) var thirst_per_dry_night: int = 1

## A storm: crows stay away tonight.
@export var keeps_crows_away: bool = false

## Frost: on the morning it arrives, every crop that can't grow in the next
## season dies (they'd die at the season's turn anyway; frost is a night
## sooner). Crops that list the next season (Stage 12's hardy ones) live.
@export var kills_tender_crops: bool = false

## When it's fixed by date (SeasonTheme.fixed_weather), how many days ahead
## the board and the morning summary start warning about it. 0: only the
## usual one-day forecast.
@export var warn_days_ahead: int = 0
## The warning, after "Frost in 3 days (autumn day 28)." in the summary.
@export_multiline var warning_text: String = ""

# --- How it looks and sounds -------------------------------------------------

## A scene laid over the farm and the town while it lasts (falling rain,
## falling snow), as SeasonTheme.overlay is. Empty for none.
@export var overlay: PackedScene

## A colour the outdoors is multiplied by, on top of the time of day's and
## the season's (Daylight): grey for rain, warm for a heatwave. White for none.
@export var light_tint: Color = Color.WHITE

## A loop that plays while it lasts: rain on the leaves. Quieter indoors.
@export var ambience: AudioStream
## How loud the loop is outdoors, in decibels (0 is as made).
@export var ambience_volume_db: float = 0.0
