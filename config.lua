local ADDON_NAME, ns = ...

-- Create options UI
local uniquealyzer = 0;
local function createCheckbutton(parent, x_loc, y_loc, displayname)
	uniquealyzer = uniquealyzer + 1;

	local checkbutton = CreateFrame("CheckButton", "ScrapHeapEvents_cb" .. uniquealyzer, parent,
		"ChatConfigCheckButtonTemplate");
	checkbutton:SetPoint("TOPLEFT", x_loc, y_loc);
	getglobal(checkbutton:GetName() .. 'Text'):SetText(displayname);

	return checkbutton;
end

-- Create the Blizzard addon option frame
local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer);
panel:RegisterEvent("ADDON_LOADED");
panel:Hide()

-- Handle the events as they happen
panel:SetScript("OnShow", function(panel)
	local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	fs:SetPoint("TOPLEFT", 10, -15);
	fs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 10, -45);
	fs:SetJustifyH("LEFT");
	fs:SetJustifyV("TOP");
	fs:SetText(ADDON_NAME);

	-- Create option for completely disabling the addon
	local cb1 = createCheckbutton(panel, 10, -45, "Enable " .. ADDON_NAME .. " functionality");
	cb1:SetScript("OnClick",
		function(self)
			ns.Toggle()
		end
	);

	-- Create option for drawing the line on the World Map
	local cb2 = createCheckbutton(panel, 10, -75, "Show on the World Map");
	cb2:SetScript("OnClick",
		function(self)
			addonConfig["ShowOnWorldMap"] = self:GetChecked();
		end
	);

	-- Create option for drawing the line on the Battlefield Map
	local cb3 = createCheckbutton(panel, 10, -105, "Show on the Battlefield Map");
	cb3:SetScript("OnClick",
		function(self)
			addonConfig["ShowOnBattlefieldMap"] = self:GetChecked();
		end
	);

	-- Create label to show how the links appear
	local infoLabel = panel:CreateFontString("ScrapHeapEvents_infoLabel", "OVERLAY", "GameFontNormalSmall");
	infoLabel:SetPoint("TOPLEFT", 35, -125);
	infoLabel:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 35, -185);
	infoLabel:SetJustifyH("LEFT");
	infoLabel:SetJustifyV("TOP");
	cb1:SetChecked(addonConfig["Enabled"]);
	cb2:SetChecked(addonConfig["ShowOnWorldMap"]);
	cb3:SetChecked(addonConfig["ShowOnBattlefieldMap"]);
	panel:SetScript("OnShow", nil);
end)
panel.name = ADDON_NAME;
ns.category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
Settings.RegisterAddOnCategory(ns.category)
