-- Page Chantiers : un sous-onglet par constructeur, avancement, bouton de livraison et matériaux paginés.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local chantiers = require("colonie.chantiers")
local base = require("colonie.vues.base")

local R = theme.ROLES

local page = {}

local SOUS_ONGLET_SUIVANT = { nom = "suivant", libelle = ">" } -- nom hors du format "x,y,z" des clés de hutte
local LARGEUR_NOM_MIN = 10 -- en dessous, le bouton de livraison passe sous le nom du constructeur
local HAUTEUR_ENTETE = 5   -- gabarit riche : panneau du constructeur et bouton de livraison
local LARGEUR_BOUTON_RICHE = 28

local COLONNES = {
  { titre = "Matériau", min = 10 },
  { titre = "Dispo", largeur = 9, alignement = "droite", facultatif = true },
  { titre = "En livr.", largeur = 8, alignement = "droite", facultatif = true },
  { titre = "Manque", largeur = 6, alignement = "droite" },
}
local COLONNE_STATUT = { titre = "Statut", largeur = 11 }

local LEGENDE_BARRE = { { "dispo", R.bon }, { "livraison", R.info }, { "manque", R.mauvais } }

-- Sous-onglets des constructeurs : tous s'ils tiennent, sinon « > » (constructeur suivant) puis la première fenêtre
-- de la liste qui montre le constructeur actif.
local function sous_onglets(zone, constructeurs, indice)
  local tous = {}
  for i, constructeur in ipairs(constructeurs) do tous[i] = { nom = constructeur.cle, libelle = constructeur.nom } end
  if #dessin.zones_onglets(zone.x, zone.y, zone.largeur, tous) == #tous then return tous end
  local fenetre
  for debut = 1, indice do
    fenetre = { SOUS_ONGLET_SUIVANT }
    for i = debut, #tous do fenetre[#fenetre + 1] = tous[i] end
    -- L'actif est le (indice - debut + 2)e onglet de la fenêtre, après « > ».
    if #dessin.zones_onglets(zone.x, zone.y, zone.largeur, fenetre) >= indice - debut + 2 then return fenetre end
  end
  return fenetre
end

local function livraison_active(etat, cle)
  return type(etat.livraison) == "table" and etat.livraison[cle] == true
end

-- Bouton et corps du gabarit compact : le bouton à droite du nom, ou dessous si la place manque.
local function disposer_compact(zone, taille)
  local fin_zone = zone.y + zone.hauteur - 1
  local bouton, largeur_nom, debut
  if zone.largeur >= taille + 1 + LARGEUR_NOM_MIN then
    local x2 = zone.x + zone.largeur - 1
    bouton = { x1 = x2 - taille + 1, x2 = x2, y1 = zone.y + 1, y2 = zone.y + 1 }
    largeur_nom, debut = zone.largeur - taille - 1, zone.y + 2
  else
    bouton = { x1 = zone.x, x2 = zone.x + math.min(taille, zone.largeur) - 1, y1 = zone.y + 2, y2 = zone.y + 2 }
    largeur_nom, debut = zone.largeur, zone.y + 3
  end
  if bouton.y1 > fin_zone then bouton = nil end
  return bouton, largeur_nom, { x = zone.x, y = debut, largeur = zone.largeur, hauteur = math.max(0, fin_zone - debut + 1) }
end

-- Bouton, panneau du constructeur et panneau des matériaux du gabarit riche.
local function disposer_riche(zone)
  local x, largeur = zone.x + 1, zone.largeur - 2
  local y = zone.y + 2
  local largeur_bouton = math.min(LARGEUR_BOUTON_RICHE, math.floor(largeur / 3))
  local bouton = { x1 = x + largeur - largeur_bouton, x2 = x + largeur - 1, y1 = y, y2 = y + HAUTEUR_ENTETE - 1 }
  local entete = { x = x, y = y, largeur = largeur - largeur_bouton - 1, hauteur = HAUTEUR_ENTETE }
  local haut = y + HAUTEUR_ENTETE + 1
  local materiaux = { x = x, y = haut, largeur = largeur, hauteur = zone.y + zone.hauteur - haut }
  return bouton, entete, materiaux
end

