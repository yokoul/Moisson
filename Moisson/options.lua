-- Moisson — panneau d'options dans l'interface (Options → AddOns → Moisson).
-- Les réglages se sont accumulés : en une seule colonne, la page devenait un
-- ruban qu'il fallait faire défiler pour tout voir. Elle est donc découpée en
-- sections, réparties sur deux colonnes, et posée à des coordonnées calculées
-- plutôt qu'en chaîne d'ancres — chaque section sait ainsi où la précédente
-- s'est arrêtée, dans sa colonne. Le ScrollFrame reste, comme filet, pour les
-- petites résolutions.

local ADDON, ns = ...
local L = ns.L

-- Libellés courts : en colonne, une phrase entière déborderait. L'explication
-- complète part dans le tooltip de la coche, pour ne rien perdre.
local GROUPES = {
	{
		titre = L.OPT_GRP_HUD, colonne = 1,
		coches = {
			{ cle = "rotation",  txt = L.OPT_ROTATION,  aide = L.OPT_ROTATION_AIDE },
			{ cle = "cardinaux", txt = L.OPT_CARDINAUX },
			{ cle = "coords",    txt = L.OPT_COORDS },
			{ cle = "sourisalt", txt = L.OPT_SOURISALT, aide = L.OPT_SOURISALT_AIDE },
			{ cle = "combat",    txt = L.OPT_COMBAT },
		},
	},
	{
		titre = L.OPT_GRP_PANNEAU, colonne = 1,
		coches = {
			{ cle = "compteurs", txt = L.OPT_COMPTEURS },
			{ cle = "replie",    txt = L.OPT_REPLIE,    aide = L.OPT_REPLIE_AIDE },
			-- le côté vit en clair dans la base (gauche | droite) : la coche ne
			-- voit que « à droite »
			{ cle = "cote",      txt = L.OPT_COTE,
				lit = function() return ns.db.cote == "droite" end },
			{ cle = "stockcompte", txt = L.OPT_STOCKCOMPTE, aide = L.OPT_STOCKCOMPTE_AIDE },
			-- idem pour la portée (royaume | tout)
			{ cle = "portee",    txt = L.OPT_PORTEE, aide = L.OPT_PORTEE_AIDE,
				lit = function() return ns.db.portee == "tout" end },
		},
	},
	{
		titre = L.OPT_GRP_APPARENCE, colonne = 2,
		curseurs = {
			{ cle = "taille",     txt = L.OPT_TAILLE,     min = 0.5, max = 1.2, pas = 0.05 },
			{ cle = "echelle",    txt = L.OPT_ECHELLE,    min = 1,   max = 2,   pas = 0.1 },
			{ cle = "alpha",      txt = L.OPT_ALPHA,      min = 0,   max = 1,   pas = 0.05 },
			{ cle = "alpha2",     txt = L.OPT_ALPHA2,     min = 0,   max = 1,   pas = 0.05 },
			{ cle = "radarfond",  txt = L.OPT_RADARFOND,  min = 0,   max = 1,   pas = 0.05 },
			{ cle = "radarvoile", txt = L.OPT_RADARVOILE, min = 0,   max = 1,   pas = 0.05 },
			{ cle = "cardalpha",  txt = L.OPT_CARDALPHA,  min = 0,   max = 1,   pas = 0.05 },
		},
	},
}

local RACCOURCIS = {
	{ cmd = "MOISSON_TOGGLE",  txt = L.OPT_BIND_HUD },
	{ cmd = "MOISSON_MOUSE",   txt = L.OPT_BIND_SOURIS },
	{ cmd = "MOISSON_FOND",    txt = L.OPT_BIND_FOND },
	{ cmd = "MOISSON_REPLIER", txt = L.OPT_BIND_REPLIER },
}

local LARGEUR = 560
local COLONNE = { [1] = 14, [2] = 292 }  -- x de chaque colonne
local L_COLONNE = 254                     -- largeur utile d'une colonne
local H_COCHE, H_CURSEUR, H_TITRE = 24, 44, 26

