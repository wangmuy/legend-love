# 战斗实机截图

由 `main.lua` 的调试参数自动生成（battle-extensibility 验收）：

```bash
# 战斗开始画面
lovec game --shot=battle --frame=250 --battle=4

# 完整战斗（失败结算）
lovec game --shot=s3 --frame=1400 --battle=4 \
      --keys=return,return,down,down,down,down,down,down,return
```

截图落在 LÖVE 的 save 目录：
`%APPDATA%/LOVE/wangmuy.love2d.jygame/`

## 文件

| 文件 | 内容 | 证明了什么 |
|------|------|-----------|
| `battle-start.png` | 战斗地图 + 9 项战斗菜单 + 双方人物 + 头像血条 | 战斗初始化 + 绘制链全部正确 |
| `battle-settlement-failure.png` | 「战斗失败」提示框 + 回主地图 | 战斗能跑到结束判定 + 结算 + 失败语义 |

**为什么这两张重要**：这两张是唯一"自动化替代不了"的验证，
它们暴露了 5 个只在实机可见的回归（见 commit `ebf81ac` / `508da14`）：

1. 协程搬到 `script/battle/` 后成了 nil upvalue（战斗一开就崩）
2. `lib_love.lua` 的 `PicLoadCache` 少写 `local`（历史遗留）
3. `SpriteAtlas` 与 `lib.PicFileCache` 两套贴图系统不互通
4. `--keys` 传数字是空操作（我的调试工具坏了）
5. `PicGetXY` 只判一层空（历史遗留）
