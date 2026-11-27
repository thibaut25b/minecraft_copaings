-- Liste des objets suivis : config puis coffre modèle, sans doublon (logique pure).

local inventaire = require("production.inventaire")

local suivi = {}

--- Entrées { objet, nbt, nom, cle } suivies : `objets` (config déjà validée : { objet, nom, nbt? }) puis les items
--- de `contenu` (`list()` d'un inventaire : { [emplacement] = { name, count, nbt? } }) dans l'ordre des
--- emplacements. Une entrée de config sans `nbt` suit toutes les variantes de son id et n'a pas de `cle` ; sinon
--- `cle` = inventaire.cle(objet, nbt) ("" = variante sans composants). Un item du coffre déjà couvert n'est pas
--- répété ; il a un nom vide et `nbt` = son nbt ou "". `contenu` nil : la config seule. Piles illisibles ignorées.
function suivi.fusionner(objets, contenu)
  local liste, cles, ids_entiers = {}, {}, {}
  for _, entree in ipairs(objets) do
    local copie = { objet = entree.objet, nom = entree.nom, nbt = entree.nbt }
    if entree.nbt == nil then
      ids_entiers[entree.objet] = true
    else
      copie.cle = inventaire.cle(entree.objet, entree.nbt)
      cles[copie.cle] = true
    end
    liste[#liste + 1] = copie
  end
  local emplacements = {}
  for emplacement in pairs(contenu or {}) do
    if type(emplacement) == "number" then emplacements[#emplacements + 1] = emplacement end
  end
  table.sort(emplacements)
  for _, emplacement in ipairs(emplacements) do
    local pile = contenu[emplacement]
    local id = type(pile) == "table" and pile.name or nil
    local nbt = type(pile) == "table" and pile.nbt or nil
    if type(id) == "string" and id ~= "" and (nbt == nil or type(nbt) == "string") and not ids_entiers[id] then
      local cle = inventaire.cle(id, nbt)
      if not cles[cle] then
        cles[cle] = true
        liste[#liste + 1] = { objet = id, nbt = nbt or "", nom = "", cle = cle }
      end
    end
  end
  return liste
end

--- Ids distincts de `liste` (entrées de `fusionner`), dans l'ordre de première apparition : à lire sur le pont.
function suivi.ids(liste)
  local ids, vus = {}, {}
  for _, entree in ipairs(liste) do
    if not vus[entree.objet] then
      vus[entree.objet] = true
      ids[#ids + 1] = entree.objet
    end
  end
  return ids
end

return suivi
