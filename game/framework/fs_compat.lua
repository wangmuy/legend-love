-- fs_compat.lua
-- 跨平台文件系统原语（Windows / Linux / macOS）
--
-- 定位：**仅在「无 love.filesystem」的环境**下使用，即单元测试（纯 Lua）与
-- 开发工具（tools/）。游戏运行时（game/framework、game/script）必须走
-- EngineAPI.file → love.filesystem，否则 Android / .love 打包下路径不可见。
--
-- 为什么需要这个模块：
--   历史上测试和工具有大量硬编码 POSIX 假设（`test -d`、`ls -1`、
--   `find`、`md5sum`、`/tmp`、`mkdir -p`）。Windows 上 `io.popen` 走
--   cmd.exe，这些命令全部不存在，导致整套 MOD 相关测试在 Windows 上
--   静默失败（返回 0 / false，而不是报错）。
--
-- 约束：LÖVE 11.x 用 LuaJIT（Lua 5.1），所以本模块必须 5.1 兼容
--       （不用 goto、不用 // 整除、不用 5.2+ 语法）。

local Fs = {}

-- package.config 首字符在 Windows 上是 "\"，POSIX 上是 "/"
Fs.isWindows = package.config:sub(1, 1) == "\\"

-- ---------------------------------------------------------------- 内部工具

-- 执行 shell 命令并返回完整 stdout（失败返回空串）。
local function capture(cmd)
    local p = io.popen(cmd)
    if not p then return "" end
    local out = p:read("*a")
    p:close()
    return out or ""
end

-- 把 stdout 按行切分为数组（丢弃空行）
local function splitLines(text)
    local lines = {}
    for line in (text or ""):gmatch("[^\r\n]+") do
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

