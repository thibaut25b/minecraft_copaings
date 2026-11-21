-- Blackjack contre la banque : sabot, valeur des mains, jeu de la banque et règlement, sans rien afficher.

local blackjack = {}

--- Couleurs des cartes, dans l'ordre du jeu neuf.
blackjack.COULEURS = { "pique", "coeur", "carreau", "trefle" }
--- Rangs : 1 = as, 11 = valet, 12 = dame, 13 = roi.
blackjack.LIBELLES = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R" }
--- Le sabot est remélangé avant un tour quand il en reste moins que cette part.
blackjack.REMELANGE = 0.25
--- La banque tire tant qu'elle a moins que ce total, et reste sur 17 souple.
blackjack.BANQUE_RESTE = 17
--- Gain total d'un blackjack naturel : mise x 5 / 2 (3 pour 2), arrondi à l'entier inférieur.
blackjack.NATUREL = { 5, 2 }

--- Sabot neuf de `jeux` jeux de 52 cartes, mélangé avec `hasard(n)` (entier uniforme de 1 à n).
function blackjack.sabot(jeux, hasard)
  local cartes = {}
  for _ = 1, jeux do
    for _, couleur in ipairs(blackjack.COULEURS) do
      for rang = 1, 13 do cartes[#cartes + 1] = { rang = rang, couleur = couleur } end
    end
  end
  for i = #cartes, 2, -1 do
    local j = hasard(i)
    cartes[i], cartes[j] = cartes[j], cartes[i]
  end
  return { cartes = cartes, position = 1 }
end

--- Vrai si le sabot doit être remélangé avant un nouveau tour.
function blackjack.a_remelanger(sabot)
  return #sabot.cartes - sabot.position + 1 < #sabot.cartes * blackjack.REMELANGE
end

--- Carte suivante du sabot (copie), qui avance.
function blackjack.tirer(sabot)
  local carte = sabot.cartes[sabot.position]
  if not carte then error("sabot vide", 2) end
  sabot.position = sabot.position + 1
  return { rang = carte.rang, couleur = carte.couleur }
end

--- Valeur d'une main : total (un as vaut 11 tant que la main ne dépasse pas 21, sinon 1) et vrai si la main est
--- souple (un as y compte pour 11).
function blackjack.valeur(main)
  local total, as = 0, false
  for _, carte in ipairs(main) do
    total = total + math.min(10, carte.rang)
    as = as or carte.rang == 1
  end
  if as and total + 10 <= 21 then return total + 10, true end
  return total, false
end

--- Vrai pour un blackjack naturel : deux cartes qui font 21.
function blackjack.naturel(main)
  return #main == 2 and blackjack.valeur(main) == 21
end

--- Cartes que tire la banque à partir de sa `main`, lues dans `sabot` sans le faire avancer.
function blackjack.tirage_banque(main, sabot)
  local copie, tirees = {}, {}
  for i, carte in ipairs(main) do copie[i] = carte end
  local apercu = { cartes = sabot.cartes, position = sabot.position }
  while blackjack.valeur(copie) < blackjack.BANQUE_RESTE do
    local carte = blackjack.tirer(apercu)
    copie[#copie + 1] = carte
    tirees[#tirees + 1] = carte
  end
  return tirees
end

--- Règlement d'une main finie : gain total (mise comprise) et issue parmi "blackjack", "banque_blackjack", "egalite",
--- "depasse", "banque_depasse", "gagne", "perdu".
function blackjack.regler(joueur, banque, mise)
  local naturel_joueur, naturel_banque = blackjack.naturel(joueur), blackjack.naturel(banque)
  if naturel_joueur and naturel_banque then return mise, "egalite" end
  if naturel_joueur then return math.floor(mise * blackjack.NATUREL[1] / blackjack.NATUREL[2]), "blackjack" end
  if naturel_banque then return 0, "banque_blackjack" end
  local total_joueur, total_banque = blackjack.valeur(joueur), blackjack.valeur(banque)
  if total_joueur > 21 then return 0, "depasse" end
  if total_banque > 21 then return 2 * mise, "banque_depasse" end
  if total_joueur > total_banque then return 2 * mise, "gagne" end
  if total_joueur < total_banque then return 0, "perdu" end
  return mise, "egalite"
end

--- Gain si le joueur reste maintenant : la banque joue avec les cartes du sabot, sans le faire avancer.
function blackjack.gain_si_reste(joueur, banque, sabot, mise)
  if blackjack.valeur(joueur) > 21 or blackjack.naturel(joueur) or blackjack.naturel(banque) then
    return (blackjack.regler(joueur, banque, mise))
  end
  local finale = {}
  for i, carte in ipairs(banque) do finale[i] = carte end
  for _, carte in ipairs(blackjack.tirage_banque(banque, sabot)) do finale[#finale + 1] = carte end
  return (blackjack.regler(joueur, finale, mise))
end

--- Libellé court d'une carte : « 10 », « D ».
function blackjack.libelle(carte)
  return blackjack.LIBELLES[carte.rang]
end

--- Règles affichables : intro, entrées ({ texte }), pied.
function blackjack.regles()
  return {
    intro = { "Approche 21 sans le dépasser.", "Figures : 10. As : 1 ou 11." },
    entrees = {
      { texte = "Blackjack : x2,5 (3 pour 2)" }, { texte = "Main gagnante : x2" },
      { texte = "Égalité : mise rendue" }, { texte = "Doubler : une carte de plus" },
      { texte = "Gain arrondi au jeton inférieur" },
    },
    pied = { "La banque tire jusqu'à 17, reste sur 17.", "Retour estimé : 99 % en jouant bien." },
  }
end

return blackjack
