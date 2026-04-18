## Why

当前项目使用 `love src/` 命令手动运行，缺乏自动化构建流程。为了支持多平台发布（Android APK、Linux AppImage、Windows ZIP），需要引入基于 GitHub Actions 的 CI/CD 构建系统，同时支持本地构建 .love 文件进行测试。

## What Changes

- **BREAKING**: 将 `src/` 目录重命名为 `game/`，以符合 LÖVE 构建模板的标准结构
- 添加 `game/product.env` 构建配置文件，定义产品元数据和目标平台
- 合并模板 `conf.lua` 功能（调试支持、从 product.env 读取配置）
- 复制 GitHub Actions 工作流和构建动作（`.github/workflows/build.yml`、`.github/actions/*`）
- 复制本地构建脚本 `tools/build-love.sh`
- 更新所有文档中的 `src/` 引用为 `game/`

## Capabilities

### New Capabilities
- `cicd-builds`: 多平台自动化构建系统，支持本地 .love 构建和 GitHub Actions CI/CD

### Modified Capabilities
- 无现有功能需求变更

## Impact

- 目录结构变更：`src/` → `game/`
- 新增 CI/CD 依赖：GitHub Actions
- 本地构建依赖：7z、love.AppImage
- 构建输出：`builds/1/jylegend.love` 等
