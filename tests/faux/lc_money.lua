-- Faux de l'API globale `lc_money` de Lightman's Currency (readInventoryValues seulement), valeurs fixées par le test.

local lc_money = {}

--- API dont `valeurs` ({ [identifiant] = valeur }) peut changer en cours de test ; `type_monnaie` est la clé du
--- dictionnaire renvoyé. Champ `panne` : readInventoryValues lève ce message.
function lc_money.nouveau(valeurs, type_monnaie)
  local api = { valeurs = valeurs or {}, type_monnaie = type_monnaie or "lightmanscurrency:coins!main" }

  local function entrees(objets)
    if type(objets) ~= "table" then error("bad argument #1 (table expected)", 3) end
    if objets.name then return { objets } end
    local liste = {}
    for _, entree in pairs(objets) do liste[#liste + 1] = entree end
    return liste
  end

  --- Comme la référence : { [typeUnique] = { type, numeric, text, arg, data } } pour la monnaie présente, {} sinon.
  function api.readInventoryValues(objets)
    if api.panne then error(api.panne, 2) end
    local total, reconnu = 0, false
    for _, entree in ipairs(entrees(objets)) do
      local valeur = api.valeurs[entree.name]
      if valeur then
        reconnu = true
        total = total + valeur * (entree.count or 1)
      end
    end
    if not reconnu then return {} end
    return { [api.type_monnaie] = { type = api.type_monnaie, numeric = total, text = tostring(total),
      arg = "coin;" .. total, data = {} } }
  end

  return api
end

return lc_money
