-- Écran de démonstration : tableau des départs d'une gare et plan du réseau avec les trains en mouvement.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local fictif = require("galerie.fictif")

local R = theme.ROLES
local IMAGES = 60
local DUREE_VOLETS = 4
local VOLETS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local LIGNES = {
  A = { couleur = R.accent, points = { "port", { 0.22, 0.2 }, "centrale", "usine" } },
  B = { couleur = colors.orange, points = { "mine", { 0.24, 0.9 }, "centrale", { 0.62, 0.24 }, "fermes" } },
  C = { couleur = R.bon, points = { "valbourg", { 0.45, 0.08 }, "centrale", { 0.45, 0.7 }, "scierie",
    { 0.9, 0.9 }, "usine" } },
}

-- Position normalisée, nom et place de l'étiquette en cases par rapport à la gare.
local GARES = {
  port = { 0.03, 0.2, "Port-Nord", 0, -1 },
  centrale = { 0.45, 0.52, "Gare centrale", 2, 1 },
  usine = { 0.97, 0.52, "Usine Est", -10, -1 },
  mine = { 0.06, 0.9, "Mine profonde", 0, -1 },
  fermes = { 0.86, 0.24, "Fermes du plateau", -9, -1 },
  valbourg = { 0.28, 0.08, "Valbourg", -10, 0 },
  scierie = { 0.66, 0.9, "Scierie", -3, 1 },
}

-- Étiquettes posées dans cet ordre ; celle qui chevaucherait une étiquette déjà posée est omise.
local ORDRE_ETIQUETTES = { "centrale", "port", "usine", "mine", "fermes", "valbourg", "scierie" }

-- Chaque train fait l'aller-retour entre deux fractions de sa ligne, arrêté un instant à chaque bout.
local TRAINS = {
  { ligne = "A", de = 0, a = 0.45, phase = 0 },
  { ligne = "A", de = 0.5, a = 1, phase = 0.5 },
  { ligne = "B", de = 0, a = 0.55, phase = 0.25 },
  { ligne = "B", de = 0.55, a = 1, phase = 0.7 },
  { ligne = "C", de = 0, a = 0.4, phase = 0.6 },
  { ligne = "C", de = 0.45, a = 1, phase = 0.1 },
}

local A_L_HEURE = { "à l'heure", R.bon }

-- `bascule` : entre les images debut et fin, `champ` prend la valeur `autre`.
local DEPARTS = {
  { "14:33", "Port-Nord", "direct", "A", "2", { "à quai", R.info } },
  { "14:36", "Usine Est", "direct", "A", "1", A_L_HEURE },
  { "14:38", "Mine profonde", "dépôt de charbon", "B", "4", A_L_HEURE,
    bascule = { 20, 50, 6, { "retard +4 min", R.moyen } } },
  { "14:41", "Valbourg", "direct", "C", "3", A_L_HEURE },
  { "14:44", "Fermes du plateau", "silo, moulin", "B", "5", A_L_HEURE, bascule = { 10, 40, 5, "6" } },
  { "14:47", "Scierie", "carrière", "C", "3", { "supprimé", R.mauvais } },
  { "14:52", "Port-Nord", "direct", "A", "2", A_L_HEURE },
  { "14:55", "Mine profonde", "dépôt de charbon", "B", "4", A_L_HEURE },
  { "15:02", "Usine Est", "direct", "A", "1", A_L_HEURE },
  { "15:06", "Valbourg", "Scierie, carrière", "C", "3", A_L_HEURE },
}

local LARGEUR_AVEC_VIA = 75

-- La colonne Via n'apparaît qu'à partir de LARGEUR_AVEC_VIA cases, sinon elle serait illisible.
local COLONNES = {
  { titre = "Heure", largeur = 5 },
  { titre = "Destination", largeur = 18 },
  { titre = "Via", largeur = 20 },
  { titre = "Ligne", largeur = 5, alignement = "centre", facultatif = true },
  { titre = "Voie", largeur = 4, alignement = "centre" },
  { titre = "État" },
}
local COLONNES_SANS_VIA = { COLONNES[1], { titre = "Destination" }, COLONNES[4], COLONNES[5],
  { titre = "État", largeur = 13 } }

