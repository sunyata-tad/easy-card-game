# 卡牌游戏项目状态文档

> 最后更新：2026-08-12（交互反馈三色飘字 + 三段式打牌；初始卡组重做）
> 项目路径：`D:/游戏开发/项目文件/card`
> 引擎：Godot 4.7（Forward Plus）
> 语言：GDScript（数据驱动，JSON 配置）
> 命名约定：snake_case

---

## 近期重大变更（2026-08-12）

- **自动攻击移除** → 主动**弃牌攻击**（回合中弃 1 张手牌 → get_strength() 走完整攻击链，一回合一次）
- **蓄力/ skip_attack 删除**：`store_damage` / `pending_stored_damage` / 蓄力·蓄势 卡移除
- **遗物系统新增**：`relic_data.gd` / `relic_database.gd` / `relic_manager.gd` / `data/relics.json`；无尽 Boss 战后**遗物三选一**（`RelicRewardScreen`）；终末轮回 + 占位头环
- **数值**：力量 5 开局、玩家 HP 50
- 战斗按钮"普通攻击"；无法攻击提示"你已经攻击过了。"
- 效果文本 ↔ 代码一致性规范（条件式）见 coding-conventions §6
- **交互反馈（视觉）**：`show_damage_number` 三色区分（伤害红/治疗绿/护甲蓝）；卡牌打出改为三段式（`fly_to_center`/`fly_to_discard` + `detach_card_node` 防打断）；详见 GAME_DESIGN 第 10 章
- **初始卡组重做**：裂击×3/破绽×2/压制×2/铁壁×3；新增 `damage_if_debuff` 条件伤害效果；数值基准（1卡=2抽=1定向检索=5伤/5防）
- **卡牌 UI 视觉**：稀有度边框+光晕 + 底部稀有度色带；取消类型颜色区分（类型仅文字标注）；稀有度四档（无 basic）
- **弃牌攻击简化**：选中即弃（无确认按钮）

---

## 1. 项目概述

回合制卡牌战斗 + 文字地图探索。玩家通过卡牌操控属性和牌堆，每回合自动攻击（力量为基础伤害），战斗间有地图探索、角色成长、存档系统。当前主线为**无尽模式**（营地 + 向北逐层推进），另有测试地图。

---

## 2. 核心设计理念

### 2.1 卡牌设计
- **负面效果可重合**，正面效果各自独立
- 卡牌升级：upgrade JSON 已定义、`GameData.upgrade_card_at_index()` 已实现，但**游戏内无触发途径**
- 卡牌效果采用**字典注册模式**：`effect_resolver.register_effect_handler("效果名", 处理函数)` 注册，新增效果无需改分发逻辑

### 2.2 伤害模型（当前实际）
- **弃牌攻击**：玩家回合中主动弃 1 张手牌 → 用 get_strength() 走完整攻击链结算（一回合一次）
- **裸属性 + buff 修正并存**：
  - `PlayerManager.base_strength / base_dexterity`（裸属性）
  - `get_strength() = base_strength + strength buff.stacks`
  - 临时攻击力通过 `calc_attack_base` 钩子（`temp_atk_%d`）注入，`clear_temp_hooks()` 清理

### 2.3 抽牌机制
- **游戏王模式**：开局抽 5，每回合抽 1
- 不自动弃手牌，手牌 > 10 时玩家选择弃牌
- 弃牌上限 = hand.size() - max_hand_size
- **不自动洗牌**（需卡牌效果触发 `manual_shuffle_discard_to_draw`）

### 2.4 弃牌流程
- 点击结束回合 → 弃牌检查 → 弃牌选择模式（卡牌选择 UI）→ 确认 → 敌人回合结算

### 2.5 卡牌交互
- **非指向性卡**：拖出手牌区打出
- **指向性卡**（single_enemy/single_ally）：拖拽移到屏幕中央 + 箭头选目标；也可短按进入目标模式
- **选择模式**（如弃牌）：顶部选择栏，点击标记选中、确认/跳过

### 2.6 效果与属性体系
- **持续性效果统一为 buff**，由 `BuffManager` 管理，通过 `HookChain` 注入伤害计算
- **持久属性为裸属性**（base_strength/base_dexterity），与 buff 修正叠加
- **临时一次性效果**（temp_damage_boost）用钩子 + 状态字段，不再伪装成 buff

