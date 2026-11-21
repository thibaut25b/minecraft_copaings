-- Écran du crash : courbe du multiplicateur en pseudo-pixels, gros multiplicateur, explosion, historique des points.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local base = require("casino.vues.base")
local crash = require("casino.jeux.crash")
local session = require("casino.session")

local R = theme.ROLES

local vue = { titre = "Crash", regles = crash.regles }

local LARGEUR_HISTORIQUE = 22
local DUREE_MIN = 8      -- secondes visibles au départ sur l'axe du temps
local HAUT_MIN = 2       -- multiplicateur visible au départ en haut de la courbe
local MARGE = 1.2        -- place gardée au-dessus et à droite de la pointe
local REPERES = { 2, 5, 10, 20, 50 }

-- Multiplicateur (centièmes) et temps montrés : en vol, figés au point atteint, ou au départ.
local function instant(jeu, maintenant)
  if jeu.phase == "monte" then
    local ecoule = maintenant - jeu.debut
    return crash.multiplicateur(ecoule), ecoule
  end
  if jeu.atteint then return jeu.atteint, crash.instant(jeu.atteint) end
  return 100, 0
end

--- Géométrie : courbe, historique (grand moniteur), barre avec JOUER ou ENCAISSER.
function vue.disposer(largeur, hauteur, etat)
  local jeu = etat.crash
  local principal
  if jeu.phase == "monte" then
    principal = { cle = "encaisser", libelle = "ENCAISSER", style = "alerte", action = { type = "encaisser" } }
  else
    principal = { cle = "jouer", libelle = jeu.resultat and "REJOUER" or "JOUER", court = "JOUER", style = "principal",
      action = { type = "jouer" } }
  end
  local plan = base.chrome(largeur, hauteur, base.boutons_jeu(etat, "Mise", {}, principal))
  local c = plan.contenu
  plan.courbe = { x = c.x, y = c.y, largeur = c.largeur, hauteur = c.hauteur }
  if base.grand(largeur, hauteur) then
    plan.courbe.largeur = c.largeur - LARGEUR_HISTORIQUE - 2
    plan.historique = { x = c.x + plan.courbe.largeur + 2, y = c.y, largeur = LARGEUR_HISTORIQUE, hauteur = c.hauteur }
  end
  return plan
end

local function couleur_point(point)
  if point < 200 then return R.mauvais end
  if point < 1000 then return R.texte end
  return R.moyen
end

