-- Écrans du casino : une seule géométrie (`vues.disposer`) pour dessiner et pour traduire un toucher en action.

local dessin = require("commun.dessin")
local theme = require("commun.theme")
local base = require("casino.vues.base")

local R = theme.ROLES

local vues = {}

--- Plus petite cible jouable.
vues.MIN = base.MIN

local ECRANS = {
  hall = require("casino.vues.hall"),
  machine = require("casino.vues.machine"),
  roulette = require("casino.vues.roulette"),
  crash = require("casino.vues.crash"),
  blackjack = require("casino.vues.blackjack"),
}

--- Plan de l'écran courant pour une cible de `largeur` x `hauteur` : { zones, ... } ; `trop_petit` sous le minimum.
--- Une zone : { cle, x, y, largeur, hauteur, action, inactif, bouton (dessinée par la barre) }.
function vues.disposer(largeur, hauteur, etat)
  if largeur < base.MIN.largeur or hauteur < base.MIN.hauteur then return { trop_petit = true, zones = {} } end
  local ecran = ECRANS[etat.ecran]
  if etat.regles and etat.ecran ~= "hall" then
    local plan = base.disposer_regles(largeur, hauteur)
    plan.dessiner = function(cible)
      base.bandeau(cible, largeur, ecran.titre, etat)
      base.dessiner_regles(cible, plan, ecran.titre, ecran.regles())
    end
    return plan
  end
  local plan = ecran.disposer(largeur, hauteur, etat)
  plan.dessiner = function(cible, maintenant) ecran.dessiner(cible, plan, etat, maintenant) end
  return plan
end

--- Dessine l'écran courant à l'instant `maintenant` (secondes, même horloge que la session).
function vues.dessiner(cible, etat, maintenant)
  local largeur, hauteur = cible.getSize()
  local plan = vues.disposer(largeur, hauteur, etat)
  dessin.effacer(cible, R.fond)
  if plan.trop_petit then return base.trop_petit(cible, largeur, hauteur) end
  plan.dessiner(cible, maintenant)
  for _, zone in ipairs(plan.zones) do
    if zone.bouton then base.bouton(cible, zone, etat, maintenant) end
  end
end

--- Action du toucher en (x, y), ou nil (hors zone, zone inactive ou simple affichage) : une table { type, cle, ... }
--- que comprend `session.agir`.
function vues.action_touchee(cible, etat, x, y)
  local largeur, hauteur = cible.getSize()
  for _, zone in ipairs(vues.disposer(largeur, hauteur, etat).zones) do
    if zone.action and not zone.inactif and base.dans(zone, x, y) then return zone.action end
  end
  return nil
end

return vues
