-- Écran de démonstration : salle de contrôle d'une usine Create (lignes, stress du réseau, production, stocks).

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local fictif = require("galerie.fictif")

local R = theme.ROLES
local IMAGES = 60
local CAPACITE = 16384
local HISTORIQUE = 60

-- `alerte` : plage d'images où la ligne est en alerte.
local LIGNES = {
  { nom = "Broyeurs à minerai", debit = 1240, charge = 0.82, graine = 0.4 },
  { nom = "Mélange de laiton", debit = 320, charge = 0.64, graine = 1.9 },
  { nom = "Presse à plaques", debit = 960, charge = 0.91, graine = 3.1, alerte = { 20, 44 } },
  { nom = "Four à briques", debit = 0, charge = 0, graine = 0, arret = true },
  { nom = "Chaîne mécanismes", debit = 48, charge = 0.57, graine = 4.2 },
  { nom = "Ligne de béton", debit = 512, charge = 0.73, graine = 5.0 },
}

local PRODUCTION = { 1320, 1480, 1610, 1540, 1720, 1690, 1405, 1580, 1760, 1830, 1650 }

local STOCKS = {
  { nom = "Lingots de laiton", quantite = 2304, seuil = 1000, graine = 0.7 },
  { nom = "Plaques de fer", quantite = 412, seuil = 1000, graine = 2.2 },
  { nom = "Mécanismes de précision", quantite = 18, seuil = 64, graine = 1.1 },
  { nom = "Tiges en fer", quantite = 3120, seuil = 500, graine = 3.6 },
  { nom = "Béton", quantite = 8840, seuil = 2000, graine = 4.4 },
  { nom = "Rails", quantite = 236, seuil = 200, graine = 5.3 },
  { nom = "Courroies", quantite = 96, seuil = 50, graine = 2.9 },
  { nom = "Engrenages", quantite = 1480, seuil = 256, graine = 0.2 },
  { nom = "Rouages de cuivre", quantite = 140, seuil = 128, graine = 4.9 },
  { nom = "Tôles de zinc", quantite = 64, seuil = 256, graine = 1.6 },
}

local function stress(x)
  return CAPACITE * (0.66 + 0.24 * fictif.vague(x, IMAGES, 1.3))
end

local function couleur_stress(ratio)
  if ratio < 0.75 then return R.bon end
  if ratio < 0.9 then return R.moyen end
  return R.mauvais
end

-- Libellé, couleur de la marque, couleur du texte et couleur de la barre de charge.
local function etat_ligne(ligne, t)
  if ligne.arret then return "arrêt", R.bordure, R.discret, R.bordure end
  if ligne.alerte and fictif.pendant(t, ligne.alerte[1], ligne.alerte[2]) then
    return "alerte", fictif.clignote(t, 6) and R.mauvais or R.surface, R.mauvais, R.mauvais
  end
  return "marche", R.bon, R.texte, R.accent
end

-- Colonnes : nom, état (8), débit (11), charge (barre et pourcentage) ; la charge tombe la première si la place manque.
local function dessiner_lignes(cible, zone, t)
  local souple = zone.largeur - (8 + 11 + 2)
  if souple < 10 then return end
  local avec_charge = souple >= 10 + 15
  local largeur_nom = avec_charge and math.min(25, souple - 15) or souple
  local largeur_barre = souple - largeur_nom
  local x_etat = zone.x + largeur_nom + 1
  local x_debit = x_etat + 9
  local x_barre = x_debit + 12
  local pas = zone.hauteur >= 2 * #LIGNES + 1 and 2 or 1
  dessin.ecrire(cible, zone.x, zone.y, "ligne", R.discret, R.surface)
  dessin.ecrire(cible, x_etat, zone.y, "état", R.discret, R.surface)
  dessin.ecrire(cible, x_debit, zone.y, dessin.aligner("débit", 11, "droite"), R.discret, R.surface)
  if avec_charge then dessin.ecrire(cible, x_barre, zone.y, "charge", R.discret, R.surface) end
  for i, ligne in ipairs(LIGNES) do
    local y = zone.y + pas * i
    if y >= zone.y + zone.hauteur then return end
    local libelle, marque, encre, couleur_barre = etat_ligne(ligne, t)
    local variation = ligne.arret and 0 or 0.06 * fictif.vague(t, IMAGES, ligne.graine)
    local charge = ligne.charge + variation
    local debit = ligne.debit * (1 + variation)
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(ligne.nom, largeur_nom), ligne.arret and R.discret or R.texte,
      R.surface)
    panneaux.legende(cible, x_etat, y, marque, libelle, R.surface, encre)
    local debit_texte = ligne.arret and "-" or panneaux.milliers(debit) .. " /min"
    dessin.ecrire(cible, x_debit, y, dessin.aligner(debit_texte, 11, "droite"), R.texte, R.surface)
    if avec_charge then
      panneaux.barre_fine(cible, x_barre, y, largeur_barre - 5, charge, couleur_barre)
      dessin.ecrire(cible, x_barre + largeur_barre - 5, y, dessin.aligner(math.floor(charge * 100 + 0.5) .. " %", 5,
        "droite"), R.discret, R.surface)
    end
  end
end

