-- Écran de démonstration : tableau de bord d'une colonie MineColonies (bonheur, population, requêtes, raid).

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local fictif = require("galerie.fictif")

local R = theme.ROLES
local IMAGES = 60
local RAID = { 24, 48 }
local HABITANTS, LIMITE = 84, 96

local BONHEUR_JOURS = { 7.1, 7.4, 7.2, 6.6, 6.9, 7.5, 7.8, 8.1, 7.9, 7.6, 8.0, 8.3, 8.2 }

local PROBLEMES = {
  { "Hélène M.", "Acier x16", "Forge", "18 min", { texte = "introuvable", couleur = R.mauvais } },
  { "Bastien R.", "Bois x64", "Scierie", "12 min", { texte = "à fabriquer", couleur = R.moyen } },
  { "Léa F.", "Pain x32", "Boulangerie", "9 min", { texte = "à fabriquer", couleur = R.moyen } },
  { "Marius D.", "Pioche fer", "Mine", "7 min", { texte = "introuvable", couleur = R.mauvais } },
  { "Agathe P.", "Laine x8", "Tisserand", "5 min", { texte = "sans livreur", couleur = R.moyen } },
  { "Victor L.", "Coke x64", "Fonderie", "3 min", { texte = "stock bas", couleur = R.moyen } },
  { "Rose G.", "Cuir x12", "Tannerie", "2 min", { texte = "introuvable", couleur = R.mauvais } },
}

local COLONNES = {
  { titre = "Colon", largeur = 10 },
  { titre = "Objet", largeur = 11 },
  { titre = "Bâtiment", largeur = 11, facultatif = true },
  { titre = "Depuis", largeur = 6, alignement = "droite" },
  { titre = "Cause" },
}

local function bonheur(t)
  local base = 8.2 + 0.15 * fictif.vague(t, IMAGES, 0.9)
  if fictif.pendant(t, RAID[1], RAID[2]) then base = base - 0.06 * (t - RAID[1]) end
  return base
end

local function couleur_bonheur(note)
  if note >= 7.5 then return R.bon end
  if note >= 6 then return R.moyen end
  return R.mauvais
end

local function dessiner_alerte(cible, x, y, largeur, t)
  if fictif.pendant(t, RAID[1], RAID[2]) then
    local couleur = fictif.clignote(t, 8) and R.mauvais or colors.pink
    panneaux.pastille(cible, x, y, "RAID EN COURS : 14 barbares à la porte nord, 6 gardes engagés", couleur, largeur)
    return
  end
  panneaux.rectangle(cible, x, y, largeur, 1, R.surface)
  panneaux.legende(cible, x + 1, y, R.bon, "Aucune menace : 6 gardes en poste, murs intacts", R.surface, R.discret)
end

local function dessiner_bonheur(cible, zone, t)
  local note = bonheur(t)
  panneaux.jauge(cible, zone, note / 10, couleur_bonheur(note), (string.format("%.1f", note):gsub("%.", ",")), "sur 10")
end

local function dessiner_population(cible, zone)
  if zone.hauteur < 2 then return end
  local chiffre = HABITANTS .. " / " .. LIMITE
  dessin.ecrire(cible, zone.x, zone.y, chiffre, R.texte, R.surface)
  dessin.ecrire(cible, zone.x + #chiffre + 1, zone.y, dessin.tronquer("colons", zone.largeur - #chiffre - 1), R.discret,
    R.surface)
  panneaux.barre_fine(cible, zone.x, zone.y + 1, zone.largeur, HABITANTS / LIMITE, R.accent)
  panneaux.paires(cible, { x = zone.x, y = zone.y + 3, largeur = zone.largeur, hauteur = zone.hauteur - 3 }, {
    { "Adultes", "71" },
    { "Enfants", "13" },
    { "Sans emploi", "3", R.moyen },
    { "Lits libres", tostring(LIMITE - HABITANTS) },
  })
end

local function dessiner_historique(cible, zone, t)
  local valeurs = {}
  for i, note in ipairs(BONHEUR_JOURS) do valeurs[i] = note end
  valeurs[#valeurs + 1] = bonheur(t)
  panneaux.courbe(cible, zone, valeurs, {
    couleur = R.accent2, remplissage = R.bordure, min = 4, max = 10,
    graduations = { { 10, "10" }, { 7, "7" }, { 4, "4" } },
    repere = { valeur = 6, couleur = R.moyen },
    abscisses = { "J-13", "J-7", "aujourd'hui" },
  })
end

local function dessiner_requetes(cible, zone, t)
  local bloquees = fictif.pendant(t, RAID[1], RAID[2]) and 6 or 4
  panneaux.secteurs(cible, zone, {
    { 41, R.bon, "Livrées" },
    { 7, R.info, "En cours" },
    { 12, R.moyen, "En attente" },
    { bloquees, R.mauvais, "Bloquées" },
  })
end

local function dessiner_problemes(cible, zone)
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, COLONNES, PROBLEMES, { fond = R.surface })
end

return {
  nom = "colonie",
  titre = "Colonie",
  images = IMAGES,
  dessiner = function(cible, t)
    theme.appliquer(cible, "nuit")
    dessin.effacer(cible, R.fond)
    local largeur, hauteur = cible.getSize()
    panneaux.bandeau(cible, "Colonie de Valbourg", "MineColonies, hôtel de ville niveau 4",
      { { "Jour 87", R.discret }, { fictif.horloge(t, 21, 40), R.accent } })
    dessiner_alerte(cible, 2, 3, largeur - 2, t)
    local haut, reste = 5, hauteur - 4
    local rangees = panneaux.repartir(haut, reste, { 50, 50 }, 1)
    local en_haut = panneaux.repartir(2, largeur - 2, { 24, 28, 48 }, 1)
    local en_bas = panneaux.repartir(2, largeur - 2, { 40, 60 }, 1)
    local h1, h2 = rangees[1].taille, rangees[2].taille
    dessiner_bonheur(cible, panneaux.panneau(cible, en_haut[1].debut, haut, en_haut[1].taille, h1, "Bonheur"), t)
    dessiner_population(cible, panneaux.panneau(cible, en_haut[2].debut, haut, en_haut[2].taille, h1, "Population",
      "limite " .. LIMITE))
    dessiner_historique(cible, panneaux.panneau(cible, en_haut[3].debut, haut, en_haut[3].taille, h1,
      "Bonheur sur 14 jours", "seuil 6"), t)
    dessiner_requetes(cible, panneaux.panneau(cible, en_bas[1].debut, rangees[2].debut, en_bas[1].taille, h2,
      "Requêtes par statut", "aujourd'hui"), t)
    dessiner_problemes(cible, panneaux.panneau(cible, en_bas[2].debut, rangees[2].debut, en_bas[2].taille, h2,
      "Requêtes à problème", #PROBLEMES .. " en souffrance"))
  end,
}
