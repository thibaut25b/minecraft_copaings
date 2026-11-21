-- Lecture de la colonie contre un faux Colony Integrator : instantané complet, dégradé ou refusé.

local verif = require("verif")
local lecture = require("colonie.lecture")
local faux_integrateur = require("faux.integrateur")

local HUTTE = { pos = { x = 10, y = 64, z = -3 }, type = "builder", level = 2, displayName = "Builder's Hut" }

local function peupler(etat)
  etat.citoyens = {
    -- Comme le mod : pas de clé `job` sur le citoyen, elle est dans `workBuilding`.
    { id = 1, name = "Léa", state = "Working", health = 18, maxHealth = 20,
      homeBuilding = { pos = { x = 0, y = 64, z = 0 }, type = "residence", level = 1, displayName = "Residence" },
      workBuilding = { pos = HUTTE.pos, type = "builder", level = 2, displayName = "Builder's Hut",
                       job = "minecolonies:builder" } },
    { id = 2, name = "Tom", state = "Idle" },
  }
  etat.visiteurs = { { id = 9, name = "Ana" } }
  etat.travaux = {
    { id = 3, priority = 1, level = 1, targetLevel = 2, pos = HUTTE.pos, displayName = "Builder's Hut",
      type = "UPGRADE", stage = "BUILD", isClaimed = true, builderHome = HUTTE },
    { id = 4, priority = 1, level = 0, pos = { x = 5, y = 64, z = 5 }, displayName = "Farm",
      type = "INCONNU", stage = "CLEAR", isClaimed = false },
  }
  etat.batiments = { HUTTE }
  etat.requetes = { { id = "tok", displayName = "4 Stone", count = 4, minCount = 4, target = HUTTE.pos,
                      items = { { name = "minecraft:stone", count = 4 } } } }
end

return {
  lire_produit_l_instantane_du_contrat_avec_zero_pour_sante_et_niveau_inconnus = function()
    local integrateur, etat = faux_integrateur.creer()
    peupler(etat)
    etat.chantiers = 1
    verif.egal(lecture.lire(integrateur), {
      nom = "Valfleuri", style = "medievaloak", bonheur = 7.4,
      citoyens = 2, limite = 25, tombes = 0, visiteurs = 1, raid = false, chantiers = 1,
      travaux = {
        { id = 3, batiment = "Builder's Hut", type = "amélioration", niveau = 2, constructeur = "Léa", pris = true },
        { id = 4, batiment = "Farm", type = "inconnu", niveau = 0, constructeur = "", pris = false },
      },
      habitants = {
        { nom = "Léa", metier = "Builder", etat = "Working", sante = 18, sante_max = 20, loge = true, employe = true },
        { nom = "Tom", metier = "", etat = "Idle", sante = 0, sante_max = 0, loge = false, employe = false },
      },
    })
  end,

  raid_vaut_vrai_si_attaque_ou_raid = function()
    local integrateur, etat = faux_integrateur.creer()
    etat.attaque = true
    verif.egal(lecture.lire(integrateur).raid, true)
    etat.attaque, etat.raid = false, true
    verif.egal(lecture.lire(integrateur).raid, true)
  end,

  champs_secondaires_illisibles_degradent_l_instantane = function()
    local integrateur, etat = faux_integrateur.creer()
    peupler(etat)
    etat.exceptions.getVisitors = "chunk déchargé"
    etat.exceptions.getWorkOrders = "chunk déchargé"
    local instantane = lecture.lire(integrateur)
    verif.egal({ instantane.visiteurs, instantane.travaux, #instantane.habitants }, { 0, {}, 2 })
  end,

  hors_colonie_renvoie_nil_et_un_message = function()
    local integrateur, etat = faux_integrateur.creer()
    etat.en_colonie = false
    local instantane, message = lecture.lire(integrateur)
    verif.egal(instantane, nil)
    verif.vrai(message:find("hors colonie", 1, true))
    local liste, raison = lecture.requetes(integrateur)
    verif.egal(liste, nil)
    verif.vrai(raison:find("hors colonie", 1, true))
  end,

  integrateur_absent_renvoie_nil_et_un_message = function()
    local instantane, message = lecture.lire(nil)
    verif.egal(instantane, nil)
    verif.vrai(message:find("introuvable", 1, true))
  end,

  integrateur_qui_leve_renvoie_nil_et_son_message = function()
    local integrateur, etat = faux_integrateur.creer()
    etat.exceptions.isInColony = "chunk déchargé"
    local instantane, message = lecture.lire(integrateur)
    verif.egal(instantane, nil)
    verif.vrai(message:find("chunk déchargé", 1, true))
  end,

  requetes_normalisees_nomment_le_demandeur = function()
    local integrateur, etat = faux_integrateur.creer()
    peupler(etat)
    local liste = lecture.requetes(integrateur)
    verif.egal({ liste[1].id, liste[1].demandeur, liste[1].candidats }, { "tok", "Builder's Hut", { "minecraft:stone" } })
  end,

  requetes_sans_batiments_lisibles_gardent_un_demandeur_vide = function()
    local integrateur, etat = faux_integrateur.creer()
    peupler(etat)
    etat.exceptions.getBuildings = "chunk déchargé"
    verif.egal(lecture.requetes(integrateur)[1].demandeur, "")
  end,

  -- Non-régression : l'erreur brute du mod, coupée à l'écran, ne disait pas au joueur quoi faire.
  requete_a_objet_enchante_donne_une_consigne_au_joueur = function()
    local integrateur, etat = faux_integrateur.creer()
    etat.exceptions.getRequests = "Java Exception Thrown: java.lang.IllegalStateException: Element Reference"
      .. "{ResourceKey[minecraft:enchantment / minecraft:looting]=Enchantment Looting} is not valid in current registry set"
    local liste, message = lecture.requetes(integrateur)
    verif.egal(liste, nil)
    verif.vrai(message:find("presse-papiers", 1, true), message)
    verif.vrai(not message:find("IllegalStateException", 1, true), message)
  end,

  requetes_illisibles_renvoient_nil_et_le_message = function()
    local integrateur, etat = faux_integrateur.creer()
    etat.exceptions.getRequests = "chunk déchargé"
    local liste, message = lecture.requetes(integrateur)
    verif.egal(liste, nil)
    verif.vrai(message:find("chunk déchargé", 1, true))
  end,
}
