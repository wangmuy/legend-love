基于游泳的鱼的金庸群侠传 lua 复刻版，修改 gbk 编码为 utf8 编码。

## 文档

- [AGENTS.md](AGENTS.md) - 项目编码指南和架构说明
- [TESTING.md](TESTING.md) - 测试方法和命令
- [SRC_FILES.md](SRC_FILES.md) - src/ 目录文件分析（使用状态和作用说明）
- [DATA_FILES.md](DATA_FILES.md) - src/data/ 数据文件格式说明
- [SCRIPT_FILES.md](SCRIPT_FILES.md) - src/script/ 脚本文件说明

> **重要**: 以上文档内容以实际运行代码为准，文档可能与代码存在偏差，开发时请优先参考源码。

## love2d 版运行说明

基于游泳的鱼的金庸群侠传 lua 复刻版，utf8 编码，纯 lua(love2d) 版.

### 运行

```
cd bin
love .
# if using AppImage
# love.AppImage .
```

### 测试

```bash
cd src && lua tests/test_runner.lua
```
