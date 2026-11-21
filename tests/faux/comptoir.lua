-- Faux Item Trader de Lightman's Currency fidèle à docs/lightmans.md : offres, stockage en réseau, permissions.
-- Champ `panne` (texte) : toute méthode du comptoir et de ses offres lève ce message.

local coffre = require("faux.coffre")

local comptoir = {}

local VIDE = { name = "minecraft:air", count = 0 }

local function garde(c)
  if c.panne then error(c.panne, 3) end
end

local function monnaie(numeric)
  return { type = "lightmanscurrency:coins!main", numeric = numeric, text = numeric .. "c", data = {},
    arg = "coin;" .. numeric .. "-lightmanscurrency:coin_copper" }
end

--- Comptoir `nom` dont le stockage (`taille` emplacements, `contenu`) est un faux coffre de `reseau`, pour que
--- `pullItems` y trouve le tampon. `definitions` = { { vend = { { name, count } }, prix = crédits, achat = true
--- (offre d'achat) } }. Champs de test : `permissions` ({ openStorage, editTrades } : niveau, 0 = refus),
--- `stockage` (le faux coffre), `prix_regles` (valeurs passées à setPrice acceptées), `offres` (objets offre).
function comptoir.nouveau(reseau, nom, definitions, taille, contenu)
  local c = { nom = nom, permissions = { openStorage = 1, editTrades = 1 }, prix_regles = {}, offres = {},
    proprietaire = "Thibaut" }
  c.stockage = coffre.nouveau(reseau, nom .. "#stockage", taille or 27, contenu)

  for i, definition in ipairs(definitions or {}) do
    local offre = { prix = definition.prix or 0 }
    function offre.isValid() garde(c) return true end
    function offre.isSale() garde(c) return not definition.achat end
    function offre.isPurchase() garde(c) return definition.achat == true end
    function offre.getStock() garde(c) return definition.stock or 0 end
    function offre.getPrice() garde(c) return monnaie(offre.prix) end
    function offre.getSellItems()
      garde(c)
      local cases = {}
      for j = 1, 2 do
        local vendu = definition.vend and definition.vend[j]
        cases[j] = vendu and { name = vendu.name, count = vendu.count } or { name = VIDE.name, count = VIDE.count }
      end
      return cases
    end
    -- Comme la référence : false (sans erreur) sans la permission editTrades.
    function offre.setPrice(valeur)
      garde(c)
      if (c.permissions.editTrades or 0) <= 0 then return false end
      local nombre = tostring(valeur):match("^coin;(%d+)%-")
      if not nombre then error("Invalid money value", 2) end
      offre.prix = tonumber(nombre)
      c.prix_regles[#c.prix_regles + 1] = valeur
      return true
    end
    c.offres[i] = offre
  end

  function c.getName() garde(c) return nom end
  function c.getOwnerName() garde(c) return c.proprietaire end
  function c.tradeCount() garde(c) return #c.offres end
  function c.getMyPermissionLevel(permission) garde(c) return c.permissions[permission] or 0 end
  function c.getTrades()
    garde(c)
    local liste = {}
    for i, offre in ipairs(c.offres) do liste[i] = offre end
    return liste
  end
  -- 1-based, comme TraderPeripheral.getTrade.
  function c.getTrade(i)
    garde(c)
    if type(i) ~= "number" or i < 1 or i > #c.offres then error("Trade index out of bounds", 2) end
    return c.offres[i]
  end
  function c.getStorageStackLimit() garde(c) return 64 end
  -- Sans la permission openStorage, getStorage lève.
  function c.getStorage()
    garde(c)
    if (c.permissions.openStorage or 0) <= 0 then error("Missing permission: openStorage", 2) end
    return c.stockage
  end

  --- Paramètres de `os.pullEvent` pour un achat de l'offre `i` (1-based) par `joueur` au prix courant : l'indice
  --- de l'événement est 0-based.
  function c.evenement(i, joueur)
    return { "lc_trade", c, i - 1, c.offres[i], { Name = joueur }, monnaie(c.offres[i].prix), monnaie(0) }
  end

  return c
end

return comptoir
