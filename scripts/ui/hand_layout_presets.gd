class_name HandLayoutPresets

const CARD_WIDTH := 140.0
const BASE_Y := 20.0

const LAYOUTS := {
	1: {
		"spacing": 0.0,
		"max_rotation": 0.0,
		"curve_factor": 0.0
	},
	2: {
		"spacing": 140.0,
		"max_rotation": 6.0,
		"curve_factor": 1.5
	},
	3: {
		"spacing": 130.0,
		"max_rotation": 7.0,
		"curve_factor": 2.0
	},
	4: {
		"spacing": 115.0,
		"max_rotation": 8.0,
		"curve_factor": 2.0
	},
	5: {
		"spacing": 100.0,
		"max_rotation": 9.0,
		"curve_factor": 2.5
	},
	6: {
		"spacing": 88.0,
		"max_rotation": 9.0,
		"curve_factor": 2.5
	},
	7: {
		"spacing": 76.0,
		"max_rotation": 10.0,
		"curve_factor": 2.5
	},
	8: {
		"spacing": 66.0,
		"max_rotation": 10.0,
		"curve_factor": 2.5
	},
	9: {
		"spacing": 58.0,
		"max_rotation": 9.0,
		"curve_factor": 2.0
	},
	10: {
		"spacing": 52.0,
		"max_rotation": 8.0,
		"curve_factor": 2.0
	}
}

static func get_layout(hand_size: int, container_width: float) -> Dictionary:
	var size = maxi(hand_size, 1)
	
	if size <= 10 and LAYOUTS.has(size):
		var layout = LAYOUTS[size]
		var spacing = layout.spacing
		var total_width = CARD_WIDTH + (size - 1) * spacing
		var start_x = (container_width - total_width) / 2.0
		var center_index = (size - 1) / 2.0
		
		return {
			"spacing": spacing,
			"start_x": start_x,
			"center_index": center_index,
			"max_rotation": layout.max_rotation,
			"curve_factor": layout.curve_factor,
			"base_y": BASE_Y
		}
	
	var spacing = minf((container_width - CARD_WIDTH) / maxf(size - 1, 1), 52.0)
	var total_width = CARD_WIDTH + (size - 1) * spacing
	var start_x = (container_width - total_width) / 2.0
	var center_index = (size - 1) / 2.0
	
	return {
		"spacing": spacing,
		"start_x": start_x,
		"center_index": center_index,
		"max_rotation": 8.0,
		"curve_factor": 2.0,
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

