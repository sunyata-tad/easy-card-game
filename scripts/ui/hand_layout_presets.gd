class_name HandLayoutPresets

const CARD_WIDTH := 140.0
const BASE_Y := 20.0

const IDEAL_SPACINGS := {
	1: 0.0,
	2: 155.0,
	3: 155.0,
	4: 150.0,
	5: 148.0,
	6: 145.0,
	7: 142.0,
	8: 140.0,
	9: 138.0,
	10: 136.0
}

const ROTATION_CURVE := {
	1: {"max_rotation": 0.0, "curve_factor": 0.0},
	2: {"max_rotation": 4.0, "curve_factor": 1.0},
	3: {"max_rotation": 5.0, "curve_factor": 1.2},
	4: {"max_rotation": 5.0, "curve_factor": 1.2},
	5: {"max_rotation": 5.0, "curve_factor": 1.3},
	6: {"max_rotation": 5.0, "curve_factor": 1.3},
	7: {"max_rotation": 5.0, "curve_factor": 1.3},
	8: {"max_rotation": 4.0, "curve_factor": 1.2},
	9: {"max_rotation": 4.0, "curve_factor": 1.0},
	10: {"max_rotation": 3.0, "curve_factor": 1.0}
}

static func get_layout(hand_size: int, container_width: float) -> Dictionary:
	var size = maxi(hand_size, 1)
	
	var ideal_spacing: float
	var max_rotation: float
	var curve_factor: float
	
	if size <= 10 and IDEAL_SPACINGS.has(size):
		ideal_spacing = IDEAL_SPACINGS[size]
		var rc = ROTATION_CURVE[size]
		max_rotation = rc.max_rotation
		curve_factor = rc.curve_factor
	else:
		ideal_spacing = 130.0
		max_rotation = 4.0
		curve_factor = 1.0
	
	var max_spacing: float
	if size > 1:
		max_spacing = (container_width - CARD_WIDTH) / float(size - 1)
	else:
		max_spacing = ideal_spacing
	
	var spacing = minf(ideal_spacing, max_spacing)
	var total_width = CARD_WIDTH + (size - 1) * spacing
	var start_x = (container_width - total_width) / 2.0
	var center_index = (size - 1) / 2.0
	
	return {
		"spacing": spacing,
		"start_x": start_x,
		"center_index": center_index,
		"max_rotation": max_rotation,
		"curve_factor": curve_factor,
		"base_y": BASE_Y
	}

static func get_card_position(index: int, hand_size: int, container_width: float) -> Dictionary:
	var layout = get_layout(hand_size, container_width)
	
	var offset_from_center = index - layout.center_index
	var x_pos = layout.start_x + index * layout.spacing
	var rotation_deg = offset_from_center * (layout.max_rotation / max(layout.center_index, 0.5))
	var y_pos = layout.base_y + abs(offset_from_center) * layout.curve_factor
	
	return {
		"position": Vector2(x_pos, y_pos),
		"rotation": rotation_deg
	}
