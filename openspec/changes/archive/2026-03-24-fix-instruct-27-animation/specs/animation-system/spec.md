## ADDED Requirements

### Requirement: 全局动画状态支持
系统 SHALL 支持通过全局状态 `JY.AnimationMyPic` 覆盖主角贴图，用于动画显示。

#### Scenario: 设置动画贴图
- **WHEN** `instruct_27` 设置 `JY.AnimationMyPic = 3445`
- **AND** `DrawSMap` 被调用
- **THEN** `DrawSMap` 使用 `JY.AnimationMyPic` 作为主角贴图

#### Scenario: 清除动画贴图
- **WHEN** `instruct_27` 动画结束，清除 `JY.AnimationMyPic`
- **AND** `DrawSMap` 被调用
- **THEN** `DrawSMap` 使用 `JY.MyPic` 作为主角贴图

### Requirement: DrawSMap支持动画贴图覆盖
`DrawSMap` 函数 SHALL 优先使用 `JY.AnimationMyPic`（如果存在），否则使用 `JY.MyPic`。

#### Scenario: 动画期间绘制
- **WHEN** `JY.AnimationMyPic` 不为 nil
- **AND** `DrawSMap` 绘制主角
- **THEN** 使用 `JY.AnimationMyPic * 2` 作为贴图编号

#### Scenario: 非动画期间绘制
- **WHEN** `JY.AnimationMyPic` 为 nil
- **AND** `DrawSMap` 绘制主角
- **THEN** 使用 `JY.MyPic * 2` 作为贴图编号

## MODIFIED Requirements

### Requirement: instruct_27使用全局动画状态
`instruct_27` 函数 SHALL 使用 `JY.AnimationMyPic` 传递动画贴图，而不是直接修改 `JY.MyPic`。

#### Scenario: 播放主角动画
- **WHEN** `instruct_27(id=-1, startpic=6890, endpic=6932)` 被调用
- **THEN** 每帧设置 `JY.AnimationMyPic = i/2`
- **AND** 等待 `CC.AnimationFrame` 毫秒
- **AND** 动画结束后清除 `JY.AnimationMyPic`
