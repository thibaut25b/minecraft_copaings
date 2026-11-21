-- État du casino et ses transitions (écrans, mises, tours) : aucune entrée ni sortie, caisse et hasard injectés.

local machine = require("casino.jeux.machine")
local roulette = require("casino.jeux.roulette")
local crash = require("casino.jeux.crash")

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
  for _, cle in ipairs({ "mise_min", "mise_max", "jetons_depart", "recharge" }) do
    local valeur = reglages[cle]
    if valeur ~= math.floor(valeur) or valeur < 1 then remettre(cle, "doit être un entier positif") end
  end
  for _, cle in ipairs({ "inactivite", "periode_image" }) do
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

--- Nouvelle session : hall, première mise, rien en cours. `solde` vient de la caisse.
function session.nouvelle(reglages, solde)
  local paliers = session.paliers(reglages.mise_min, reglages.mise_max)
  return {
    ecran = "hall", solde = solde, record = 0, paliers = paliers, mise = paliers[1], mise_max = reglages.mise_max,
    recharge = reglages.recharge, regles = false, sons = {}, geste = 0,
    machine = { phase = "attente", arrets = { 13, 6, 9 } },
    roulette = { phase = "attente", mises = {}, historique = {}, position = 0 },
    crash = { phase = "attente", historique = {} },
  }
end

--- Vrai si un tour est en train de se jouer.
function session.en_cours(etat)
  return etat.machine.phase == "tourne" or etat.roulette.phase == "tourne" or etat.crash.phase == "monte"
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

local function miser(etat, contexte, montant, gain_prevu)
  local ok, raison = contexte.caisse.miser(montant, gain_prevu)
  etat.solde = contexte.caisse.solde()
  if not ok then
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
  if not miser(etat, contexte, etat.mise, gain) then return end
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
    return refuser(etat, "Mise maximale par case : " .. etat.mise_max .. " jetons.", contexte.maintenant)
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
  if not miser(etat, contexte, total, gain) then return end
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
  if not miser(etat, contexte, etat.mise, crash.gain_sans_geste(etat.mise, point)) then return end
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

-- Actions ----------------------------------------------------------------------------------------------------------

local JOUER = { machine = jouer_machine, roulette = jouer_roulette, crash = jouer_crash }

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
  session.avertir(etat, "+" .. resultat .. " jetons fictifs ajoutés.", "bon", contexte.maintenant)
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
  if etat.message and maintenant >= etat.message.fin then etat.message = nil end
  if etat.appui and maintenant >= etat.appui.fin then etat.appui = nil end
  for _, nom in ipairs({ "machine", "roulette", "crash" }) do
    local jeu = etat[nom]
    if jeu.fete and maintenant >= jeu.fete then jeu.fete = nil end
  end
  if etat.ecran ~= "hall" and not session.en_cours(etat) and maintenant - etat.geste >= contexte.inactivite then
    etat.ecran, etat.regles = "hall", false
  end
end

--- Vrai si l'écran bouge tout seul (tour en cours ou fête d'un gain) : il faut une image par période.
function session.anime(etat, maintenant)
  if session.en_cours(etat) then return true end
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
