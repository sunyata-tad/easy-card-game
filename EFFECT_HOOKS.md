# 效果调用规范（Effect Hook Spec）

> 更新时间：2026-08-07
> 适用范围：卡牌/敌人效果在战斗中的**调用**与**实现**
> 核心原则：**调用钩子（trigger / register）→ 实现效果（回调内写逻辑）**

本文档是效果钩子系统的**唯一权威规范**。所有效果实现必须遵守本规范；所有钩子名称必须以
[`scripts/effects/hook_registry.gd`](scripts/effects/hook_registry.gd) 为准（单点事实）。

---

## 1. 为什么需要这套规范

此前钩子名（如 `calc_attack_base`）以**魔法字符串**散落在 5 个文件中，存在两个痛点：

1. **拼写无校验**：钩子名拼错只在运行时静默失败，伤害计算静默出错，极难排查。
2. **无统一清单**：想要复用某个钩子，得去 5 个文件里翻找，不知道有哪些钩子、各做什么。

本规范解决方式：

| 痛点 | 方案 |
|------|------|
| 拼写无校验 | `HookChain` 调用时自动校验钩子名，未文档化立即 `push_warning` |
| 无统一清单 | 新建 `HookRegistry`，集中定义常量 + `_HOOK_DOCS` 钩子列表（名字 + 注释） |
| 调用/实现混乱 | 本文档固化"调用钩子 → 实现效果"的标准流程 |

---

## 2. 架构总览

效果系统由三层组成，职责分离：

```
┌────────────────────────────────────────────────────────────┐
│ 第 1 层：效果定义（数据）                                     │
│   卡牌 JSON effect 字典 → CardData.effects                    │
│   例：{ "effect_type": "damage", "value": 8 }                │
└───────────────────────────┬────────────────────────────────┘
                            │ resolve_effect(effect, source, target)
┌───────────────────────────▼────────────────────────────────┐
│ 第 2 层：效果解析（EffectResolver，字典注册模式）             │
│   effect_type → handler 函数（实现具体效果）                  │
│   例：register_effect_handler("damage", func(e,s,t): ...)   │
└───────────────────────────┬────────────────────────────────┘
                            │ 内部调用
┌───────────────────────────▼────────────────────────────────┐
│ 第 3 层：钩子链（HookChain + HookRegistry）                  │
│   trigger(钩子名, value, ctx) → 多个回调按 priority 依次执行  │
│   register(钩子名, 回调, priority, id)                       │
└────────────────────────────────────────────────────────────┘
```

- **第 2 层（EffectResolver）**负责"效果要做什么"（造成伤害 / 抽牌 / 上 buff）。
- **第 3 层（HookChain）**负责"数值如何被修正"（力量 / 虚弱 / 易伤 / 蓄力等插入计算链）。

---

## 3. 调用流程（标准执行链）

### 3.1 卡牌效果执行

```
打出卡牌
  → battle_controller.play_card()
  → effect_resolver.resolve_effects(card.effects, player_manager, target)
      → 对每个 effect 字典调用 resolve_effect()
          → 查 _handlers 注册表分发到具体 handler（实现效果）
      → card_system.play_card()（处理抽牌堆/手牌）
```

### 3.2 伤害计算的钩子链（必须遵守，防双算）

攻击发起方（玩家/敌人对称）：

```
hook_chain.trigger(HOOK_ON_ATTACK_START, 0, ctx)      # 可写 ctx: skip_attack / ignore_block
base = trigger(HOOK_CALC_BASE, base_strength, ctx)    # 临时力量钩子注入点
base = trigger(HOOK_CALC_MULT, base, ctx)             # 倍率
add  = trigger(HOOK_CALC_ADD, 0, ctx)                 # 加算（蓄力注入点）
raw  = base + add
final= trigger(HOOK_CALC_FINAL, raw, ctx)             # 最终倍率（虚弱 ×0.75）
trigger(HOOK_ON_ATTACK_HIT, final, {"hit_index":0})   # 命中（反击注入点）
target.take_damage(final, ctx.get("ignore_block"))
trigger(HOOK_ON_ATTACK_END, 0, ctx)                   # 收尾
```

受击方 `take_damage` 内部：

```
actual = trigger(HOOK_ON_DAMAGE_TAKEN, amount, ctx)   # 易伤 ×1.5 注入点（单一责任方，防双算）
格挡抵消（除非 ignore_block）
扣血 → 信号
if hp <= 0: trigger(HOOK_ON_BEFORE_DEATH, dmg, ctx)   # 可写 ctx.can_die=false 阻止死亡
```

> ⚠️ **防双算规则**：`vulnerable`（易伤）只在受击侧 `HOOK_ON_DAMAGE_TAKEN` 处理；
> `weak`（虚弱）只在攻击侧 `HOOK_CALC_FINAL` 处理。不要在同一效果的多个钩子重复修正。

---

## 4. 钩子列表（名字 + 注释）

> 代码中同样维护了这份清单：`HookRegistry.get_hook_docs()`。**改钩子必须先改注册表。**

### 4.1 攻击链（攻击发起方）

