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
local TRACKED_MAP_ID = 2346               -- Undermine
local VIGNETTES_TO_TRACK = { 6757, 6687 } -- SCRAP Heap
local trackedVignetteGUID = nil
local lastUpdatedTime = GetServerTime()
local DEFAULT_PIN_TEMPLATE = "VignettePinTemplate"
-- Pin template name for the addon RareScanner, which changes the default pin template name
local RS_PIN_TEMPLATE = "RSVignettePinTemplate"
local MAP_TYPE_WORLD_MAP = 1
local MAP_TYPE_BATTLEFIELD_MAP = 2

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

local battlefieldMapPathProvider = CreateFromMixins(MapCanvasDataProviderMixin)
function battlefieldMapPathProvider:HideLine()
	trackedVignetteGUID = nil
	-- Battlefield map may not be loaded yet
	if self:GetMap() then
		self:GetMap():RemoveAllPinsByTemplate(PATHPIN_TEMPLATE)
	end
end

function battlefieldMapPathProvider:OnShow()
	MapCanvasDataProviderMixin.OnShow(self)
end

function battlefieldMapPathProvider:OnHide()
	MapCanvasDataProviderMixin.OnHide(self)
end

-- pin mixins
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

function ns.DrawLine(pin, type, xy1, xy2, mapType)
	local t = ns.ResetPin(pin)
	t:SetVertexColor(.5, 1, .5, 1)
	t:SetTexture(type)

	local line_width = pin.parentHeight * 0.05

	local x1, y1 = xy1.x, xy1.y
	local x2, y2 = xy2.x, xy2.y
	local width = pin.parentWidth
	local height = pin.parentHeight
	if mapType == MAP_TYPE_BATTLEFIELD_MAP then
		line_width = line_width * 2
		width = width / BATTLEFIELD_MAP_POI_SCALE
		height = height / BATTLEFIELD_MAP_POI_SCALE
	end

	local x1p = x1 * width
	local x2p = x2 * width
	local y1p = y1 * height
	local y2p = y2 * height
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
	local battlefieldMapShown = (BattlefieldMapFrame and BattlefieldMapFrame:IsShown()) or false
	local shouldShow = (addonConfig["ShowOnWorldMap"] and WorldMapFrame:IsShown()) or
		(addonConfig["ShowOnBattlefieldMap"] and battlefieldMapShown)
	local eitherMapInTrackedZone = (WorldMapFrame.mapID == TRACKED_MAP_ID) or
		(BattlefieldMapFrame and BattlefieldMapFrame.mapID == TRACKED_MAP_ID)
	--check if one of the maps is opened
	if (shouldShow and eitherMapInTrackedZone and not IsInInstance() and addonConfig["Enabled"] and not InCombatLockdown()) then
		local pinPosX, pinPosY
		ns.HideLines()
		-- RareScanner changes the base VignettePinTemplate into RSVignettePinTemplate
		local isRareScannerActive = RareScanner or false
		local doRetry = true
		local pinTemplate = DEFAULT_PIN_TEMPLATE
		-- Be paranoid about an infinite loop due to some dump logic mistake I might make
		local count = 0
		while doRetry and count < 3 do
			count = count + 1
			for pin in vignettesPathProvider:GetMap():EnumeratePinsByTemplate(pinTemplate) do
				if (tableHas(VIGNETTES_TO_TRACK, pin:GetVignetteID())) then
					-- None of these Checks work when you leave the map open and the vignette goes away
					-- So you can't use them to detect when the line should disappear
					-- if (not pin:IsShown() or not pin:IsVisible() or pin:IsSuppressed()) then
					trackedVignetteGUID = pin:GetVignetteGUID()
					pinPosX, pinPosY = pin:GetPosition()
					doRetry = false
					-- Break the for loop
					break
				end
			end
			if battlefieldMapShown then
				for pin in battlefieldMapPathProvider:GetMap():EnumeratePinsByTemplate(pinTemplate) do
					if (tableHas(VIGNETTES_TO_TRACK, pin:GetVignetteID())) then
						-- None of these Checks work when you leave the map open and the vignette goes away
						-- So you can't use them to detect when the line should disappear
						-- if (not pin:IsShown() or not pin:IsVisible() or pin:IsSuppressed()) then
						trackedVignetteGUID = pin:GetVignetteGUID()
						pinPosX, pinPosY = pin:GetPosition()
						doRetry = false
						-- Break the for loop
						break
					end
				end
			end
			doRetry = false
			if (trackedVignetteGUID == nil and isRareScannerActive) then
				-- Are we already retrying?
				if (pinTemplate == RS_PIN_TEMPLATE) then
					break
				else
					pinTemplate = RS_PIN_TEMPLATE
					doRetry = true
				end
			end
		end

		-- No pin found (in reset stage)
		if not trackedVignetteGUID then
			return
		end

		--get the player map position
		local ppos = C_Map.GetPlayerMapPosition(TRACKED_MAP_ID, "player")

		if addonConfig["ShowOnWorldMap"] and WorldMapFrame:IsShown() and WorldMapFrame.mapID == TRACKED_MAP_ID then
			if (not ppos or not pinPosX or not pinPosY) then
				return
			end
			local map = vignettesPathProvider:GetMap()
			map:AcquirePin(PATHPIN_TEMPLATE, LINE, ppos, CreateVector2D(pinPosX, pinPosY), MAP_TYPE_WORLD_MAP)
		end
		if addonConfig["ShowOnBattlefieldMap"] and battlefieldMapShown then
			if (not ppos or not pinPosX or not pinPosY) then
				return
			end
			local map = battlefieldMapPathProvider:GetMap()
			map:AcquirePin(PATHPIN_TEMPLATE, LINE, ppos, CreateVector2D(pinPosX, pinPosY), MAP_TYPE_BATTLEFIELD_MAP)
		end
	else
		ns.HideLines()
	end
