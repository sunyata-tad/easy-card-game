# 卡牌游戏项目状态文档

> 最后更新：2026-05-31
> 项目路径：`D:/游戏开发/项目文件/card`
> 引擎：Godot 4.x + GDScript
> 命名约定：snake_case

---

## 1. 项目概述

回合制卡牌战斗游戏，类似Slay the Spire。玩家通过卡牌操控属性和牌堆，每回合自动攻击（力量为基础伤害），战斗间有地图探索、奖励选择、存档系统。

---

## 2. 核心设计理念

### 2.1 卡牌设计
- **负面效果可重合**，正面效果各自独立
- 卡牌升级：upgrade JSON已定义，但**游戏内无触发途径**

### 2.2 战斗模型
- **自动攻击**：力量永久基础伤害，每回合自动结算
- 卡牌用于调节属性和操控牌堆，不是唯一伤害来源

### 2.3 抽牌机制
- **游戏王模式**：开局抽5，每回合抽1
- 不自动弃手牌，手牌>10时玩家选择弃牌
- 弃牌上限 = hand.size()-10，区间[0, max]
- **不自动洗牌**（需卡牌效果手动触发）

### 2.4 弃牌流程
- 点击结束回合 → 弃牌检查 → 弃牌选择模式 → 确认 → 敌人回合结算

### 2.5 卡牌交互
- **非指向性卡**：拖出手牌区打出
- **指向性卡**：拖拽时移到屏幕中央+箭头选目标
- **选择模式**：点击卡牌上移到画面中央标记选中，再次点击取消

### 2.6 效果与属性体系
- **所有持续性效果统一为buff**，由buff_manager管理
- **所有属性统一为buff**：strength/dexterity/stored_power全是buff，PlayerManager无裸属性

### 2.7 buff衰减
- stack_decay字段可自定义衰减规则
- 支持的衰减事件：on_turn_end（掉N层）、on_turn_end_pct（百分比掉层）、on_attacked、on_card_played等
- 通过decay_on_event(event)通用触发
- **当前所有buff均为空字典=永续不衰减，留待逐个配置**

### 2.8 无层数buff
- NO_STACK_BUFFS = ["skip_attack", "ignore_block", "counter_stance"]
- buff栏只显示符号不显示数字，stacks固定为1

---

## 3. 架构与文件结构

### 3.1 目录结构
```
card/
├── scenes/                    # Godot场景文件
│   ├── main.tscn              # 主入口
│   ├── start.tscn             # 主菜单
│   ├── BattleScene.tscn       # 战斗场景
│   ├── Card.tscn              # 卡牌UI场景
│   ├── EnemyUI.tscn           # 敌人UI场景
│   ├── MapScreen.tscn         # 地图场景
│   ├── RewardScreen.tscn      # 奖励场景
│   ├── GameOverScreen.tscn    # 游戏结束场景
│   ├── CharacterSelectScreen.tscn
│   └── CharacterCreationScreen.tscn
├── scripts/                   # GDScript脚本
│   ├── battle/                # 战斗系统
│   │   ├── battle_controller.gd
│   │   ├── effect_resolver.gd
│   │   ├── ui_controller.gd
│   │   ├── state_machine.gd
│   │   └── turn_manager.gd
│   ├── systems/               # 游戏系统
│   │   ├── player_manager.gd
│   │   ├── enemy_unit.gd
│   │   ├── card_system.gd
│   │   └── enemy_system.gd
│   ├── effects/               # 效果系统
│   │   ├── buff_manager.gd
│   │   ├── buff_data.gd
│   │   └── hook_chain.gd
│   ├── ui/                    # UI组件
│   │   ├── card_ui.gd
│   │   ├── enemy_ui.gd
│   │   ├── player_ui.gd
│   │   ├── hand_layout_presets.gd
│   │   ├── drag_arrow.gd
│   │   └── target_marker.gd
│   ├── battle.gd              # 战斗场景入口
│   ├── game_manager.gd        # 全局场景管理
│   ├── game_data.gd           # 全局数据存储（Autoload）
│   ├── card_data.gd           # 卡牌数据类
│   ├── card_database.gd       # 卡牌数据库
│   ├── enemy_data.gd          # 敌人数据类
│   ├── enemy_database.gd      # 敌人数据库
│   ├── save_manager.gd        # 存档管理
│   ├── map_controller.gd      # 地图控制器
│   ├── map_screen.gd          # 地图场景
│   ├── map_database.gd        # 地图数据库
│   ├── map_state.gd           # 地图状态
│   ├── reward_screen.gd       # 奖励场景
│   ├── game_over_screen.gd    # 游戏结束场景
│   ├── start.gd               # 主菜单
│   ├── character_data.gd      # 角色数据
│   ├── character_manager.gd   # 角色管理
│   ├── character_select_screen.gd
│   └── character_creation_screen.gd
└── data/                      # JSON数据
    ├── cards/                 # 卡牌定义
    │   ├── 斩击.json
    │   ├── 格挡.json
    │   ├── 蓄力.json
    │   ├── 蓄势.json
    │   ├── 破甲.json
    │   ├── 招架.json
    │   └── vulnerable.json
    ├── enemies/               # 敌人定义
    │   ├── test_dummy.json
    │   ├── 石甲卫兵.json
    │   ├── 暗影刺客.json
    │   └── 腐化法师.json
    ├── decks.json             # 初始卡组
    ├── tags.json              # 标签定义
    └── maps/
        └── test_map.json
```

