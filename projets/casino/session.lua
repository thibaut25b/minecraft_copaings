-- État du casino et ses transitions (écrans, mises, tours) : aucune entrée ni sortie, caisse et hasard injectés.

local machine = require("casino.jeux.machine")
local roulette = require("casino.jeux.roulette")
local crash = require("casino.jeux.crash")
local blackjack = require("casino.jeux.blackjack")

local texte = require("commun.texte")
local monnaie = require("casino.monnaie")

local session = {}

--- Secondes après le départ où s'arrête chaque rouleau de la machine.
session.ARRETS_MACHINE = { 1.1, 1.6, 2.1 }
--- Durée du lancer de roulette et nombre de tours complets du bandeau.
session.DUREE_ROULETTE = 4.5
session.TOURS_ROULETTE = 3
--- Tours complets de bande ajoutés par rouleau (le rouleau i fait i + TOURS_MACHINE tours).
session.TOURS_MACHINE = 1
--- Durées d'affichage : bouton enfoncé, message, fête après un gain.
session.DUREE_APPUI = 0.15
session.DUREE_MESSAGE = 4
session.DUREE_FETE = 2
--- Blackjack : écart entre deux cartes distribuées, durée du glissement d'une carte (secondes).
session.PAS_CARTE = 0.45
session.GLISSE_CARTE = 0.25
--- Nombre de résultats gardés dans l'historique d'un jeu.
session.HISTORIQUE = 12

