-- Prix des offres : lesquels régler, sous quelle forme, et la mémoire des refus pour ne pas marteler le serveur.

local prix = {}

--- Valeur à passer à setPrice pour `credits` crédits de la pièce de compte : « coin;12-lightmanscurrency:coin_copper ».
function prix.valeur(credits, piece)
  return ("coin;%d-%s"):format(credits, piece)
end

--- Prix voulu (en crédits) de l'offre : `articles[objet].prix` de son premier objet, ou nil s'il n'y en a pas.
function prix.voulu(offre, articles)
  local article = type(articles) == "table" and articles[offre.objets[1].objet] or nil
  local voulu = type(article) == "table" and article.prix or nil
  if type(voulu) ~= "number" or voulu < 0 then return nil end
  return math.floor(voulu)
end

--- Décisions pour les offres du comptoir `nom`. `refus` = { [cle] = { voulu, actuel } } des refus passés (cle =
--- « nom#indice »). Renvoie { a_regler = { { cle, offre, prix, valeur } }, refusees = { cle, ... } } : une offre
--- déjà refusée n'est pas retentée tant que le prix voulu et le prix lu n'ont pas changé.
function prix.decider(nom, offres, reglages, refus)
  local decision = { a_regler = {}, refusees = {} }
  for _, offre in ipairs(offres) do
    local voulu = prix.voulu(offre, reglages.articles)
    if voulu and voulu ~= offre.prix then
      local cle = nom .. "#" .. offre.indice
      local passe = refus[cle]
      if passe and passe.voulu == voulu and passe.actuel == offre.prix then
        decision.refusees[#decision.refusees + 1] = cle
      else
        decision.a_regler[#decision.a_regler + 1] = { cle = cle, offre = offre, prix = voulu,
          valeur = prix.valeur(voulu, reglages.piece_de_compte) }
      end
    end
  end
  return decision
end

return prix