### 3.2 场景流程
```
主菜单(start) → 角色选择 → 角色创建 → 地图(MapScreen) → 战斗(BattleScene) → 奖励(RewardScreen)
                                                                    ↓
                                                              游戏结束(GameOverScreen)
```

GameManager场景枚举：MAIN_MENU, CHARACTER_SELECT, CHARACTER_CREATION, MAP, BATTLE, REWARD, GAME_OVER

---

## 4. 核心系统详解

### 4.1 状态机 (StateMachine)

状态枚举：INIT → DRAW_PHASE → PLAYER_TURN → RESOLVING → ENEMY_TURN → TURN_END → VICTORY/DEFEAT

合法转换：
- INIT → DRAW_PHASE
- DRAW_PHASE → PLAYER_TURN, VICTORY, DEFEAT
- PLAYER_TURN → RESOLVING, ENEMY_TURN, VICTORY, DEFEAT
- RESOLVING → PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT
- ENEMY_TURN → TURN_END, VICTORY, DEFEAT
- TURN_END → DRAW_PHASE, ENEMY_TURN, VICTORY, DEFEAT

关键字段：`previous_state`（用于判断是否从RESOLVING进入PLAYER_TURN，控制回合提示显示）

### 4.2 战斗流程 (BattleController)

```
setup_battle() → start_battle()
  → INIT → DRAW_PHASE(抽牌,决定意图) → PLAYER_TURN
  → 玩家操作(打出卡牌→RESOLVING→PLAYER_TURN循环)
  → 结束回合 → ENEMY_TURN → TURN_END
  → _process_turn_end_effects():
      1. tick_buffs_on_turn_end (毒/再生等)
      2. _execute_player_auto_attack (获取护甲,判断skip_attack,计算伤害,攻击,清除stored_power)
      3. _execute_enemy_attacks (逐个执行敌人行动)
      4. decrease_durations + remove_at_turn_end
  → DRAW_PHASE(下回合)
```

关键细节：
- setup_battle从GameData读取strength/dexterity创建初始buff
- sync_player_stats_to_gamedata从buff_manager写回GameData
- skip_attack时仍获取dexterity护甲，只跳过攻击
- auto_attack后执行`remove_buff("stored_power")`清除蓄力

### 4.3 BuffManager modifier体系

MODIFIER_FORMULAS定义：
| buff_id | modifier公式 | 说明 |
|---------|-------------|------|
| strength | damage_add=float(stacks) | 永久加伤害 |
| dexterity | block_add=float(stacks) | 永久加护甲 |
| temp_strength | damage_add=float(stacks) | 临时加伤害 |
| stored_power | damage_add=float(stacks) | 蓄力伤害 |
| weak | damage_mult=0.75 | 伤害乘算 |
| vulnerable | damage_taken_mult=1.5 | 受伤乘算 |
| skip_attack | {} | 无modifier |
| ignore_block | {} | 无modifier |
| counter_stance | {} | 无modifier |

DURATION_STACK_BUFFS = ["weak", "vulnerable"]：叠加延长duration而非stacks

