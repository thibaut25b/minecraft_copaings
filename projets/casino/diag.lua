-- Diagnostic à lancer à la main (/casino/diag) : périphériques visibles, lc_money, contenu et valeur des trois
-- inventaires réglés, SANS RIEN DÉPLACER ; détail complet dans /casino-diag.txt.

package.path = "/?.lua;" .. package.path
local config = require("commun.config")
local peripheriques = require("commun.peripheriques")
local vers_cc = require("commun.texte").vers_cc
local defauts = require("casino.reglages")

local FICHIER = "/casino-diag.txt"
local CHEMIN_CONFIG = "/casino.cfg"
local INVENTAIRES = { { cle = "depot", titre = "Coffre de dépôt" }, { cle = "sortie", titre = "Coffre de sortie" },
  { cle = "reserve", titre = "Réserve" } }

local reglages = config.charger(CHEMIN_CONFIG, defauts)
local rapport = { peripheriques = peripheriques.visibles(), pieces = {}, inventaires = {} }
local lignes = { "Périphériques visibles : " .. #rapport.peripheriques }
for _, nom in ipairs(rapport.peripheriques) do lignes[#lignes + 1] = "  " .. nom end

-- Lecture protégée de lc_money : le retour brut est gardé tel quel pour constater sa forme.
local function lire_valeur(objets)
  if type(lc_money) ~= "table" then return false, "lc_money absent" end
  return pcall(lc_money.readInventoryValues, objets)
end

rapport.lc_money = type(lc_money) == "table"
lignes[#lignes + 1] = "lc_money : " .. (rapport.lc_money and "présent" or "ABSENT")
for _, piece in ipairs(reglages.pieces) do
  local ok, valeur = lire_valeur({ { name = piece.id, count = 1 } })
  rapport.pieces[piece.id] = { ok = ok, retour = valeur }
  local entree = ok and type(valeur) == "table" and valeur[reglages.type_monnaie]
  lignes[#lignes + 1] = "  1 " .. piece.nom .. " : "
    .. (type(entree) == "table" and tostring(entree.numeric) or (ok and "pas de type " .. reglages.type_monnaie
      or tostring(valeur)))
end

for _, role in ipairs(INVENTAIRES) do
  local nom = reglages[role.cle]
  local objet = peripheriques.par_nom(nom)
  local partie = { nom = nom, present = objet ~= nil }
  if objet then
    local ok_liste, contenu = peripheriques.appel(objet, "list")
    local ok_taille, taille = peripheriques.appel(objet, "size")
    partie.contenu, partie.taille = ok_liste and contenu or tostring(contenu), ok_taille and taille or nil
    local valeur_ok, valeur = false, nil
    if ok_liste then valeur_ok, valeur = lire_valeur(contenu) end
    partie.valeur = valeur
    local piles = 0
    if ok_liste then for _ in pairs(contenu) do piles = piles + 1 end end
    local entree = valeur_ok and type(valeur) == "table" and valeur[reglages.type_monnaie]
    lignes[#lignes + 1] = string.format("%s « %s » : %d piles sur %s, valeur %s", role.titre, nom, piles,
      tostring(partie.taille), type(entree) == "table" and tostring(entree.numeric) or "?")
  else
    lignes[#lignes + 1] = role.titre .. " « " .. nom .. " » : INTROUVABLE"
  end
  rapport.inventaires[role.cle] = partie
end

lignes[#lignes + 1] = "Les trois coffres doivent être sur le même réseau filaire et réglés par leur nom réseau "
  .. "(pas un côté) : la réserve envoie vers la sortie par ce nom, ce que ce diagnostic ne peut pas tester."
for _, ligne in ipairs(lignes) do print(vers_cc(ligne)) end
local fichier = fs.open(FICHIER, "w")
if fichier then
  fichier.write(textutils.serialize(rapport))
  fichier.close()
  print(vers_cc("Détail : " .. FICHIER))
else
  print(vers_cc("Écriture impossible : " .. FICHIER))
end
