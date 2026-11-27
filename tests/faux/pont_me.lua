-- Faux ME Bridge fidèle à docs/peripheriques.md : stock, fabrication, cible de livraison et pannes pilotables.

local pont_me = {}

--- Crée un faux pont et renvoie `pont, etat`. Le test pilote `etat` :
-- `stock` (nom -> quantité), `fabricables` (nom -> true), `capacite` (place libre de la cible, nil = illimitée),
-- `cibles` (cible -> true ; nil = toute cible acceptée), `connecte`, `codes` (méthode -> code renvoyé en `nil, code`),
-- `exceptions` (méthode -> message levé, ou fonction des arguments qui renvoie le message ou nil),
-- `taches` (tâches lancées, champ `etat` : "calcul", "en_cours", "fini", "annule", "erreur", "echec_calcul" ;
-- champ `debug` : texte de `getDebugMessage`),
-- `noms` (nom -> displayName, défaut : le nom lui-même), `variantes` (nom -> liste de { nbt, count, displayName? } :
-- variantes à composants, en plus de la variante sans composants tenue par `stock`),
-- `objets_illisibles` (craftItem renvoie un objet tâche sans méthodes). Il lit `appels` et `livre` (nom -> quantité).
function pont_me.creer()
  local etat = {
    stock = {}, fabricables = {}, capacite = nil, cibles = nil, connecte = true, codes = {}, exceptions = {},
    taches = {}, noms = {}, variantes = {}, objets_illisibles = false, appels = {}, livre = {},
  }
  local pont = {}

  local function methode(nom, corps)
    pont[nom] = function(...)
      etat.appels[#etat.appels + 1] = { methode = nom, arguments = { ... } }
      local exception = etat.exceptions[nom]
      if type(exception) == "function" then exception = exception(...) end
      if exception then error(exception, 0) end
      if not etat.connecte then return nil, "NOT_CONNECTED" end
      if etat.codes[nom] then return nil, etat.codes[nom] end
      return corps(...)
    end
  end

  -- Item `nom` : la variante sans composants (champ `nbt` absent), ou `variante` ({ nbt, count, displayName? }).
  local function item(nom, variante)
    local resultat = {
      name = nom, count = etat.stock[nom] or 0, displayName = etat.noms[nom] or nom, maxStackSize = 64, tags = {},
      components = {}, isCraftable = etat.fabricables[nom] == true,
    }
    if variante then
      resultat.count, resultat.nbt = variante.count, variante.nbt
      resultat.displayName = variante.displayName or resultat.displayName
      resultat.components = { nbt = variante.nbt }
    end
    return resultat
  end

  -- Items stockés (count > 0) qui passent `filtre` ({ name?, nbtHash? }), triés par nom puis variante.
  local function stockes(filtre)
    local noms, vus = {}, {}
    for nom in pairs(etat.stock) do if not vus[nom] then vus[nom] = true; noms[#noms + 1] = nom end end
    for nom in pairs(etat.variantes) do if not vus[nom] then vus[nom] = true; noms[#noms + 1] = nom end end
    table.sort(noms)
    local liste = {}
    for _, nom in ipairs(noms) do
      if filtre.name == nil or filtre.name == nom then
        if (etat.stock[nom] or 0) > 0 and (filtre.nbtHash == nil or filtre.nbtHash == "") then
          liste[#liste + 1] = item(nom)
        end
        for _, variante in ipairs(etat.variantes[nom] or {}) do
          if variante.count > 0 and (filtre.nbtHash == nil or filtre.nbtHash == variante.nbt) then
            liste[#liste + 1] = item(nom, variante)
          end
        end
      end
    end
    return liste
  end

  local function objet_tache(tache)
    if etat.objets_illisibles then return {} end
    local function vaut(valeur) return function() return tache.etat == valeur end end
    return {
      getId = function() return tache.numero end,
      isDone = vaut("fini"),
      isCanceled = vaut("annule"),
      hasErrorOccurred = vaut("erreur"),
      isCalculationNotSuccessful = vaut("echec_calcul"),
      getDebugMessage = function() return tache.debug or "" end,
      isCraftingStarted = function() return tache.etat ~= "calcul" end,
      getRequestedItem = function() return item(tache.nom) end,
    }
  end

  methode("isConnected", function() return true end)

  methode("getItem", function(filtre)
    if type(filtre) ~= "table" or filtre.name == nil then return nil, "EMPTY_FILTER" end
    local premier = stockes(filtre)[1]
    if premier then return premier end
    if etat.fabricables[filtre.name] and (filtre.nbtHash == nil or filtre.nbtHash == "") then return item(filtre.name) end
    return nil
  end)

  methode("getItems", function(filtre)
    return stockes(type(filtre) == "table" and filtre or {})
  end)

  methode("exportItem", function(cible, filtre)
    if type(cible) ~= "string" or (etat.cibles and not etat.cibles[cible]) then return nil, "INVENTORY_NOT_FOUND" end
    filtre = filtre or {}
    local nom = filtre.name
    local voulu = filtre.count or 2147483647
    local sorti = math.min(voulu, etat.stock[nom] or 0, etat.capacite or voulu)
    if sorti <= 0 then return 0 end
    etat.stock[nom] = etat.stock[nom] - sorti
    if etat.capacite then etat.capacite = etat.capacite - sorti end
    etat.livre[nom] = (etat.livre[nom] or 0) + sorti
    return sorti
  end)

  methode("craftItem", function(filtre)
    if not etat.fabricables[filtre.name] then return nil, "NOT_CRAFTABLE" end
    local tache = { numero = #etat.taches + 1, nom = filtre.name, quantite = filtre.count or 2147483647, etat = "calcul" }
    etat.taches[#etat.taches + 1] = tache
    return objet_tache(tache)
  end)

  -- Comme AE2 : seules les tâches dont le CPU est occupé sont listées.
  methode("getCraftingTasks", function()
    local liste = {}
    for _, tache in ipairs(etat.taches) do
      if tache.etat == "en_cours" then
        liste[#liste + 1] = {
          bridgeId = tache.numero, quantity = tache.quantite, resource = item(tache.nom),
          cpu = { storage = 65536, coProcessors = 1, isBusy = true, name = "Unnamed", selectionMode = "ANY" },
          completion = 0.5, crafted = 0, id = "uuid-" .. tache.numero,
        }
      end
    end
    return liste
  end)

  return pont, etat
end

--- Appels reçus pour une méthode donnée (liste de listes d'arguments).
function pont_me.appels_de(etat, nom)
  local liste = {}
  for _, appel in ipairs(etat.appels) do
    if appel.methode == nom then liste[#liste + 1] = appel.arguments end
  end
  return liste
end

return pont_me