关键方法：
- `get_flat_add(stat)`: 累加所有xxx_add modifier值（不乘stacks，因MODIFIER_FORMULAS已包含）
- `get_mult(stat)`: 累乘所有xxx_mult modifier值
- `apply_buff()`: 已存在→add_stacks+recalculate；不存在→duplicate+recalculate+append
- `recalculate_modifiers()`: 根据MODIFIER_FORMULAS重新计算buff.modifiers
- `decrease_durations()`: 处理duration递减+stack_decay衰减+过期移除
- `decay_on_event(event)`: 通用事件触发衰减

### 4.4 伤害计算链条

**卡牌伤害（effect_resolver._resolve_damage）：**
```
total = base_damage + strength + temp_strength  （不加stored_power）
total × damage_mult(weak)
→ target.take_damage(final_damage)
    → final_damage × damage_taken_mult(vulnerable)  （由take_damage内部统一处理）
```

**自动攻击伤害（battle_controller._execute_player_auto_attack）：**
```
total = get_total_damage() = get_flat_add("damage")  （含strength+temp_strength+stored_power）
total × damage_mult(weak)
→ target.take_damage(final_damage)
    → final_damage × damage_taken_mult(vulnerable)
```

**关键规则：**
- effect_resolver不再外部乘damage_taken_mult（避免双算）
- stored_power只参与auto_attack，不参与卡牌伤害
- auto_attack后执行remove_buff("stored_power")

### 4.5 PlayerManager便捷方法

| 方法 | 实现 |
|------|------|
| get_strength() | buff_manager.get_buff_by_id("strength").stacks |
| get_dexterity() | buff_manager.get_buff_by_id("dexterity").stacks |
| get_stored_power() | buff_manager.get_buff_by_id("stored_power").stacks |
| get_total_damage() | int(buff_manager.get_flat_add("damage")) |
| get_total_block() | int(buff_manager.get_flat_add("block")) |

### 4.6 EffectResolver效果类型

| effect_type | 处理函数 | 说明 |
|-------------|---------|------|
| damage | _resolve_damage | 对目标造成伤害 |
| block | _resolve_block | 给目标加护甲 |
| heal | _resolve_heal | 治疗 |
| damage_boost | _resolve_damage_boost | 永久力量+value |
| temp_damage_boost | _resolve_temp_damage_boost | 临时力量(duration=1, on_turn_end_remove) |
| skip_attack | _resolve_skip_attack | 蓄势buff(duration=1, on_turn_end_remove) |
| store_damage | _resolve_store_damage | 蓄力：当前力量+临时力量→stored_power，移除temp_strength |
| ignore_block | _resolve_ignore_block | 破甲buff(duration=1, on_turn_end_remove) |
| counter_stance | _resolve_counter_stance | 招架buff(duration=1, on_turn_end_remove) |
| draw | _resolve_draw | 抽牌 |
| apply_buff / apply_debuff | _resolve_apply_buff | 应用buff（兼容buff_type和buff_id字段） |
| add_card_to_hand | _resolve_add_card | 添加卡牌到手牌 |
| search_draw | _resolve_search_draw | 搜索抽牌堆并抽牌 |
| search_discard | _resolve_search_discard | 搜索弃牌堆并抽牌 |
| search_draw_by_tag | _resolve_search_draw_by_tag | 按标签搜索抽牌堆 |
| search_discard_by_tag | _resolve_search_discard_by_tag | 按标签搜索弃牌堆 |
| exhaust_random | _resolve_exhaust_random | 随机消耗手牌 |
| discard_random | _resolve_discard_random | 随机弃掉手牌 |
| shuffle_discard_to_draw | _resolve_shuffle_discard_to_draw | 手动洗牌 |

### 4.7 store_damage（蓄力）详细逻辑

```gdscript
func _resolve_store_damage(source):
    current = source.get_strength()           # 永久力量
    temp = source.buff_manager.get_buff_by_id("temp_strength")
    if temp:
        current += temp.stacks                 # 加上临时力量
        source.buff_manager.remove_buff("temp_strength")  # 移除临时力量
    stored = source.buff_manager.get_buff_by_id("stored_power")
    if stored:
        stored.add_stacks(current)             # 累加到已有蓄力
        recalculate_modifiers(stored)
    else:
        create new stored_power buff           # 首次蓄力
```

### 4.8 地图系统 (MapScreen)

#### 设计决策与失败历史

**核心需求**：纯文本地图，地点以文本框表示，连线表示通路。动态创建/删除节点，当前地点始终在屏幕中央，移动动画连续丝滑。

