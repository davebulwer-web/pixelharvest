extends StaticBody2D
##
## NoticeBoard — the board in the town square. Face it and press E to read it.
##
## Like the shipping bin, this node is only the board's presence: picture,
## collision and answering E. What's pinned to it is worked out fresh each
## time by Notices, and the town shows it in the dialogue box. The board just
## announces that it was read (EventBus.notice_board_read), so Stage 8's
## quests and market days can add their own notices without touching it.
##
## Since DECISIONS 050 it also posts a small job each day, and takes it in:
## the town hangs a "!" or "?" over it like over a person (Quests.BOARD).
##

const TILE_PX := 16

## How high its request marker floats above its base: just over the board.
const MARKER_HEIGHT := 46


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"notice_board")


## The board is two tiles wide, so facing its own cell or either neighbour
## counts as facing it.
func occupies(cell: Vector2i) -> bool:
	var home := Vector2i((position - Vector2(0, 1)) / TILE_PX)
	return cell.y == home.y and absi(cell.x - home.x) <= 1


func interact() -> void:
	EventBus.notice_board_read.emit()
