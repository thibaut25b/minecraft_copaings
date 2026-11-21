-- Pages du tableau de bord de la colonie : titre, onglets, alertes, corps de page et pied, dessinés sur une cible.

local dessin = require("commun.dessin")
local chantiers = require("colonie.chantiers")

local vues = {}

local SOUS_ONGLET_SUIVANT = { nom = "suivant", libelle = ">" } -- nom hors du format "x,y,z" des clés de hutte
local LARGEUR_NOM_MIN = 10 -- en dessous, le bouton de livraison passe sous le nom du constructeur

local LIGNES_FIXES = 3 -- titre, onglets, pied
local LIGNE_ONGLETS = 2
local ALERTES_MIN = 2
local COLONNE_VALEUR = 12
local LARGEUR_LIBELLE = 10
local LARGEUR_BARRE_MAX = 24
local LARGEUR_BARRE_MIN = 4
local HAUTEUR_AEREE = 14
local BONHEUR_BON = 7
local BONHEUR_MOYEN = 4

-- Statuts d'une ligne de passe : un seul endroit pour l'ordre, le libellé et la couleur (`action` : le joueur doit agir).
local STATUTS = {
  { id = "livre", libelle = "livré", couleur = colors.lime, action = false },
  { id = "partiel", libelle = "partiel", couleur = colors.yellow, action = false },
  { id = "en_fabrication", libelle = "fabrication", couleur = colors.lightBlue, action = false },
  { id = "manquant", libelle = "manquant", couleur = colors.red, action = true },
  { id = "ignore", libelle = "ignoré", couleur = colors.lightGray, action = false },
  { id = "erreur", libelle = "erreur", couleur = colors.orange, action = true },
}

local STATUT_PAR_ID = {}
for _, statut in ipairs(STATUTS) do STATUT_PAR_ID[statut.id] = statut end

local function statut_de(id)
  return STATUT_PAR_ID[id] or { id = id, libelle = tostring(id), couleur = colors.white, action = false }
end

-- Copie triée : les éléments de rang 0 d'abord, l'ordre d'origine conservé à rang égal.
local function trier_par_rang(liste, rang)
  local copie = {}
  for i, element in ipairs(liste) do copie[i] = { element = element, rang = rang(element), ordre = i } end
  table.sort(copie, function(a, b)
    if a.rang ~= b.rang then return a.rang < b.rang end
    return a.ordre < b.ordre
  end)
  local resultat = {}
  for i, entree in ipairs(copie) do resultat[i] = entree.element end
  return resultat
end

-- Écrit sur la ligne `n` de la zone du corps, à la colonne `x` de la zone, coupé à la largeur de la zone.
local function ecrire_zone(cible, zone, n, x, texte, couleur)
  local disponible = zone.largeur - x + 1
  if n < 1 or n > zone.hauteur or disponible < 1 then return end
  dessin.ecrire(cible, zone.x + x - 1, zone.y + n - 1, dessin.tronquer(texte, disponible), couleur)
end

local function ligne_valeur(cible, zone, n, libelle, valeur, couleur, ratio, couleur_barre)
  ecrire_zone(cible, zone, n, 1, dessin.aligner(libelle, LARGEUR_LIBELLE), colors.lightGray)
  ecrire_zone(cible, zone, n, COLONNE_VALEUR, valeur, couleur)
  local debut = COLONNE_VALEUR + #valeur + 1
  local largeur = math.min(LARGEUR_BARRE_MAX, zone.largeur - debut + 1)
  if ratio and n <= zone.hauteur and largeur >= LARGEUR_BARRE_MIN then
    dessin.barre(cible, zone.x + debut - 1, zone.y + n - 1, largeur, ratio, couleur_barre)
  end
end

local function dire_colonie_illisible(cible, zone, n)
  ecrire_zone(cible, zone, n, 1, "Colonie illisible : vérifie l'intégrateur", colors.orange)
end

