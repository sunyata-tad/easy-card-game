# card — Godot 卡牌游戏项目

## 项目简介
Godot 4.6 GDScript 回合制卡牌战斗游戏。

## 核心约定
- 命名规范：snake_case
- 所有属性统一为 buff，PlayerManager 无裸属性
- 所有持续性效果统一为 buff，由 buff_manager 管理
- 伤害计算链条请参考 GAME_DESIGN.md 第 2.4-2.5 节

## 关键文件
- `GAME_DESIGN.md` — 游戏策划文档（编码前必读）
- `PROJECT_STATE.md` — 技术架构与项目状态
- `.claude/skills/game-designer/SKILL.md` — 游戏策划 skill，记录设计决策

## 语言与提交规范
- **对话语言**：始终使用简体中文回复
- **Git Commit Message**：始终使用简体中文，格式为 `<类型>: <中文描述>`
  - 类型：feat(新功能), fix(修复), refactor(重构), docs(文档), style(样式), chore(杂项)
  - 示例：`feat: 添加卡牌抽卡动画效果`

## 工作流程
1. 编码前先读取 GAME_DESIGN.md 确认实现与设计一致
2. 策划讨论时使用 game-designer skill 自动记录决策
3. 发现设计偏离主动提醒
