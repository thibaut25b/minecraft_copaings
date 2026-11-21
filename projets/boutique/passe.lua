-- Passe de la boutique sur les périphériques : lit comptoirs, tampon et réseau, règle les prix, tire et commande.
-- Tout mouvement est mesuré par le retour de pullItems, jamais supposé réussi.

local logistique = require("commun.logistique")
local peripheriques = require("commun.peripheriques")
local offres = require("boutique.offres")
local prix = require("boutique.prix")
local reassort = require("boutique.reassort")

local passe = {}

local function permission(nom_permission, id, comptoir)
  return ("donne la permission %s à computercraft#%s sur %s"):format(nom_permission, tostring(id), comptoir)
end

-- Quantités par objet d'un contenu d'inventaire ({ [emplacement] = { name, count } }).
local function compter(contenu)
  local quantites = {}
  for _, pile in pairs(contenu) do
    if type(pile) == "table" and type(pile.name) == "string" and type(pile.count) == "number" then
      quantites[pile.name] = (quantites[pile.name] or 0) + pile.count
    end
  end
  return quantites
end

--- Lit le comptoir `nom` (objet `trader`) : { nom, offres, stockage (quantités, nil si illisible), inventaire }, et
--- ses erreurs. Sans la permission openStorage, getStorage lève : le comptoir garde ses offres sans stockage.
function passe.lire_comptoir(nom, trader, id)
  local lu, erreurs = { nom = nom, offres = {} }, {}
  local liste, probleme = offres.lire(trader)
  if liste then
    lu.offres = liste
    for _, message in ipairs(probleme) do erreurs[#erreurs + 1] = nom .. " : " .. message end
  else
    erreurs[#erreurs + 1] = nom .. " : " .. probleme
  end
  local ok, inventaire = peripheriques.appel(trader, "getStorage")
  if not ok or type(inventaire) ~= "table" then
    erreurs[#erreurs + 1] = permission("openStorage", id, nom)
    return lu, erreurs
  end
  local lisible, contenu = peripheriques.appel(inventaire, "list")
  if lisible and type(contenu) == "table" then
    lu.stockage, lu.inventaire = compter(contenu), inventaire
  else
    erreurs[#erreurs + 1] = nom .. " : stockage illisible : " .. tostring(contenu)
  end
  return lu, erreurs
end

--- Contenu du tampon `nom` ({ [emplacement] = { name, count } }), ou nil et un message.
function passe.lire_tampon(nom)
  local ok, contenu = peripheriques.appel(peripheriques.par_nom(nom), "list")
  if not ok then return nil, "Tampon « " .. nom .. " » illisible : " .. tostring(contenu) end
  if type(contenu) ~= "table" then return nil, "Tampon « " .. nom .. " » illisible" end
  return contenu
end

--- Tire au plus `nombre` objets `objet` du tampon vers `inventaire`, emplacement par emplacement, en décomptant
--- `contenu` du tampon. S'arrête dès qu'un mouvement est partiel (cible pleine). Renvoie le nombre tiré et un
--- message si un appel a échoué.
function passe.tirer(inventaire, nom_tampon, contenu, objet, nombre)
  local emplacements = {}
  for emplacement, pile in pairs(contenu) do
    if type(pile) == "table" and pile.name == objet and type(pile.count) == "number" and pile.count > 0 then
      emplacements[#emplacements + 1] = emplacement
    end
  end
  table.sort(emplacements)
  local tire = 0
  for _, emplacement in ipairs(emplacements) do
    local pile = contenu[emplacement]
    local voulu = math.min(nombre - tire, pile.count)
    if voulu <= 0 then break end
    local ok, bouge = peripheriques.appel(inventaire, "pullItems", nom_tampon, emplacement, voulu)
    if not ok then return tire, tostring(bouge) end
    bouge = type(bouge) == "number" and bouge or 0
    pile.count = pile.count - bouge
    tire = tire + bouge
    if bouge < voulu then break end
  end
  return tire
end

-- Règle les prix d'un comptoir ; un refus est mémorisé dans `refus` et donne un message.
local function regler_prix(comptoir, ctx, refus, messages)
  local decision = prix.decider(comptoir.nom, comptoir.offres, ctx.reglages, ctx.memoire.refus)
  local refuse = #decision.refusees > 0
  for _, cle in ipairs(decision.refusees) do refus[cle] = ctx.memoire.refus[cle] end
  for _, a_regler in ipairs(decision.a_regler) do
    local ok, accepte = peripheriques.appel(a_regler.offre.trade, "setPrice", a_regler.valeur)
    if ok and accepte == true then
      ctx.trace.info(("Prix : %s offre %d à %d crédits"):format(comptoir.nom, a_regler.offre.indice, a_regler.prix))
    else
      refus[a_regler.cle] = { voulu = a_regler.prix, actuel = a_regler.offre.prix }
      if ok then
        refuse = true
      else
        messages[#messages + 1] = comptoir.nom .. " : setPrice : " .. tostring(accepte)
      end
    end
  end
  if refuse then messages[#messages + 1] = permission("editTrades", ctx.id, comptoir.nom) end
end

--- Une passe. `ctx` = { comptoirs = { { nom, trader } }, tampon (nom), ticker (ou nil), reglages, memoire =
--- { en_route, refus } (mise à jour), maintenant (s), id (de l'ordinateur), trace }. Renvoie { articles, erreurs =
--- { comptoirs, tampon, reseau, prix } }. Tampon illisible : aucune commande (l'arrivée ne pourrait pas se voir).
function passe.executer(ctx)
  local erreurs = { comptoirs = {}, tampon = {}, reseau = {}, prix = {} }
  local memoire = ctx.memoire
  memoire.en_route = reassort.oublier(memoire.en_route, ctx.maintenant, ctx.reglages.delai_commande)
  local lus, par_nom = {}, {}
  for _, comptoir in ipairs(ctx.comptoirs) do
    local lu, messages = passe.lire_comptoir(comptoir.nom, comptoir.trader, ctx.id)
    for _, message in ipairs(messages) do erreurs.comptoirs[#erreurs.comptoirs + 1] = message end
    lus[#lus + 1], par_nom[lu.nom] = lu, lu
  end
  local refus = {}
  for _, lu in ipairs(lus) do regler_prix(lu, ctx, refus, erreurs.prix) end
  memoire.refus = refus

  local contenu, message = passe.lire_tampon(ctx.tampon)
  if not contenu then erreurs.tampon[1] = message end
  local reseau
  if ctx.ticker then
    reseau, message = logistique.stock(ctx.ticker)
    if not reseau then erreurs.reseau[1] = "Stock Ticker : " .. message end
  end

  local plan = reassort.planifier({ comptoirs = lus, tampon = contenu and compter(contenu) or {},
    reseau = contenu and reseau or nil, en_route = memoire.en_route, reglages = ctx.reglages })
  for _, tirage in ipairs(plan.tirages) do
    local lu = par_nom[tirage.comptoir]
    local tire, panne = passe.tirer(lu.inventaire, ctx.tampon, contenu, tirage.objet, tirage.nombre)
    if panne then erreurs.tampon[#erreurs.tampon + 1] = lu.nom .. " : tirage impossible : " .. panne end
    if tire > 0 then
      reassort.deduire(memoire.en_route, tirage.objet, tire)
      lu.stockage[tirage.objet] = (lu.stockage[tirage.objet] or 0) + tire
      ctx.trace.info(("Réassort : %d x %s vers %s (%d voulus)"):format(tire, tirage.objet, lu.nom, tirage.nombre))
    end
  end
  for _, commande in ipairs(plan.commandes) do
    local nombre, raison = logistique.commander(ctx.ticker, ctx.reglages.adresse, commande.objet, commande.nombre)
    if not nombre then
      erreurs.reseau[#erreurs.reseau + 1] = "Commande de " .. commande.objet .. " : " .. raison
    elseif nombre >= 1 then
      reassort.ajouter(memoire.en_route, commande.objet, nombre, ctx.maintenant)
      ctx.trace.info(("Commande : %d x %s vers %s"):format(nombre, commande.objet, ctx.reglages.adresse))
    end
  end
  return { articles = reassort.articles(lus, reseau, memoire.en_route, ctx.reglages), erreurs = erreurs }
end

return passe
