# D 方案增强：Hint 占位（可选，推荐）

> 回答：D 方案下，原字符串区能否填充 `thing001` / `person001` 这类 hint，以便用 UPedit 打开时能看出这是占位值？

## 结论：**可以，而且推荐。** 这正好补上 D 唯一的短板。

好处：
1. **UPedit 可读** —— 打开 `ranger.grp` 时看到 `p0001`、`thing001`，一眼知道字符串已外置，不会误以为数据损坏
2. **零风险** —— hint 只写在**原字符串字段的字节范围内**，与数值字段范围完全不相交
3. **可追溯** —— hint 里的编号直接对应旁路表的 key，人工排查时能对上号
4. **保持文件大小不变** —— 仍写满定长字段，`ranger.idx` / 所有数值偏移一字不动

## 1. 写入范围安全性验证

hint 只覆盖字符串字段原本占用的字节，不触碰任何数值字段：

```
Person  记录（182 字节）
  [0,2)     代号                    数值
  [2,8)     头像/生命增长/无用       数值
  [8,18)    姓名    <- hint 写入
  [18,28)   外号    <- hint 写入
  [28,182)  性别…携带物品4数量        数值   <- 不碰

Thing   记录（190 字节）
  [0,2)     代号                    数值
  [2,22)    名      <- hint 写入
  [22,42)   名2     <- hint 写入
  [42,72)   说明    <- hint 写入
  [72,190)  练出武功…需要物品数量     数值   <- 不碰

Scene   记录（52 字节）
  [2,12)    名称    <- hint 写入
  [12,52)   出门音乐…跳转口Y2        数值   <- 不碰

Wugong  记录（136 字节）
  [2,12)    名称    <- hint 写入
  [12,136)  未知…10级杀伤内力        数值   <- 不碰
```

**写入范围与数值字段范围完全不相交 → 零风险。**

## 2. Hint 格式设计（已验证可放下）

全 20 MOD 各段最大记录数：Person 800、Thing 550、Scene 153、Wugong 398。

**必须预留 1 字节给 NUL 终止符**，所以 hint 长度必须 ≤ 字段宽度 − 1。

> ⚠ 初版设计 `person%04d`（如 `person0799`）恰好 10 字节 = 字段宽度，**没有 NUL 余量**。
> 虽然 `Byte.getstr` 读到 length 用尽也能正确返回，但太脆弱，已改为下面更短的格式。

**最终 hint 格式（已对全 20 MOD 验证：0 溢出）：**

| 字段 | 宽度 | 可用 | hint 格式 | 最长实例 | 含 NUL | 结果 |
|------|-----|------|----------|---------|-------|------|
| Person.姓名 | 10 | 9 | `p%04d` | `p0799` (5) | 6 | ✅ 余 4 |
| Person.外号 | 10 | 9 | `n%04d` | `n0799` (5) | 6 | ✅ 余 4 |
| Thing.名 | 20 | 19 | `thing%03d` | `thing549` (8) | 9 | ✅ 余 11 |
| Thing.名2 | 20 | 19 | `thing%03d` | `thing549` (8) | 9 | ✅ 余 11 |
| Thing.说明 | 30 | 29 | `desc:thing%03d` | `desc:thing549` (13) | 14 | ✅ 余 16 |
| Scene.名称 | 10 | 9 | `scene%03d` | `scene152` (8) | 9 | ✅ 余 1 |
| Wugong.名称 | 10 | 9 | `wugong%03d` | `wugong397` (9) | 10 | ⚠ 正好 |

`wugong397`（9 字节 + NUL = 10）是唯一恰好占满的；可改为 `w%03d`（4 字节，安全）。
**建议统一格式：** `p%04d` / `n%04d` / `thing%03d` / `desc:thing%03d` / `scene%03d` / `wugong%03d`，
并把溢出检查写进构建期断言。

### 实测结果（mingdong）

