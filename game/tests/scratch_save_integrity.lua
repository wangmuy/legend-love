-- 一次性：全 MOD save/ 与源逐字节一致性（门禁用）
-- 用法: cd game && lua tests/scratch_save_integrity.lua
--
-- 跨平台：目录枚举走 fs_compat（Windows 下 io.popen 走 cmd.exe，
-- `ls -1` / `2>/dev/null` 都不可用）。
package.path = "./?.lua;" .. package.path
local Fs = require("framework.fs_compat")

local mismatches, checked = 0, 0
for _, slug in ipairs(Fs.listDirectory("mods")) do
    if slug:sub(1, 1) ~= "_" and Fs.directoryExists("mods/" .. slug) then
        local srcDir = "../reference/allmods/kys-" .. slug .. "/save/"
        for _, name in ipairs(Fs.listDirectory(srcDir)) do
            local prod = "mods/" .. slug .. "/save/" .. name
            local a, b = Fs.readFile(prod), Fs.readFile(srcDir .. name)
            if a and b then
                checked = checked + 1
                if a ~= b then
                    mismatches = mismatches + 1
                    print("MISMATCH mods/" .. slug .. "/save/" .. name)
                end
            end
        end
    end
end
print(string.format("save_integrity: checked=%d mismatches=%d", checked, mismatches))
