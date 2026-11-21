-- Écran du blackjack : mains de la banque et du joueur, cartes distribuées depuis le sabot, totaux, actions.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local base = require("casino.vues.base")
local blackjack = require("casino.jeux.blackjack")
local session = require("casino.session")

local R = theme.ROLES

local vue = { titre = "Blackjack", regles = blackjack.regles }

-- Caractères des couleurs dans la police de CC, et leur encre sur la carte.
local SYMBOLES = { pique = string.char(6), coeur = string.char(3), carreau = string.char(4), trefle = string.char(5) }
local ENCRES = { pique = R.fond, coeur = R.mauvais, carreau = R.mauvais, trefle = R.fond }
local ENORME = { largeur = 15, hauteur = 12 }
local GRANDE = { largeur = 9, hauteur = 7 }
local PETITE = { largeur = 6, hauteur = 4 }
local LARGEUR_TOTAL = 12

local ISSUES = {
  blackjack = function() return "Blackjack" end,
  banque_blackjack = function() return "Blackjack de la banque" end,
  egalite = function(j, b) return "Égalité à " .. j .. (j == b and "" or " contre " .. b) end,
  depasse = function(j) return "Tu dépasses 21 (" .. j .. ")" end,
  banque_depasse = function(_, b) return "La banque dépasse 21 (" .. b .. ")" end,
  gagne = function(j, b) return "Tu gagnes " .. j .. " contre " .. b end,
  perdu = function(j, b) return "La banque gagne " .. b .. " contre " .. j end,
}