```
size: 223688 -> 223688  SAME
converted: 2724
Person rec0 姓名区: p0000.....
Person rec1 姓名区: p0001.....
Person rec1 外号区: n0001.....
Thing  rec0 名区  : thing000............
side.Person[1].Name = 胡斐
side.Person[1].Nick = 雪山飛狐
side.Thing[0].Name  = 大可樂
side.Thing[0].Desc  = 活性飲料，迅速補充你的體力
side.Scene[0].Name  = 胡斐居
side.Wugong[0].Name = 普通攻擊
```

**文件大小不变、hint 写入正确、旁路表保留完整繁体、零截断。**

## 3. 与旁路表的对应关系

hint 编号 = 旁路表 key 的记录下标，一一对应：

```lua
-- ranger.str 旁路表（UTF-8，去重）
Person[1].姓名 = "p0001"      <->  side.Person[1].姓名 = "胡斐"
Person[1].外号 = "n0001"      <->  side.Person[1].外号 = "雪山飛狐"
Thing[0].名    = "thing000"   <->  side.Thing[0].名    = "大可樂"
```

## 4. 运行时读取

`GetDataFromStruct` 遇到字符串字段（`t[2]==2`）时**优先查旁路表**；
查不到（例如原版/无 MOD 时）才回退到从缓冲区读 —— 保证零回归：

```lua
if t[2] == 2 then
    local v = SideStr and SideStr.get(segName, recordIndex, key)
    if v ~= nil then return v end
    return Byte.getstr(data, t[1]+offset, t[3])   -- 回退（原版行为）
end
```

## 5. 写入（`SetDataFromStruct`）

写字符串时**只更新旁路表**，不写缓冲区（缓冲区保持 hint 不变）：

```lua
if t[2] == 2 then
    if SideStr and SideStr.set(segName, recordIndex, key, v) then return end
    Byte.setstr(data, t[1]+offset, t[3], v)       -- 回退（原版行为）
end
```

## 6. 存档（`SaveRecord`）的处理

`SaveRecord` 把内存缓冲区写回 `rN.grp`。由于缓冲区里字符串是 hint，**存档必须同时保存旁路表**，否则读档会丢字符串。

两种做法：

| 做法 | 说明 | 评价 |
|------|------|------|
| **(a) 存档也存 UTF-8 + 旁路表** | `rN.grp` 保留 hint，另存 `rN.str`（旁路表） | ✅ 推荐；避免反复转码；读档逻辑与启动一致 |
| (b) 回写时把字符串转回 Big5 填进缓冲区 | `rN.grp` 自包含，无额外文件 | ⚠️ 需 Big5 编码器；主角改名场景 5 字恰好占满字段（可行但紧） |

推荐 **(a)**：读档与启动走**同一条**旁路表加载路径，逻辑统一，且不需要 Big5 编码器（只需解码器）。

## 7. 对 UPedit 的实际可见效果

用 UPedit 打开处理后的 `ranger.grp`：

```
人物 1:  姓名 = p0001         外号 = n0001
物品 0:  名 = thing000      名2 = thing000    说明 = desc:thing000
场景 0:  名称 = scene000
武功 0:  名称 = wugong000
```

一眼可辨：这些是占位符，真实字符串在旁路表里。

**代价**：UPedit 里**不能直接编辑**字符串（改了 hint 不影响游戏）。
但这本就不是我们的使用场景 —— 我们只**读** MOD，不产出供 UPedit 编辑的文件。

## 8. 完整方案（D + hint）小结

```
构建期：
  ranger.grp  ->  ranger.grp（字符串区替换为 hint，数值区一字不改）
              ->  ranger.str（UTF-8 旁路表，去重，key = 段/下标/字段）
              ->  ranger.idx（原样复制）

运行时：
  GetDataFromStruct(字符串字段) -> 查 ranger.str，miss 则回退缓冲区
  SetDataFromStruct(字符串字段) -> 写 ranger.str
  SaveRecord -> rN.grp（hint）+ rN.str（旁路表）
```

优点：**不截断、长度自由、数值零改动、UPedit 可辨、可 diff、体积小**。
