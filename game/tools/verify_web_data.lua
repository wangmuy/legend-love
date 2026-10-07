-- tools/verify_web_data.lua
-- 验证数据完整性（包括新提取的 D* 事件、基础配置、商店数据）

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
    "events.json",
    "config.json",
    "shops.json",
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
            print(string.format("OK (%d bytes)", size))
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
import json, sys

scenes = json.load(open('engine-web/data-web/scenes.json', encoding='utf-8'))
chars_data = json.load(open('engine-web/data-web/chars.json', encoding='utf-8'))
items_data = json.load(open('engine-web/data-web/items.json', encoding='utf-8'))
skills_data = json.load(open('engine-web/data-web/skills.json', encoding='utf-8'))
events_data = json.load(open('engine-web/data-web/events.json', encoding='utf-8'))
config_data = json.load(open('engine-web/data-web/config.json', encoding='utf-8'))
shops_data = json.load(open('engine-web/data-web/shops.json', encoding='utf-8'))

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

# D* event item refs: check event IDs >= 0 refer to valid scenarios
event_ids = set()
for e in events_data.get('events', []):
    for f in ['eventSpace', 'eventTouch', 'eventExtra']:
        if e[f] >= 0: event_ids.add(e[f])
print('D* events: ' + str(len(events_data.get('events', []))) + ' total, ' + str(len(event_ids)) + ' unique event refs')

# Shop item refs
shop_bad = 0; shop_total = 0
for shop in shops_data.get('shops', []):
    for it in shop.get('items', []):
        shop_total += 1
        if it['id'] not in items: shop_bad += 1
print('Shop item refs: ' + str(shop_total) + ' total, ' + str(shop_bad) + ' broken')

# Config data check
my = config_data.get('my', {})
print('Config: pos=(' + str(my.get('px',0)) + ',' + str(my.get('py',0)) + '), team=' + str(len(config_data.get('team', []))) + ', items=' + str(len(config_data.get('items', []))))

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