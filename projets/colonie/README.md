# Colonie

Livre dans la colonie les objets que les colons demandent, depuis ton réseau AE2, et affiche l'état sur un moniteur.

## Matériel à poser

- Un ordinateur avancé.
- Un moniteur avancé collé à l'ordinateur.
- Un Colony Integrator (Advanced Peripherals) posé dans la colonie, collé à l'ordinateur ou relié par modem filaire.
- Un ME Bridge (Advanced Peripherals) relié au réseau AE2, collé à l'ordinateur ou relié par modem filaire.
- Un inventaire de livraison collé au pont ME : un casier (rack) de l'entrepôt de la colonie, ou un coffre vidé vers
  l'entrepôt. Les coursiers ne servent une requête que si l'objet est dans l'entrepôt.
- Des modems filaires et du câble seulement si les périphériques ne touchent pas l'ordinateur.

## Installation

Le dépôt doit être public. Sur l'ordinateur :

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua colonie
```

L'ordinateur lance ensuite la colonie à chaque démarrage. Relancer la commande met à jour.

## Réglages

Ils sont dans `/colonie.cfg`, créé au premier lancement et jamais écrasé par une mise à jour.
La liste et le sens de chaque réglage sont dans `projets/colonie/reglages.lua`.

## Diagnostic

Si l'affichage reste vide ou si un périphérique n'est pas reconnu :

```
/colonie/diag
```

Le programme liste les méthodes du Colony Integrator et du pont ME, lit leurs données sans rien modifier,
et écrit le résultat dans `/diag.txt` (3 premiers éléments de chaque liste).
