local ADDON_NAME, ns = ...

-- Create options UI
local uniquealyzer = 0;
local function createCheckbutton(parent, x_loc, y_loc, displayname)
	uniquealyzer = uniquealyzer + 1;

	local checkbutton = CreateFrame("CheckButton", "ScrapHeapEvents_cb" .. uniquealyzer, parent,
		"ChatConfigCheckButtonTemplate");
	checkbutton:SetPoint("TOPLEFT", x_loc, y_loc);
	getglobal(checkbutton:GetName() .. 'Text'):SetText(displayname);
	getglobal(checkbutton:GetName() .. 'Text'):SetWidth(500);

	return checkbutton;
end

local function createSoundInputField(parent, x_loc, y_loc, displayname)
	uniquealyzer = uniquealyzer + 1;

	local editbox = CreateFrame("EditBox", "ScrapHeapEvents_eb" .. uniquealyzer, parent,
		"InputBoxTemplate");
	editbox:SetPoint("TOPLEFT", x_loc, y_loc);
	editbox:SetMaxLetters(6)
	editbox:SetNumeric(true)
	-- editbox:SetTextInsets(5, 5, 5, -5)
	-- editbox:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE, THICK")
	editbox:SetAutoFocus(false)
	editbox:SetJustifyV("TOP")
	editbox:SetJustifyH("LEFT")
	editbox:SetSize(70, 40)
	uniquealyzer = uniquealyzer + 1;
	local testbutton = CreateFrame("Button", "ScrapHeapEvents_tb" .. uniquealyzer, parent, "UIPanelButtonTemplate");
	testbutton:SetPoint("TOPLEFT", editbox, "TOPRIGHT", 15, -5)
	testbutton:SetWidth(100)
	testbutton:SetHeight(30)
	testbutton.tooltip = "Test the sound"
	testbutton:SetScript("OnClick", function(_)
		if editbox:GetNumber() ~= nil then
			PlaySound(editbox:GetNumber())
		end
	end)
	getglobal(testbutton:GetName() .. "Text"):SetText(displayname);
	uniquealyzer = uniquealyzer + 1;
	local resetbutton = CreateFrame("Button", "ScrapHeapEvents_tb" .. uniquealyzer, parent, "UIPanelButtonTemplate");
	resetbutton:SetPoint("TOPLEFT", testbutton, "TOPRIGHT", 15)
	resetbutton:SetWidth(120)
	resetbutton:SetHeight(30)
	resetbutton.tooltip = "Reset to default"
	resetbutton:SetScript("OnClick", function(_)
		editbox:SetNumber(ns.DEFAULT_ALERT_SOUND)
		ns:validateSoundInput(editbox)
	end)
	getglobal(resetbutton:GetName() .. "Text"):SetText("Reset to default")

	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", editbox, "BOTTOMLEFT", 0, -15);
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetText("To view more sounds, go to this URL to find one you like:|n" ..
		" - ctrl+c to copy the URL, then ctrl+v to paste in your browser|n" ..
		" - When you find one you like, enter the number after 'sound=' from the URL")
	uniquealyzer = uniquealyzer + 1;
	local urlbox = CreateFrame("EditBox", "ScrapHeapEvents_eb" .. uniquealyzer, parent,
		"InputBoxTemplate");
	urlbox:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -15);
	urlbox:SetText("https://www.wowhead.com/sounds")
	urlbox:SetAutoFocus(false)
	urlbox:SetJustifyV("TOP")
	urlbox:SetJustifyH("LEFT")
	urlbox:SetSize(400, 40)
	urlbox:SetScript("OnEditFocusLost",
		function(self)
			self:SetText("https://www.wowhead.com/sounds")
		end
	)

	return editbox
end

function ns:validateSoundInput(editbox)
	if editbox:GetNumber() == nil or editbox:GetNumber() == 0 then
		editbox:SetNumber(ns.SHEAddonConfig["DumpsterAlertSound"])
	else
		ns.SHEAddonConfig["DumpsterAlertSound"] = editbox:GetNumber()
	end
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
		function(_)
			ns.Toggle()
		end
	);

	-- Create option for drawing the line on the World Map
	local cb2 = createCheckbutton(panel, 10, -75, "Show on the World Map");
	cb2:SetScript("OnClick",
		function(self)
			ns.SHEAddonConfig["ShowOnWorldMap"] = self:GetChecked();
		end
	);

	-- Create option for drawing the line on the Battlefield Map
	local cb3 = createCheckbutton(panel, 10, -105, "Show on the Battlefield Map");
	cb3:SetScript("OnClick",
		function(self)
			ns.SHEAddonConfig["ShowOnBattlefieldMap"] = self:GetChecked();
		end
	);

	-- Allow configuration of the alert sound
	local eb1 = createSoundInputField(panel, 40, -165, "Test the sound");
	eb1:SetScript("OnEnterPressed",
		function(self)
			ns:validateSoundInput(self)
			eb1:ClearHighlightText()
		end
	)
	eb1:SetScript("OnEditFocusLost",
		function(self)
			ns:validateSoundInput(self)
			eb1:ClearHighlightText()
		end
	)

	-- Create option for alerting that an Overflowing Dumpster is near
	local cb4 = createCheckbutton(panel, 10, -135,
	"Alert when an Overflowing Dumpster is near|n(Works best with the Battlefield Map setting enabled, and open [Shift+M by default])");
	cb4:SetScript("OnClick",
		function(self)
			ns.SHEAddonConfig["DumpsterAlert"] = self:GetChecked();
		end
	);

	cb1:SetChecked(ns.SHEAddonConfig["Enabled"]);
	cb2:SetChecked(ns.SHEAddonConfig["ShowOnWorldMap"]);
	cb3:SetChecked(ns.SHEAddonConfig["ShowOnBattlefieldMap"]);
	cb4:SetChecked(ns.SHEAddonConfig["DumpsterAlert"]);
	eb1:SetNumber(ns.SHEAddonConfig["DumpsterAlertSound"]);
	panel:SetScript("OnShow", nil);
end)
panel.name = ADDON_NAME;
ns.category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
Settings.RegisterAddOnCategory(ns.category)
