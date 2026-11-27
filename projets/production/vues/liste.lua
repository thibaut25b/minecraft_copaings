-- Liste paginée de la vue (lignes classées ou alertes) : colonnes adaptées à la largeur, mini-courbe, ligne touchable.

local dessin = require("commun.dessin")
local graphes = require("commun.graphes")
local pagination = require("commun.pagination")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local flux = require("production.flux")
local base = require("production.vues.base")

local R = theme.ROLES

local liste = {}

--- Durée couverte par la mini-courbe d'une ligne, en secondes.
liste.DUREE_COURBE = 600

local LARGEUR_NOM_MINI = 12 -- en dessous, la colonne du nom passe avant les autres
local LARGEUR_NOM_MAXI = 24 -- un nom plus long peut être coupé pour garder les colonnes
local LARGEUR_COURBE = 10

-- Colonnes retenues, de la plus riche à la plus sobre : la première qui tient gagne.
local CHOIX = {
  prod = { { "rang", "nom", "stock", "prod", "courbe" }, { "rang", "nom", "stock", "prod" }, { "nom", "stock", "prod" },
    { "nom", "prod" } },
  conso = { { "rang", "nom", "stock", "conso", "courbe" }, { "rang", "nom", "stock", "conso" },
    { "nom", "stock", "conso" }, { "nom", "conso" } },
  bilan = { { "rang", "nom", "stock", "prod", "conso", "net", "courbe" }, { "rang", "nom", "stock", "prod", "conso", "net" },
    { "rang", "nom", "stock", "net", "courbe" }, { "rang", "nom", "stock", "net" }, { "nom", "stock", "net" },
    { "nom", "net" } },
  alertes = { { "nom", "stock", "net", "rupture" }, { "nom", "net", "rupture" }, { "nom", "rupture" } },
}

