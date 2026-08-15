-- Moisson — familles de matériaux de Classic Era, par itemID, et catégories
-- de récolte partagées (compteurs, stocks, fenêtre de bilan).
-- Les listes sont nécessaires : la DB2 du client Era classe presque tout en
-- « Trade Goods » générique (classe 7, sous-classe 0) — la sous-classe est
-- inutilisable pour catégoriser. Le contenu Era étant figé, on les embarque.
-- IDs vérifiés contre items.db (dump wago.tools + API Blizzard, name_fr).

local ADDON, ns = ...

local FAM = {}
local function ajoute(cat, ids)
	for _, id in ipairs(ids) do FAM[id] = cat end
end

ajoute("herbes", {
	765,   -- Feuillargent
	785,   -- Mage royal
	2447,  -- Pacifique
	2449,  -- Terrestrine
	2450,  -- Eglantine
	2452,  -- Chardonnier
	2453,  -- Doulourante
	3355,  -- Aciérite sauvage
	3356,  -- Sang-royal
	3357,  -- Vietérule
	3358,  -- Moustache de Khadgar
	3369,  -- Tombeline
	3818,  -- Pâlerette
	3819,  -- Hivernale
	3820,  -- Etouffante
	3821,  -- Dorépine
	4625,  -- Fleur de feu
	8153,  -- Sauvageonne
	8831,  -- Lotus pourpre
	8836,  -- Larmes d'Arthas
	8838,  -- Soleillette
	8839,  -- Aveuglette
	8845,  -- Champignon fantôme
	8846,  -- Gromsang
	13463, -- Feuillerêve
	13464, -- Sansam doré
	13465, -- Sauge-argent des montagnes
	13466, -- Fleur de peste
	13467, -- Calot de glace
	13468, -- Lotus noir
	19726, -- Vignesang
})

ajoute("minerais", {
	2770,  -- Minerai de cuivre
	2771,  -- Minerai d'étain
	2772,  -- Minerai de fer
	2775,  -- Minerai d'argent
	2776,  -- Minerai d'or
	3858,  -- Minerai de mithril
	7911,  -- Minerai de vrai-argent
	10620, -- Minerai de thorium
	11370, -- Minerai de sombrefer
	2835,  -- Pierre brute
	2836,  -- Pierre grossière
	2838,  -- Pierre lourde
	7912,  -- Pierre solide
	12365, -- Pierre dense
	11382, -- Sang de la montagne
})

ajoute("gemmes", {
	774,   -- Malachite
	818,   -- Oeil de tigre
	1206,  -- Agate mousse
	1210,  -- Oeil ténébreux
	1529,  -- Jade
	1705,  -- Pierre de lune inférieure
	3864,  -- Citrine
	5498,  -- Petite perle satinée
	5500,  -- Perle iridescente
	7909,  -- Aigue-marine
	7910,  -- Rubis étoilé
	7971,  -- Perle noire
	12361, -- Saphir bleu
	12363, -- Cristal des arcanes
	12364, -- Énorme émeraude
	12799, -- Grande opale
	12800, -- Diamant d'Azeroth
	13926, -- Perle dorée
})

ajoute("cuirs", {
	2934,  -- Lanières de cuir déchirées
	2318,  -- Cuir léger
	2319,  -- Cuir moyen
	4234,  -- Cuir lourd
	4304,  -- Cuir épais
	8170,  -- Cuir robuste
	783,   -- Peau légère
	4232,  -- Peau moyenne
	4235,  -- Peau lourde
	8169,  -- Peau épaisse
	8171,  -- Peau robuste
	15417, -- Cuir de diablosaure
	17012, -- Cuir du Magma
	15412, -- Ecaille de dragon vert
	15414, -- Ecaille de dragon rouge
	15415, -- Ecaille de dragon bleu
	15416, -- Ecaille de dragon noir
	7286,  -- Ecaille de dragonnet noir
	7287,  -- Ecaille de dragonnet rouge
	5784,  -- Ecailles de murloc visqueuses
	5785,  -- Ecailles de murloc épaisses
	8154,  -- Ecaille de scorpide
	15408, -- Ecaille de scorpide épaisse
	8167,  -- Ecaille de tortue
})