--- Géométrie : main de la banque en haut, du joueur en bas, sabot à droite, barre d'actions pendant la main.
function vue.disposer(largeur, hauteur, etat)
  local jeu = etat.blackjack
  local boutons
  if jeu.phase == "joueur" then
    boutons = {
      { cle = "mise", libelle = "Mise " .. panneaux.milliers(jeu.mise), court = panneaux.milliers(jeu.mise),
        style = "affichage" },
      { cle = "doubler", libelle = "DOUBLER", court = "x2", action = { type = "doubler" }, inactif = #jeu.joueur ~= 2 },
      { cle = "rester", libelle = "RESTER", style = "alerte", action = { type = "rester" } },
      { cle = "tirer", libelle = "TIRER", style = "principal", action = { type = "tirer" } },
    }
  else
    boutons = base.boutons_jeu(etat, "Mise", {}, { cle = "jouer", libelle = "DISTRIBUER", court = "JOUER",
      style = "principal", action = { type = "jouer" }, inactif = session.en_cours(etat) })
  end
  local plan = base.chrome(largeur, hauteur, boutons)
  local c = plan.contenu
  plan.grand = base.grand(largeur, hauteur)
  plan.carte = PETITE
  for _, taille in ipairs({ GRANDE, ENORME }) do
    if c.hauteur >= 2 * (taille.hauteur + 1) + 3 and c.largeur >= 8 * taille.largeur then plan.carte = taille end
  end
  local h = plan.carte.hauteur + 1
  local largeur_main = c.largeur - plan.carte.largeur - 2
  plan.banque = { x = c.x, y = c.y, largeur = largeur_main, hauteur = h }
  plan.joueur = { x = c.x, y = c.y + c.hauteur - h, largeur = largeur_main, hauteur = h }
  plan.sabot = { x = c.x + c.largeur - plan.carte.largeur, y = c.y + 1 }
  plan.milieu = { x = c.x, y = c.y + h, largeur = largeur_main, hauteur = c.hauteur - 2 * h }
  return plan
end

local function dessiner_carte(cible, x, y, taille, carte, cachee)
  local l, h = taille.largeur, taille.hauteur
  if cachee then
    panneaux.rectangle(cible, x, y, l, h, R.accent2)
    panneaux.rectangle(cible, x + 1, y + 1, l - 2, h - 2, R.bordure)
    return
  end
  panneaux.rectangle(cible, x, y, l, h, R.texte)
  local libelle, symbole, encre = blackjack.libelle(carte), SYMBOLES[carte.couleur], ENCRES[carte.couleur]
  dessin.ecrire(cible, x, y, libelle .. symbole, encre, R.texte)
  dessin.ecrire(cible, x + l - #libelle, y + h - 1, libelle, encre, R.texte)
  if h >= 5 then base.centrer(cible, x, y + math.floor(h / 2), l, symbole .. symbole .. symbole, encre, R.texte) end
end

local function cachee(jeu, index, maintenant)
  return index == 2 and (not jeu.revele or maintenant < jeu.revele)
end

-- Cartes visibles à l'instant (la carte cachée de la banque n'y compte pas).
local function visibles(main, jeu, est_banque, maintenant)
  local liste = {}
  for i, carte in ipairs(main) do
    if carte.instant <= maintenant and not (est_banque and cachee(jeu, i, maintenant)) then
      liste[#liste + 1] = carte
    end
  end
  return liste
end

local function texte_total(cartes)
  if #cartes == 0 then return "" end
  local total, souple = blackjack.valeur(cartes)
  if souple and total < 21 then return (total - 10) .. " ou " .. total end
  return tostring(total)
end

local function dessiner_main(cible, plan, zone, titre, main, jeu, est_banque, maintenant)
  local taille = plan.carte
  local cartes = visibles(main, jeu, est_banque, maintenant)
  local total = texte_total(cartes)
  local couleur = #cartes > 0 and blackjack.valeur(cartes) > 21 and R.mauvais or R.moyen
  local x_texte = dessin.ecrire(cible, zone.x, zone.y, titre, R.discret, R.fond) + zone.x + 1
  dessin.ecrire(cible, x_texte, zone.y, total, couleur, R.fond)
  local place = zone.largeur - (plan.grand and LARGEUR_TOTAL or 0)
  local pas = math.min(taille.largeur + 1, math.max(3, math.floor((place - taille.largeur) / math.max(1, #main - 1))))
  for i, carte in ipairs(main) do
    if carte.instant <= maintenant then
      local x, y = zone.x + (i - 1) * pas, zone.y + 1
      local part = math.min(1, (maintenant - carte.instant) / session.GLISSE_CARTE)
      x = math.floor(plan.sabot.x + (x - plan.sabot.x) * part + 0.5)
      y = math.floor(plan.sabot.y + (y - plan.sabot.y) * part + 0.5)
      dessiner_carte(cible, x, y, taille, carte, est_banque and cachee(jeu, i, maintenant))
    end
  end
  if plan.grand and #cartes > 0 then
    local chiffres = tostring(blackjack.valeur(cartes))
    base.gros(cible, zone.x + zone.largeur - math.ceil(base.largeur_gros(chiffres, 2) / 2) - 1, zone.y + 2, chiffres,
      couleur, R.fond, 2)
  end
end

local function statut(etat)
  local jeu = etat.blackjack
  if jeu.phase == "anime" then return { texte = "Distribution...", couleur = R.discret } end
  if jeu.phase == "joueur" then
    return { texte = "Tirer, rester ou doubler ?", court = "TIRER, RESTER ou x2 ?", couleur = R.moyen }
  end
  if jeu.phase == "fini" and jeu.resultat then
    local libelle = ISSUES[jeu.issue](blackjack.valeur(jeu.joueur), blackjack.valeur(jeu.banque))
    return base.statut_resultat(jeu.resultat, libelle, etat.solde)
  end
  return { texte = "Choisis ta mise, puis DISTRIBUER.", court = "Mise, puis JOUER.", couleur = R.discret }
end

local function dessiner_milieu(cible, plan, etat)
  local jeu, zone = etat.blackjack, plan.milieu
  if zone.hauteur < 1 then return end
  local resultat = jeu.phase == "fini" and jeu.resultat
  local y = zone.y + math.floor((zone.hauteur - 1) / 2)
  if resultat and zone.hauteur >= 5 then
    local net = resultat.gain - resultat.mise
    local chiffres = (net >= 0 and "+" or "-") .. panneaux.milliers(math.abs(net))
    local couleur = net > 0 and R.bon or (net == 0 and R.info or R.mauvais)
    local echelle = base.echelle_gros(chiffres, zone.largeur, zone.hauteur - 2, 3)
    local largeur = math.ceil(base.largeur_gros(chiffres, echelle) / 2)
    base.gros(cible, zone.x + math.floor((zone.largeur - largeur) / 2), zone.y + 1, chiffres, couleur, R.fond, echelle)
    return
  end
  local rappel = "Blackjack paie 3 pour 2. La banque reste à 17."
  if jeu.double and jeu.phase ~= "attente" then rappel = "Mise doublée : " .. texte.quantite(jeu.mise, "jeton") .. "." end
  base.centrer(cible, zone.x, y, zone.largeur, base.choisir(rappel, "3 pour 2, banque à 17", zone.largeur), R.discret,
    R.fond)
end

--- Dessine la table à l'instant `maintenant`.
function vue.dessiner(cible, plan, etat, maintenant)
  local jeu = etat.blackjack
  base.bandeau(cible, plan.largeur, vue.titre, etat)
  dessiner_carte(cible, plan.sabot.x, plan.sabot.y, plan.carte, nil, true)
  if plan.carte.hauteur + plan.sabot.y + 1 <= plan.joueur.y then
    base.centrer(cible, plan.sabot.x, plan.sabot.y + plan.carte.hauteur, plan.carte.largeur, "sabot", R.discret, R.fond)
  end
  dessiner_milieu(cible, plan, etat)
  dessiner_main(cible, plan, plan.banque, "Banque", jeu.banque, jeu, true, maintenant)
  dessiner_main(cible, plan, plan.joueur, "Toi", jeu.joueur, jeu, false, maintenant)
  base.message(cible, plan, etat, statut(etat), maintenant)
end

return vue
