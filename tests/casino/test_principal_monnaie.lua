-- Bout en bout en vraie monnaie : dépôt relevé par minuterie, une partie, encaissement au toucher, inventaire manquant.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local faux_moniteur = require("faux.moniteur")
local coffre = require("faux.coffre")
local faux_lc = require("faux.lc_money")
local machine = require("casino.jeux.machine")
local monnaie = require("casino.monnaie")

local CUIVRE, FER, OR, EMERAUDE = "lightmanscurrency:coin_copper", "lightmanscurrency:coin_iron",
  "lightmanscurrency:coin_gold", "lightmanscurrency:coin_emerald"
local VALEURS = { [CUIVRE] = 1, [FER] = 10, [OR] = 100, [EMERAUDE] = 1000 }

local SEPT
for i, nom in ipairs(machine.BANDE) do
  if nom == "sept" and not SEPT then SEPT = i end
end

-- Monde : config en mode monnaie (réserve nommée `nom_reserve`), trois coffres, moniteur 51x19, faux lc_money.
local function lancer(nom_reserve)
  local m = { horloge = 0, minuteurs = {}, numero = 0, disque = systeme.installer(), reseau = coffre.reseau() }
  m.disque.disque["casino.cfg"] = textutils.serialize({ mode = "monnaie", depot = "minecraft:chest_0",
    sortie = "minecraft:chest_1", reserve = nom_reserve or "minecraft:chest_2", periode_image = 0.25 })
  m.depot = coffre.nouveau(m.reseau, "minecraft:chest_0", 27)
  m.sortie = coffre.nouveau(m.reseau, "minecraft:chest_1", 27)
  m.reserve = coffre.nouveau(m.reseau, "minecraft:chest_2", 54, { [1] = { name = EMERAUDE, count = 10 },
    [2] = { name = OR, count = 20 }, [3] = { name = FER, count = 50 }, [4] = { name = CUIVRE, count = 64 } })
  m.moniteur = faux_moniteur.nouveau(51, 19)
  m.moniteur.setTextScale = function() end
  peripheral = {
    find = function(genre) if genre == "monitor" then return m.moniteur end end,
    wrap = function(nom) return m.reseau.inventaires[nom] end,
    getNames = function()
      local noms = {}
      for nom in pairs(m.reseau.inventaires) do noms[#noms + 1] = nom end
      return noms
    end,
    getType = function() return "minecraft:chest" end,
  }
  lc_money = faux_lc.nouveau(VALEURS)
  term = { current = function() return faux_moniteur.nouveau(51, 19) end }
  os.clock = function() return m.horloge end
  os.startTimer = function(delai)
    m.numero = m.numero + 1
    m.minuteurs[m.numero] = m.horloge + delai
    return m.numero
  end
  os.cancelTimer = function(id) m.minuteurs[id] = nil end
  os.pullEventRaw = function() return coroutine.yield() end
  math.random = function() return SEPT end
  local co = coroutine.create(function() assert(loadfile("projets/casino/principal.lua"))() end)
  function m.envoyer(...)
    local ok, erreur = coroutine.resume(co, ...)
    if not ok then error(erreur, 0) end
  end
  function m.attendre(secondes)
    local fin = m.horloge + secondes
    while true do
      local id, quand
      for numero, instant in pairs(m.minuteurs) do
        if not quand or instant < quand then id, quand = numero, instant end
      end
      if not id or quand > fin then break end
      m.minuteurs[id] = nil
      m.horloge = math.max(m.horloge, quand)
      m.envoyer("timer", id)
    end
    m.horloge = fin
  end
  function m.toucher(motif)
    for y = 19, 1, -1 do
      local x = m.moniteur.ligne(y):find(motif, 1, true)
      if x then return m.envoyer("monitor_touch", "top", x + 1, y) end
    end
    error("introuvable à l'écran : " .. motif .. "\n" .. m.moniteur.texte())
  end
  function m.credits()
    return textutils.unserialize(m.disque.disque["casino.credits"]).solde
  end
  function m.valeur_totale()
    local total = 0
    for _, c in ipairs({ m.depot, m.sortie, m.reserve }) do total = total + monnaie.valeur(c.emplacements, VALEURS) end
    return total
  end
  m.envoyer()
  return m
end

return {
  depot_partie_et_encaissement_au_toucher = function()
    local m = lancer()
    verif.vrai(m.moniteur.chercher("Max"), m.moniteur.texte())
    m.depot.ranger(OR, 2)
    local total = m.valeur_totale()
    m.attendre(1.5)
    verif.egal(m.credits(), 200)
    verif.vrai(m.moniteur.chercher("Cr\233dits 200"), m.moniteur.texte())
    m.toucher("Machine")
    m.toucher("JOUER")
    m.attendre(4)
    verif.egal(m.credits(), 190 + 1000)
    m.toucher("Hall")
    m.toucher("Encaisser")
    verif.egal(m.credits(), 0)
    verif.egal({ m.sortie.compter(EMERAUDE), m.sortie.compter(OR), m.sortie.compter(FER) }, { 1, 1, 9 })
    verif.egal(m.valeur_totale(), total, "aucune pièce créée ni détruite")
    local journal = m.disque.disque["casino.log"]
    for _, motif in ipairs({ "Dépôt : 2 x " .. OR, "Caisse : miser(10", "Encaissement demandé : 1190" }) do
      verif.vrai(journal:find(motif, 1, true), motif .. "\n" .. journal)
    end
    verif.egal(m.disque.disque["casino.jetons"], nil, "les jetons fictifs ont leur propre fichier")
  end,

  reserve_introuvable_bloque_les_jeux_et_le_dit = function()
    local m = lancer("minecraft:chest_9")
    verif.vrai(m.moniteur.chercher("Casino ferm"), m.moniteur.texte())
    verif.vrai(m.moniteur.chercher("minecraft:chest_9"), m.moniteur.texte())
    verif.egal(m.moniteur.chercher("Machine"), nil, "aucune tuile de jeu tant que la banque manque")
    m.depot.ranger(OR, 1)
    m.attendre(2)
    verif.egal(m.depot.compter(OR), 1, "rien n'est pris tant que la banque est suspendue")
    m.reseau.inventaires["minecraft:chest_9"] = m.reserve
    m.attendre(2)
    verif.egal(m.credits(), 100)
  end,
}