### 2.7 buff 衰减
- `stack_decay` 字段可自定义衰减规则，`decay_on_event(event)` 通用触发
- 支持事件：on_turn_end（掉 N 层）、on_turn_end_pct（百分比掉层）等
- ⚠️ **当前多数 buff 的 stack_decay 为空字典（永续不衰减），留待逐个配置**

### 2.8 无层数 buff
- NO_STACK_BUFFS = ["ignore_block", "counter_stance"]
- buff 栏只显示符号不显示数字，stacks 固定为 1

---

## 3. 架构与文件结构

### 3.1 目录结构（2026-08-05，ai/ 空目录已删除）

```
card/
├── scenes/                    # Godot 场景（.tscn）
│   ├── main.tscn / start.tscn # 主入口 / 主菜单
│   ├── BattleScene.tscn / Card.tscn / EnemyUI.tscn
│   ├── MapScreen.tscn / RewardScreen.tscn / GameOverScreen.tscn
│   └── CharacterSelectScreen.tscn / CharacterCreationScreen.tscn
├── scripts/
│   ├── battle/                # 战斗系统
│   │   ├── battle_controller.gd   # 战斗总控
│   │   ├── effect_resolver.gd     # 卡牌效果解析（字典注册模式）
│   │   ├── ui_controller.gd       # 战斗 UI 控制
│   │   ├── state_machine.gd       # 状态机
│   │   └── turn_manager.gd        # 回合管理
│   ├── systems/               # 核心系统
│   │   ├── player_manager.gd      # 玩家战斗单位（裸属性 + hook）
│   │   ├── enemy_unit.gd          # 敌人战斗单位
│   │   ├── card_system.gd         # 抽/弃/洗/消耗牌逻辑
│   │   └── enemy_system.gd        # 敌人群体管理
│   ├── effects/               # 效果系统
│   │   ├── buff_manager.gd        # Buff 生命周期
│   │   ├── buff_data.gd           # Buff 数据模型
│   │   └── hook_chain.gd          # 钩子链（责任链）
│   ├── ui/                    # UI 组件
│   │   ├── card_ui.gd / enemy_ui.gd / player_ui.gd
│   │   ├── hand_layout_presets.gd / drag_arrow.gd / target_marker.gd
│   ├── battle.gd              # 战斗场景入口（接收敌人、经验结算、退出保存）
│   ├── game_manager.gd        # 全局场景管理（Autoload）
│   ├── game_data.gd           # 全局数据（Autoload）
│   ├── save_manager.gd        # 存档管理（Autoload）
│   ├── card_pool_manager.gd   # 永久卡池（Autoload）
│   ├── character_manager.gd   # 角色管理（Autoload）
│   ├── card_data.gd / card_database.gd
│   ├── enemy_data.gd / enemy_database.gd
│   ├── map_controller.gd / map_screen.gd / map_database.gd / map_state.gd
│   ├── reward_screen.gd / game_over_screen.gd / start.gd
│   ├── character_data.gd / character_select_screen.gd / character_creation_screen.gd
└── data/                      # JSON 数据
    ├── cards/                 # 卡牌定义（含 _模板_卡牌名.json）
    ├── enemies/               # 敌人定义
    ├── maps/                  # 地图（test_map.json）
    ├── decks.json / buffs.json / tags.json
```

### 3.2 Autoload 注册（project.godot）

| Autoload | 脚本 | 职责 |
|----------|------|------|
| GameManager | game_manager.gd | 场景切换、流程控制 |
| GameData | game_data.gd | 当前 run 状态（血量/属性/牌组/金币/经验） |
| SaveManager | save_manager.gd | 存档（user://savegame.json） |
| CharacterManager | character_manager.gd | 角色持久化（user://characters.json） |
| CardPoolManager | card_pool_manager.gd | 永久卡池（user://card_pool.json） |

### 3.3 场景流程与模式

```
主菜单(start)
  ├─ 新游戏 → 清存档 + 初始化(GameData) + 解锁初始卡池 → 无尽地图(营地)
  ├─ 继续游戏 → apply_game_data → 按存档 progress 跳转（无尽地图/战斗后地图）
  └─ 测试按钮 → 测试地图（3层：营地/普通战斗/精英战斗）
无尽地图(MapScreen) → 战斗(BattleScene) → 胜利(经验/标记清层) → 返回无尽地图（或 Reward）
                              └─ 失败 → 游戏结束(GameOverScreen)
```

