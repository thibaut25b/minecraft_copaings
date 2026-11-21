-- Écran de la machine à sous : trois rouleaux animés, ligne de gain, table des gains sur grand moniteur.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local pixels = require("commun.pixels")
local theme = require("commun.theme")
local base = require("casino.vues.base")
local symboles = require("casino.vues.symboles")
local machine = require("casino.jeux.machine")
local session = require("casino.session")

local R = theme.ROLES

local vue = { titre = "Machine à sous" }

local LARGEUR_TABLE = 30
local ECART = 2
local PART_ARRET = 0.62 -- hauteur d'un arrêt de bande, en part de la fenêtre du rouleau

--- Règles de la machine, entrées colorées comme leur symbole.
function vue.regles()
  local regles = machine.regles()
  for _, entree in ipairs(regles.entrees) do entree.couleur = symboles.COULEURS[entree.symbole] end
  return regles
end

--- Géométrie : rouleaux, cadre, table des gains (grand moniteur), zone du gain, barre de boutons.
function vue.disposer(largeur, hauteur, etat)
  local bloque = session.en_cours(etat)
  local plan = base.chrome(largeur, hauteur, base.boutons_jeu(etat, "Mise", {},
    { cle = "jouer", libelle = "JOUER", style = "principal", action = { type = "jouer" }, inactif = bloque }))
  local c = plan.contenu
  plan.grand = base.grand(largeur, hauteur)
  local zone = { x = c.x, y = c.y, largeur = c.largeur, hauteur = c.hauteur }
  if plan.grand then
    zone.largeur = c.largeur - LARGEUR_TABLE - 2
    plan.table = { x = zone.x + zone.largeur + 2, y = c.y, largeur = LARGEUR_TABLE, hauteur = c.hauteur }
  end
  local largeur_rouleau = math.min(22, math.floor((zone.largeur - 2 * ECART - 4) / 3))
  local hauteur_rouleau = math.min(zone.hauteur - 2, plan.grand and 21 or 13)
  if hauteur_rouleau % 2 == 0 then hauteur_rouleau = hauteur_rouleau - 1 end
  local total = 3 * largeur_rouleau + 2 * ECART
  local x0 = zone.x + math.floor((zone.largeur - total) / 2)
  local y0 = plan.grand and zone.y + 1 or zone.y + math.floor((zone.hauteur - hauteur_rouleau) / 2)
  plan.rouleaux = {}
  for i = 1, 3 do
    plan.rouleaux[i] = { x = x0 + (i - 1) * (largeur_rouleau + ECART), y = y0, largeur = largeur_rouleau,
      hauteur = hauteur_rouleau }
  end
  plan.cadre = { x = x0 - 2, y = y0 - 1, largeur = total + 4, hauteur = hauteur_rouleau + 2 }
  plan.ligne = y0 + math.floor(hauteur_rouleau / 2)
  local y_gain = plan.cadre.y + plan.cadre.hauteur + 1
  plan.gain = { x = zone.x, y = y_gain, largeur = zone.largeur, hauteur = zone.y + zone.hauteur - y_gain }
  return plan
end

-- Position de chaque rouleau (en arrêts de bande, à partir de 1) à l'instant `maintenant`.
local function positions(jeu, maintenant)
  if jeu.phase ~= "tourne" then return jeu.arrets end
  local ecoule, liste = maintenant - jeu.debut, {}
  for i = 1, 3 do
    liste[i] = session.position(jeu.depart[i], jeu.distance[i], session.ARRETS_MACHINE[i], ecoule)
  end
  return liste
end

local function dessiner_rouleau(cible, zone, position)
  local taille = #machine.BANDE
  local toile = pixels.creer(zone.largeur, zone.hauteur, R.fond)
  local lpx, hpx = toile.taille()
  local pas = math.floor(hpx * PART_ARRET)
  local centre = math.floor(zone.hauteur / 2) * 3 + 2
  local entier = math.floor(position)
  for decalage = -2, 2 do
    local arret = entier + decalage
    local nom = machine.BANDE[(arret - 1) % taille + 1]
    symboles.peindre(toile, nom, lpx / 2 + 0.5, centre + (arret - position) * pas, math.min(pas - 3, lpx - 4))
  end
  toile.rendre(cible, zone.x, zone.y)
