class_name SoundBank
extends Resource
##
## SoundBank — every sound effect the game plays, by name (DECISIONS 042).
##
## The Audio service decides WHEN a sound plays: it listens on EventBus and
## plays "till" when a tile is tilled, "coins" when something is bought, and
## so on. This resource decides WHAT each of those names sounds like. So a
## better sound is a data change (point the name at a new file), never a code
## change. data/audio/sound_bank.tres is the one the game uses.
##
## The files are made by art/build_sounds.py. A name with no sound here is
## simply silent, so a missing entry never stops the game.
##

## Sound name -> the sound. The names Audio uses are listed in audio.gd.
@export var sounds: Dictionary[StringName, AudioStream] = {}

## A little random change of pitch, up or down, each time a sound plays, so
## something done thirty times a day (watering) doesn't sound like a machine.
## 0.05 is ±5%. 0 turns it off.
@export var pitch_variation: float = 0.05
