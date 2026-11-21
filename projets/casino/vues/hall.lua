-- Hall du casino : solde, plus gros gain de la session, une tuile par jeu, bouton de recharge.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("casino.vues.base")
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

local TUILES = {
  { jeu = "machine", titre = "Machine à sous", court = "Machine", texte = "3 rouleaux, jusqu'à x100",
    texte_court = "jusqu'à x100", art = art_machine, couleur = R.mauvais },
  { jeu = "roulette", titre = "Roulette", texte = "Européenne, de 0 à 36", texte_court = "0 à 36",
    art = art_roulette, couleur = R.bon },
  { jeu = "crash", titre = "Crash", texte = "Encaisse avant l'explosion", texte_court = "Encaisse vite",
    art = art_crash, couleur = R.alerte },
}

--- Géométrie du hall : bloc du solde, tuiles (zones « ouvrir ») et bouton de recharge.
function hall.disposer(largeur, hauteur, etat)
  local grand = base.grand(largeur, hauteur)
  local solde = { x = 2, y = 3, largeur = largeur - 2, hauteur = grand and 9 or 4 }
  local y_tuiles, y_bas = solde.y + solde.hauteur + 1, hauteur - 2
  local zones = {}
  for i, morceau in ipairs(panneaux.repartir(2, largeur - 2, { 1, 1, 1 }, 2)) do
    local tuile = TUILES[i]
    zones[i] = { cle = "tuile_" .. tuile.jeu, x = morceau.debut, y = y_tuiles, largeur = morceau.taille,
      hauteur = y_bas - 1 - y_tuiles, action = { type = "ouvrir", jeu = tuile.jeu, cle = "tuile_" .. tuile.jeu },
      tuile = tuile }
  end
  local recharge = "+" .. panneaux.milliers(etat.recharge)
  zones[#zones + 1] = { cle = "recharger", x = 2, y = y_bas, largeur = math.min(30, math.floor(largeur / 2) - 2),
    hauteur = 3, action = { type = "recharger", cle = "recharger" }, bouton = true, style = "principal",
    texte = "Recharger " .. recharge .. " jetons" }
  local bouton = zones[#zones]
  bouton.texte = base.choisir(bouton.texte, "Recharger " .. recharge, bouton.largeur)
  return { largeur = largeur, hauteur = hauteur, grand = grand, zones = zones, solde = solde,
    ligne_message = y_bas - 1, mention = { x = bouton.x + bouton.largeur + 2, y = y_bas + 1 } }
end

local function dessiner_solde(cible, plan, etat)
  local zone = plan.solde
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, zone.hauteur, R.surface)
  dessin.ecrire(cible, zone.x, zone.y, string.char(149), R.moyen, R.surface)
  dessin.ecrire(cible, zone.x + 2, zone.y, "Solde", R.discret, R.surface)
  local echelle = plan.grand and 3 or 1
  local y_chiffres = zone.y + 1 + (plan.grand and 1 or 0)
  local largeur, hauteur = base.gros(cible, zone.x + 2, y_chiffres, panneaux.milliers(etat.solde), R.moyen, R.surface,
    echelle)
  dessin.ecrire(cible, zone.x + 4 + largeur, y_chiffres + hauteur - 1, "jetons fictifs", R.discret, R.surface)
  local record = panneaux.milliers(etat.record)
  if plan.grand then
    local x = zone.x + math.floor(zone.largeur * 0.6)
    dessin.ecrire(cible, x, zone.y, "Plus gros gain de la session", R.discret, R.surface)
    base.gros(cible, x, zone.y + 2, record, etat.record > 0 and R.bon or R.discret, R.surface, 2)
    return
  end
  local texte = "Plus gros gain : " .. record
  dessin.ecrire(cible, zone.x + zone.largeur - panneaux.longueur(texte) - 1, zone.y + 1, texte,
    etat.record > 0 and R.bon or R.discret, R.surface)
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
  base.centrer(cible, zone.x + math.floor(zone.largeur / 2) - 4, zone.y + zone.hauteur - 2, 9, "Jouer",
    R.fond, R.accent)
end

--- Dessine le hall sur la cible effacée.
function hall.dessiner(cible, plan, etat, maintenant)
  base.bandeau(cible, plan.largeur, hall.titre, etat)
  dessiner_solde(cible, plan, etat)
  for _, zone in ipairs(plan.zones) do
    if zone.tuile then dessiner_tuile(cible, zone, etat, maintenant) end
  end
  base.message(cible, plan, etat, { texte = "Touche un jeu pour commencer.", couleur = R.discret }, maintenant)
  local place = plan.largeur - plan.mention.x
  dessin.ecrire(cible, plan.mention.x, plan.mention.y, dessin.tronquer(base.choisir(
    "Démo : jetons fictifs, sans aucune valeur.", "Démo : jetons fictifs.", place), place), R.alerte, R.fond)
end

return hall