**失败尝试（3次）**：
1. **预创建按钮方案**：导致位置重置时"瞬移"（动画后位置与逻辑映射不一致）
2. **移动按钮位置方案**：动画后调用`_layout_buttons()`重置位置导致瞬移
3. **临时副本方案**：副本移动后原按钮仍需重置位置，同样瞬移
4. **根本问题**：预创建按钮的索引与物理位置映射在动画后不一致

**成功方案 — 动态节点**：
- 不预创建按钮，根据需要动态生成位置按钮
- 移动时不改变节点位置，而是通过偏移量计算新节点位置
- 旧节点淡出后删除，新节点在正确位置创建并淡入

#### map_screen.gd 关键结构

```gdscript
var node_container: Control
var active_nodes: Dictionary = {}  # {location_id: {btn: Button, base_pos: Vector2}}
var map_offset: Vector2 = Vector2.ZERO
var is_animating: bool = false

const BTN_W := 100
const BTN_H := 36
const GAP_X := 40
const GAP_Y := 30
```

#### 新增：地图总览函数（_on_map_overview_pressed）

| 函数 | 说明 |
|------|------|
| `_on_map_overview_pressed()` | 弹出世界地图PopupPanel，两级视图（世界列表→区域详情）|
| `_get_regions()` | 从 current_map_data 的 "regions" 字段获取区域数据 |
| `_build_overview_map(layout, zoom)` | 根据布局数据构建可视化画布（ColorRect+Label+Line2D）|
| `_compute_fit_zoom(layout, avail_w, avail_h)` | 计算自动适配视口的缩放比例 |
| `_compute_overview_layout(valid_ids)` | BFS从当前位置开始计算节点网格布局 |

#### 关键函数

| 函数 | 说明 |
|------|------|
| `_get_center_pos()` | 获取中心位置，容器尺寸为0时回退(1152,280) |
| `_get_grid_position(grid_index, center_pos)` | 根据grid索引(0-8)计算节点位置（4=中心，其他8方向） |
| `_get_direction_offset(dir_name)` | 返回8方向偏移Vector2 |
| `_create_node(location_id, location_data, pos, is_current)` | 动态创建Button节点，初始透明(a=0)，当前地点disabled+金色字体 |
| `_refresh_nodes()` | 清空active_nodes，重新根据grid创建所有节点 |
| `_on_node_pressed(location_id)` | 点击节点→查找grid索引→映射Direction→调用_do_move_animation |
| `_do_move_animation(direction)` | 核心动画函数（详见下方） |

#### _do_move_animation 动画流程

```
1. 方向枚举→字符串 → 获取move_offset → 计算center_pos
2. 旧节点：set_parallel(true) 同时执行：
   - 位移：position += move_offset（0.35秒，EASE_IN_OUT）
   - 淡出：modulate.a → 0（0.2秒，EASE_IN）
3. await 0.35秒
4. 删除所有旧节点（queue_free + active_nodes.clear()）
5. map_controller.move_to_direction(direction) 更新数据
6. 新节点：在 start_pos = final_pos - move_offset 处创建（透明）
   - 位移：start_pos → final_pos（0.35秒，EASE_OUT）
   - 淡入：modulate.a → 1（0.2秒，EASE_OUT，延迟0.05秒）
7. await 0.35秒
8. is_animating = false
```

#### 已修复的地图Bug

| Bug | 原因 | 修复 |
|-----|------|------|
| 初始位置不合理 | `_refresh_nodes`中`node_container.size`首次调用为(0,0) | `_get_center_pos()`增加回退值Vector2(1152,280) |
| 旧节点未删除导致重叠 | `queue_free`延迟执行，新旧节点同帧同时显示 | 先收集旧按钮引用，await后统一queue_free+clear |
| 无淡入淡出效果 | 旧节点只有位移没有透明度变化 | `set_parallel(true)`让位移和淡出/淡入同时执行 |

#### 地图UI布局

- `_create_map_section()`：ColorRect背景(0.05,0.05,0.1) + node_container(clip_contents=true)
- map_section custom_minimum_size = (0, 280)
- 可交互区域改为横向排列(HBoxContainer)
- 地点信息面板 + 交互面板互斥显示

### 4.9 CardSystem