-- Texte des volets qui tournent : les lettres se figent de gauche à droite pendant DUREE_VOLETS images.
local function volets(texte, age)
  if age >= DUREE_VOLETS then return texte end
  local figees = math.floor(#texte * age / DUREE_VOLETS)
  local morceaux = {}
  for i = 1, #texte do
    local indice = (i * 7 + age * 13) % #VOLETS + 1
    morceaux[i] = i <= figees and texte:sub(i, i) or VOLETS:sub(indice, indice)
  end
  return table.concat(morceaux)
end

-- Images écoulées depuis le dernier changement de la bascule (debut ou fin), en tenant compte de la boucle.
local function age_bascule(t, bascule)
  local depuis_debut = (t - bascule[1]) % IMAGES
  local depuis_fin = (t - bascule[2]) % IMAGES
  return math.min(depuis_debut, depuis_fin)
end

local function ligne_du_tableau(depart, t)
  local cellules = {
    { texte = depart[1], couleur = R.moyen },
    { texte = depart[2], couleur = R.texte },
    { texte = depart[3], couleur = R.discret },
    { texte = depart[4], couleur = LIGNES[depart[4]].couleur },
    { texte = depart[5], couleur = R.texte },
    { texte = depart[6][1], couleur = depart[6][2] },
  }
  if depart == DEPARTS[1] and not fictif.clignote(t, 10) then cellules[6].couleur = R.texte end
  local bascule = depart.bascule
  if bascule then
    local champ, autre = bascule[3], bascule[4]
    if fictif.pendant(t, bascule[1], bascule[2]) then
      if type(autre) == "table" then
        cellules[champ] = { texte = autre[1], couleur = autre[2] }
      else
        cellules[champ] = { texte = autre, couleur = R.moyen }
      end
    end
    cellules[champ].texte = volets(cellules[champ].texte, age_bascule(t, bascule))
  end
  return cellules
end

local function dessiner_departs(cible, zone, t)
  local lignes = {}
  local avec_via = zone.largeur >= LARGEUR_AVEC_VIA
  for i, depart in ipairs(DEPARTS) do
    lignes[i] = ligne_du_tableau(depart, t)
    if not avec_via then table.remove(lignes[i], 3) end
  end
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur,
    avec_via and COLONNES or COLONNES_SANS_VIA, lignes, { fond = R.surface })
end

-- Points d'une ligne en pixels de la toile.
local function placer(point, lpx, hpx)
  if type(point) == "string" then point = GARES[point] end
  return { x = 3 + math.floor(point[1] * (lpx - 6) + 0.5), y = 3 + math.floor(point[2] * (hpx - 6) + 0.5) }
end

local function trace_ligne(ligne, lpx, hpx)
  local points, longueurs, total = {}, { 0 }, 0
  for i, point in ipairs(ligne.points) do
    points[i] = placer(point, lpx, hpx)
    if i > 1 then
      total = total + math.sqrt((points[i].x - points[i - 1].x) ^ 2 + (points[i].y - points[i - 1].y) ^ 2)
      longueurs[i] = total
    end
  end
  return { points = points, longueurs = longueurs, total = total }
end

-- Point situé à la fraction `part` de la longueur du tracé.
local function sur_trace(trace, part)
  local cherchee = part * trace.total
  for i = 2, #trace.points do
    if cherchee <= trace.longueurs[i] or i == #trace.points then
      local segment = trace.longueurs[i] - trace.longueurs[i - 1]
      local f = segment > 0 and (cherchee - trace.longueurs[i - 1]) / segment or 0
      local p, q = trace.points[i - 1], trace.points[i]
      return p.x + (q.x - p.x) * f, p.y + (q.y - p.y) * f
    end
  end
end

