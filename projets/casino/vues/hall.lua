-- Hall du casino : solde, plus gros gain de la session, une tuile par jeu, bouton de recharge.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local base = require("casino.vues.base")
local session = require("casino.session")
local symboles = require("casino.vues.symboles")
local roulette = require("casino.jeux.roulette")
local crash = require("casino.jeux.crash")

local R = theme.ROLES

local hall = { titre = "Casino" }

local COULEURS_ROUE = { vert = R.bon, rouge = R.mauvais, noir = R.fond }

-- Illustrations des tuiles, peintes dans une toile de `lpx` x `hpx` pixels.
local function art_machine(toile, lpx, hpx)
  local taille = math.min(math.floor(lpx / 3) - 2, hpx - 2)
  for i, nom in ipairs({ "sept", "cerise", "cloche" }) do
    symboles.peindre(toile, nom, lpx * (2 * i - 1) / 6 + 0.5, hpx / 2 + 0.5, taille)
  end
end

-- Petite tuile : un bandeau de numéros et la bille ; grande tuile : la roue.
local function art_roulette(toile, lpx, hpx)
  local rayon = math.floor((math.min(lpx, hpx) - 2) / 2)
  if rayon < 7 then
    local largeur_case = 3
    local depart = math.floor((lpx % largeur_case) / 2) + 1
    for i = 0, math.floor(lpx / largeur_case) - 1 do
      local numero = roulette.ROUE[i % #roulette.ROUE + 1]
      toile.rectangle(depart + i * largeur_case, 2, largeur_case - 1, hpx - 2, COULEURS_ROUE[roulette.couleur(numero)],
        true)
    end
    toile.cercle(math.floor(lpx / 2) + 1, 1, 1, R.moyen, true)
    return
  end
  local parts = {}
  for i, numero in ipairs(roulette.ROUE) do parts[i] = { 1, COULEURS_ROUE[roulette.couleur(numero)] } end
  local cx, cy = math.floor(lpx / 2) + 1, math.floor(hpx / 2) + 1
  toile.cercle(cx, cy, rayon + 1, R.moyen, true)
  graphes.secteurs(toile, cx, cy, rayon, parts)
  toile.cercle(cx, cy, math.floor(rayon * 0.55), R.bordure, true)
  toile.cercle(cx, cy, math.max(1, math.floor(rayon * 0.15)), R.moyen, true)
end

local function art_crash(toile, lpx, hpx)
  local fin = 0.82 * lpx
  local haut = crash.courbe(12)
  local rayon = math.max(1, math.floor(hpx / 10))
  local precedent
  for x = 1, math.floor(fin) do
    local valeur = crash.courbe(12 * x / fin)
    local y = hpx - 1 - (hpx - 3 - 2 * rayon) * (valeur - 1) / (haut - 1)
    toile.ligne(x, y + 1, x, hpx, R.bordure)
    if precedent then toile.ligne(x - 1, precedent, x, y, R.accent) end
    precedent = y
  end
  toile.cercle(fin, precedent, rayon, R.alerte, true)
  toile.point(fin, precedent, R.moyen)
end

-- Deux cartes en éventail : un as de coeur devant un roi de pique.
local function art_blackjack(toile, lpx, hpx)
  local h = hpx - 2
  local l = math.max(3, math.min(math.floor(h * 0.7), math.floor(lpx / 2) - 1))
  local x = math.floor((lpx - l * 1.6) / 2) + 1
  for i, encre in ipairs({ R.fond, R.mauvais }) do
    local gauche, haut = x + (i - 1) * math.floor(l * 0.6), 2 + (i - 1) * math.floor(h * 0.08)
    toile.rectangle(gauche, haut, l, h - (i - 1) * math.floor(h * 0.08), R.texte, true)
    toile.rectangle(gauche, haut, l, h - (i - 1) * math.floor(h * 0.08), R.discret, false)
    toile.cercle(gauche + l / 2, haut + h / 2, math.max(1, math.floor(l / 4)), encre, true)
  end
end

local TUILES = {
  { jeu = "machine", titre = "Machine à sous", court = "Machine", texte = "3 rouleaux, jusqu'à x100",
    texte_court = "x100 max", art = art_machine, couleur = R.mauvais },
  { jeu = "roulette", titre = "Roulette", texte = "Européenne, de 0 à 36", texte_court = "0 à 36",
    art = art_roulette, couleur = R.bon },
  { jeu = "crash", titre = "Crash", texte = "Encaisse avant l'explosion", texte_court = "Encaisse",
    art = art_crash, couleur = R.alerte },
  { jeu = "blackjack", titre = "Blackjack", texte = "21 contre la banque", texte_court = "3 pour 2",
    art = art_blackjack, couleur = R.accent2 },
}

--- Géométrie du hall : bloc du solde, tuiles (zones « ouvrir ») et bouton de recharge.
function hall.disposer(largeur, hauteur, etat)
  local grand = base.grand(largeur, hauteur)
  local solde = { x = 2, y = 3, largeur = largeur - 2, hauteur = grand and 9 or 4 }
  local y_tuiles, y_bas = solde.y + solde.hauteur + 1, hauteur - 2
  local zones = {}
  local ferme = etat.monnaie and not etat.monnaie.pret
  for i, morceau in ipairs(ferme and {} or panneaux.repartir(2, largeur - 2, { 1, 1, 1, 1 }, 2)) do
    local tuile = TUILES[i]
    zones[i] = { cle = "tuile_" .. tuile.jeu, x = morceau.debut, y = y_tuiles, largeur = morceau.taille,
      hauteur = y_bas - 1 - y_tuiles, action = { type = "ouvrir", jeu = tuile.jeu, cle = "tuile_" .. tuile.jeu },
      tuile = tuile }
  end
  local bouton = { x = 2, y = y_bas, largeur = math.min(30, math.floor(largeur / 2) - 2), hauteur = 3, bouton = true,
    style = "principal" }
  if etat.monnaie then
    bouton.cle, bouton.action = "encaisser", { type = "encaisser_solde", cle = "encaisser" }
    bouton.inactif = etat.solde == 0 or not etat.monnaie.pret
    bouton.texte = base.choisir("Encaisser " .. texte.quantite(etat.solde, "crédit"), "Encaisser", bouton.largeur)
  else
    bouton.cle, bouton.action = "recharger", { type = "recharger", cle = "recharger" }
    bouton.texte = base.choisir("Recharger +" .. texte.quantite(etat.recharge, "jeton"),
      "Recharger +" .. panneaux.milliers(etat.recharge), bouton.largeur)
  end
  zones[#zones + 1] = bouton
  return { largeur = largeur, hauteur = hauteur, grand = grand, zones = zones, solde = solde,
    ferme = ferme and { x = 2, y = y_tuiles, largeur = largeur - 2, hauteur = y_bas - 1 - y_tuiles },
    ligne_message = y_bas - 1, mention = { x = bouton.x + bouton.largeur + 2, y = y_bas + 1 } }
end

local function dessiner_solde(cible, plan, etat)
  local zone = plan.solde
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, zone.hauteur, R.surface)
  dessin.ecrire(cible, zone.x, zone.y, string.char(149), R.moyen, R.surface)
  dessin.ecrire(cible, zone.x + 2, zone.y, etat.monnaie and "Crédits" or "Solde", R.discret, R.surface)
  local echelle = plan.grand and 3 or 1
  local y_chiffres = zone.y + 1 + (plan.grand and 1 or 0)
  local largeur, hauteur = base.gros(cible, zone.x + 2, y_chiffres, panneaux.milliers(etat.solde), R.moyen, R.surface,
    echelle)
  local x_note = zone.x + 4 + largeur
  local x_droite = zone.x + math.floor(zone.largeur * 0.6)
  local note = "jetons fictifs"
  if etat.monnaie then
    local pieces = base.en_pieces(etat, etat.solde)
    note = pieces and "= " .. pieces or ""
  end
  dessin.ecrire(cible, x_note, y_chiffres + hauteur - 1, dessin.tronquer(note, (plan.grand and x_droite or
    zone.x + zone.largeur) - x_note - 1), R.discret, R.surface)
  local record = panneaux.milliers(etat.record)
  local reserve = etat.monnaie and "Réserve du casino : "
    .. (etat.monnaie.reserve and texte.quantite(etat.monnaie.reserve, "crédit") or "illisible")
  if plan.grand then
    dessin.ecrire(cible, x_droite, zone.y, "Plus gros gain de la session", R.discret, R.surface)
    base.gros(cible, x_droite, zone.y + 2, record, etat.record > 0 and R.bon or R.discret, R.surface, 2)
    if reserve then dessin.ecrire(cible, x_droite, zone.y + 7, reserve, R.info, R.surface) end
    return
  end
  local ligne = "Plus gros gain : " .. record
  dessin.ecrire(cible, zone.x + zone.largeur - panneaux.longueur(ligne) - 1, zone.y + 1, ligne,
    etat.record > 0 and R.bon or R.discret, R.surface)
  if reserve then
    reserve = base.choisir(reserve, "Réserve : " .. (etat.monnaie.reserve and texte.milliers(etat.monnaie.reserve)
      or "illisible"), 30)
    dessin.ecrire(cible, zone.x + zone.largeur - panneaux.longueur(reserve) - 1, zone.y, reserve, R.info, R.surface)
  end
end

local function dessiner_tuile(cible, zone, etat, maintenant)
  local tuile = zone.tuile
  local fond = base.appuye(etat, zone.cle, maintenant) and R.bordure or R.surface
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, zone.hauteur, fond)
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, 1, tuile.couleur)
  base.centrer(cible, zone.x, zone.y + 1, zone.largeur, base.choisir(tuile.titre, tuile.court, zone.largeur - 2),
    R.texte, fond)
  local art = { x = zone.x + 1, y = zone.y + 2, largeur = zone.largeur - 2, hauteur = zone.hauteur - 5 }
  if art.hauteur >= 2 then panneaux.toile(cible, art, fond, tuile.art) end
  base.centrer(cible, zone.x, zone.y + zone.hauteur - 3, zone.largeur,
    base.choisir(tuile.texte, tuile.texte_court, zone.largeur - 2), R.discret, fond)
  local plafonds = session.mises_max(etat)
  local pastille = plafonds and base.choisir("Max " .. texte.milliers(plafonds[tuile.jeu]),
    texte.milliers(plafonds[tuile.jeu]), zone.largeur - 2) or "Jouer"
  base.centrer(cible, zone.x + 1, zone.y + zone.hauteur - 2, zone.largeur - 2, pastille, R.fond,
    plafonds and plafonds[tuile.jeu] == 0 and R.mauvais or R.accent)