-- Valeurs de la mini-courbe : production (consommation pour le sens "conso") par minute entière, alignée sur le
-- temps absolu comme les cases de `flux` (stable d'une mesure à l'autre) ; la minute la plus ancienne, incomplète,
-- est omise.
local function valeurs_courbe(etat, cle, sens)
  local champ = sens == "conso" and "consommation" or "production"
  local largeur = flux.FINES.largeur
  local par_minute = 60 / largeur
  local barres = flux.barres(etat.flux, cle, liste.DUREE_COURBE, etat.instant)
  local derniere = math.ceil(etat.instant / largeur) - 1
  local valeurs, membres, courante = {}, 0, nil
  for k, barre in ipairs(barres) do
    local minute = math.floor((derniere - #barres + k) / par_minute)
    if minute ~= courante then
      if courante ~= nil and membres < par_minute then valeurs[#valeurs] = nil end
      valeurs[#valeurs + 1], membres, courante = 0, 0, minute
    end
    valeurs[#valeurs] = valeurs[#valeurs] + barre[champ]
    membres = membres + 1
  end
  return valeurs
end

-- Cellules de chaque sorte de colonne : titre, alignement et texte, couleur d'une ligne de rang `i`.
local function sortes(etat)
  local unite = etat.unite
  return {
    rang = { "#", "droite", function(_, i) return tostring(i), R.discret end },
    nom = { "Objet", "gauche", function(ligne) return ligne.nom, R.texte end },
    stock = { "Stock", "droite", function(ligne) return texte.milliers(ligne.stock), R.texte end },
    prod = { "Prod", "droite", function(ligne)
      return base.texte_debit(ligne.production, ligne.partiel, unite), base.couleur_debit(ligne.production, unite)
    end },
    conso = { "Conso", "droite", function(ligne)
      return base.texte_debit(-ligne.consommation, ligne.partiel, unite), base.couleur_debit(-ligne.consommation, unite)
    end },
    net = { "Net", "droite", function(ligne)
      return base.texte_debit(ligne.net, ligne.partiel, unite), base.couleur_debit(ligne.net, unite)
    end },
    rupture = { "Rupture", "droite", function(ligne) return base.duree(ligne.avant_rupture), R.alerte end },
    courbe = { base.duree(liste.DUREE_COURBE), "gauche", nil },
  }
end

--- Géométrie de la liste `lignes` dans `zone`, entête en tête si `avec_entete` : { zone, corps, entete, decoupe,
--- commande, zones }. Une ligne touchée choisit son objet ; la page demandée se lit dans `etat.pagination[nom]`.
function liste.disposer(zone, lignes, nom, demandee, avec_entete)
  local entete = avec_entete and zone.hauteur >= 4
  local corps = { x = zone.x, y = zone.y + (entete and 1 or 0), largeur = zone.largeur,
    hauteur = zone.hauteur - (entete and 1 or 0) }
  local decoupe = pagination.decouper(#lignes, corps.hauteur, demandee)
  local zones = {}
  for i = decoupe.debut, decoupe.fin do
    local y = corps.y + i - decoupe.debut
    zones[#zones + 1] = { x1 = corps.x, x2 = corps.x + corps.largeur - 1, y1 = y, y2 = y,
      action = { type = "selection", cle = lignes[i].cle } }
  end
  local commande = decoupe.commande and corps.hauteur >= 1
    and pagination.commande(corps.x, corps.y + corps.hauteur - 1, corps.largeur, decoupe) or nil
  for _, bouton in ipairs(commande and { commande.precedent, commande.suivant } or {}) do
    zones[#zones + 1] = { x1 = bouton.x1, x2 = bouton.x2, y1 = bouton.y, y2 = bouton.y,
      action = { type = "pagination", liste = nom, page = bouton.page } }
  end
  return { zone = zone, corps = corps, entete = entete, decoupe = decoupe, commande = commande, zones = zones,
    lignes = lignes }
end

-- Colonnes posées { sorte, x, largeur } et textes de la page : la première combinaison de `choix` où les noms de la
-- page tiennent entiers, sinon la première où le nom garde LARGEUR_NOM_MINI cases.
local function poser(plan, etat, choix)
  local definitions, decoupe = sortes(etat), plan.decoupe
  local textes, largeurs = {}, {}
  for _, colonnes in ipairs(choix) do
    for _, sorte in ipairs(colonnes) do
      if not largeurs[sorte] and sorte ~= "nom" then
        local definition = definitions[sorte]
        local plus = panneaux.longueur(definition[1])
        textes[sorte] = {}
        if sorte == "courbe" then plus = LARGEUR_COURBE end
        for i = decoupe.debut, decoupe.fin do
          if definition[3] then
            local valeur, couleur = definition[3](plan.lignes[i], i)
            textes[sorte][i] = { valeur, couleur }
            plus = math.max(plus, panneaux.longueur(valeur))
          end
        end
        largeurs[sorte] = plus
      end
    end
  end
  local nom_entier = LARGEUR_NOM_MINI
  for i = decoupe.debut, decoupe.fin do
    nom_entier = math.max(nom_entier, math.min(LARGEUR_NOM_MAXI, panneaux.longueur(plan.lignes[i].nom)))
  end
  local largeur = plan.zone.largeur
  for passe, nom_voulu in ipairs({ nom_entier, LARGEUR_NOM_MINI }) do
    for numero, colonnes in ipairs(choix) do
      local fixe = 0
      for _, sorte in ipairs(colonnes) do
        if sorte ~= "nom" then fixe = fixe + largeurs[sorte] + 1 end
      end
      if largeur - fixe >= nom_voulu or (passe == 2 and numero == #choix) then
        local posees, x = {}, plan.zone.x
        for _, sorte in ipairs(colonnes) do
          local taille = sorte == "nom" and math.max(1, largeur - fixe) or largeurs[sorte]
          posees[#posees + 1] = { sorte = sorte, x = x, largeur = taille, definition = definitions[sorte] }
          x = x + taille + 1
        end
        return posees, textes
      end
    end
  end
end

local function courbe(cible, etat, colonne, y, cle, sens, fond)
  local valeurs = valeurs_courbe(etat, cle, sens)
  local haut = 0
  for _, valeur in ipairs(valeurs) do haut = math.max(haut, valeur) end
  if haut <= 0 then return end
  panneaux.toile(cible, { x = colonne.x, y = y, largeur = colonne.largeur, hauteur = 1 }, fond,
    function(toile, lpx, hpx)
      graphes.histogramme(toile, { x = 1, y = 1, largeur = lpx, hauteur = hpx }, valeurs,
        { couleur = sens == "conso" and R.mauvais or R.bon, min = 0, max = haut, ecart = 1 })
    end)
end

--- Dessine la liste disposée sur `fond`, la ligne de `choisi` en évidence. `sorte` : "prod", "conso", "bilan" (lignes
--- classées) ou "alertes".
function liste.dessiner(cible, plan, etat, sorte, choisi, fond)
  local decoupe = plan.decoupe
  local colonnes, textes = poser(plan, etat, CHOIX[sorte])
  if plan.entete then
    for _, colonne in ipairs(colonnes) do
      dessin.ecrire(cible, colonne.x, plan.zone.y, dessin.aligner(colonne.definition[1], colonne.largeur,
        colonne.definition[2]), R.discret, fond)
    end
  end
  for i = decoupe.debut, decoupe.fin do
    local ligne = plan.lignes[i]
    local y = plan.corps.y + i - decoupe.debut
    local fond_ligne = ligne.cle == choisi and R.bordure or fond
    panneaux.rectangle(cible, plan.zone.x, y, plan.zone.largeur, 1, fond_ligne)
    for _, colonne in ipairs(colonnes) do
      if colonne.sorte == "courbe" then
        if etat.flux and etat.instant then courbe(cible, etat, colonne, y, ligne.cle, sorte, fond_ligne) end
      elseif colonne.sorte == "nom" then
        dessin.ecrire(cible, colonne.x, y, dessin.tronquer(ligne.nom, colonne.largeur), R.texte, fond_ligne)
      else
        local cellule = textes[colonne.sorte][i]
        dessin.ecrire(cible, colonne.x, y, dessin.aligner(cellule[1], colonne.largeur, colonne.definition[2]),
          cellule[2], fond_ligne)
      end
    end
  end
  if plan.commande then pagination.dessiner(cible, plan.commande, fond) end
end

-- Paragraphe `texte` coupé aux espaces en lignes de `largeur` cases au plus (un mot trop long est tronqué).
local function couper(texte_brut, largeur)
  local lignes, courante = {}, ""
  for mot in texte_brut:gmatch("%S+") do
    local essai = courante == "" and mot or courante .. " " .. mot
    if panneaux.longueur(essai) <= largeur or courante == "" then
      courante = essai
    else
      lignes[#lignes + 1] = courante
      courante = mot
    end
  end
  if courante ~= "" then lignes[#lignes + 1] = courante end
  return lignes
end

--- Écrit le message d'état `message` en texte dans `zone`, coupé aux espaces ; ce qui ne tient pas est omis.
function liste.message(cible, zone, message, fond)
  for i, ligne in ipairs(couper(message, zone.largeur)) do
    if i > zone.hauteur then return end
    dessin.ecrire(cible, zone.x, zone.y + i - 1, dessin.tronquer(ligne, zone.largeur), R.texte, fond)
  end
end

return liste
