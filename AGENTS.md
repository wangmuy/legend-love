# AGENTS.md - 金庸群侠传 Love2D 项目编码指南

本文档为 AI 智能体提供金庸群侠传 Love2D 项目的编码规范和工作指南。

## 项目概述

这是一个基于 Lua/Love2D 的经典国产 RPG 游戏《金庸群侠传》复刻版。
- **开发语言**: Lua 5.1+ (Love2D 框架)
- **支持平台**: 跨平台 (Linux, macOS, Windows)
- **文件编码**: UTF-8

## 构建/运行命令

```bash
# 运行游戏
love src/

# 或在游戏目录下运行
cd src && love .

# 调试输出保存在 src/debug.txt
# 错误输出保存在 src/error.txt
```

**注意**: 本项目没有正式的测试套件或代码检查工具。测试通过手动运行游戏完成。

## 代码风格规范

### 命名规范

- **全局常量**: `UPPER_CASE` (例如: `VK_ESCAPE`, `C_WHITE`, `GAME_MMAP`)
- **配置项**: `CONFIG.*` 前缀 (例如: `CONFIG.Width`, `CONFIG.Debug`)
- **游戏常量**: `CC.*` 前缀，定义在 `jyconst.lua` (例如: `CC.ScreenW`, `CC.R_GRPFilename`)
- **游戏状态**: `JY.*` 前缀 (例如: `JY.Status`, `JY.Person`)
- **函数名**: 公共函数使用 `CamelCase`，局部函数使用 `camelCase` 或 `snake_case`
- **局部变量**: 使用 `camelCase` 或 `snake_case`
- **文件内函数**: `local function FunctionName()`

### 文件组织结构

```
src/
├── main.lua          # 程序入口，Love2D 回调函数
├── conf.lua          # Love2D 配置
├── config.lua        # 游戏配置 (CONFIG.*)
├── lib_love.lua      # 图形/音频封装 (lib.*)
├── lib_Byte.lua      # 二进制数据工具 (Byte.*)
├── lib_log.lua       # 日志工具
├── luabit.lua        # 位运算操作
├── script/
│   ├── jymain.lua    # 主游戏逻辑 (~230KB)
│   ├── jyconst.lua   # 常量和游戏数据
│   ├── jymodify.lua  # 修改和扩展
│   ├── oldevent/     # 旧版事件脚本
│   └── newevent/     # 新版事件脚本
└── data/             # 游戏资源 (grp, idx, 002 文件)
```

### 函数规范

```lua
-- 公共函数
function FunctionName(arg1, arg2)
    -- 实现代码
end

-- 局部函数
local function localFunctionName(arg1)
    -- 实现代码
end

-- 事件函数 (oldevent)
function oldevent_XXX()
    instruct_1(1234, 0, 1);  -- 对话
    instruct_0();              -- 清屏
    instruct_3(...);           -- 修改事件
end
```

### 关键模式

1. **游戏循环**: 使用 Love2D 的 `love.run()` 配合自定义 `JY_Main()`
2. **事件系统**: `oldevent/` 目录下的旧版事件使用 `instruct_XXX()` 函数
3. **图像加载**: 自定义 GRP 格式，支持 PNG 回退 (参考 `LoadPic()`)
4. **屏幕状态**: `GAME_START`, `GAME_MMAP`, `GAME_SMAP`, `GAME_WMAP`

### 错误处理

- 使用 `lib.Debug()` 输出调试信息 (当 `CONFIG.Debug=1` 时写入 debug.txt)
- 对可能失败的操作使用 `pcall()` (例如图像加载)
- 检查文件操作的 nil 返回值

### 图形规范

- 使用 `lib.SetClip()` / `lib.FillColor()` 设置屏幕区域
- 使用 `lib.PicLoadCache()` 渲染精灵
- 重绘前使用 `Cls()` 清屏
- 颜色使用 `RGB(r,g,b)` 辅助函数返回打包整数

### 数据文件

- **GRP 文件**: 自定义图像格式 (RLE + PNG 混合)
- **IDX 文件**: GRP 索引文件 (4 字节偏移)
- **002 文件**: 地图数据文件
- 所有路径使用 `CONFIG.DataPath` 前缀

### 注释规范

- 单行注释使用 `--`
- 多行注释使用 `--[[ ... --]]`
- 本代码库中常见中文注释
- 函数定义上方使用 `--` 说明函数用途

### 缩进规范

- 使用 4 个空格缩进
- 相关赋值对齐
- 行长度保持合理 (<120 字符)

## 重要提示

1. **无正式测试**: 通过运行游戏并检查 debug.txt 进行测试
2. **调试模式**: 在 config.lua 中设置 `CONFIG.Debug=1` 启用详细日志
3. **资源文件**: 不理解格式前不要修改 GRP/IDX 文件
4. **Love2D 版本**: 目标 Love2D 11.x (版本见 conf.lua)
5. **文件编码**: 所有源文件使用 UTF-8

## 常见任务

- **添加 NPC 对话**: 在 `script/oldevent/` 创建/编辑文件
- **修改游戏数据**: 编辑 `script/jyconst.lua`
- **添加新场景事件**: 在 `script/newevent/` 创建文件
- **调试渲染**: 运行后检查 `src/debug.txt`
