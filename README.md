# Easy Card Game

一款使用 Godot 4.7 开发的卡牌 roguelike 游戏。

## 功能特性

### 战斗系统
- 状态机驱动的战斗流程（状态机 + 回合管理 + 效果结算器三层架构）
- 无能量限制，注重卡组运转
- 游戏王模式：弃牌堆不自动洗回，需要卡牌效果触发循环
- 伤害预览：UI 实时显示攻击预估伤害（经过完整钩子链计算）

### 卡牌系统
- JSON 驱动的卡牌定义，含模板文件供快速设计新卡
- 标签系统：支持卡牌分类、字段伪装
- 多种效果类型：伤害、护甲、检索、消耗、buff 等
- 卡牌强化：提升卡牌倍率或数值
- 卡池管理：战斗中动态抽牌、洗牌、弃牌

### 遗物系统
- JSON 定义的遗物数据库
- 遗物通过钩子链修改游戏规则（如伤害倍率、格挡加成、抽牌等）
- 战斗胜利后选择遗物奖励
- 遗物列表面板查看已拥有遗物

### 地图系统
- 无尽楼层模式
- JSON 定义的地图节点
- 地图状态管理（已访问节点、当前路径）

### Buff / 钩子链系统
- HookRegistry 注册全局钩子点（伤害计算、格挡、治疗、死亡判定等）
- HookChain 按优先级串联多个钩子，支持倍率叠加和加算修正
- BuffManager 管理 buff 的施加、层数、过期
- 遗物和卡牌效果均通过钩子链介入战斗逻辑

### UI 交互与动画
- 基于 Godot 4.7 Offset Transform 的按钮动画：悬停放大 / 点击挤压 / 按下涟漪
- 场景过渡：黑屏淡入/淡出 + 按钮消失/碎片飞散（TransitionManager）
- 一次性按钮消失动画（宝箱打开 / 营地休息）
- 连点优化：涟漪/碎片不拦截点击，快速连点跟手
- 手牌扇形布局 + 滚动窗口
- 卡牌拖拽 + 目标瞄准箭头

### 窗口自适应
- 引擎 stretch 系统自动处理缩放：`canvas_items` 模式 + `keep` 宽高比
- 移动端横屏锁定
- 桌面端拖拽窗口/最大化自动等比缩放，无需额外代码

### 存档系统
- 自动保存游戏进度
- 支持继续游戏功能

## 技术栈

- **引擎**: Godot 4.7（Forward+ 渲染）
- **语言**: GDScript
- **架构**: MVC 模式、状态机模式、钩子链模式
- **Autoload**: GameManager、GameData、SaveManager、CardPoolManager、UIStyle、TransitionManager

## 项目结构

```
card/
├── data/                    # 数据文件（JSON）
│   ├── cards/               # 卡牌定义（15 张）
│   ├── enemies/             # 敌人定义
│   ├── maps/                # 地图定义
│   ├── buffs.json           # buff 定义
│   ├── relics.json          # 遗物定义
│   ├── decks.json           # 初始牌组
│   └── tags.json            # 标签定义
├── scenes/                   # 场景文件（.tscn）
│   ├── start.tscn           # 主菜单
│   ├── BattleScene.tscn     # 战斗场景
│   ├── MapScreen.tscn       # 地图导航
│   ├── Card.tscn            # 卡牌 UI 单元
│   ├── EnemyUI.tscn         # 敌人 UI 单元
│   ├── RewardScreen.tscn    # 战斗奖励
│   ├── RelicRewardScreen.tscn # 遗物选择奖励
│   ├── RelicListPanel.tscn  # 遗物列表面板
│   ├── RelicChoiceCard.tscn # 遗物选择卡片
│   └── GameOverScreen.tscn  # 游戏结束
├── scripts/                  # 脚本文件
│   ├── battle/              # 战斗系统
│   │   ├── battle_controller.gd  # 战斗总控
│   │   ├── effect_resolver.gd    # 效果结算器
│   │   ├── state_machine.gd      # 状态机
│   │   ├── turn_manager.gd       # 回合管理
│   │   └── ui_controller.gd      # 战斗 UI 控制器
│   ├── effects/             # buff / 钩子链
│   │   ├── hook_registry.gd      # 钩子注册表
│   │   ├── hook_chain.gd         # 钩子链执行
│   │   ├── buff_data.gd          # buff 数据结构
│   │   └── buff_manager.gd       # buff 管理器
│   ├── systems/             # 核心系统
│   │   ├── player_manager.gd     # 玩家状态管理
│   │   ├── enemy_unit.gd         # 敌人单位
│   │   ├── enemy_system.gd       # 敌人系统
│   │   ├── card_system.gd        # 卡牌系统
│   │   ├── relic_manager.gd      # 遗物管理器
│   │   ├── relic_database.gd     # 遗物数据库
│   │   └── relic_data.gd         # 遗物数据结构
│   ├── ui/                  # UI 组件
│   │   ├── card_ui.gd            # 卡牌 UI（拖拽/点击/目标选择）
│   │   ├── enemy_ui.gd           # 敌人 UI
│   │   ├── drag_arrow.gd         # 拖拽瞄准箭头
│   │   ├── target_marker.gd      # 目标标记
│   │   └── hand_layout_presets.gd # 手牌布局预设
│   ├── ui_style.gd          # UI 样式 + 按钮动画（Autoload）
│   ├── transition_manager.gd # 场景过渡管理器（Autoload）
│   ├── game_manager.gd      # 全局游戏管理器（Autoload）
│   ├── game_data.gd         # 游戏数据（Autoload）
│   ├── save_manager.gd      # 存档管理器（Autoload）
│   ├── card_pool_manager.gd # 卡池管理器（Autoload）
│   ├── map_controller.gd    # 地图控制器
│   ├── map_screen.gd        # 地图界面
│   ├── map_state.gd         # 地图状态
│   └── start.gd             # 主菜单
└── project.godot            # 项目配置
```

## 运行方式

1. 安装 Godot 4.7
2. 打开项目：导入 `project.godot`
3. 运行：按 F5 或点击运行按钮

## 开发说明

- 使用中文命名数据文件和卡牌定义
- 遵循 GDScript 代码规范
- 详细注释关键逻辑
- 卡牌设计：参考 `data/cards/_模板_卡牌名.json` 创建新卡牌

## 许可证

MIT License