GameManager 场景枚举：MAIN_MENU, CHARACTER_SELECT, CHARACTER_CREATION, MAP, BATTLE, REWARD, GAME_OVER

---

## 4. 核心系统详解

### 4.1 状态机（StateMachine）

状态枚举：INIT, DRAW_PHASE, PLAYER_TURN, RESOLVING, ENEMY_TURN, TURN_END, VICTORY, DEFEAT

合法转换（非法转换被 push_error 拒绝）：
- INIT → DRAW_PHASE
- DRAW_PHASE → PLAYER_TURN, VICTORY, DEFEAT
- PLAYER_TURN → RESOLVING, ENEMY_TURN, VICTORY, DEFEAT
- RESOLVING → PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT
- ENEMY_TURN → TURN_END, VICTORY, DEFEAT
- TURN_END → DRAW_PHASE, VICTORY, DEFEAT
- VICTORY / DEFEAT → 终态

关键字段/方法：`previous_state`（控制回合提示显示）、`is_player_turn()`、`is_enemy_turn()`、`is_resolving()`、`is_battle_active()`
信号：state_changed / state_enter / state_exit
战斗结束可被 `check_battle_end` 钩子拦截修改（自定义结束条件）

### 4.2 战斗流程（BattleController）

```
setup_battle() → start_battle()
  → INIT → DRAW_PHASE(抽牌,决定意图) → PLAYER_TURN
  → 玩家操作(打出卡牌→RESOLVING→PLAYER_TURN 循环；可弃牌攻击→选目标→攻击)
  → 结束回合 → ENEMY_TURN → TURN_END
  → _process_turn_end_effects():
      1. tick_buffs_on_turn_end（毒/再生等，玩家+敌人）
      2. _execute_player_auto_block（敏捷自动护甲）
      3. _execute_enemy_attacks（逐个执行敌人行动）
      4. decrease_durations + remove_at_turn_end（玩家+敌人）
  → DRAW_PHASE(下回合)
```

关键细节：
- setup_battle 从 GameData 读取 `player_max_hp/player_current_hp/player_strength/player_dexterity` 初始化 PlayerManager
- sync_player_stats_to_gamedata 将 base_strength/base_dexterity 写回 GameData
- 敏捷护甲：TURN_END 阶段 `_execute_player_auto_block` 获取（base_dexterity 自动护甲保留）
- 弃牌攻击：玩家主动触发（弃 1 牌 → 攻击），DRAW_PHASE 不注册蓄力钩子（蓄力已删）

### 4.3 伤害计算链条（必须遵守，防双算）

**攻击流程（PlayerManager 攻击，effect_resolver._resolve_damage / battle_controller._perform_attack 共用）：**
```
hc.trigger("on_attack_start", 0, ctx)          # 可设 ignore_block 标记
base = hc.trigger("calc_attack_base", base_strength, ctx)    # 临时力量钩子(temp_atk)在此
base = int(hc.trigger("calc_attack_mult", int(base), ctx))
add = hc.trigger("calc_attack_damage", 0, ctx)               # 额外伤害加算阶段
raw = int(base) + int(add)
final_dmg = hc.trigger("calc_attack_final", raw, ctx)        # weak ×0.75
hc.trigger("on_attack_hit", final_dmg, {"hit_index": 0})
target.take_damage(final_dmg, ctx.get("ignore_block", false))
hc.trigger("on_attack_end", 0, ctx)
```

**take_damage 内部（玩家/敌人对称）：**
```
actual = hook_chain.trigger("on_damage_taken", amount, {...})   # vulnerable ×1.5
格挡抵消（除非 ignore_target_block）
扣血 → hp_changed
if hp <= 0: hook_chain.trigger("before_death", ...)             # 可阻止死亡（保 1 血）
```

**关键规则：**
- vulnerable 只在 take_damage 内部的 on_damage_taken 处理（单一责任方，防双算）
- weak 在 calc_attack_final 处理；ignore_block 通过 ctx 传给 take_damage 第二参

### 4.4 弃牌攻击（主动攻击，替代原自动攻击）

