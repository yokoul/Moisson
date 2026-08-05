-- Moisson — bouton minimap (déplaçable sur le pourtour, clic gauche = HUD,
-- clic droit = options, shift-clic = fond, clic milieu = souris, tooltip =
-- résumé de la session). HUD ouvert, le bouton reste en place : il est parqué
-- sur le leurre avec le reste des meubles de la minimap.

local ADDON, ns = ...

local mmb

-- HUD ouvert, le bouton est parqué sur le leurre — qui rejoue exactement la
-- géométrie de la minimap d'origine. C'est donc lui l'ancre, jamais la Minimap
-- partie en plein écran : s'y raccrocher enverrait le bouton au bord de l'écran
-- avec un rayon de plusieurs centaines de pixels.
local function Ancre()
	return mmb:GetParent() or Minimap
end

local function UpdatePosition()
	local ancre = Ancre()
	local a = math.rad(ns.db.bouton_angle or 200)
	local r = (ancre:GetWidth() / 2) + 5
	mmb:ClearAllPoints()
	mmb:SetPoint("CENTER", ancre, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function OnDragUpdate()
	local ancre = Ancre()
	local mx, my = ancre:GetCenter()
	if not mx then return end
	local cx, cy = GetCursorPosition()
	local s = ancre:GetEffectiveScale()
	ns.db.bouton_angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
	UpdatePosition()
end

function ns.InitBoutonMinimap()
	if mmb then return end
	mmb = CreateFrame("Button", "MoissonBoutonMinimap", Minimap)
	mmb:SetSize(31, 31)
	mmb:SetFrameStrata("MEDIUM")
	mmb:SetFrameLevel(8)
	mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	mmb:RegisterForDrag("LeftButton")
	mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- anatomie LibDBIcon (icône de contenu + anneau de tracking Blizzard) :
	-- c'est LE pattern que les skins de boutons minimap (ElvUI, MBB, Square
	-- Minimap Buttons…) savent démonter — ils strippent l'anneau et recadrent
	-- l'icône. Un médaillon tout-en-un ressortait sombre et minuscule une
	-- fois passé à leur moulinette.
	local border = mmb:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	local icon = mmb:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture("Interface\\AddOns\\Moisson\\img\\logo-minimap.png")

	mmb:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if ns.OpenOptions then ns.OpenOptions() end
		elseif button == "MiddleButton" then
			Moisson_ToggleMouse()
		elseif IsShiftKeyDown() then
			Moisson_ToggleFond()
		else
			Moisson_Toggle()
		end
	end)
	mmb:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	mmb:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	mmb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("|cff7fbf3fMoisson|r")
		local resume = ns.SessionResume and ns.SessionResume()
		if resume then
			GameTooltip:AddLine(ns.L.MMB_SESSION .. resume, 1, 1, 1)
		end
		GameTooltip:AddLine(ns.L.MMB_TIP, 0.7, 0.7, 0.7)
		GameTooltip:AddLine(ns.L.MMB_TIP2, 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)

	UpdatePosition()
end
