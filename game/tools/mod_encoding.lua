-- tools/mod_encoding.lua
-- Build-time Big5 -> UTF-8 conversion for allmods MOD save/definition data.
--
-- Background
-- ----------
-- Every allmods MOD ships `save/ranger.grp` + `save/ranger.idx` in **Big5**
-- encoding, while the Love2D engine reads all string fields as UTF-8. Without
-- conversion, every name / nickname / item name / item description / scene name
-- / skill name renders as mojibake.
--
-- The MOD `ranger.grp` uses the "allmods" record layout, which differs from the
-- vanilla (kys-pascal) layout the engine constants were written against.
-- AUTHORITATIVE SOURCE: reference/allmods/UPedit/UPedit.ini  [R_Modify]
--
--   segment | record size | field           | offset | length
--   --------+-------------+-----------------+--------+-------
--   Person  | 182         | Name            | 8      | 10
--           |             | Nick            | 18     | 10
--   Thing   | 190         | Name            | 2      | 20
--           |             | Name2           | 22     | 20
--           |             | Desc            | 42     | 30
--   Scene   | 52          | Name            | 2      | 10
--   Wugong  | 136         | Name            | 2      | 10
--   Shop    | 50          | (no strings)    | -      | -
--
-- Conversion strategy: HINT PLACEHOLDER + SIDE TABLE
-- --------------------------------------------------
-- A Big5 char is 2 bytes; a UTF-8 BMP char is 3 bytes. The fixed-width fields
-- (10/20/30 bytes) cannot hold the UTF-8 form: in-place re-encoding truncates
-- 41% of all strings (e.g. 雪山飛狐 = 12 bytes > 10-byte field). Truncation is
-- explicitly forbidden.
--
-- Instead we:
--   1. Replace each string field in `ranger.grp` with a fixed-width HINT such as
--      "P0002" (prefix = category, then a segment-local %04d index). The record
--      layout and the file size are UNCHANGED, so every numeric offset stays
--      valid and there is zero risk to non-string data.
--   2. Emit the real UTF-8 strings into a side table `ranger.str`, grouped by
--      segment, deduplicated within the segment, keyed by the same index.
--
-- The engine resolves a string by: save override (rN.ovr) -> ranger.str ->
-- raw buffer (vanilla fallback). See framework/mod_data.lua.
--
-- Traditional characters are preserved (mod_big5_trad.lua, NOT the t2s table
-- used for talk extraction).
--
-- REQ-ENC-1..6 (allmods-compat, Big5 conversion).

local M = {}

-- ---------------------------------------------------------------------------
-- record layout (the "allmods" format)
-- ---------------------------------------------------------------------------
M.LAYOUT = {
    { name = "Person", seg = 0, rec = 182, fields = {
        { name = "Name", off = 8,  len = 10, hint = "P" },
        { name = "Nick", off = 18, len = 10, hint = "N" },
    }},
    { name = "Thing", seg = 1, rec = 190, fields = {
        { name = "Name",  off = 2,  len = 20, hint = "T" },
        { name = "Name2", off = 22, len = 20, hint = "T2" },
        { name = "Desc",  off = 42, len = 30, hint = "TD" },
    }},
    { name = "Scene", seg = 2, rec = 52, fields = {
        { name = "Name", off = 2, len = 10, hint = "S" },
    }},
    { name = "Wugong", seg = 3, rec = 136, fields = {
        { name = "Name", off = 2, len = 10, hint = "W" },
    }},
    { name = "Shop", seg = 4, rec = 50, fields = {} },
}

-- ---------------------------------------------------------------------------
-- idx REPAIR (reverse-engineered 2026-10, kys-zheng)
--
-- Every MOD ships `save/ranger.idx`: six little-endian uint32 offsets that
-- describe the five fixed-size arrays inside `save/ranger.grp`
-- (Person/Thing/Scene/Wugong/Shop). A few MODs ship an idx that does NOT match
-- their own .grp:
--
--   kys-zheng : idx[6] = 138596 but ranger.grp is 114242 bytes  (idx taken
--               from a different, larger save -- r1.grp/r6.grp/r11.grp).
--   kys-pineapple: idx[6] = 228210 but ranger.grp is 229680 bytes (1470 bytes
--               of trailing padding not covered by the idx).
--
-- Reading a .grp with a mismatched idx produces garbage in the LAST segment
-- and shifts every string offset, which is what made zheng look like it used a
-- "non-standard layout". It does not: zheng's bytes decode 100% cleanly with
-- the standard UPedit layout once the idx is repaired.
--
-- `M.RepairIdx` derives a consistent idx from the ACTUAL file size and the
-- standard record sizes. It is purely data-driven -- no MOD name is involved.
-- It only rewrites the idx when the shipped one is demonstrably inconsistent,
-- so correctly-packaged MODs are never touched.
-- ---------------------------------------------------------------------------

-- Standard per-segment record sizes, in idx order.
M.SEG_REC = { 182, 190, 52, 136, 50 }

