-- API de CC sans état machine, reproduites d'après CC: Tweaked 1.120 : colors, colours, keys, textutils, parallel.

local bibliotheques = {}

local NOMS_COULEURS = {
  "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray",
  "lightGray", "cyan", "purple", "blue", "brown", "green", "red", "black",
}
local HEXA = "0123456789abcdef"

-- Combine bit à bit deux entiers de 16 bits selon `regle(a, b)` sur chaque bit (pas d'opérateur bit à bit en Lua 5.1).
local function bit_a_bit(a, b, regle)
  local resultat, poids = 0, 1
  a, b = math.floor(a), math.floor(b)
  for _ = 1, 16 do
    local x, y = a % 2, b % 2
    if regle(x == 1, y == 1) then resultat = resultat + poids end
    a, b, poids = (a - x) / 2, (b - y) / 2, poids * 2
  end
  return resultat
end

--- Nouvelle table `colors` de CC.
function bibliotheques.colors()
  local colors = {}
  for i, nom in ipairs(NOMS_COULEURS) do colors[nom] = 2 ^ (i - 1) end
  function colors.combine(...)
    local resultat = 0
    for _, couleur in ipairs({ ... }) do resultat = bit_a_bit(resultat, couleur, function(x, y) return x or y end) end
    return resultat
  end
  function colors.subtract(ensemble, ...)
    local resultat = ensemble
    for _, couleur in ipairs({ ... }) do resultat = bit_a_bit(resultat, couleur, function(x, y) return x and not y end) end
    return resultat
  end
  function colors.test(ensemble, couleur)
    return bit_a_bit(ensemble, couleur, function(x, y) return x and y end) == couleur
  end
  function colors.packRGB(r, v, b)
    return math.floor(r * 255) % 256 * 65536 + math.floor(v * 255) % 256 * 256 + math.floor(b * 255) % 256
  end
  function colors.unpackRGB(rvb)
    return math.floor(rvb / 65536) % 256 / 255, math.floor(rvb / 256) % 256 / 255, rvb % 256 / 255
  end
  function colors.rgb8(r, v, b)
    if v == nil then return colors.unpackRGB(r) end
    return colors.packRGB(r, v, b)
  end
  function colors.toBlit(couleur)
    for i = 0, 15 do
      if couleur == 2 ^ i then return HEXA:sub(i + 1, i + 1) end
    end
    error("Invalid colour: " .. tostring(couleur), 2)
  end
  function colors.fromBlit(caractere)
    local indice = type(caractere) == "string" and #caractere == 1 and HEXA:find(caractere:lower(), 1, true)
    return indice and 2 ^ (indice - 1) or nil
  end
  return colors
end

--- Nouvelle table `colours` de CC : celle de colors, grey et lightGrey à la place de gray et lightGray.
function bibliotheques.colours(colors)
  local colours = {}
  for cle, valeur in pairs(colors) do colours[cle] = valeur end
  colours.grey, colours.lightGrey = colors.gray, colors.lightGray
  colours.gray, colours.lightGray = nil, nil
  return colours
end

--- Nouvelle table `keys` de CC (codes GLFW depuis Minecraft 1.13).
function bibliotheques.keys()
  local keys = {
    space = 32, apostrophe = 39, comma = 44, minus = 45, period = 46, slash = 47, semicolon = 59, equals = 61,
    leftBracket = 91, backslash = 92, rightBracket = 93, grave = 96,
    enter = 257, tab = 258, backspace = 259, insert = 260, delete = 261, right = 262, left = 263, down = 264,
    up = 265, pageUp = 266, pageDown = 267, home = 268, ["end"] = 269, capsLock = 280, scrollLock = 281,
    numLock = 282, printScreen = 283, pause = 284, numPadDecimal = 330, numPadDivide = 331, numPadMultiply = 332,
    numPadSubtract = 333, numPadAdd = 334, numPadEnter = 335, numPadEqual = 336, leftShift = 340, leftCtrl = 341,
    leftAlt = 342, leftSuper = 343, rightShift = 344, rightCtrl = 345, rightAlt = 346, menu = 348,
  }
  keys["return"] = keys.enter
  for i = 0, 25 do keys[string.char(97 + i)] = 65 + i end
  for i, nom in ipairs({ "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" }) do
    keys[nom] = 47 + i
    keys["numPad" .. (i - 1)] = 319 + i
  end
  for i = 1, 25 do keys["f" .. i] = 289 + i end
  local noms = {}
  for nom, code in pairs(keys) do
    if nom ~= "return" then noms[code] = nom end
  end
  function keys.getName(code) return noms[code] end
  return keys
end

local MOTS_RESERVES = {}
for mot in ("and break do else elseif end false for function goto if in local nil not or repeat return then true "
  .. "until while"):gmatch("%a+") do MOTS_RESERVES[mot] = true end

local function nombre_cc(valeur)
  if valeur ~= valeur then return "0/0" end
  if valeur == math.huge then return "1/0" end
  if valeur == -math.huge then return "-1/0" end
  if valeur == math.floor(valeur) and math.abs(valeur) < 2 ^ 53 then return string.format("%d", valeur) end
  return tostring(valeur)
end

local function serialiser(valeur, suivies, retrait, compact, repetitions)
  local genre = type(valeur)
  if genre == "string" then return string.format("%q", valeur) end
  if genre == "number" then return nombre_cc(valeur) end
  if genre == "boolean" or genre == "nil" then return tostring(valeur) end
  if genre ~= "table" then error("Cannot serialize type " .. genre, 0) end
  if suivies[valeur] ~= nil then
    error(suivies[valeur] and "Cannot serialize table with recursive entries"
      or "Cannot serialize table with repeated entries", 0)
  end
  suivies[valeur] = true
  local resultat = "{}"
  if next(valeur) ~= nil then
    local ouvre, sous_retrait, cle_ouvre, cle_ferme, egal, virgule = "{\n", retrait .. "  ", "[ ", " ] = ", " = ", ",\n"
    if compact then ouvre, sous_retrait, cle_ouvre, cle_ferme, egal, virgule = "{", "", "[", "]=", "=", "," end
    local morceaux = { ouvre }
    local vues = {}
    for cle, element in ipairs(valeur) do
      vues[cle] = true
      morceaux[#morceaux + 1] = sous_retrait .. serialiser(element, suivies, sous_retrait, compact, repetitions) .. virgule
    end
    for cle, element in pairs(valeur) do
      if not vues[cle] then
        local texte
        if type(cle) == "string" and not MOTS_RESERVES[cle] and cle:match("^[%a_][%w_]*$") then
          texte = cle .. egal .. serialiser(element, suivies, sous_retrait, compact, repetitions)
        else
          texte = cle_ouvre .. serialiser(cle, suivies, sous_retrait, compact, repetitions) .. cle_ferme
            .. serialiser(element, suivies, sous_retrait, compact, repetitions)
        end
        morceaux[#morceaux + 1] = sous_retrait .. texte .. virgule
      end
    end
    morceaux[#morceaux + 1] = (compact and "" or retrait) .. "}"
    resultat = table.concat(morceaux)
  end
  if repetitions then suivies[valeur] = nil else suivies[valeur] = false end
  return resultat
end

--- Nouvelle table `textutils` de CC (serialize, unserialize, formatTime).
function bibliotheques.textutils()
  local textutils = {}
  function textutils.serialize(valeur, options)
    options = options or {}
    return serialiser(valeur, {}, "", options.compact, options.allow_repetitions)
  end
  function textutils.unserialize(texte)
    local chargeur = load("return " .. tostring(texte), "unserialize", "t", {})
    if chargeur then
      local ok, resultat = pcall(chargeur)
      if ok then return resultat end
    end
    return nil
  end
  function textutils.formatTime(heure, vingt_quatre)
    local suffixe
    if not vingt_quatre then
      suffixe = heure >= 12 and "PM" or "AM"
      if heure >= 13 then heure = heure - 12 end
    end
    local heures = math.floor(heure)
    local minutes = math.floor((heure - heures) * 60)
    if suffixe then return string.format("%d:%02d %s", heures == 0 and 12 or heures, minutes, suffixe) end
    return string.format("%d:%02d", heures, minutes)
  end
  textutils.serialise, textutils.unserialise = textutils.serialize, textutils.unserialize
  return textutils
end

--- Nouvelle table `parallel` de CC ; `attendre()` est os.pullEventRaw (sans filtre), `creer(f)` coroutine.create.
function bibliotheques.parallel(attendre, creer)
  local function coroutines(...)
    local fonctions = table.pack(...)
    local liste = {}
    for i = 1, fonctions.n do
      if type(fonctions[i]) ~= "function" then
        error("bad argument #" .. i .. " (function expected, got " .. type(fonctions[i]) .. ")", 3)
      end
      liste[i] = creer(fonctions[i])
    end
    return liste
  end

  -- Fait tourner les coroutines jusqu'à ce qu'il n'en reste que `limite` vivantes ; renvoie l'indice de la dernière morte.
  local function jusqua(liste, limite)
    local nombre = #liste
    if nombre < 1 then return 0 end
    local vivantes = nombre
    local filtres = {}
    local evenement = { n = 0 }
    while true do
      for n = 1, nombre do
        local fil = liste[n]
        if fil and (filtres[fil] == nil or filtres[fil] == evenement[1] or evenement[1] == "terminate") then
          local ok, filtre = coroutine.resume(fil, table.unpack(evenement, 1, evenement.n))
          if not ok then error(filtre, 0) end
          filtres[fil] = filtre
          if coroutine.status(fil) == "dead" then
            liste[n] = nil
            vivantes = vivantes - 1
            if vivantes <= limite then return n end
          end
        end
      end
      for n = 1, nombre do
        local fil = liste[n]
        if fil and coroutine.status(fil) == "dead" then
          liste[n] = nil
          vivantes = vivantes - 1
          if vivantes <= limite then return n end
        end
      end
      evenement = table.pack(attendre())
    end
  end

  return {
    waitForAny = function(...)
      local liste = coroutines(...)
      return jusqua(liste, #liste - 1)
    end,
    waitForAll = function(...)
      jusqua(coroutines(...), 0)
    end,
  }
end

return bibliotheques
