-- Planche d'échantillons : chaque brique d'affichage disponible, légendée, dans le thème demandé.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local fictif = require("galerie.fictif")

local R = theme.ROLES
local IMAGES = 60

local planche = {}

local ROLES = {
  "fond", "surface", "bordure", "texte", "discret", "accent", "accent2", "bon", "moyen", "mauvais", "info",
}

local function courbe(cible, zone, t)
  panneaux.courbe(cible, zone, fictif.serie(t, IMAGES, 40, 0.8, 55, 35), {
    couleur = R.accent, min = 0, max = 100, graduations = { { 100, "100" }, { 0, "0" } },
  })
end

local function courbe_remplie(cible, zone, t)
  panneaux.courbe(cible, zone, fictif.serie(t, IMAGES, 40, 2.6, 50, 30), {
    couleur = R.accent, remplissage = colors.blue, min = 0, max = 100,
    repere = { valeur = 75, couleur = R.moyen }, abscisses = { "-40 s", "maintenant" },
  })
end

local function histogramme(cible, zone, t)
  local valeurs = {}
  for i = 1, 10 do valeurs[i] = 55 + 40 * fictif.vague(i * 6 + t, IMAGES, 1.4) end
  panneaux.histogramme(cible, zone, valeurs, {
    couleur = colors.blue, max = 100, surligne = math.floor(t / 6) % 10 + 1, couleur_surligne = R.accent,
  })
end

local function anneaux(cible, zone, t)
  local morceaux = panneaux.repartir(zone.x, zone.largeur, { 1, 1, 1 }, 1)
  local reglages = { { 0.82, R.bon, 0.5 }, { 0.6, R.moyen, 2.1 }, { 0.28, R.mauvais, 3.7 } }
  for i, morceau in ipairs(morceaux) do
    local ratio = reglages[i][1] + 0.08 * fictif.vague(t, IMAGES, reglages[i][3])
    panneaux.jauge(cible, { x = morceau.debut, y = zone.y, largeur = morceau.taille, hauteur = zone.hauteur }, ratio,
      reglages[i][2], math.floor(ratio * 100 + 0.5) .. "%")
  end
end

local function secteurs(cible, zone, t)
  local bascule = 6 * fictif.vague(t, IMAGES, 1.2)
  panneaux.secteurs(cible, zone, {
    { 48 + bascule, R.accent, "Fer" },
    { 30 - bascule, R.accent2, "Cuivre" },
    { 14, colors.orange, "Or" },
    { 8, R.info, "Zinc" },
  })
end

local function barres(cible, zone, t)
  local lignes = {
    { "Pleine", R.accent, 0.72, false },
    { "Fine", R.bon, 0.55, true },
    { "Fine", R.moyen, 0.83, true },
    { "Fine", R.mauvais, 0.2, true },
  }
  local pas = zone.hauteur >= 2 * #lignes - 1 and 2 or 1
  for i, ligne in ipairs(lignes) do
    local y = zone.y + (i - 1) * pas
    if y >= zone.y + zone.hauteur then return end
    local ratio = ligne[3] + 0.1 * fictif.vague(t, IMAGES, i)
    dessin.ecrire(cible, zone.x, y, ligne[1], R.discret, R.surface)
    local largeur = zone.largeur - 13
    if ligne[4] then
      panneaux.barre_fine(cible, zone.x + 7, y, largeur, ratio, ligne[2])
    else
      dessin.barre(cible, zone.x + 7, y, largeur, ratio, ligne[2], R.bordure)
    end
    dessin.ecrire(cible, zone.x + zone.largeur - 5, y, dessin.aligner(math.floor(ratio * 100 + 0.5) .. " %", 5,
      "droite"), R.texte, R.surface)
  end
end

local function tableau(cible, zone)
  dessin.tableau(panneaux.sur_fond(cible, R.surface), zone.x, zone.y, zone.largeur, zone.hauteur, {
    { titre = "Objet" },
    { titre = "Stock", largeur = 6, alignement = "droite" },
    { titre = "État", largeur = 11 },
  }, {
    { "Fer", "2 304", { texte = "suffisant", couleur = R.bon } },
    { "Cuivre", "412", { texte = "bas", couleur = R.moyen } },
    { "Mécanismes", "18", { texte = "critique", couleur = R.mauvais } },
    { "Rails", "236", { texte = "suffisant", couleur = R.bon } },
    { "Courroies", "96", { texte = "suffisant", couleur = R.bon } },
    { "Béton", "8 840", { texte = "suffisant", couleur = R.bon } },
    { "Engrenages", "1 480", { texte = "suffisant", couleur = R.bon } },
    { "Tôles de zinc", "64", { texte = "bas", couleur = R.moyen } },
  })
