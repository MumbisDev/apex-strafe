class_name ReplayInput
extends InputSource

var frames: Array[InputFrame] = []
var index: int = 0
var loop: bool = false

func sample(_dt: float, _fighter: Fighter) -> InputFrame:
	if frames.is_empty():
		return InputFrame.new()
	if index >= frames.size():
		if loop:
			index = 0
		else:
			return frames[frames.size() - 1]
	var f := frames[index]
	index += 1
	return f

func reset() -> void:
	index = 0