ajoute("tissus", {
	2589,  -- Etoffe de lin
	2592,  -- Etoffe de laine
	4306,  -- Etoffe de soie
	4338,  -- Etoffe de tisse-mage
	14047, -- Etoffe runique
	14256, -- Gangrétoffe
})

ajoute("viandes", {
	769,   -- Morceau de viande de sanglier
	1015,  -- Steak de loup
	2672,  -- Viande de loup maigre
	2674,  -- Chair de clampant
	2924,  -- Viande de crocilisque
	3173,  -- Viande d'ours
	3667,  -- Viande de crocilisque tendre
	3712,  -- Viande de tortue
	3730,  -- Viande de grand ours
	3731,  -- Viande de lion
	5465,  -- Petite patte d'araignée
	5467,  -- Viande de kodo
	5471,  -- Viande de cerf
	12037, -- Viande mystère
	4555,  -- Epaisse queue écailleuse
	7974,  -- Chair de palourde piquante
	4655,  -- Chair de palourde géante
	4603,  -- Jaune-queue tacheté cru
	6289,  -- Lutjan à longue mâchoire cru
	6291,  -- Goujon brillant cru
	6303,  -- Maquereau ombré cru
	6317,  -- Furie du loch crue
})

ajoute("elems", {
	7067,  -- Terre élémentaire
	7068,  -- Feu élémentaire
	7069,  -- Air élémentaire
	7070,  -- Eau élémentaire
	7076,  -- Essence de terre
	7078,  -- Essence de feu
	7080,  -- Essence d'eau
	7082,  -- Essence d'air
	12803, -- Essence de vie
	12808, -- Essence de non-mort
	7972,  -- Ichor de non-mort
	17010, -- Noyau de feu
	17011, -- Noyau de lave
})

ns.FAMILLES = FAM

-- ---------------------------------------------------------------- catégories --

-- Le tri fiable vient des listes ci-dessus ; les sous-classes modernes restent
-- en repli et toute marchandise inconnue part en « autres ».
local L = ns.L

ns.CATS = {
	herbes   = { nom = L.CAT_HERBES,   icone = "Interface\\Icons\\Trade_Herbalism" },
	minerais = { nom = L.CAT_MINERAIS, icone = "Interface\\Icons\\Trade_Mining" },
	gemmes   = { nom = L.CAT_GEMMES,   icone = "Interface\\Icons\\INV_Misc_Gem_01" },
	cuirs    = { nom = L.CAT_CUIRS,    icone = "Interface\\Icons\\INV_Misc_LeatherScrap_02" },
	tissus   = { nom = L.CAT_TISSUS,   icone = "Interface\\Icons\\INV_Fabric_Linen_01" },
	viandes  = { nom = L.CAT_VIANDES,  icone = "Interface\\Icons\\INV_Misc_Food_14" },
	elems    = { nom = L.CAT_ELEMS,    icone = "Interface\\Icons\\INV_Stone_05" },
	autres   = { nom = L.CAT_AUTRES,   icone = "Interface\\Icons\\INV_Misc_Bag_08" },
}
ns.ORDRE_CATS = { "herbes", "minerais", "gemmes", "cuirs", "tissus", "viandes",
	"elems", "autres" }

local SUB7 = { [9] = "herbes", [7] = "minerais", [6] = "cuirs", [5] = "tissus",
	[8] = "viandes", [10] = "elems" }

function ns.Categorie(id, classID, subClassID)
	local fam = FAM[id]
	if fam then return fam end
	if classID == 7 then return SUB7[subClassID] or "autres" end
	if classID == 3 then return "gemmes" end
end

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- variante « je n'ai que l'itemID » : renvoie la catégorie et l'icône
function ns.CategorieDe(id)
	local _, _, _, _, icone, classID, subClassID = GetItemInfoInstant(id)
	return ns.Categorie(id, classID, subClassID), icone
end