local function peindre_plan(toile, lpx, hpx, t)
  local traces = {}
  for nom, ligne in pairs(LIGNES) do
    traces[nom] = trace_ligne(ligne, lpx, hpx)
    local points = traces[nom].points
    for i = 2, #points do
      for dx = 0, 1 do
        for dy = 0, 1 do
          toile.ligne(points[i - 1].x + dx, points[i - 1].y + dy, points[i].x + dx, points[i].y + dy, ligne.couleur)
        end
      end
    end
  end
  for nom in pairs(GARES) do
    local p = placer(nom, lpx, hpx)
    local cote = nom == "centrale" and 6 or 4
    local bord = (cote - 2) / 2
    toile.rectangle(p.x - bord, p.y - bord, cote, cote, R.texte, true)
    toile.rectangle(p.x - bord + 1, p.y - bord + 1, cote - 2, cote - 2, R.surface, true)
  end
  for _, train in ipairs(TRAINS) do
    local aller = (1 - math.cos(2 * math.pi * (t / IMAGES + train.phase))) / 2
    local x, y = sur_trace(traces[train.ligne], train.de + (train.a - train.de) * aller)
    toile.rectangle(math.floor(x + 0.5) - 1, math.floor(y + 0.5) - 1, 4, 4, R.texte, true)
  end
end

local function dessiner_plan(cible, zone, t)
  local hauteur_plan = zone.hauteur - 2
  if hauteur_plan < 4 then return end
  local plan = { x = zone.x, y = zone.y, largeur = zone.largeur, hauteur = hauteur_plan }
  local lpx, hpx = 2 * plan.largeur, 3 * plan.hauteur
  panneaux.toile(cible, plan, R.surface, function(toile) peindre_plan(toile, lpx, hpx, t) end)
  local posees = {}
  for _, nom in ipairs(ORDRE_ETIQUETTES) do
    local gare = GARES[nom]
    local p = placer(nom, lpx, hpx)
    local x, y = panneaux.case(plan, p.x, p.y)
    local longueur = panneaux.longueur(gare[3])
    x = math.max(plan.x, math.min(x + gare[4], plan.x + plan.largeur - longueur))
    y = math.max(plan.y, math.min(y + gare[5], plan.y + plan.hauteur - 1))
    local libre = true
    for _, posee in ipairs(posees) do
      if posee.y == y and x <= posee.fin + 1 and x + longueur - 1 >= posee.x - 1 then libre = false end
    end
    if libre then
      dessin.ecrire(cible, x, y, gare[3], nom == "centrale" and R.texte or R.discret, R.surface)
      posees[#posees + 1] = { x = x, y = y, fin = x + longueur - 1 }
    end
  end
  local x, y = zone.x, zone.y + zone.hauteur - 1
  for _, nom in ipairs({ "A", "B", "C" }) do
    if x + 9 > zone.x + zone.largeur then return end
    x = x + panneaux.legende(cible, x, y, LIGNES[nom].couleur, "Ligne " .. nom) + 3
  end
end

return {
  nom = "trains",
  titre = "Trains",
  images = IMAGES,
  dessiner = function(cible, t)
    theme.appliquer(cible, "nuit")
    dessin.effacer(cible, R.fond)
    local largeur, hauteur = cible.getSize()
    panneaux.bandeau(cible, "Gare centrale", "réseau Create, 3 lignes",
      { { "Jour 142", R.discret }, { fictif.horloge(t, 14, 32), R.accent } })
    local hauteur_departs = math.min(#DEPARTS + 4, math.floor((hauteur - 2) * 0.42))
    dessiner_departs(cible, panneaux.panneau(cible, 2, 3, largeur - 2, hauteur_departs, "Départs",
      "mis à jour en direct"), t)
    local y = 3 + hauteur_departs + 1
    dessiner_plan(cible, panneaux.panneau(cible, 2, y, largeur - 2, hauteur - y + 1, "Plan du réseau",
      #TRAINS .. " trains en circulation"), t)
  end,
}
