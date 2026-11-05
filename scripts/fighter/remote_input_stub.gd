class_name RemoteInput
extends InputSource
## Stub for future online multiplayer. Documents the interface only.

var last_frame: InputFrame = InputFrame.new()

func sample(_dt: float, _fighter: Fighter) -> InputFrame:
	## Future: receive networked InputFrame for this tick.
	return last_frame

func apply_network_frame(frame: InputFrame) -> void:
	last_frame.copy_from(frame)
