## 为什么

数据提取管线（Slice 1）已完成 5 个子 change，产出了 7 个 JSON 文件。但对二进制结构体的审计发现大量遗漏：
- 场景遗漏 4 个字段（19%）
- 角色遗漏 11 个字段（26%）
- 物品遗漏 49 个字段（91%）
- 技能遗漏 33 个字段（87%）
- D* 事件数据（alldef.grp）完全未提取
- 基础数据（ranger.grp 前 836 字节）完全未提取
- 商店数据完全未提取
- extract_scenes.lua 存在出口/跳转偏移 Bug

## 变更内容

- 修复 extract_scenes.lua 的出口/跳转偏移 Bug
- 补全所有遗漏字段（场景 4 + 角色 11 + 物品 49 + 技能 33 = 97 个字段）
- 新增 D* 事件数据提取（alldef.grp → events.json）
- 新增基础数据提取（ranger.grp 前 836 字节 → config.json）
- 新增商店数据提取（ranger.grp 偏移 136262 → shops.json）
- 更新 verify_web_data.lua 完整性检查
- 更新提取统一运行器 extract_web_data.lua
- 更新 data_loader.lua 和 index.js 加载新 JSON
- 更新 data-integrity 测试

## 能力

### 新增能力
- events.json：每个场景 200 个地砖事件（通行标志、事件触发 ID、坐标、贴图）
- config.json：基础游戏配置（主角位置、队伍、乘船状态等）
- shops.json：商店商品列表（5 个商店）

### 修改的能力
- scenes.json：新增 enterMusic、exitMusic、enterCondition、mapX2、mapY2
- chars.json：新增 11 个字段（头像、经验、武学常识等）
- items.json：新增所有 49 个属性/需求/合成字段
- skills.json：新增 33 个伤害/范围/等级字段
- verify_web_data.lua：补充所有新字段和文件的验证
- extract_web_data.lua：增加 D*/基础/商店提取步骤

## 影响

- 修改 tools/extract_scenes.lua：修复 Bug + 补全字段
- 修改 tools/extract_runtime.lua：补全字段
- 修改 tools/verify_web_data.lua：补充验证
- 修改 tools/extract_web_data.lua：增加新步骤
- 新增 tools/extract_events.lua：D* 事件提取
- 新增 tools/extract_base.lua：基础数据提取
- 新增 tools/extract_shops.lua：商店数据提取
- 修改 data_loader.lua：注册新 JSON
- 修改 index.js：加载新 JSON
- 修改 engine-web/tests/data-integrity.spec.js：新增测试