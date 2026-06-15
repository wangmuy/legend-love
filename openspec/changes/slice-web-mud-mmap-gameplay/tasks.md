## 1. 游戏框架集成（web-game-bridge）

- [x] 1.1 processEventQueue 拉取 JSBridge 事件：choose N → MenuAsync.closeMenu(N)，其他命令 → CommandEngine.dispatchCommand
- [x] 1.2 实现 `processEventQueue` 调用 CoroutineScheduler:update(dt) 和 StateMachine:update(dt)
- [x] 1.3 建立 framework/*.lua 的 require 路径映射（从 dataCache 或单独加载）
- [x] 1.4 加载并运行脚本模块（jymain.lua, jyconst.lua, jymodify.lua）
- [x] 1.5 JYMainAdapter.init() 完整初始化流程可运行（IncludeFile → SetGlobalConst → SetGlobal → GenTalkIdx → SetModify）
- [x] 1.6 Web 版的 Cls() / ShowScreen() 实现（映射到 EngineAPI.render）
- [x] 1.7 `_G.DrawString` / `_G.DrawBox` 等兼容函数映射到 ANSI 输出
- [x] 1.8 开始菜单文字渲染 + choose N 交互（替换 MenuAsync.ShowMenuCoroutine）
- [x] 1.9 属性选择界面文字渲染 + Y/N 交互
- [x] 1.10 错误处理：脚本加载失败时显示友好提示

## 2. 命令解析引擎（web-command-engine）

- [x] 2.1 实现 parseCommand(text)：将文本解析为 {cmd, args}
- [x] 2.2 设计命令注册表结构，支持按 JY.Status 区分可用命令
- [x] 2.3 实现 dispatchCommand(cmd, args)：匹配命令 + 执行处理器
- [x] 2.4 实现 `help` 命令：显示当前状态所有可用命令
- [x] 2.5 实现 `choose N` 命令：选择菜单项（映射为数字键事件）
- [x] 2.6 未知命令提示：显示"未知命令，输入 help 查看可用命令"
- [x] 2.7 命令参数解析：支持带引号的参数（如 `go "河洛客栈"`）

## 3. 大地图和场景交互（web-mmap-smap）

- [x] 3.1 实现 MMAP `list`：从 entrances.json 列出所有可去场景（编号 + 场景名）
- [x] 3.2 实现 MMAP `go <场景名>`：查找场景入口，更新 JY.Base 坐标，切换到 GAME_SMAP
- [x] 3.3 实现 MMAP `look`：显示当前位置描述文本
- [x] 3.4 实现 MMAP `where`：显示当前坐标 (X, Y) 和附近场景
- [x] 3.5 实现 SMAP `look`：显示场景描述（场景名 + 描述 + NPC 列表 + 物品 + 出口）
- [x] 3.6 实现 SMAP `exits`：列出场景出口方向
- [x] 3.7 实现 SMAP `go <方向>`：匹配出口方向，离开场景回到大地图
- [x] 3.8 场景描述模板：基于场景类型生成合适的中文描述
- [x] 3.9 go 命令容错：模糊匹配场景名（如 "河洛" 匹配 "河洛客栈"）

## 4. 验证

- [x] 4.1 单元测试：parseCommand 各边界情况
- [x] 4.2 单元测试：命令注册表完整性
- [x] 4.3 E2E 测试：开始菜单 → 属性选择 → MMAP → SMAP 完整流程
- [x] 4.4 E2E 测试：MMAP 所有命令 (list/go/look/where/help)
- [x] 4.5 E2E 测试：SMAP 所有命令 (look/exits/go)
- [x] 4.6 E2E 测试：未知命令提示
- [x] 4.7 E2E 测试：错误命令提示（如 go 不存在的场景）