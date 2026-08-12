## 遗物数据模型：单个遗物的静态配置（来自 data/relics.json）。
## 遗物 = 规则改变效果的本体（"把规则改变效果绑定在遗物上"）。
class_name RelicData

var id: String              ## 遗物唯一 id
var name: String            ## 显示名称
var description: String     ## 效果介绍（支持 \n 换行与①②③序号）
var flavor_text: String = ""   ## 风味介绍文本（单独空间）
var repeatable: bool = false   ## 是否可重复获取（防重复获取 bug；占位遗物为 true）

func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", id)
	description = data.get("description", "")
	flavor_text = data.get("flavor_text", "")
	repeatable = data.get("repeatable", false)

func duplicate() -> RelicData:
	return RelicData.new({"id": id, "name": name, "description": description, "flavor_text": flavor_text, "repeatable": repeatable})
