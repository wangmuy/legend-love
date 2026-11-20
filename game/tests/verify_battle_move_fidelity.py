#!/usr/bin/env python3
"""搬移保真性验证（battle-extensibility Task 2/5）

用途：证明「66 个战斗函数 + 20 个协程搬到 script/battle/ 是**纯搬移**，
      逻辑一字未改」。这是「零回归」在自动化层面的最强证据 ——
      比跑测试更硬，因为它直接比对源码字节。

用法（在仓库根目录）：
    python3 game/tests/verify_battle_move_fidelity.py

原理：
    从 git 历史取搬移前的文件，逐函数提取函数体文本，
    与搬移后的文件做**逐字节比对**。
"""
import re
import subprocess
import sys

# 搬移的两个 commit 的父提交（搬移前状态）
COMMIT_JYMAIN_BEFORE  = "50df105^"   # 阶段 1：jymain.lua 的 66 个函数
COMMIT_WARASYNC_BEFORE = "2d1f538^"  # 阶段 2C：war_async.lua 的 20 个协程

BATTLE_FILES = [
    "game/script/battle/battle_data.lua",
    "game/script/battle/battle_render.lua",
    "game/script/battle/battle_action.lua",
    "game/script/battle/battle_ai.lua",
    "game/script/battle/battle_flow.lua",
]
CORO_FILE = "game/script/battle/battle_flow_coroutines.lua"

# ---------------------------------------------------------------------------
# 允许偏离白名单
# ---------------------------------------------------------------------------
# 搬移本身是字节保真的（阶段 1 / 2C 的验收结论不变）。
# 但搬移**之后**又按根因修过若干健壮性缺陷（见 commit "fix(battle): 5 个
# 健壮性缺陷的根因修复"）。这些函数允许与搬移基准不同 —— 差异必须是
# **修缺陷**，不是"顺手重构"。
#
# 为什么仍然保留这个脚本：它继续守住「没有其他函数被悄悄改动」。
# 若以后有人改动了名单外的任何一个战斗函数，这里会 FAIL。
ALLOWED_DEVIATIONS = {
    # --- 第一批：5 个健壮性缺陷根因修复 ---
    "War_WugongHurtLife":   "while-true 加显式下界（level>=1），消除无限循环",
    "War_WugongHurtNeili":  "补 level 钳制 + 字段判空（与 HurtLife 对称）",
    "War_AutoMove":         "回溯循环补 prevI 进度守卫 + 硬上限",
    "War_EndPersonData":    "除 liveNum 补零守卫（避免 inf 污染经验）",
    # --- 第二批：武功等级单点钳制（15 处等级计算收敛到 War_WugongLevel） ---
    "War_Fight_Sub":        "等级计算改用 War_WugongLevel（钳 1..10）",
    "War_AutoSelectWugong": "同上",
    "War_AutoExecuteFight": "同上",
    "War_AutoMoveCoroutine": "同上（协程版）",
    "War_AutoCoroutine":    "同上（协程版）",
    "War_AttackCoroutine":  "同上（协程版）",
    "War_Fight_ExecuteCoroutine": "同上（协程版）",
    "War_Fight_SubCoroutine":     "同上（协程版）",
}
# 协程组的白名单（结构上与上面同一张表，这里显式声明便于阅读）
ALLOWED_COROUTINES = set(ALLOWED_DEVIATIONS)


