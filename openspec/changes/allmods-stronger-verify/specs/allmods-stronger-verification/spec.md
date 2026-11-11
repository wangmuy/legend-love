# Spec: allmods-stronger-verification

> Change: `allmods-stronger-verify` · Slice: `allmods-slice3` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-STRV-1 ~ REQ-STRV-6

## REQ-STRV-1: `diff.md` 逐条审计

**Given** `game/mods/stronger/diff.md` 已生成
**When** 逐条审计其差异
**Then** 所有「MOD 独有」项全部有判定（预期 / 需修复 / 死文件），需修复项 = 0

## REQ-STRV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 21 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 回退原版 | 17 |
| 在 save/ | 3 |
| 死文件 | 1 |
| **Σ** | **21** |

**And** 不得笼统表述为「均回退原版」。

## REQ-STRV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | stronger | pascal | 区分度 |
|------|----------|--------|--------|
| 主角姓名 | 韋大寶 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3727 | 2977 | ✅ |

**And** 资源路径全部指向 `mods/stronger/`。

## REQ-STRV-4: `kysmod.ini` 的 `in_product` 判定修正

**Given** `mod_build.lua:879-882` 把 `kysmod.ini` 复制到 `data/`
**When** 运行审计
**Then**：

- 全部 20 个 MOD 的 `kysmod.ini` 记录 `in_product=true`
- 全部 `cc/*.txt` 记录 `in_product=false`（构建期词典，不进产物）
- 「必需但未进产物」矛盾数 = 0

**And** `checkInProduct` 实现 per-rule 覆盖：

```lua
if rule.in_product == false then return false end
if rule.in_product ~= true and not M.IN_PRODUCT_BY_CATEGORY[rule.category] then
    return false
end
```

**And** 新增回归测试：
- `testKysmodIniIsBuildInputButShipped`（20/20 `in_product=true`）
- `testCcDictsAreBuildInputAndNotShipped`（全部 `in_product=false`）

## REQ-STRV-5: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-STRV-6: 验证报告 + 回归测试

**Given** 审计完成
**When** 检查产出
**Then**：

- `reports/stronger-verify.md` 含结论摘要、逐条审计表、非基线值证据、零回归输出
- 新增 `testProductSavesNotDestroyedByTests`（`test_mod_boot.lua` 末位，
  断言全部 MOD 产物 `r1.grp` 与源逐字节一致）
- `test_mod_boot.lua` 的 save/load 测试实施备份 + 恢复
