-- Fourniture des requêtes par le pont ME : export vers l'inventaire de livraison et auto-craft AE2.

local peripheriques = require("commun.peripheriques")
local requetes = require("colonie.requetes")

local fourniture = {}

-- Méthodes de l'objet tâche de `craftItem` : un `true` dit que la tâche a échoué, ou qu'elle s'est arrêtée normalement.
local ECHECS_DE_TACHE = { "hasErrorOccurred", "isCalculationNotSuccessful" }
local FINS_DE_TACHE = { "isDone", "isCanceled" }
-- Nombre de passes où une requête servie peut manquer à la liste avant que sa livraison soit oubliée.
local PASSES_AVANT_OUBLI = 3

local function copier(table_source, modifs)
  local copie = {}
  for cle, valeur in pairs(table_source) do copie[cle] = valeur end
  for cle, valeur in pairs(modifs) do copie[cle] = valeur end
  return copie
end

-- "echec", "finie" ou "tourne" ; nil si l'objet tâche est illisible.
local function etat_tache(tache)
  for _, groupe in ipairs({ { ECHECS_DE_TACHE, "echec" }, { FINS_DE_TACHE, "finie" } }) do
    for _, methode in ipairs(groupe[1]) do
      local ok, valeur = peripheriques.appel(tache, methode)
      if not ok then return nil end
      if valeur == true then return groupe[2] end
    end
  end
  return "tourne"
end

local function message_d_echec(tache)
  local message = "fabrication impossible : ingrédients manquants ?"
  local ok, detail = peripheriques.appel(tache, "getDebugMessage")
  if ok and type(detail) == "string" and detail ~= "" then message = message .. " (" .. detail .. ")" end
  return message
end

local function ligne(requete, action, statut, livre, message)
  return { requete = requete, action = action, statut = statut, livre = livre, message = message }
end

