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
	{ cle = "stockcompte", txt = L.OPT_STOCKCOMPTE },
	-- la portée vit en clair dans la base (royaume | tout) : la coche ne voit
	-- que « tous les royaumes »
	{ cle = "portee",    txt = L.OPT_PORTEE,
		lit = function() return ns.db.portee == "tout" end },
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
	content:SetSize(560, 980)
	scroll:SetScrollChild(content)

	-- la bannière porte déjà le nom de l'addon
	local logo = content:CreateTexture(nil, "ARTWORK")
	logo:SetSize(210, 212) -- ratio du fichier 341×344
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
		if def.lit then
			cb:SetChecked(def.lit())
		else
			cb:SetChecked(ns.db[def.cle])
		end
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

	local bindActif -- un seul bouton écoute le clavier à la fois

	local function BindButton(command, label, anchorTo, offsetY)
		local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		b:SetSize(300, 22)
		b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
		local function refresh()
			local key = GetBindingKey(command)
			b:SetText(label .. " : " .. (key and GetBindingText(key) or L.OPT_NON_DEFINI))
		end
		-- rendre le clavier : le panneau peut se fermer avant qu'une touche
		-- arrive, il ne faut pas rouvrir sur un bouton resté « en écoute »
		local function stop()
			if not b.ecoute then return end
			b.ecoute = false
			b:EnableKeyboard(false)
			b:SetScript("OnKeyDown", nil)
			if bindActif == stop then bindActif = nil end
			refresh()
		end
		b:SetScript("OnClick", function(self)
			if self.ecoute then return end
			-- SetBinding est protégé en combat : inutile d'écouter pour rien
			if InCombatLockdown() then
				ns.print(L.OPT_BIND_COMBAT)
				return
			end
			if bindActif then bindActif() end
			bindActif = stop
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
				stop()
			end)
		end)
		panel:HookScript("OnShow", refresh)
		panel:HookScript("OnHide", stop)
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

	local stocks = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	stocks:SetSize(328, 22)
	stocks:SetPoint("TOPLEFT", razSession, "BOTTOMLEFT", 0, -8)
	stocks:SetText(L.OPT_STOCKS)
	stocks:SetScript("OnClick", function()
		if ns.OuvrirStocks then ns.OuvrirStocks(true) end
	end)

	local credits = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	credits:SetPoint("TOPLEFT", stocks, "BOTTOMLEFT", 0, -24)
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
