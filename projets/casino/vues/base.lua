-- Briques d'écran du casino : bandeau, barre de boutons, ligne de message, gros chiffres, règles, écran trop petit.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local pixels = require("commun.pixels")
local texte = require("commun.texte")
local theme = require("commun.theme")
local session = require("casino.session")
local monnaie = require("casino.monnaie")

local R = theme.ROLES

local base = {}

--- Plus petite cible jouable ; en dessous, un message demande un moniteur plus grand.
base.MIN = { largeur = 51, hauteur = 19 }
--- À partir de cette taille, les jeux ajoutent leurs panneaux latéraux.
base.GRAND = { largeur = 80, hauteur = 30 }

local HAUTEUR_BARRE = 3
local LARGEUR_PRINCIPAL = 24
local TONS = { bon = R.bon, mauvais = R.mauvais, info = R.info }

-- Police 3 x 5 des gros chiffres : une chaîne par rangée, « 1 » = pixel allumé.
local GLYPHES = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "001", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
  x = { "000", "101", "010", "101", "000" }, ["+"] = { "000", "010", "111", "010", "000" },
  ["-"] = { "000", "000", "111", "000", "000" }, ["."] = { "0", "0", "0", "0", "1" },
  [" "] = { "0", "0", "0", "0", "0" },
}

--- Vrai si la cible a la place des panneaux latéraux.
function base.grand(largeur, hauteur)
  return largeur >= base.GRAND.largeur and hauteur >= base.GRAND.hauteur
end

--- Vrai si le bouton `cle` vient d'être touché (retour visuel).
function base.appuye(etat, cle, maintenant)
  return etat.appui ~= nil and etat.appui.cle == cle and maintenant < etat.appui.fin
end

--- Vrai si la case (x, y) est dans `zone` { x, y, largeur, hauteur }.
function base.dans(zone, x, y)
  return x >= zone.x and x < zone.x + zone.largeur and y >= zone.y and y < zone.y + zone.hauteur
end

