-- Sons du casino sur un haut-parleur : quelques notes jouées ensemble par événement de jeu.

local peripheriques = require("commun.peripheriques")

local son = {}

--- Notes de chaque événement : { instrument, hauteur (0 à 24) }.
son.NOTES = {
  mise = { { "hat", 12 } },
  rouleau = { { "basedrum", 6 } },
  gain = { { "bell", 12 }, { "bell", 16 }, { "bell", 19 } },
  perte = { { "bass", 6 }, { "bass", 1 } },
  refus = { { "bit", 3 } },
  carte = { { "hat", 18 } },
  explosion = { { "basedrum", 0 }, { "snare", 2 } },
}

--- Joue l'événement `nom` sur `haut_parleur` au `volume` (0 à 3). Renvoie true, ou false et le message d'erreur.
function son.jouer(haut_parleur, nom, volume)
  for _, note in ipairs(son.NOTES[nom] or {}) do
    local ok, message = peripheriques.appel(haut_parleur, "playNote", note[1], volume, note[2])
    if not ok then return false, message end
  end
  return true
end

return son