- MAX_HAND_SIZE = 10
- draw_cards()：空抽牌堆不自动洗牌，emit deck_exhausted
- manual_shuffle_discard_to_draw()：手动洗牌方法
- 支持搜索抽牌堆/弃牌堆/按标签搜索
- 支持消耗(exhaust)和弃牌(discard)

---

## 5. UI系统

### 5.1 UIController

关键变量：
- `_card_select_active/_card_select_min/_card_select_max/_card_selected_cards`：弃牌选择模式状态
- `drag_arrow: DragArrow`：指向性卡拖拽箭头
- `is_dragging/dragging_card/drag_card_node`：拖拽状态
- `is_selecting_target`：选目标状态
- `player_manager`：引用（用于敌人意图计算和buff变化刷新）

关键信号：card_clicked, card_released, card_cancelled, card_dropped, card_played, enemy_selected, end_turn_clicked

### 5.2 CardUI

关键变量：
- `is_dragging/is_pressed/is_hovered/is_select_mode/is_awaiting_target`
- `original_position/original_scale/original_rotation`：动画还原用
- `drag_exited_hand`：拖拽出手牌区标志

选择模式行为：
- is_select_mode=true时禁止hover动画和拖拽
- 选择模式不调_cancel_press，不触_animate_press_down
- mouse_filter恢复为MOUSE_FILTER_STOP

### 5.3 EnemyUI

- 需要player_manager引用（意图伤害考虑玩家vulnerable）
- buff栏使用offset布局
- 支持tooltip悬停弹窗（Button+mouse_entered/exited+自定义PanelContainer）
- NO_STACK_BUFFS不显示层数

### 5.4 手牌布局 (HandLayoutPresets)

- CARD_WIDTH = 140.0
- IDEAL_SPACINGS: 1-10张的理想间距
- ROTATION_CURVE: 1-10张的旋转曲线
- 动态spacing = min(ideal, max_spacing)
- max_spacing = (container_width - CARD_WIDTH) / (n-1)
- HandArea: offset_left=192, anchor_right=1

### 5.5 弃牌选择模式

信号路径：CardUI._gui_input → is_select_mode → emit card_clicked → ui_controller._on_card_select_card_clicked → _toggle_card_selection

选中动画：tween移到画面中央+rotation归零+放大1.1+变红+z_index=50
取消动画：tween回original_position+original_rotation+original_scale+白色+z_index=0
多张选中：_reposition_selected_cards水平错开排列（spacing=card_width+20）

弃牌栏位置：PRESET_TOP_WIDE（屏幕顶部，不遮挡手牌）

### 5.6 回合提示

- 只在回合真正开始时显示banner（非RESOLVING→PLAYER_TURN时）
- PRESET_CENTER居中+grow双向+无position偏移
- 已删除"战斗开始"和"蓄力中"多余提示

---

## 6. 数据定义

### 6.1 卡牌

| ID | 类型 | 目标 | 效果 | 稀有度 |
|----|------|------|------|--------|
| 斩击 | attack | self | temp_damage_boost +5 | basic |
| 格挡 | skill | self | block 5 | basic |
| 蓄力 | skill | self | skip_attack + store_damage | uncommon |
| 蓄势 | skill | self | skip_attack + draw 2 | uncommon |
| 破甲 | attack | self | ignore_block + temp_damage_boost +3 | uncommon |
| 招架 | skill | self | counter_stance + block 5 | uncommon |
| 致弱 | skill | single_enemy | apply_buff vulnerable 2层 | common |

初始卡组(decks.json)：斩击×3, 格挡×3, 蓄力×2, 蓄势×2

### 6.2 敌人

| ID | HP | AI | 行为 | 描述 |
|----|-----|----|------ |------|
| test_dummy | 10 | basic | 攻击1 | 测试木偶 |
| 石甲卫兵 | 30 | basic | 攻击3/防御5/重击5 | 攻守兼备 |
| 暗影刺客 | 15 | basic | 暗杀8/下毒weak/刺击6 | 高攻低血 |
| 腐化法师 | 22 | basic | 蓄能strength/衰弱vulnerable/法击4 | 自我强化+削弱 |

### 6.3 BuffData字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | buff标识 |
| name | String | 显示名 |
| buff_type | String | buff/debuff |
| duration | int | -1=永久，>0=回合数 |
| stacks | int | 层数 |
| max_stacks | int | 上限(默认99) |
| trigger_timing | String | passive/on_turn_end/on_turn_start/on_turn_end_remove |
| modifiers | Dictionary | 由MODIFIER_FORMULAS计算 |
| tick_effect | Dictionary | 定时触发效果 |
| icon_path | String | 图标路径 |
| stack_decay | Dictionary | 衰减规则(空=永续) |

