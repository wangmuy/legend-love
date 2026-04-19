## 1. 目录结构重构

- [x] 1.1 将 `src/` 目录重命名为 `game/`
- [x] 1.2 验证 `game/` 目录包含所有必要文件（main.lua、conf.lua、script/、data/、pic/、sound/、tests/）
- [ ] 1.3 确保没有遗漏任何子目录或文件

## 2. 构建配置

- [ ] 2.1 创建 `game/product.env` 文件，配置如下：
  - LOVE_VERSION="11.5"
  - PRODUCT_NAME="jylegend"
  - PRODUCT_ID="wangmuy.love2d.jygame"
  - PRODUCT_COMPANY="wangmuy solo"
  - PRODUCT_UUID="e6af0e53-2cbc-44df-b952-6a9bb2fe6b86"
  - TARGET_ANDROID="true"
  - TARGET_LINUX_APPIMAGE="true"
  - TARGET_WINDOWS_ZIP="true"
  - 其余平台设置为 "false"
  - ITCH_USER=""（空值，禁用 itch.io 发布）

## 3. conf.lua 更新

- [ ] 3.1 备份现有 `game/conf.lua`
- [ ] 3.2 合并模板的调试支持代码（lldebugger 检测和启动）
- [ ] 3.3 添加 product.env 读取逻辑
- [ ] 3.4 更新 `t.identity` 从 product.env 读取 PRODUCT_ID
- [ ] 3.5 保留现有窗口配置（CONFIG.Width/Height、CONFIG.FullScreen）
- [ ] 3.6 保留中文标题设置
- [ ] 3.7 验证 conf.lua 语法正确

## 4. CI/CD 文件复制

- [x] 4.1 创建 `.github/workflows/` 目录
- [x] 4.2 复制 `~/project/bootstrap-love2d-project/.github/workflows/build.yml` 到 `.github/workflows/`
- [x] 4.3 创建 `.github/actions/` 目录
- [x] 4.4 复制 `~/project/bootstrap-love2d-project/.github/actions/*` 到 `.github/actions/`
  - build-android/
  - build-html/
  - build-ios/
  - build-linux/
  - build-love/
  - build-macos/
  - build-windows/
  - get-env/
  - install-tools/
  - publish-itch
- [x] 4.5 创建 `tools/` 目录
- [x] 4.6 复制 `~/project/bootstrap-love2d-project/tools/build-love.sh` 到 `tools/`
- [x] 4.7 给 `tools/build-love.sh` 添加执行权限（chmod +x）

## 5. GitHub Actions 工作流修改（本地修改）

- [x] 5.1 修改 `.github/workflows/build.yml`，注释掉或删除以下内容：
  - Sign Android release .apk 步骤
  - Sign Android .aab 步骤
  - Upload Android release .apk 步骤
  - Upload Android release .aab 步骤
  - Upload Android release .apk to itch.io 步骤
- [x] 5.2 保留 Android debug 构建和签名步骤
- [x] 5.3 确保 Android debug APK 构建后上传为 artifact

## 6. 文档更新

- [x] 6.1 更新 `AGENTS.md` 中的所有 `src/` 引用为 `game/`
- [x] 6.2 更新 `SRC_FILES.md` 的标题和内容中的 `src/` 引用
- [x] 6.3 更新 `SCRIPT_FILES.md` 中的 `src/script/` 引用
- [x] 6.4 更新 `DATA_FILES.md` 中的 `src/data/` 和 `src/script/` 引用
- [x] 6.5 更新 `ARCHITECTURE.md` 中的 `src/` 引用
- [x] 6.6 更新 `TESTING.md` 中的 `src/tests/` 引用
- [x] 6.7 更新 `README.md` 中的 `src/` 引用
- [x] 6.8 在 `AGENTS.md` 中添加构建说明和本地测试指令

## 7. 本地测试验证

- [x] 7.1 运行 `./tools/build-love.sh`
- [x] 7.2 验证 `builds/1/jylegend.love` 文件生成（56 MiB）
- [x] 7.3 运行单元测试：`cd game && lua tests/test_runner.lua`
- [x] 7.4 验证所有单元测试通过（28/28 全部通过）
- [ ] 7.5 （可选）手动测试：运行 `/home/woodfish/bin/love.AppImage builds/1/jylegend.love` 验证游戏启动

## 7.6 跨平台文件系统适配（love.filesystem）

- [x] 7.6.1 新增 `game/lib_file.lua` 作为统一文件读写封装，优先使用 `love.filesystem`（相对路径）
- [x] 7.6.2 调整日志输出到 `love.filesystem` 路径（`debug.txt`）
- [x] 7.6.3 调整存档/索引等核心文件读写路径通过 `FileUtil` 访问（`lib_Byte.lua`、`lib_love.lua`、`script/jymain.lua`）
- [x] 7.6.4 验证 `debug.txt` 已写入 `~/.local/share/love/wangmuy.love2d.jygame/`
- [x] 7.6.5 存档槽路径切换：`id=0` 使用内置 `data/*` 模板，`id=1/2/3` 使用 `save/*` 可写路径
- [x] 7.6.6 修复读档失败时的菜单交互：显示“存档不存在”提示后返回菜单（不丢失 UI）
- [x] 7.6.7 事件驱动适配器中改用异步消息框（`AsyncMessageBox`），避免阻塞式提示导致菜单卡死/无响应

## 8. Git 提交和推送

- [x] 8.1 更新 `.gitignore`（添加 builds/ 目录，更新 debug.txt 路径）
- [x] 8.2 添加所有变更到 git：`git add .`
- [x] 8.3 创建提交，包含清晰的变更说明（目录重命名 + CI/CD 添加 + build.yml 修改）
  - 提交信息："Setup CI/CD builds: add GitHub Actions, move src/ to game/, add product.env"
  - 1461 个文件变更，2450 行新增，65 行删除
- [ ] 8.4 推送变更到 GitHub：`git push origin love2d-event-driven`（当前分支）

## 9. GitHub Secrets 配置（**手动执行**，有问题通知我）

- [ ] 9.1 生成 Android debug keystore：
  ```bash
  keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 18250 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
  openssl base64 < debug.keystore | tr -d '\n' > debug.keystore.base64.txt
  ```
- [ ] 9.2 在 GitHub 网站设置 Secrets（仓库 Settings → Secrets → Actions）：
  - `ANDROID_DEBUG_SIGNINGKEY_BASE64`：debug.keystore 的 base64 内容
  - `ANDROID_DEBUG_ALIAS`：`androiddebugkey`
  - `ANDROID_DEBUG_KEYSTORE_PASSWORD`：`android`
  - `ANDROID_DEBUG_KEY_PASSWORD`：`android`
- [ ] 9.3 安全删除本地 debug.keystore 文件

## 10. GitHub Actions 验证（**手动执行**，有错误通知我）

- [ ] 10.1 在 GitHub 仓库页面进入 Actions 标签
- [ ] 10.2 手动触发 "Build LÖVE" 工作流（workflow_dispatch）
- [ ] 10.3 等待工作流完成
- [ ] 10.4 检查构建产物：
  - jylegend.love ✓
  - jylegend.zip ✓
  - jylegend.AppImage ✓
  - jylegend-debug-signed.apk ✓（仅 debug 版本）
- [ ] 10.5 如有错误，记录错误信息并通知我协助解决

## 11. 清理和完成

- [ ] 11.1 确认所有文件权限正确
- [ ] 11.2 确认所有平台使用统一的 UUID：`e6af0e53-2cbc-44df-b952-6a9bb2fe6b86`
