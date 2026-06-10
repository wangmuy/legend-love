-- tools/extract_web_data.lua
-- 一键提取所有 Web MUD 数据
-- 运行: cd game && lua tools/extract_web_data.lua

print("Extracting Web MUD data...")
print("")

-- 1. Dialogues
print("[1/8] Extracting dialogues...")
dofile("tools/extract_dialogues.lua")

-- 2. Scenes
print("[2/8] Extracting scenes...")
local extract_scenes = dofile("tools/extract_scenes.lua")
extract_scenes.run("data", "engine-web/data-web/scenes.json")

-- 3. Runtime data (chars, items, skills)
print("[3/8] Extracting runtime data (chars/items/skills)...")
dofile("tools/extract_runtime.lua")

-- 4. Entrances
print("[4/8] Extracting entrances...")
dofile("tools/extract_entrances.lua")

-- 5. Encounters
print("[5/8] Extracting encounters...")
dofile("tools/extract_encounters.lua")

-- 6. D* events
print("[6/8] Extracting D* events (alldef.grp)...")
dofile("tools/extract_events.lua")

-- 7. Base config
print("[7/8] Extracting base config (ranger.grp header)...")
dofile("tools/extract_base.lua")

-- 8. Shops
print("[8/8] Extracting shop data...")
dofile("tools/extract_shops.lua")

-- 9. Filter unnecessary fields
print("[9/9] Filtering unnecessary fields (graphics/sound)...")
os.execute("python3 tools/filter_web_data.py")

print("")
print("All extractions complete.")
print("Output: engine-web/data-web/*.json")