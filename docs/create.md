# Create 6.0.10 et Create Crafts & Additions 1.7.2 : API ComputerCraft (MC 1.21.1, NeoForge, CC:T 1.120.2)

Source : bytecode de `create-1.21.1-6.0.10.jar`, `createaddition-1.7.2.jar`, `cc-tweaked-1.21.1-forge-1.120.2.jar`. Classes Create relatives à `com/simibubi/create/` (abrégé `C/`), compat CC = `C/compat/computercraft/implementation/` (abrégé `cc/`). Create Additions = `com/mrh0/createaddition/compat/computercraft/` (abrégé `CA/`). Aucune annotation `@LuaFunction(value=...)` dans Create ni dans Create Additions : nom Lua = nom Java. Tout ce qui n'est pas lu dans le bytecode est en section finale.

## Réponses de conception

1. **Stress et vitesse** : Stressomètre (`Create_Stressometer`) : `getStress()`, `getStressCapacity()` (floats, surcharge si `capacité < stress`). Speedomètre (`Create_Speedometer`) : `getSpeed()` (RPM signé, 0 si surchargé). Mieux : écouter `stress_change`, `overstressed`, `speed_change`.
2. **Stock** : Stock Ticker (`Create_StockTicker`) : `stock()` = tout l'inventaire du réseau logistique, `{[i] = {name, count, ...}}`, 1-based ; `stock(true)` = détails complets.
3. **Livraison** : `stockTicker.requestFiltered(adresse, filtre1, filtre2, ...)`, filtre = table comparée aux détails d'objet, `_requestCount` = quantité max. Retour = nombre d'objets demandés. Autre voie : Redstone Requester (`setRequest`, `setAddress`, `request()`).
4. **Couper une ligne** : relais redstone CC:T (`redstone_relay`) : `setOutput(côté, true)` vers un embrayage ou un changement de vitesse ; relancer avec `false`. Attention : Create Additions a aussi un type `redstone_relay` (relais d'énergie, sans sortie redstone).
5. **Nappe (Table Cloth)** : `Create_TableClothShop` : lire/régler l'objet vendu (`getWares`/`setWares`), le prix (`getPriceTagItem`/`setPriceTagItem`, `getPriceTagCount`/`setPriceTagCount` 1..100), l'adresse de livraison (`getAddress`/`setAddress`).
6. **Achat** : aucun événement sur la nappe. L'ordinateur voit l'achat par (a) le paiement arrivé dans le Stock Ticker (`stockTicker.list()`), (b) `package_created` sur le Packager qui prépare le colis.

## 0. Règles communes

| Point | Constat (classe) |
|---|---|
| Attachement Create | Capacité `PeripheralCapability` enregistrée par chaque BE (`registerCapabilities`) ; le lambda ignore la face (`lambda$registerCapabilities$0(BE, Direction)` -> `computerBehaviour.getPeripheralCapability()`). Ordinateur adjacent OU modem filaire sur n'importe quelle face |
| BE avec capacité (grep `PeripheralCapability`) | Sticker, SpeedGauge, StressGauge, CreativeMotor, SpeedController, SequencedGearshift, Frogport, Packager, Repackager, RedstoneRequester, StockTicker, TableCloth, DisplayLink, NixieTube, TrackObserver, Signal, Station. **Pas de Postbox** (voir 2.7) |
| Création | `cc/ComputerBehaviour.getPeripheralFor` : un `instanceof` par BE ; sinon exception "No peripheral available for ..." |
| Attachement Create Additions | `CA/Peripherals.registerPeripheralCapabilities` : Electric Motor, Portable Energy Interface, Modular Accumulator, Redstone Relay, Digital Adapter, Servo Motor ; lambda `(BE, Direction)` (face non lue, voir Non vérifié) |
| Événements Create | `cc/peripherals/SyncedPeripheral.queueEvent` ajoute le **nom d'attachement du périphérique en 1er paramètre** : `os.pullEvent()` -> `nomEvénement, nomPériphérique, args...`. Envoyé à tous les ordinateurs attachés |
| `mainThread` | Indiqué par méthode ci-dessous ; sans `mainThread` la lecture se fait hors thread serveur |
| Objets Lua | `PackageLuaObject`, `PackageOrderLuaObject` : objets Java à méthodes `@LuaFunction` (table de fonctions côté Lua) |
| Statut BE | Un ordinateur attaché met `hasAttachedComputer` (`AbstractComputerBehaviour`), synchronisé aux clients (`AttachedComputerPacket`) : l'interface du bloc affiche le mode ordinateur |

### Forme d'un objet (CC:T `shared/details/ItemDetails`)

| Fonction | Clés |
|---|---|
| basique (`fillBasic`) | `name` (string `mod:id`), `count` (number), `nbt` (string, hash des composants, absent si aucun) |
| complète (`fill`) | basique + `displayName`, `maxCount`, `damage`, `maxDamage`, `durability`, `tags` (`{["c:ingots"]=true}`), `itemGroups`, `lore`, `enchantments`, `potionEffects`, `unbreakable` (selon l'objet) |
| ajout Create | Colis : clé `package` = objet colis (2.4), sans packager (non modifiable) (`ComputerBehaviour.registerItemDetailProviders`) |

- Listes Create `{[slot] = détailsBasiques}` : `ComputerUtil.list(IItemHandler)`, slots 1-based, slots vides absents.
- `getItemDetail(slot)` : `ComputerUtil.getItemDetail`, slot 1-based, `nil` si vide, erreur `Slot <n> out of range, available slots between 1 and <max>`.
- Stock (`BigItemStack`) : `count` remplacé par la quantité réelle, peut dépasser 64.

## 1. Cinétique

| Type CC | Bloc | Méthode Lua | Retour / arguments | Thread |
|---|---|---|---|---|
| `Create_Stressometer` | Stressomètre (`StressGaugePeripheral`) | `getStress()` | float, champ `stress` du réseau | non |
| | | `getStressCapacity()` | float, champ `capacity` du réseau | non |
| `Create_Speedometer` | Speedomètre (`SpeedGaugePeripheral`) | `getSpeed()` | float RPM signé (`KineticBlockEntity.getSpeed`) | non |
| `Create_RotationSpeedController` | Contrôleur de vitesse (`SpeedControllerPeripheral`) | `setTargetSpeed(int)` | `ScrollValueBehaviour.setValue` | oui |
| | | `getTargetSpeed()` | float | non |
| `Create_CreativeMotor` | Moteur créatif (`CreativeMotorPeripheral`) | `setGeneratedSpeed(int)` / `getGeneratedSpeed()` | idem | oui / non |
| `Create_SequencedGearshift` | Boîte séquencée (`SequencedGearshiftPeripheral`) | `rotate(angle, [mod])` | angle en degrés, `abs` appliqué | oui |
| | | `move(distance, [mod])` | distance en blocs, `abs` appliqué | oui |
| | | `isRunning()` | bool (`not isIdle()`) | non |
| `Create_Sticker` | Sticker (`StickerPeripheral`) | `isExtended()`, `isAttachedToBlock()` | bool | non |
| | | `extend()`, `retract()`, `toggle()` | bool | oui |

- `rotate`/`move` : efface le programme du bloc, met 1 instruction + `END`, lance `run(0)`. Sens et vitesse par `mod` (défaut 1) : `2` = avant rapide, `1` = avant, `-1` = arrière, `-2` = arrière rapide ; toute autre valeur = avant (`InstructionSpeedModifiers.getByModifier`, `orElse(FORWARD)`). Le signe de `angle` est ignoré.

### Stress et vitesse (`KineticBlockEntity`, `StressGaugeBlockEntity`)

| Situation | `getStress` | `getStressCapacity` | `getSpeed` |
|---|---|---|---|
| Normal | demande du réseau | capacité du réseau | RPM signé |
| Surcharge (`capacity < stress` et stress activé) | demande (reste > capacité) | capacité | 0 |
| Monde gelé (`tickRateManager.isFrozen`) | inchangé | inchangé | 0 |
| Bloc hors réseau (`clearKineticInformation`) | 0 | 0 | 0 |

- Surcharge : `overStressed = capacity < stress && StressImpact.isEnabled()` (`updateFromNetwork`). Ratio affiché par le cadran : `stress / capacity`, 1.125 si surchargé.
- Signe de la vitesse : sens de rotation de l'arbre. Unité : RPM.

### Événements cinétiques (`KineticsChangeEvent(speed, capacity, stress, overStressed)`)

| Événement | Paramètres après le nom du périphérique | Émis |
|---|---|---|
| `stress_change` | stress (float), capacité (float) | Stressomètre, à chaque `updateFromNetwork` non surchargé |
| `overstressed` | aucun | Stressomètre, `updateFromNetwork` en surcharge (à chaque mise à jour, pas seulement au passage) |
| `speed_change` | vitesse (float, 0 si surchargé) | Speedomètre, à chaque `onSpeedChanged` |

Émis seulement si un ordinateur est attaché (`hasAttachedComputer`). Pas d'événement du stressomètre quand la vitesse tombe à 0 (`onSpeedChanged` sort avant `updateFromNetwork`).

```lua
local jauge = peripheral.find("Create_Stressometer")
local vitesse = peripheral.find("Create_Speedometer")
local stress, capacite = jauge.getStress(), jauge.getStressCapacity()
print(stress, capacite, capacite < stress, vitesse.getSpeed())
while true do
  local ev, nom, a, b = os.pullEvent()
  if ev == "stress_change" then print(nom, "stress", a, "/", b)
  elseif ev == "overstressed" then print(nom, "SURCHARGE")
  elseif ev == "speed_change" then print(nom, "rpm", a) end
end
```

## 2. Logistique

### 2.1 Stock Ticker (`Create_StockTicker`, `StockTickerPeripheral`, tout en `mainThread`)

| Méthode | Arguments | Retour |
|---|---|---|
| `stock([detaille])` | bool optionnel | `{[i] = détails + count}` de `getAccurateSummary().getStacks()` : stock de tout le réseau logistique ; i 1-based ; basique par défaut, complet si `true` |
| `getStockItemDetail(i)` | int 1-based (index de `stock()`) | détails complets + `count`, ou `nil` ; erreur slot hors bornes |
| `requestFiltered(adresse, filtre, ...)` | string, puis 1 à n tables | int = total d'objets mis dans la commande |
| `list()` | aucun | contenu des **paiements reçus** (`getReceivedPaymentsHandler`), `{[slot] = basique}` |
| `getItemDetail(slot)` | int 1-based | détail d'un slot des paiements |

`requestFiltered`, ordre exact :
1. Pour chaque filtre (arguments 2..n) : erreur `Filter must be a table` ou `Filter keys must be strings`.
2. `_requestCount` retiré du filtre : quantité max pour CE filtre (défaut `2147483647`) ; erreur `_requestCount must be a positive number or nil for no limit` si non nombre ou < 1.
3. Parcourt le stock ; pour chaque entrée qui correspond (`ComputerUtil.bigItemStackToLuaTableFilter`), prend `min(trouvé, reste)` et le retire du stock local : deux filtres ne prennent pas deux fois le même objet.
4. Envoie UNE commande `PackageOrder` (type `RESTOCK`) vers `adresse` (`broadcastPackageRequest`) aux packagers du réseau, même si vide.
5. Retourne le total demandé (pas une preuve de livraison).

### 2.2 Filtres (`cc/ComputerUtil`)

Le filtre est comparé aux détails COMPLETS de l'objet + `count` (quantité en stock). `name` sans `:` reçoit le préfixe `minecraft:`.

| Forme | Effet |
|---|---|
| table sans `_mode` | mode `contains` : chaque clé du filtre doit exister dans l'objet et correspondre |
| `_mode = "exact"` | mêmes clés exactement |
| `_mode = "contained"` | chaque clé de l'objet doit exister dans le filtre |
| `_mode` autre | erreur `Invalid match mode: <x>, expected 'exact', 'contained' or 'contains'` (insensible à la casse) |
| liste (table 1..n) | mode `contains` : chaque élément du filtre trouve un élément distinct |
| nombre | égalité en double |
| `{_op = "not", value = v}` | ne correspond pas à `v` |
| `{_op = "any" / "all", value = {v1, v2}}` | au moins un / tous ; erreur `<op> operator requires a list of values` |
| `{_op = "type", value = "nil"/"number"/"string"/"boolean"/"table"/"list"/"map"/"object"}` | test de type ; erreur `Type operator requires a string value`, `Unknown type: <x>` |
| `{_op = ">", ">=", "<", "<=", "==", "~=", value = n}` | comparaison numérique |
| `{_op = "glob" / "regex", value = motif}` | sur une chaîne (`Glob.toRegexPattern`, `String.matches` : motif sur toute la chaîne) |
| autre `_op` | `Unknown operator: <x>` ou `Operator <x> not supported for type <T>` |

Exemples : `{name = "iron_ingot"}`, `{tags = {["c:ingots"] = true}}`, `{name = {_op = "glob", value = "*:*_log"}}`, `{count = {_op = ">=", value = 64}}`.

```lua
local st = peripheral.find("Create_StockTicker")
local fer = 0
for _, obj in pairs(st.stock()) do
  if obj.name == "minecraft:iron_ingot" then fer = fer + obj.count end
end
local n = st.requestFiltered("Atelier", { name = "iron_ingot", _requestCount = 64 },
  { tags = { ["c:ingots/copper"] = true }, _requestCount = 32 })
print(fer, "en stock,", n, "demandés")
```

### 2.3 Packager et Repackager (`Create_Packager`, `Create_Repackager`, tout en `mainThread`)

| Méthode | Retour / effet |
|---|---|
| `makePackage()` | bool : `false` si un colis est déjà tenu ; sinon `activate()` puis `true` si un colis est créé |
| `list()` / `getItemDetail(slot)` | inventaire ciblé par le packager (`targetInventory`), 1-based |
| `getAddress()` | string : adresse lue sur le panneau (`updateSignAddress`, `signBasedAddress`) ou adresse imposée |
| `setAddress([adresse])` | impose l'adresse (`customComputerAddress`) ; `nil` ou sans argument rend la main au panneau |
| `getPackage()` | objet colis tenu, ou `nil` |

Attacher ou détacher un ordinateur remet `hasCustomComputerAddress = false` : l'adresse imposée est perdue au redémarrage de l'ordinateur.

| Événement | Paramètres après le nom | Émis par |
|---|---|---|
| `package_created` | colis | Packager, `attemptToSend` (colis créé) |
| `package_received` | colis | Packager / Repackager, `unwrapBox` (colis déballé) |
| `package_repackaged` | colis, count (int) | Repackager, `attemptToRepackage` (fragments recombinés) |

### 2.4 Objet colis (`cc/luaObjects/PackageLuaObject`, `mainThread`)

| Méthode | Retour |
|---|---|
| `isEditable()` | bool : vrai seulement si c'est le colis tenu par le packager d'origine |
| `getAddress()` | string |
| `setAddress(s)` | erreur `Package is not editable` sinon |
| `list()` / `getItemDetail(slot)` | contenu du colis, 1-based |
| `getOrderData()` | objet commande ou `nil` |

`hasOrderData` et `getLuaItemStacks` ne sont PAS exposés (pas d'`@LuaFunction`).

Objet commande (`PackageOrderLuaObject`) : `getOrderID()` (int), `getIndex()` (1-based, `+1`), `isFinal()`, `getLinkIndex()` (1-based), `isFinalLink()`, `list()` (`{[i] = basique + count}` ou `nil`), `getItemDetail(i)` (erreur `Slot out of range (1 or greater)`, `nil` au-delà), `getCrafts()` (`{[i] = {count = n, recipe = {[slot] = basique}}}`, cases `minecraft:air` absentes).

### 2.5 Redstone Requester (`Create_RedstoneRequester`, `mainThread`)

| Méthode | Arguments | Effet |
|---|---|---|
| `request()` | aucun | `triggerRequest()` : envoie la commande enregistrée |
| `setRequest(o1, ..., o9)` | 9 au plus | commande simple |
| `setCraftingRequest(n, o1, ..., o9)` | int puis 9 au plus | commande de fabrication, motif = objets à 1 exemplaire, `n` = nombre |
| `getRequest()` | | `{[i] = complet + count}`, cases vides absentes, i 1-based |
| `setAddress(s)` / `getAddress()` | string | adresse de livraison |
| `setConfiguration(s)` / `getConfiguration()` | `"allow_partial"` ou `"strict"` | sinon erreur `Unknown configuration: "<x>" Possible configurations are: "allow_partial" and "strict".` |

Objet de commande (`generateOrder`) : `nil` = case vide ; `"mod:id"` = 1 exemplaire ; `{name = "mod:id", count = n}` (défaut `minecraft:air`, 1) ; `count > 256` -> `Count for item <nom> exceeds 256`. Id inconnu = air, sans erreur.

### 2.6 Frogport (`Create_Frogport`, `mainThread`)

| Méthode | Retour / effet |
|---|---|
| `setAddress(s)` / `getAddress()` | filtre d'adresse (`addressFilter`) |
| `getConfiguration()` | `"send_recieve"` (orthographe du code) si accepte les colis, `"send"` sinon, `nil` sans cible |
| `setConfiguration(s)` | bool : `false` sans cible ; erreur `Unknown configuration: "<x>" Possible configurations are: "send_recieve" and "send".` |
| `list()` / `getItemDetail(slot)` | inventaire du Frogport, 1-based |

Événements : `package_sent` et `package_received` (nom, colis), émis par `FrogportBlockEntity.tick`.

### 2.7 Postbox (`Create_Postbox`)

Classe `PostboxPeripheral` : mêmes méthodes et événements que le Frogport (`GlobalStation.runMailTransfer` émet `package_sent` / `package_received`). **Aucune capacité `PeripheralCapability` enregistrée pour les Postbox dans le jar** : très probablement inaccessible à un ordinateur.

### 2.8 Nappe boutique (`Create_TableClothShop`, `TableClothShopPeripheral`, `mainThread`)

| Méthode | Arguments | Retour / effet |
|---|---|---|
| `isShop()` | | bool : commande enregistrée non vide |
| `getAddress()` / `setAddress(s)` | string | adresse de livraison des achats |
| `getWares()` | | `{[i] = complet + count}` des objets vendus |
| `setWares(o1, ..., o9)` | 9 au plus, `nil` ignoré, `{name, count}` | remplace l'offre ; `notifyShopUpdate` |
| `getPriceTagItem()` | | détails complets de l'objet monnaie |
| `setPriceTagItem([id])` | string ou rien (= air) | objet monnaie |
| `getPriceTagCount()` | | int, prix |
| `setPriceTagCount([n])` | nombre | borné `max(1, min(100, n))` ; sans argument = 1 |

- `assertShop` (erreur `TableCloth is not a shop!`) sur toutes les méthodes sauf `isShop` et `setWares` : `setWares` transforme une nappe en boutique.
- `setWares` : erreur `Tablecloth isn't empty.` si des objets posés à la main ; `Table or nil expected for each item entry` ; `Count for item <nom> exceeds 256` ; `Invalid item at index: <n>` (1-based) si id inconnu.
- Achat (`TableClothBlockEntity.useShop`) : le joueur clique avec une liste de courses ; messages `no_price_set`, `keeper_missing`, `out_of_stock`. **Aucun événement CC** pour un achat. Le paiement arrive dans les paiements du Stock Ticker (`stockTicker.list()`).
- Avec un ordinateur attaché, retirer le dernier objet posé ne supprime pas le BE de la nappe (`use`, test `hasAttachedComputer`).

## 3. Affichage

### Display Link (`Create_DisplayLink`, `DisplayLinkPeripheral`)

| Méthode | Arguments / retour | Thread |
|---|---|---|
| `setCursorPos(x, y)` | 1-based, erreur `cursor position must be larger then 0` | non |
| `getCursorPos()` | x, y (1-based) | non |
| `getSize()` | **lignes, colonnes** (ordre inverse de `term.getSize`) | oui |
| `isColor()` / `isColour()` | toujours `false` | non |
| `write(texte)` | écrit au curseur, avance x de la longueur, pas de retour à la ligne | non |
| `writeBytes(s ou {octets})` | octets (ASCII / UTF-8) ; erreur "string or table" | non |
| `clearLine()` / `clear()` | vide la ligne du curseur / tout | non |
| `update()` | `tickSource()` : pousse le texte vers l'affichage cible | oui |

- Le texte est un tampon : liste NBT `ComputerSourceList` dans la config de source du lien, complétée par des espaces. Rien ne s'affiche avant `update()` (ou le rafraîchissement passif du lien).
- Lu par `ComputerDisplaySource.provideText`. La source du lien doit donc être la source « ordinateur ».
- `getSize()` lève une erreur Java si aucune cible n'est liée (`activeTarget` nul).

### Nixie Tube (`Create_NixieTube`, `mainThread`)

`setText(texte, [couleur])`, `setTextColour(couleur)`, `setTextColor(couleur)` : couleur = nom `DyeColor` (`"grey"` accepté pour `"gray"`). `setSignal(premier, [second])` : tables `r`, `g`, `b` (0..255), `glowWidth`, `glowHeight`, `blinkPeriod` (0..255), `blinkOffTime` (0..255) ; erreur `field <k> must be in range <a>-<b>`. Le premier attachement vide la chaîne de tubes, le dernier détachement rend l'affichage redstone.

## 4. Trains (résumé)

| Type | Méthodes | Événements (après le nom) |
|---|---|---|
| `Create_Station` | `assemble`, `disassemble`, `setAssemblyMode(bool)`, `isInAssemblyMode`, `getStationName`, `setStationName`, `isTrainPresent`, `isTrainImminent`, `isTrainEnroute`, `getTrainName`, `setTrainName`, `hasSchedule`, `getSchedule`, `setSchedule(t)`, `canTrainReach(nom)`, `distanceTo(nom)` | `train_imminent`, `train_arrival`, `train_departure` : nom du train |
| `Create_Signal` | `getState` (`"RED"`, `"YELLOW"`, `"GREEN"`, `"INVALID"`), `isForcedRed`, `setForcedRed(bool)`, `listBlockingTrainNames`, `getSignalType`, `cycleSignalType` | `train_signal_state_change` : état |
| `Create_TrainObserver` | `isTrainPassing`, `getPassingTrainName` | `train_passing`, `train_passed` : nom du train |

Erreurs relevées : `station is not connected to a track`, `station must be in assembly mode`, `train doesn't have a schedule`, `Schedule must have at least one entry`, `no signal`.

## 5. Create Crafts & Additions 1.7.2

Types (`CA/Peripherals`) : `electric_motor`, `portable_energy_interface`, `modular_accumulator`, `redstone_relay`, `digital_adapter`, `servo_motor`. Toutes les méthodes sont `mainThread`. Aucun événement.

### Digital Adapter (`digital_adapter`, `DigitalAdapterPeripheral`)

Lit le BE voisin à `getBlockPos().relative(direction)` (`DigitalAdapterBlockEntity.getStressGauge`, etc.). Direction = argument string, **absolue** (`Helpers.nameToDir`, sensible à la casse) : `"down"`/`"bottom"`, `"up"`/`"top"`, `"south"`, `"east"`, `"west"` ; **toute autre chaîne = nord**. Bloc absent ou d'un autre type : retour 0 (ou valeur neutre), pas d'erreur.

| Méthode | Bloc voisin lu | Retour |
|---|---|---|
| `getKineticStress(dir)` / `getKineticCapacity(dir)` | Stressomètre | float |
| `getKineticSpeed(dir)` | Speedomètre | float RPM |
| `getTargetSpeed(dir)` / `setTargetSpeed(dir, rpm)` | Contrôleur de vitesse | int / rien |
| `getKineticTopSpeed()` | config `maxRotationSpeed` | int |
| `getPulleyDistance(dir)` | poulie à corde, à tuyau ou d'ascenseur | float (offset interpolé) |
| `getPistonDistance(dir)` | piston mécanique | float |
| `getBearingAngle(dir)` | roulement mécanique | float, degrés |
| `getElevatorFloor(dir)`, `hasElevatorArrived(dir)`, `getElevatorFloors(dir)` | poulie d'ascenseur | int, bool, int |
| `getElevatorFloorName(dir, i)` / `gotoElevatorFloor(dir, i)` | idem, `i` **0-based** (`namesList.get(i)`) | string (ou `tostring(i)` si invalide) / int |
| `getDurationAngle(degrés, rpm)` / `getDurationDistance(blocs, rpm)` | aucun | float, secondes |
| `print(texte)` | aucun | écrit la ligne courante (128 caractères max) puis ligne + 1 (max 16) |
| `getLine()` / `setLine(n)` | | int ; `setLine` accepte 1..16, sinon garde l'actuelle ; retourne la ligne |
| `getMaxLines()` | | 16 |
| `clearLine()` / `clear()` | | |

### Moteurs, énergie

| Type | Méthodes | Notes |
|---|---|---|
| `electric_motor` | `getType()`, `setSpeed(rpm)`, `stop()`, `getSpeed()`, `getStressCapacity()` (int), `getEnergyConsumption()` (float), `rotate(degrés, [rpm])`, `translate(blocs, [rpm])`, `getMaxInsert()`, `getMaxExtract()` | `setSpeed` borné par la config `ELECTRIC_MOTOR_RPM_RANGE` ; même vitesse = sans effet ; erreurs `Speed must be a finite number.`, `Speed is set too many times per second (Anti Spam).`. `rotate`/`translate` : avec `rpm`, règle la vitesse (négative si angle < 0) ; retourne la durée en secondes |
| `servo_motor` | `getSpeed`, `setSpeed(rpm)`, `getAngle`, `getTargetAngle`, `setTargetAngle(a)` (-180..180), `getMinAngle`, `setMinAngle(a)` (0..180), `getMaxAngle`, `setMaxAngle(a)` (0..180), `isAssembled`, `assemble`, `disassemble`, `getEnergyConsumption` (int) | erreurs `Angle must be between -180 and 180.`, `Min angle must be between 0 and 180.`, `Max angle must be between 0 and 180.` |
| `modular_accumulator` | `getEnergy`, `getCapacity` (int, du contrôleur multibloc), `getPercent` (float), `getMaxInsert`, `getMaxExtract`, `getHeight`, `getWidth` | |
| `portable_energy_interface` | `getEnergy`, `getCapacity`, `isConnected`, `getMaxInsert`, `getMaxExtract` | |
| `redstone_relay` (Create Additions) | `getMaxInsert`, `getMaxExtract`, `getThroughput`, `isPowered` (propriété `POWERED`) | relais d'ÉNERGIE commandé par redstone. Aucune sortie redstone |

## 6. Relais redstone CC:T (`redstone_relay`, bloc `computercraft:redstone_relay`)

`shared/peripheral/redstone/RedstoneRelayPeripheral` étend `core/apis/RedstoneMethods` (mêmes méthodes que l'API `redstone`). Périphérique CC normal : adjacent ou modem filaire.

| Méthode Lua | Arguments | Retour |
|---|---|---|
| `setOutput(côté, bool)` | | `true` = niveau 15, `false` = 0 |
| `getOutput(côté)` / `getInput(côté)` | | bool |
| `setAnalogOutput(côté, 0..15)` / `setAnalogueOutput` | | erreur `Expected number in range 0-15` |
| `getAnalogOutput(côté)` / `getAnalogueOutput` | | int |
| `getAnalogInput(côté)` / `getAnalogueInput` | | int |
| `setBundledOutput(côté, masque)` / `getBundledOutput(côté)` / `getBundledInput(côté)` | | int |
| `testBundledInput(côté, masque)` | | bool |

- Côtés : `"bottom"`, `"top"`, `"back"`, `"front"`, `"right"`, `"left"` (`ComputerSide`), relatifs à la face avant du relais (`RedstoneRelayBlockEntity.mapSide`, `DirectionUtil.toLocal`).
- Événement `redstone` SANS paramètre (`queueRedstoneEvent`, `AttachedComputerSet.queueEvent("redstone")`), vers les ordinateurs attachés au relais, quand une entrée change.
- Piège : `peripheral.find("redstone_relay")` peut renvoyer le relais d'énergie de Create Additions. Filtrer sur la méthode.

```lua
local relais = peripheral.find("redstone_relay", function(_, p) return p.setOutput ~= nil end)
relais.setOutput("back", true)    -- embrayage alimenté : ligne coupée
sleep(5)
relais.setOutput("back", false)   -- ligne relancée
print(relais.getAnalogInput("front"))
```

## Non vérifié

- Unité « SU » et formule du stress (impact x RPM) : nom d'unité non lu ; seuls les champs `stress`/`capacity` du réseau sont lus.
- Valeurs de `getStress`/`getStressCapacity` quand la source s'arrête sans que le bloc quitte le réseau (`removeSource` ne remet pas `stress`/`capacity` à 0 ; `setNetwork(null)` non lu).
- Bornes de `setTargetSpeed` / `setGeneratedSpeed` (`ScrollValueBehaviour.setValue`, bornes typiques -256..256 non lues).
- Sens exact de `count` dans `package_repackaged` (taille de la liste recomposée supposée).
- Si `getAccurateSummary()` renvoie une copie : `requestFiltered` décrémente les `count` de la liste reçue ; si c'est le cache, un `stock()` juste après peut être faussé.
- Sémantique des adresses (joker `*`, correspondance glob entre adresse du colis et filtre du Frogport/Postbox) : non lue.
- Quels packagers répondent à `requestFiltered` (réseau du Stock Ticker par fréquence) et délai de livraison.
- Comment choisir la source « ordinateur » d'un Display Link (interface, enregistrement de `ComputerDisplaySource`) ; rafraîchissement passif réel.
- Postbox réellement inaccessible : seule l'absence de `PeripheralCapability` dans le jar est constatée.
- Comment une nappe est liée à son Stock Ticker (`targetOffset`) ; si une nappe vide a un BE (sinon pas de périphérique) ; consommation des paiements.
- Bornes `glowWidth` / `glowHeight` du Nixie ; noms de couleurs acceptés (casse) ; forme de `getSchedule`/`setSchedule` ; retours de `canTrainReach`/`distanceTo` (`MethodResult`).
- Create Additions : usage de la face dans les lambdas de capacité ; ligne initiale du Digital Adapter et lien avec un Display Link ; unités de `getEnergyConsumption` ; plage config `ELECTRIC_MOTOR_RPM_RANGE`.
- Conversion des objets `@LuaFunction` en tables Lua par CC:T : comportement standard de CC, non relu dans `CobaltLuaMachine`.
- Rien n'a été exécuté en jeu : toute la référence vient du bytecode statique.
