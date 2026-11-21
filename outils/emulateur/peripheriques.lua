-- Faux périphériques de l'émulateur, débranchés au départ : une case à cocher de la page les branche ou les débranche.
-- Pour en ajouter un : une entrée { nom, type, methodes } dans cette liste ; `methodes(hote)` renvoie ses méthodes.
-- `hote.son(frequence, volume, duree)` joue un bip ; le programme trouve le périphérique par peripheral.find(type).

local INSTRUMENTS = {}
for nom in ("harp basedrum snare hat bass flute bell guitar chime xylophone iron_xylophone cow_bell didgeridoo bit "
  .. "banjo pling"):gmatch("%S+") do INSTRUMENTS[nom] = true end

-- Hauteur 0 à 24 d'un bloc musical : 12 vaut fa dièse 4 (370 Hz), un demi-ton par cran.
local function frequence(hauteur)
  return 369.99 * 2 ^ ((hauteur - 12) / 12)
end

return {
  {
    nom = "speaker_0",
    type = "speaker",
    methodes = function(hote)
      return {
        playNote = function(instrument, volume, hauteur)
          if not INSTRUMENTS[instrument] then error("Invalid instrument, \"" .. tostring(instrument) .. "\"!", 2) end
          hote.son(frequence(math.max(0, math.min(24, hauteur or 1))), math.max(0, math.min(3, volume or 1)) / 3, 0.2)
          return true
        end,
        playSound = function(_, volume, vitesse)
          hote.son(440 * math.max(0.5, math.min(2, vitesse or 1)), math.max(0, math.min(3, volume or 1)) / 3, 0.3)
          return true
        end,
        stop = function() end,
      }
    end,
  },
}