local function couleur_bonheur(bonheur)
  if bonheur >= BONHEUR_BON then return colors.lime end
  if bonheur >= BONHEUR_MOYEN then return colors.yellow end
  return colors.red
end

local function dessiner_synthese(cible, zone, n, lignes)
  if #lignes == 0 then
    ecrire_zone(cible, zone, n, 1, "Aucune requête en cours", colors.lightGray)
    return
  end
  local nombres = {}
  for _, ligne in ipairs(lignes) do nombres[ligne.statut] = (nombres[ligne.statut] or 0) + 1 end
  local livrees = nombres.livre or 0
  ligne_valeur(cible, zone, n, "Requêtes", livrees .. "/" .. #lignes .. " livrées", colors.white,
    livrees / #lignes, colors.lime)
  for _, statut in ipairs(STATUTS) do
    if nombres[statut.id] then
      n = n + 1
      ecrire_zone(cible, zone, n, 1, string.format("%-3d%s", nombres[statut.id], statut.libelle), statut.couleur)
    end
  end
end

local function dessiner_resume(cible, zone, etat)
  local colonie = etat.colonie
  local n = 1
  if colonie then
    local bonheur = colonie.bonheur
    ligne_valeur(cible, zone, n, "Bonheur", string.format("%.1f/10", bonheur), couleur_bonheur(bonheur),
      bonheur / 10, couleur_bonheur(bonheur))
    local ratio_citoyens = colonie.limite > 0 and colonie.citoyens / colonie.limite or 0
    ligne_valeur(cible, zone, n + 1, "Citoyens", colonie.citoyens .. "/" .. colonie.limite, colors.white,
      ratio_citoyens, colors.cyan)
    ligne_valeur(cible, zone, n + 2, "Tombes", tostring(colonie.tombes),
      colonie.tombes > 0 and colors.red or colors.white)
    ligne_valeur(cible, zone, n + 3, "Visiteurs", tostring(colonie.visiteurs), colors.white)
    ligne_valeur(cible, zone, n + 4, "Chantiers", tostring(colonie.chantiers), colors.white)
    n = n + 5
  else
    dire_colonie_illisible(cible, zone, n)
    n = n + 1
  end
  if zone.hauteur >= HAUTEUR_AEREE then n = n + 1 end
  dessiner_synthese(cible, zone, n, etat.lignes)
end

local function dessiner_requetes(cible, zone, etat)
  if #etat.lignes == 0 then
    ecrire_zone(cible, zone, 1, 1, "Aucune requête en cours", colors.lightGray)
    return
  end
  local colonnes = {
    { titre = "Demandeur", facultatif = true },
    { titre = "Requête" },
    { titre = "Qté", largeur = 7, alignement = "droite" },
    { titre = "Statut", largeur = 11 },
    { titre = "Message", facultatif = true },
  }
  local triees = trier_par_rang(etat.lignes, function(ligne) return statut_de(ligne.statut).action and 0 or 1 end)
  local rangees = {}
  for i, ligne in ipairs(triees) do
    local statut = statut_de(ligne.statut)
    rangees[i] = {
      ligne.requete.demandeur,
      ligne.requete.libelle,
      ligne.livre .. "/" .. ligne.requete.quantite,
      { texte = statut.libelle, couleur = statut.couleur },
      { texte = ligne.message, couleur = colors.lightGray },
    }
  end
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, colonnes, rangees)
end

local function dessiner_travaux(cible, zone, etat)
  local colonie = etat.colonie
  if not colonie then return dire_colonie_illisible(cible, zone, 1) end
  if #colonie.travaux == 0 then
    ecrire_zone(cible, zone, 1, 1, "Aucun chantier en cours", colors.lightGray)
    return
  end
  local colonnes = {
    { titre = "Bâtiment" },
    { titre = "Type", largeur = 12, facultatif = true },
    { titre = "Niv", largeur = 3, alignement = "droite" },
    { titre = "Constructeur", facultatif = true },
    { titre = "État", largeur = 10 },
  }
  local triees = trier_par_rang(colonie.travaux, function(travail) return travail.pris and 1 or 0 end)
  local rangees = {}
  for i, travail in ipairs(triees) do
    rangees[i] = {
      travail.batiment,
      travail.type,
      tostring(travail.niveau),
      travail.constructeur,
      travail.pris and { texte = "en cours", couleur = colors.lime } or { texte = "en attente", couleur = colors.yellow },
    }
  end
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, colonnes, rangees)
end

