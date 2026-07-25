-- Moisson — panneau d'options dans l'interface (Options → AddOns → Moisson).
-- Le contenu dépasse la hauteur du canevas Blizzard : tout vit dans un
-- ScrollFrame, seule la molette/l'ascenseur bouge.

local ADDON, ns = ...
local L = ns.L

local COCHES = {
	{ cle = "rotation",  txt = L.OPT_ROTATION },
	{ cle = "cardinaux", txt = L.OPT_CARDINAUX },
	{ cle = "coords",    txt = L.OPT_COORDS },
	{ cle = "compteurs", txt = L.OPT_COMPTEURS },
	{ cle = "boutons",   txt = L.OPT_BOUTONS },
	{ cle = "sourisalt", txt = L.OPT_SOURISALT },
	{ cle = "combat",    txt = L.OPT_COMBAT },
}

local CURSEURS = {
	{ cle = "taille",     txt = L.OPT_TAILLE,     min = 0.5, max = 1.2, pas = 0.05 },
	{ cle = "echelle",    txt = L.OPT_ECHELLE,    min = 1,   max = 2,   pas = 0.1 },
	{ cle = "alpha",      txt = L.OPT_ALPHA,      min = 0,   max = 1,   pas = 0.05 },
	{ cle = "alpha2",     txt = L.OPT_ALPHA2,     min = 0,   max = 1,   pas = 0.05 },
	{ cle = "radarfond",  txt = L.OPT_RADARFOND,  min = 0,   max = 1,   pas = 0.05 },
	{ cle = "radarvoile", txt = L.OPT_RADARVOILE, min = 0,   max = 1,   pas = 0.05 },
	{ cle = "cardalpha",  txt = L.OPT_CARDALPHA,  min = 0,   max = 1,   pas = 0.05 },
}

function ns.InitOptions()
	local panel = CreateFrame("Frame")
	panel.name = "Moisson"

	local scroll = CreateFrame("ScrollFrame", "MoissonOptionsScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(560, 1010)
	scroll:SetScrollChild(content)

	-- la bannière porte déjà le nom de l'addon
	local logo = content:CreateTexture(nil, "ARTWORK")
	logo:SetSize(280, 191) -- ratio du fichier 768×524
	logo:SetPoint("TOPLEFT", 16, -8)
	logo:SetTexture("Interface\\AddOns\\Moisson\\img\\logo-primary.png")

	local sousTitre = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sousTitre:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -2)
	sousTitre:SetText(L.OPT_SOUSTITRE)

	local prev = sousTitre
	for _, def in ipairs(COCHES) do
		local cb = CreateFrame("CheckButton", "MoissonOpt_" .. def.cle, content, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
		cb:SetSize(24, 24)
		_G[cb:GetName() .. "Text"]:SetText(def.txt)
		cb:SetChecked(ns.db[def.cle])
		cb:SetScript("OnClick", function(self)
			ns.Apply[def.cle](self:GetChecked() and true or false)
		end)
		prev = cb
	end

	local prevSlider
	for i, def in ipairs(CURSEURS) do
		local s = CreateFrame("Slider", "MoissonCurseur_" .. def.cle, content, "OptionsSliderTemplate")
		if i == 1 then
			s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 8, -32)
		else
			s:SetPoint("TOPLEFT", prevSlider, "BOTTOMLEFT", 0, -36)
		end
		s:SetWidth(240)
		s:SetMinMaxValues(def.min, def.max)
		s:SetValueStep(def.pas)
		s:SetObeyStepOnDrag(true)
		s:SetValue(ns.db[def.cle])
		_G[s:GetName() .. "Low"]:SetText(def.min)
		_G[s:GetName() .. "High"]:SetText(def.max)
		_G[s:GetName() .. "Text"]:SetText(def.txt .. " : " .. ns.db[def.cle])
		s:SetScript("OnValueChanged", function(self, v)
			v = math.floor(v / def.pas + 0.5) * def.pas
			v = tonumber(string.format("%.2f", v))
			ns.Apply[def.cle](v)
			_G[self:GetName() .. "Text"]:SetText(def.txt .. " : " .. v)
		end)
		prevSlider = s
	end

	-- ---- raccourcis clavier, définissables directement ici ----

	local function BindButton(command, label, anchorTo, offsetY)
		local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		b:SetSize(300, 22)
		b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
		local function refresh()
			local key = GetBindingKey(command)
			b:SetText(label .. " : " .. (key and GetBindingText(key) or L.OPT_NON_DEFINI))
		end
		b:SetScript("OnClick", function(self)
			if self.ecoute then return end
			self.ecoute = true
			self:SetText(label .. " : |cffffd200" .. L.OPT_APPUIE .. "|r")
			self:EnableKeyboard(true)
			self:SetScript("OnKeyDown", function(self, key)
				if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
				or key == "LALT" or key == "RALT" or key == "UNKNOWN" then
					return
				end
				if key == "ESCAPE" then
					local old = GetBindingKey(command)
					if old then SetBinding(old) end
				else
					local combo = (IsAltKeyDown() and "ALT-" or "")
						.. (IsControlKeyDown() and "CTRL-" or "")
						.. (IsShiftKeyDown() and "SHIFT-" or "")
						.. key
					SetBinding(combo, command)
				end
				SaveBindings(GetCurrentBindingSet())
				self.ecoute = false
				self:EnableKeyboard(false)
				self:SetScript("OnKeyDown", nil)
				refresh()
			end)
		end)
		panel:HookScript("OnShow", refresh)
		refresh()
		return b
	end

	local bindHud = BindButton("MOISSON_TOGGLE", L.OPT_BIND_HUD, prevSlider, -32)
	local bindSouris = BindButton("MOISSON_MOUSE", L.OPT_BIND_SOURIS, bindHud, -6)
	local bindFond = BindButton("MOISSON_FOND", L.OPT_BIND_FOND, bindSouris, -6)

	local razSession = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	razSession:SetSize(160, 22)
	razSession:SetPoint("TOPLEFT", bindFond, "BOTTOMLEFT", 0, -24)
	razSession:SetText(L.OPT_RAZ_SESSION)
	razSession:SetScript("OnClick", function() if ns.Raz then ns.Raz(false) end end)

	local razTout = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	razTout:SetSize(160, 22)
	razTout:SetPoint("LEFT", razSession, "RIGHT", 8, 0)
	razTout:SetText(L.OPT_RAZ_TOUT)
	razTout:SetScript("OnClick", function() if ns.Raz then ns.Raz(true) end end)

	local credits = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	credits:SetPoint("TOPLEFT", razSession, "BOTTOMLEFT", 0, -24)
	credits:SetText(L.OPT_CREDITS)

	-- nouvelle API Settings (1.15) avec repli sur l'ancienne
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(panel, "Moisson")
		Settings.RegisterAddOnCategory(cat)
		-- OpenToCategory exige l'ID numérique attribué par le jeu
		ns.OpenOptions = function() Settings.OpenToCategory(cat:GetID()) end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
		ns.OpenOptions = function() InterfaceOptionsFrame_OpenToCategory(panel) end
	end
end