-- 单引号/双引号保护（POSIX 用单引号，Windows 用双引号）
local function quotePosix(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function quoteWin(s)
    return '"' .. tostring(s):gsub('"', '""') .. '"'
end

-- 对外暴露引号工具（工具层拼 shell 命令时需要一致的保护策略）
Fs.quotePosix = quotePosix
Fs.quoteWin = quoteWin

-- 去掉结尾的路径分隔符（`dir\` / `dir/` → `dir`），根目录除外
local function stripTrailingSep(path)
    path = tostring(path)
    local stripped = path:gsub("[/\\]+$", "")
    if stripped == "" then return path end
    return stripped
end

-- Windows：把控制台输出代码页切成系统 ANSI 代码页（ACP）。
--
-- 仅在「需要把含非 ASCII 字符的路径交给 cmd 内建命令」时使用
-- （mkdir / rmdir / if exist）。目录列举已改用 `cmd /u` + UTF-16 解码，
-- 不依赖这里。
local ansiConsoleReady = false

local function ansiCodePage()
    local raw = capture('reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Nls\\CodePage" /v ACP 2>NUL')
    return raw:match("ACP%s+REG_SZ%s+(%d+)")
end

local function ensureAnsiConsole()
    if ansiConsoleReady then return end
    ansiConsoleReady = true
    if not Fs.isWindows then return end
    local acp = ansiCodePage()
    if not acp or acp == "" then return end
    capture("chcp " .. acp .. " >NUL")
end

-- UTF-16LE → UTF-8（含代理对）。用于解码 `cmd /u` 的输出。
--
-- 为什么用 `cmd /u` 列举目录：
--   `dir /b` 的输出编码 = 控制台输出代码页，而 Lua 的 io.open 按系统 ACP
--   解释路径。两者不一致时会出现「名字列得出来但打不开」（实测 UTF-8 控制台
--   下 335 个文件里 16 个失败，且列出的名字也不是合法 UTF-8，无法与源码里的
--   中文字面量比较）。
--   `cmd /u` 让内建命令直接输出 UTF-16LE，我们在 Lua 里解成 UTF-8：
--   ✅ 名字是标准 UTF-8，可与源码字面量比较、可排序、可写日志；
--   ⚠️ 这类路径不能再用 io.open —— 见 Fs.readFile 的 Win32 桥接。
local function utf16leToUtf8(s)
    local out = {}
    local i, n = 1, #s
    while i + 1 <= n do
        local lo, hi = s:byte(i), s:byte(i + 1)
        local cp = lo + hi * 256
        i = i + 2
        if cp >= 0xD800 and cp <= 0xDBFF and i + 1 <= n then
            local low = s:byte(i) + s:byte(i + 1) * 256
            if low >= 0xDC00 and low <= 0xDFFF then
                cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                i = i + 2
            end
        end
        if cp == 13 or cp == 10 then
            out[#out + 1] = "\n"
        elseif cp < 0x80 then
            out[#out + 1] = string.char(cp)
        elseif cp < 0x800 then
            out[#out + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
        elseif cp < 0x10000 then
            out[#out + 1] = string.char(0xE0 + math.floor(cp / 4096),
                0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
        else
            out[#out + 1] = string.char(0xF0 + math.floor(cp / 262144),
                0x80 + math.floor(cp / 4096) % 64,
                0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
        end
    end
    return table.concat(out)
end

-- 路径是否含非 ASCII 字节（需要走 Win32 桥接）
local function hasNonAscii(s)
    return s:find("[\128-\255]") ~= nil
end

-- ---------------------------------------------------------------- 目录

-- 目录列举缓存：{ [path] = { {name=..., dir=bool}, ... } }
-- 必要性：MOD 审计要遍历 11000+ 文件，若每次判类型都 spawn 一个 shell，
-- 整套测试会从几秒退化到几分钟。一次列举拿到「名字 + 是否目录」后缓存复用。
local listCache = {}

local function normalizeDirKey(path)
    local p = stripTrailingSep(tostring(path))
    p = p:gsub("^\\./", "")
    p = p:gsub("\\", "/")
    return p
end

--- 清理缓存（测试之间切换工作目录时调用）。
function Fs.clearCache()
    listCache = {}
end

--- 失效某个路径的缓存（自身 + 全部子孙 + 父目录中该条目的类型）。
-- 任何「改动目录内容」的操作（建/删目录、写文件）都必须调用，
-- 否则「删了目录但缓存还认为存在」会让后续 mkdir 提前返回、写文件失败。
-- 必须连**子孙**一起清：删掉 mods/Dragon 后，mods/Dragon/music 的旧列举
-- 仍然存在，会让 directoryExists("mods/Dragon/music") 误报 true。
-- @param path string
function Fs.invalidate(path)
    local key = normalizeDirKey(path)
    listCache[key] = nil
    -- 清理子孙：所有以 key .. "/" 开头的缓存键
    local prefix = key .. "/"
    for k in pairs(listCache) do
        if k:sub(1, #prefix) == prefix then
            listCache[k] = nil
        end
    end
    -- 清理父目录（其中该条目的类型信息已过期）
    local parent = key:match("^(.*)/[^/]+$")
    if parent ~= nil then
        if parent == "" then parent = "." end
        listCache[parent] = nil
    end
end

--- 列举目录条目，每项含名字与「是否目录」。
-- @param path string 目录路径
-- @return table { {name=string, dir=boolean}, ... }（顺序不保证；目录不存在返回空表）
function Fs.listEntries(path)
    local key = normalizeDirKey(path)
    if listCache[key] then return listCache[key] end

    local entries = {}
    if Fs.isWindows then
        -- 两次列举：目录 / 非目录，都用 `cmd /u` 输出 UTF-16LE 再解码。
        -- （原因见 utf16leToUtf8 的注释：编码必须与系统 ACP 一致才能后续打开。）
        local dirOut = utf16leToUtf8(capture('cmd /u /c dir /b /a:d ' ..
            quoteWin(key) .. ' 2>NUL'))
        for _, name in ipairs(splitLines(dirOut)) do
            entries[#entries + 1] = { name = name, dir = true }
        end
        local fileOut = utf16leToUtf8(capture('cmd /u /c dir /b /a-d ' ..
            quoteWin(key) .. ' 2>NUL'))
        for _, name in ipairs(splitLines(fileOut)) do
            entries[#entries + 1] = { name = name, dir = false }
        end
    else
        -- `ls -1p` 给目录追加 "/"，一次调用同时拿到名字与类型
        local out = capture('ls -1p ' .. quotePosix(key) .. ' 2>/dev/null')
        for _, line in ipairs(splitLines(out)) do
            local name = line
            local isDir = false
            if name:sub(-1) == "/" then
                name = name:sub(1, -2)
                isDir = true
            end
            if name ~= "" and name ~= "." and name ~= ".." then
                entries[#entries + 1] = { name = name, dir = isDir }
            end
        end
    end

    listCache[key] = entries
    return entries
end

--- 判断目录是否存在。
-- 先查父目录缓存（零进程），未命中再退回显式探测。
-- @param path string 目录路径
-- @return boolean
function Fs.directoryExists(path)
    if path == nil or path == "" then return false end
    local key = normalizeDirKey(path)

    -- 1) 自身已被列举过 → 必然是目录
    if listCache[key] then return true end

    -- 2) 父目录已缓存 → 直接查类型（不 spawn 任何进程）
    local parent, leaf = key:match("^(.*)/([^/]+)$")
    if parent ~= nil and leaf ~= nil then
        if parent == "" then parent = "." end
        if listCache[parent] then
            for _, e in ipairs(listCache[parent]) do
                if e.name == leaf then return e.dir end
            end
            return false
        end
    end

    -- 3) Windows：`if exist "dir\"`（带尾分隔符才只匹配目录）
    if Fs.isWindows then
        if hasNonAscii(key) then
            ensureAnsiConsole()
        end
        local out = capture('if exist ' .. quoteWin(key .. "\\") ..
            ' (echo 1) else (echo 0)')
        return out:find("1", 1, true) ~= nil
    end

    -- 4) POSIX：test -d
    local out = capture('test -d ' .. quotePosix(key) .. ' && echo 1 || echo 0')
    return out:find("1", 1, true) ~= nil