local function manques(habitant)
  if not habitant.loge and not habitant.employe then return "logis, emploi" end
  if not habitant.loge then return "logis" end
  if not habitant.employe then return "emploi" end
  return ""
end

-- Une santé maximale à 0 signifie que la santé du colon est inconnue (entité non chargée).
local function texte_sante(habitant)
  if habitant.sante_max <= 0 then return "-" end
  return math.floor(habitant.sante + 0.5) .. "/" .. math.floor(habitant.sante_max + 0.5)
end

local function couleur_sante(habitant)
  if habitant.sante_max <= 0 or habitant.sante >= habitant.sante_max then return colors.white end
  return habitant.sante * 2 < habitant.sante_max and colors.red or colors.yellow
end

local function dessiner_habitants(cible, zone, etat)
  local colonie = etat.colonie
  if not colonie then return dire_colonie_illisible(cible, zone, 1) end
  if #colonie.habitants == 0 then
    ecrire_zone(cible, zone, 1, 1, "Aucun habitant", colors.lightGray)
    return
  end
  local colonnes = {
    { titre = "Nom" },
    { titre = "Manque", largeur = 13 },
    { titre = "Santé", largeur = 5, alignement = "droite" },
    { titre = "Métier", facultatif = true },
    { titre = "État", largeur = 10, facultatif = true },
  }
  local triees = trier_par_rang(colonie.habitants, function(habitant) return manques(habitant) == "" and 1 or 0 end)
  local rangees = {}
  for i, habitant in ipairs(triees) do
    rangees[i] = {
      habitant.nom,
      { texte = manques(habitant), couleur = colors.orange },
      { texte = texte_sante(habitant), couleur = couleur_sante(habitant) },
      habitant.metier,
      { texte = habitant.etat, couleur = colors.lightGray },
    }
  end
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, colonnes, rangees)
end