end

local function onglets(cible, zone, t)
  local liste = { { nom = "resume", libelle = "Résumé" }, { nom = "requetes", libelle = "Requêtes" },
    { nom = "stocks", libelle = "Stocks" } }
  local actif = liste[math.floor(t / 20) % #liste + 1]
  dessin.onglets(panneaux.sur_fond(cible, R.surface), zone.x, zone.y, zone.largeur, liste, actif.nom)
  if zone.hauteur >= 3 then
    dessin.ecrire(cible, zone.x, zone.y + 2, dessin.tronquer("Page affichée : " .. actif.libelle, zone.largeur),
      R.discret, R.surface)
  end
end

local function pastilles(cible, zone, t)
  local x = zone.x
  local etats = { { "MARCHE", R.bon }, { "ATTENTE", R.moyen }, { "ALERTE", fictif.clignote(t, 6) and R.mauvais or
    colors.pink }, { "INFO", R.info } }
  for _, etat in ipairs(etats) do
    local largeur = panneaux.longueur(etat[1]) + 2
    if x + largeur > zone.x + zone.largeur then break end
    x = x + panneaux.pastille(cible, x, zone.y, etat[1], etat[2]) + 1
  end
  if zone.hauteur < 3 then return end
  x = zone.x
  for _, etat in ipairs({ { "marche", R.bon }, { "arrêt", R.bordure }, { "alerte", R.mauvais } }) do
    if x + 8 > zone.x + zone.largeur then return end
    x = x + panneaux.legende(cible, x, zone.y + 2, etat[2], etat[1]) + 2
  end
end

local ECHANTILLONS = {
  { "Courbe", "panneaux.courbe", courbe },
  { "Courbe remplie", "remplissage, repère", courbe_remplie },
  { "Histogramme", "panneaux.histogramme", histogramme },
  { "Anneaux", "panneaux.jauge", anneaux },
  { "Secteurs", "panneaux.secteurs", secteurs },
  { "Barres", "dessin.barre, barre_fine", barres },
  { "Tableau", "dessin.tableau", tableau },
  { "Onglets", "dessin.onglets", onglets },
  { "Pastilles", "pastille, legende", pastilles },
}

local function palette(cible, zone)
  local x, y = zone.x, zone.y
  for _, role in ipairs(ROLES) do
    local largeur = #role + 4
    if x + largeur - 2 > zone.x + zone.largeur then
      x, y = zone.x, y + 1
      if y >= zone.y + zone.hauteur then return end
    end
    -- La surface est le fond du panneau : son échantillon se voit par son contour.
    if R[role] == R.surface then
      dessin.ecrire(cible, x, y, "[]", R.bordure, R.surface)
    else
      panneaux.rectangle(cible, x, y, 2, 1, R[role])
    end
    dessin.ecrire(cible, x + 3, y, role, R.texte, R.surface)
    x = x + largeur + 2
  end
end

local function dessiner(cible, t, nom_theme)
  theme.appliquer(cible, nom_theme)
  dessin.effacer(cible, R.fond)
  local largeur, hauteur = cible.getSize()
  panneaux.bandeau(cible, "Vitrine des briques", "thème " .. nom_theme, { { "commun/panneaux.lua", R.discret } })
  local bas = hauteur
  if hauteur >= 30 then
    bas = hauteur - 6
    palette(cible, panneaux.panneau(cible, 2, bas + 2, largeur - 2, 5, "Rôles de la palette", "theme.ROLES"))
  end
  local rangees = panneaux.repartir(3, bas - 2, { 1, 1, 1 }, 1)
  local colonnes = panneaux.repartir(2, largeur - 2, { 1, 1, 1 }, 1)
  for i, echantillon in ipairs(ECHANTILLONS) do
    local rangee, colonne = rangees[math.floor((i - 1) / 3) + 1], colonnes[(i - 1) % 3 + 1]
    local zone = panneaux.panneau(cible, colonne.debut, rangee.debut, colonne.taille, rangee.taille, echantillon[1])
    if zone.hauteur >= 2 then
      local legende = zone.y + zone.hauteur - 1
      dessin.ecrire(cible, zone.x, legende, dessin.tronquer(echantillon[2], zone.largeur), R.accent2, R.surface)
      echantillon[3](cible, { x = zone.x, y = zone.y, largeur = zone.largeur, hauteur = zone.hauteur - 1 }, t)
    end
  end
end

--- Écran de la galerie qui montre la planche dans le thème `nom_theme`.
function planche.ecran(nom, titre, nom_theme)
  return {
    nom = nom,
    titre = titre,
    images = IMAGES,
    dessiner = function(cible, t) dessiner(cible, t, nom_theme) end,
  }
end

return planche
