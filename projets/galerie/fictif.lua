-- Données fictives des écrans de la galerie : toutes périodiques en `t`, pour que chaque animation boucle sans saut.

local fictif = {}

local DEUX_PI = 2 * math.pi

--- Valeur dans -1..1 environ, de période `periode`, dont la forme dépend de `graine` (harmoniques entières).
function fictif.vague(x, periode, graine)
  local angle = DEUX_PI * x / periode
  return 0.5 * math.sin(angle + graine) + 0.28 * math.sin(2 * angle + 1.7 * graine)
    + 0.14 * math.sin(3 * angle + 2.3 * graine) + 0.08 * math.sin(7 * angle + 3.1 * graine)
    + 0.05 * math.sin(13 * angle + 4.7 * graine)
end

--- Historique de `nombre` valeurs qui finit à l'image `t` : il défile d'un pas par image et boucle avec `periode`.
function fictif.serie(t, periode, nombre, graine, centre, amplitude)
  local valeurs = {}
  for i = 1, nombre do valeurs[i] = centre + amplitude * fictif.vague(t - nombre + i, periode, graine) end
  return valeurs
end

--- Vrai pendant la première moitié de chaque période de `periode` images.
function fictif.clignote(t, periode)
  return t % periode < periode / 2
end

--- Vrai si l'image `t` est dans [debut, fin[.
function fictif.pendant(t, debut, fin)
  return t >= debut and t < fin
end

--- Horloge « HH:MM » dont les deux-points clignotent toutes les cinq images.
function fictif.horloge(t, heures, minutes)
  return string.format(fictif.clignote(t, 10) and "%02d:%02d" or "%02d %02d", heures, minutes)
end

return fictif
