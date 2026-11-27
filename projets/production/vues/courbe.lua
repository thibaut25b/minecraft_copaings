-- Courbe de l'objet choisi : production et consommation depuis 0, échelle qui résiste aux pics, graduations rondes.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local flux = require("production.flux")
local base = require("production.vues.base")

local R = theme.ROLES

local courbe = {}

--- Le plafond de l'échelle vaut ce multiple de la médiane des points non nuls quand le maximum le dépasse.
courbe.FACTEUR_PLAFOND = 3

local HAUTEUR_ABSCISSES = 5     -- sous cette hauteur, la rangée de l'axe du temps est omise
local PIXELS_REPERE = 3         -- hauteur du repère d'un point plafonné, en pixels

--- Durée de la courbe : 1 h (cases de 1 min) quand la fenêtre vaut 1 h, sinon 10 min (cases de 10 s).
function courbe.duree(etat)
  return etat.fenetre == 3600 and 3600 or 600
end

local function mediane(valeurs)
  table.sort(valeurs)
  local n = #valeurs
  if n % 2 == 1 then return valeurs[(n + 1) / 2] end
  return (valeurs[n / 2] + valeurs[n / 2 + 1]) / 2
end

-- Plafond d'une liste de valeurs non nulles : FACTEUR_PLAFOND fois leur médiane si leur maximum le dépasse.
local function plafonner(non_nulles, maximum)
  if #non_nulles == 0 then return 0 end
  return math.min(maximum, courbe.FACTEUR_PLAFOND * mediane(non_nulles))
end

