-- Écran de la roulette : bandeau de roue animé, derniers numéros, tapis tactile à plusieurs mises.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("casino.vues.base")
local roulette = require("casino.jeux.roulette")
local session = require("casino.session")

local R = theme.ROLES

local vue = { titre = "Roulette", regles = roulette.regles }

local LARGEUR_CASE_BANDE = 4
local COULEURS = { vert = R.bon, rouge = R.mauvais, noir = R.fond }
local TAPIS = R.surface
local SIMPLES = { "manque", "pair", "rouge", "noir", "impair", "passe" }

-- Hauteurs des rangées de numéros et des rangées extérieures (environ 0,6 fois moins hautes) qui tiennent dans
-- `place`, deux rangées de séparation comprises.
local function hauteurs(place)
  for numeros = 8, 2, -1 do
    local exterieures = math.max(1, math.floor(numeros * 0.6 + 0.5))
    if 3 * numeros + 2 * exterieures + 2 <= place then return numeros, exterieures end
  end
  return 1, 1
end

local function fond_case(cle)
  local case = roulette.case(cle)
  if case.genre == "plein" then return COULEURS[roulette.couleur(tonumber(case.libelle))] end
  if cle == "rouge" then return R.mauvais end
  if cle == "noir" then return R.fond end
  return R.bordure
end

--- Géométrie : bandeau, historique (grand moniteur), une zone par case du tapis, barre de boutons.
function vue.disposer(largeur, hauteur, etat)
  local jeu = etat.roulette
  local bloque = session.en_cours(etat)
  local plan = base.chrome(largeur, hauteur, base.boutons_jeu(etat, "Jeton", {
    { cle = "effacer", libelle = "Effacer", court = "X", action = { type = "effacer" },
      inactif = bloque or next(jeu.mises) == nil },
  }, { cle = "jouer", libelle = "LANCER", style = "principal", action = { type = "jouer" }, inactif = bloque }))
  local c = plan.contenu
  plan.grand = base.grand(largeur, hauteur)
  plan.bande = { x = c.x, y = c.y, largeur = c.largeur, hauteur = plan.grand and 5 or 3 }
  local y = c.y + plan.bande.hauteur
  if plan.grand then
    plan.historique = { x = c.x, y = y + 1, largeur = c.largeur }
    y = y + 3
  end
  local place = c.y + c.hauteur - y
  local h_numeros, h_exterieures = hauteurs(place)
  local pas = math.min(11, math.floor((c.largeur - 1) / 14))
  local largeur_tapis = 14 * pas + 1
  local tx = c.x + math.floor((c.largeur - largeur_tapis) / 2)
  local ty = y + math.floor((place - (3 * h_numeros + 2 * h_exterieures + 2)) / 2)
  local vide_rangee = h_numeros >= 3 and 1 or 0
  local cases = {}
  local function ajouter(cle, x, y_case, l, h, l_dessin, h_dessin)
    cases[#cases + 1] = { cle = "case_" .. cle, case = cle, x = x, y = y_case, largeur = l, hauteur = h,
      dessin_largeur = l_dessin or l - 1, dessin_hauteur = h_dessin or h, inactif = bloque,
      action = { type = "case", case = cle, cle = "case_" .. cle } }
  end
  ajouter("n0", tx, ty, pas, 3 * h_numeros, pas - 1, 3 * h_numeros - vide_rangee)
  for colonne = 1, 12 do
    for rangee = 1, 3 do
      local numero = 3 * colonne - (rangee - 1)
      ajouter(roulette.cle_numero(numero), tx + colonne * pas, ty + (rangee - 1) * h_numeros, pas, h_numeros, nil,
        h_numeros - vide_rangee)
    end
  end
  for rangee = 1, 3 do
    ajouter("c" .. (4 - rangee), tx + 13 * pas, ty + (rangee - 1) * h_numeros, pas + 1, h_numeros, pas + 1,
      h_numeros - vide_rangee)
  end
  local y_douzaines = ty + 3 * h_numeros + 1
  for douzaine = 1, 3 do
    ajouter("d" .. douzaine, tx + pas + (douzaine - 1) * 4 * pas, y_douzaines, 4 * pas, h_exterieures)
  end
  for i, cle in ipairs(SIMPLES) do
    ajouter(cle, tx + pas + (i - 1) * 2 * pas, y_douzaines + h_exterieures + 1, 2 * pas, h_exterieures)
  end
  for _, case in ipairs(cases) do plan.zones[#plan.zones + 1] = case end
  plan.tapis = { x = tx - 1, y = ty, largeur = largeur_tapis + 2, hauteur = 3 * h_numeros + 2 * h_exterieures + 2 }
  return plan
end

local function position(jeu, maintenant)
  if jeu.phase ~= "tourne" then return jeu.position end
  return session.position(jeu.depart, jeu.distance, session.DUREE_ROULETTE, maintenant - jeu.debut)
end

local function dessiner_bande(cible, zone, jeu, maintenant)
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, zone.hauteur, R.surface)
  local p = position(jeu, maintenant)
  local entier = math.floor(p)
  local centre = zone.x + math.floor(zone.largeur / 2) - 1
  local milieu = zone.y + math.floor(zone.hauteur / 2)
  local visibles = math.ceil(zone.largeur / LARGEUR_CASE_BANDE / 2) + 1
  local fini = jeu.phase == "fini"
  for k = -visibles, visibles do
    local indice = (entier + k) % #roulette.ROUE
    local numero = roulette.ROUE[indice + 1]
    local x = centre + math.floor((entier + k - p) * LARGEUR_CASE_BANDE + 0.5)
    local fond = COULEURS[roulette.couleur(numero)]
    local sortie = fini and k == 0
    if sortie then fond = R.accent end
    for y = zone.y + 1, zone.y + zone.hauteur - 2 do
      local texte = y == milieu and dessin.aligner(tostring(numero), LARGEUR_CASE_BANDE - 1, "centre") or "   "
      base.ecrire_dans(cible, zone, x, y, texte, sortie and R.fond or R.texte, fond)
    end
  end
  local repere = fini and R.accent or R.moyen
  dessin.ecrire(cible, centre, zone.y, string.rep(string.char(31), LARGEUR_CASE_BANDE - 1), repere, R.surface)
  dessin.ecrire(cible, centre, zone.y + zone.hauteur - 1, string.rep(string.char(30), LARGEUR_CASE_BANDE - 1), repere,
    R.surface)
