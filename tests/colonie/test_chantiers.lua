-- Chantiers : manques convertis en requêtes, composition de la passe et livraison de bout en bout sur plusieurs passes.

local verif = require("verif")
local chantiers = require("colonie.chantiers")
local fourniture = require("colonie.fourniture")
local lecture = require("colonie.lecture")
local faux_pont = require("faux.pont_me")
local faux_integrateur = require("faux.integrateur")

local TERRE = "minecraft:dirt"
local PIERRE = "minecraft:stone"
local CLE = "10,64,-3"
local HUTTE = { pos = { x = 10, y = 64, z = -3 }, type = "builder", level = 2, displayName = "Builder's Hut",
  citizens = { { id = 1, name = "Léa" } } }

local function ressource(item, besoin, disponible, en_livraison)
  return { item = item, libelle = item, besoin = besoin, disponible = disponible, en_livraison = en_livraison or 0,
    manque = math.max(0, besoin - disponible - (en_livraison or 0)) }
end

local function constructeur(cle, ressources)
  return { cle = cle, pos = {}, nom = "Léa", niveau = 2, ressources = ressources }
end

local function ordinaire(id, cible, candidats)
  return { id = id, libelle = id, demandeur = "", cible = cible, quantite = 16, quantite_min = 16,
    candidats = candidats, equipement = false }
end

-- Monde de bout en bout : une hutte, un faux pont, une fourniture. `brut(needs, available, delivering)` règle la
-- ressource Terre vue par le faux intégrateur ; `passe()` lit, compose, sert et répartit comme le point d'entrée.
local function monde(livraison)
  local m = { livraison = livraison or { [CLE] = true } }
  m.integrateur, m.colonie = faux_integrateur.creer()
  m.colonie.batiments = { HUTTE }
  m.pont, m.etat_pont = faux_pont.creer()
  m.etat_pont.stock[TERRE] = 1000
  m.objet = fourniture.creer(m.pont, { cible_export = "@up", fabriquer = false, ignorer_equipement = true,
    exclusions = {} })
  function m.brut(needs, available, delivering)
    m.colonie.ressources[CLE] = { { item = { name = TERRE }, displayName = "Dirt", status = "?", needs = needs,
      available = available, delivering = delivering or 0 } }
  end
  function m.passe()
    local constructeurs = lecture.constructeurs(m.integrateur)
    local ordinaires = lecture.requetes(m.integrateur)
    local passe = chantiers.composer(ordinaires, constructeurs, m.livraison)
    local _, par_constructeur = chantiers.repartir(m.objet.passer(passe.a_servir))
    return (par_constructeur[CLE] or {})[TERRE]
  end
  function m.exports()
    local quantites = {}
    for i, arguments in ipairs(faux_pont.appels_de(m.etat_pont, "exportItem")) do quantites[i] = arguments[2].count end
    return quantites
  end
  return m
end

