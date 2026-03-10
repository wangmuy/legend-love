# AGENTS.md - Coding Guidelines for Legend of Love

This file provides guidelines for AI agents working on the Legend of Love (金庸群侠传) Love2D project.

## Project Overview

A Lua/Love2D remake of the classic Chinese RPG "Legend of the Condor Heroes" (金庸群侠传).
- **Language**: Lua 5.1+ (Love2D framework)
- **Platform**: Cross-platform (Linux, macOS, Windows)
- **Encoding**: UTF-8

## Build/Run Commands

```bash
# Run the game
love src/

# Or from the game directory
cd src && love .

# Debug output goes to src/debug.txt
# Error output goes to src/error.txt
```

**Note**: There are no formal test suites or linting tools configured. Testing is done manually by running the game.

## Code Style Guidelines

### Naming Conventions

- **Global constants**: `UPPER_CASE` (e.g., `VK_ESCAPE`, `C_WHITE`, `GAME_MMAP`)
- **Configuration**: `CONFIG.*` prefix (e.g., `CONFIG.Width`, `CONFIG.Debug`)
- **Game constants**: `CC.*` prefix in `jyconst.lua` (e.g., `CC.ScreenW`, `CC.R_GRPFilename`)
- **Global game state**: `JY.*` prefix (e.g., `JY.Status`, `JY.Person`)
- **Functions**: `CamelCase` for public, `camelCase` or `snake_case` for local
- **Local variables**: `camelCase` or `snake_case`
- **File-local functions**: `local function FunctionName()`

### File Organization

```
src/
├── main.lua          # Entry point, Love2D callbacks
├── conf.lua          # Love2D configuration
├── config.lua        # Game configuration (CONFIG.*)
├── lib_love.lua      # Graphics/audio wrapper (lib.*)
├── lib_Byte.lua      # Binary data utilities (Byte.*)
├── lib_log.lua       # Logging utilities
├── luabit.lua        # Bit manipulation
├── script/
│   ├── jymain.lua    # Main game logic (~230KB)
│   ├── jyconst.lua   # Constants and game data
│   ├── jymodify.lua  # Modifications and extensions
│   ├── oldevent/     # Legacy event scripts
│   └── newevent/     # New event scripts
└── data/             # Game assets (grp, idx, 002 files)
```

### Function Conventions

```lua
-- Public function
function FunctionName(arg1, arg2)
    -- implementation
end

-- Local function
local function localFunctionName(arg1)
    -- implementation
end

-- Event function (oldevent)
function oldevent_XXX()
    instruct_1(1234, 0, 1);  -- Dialog
    instruct_0();              -- Clear screen
    instruct_3(...);           -- Modify event
end
```

### Key Patterns

1. **Game Loop**: Uses Love2D's `love.run()` with custom `JY_Main()`
2. **Event System**: Legacy events in `oldevent/` use `instruct_XXX()` functions
3. **Image Loading**: Custom GRP format with PNG fallback (see `LoadPic()`)
4. **Screen States**: `GAME_START`, `GAME_MMAP`, `GAME_SMAP`, `GAME_WMAP`

### Error Handling

- Use `lib.Debug()` for debug output (writes to debug.txt when `CONFIG.Debug=1`)
- Use `pcall()` for potentially failing operations (e.g., image loading)
- Check nil returns from file operations

### Graphics Conventions

- Use `lib.SetClip()` / `lib.FillColor()` for screen regions
- Use `lib.PicLoadCache()` for sprite rendering
- Use `Cls()` to clear screen before redraws
- Colors use `RGB(r,g,b)` helper returning packed integer

### Data Files

- **GRP files**: Custom image format (RLE + PNG hybrid)
- **IDX files**: Index files for GRP (4-byte offsets)
- **002 files**: Map data files
- All paths use `CONFIG.DataPath` prefix

### Comments

- Use `--` for single-line comments
- Use `--[[ ... --]]` for multi-line comments
- Chinese comments are common in this codebase
- Document function purpose with `--` above definition

### Indentation

- Use 4 spaces for indentation
- Align related assignments
- Keep line length reasonable (<120 chars)

## Important Notes

1. **No formal tests**: Test by running the game and checking debug.txt
2. **Debug mode**: Set `CONFIG.Debug=1` in config.lua for verbose logging
3. **Resource files**: Don't modify GRP/IDX files without understanding the format
4. **Love2D version**: Targets Love2D 11.x (check conf.lua for version)
5. **Encoding**: All source files are UTF-8

## Common Tasks

- **Add NPC dialog**: Create/edit files in `script/oldevent/`
- **Modify game data**: Edit `script/jyconst.lua`
- **Add new scene events**: Create files in `script/newevent/`
- **Debug rendering**: Check `src/debug.txt` after running
