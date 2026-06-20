## 1. 目录结构重构

- [x] 1.1 将 `src/` 目录重命名为 `game/`
- [x] 1.2 验证 `game/` 目录包含所有必要文件（main.lua、conf.lua、script/、data/、pic/、sound/、tests/）
- [x] 1.3 确保没有遗漏任何子目录或文件

## 2. 构建配置

- [x] 2.1 创建 `game/product.env` 文件

## 3. conf.lua 更新

- [x] 3.1 备份现有 `game/conf.lua`
- [x] 3.2 合并模板的调试支持代码（lldebugger 检测和启动）
- [x] 3.3 添加 product.env 读取逻辑
- [x] 3.4 更新 `t.identity` 从 product.env 读取 PRODUCT_ID
- [x] 3.5 保留现有窗口配置（CONFIG.Width/Height、CONFIG.FullScreen）
- [x] 3.6 保留中文标题设置
- [x] 3.7 验证 conf.lua 语法正确

## 4. CI/CD 文件复制

- [x] 4.1 创建 `.github/workflows/` 目录
- [x] 4.2 复制 `~/project/bootstrap-love2d-project/.github/workflows/build.yml` 到 `.github/workflows/`
- [x] 4.3 创建 `.github/actions/` 目录
- [x] 4.4 复制所有 actions

## 5. 构建脚本

- [x] 5.1-5.4 构建脚本

## 6. 游戏主循环兼容性修复

- [x] 6.1-6.6 全部完成

## 7. 本地测试

- [ ] 7.5 运行 `/home/woodfish/bin/love.AppImage builds/1/jylegend.love` 验证游戏启动（需完成构建后手动执行）

## 8. Git 推送

- [ ] 8.4 推送变更到 GitHub（当前分支 love2d-event-driven）

## 9. Android 签名

- [ ] 9.1-9.3 Android keystore 生成与配置（需 GitHub Secrets 设置）

## 10. GitHub Actions 触发

- [ ] 10.1-10.5 触发并验证构建

## 11. 最终确认

- [x] 11.1 确认所有文件权限正确
- [x] 11.2 确认所有平台使用统一的 UUID