- 流程：玩家回合点击"普通攻击" → 进入"选一张牌弃掉"（card select 模式）→ 弃牌立即结算 → 实时检测存活敌人 → 选目标 → `_perform_attack` 走完整攻击链（伤害 = get_strength()）
- 一回合一次（`discard_attack_available`，回合开始重置）；弃牌代价已付即消耗名额（防倾泻手牌）
- 实时结算：选目标前实时检测存活敌人；目标已死自动改选存活；无存活目标则攻击作废
- 无法攻击时提示"你已经攻击过了。"
- 旧蓄力机制（store_damage / pending_stored_damage）已删除（2026-08-12）

### 4.5 Buff 系统

#### BuffManager
- buffs 数组 + hook_chain；`DURATION_STACK_BUFFS = ["weak","vulnerable"]`（叠加延长 duration）
- `get_flat_add(stat)`：累加所有 xxx_add；`get_mult(stat)`：累乘所有 xxx_mult
- `apply_buff()`：已存在→add_stacks+重建钩子；不存在→duplicate+注册钩子
- `decrease_durations()`：duration 递减 + stack_decay 衰减 + 过期移除
- `decay_on_event(event)`：通用事件触发衰减；`remove_at_turn_end()`：回合末移除
- ⚠️ **已移除**：MODIFIER_FORMULAS 常量、recalculate_modifiers()、temp_strength 分支（2026-08-05 剪枝）
- buff 的 modifiers 直接在 BuffData 中配置（如 weak 带 `modifiers:{"damage_mult":0.75}`）

#### Buff 的 Hook 注册（_register_buff_hook）
| buff_id | hook 阶段 | 效果 |
|---------|----------|------|
| strength | calc_attack_damage | +stacks 伤害 |
| dexterity | calc_attack_block | +stacks 格挡 |
| weak | calc_attack_final | 伤害 ×0.75 |
| vulnerable | on_damage_taken | 受伤 ×1.5 |
| ignore_block | on_attack_start | 标记无视格挡 |
| counter_stance | on_attack_hit | 记录反击伤害 |

⚠️ 层数变化时必须重建 hook 回调（闭包捕获旧层数）：`_update_strength_hook`

#### Buff 创建（effect_resolver._create_buff_from_id）
支持：strength, dexterity, weak, vulnerable, poison, regen（weak/vulnerable duration=2；poison on_turn_end 伤害；regen on_turn_start 治疗）

### 4.6 卡牌系统

#### 效果分发（effect_resolver，字典注册模式）
- 处理器注册表 `_handlers: {effect_type: Callable}`，`register_effect_handler()` 注册
- 处理器签名：`func(effect: Dictionary, source, target) -> Dictionary`
- 支持 `base_stat` 字段：效果值基于玩家属性（strength/dexterity × multiplier）

#### 效果类型
damage / block / heal / damage_boost(永久改 base_strength) / temp_damage_boost(注册 calc_attack_base 钩子) / ignore_block(破甲) / counter_stance(招架) / draw / apply_buff·apply_debuff / add_card_to_hand / search_draw·search_discard / search_draw_by_tag·search_discard_by_tag / exhaust_random·discard_random / shuffle_discard_to_draw
（蓄力 store_damage、skip_attack 已删除 2026-08-12）

#### CardSystem
- 四牌堆：draw_pile / hand / discard_pile / exhaust_pile（消耗堆）
- max_hand_size = 10；draw_cards() 空抽牌堆不自动洗牌，emit deck_exhausted
- 支持搜索（按 id/标签）、消耗、弃牌、add_to_draw_pile(to_top)、add_to_hand
- 信号：card_drawn / card_played / card_discarded / card_exhausted / hand_changed / deck_count_changed / card_added_to_hand / deck_exhausted

### 4.7 地图系统（MapController + MapScreen）

#### 架构
`map_screen.gd`（视图，纯代码构建 UI）↔ `map_controller.gd`（逻辑）↔ `map_state.gd`（状态）↔ `map_database.gd`（JSON 加载）

#### MapController
- `Direction` 枚举（8 方向）+ DIRECTION_NAMES / DIRECTION_VECTORS 映射
- `load_map(map_id)`：`"test"` → 测试地图；endless_mode → 无尽模式；否则加载 JSON 地图
- **无尽模式**：营地（layer_0，休息/卡组桌）+ 向北动态生成楼层；`EndlessLayerType` = BOSS(每10层)/NORMAL/CHEST/ELITE/EVENT(未实装)
- `_generate_layer_node(layer)` 到达时生成；`max_layer_reached` 记录最深层
- `can_move_to()`：北进需清空当前层战斗敌人；南行可回营地
- `remove_dead_enemies(alive_ids)` / `mark_layer_cleared(layer)`：战斗返回后清理
- 信号：location_changed / interactable_selected / interactable_deselected / battle_requested / log_message