function ns.InitOptions()
	local panel = CreateFrame("Frame")
	panel.name = "Moisson"

	local scroll = CreateFrame("ScrollFrame", "MoissonOptionsScroll", panel,
		"UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local content = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(content)

	-- ---- bandeau : le logo tenait un tiers de la page à lui seul ----

	local logo = content:CreateTexture(nil, "ARTWORK")
	logo:SetSize(96, 97) -- ratio du fichier 341×344
	logo:SetPoint("TOPLEFT", COLONNE[1], -6)
	logo:SetTexture("Interface\\AddOns\\Moisson\\img\\logo-primary.png")

	local sousTitre = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sousTitre:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -22)
	sousTitre:SetWidth(LARGEUR - 96 - 40)
	sousTitre:SetJustifyH("LEFT")
	sousTitre:SetText(L.OPT_SOUSTITRE)

	-- ---- sections, colonne par colonne ----

	local y = { [1] = 112, [2] = 112 } -- sous le bandeau

	local function Section(colonne, titre)
		local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fs:SetPoint("TOPLEFT", COLONNE[colonne], -y[colonne])
		fs:SetTextColor(1, 0.82, 0)
		fs:SetText(titre)
		local filet = content:CreateTexture(nil, "ARTWORK")
		filet:SetPoint("TOPLEFT", COLONNE[colonne], -y[colonne] - 16)
		filet:SetSize(L_COLONNE, 1)
		filet:SetColorTexture(1, 0.82, 0, 0.25)
		y[colonne] = y[colonne] + H_TITRE
	end

	local function Aide(frame, titre, texte)
		if not texte then return end
		frame:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(titre, 1, 0.82, 0)
			GameTooltip:AddLine(texte, 1, 1, 1, true) -- true : le texte s'enroule
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	local function Coche(colonne, def)
		local cb = CreateFrame("CheckButton", "MoissonOpt_" .. def.cle, content,
			"UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", COLONNE[colonne], -y[colonne])
		cb:SetSize(22, 22)
		local texte = _G[cb:GetName() .. "Text"]
		texte:SetText(def.txt)
		texte:SetWidth(L_COLONNE - 30)
		texte:SetJustifyH("LEFT")
		texte:SetWordWrap(false) -- une ligne, coupée au besoin : le tooltip complète
		if def.lit then
			cb:SetChecked(def.lit())
		else
			cb:SetChecked(ns.db[def.cle])
		end
		cb:SetScript("OnClick", function(self)
			ns.Apply[def.cle](self:GetChecked() and true or false)
		end)
		Aide(cb, def.txt, def.aide)
		y[colonne] = y[colonne] + H_COCHE
	end

	local function Curseur(colonne, def)
		local s = CreateFrame("Slider", "MoissonCurseur_" .. def.cle, content,
			"OptionsSliderTemplate")
		s:SetPoint("TOPLEFT", COLONNE[colonne] + 6, -y[colonne] - 12)
		s:SetWidth(L_COLONNE - 20)
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
		y[colonne] = y[colonne] + H_CURSEUR
	end

	for _, groupe in ipairs(GROUPES) do
		local c = groupe.colonne
		Section(c, groupe.titre)
		for _, def in ipairs(groupe.coches or {}) do Coche(c, def) end
		for _, def in ipairs(groupe.curseurs or {}) do Curseur(c, def) end
		y[c] = y[c] + 14 -- respiration entre deux sections
	end

	-- ---- pleine largeur, sous la plus haute des deux colonnes ----

	local bas = math.max(y[1], y[2])

	local sepTitre = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sepTitre:SetPoint("TOPLEFT", COLONNE[1], -bas)
	sepTitre:SetTextColor(1, 0.82, 0)
	sepTitre:SetText(L.OPT_GRP_RACCOURCIS)
	local filet = content:CreateTexture(nil, "ARTWORK")
	filet:SetPoint("TOPLEFT", COLONNE[1], -bas - 16)
	filet:SetSize(LARGEUR - 28, 1)
	filet:SetColorTexture(1, 0.82, 0, 0.25)
	bas = bas + H_TITRE

	-- ---- raccourcis clavier, définissables directement ici ----

	local bindActif -- un seul bouton écoute le clavier à la fois

	local function BindButton(def, x, yy)
		local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		b:SetSize(266, 22)
		b:SetPoint("TOPLEFT", x, -yy)
		local function refresh()
			local key = GetBindingKey(def.cmd)
			b:SetText(def.txt .. " : " .. (key and GetBindingText(key) or L.OPT_NON_DEFINI))
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
			self:SetText(def.txt .. " : |cffffd200" .. L.OPT_APPUIE .. "|r")
			self:EnableKeyboard(true)
			self:SetScript("OnKeyDown", function(self, key)
				if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
				or key == "LALT" or key == "RALT" or key == "UNKNOWN" then
					return
				end
				if key == "ESCAPE" then
					local old = GetBindingKey(def.cmd)
					if old then SetBinding(old) end
				else
					local combo = (IsAltKeyDown() and "ALT-" or "")
						.. (IsControlKeyDown() and "CTRL-" or "")
						.. (IsShiftKeyDown() and "SHIFT-" or "")
						.. key
					SetBinding(combo, def.cmd)
				end
				SaveBindings(GetCurrentBindingSet())
				stop()
			end)
		end)
		panel:HookScript("OnShow", refresh)
		panel:HookScript("OnHide", stop)
		refresh()
	end

	-- deux par rangée
	for i, def in ipairs(RACCOURCIS) do
		local col = (i % 2 == 1) and 1 or 2
		BindButton(def, COLONNE[col], bas + math.floor((i - 1) / 2) * 26)
	end
	bas = bas + math.ceil(#RACCOURCIS / 2) * 26 + 16

	-- ---- actions ----

	local function Bouton(x, yy, largeur, texte, action)
		local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
		b:SetSize(largeur, 22)
		b:SetPoint("TOPLEFT", x, -yy)
		b:SetText(texte)
		b:SetScript("OnClick", action)
		return b
	end

	Bouton(COLONNE[1], bas, 172, L.OPT_STOCKS, function()
		if ns.OuvrirStocks then ns.OuvrirStocks(true) end
	end)
	Bouton(COLONNE[1] + 180, bas, 172, L.OPT_RAZ_SESSION, function()
		if ns.Raz then ns.Raz(false) end
	end)
	Bouton(COLONNE[1] + 360, bas, 172, L.OPT_RAZ_TOUT, function()
		if ns.Raz then ns.Raz(true) end
	end)
	bas = bas + 34

	local credits = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	credits:SetPoint("TOPLEFT", COLONNE[1], -bas)
	credits:SetWidth(LARGEUR - 28)
	credits:SetJustifyH("LEFT")
	credits:SetText(L.OPT_CREDITS)
	bas = bas + 30

	-- le canevas fait exactement la hauteur du contenu : l'ascenseur n'apparaît
	-- que s'il sert vraiment
	content:SetSize(LARGEUR, bas)

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
