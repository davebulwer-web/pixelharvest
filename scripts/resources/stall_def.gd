class_name StallDef
extends Resource
##
## StallDef — one market stall: whose it is and where it stands (DECISIONS 037).
##
## The shop behind the stall is an ordinary ShopDef (keeper, greetings, opening
## hours, what it buys and sells), so the shop menu and the keeper's words work
## exactly as they do indoors. The stall itself is only a picture, a counter to
## stand at, and a place on the map.
##
## Nothing in this file may touch an autoload (it is plain data).
##

@export var shop: ShopDef

## The cell the middle of the counter stands on, on the event's location's
## map. The counter is three cells wide (this one and one each side); the
## keeper stands on the cell above this one, and you talk to them from below.
@export var cell: Vector2i

## 48×64: an awning at the top, open in the middle where the keeper shows
## through, and a counter along the bottom 24 pixels. Its bottom edge sits on
## the bottom of `cell`.
@export var picture: Texture2D