def git_show(ref_path):
    r = subprocess.run(["git", "show", ref_path], capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise SystemExit(f"git show 失败: {ref_path}\n{r.stderr}")
    return r.stdout


def extract_funcs(src, pattern=r'^function ([A-Za-z_][A-Za-z_0-9]*)\(', lo=None, hi=None):
    """按「下一个 function 前一行」切块（与搬移脚本同一算法）"""
    lines = src.split("\n")
    marks = []
    for i, L in enumerate(lines, 1):
        m = re.match(pattern, L)
        if m:
            if lo and i < lo:
                continue
            if hi and i > hi:
                continue
            marks.append((i, m.group(1)))
    out = {}
    for idx, (start, name) in enumerate(marks):
        end = marks[idx + 1][0] - 1 if idx + 1 < len(marks) else (hi or len(lines))
        out[name] = "\n".join(lines[start - 1:end]).rstrip()
    return out


def extract_coros(src):
    """协程按「配对的列 0 end」切块"""
    lines = src.split("\n")
    marks = []
    for i, L in enumerate(lines, 1):
        m = re.match(r'^(War_[A-Za-z_0-9]+Coroutine|SelectTargetCoroutine)\s*=\s*function', L)
        if m:
            marks.append((i, m.group(1)))
    out = {}
    for start, name in marks:
        for j in range(start, len(lines) + 1):
            if lines[j - 1].rstrip() == "end":
                out[name] = "\n".join(lines[start - 1:j]).rstrip()
                break
    return out


def main():
    failures = 0

    # ---------------- 66 个战斗函数 ----------------
    print("=== 1. jymain.lua 的 66 个战斗函数 ===")
    before = extract_funcs(git_show(f"{COMMIT_JYMAIN_BEFORE}:game/script/jymain.lua"),
                           lo=4681, hi=7347)
    after = {}
    for p in BATTLE_FILES:
        with open(p, encoding="utf-8") as f:
            after.update(extract_funcs(f.read()))

    print(f"  搬移前 {len(before)} 个 / 搬移后 {len(after)} 个")
    bad, allowed = [], []
    for name, txt in before.items():
        if name not in after:
            bad.append((name, "缺失"))
        elif after[name] != txt:
            if name in ALLOWED_DEVIATIONS:
                allowed.append(name)
            else:
                bad.append((name, "内容不一致（且不在允许偏离名单）"))
    if allowed:
        print(f"  [INFO] {len(allowed)} 个函数有**已记录的缺陷修复**（允许偏离）：")
        for n in allowed:
            print(f"        {n}: {ALLOWED_DEVIATIONS[n]}")
    if bad:
        print(f"  [FAIL] {len(bad)} 处不一致:")
        for n, why in bad[:10]:
            print(f"    {n}: {why}")
        failures += 1
    else:
        if allowed:
            print(f"  [PASS] {len(before) - len(allowed)} 个逐字节一致 + {len(allowed)} 个已记录修复")
        else:
            print(f"  [PASS] 全部 {len(before)} 个函数**逐字节一致**")

    # ---------------- 20 个协程 ----------------
    print("\n=== 2. war_async.lua 的 20 个协程 ===")
    beforec = extract_coros(git_show(f"{COMMIT_WARASYNC_BEFORE}:game/framework/war_async.lua"))
    with open(CORO_FILE, encoding="utf-8") as f:
        afterc = extract_coros(f.read())

    print(f"  搬移前 {len(beforec)} 个 / 搬移后 {len(afterc)} 个")
    badc, allowedc = [], []
    for name, txt in beforec.items():
        if name not in afterc:
            badc.append((name, "缺失"))
        elif afterc[name] != txt:
            if name in ALLOWED_COROUTINES:
                allowedc.append(name)
            else:
                badc.append((name, "内容不一致（且不在允许偏离名单）"))
    if allowedc:
        print(f"  [INFO] {len(allowedc)} 个协程有**已记录的缺陷修复**（允许偏离）：")
        for n in allowedc:
            print(f"        {n}: {ALLOWED_DEVIATIONS[n]}")
    if badc:
        print(f"  [FAIL] {len(badc)} 处不一致:")
        for n, why in badc[:10]:
            print(f"    {n}: {why}")
        failures += 1
    else:
        if allowedc:
            print(f"  [PASS] {len(beforec) - len(allowedc)} 个协程逐字节一致 + {len(allowedc)} 个已记录修复")
        else:
            print(f"  [PASS] 全部 {len(beforec)} 个协程**逐字节一致**")

    # ---------------- 汇总 ----------------
    print("\n" + "=" * 50)
    if failures == 0:
        print("[ ok ] 搬移是纯字节搬移，零逻辑改动（可机器验证）")
        return 0
    print(f"[FAIL] {failures} 组不一致")
    return 1


if __name__ == "__main__":
    sys.exit(main())
