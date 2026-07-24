-- Moisson — HUD de récolte plein écran pour WoW Classic Era.
-- Principe (hommage à FarmHud de Hizuro, réécrit de zéro) : on ne dessine pas
-- de carte, on déplace la vraie Minimap en plein écran, zoom mini, fond quasi
-- transparent. Les pins (GatherMate2, Questie) sont rebranchés sur un calque
-- frère « cluster » pour rester opaques pendant que le fond de carte s'efface.

local ADDON, ns = ...

local Minimap = _G.Minimap
local MT = getmetatable(Minimap).__index
local UpdateRotation = _G.Minimap_UpdateRotationSetting or function() end

local DEFAUTS = {
	taille    = 0.92,  -- fraction du plus petit côté de l'écran
	alpha     = 0.25,  -- transparence du fond de carte
	alpha2    = 0.70,  -- alpha alternatif (bouton « fond »)
	rotation  = true,  -- la carte tourne avec le joueur
	coords    = true,
	cardinaux = true,
	compteurs = true,
	boutons   = true,
	combat    = true,  -- masquer le HUD en combat
}

local db                    -- MoissonDB.opts
local saved                 -- instantané de la minimap à restaurer
local moved = {}            -- objets parqués sur le leurre
local coordsTicker, cardsTicker
local zoomLock = false
local hiddenByCombat = false

-- Frames anchorées à la minimap sans en être filles (ElvUI & Blizzard).
local EXTERNES = {
	"MinimapBackdrop", "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag",
	"MinimapCompassTexture", "MinimapZoneText", "MinimapToggleButton",
	"MinimapZoomIn", "MinimapZoomOut", "MiniMapTracking", "MiniMapTrackingFrame",
	"MiniMapWorldMapButton", "GameTimeFrame", "TimeManagerClockButton",
	"MiniMapMailFrame", "MiniMapBattlefieldFrame", "LFGMinimapFrame",
	"QueueStatusMinimapButton",
}

-- ------------------------------------------------------------------ frames --

local hud = CreateFrame("Frame", "MoissonHUD", UIParent)
hud:Hide()
hud:SetFrameStrata("BACKGROUND")
hud:SetFrameLevel(2)
hud:SetPoint("CENTER", WorldFrame, "CENTER")
hud:SetSize(200, 200)
hud.size = 200
ns.hud = hud

-- calque des pins : même géométrie que la minimap plein écran, mais frame
-- frère → l'alpha du fond ne l'affecte pas.
local cluster = CreateFrame("Frame", "MoissonCluster", hud)
cluster:SetPoint("CENTER")
cluster:Hide()
function cluster:GetZoom() return MT.GetZoom(Minimap) end
function cluster:SetZoom() end

-- leurre : occupe l'ancien emplacement de la minimap pour que les boutons
-- (ElvUI, MinimapButtonButton, LibDBIcon…) restent utilisables.
local leurre = CreateFrame("Button", "MoissonLeurre", UIParent)
leurre:Hide()
leurre:EnableMouse(false)

local texts = CreateFrame("Frame", nil, hud)
texts:SetAllPoints()

local coordsFS = texts:CreateFontString(nil, "ARTWORK", "GameFontNormal")
coordsFS:SetTextColor(1, 0.82, 0)
coordsFS:Hide()

local sourisFS = texts:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
sourisFS:SetText("— SOURIS ACTIVE —")
sourisFS:SetTextColor(1, 0.3, 0.3)
sourisFS:SetPoint("CENTER", hud, "CENTER", 0, -24)
sourisFS:Hide()

local CARDINAUX = { "N", "NE", "E", "SE", "S", "SO", "O", "NO" }
local cards = {}
for i = 1, 8 do
	local principal = (i % 2 == 1)
	local fs = texts:CreateFontString(nil, "ARTWORK",
		principal and "GameFontNormalLarge" or "GameFontNormal")
	fs:SetText(CARDINAUX[i])
	if principal then
		fs:SetTextColor(1, 0.82, 0)
	else
		fs:SetTextColor(0.8, 0.8, 0.8)
	end
	fs:Hide()
	cards[i] = fs
end

-- --------------------------------------------------------------- utilitaires --

