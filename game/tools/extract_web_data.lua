-- tools/extract_web_data.lua
-- 一键提取所有 Web MUD 数据

print("Extracting Web MUD data...")
print("")

-- 1. Dialogues
print("[1/5] Extracting dialogues...")
dofile("tools/extract_dialogues.lua")

-- 2. Scenes
print("[2/5] Extracting scenes...")
local extract_scenes = dofile("tools/extract_scenes.lua")
extract_scenes.run("data", "data-web/scenes.json")

-- 3. Runtime data (chars, items, skills)
print("[3/5] Extracting runtime data (chars/items/skills)...")
dofile("tools/extract_runtime.lua")

-- 4. Entrances
print("[4/5] Extracting entrances...")
dofile("tools/extract_entrances.lua")

-- 5. Encounters
print("[5/5] Extracting encounters...")
dofile("tools/extract_encounters.lua")

print("")
print("All extractions complete.")
print("Output: data-web/*.json")