---
name: godot-scene-writing
description: 用于编写 Godot 的 .tscn 场景文件，提供节点类型、布局属性和最佳实践指南
---

# Godot 场景编写指南

## 概述

此技能帮助你编写 Godot 的 .tscn 场景文件。Godot 4.x 使用文本格式保存场景，可直接编辑。

---

## 场景文件结构

### 基本格式

```gdscript
[gd_scene format=3 uid="uid://xxxxx"]

[ext_resource type="Script" path="res://scripts/xxx.gd" id="1_script"]

[node name="NodeName" type="NodeType" parent="."]
property = value

[node name="ChildName" type="NodeType" parent="ParentPath"]
property = value
```

---

## 常用节点类型

### 容器节点

| 类型 | 用途 | 常用属性 |
|------|------|----------|
| Control | UI基类 | anchors, position, size |
| VBoxContainer | 垂直布局 | separation |
| HBoxContainer | 水平布局 | separation |
| MarginContainer | 外边距 | margin_* |
| ScrollContainer | 滚动容器 | scroll_horizontal, scroll_vertical |

### 显示节点

| 类型 | 用途 | 常用属性 |
|------|------|----------|
| Label | 文本显示 | text, font_size, font_color |
| Button | 按钮 | text, disabled |
| ColorRect | 纯色背景 | color |
| TextureRect | 图片显示 | texture, stretch_mode |
| ProgressBar | 进度条 | value, max_value, show_percentage |

### 对话框

| 类型 | 用途 | 常用属性 |
|------|------|----------|
| AcceptDialog | 确认对话框 | dialog_text, title |
| ConfirmationDialog | 确认/取消对话框 | dialog_text, title |
| FileDialog | 文件选择 | file_mode, filters |

---

## 布局预设 (anchors_preset)

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | TOP_LEFT | 左上角 |
| 1 | TOP_RIGHT | 右上角 |
| 2 | BOTTOM_LEFT | 左下角 |
| 3 | BOTTOM_RIGHT | 右下角 |
| 4 | CENTER_LEFT | 左中 |
| 5 | CENTER_TOP | 上中 |
| 6 | CENTER_RIGHT | 右中 |
| 7 | CENTER_BOTTOM | 下中 |
| 8 | CENTER | 正中心 |
| 9 | LEFT_WIDE | 左侧填充 |
| 10 | TOP_WIDE | 顶部填充 |
| 11 | RIGHT_WIDE | 右侧填充 |
| 12 | BOTTOM_WIDE | 底部填充 |
| 13 | V_CENTER_WIDE | 垂直居中填充 |
| 14 | H_CENTER_WIDE | 水平居中填充 |
| 15 | FULL_RECT | 全屏填充 |

---

## 常用属性

### 布局属性

```gdscript
# 锚点
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 0.0
anchor_bottom = 1.0

# 或使用预设
anchors_preset = 15

# 偏移
offset_left = -100.0
offset_right = 100.0
offset_top = 0.0
offset_bottom = 0.0

# 增长方向
grow_horizontal = 2  # 0=左, 1=无, 2=右
grow_vertical = 2    # 0=上, 1=无, 2=下
```

### 尺寸属性

```gdscript
# 最小尺寸
custom_minimum_size = Vector2(200, 40)

# 绝对尺寸
size = Vector2(140, 180)

# 尺寸标志
size_flags_horizontal = 3  # 1=填充, 2=扩展, 4=收缩
size_flags_vertical = 3
```

### 文本属性

```gdscript
# Label/Button 文本
text = "按钮文本"

# 字体大小
theme_override_font_sizes/font_size = 24

# 字体颜色
theme_override_colors/font_color = Color(1, 0.5, 0.5, 1)

# 对齐
horizontal_alignment = 1  # 0=左, 1=中, 2=右
vertical_alignment = 1    # 0=上, 1=中, 2=下
```

### 颜色属性

```gdscript
# ColorRect 颜色
color = Color(0.1, 0.1, 0.15, 1.0)

# RGBA格式: Color(R, G, B, A)
# 值范围: 0.0 ~ 1.0
```

---

## 节点路径规则

### parent 属性

| 值 | 说明 |
|------|------|
| "." | 根节点 |
| "ParentName" | 直接子节点 |
| "ParentPath/ChildName" | 嵌套子节点 |

### 示例

