## 手牌布局预设：扇形（轻微弧度）摆放。
## - 中间卡牌最靠上（突出），向两侧逐渐下沉并轻微旋转，像手持牌。
## - 手牌超过 MAX_VISIBLE 时，由 ui_controller 只显示一个窗口；窗口外的卡牌隐藏，
##   悬浮在手牌区左右边缘可"旋转"窗口（滚动查看）。
class_name HandLayoutPresets

const CARD_WIDTH := 140.0
const MAX_VISIBLE := 9        ## 扇形同时显示的最大卡牌数
const BASE_Y := 6.0           ## 中间卡牌的 Y（越小越靠上）
const ARC_DROP := 30.0        ## 边缘卡牌相对中间的下沉量（弧度）
const MAX_ROTATION := 9.0     ## 边缘卡牌最大旋转角度（度）
const MIN_STEP := 78.0        ## 卡牌最小间距（重叠更多）
const MAX_STEP := 150.0       ## 卡牌最大间距

## 计算可见窗口内第 slot_index 张卡牌的位置与旋转。
## slot_index ∈ [0, visible_count)，0 为最左，visible_count-1 为最右。
static func get_card_position(slot_index: int, visible_count: int, container_width: float) -> Dictionary:
	var n := maxi(visible_count, 1)
	var center := container_width / 2.0
	var half := (n - 1) / 2.0

	# 水平间距：卡牌多时更挤（重叠），限制在 [MIN_STEP, MAX_STEP]
	var step := MAX_STEP
	if n > 1:
		step = (container_width - CARD_WIDTH) / float(n - 1)
	step = clampf(step, MIN_STEP, MAX_STEP)

	var offset := float(slot_index) - half     # 负数=左，0=中间，正数=右
	var x := center + offset * step - CARD_WIDTH / 2.0

	# 弧形：中间最靠上，向两侧逐渐下沉（二次曲线，轻微弧度）
	var norm := offset / maxf(half, 0.5)
	var y := BASE_Y + ARC_DROP * norm * norm

	# 旋转：左负右正，轻微倾斜
	var rotation := MAX_ROTATION * norm

	return {"position": Vector2(x, y), "rotation": rotation}
