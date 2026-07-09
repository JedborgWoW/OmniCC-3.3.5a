-- compat.lua
-- Compatibility shims so the modern OmniCC code base can run on the
-- Wrath of the Lich King 3.3.5a client (interface 30300).
--
-- This file MUST be loaded before everything else (see OmniCC.toc). It only
-- ever *adds* things that are missing on 3.3.5a, so it is safe to leave loaded
-- even if a future client happens to provide some of these natively.

local _G = _G
local floor = math.floor
local tinsert, tremove = table.insert, table.remove
local select, unpack = select, unpack

-------------------------------------------------------------------------------
-- WOW_PROJECT_ID (added in Legion / Classic) -- some bundled code branches on
-- it (e.g. AceGUI's ColorPicker). 3.3.5a never sets these, so define the
-- standard constants and report ourselves as the Wrath Classic project so the
-- upstream code takes the nearest Classic code path.
-------------------------------------------------------------------------------

if _G.WOW_PROJECT_MAINLINE == nil then
    _G.WOW_PROJECT_MAINLINE = 1
end
if _G.WOW_PROJECT_CLASSIC == nil then
    _G.WOW_PROJECT_CLASSIC = 2
end
if _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC == nil then
    _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
end
if _G.WOW_PROJECT_WRATH_CLASSIC == nil then
    _G.WOW_PROJECT_WRATH_CLASSIC = 11
end
if _G.WOW_PROJECT_ID == nil then
    _G.WOW_PROJECT_ID = _G.WOW_PROJECT_WRATH_CLASSIC
end

-------------------------------------------------------------------------------
-- xpcall vararg support (Lua 5.2+). On Lua 5.1 (3.3.5a) xpcall(f, handler, ...)
-- silently DROPS the extra arguments, so Ace3's safecall
-- (xpcall(func, errorhandler, ...)) loses `self` and blows up with
-- "attempt to index local 'self' (a nil value)". Wrap any extra args in a
-- closure so they reach func. No-arg calls keep the native fast path.
-------------------------------------------------------------------------------

do
    local orig_xpcall = xpcall
    -- probe whether the native xpcall already forwards varargs (5.2+): the
    -- second return value is the value the probe function passed through.
    local _, forwarded = orig_xpcall(function(a) return a end, function() end, true)
    if not forwarded then
        function _G.xpcall(f, errorhandler, ...)
            local n = select("#", ...)
            if n == 0 then
                return orig_xpcall(f, errorhandler)
            end
            local args = { ... }
            return orig_xpcall(function()
                return f(unpack(args, 1, n))
            end, errorhandler)
        end
    end
end

-------------------------------------------------------------------------------
-- securecallfunction (used by CallbackHandler-1.0)
-- 3.3.5a only has securecall/pcall; a plain forwarding call is good enough for
-- an addon and preserves return values.
-------------------------------------------------------------------------------

if type(_G.securecallfunction) ~= "function" then
    function _G.securecallfunction(func, ...)
        return func(...)
    end
end

-------------------------------------------------------------------------------
-- Round (added in Legion)
-------------------------------------------------------------------------------

if type(_G.Round) ~= "function" then
    function _G.Round(value)
        return floor(value + 0.5)
    end
end

-------------------------------------------------------------------------------
-- CopyTable (deep copy) -- WotLK has it in FrameXML, but polyfill defensively
-------------------------------------------------------------------------------

if type(_G.CopyTable) ~= "function" then
    local function copy(src)
        local dest = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                dest[k] = copy(v)
            else
                dest[k] = v
            end
        end
        return dest
    end
    _G.CopyTable = copy
end

-------------------------------------------------------------------------------
-- GetCurrentRegion / GetCurrentRegionName (added in WoD) -- used by AceDB-3.0
-- for region-scoped profile keys. 3.3.5a has no region concept, so report US.
-------------------------------------------------------------------------------

if type(_G.GetCurrentRegion) ~= "function" then
    function _G.GetCurrentRegion()
        return 1
    end
end

if type(_G.GetCurrentRegionName) ~= "function" then
    function _G.GetCurrentRegionName()
        return "US"
    end
end

-------------------------------------------------------------------------------
-- tIndexOf (FrameXML helper not present on 3.3.5a)
-------------------------------------------------------------------------------

if type(_G.tIndexOf) ~= "function" then
    function _G.tIndexOf(tbl, item)
        for i, v in ipairs(tbl) do
            if v == item then
                return i
            end
        end
    end
end

-------------------------------------------------------------------------------
-- C_AddOns namespace (Dragonflight) -> classic globals
-------------------------------------------------------------------------------

if type(_G.C_AddOns) ~= "table" then
    _G.C_AddOns = {
        GetAddOnMetadata = _G.GetAddOnMetadata,
        LoadAddOn = _G.LoadAddOn,
        IsAddOnLoaded = _G.IsAddOnLoaded,
        EnableAddOn = _G.EnableAddOn,
        DisableAddOn = _G.DisableAddOn,
        GetNumAddOns = _G.GetNumAddOns,
        GetAddOnInfo = _G.GetAddOnInfo,
    }
end

-------------------------------------------------------------------------------
-- C_UI namespace
-------------------------------------------------------------------------------

if type(_G.C_UI) ~= "table" then
    _G.C_UI = {}
end
if type(_G.C_UI.Reload) ~= "function" then
    _G.C_UI.Reload = _G.ReloadUI
end

-------------------------------------------------------------------------------
-- GetTickTime (added in Legion) -- a small floor for scheduling sleeps
-------------------------------------------------------------------------------

if type(_G.GetTickTime) ~= "function" then
    function _G.GetTickTime()
        return 0.01
    end
end

-------------------------------------------------------------------------------
-- C_Timer.After (added in WoD) -- OnUpdate based scheduler
-------------------------------------------------------------------------------

if type(_G.C_Timer) ~= "table" then
    _G.C_Timer = {}
end

if type(_G.C_Timer.After) ~= "function" then
    -- Zero-allocation scheduler. OmniCC reschedules an After callback for EVERY
    -- tick of EVERY visible cooldown timer (plus every finish effect and display
    -- resize), so a fresh entry table per call - and tremove's array shifting on
    -- every expiry - churned enough garbage to contribute to periodic ~1s GC
    -- freezes. Entry tables are pooled and the queue is compacted in place.
    local pending = {}   -- live entries, kept dense in 1..npending
    local npending = 0
    local pool = {}      -- expired entry tables, reused by After
    local npool = 0
    local handler = CreateFrame("Frame")
    handler:Hide()

    handler:SetScript("OnUpdate", function(self)
        local now = GetTime()
        -- callbacks scheduled by the callbacks themselves land at indexes > n
        -- and run on a later frame, exactly like the old backwards loop
        local n = npending
        local kept = 0
        for i = 1, n do
            local entry = pending[i]
            if now >= entry.at then
                local cb = entry.cb
                -- recycle BEFORE the call so the entry drops its closure even if
                -- the callback errors; After may hand it out again immediately
                entry.cb = false
                npool = npool + 1
                pool[npool] = entry
                local ok, err = pcall(cb)
                if not ok then
                    geterrorhandler()(err)
                end
            else
                kept = kept + 1
                if kept ~= i then
                    pending[kept] = entry
                end
            end
        end
        -- slide any entries appended during the loop down onto the kept block
        for i = n + 1, npending do
            kept = kept + 1
            pending[kept] = pending[i]
        end
        for i = kept + 1, npending do
            pending[i] = nil
        end
        npending = kept

        if npending == 0 then
            self:Hide()
        end
    end)

    function _G.C_Timer.After(delay, callback)
        local entry
        if npool > 0 then
            entry = pool[npool]
            pool[npool] = nil
            npool = npool - 1
        else
            entry = {}
        end
        entry.at = GetTime() + (delay or 0)
        entry.cb = callback
        npending = npending + 1
        pending[npending] = entry
        handler:Show()
    end
end

-------------------------------------------------------------------------------
-- Region:SetSize / GetSize (added in Cataclysm) -> SetWidth + SetHeight.
-- Applied to every widget/region method table OmniCC and the bundled Ace3 use,
-- since each frame type has its own method table on this client.
-------------------------------------------------------------------------------

do
    local function addSizeMethods(index)
        if type(index) ~= "table" then
            return
        end
        -- rawset for NEW methods: on this client the frame-type __index table
        -- carries a __newindex guard that silently drops a plain `function
        -- index.X` (an assignment) for a key that doesn't exist yet, leaving the
        -- method nil. rawset bypasses it; the type()~="function" reads stay
        -- chain-aware so a native is never shadowed.
        if type(index.GetSize) ~= "function" then
            rawset(index, "GetSize", function(self)
                return self:GetWidth(), self:GetHeight()
            end)
        end
        if type(index.SetSize) ~= "function" then
            rawset(index, "SetSize", function(self, width, height)
                self:SetWidth(width)
                self:SetHeight(height or width)
            end)
        end
    end

    local function indexOf(object)
        local mt = object and getmetatable(object)
        return mt and mt.__index
    end

    local probe = CreateFrame("Frame")

    -- frame-derived widget types
    local frameTypes = {
        "Frame", "Button", "CheckButton", "EditBox", "Slider", "StatusBar",
        "ScrollFrame", "Cooldown", "GameTooltip", "ColorSelect", "MessageFrame",
        "SimpleHTML", "ScrollingMessageFrame", "Model",
    }
    for _, frameType in ipairs(frameTypes) do
        local ok, f = pcall(CreateFrame, frameType)
        if ok and f then
            addSizeMethods(indexOf(f))
            if f.Hide then
                f:Hide()
            end
        end
    end

    -- regions
    addSizeMethods(indexOf(probe:CreateTexture()))
    addSizeMethods(indexOf(probe:CreateFontString()))

    probe:Hide()
end

-------------------------------------------------------------------------------
-- Texture:SetColorTexture (added in Legion) -> SetTexture(r, g, b, a)
-------------------------------------------------------------------------------

do
    local tex = UIParent:CreateTexture()
    local mt = getmetatable(tex)
    local index = mt and mt.__index
    if type(index) == "table" and type(index.SetColorTexture) ~= "function" then
        rawset(index, "SetColorTexture", function(self, r, g, b, a)
            self:SetTexture(r, g, b, a or 1)
        end)
    end
end

-------------------------------------------------------------------------------
-- Frame methods added after 3.3.5a that the bundled (modern) Ace3 calls.
-- These are layout/keyboard niceties with no equivalent on this client, so they
-- become harmless no-ops.
-------------------------------------------------------------------------------

do
    local frame = CreateFrame("Frame")
    local mt = getmetatable(frame)
    local index = mt and mt.__index

    if type(index) == "table" then
        if type(index.SetFixedFrameStrata) ~= "function" then
            rawset(index, "SetFixedFrameStrata", function() end)
        end
        if type(index.SetFixedFrameLevel) ~= "function" then
            rawset(index, "SetFixedFrameLevel", function() end)
        end
        if type(index.SetPropagateKeyboardInput) ~= "function" then
            rawset(index, "SetPropagateKeyboardInput", function() end)
        end
    end

    frame:Hide()
end

-------------------------------------------------------------------------------
-- Cooldown widget methods that were added after 3.3.5a.
--
-- OmniCC's core hooks Cooldown:SetCooldown, which DOES exist on 3.3.5a, so we
-- only need to fill in the newer helpers. The non-visual ones become no-ops;
-- SetCooldownDuration / Clear route through the real SetCooldown so anything
-- that drives a cooldown through them (e.g. the config preview) still works and
-- is still seen by OmniCC's hook.
-------------------------------------------------------------------------------

do
    local cd = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
    local mt = getmetatable(cd)
    local index = mt and mt.__index

    if type(index) == "table" then
        if type(index.SetCooldownDuration) ~= "function" then
            rawset(index, "SetCooldownDuration", function(self, duration, modRate)
                local d = tonumber(duration) or 0
                if d > 0 then
                    self:SetCooldown(GetTime(), d)
                else
                    self:SetCooldown(0, 0)
                end
            end)
        end

        if type(index.GetCooldownDuration) ~= "function" then
            rawset(index, "GetCooldownDuration", function(self)
                return self._occ_duration and (self._occ_duration * 1000) or 0
            end)
        end

        if type(index.Clear) ~= "function" then
            rawset(index, "Clear", function(self)
                self:SetCooldown(0, 0)
            end)
        end

        -- purely cosmetic spiral tuning that doesn't exist on 3.3.5a
        if type(index.SetSwipeColor) ~= "function" then
            rawset(index, "SetSwipeColor", function() end)
        end
        if type(index.SetDrawEdge) ~= "function" then
            rawset(index, "SetDrawEdge", function() end)
        end
        if type(index.SetDrawSwipe) ~= "function" then
            rawset(index, "SetDrawSwipe", function() end)
        end
        if type(index.SetEdgeTexture) ~= "function" then
            rawset(index, "SetEdgeTexture", function() end)
        end
        if type(index.SetHideCountdownNumbers) ~= "function" then
            rawset(index, "SetHideCountdownNumbers", function() end)
        end
        -- 3.3.5a never draws its own countdown numbers, so report them hidden
        if type(index.GetHideCountdownNumbers) ~= "function" then
            rawset(index, "GetHideCountdownNumbers", function()
                return true
            end)
        end
    end

    cd:Hide()
end

-------------------------------------------------------------------------------
-- GameTooltip:SetSpellByID (added in MoP) and crash-safe SetHyperlink.
--
-- SetSpellByID does not exist on 3.3.5a. Worse, SetHyperlink("spell:<id>") with
-- a spell id the core does not actually know about triggers a *native* client
-- crash (ACCESS_VIOLATION, see issue #132). We therefore always validate spell
-- links with GetSpellInfo before handing them to the real SetHyperlink, and
-- build SetSpellByID on top of that guarded path. Patching the shared tooltip
-- metatable covers GameTooltip, ItemRefTooltip and every library-owned tooltip.
-------------------------------------------------------------------------------

do
    local mt = GameTooltip and getmetatable(GameTooltip)
    local index = mt and mt.__index

    if type(index) == "table" then
        local origSetHyperlink = index.SetHyperlink
        if type(origSetHyperlink) == "function" then
            function index.SetHyperlink(self, link, ...)
                local spellId = link and tostring(link):match("spell:(%d+)")
                if spellId and not GetSpellInfo(tonumber(spellId)) then
                    -- unknown spell id -> would hard-crash the client; ignore it
                    return
                end
                return origSetHyperlink(self, link, ...)
            end
        end

        if type(index.SetSpellByID) ~= "function" then
            rawset(index, "SetSpellByID", function(self, spellId)
                if not spellId or not GetSpellInfo(spellId) then
                    return
                end
                return self:SetHyperlink("spell:" .. spellId)
            end)
        end
    end
end
