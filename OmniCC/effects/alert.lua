-- a finish effect that displays the cooldown at the center of the screen
local AddonName, Addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

local AlertFrame = CreateFrame("Frame", nil, UIParent)
AlertFrame:SetPoint("CENTER")
AlertFrame:SetSize(50, 50)
AlertFrame:SetAlpha(0)
AlertFrame:Hide()

local icon = AlertFrame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(AlertFrame)
AlertFrame.icon = icon

local animationGroup = AlertFrame:CreateAnimationGroup()
animationGroup:SetLooping("NONE")
animationGroup:SetScript("OnFinished", function() AlertFrame:Hide() end)
AlertFrame.animationGroup = animationGroup

-- 3.3.5a animation API: Scale animations are multiplicative (use the reciprocal
-- to undo a grow) and Alpha animations use SetChange (a delta) rather than
-- SetFromAlpha/SetToAlpha.
local function newScale(order, scale)
    local anim = animationGroup:CreateAnimation("Scale")
    anim:SetDuration(0.3)
    anim:SetOrder(order)
    anim:SetOrigin("CENTER", 0, 0)
    anim:SetScale(scale, scale)
end

local function newAlpha(order, change)
    local anim = animationGroup:CreateAnimation("Alpha")
    anim:SetDuration(0.3)
    anim:SetOrder(order)
    anim:SetChange(change)
end

-- grow + fade in
newScale(1, 2.5)
newAlpha(1, 0.7)

-- shrink + fade out
newScale(2, 1 / 2.5)
newAlpha(2, -0.7)

local AlertEffect = Addon.FX:Create("alert", L.Alert, L.AlertTip)

function AlertEffect:Run(cooldown)
	local buttonIcon = Addon:GetButtonIcon(cooldown:GetParent())
	if not buttonIcon then
		return
	end

	local alertAnimation = AlertFrame.animationGroup
	if alertAnimation:IsPlaying() then
		alertAnimation:Stop()
	end

	-- reset starting alpha so the SetChange deltas land where we expect
	AlertFrame:SetAlpha(0)
	AlertFrame:Show()

	local alertIcon = AlertFrame.icon
	alertIcon:SetVertexColor(buttonIcon:GetVertexColor())
	alertIcon:SetTexture(buttonIcon:GetTexture())

	alertAnimation:Play()
end