end

-- Mots de `phrase` répartis en lignes d'au plus `largeur` cases.
local function lignes_de(phrase, largeur)
  local lignes, courante = {}, ""
  for mot in phrase:gmatch("%S+") do
    local essai = courante == "" and mot or courante .. " " .. mot
    if panneaux.longueur(essai) > largeur and courante ~= "" then
      lignes[#lignes + 1] = courante
      courante = mot
    else
      courante = essai
    end
  end
  if courante ~= "" then lignes[#lignes + 1] = courante end
  return lignes
end

-- Vraie monnaie indisponible : à la place des tuiles, ce qui manque, en entier.
local function dessiner_fermeture(cible, zone, probleme)
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Casino fermé",
    "lance /casino/diag")
  for i, ligne in ipairs(lignes_de(probleme, interieur.largeur)) do
    if i > interieur.hauteur then break end
    dessin.ecrire(cible, interieur.x, interieur.y + i - 1, dessin.tronquer(ligne, interieur.largeur), R.alerte,
      R.surface)
  end
end

--- Dessine le hall sur la cible effacée.
function hall.dessiner(cible, plan, etat, maintenant)
  base.bandeau(cible, plan.largeur, hall.titre, etat)
  dessiner_solde(cible, plan, etat)
  for _, zone in ipairs(plan.zones) do
    if zone.tuile then dessiner_tuile(cible, zone, etat, maintenant) end
  end
  if plan.ferme then dessiner_fermeture(cible, plan.ferme, etat.monnaie.probleme) end
  base.message(cible, plan, etat, { texte = "Touche un jeu pour commencer.", couleur = R.discret }, maintenant)
  local place = plan.largeur - plan.mention.x
  local long, court = "Démo : jetons fictifs, sans aucune valeur.", "Démo : jetons fictifs."
  if etat.monnaie then long, court = "Dépose tes pièces dans le coffre de dépôt.", "Dépose tes pièces." end
  dessin.ecrire(cible, plan.mention.x, plan.mention.y, dessin.tronquer(base.choisir(long, court, place), place),
    R.alerte, R.fond)
end

return hall
