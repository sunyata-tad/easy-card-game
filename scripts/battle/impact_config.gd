## ImpactConfig —— 打击感参数配置（按伤害数值分档）
## 档位：<10 轻 / 10-20 中 / >20 重
## 返回 scale_peak(飘字峰值缩放) / rotation(扭曲弧度) / shake_amp(震动幅度) / shake_dur(震动时长)
class_name ImpactConfig

const LIGHT_THRESHOLD := 10
const HEAVY_THRESHOLD := 20

static func get_params(amount: int) -> Dictionary:
	if amount < LIGHT_THRESHOLD:
		return {"scale_peak": 1.2, "rotation": 0.05, "shake_amp": 2.0, "shake_dur": 0.1}
	elif amount <= HEAVY_THRESHOLD:
		return {"scale_peak": 1.4, "rotation": 0.1, "shake_amp": 5.0, "shake_dur": 0.2}
	else:
		return {"scale_peak": 1.6, "rotation": 0.15, "shake_amp": 10.0, "shake_dur": 0.3}
## 给飘字 Label 施加跳动(scale 脉冲)+扭曲(rotation 抖动)特效，按 amount 分档强度
static func apply_text_effect(label: Label, amount: int, tween_owner: Node) -> void:
	var params := get_params(amount)
	var peak := float(params.scale_peak)
	var rot := float(params.rotation)
	var rot_dir := 1.0 if randf() > 0.5 else -1.0
	# 跳动：scale 脉冲
	var scale_tween := tween_owner.create_tween()
	scale_tween.tween_property(label, "scale", Vector2(peak, peak), 0.08).set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC)
	# 扭曲：rotation 抖动
	var rot_tween := tween_owner.create_tween()
	rot_tween.tween_property(label, "rotation", rot_dir * rot, 0.04)
	rot_tween.tween_property(label, "rotation", -rot_dir * rot * 0.5, 0.04)
	rot_tween.tween_property(label, "rotation", 0.0, 0.08)