local function dessiner_jauge(cible, zone, t)
  local actuel = stress(t)
  local ratio = actuel / CAPACITE
  local largeur_anneau = math.min(math.floor(1.5 * zone.hauteur) + 1, math.floor(zone.largeur / 2))
  panneaux.jauge(cible, { x = zone.x, y = zone.y, largeur = largeur_anneau, hauteur = zone.hauteur }, ratio,
    couleur_stress(ratio), math.floor(ratio * 100 + 0.5) .. " %", "stress")
  local x = zone.x + largeur_anneau + 2
  local largeur = zone.x + zone.largeur - x
  if largeur < 12 then return end
  panneaux.paires(cible, { x = x, y = zone.y, largeur = largeur, hauteur = zone.hauteur }, {
    { "Utilisé", panneaux.milliers(actuel) .. " su" },
    { "Capacité", panneaux.milliers(CAPACITE) .. " su" },
    { "Marge", panneaux.milliers(CAPACITE - actuel) .. " su", couleur_stress(ratio) },
    { "Moteurs", "14 actifs" },
  })
end

local function dessiner_courbe(cible, zone, t)
  local valeurs = {}
  for i = 1, HISTORIQUE do valeurs[i] = stress(t - HISTORIQUE + i) end
  panneaux.courbe(cible, zone, valeurs, {
    couleur = R.accent, remplissage = colors.blue, min = 0, max = CAPACITE * 1.15,
    graduations = { { CAPACITE, "16k" }, { CAPACITE / 2, "8k" }, { 0, "0" } },
    repere = { valeur = CAPACITE, couleur = R.mauvais },
    abscisses = { "-60 s", "-30 s", "maintenant" },
  })
end

local function dessiner_production(cible, zone, t)
  local valeurs = {}
  for i, valeur in ipairs(PRODUCTION) do valeurs[i] = valeur end
  valeurs[#valeurs + 1] = 980 + 160 * fictif.vague(t, IMAGES, 2.4)
  panneaux.histogramme(cible, zone, valeurs, {
    couleur = colors.blue, max = 2000, surligne = #valeurs, couleur_surligne = R.accent,
    abscisses = { "08h", "13h", "19h (en cours)" },
  })
end

local function dessiner_stocks(cible, zone, t)
  local tries = {}
  for i, stock in ipairs(STOCKS) do
    local quantite = math.floor(stock.quantite * (1 + 0.04 * fictif.vague(t, IMAGES, stock.graine)) + 0.5)
    tries[i] = { nom = stock.nom, quantite = quantite, seuil = stock.seuil, bas = quantite < stock.seuil }
  end
  table.sort(tries, function(a, b)
    if a.bas ~= b.bas then return a.bas end
    return a.quantite / a.seuil < b.quantite / b.seuil
  end)
  local pas = zone.hauteur >= 2 * #tries and 2 or 1
  for i, stock in ipairs(tries) do
    local y = zone.y + (i - 1) * pas
    if y >= zone.y + zone.hauteur then return end
    local chiffres = panneaux.milliers(stock.quantite)
    if zone.largeur >= 30 then chiffres = chiffres .. " / " .. panneaux.milliers(stock.seuil) end
    local place = zone.largeur - #chiffres - 1
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(stock.nom, place), stock.bas and R.mauvais or R.texte, R.surface)
    dessin.ecrire(cible, zone.x + zone.largeur - #chiffres, y, chiffres, stock.bas and R.mauvais or R.discret,
      R.surface)
    if pas == 2 then
      local ratio = stock.quantite / (2 * stock.seuil)
      local couleur = stock.bas and R.mauvais or (ratio < 0.75 and R.moyen or R.bon)
      panneaux.barre_fine(cible, zone.x, y + 1, zone.largeur, ratio, couleur)
    end
  end
end

return {
  nom = "usine",
  titre = "Usine Create",
  images = IMAGES,
  dessiner = function(cible, t)
    theme.appliquer(cible, "nuit")
    dessin.effacer(cible, R.fond)
    local largeur, hauteur = cible.getSize()
    panneaux.bandeau(cible, "Usine Create", "salle de contrôle, réseau principal",
      { { "Jour 142", R.discret }, { fictif.horloge(t, 14, 32), R.accent } })
    local colonnes = panneaux.repartir(2, largeur - 2, { 63, 37 }, 1)
    local gauche, droite = colonnes[1], colonnes[2]
    local haut_bande = math.max(10, math.floor((hauteur - 2) * 0.3))
    local bas_y = 3 + haut_bande + 1
    local reste = hauteur - bas_y + 1
    dessiner_lignes(cible, panneaux.panneau(cible, gauche.debut, 3, gauche.taille, haut_bande,
      "Lignes de production", #LIGNES .. " lignes"), t)
    dessiner_jauge(cible, panneaux.panneau(cible, droite.debut, 3, droite.taille, haut_bande, "Stress actuel",
      "réseau cinétique"), t)
    if reste >= 14 then
      local rangees = panneaux.repartir(bas_y, reste, { 3, 2 }, 1)
      dessiner_courbe(cible, panneaux.panneau(cible, gauche.debut, rangees[1].debut, gauche.taille, rangees[1].taille,
        "Stress du réseau", "capacité " .. panneaux.milliers(CAPACITE) .. " su"), t)
      dessiner_production(cible, panneaux.panneau(cible, gauche.debut, rangees[2].debut, gauche.taille,
        rangees[2].taille, "Production par heure", "plaques de fer"), t)
    elseif reste >= 5 then
      dessiner_courbe(cible, panneaux.panneau(cible, gauche.debut, bas_y, gauche.taille, reste, "Stress du réseau"), t)
    end
    if reste >= 5 then
      dessiner_stocks(cible, panneaux.panneau(cible, droite.debut, bas_y, droite.taille, reste, "Stocks",
        "sous le seuil en rouge"), t)
    end
  end,
}
