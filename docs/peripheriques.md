# Périphériques Advanced Peripherals 0.8.2a (MC 1.21.1, NeoForge)

Source : bytecode du jar. Une clé non listée est absente. `pos` = `{x=int,y=int,z=int}` (arrondi à l'entrée).
Noms d'énumération = `name()` Java.

## Erreurs

| Cas | Comportement |
|---|---|
| Colony, pas de colonie ou permission | exception Lua `Here is no colony or you don't have the right permissions` |
| Colony, `pos` invalide | exception Lua `Table should contains key 'x', 'y' and 'z'` ou `Position should be numbers` |
| ME Bridge, hors réseau ou filtre invalide | retour `nil, "<CODE>"` (`NOT_CONNECTED`, `ITEM_NOT_FOUND`, `NO_VALID_FILTER_TYPE`...), pas d'exception |

## Forme Lua d'un item (colonie et ME Bridge)

| Clé | Type | Note |
|---|---|---|
| `name` | string | id registre, ex. `minecraft:oak_log` |
| `count` | number | ME Bridge : peut valoir 0 |
| `displayName` | string | |
| `maxStackSize` | number | |
| `tags` | `{["c:logs"]=true,...}` | clé = tag, valeur `true` |
| `components` | table | patch de composants (écarts au défaut) |
| `nbt` | string | HASH des composants (pas une table). À passer à `nbtHash` d'un filtre |
| `prototype` | table | composants par défaut, ou `{_error=string}` |
| `isCraftable` | boolean | ME Bridge seulement (pas de `fingerprint` ni `slot`) |

## Colony Integrator (`colony_integrator`)

| Méthode | Retour |
|---|---|
| `isInColony()` | boolean (sans exception) |
| `isWithin(pos)` | boolean (false si pas de colonie, sans exception) |
| `amountOfConstructionSites()`, `getColonyID()` | number |
| `getColonyName()`, `getColonyStyle()` | string |
| `isActive()`, `isUnderAttack()`, `isUnderRaid()` | boolean |
| `getLocation()` | pos du centre |
| `getHappiness()` | number (bonheur global) |
| `getCitizenCount()`, `getCitizenLimit()`, `getGraveCount()` | number |
| `getCitizen(id)` | table citoyen, `nil` si id inconnu |
| `getCitizens()`, `getVisitors()`, `getBuildings()`, `getWorkOrders()` | liste de tables |
| `getResearches()` | `{[branchId]=liste de recherches}` |
| `getWorkOrderResources(id)` | liste de ressources, `nil` si id inconnu |
| `getBuilderResources(pos)` | liste de ressources, `nil` si pas de hut constructeur à `pos` (= `getBuildings()[i].pos`) |
| `getRequests()` | liste de requêtes |

### Citoyen (`getCitizens`, `getCitizen`)

- `id` number, `uuid` string, `name` string, `isChild` boolean, `gender` `"female"|"male"`, `saturation` number, `happiness` number.
- `skills` : `{[NOM_SKILL]={level=number,xp=number}}`. `disease` : string id (si malade).
- `pos` pos, `bedPos` pos (peut manquer). `job` : string id, ex. `minecolonies:builder` (si job). `jobStatus` : string (`JobStatus.name`).
- `homeBuilding`, `workBuilding` : bâtiment de base `{pos,type,level,displayName}` (si assigné).
- `state` : string traduite (`"Idle"` par défaut). `isIdle`, `isAsleep`, `isMourning`, `needsBetterFood` : boolean.
- `partner` : id (si marié). `children` : liste d'ids. `health`, `maxHealth`, `armor`, `toughness` : number (si entité chargée).
- Visiteur : `id,uuid,name,isChild,gender,saturation,happiness,skills,disease`, `pos` (position assise), `recruitCost` (table item). Pas de `job`, `homeBuilding`, `bedPos`.

### Bâtiment (`getBuildings`)

- Base : `pos`, `type` (schematic), `level`, `displayName`. Plus : `style` (pack), `maxLevel`, `built`, `priority` (ramassage), `guarded`, `storageBlocks`, `storageSlots` (number/boolean).
- `isWorking` vaut en réalité `isPendingConstruction` (vrai = chantier en attente).
- `structure` : `{cornerA=pos,cornerB=pos,rotation=string,isMirrored=boolean}`. `citizens` : liste de `{id=,name=}`.

### Commande de travaux (`getWorkOrders`)

- `id`, `priority`, `level` (courant), `targetLevel` : number. `pos` : chantier. `displayName` : string.
- `type` (`WorkOrderType.name`), `stage` (`BuildingProgressStage.name`) : string. `isClaimed` : boolean.
- `builderHome` : bâtiment de base du constructeur (seulement si `isClaimed`).

### Ressources (`getBuilderResources`, `getWorkOrderResources`)

Liste triée (comparateur MineColonies). `getWorkOrderResources` lit le bâtiment qui a réclamé la commande.

| Clé | Type / sens |
|---|---|
| `item` | table item |
| `displayName` | string |
| `status` | string `RessourceAvailability.name` (valeurs non vérifiées) |
| `needs` | number : quantité totale requise |
| `available` | number : quantité disponible |
| `delivering` | number : quantité en cours de livraison |

### Requêtes (`getRequests`)

Union des requêtes du résolveur joueur et du résolveur "retrying", dédupliquées, limitées aux `IDeliverable`.

| Clé | Type / sens |
|---|---|
| `id` | string (identifiant du token) |
| `displayName` | string (titre court, formatage retiré) |
| `description` | string (texte long, formatage retiré) |
| `state` | string `RequestState.name` (valeurs non vérifiées) |
| `count` | number (quantité demandée) |
| `minCount` | number (minimum acceptable) |
| `items` | liste de tables item (piles d'affichage) |
| `target` | pos du demandeur (un pos, pas un nom) |

Pas de clés `desc`, `name`, `type`, `requester`, `delivering`.
```lua
local col = peripheral.find("colony_integrator")
for _, r in ipairs(col.getRequests()) do
  print(r.displayName, r.count, r.state, r.target.x, r.target.y, r.target.z, r.items[1] and r.items[1].name)
end
for _, e in ipairs(col.getBuilderResources({x=10, y=64, z=-3}) or {}) do print(e.item.name, e.needs, e.available, e.delivering) end
```

### Recherche (`getResearches`)
Élément : `id,displayName,requirements,cost,researchEffects,status,requiredTime,progress`, plus `children` (récursif, si non vide).
`requirements[i]` : `type,desc,fulfilled` + `building,level` ou `buildings,level` ou `researchId`. `cost[i]` : `{validItems=liste d'items,count=number}`. `researchEffects` : liste de strings.

## ME Bridge (`me_bridge`)

Types additionnels : `storage_bridge`, `multi_drive`. Hors réseau, toute méthode retourne `nil, "NOT_CONNECTED"`.

### Filtre (table Lua)

| Clé | Type | Sens |
|---|---|---|
| `name` | string | `"minecraft:iron_ingot"` ou `"#c:ingots/iron"` (tag, préfixe `#`) |
| `components` | string SNBT ou table | composants à tester |
| `matcher` | string | `"patch"` (défaut), `"exact"`, `"subset"` |
| `nbtHash` | string | égal au champ `nbt` d'un item retourné |
| `count` | number | quantité à déplacer ou fabriquer. Défaut 2147483647 (tout) |
| `fromSlot`, `toSlot` | number | emplacements de l'inventaire externe (-1 = tous) |
| `type` | string | `"item"`, `"fluid"`, `"chemical"` (méthodes génériques : `isCraftable`, `isCrafting`, `cancelCraftingTasks`, `getPatterns`) |

Pas de champs `tags`, `fingerprint`, `nbt`, `displayName`. Génériques sans `type` : type déduit de `name` (exception Lua si ni `type` ni `name`).
Filtre vide `{}` ou omis : accepté par `getItems`, `exportItem`, `importItem`.

### Transfert

| Méthode | Retour |
|---|---|
| `exportItem(cible, filtre)` | number déplacé (bridge vers cible) |
| `importItem(cible, filtre)` | number déplacé (cible vers bridge) |

Ordre confirmé : CIBLE PUIS FILTRE (filtre optionnel, alors `count` = tout). Cible :
- `"@direction"` : inventaire adjacent au bridge. Absolue (`north,south,east,west,up,down`) ou relative au bloc (`top,bottom,front,back,left,right`). Ex. `"@up"`.
- nom de périphérique réseau vu par l'ordinateur (`peripheral.getNames()`, ex. `"minecraft:chest_0"`). Un `"up"` sans `@` est lu comme nom réseau et échoue.

Erreurs : `nil, "INVENTORY_NOT_FOUND"` (cible illisible), `nil, "<code filtre>"`. Retourne 0 si rien ne correspond, cible pleine ou `count<=0`.

### Lecture

| Méthode | Retour |
|---|---|
| `getItem(filtre)` | table item. `nil, "EMPTY_FILTER"` si filtre vide. `nil` seul si absent et non fabricable. `count=0,isCraftable=true` si absent mais fabricable |
| `getItems([filtre])` | liste de tables item (stockés) |
| `getCraftableItems([filtre])` | liste de tables item fabricables (`count` = stock, peut valoir 0) |
| `isCraftable(filtre)` | boolean |
| `isConnected()`, `isOnline()` | boolean |
| `getPatterns([{input=filtre,output=filtre}])` | liste de motifs. `nil, "NO_FILTER"` si la table n'a ni `input` ni `output` |
| `getCraftingCPUs()` | liste de CPU |

Motif : `{patternType="crafting|processing|smithing|stonecutting|unknown", inputs=liste de {primaryInput,possibleInputs,multiplier,remaining}, outputs=liste de tables item, primaryOutput=table item}`.
CPU : `{storage,coProcessors,isBusy,name,selectionMode}` + `craftingJob` (table tâche) si occupé. `name` = `"Unnamed"` si sans nom.
Énergie et capacités (number, sans argument) : `getStoredEnergy, getEnergyCapacity, getEnergyUsage, getAverageEnergyInput`, et `getMax|getUsed|getAvailable` + `ItemStorage|FluidStorage|ChemicalStorage|ExternalItemStorage|ExternalItemCount|ExternalFluidStorage|ExternalChemicalStorage`.

### Fabrication

| Méthode | Retour |
|---|---|
| `craftItem(filtre [, nomCPU])` | objet tâche. Erreurs : `nil, "CPU_NOT_FOUND"` ou `nil, "NOT_CRAFTABLE"` |
| `getCraftingTasks()` | liste de tables tâche |
| `getCraftingTask(id)` | tâche, ou `nil, "NOT_FOUND"` (voir "Non vérifié") |
| `isCrafting(filtre [, nomCPU])` | boolean (voir "Non vérifié") |
| `cancelCraftingTasks(filtre)` | number de CPU annulés |

`craftItem` : toujours fournir `count` (sinon 2147483647). `nomCPU` = `getCraftingCPUs()[i].name`. Retour immédiat : calcul et lancement sont asynchrones, signalés par `ae_crafting`.
Objet tâche (appel `t.isDone()`) : `getId, isDone, isCanceled, isCraftingStarted, isCalculationStarted, isCalculationNotSuccessful, hasErrorOccurred, getDebugMessage, getRequestedItem, getElapsedTime, getTotalItems, getItemProgress, getEmittedItems, getUsedItems, getMissingItems, hasMultiplePaths, getFinalOutput, cancel`. `getId()` = `jobId` de l'événement.
Table tâche (`getCraftingTasks`, `craftingJob`) : `bridgeId` (number, -1 si hors bridge), `quantity`, `resource` (table item), `cpu` (CPU sans `craftingJob`), et selon l'état du CPU `completion` (0..1), `crafted` (number), `id` (UUID string AE2).
`getCraftingTasks` ne liste que les tâches lancées via CE bridge dont le CPU est occupé.

```lua
local me = peripheral.find("me_bridge")
local n = me.exportItem("@up", {name="minecraft:iron_ingot", count=64})  -- number
local it = me.getItem({name="minecraft:iron_ingot"})                     -- nil si inconnu
local t, err = me.craftItem({name="minecraft:piston", count=4})
if not t then error(err) end
repeat local _, isErr, id, status = os.pullEvent("ae_crafting")
until id == t.getId() and (isErr or status == "JOB_DONE")
```

## Événements

- `ae_crafting` (`craftItem`) : `isError` boolean, `jobId` number, `status` string.
  - isError=false : `CALCULATION_STARTED, CRAFTING_STARTED, JOB_DONE, JOB_CANCELED`.
  - isError=true : `NOT_CRAFTABLE, MISSING_ITEMS, UNKNOWN_ERROR, NOT_CONNECTED`, ou un code d'erreur de soumission AE2.
- `disk`, `disk_eject` (ME Bridge, disques/cellules montés) : un argument, non vérifié.
- Le Colony Integrator ne met aucun événement en file.

## Non vérifié

- Valeurs de `status` (ressources), `state` (requêtes), `jobStatus`, `type`, `stage` : énumérations MineColonies absentes du jar.
- `isCrafting` et `getCraftingTask` enveloppent un `MethodResult` dans un second `MethodResult.of(Object)` : la valeur vue en Lua peut être `nil`. Tester en jeu. Repli : `getCraftingTasks()` ou `getCraftingCPUs()[i].isBusy`.
- Conversion en Lua de l'objet tâche de `craftItem` (table de méthodes attendue via `@LuaFunction`) ; ordre des paramètres d'événement côté `os.pullEvent`.
- Clés nullables (`bedPos`, `homeBuilding`, `workBuilding`, `job`, `disease`) : absentes ou `nil`, équivalent en Lua.
- `getWorkOrderResources` sur commande non réclamée, `getBuilderResources` sur bâtiment absent ou non constructeur : `nil` probable, exception possible.
- Item pour une pile vide ; sens exact des `matcher` ; unités de l'énergie et des capacités.
- Fluides et chimiques (`getFluid*`, `exportFluid`...) non relevés. Doc embarquée (patchouli) non confrontée.