| 常量 | 钩子名 | 传入 value | 注释 | 可用 ctx 标记 |
|------|--------|-----------|------|--------------|
| `HOOK_ON_ATTACK_START` | `on_attack_start` | `0` | 攻击开始；可写 ctx 标记改变本次攻击 | `skip_attack`（跳过攻击）、`ignore_block`（无视格挡） |
| `HOOK_CALC_BASE` | `calc_attack_base` | 基础攻击力 | 基础攻击力计算，返回修正后的攻击力（临时力量钩子注入点） | — |
| `HOOK_CALC_MULT` | `calc_attack_mult` | 当前攻击力 | 攻击力倍率，返回 × 倍率后的值 | — |
| `HOOK_CALC_ADD` | `calc_attack_damage` | `0` | 攻击力加算，额外伤害从此累加（蓄力钩子注入点） | — |
| `HOOK_CALC_FINAL` | `calc_attack_final` | 原始伤害 | 最终伤害倍率，返回最终伤害（虚弱 ×0.75 注入点） | — |
| `HOOK_ON_ATTACK_HIT` | `on_attack_hit` | 最终伤害 | 攻击命中；可写 ctx 记录反击等 | `counter_damage` |
| `HOOK_ON_ATTACK_END` | `on_attack_end` | `0` | 攻击结束，用于收尾/清理 | — |

### 4.2 受击链（防守方）

| 常量 | 钩子名 | 传入 value | 注释 | 可用 ctx 标记 |
|------|--------|-----------|------|--------------|
| `HOOK_CALC_BLOCK` | `calc_attack_block` | 基础格挡 | 格挡值计算，返回修正后的格挡（敏捷钩子注入点） | — |
| `HOOK_ON_DAMAGE_TAKEN` | `on_damage_taken` | 伤害值 | 受到伤害，返回修正后的伤害（易伤 ×1.5 注入点） | `source_type` |
| `HOOK_ON_BEFORE_DEATH` | `before_death` | 致死伤害 | 死亡前判定，写 `ctx.can_die=false` 阻止死亡（保 1 血） | `can_die` |

### 4.3 规则门（全局判定）

| 常量 | 钩子名 | 传入 value | 注释 | 可用 ctx 标记 |
|------|--------|-----------|------|--------------|
| `HOOK_CHECK_DISCARD` | `check_discard` | 需弃牌数 | 弃牌规则门，写 `ctx.block_discard=true` 阻止弃牌（不弃注入点） | `block_discard` |
| `HOOK_CHECK_BATTLE_END` | `check_battle_end` | `0` | 战斗结束判定，可改写结束条件与结果 | `should_end`、`result`、`reason` |

---

## 5. 如何复用旧效果（标准流程）

**复用旧效果 = 调用已有钩子 + 写回调实现效果**，绝不复制粘贴旧的魔法字符串。

### 5.1 复用现有钩子实现新效果

例如：做一张"本回合攻击力额外 +3"的卡（效果实现处）：

```gdscript
# 效果实现处（EffectResolver 的 handler 或某系统回调）
hook_chain.register(
	HookRegistry.HOOK_CALC_BASE,          # 调用钩子：基础攻击力阶段
	func(v, _c): return v + 3,            # 实现效果：回调内写逻辑
	5,                                    # priority：越小越先执行
	"my_temp_atk"                         # 唯一 id：便于之后 unregister 清理
)
```

触发方（攻击流程）已经在 `effect_resolver._resolve_damage` / `battle_controller._perform_attack`
中调用了 `HOOK_CALC_BASE`，**无需改动触发方**——这正是钩子链的解耦价值。

### 5.2 新增一个钩子（必须三步走）

1. **定义常量**：在 `hook_registry.gd` 常量区加一行，如
   `const HOOK_ON_CARD_PLAYED: String = "on_card_played"`
2. **登记文档**：在 `_HOOK_DOCS` 列表补一条 `{name, stage, value, desc, ctx}`，让它在清单里可查
3. **调用与实现**：触发方 `trigger(HookRegistry.HOOK_ON_CARD_PLAYED, v, ctx)`；
   效果方 `register(...)` 注入回调

> 如果只是想给某张卡牌加效果、且不涉及数值计算链，优先在 `EffectResolver` 注册 handler
> （`register_effect_handler`）——那是"效果级"扩展；钩子链是"数值修正级"扩展。

---

## 6. 回调约定

钩子回调统一签名：

```gdscript
func callback(current_value: Variant, context: Dictionary) -> Variant
```

| 约定 | 说明 |
|------|------|
| 返回值 | 传给下一个回调的 `current_value`；不修改就 `return current_value` |
| context | 同一钩子链内共享；用 `ctx.get("标记", 默认值)` 读取，写入时直接赋值 |
| priority | 数值越小越先执行；同一阶段多个效果靠 priority 定序 |
| id | 每次 `register` 给出唯一 id，用于 `unregister(钩子名, id)` 精确清理 |

---

## 7. 新增效果快速参考（决策树）

```
新效果是否要修正"伤害/格挡/受击/弃牌"数值？
├─ 是 → 复用/新增钩子（见第 5 节），在 hook_registry.gd 登记
└─ 否 → 是独立动作（抽牌、上 buff、加卡、洗牌…）？
        ├─ 是 → 在 EffectResolver 用 register_effect_handler 注册 handler
        │         （可组合内置效果：resolve_effect 嵌套调用）
        └─ 否 → 需要新流程（新阶段/新规则门）？
                └─ 是 → 按 5.2 新增钩子，三步走
```

---

## 8. 相关文件

| 文件 | 职责 |
|------|------|
| `scripts/effects/hook_registry.gd` | 钩子常量 + 钩子清单（名字 + 注释）★ 改钩子必改这里 |
| `scripts/effects/hook_chain.gd` | 钩子链执行器（register / trigger / unregister + 名称校验） |
| `scripts/effects/buff_manager.gd` | buff 生命周期，负责将 buff 注册为钩子回调 |
| `scripts/battle/effect_resolver.gd` | 效果解析分发（effect_type → handler） |
| `scripts/battle/battle_controller.gd` | 战斗总控，触发攻击链 / 规则门钩子 |
| `scripts/systems/player_manager.gd` | 玩家单位，受击链（on_damage_taken / before_death） |
| `scripts/systems/enemy_unit.gd` | 敌人单位，受击链（on_damage_taken / before_death） |
