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
    local pending = {}
    local handler = CreateFrame("Frame")
    handler:Hide()

    handler:SetScript("OnUpdate", function(self)
        local now = GetTime()
        -- iterate backwards so we can remove in-place; callbacks scheduled by
        -- the callbacks themselves get appended and run on a later frame
        local count = #pending
        for i = count, 1, -1 do
            local entry = pending[i]
            if now >= entry.at then
                tremove(pending, i)
                local cb = entry.cb
                local ok, err = pcall(cb)
                if not ok then
                    geterrorhandler()(err)
                end
            end
        end

        if #pending == 0 then
            self:Hide()
        end
    end)

    function _G.C_Timer.After(delay, callback)
        pending[#pending + 1] = { at = GetTime() + (delay or 0), cb = callback }
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
        if type(index.GetSize) ~= "function" then
            function index.GetSize(self)
                return self:GetWidth(), self:GetHeight()
            end
        end
        if type(index.SetSize) ~= "function" then
            function index.SetSize(self, width, height)
                self:SetWidth(width)
                self:SetHeight(height or width)
            end
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
        function index.SetColorTexture(self, r, g, b, a)
            self:SetTexture(r, g, b, a or 1)
        end
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
            function index.SetFixedFrameStrata() end
        end
        if type(index.SetFixedFrameLevel) ~= "function" then
            function index.SetFixedFrameLevel() end
        end
        if type(index.SetPropagateKeyboardInput) ~= "function" then
            function index.SetPropagateKeyboardInput() end
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
            function index.SetCooldownDuration(self, duration, modRate)
                local d = tonumber(duration) or 0
                if d > 0 then
                    self:SetCooldown(GetTime(), d)
                else
                    self:SetCooldown(0, 0)
                end
            end
        end

        if type(index.GetCooldownDuration) ~= "function" then
            function index.GetCooldownDuration(self)
                return self._occ_duration and (self._occ_duration * 1000) or 0
            end
        end

        if type(index.Clear) ~= "function" then
            function index.Clear(self)
                self:SetCooldown(0, 0)
            end
        end

        -- purely cosmetic spiral tuning that doesn't exist on 3.3.5a
        if type(index.SetSwipeColor) ~= "function" then
            function index.SetSwipeColor() end
        end
        if type(index.SetDrawEdge) ~= "function" then
            function index.SetDrawEdge() end
        end
        if type(index.SetDrawSwipe) ~= "function" then
            function index.SetDrawSwipe() end
        end
        if type(index.SetEdgeTexture) ~= "function" then
            function index.SetEdgeTexture() end
        end
        if type(index.SetHideCountdownNumbers) ~= "function" then
            function index.SetHideCountdownNumbers() end
        end
        -- 3.3.5a never draws its own countdown numbers, so report them hidden
        if type(index.GetHideCountdownNumbers) ~= "function" then
            function index.GetHideCountdownNumbers()
                return true
            end
        end
    end

    cd:Hide()
end