--- Écrit `texte` (ASCII) en (x, y) en ne gardant que ce qui tombe dans les colonnes de `zone`.
function base.ecrire_dans(cible, zone, x, y, texte, couleur, fond)
  local debut, fin = math.max(x, zone.x), math.min(x + #texte - 1, zone.x + zone.largeur - 1)
  if fin < debut then return end
  dessin.ecrire(cible, debut, y, texte:sub(debut - x + 1, fin - x + 1), couleur, fond)
end

--- Texte centré sur `largeur` cases à partir de x.
function base.centrer(cible, x, y, largeur, texte, couleur, fond)
  if largeur < 1 then return end
  dessin.ecrire(cible, x, y, dessin.aligner(texte, largeur, "centre"), couleur, fond)
end

--- Le texte long s'il tient sur `largeur`, sinon le court.
function base.choisir(long, court, largeur)
  if court and panneaux.longueur(long) > largeur then return court end
  return long
end

--- Largeur en pixels de `texte` en gros chiffres à l'`echelle` donnée.
function base.largeur_gros(texte, echelle)
  local total = 0
  for i = 1, #texte do total = total + (#GLYPHES[texte:sub(i, i)][1] + 1) * echelle end
  return math.max(0, total - echelle)
end

--- Peint `texte` (chiffres, x, +, -, point, espace) en gros chiffres dans `toile`, coin haut gauche en (px, py).
function base.gros_toile(toile, px, py, texte, couleur, echelle)
  for i = 1, #texte do
    local glyphe = GLYPHES[texte:sub(i, i)]
    for rangee, motif in ipairs(glyphe) do
      for colonne = 1, #motif do
        if motif:sub(colonne, colonne) == "1" then
          toile.rectangle(px + (colonne - 1) * echelle, py + (rangee - 1) * echelle, echelle, echelle, couleur, true)
        end
      end
    end
    px = px + (#glyphe[1] + 1) * echelle
  end
end

--- Gros chiffres posés en (x, y) sur `fond` ; renvoie la largeur et la hauteur occupées en cases.
function base.gros(cible, x, y, texte, couleur, fond, echelle)
  local largeur = math.ceil(base.largeur_gros(texte, echelle) / 2)
  local hauteur = math.ceil(5 * echelle / 3)
  local toile = pixels.creer(largeur, hauteur, fond)
  base.gros_toile(toile, 1, 1 + math.floor((3 * hauteur - 5 * echelle) / 2), texte, couleur, echelle)
  toile.rendre(cible, x, y)
  return largeur, hauteur
end

--- Plus grande échelle (1 à `maximum`) pour que `texte` tienne en `largeur` x `hauteur` cases.
function base.echelle_gros(texte, largeur, hauteur, maximum)
  for echelle = maximum, 2, -1 do
    if base.largeur_gros(texte, echelle) <= 2 * largeur and 5 * echelle <= 3 * hauteur then return echelle end
  end
  return 1
end

-- Largeurs des boutons de la barre : libellés longs avec marge, puis serrés, puis courts.
local function ranger(boutons, largeur)
  local essais = { { "libelle", 4 }, { "libelle", 2 }, { "court", 2 } }
  for _, essai in ipairs(essais) do
    local total, largeurs, textes = #boutons - 1, {}, {}
    for i, bouton in ipairs(boutons) do
      textes[i] = bouton[essai[1]] or bouton.libelle
      largeurs[i] = panneaux.longueur(textes[i]) + essai[2]
      total = total + largeurs[i]
    end
    if total <= largeur then return largeurs, textes, largeur - total end
  end
  local largeurs, textes = {}, {}
  for i, bouton in ipairs(boutons) do
    largeurs[i], textes[i] = math.max(1, math.floor((largeur - #boutons + 1) / #boutons)), bouton.court or bouton.libelle
  end
  return largeurs, textes, 0
end

--- Mise en page commune d'un jeu : bandeau, contenu, ligne de message, barre de `boutons` en bas. Un bouton :
--- { cle, libelle, court, action, style ("principal", "alerte", "affichage"), inactif, couleur } ; le dernier est le
--- bouton principal, calé à droite et élargi. Renvoie { largeur, hauteur, zones, contenu, ligne_message }.
function base.chrome(largeur, hauteur, boutons)
  local y = hauteur - HAUTEUR_BARRE + 1
  local largeurs, textes, reste = ranger(boutons, largeur - 2)
  local zones, x = {}, 2
  for i, bouton in ipairs(boutons) do
    local zone = { cle = bouton.cle, x = x, y = y, largeur = largeurs[i], hauteur = HAUTEUR_BARRE, texte = textes[i],
      style = bouton.style, inactif = bouton.inactif, couleur = bouton.couleur, bouton = true }
    if bouton.action then
      zone.action = bouton.action
      zone.action.cle = bouton.cle
    end
    if i == #boutons then
      zone.largeur = math.min(largeurs[i] + reste, math.max(largeurs[i], LARGEUR_PRINCIPAL))
      zone.x = largeur - zone.largeur
    end
    zones[i] = zone
    x = x + largeurs[i] + 1
  end
  return {
    largeur = largeur, hauteur = hauteur, zones = zones, ligne_message = y - 1,
    contenu = { x = 2, y = 3, largeur = largeur - 2, hauteur = y - 4 },
  }
end

--- Boutons communs d'un jeu : hall, mise (moins, valeur, plus), règles, puis `autres` et le bouton `principal`.
function base.boutons_jeu(etat, nom_mise, autres, principal)
  local bloque = session.en_cours(etat)
  local valeur = panneaux.milliers(etat.mise)
  local plafonds = session.mises_max(etat)
  local liste = {
    { cle = "hall", libelle = "< Hall", court = "<", action = { type = "hall" }, inactif = bloque },
    { cle = "moins", libelle = "-", action = { type = "mise", pas = -1 },
      inactif = bloque or etat.mise <= etat.paliers[1] },
    { cle = "mise", libelle = nom_mise .. " " .. valeur, court = valeur, style = "affichage",
      couleur = (etat.mise > etat.solde or (plafonds and etat.mise > (plafonds[etat.ecran] or 0))) and R.mauvais
        or R.moyen },
    { cle = "plus", libelle = "+", action = { type = "mise", pas = 1 },
      inactif = bloque or etat.mise >= etat.paliers[#etat.paliers] },
    { cle = "regles", libelle = "Règles", court = "?", action = { type = "regles" }, inactif = bloque },
  }
  for _, bouton in ipairs(autres) do liste[#liste + 1] = bouton end
  liste[#liste + 1] = principal
  return liste
end

--- Dessine un bouton de la barre : enfoncé, inactif, principal, alerte ou ordinaire.
function base.bouton(cible, zone, etat, maintenant)
  local fond, encre = R.bordure, R.texte
  if zone.style == "affichage" then
    fond, encre = R.fond, zone.couleur or R.moyen
  elseif zone.inactif then
    fond, encre = R.surface, R.discret
  elseif base.appuye(etat, zone.cle, maintenant) then
    fond, encre = R.texte, R.fond
  elseif zone.style == "principal" then
    fond, encre = R.accent, R.fond
  elseif zone.style == "alerte" then
    fond, encre = R.moyen, R.fond
  end
  panneaux.rectangle(cible, zone.x, zone.y, zone.largeur, zone.hauteur, fond)
  base.centrer(cible, zone.x, zone.y + math.floor((zone.hauteur - 1) / 2), zone.largeur, zone.texte, encre, fond)
end

--- Bandeau d'un écran : titre, mention de démo, solde à droite.
function base.bandeau(cible, largeur, titre, etat)
  local segments = {}
  local plafonds = session.mises_max(etat)
  if plafonds and plafonds[etat.ecran] then
    segments[1] = { "Mise max " .. texte.milliers(plafonds[etat.ecran]), R.discret }
  end
  local mention = largeur >= 70 and "démo, jetons fictifs" or "démo"
  if etat.monnaie then mention = largeur >= 70 and "pièces réelles" or nil end
  segments[#segments + 1] = { (etat.monnaie and "Crédits " or "Solde ") .. texte.milliers(etat.solde), R.moyen }
  panneaux.bandeau(cible, titre, mention, segments)
end

--- Équivalent en pièces d'un montant en vraie monnaie (« 1 or 5 fer »), ou nil avec les jetons fictifs.
function base.en_pieces(etat, montant)
  if not etat.monnaie or not etat.monnaie.valeurs then return nil end
  return monnaie.decrire(montant, etat.monnaie.pieces, etat.monnaie.valeurs)
end

--- Ligne de message : jeu suspendu (vraie monnaie), sinon le message en cours, sinon `statut` { texte, court,
--- couleur } du jeu.
function base.message(cible, plan, etat, statut, maintenant)
  local message = etat.message
  local texte_ligne, court, couleur = statut.texte, statut.court, statut.couleur
  if message and maintenant < message.fin then texte_ligne, court, couleur = message.texte, nil, TONS[message.ton] end
  if etat.monnaie and not etat.monnaie.pret then
    texte_ligne, couleur = "Jeu suspendu : " .. etat.monnaie.probleme, R.mauvais
    court = etat.ecran == "hall" and "Jeux suspendus en attendant la banque." or "Jeu suspendu : voir le hall."
  end
  base.centrer(cible, 1, plan.ligne_message, plan.largeur, base.choisir(texte_ligne, court, plan.largeur), couleur,
    R.fond)
end

--- Statut d'un tour réglé : gain, mise rendue ou perte, avec le nouveau solde (et son équivalent en pièces).
function base.statut_resultat(resultat, libelle, etat)
  local gain, mise, unite = resultat.gain, resultat.mise, etat.unite
  local solde = texte.milliers(etat.solde)
  local pieces = base.en_pieces(etat, gain)
  if gain > mise then
    return { texte = string.format("%s : gagné %s%s ! Solde %s.", libelle, texte.quantite(gain, unite),
      pieces and " (" .. pieces .. ")" or "", solde), court = "Gagné " .. texte.quantite(gain, unite) .. " !",
      couleur = R.bon }
  end
  if gain == mise then
    return { texte = libelle .. " : mise rendue. Solde " .. solde .. ".", court = "Mise rendue.", couleur = R.info }
  end
  return { texte = string.format("%s : perdu %s. Solde %s.", libelle, texte.quantite(mise - gain, unite), solde),
    court = "Perdu " .. texte.quantite(mise - gain, unite) .. ".", couleur = R.mauvais }
end

--- Mise en page de l'écran des règles : un seul bouton pour revenir au jeu.
function base.disposer_regles(largeur, hauteur)
  return base.chrome(largeur, hauteur, {
    { cle = "fermer", libelle = "Retour au jeu", court = "Retour", style = "principal", action = { type = "regles" } },
  })
end

--- Règles `regles` { intro, entrees { texte, couleur }, pied } dans un panneau sur le contenu du plan. Les entrées
--- se rangent en colonnes ; les lignes vides tombent d'abord quand la place manque.
function base.dessiner_regles(cible, plan, titre, regles)
  local c = plan.contenu
  local zone = panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, "Règles : " .. titre)
  local largeur_colonne = 0
  for _, entree in ipairs(regles.entrees) do
    largeur_colonne = math.max(largeur_colonne, panneaux.longueur(entree.texte) + 3)
  end
  local colonnes = math.max(1, math.floor((zone.largeur + 3) / largeur_colonne))
  local rangees = math.ceil(#regles.entrees / colonnes)
  local vides = math.max(0, math.min(2, zone.hauteur - #regles.intro - rangees - #regles.pied))
  local y = zone.y
  local function ligne(texte, couleur)
    if y < zone.y + zone.hauteur then
      dessin.ecrire(cible, zone.x, y, dessin.tronquer(texte, zone.largeur), couleur, R.surface)
    end
    y = y + 1
  end
  for _, texte in ipairs(regles.intro) do ligne(texte, R.texte) end
  if vides >= 1 then y = y + 1 end
  for i, entree in ipairs(regles.entrees) do
    local colonne, rangee = math.floor((i - 1) / rangees), (i - 1) % rangees
    if y + rangee < zone.y + zone.hauteur then
      dessin.ecrire(cible, zone.x + colonne * largeur_colonne, y + rangee,
        dessin.tronquer(entree.texte, largeur_colonne - 1), entree.couleur or R.moyen, R.surface)
    end
  end
  y = y + rangees
  if vides >= 2 then y = y + 1 end
  for _, texte in ipairs(regles.pied) do ligne(texte, R.info) end
end

--- Message pleine cible quand elle est sous la taille minimale.
function base.trop_petit(cible, largeur, hauteur)
  local lignes = {
    { "Moniteur trop petit", R.alerte },
    { string.format("Il faut %d x %d cases, ici %d x %d.", base.MIN.largeur, base.MIN.hauteur, largeur, hauteur), R.texte },
    { "Ajoute des blocs de moniteur", R.discret },
    { "ou baisse echelle_texte.", R.discret },
  }
  local haut = math.max(1, math.floor((hauteur - #lignes) / 2) + 1)
  for i, ligne in ipairs(lignes) do base.centrer(cible, 1, haut + i - 1, largeur, ligne[1], ligne[2], R.fond) end
end

return base