---

## 7. 已完成功能清单

- [x] 战斗系统18个bug修复
- [x] 效果→buff统一重构（删除旧属性/信号）
- [x] 属性全部统一为buff（PlayerManager无裸属性）
- [x] 6张新卡牌JSON + 3个新敌人JSON
- [x] 卡牌交互系统重构（拖拽打出+指向性箭头+选择模式）
- [x] 弃牌流程重构（选择模式+中央动画+rotation处理）
- [x] 伤害计算链修复（双算bug+stored_power渗入+get_flat_add双乘stacks）
- [x] buff栏tooltip悬停弹窗
- [x] 敌人buff栏可见（offset布局+tscn节点位置调整+EnemyUI高度210）
- [x] 敌人意图伤害考虑玩家vulnerable
- [x] 玩家buff变化时刷新所有敌人意图
- [x] apply_buff兼容buff_type字段
- [x] buff衰减机制扩展（stack_decay字段+decay_on_event方法）
- [x] 无层数buff不显示层数（NO_STACK_BUFFS）
- [x] skip_attack命名统一为"蓄势"
- [x] 弃牌选择栏移到屏幕顶部
- [x] 选择模式卡牌动画修复（rotation归零+original_rotation保存+不调_cancel_press）
- [x] 卡牌布局动态自适应
- [x] 回合提示位置严格居中
- [x] "你的回合"只在非RESOLVING进入时显示
- [x] 删除"战斗开始"和"蓄力中"多余提示
- [x] 选择模式hover动画禁止
- [x] 地图系统：动态节点方案（放弃预创建按钮，动态创建/删除）
- [x] 地图系统：_do_move_animation动画（旧节点滑出淡出+新节点反向滑入淡入）
- [x] 地图系统：初始位置bug修复（_get_center_pos回退值）
- [x] 地图系统：旧节点重叠bug修复（先收集引用，await后统一queue_free）
- [x] 地图系统：淡入淡出效果（set_parallel让位移+透明度同时执行）
- [x] 地图系统：地图总览功能（弹出菜单、两级视图、BFS布局、画布渲染、自动适配）

---

## 8. 当前Bug与待修复

### 8.1 严重Bug

#### BUG-1: 蓄力后斩击伤害未实时计算
- **描述**：先打出蓄力卡，再打出斩击卡时，伤害显示未能实时反映临时力量增加
- **根因分析**：打出蓄力后stored_power buff已创建，但打出斩击(temp_damage_boost)时，UI上预计伤害值未实时更新。需要确认_update_player_ui()在每张卡打出后是否正确刷新了所有伤害相关信息
- **相关文件**：effect_resolver.gd:_resolve_store_damage, battle_controller.gd:play_card→_update_player_ui, ui_controller.gd:update_player_stats_info

#### BUG-2: 多次打出蓄力造成重复加伤害
- **描述**：多次打出蓄力卡会重复将当前力量累加到stored_power，导致伤害膨胀
- **根因分析**：_resolve_store_damage中，每次调用都取current=get_strength()+temp_strength，然后add_stacks(current)到stored_power。如果第二次蓄力时temp_strength已移除但strength不变，则会再次把strength加到stored_power上
- **示例**：strength=5，第一次蓄力→stored_power=5；第二次蓄力→stored_power=5+5=10（但实际应只蓄力一次的伤害）
- **设计需确认**：蓄力卡是否应该允许一回合多次打出？如果允许，第二次应该蓄什么？
- **相关文件**：effect_resolver.gd:_resolve_store_damage

### 8.2 其他严重问题

- **选择模式取消选中仍需实测**：确认不调_cancel_press后，点击取消选中流程是否正确完整
- **buff衰减机制未配置**：stack_decay框架已有，但所有buff都是空字典（如weak应每回合掉1层duration）
- **卡牌升级无触发途径**：upgrade JSON已定义但游戏内无法升级
- **缺少洗牌卡**：手动洗牌设计但无卡牌触发

### 8.3 中等问题