local function dessiner_ressources(cible, corps, etat, constructeur)
  if constructeur.erreur then return ecrire_zone(cible, corps, 1, 1, constructeur.erreur, colors.orange) end
  if #constructeur.ressources == 0 then
    return ecrire_zone(cible, corps, 1, 1, "Aucune ressource à fournir", colors.lightGray)
  end
  local livree = type(etat.livraison) == "table" and etat.livraison[constructeur.cle] == true
  local lignes = (etat.lignes_chantiers or {})[constructeur.cle] or {}
  local colonnes = {
    { titre = "Matériau" },
    { titre = "Besoin", largeur = 6, alignement = "droite", facultatif = true },
    { titre = "Dispo", largeur = 6, alignement = "droite", facultatif = true },
    { titre = "En livr.", largeur = 8, alignement = "droite", facultatif = true },
    { titre = "Manque", largeur = 6, alignement = "droite" },
  }
  if livree then colonnes[#colonnes + 1] = { titre = "Statut", largeur = 11 } end
  local triees = trier_par_rang(constructeur.ressources, function(ressource) return ressource.manque > 0 and 0 or 1 end)
  local rangees = {}
  for i, ressource in ipairs(triees) do
    local ligne = lignes[ressource.item]
    local statut = ligne and statut_de(ligne.statut)
    rangees[i] = {
      ressource.libelle,
      tostring(ressource.besoin),
      tostring(ressource.disponible),
      tostring(ressource.en_livraison),
      { texte = tostring(ressource.manque), couleur = ressource.manque > 0 and colors.orange or colors.lime },
      statut and { texte = statut.libelle, couleur = statut.couleur } or "",
    }
  end
  dessin.tableau(cible, corps.x, corps.y, corps.largeur, corps.hauteur, colonnes, rangees)
end

local function dessiner_chantiers(cible, zone, etat, plan)
  if zone.hauteur < 1 then return end
  if type(etat.constructeurs) ~= "table" then
    return ecrire_zone(cible, zone, 1, 1, "Constructeurs illisibles : vérifie l'intégrateur", colors.orange)
  end
  local chantier = plan.chantier
  if not chantier then return ecrire_zone(cible, zone, 1, 1, "Aucun constructeur dans la colonie", colors.lightGray) end
  local constructeur = chantier.constructeur
  dessin.onglets(cible, zone.x, zone.y, zone.largeur, chantier.sous_onglets, constructeur.cle)
  local titre = constructeur.nom .. " (niveau " .. constructeur.niveau .. ")"
  ecrire_zone(cible, zone, 2, 1, dessin.tronquer(titre, chantier.largeur_nom), colors.white)
  local bouton = chantier.bouton
  if bouton then
    local texte = dessin.aligner(bouton.texte, bouton.x2 - bouton.x1 + 1, "centre")
    if bouton.actif then
      dessin.ecrire(cible, bouton.x1, bouton.y, texte, colors.black, colors.lime)
    else
      dessin.ecrire(cible, bouton.x1, bouton.y, texte, colors.white, colors.red)
    end
  end
  dessiner_ressources(cible, chantier.corps, etat, constructeur)
end

-- Les pages, dans l'ordre des onglets : un seul endroit pour les noms, les libellés et le dessin.
local PAGES = {
  { nom = "resume", libelle = "Résumé", dessiner = dessiner_resume },
  { nom = "requetes", libelle = "Requêtes", dessiner = dessiner_requetes },
  { nom = "travaux", libelle = "Travaux", dessiner = dessiner_travaux },
  { nom = "chantiers", libelle = "Chantiers", dessiner = dessiner_chantiers },
  { nom = "habitants", libelle = "Habitants", dessiner = dessiner_habitants },
}

local function page_nommee(nom)
  for _, page in ipairs(PAGES) do
    if page.nom == nom then return page end
  end
  return PAGES[1]
end

-- Bandeaux sous les onglets : raid d'abord, puis les erreurs (les dernières repliées en « + N autres »).
local function lister_alertes(etat, hauteur)
  local alertes = {}
  if etat.colonie and etat.colonie.raid then
    alertes[1] = { texte = "RAID : colonie attaquée", alignement = "centre", couleur = colors.white, fond = colors.red }
  end
  local budget = math.max(ALERTES_MIN, math.floor((hauteur - LIGNES_FIXES) / 4))
  local erreurs = etat.erreurs
  local montrees = #erreurs <= budget and #erreurs or budget - 1
  for i = 1, montrees do
    alertes[#alertes + 1] = { texte = "! " .. erreurs[i], alignement = "gauche", couleur = colors.orange }
  end
  if #erreurs > montrees then
    alertes[#alertes + 1] = {
      texte = string.format("+ %d autres erreurs", #erreurs - montrees), alignement = "gauche", couleur = colors.orange,
    }
  end
  return alertes
end

local function dessiner_titre(cible, largeur, etat)
  local nom = etat.colonie and etat.colonie.nom or "Colonie"
  dessin.ecrire(cible, largeur - #etat.heure + 1, 1, etat.heure, colors.lightGray)
  dessin.ecrire(cible, 1, 1, dessin.tronquer(nom, largeur - #etat.heure - 1), colors.white)
end

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

-- Géométrie de la page Chantiers dans `zone` : sous-onglets, nom, bouton de livraison et corps ; nil sans constructeur.
local function disposer_chantier(zone, etat)
  local constructeurs = etat.constructeurs
  local cle = chantiers.choisir(constructeurs, etat.constructeur)
  if not cle or zone.hauteur < 1 then return nil end
  local indice = 1
  for i, constructeur in ipairs(constructeurs) do
    if constructeur.cle == cle then indice = i end
  end
  local actif = type(etat.livraison) == "table" and etat.livraison[cle] == true
  local texte = "Livraison auto : " .. (actif and "OUI" or "NON")
  local taille = #texte + 2
  local fin_zone = zone.y + zone.hauteur - 1
  local bouton, largeur_nom, debut_corps
  if zone.largeur >= taille + 1 + LARGEUR_NOM_MIN then
    local x2 = zone.x + zone.largeur - 1
    bouton = { x1 = x2 - taille + 1, x2 = x2, y = zone.y + 1 }
    largeur_nom, debut_corps = zone.largeur - taille - 1, zone.y + 2
  else
    bouton = { x1 = zone.x, x2 = zone.x + math.min(taille, zone.largeur) - 1, y = zone.y + 2 }
    largeur_nom, debut_corps = zone.largeur, zone.y + 3
  end
  if bouton.y > fin_zone then bouton = nil end
  if bouton then bouton.texte, bouton.actif = texte, actif end
  return {
    constructeur = constructeurs[indice],
    suivant = constructeurs[indice % #constructeurs + 1].cle,
    sous_onglets = sous_onglets(zone, constructeurs, indice),
    largeur_nom = largeur_nom,
    bouton = bouton,
    corps = { x = zone.x, y = debut_corps, largeur = zone.largeur, hauteur = math.max(0, fin_zone - debut_corps + 1) },
  }
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local page = page_nommee(etat.page)
  local alertes = lister_alertes(etat, hauteur)
  local y = LIGNE_ONGLETS + 1 + #alertes
  local zone = { x = 1, y = y, largeur = largeur, hauteur = math.max(0, hauteur - y) }
  local plan = {
    largeur = largeur, hauteur = hauteur, page = page, alertes = alertes, zone = zone,
    onglets = dessin.zones_onglets(1, LIGNE_ONGLETS, largeur, PAGES),
  }
  if page.nom == "chantiers" then plan.chantier = disposer_chantier(zone, etat) end
  return plan
end

--- Dessine tout le tableau de bord (titre, onglets, alertes, page `etat.page`, pied) sur la cible.
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  local largeur, hauteur = plan.largeur, plan.hauteur
  dessin.effacer(cible, colors.black)
  dessiner_titre(cible, largeur, etat)
  dessin.onglets(cible, 1, LIGNE_ONGLETS, largeur, PAGES, plan.page.nom)
  for i, alerte in ipairs(plan.alertes) do
    dessin.ecrire(cible, 1, LIGNE_ONGLETS + i, dessin.aligner(alerte.texte, largeur, alerte.alignement), alerte.couleur,
      alerte.fond)
  end
  plan.page.dessiner(cible, plan.zone, etat, plan)
  local secondes = math.max(0, math.ceil(etat.prochaine_passe))
  dessin.ecrire(cible, 1, hauteur, dessin.tronquer("Prochaine passe dans " .. secondes .. " s", largeur),
    colors.lightGray)
end

--- Action du toucher en (x, y), ou nil : `{ type = "page", page }`, `{ type = "constructeur", cle }` (sous-onglet)
--- ou `{ type = "livraison", cle }` (bouton de livraison du constructeur montré).
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  local page = dessin.onglet_sous_point(plan.onglets, x, y)
  if page then return { type = "page", page = page } end
  local chantier = plan.chantier
  if not chantier then return nil end
  local zones = dessin.zones_onglets(plan.zone.x, plan.zone.y, plan.zone.largeur, chantier.sous_onglets)
  local cle = dessin.onglet_sous_point(zones, x, y)
  if cle == SOUS_ONGLET_SUIVANT.nom then return { type = "constructeur", cle = chantier.suivant } end
  if cle then return { type = "constructeur", cle = cle } end
  local bouton = chantier.bouton
  if bouton and y == bouton.y and x >= bouton.x1 and x <= bouton.x2 then
    return { type = "livraison", cle = chantier.constructeur.cle }
  end
  return nil
end

return vues
