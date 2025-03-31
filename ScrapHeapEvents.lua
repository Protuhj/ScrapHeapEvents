--[[
ScrapHeapEvents
Author: Protuhj
Description: Relatively simple addon to draw a line from your character to S.C.R.A.P Heap events in Undermine

Contains some code fragments and ideas from other addons like WorldQuestTracker and Zarillion's HandyNotes plugins.
]]

local ADDON_NAME, ns = ...
local LINE = 'Interface\\AddOns\\' .. ADDON_NAME .. '\\line'
local PATHPIN_TEMPLATE = "ScrapHeapEventsPathPinTemplate"

-------------------------------
local enabled = true
local trackedMapID = 2346 -- Undermine
local trackedVignetteID = {6757, 6687} -- SCRAP Heap
local trackedVignetteGUID = nil
local lastUpdatedTime = GetServerTime()
local DEFAULT_PIN_TEMPLATE = "VignettePinTemplate"
-- Pin template name for the addon RareScanner, which changes the default pin template name
local RS_PIN_TEMPLATE = "RSVignettePinTemplate"


local function tableHas(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local vignettesPathProvider = CreateFromMixins(MapCanvasDataProviderMixin)
function vignettesPathProvider:HideLine()
	trackedVignetteGUID = nil
	self:GetMap():RemoveAllPinsByTemplate(PATHPIN_TEMPLATE)
end

function vignettesPathProvider:OnShow()
	MapCanvasDataProviderMixin.OnShow(self)
end

function vignettesPathProvider:OnHide()
	MapCanvasDataProviderMixin.OnHide(self)
end

-- pin mixin
ScrapHeapEventsPathPinMixin = CreateFromMixins(MapCanvasPinMixin)
function ScrapHeapEventsPathPinMixin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
end

function ScrapHeapEventsPathPinMixin:SetPassThroughButtons() end

function ScrapHeapEventsPathPinMixin:OnAcquired(...)
    local _, _, w, h = self:GetParent():GetRect()
    self.parentWidth = w
    self.parentHeight = h

    if (w and h) then
        local x, y = ns.DrawLine(self, ...)
        self:ApplyCurrentScale()
        self:SetPosition(x, y)
    end
end

function ScrapHeapEventsPathPinMixin:ApplyFrameLevel()
    MapCanvasPinMixin.ApplyFrameLevel(self)
end

--add the provider to pins
WorldMapFrame:AddDataProvider(vignettesPathProvider)

function ns.ResetPin(pin)
    pin.texture:SetRotation(0)
    pin.texture:SetTexCoord(0, 1, 0, 1)
    pin.texture:SetVertexColor(1, 1, 1, 1)
    pin.frameOffset = 0
    pin.rotation = nil
    pin:SetAlpha(1)
    if pin.SetScalingLimits then
        pin:SetScalingLimits(nil, nil, nil)
    end
    return pin.texture
end

function ns.DrawLine(pin, type, xy1, xy2)
    local t = ns.ResetPin(pin)
    t:SetVertexColor(.5, 1, .5, 1)
    t:SetTexture(type)

    local line_width = pin.parentHeight * 0.05

	local x1, y1 = xy1.x, xy1.y
	local x2, y2 = xy2.x, xy2.y


	local x1p = x1 * pin.parentWidth
	local x2p = x2 * pin.parentWidth
	local y1p = y1 * pin.parentHeight
	local y2p = y2 * pin.parentHeight
	local line_length = sqrt((x2p - x1p) ^ 2 + (y2p - y1p) ^ 2)

	pin.rotation = -math.atan2(y2p - y1p, x2p - x1p)

	pin:SetSize(line_length, line_width)
	pin.texture:SetRotation(pin.rotation)

	return (x1 + x2) / 2, (y1 + y2) / 2
end

local UpdateFrame = CreateFrame("frame")
function UpdateFrame:OnUpdate()
	-- Let's not check this too often
	if (GetServerTime() - lastUpdatedTime < 1) then
		return
	end
	-- print(GetServerTime())
	lastUpdatedTime = GetServerTime()
	--check if the map is opened
	if (WorldMapFrame:IsShown() and WorldMapFrame.mapID == trackedMapID and not IsInInstance() and enabled and not InCombatLockdown()) then
		local trackedVignettePin = nil
		vignettesPathProvider:HideLine()
		-- RareScanner changes the base VignettePinTemplate into RSVignettePinTemplate
		local isRareScannerActive = RareScanner or false
		local doRetry = true
		local pinTemplate = DEFAULT_PIN_TEMPLATE
		-- Be paranoid about an infinite loop due to some dump logic mistake I might make
		local count = 0
		while doRetry and count < 3 do
			count = count + 1
			for pin in vignettesPathProvider:GetMap():EnumeratePinsByTemplate(pinTemplate) do
				if (tableHas(trackedVignetteID, pin:GetVignetteID())) then
					-- None of these Checks work when you leave the map open and the vignette goes away
					-- So you can't use them to detect when the line should disappear
					-- if (not pin:IsShown() or not pin:IsVisible() or pin:IsSuppressed()) then
					trackedVignettePin = pin
					doRetry = false
					break
				end
			end
			doRetry = false
			if (trackedVignettePin == nil and isRareScannerActive) then
				-- Are we already retrying?
				if (pinTemplate == RS_PIN_TEMPLATE) then
					break
				else
					pinTemplate = RS_PIN_TEMPLATE
					doRetry = true
				end
			end
		end
		if (trackedVignettePin == nil) then
			return
		end
		trackedVignetteGUID = trackedVignettePin:GetVignetteGUID()
		--get the player map position
		local ppos = C_Map.GetPlayerMapPosition(WorldMapFrame.mapID, "player")
		local pinPosX, pinPosY = trackedVignettePin:GetPosition()
		if (not ppos or not pinPosX or not pinPosY) then
			return
		end
		local map = vignettesPathProvider:GetMap()
		map:AcquirePin(PATHPIN_TEMPLATE, LINE, ppos, CreateVector2D(pinPosX, pinPosY))
	else
		vignettesPathProvider:HideLine()
	end
end

-- Need this function to remove the line once the event is complete
function UpdateFrame:OnEvent(event, ...)
	-- print("event fired " .. event)
    if event == "VIGNETTES_UPDATED" then
        if not trackedVignetteGUID then
			return
		end
		local vignettesByGUID = {};
		local vignettes = C_VignetteInfo.GetVignettes();
		if vignettes then
			for _,guid in ipairs(vignettes) do
				vignettesByGUID[guid] = true;
				if guid == trackedVignetteGUID then
					return
				end
			end
		end
		if not vignettesByGUID[trackedVignetteGUID] then
			vignettesPathProvider:HideLine()
			return
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		if not enabled then
			return
		end
		ns.ShouldBeActive()
	end
end

-- Try to ensure the addon only runs anything when in Undermine
function ns.ShouldBeActive()
	if C_Map.GetBestMapForUnit("player") == trackedMapID then
		-- print("everything activated")
		print(ADDON_NAME .. " is active, enter /scrapheapevents to toggle it on or off.")
		UpdateFrame:RegisterEvent("VIGNETTES_UPDATED")
		UpdateFrame:SetScript("OnUpdate", UpdateFrame.OnUpdate)
	else
		-- print("Wrong zone, inactive")
		UpdateFrame:UnregisterEvent("VIGNETTES_UPDATED")
		UpdateFrame:SetScript("OnUpdate", nil)
	end
end

-- If the user wants the addon disabled
function ns.Disable()
	vignettesPathProvider:HideLine()
	UpdateFrame:UnregisterEvent("VIGNETTES_UPDATED")
	UpdateFrame:SetScript("OnUpdate", nil)
end
SLASH_SCRAPHEAPEVENTS1 = "/scrapheapevents"
SlashCmdList["SCRAPHEAPEVENTS"] = function()
	enabled = not enabled
	print(ADDON_NAME .. " is now " .. (enabled and "enabled" or "disabled"))
	if enabled then
		ns.ShouldBeActive()
	else
		ns.Disable()
	end
end

-- First time through
ns.ShouldBeActive()
-- Need the event handler
UpdateFrame:SetScript("OnEvent", UpdateFrame.OnEvent)
UpdateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
