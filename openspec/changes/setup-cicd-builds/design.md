## Context

当前项目已完成事件驱动架构迁移，所有游戏代码位于 `src/` 目录。为了支持多平台发布，需要引入 LÖVE 构建模板中的 CI/CD 系统。模板使用 `game/` 作为游戏代码目录，与现有 `src/` 结构冲突。

**当前状态：**
- 代码位置：`src/`（包含 main.lua、conf.lua、script/、data/ 等）
- 构建方式：`love src/` 本地手动运行
- 文档引用：所有文档使用 `src/` 路径

**模板参考：**
- 模板路径：`~/project/bootstrap-love2d-project/`
- 模板结构：`game/` 目录包含 main.lua、conf.lua、product.env
- 构建系统：GitHub Actions + 本地 7z 打包

## Goals / Non-Goals

**Goals:**
- 建立本地 .love 构建能力（使用 7z 和 love.AppImage）
- 建立 GitHub Actions CI/CD 流程
- 支持 Android APK、Linux AppImage、Windows ZIP 构建
- 保持现有代码功能不变

**Non-Goals:**
- 不引入性能监控 overlay（overlayStats.lua）
- 不引入 HTTPS 支持（runtime/ 目录）
- 不配置 itch.io 自动发布
- 不构建 iOS、macOS、HTML 版本
- 不修改 IDE 调试配置

## Decisions

### 1. 目录重命名：src/ → game/

**决策**：将 `src/` 完全重命名为 `game/`，而非创建符号链接或修改模板。

**理由**：
- 模板在多处硬编码 `game/` 路径（.github/workflows/build.yml 9 处、tools/*.sh 等）
- 修改模板路径维护成本高，后续更新困难
- 重命名是最简单可靠的方式

**替代方案**：
- 符号链接 `game/ → src/`：GitHub Actions 可能无法正确跟随，Windows 支持差
- 修改模板所有路径：工作量大，易出错

### 2. 最小化模板复制

**决策**：仅复制必要的构建相关文件，不包含可选功能。

**复制内容**：
- `.github/workflows/build.yml` - 主 CI 工作流
- `.github/actions/*` - 各平台构建动作
- `tools/build-love.sh` - 本地构建脚本
- `game/product.env` - 构建配置

**不复制内容**：
- `game/lib/overlayStats.lua` - 性能监控（不需要）
- `game/runtime/` - HTTPS 支持（不需要）
- `resources/icon.png` - 使用现有图标

### 3. conf.lua 合并策略

**决策**：保留现有 `conf.lua` 的核心配置，合并模板的调试支持和 product.env 读取功能。

**合并内容**：
- 调试器支持（`lldebugger`）
- product.env 读取逻辑
- `t.identity` 从 product.env 读取

**保留内容**：
- `CONFIG.Width/Height` 窗口尺寸
- `CONFIG.FullScreen` 全屏设置
- 中文标题 `"金庸群侠传 lua 复刻版"`

### 4. 平台选择

**决策**：仅启用必要的平台构建目标。

| 平台 | 状态 | 理由 |
|------|------|------|
| .love | ✅ | 基础包，本地测试必需 |
| Android APK | ✅ | 移动端发布 |
| Linux AppImage | ✅ | Linux 桌面 |
| Windows ZIP | ✅ | Windows 桌面 |
| iOS | ❌ | 模板标记为 🚧 实验性 |
| macOS | ❌ | 不需要 |
| HTML5 | ❌ | love.js 可能不兼容事件驱动架构 |
| Linux tarball | ❌ | AppImage 已覆盖 |
| Windows installer/SFX | ❌ | ZIP 已覆盖 |

### 5. 产品命名

**决策**：使用 ASCII 名称 `jylegend` 作为 `PRODUCT_NAME`，中文描述保留在 `PRODUCT_DESC`。

**理由**：避免中文文件名在某些文件系统/工具链中的兼容问题。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 目录重命名破坏现有工作流 | 同步更新所有文档，AGENTS.md 明确标注变更 |
| OpenSpec 历史记录中的 `src/` 引用过时 | 历史记录保持不变，作为变更轨迹 |
| GitHub Actions 首次运行失败 | 本地先用 `tools/build-love.sh` 验证 |
| Android 签名配置缺失 | 首次 CI 运行会失败，需要后续配置密钥 |

## Migration Plan

1. **本地验证**（变更实施时）：
   - 运行 `./tools/build-love.sh`
   - 验证 `builds/1/jylegend.love` 生成
   - 运行 `/home/woodfish/bin/love.AppImage builds/1/jylegend.love`
   - 确认游戏正常启动

2. **GitHub Actions 验证**（推送到 GitHub 后）：
   - 手动触发 workflow_dispatch
   - 检查各平台构建产物
   - Android 构建需要配置签名密钥后才能成功

3. **回滚策略**：
   - 如有问题，恢复 `src/` 目录（保留 git 历史）
   - 移除 `.github/workflows/` 和 `tools/`
   - 恢复原有文档引用

## Open Questions

- ~~Android 签名密钥如何配置？~~ 已决定：先只构建 debug 版本，使用标准 Android debug 密钥
- ~~是否需要为不同平台生成不同的 UUID？~~ 已决定：使用统一 UUID

## 更新决策

### 6. Android 构建策略（更新）

**决策**：先只构建 Android debug APK，不构建 release APK/AAB。

**理由**：
- Release 构建需要配置签名密钥（ANDROID_RELEASE_SIGNINGKEY_BASE64 等 secrets）
- Debug 构建使用标准 Android debug 密钥，配置简单
- 后续需要 release 版本时再配置正式签名密钥

**Debug 密钥生成**（标准 Android Studio debug 密钥）：
```bash
keytool -genkey -v \
  -keystore debug.keystore \
  -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 18250 \
  -storepass android \
  -keypass android \
  -dname "CN=Android Debug,O=Android,C=US"

# 生成 base64
openssl base64 < debug.keystore | tr -d '\n'
```

**需要的 GitHub Secrets**（仅 debug）：
- `ANDROID_DEBUG_SIGNINGKEY_BASE64`
- `ANDROID_DEBUG_ALIAS=androiddebugkey`
- `ANDROID_DEBUG_KEYSTORE_PASSWORD=android`
- `ANDROID_DEBUG_KEY_PASSWORD=android`

### 7. UUID 策略

**决策**：所有平台使用统一的 `PRODUCT_UUID`。

**理由**：
- 简化配置管理
- 这是单一产品，不需要按平台区分 UUID
- 已生成的 UUID：`e6af0e53-2cbc-44df-b952-6a9bb2fe6b86`
