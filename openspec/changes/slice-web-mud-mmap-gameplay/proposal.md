---
status: active
parent_epic: web-mud-text-version
---

# Slice 3: 大地图漫游

## 用户故事

用户在浏览器打开页面后，能够从开始菜单进入新游戏，分配属性，进入大地图进行漫游（list/look/quit），并进入场景查看基础信息。

## 切片类型

Feature

## In Scope

- 游戏框架（framework/*.lua）在 Web 环境的加载和运行（CoroutineScheduler, StateMachine, EventBridge, GameStates）
- `processEventQueue` 集成 CoroutineScheduler，驱动协程运转
- 游戏脚本（jymain.lua, jyconst.lua, jymodify.lua）加载
- JYMainAdapter.init() 完整初始化流程
- Web 文字命令解析器：parseCommand + dispatch + context-aware registry
- 开始菜单文字版：1.新游戏 2.读档 3.退出（通过文本命令 choose N）
- 属性选择：随机生成 + Y/N 确认
- 大地图 GAME_MMAP 状态文字交互：
  - `list` — 选择场景前往（基于 entrances.json，菜单模式）
  - `look` — 查看当前位置、坐标、方位和附近场景
  - `quit` — 退出当前游戏返回开始菜单（二次确认）
  - `help` — 显示当前状态可用命令
  - `choose N` — 选择菜单项
- 场景 GAME_SMAP 基础交互：
  - `look` — 场景描述（NPC、物品、出口）
  - `exits` — 出口编号列表
  - `go <编号>` — 按出口编号离开场景回到大地图
  - `leave` — 离开场景回到大地图
- 输入适配：Web 文本命令 → 转换为 framework 可消费的按键事件

## Out of Scope

- NPC 对话（talk 命令）— Slice 4
- 物品交互（take/give）— Slice 4
- 事件触发 — Slice 4
- 战斗系统 — Slice 5
- 角色管理（status/bag/equip）— Slice 6
- 存档读档（save/load）— Slice 6（JSBridge 已就绪）
- 场景内动画效果
- 大地图行走动画（文字版走格子不需要）

## 验收标准

### GAME_START → MMAP 流程
- **Given** 页面加载完成，系统就绪
- **When** 用户输入 `choose 1`
- **Then** 进入属性选择界面，显示随机属性
- **When** 属性显示后，用户输入 `choose 1`（是）
- **Then** 进入大地图状态，显示当前位置描述

### MMAP 交互
- **Given** 玩家处于大地图 GAME_MMAP 状态
- **When** 输入 `list`
- **Then** 弹出场景菜单（编号 + 场景名），choose N 选择前往
- **When** 输入 `look`
- **Then** 输出当前位置、坐标、方位和附近场景列表
- **When** 输入 `quit`
- **Then** 弹出确认对话框，choose 1 确认后返回开始菜单
- **When** 输入 `help`
- **Then** 列出 MMAP 状态可用命令

### SMAP 交互
- **Given** 玩家处于场景 GAME_SMAP 状态
- **When** 输入 `look`
- **Then** 输出场景描述，包含场景名、描述模板、NPC 列表、出口
- **When** 输入 `exits`
- **Then** 列出出口编号和目标场景名
- **When** 输入 `leave`
- **Then** 离开场景回到大地图
- **When** 输入 `go <编号>`
- **Then** 通过出口编号离开场景（或进入新场景）

## 影响领域

framework integration, event-loop, input, render, game-states, jymain-adapter