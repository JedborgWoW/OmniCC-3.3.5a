-- code to drive the addon
local AddonName, Addon = ...
local CONFIG_ADDON = AddonName .. '_Config'
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

-- 3.3.5a has neither EventUtil nor EventRegistry, so we drive everything off a
-- single event frame.
local eventFrame = CreateFrame('Frame')

local function onAddonLoaded()
    Addon:InitializeDB()
    Addon.Cooldown:SetupHooks()

    -- setup addon compartment button (only exists on modern clients)
    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon{
            text = C_AddOns.GetAddOnMetadata(AddonName, "Title"),
            icon = C_AddOns.GetAddOnMetadata(AddonName, "IconTexture"),
            func = function() Addon:ShowOptionsFrame() end,
        }
    end

    -- setup slash commands
    SlashCmdList[AddonName] = function(cmd)
        if cmd == 'version' then
            print(L.Version:format(Addon.db.global.addonVersion))
        elseif cmd == 'config' then
            Addon:ShowOptionsFrame()
        else
            Addon:ShowOptionsFrame()
        end
    end

    SLASH_OmniCC1 = '/omnicc'
    SLASH_OmniCC2 = '/occ'
end

eventFrame:RegisterEvent('ADDON_LOADED')
eventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
eventFrame:SetScript('OnEvent', function(self, event, ...)
    if event == 'ADDON_LOADED' then
        local loadedAddon = ...
        if loadedAddon == AddonName then
            self:UnregisterEvent('ADDON_LOADED')
            onAddonLoaded()
        end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        Addon:PLAYER_ENTERING_WORLD()
    end
end)

function Addon:PLAYER_ENTERING_WORLD()
    self.Timer:ForActive('Update')
end

-- utility methods
function Addon:ShowOptionsFrame()
    if C_AddOns.LoadAddOn(CONFIG_ADDON) then
        local dialog = LibStub('AceConfigDialog-3.0')

        dialog:Open(AddonName)
        dialog:SelectGroup(AddonName, "themes", DEFAULT)

        return true
    end

    return false
end

function Addon:CreateHiddenFrame(...)
    local f = CreateFrame(...)

    f:Hide()

    return f
end

function Addon:GetButtonIcon(frame)
    if frame then
        local icon = frame.icon
        if type(icon) == 'table' and icon.GetTexture then
            return icon
        end

        local name = frame:GetName()
        if name then
            icon = _G[name .. 'Icon'] or _G[name .. 'IconTexture']

            if type(icon) == 'table' and icon.GetTexture then
                return icon
            end
        end
    end
end

-- exports
_G[AddonName] = Addon