end

--- 列出目录下的条目名（不含 `.` / `..`，仅名字不带路径）。
-- 目录不存在或列举失败时返回空表。
-- @param path string 目录路径
-- @return table 名字数组
function Fs.listDirectory(path)
    local names = {}
    for _, e in ipairs(Fs.listEntries(path)) do
        names[#names + 1] = e.name
    end
    return names
end

--- 创建目录（含中间层级）。目标已存在时视为成功。
-- @param path string 目录路径
-- @return boolean 是否成功
function Fs.makeDirectory(path)
    path = stripTrailingSep(path)
    if path == "" or path == "." then return true end
    if Fs.directoryExists(path) then return true end
    if Fs.isWindows then
        -- cmd 的 mkdir 会自动创建中间层级
        capture('mkdir ' .. quoteWin(path) .. ' 2>NUL')
    else
        capture('mkdir -p ' .. quotePosix(path) .. ' 2>/dev/null')
    end
    Fs.invalidate(path)
    return Fs.directoryExists(path)
end

--- 递归删除目录（不存在时视为成功）。
-- @param path string 目录路径
-- @return boolean
function Fs.removeTree(path)
    path = stripTrailingSep(path)
    if path == "" then return false end
    if Fs.isWindows then
        capture('rmdir /s /q ' .. quoteWin(path) .. ' 2>NUL')
    else
        capture('rm -rf ' .. quotePosix(path) .. ' 2>/dev/null')
    end
    Fs.invalidate(path)
    return not Fs.directoryExists(path)
end

-- ---------------------------------------------------------------- 文件

-- Windows 非 ASCII 路径桥接
--
-- 为什么需要：Windows 版 PUC-Lua 的 io.open 用 `fopen`，参数按**系统 ACP**
-- 编码解释。我们的源码/路径字面量是 UTF-8，一旦含中文（如 MOD 源里的
-- "match - 复制.bin"、"不使用.png"），io.open 就必然失败 —— 这不是本仓库
-- 能修的（要用 Win32 CreateFileW 或 Lua 的 UTF-8 补丁）。
--
-- 做法：把路径写进一个 **UTF-8 BOM 的 .ps1**，交给 powershell -File 执行。
-- PowerShell 看到 BOM 就按 UTF-8 解析脚本，内部 API 全是 Unicode，所以
-- 中文路径与内容都能正确处理。每次调用启动一个 powershell 进程（约 200ms），
-- 因此只对**确实含非 ASCII** 的路径启用，纯 ASCII 路径零开销。

local winBridgeSeq = 0

--- 执行一段 PowerShell 脚本（UTF-8 BOM 写入临时 .ps1，避免中文被误解码）。
-- @param script string PowerShell 脚本正文
-- @param marker string 脚本成功时要写出的标记文件路径
-- @return boolean 是否成功（标记文件存在）
-- @return string 合并输出（便于诊断）
local function winRunScript(script, marker)
    winBridgeSeq = winBridgeSeq + 1
    local base = Fs.tempPath("fs_compat_" .. winBridgeSeq)
    local ps1 = base .. ".ps1"

    local f = io.open(ps1, "wb")
    if not f then return false, "" end
    f:write("\239\187\191")           -- UTF-8 BOM：PowerShell 5.1 靠它识别 UTF-8
    f:write(script)
    f:write("\n")
    f:close()

    -- 把 PowerShell 的 $LOCALAPPDATA 指到临时目录：
    -- PowerShell 启动时会写 ModuleAnalysisCache（$LOCALAPPDATA\Microsoft\...）。
    -- 该变量缺失/为空时它会退化到**当前工作目录**，在仓库里留下一个
    -- Microsoft/ 目录（实测 mod_audit 跑完就会多出这个目录）。
    -- 同时不能改 CWD —— 调用方传进来的相对路径要靠 CWD 解析。
    local tmpWork = Fs.tempDir()
    local p = io.popen('set "LOCALAPPDATA=' .. tmpWork:gsub("/", "\\") ..
        '" && powershell -NoProfile -ExecutionPolicy Bypass -File "' ..
        ps1 .. '" 2>&1')
    local out = ""
    if p then out = p:read("*a") or ""; p:close() end
    os.remove(ps1)

    -- 成功与否看标记文件（由脚本自己写），避免解析 stdout 编码
    local m = io.open(marker, "rb")
    local ok = m ~= nil
    if m then m:close(); os.remove(marker) end
    return ok, out
end

-- 把 Lua 字符串转成 PowerShell 单引号字面量（内部单引号翻倍）
local function psQuote(s)
    return "'" .. tostring(s):gsub("'", "''") .. "'"
end

--- 用 PowerShell（Unicode API）读文件全部字节。
-- @param path string UTF-8 路径
-- @return string|nil
function Fs._winReadBytes(path)
    winBridgeSeq = winBridgeSeq + 1
    local outFile = Fs.tempPath("fs_compat_read_" .. winBridgeSeq .. ".bin")
    local marker = outFile .. ".ok"
    local script = string.format(
        "[IO.File]::WriteAllBytes(%s, [IO.File]::ReadAllBytes(%s))\n" ..
        "Set-Content -LiteralPath %s -Value 1 -NoNewline\n",
        psQuote(outFile), psQuote(path), psQuote(marker))
    local ok = winRunScript(script, marker)
    if not ok then return nil end

    local f = io.open(outFile, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    os.remove(outFile)
    return data or ""
end

--- 用 PowerShell（Unicode API）判断路径是否为普通文件。
-- @param path string UTF-8 路径
-- @return boolean
function Fs._winIsFile(path)
    winBridgeSeq = winBridgeSeq + 1
    local marker = Fs.tempPath("fs_compat_q_" .. winBridgeSeq .. ".ok")
    local script = string.format(
        "if (Test-Path -LiteralPath %s -PathType Leaf) { Set-Content -LiteralPath %s -Value 1 -NoNewline }\n",
        psQuote(path), psQuote(marker))
    -- winRunScript 已消费并删除标记文件，这里直接用它的返回值
    local ok = winRunScript(script, marker)
    return ok == true
end

--- 用 PowerShell（Unicode API）写文件。
-- @param path string UTF-8 路径
-- @param data string 二进制内容
-- @return boolean
function Fs._winWriteBytes(path, data)
    winBridgeSeq = winBridgeSeq + 1
    -- 先把内容落到一个 ASCII 名的临时文件（io.open 可写），再让 PowerShell
    -- 用它做源拷到目标（目标路径可含中文）。
    local stage = Fs.tempPath("fs_compat_stage_" .. winBridgeSeq .. ".bin")
    local f = io.open(stage, "wb")
    if not f then return false end
    f:write(data)
    f:close()

    local marker = Fs.tempPath("fs_compat_w_" .. winBridgeSeq .. ".ok")
    local script = string.format(
        "[IO.File]::WriteAllBytes(%s, [IO.File]::ReadAllBytes(%s))\n" ..
        "Set-Content -LiteralPath %s -Value 1 -NoNewline\n",
        psQuote(path), psQuote(stage), psQuote(marker))
    local ok = winRunScript(script, marker)
    os.remove(stage)
    Fs.invalidate(path)
    return ok
end

--- 判断普通文件是否存在（目录不算）。
-- @param path string
-- @return boolean
function Fs.fileExists(path)
    if Fs.isWindows and hasNonAscii(tostring(path)) then
        -- 非 ASCII 路径：io.open 在本机打不开（见 winRunScript 注释），
        -- 交给 PowerShell 的 Unicode API 判断。
        return Fs._winIsFile(path)
    end
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

--- 读取整个文件为二进制字符串。
-- @param path string
-- @return string|nil
function Fs.readFile(path)
    if Fs.isWindows and hasNonAscii(tostring(path)) then
        return Fs._winReadBytes(path)
    end
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--- 写二进制字符串到文件（自动创建父目录）。
-- @param path string
-- @param data string
-- @return boolean 是否成功
function Fs.writeFile(path, data)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir and dir ~= "" then Fs.makeDirectory(dir) end
    if Fs.isWindows and hasNonAscii(tostring(path)) then
        return Fs._winWriteBytes(path, data)
    end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    Fs.invalidate(path)
    return true
end

--- 删除普通文件。
-- @param path string
-- @return boolean
function Fs.removeFile(path)
    if not Fs.fileExists(path) then return true end
    local ok = os.remove(path) ~= nil
    Fs.invalidate(path)
    return ok
end

--- 逐个列举目录下匹配 Lua 模式的**文件**（不递归子目录）。
-- @param path string 目录
-- @param pattern string|nil Lua 模式，作用于文件名
-- @return table 文件名数组（已排序，便于断言稳定）
function Fs.listFiles(path, pattern)
    local out = {}
    for _, e in ipairs(Fs.listEntries(path)) do
        if not e.dir and (not pattern or e.name:match(pattern)) then
            out[#out + 1] = e.name
        end
    end
    table.sort(out)
    return out
end

--- 递归列举目录下所有文件，返回相对该目录的正斜杠路径（已排序）。
-- @param path string 根目录
-- @return table 相对路径数组
function Fs.walkFiles(path)
    local out = {}
    local function walk(abs, rel)
        for _, e in ipairs(Fs.listEntries(abs)) do
            local childRel = (rel == "") and e.name or (rel .. "/" .. e.name)
            if e.dir then
                walk(abs .. "/" .. e.name, childRel)
            else
                out[#out + 1] = childRel
            end
        end
    end
    walk(normalizeDirKey(path), "")
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------- 临时路径

--- 返回跨平台临时目录（不带结尾分隔符）。
-- Windows 优先 TEMP/TMP，POSIX 用 /tmp。
-- @return string
function Fs.tempDir()
    if Fs.isWindows then
        local t = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Windows\\Temp"
        return stripTrailingSep(t)
    end
    return "/tmp"
end

--- 拼接路径（统一用正斜杠；Windows 上 Lua io 也接受正斜杠）。
-- @param ... string 路径片段
-- @return string
function Fs.join(...)
    local parts = { ... }
    local out = {}
    for _, p in ipairs(parts) do
        p = tostring(p)
        p = p:gsub("[/\\]+$", "")
        if p ~= "" then out[#out + 1] = p end
    end
    return table.concat(out, "/")
end

--- 临时文件完整路径（仅拼接，不创建）。
-- @param name string 文件名
-- @return string
function Fs.tempPath(name)
    return Fs.join(Fs.tempDir(), name)
end

-- ---------------------------------------------------------------- shell

-- Windows 上可用的 POSIX shell 候选（按优先级）。
-- 说明：Windows 原生 io.popen 走 cmd.exe，不认 `grep` / `head` / `md5sum`
-- / `2>/dev/null`。开发工具与测试里的「证据命令」是记录在文档里的 POSIX
-- 形式（供人复现），所以执行时需要在 Windows 上找一个 bash 来跑它们。
local BASH_CANDIDATES_WIN = {
    "C:/msys64/usr/bin/bash.exe",
    "D:/msys64/usr/bin/bash.exe",
    "C:/msys32/usr/bin/bash.exe",
    "D:/msys32/usr/bin/bash.exe",
    "D:/msys2/usr/bin/bash.exe",
    "C:/Program Files/Git/bin/bash.exe",
    "C:/Program Files (x86)/Git/bin/bash.exe",
    "C:/Windows/System32/bash.exe",   -- WSL
}

local cachedBash      -- false = 已探测过且没有

--- 查找可用的 POSIX shell（仅 Windows 需要；POSIX 返回 nil，表示直接用 sh）。
-- @return string|nil bash 可执行文件路径
function Fs.findPosixShell()
    if not Fs.isWindows then return nil end
    if cachedBash ~= nil then
        return cachedBash or nil
    end
    for _, p in ipairs(BASH_CANDIDATES_WIN) do
        if Fs.fileExists(p) then
            cachedBash = p
            return p
        end
    end
    cachedBash = false
    return nil
end

--- 判断当前环境能否执行 POSIX shell 命令（grep/head/md5sum/find 等）。
-- @return boolean
function Fs.canRunPosix()
    if not Fs.isWindows then return true end
    return Fs.findPosixShell() ~= nil
end

-- cmd.exe 下调用外部程序且需要引号时的正确形式是 `"" prog" args "`
-- （cmd 会剥掉最外层一对引号）。少写这一层，cmd 会把路径里的空格当成参数分隔。
local function quoteForCmd(s)
    return '"' .. tostring(s):gsub('"', '""') .. '"'
end

--- 执行一条 shell 命令并捕获 stdout+stderr。
--
-- POSIX 上直接交给 /bin/sh；Windows 上若有 bash 则用 bash 执行（命令按
-- POSIX 语法书写），否则返回 ok=false 与明确的「环境不支持」原因，调用方
-- 应据此跳过而不是判失败。
--
-- @param cmd string 待执行命令（POSIX 语法）
-- @param opts table|nil { timeout = 秒 }（Windows 下不强制超时）
-- @return boolean ok（能否执行）
-- @return string output（合并的 stdout + stderr）
-- @return string|nil errReason（ok=false 时的原因）
function Fs.runShell(cmd, opts)
    opts = opts or {}
    local full
    local bash = Fs.findPosixShell()

    if Fs.isWindows then
        if not bash then
            return false, "", "no-posix-shell"
        end
        -- bash 内跑脚本；把 stderr 合进 stdout，便于断言输出内容
        local script = tostring(cmd) .. " 2>&1"
        if opts.timeout and opts.timeout > 0 then
            script = string.format("timeout %d bash -c %s 2>&1",
                math.floor(opts.timeout), quotePosix(script))
        end
        full = '""' .. bash .. '" -c ' .. quoteForCmd(script) .. ' "'
    else
        if opts.timeout and opts.timeout > 0 then
            full = string.format("timeout %d sh -c %s 2>&1",
                math.floor(opts.timeout), quotePosix(cmd))
        else
            full = "sh -c " .. quotePosix(cmd) .. " 2>&1"
        end
    end

    local p = io.popen(full)
    if not p then
        return false, "", "popen-failed"
    end
    local out = p:read("*a") or ""
    p:close()
    return true, out
end

--- 当前 Lua 解释器可执行文件路径（用于证据命令里的 `lua -e ...`）。
-- best-effort：取 arg[-1]；取不到时返回 nil（调用方应回退到裸 "lua"）。
-- @return string|nil
function Fs.luaInterpreter()
    local a = rawget(_G, "arg")
    if type(a) == "table" then
        local ok, v = pcall(function() return a[-1] end)
        if ok and type(v) == "string" and v ~= "" then
            return v
        end
    end
    return nil
end

return Fs
