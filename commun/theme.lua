-- Thèmes de palette pour les cibles de CC : même rôles sur les mêmes emplacements, seuls les RVB changent.

local theme = {}

local EMPLACEMENTS = {
  "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray",
  "lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black",
}

-- Palette d'origine de CC (doc CC: Tweaked, module colors).
local ORIGINE = {
  white = 0xF0F0F0, orange = 0xF2B233, magenta = 0xE57FD8, lightBlue = 0x99B2F2,
  yellow = 0xDEDE6C, lime = 0x7FCC19, pink = 0xF2B2CC, gray = 0x4C4C4C,
  lightGray = 0x999999, cyan = 0x4C99B2, purple = 0xB266E5, blue = 0x3366CC,
  brown = 0x7F664C, green = 0x57A64E, red = 0xCC4C4C, black = 0x111111,
}

local PALETTES = {
  nuit = {
    black = 0x0B1020, gray = 0x1A2236, brown = 0x34415E, lightGray = 0x8D9AB8, white = 0xE6EBF5,
    lightBlue = 0x5AA9FF, purple = 0xA78BFA, lime = 0x4ADE80, yellow = 0xFACC15, red = 0xF87171,
    cyan = 0x2DD4BF, orange = 0xFB923C, magenta = 0xF472B6, pink = 0xFDA4AF, blue = 0x2563EB,
    green = 0x15803D,
  },
  ambre = {
    black = 0x120A00, gray = 0x2A1A00, brown = 0x5C3A00, lightGray = 0xA66A10, white = 0xFFC84A,
    lightBlue = 0xFFE29A, purple = 0xFF8A1F, lime = 0xB8D43A, yellow = 0xFFD21F, red = 0xFF4A1C,
    cyan = 0xE0A458, orange = 0xFF9D2E, magenta = 0xD9732B, pink = 0xF2B880, blue = 0x8C5A14,
    green = 0x8A9A2A,
  },
}

--- Thèmes disponibles.
theme.NOMS = { "nuit", "ambre" }

--- Rôle sémantique -> couleur CC, identique pour tous les thèmes.
theme.ROLES = {
  fond = colors.black,
  surface = colors.gray,
  bordure = colors.brown,
  texte = colors.white,
  discret = colors.lightGray,
  accent = colors.lightBlue,
  accent2 = colors.purple,
  bon = colors.lime,
  moyen = colors.yellow,
  mauvais = colors.red,
  info = colors.cyan,
}

local function poser(cible, palette)
  if type(cible.setPaletteColour) ~= "function" then return end
  for _, nom in ipairs(EMPLACEMENTS) do cible.setPaletteColour(colors[nom], palette[nom]) end
end

--- Pose la palette du thème `nom` sur la cible ; sans effet si la cible n'a pas setPaletteColour.
function theme.appliquer(cible, nom)
  local palette = PALETTES[nom]
  if not palette then error("thème inconnu : " .. tostring(nom), 2) end
  poser(cible, palette)
end

--- Remet la palette d'origine de CC.
function theme.restaurer(cible)
  poser(cible, ORIGINE)
end

return theme