--- Paliers de mise de `min` à `max` : les bornes et les 1, 2, 5 x 10^k entre les deux, croissants.
function session.paliers(min, max)
  local liste, vus = {}, {}
  local function ajouter(valeur)
    if valeur >= min and valeur <= max and not vus[valeur] then
      vus[valeur] = true
      liste[#liste + 1] = valeur
    end
  end
  ajouter(min)
  local puissance = 1
  while puissance <= max do
    for _, facteur in ipairs({ 1, 2, 5 }) do ajouter(facteur * puissance) end
    puissance = puissance * 10
  end
  ajouter(max)
  table.sort(liste)
  return liste
end

--- Remet aux défauts les réglages de mauvais type ou hors bornes ; renvoie la liste des messages.
function session.corriger(reglages, defauts, themes)
  local messages = {}
  local function remettre(cle, raison)
    messages[#messages + 1] = "Config : " .. cle .. " " .. raison .. ", " .. tostring(defauts[cle]) .. " utilisé"
    reglages[cle] = defauts[cle]
  end
  for cle, defaut in pairs(defauts) do
    if type(reglages[cle]) ~= type(defaut) then remettre(cle, "invalide") end
  end
  for _, cle in ipairs({ "mise_min", "mise_max", "mise_defaut", "jetons_depart", "recharge", "jeux_blackjack",
    "mise_min_monnaie", "mise_max_monnaie", "mise_defaut_monnaie" }) do
    local valeur = reglages[cle]
    if valeur ~= math.floor(valeur) or valeur < 1 then remettre(cle, "doit être un entier positif") end
  end
  if reglages.mode ~= "demo" and reglages.mode ~= "monnaie" then remettre("mode", "doit valoir demo ou monnaie") end
  for _, piece in ipairs(reglages.pieces) do
    if type(piece) ~= "table" or type(piece.id) ~= "string" or type(piece.nom) ~= "string" then
      remettre("pieces", "doit lister des { id, nom }")
      break
    end
  end
  if reglages.mise_max_monnaie < reglages.mise_min_monnaie then
    remettre("mise_min_monnaie", "dépasse mise_max_monnaie")
    remettre("mise_max_monnaie", "est sous mise_min_monnaie")
  end
  for _, cle in ipairs({ "inactivite", "periode_image", "periode_depot", "periode_valeurs" }) do
    if reglages[cle] <= 0 then remettre(cle, "doit être positif") end
  end
  if reglages.mise_max < reglages.mise_min then
    remettre("mise_min", "dépasse mise_max")
    if reglages.mise_max < reglages.mise_min then remettre("mise_max", "est sous mise_min") end
  end
  if reglages.volume < 0 or reglages.volume > 3 then remettre("volume", "hors de 0 à 3") end
  if reglages.echelle_texte < 0.5 or reglages.echelle_texte > 5 then remettre("echelle_texte", "hors de 0.5 à 5") end
  local connu = false
  for _, nom in ipairs(themes) do connu = connu or nom == reglages.theme end
  if not connu then remettre("theme", "inconnu") end
  return messages
end

--- Position d'une animation qui ralentit : de `depart` à `depart + distance` en `duree` secondes, après `ecoule`.
function session.position(depart, distance, duree, ecoule)
  local part = math.max(0, math.min(1, ecoule / duree))
  return depart + distance * (1 - (1 - part) ^ 3)
end

--- Nouvelle session : hall, mise de départ (le plus grand palier sous `mise_defaut`), rien en cours. `solde` vient
--- de la caisse.
function session.nouvelle(reglages, solde)
  local paliers = session.paliers(reglages.mise_min, reglages.mise_max)
  local mise = paliers[1]
  for _, palier in ipairs(paliers) do
    if palier <= reglages.mise_defaut then mise = palier end
  end
  return {
    ecran = "hall", solde = solde, record = 0, paliers = paliers, mise = mise, mise_max = reglages.mise_max,
    recharge = reglages.recharge, unite = reglages.mode == "monnaie" and "crédit" or "jeton",
    jeux_blackjack = reglages.jeux_blackjack, regles = false, sons = {}, geste = 0,
    machine = { phase = "attente", arrets = { 13, 6, 9 } },
    roulette = { phase = "attente", mises = {}, historique = {}, position = 0 },
    crash = { phase = "attente", historique = {} },
    blackjack = { phase = "attente", joueur = {}, banque = {} },
  }
end

-- Gain net maximal d'un tour pour un crédit misé, par jeu (une mise pleine à la roulette).
local EXPOSITIONS = {
  machine = machine.exposition(1), roulette = roulette.exposition({ n0 = 1 }), crash = crash.exposition(1),
  blackjack = blackjack.exposition(1),
}

--- En vraie monnaie (`etat.monnaie` = { pret, probleme, reserve, ... }), plus grande mise que la réserve couvre,
--- par jeu ; nil avec les jetons fictifs.
function session.mises_max(etat)
  if not etat.monnaie then return nil end
  local plafonds = {}
  for jeu, exposition in pairs(EXPOSITIONS) do
    plafonds[jeu] = etat.monnaie.pret and monnaie.mise_max(etat.monnaie.reserve, etat.solde, exposition) or 0
  end
  return plafonds
end

--- Vrai si un tour est en train de se jouer.
function session.en_cours(etat)
  local phase = etat.blackjack.phase
  return etat.machine.phase == "tourne" or etat.roulette.phase == "tourne" or etat.crash.phase == "monte"
    or phase == "anime" or phase == "joueur"
end

--- Affiche `texte` quelques secondes ; `ton` : "bon", "mauvais" ou "info".
function session.avertir(etat, texte, ton, maintenant)
  etat.message = { texte = texte, ton = ton, fin = maintenant + session.DUREE_MESSAGE }
end

--- Sons demandés depuis le dernier appel, dans l'ordre ; la liste est vidée.
function session.vider_sons(etat)
  local sons = etat.sons
  etat.sons = {}
  return sons
end

local function sonner(etat, nom)
  etat.sons[#etat.sons + 1] = nom
end

local function refuser(etat, raison, maintenant)
  session.avertir(etat, raison, "mauvais", maintenant)
  sonner(etat, "refus")
end

local function noter(historique, valeur)
  table.insert(historique, 1, valeur)
  historique[session.HISTORIQUE + 1] = nil
end

-- Mise du jeu courant : `exposition` est le gain net maximal du tour, contrôlé par la caisse en vraie monnaie.
local function miser(etat, contexte, montant, gain_prevu, exposition)
  local ok, raison = contexte.caisse.miser(montant, gain_prevu, exposition)
  etat.solde = contexte.caisse.solde()
  if not ok then
    local plafonds = session.mises_max(etat)
    if plafonds and montant <= etat.solde then
      raison = raison .. " Mise max : " .. texte.milliers(plafonds[etat.ecran]) .. "."
    end
    refuser(etat, raison, contexte.maintenant)
    return false
  end
  etat.message = nil
  sonner(etat, "mise")
  return true
end

local function regler(etat, contexte, jeu, gain)
  local ok, raison = contexte.caisse.regler(gain)
  etat.solde = contexte.caisse.solde()
  if not ok then refuser(etat, raison, contexte.maintenant) end
  jeu.resultat = { mise = jeu.mise, gain = gain }
  etat.geste = contexte.maintenant
  if gain > etat.record then etat.record = gain end
  jeu.fete = gain > jeu.mise and contexte.maintenant + session.DUREE_FETE or nil
  sonner(etat, gain >= jeu.mise and "gain" or "perte")
end

-- Machine à sous ---------------------------------------------------------------------------------------------------

local function jouer_machine(etat, contexte)
  local jeu = etat.machine
  local arrets = machine.tirer(contexte.hasard)
  local gain = machine.gain(arrets, etat.mise)
  if not miser(etat, contexte, etat.mise, gain, machine.exposition(etat.mise)) then return end
  local taille = #machine.BANDE
  jeu.depart, jeu.distance = {}, {}
  for i = 1, 3 do
    jeu.depart[i] = jeu.arrets[i]
    jeu.distance[i] = (arrets[i] - jeu.arrets[i]) % taille + taille * (i + session.TOURS_MACHINE)
  end
  jeu.phase, jeu.debut, jeu.cible, jeu.mise, jeu.gain = "tourne", contexte.maintenant, arrets, etat.mise, gain
  jeu.arretes, jeu.resultat, jeu.combinaison, jeu.fete = 0, nil, nil, nil
end

local function avancer_machine(etat, contexte)
  local jeu = etat.machine
  if jeu.phase ~= "tourne" then return end
  local ecoule = contexte.maintenant - jeu.debut
  while jeu.arretes < 3 and ecoule >= session.ARRETS_MACHINE[jeu.arretes + 1] do
    jeu.arretes = jeu.arretes + 1
    sonner(etat, "rouleau")
  end
  if jeu.arretes < 3 then return end
  jeu.arrets, jeu.phase, jeu.combinaison = jeu.cible, "fini", machine.combinaison(jeu.cible)
  regler(etat, contexte, jeu, jeu.gain)
end

-- Roulette ---------------------------------------------------------------------------------------------------------

local function poser_jeton(etat, contexte, cle)
  local jeu = etat.roulette
  if jeu.phase == "tourne" then return end
  if roulette.case(cle) == nil then error("case inconnue : " .. tostring(cle), 2) end
  if roulette.total(jeu.mises) + etat.mise > etat.solde then
    return refuser(etat, "Solde insuffisant pour un jeton de plus.", contexte.maintenant)
  end
  if (jeu.mises[cle] or 0) + etat.mise > etat.mise_max then
    return refuser(etat, "Mise maximale par case : " .. texte.quantite(etat.mise_max, etat.unite) .. ".", contexte.maintenant)
  end
  jeu.mises[cle] = (jeu.mises[cle] or 0) + etat.mise
  jeu.phase, jeu.fete = "attente", nil
  sonner(etat, "mise")
end

local function jouer_roulette(etat, contexte)
  local jeu = etat.roulette
  local total = roulette.total(jeu.mises)
  if total == 0 then return refuser(etat, "Pose d'abord des jetons sur le tapis.", contexte.maintenant) end
  local numero = roulette.tirer(contexte.hasard)
  local gain = roulette.gain(jeu.mises, numero)
  if not miser(etat, contexte, total, gain, roulette.exposition(jeu.mises)) then return end
  local taille = #roulette.ROUE
  jeu.depart = jeu.position
  jeu.distance = (roulette.indice(numero) - jeu.position) % taille + taille * session.TOURS_ROULETTE
  jeu.phase, jeu.debut, jeu.numero, jeu.mise, jeu.gain = "tourne", contexte.maintenant, numero, total, gain
  jeu.resultat, jeu.fete = nil, nil
end

local function avancer_roulette(etat, contexte)
  local jeu = etat.roulette
  if jeu.phase ~= "tourne" or contexte.maintenant - jeu.debut < session.DUREE_ROULETTE then return end
  jeu.position, jeu.phase = roulette.indice(jeu.numero), "fini"
  noter(jeu.historique, jeu.numero)
  regler(etat, contexte, jeu, jeu.gain)
end

-- Crash ------------------------------------------------------------------------------------------------------------

local function jouer_crash(etat, contexte)
  local jeu = etat.crash
  local point = crash.point(contexte.hasard)
  if not miser(etat, contexte, etat.mise, crash.gain_sans_geste(etat.mise, point), crash.exposition(etat.mise)) then
    return
  end
  jeu.phase, jeu.debut, jeu.point, jeu.mise = "monte", contexte.maintenant, point, etat.mise
  jeu.atteint, jeu.resultat, jeu.fete = nil, nil, nil
end

local function finir_crash(etat, contexte, phase, atteint, gain)
  local jeu = etat.crash
  jeu.phase, jeu.atteint = phase, atteint
  noter(jeu.historique, jeu.point)
  if phase == "explose" then sonner(etat, "explosion") end
  regler(etat, contexte, jeu, gain)
end

local function avancer_crash(etat, contexte)
  local jeu = etat.crash
  if jeu.phase ~= "monte" then return end
  local atteint = crash.multiplicateur(contexte.maintenant - jeu.debut)
  if crash.gagne(atteint, jeu.point) then return end
  if jeu.point >= crash.PLAFOND then
    finir_crash(etat, contexte, "encaisse", crash.PLAFOND, crash.gain(jeu.mise, crash.PLAFOND))
  else
    finir_crash(etat, contexte, "explose", jeu.point, 0)
  end
end

local function encaisser(etat, contexte)
  avancer_crash(etat, contexte)
  local jeu = etat.crash
  if jeu.phase ~= "monte" then return end
  local atteint = crash.multiplicateur(contexte.maintenant - jeu.debut)
  finir_crash(etat, contexte, "encaisse", atteint, crash.gain(jeu.mise, atteint))
end

-- Blackjack --------------------------------------------------------------------------------------------------------
-- Les cartes portent leur `instant` d'apparition ; `fin` est la fin de l'animation, `suite` la phase qui suit.

local function poser(main, carte, instant)
  carte.instant = instant
  main[#main + 1] = carte
end

-- La banque retourne sa carte cachée à `debut` puis tire selon sa règle ; la main se règle ensuite.
local function jouer_banque(jeu, debut)
  jeu.revele = debut
  local instant = debut + session.PAS_CARTE
  for _ = 1, #blackjack.tirage_banque(jeu.banque, jeu.sabot) do
    poser(jeu.banque, blackjack.tirer(jeu.sabot), instant)
    instant = instant + session.PAS_CARTE
  end
  jeu.phase, jeu.fin, jeu.suite = "anime", instant, "fini"
end

-- Après une carte du joueur : dépassement (main perdue), 21 ou doublement (la banque joue), sinon il rejoue.
local function apres_carte(jeu, maintenant, double)
  local debut = maintenant + session.GLISSE_CARTE
  local total = blackjack.valeur(jeu.joueur)
  if total > 21 then
    jeu.revele, jeu.phase, jeu.fin, jeu.suite = debut, "anime", debut + session.PAS_CARTE, "fini"
  elseif double or total == 21 then
    jouer_banque(jeu, debut)
  else
    jeu.phase, jeu.fin, jeu.suite = "anime", debut, "joueur"
  end
end

local function jouer_blackjack(etat, contexte)
  local jeu, maintenant = etat.blackjack, contexte.maintenant
  local remelange = not jeu.sabot or blackjack.a_remelanger(jeu.sabot)
  if remelange then jeu.sabot = blackjack.sabot(etat.jeux_blackjack, contexte.hasard) end
  local sabot = jeu.sabot
  local depart = sabot.position
  local cartes = {}
  for i = 1, 4 do cartes[i] = blackjack.tirer(sabot) end
  local joueur, banque = { cartes[1], cartes[3] }, { cartes[2], cartes[4] }
  if not miser(etat, contexte, etat.mise, blackjack.gain_si_reste(joueur, banque, sabot, etat.mise),
    blackjack.exposition(etat.mise)) then
    sabot.position = depart
    return
  end
  if remelange then session.avertir(etat, "Sabot remélangé.", "info", maintenant) end
  jeu.joueur, jeu.banque, jeu.mise, jeu.double = {}, {}, etat.mise, false
  jeu.resultat, jeu.issue, jeu.revele, jeu.fete = nil, nil, nil, nil
  for i, carte in ipairs(cartes) do
    poser(i % 2 == 1 and jeu.joueur or jeu.banque, carte, maintenant + (i - 1) * session.PAS_CARTE)
  end
  local fin = maintenant + 3 * session.PAS_CARTE + session.GLISSE_CARTE
  if blackjack.naturel(joueur) or blackjack.naturel(banque) then
    jeu.revele, jeu.phase, jeu.fin, jeu.suite = fin, "anime", fin + session.PAS_CARTE, "fini"
  else
    jeu.phase, jeu.fin, jeu.suite = "anime", fin, "joueur"
  end
end

-- Une carte de plus pour le joueur ; le gain prévu de la caisse devient celui du joueur qui resterait ensuite.
local function tirer_carte(etat, contexte)
  local jeu = etat.blackjack
  if jeu.phase ~= "joueur" then return end
  poser(jeu.joueur, blackjack.tirer(jeu.sabot), contexte.maintenant)
  local ok, raison = contexte.caisse.modifier(0, blackjack.gain_si_reste(jeu.joueur, jeu.banque, jeu.sabot, jeu.mise))
  if not ok then refuser(etat, raison, contexte.maintenant) end
  sonner(etat, "carte")
  apres_carte(jeu, contexte.maintenant, false)
end

local function rester(etat, contexte)
  local jeu = etat.blackjack
  if jeu.phase ~= "joueur" then return end
  sonner(etat, "carte")
  jouer_banque(jeu, contexte.maintenant)
end

-- Doubler : seconde mise égale à la première, une seule carte, puis la banque joue. Refusé sans assez de jetons.
local function doubler(etat, contexte)
  local jeu = etat.blackjack
  if jeu.phase ~= "joueur" or #jeu.joueur ~= 2 then return end
  local apercu = { cartes = jeu.sabot.cartes, position = jeu.sabot.position }
  local main = { jeu.joueur[1], jeu.joueur[2], blackjack.tirer(apercu) }
  local ok, raison = contexte.caisse.modifier(jeu.mise, blackjack.gain_si_reste(main, jeu.banque, apercu, 2 * jeu.mise))
  etat.solde = contexte.caisse.solde()
  if not ok then return refuser(etat, raison, contexte.maintenant) end
  jeu.mise, jeu.double = 2 * jeu.mise, true
  poser(jeu.joueur, blackjack.tirer(jeu.sabot), contexte.maintenant)
  sonner(etat, "mise")
  apres_carte(jeu, contexte.maintenant, true)
end

-- Sans geste pendant `inactivite`, le joueur reste ; une animation finie passe à sa suite, une main finie se règle.
local function avancer_blackjack(etat, contexte)
  local jeu = etat.blackjack
  if jeu.phase == "joueur" and contexte.maintenant - etat.geste >= contexte.inactivite then
    rester(etat, contexte)
  end
  if jeu.phase ~= "anime" or contexte.maintenant < jeu.fin then return end
  jeu.phase = jeu.suite
  if jeu.phase ~= "fini" then return end
  local gain, issue = blackjack.regler(jeu.joueur, jeu.banque, jeu.mise)
  jeu.issue = issue
  regler(etat, contexte, jeu, gain)
end

-- Actions ----------------------------------------------------------------------------------------------------------

local JOUER = { machine = jouer_machine, roulette = jouer_roulette, crash = jouer_crash, blackjack = jouer_blackjack }

local function changer_mise(etat, pas)
  local indice = 1
  for i, valeur in ipairs(etat.paliers) do
    if valeur <= etat.mise then indice = i end
  end
  etat.mise = etat.paliers[math.max(1, math.min(#etat.paliers, indice + pas))]
end

local function recharger(etat, contexte)
  local ok, resultat = contexte.caisse.recharger()
  etat.solde = contexte.caisse.solde()
  if not ok then return refuser(etat, resultat, contexte.maintenant) end
  session.avertir(etat, "+" .. texte.quantite(resultat, etat.unite) .. " fictifs ajoutés.", "bon", contexte.maintenant)
  sonner(etat, "gain")
end

--- Applique l'action d'un toucher ({ type, cle, ... }, voir `vues.action_touchee`). `contexte` = { caisse, hasard,
--- maintenant }. Une action interdite pendant un tour est ignorée ; une action inconnue lève une erreur.
function session.agir(etat, action, contexte)
  local maintenant = contexte.maintenant
  etat.geste = maintenant
  etat.appui = { cle = action.cle, fin = maintenant + session.DUREE_APPUI }
  local genre, libre = action.type, not session.en_cours(etat)
  if genre == "ouvrir" then
    if etat.monnaie and not etat.monnaie.pret then return refuser(etat, etat.monnaie.probleme, maintenant) end
    etat.ecran, etat.regles = action.jeu, false
  elseif genre == "hall" then
    if libre then etat.ecran, etat.regles = "hall", false end
  elseif genre == "regles" then
    if libre then etat.regles = not etat.regles end
  elseif genre == "mise" then
    if libre then changer_mise(etat, action.pas) end
  elseif genre == "recharger" then
    recharger(etat, contexte)
  elseif genre == "jouer" then
    if libre then JOUER[etat.ecran](etat, contexte) end
  elseif genre == "encaisser" then
    encaisser(etat, contexte)
  elseif genre == "case" then
    poser_jeton(etat, contexte, action.case)
  elseif genre == "tirer" then
    tirer_carte(etat, contexte)
  elseif genre == "rester" then
    rester(etat, contexte)
  elseif genre == "doubler" then
    doubler(etat, contexte)
  elseif genre == "effacer" then
    if etat.roulette.phase ~= "tourne" then etat.roulette.mises, etat.roulette.phase = {}, "attente" end
  else
    error("action inconnue : " .. tostring(genre), 2)
  end
end

--- Fait avancer le temps jusqu'à `contexte.maintenant` : fin des tours, des messages, retour au hall après
--- `contexte.inactivite` secondes sans toucher ni fin de tour (jamais pendant un tour).
function session.avancer(etat, contexte)
  local maintenant = contexte.maintenant
  avancer_machine(etat, contexte)
  avancer_roulette(etat, contexte)
  avancer_crash(etat, contexte)
  avancer_blackjack(etat, contexte)
  if etat.message and maintenant >= etat.message.fin then etat.message = nil end
  if etat.appui and maintenant >= etat.appui.fin then etat.appui = nil end
  for _, nom in ipairs({ "machine", "roulette", "crash", "blackjack" }) do
    local jeu = etat[nom]
    if jeu.fete and maintenant >= jeu.fete then jeu.fete = nil end
  end
  if etat.ecran ~= "hall" and not session.en_cours(etat) and maintenant - etat.geste >= contexte.inactivite then
    etat.ecran, etat.regles = "hall", false
  end
end

--- Vrai si l'écran bouge tout seul (tour en cours ou fête d'un gain) : il faut une image par période.
function session.anime(etat, maintenant)
  if session.en_cours(etat) and etat.blackjack.phase ~= "joueur" then return true end
  local jeu = etat[etat.ecran]
  return jeu ~= nil and jeu.fete ~= nil and maintenant < jeu.fete
end

--- Prochain instant où l'écran change sans toucher (fin d'un message, d'un appui, retour au hall), ou nil.
function session.echeance(etat, inactivite)
  local prochaine
  local function retenir(instant)
    if instant and (not prochaine or instant < prochaine) then prochaine = instant end
  end
  retenir(etat.message and etat.message.fin)
  retenir(etat.appui and etat.appui.fin)
  if etat.ecran ~= "hall" then retenir(etat.geste + inactivite) end
  return prochaine
end

return session
