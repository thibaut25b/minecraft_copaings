-- Crash : point d'explosion tiré d'avance, multiplicateur qui monte avec le temps, sans rien afficher.
-- Loi du point : P(point > m) = floor(RETOUR x TIRAGES / m) / TIRAGES, soit 0,97 / m (m en centièmes, de 1,00 au plafond).

local crash = {}

--- Part reversée en moyenne, en pour cent du multiplicateur visé (l'avantage de la maison est le reste).
crash.RETOUR = 97
--- Nombre de tirages équiprobables du point d'explosion.
crash.TIRAGES = 10000
--- Multiplicateur maximal, en centièmes : atteint, la mise est encaissée d'office.
crash.PLAFOND = 10000
--- Croissance du multiplicateur, par seconde : multiplicateur(t) = exp(VITESSE x t).
crash.VITESSE = 0.12

--- Point d'explosion en centièmes (100 = x1,00) tiré avec `hasard(n)`, entier uniforme de 1 à n.
function crash.point(hasard)
  local reste = crash.TIRAGES - hasard(crash.TIRAGES) + 1
  local point = math.floor(crash.RETOUR * crash.TIRAGES / reste) + 1
  return math.max(100, math.min(crash.PLAFOND, point))
end

--- Multiplicateur continu après `secondes`.
function crash.courbe(secondes)
  return math.exp(crash.VITESSE * math.max(0, secondes))
end

--- Multiplicateur affiché après `secondes`, en centièmes, borné au plafond.
function crash.multiplicateur(secondes)
  return math.min(crash.PLAFOND, math.floor(100 * crash.courbe(secondes) + 1e-9))
end

--- Secondes qu'il faut pour atteindre le multiplicateur `centiemes`.
function crash.instant(centiemes)
  return math.log(centiemes / 100) / crash.VITESSE
end

--- Gain total (mise comprise) d'une mise encaissée à `centiemes`, arrondi à l'entier inférieur.
function crash.gain(mise, centiemes)
  return math.floor(mise * centiemes / 100)
end

--- Le joueur qui encaisse à `centiemes` gagne si le point d'explosion est au-dessus.
function crash.gagne(centiemes, point)
  return centiemes < point
end

--- Gain d'un tour où le joueur ne touche à rien : encaissé d'office au plafond, perdu sinon.
function crash.gain_sans_geste(mise, point)
  return point >= crash.PLAFOND and crash.gain(mise, crash.PLAFOND) or 0
end

--- Texte d'un multiplicateur : 142 donne « x1.42 ».
function crash.texte(centiemes)
  return string.format("x%d.%02d", math.floor(centiemes / 100), centiemes % 100)
end

--- Règles affichables : intro, entrées ({ texte }), pied.
function crash.regles()
  return {
    intro = { "Le multiplicateur monte jusqu'à l'explosion.", "ENCAISSE avant : mise x multiplicateur." },
    entrees = {
      { texte = "Explosion possible dès " .. crash.texte(100) },
      { texte = "Plafond " .. crash.texte(crash.PLAFOND) .. " : encaissé d'office" },
    },
    pied = { string.format("Loi : P(dépasser x m) = 0,%02d / m.", crash.RETOUR),
      string.format("Retour au joueur : %d %%, toute cible.", crash.RETOUR) },
  }
end

return crash