--- Géométrie de la page dans `zone` : sous-onglets, bouton de livraison, matériaux paginés et zones touchables.
function page.disposer(zone, etat, riche)
  if zone.hauteur < 1 then return { zone = zone, zones = {} } end
  if type(etat.constructeurs) ~= "table" then
    return { zone = zone, zones = {}, message = base.CONSTRUCTEURS_ILLISIBLES, couleur = R.alerte }
  end
  local constructeurs = etat.constructeurs
  local cle = chantiers.choisir(constructeurs, etat.constructeur)
  if not cle then return { zone = zone, zones = {}, message = "Aucun constructeur dans la colonie", couleur = R.discret } end
  local indice = 1
  for i, constructeur in ipairs(constructeurs) do
    if constructeur.cle == cle then indice = i end
  end
  local constructeur = constructeurs[indice]
  local actif = livraison_active(etat, cle)
  local plan = {
    zone = zone, constructeur = constructeur, actif = actif,
    texte_bouton = "Livraison auto : " .. (actif and "OUI" or "NON"),
    sous_onglets = sous_onglets(zone, constructeurs, indice),
  }
  local zones = {}
  local suivant = constructeurs[indice % #constructeurs + 1].cle
  for _, onglet in ipairs(dessin.zones_onglets(zone.x, zone.y, zone.largeur, plan.sous_onglets)) do
    local cible_cle = onglet.nom == SOUS_ONGLET_SUIVANT.nom and suivant or onglet.nom
    zones[#zones + 1] = { x1 = onglet.x1, x2 = onglet.x2, y1 = onglet.y, y2 = onglet.y,
      action = { type = "constructeur", cle = cible_cle } }
  end
  local corps
  if riche then
    plan.bouton, plan.entete, plan.materiaux = disposer_riche(zone)
    local m = plan.materiaux
    corps = panneaux.interieur(m.x, m.y, m.largeur, m.hauteur)
  else
    local corps_compact
    plan.bouton, plan.largeur_nom, corps_compact = disposer_compact(zone, #plan.texte_bouton + 2)
    plan.avancement = corps_compact.y
    corps = { x = corps_compact.x, y = corps_compact.y + 1, largeur = corps_compact.largeur,
      hauteur = math.max(0, corps_compact.hauteur - 1) }
    plan.corps_message = corps_compact
  end
  if plan.bouton then
    zones[#zones + 1] = { x1 = plan.bouton.x1, x2 = plan.bouton.x2, y1 = plan.bouton.y1, y2 = plan.bouton.y2,
      action = { type = "livraison", cle = cle } }
  end
  if not constructeur.erreur and #constructeur.ressources > 0 then
    plan.liste = base.disposer_liste(corps, "chantier:" .. cle, #constructeur.ressources, etat)
    zones = base.reunir(zones, plan.liste.zones)
  end
  plan.corps = corps
  plan.zones = zones
  return plan
end

local function triees(constructeur)
  return base.trier_par_rang(constructeur.ressources, function(ressource) return ressource.manque > 0 and 0 or 1 end)
end

local function statut_ressource(etat, plan, ressource)
  local lignes = (etat.lignes_chantiers or {})[plan.constructeur.cle] or {}
  local ligne = lignes[ressource.item]
  return ligne and base.pastille(ligne.statut) or ""
end

local function couleur_manque(ressource)
  return ressource.manque > 0 and R.alerte or R.bon
end

local function resume_materiaux(constructeur)
  local manquants, en_livraison = 0, 0
  for _, ressource in ipairs(constructeur.ressources) do
    if ressource.manque > 0 then manquants = manquants + 1 end
    if ressource.en_livraison > 0 then en_livraison = en_livraison + 1 end
  end
  return #constructeur.ressources .. " matériaux, " .. manquants .. " en manque, " .. en_livraison .. " en livraison"
end

local function dessiner_bouton(cible, plan)
  local bouton = plan.bouton
  local fond, encre = plan.actif and R.bon or R.mauvais, plan.actif and R.fond or R.texte
  local largeur = bouton.x2 - bouton.x1 + 1
  panneaux.rectangle(cible, bouton.x1, bouton.y1, largeur, bouton.y2 - bouton.y1 + 1, fond)
  local milieu = bouton.y1 + math.floor((bouton.y2 - bouton.y1) / 2)
  dessin.ecrire(cible, bouton.x1, milieu, dessin.aligner(plan.texte_bouton, largeur, "centre"), encre, fond)
  if bouton.y2 > milieu then
    local aide = plan.actif and "touche pour arrêter" or "touche pour activer"
    dessin.ecrire(cible, bouton.x1, milieu + 1, dessin.aligner(aide, largeur, "centre"), encre, fond)
  end
end

local function dessiner_avancement_compact(cible, plan)
  local zone = { x = plan.zone.x, y = plan.avancement, largeur = plan.zone.largeur, hauteur = 1 }
  local ratio = chantiers.avancement(plan.constructeur)
  if ratio then base.mesure(cible, zone, 1, "Avancement", base.pourcent(ratio), base.couleur_part(ratio), ratio) end
end

local function dessiner_entete_riche(cible, plan)
  local e, constructeur = plan.entete, plan.constructeur
  local interieur = panneaux.panneau(cible, e.x, e.y, e.largeur, e.hauteur,
    constructeur.nom .. " (niveau " .. constructeur.niveau .. ")", "hutte " .. constructeur.cle)
  local ratio = chantiers.avancement(constructeur)
  if not ratio then return base.ecrire(cible, interieur, 1, 1, "Pas de chantier en cours", R.discret, R.surface) end
  local texte = "Avancement " .. base.pourcent(ratio)
  local ecrit = base.ecrire(cible, interieur, 1, 1, texte, base.couleur_part(ratio), R.surface)
  panneaux.barre_fine(cible, interieur.x + ecrit + 2, interieur.y, interieur.largeur - ecrit - 2, ratio,
    base.couleur_part(ratio))
  base.ecrire(cible, interieur, 2, 1, resume_materiaux(constructeur), R.discret, R.surface)
end

-- Rangées des matériaux du gabarit riche : nom, barre empilée sur le besoin, chiffres, manque et statut.
local function dessiner_materiaux_riche(cible, plan, etat)
  local liste, zone = plan.liste, plan.liste.zone
  local avec_statut = plan.actif
  local largeur_nom = math.min(26, math.floor(zone.largeur * 0.28))
  local largeur_statut = avec_statut and 12 or 0
  local x_manque = zone.x + zone.largeur - largeur_statut - 10
  local x_chiffres = x_manque - 13
  local x_barre = zone.x + largeur_nom + 1
  local largeur_barre = x_chiffres - x_barre - 2
  local f = R.surface
  dessin.ecrire(cible, zone.x, zone.y, "Matériau", R.discret, f)
  local legende = { x = x_barre, y = zone.y, largeur = math.max(0, largeur_barre), hauteur = 1 }
  base.legende(cible, legende, 1, LEGENDE_BARRE, f)
  dessin.ecrire(cible, x_chiffres, zone.y, dessin.aligner("Dispo/besoin", 12, "droite"), R.discret, f)
  dessin.ecrire(cible, x_manque, zone.y, dessin.aligner("Manque", 9, "droite"), R.discret, f)
  if avec_statut then dessin.ecrire(cible, x_manque + 10, zone.y, "Statut", R.discret, f) end
  local ressources = triees(plan.constructeur)
  local decoupe = liste.decoupe
  for i = decoupe.debut, decoupe.fin do
    local ressource = ressources[i]
    local y = zone.y + i - decoupe.debut + 1
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(ressource.libelle, largeur_nom), R.texte, f)
    if largeur_barre >= 6 then
      local disponible = math.min(ressource.disponible, ressource.besoin)
      local en_livraison = math.min(ressource.en_livraison, ressource.besoin - disponible)
      panneaux.barre_empilee(cible, { x = x_barre, y = y, largeur = largeur_barre, hauteur = 1 }, {
        { disponible, R.bon }, { en_livraison, R.info }, { ressource.manque, R.mauvais },
      }, ressource.besoin)
    end
    local chiffres = panneaux.milliers(ressource.disponible) .. "/" .. panneaux.milliers(ressource.besoin)
    dessin.ecrire(cible, x_chiffres, y, dessin.aligner(chiffres, 12, "droite"), R.texte, f)
    local manque = ressource.manque > 0 and panneaux.milliers(ressource.manque) or "complet"
    dessin.ecrire(cible, x_manque, y, dessin.aligner(manque, 9, "droite"), couleur_manque(ressource), f)
    local statut = avec_statut and statut_ressource(etat, plan, ressource)
    if type(statut) == "table" then
      dessin.ecrire(cible, x_manque + 10, y, dessin.aligner(statut.texte, 11, "centre"), statut.couleur, statut.fond)
    end
  end
  base.dessiner_commande(cible, liste, #ressources, f)
end

local function dessiner_materiaux_compact(cible, plan, etat)
  local colonnes = {}
  for i, colonne in ipairs(COLONNES) do colonnes[i] = colonne end
  if plan.actif then colonnes[#colonnes + 1] = COLONNE_STATUT end
  local rangees = {}
  for i, ressource in ipairs(triees(plan.constructeur)) do
    rangees[i] = {
      ressource.libelle,
      ressource.disponible .. "/" .. ressource.besoin,
      tostring(ressource.en_livraison),
      { texte = tostring(ressource.manque), couleur = couleur_manque(ressource) },
      statut_ressource(etat, plan, ressource),
    }
  end
  base.dessiner_liste(cible, plan.liste, colonnes, rangees, R.fond, R.surface)
end

--- Dessine la page disposée.
function page.dessiner(cible, plan, etat, riche)
  local zone = plan.zone
  if plan.message then return base.message(cible, zone, plan.message, plan.couleur, R.fond) end
  if not plan.constructeur then return end
  dessin.onglets(cible, zone.x, zone.y, zone.largeur, plan.sous_onglets, plan.constructeur.cle)
  local constructeur = plan.constructeur
  if riche then
    dessiner_entete_riche(cible, plan)
    local m = plan.materiaux
    panneaux.panneau(cible, m.x, m.y, m.largeur, m.hauteur, "Matériaux du chantier", "manques en premier")
  else
    local titre = constructeur.nom .. " (niveau " .. constructeur.niveau .. ")"
    base.ecrire(cible, zone, 2, 1, dessin.tronquer(titre, plan.largeur_nom), R.texte, R.fond)
    dessiner_avancement_compact(cible, plan)
  end
  if plan.bouton then dessiner_bouton(cible, plan) end
  local fond = riche and R.surface or R.fond
  local message_zone = riche and plan.corps or plan.corps_message
  if constructeur.erreur then return base.message(cible, message_zone, constructeur.erreur, R.alerte, fond) end
  if not plan.liste then return base.message(cible, message_zone, "Aucune ressource à fournir", R.discret, fond) end
  if riche then return dessiner_materiaux_riche(cible, plan, etat) end
  dessiner_materiaux_compact(cible, plan, etat)
end

return page
