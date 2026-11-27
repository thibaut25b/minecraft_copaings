-- Liste des objets suivis : config puis coffre modèle, sans doublon (logique pure).

local suivi = {}

--- Entrées { objet, nom } suivies : `objets` (config, déjà validée) puis les items de `contenu` (`list()` d'un
--- inventaire : { [emplacement] = { name, count } }) dans l'ordre des emplacements. Un id déjà présent n'est pas
--- répété ; les items du coffre ont un nom vide. `contenu` nil : la config seule. Piles illisibles ignorées.
function suivi.fusionner(objets, contenu)
  local liste, vus = {}, {}
  for _, entree in ipairs(objets) do
    liste[#liste + 1] = { objet = entree.objet, nom = entree.nom }
    vus[entree.objet] = true
  end
  local emplacements = {}
  for emplacement in pairs(contenu or {}) do
    if type(emplacement) == "number" then emplacements[#emplacements + 1] = emplacement end
  end
  table.sort(emplacements)
  for _, emplacement in ipairs(emplacements) do
    local pile = contenu[emplacement]
    local id = type(pile) == "table" and pile.name or nil
    if type(id) == "string" and id ~= "" and not vus[id] then
      vus[id] = true
      liste[#liste + 1] = { objet = id, nom = "" }
    end
  end
  return liste
end

--- Retire de `table_par_objet` ({ [objet] = valeur }) les objets absents de `liste` ({ objet, nom }).
function suivi.oublier(table_par_objet, liste)
  local suivis = {}
  for _, entree in ipairs(liste) do suivis[entree.objet] = true end
  for objet in pairs(table_par_objet) do
    if not suivis[objet] then table_par_objet[objet] = nil end
  end
end

return suivi
