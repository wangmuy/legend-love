-- 一次性：全 MOD save/ 与源逐字节一致性（门禁用）
-- 用法: cd game && lua tests/scratch_save_integrity.lua
local p = io.popen("ls -d mods/*/ 2>/dev/null")
local mismatches, checked = 0, 0
for d in p:lines() do
    local slug = d:match("mods/([^/]+)/")
    if slug and slug:sub(1, 1) ~= "_" then
        local lp = io.popen("ls ../reference/allmods/kys-" .. slug .. "/save/ 2>/dev/null")
        if lp then
            for name in lp:lines() do
                local prod, srcc = d .. "save/" .. name, "../reference/allmods/kys-" .. slug .. "/save/" .. name
                local fp, fs = io.open(prod, "rb"), io.open(srcc, "rb")
                if fp and fs then
                    checked = checked + 1
                    if fp:read("*a") ~= fs:read("*a") then
                        mismatches = mismatches + 1
                        print("MISMATCH " .. d .. name)
                    end
                    fp:close()
                    fs:close()
                end
            end
        end
    end
end
print(string.format("save_integrity: checked=%d mismatches=%d", checked, mismatches))