#### MapScreen（纯代码构建 UI）
- header：状态 / 地点名 / 设置 / 地图（总览）按钮
- 地图区：node_container 动态节点（keep/remove/add 分类动画）
- 交互物区：battle_trigger / info / heal / container / portal / deck_view / test_exp
- 探索日志（最多 50 条）；状态面板（等级/经验/属性点加点/卡组）；卡组工作台（从卡池添加/移除，单卡上限 3）；设置弹窗（保存）
- 群战 `_start_group_battle(enemy_ids, layer)`：无尽模式带 layer 存档

#### 地图总览（_on_map_overview_pressed）
- 两级视图：世界视图（区域列表）→ 区域视图（canvas 节点图，未访问 ???
）
- 拖动/缩放**代码已实现**（canvas 绑 gui_input + MOUSE_FILTER_STOP），但**可用性未验证**（BUG-3/4）
- `_compute_fit_zoom`：启发式自动缩放（BUG-5）；`_compute_overview_layout`：BFS 布局

#### MapState
字段：current_map_id, current_location_id, visited_locations, interactable_states, enabled_connections, interaction_log
方法：initialize, move_to, get/set_interactable_state, enable_connection, add_log, get_recent_logs, serialize/deserialize

### 4.8 存档系统

#### SaveManager（user://savegame.json，version 2）
- `GameProgress` 枚举：NONE / IN_BATTLE / IN_MAP / GAME_OVER
- save_game(progress, additional) / save_map_state() / save_before_battle(enemy_id, map_id, endless_layer, is_test_mode) / save_game_over()
- apply_game_data()：恢复 GameData（含牌组升级/标签/treated_as）
- 牌组序列化：每张卡单独保存 id/name/is_upgraded/effects/tags/treated_as

#### CardPoolManager（user://card_pool.json）
- `{version, unlocked_card_ids}`；initialize_with_starter_cards() 首次从 decks.json 初始化
- 永久卡池跨角色继承，不随死亡消失

#### CharacterManager（user://characters.json）
- 角色创建/删除/选择/序列化；⚠️ **当前主流程未接入角色创建**（新游戏直接进无尽地图）

---

## 5. UI 系统

### 5.1 UIController（战斗）
- 手牌布局（HandLayoutPresets.get_card_position）、拖拽箭头（DragArrow）、目标标记（TargetMarker）
- 攻击目标按钮（手动选目标模式）、卡牌选择模式（回调机制）、伤害数字、buff 栏 + tooltip
- show_turn_banner / show_state_message 提示
- 玩家属性面板：弃牌攻击:%d（get_expected_attack_damage，弃牌攻击伤害预览）

### 5.2 CardUI
- 状态：is_pressed / is_dragging / is_hovered / is_select_mode / is_awaiting_target
- original_position / original_scale / original_rotation（动画还原）
- 信号：card_clicked / card_hovered / card_unhovered / drag_started / drag_updated / drag_ended / card_released / card_cancelled / target_mode_started / target_mode_ended / card_play_requested
- 交互：左键按下→拖拽(>10px)→拖放/打出/点击；右键取消；短按指向卡进入目标模式

### 5.3 EnemyUI / PlayerUI
- 意图显示（attack 考虑玩家 vulnerable；defend/buff/debuff）；buff 栏 + tooltip
- 敌人 buff 变化时刷新意图

### 5.4 手牌布局（HandLayoutPresets）
- CARD_WIDTH = 140.0；IDEAL_SPACINGS / ROTATION_CURVE（max_rotation/curve_factor）
- 动态 spacing = min(ideal, max_spacing)；弧形布局

---

## 6. 数据定义

### 6.1 卡牌（data/cards/，14 张可玩卡 + 1 模板）

初始卡组（decks.json，2026-08-12 重做）：

| ID | 类型 | 目标 | 效果 | 稀有度 |
|----|------|------|------|--------|
| 裂击 | attack | single_enemy | damage 5 | common |
| 破绽 | skill | single_enemy | apply_debuff vulnerable 2层 | common |
| 压制 | attack | single_enemy | damage_if_debuff(vulnerable) 4→8 | common |
| 铁壁 | skill | self | block 5 | common |

