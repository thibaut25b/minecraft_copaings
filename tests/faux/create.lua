-- Faux périphériques Create fidèles à docs/create.md : Stock Ticker, stressomètre, speedomètre, relais redstone.
-- Champ commun `panne` (texte) : toute méthode lève ce message.

local create = {}

local function garde(objet)
  if objet.panne then error(objet.panne, 3) end
end

--- Stock Ticker. Le test pilote `stock` ({ [identifiant] = quantité }) et lit `commandes` ({ adresse, objet,
--- nombre }). `a_la_commande(commande)`, s'il existe, est appelé après chaque commande (pour simuler la livraison).
function create.ticker(stock)
  local t = { stock_reseau = stock or {}, commandes = {} }

  function t.stock()
    garde(t)
    local noms = {}
    for nom in pairs(t.stock_reseau) do noms[#noms + 1] = nom end
    table.sort(noms)
    local liste = {}
    for i, nom in ipairs(noms) do liste[i] = { name = nom, count = t.stock_reseau[nom] } end
    return liste
  end

  -- Comme la référence : le total mis en commande, borné par le stock ; le stock quitte le réseau.
  function t.requestFiltered(adresse, ...)
    garde(t)
    local total = 0
    for _, filtre in ipairs({ ... }) do
      if type(filtre) ~= "table" then error("Filter must be a table", 2) end
      local limite = filtre._requestCount
      if limite ~= nil and (type(limite) ~= "number" or limite < 1) then
        error("_requestCount must be a positive number or nil for no limit", 2)
      end
      local pris = math.min(t.stock_reseau[filtre.name] or 0, limite or math.huge)
      if pris > 0 then
        t.stock_reseau[filtre.name] = t.stock_reseau[filtre.name] - pris
        local commande = { adresse = adresse, objet = filtre.name, nombre = pris }
        t.commandes[#t.commandes + 1] = commande
        if t.a_la_commande then t.a_la_commande(commande) end
      end
      total = total + pris
    end
    return total
  end

  return t
end

--- Stressomètre : le test règle `stress` et `capacite`.
function create.stressometre(stress, capacite)
  local s = { stress = stress or 0, capacite = capacite or 0 }
  function s.getStress()
    garde(s)
    return s.stress
  end
  function s.getStressCapacity()
    garde(s)
    return s.capacite
  end
  return s
end

--- Speedomètre : le test règle `vitesse` (RPM signé).
function create.speedometre(vitesse)
  local s = { vitesse = vitesse or 0 }
  function s.getSpeed()
    garde(s)
    return s.vitesse
  end
  return s
end

local COTES = { top = true, bottom = true, left = true, right = true, front = true, back = true }

--- Relais redstone de CC : `sorties` ({ [côté] = booléen }) garde le dernier ordre, `ordres` compte les setOutput.
function create.relais()
  local r = { sorties = {}, ordres = 0 }
  function r.setOutput(cote, actif)
    garde(r)
    if not COTES[cote] then error("Invalid side", 2) end
    r.sorties[cote] = actif == true
    r.ordres = r.ordres + 1
  end
  function r.getOutput(cote)
    garde(r)
    if not COTES[cote] then error("Invalid side", 2) end
    return r.sorties[cote] == true
  end
  return r
end

return create