```gdscript
# 根节点
[node name="Root" type="Control" parent="."]

# 根节点的直接子节点
[node name="Background" type="ColorRect" parent="."]

# Background 的子节点
[node name="Label" type="Label" parent="Background"]

# 嵌套路径
[node name="Content" type="VBoxContainer" parent="ScrollContainer"]
```

---

## 完整示例

### 示例1: 基础UI界面

```gdscript
[gd_scene format=3 uid="uid://example_001"]

[ext_resource type="Script" path="res://scripts/example.gd" id="1_script"]

[node name="ExampleScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.15, 1)

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -100.0
offset_top = 30.0
offset_right = 100.0
offset_bottom = 60.0
grow_horizontal = 2
theme_override_colors/font_color = Color(0.4, 1, 0.4, 1)
theme_override_font_sizes/font_size = 28
horizontal_alignment = 1
text = "标题"

[node name="ButtonContainer" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 0
alignment = 1
theme_override_constants/separation = 15

[node name="ConfirmButton" type="Button" parent="ButtonContainer"]
layout_mode = 2
text = "确认"

[node name="CancelButton" type="Button" parent="ButtonContainer"]
layout_mode = 2
text = "取消"
```

### 示例2: 带滚动的列表

```gdscript
[gd_scene format=3 uid="uid://example_002"]

[node name="ScrollScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="ScrollContainer" type="ScrollContainer" parent="."]
layout_mode = 1
anchors_preset = 14
anchor_top = 0.1
anchor_right = 1.0
anchor_bottom = 0.85
offset_top = 20.0
offset_bottom = -20.0
grow_horizontal = 2
grow_vertical = 2

[node name="ListContainer" type="VBoxContainer" parent="ScrollContainer"]
size_flags_horizontal = 3
theme_override_constants/separation = 10

[node name="Item1" type="Button" parent="ScrollContainer/ListContainer"]
layout_mode = 2
text = "项目1"

[node name="Item2" type="Button" parent="ScrollContainer/ListContainer"]
layout_mode = 2
text = "项目2"
```

---

## 常见问题

### Q: 如何让节点居中？

```gdscript
anchors_preset = 5  # CENTER_TOP
anchor_left = 0.5
anchor_right = 0.5
offset_left = -100.0  # 宽度一半
offset_right = 100.0
grow_horizontal = 2
```

### Q: 如何让节点填充父容器？

```gdscript
anchors_preset = 15  # FULL_RECT
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

### Q: 如何添加间距？

```gdscript
# HBoxContainer/VBoxContainer
theme_override_constants/separation = 10

# MarginContainer
theme_override_constants/margin_left = 20
theme_override_constants/margin_right = 20
theme_override_constants/margin_top = 20
theme_override_constants/margin_bottom = 20
```

### Q: 如何连接按钮信号？

在脚本中使用：

```gdscript
func _ready():
    var button = $ButtonContainer/ConfirmButton
    button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed():
    print("确认按钮被点击")
```

---

## 最佳实践

### 1. 使用锚点预设

优先使用 `anchors_preset` 而非手动设置所有锚点。

### 2. 层次结构清晰

```
根节点 (Control)
├── Background (ColorRect)
├── Content (VBoxContainer)
│   ├── Title (Label)
│   └── Body (HBoxContainer)
└── Footer (HBoxContainer)
```

### 3. 命名规范

- 使用 PascalCase：`ButtonContainer`
- 描述性命名：`ConfirmButton` 而非 `Button1`

### 4. 分离脚本

```gdscript
[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_script"]

[node name="MainMenu" type="Control"]
script = ExtResource("1_script")
```

---

## 生成 UID

每个场景文件需要唯一的 UID：

```gdscript
[gd_scene format=3 uid="uid://unique_identifier"]
```

可以使用格式：`uid://场景名_随机数`

---

## 参考模板

### 基础菜单模板

```gdscript
[gd_scene format=3 uid="uid://menu_template"]

[ext_resource type="Script" path="res://scripts/menu.gd" id="1_script"]

[node name="Menu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.15, 1)

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
alignment = 1
theme_override_constants/separation = 20

[node name="StartButton" type="Button" parent="VBox"]
layout_mode = 2
text = "开始游戏"

[node name="ExitButton" type="Button" parent="VBox"]
layout_mode = 2
text = "退出游戏"
```
