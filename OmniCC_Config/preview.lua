-- preview.lua (3.3.5a backport)
-- A small movable window that shows a live sample cooldown so the user can see
-- what the current theme looks like. Rebuilt using widgets/APIs that exist on
-- the Wrath 3.3.5a client.
local AddonName, Addon = ...
local OmniCC = _G.OmniCC
local L = LibStub("AceLocale-3.0"):GetLocale("OmniCC")
local DEFAULT_DURATION = 30

local FALLBACK_ICON = "Interface\\Icons\\Spell_Nature_TimeStop"

local function getRandomIcon()
    local numTabs = GetNumSpellTabs()
    if numTabs and numTabs > 0 then
        local _, _, offset, numSlots = GetSpellTabInfo(numTabs)
        local total = (offset or 0) + (numSlots or 0)
        if total > 0 then
            local tex = GetSpellTexture(math.random(1, total), BOOKTYPE_SPELL)
            if tex then
                return tex
            end
        end
    end

    return FALLBACK_ICON
end

-- preview dialog
local PreviewDialog = CreateFrame("Frame", AddonName .. "PreviewDialog", UIParent)

PreviewDialog:Hide()
PreviewDialog:SetClampedToScreen(true)
PreviewDialog:SetFrameStrata("TOOLTIP")
PreviewDialog:SetMovable(true)
PreviewDialog:EnableMouse(true)
PreviewDialog:SetToplevel(true)
PreviewDialog:SetSize(165, 165)
PreviewDialog:ClearAllPoints()
PreviewDialog:SetPoint("CENTER")

PreviewDialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- drag handling
PreviewDialog:RegisterForDrag("LeftButton")
PreviewDialog:SetScript("OnDragStart", PreviewDialog.StartMoving)
PreviewDialog:SetScript("OnDragStop", PreviewDialog.StopMovingOrSizing)

-- title text
local titleText = PreviewDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
titleText:SetPoint("TOP", 0, -14)
titleText:SetText(L.Preview)

-- close button
local closeButton = CreateFrame("Button", nil, PreviewDialog, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", 2, 2)

-- container
local container = CreateFrame("Frame", nil, PreviewDialog)
container:SetPoint("TOPLEFT", 14, -30)
container:SetPoint("BOTTOMRIGHT", -14, 12)

-- container bg
local bg = container:CreateTexture(nil, "BACKGROUND")
bg:SetTexture(1, 1, 1, 0.3)
bg:SetAllPoints()

-- action icon
local icon = container:CreateTexture(nil, "ARTWORK")
icon:SetSize(ActionButton1:GetWidth() * 2, ActionButton1:GetHeight() * 2)
icon:SetPoint("TOP", 0, -4)
PreviewDialog.icon = icon
container.icon = icon

-- cooldown
local cooldown = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
cooldown:SetAllPoints(icon)

PreviewDialog.cooldown = cooldown

-- duration input
local editBoxText = container:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
editBoxText:SetText(L.Duration)
editBoxText:SetPoint("TOP", icon, "BOTTOM", 0, -4)

local editBox = CreateFrame("EditBox", "$parentDurationInput", container, "InputBoxTemplate")
editBox:SetAutoFocus(false)
editBox:SetNumeric(true)
editBox:SetMaxLetters(7)
editBox:SetJustifyH("CENTER")
editBox:SetSize(container:GetWidth() - 40, 20)
editBox:SetPoint("TOP", editBoxText, "BOTTOM", 0, -4)

local function getDuration()
    return tonumber(editBox:GetText()) or 0
end

editBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    PreviewDialog:StartCooldown(getDuration())
end)
editBox:SetScript("OnEditFocusLost", function(self)
    PreviewDialog:StartCooldown(getDuration())
end)

PreviewDialog.duration = editBox

-- 3.3.5a has no OnCooldownDone, so loop the preview ourselves. A generation
-- token makes sure only the most recent cooldown restarts the loop.
PreviewDialog.loopGen = 0

function PreviewDialog:StartCooldown(duration)
    duration = tonumber(duration) or 0

    self.loopGen = self.loopGen + 1
    local gen = self.loopGen

    if duration <= 0 then
        self.cooldown:SetCooldown(0, 0)
        return
    end

    self.icon:SetTexture(getRandomIcon())
    self.cooldown:SetCooldown(GetTime(), duration)

    C_Timer.After(duration, function()
        if gen == PreviewDialog.loopGen and PreviewDialog:IsVisible() then
            PreviewDialog:StartCooldown(getDuration())
        end
    end)
end

PreviewDialog:SetScript("OnShow", function(self)
    if self.duration:GetText() == "" then
        self.duration:SetText(DEFAULT_DURATION)
    end
    self:StartCooldown(getDuration())
end)

PreviewDialog:SetScript("OnHide", function(self)
    self.loopGen = self.loopGen + 1
    self.cooldown:SetCooldown(0, 0)
end)

editBox:SetText(DEFAULT_DURATION)

-- preview
function PreviewDialog:SetTheme(theme)
    self.cooldown._occ_settings_force = theme

    if OmniCC.Cooldown.UpdateSettings(self.cooldown) then
        local display = OmniCC.Display:Get(self.cooldown:GetParent())
        if display then
            display:UpdateCooldownText()
        end
    end

    self:Show()
end

-- exports
Addon.PreviewDialog = PreviewDialog