- **buff栏与属性面板信息重复**：蓄力/预计攻击在两处显示
- **info_panel位置验证**：anchor布局+call_deferred定位到player_area右侧，需实测
- **AI只有basic模式**：敌人行为可预测，缺少智能AI
- **更多敌人/Boss设计**：当前只有4个敌人
- **Game Over界面**：未测试
- **敌人buff栏stack_decay配置**：腐化法师等敌人buff应配置衰减规则

### 8.4 地图总览Bug

#### BUG-3: 地图总览拖动效果不可用
- **描述**：进入区域详情视图后，鼠标左键拖动无法平移地图
- **根因**：Godot 4 的 gui_input 事件不会从child冒泡到parent。之前将 gui_input 连接到 ScrollContainer，但鼠标事件被 canvas（ScrollContainer的child）拦截
- **当前尝试**（2026-05-31）：将 gui_input 移到 canvas 自身，canvas 设 MOUSE_FILTER_STOP。待验证
- **优先级**：高（用户明确要求先修复拖动）

#### BUG-4: 地图总览鼠标滚轮缩放不可用
- **描述**：鼠标滚轮缩放无效果
- **原因**：与BUG-3相同（事件传递问题）
- **优先级**：低（用户要求暂时搁置）

#### BUG-5: _compute_fit_zoom 自动缩放公式可能不精确
- **描述**：`zoom_w = (avail_w - 40) / (grid_w * 200)` 中的 -40 和 *200 与实际画布尺寸公式不完全对应
- **优先级**：低

---

## 9. 待开发功能

### 9.1 高优先级
- [ ] 修复BUG-1: 蓄力后伤害实时计算
- [ ] 修复BUG-2: 多次蓄力重复加伤害
- [ ] buff stack_decay逐个配置（weak每回合duration-1等）
- [ ] 洗牌卡牌设计与实现
- [ ] 卡牌升级触发机制（reward界面或地图交互物）
- [ ] 地图连线绘制功能（_draw_lines）
- [ ] 地图移动动画实测与微调（时长/缓动曲线）

### 9.2 中优先级
- [ ] 敌人AI模式扩展
- [ ] 更多敌人/Boss
- [ ] 卡牌打出后动画+音效
- [ ] info_panel位置实测

### 9.3 低优先级
- [ ] buff栏与属性面板信息去重
- [ ] Game Over界面完善
- [ ] 敌人buff衰减配置

---

## 10. 技术备忘

### 10.1 关键信号连接

```
battle_controller._connect_ui_signals():
  ui_controller.card_clicked → _on_ui_card_clicked
  ui_controller.card_released → _on_ui_card_released
  ui_controller.card_cancelled → _on_ui_card_cancelled
  ui_controller.card_dropped → _on_ui_card_dropped
  ui_controller.card_played → _on_ui_card_played
  ui_controller.enemy_selected → _on_ui_enemy_selected
  ui_controller.end_turn_clicked → _on_ui_end_turn_clicked

battle_controller._connect_signals():
  state_machine.state_enter → _on_state_enter
  turn_manager.player_turn_start → _on_player_turn_start
  card_system.card_played → _on_card_played
  card_system.hand_changed → _on_hand_changed
  player_manager.hp_changed → _on_player_hp_changed
  player_manager.block_changed → _on_player_block_changed
  player_manager.player_died → _on_player_died
  player_manager.counter_damage → _on_counter_damage
```

### 10.2 _update_player_ui()调用点

每次卡牌打出后(battle_controller.play_card)、玩家HP/护甲变化时、初始UI时都会调用：
```gdscript
func _update_player_ui():
    ui_controller.update_player_display(hp, max_hp, block)
    ui_controller.update_player_stats_info(player_manager)
    ui_controller.update_player_buff_bar(player_manager)
    ui_controller.update_all_enemy_intents()
```

### 10.3 EnemyUI场景布局

- custom_minimum_size = 150×210
- BlockLabel y=118
- HPBar y=162
- IntentLabel y=180

### 10.4 BattleScene布局

- HandArea: offset_left=192, anchor_right=1
- HandArea宽度 = viewport_width - 192 - 50

---

## 11. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-05-24 | 初始创建：整理全部项目状态、架构、数据、bug清单 |
| 2026-05-24 | 新增4.8地图系统章节：设计决策与失败历史、动态节点方案、动画流程、3个bug修复；已完成清单+6项地图功能；待开发+2项地图功能（连线绘制、动画实测） |
