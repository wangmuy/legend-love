-- tools/verify_web_data.lua
-- 验证数据完整性

local function fileSize(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local dataDir = "engine-web/data-web"

print("")
print("=== Web MUD Data Verification ===")
print("")

local files = {
    "dialogues.json",
    "scenes.json",
    "chars.json",
    "items.json",
    "skills.json",
    "entrances.json",
    "wmap.json",
}

local totalSize = 0
local allOk = true
for _, name in ipairs(files) do
    local path = dataDir .. "/" .. name
    local size = fileSize(path)
    io.write("[" .. name .. "] ")
    if size and size > 0 then
        local content = readFile(path)
        local trimmed = content:match("^%s*(.-)%s*$")
        local startsWithBrace = trimmed:sub(1,1) == "{"
        local endsWithBrace = trimmed:sub(-1,-1) == "}"
        if startsWithBrace and endsWithBrace then
            print("OK (" .. size .. " bytes)")
        else
            print("INVALID (not JSON-like structure)")
            allOk = false
        end
        totalSize = totalSize + size
    else
        print("NOT FOUND")
        allOk = false
    end
end

print("")
print(string.format("Total size: %d bytes (%.1f MB)", totalSize, totalSize / 1024 / 1024))
if totalSize <= 15 * 1024 * 1024 then
    print("Size check: OK (<= 15MB)")
else
    print("Size check: FAILED (> 15MB)")
    allOk = false
end

print("")
print("=== Cross-references ===")
-- Validate with python3
local cmd = [[python3 -c "
import json
scenes = json.load(open('engine-web/data-web/scenes.json', encoding='utf-8'))
chars_data = json.load(open('engine-web/data-web/chars.json', encoding='utf-8'))
items_data = json.load(open('engine-web/data-web/items.json', encoding='utf-8'))
skills_data = json.load(open('engine-web/data-web/skills.json', encoding='utf-8'))
chars = {c['id']: c for c in chars_data.get('chars', [])}
items = {i['id']: i for i in items_data.get('items', [])}
skills = {s['id']: s for s in skills_data.get('skills', [])}
bad_npc = 0; total_npc = 0; bad_item = 0; total_item = 0
for s in scenes.get('scenes', []):
    for n in s.get('npc', []):
        total_npc += 1
        if n['id'] not in chars: bad_npc += 1
    for i in s.get('items', []):
        total_item += 1
        if i['id'] not in items: bad_item += 1
print('NPC refs: ' + str(total_npc) + ' total, ' + str(bad_npc) + ' broken')
print('Item refs: ' + str(total_item) + ' total, ' + str(bad_item) + ' broken')
print('Chars: ' + str(len(chars)))
print('Items: ' + str(len(items)))
print('Skills: ' + str(len(skills)))
"]]
local f = io.popen(cmd, "r")
local result = f:read("*a")
f:close()
for line in result:gmatch("[^\r\n]+") do
    print("  " .. line)
    if line:match("broken") and not line:match("0 broken") then
        allOk = false
    end
end

print("")
if allOk then
    print("Result: ALL CHECKS PASSED")
else
    print("Result: SOME CHECKS FAILED")
end
print("")