end

-- Need this function to remove the line once the event is complete
function UpdateFrame:OnEvent(event, arg1, ...)
	-- print("event fired " .. event)
	if event == "VIGNETTES_UPDATED" then
		if not trackedVignetteGUID then
			return
		end
		local vignettesByGUID = {};
		local vignettes = C_VignetteInfo.GetVignettes();
		if vignettes then
			for _, guid in ipairs(vignettes) do
				vignettesByGUID[guid] = true;
				if guid == trackedVignetteGUID then
					return
				end
			end
		end
		if not vignettesByGUID[trackedVignetteGUID] then
			ns.HideLines()
			return
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		if not addonConfig["Enabled"] then
			ns.Disable()
			return
		end
		ns.ShouldBeActive()
	elseif event == "VARIABLES_LOADED" then
		-- Our saved variables, if they exist, have been loaded at this point.
		if addonConfig == nil then
			-- This is the first time this addon is loaded; set SVs to default values
			addonConfig = {}
		end
		-- Set default config options
		if addonConfig["Enabled"] == nil then
			addonConfig["Enabled"] = true
		end
		if addonConfig["ShowOnWorldMap"] == nil then
			addonConfig["ShowOnWorldMap"] = true
		end
		if addonConfig["ShowOnBattlefieldMap"] == nil then
			addonConfig["ShowOnBattlefieldMap"] = true
		end
		UpdateFrame:UnregisterEvent("VARIABLES_LOADED")

		--add the provider to pins
		WorldMapFrame:AddDataProvider(vignettesPathProvider)
		-- If the Battlefield Map wasn't open upon load, we should then wait for it to be loaded (if ever)
		if not BattlefieldMapFrame then
			UpdateFrame:RegisterEvent("ADDON_LOADED")
		else
			BattlefieldMapFrame:AddDataProvider(battlefieldMapPathProvider)
		end

		print(ADDON_NAME .. " is " .. (addonConfig["Enabled"] and "enabled" or "disabled"))
		if addonConfig["Enabled"] then
			ns.ShouldBeActive()
		else
			ns.Disable()
		end
	elseif event == "ADDON_LOADED" and arg1 == "Blizzard_BattlefieldMap" then
		BattlefieldMapFrame:AddDataProvider(battlefieldMapPathProvider)
		UpdateFrame:UnregisterEvent("ADDON_LOADED")
	end
end

-- Try to ensure the addon only runs anything when in Undermine
function ns.ShouldBeActive()
	if C_Map.GetBestMapForUnit("player") == TRACKED_MAP_ID then
		-- print("everything activated")
		UpdateFrame:RegisterEvent("VIGNETTES_UPDATED")
		UpdateFrame:SetScript("OnUpdate", UpdateFrame.OnUpdate)
	else
		-- print("Wrong zone, inactive")
		UpdateFrame:UnregisterEvent("VIGNETTES_UPDATED")
		UpdateFrame:SetScript("OnUpdate", nil)
	end
end

function ns.HideLines()
	vignettesPathProvider:HideLine()
	battlefieldMapPathProvider:HideLine()
end

-- If the user wants the addon disabled
function ns.Disable()
	ns.HideLines()
	UpdateFrame:UnregisterEvent("VIGNETTES_UPDATED")
	UpdateFrame:SetScript("OnUpdate", nil)
end

-- Toggle the enabled-state of the addon
function ns.Toggle()
	addonConfig["Enabled"] = not addonConfig["Enabled"]
	print(ADDON_NAME .. " is now " .. (addonConfig["Enabled"] and "enabled" or "disabled"))
	if addonConfig["Enabled"] then
		ns.ShouldBeActive()
	else
		ns.Disable()
	end
end

SLASH_SCRAPHEAPEVENTS1 = "/scrapheapevents"
SlashCmdList["SCRAPHEAPEVENTS"] = function()
	Settings.OpenToCategory(ns.category.ID)
end

-- Need the event handler
UpdateFrame:SetScript("OnEvent", UpdateFrame.OnEvent)
UpdateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
UpdateFrame:RegisterEvent("VARIABLES_LOADED")
