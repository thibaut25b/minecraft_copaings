-- Roulette européenne (0 à 36) : cases du tapis, paiements et tirage, sans rien afficher.

local roulette = {}

--- Ordre des numéros sur la roue européenne, en partant du 0.
roulette.ROUE = {
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
}

local ROUGES = {}
for _, numero in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do
  ROUGES[numero] = true
end

--- Gain total (mise comprise) pour un jeton gagnant, par genre de case.
roulette.RETOURS = { plein = 36, douzaine = 3, colonne = 3, simple = 2 }

--- Couleur d'un numéro : "vert" (0), "rouge" ou "noir".
function roulette.couleur(numero)
  if numero == 0 then return "vert" end
  return ROUGES[numero] and "rouge" or "noir"
end

local function entre(bas, haut)
  return function(numero) return numero >= bas and numero <= haut end
end

local function colonne(reste)
  return function(numero) return numero > 0 and numero % 3 == reste end
end

local function couleur(voulue)
  return function(numero) return roulette.couleur(numero) == voulue end
end

local function parite(reste)
  return function(numero) return numero > 0 and numero % 2 == reste end
end

-- Cases hors numéros pleins : genre, libellés long et court, numéros gagnants.
local EXTERIEURES = {
  d1 = { genre = "douzaine", libelle = "1-12", court = "1-12", contient = entre(1, 12) },
  d2 = { genre = "douzaine", libelle = "13-24", court = "13-24", contient = entre(13, 24) },
  d3 = { genre = "douzaine", libelle = "25-36", court = "25-36", contient = entre(25, 36) },
  c1 = { genre = "colonne", libelle = "2:1", court = "2:1", contient = colonne(1) },
  c2 = { genre = "colonne", libelle = "2:1", court = "2:1", contient = colonne(2) },
  c3 = { genre = "colonne", libelle = "2:1", court = "2:1", contient = colonne(0) },
  manque = { genre = "simple", libelle = "1-18", court = "1-18", contient = entre(1, 18) },
  passe = { genre = "simple", libelle = "19-36", court = "19-36", contient = entre(19, 36) },
  pair = { genre = "simple", libelle = "Pair", court = "Pair", contient = parite(0) },
  impair = { genre = "simple", libelle = "Impair", court = "Imp", contient = parite(1) },
  rouge = { genre = "simple", libelle = "Rouge", court = "Rge", contient = couleur("rouge") },
  noir = { genre = "simple", libelle = "Noir", court = "Noir", contient = couleur("noir") },
}

--- Clés des cases hors numéros, dans l'ordre du tapis : douzaines, colonnes (de bas en haut), chances simples.
roulette.EXTERIEURES = { "d1", "d2", "d3", "c1", "c2", "c3", "manque", "pair", "rouge", "noir", "impair", "passe" }

--- Clé de la case du numéro plein `numero`.
function roulette.cle_numero(numero)
  return "n" .. numero
end

--- Case de clé `cle` ({ genre, libelle, court, contient(numero) }), ou nil si la clé est inconnue.
function roulette.case(cle)
  local chiffres = type(cle) == "string" and cle:match("^n(%d+)$")
  if chiffres then
    local numero = tonumber(chiffres)
    if numero > 36 then return nil end
    return { genre = "plein", libelle = chiffres, court = chiffres, contient = function(n) return n == numero end }
  end
  return EXTERIEURES[cle]
end

--- Gain total (mises comprises) des `mises` { [cle] = montant } quand `numero` sort. Une clé inconnue lève une erreur.
function roulette.gain(mises, numero)
  local total = 0
  for cle, montant in pairs(mises) do
    local case = roulette.case(cle)
    if not case then error("case inconnue : " .. tostring(cle), 2) end
    if case.contient(numero) then total = total + montant * roulette.RETOURS[case.genre] end
  end
  return total
end

--- Somme des `mises`.
function roulette.total(mises)
  local total = 0
  for _, montant in pairs(mises) do total = total + montant end
  return total
end

--- Tire le numéro sorti avec `hasard(n)`, entier uniforme de 1 à n.
function roulette.tirer(hasard)
  return hasard(#roulette.ROUE) - 1
end

--- Indice (à partir de 0) du numéro sur la roue.
function roulette.indice(numero)
  for i, valeur in ipairs(roulette.ROUE) do
    if valeur == numero then return i - 1 end
  end
  error("numéro hors roue : " .. tostring(numero), 2)
end

--- Taux de retour au joueur exact d'un jeton posé sur la case `cle`, par énumération des 37 numéros.
function roulette.retour(cle)
  local somme = 0
  for _, numero in ipairs(roulette.ROUE) do somme = somme + roulette.gain({ [cle] = 1 }, numero) end
  return somme / #roulette.ROUE
end

--- Règles affichables : intro, entrées ({ texte }), pied.
function roulette.regles()
  local r = roulette.RETOURS
  return {
    intro = { "Pose tes jetons sur le tapis, puis LANCER.", "Le 0 fait perdre toutes les autres mises." },
    entrees = {
      { texte = "Plein (un numéro) : x" .. r.plein }, { texte = "Douzaine : x" .. r.douzaine },
      { texte = "Colonne (2:1) : x" .. r.colonne }, { texte = "Rouge ou noir : x" .. r.simple },
      { texte = "Pair ou impair : x" .. r.simple }, { texte = "1-18 ou 19-36 : x" .. r.simple },
    },
    pied = { "Gain = jeton x multiplicateur, mise comprise.",
      (string.format("Retour au joueur : %.1f %% sur toute case.", 100 * roulette.retour("rouge")):gsub("%.", ",", 1)) },
  }
end

return roulette
