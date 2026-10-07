## 1. parseCommand 实现

- [x] 1.1 基本解析：空格分隔命令和参数
- [x] 1.2 引号支持：`go "河洛客栈"` 视为一个参数
- [x] 1.3 空输入 / 空白输入返回 nil
- [x] 1.4 命令转小写

## 2. 命令注册表

- [x] 2.1 registerCommands(stateId, commands) 函数
- [x] 2.2 getCommands(stateId) 函数
- [x] 2.3 命令条目结构：{handler, description}

## 3. dispatchCommand 实现

- [x] 3.1 按 JY.Status 查找命令表
- [x] 3.2 pcall 保护执行命令处理器
- [x] 3.3 未知命令返回 false
- [x] 3.4 执行错误输出到终端

## 4. 内置命令

- [x] 4.1 `help` 命令：列出当前状态所有可用命令
- [x] 4.2 `choose N` 命令：关闭当前菜单返回 N，无菜单时提示
- [x] 4.3 `help <命令名>` 显示单个命令用法

## 5. WebUI 输出辅助

- [x] 5.1 WebUI.write(text) — 输出文本 + 换行
- [x] 5.2 WebUI.writeLine(text) — 输出文本
- [x] 5.3 WebUI.separator() — 分隔线
- [x] 5.4 WebUI.title(text) — 标题

## 6. 验证

- [x] 6.1 单元测试：parseCommand 各种输入情况
- [x] 6.2 单元测试：命令注册和查找
- [x] 6.3 单元测试：dispatchCommand 分发正确
- [x] 6.4 E2E 测试：help 命令输出
- [x] 6.5 E2E 测试：未知命令提示