local function peindre_courbe(toile, lpx, hpx, jeu, atteint, ecoule, maintenant)
  local valeur = atteint / 100
  local duree = math.max(DUREE_MIN, ecoule * MARGE)
  local haut = math.max(HAUT_MIN, valeur * MARGE)
  local function py(multiplicateur) return hpx - (hpx - 2) * (multiplicateur - 1) / (haut - 1) end
  local texte = crash.texte(atteint)
  local echelle = math.max(1, math.min(4, math.floor(hpx / 16), math.floor((lpx - 8) / (6 * #texte))))
  local droite_texte, bas_texte = 5 + base.largeur_gros(texte, echelle) + 2, 4 + 5 * echelle + 2
  local reperes = {}
  for _, repere in ipairs(REPERES) do
    local y = py(repere)
    if repere < haut then
      reperes[#reperes + 1] = { "x" .. repere, y }
      for px = 1, lpx, 3 do
        if px > droite_texte or y > bas_texte then toile.point(px, y, R.bordure) end
      end
    end
  end
  local couleur = jeu.phase == "explose" and R.mauvais or (jeu.phase == "encaisse" and R.bon or R.accent)
  local fin = 1 + (lpx - 1) * ecoule / duree
  local precedent
  for px = 1, math.floor(fin) do
    local y = py(math.min(valeur, crash.courbe((px - 1) / (lpx - 1) * duree)))
    toile.ligne(px, y + 1, px, hpx, R.bordure)
    if precedent then toile.ligne(px - 1, precedent, px, y, couleur) end
    precedent = y
  end
  local pointe_y = precedent or py(1)
  if jeu.phase == "explose" then
    local rayon = math.max(3, math.floor(hpx / 8))
    for k = 0, 7 do
      local angle = k * math.pi / 4
      toile.ligne(fin, pointe_y, fin + math.cos(angle) * rayon * 1.6, pointe_y + math.sin(angle) * rayon * 1.6,
        R.alerte)
    end
    toile.cercle(fin, pointe_y, rayon, R.alerte, true)
    toile.cercle(fin, pointe_y, math.floor(rayon / 2), R.moyen, true)
  elseif jeu.phase == "monte" then
    local pulsation = math.floor(maintenant * 8) % 2
    toile.rectangle(fin - 1 - pulsation, pointe_y - 1 - pulsation, 3 + 2 * pulsation, 3 + 2 * pulsation, R.moyen, true)
  else
    toile.rectangle(fin - 1, pointe_y - 1, 3, 3, couleur, true)
  end
  local couleur_texte = jeu.phase == "explose" and R.mauvais or (jeu.phase == "encaisse" and R.bon or R.texte)
  base.gros_toile(toile, 5, 4, texte, couleur_texte, echelle)
  return bas_texte, reperes
end

local function dessiner_historique(cible, zone, jeu)
  local interieur = panneaux.panneau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, "Derniers points")
  if #jeu.historique == 0 then
    dessin.ecrire(cible, interieur.x, interieur.y, "Aucun tour joué.", R.discret, R.surface)
  end
  for i, point in ipairs(jeu.historique) do
    local y = interieur.y + i - 1
    if y >= interieur.y + interieur.hauteur - 2 then break end
    dessin.ecrire(cible, interieur.x, y, crash.texte(point), couleur_point(point), R.surface)
  end
  dessin.ecrire(cible, interieur.x, interieur.y + interieur.hauteur - 1,
    string.format("Retour : %d %%", crash.RETOUR), R.info, R.surface)
end

local function statut(etat, maintenant)
  local jeu = etat.crash
  if jeu.phase == "monte" then
    local atteint = crash.multiplicateur(maintenant - jeu.debut)
    local gain = crash.gain(jeu.mise, atteint)
    return { texte = "ENCAISSER maintenant : " .. texte.quantite(gain, "jeton") .. ".",
      court = "Encaisser : " .. panneaux.milliers(gain), couleur = R.moyen }
  end
  if jeu.phase == "explose" then
    return base.statut_resultat(jeu.resultat, "Explosion à " .. crash.texte(jeu.point), etat.solde)
  end
  if jeu.phase == "encaisse" then
    local resultat = base.statut_resultat(jeu.resultat, "Encaissé à " .. crash.texte(jeu.atteint), etat.solde)
    if jeu.point > jeu.atteint then
      local prevue = " Explosion prévue à " .. crash.texte(jeu.point) .. "."
      resultat.texte, resultat.court = resultat.texte .. prevue, resultat.court .. prevue
    end
    return resultat
  end
  return { texte = "Mise, JOUER, puis ENCAISSER avant l'explosion.", court = "JOUER puis ENCAISSER.",
    couleur = R.discret }
end

--- Dessine le crash à l'instant `maintenant`.
function vue.dessiner(cible, plan, etat, maintenant)
  local jeu = etat.crash
  base.bandeau(cible, plan.largeur, vue.titre, etat)
  local atteint, ecoule = instant(jeu, maintenant)
  local bas_texte, reperes
  panneaux.toile(cible, plan.courbe, R.surface, function(toile, lpx, hpx)
    bas_texte, reperes = peindre_courbe(toile, lpx, hpx, jeu, atteint, ecoule, maintenant)
  end)
  local droite = plan.courbe.x + plan.courbe.largeur
  for _, repere in ipairs(reperes) do
    local _, y_repere = panneaux.case(plan.courbe, 1, repere[2])
    dessin.ecrire(cible, droite - #repere[1], y_repere, repere[1], R.discret, R.surface)
  end
  local _, y = panneaux.case(plan.courbe, 5, bas_texte)
  local libelles = { explose = { "EXPLOSION", R.mauvais }, encaisse = { "ENCAISSÉ", R.bon },
    attente = { "Prêt", R.discret } }
  local libelle = libelles[jeu.phase]
  if libelle and y < plan.courbe.y + plan.courbe.hauteur then
    panneaux.pastille(cible, plan.courbe.x + 2, y, libelle[1], libelle[2])
  end
  if plan.historique then dessiner_historique(cible, plan.historique, jeu) end
  base.message(cible, plan, etat, statut(etat, maintenant), maintenant)
end

return vue
