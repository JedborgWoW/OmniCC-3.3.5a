-- a flare finish effect. Artwork by Renaitre
local ADDON, Addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)

local FLARE_TEXTURE = ([[Interface\Addons\%s\media\flare]]):format(ADDON)
local FLARE_DURATION = 0.75
local FLARE_SCALE = 5

local FlareEffect = Addon.FX:Create("flare", L.Flare)

local unused = {}

local function onFlareAnimationFinished(self)
	local parent = self:GetParent()
	-- Mark a natural finish so OnHide does not call animation:Stop() on the
	-- group whose OnFinished we are still inside. On stock 3.3.5a stopping an
	-- animation group from within its own finish callback corrupts the
	-- animation manager and crashes the client (#132).
	parent.finished = true
	if parent:IsShown() then
		parent:Hide()
	end
end

local function createFlareAnimation(parent)
	local animation = parent:CreateAnimationGroup()
	animation:SetScript('OnFinished', onFlareAnimationFinished)
	animation:SetLooping('NONE')

	local init = animation:CreateAnimation('Alpha')
	init:SetChange(-1)
	init:SetDuration(0)
	init:SetOrder(0)

	local grow = animation:CreateAnimation('Scale')
	grow:SetOrigin('CENTER', 0, 0)
	grow:SetScale(FLARE_SCALE, FLARE_SCALE)
	grow:SetDuration(FLARE_DURATION / 2)
	grow:SetOrder(1)

	local brighten = animation:CreateAnimation('Alpha')
	brighten:SetDuration(FLARE_DURATION / 2)
	brighten:SetChange(1)
	brighten:SetOrder(1)

	local shrink = animation:CreateAnimation('Scale')
	shrink:SetOrigin('CENTER', 0, 0)
	shrink:SetScale(1/FLARE_SCALE, 1/FLARE_SCALE)
	shrink:SetDuration(FLARE_DURATION / 2)
	shrink:SetOrder(2)

	local fade = animation:CreateAnimation('Alpha')
	fade:SetDuration(FLARE_DURATION / 2)
	fade:SetChange(-1)
	fade:SetOrder(2)

	return animation
end

local function onFlareFrameHidden(self)
	if not unused[self] then
		unused[self] = true
		-- Only stop when hidden externally mid-animation; a group that just
		-- finished is already stopped and stopping it here would crash 3.3.5a.
		if not self.finished then
			self.animation:Stop()
		end
		self.finished = nil
		self:Hide()
	end
end

local function createFlareFrame()
	local frame = CreateFrame('Frame')
	frame:Hide()
	frame:SetScript('OnHide', onFlareFrameHidden)
	frame:SetToplevel(true)

	local icon = frame:CreateTexture(nil, 'OVERLAY')
	icon:SetPoint('CENTER')
	icon:SetBlendMode('ADD')
	icon:SetAllPoints(icon:GetParent())
	icon:SetTexture(FLARE_TEXTURE)

	frame.animation = createFlareAnimation(frame)

	return frame
end

function FlareEffect:Run(cooldown)
	local owner = cooldown:GetParent() or cooldown

	if owner and owner:IsVisible() then
		local shine = next(unused) or createFlareFrame()
		unused[shine] = nil

		shine:SetParent(owner)
		shine:ClearAllPoints()
		shine:SetAllPoints(cooldown)
		shine:Show()
		shine.animation:Play()
	end
end
