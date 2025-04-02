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
local lastUpdatedTime = GetServerTime()
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

function ns.VignettesUpdated()
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
	ns.HideLines()
	-- check if one of the maps is opened
	if (shouldShow and eitherMapInTrackedZone and not IsInInstance() and addonConfig["Enabled"] and not InCombatLockdown()) then
		local pinPos = nil
		local vignettes = C_VignetteInfo.GetVignettes();
		if vignettes then
			for _, guid in ipairs(vignettes) do
				local vignInfo = C_VignetteInfo.GetVignetteInfo(guid)
				if vignInfo then
					if tableHas(VIGNETTES_TO_TRACK, vignInfo.vignetteID) then
						pinPos = C_VignetteInfo.GetVignettePosition(guid, TRACKED_MAP_ID)
						break
					end
				end
			end
		end
		-- No valid pin position found (in reset stage)
		if not pinPos then
			return
		end

		-- get the player map position
		local ppos = C_Map.GetPlayerMapPosition(TRACKED_MAP_ID, "player")
		if (not ppos or not pinPos) then
			return
		end
		if addonConfig["ShowOnWorldMap"] and WorldMapFrame:IsShown() and WorldMapFrame.mapID == TRACKED_MAP_ID then
			local theMap = vignettesPathProvider:GetMap()
			if theMap then
				theMap:AcquirePin(PATHPIN_TEMPLATE, LINE, ppos, pinPos, MAP_TYPE_WORLD_MAP)
			end
		end
		if addonConfig["ShowOnBattlefieldMap"] and battlefieldMapShown then
			local theMap = battlefieldMapPathProvider:GetMap()
			if theMap then
				theMap:AcquirePin(PATHPIN_TEMPLATE, LINE, ppos, pinPos, MAP_TYPE_BATTLEFIELD_MAP)
			end
		end
	end
end

local UpdateFrame = CreateFrame("frame")

-- Need this function to remove the line once the event is complete
function UpdateFrame:OnEvent(event, arg1, ...)
	if event == "VIGNETTES_UPDATED" then
		ns.VignettesUpdated()
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
	else
		-- print("Wrong zone, inactive")
		UpdateFrame:UnregisterEvent("VIGNETTES_UPDATED")
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