初始卡组 = 裂击×3 / 破绽×2 / 压制×2 / 铁壁×3

其余卡（进阶/解锁，不在开局）：致弱 / 批命 / 生死轮转 / 热寂 / 契约 / 逆流
历史遗留（已移出初始卡组，JSON 保留待清理）：斩击 / 格挡 / 破甲 / 招架

卡牌 JSON 模板：`_模板_卡牌名.json`（含 effect_type / buff_id / base_stat 说明，可扩展架构参考）

### 6.2 敌人（data/enemies/，5 个）

| ID | HP | AI | 行为 | 描述 |
|----|-----|----|------|------|
| test_dummy | 100 | basic | 攻击1 | 测试木偶 |
| test_debuffer | 10 | basic | 虚弱 weak 1层/攻击1 | 测试虚弱训练师 |
| 石甲卫兵 | 30 | basic | 攻击3/防御5/重击5 | 攻守兼备 |
| 暗影刺客 | 15 | basic | 暗杀8/下毒weak/刺击6 | 高攻低血 |
| 腐化法师 | 22 | basic | 蓄能strength/衰弱vulnerable/法击4 | 自我强化+削弱 |

action type：attack / defend / buff / debuff，均带 intent_text / intent_icon

### 6.3 Buff（data/buffs.json）

可用 buff：strength, dexterity, weak, vulnerable, poison, regen, ignore_block, counter_stance
（skip_attack 已删 2026-08-12）
（2026-08-05 剪枝：temp_strength / stored_power 已从定义移除）

字段：id / name / symbol / color / description / buff_type / modifier_formula（已废弃，保留字段）

### 6.4 标签（data/tags.json）
- 分类：type / keyword / archetype / rarity
- 标签属性：Exhaust / Retain / Innate / Ethereal / Unplayable 等（priority / conflicts）
- 卡牌支持：has_tag（含 treated_as）/ has_any_tag / has_all_tags / get_all_tags

### 6.5 地图（data/maps/test_map.json）
- regions（区域归属）/ locations（8 方向 connections + interactables）/ interactables（state 状态机）
- interactable 类型：battle_trigger / info / heal / container / portal / deck_view

### 6.6 存档格式
- user://savegame.json：{version:2, progress, game_data, map_state, enemy_id, map_id, additional}
- user://card_pool.json：{version:1, unlocked_card_ids}
- user://characters.json：角色数组（CharacterData.serialize）

---

## 7. 已完成功能清单

- [x] 战斗系统：状态机 + HookChain 责任链 + 效果字典注册模式
- [x] 伤害模型重构：裸属性 base_strength/base_dexterity + buff 修正 + 完整钩子链
- [x] ~~蓄力机制重构：pending_stored_damage + _pending_stored 钩子~~（2026-08-12 已删除，改用弃牌攻击）
- [x] 效果分发重构：match → register_effect_handler 注册表（可扩展）
- [x] 无尽模式：营地 + 动态楼层（普通/宝箱/精英/Boss/事件）+ 战斗前后存档恢复
- [x] 测试地图：营地/普通战斗/精英战斗 3 层
- [x] 卡牌系统：拖拽/指向箭头/选择模式/标签检索/消耗堆
- [x] 地图系统：动态节点动画、地图总览弹窗（拖动/缩放代码已实现，待验证）
- [x] 卡组工作台：从永久卡池添加/移除卡牌（单卡上限 3）
- [x] 存档系统：GameProgress、战斗前存档、战斗后存活敌人恢复
- [x] 角色系统：CharacterData/CharacterManager 持久化（未接入主流程）
- [x] 2026-08-05 死代码剪枝：删除 166 行完全失效代码（详见 git diff）

---

## 8. 已知问题与待办

### 8.1 战斗 Bug（蓄力相关，均已随删除关闭）

#### BUG-1: 蓄力后斩击伤害未实时计算（✅ 关闭 2026-08-12：蓄力机制已删除）
- 原由 `store_damage` / `pending_stored_damage` 引起，机制已删

#### BUG-2: 多次打出蓄力重复加伤害（✅ 关闭 2026-08-12：蓄力机制已删除）
- 原由 `_resolve_store_damage` 的 `pending_stored_damage += raw` 引起，机制已删

### 8.2 地图总览 Bug

