## ADDED Requirements

### Requirement: 本地 .love 文件构建
系统 SHALL 支持使用本地工具构建 .love 文件。

#### Scenario: 使用 build-love.sh 构建
- **WHEN** 用户在项目根目录执行 `./tools/build-love.sh`
- **THEN** 系统使用 7z 将 `game/` 目录打包为 `.love` 文件
- **AND** 输出文件位于 `builds/1/jylegend.love`

#### Scenario: 使用 love.AppImage 运行
- **WHEN** 用户执行 `/home/woodfish/bin/love.AppImage builds/1/jylegend.love`
- **THEN** 游戏正常启动并运行

### Requirement: GitHub Actions CI/CD 工作流
系统 SHALL 在推送到 GitHub 时自动触发多平台构建。

#### Scenario: 手动触发工作流
- **WHEN** 用户在 GitHub Actions 界面手动触发 workflow_dispatch
- **THEN** 系统执行构建工作流
- **AND** 为启用的平台生成构建产物

#### Scenario: 标签推送触发发布构建
- **WHEN** 用户推送形如 `1.0.0` 的标签到 GitHub
- **THEN** 系统创建 GitHub Release
- **AND** 将构建产物上传到 Release 资源

### Requirement: Android APK 构建
系统 SHALL 构建 Android APK 文件。

#### Scenario: Android 构建成功
- **GIVEN** GitHub Actions 工作流运行
- **WHEN** TARGET_ANDROID 设置为 "true"
- **THEN** 系统生成签名后的 APK 文件

### Requirement: Linux AppImage 构建
系统 SHALL 构建 Linux AppImage 文件。

#### Scenario: Linux AppImage 构建成功
- **GIVEN** GitHub Actions 工作流运行
- **WHEN** TARGET_LINUX_APPIMAGE 设置为 "true"
- **THEN** 系统生成 jylegend.AppImage 文件

### Requirement: Windows ZIP 构建
系统 SHALL 构建 Windows ZIP 文件。

#### Scenario: Windows ZIP 构建成功
- **GIVEN** GitHub Actions 工作流运行
- **WHEN** TARGET_WINDOWS_ZIP 设置为 "true"
- **THEN** 系统生成 jylegend.zip 文件

### Requirement: 构建配置管理
系统 SHALL 通过 `game/product.env` 文件管理构建配置。

#### Scenario: product.env 配置读取
- **GIVEN** game/product.env 文件存在且配置正确
- **WHEN** 构建脚本或 CI 工作流运行
- **THEN** 系统正确读取所有配置项
- **AND** 按配置启用/禁用对应平台构建

### Requirement: 目录结构变更
系统 SHALL 使用 `game/` 目录存放游戏代码。

#### Scenario: 代码位于 game/ 目录
- **GIVEN** 所有源代码从 src/ 移动到 game/
- **WHEN** 执行构建或运行命令
- **THEN** 系统正确使用 game/ 目录下的文件

### Requirement: 文档同步更新
系统 SHALL 更新所有文档中的路径引用。

#### Scenario: 文档路径引用正确
- **GIVEN** 文档已更新
- **WHEN** 用户阅读 AGENTS.md、SRC_FILES.md、TESTING.md 等文档
- **THEN** 所有 `src/` 引用已更新为 `game/`
