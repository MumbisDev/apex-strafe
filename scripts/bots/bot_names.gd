class_name BotNames
extends RefCounted
## Twelve bot identities. Index i pairs NAMES[i] with UITheme.BOT_COLORS[i].

const NAMES: Array[String] = [
	"Vex", "Juno", "Kilo", "Rook", "Nyx", "Pike",
	"Slate", "Orion", "Echo", "Tango", "Wren", "Blitz",
]

static func count() -> int:
	return NAMES.size()

static func name_at(index: int) -> String:
	return NAMES[posmod(index, NAMES.size())]

static func color_at(index: int) -> Color:
	return UITheme.BOT_COLORS[posmod(index, UITheme.BOT_COLORS.size())]

## Seeded shuffle of all identity indices so a match can take the first N.
static func shuffled_indices(rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for i in NAMES.size():
		out.append(i)
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