#### BUG-3: 地图总览拖动（⚠️ 代码已实现，可用性未验证）
- 代码：canvas 绑 gui_input（MOUSE_FILTER_STOP，子控件 IGNORE），MOUSE_BUTTON_LEFT + InputEventMouseMotion 更新 canvas.position
- 潜在问题：拖动 delta 乘 scale_factor，缩放≠1 时幅度异常
- **设计方向**：地图考虑其他优化方式（可能移除总览弹窗）

#### BUG-4: 地图总览滚轮缩放（⚠️ 代码已实现，可用性未验证）
- 与 BUG-3 同源

#### BUG-5: _compute_fit_zoom 自动缩放公式为启发式
- zoom_w=(avail_w-40)/(grid_w*200)、zoom_h=(avail_h-40)/(grid_h*100)，与实际画布公式不完全对应

### 8.3 其他问题
- 选择模式取消选中流程需实测
- buff stack_decay 大部分未配置（weak 每回合 duration-1 等）
- 卡牌升级无触发途径（upgrade JSON 有定义，游戏内无入口）
- 敌人 AI 仅 basic（decide_next_intent 随机抽取 actions）
- 敌人/Boss 不足（无尽 Boss 层复用普通敌人）
- 无尽模式 EVENT 事件楼层未实装
- 角色系统未接入主流程（新游戏直接进无尽地图）

### 8.4 待开发功能
- 高优先级：卡牌重新设计（规则突破 + 减益利用）、卡牌升级触发、buff stack_decay 配置、EVENT 事件实装
- 中优先级：敌人 AI 扩展、更多敌人/Boss、卡牌动画+音效、地图优化（替代总览方案）
- 低优先级：buff 栏与属性面板去重、Game Over 完善、敌人 buff 衰减配置

### 8.5 规划方向（用户 2026-08-05 确认，2026-08-12 更新）
- ~~**蓄力**~~：已删除（2026-08-12）
- **地图拖动 bug 未成功**：地图考虑其他优化方式
- **卡牌重新设计**（规则突破 + 减益利用；数值基准 1 卡≈5）
- 死代码剪枝已完成（166 行）

---

## 9. 技术备忘

### 9.1 战斗关键信号

```
battle_controller._connect_ui_signals():
  ui_controller.card_clicked / card_released / card_cancelled
  ui_controller.card_dropped / card_played / enemy_selected / end_turn_clicked

battle_controller._connect_signals():
  state_machine.state_enter → _on_state_enter
  turn_manager.player_turn_start → _on_player_turn_start
  card_system.card_played / hand_changed / deck_count_changed
  enemy_system.enemy_died / enemy_damaged / all_enemies_defeated
  player_manager.hp_changed / block_changed / player_died / counter_damage
```

### 9.2 钩子注册/清理
- 临时攻击钩子：`temp_atk_%d`（calc_attack_base），`clear_temp_hooks()` 清理
- 遗物钩子：`relic_before_death`（before_death）、`relic_damage_redirect`（on_damage_taken），由 RelicManager 注册

### 9.3 战斗胜利结算（battle.gd）
- 无尽层经验：30 + 层×5（Boss 层 +50）→ gain_exp
- 胜利：标记 endless_layer_cleared → 返回无尽地图；**Boss 层（%10==0）先进遗物三选一**；非无尽 → RewardScreen
- 测试模式：不存档，直接返回测试地图

### 9.4 PlayerManager 便捷方法

| 方法 | 实现 |
|------|------|
| get_strength() | base_strength + strength buff.stacks |
| get_dexterity() | base_dexterity + dexterity buff.stacks |
| get_total_damage() | base_strength + int(get_flat_add("damage")) |
| get_total_block() | base_dexterity + int(get_flat_add("block")) |
| get_expected_attack_damage() | 完整钩子链预览（UI 用，弃牌攻击伤害预览） |

---

## 10. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-05-24 | 初始创建（旧架构描述） |
| 2026-08-05 | **全面重写**：反映重构后的伤害模型（裸属性+hook）、蓄力 pending_stored_damage、效果注册表、无尽模式、存档 GameProgress、5 敌人、死代码剪枝；同步已知问题真实状态（BUG-1~5） |
| 2026-08-12 | **交互反馈 + 卡牌重做 + UI**：飘字三色区分；卡牌打出三段式流程；初始卡组重做为裂击/破绽/压制/铁壁；新增 `damage_if_debuff` 条件伤害；卡牌 UI 稀有度边框+光晕+底带、取消类型颜色、弃牌攻击选中即弃 |
