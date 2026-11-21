-- Faux ME Bridge fidèle à docs/peripheriques.md : stock, fabrication, cible de livraison et pannes pilotables.

local pont_me = {}

--- Crée un faux pont et renvoie `pont, etat`. Le test pilote `etat` :
-- `stock` (nom -> quantité), `fabricables` (nom -> true), `capacite` (place libre de la cible, nil = illimitée),
-- `cibles` (cible -> true ; nil = toute cible acceptée), `connecte`, `codes` (méthode -> code renvoyé en `nil, code`),
-- `exceptions` (méthode -> message levé, ou fonction des arguments qui renvoie le message ou nil),
-- `taches` (tâches lancées, champ `etat` : "calcul", "en_cours", "fini", "annule", "erreur", "echec_calcul" ;
-- champ `debug` : texte de `getDebugMessage`),
-- `objets_illisibles` (craftItem renvoie un objet tâche sans méthodes). Il lit `appels` et `livre` (nom -> quantité).
function pont_me.creer()
  local etat = {
    stock = {}, fabricables = {}, capacite = nil, cibles = nil, connecte = true, codes = {}, exceptions = {},
    taches = {}, objets_illisibles = false, appels = {}, livre = {},
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

  local function item(nom)
    return {
      name = nom, count = etat.stock[nom] or 0, displayName = nom, maxStackSize = 64, tags = {},
      components = {}, nbt = "", isCraftable = etat.fabricables[nom] == true,
    }
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
    if (etat.stock[filtre.name] or 0) > 0 or etat.fabricables[filtre.name] then return item(filtre.name) end
    return nil
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