--- Crée l'objet de fourniture lié au pont ME. `passer(requetes_normalisees)` renvoie les lignes de passe.
-- `avertissements` liste les problèmes de réglages (exclusions invalides, ignorées).
function fourniture.creer(pont, reglages)
  local valides, invalides = requetes.trier_motifs(reglages.exclusions)
  local regles = copier(reglages, { exclusions = valides })
  local servies = {} -- id -> { action, livre, absences } : cumul exporté pour une requête encore listée
  local taches = {}  -- nom d'item -> { objet, sursis } : tâche lancée par `craftItem`
  local echecs = {}  -- nom d'item -> { message, a_montrer } : dernière fabrication échouée
  local objet = { avertissements = {} }
  for _, motif in ipairs(invalides) do
    objet.avertissements[#objet.avertissements + 1] = "Exclusion invalide ignorée : " .. motif
  end

  local function lire_en_cours()
    local listees = {}
    local ok, liste = peripheriques.appel(pont, "getCraftingTasks")
    if ok and type(liste) == "table" then
      for _, tache in ipairs(liste) do
        if type(tache) == "table" and type(tache.resource) == "table" and tache.resource.name then
          listees[tache.resource.name] = true
        end
      end
    end
    local en_cours = {}
    for nom in pairs(listees) do en_cours[nom] = true end
    for nom, tache in pairs(taches) do
      local etat = etat_tache(tache.objet)
      if etat == "echec" then
        echecs[nom] = { message = message_d_echec(tache.objet), a_montrer = true }
        taches[nom] = nil
      elseif etat == "finie" then
        taches[nom] = nil
      elseif etat == nil and not listees[nom] then
        -- Objet illisible et tâche non listée : le calcul AE2 n'est pas listé non plus, d'où une passe de sursis.
        if tache.sursis then
          tache.sursis = false
          en_cours[nom] = true
        else
          taches[nom] = nil
        end
      else
        en_cours[nom] = true
      end
    end
    return en_cours
  end

  local function lire_stock(nom)
    local ok, item, code = peripheriques.appel(pont, "getItem", { name = nom })
    if not ok then return nil, "Stock illisible : " .. tostring(item) end
    if item == nil and code ~= nil then return nil, "Stock illisible (" .. tostring(code) .. ")" end
    if type(item) ~= "table" then return { quantite = 0, fabricable = false } end
    return { quantite = tonumber(item.count) or 0, fabricable = item.isCraftable == true }
  end

  local function livrer(requete, action, stocks, cumul)
    local ok, sorti, code = peripheriques.appel(pont, "exportItem", regles.cible_export,
      { name = action.item, count = action.quantite })
    if not ok then return ligne(requete, action, "erreur", cumul, "Export impossible : " .. tostring(sorti)) end
    if sorti == nil then return ligne(requete, action, "erreur", cumul, "Export refusé (" .. tostring(code) .. ")") end
    sorti = tonumber(sorti) or 0
    if sorti <= 0 then
      return ligne(requete, action, "erreur", cumul, "Rien n'est sorti : inventaire de livraison plein ?")
    end
    stocks[action.item].quantite = stocks[action.item].quantite - sorti
    echecs[action.item] = nil
    local total = cumul + sorti
    servies[requete.id] = { action = action, livre = total, absences = 0 }
    if total < requete.quantite_min then
      return ligne(requete, action, "partiel", total, total .. " sur " .. requete.quantite_min .. " sortis")
    end
    return ligne(requete, action, "livre", total, "")
  end

  local function lancer(nom, commande)
    local ok, tache, code = peripheriques.appel(pont, "craftItem", { name = nom, count = commande.total })
    local message
    if not ok then
      message = "Fabrication impossible : " .. tostring(tache)
    elseif tache == nil then
      message = "Fabrication refusée (" .. tostring(code) .. ")"
    else
      taches[nom] = { objet = tache, sursis = true }
      echecs[nom] = nil
      return
    end
    for _, ligne_fab in ipairs(commande.lignes) do
      ligne_fab.statut = "erreur"
      ligne_fab.message = message
    end
  end

  --- Sert les requêtes d'une passe : chaque requête voit le stock laissé par les précédentes.
  -- Une requête servie sous son minimum reprend aux passes suivantes pour le reste seulement.
  function objet.passer(liste)
    local en_cours = lire_en_cours()
    local stocks, erreurs = {}, {}
    local commandes, ordre = {}, {}
    local lignes, presentes = {}, {}

    local function stocks_de(requete)
      local vue, erreur = {}, nil
      for _, nom in ipairs(requete.candidats) do
        if stocks[nom] == nil and erreurs[nom] == nil then
          stocks[nom], erreurs[nom] = lire_stock(nom)
        end
        vue[nom] = stocks[nom]
        erreur = erreur or erreurs[nom]
      end
      return vue, erreur
    end

    local function servir(requete, cumul)
      local reste = requete
      if cumul > 0 then
        reste = copier(requete, { quantite = requete.quantite - cumul, quantite_min = requete.quantite_min - cumul })
      end
      local vue, erreur = stocks_de(requete)
      local action = requetes.decider(reste, vue, regles, en_cours)
      if action.type == "ignorer" then return ligne(requete, action, "ignore", cumul, action.raison) end
      if action.type == "livrer" then return livrer(requete, action, stocks, cumul) end
      if erreur then return ligne(requete, action, "erreur", cumul, erreur) end
      if action.type == "attendre" then return ligne(requete, action, "en_fabrication", cumul, action.raison) end
      if action.type ~= "fabriquer" then return ligne(requete, action, "manquant", cumul, action.raison) end

      local echec = echecs[action.item]
      if echec and echec.a_montrer then return ligne(requete, action, "manquant", cumul, echec.message) end
      stocks[action.item].quantite = 0 -- le stock présent revient à cette requête, la fabrication fait le reste
      local resultat = ligne(requete, action, "en_fabrication", cumul, "fabrication lancée")
      if not commandes[action.item] then
        commandes[action.item] = { total = 0, lignes = {} }
        ordre[#ordre + 1] = action.item
      end
      local commande = commandes[action.item]
      commande.total = commande.total + action.quantite
      commande.lignes[#commande.lignes + 1] = resultat
      return resultat
    end

    for _, requete in ipairs(liste) do
      presentes[requete.id] = true
      local servie = servies[requete.id]
      if servie and servie.livre >= requete.quantite_min then
        lignes[#lignes + 1] = ligne(requete, servie.action, "livre", servie.livre, "en attente du coursier")
      else
        lignes[#lignes + 1] = servir(requete, servie and servie.livre or 0)
      end
    end

    for _, nom in ipairs(ordre) do lancer(nom, commandes[nom]) end
    for _, echec in pairs(echecs) do echec.a_montrer = false end
    for id, servie in pairs(servies) do
      servie.absences = presentes[id] and 0 or servie.absences + 1
      if servie.absences > PASSES_AVANT_OUBLI then servies[id] = nil end
    end
    return lignes
  end

  return objet
end

return fourniture