end

local function dessiner_historique(cible, zone, jeu)
  local x = zone.x + dessin.ecrire(cible, zone.x, zone.y, "Derniers numéros : ", R.discret, R.fond)
  if #jeu.historique == 0 then
    dessin.ecrire(cible, x, zone.y, "aucun pour l'instant", R.discret, R.fond)
    return
  end
  for _, numero in ipairs(jeu.historique) do
    if x + LARGEUR_CASE_BANDE > zone.x + zone.largeur then return end
    dessin.ecrire(cible, x, zone.y, dessin.aligner(tostring(numero), LARGEUR_CASE_BANDE - 1, "centre"), R.texte,
      COULEURS[roulette.couleur(numero)])
    x = x + LARGEUR_CASE_BANDE
  end
end

local function dessiner_case(cible, zone, jeu, etat, maintenant)
  local case = roulette.case(zone.case)
  local mise = jeu.mises[zone.case]
  local gagnante = jeu.phase == "fini" and case.contient(jeu.numero)
  local fond, encre = fond_case(zone.case), R.texte
  if gagnante then fond, encre = R.accent, R.fond end
  if base.appuye(etat, zone.cle, maintenant) then fond, encre = R.texte, R.fond end
  local l, h = zone.dessin_largeur, zone.dessin_hauteur
  if mise and h == 1 and not gagnante then fond, encre = R.moyen, R.fond end
  panneaux.rectangle(cible, zone.x, zone.y, l, h, fond)
  local libelle = base.choisir(case.libelle, case.court, l)
  local y_libelle = zone.y + math.floor((h - (mise and h >= 2 and 2 or 1)) / 2)
  base.centrer(cible, zone.x, y_libelle, l, libelle, encre, fond)
  if mise and h >= 2 then
    local jeton = panneaux.milliers(mise)
    local largeur = math.min(l, #jeton + 2)
    panneaux.pastille(cible, zone.x + math.floor((l - largeur) / 2), y_libelle + 1, jeton, R.moyen, largeur, R.fond)
  end
end

local function statut(etat)
  local jeu = etat.roulette
  if jeu.phase == "tourne" then return { texte = "La bille roule...", couleur = R.discret } end
  if jeu.phase == "fini" and jeu.resultat then
    local couleur = roulette.couleur(jeu.numero)
    return base.statut_resultat(jeu.resultat, "Sorti : " .. jeu.numero .. " " .. couleur, etat.solde)
  end
  local total, cases = 0, 0
  for _, montant in pairs(jeu.mises) do
    total, cases = total + montant, cases + 1
  end
  if total == 0 then
    return { texte = "Touche le tapis pour poser un jeton de " .. panneaux.milliers(etat.mise) .. ".",
      court = "Touche le tapis pour miser.", couleur = R.discret }
  end
  return { texte = string.format("Mises : %s jetons sur %d case%s. Touche LANCER.", panneaux.milliers(total), cases,
    cases > 1 and "s" or ""), court = "Mises : " .. panneaux.milliers(total) .. ". LANCER.", couleur = R.moyen }
end

--- Dessine la roulette à l'instant `maintenant`.
function vue.dessiner(cible, plan, etat, maintenant)
  local jeu = etat.roulette
  base.bandeau(cible, plan.largeur, vue.titre, etat)
  dessiner_bande(cible, plan.bande, jeu, maintenant)
  if plan.historique then dessiner_historique(cible, plan.historique, jeu) end
  local t = plan.tapis
  panneaux.rectangle(cible, t.x, t.y, t.largeur, t.hauteur, TAPIS)
  for _, zone in ipairs(plan.zones) do
    if zone.case then dessiner_case(cible, zone, jeu, etat, maintenant) end
  end
  base.message(cible, plan, etat, statut(etat), maintenant)
end

return vue
