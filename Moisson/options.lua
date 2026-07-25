-- Moisson — panneau d'options dans l'interface (Options → AddOns → Moisson).

local ADDON, ns = ...

local COCHES = {
	{ cle = "rotation",  txt = "Rotation façon radar (la carte tourne avec le joueur)" },
	{ cle = "cardinaux", txt = "Points cardinaux (N/NE/E/…)" },
	{ cle = "coords",    txt = "Coordonnées du joueur" },
	{ cle = "compteurs", txt = "Panneau des compteurs de récolte" },
	{ cle = "boutons",   txt = "Boutons à l'écran (souris, fond, options, fermer)" },
	{ cle = "combat",    txt = "Masquer le HUD en combat" },
}

local CURSEURS = {
	{ cle = "taille",    txt = "Taille du HUD",            min = 0.5, max = 1.2, pas = 0.05 },
	{ cle = "echelle",   txt = "Grossissement des pins",   min = 1,   max = 2,   pas = 0.1 },
	{ cle = "alpha",     txt = "Fond de carte",            min = 0,   max = 1,   pas = 0.05 },
	{ cle = "alpha2",    txt = "Fond alternatif",          min = 0,   max = 1,   pas = 0.05 },
	{ cle = "cardalpha", txt = "Opacité des cardinaux",    min = 0,   max = 1,   pas = 0.05 },
}

function ns.InitOptions()
	local panel = CreateFrame("Frame")
	panel.name = "Moisson"

	local titre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titre:SetPoint("TOPLEFT", 16, -16)
	titre:SetText("|cff7fbf3fMoisson|r — HUD de récolte")

	local sousTitre = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sousTitre:SetPoint("TOPLEFT", titre, "BOTTOMLEFT", 0, -4)
	sousTitre:SetText("Raccourcis définissables ci-dessous.  En jeu : /moisson aide")

	local prev = sousTitre
	for _, def in ipairs(COCHES) do
		local cb = CreateFrame("CheckButton", "MoissonOpt_" .. def.cle, panel, "UICheckButtonTemplate")
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
		local s = CreateFrame("Slider", "MoissonCurseur_" .. def.cle, panel, "OptionsSliderTemplate")
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
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(300, 22)
		b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
		local function refresh()
			local key = GetBindingKey(command)
			b:SetText(label .. " : " .. (key and GetBindingText(key) or "|cff808080non défini|r"))
		end
		b:SetScript("OnClick", function(self)
			if self.ecoute then return end
			self.ecoute = true
			self:SetText(label .. " : |cffffd200appuie sur une touche…|r (Échap : effacer)")
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

	local bindHud = BindButton("MOISSON_TOGGLE", "Ouvrir / fermer le HUD", prevSlider, -32)
	local bindSouris = BindButton("MOISSON_MOUSE", "Basculer la souris", bindHud, -6)
	local bindFond = BindButton("MOISSON_FOND", "Basculer le fond de carte", bindSouris, -6)

	local razSession = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	razSession:SetSize(160, 22)
	razSession:SetPoint("TOPLEFT", bindFond, "BOTTOMLEFT", 0, -24)
	razSession:SetText("RàZ compteurs session")
	razSession:SetScript("OnClick", function() if ns.Raz then ns.Raz(false) end end)

	local razTout = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	razTout:SetSize(160, 22)
	razTout:SetPoint("LEFT", razSession, "RIGHT", 8, 0)
	razTout:SetText("RàZ tout (global)")
	razTout:SetScript("OnClick", function() if ns.Raz then ns.Raz(true) end end)

	local credits = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	credits:SetPoint("BOTTOMLEFT", 16, 16)
	credits:SetText("Mécanisme inspiré de FarmHud (Hizuro) — réécriture yokoul.")

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