end

local function dessiner_table(cible, plan, etat)
  local t = plan.table
  local interieur = panneaux.panneau(cible, t.x, t.y, t.largeur, t.hauteur, "Table des gains", "x mise")
  local gagnante = etat.machine.phase == "fini" and etat.machine.combinaison or nil
  local pas = interieur.hauteur >= 2 * #machine.TABLE and 2 or 1
  for i, ligne in ipairs(machine.TABLE) do
    local y = interieur.y + (i - 1) * pas
    if y >= interieur.y + interieur.hauteur then break end
    local fond = ligne == gagnante and R.bordure or R.surface
    panneaux.rectangle(cible, interieur.x - 1, y, interieur.largeur + 2, 1, fond)
    dessin.ecrire(cible, interieur.x, y, machine.libelle(ligne), symboles.COULEURS[ligne.symbole], fond)
    local valeur = "x" .. ligne.multiplicateur
    dessin.ecrire(cible, interieur.x + interieur.largeur - #valeur, y, valeur, R.texte, fond)
  end
  local pied = (string.format("Retour : %.1f %%", 100 * machine.retour()):gsub("%.", ",", 1))
  dessin.ecrire(cible, interieur.x, interieur.y + interieur.hauteur - 1, pied, R.info, R.surface)
end

local function statut(etat)
  local jeu = etat.machine
  if jeu.phase == "tourne" then return { texte = "Les rouleaux tournent...", couleur = R.discret } end
  if not jeu.resultat then
    return { texte = "Choisis ta mise, puis touche JOUER.", court = "Mise, puis JOUER.", couleur = R.discret }
  end
  return base.statut_resultat(jeu.resultat, jeu.combinaison and machine.libelle(jeu.combinaison) or "Rien",
    etat.solde)
end

--- Dessine la machine à l'instant `maintenant`.
function vue.dessiner(cible, plan, etat, maintenant)
  local jeu = etat.machine
  base.bandeau(cible, plan.largeur, vue.titre, etat)
  local fete = jeu.fete and maintenant < jeu.fete
  local clignote = fete and math.floor(maintenant * 6) % 2 == 0
  local cadre = plan.cadre
  panneaux.rectangle(cible, cadre.x, cadre.y, cadre.largeur, cadre.hauteur, clignote and R.moyen or R.bordure)
  local liste = positions(jeu, maintenant)
  for i, zone in ipairs(plan.rouleaux) do dessiner_rouleau(cible, zone, liste[i]) end
  local repere, fond_repere = R.fond, clignote and R.bon or R.moyen
  dessin.ecrire(cible, cadre.x, plan.ligne, string.char(16), repere, fond_repere)
  dessin.ecrire(cible, cadre.x + cadre.largeur - 1, plan.ligne, string.char(17), repere, fond_repere)
  if plan.table then dessiner_table(cible, plan, etat) end
  local resultat = jeu.phase == "fini" and jeu.resultat
  if resultat and plan.gain.hauteur >= 3 then
    local net = resultat.gain - resultat.mise
    local texte = (net >= 0 and "+" or "-") .. panneaux.milliers(math.abs(net))
    local couleur = net > 0 and R.bon or (net == 0 and R.info or R.mauvais)
    local echelle = base.echelle_gros(texte, plan.gain.largeur, plan.gain.hauteur, 3)
    local largeur = math.ceil(base.largeur_gros(texte, echelle) / 2)
    base.gros(cible, plan.gain.x + math.floor((plan.gain.largeur - largeur) / 2), plan.gain.y, texte, couleur, R.fond,
      echelle)
  end
  base.message(cible, plan, etat, statut(etat), maintenant)
end

return vue