local function print_(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf3fMoisson|r " .. tostring(msg))
end
ns.print = print_

local function SetScales()
	local e = UIParent:GetEffectiveScale()
	local w, h = WorldFrame:GetSize()
	local size = math.min(w / e, h / e) * db.taille
	hud:SetSize(size, size)
	hud.size = size
	cluster:SetSize(size, size)
	if Minimap:GetParent() == hud then
		MT.SetSize(Minimap, size, size)
	end
	coordsFS:ClearAllPoints()
	coordsFS:SetPoint("CENTER", hud, "CENTER", 0, -size * 0.17)
end

local function UpdateCards()
	local f = 0
	if db.rotation then f = GetPlayerFacing() or 0 end
	local r = hud.size * 0.5 * 0.46
	for i = 1, 8 do
		local a = f + (i - 1) * math.pi / 4
		cards[i]:ClearAllPoints()
		cards[i]:SetPoint("CENTER", hud, "CENTER", math.sin(a) * r, math.cos(a) * r)
	end
end

local function UpdateCoords()
	local mapID = C_Map.GetBestMapForUnit("player")
	if mapID then
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		if pos then
			local x, y = pos:GetXY()
			if x and x > 0 then
				coordsFS:SetFormattedText("%.1f · %.1f", x * 100, y * 100)
				return
			end
		end
	end
	coordsFS:SetText("")
end

-- ------------------------------------------------- parcage vers le leurre --

-- Les pins de farm ne doivent PAS être parqués : leurs libs les rebranchent
-- elles-mêmes sur le cluster via SetMinimapObject/ReparentMinimapPins.
local function isPin(obj, name)
	if LibStub then
		local hbd = LibStub.libs["HereBeDragons-Pins-2.0"]
		if hbd and hbd.minimapPins and hbd.minimapPins[obj] then return true end
		local hbdq = LibStub.libs["HereBeDragonsQuestie-Pins-2.0"]
		if hbdq and hbdq.minimapPins and hbdq.minimapPins[obj] then return true end
	end
	if name and name:match("GatherMatePin") then return true end
	return false
end

-- Ré-ancre les points d'un objet de `from` vers `to`. Retourne true si touché.
local function retargetPoints(obj, from, to)
	if not obj.GetNumPoints then return false end
	local n, all, touched = obj:GetNumPoints(), {}, false
	for p = 1, n do
		local point, relTo, relPoint, x, y = obj:GetPoint(p)
		if relTo == from then
			relTo = to
			touched = true
		end
		all[p] = { point, relTo, relPoint, x, y }
	end
	if touched then
		obj:ClearAllPoints()
		for _, a in ipairs(all) do
			obj:SetPoint(a[1], a[2], a[3], a[4], a[5])
		end
	end
	return touched
end

-- Déplace (on=true) ou restaure (on=false) un meuble de la minimap.
local function park(obj, on)
	local name = obj.GetName and obj:GetName()
	if obj == hud or obj == cluster or obj == leurre or isPin(obj, name) then
		return
	end
	local from, to = Minimap, leurre
	if not on then from, to = leurre, Minimap end

	local touched = false
	if obj:GetParent() == from then
		-- SetParent réinitialise strata/niveau : on les réapplique.
		local strata, level, layer, sublevel
		if obj.GetFrameLevel then
			strata, level = obj:GetFrameStrata(), obj:GetFrameLevel()
		elseif obj.GetDrawLayer then
			layer, sublevel = obj:GetDrawLayer()
		end
		obj:SetParent(to)
		if strata then
			obj:SetFrameStrata(strata)
			obj:SetFrameLevel(level)
		elseif layer then
			obj:SetDrawLayer(layer, sublevel)
		end
		touched = true
	end
	if retargetPoints(obj, from, to) then touched = true end

	if on and touched then
		moved[#moved + 1] = obj
	end
end

-- ------------------------------------------------------------ pins étrangers --

local function ForeignPins(state)
	local map = state and cluster or Minimap
	local GM2 = _G.GatherMate2
	if GM2 and GM2.GetModule then
		local display = GM2:GetModule("Display", true)
		if display and display.ReparentMinimapPins then
			display:ReparentMinimapPins(map)
		end
	end
	if LibStub then
		local hbd = LibStub.libs["HereBeDragons-Pins-2.0"]
		if hbd and hbd.SetMinimapObject then
			hbd:SetMinimapObject(state and map or nil)
		end
		local hbdq = LibStub.libs["HereBeDragonsQuestie-Pins-2.0"]
		if hbdq and hbdq.SetMinimapObject then
			hbdq:SetMinimapObject(state and map or nil)
		end
	end
end

-- ------------------------------------------------------------------- souris --

local function PingClick()
	local x, y = GetCursorPosition()
	local s = MT.GetEffectiveScale(Minimap)
	x, y = x / s, y / s
	local cx, cy = MT.GetCenter(Minimap)
	x, y = x - cx, y - cy
	if math.sqrt(x * x + y * y) < MT.GetWidth(Minimap) * 0.5 then
		Minimap:PingLocation(x, y)
	end
end

function Moisson_ToggleMouse(force)
	if Minimap:GetParent() ~= hud then return end
	local enable
	if force ~= nil then enable = force else enable = not Minimap:IsMouseEnabled() end
	MT.EnableMouse(Minimap, enable)
	sourisFS:SetShown(enable)
end

-- ------------------------------------------------------- ancrage plein écran --

-- SetPoint peut lever « anchor family connection » selon ce que d'autres
-- addons ont ancré ; on retente puis on retombe sur SetAllPoints.
local function AnchorMinimap()
	for try = 1, 3 do
		MT.ClearAllPoints(Minimap)
		local ok = pcall(function()
			if try < 3 then
				MT.SetPoint(Minimap, "CENTER", hud, "CENTER", 0, 0)
			else
				MT.SetAllPoints(Minimap, hud)
			end
		end)
		if ok then return true end
	end
end

-- --------------------------------------------------------------- Show / Hide --

hud:SetScript("OnShow", function(self)
	-- 1. instantané de la minimap
	saved = {
		parent = Minimap:GetParent(),
		scale  = Minimap:GetScale(),
		width  = Minimap:GetWidth(),
		height = Minimap:GetHeight(),
		strata = Minimap:GetFrameStrata(),
		level  = Minimap:GetFrameLevel(),
		alpha  = Minimap:GetAlpha(),
		zoom   = Minimap:GetZoom(),
		mouse  = Minimap:IsMouseEnabled(),
		wheel  = Minimap:IsMouseWheelEnabled(),
		onUp   = Minimap:GetScript("OnMouseUp"),
		onDown = Minimap:GetScript("OnMouseDown"),
		onWheel = Minimap:GetScript("OnMouseWheel"),
		rotate = C_CVar.GetCVar("rotateMinimap"),
		points = {},
	}
	for i = 1, Minimap:GetNumPoints() do
		saved.points[i] = { Minimap:GetPoint(i) }
	end

	-- 2. le leurre prend la place de la minimap
	leurre:SetParent(saved.parent)
	leurre:SetScale(saved.scale)
	leurre:SetSize(saved.width, saved.height)
	leurre:SetFrameStrata(saved.strata)
	leurre:SetFrameLevel(saved.level)
	leurre:ClearAllPoints()
	for _, p in ipairs(saved.points) do
		pcall(leurre.SetPoint, leurre, unpack(p))
	end
	leurre:Show()

	-- 3. parquer les meubles (boutons, textures, cadres ancrés)
	wipe(moved)
	local children = { Minimap:GetChildren() }
	for _, child in ipairs(children) do pcall(park, child, true) end
	local regions = { Minimap:GetRegions() }
	for _, region in ipairs(regions) do pcall(park, region, true) end
	for _, name in ipairs(EXTERNES) do
		local f = _G[name]
		if f then pcall(park, f, true) end
	end

	-- 4. la minimap passe en plein écran
	MT.Hide(Minimap)
	MT.SetParent(Minimap, hud)
	AnchorMinimap()
	MT.SetFrameStrata(Minimap, "BACKGROUND")
	MT.SetFrameLevel(Minimap, 1)
	MT.SetScale(Minimap, 1)
	SetScales()
	MT.SetZoom(Minimap, 0)
	MT.SetAlpha(Minimap, db.alpha)
	self.fondAlt = false
	MT.EnableMouse(Minimap, false)
	MT.EnableMouseWheel(Minimap, false)
	MT.SetScript(Minimap, "OnMouseUp", PingClick)
	MT.SetScript(Minimap, "OnMouseDown", nil)
	MT.SetScript(Minimap, "OnMouseWheel", nil)

	-- 5. rotation façon radar
	if (saved.rotate == "1") ~= db.rotation then
		C_CVar.SetCVar("rotateMinimap", db.rotation and "1" or "0")
		UpdateRotation()
	end
	MT.Show(Minimap)

	-- 6. pins de farm sur le calque opaque
	cluster:SetFrameStrata("BACKGROUND")
	cluster:SetFrameLevel(5)
	cluster:Show()
	ForeignPins(true)

	-- 7. habillage
	if db.coords then
		coordsFS:Show()
		UpdateCoords()
		coordsTicker = C_Timer.NewTicker(0.1, UpdateCoords)
	end
	if db.cardinaux then
		UpdateCards()
		for i = 1, 8 do cards[i]:Show() end
		if db.rotation then
			cardsTicker = C_Timer.NewTicker(0.05, UpdateCards)
		end
	end
	self.boutons:SetShown(db.boutons)
	if ns.CompteursOnShow then ns.CompteursOnShow() end
end)

hud:SetScript("OnHide", function(self)
	if not saved then return end

	if coordsTicker then coordsTicker:Cancel(); coordsTicker = nil end
	if cardsTicker then cardsTicker:Cancel(); cardsTicker = nil end
	coordsFS:Hide()
	for i = 1, 8 do cards[i]:Hide() end
	sourisFS:Hide()

	ForeignPins(false)
	cluster:Hide()

	-- restauration intégrale de la minimap
	MT.Hide(Minimap)
	MT.SetParent(Minimap, saved.parent)
	MT.ClearAllPoints(Minimap)
	for _, p in ipairs(saved.points) do
		pcall(MT.SetPoint, Minimap, unpack(p))
	end
	MT.SetScale(Minimap, saved.scale)
	MT.SetSize(Minimap, saved.width, saved.height)
	MT.SetFrameStrata(Minimap, saved.strata)
	MT.SetFrameLevel(Minimap, saved.level)
	MT.SetAlpha(Minimap, saved.alpha)
	MT.EnableMouse(Minimap, saved.mouse)
	MT.EnableMouseWheel(Minimap, saved.wheel)
	MT.SetScript(Minimap, "OnMouseUp", saved.onUp)
	MT.SetScript(Minimap, "OnMouseDown", saved.onDown)
	MT.SetScript(Minimap, "OnMouseWheel", saved.onWheel)
	local maxZoom = Minimap:GetZoomLevels()
	MT.SetZoom(Minimap, math.min(saved.zoom, maxZoom))

	if C_CVar.GetCVar("rotateMinimap") ~= saved.rotate then
		C_CVar.SetCVar("rotateMinimap", saved.rotate)
		UpdateRotation()
	end
	MT.Show(Minimap)

	-- les meubles reviennent du leurre
	for _, obj in ipairs(moved) do
		pcall(park, obj, false)
	end
	wipe(moved)
	leurre:Hide()

	if ns.CompteursOnHide then ns.CompteursOnHide() end
	saved = nil
end)

-- ------------------------------------------------------------------ boutons --

local boutons = CreateFrame("Frame", nil, hud)
boutons:SetSize(1, 1)
boutons:SetPoint("CENTER", hud, "CENTER", 0, -60)
boutons:Hide()
hud.boutons = boutons

local function NewBouton(offsetX, texture, tooltip, onClick)
	local b = CreateFrame("Button", nil, boutons)
	b:SetSize(20, 20)
	b:SetPoint("CENTER", offsetX, 0)
	b:SetNormalTexture(texture)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(tooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

NewBouton(-33, "Interface\\CURSOR\\Point", "Souris (inspecter les pins)", function()
	Moisson_ToggleMouse()
end)
NewBouton(-11, "Interface\\WorldMap\\WorldMap-Icon", "Fond de carte", function()
	hud.fondAlt = not hud.fondAlt
	MT.SetAlpha(Minimap, hud.fondAlt and db.alpha2 or db.alpha)
end)
NewBouton(11, "Interface\\Buttons\\UI-OptionsButton", "Aide (/moisson aide)", function()
	ns.Aide()
end)
NewBouton(33, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "Fermer", function()
	Moisson_Toggle(false)
end)

-- ------------------------------------------------------------------- toggle --

function Moisson_Toggle(force)
	if force == nil then force = not hud:IsShown() end
	if force and InCombatLockdown() and db.combat then
		print_("HUD indisponible en combat.")
		return
	end
	hud:SetShown(force)
end

BINDING_HEADER_MOISSON = "Moisson"
BINDING_NAME_MOISSON_TOGGLE = "Afficher / masquer le HUD"
BINDING_NAME_MOISSON_MOUSE = "Basculer la souris (HUD ouvert)"

-- ------------------------------------------------------------------ garde-fous --

-- Quoi qu'il arrive, zoom 0 tant que le HUD est ouvert (molette ElvUI, etc.)
hooksecurefunc(Minimap, "SetZoom", function(_, level)
	if hud:IsShown() and not zoomLock and level ~= 0 then
		zoomLock = true
		MT.SetZoom(Minimap, 0)
		zoomLock = false
	end
end)

-- ------------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		MoissonDB = MoissonDB or {}
		MoissonDB.opts = MoissonDB.opts or {}
		for k, v in pairs(DEFAUTS) do
			if MoissonDB.opts[k] == nil then MoissonDB.opts[k] = v end
		end
		db = MoissonDB.opts
		ns.db = db
		if ns.InitCompteurs then ns.InitCompteurs() end
	elseif event == "PLAYER_LOGOUT" then
		-- ne pas laisser fuiter la CVar de rotation si on déco HUD ouvert
		if saved and C_CVar.GetCVar("rotateMinimap") ~= saved.rotate then
			C_CVar.SetCVar("rotateMinimap", saved.rotate)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if db and db.combat and hud:IsShown() then
			hiddenByCombat = true
			hud:Hide()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if hiddenByCombat then
			hiddenByCombat = false
			hud:Show()
		end
	end
end)

-- -------------------------------------------------------------------- slash --

function ns.Aide()
	print_("commandes :")
	print_("  /moisson — afficher/masquer le HUD")
	print_("  /moisson souris — activer la souris (tooltips des pins)")
	print_("  /moisson rotation — carte fixe ou rotative")
	print_("  /moisson taille 0.5–1 · alpha 0–1 — géométrie")
	print_("  /moisson compteurs — panneau de récolte on/off")
	print_("  /moisson bilan — totaux en chat")
	print_("  /moisson raz — remise à zéro session (« raz tout » : global)")
end

SLASH_MOISSON1 = "/moisson"
SlashCmdList["MOISSON"] = function(input)
	input = (input or ""):lower():gsub("^%s+", "")
	local cmd, arg = input:match("^(%S*)%s*(.*)$")
	if cmd == "" then
		Moisson_Toggle()
	elseif cmd == "souris" then
		Moisson_ToggleMouse()
	elseif cmd == "rotation" then
		db.rotation = not db.rotation
		print_("rotation " .. (db.rotation and "activée" or "désactivée") .. ".")
		if hud:IsShown() then Moisson_Toggle(false); Moisson_Toggle(true) end
	elseif cmd == "taille" then
		local v = tonumber(arg)
		if v and v >= 0.3 and v <= 1 then
			db.taille = v
			if hud:IsShown() then SetScales(); UpdateCards() end
			print_("taille : " .. v)
		else
			print_("taille attendue entre 0.3 et 1.")
		end
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if v and v >= 0 and v <= 1 then
			db.alpha = v
			if hud:IsShown() then MT.SetAlpha(Minimap, v) end
			print_("alpha : " .. v)
		else
			print_("alpha attendu entre 0 et 1.")
		end
	elseif cmd == "compteurs" then
		db.compteurs = not db.compteurs
		print_("compteurs " .. (db.compteurs and "affichés" or "masqués") .. ".")
		if ns.CompteursOnShow and hud:IsShown() then ns.CompteursOnShow() end
	elseif cmd == "bilan" then
		if ns.Bilan then ns.Bilan() end
	elseif cmd == "raz" then
		if ns.Raz then ns.Raz(arg == "tout") end
	else
		ns.Aide()
	end
end