-- Is `idxOffsets` usable for a .grp of `grpSize` bytes?
--
--   * six non-negative, non-decreasing offsets
--   * every segment length is a whole multiple of its record size
--   * the arrays do not run past the end of the file
--
-- Trailing padding BEYOND the last array is allowed: kys-pineapple ships
-- 1470 bytes of uninitialised padding after the Shop array and its idx is
-- otherwise perfectly valid, so demanding `idx[6] == grpSize` would wrongly
-- discard a correct idx.
function M.IdxIsConsistent(idxOffsets, grpSize)
    if not idxOffsets or #idxOffsets < 6 then return false end
    for i = 1, 6 do
        local v = idxOffsets[i]
        if type(v) ~= "number" or v < 0 then return false end
        if i > 1 and v < idxOffsets[i - 1] then return false end
    end
    if idxOffsets[6] > grpSize then return false end
    for i = 1, 5 do
        local len = idxOffsets[i + 1] - idxOffsets[i]
        if len % M.SEG_REC[i] ~= 0 then return false end
    end
    return true
end

-- Derive the real segment boundaries of a `ranger.grp` FROM ITS BYTES.
--
-- This is the authoritative repair for MODs that ship an `ranger.idx` which
-- does not describe their own `ranger.grp` (kys-zheng: idx describes a
-- 138596-byte file but the grp is 114242 bytes).
--
-- Each segment is a fixed-stride array whose first field is a Big5 string at a
-- known offset:
--
--   Person rec 182 name@8   Thing rec 190 name@2
--   Scene  rec 52  name@2   Wugong rec 136 name@2
--
-- For every Big5 string in the file we treat its position minus the field
-- offset as a candidate array start, then measure how many records line up at
-- the segment's stride. The longest run wins. Boundaries are then chained so
-- that each segment starts where the previous one ended. Nothing is keyed on a
-- MOD name -- only on the bytes and the UPedit record sizes.
--
-- Returns newIdx (6 numbers), detection table, or nil, reason.
function M.DetectLayout(grp, opts)
    opts = opts or {}
    local grpSize = #grp
    local strings = M.ScanStrings(grp)
    if #strings == 0 then return nil, nil, "no Big5 strings found" end

    local byPos = {}
    for _, s in ipairs(strings) do byPos[s.pos] = true end

    -- Count how many consecutive records line up at `start`.
    --
    -- When a segment declares more than one string field (Thing: 名称/名称2/
    -- 物品说明), a record only counts when ALL of them are present. This stops
    -- a stray trailing string from extending the run by one record.
    local function runLen(start, rec, off, extra)
        local n = 0
        local p = start
        while byPos[p + off] do
            local ok = true
            if extra then
                for _, e in ipairs(extra) do
                    if not byPos[p + e] then ok = false break end
                end
            end
            if not ok then break end
            n = n + 1
            p = p + rec
        end
        return n
    end

    -- Candidate segment starts: for each string, pos - fieldOffset.
    local SEGS = {
        { name = "Person", rec = 182, off = 8,  extra = { 18 } },
        { name = "Thing",  rec = 190, off = 2,  extra = { 22, 42 } },
        { name = "Scene",  rec = 52,  off = 2 },
        { name = "Wugong", rec = 136, off = 2 },
    }

    -- Detect the best start for each segment independently.
    local det = {}
    for _, d in ipairs(SEGS) do
        local best = { n = 0, start = nil }
        for _, s in ipairs(strings) do
            local start = s.pos - d.off
            if start >= 0 and (not best.start or true) then
                local n = runLen(start, d.rec, d.off, d.extra)
                if n > best.n then best = { n = n, start = start } end
            end
        end
        det[#det + 1] = { name = d.name, rec = d.rec, off = d.off, start = best.start, n = best.n }
    end

    -- Chain the detected starts into a monotonic layout.
    --
    -- Each segment's detected start is authoritative; a segment's END is the
    -- NEXT segment's start. That is exactly how the idx is defined, and it
    -- prevents a spurious trailing record in one array from shifting the next.
    -- The last array's end is its own detected start plus its run.
    local starts = {}
    for i = 1, #det do
        starts[i] = det[i].start
    end
    -- Fill a missing Person start from the first plausible header: the first
    -- record boundary at or after the smallest string position, snapped down to
    -- the nearest multiple of the Person record size.
    if not starts[1] then
        local firstPos = strings[1].pos
        starts[1] = math.max(0, firstPos - det[1].off)
    end
    -- Enforce monotonicity: a start may never precede the previous start, and
    -- an undetected segment collapses onto the previous boundary (zero length).
    for i = 2, #det do
        if not starts[i] or starts[i] < starts[i - 1] then
            starts[i] = starts[i - 1]
        end
    end
    if starts[1] < 0 then starts[1] = 0 end
    -- Segment i spans [starts[i], starts[i+1]); the final segment's end is its
    -- own run length.
    local out = { starts[1] }
    for i = 1, #det - 1 do out[i + 1] = starts[i + 1] end
    local last = det[#det]
    local n = runLen(starts[#det], last.rec, last.off, last.extra)
    out[#det + 1] = starts[#det] + (n > 0 and n or 0) * last.rec
    local cur = out[#det + 1]
    -- The Shop array follows Wugong. Its records carry no Big5 strings, so it
    -- is sized from the remaining bytes (whole 50-byte records).
    local tail = grpSize - cur
    local shopN = math.floor(tail / M.SEG_REC[5])
    if shopN < 1 then
        -- Allow the Shop span to be empty (no room left).
        shopN = 0
    end
    out[6] = cur + shopN * M.SEG_REC[5]

    -- Trailing padding (not a whole record) is excluded from the arrays but
    -- must not be silently dropped: report it.
    local padding = grpSize - out[6]
    return out, det, nil, padding
end

-- Repair an idx: return the shipped one when it is consistent, otherwise the
-- data-detected layout. Returns newIdx, reason.
function M.RepairIdx(grp, idxOffsets)
    if M.IdxIsConsistent(idxOffsets, #grp) then
        return idxOffsets, nil
    end
    local detected, det, err, padding = M.DetectLayout(grp)
    if not detected then
        return nil, "idx inconsistent and layout detection failed: " .. tostring(err)
    end
    return detected, string.format(
        "idx inconsistent (idx[6]=%s, file=%d); layout detected from data",
        idxOffsets and tostring(idxOffsets[6]) or "nil", #grp)
end


-- ---------------------------------------------------------------------------
-- layout PROBING (reverse-engineered 2026-10)
--
-- Most MODs follow the UPedit `[R_Modify]` layout above, but a few ship data
-- written by older editors with a DIFFERENT record layout. Reading those with
-- the standard layout yields control characters / U+FFFD garbage (see
-- openspec/changes/allmods-encoding-convert/reports/encoding-reverse.md).
--
-- Instead of hard-coding MOD names, we PROBE the real layout from the bytes:
--   * candidate record sizes  = divisors of the segment length
--   * candidate field offsets = offsets where >=50% of records start a Big5
--     high-byte pair (>=0x81 followed by 0x40..0xFE)
--   * candidate header size   = (segment length - n*rec) for a plausible n
-- A layout is accepted only when it decodes cleanly (no U+FFFD) for the vast
-- majority of records. This keeps the probe honest: it is derived from data,
-- never from a MOD name.
-- ---------------------------------------------------------------------------

-- Big5 lead-byte test: 0x81..0xFE followed by 0x40..0x7E or 0xA1..0xFE.
local function isBig5Lead(b)
    return b ~= nil and b >= 0x81 and b <= 0xFE
end
local function isBig5Trail(b)
    return b ~= nil and ((b >= 0x40 and b <= 0x7E) or (b >= 0xA1 and b <= 0xFE))
end

-- Does `raw` start with a decodable Big5 pair?
local function startsBig5Pair(raw)
    return isBig5Lead(raw:byte(1)) and isBig5Trail(raw:byte(2))
end

-- Normalise CR/LF inside a raw fixed-width string field.
--
-- Some MODs accidentally pasted a line break into a fixed-width string field
-- (kys-BookCalamity / kys-awaken / kys-Dragon: "大燕傳國玉璽\r\n",
-- "大剪刀\r\n刀法"). Those bytes are editor artefacts, not text: the engine
-- renders these fields on a single line. Strip every CR/LF plus any whitespace
-- that follows it, then trim trailing C0 control bytes. Other control bytes are
-- left alone so a field that genuinely carries them is never altered.
function M.TrimControl(raw)
    raw = raw:gsub("\r\n", ""):gsub("[\r\n]", "")
    local last = #raw
    while last > 0 do
        local b = raw:byte(last)
        if b < 0x20 or b == 0x7f then last = last - 1 else break end
    end
    return raw:sub(1, last)
end

-- Count U+FFFD occurrences in a decoded string.
local function countReplacement(s)
    local n = 0
    local i = 1
    while true do
        local p = s:find("\239\191\189", i, true)
        if not p then break end
        n = n + 1
        i = p + 3
    end
    return n
end

-- Read a NUL-terminated field from `grp` at absolute 1-based position.
local function rawFieldAt(grp, pos, len)
    local raw = grp:sub(pos, pos + len - 1)
    local z = raw:find("\0", 1, true)
    if z then raw = raw:sub(1, z - 1) end
    return raw
end

-- Score a candidate (header, rec, fieldOffset) triple for one field:
-- fraction of records whose field decodes to a clean Big5 string.
local function scoreField(grp, base, size, header, rec, off, len, minRecs)
    local nrec = math.floor((size - header) / rec)
    if nrec < minRecs then return -1, 0 end
    local total, good = 0, 0
    local sample = math.min(nrec, 400)
    for r = 0, sample - 1 do
        local raw = rawFieldAt(grp, base + header + r * rec + off + 1, len)
        -- Only fields that actually LOOK like a Big5 string participate in the
        -- score. A field holding a small numeric value / stray padding byte is
        -- not a string slot and must not count against the layout.
        if startsBig5Pair(raw) then
            total = total + 1
            if countReplacement(M.DecodeBig5(raw)) == 0 then
                good = good + 1
            end
        end
    end
    if total == 0 then return -1, 0 end
    -- Require a meaningful sample: an offset that only 3 records coincidentally
    -- align with must not beat a real field that covers most records.
    if total < math.max(8, nrec * 0.25) then return -1, 0 end
    return good / total, total
end

-- Is `off` a genuine field START? A field start is preceded (within the record)
-- by a non-Big5 byte, or is the record start. This rejects offsets that land in
-- the MIDDLE of a Big5 string (e.g. @140 = "冰蠶" inside "千年冰蠶" @116).
local function isFieldStart(grp, base, size, header, rec, off, minRecs)
    if off == 0 then return true end
    local nrec = math.floor((size - header) / rec)
    local sample = math.min(nrec, 200)
    if sample < 1 then return false end
    local starts, mid = 0, 0
    for r = 0, sample - 1 do
        local rb = base + header + r * rec
        local b1 = grp:byte(rb + off + 1)
        local b2 = grp:byte(rb + off + 2)
        if isBig5Lead(b1) and isBig5Trail(b2) then
            -- check the previous byte: if it is a lead byte, we are mid-string
            local prev = grp:byte(rb + off)
            if prev and isBig5Lead(prev) then
                mid = mid + 1
            else
                starts = starts + 1
            end
        end
    end
    -- Accept as a field start when most Big5-pair positions are not mid-string.
    if starts + mid == 0 then return true end
    return starts >= mid
end

-- Return a list of divisors of `n` within [lo, hi], ascending.
local function divisorsIn(n, lo, hi)
    local out = {}
    for d = lo, hi do
        if n % d == 0 then out[#out + 1] = d end
    end
    return out
end

-- Probe ONE segment for a string field of length `len`.
--
-- `opts.rec` PINS the record size (physical format property, taken from the
-- UPedit layout). Probing the record size itself is unreliable: any divisor of
-- the segment length can score 1.0 by cutting records in half, so the record
-- size must be given, not guessed.
--
-- Returns best = { header=, rec=, off=, score=, nrec= } or nil.
function M.ProbeField(grp, idxOffsets, segIndex, len, opts)
    opts = opts or {}
    local rec = opts.rec
    if not rec then return nil end
    local loOff = opts.loOff or 0
    local hiOff = opts.hiOff or math.min(rec - 2, 300)
    local minRecs = opts.minRecs or 10
    local minScore = opts.minScore or 0.9
    -- Fields are ordered within a record: a later field must start after the
    -- previous one, otherwise every field collapses onto the first match.
    local minOff = opts.minOff or loOff

    local s = idxOffsets[segIndex + 1]
    local e = idxOffsets[segIndex + 2]
    if not (s and e and e > s) then return nil end
    local size = e - s
    local base = s -- 0-based offset of segment start

    -- Candidate headers: only 0 and the residue that makes the length divide.
    local headers = { 0 }
    local rem = size % rec
    if rem ~= 0 and size - rem >= minRecs * rec then headers[#headers + 1] = rem end

    local best = nil
    for _, header in ipairs(headers) do
        local nrec = math.floor((size - header) / rec)
        if nrec >= minRecs then
            local sample = math.min(nrec, 400)
            -- count Big5-pair starts per offset
            local counts = {}
            for r = 0, sample - 1 do
                local rb = base + header + r * rec
                for k = loOff, hiOff do
                    local b1 = grp:byte(rb + k + 1)
                    local b2 = grp:byte(rb + k + 2)
                    if isBig5Lead(b1) and isBig5Trail(b2) then
                        counts[k] = (counts[k] or 0) + 1
                    end
                end
            end
            local offs = {}
            for k, v in pairs(counts) do
                if v >= sample * 0.5 then offs[#offs + 1] = k end
            end            -- always consider the standard offset as a fallback
            for _, k in ipairs(opts.tryOffs or {}) do offs[#offs + 1] = k end
            table.sort(offs)
            for _, off in ipairs(offs) do
                if off >= minOff then
                local sc = scoreField(grp, base, size, header, rec, off, len, minRecs)
                if sc >= minScore and isFieldStart(grp, base, size, header, rec, off, minRecs) then
                    -- Prefer the LEFT MOST offset that scores: a field begins at
                    -- its first byte, and later offsets are substrings of it.
                    if not best or off < best.off
                        or (off == best.off and sc > best.score) then
                        best = { header = header, rec = rec, off = off, score = sc, nrec = nrec }
                    end
                end
                end
            end
        end
    end
    return best
end

-- Probe a full layout for every segment that carries strings.
--
-- The record size is PINNED to the standard UPedit value; only the per-segment
-- header and the per-field offsets are probed. A segment keeps the standard
-- layout unless a probed layout is strictly better (decodes cleanly where the
-- standard does not). Nothing here is keyed on a MOD name: the decision is
-- derived purely from the bytes.
function M.ProbeLayout(grp, idxOffsets, standard)
    standard = standard or M.LAYOUT
    local out = {}
    local changes = {}
    for _, seg in ipairs(standard) do
        local s = idxOffsets[seg.seg + 1]
        local e = idxOffsets[seg.seg + 2]
        local size = (s and e and e > s) and (e - s) or 0

        local newSeg = {
            name = seg.name, seg = seg.seg, rec = seg.rec,
            header = seg.header or 0, fields = {},
        }

        -- Per-field probe: fix rec, find header+offset. Fields are probed in
        -- order and each subsequent field must start after the previous one.
        local probedFields = {}
        local allBetter = true
        local anyField = false
        local cursor = 0
        for i, f in ipairs(seg.fields) do
            local stdScore = -1
            if size > 0 then
                stdScore = scoreField(grp, s, size, seg.header or 0, seg.rec, f.off, f.len, 5)
            end
            local probed = M.ProbeField(grp, idxOffsets, seg.seg, f.len, {
                rec = seg.rec,
                tryOffs = { f.off },
                minOff = cursor,
            })
            local stdOk = stdScore >= 0.9
                and isFieldStart(grp, s, size, seg.header or 0, seg.rec, f.off, 5)
                and f.off >= cursor
            if probed and not stdOk and probed.score >= 0.9 then
                probedFields[i] = probed
                anyField = true
                cursor = probed.off + f.len
            elseif probed and stdOk then
                -- standard already decodes cleanly: keep it
                probedFields[i] = probed
                cursor = f.off + f.len
            elseif stdOk then
                cursor = f.off + f.len
            end
        end

        if anyField and allBetter then
            for i, f in ipairs(seg.fields) do
                local p = probedFields[i]
                if p then
                    newSeg.header = p.header
                    newSeg.fields[i] = { name = f.name, off = p.off, len = f.len, hint = f.hint }
                    changes[#changes + 1] = string.format(
                        "%s.%s: off %d->%d header %d->%d (score %.2f)",
                        seg.name, f.name, f.off, p.off, seg.header or 0, p.header, p.score)
                else
                    newSeg.fields[i] = { name = f.name, off = f.off, len = f.len, hint = f.hint }
                end
            end
        else
            for i, f in ipairs(seg.fields) do
                newSeg.fields[i] = { name = f.name, off = f.off, len = f.len, hint = f.hint }
            end
        end
        out[#out + 1] = newSeg
    end
    return out, changes
end

-- ---------------------------------------------------------------------------
-- compound-layout PROBE
--
-- Detects segments that hold more than one logical array, or arrays split over
-- several segments. Strategy:
--   1. Enumerate every Big5 string start in the whole file together with its
--      decoded value.
--   2. Group starts by (rec, field-offset) pattern: a real array produces a
--      long arithmetic sequence with a constant stride.
--   3. Emit one region per sequence found.
--
-- Returns spec (for M.MakeCompoundLayout) and a human-readable change list.
-- Nothing is keyed on a MOD name.
-- ---------------------------------------------------------------------------

-- Enumerate all decodable Big5 strings: { pos = 0-based, raw = bytes, text = utf8 }
function M.ScanStrings(grp)
    local out = {}
    local i = 1
    local n = #grp
    while i < n do
        local b = grp:byte(i)
        if isBig5Lead(b) and isBig5Trail(grp:byte(i + 1)) then
            local j = i
            while j < n and isBig5Lead(grp:byte(j)) and isBig5Trail(grp:byte(j + 1)) do
                j = j + 2
            end
            local raw = grp:sub(i, j - 1)
            local text = M.DecodeBig5(raw)
            if #text >= 2 and countReplacement(text) == 0 then
                out[#out + 1] = { pos = i - 1, raw = raw, text = text }
            end
            i = j
        else
            i = i + 1
        end
    end
    return out
end

-- Probe a compound layout for a MOD whose segments carry interleaved arrays.
-- `logical` maps a logical segment name to the (rec, fieldOffsets) candidates
-- that should be searched for. Returns spec, changes.
function M.ProbeCompoundLayout(grp, idxOffsets, logical, opts)
    opts = opts or {}
    local minRun = opts.minRun or 8
    local strings = M.ScanStrings(grp)
    local spec = {}
    local changes = {}

    -- index of position -> string record
    local byPos = {}
    for _, s in ipairs(strings) do byPos[s.pos] = s end

    -- A region must live inside one idx segment. `segLo/segHi` (0-based byte
    -- offsets) optionally restrict the search; `bounds` is a list of
    -- { lo =, hi = } pairs taken from idxOffsets.
    local function inBounds(from, count, rec)
        local bounds = opts.bounds
        if not bounds then return true end
        local lo, hi = from, from + count * rec
        for _, b in ipairs(bounds) do
            if lo >= b.lo and hi <= b.hi then return true end
        end
        return false
    end

    for _, item in ipairs(logical) do
        local name = item.name
        local regions = {}
        local used = {}
        -- Byte ranges already claimed by a region; phase-shifted aliases of the
        -- same array overlap heavily and must be discarded.
        local claimed = {}
        local function overlaps(from, count, rec)
            local lo, hi = from, from + count * rec
            for _, r in ipairs(claimed) do
                if r.rec == rec and lo < r.hi and r.lo < hi then return true end
            end
            return false
        end
        for _, cand in ipairs(item.candidates) do
            local rec = cand.rec
            local fieldOff = cand.fieldOff
            local len = cand.len or 10
            -- walk every string start; a run is a maximal arithmetic sequence
            -- with stride == rec that also has a plausible field offset.
            local i = 1
            while i <= #strings do
                local s0 = strings[i]
                local start = s0.pos - fieldOff
                if start >= 0 and not used[start] then
                    local count = 0
                    local p = start
                    while true do
                        local hit = byPos[p + fieldOff]
                        if hit then count = count + 1; p = p + rec else break end
                    end
                    if count >= minRun and not overlaps(start, count, rec)
                        and inBounds(start, count, rec) then
                        regions[#regions + 1] = {
                            from = start, rec = rec, count = count,
                            fields = { { off = fieldOff, len = len, hint = cand.hint } },
                        }
                        for k = 0, count - 1 do used[start + k * rec] = true end
                        claimed[#claimed + 1] = { lo = start, hi = start + count * rec, rec = rec }
                        changes[#changes + 1] = string.format(
                            "%s: region from=%d rec=%d count=%d off=%d",
                            name, start, rec, count, fieldOff)
                    end
                end
                i = i + 1
            end
        end
        if #regions > 0 then
            table.sort(regions, function(a, b) return a.from < b.from end)
            spec[#spec + 1] = { name = name, regions = regions }
        end
    end
    return spec, changes
end

-- hint index ceiling for %04d
M.HINT_MAX = 9999

-- ---------------------------------------------------------------------------
-- Big5 decode
--
-- Uses the TRADITIONAL-preserving table (mod_big5_trad.lua), NOT talk_big5.lua.
-- The talk table maps Big5 -> Simplified (built with OpenCC t2s), which would
-- rewrite 靈->灵, 鳳->凤 etc. MOD display data must keep the original
-- traditional/simplified form as authored (user requirement Q3).
-- ---------------------------------------------------------------------------

local BIG5 = nil

local function loadBig5()
    if BIG5 then return BIG5 end
    local ok, tbl = pcall(require, "tools.mod_big5_trad")
    if not ok or type(tbl) ~= "table" then
        local info = debug.getinfo(1, "S").source:sub(2)
        local dir = info:match("^(.*)[/\\][^/\\]*$") or "."
        local chunk = loadfile(dir .. "/mod_big5_trad.lua")
        if chunk then tbl = chunk() end
    end
    BIG5 = tbl or {}
    return BIG5
end

-- Decode a Big5 byte string into a UTF-8 string (stops at NUL).
function M.DecodeBig5(raw)
    local tbl = loadBig5()
    local out = {}
    local i = 1
    local n = #raw
    while i <= n do
        local b = raw:byte(i)
        if b == 0 then break end
        if b < 0x80 then
            out[#out + 1] = string.char(b)
            i = i + 1
        elseif i + 1 <= n then
            local b2 = raw:byte(i + 1)
            local ch = tbl[b * 256 + b2]
            out[#out + 1] = ch or "\239\191\189" -- U+FFFD for unknown pair
            i = i + 2
        else
            break
        end
    end
    return table.concat(out)
end

-- Return the raw bytes of a field, up to (not including) the first NUL.
local function rawField(grp, base, off, len)
    local raw = grp:sub(base + off + 1, base + off + len)
    local z = raw:find("\0", 1, true)
    if z then raw = raw:sub(1, z - 1) end
    return raw
end

-- True if `raw` is a genuine string slot, as opposed to a numeric/binary field
-- that merely happens to occupy a string offset.
--
-- The original guard was a bare high-byte test. That correctly rejects
-- numeric slots (pig3dos Person 外号 @18 holds int16 stats: 0x07 0x00 0x07 ...)
-- but it also DROPPED genuine ASCII-only names that MOD authors really wrote:
--   lyff        Person[0].Name   = "AAA"
--   HeavenSword Person[74].Name  = "killer-G"
--   GodsDevils  Person[191].Nick = "123"
--   ptt         Scene[64].Name   = "PTT"
--   dream       Thing[80].Name   = "------"
-- Those fields decode to a valid UTF-8 ASCII string, so the engine should render
-- them rather than an empty placeholder.
--
-- Discriminator: a field is a string when it decodes to text, i.e.
--
--   (a) it is entirely printable ASCII (0x20..0x7E) AND at least two bytes
--       long, or
--   (b) it has high bytes AND every high-byte pair is a known Big5 code point
--       (so the field decodes without any U+FFFD replacement).
--
-- The length floor in (a) matters: single-byte residue such as pineapple's 623
-- `" "` slots and zheng's `<`/`K`/`7`/`$` bytes are binary leftovers, not text.
-- Every genuine ASCII string observed is >= 2 bytes, and no genuine one is a
-- lone character. Binary slots always contain at least one non-printable byte
-- (NUL/C0), so `allPrint` rejects them.
--
-- Clause (b) is NOT a bare high-byte test: a numeric int32 slot filled with
-- 0xFF (`-1`) or a truncated Big5 lead byte would pass a bare test but decode
-- to U+FFFD garbage. Requiring full Big5 coverage rejects those while keeping
-- every real Big5 string (all 20 MODs currently decode with 0 U+FFFD, so the
-- stricter test changes nothing for real data — it only removes false
-- positives). Non-Big5 high bytes are legitimately possible in MOD data, so
-- this mirrors exactly what `DecodeBig5` can render.
local function isStringField(raw)
    if raw == "" then return false end
    local allPrint = true
    local hasHigh = false
    local tbl = nil
    local i, n = 1, #raw
    while i <= n do
        local b = raw:byte(i)
        if b >= 0x80 then
            hasHigh = true
            -- lead byte must be followed by a trail byte
            if i + 1 > n then return false end
            tbl = tbl or loadBig5()
            local b2 = raw:byte(i + 1)
            local ch = tbl[b * 256 + b2]
            if ch == nil or ch == "\239\191\189" then return false end
            i = i + 2
        else
            if b < 0x20 or b > 0x7e then allPrint = false end
            i = i + 1
        end
    end
    if hasHigh then return true end
    return allPrint and #raw >= 2
end

-- ---------------------------------------------------------------------------
-- public: hint for a field
-- ---------------------------------------------------------------------------

-- Build a fixed-width hint: prefix + segment-local %04d index.
function M.Hint(prefix, index)
    return prefix .. string.format("%04d", index)
end

-- public: expose the string-field discriminator for unit tests.
-- Kept as a thin wrapper so production code keeps using the local function
-- (no extra call overhead in the hot conversion loop).
function M.IsStringField(raw)
    return isStringField(raw)
end

-- ---------------------------------------------------------------------------
-- public: convert one ranger.grp (returns newGrp, sideTable, report)
--
--   newGrp    : string, same length as input; string fields replaced by hints
--   sideTable : { Person = { [index] = "值", ... }, Thing = {...}, ... }
--               plus .__meta = { Person = { [index] = {rec=,field=} }, ... }
--   report    : { fields=, converted=, dedup=, perSeg={}, overflows= }
-- ---------------------------------------------------------------------------

function M.ConvertRanger(grp, idxOffsets, layout)
    layout = layout or M.LAYOUT
    local pieces = {}
    local cursor = 1 -- 1-based position already emitted
    local n = #grp

    local function emit(upto)
        if upto >= cursor then
            pieces[#pieces + 1] = grp:sub(cursor, upto)
            cursor = upto + 1
        end
    end

    local side = { __meta = {} }
    local report = { fields = 0, converted = 0, dedup = 0, perSeg = {}, overflows = {}, skipped = {} }

    for _, seg in ipairs(layout) do
        -- Compound layout: the logical segment is spread over one or more
        -- physical regions (kys-zheng packs Thing+Scene into idx[1] and splits
        -- Wugong over idx[2]/idx[3]). Each region carries its own rec/fields.
        local regionList
        if seg.regions then
            regionList = {}
            for _, reg in ipairs(seg.regions) do
                regionList[#regionList + 1] = {
                    from = reg.from,
                    rec = reg.rec,
                    count = reg.count,
                    header = reg.header or 0,
                    fields = reg.fields,
                    name = seg.name,
                }
            end
        else
            local s = idxOffsets[seg.seg + 1]
            local e = idxOffsets[seg.seg + 2]
            if s and e and e > s and #seg.fields > 0 then
                local header = seg.header or 0
                regionList = { {
                    from = s + header,
                    rec = seg.rec,
                    count = math.floor((e - s - header) / seg.rec),
                    header = 0,
                    fields = seg.fields,
                    name = seg.name,
                } }
            end
        end
        if regionList and #regionList > 0 then
            side[seg.name] = side[seg.name] or {}
            side.__meta[seg.name] = side.__meta[seg.name] or {}
            local byValue = {}  -- dedup within segment: value -> index
            local nextIndex = 0
            local emptyHintIndex = nil  -- shared empty-string entry for skipped fields
            local segStat = { records = 0, fields = 0, converted = 0, dedup = 0, skipped = 0 }
            for _, reg in ipairs(regionList) do
            local seg = reg  -- local alias for the loop body below
            local s = reg.from
            local nrec = reg.count
            segStat.records = segStat.records + nrec
            for r = 0, nrec - 1 do
                local rbase = s + r * reg.rec
                for _, f in ipairs(reg.fields) do
                    local raw = rawField(grp, rbase, f.off, f.len)
                    segStat.fields = segStat.fields + 1
                    -- A field is only a string when it actually carries Big5
                    -- text or printable ASCII of length >= 2. Numeric fields
                    -- (e.g. pig3dos has no 外号 slot, only a stat byte) must be
                    -- left untouched, otherwise we emit control characters as
                    -- "strings".
                    -- A field is a string when it carries ANY Big5 high byte,
                    -- or when it is entirely printable ASCII text of length >= 2
                    -- (see isStringField). Testing only the first byte would skip
                    -- mixed fields such as "2008年北京奧運會吉祥物" or "?陽刀氣",
                    -- whose ASCII prefix would otherwise be left in the .grp and
                    -- leak raw bytes into the engine's reader. Numeric fields (e.g.
                    -- pig3dos has no 外号 slot, only int16 stats) contain
                    -- non-printable bytes, so they stay untouched, while genuine
                    -- ASCII names like lyff's "AAA" are converted instead of
                    -- silently dropped.
                    if raw ~= "" and isStringField(raw) then
                        -- Editor artefacts: MOD authors pasted line breaks into
                        -- fixed-width fields, leaving a CR/LF inside the string
                        -- (trailing, or interior as in awaken's "七傷拳\r\n譜").
                        -- Those bytes are not part of the text and must not be
                        -- rendered, so remove them before decoding. Other C0
                        -- control bytes are preserved verbatim.
                        raw = M.TrimControl(raw)
                        local value = M.DecodeBig5(raw)
                        local index = byValue[value]
                        if index == nil then
                            if nextIndex > M.HINT_MAX then
                                report.overflows[#report.overflows + 1] =
                                    string.format("%s index overflow at %d", seg.name, nextIndex)
                            end
                            index = nextIndex
                            nextIndex = nextIndex + 1
                            byValue[value] = index
                            side[seg.name][index] = value
                            side.__meta[seg.name][index] =
                                { rec = r, field = f.name, offset = rbase + f.off }
                        else
                            segStat.dedup = segStat.dedup + 1
                            report.dedup = report.dedup + 1
                        end

                        local hint = M.Hint(f.hint, index)
                        if #hint + 1 > f.len then
                            report.overflows[#report.overflows + 1] =
                                string.format("%s.%s hint %q too long for %d-byte field",
                                    seg.name, f.name, hint, f.len)
                        end

                        local off = rbase + f.off
                        emit(off)
                        pieces[#pieces + 1] = hint .. string.rep("\0", f.len - #hint)
                        cursor = off + f.len + 1

                        segStat.converted = segStat.converted + 1
                    else
                        segStat.skipped = segStat.skipped + 1
                        report.skipped[#report.skipped + 1] =
                            string.format("%s rec %d field %s (non-string)", seg.name, r, f.name)
                        -- The engine's struct still declares this offset as a
                        -- string field (e.g. ModData.MOD_STRINGS.Person.外号
                        -- = {18,2,10}). If we leave the raw bytes in the .grp
                        -- the engine reads them via Byte.getstr and renders
                        -- binary as control characters (pig3dos stores int16
                        -- stats where 外号 would be). Neutralise the slot by
                        -- writing an empty hint that resolves to "": the
                        -- numeric data lives only in the .grp and nothing in
                        -- the engine reads these offsets numerically, so
                        -- nothing is lost.
                        local off = rbase + f.off
                        if f.hint and f.len and #f.hint + 1 <= f.len then
                            local emptyIndex = emptyHintIndex
                            if emptyIndex == nil then
                                emptyIndex = nextIndex
                                nextIndex = nextIndex + 1
                                side[seg.name][emptyIndex] = ""
                                side.__meta[seg.name][emptyIndex] =
                                    { rec = -1, field = f.name, offset = -1, empty = true }
                                emptyHintIndex = emptyIndex
                            end
                            local hint = M.Hint(f.hint, emptyIndex)
                            emit(off)
                            pieces[#pieces + 1] = hint .. string.rep("\0", f.len - #hint)
                            cursor = off + f.len + 1
                        end
                    end
                end
            end
            end
            report.perSeg[seg.name] = segStat
            report.fields = report.fields + segStat.fields
            report.converted = report.converted + segStat.converted
        end
    end

    emit(n)

    return table.concat(pieces), side, report
end

-- ---------------------------------------------------------------------------
-- public: serialize a side table to `ranger.str` text (grouped by segment)
-- ---------------------------------------------------------------------------

local SEG_ORDER = { "Person", "Thing", "Scene", "Wugong" }

function M.SerializeSideTable(side)
    local lines = {
        "# ranger.str - MOD side string table (UTF-8)",
        "# format: index,segment,record,field,value",
        "# index is segment-local, matching the hint in ranger.grp",
    }
    for _, segName in ipairs(SEG_ORDER) do
        local tbl = side[segName]
        if tbl then
            lines[#lines + 1] = "# " .. segName
            local keys = {}
            for k in pairs(tbl) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local meta = side.__meta and side.__meta[segName] and side.__meta[segName][k]
                local rec = meta and meta.rec or ""
                local field = meta and meta.field or ""
                -- values are written verbatim; a value never contains a newline
                lines[#lines + 1] = string.format("%04d,%s,%s,%s,%s",
                    k, segName, tostring(rec), tostring(field), tbl[k])
            end
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

-- ---------------------------------------------------------------------------
-- public: parse a `ranger.str` back into a side table (runtime + tests)
-- ---------------------------------------------------------------------------

function M.ParseSideTable(text)
    local side = { __meta = {} }
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local idx, seg, rec, field, value =
                line:match("^(%d+),([^,]+),([^,]*),([^,]*),(.*)$")
            if idx then
                local k = tonumber(idx)
                side[seg] = side[seg] or {}
                side.__meta[seg] = side.__meta[seg] or {}
                side[seg][k] = value
                side.__meta[seg][k] = { rec = tonumber(rec), field = field }
            end
        end
    end
    return side
end

-- ---------------------------------------------------------------------------
-- public: read a ranger.idx into a 6-entry 1-based offset list
-- ---------------------------------------------------------------------------

function M.ParseIdx(idxData)
    local offs = {}
    for i = 0, 5 do
        local o = i * 4
        if o + 4 > #idxData then break end
        local b1, b2, b3, b4 = idxData:byte(o + 1, o + 4)
        offs[i + 1] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    return offs
end

-- ---------------------------------------------------------------------------
-- public: decode a MOD ranger.grp for verification / auditing (pre-conversion)
-- ---------------------------------------------------------------------------

function M.DumpStrings(grp, idxOffsets)
    local out = {}
    for _, seg in ipairs(M.LAYOUT) do
        local s = idxOffsets[seg.seg + 1]
        local e = idxOffsets[seg.seg + 2]
        if s and e and e > s then
            local nrec = math.floor((e - s) / seg.rec)
            for r = 0, nrec - 1 do
                local rbase = s + r * seg.rec
                for _, f in ipairs(seg.fields) do
                    local raw = rawField(grp, rbase, f.off, f.len)
                    if raw ~= "" then
                        out[#out + 1] = {
                            seg = seg.name, field = f.name,
                            rec = r, offset = rbase + f.off,
                            value = M.DecodeBig5(raw),
                        }
                    end
                end
            end
        end
    end
    return out
end

return M