--- Points de `cle` sur `place` colonnes de pixels au plus (les plus récents), en items/s : { production,
--- consommation } (listes où `false` marque une case sans donnée), largeur (secondes par point), maximum, plafond,
--- plafonnes { [i] = true }. Chaque sens a pour plafond FACTEUR_PLAFOND fois la médiane de ses points non nuls
--- quand son maximum le dépasse ; l'échelle commune est le plus grand des deux : un pic isolé n'écrase pas le reste.
function courbe.preparer(etat, cle, place)
  local duree = courbe.duree(etat)
  local barres = flux.barres(etat.flux, cle, duree, etat.instant)
  local nombre = math.max(1, math.min(#barres, place))
  local points = { production = {}, consommation = {} }
  local non_nulles, maxima = { production = {}, consommation = {} }, { production = 0, consommation = 0 }
  local plafonnes = {}
  for k = #barres - nombre + 1, #barres do
    local barre = barres[k]
    for champ, liste in pairs(points) do
      local valeur = barre[champ]
      if champ == "consommation" and not etat.options.consommation then valeur = 0 end
      liste[#liste + 1] = not barre.vide and valeur
      if not barre.vide and valeur > 0 then
        non_nulles[champ][#non_nulles[champ] + 1] = valeur
        maxima[champ] = math.max(maxima[champ], valeur)
      end
    end
  end
  local plafond = math.max(plafonner(non_nulles.production, maxima.production),
    plafonner(non_nulles.consommation, maxima.consommation))
  for _, liste in pairs(points) do
    for i, valeur in ipairs(liste) do
      if valeur and valeur > plafond then plafonnes[i] = true end
    end
  end
  return { production = points.production, consommation = points.consommation, largeur = duree / #barres,
    maximum = math.max(maxima.production, maxima.consommation), plafond = plafond, plafonnes = plafonnes }
end

--- Graduations rondes (pas de 1, 2 ou 5 fois une puissance de 10) de 0 exclu à `plafond` (dans l'unité affichée)
--- pour `rangees` rangées de cases : de 2 à 4 valeurs dès 4 rangées, la plus grande valeur ronde seule sur 2 ou 3
--- rangées, aucune en dessous ou si le plafond est nul.
function courbe.graduations(plafond, rangees)
  local maxi = math.min(4, math.floor(rangees / 2))
  if maxi < 1 or not (plafond > 0) then return {} end
  local puissance = 10 ^ (math.floor(math.log(plafond) / math.log(10)) - 2)
  while true do
    for _, multiple in ipairs({ 1, 2, 5 }) do
      local pas = multiple * puissance
      local nombre = math.floor(plafond / pas + 1e-9)
      if nombre <= maxi then
        local valeurs = {}
        for i = 1, nombre do valeurs[i] = tonumber(string.format("%.12g", i * pas)) end
        return valeurs
      end
    end
    puissance = puissance * 10
  end
end

--- Repères de l'axe du temps sur `duree` secondes affichées : { secondes avant maintenant, texte }, toutes les
--- 5 min jusqu'à 10 min, sinon toutes les 15 min, puis « maintenant ».
function courbe.reperes(duree)
  local pas = duree <= 600 and 300 or 900
  local reperes = {}
  for avant = math.floor(duree / pas) * pas, pas, -pas do
    reperes[#reperes + 1] = { avant, "-" .. math.floor(avant / 60) .. " min" }
  end
  reperes[#reperes + 1] = { 0, "maintenant" }
  return reperes
end

-- Rangée de pixels de la part `part` du plafond dans une toile de `hpx` rangées, comme la place graphes.courbe.
local function rangee(part, hpx)
  return hpx - math.floor(part * (hpx - 1) + 0.5)
end

-- Graduations et largeur de la gouttière des étiquettes (0 sans étiquette) : complètes, sinon le seul maximum,
-- sinon rien, pour que chaque point garde sa colonne de pixels.
local function etiqueter(largeur, rangees, plafond_unite, points)
  for _, rangees_maxi in ipairs({ rangees, 3, 0 }) do
    local valeurs = courbe.graduations(plafond_unite, math.min(rangees, rangees_maxi))
    local gouttiere = 0
    for _, valeur in ipairs(valeurs) do gouttiere = math.max(gouttiere, panneaux.longueur(base.nombre(valeur)) + 1) end
    if gouttiere == 0 or 2 * (largeur - gouttiere) >= points then return valeurs, gouttiere end
  end
  return {}, 0
end

--- Repères de l'axe du temps placés sur `largeur` cases pour `duree` secondes affichées : { colonne du trait,
--- debut du libellé (cases depuis la gauche du graphe), texte }. Le premier libellé part de son trait, « maintenant »
--- est calé à droite, les autres sont centrés sur leur trait ; tant que deux libellés se touchent, un repère
--- intermédiaire sur deux est retiré (en dernier recours, il ne reste que « maintenant »).
function courbe.placer_reperes(duree, largeur)
  local liste = courbe.reperes(duree)
  while true do
    local places, libre = {}, true
    for i, repere in ipairs(liste) do
      local longueur = panneaux.longueur(repere[2])
      local colonne = math.floor((duree - repere[1]) / duree * (largeur - 1) + 0.5)
      local debut = colonne - math.floor(longueur / 2)
      if repere[1] == 0 then debut = largeur - longueur elseif i == 1 then debut = colonne end
      local precedent = places[#places]
      if debut < 0 or debut + longueur > largeur
        or (precedent and precedent.debut + panneaux.longueur(precedent.texte) >= debut) then
        libre = false
      end
      places[#places + 1] = { colonne = colonne, debut = debut, texte = repere[2] }
    end
    if libre then return places end
    if #liste <= 2 then
      local dernier = places[#places]
      return dernier.debut >= 0 and { dernier } or {}
    end
    local reduite = { liste[1] }
    for i = 2, #liste - 1 do
      if i % 2 == 1 then reduite[#reduite + 1] = liste[i] end
    end
    reduite[#reduite + 1] = liste[#liste]
    liste = reduite
  end
end

-- Courbes dans `trace` selon `options` { graduations, plafond (unité affichée), avec_conso, reperes } : production
-- remplie dessous, graduations en pointillé serré par-dessus le remplissage, puis les deux courbes, repère `R.moyen` en haut des points
-- plafonnés, trait de chaque repère de temps en bas. Renvoie la rangée de cases de chaque graduation.
local function peindre(cible, trace, prepare, options, fond)
  local cases = {}
  panneaux.toile(cible, trace, fond, function(toile, lpx, hpx)
    local cadre = { x = 1, y = 1, largeur = lpx, hauteur = hpx }
    local production = { couleur = R.bon, min = 0, max = prepare.plafond }
    local consommation = { couleur = R.mauvais, min = 0, max = prepare.plafond }
    graphes.courbe(toile, cadre, prepare.production,
      { couleur = R.bon, remplissage = R.bordure, min = 0, max = prepare.plafond })
    for i, valeur in ipairs(options.graduations) do
      local py = rangee(valeur / options.plafond, hpx)
      for px = 1, lpx, 2 do toile.point(px, py, R.discret) end
      local _, y = panneaux.case(trace, 1, py)
      cases[i] = y
    end
    graphes.courbe(toile, cadre, prepare.production, production)
    if options.avec_conso then graphes.courbe(toile, cadre, prepare.consommation, consommation) end
    local nombre = #prepare.production
    for i in pairs(prepare.plafonnes) do
      local px = 1 + (nombre > 1 and math.floor((i - 1) * (lpx - 1) / (nombre - 1) + 0.5) or 0)
      toile.ligne(px, 1, px, math.min(PIXELS_REPERE, hpx), R.moyen)
    end
    for _, repere in ipairs(options.reperes) do
      local px = math.min(lpx, 2 * repere.colonne + 1)
      toile.ligne(px, math.max(1, hpx - 1), px, hpx, R.discret)
    end
  end)
  return cases
end

--- Dessine dans `zone` la courbe de `cle` : unité et vrai maximum en haut, production (remplie) et consommation
--- depuis 0 en bas (production seule si la consommation est masquée), graduations rondes à gauche, axe du temps
--- dessous si la hauteur le permet.
function courbe.dessiner(cible, zone, etat, cle, fond)
  if zone.hauteur < 3 or zone.largeur < 4 then return end
  if not cle or not etat.flux or not etat.instant then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("En attente de mesures", zone.largeur), R.discret, fond)
    return
  end
  local abscisses = zone.hauteur >= HAUTEUR_ABSCISSES
  local hauteur = zone.hauteur - 1 - (abscisses and 1 or 0)
  local complet = courbe.preparer(etat, cle, math.huge)
  local plafond_unite = flux.convertir(complet.plafond, etat.unite)
  local graduations, gouttiere = etiqueter(zone.largeur, hauteur, plafond_unite, #complet.production)
  local trace = { x = zone.x + gouttiere, y = zone.y + 1, largeur = zone.largeur - gouttiere, hauteur = hauteur }
  local prepare = courbe.preparer(etat, cle, 2 * trace.largeur)
  dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer(flux.LIBELLES[etat.unite], zone.largeur), R.discret, fond)
  local maximum = "max " .. base.texte_absolu(prepare.maximum, etat.unite)
  if panneaux.longueur(maximum) + 6 <= zone.largeur then
    dessin.ecrire(cible, zone.x + zone.largeur - panneaux.longueur(maximum), zone.y, maximum,
      next(prepare.plafonnes) and R.moyen or R.texte, fond)
  end
  local reperes = abscisses and courbe.placer_reperes(#prepare.production * prepare.largeur, trace.largeur) or {}
  local cases = peindre(cible, trace, prepare, { graduations = graduations, plafond = plafond_unite,
    avec_conso = etat.options.consommation, reperes = reperes }, fond)
  if gouttiere > 0 then
    for i, valeur in ipairs(graduations) do
      dessin.ecrire(cible, zone.x, cases[i], dessin.aligner(base.nombre(valeur), gouttiere - 1, "droite"), R.discret,
        fond)
    end
    if cases[1] ~= trace.y + hauteur - 1 then
      dessin.ecrire(cible, zone.x, trace.y + hauteur - 1, dessin.aligner("0", gouttiere - 1, "droite"), R.discret,
        fond)
    end
  end
  for _, repere in ipairs(reperes) do
    dessin.ecrire(cible, trace.x + repere.debut, zone.y + zone.hauteur - 1, repere.texte, R.discret, fond)
  end
end

return courbe
