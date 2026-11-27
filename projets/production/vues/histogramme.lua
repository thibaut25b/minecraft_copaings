-- Histogramme des débits par tranche de temps : production (stock qui monte) et consommation (stock qui baisse).

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local debit = require("production.debit")
local base = require("production.vues.base")

local R = theme.ROLES

local histogramme = {}

local PIXELS_PAR_CASE = 2
local HAUTEUR_AXE_MINI = 5 -- sous cette hauteur, la rangée des abscisses est omise

--- Nombre de barres pour `zone` : une par colonne de pixels, sans descendre sous la période de mesure (une tranche
--- plus courte que la période n'aurait pas d'échantillon).
function histogramme.nombre_de_barres(zone, duree_graphe, periode)
  return math.max(1, math.min(zone.largeur * PIXELS_PAR_CASE, math.floor(duree_graphe / periode)))
end

-- Productions et consommations (valeurs positives, 0 pour une tranche vide) et plus grande amplitude.
local function separer(barres, nombre)
  local production, consommation, maximum, mesurees = {}, {}, 0, 0
  for k = 1, nombre do
    local valeur = barres[k]
    production[k], consommation[k] = 0, 0
    if valeur then
      mesurees = mesurees + 1
      if valeur > 0 then production[k] = valeur else consommation[k] = -valeur end
      maximum = math.max(maximum, math.abs(valeur))
    end
  end
  return production, consommation, maximum, mesurees
end

--- Dessine dans `zone` l'histogramme de `objet` sur `etat.duree_graphe` : légende et échelle max en haut, barres,
--- abscisses en bas si la hauteur le permet. Les barres partent du bas ; vert = production, rouge = consommation.
function histogramme.dessiner(cible, zone, etat, objet, fond)
  if zone.hauteur < 2 or zone.largeur < 1 then return end
  local serie = objet and etat.series[objet] or {}
  local nombre = histogramme.nombre_de_barres(zone, etat.duree_graphe, etat.periode)
  local production, consommation, maximum, mesurees =
    separer(debit.barres(serie, etat.duree_graphe, nombre), nombre)
  local avec_axe = zone.hauteur >= HAUTEUR_AXE_MINI
  local trace = { x = zone.x, y = zone.y + 1, largeur = zone.largeur, hauteur = zone.hauteur - (avec_axe and 2 or 1) }
  if mesurees == 0 then
    dessin.ecrire(cible, zone.x, trace.y, dessin.tronquer("En attente de mesures", zone.largeur), R.discret, fond)
    return
  end
  local x = zone.x + panneaux.legende(cible, zone.x, zone.y, R.bon, "production", fond, R.discret) + 1
  x = x + panneaux.legende(cible, x, zone.y, R.mauvais, "consommation", fond, R.discret) + 1
  local echelle = "max " .. base.texte_debit(maximum, false, etat.unite):gsub("^%+", "") .. " " .. debit.LIBELLES[etat.unite]
  local longueur = panneaux.longueur(echelle)
  if x + longueur <= zone.x + zone.largeur then
    dessin.ecrire(cible, zone.x + zone.largeur - longueur, zone.y, echelle, R.texte, fond)
  end
  panneaux.toile(cible, trace, fond, function(toile, largeur_px, hauteur_px)
    local cadre = { x = 1, y = 1, largeur = largeur_px, hauteur = hauteur_px }
    graphes.histogramme(toile, cadre, production, { couleur = R.bon, min = 0, max = maximum, ecart = 0 })
    graphes.histogramme(toile, cadre, consommation, { couleur = R.mauvais, min = 0, max = maximum, ecart = 0 })
  end)
  if avec_axe then
    local y = zone.y + zone.hauteur - 1
    dessin.ecrire(cible, zone.x, y, "-" .. base.duree(etat.duree_graphe), R.discret, fond)
    local maintenant = "maintenant"
    if zone.largeur >= #maintenant + 12 then
      dessin.ecrire(cible, zone.x + zone.largeur - #maintenant, y, maintenant, R.discret, fond)
    end
  end
end

return histogramme