return {
  ressource_en_manque_devient_une_requete_du_manque_exact = function()
    local liste = chantiers.requetes({ constructeur(CLE, { ressource(TERRE, 64, 10, 4) }) }, { [CLE] = true })
    verif.egal(#liste, 1)
    verif.egal({ liste[1].quantite, liste[1].quantite_min, liste[1].candidats, liste[1].demandeur, liste[1].chantier,
      liste[1].item, liste[1].equipement }, { 50, 50, { TERRE }, "Léa", CLE, TERRE, false })
  end,

  ressource_sans_manque_n_est_pas_une_requete = function()
    verif.egal(chantiers.requetes({ constructeur(CLE, { ressource(PIERRE, 8, 8) }) }, { [CLE] = true }), {})
  end,

  constructeur_desactive_ne_produit_aucune_requete = function()
    local liste = { constructeur(CLE, { ressource(TERRE, 64, 0) }) }
    verif.egal(chantiers.requetes(liste, {}), {})
    verif.egal(chantiers.requetes(liste, { [CLE] = false }), {})
  end,

  identifiant_stable_quand_la_livraison_avance_puis_change_avec_le_besoin_total = function()
    local function id(besoin, disponible, en_livraison)
      local c = constructeur(CLE, { ressource(TERRE, besoin, disponible, en_livraison) })
      return chantiers.requetes({ c }, { [CLE] = true })[1].id
    end
    verif.egal(id(64, 0), id(64, 20, 10), "disponible et en livraison ne changent pas l'identifiant")
    verif.vrai(id(64, 0) ~= id(128, 0), "un nouveau besoin total donne une nouvelle requête")
    local autre = chantiers.requetes({ constructeur("1,2,3", { ressource(TERRE, 64, 0) }) }, { ["1,2,3"] = true })
    verif.vrai(id(64, 0) ~= autre[1].id, "deux huttes n'ont jamais le même identifiant")
  end,

  composer_met_les_requetes_ordinaires_avant_les_chantiers = function()
    local passe = chantiers.composer({ ordinaire("r1", "", { PIERRE }) },
      { constructeur(CLE, { ressource(TERRE, 64, 0) }) }, { [CLE] = true })
    verif.egal({ #passe.a_servir, passe.a_servir[1].id, passe.a_servir[2].chantier }, { 2, "r1", CLE })
  end,

  requete_ordinaire_d_une_hutte_livree_pour_un_item_du_chantier_est_ecartee = function()
    local constructeurs = { constructeur(CLE, { ressource(TERRE, 64, 0) }) }
    local ordinaires = { ordinaire("terre", CLE, { TERRE }), ordinaire("pierre", CLE, { PIERRE }),
      ordinaire("ailleurs", "0,0,0", { TERRE }) }
    local passe = chantiers.composer(ordinaires, constructeurs, { [CLE] = true })
    verif.egal({ #passe.ecartees, passe.ecartees[1].id }, { 1, "terre" })
    verif.egal({ passe.a_servir[1].id, passe.a_servir[2].id }, { "pierre", "ailleurs" })
    verif.egal(#chantiers.composer(ordinaires, constructeurs, {}).ecartees, 0, "hutte désactivée : rien n'est écarté")
  end,

  composer_sans_requetes_ordinaires_lisibles_garde_les_chantiers = function()
    local passe = chantiers.composer(nil, { constructeur(CLE, { ressource(TERRE, 64, 0) }) }, { [CLE] = true })
    verif.egal({ #passe.a_servir, passe.a_servir[1].chantier }, { 1, CLE })
  end,

  repartir_separe_les_lignes_ordinaires_des_lignes_par_constructeur = function()
    local lignes = fourniture.lignes_sans_pont(chantiers.composer({ ordinaire("r1", "", { PIERRE }) },
      { constructeur(CLE, { ressource(TERRE, 64, 0) }) }, { [CLE] = true }).a_servir)
    local ordinaires, par_constructeur = chantiers.repartir(lignes)
    verif.egal({ #ordinaires, ordinaires[1].requete.id }, { 1, "r1" })
    verif.egal(par_constructeur[CLE][TERRE].statut, "manquant")
  end,

  choisir_garde_le_constructeur_present_et_retombe_sur_le_premier_sinon = function()
    local liste = { constructeur("a", {}), constructeur("b", {}) }
    verif.egal({ chantiers.choisir(liste, "b"), chantiers.choisir(liste, "z"), chantiers.choisir(liste, nil) },
      { "b", "a", "a" })
    verif.egal({ chantiers.choisir({}, "a"), chantiers.choisir(nil, "a") }, { nil, nil })
  end,

  manque_exporte_n_est_pas_relivre_pendant_que_le_coursier_le_porte = function()
    local m = monde()
    m.brut(64, 0)
    verif.egal(m.passe().statut, "livre")
    verif.egal(m.passe().message, "en attente du coursier", "export pas encore pris")
    m.brut(64, 0, 32)
    m.passe()
    m.brut(64, 40, 0)
    verif.egal(m.passe().statut, "livre", "le manque baisse : la même requête reste servie")
    m.brut(64, 64, 0)
    verif.egal(m.passe(), nil, "plus de manque, plus de requête")
    m.passe()
    verif.egal(m.exports(), { 64 })
  end,

  export_partiel_reprend_le_reste_sans_depasser_le_manque = function()
    local m = monde()
    m.brut(64, 0)
    m.etat_pont.capacite = 20
    verif.egal(m.passe().statut, "partiel")
    m.etat_pont.capacite = nil
    verif.egal(m.passe().statut, "livre")
    m.passe()
    verif.egal(m.exports(), { 64, 44 })
    verif.egal(m.etat_pont.livre[TERRE], 64)
  end,

  nouveau_besoin_total_est_servi_meme_juste_apres_une_livraison = function()
    local m = monde()
    m.brut(64, 0)
    m.passe()
    m.brut(64, 64)
    m.passe()
    m.brut(192, 64)
    verif.egal(m.passe().statut, "livre")
    verif.egal(m.exports(), { 64, 128 })
  end,

  constructeur_desactive_n_est_jamais_servi_mais_reste_lisible = function()
    local m = monde({})
    m.brut(64, 0)
    for _ = 1, 3 do verif.egal(m.passe(), nil) end
    verif.egal(m.exports(), {})
    verif.egal(lecture.constructeurs(m.integrateur)[1].ressources[1].manque, 64)
  end,

  chantiers_servis_quand_get_requests_est_en_panne = function()
    local m = monde()
    m.colonie.exceptions.getRequests = "Element Reference{minecraft:enchantment} is not valid in current registry set"
    m.brut(64, 0)
    verif.egal(m.passe().statut, "livre")
    verif.egal(m.exports(), { 64 })
  end,

  requete_ordinaire_de_la_hutte_livree_n_est_pas_livree_en_plus_du_chantier = function()
    local m = monde()
    m.colonie.requetes = { { id = "r1", displayName = "64 Dirt", count = 64, minCount = 64, target = HUTTE.pos,
      items = { { name = TERRE, count = 64 } } } }
    m.brut(64, 0)
    m.passe()
    verif.egal(m.exports(), { 64 })
  end,

  requetes_ecartees_sont_listees_ignorees_avec_leur_raison = function()
    local lignes = fourniture.lignes_ignorees({ ordinaire("r1", CLE, { TERRE }) }, "livrée par l'onglet Chantiers")
    verif.egal({ lignes[1].statut, lignes[1].livre, lignes[1].message, lignes[1].action.type },
      { "ignore", 0, "livrée par l'onglet Chantiers", "ignorer" })
  end,

  requetes_ordinaires_et_chantiers_partagent_le_stock_de_la_passe = function()
    local m = monde()
    m.etat_pont.stock[TERRE] = 70
    m.colonie.requetes = { { id = "r1", displayName = "16 Dirt", count = 16, minCount = 16, target = { x = 0, y = 0, z = 0 },
      items = { { name = TERRE, count = 16 } } } }
    m.brut(64, 0)
    verif.egal(m.passe().statut, "manquant", "la requête ordinaire passe d'abord, il reste 54 sur 64")
    verif.egal(m.exports(), { 16 })
  end,
}
