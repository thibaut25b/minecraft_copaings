-- Détail de l'objet choisi : nom et bouton Reset, stock, débits moyens, variation depuis le départ.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local debit = require("production.debit")
local base = require("production.vues.base")

local R = theme.ROLES

local detail = {}

local LIBELLE_RESET = "Reset"

--- Géométrie du détail de `objet` dans `zone` : { zone, objet, reset, zones }. Le bouton Reset vide son suivi.
function detail.disposer(zone, objet)
  local largeur = #LIBELLE_RESET + 2
  local reset = { x1 = zone.x + zone.largeur - largeur, x2 = zone.x + zone.largeur - 1, y1 = zone.y, y2 = zone.y }
  reset.action = { type = "reset", objet = objet }
  return { zone = zone, objet = objet, reset = reset, zones = zone.hauteur >= 1 and objet and { reset } or {} }
end

-- Paires { libellé, valeur, couleur } du détail : stock, quatre débits, variation depuis le départ.
local function paires(etat, objet)
  local serie = etat.series[objet] or {}
  local liste = { { "Stock", base.stock(etat, objet) } }
  for _, fenetre in ipairs(base.FENETRES) do
    local par_seconde, partiel = debit.debit(serie, fenetre[1])
    liste[#liste + 1] = { "Débit " .. fenetre[2], base.texte_debit(par_seconde, partiel, etat.unite) .. " "
      .. debit.LIBELLES[etat.unite], base.couleur_debit(par_seconde, etat.unite) }
  end
  local variation, duree = debit.depuis_debut(serie, etat.departs[objet])
  if variation then
    local signe = variation > 0 and "+" or ""
    liste[#liste + 1] = { "Depuis le début", signe .. texte.milliers(variation) .. " en " .. base.duree(duree),
      base.couleur_debit(variation, "s") }
  else
    liste[#liste + 1] = { "Depuis le début", "-" }
  end
  return liste
end

--- Dessine le détail disposé sur `fond` ; sans objet choisi, un message discret.
function detail.dessiner(cible, plan, etat, fond)
  local zone = plan.zone
  if zone.hauteur < 1 then return end
  if not plan.objet then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Aucun objet choisi", zone.largeur), R.discret, fond)
    return
  end
  local nom = base.nom(etat, base.entree(etat, plan.objet))
  dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer(nom, zone.largeur - #LIBELLE_RESET - 3), R.accent, fond)
  panneaux.pastille(cible, plan.reset.x1, zone.y, LIBELLE_RESET, R.alerte)
  panneaux.paires(cible, { x = zone.x, y = zone.y + 1, largeur = zone.largeur, hauteur = zone.hauteur - 1 },
    paires(etat, plan.objet), fond)
end

return detail
