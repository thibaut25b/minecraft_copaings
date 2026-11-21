# Lightman's Currency 2.3.0.6 : API ComputerCraft (MC 1.21.1, NeoForge, CC:T 1.120.2)

Source : bytecode de `lightmanscurrency-1.21-2.3.0.6.jar`, `lctech-1.21-0.2.2.7.jar`, `cc-tweaked-1.21.1-forge-1.120.2.jar`. Chemins de classes relatifs à `io/github/lightman314/lightmanscurrency/` (abrégé `LC/`), CC = `integration/computercraft` (abrégé `icc/`). Tout ce qui n'est pas lu dans le bytecode ou dans un fichier du jar est en section finale.

## Réponses de conception

1. **Faire payer** : Paygate (`lc_trader_paygate`) ou Item Trader (`lc_trader_item`) adjacent à l'ordinateur (ou via modem filaire). Le joueur paie dans l'interface du bloc ; l'ordinateur reçoit `lc_trade` APRÈS le débit (`PaygateTraderData.ExecuteTrade`, `ItemTraderData.ExecuteTrade`). C'est le seul signal sûr : nom du joueur + montant payé (table monnaie) + indice de l'offre.
2. **Identité** : seul `player.Name` (string) arrive en Lua. Le champ `ID` (UUID Java) est mis dans la table mais CC le convertit en nil (`CobaltLuaMachine.toValue` : type inconnu, nil + warning). Pas d'UUID côté Lua.
3. **Verser** : AUCUNE méthode Lua ne dépose, retire, vire ou donne de la monnaie (aucune chaîne deposit/withdraw/transfer/give/collect dans `icc/**`). L'ATM (`lc_atm`) est en lecture seule (soldes de TOUS les comptes). `lc_money` ne fait que du calcul.
4. **Seules voies de versement** : (a) objets : le Lua déplace des pièces/jetons avec `pushItems`/`pullItems` du stockage d'un Item Trader (`getStorage()`, permission `openStorage`) ou de tout inventaire du réseau, ou via dropper/hopper en redstone ; (b) le joueur encaisse lui-même (offre trader en mode achat, non testée).
5. **Prix** : `trade.setPrice(valeur)` règle une offre ; exige la permission `editTrades`, accordée au numéro d'ordinateur par le propriétaire du trader dans l'onglet d'autorisation externe (voir section 1). Pas de notion de joueur propriétaire de l'ordinateur : l'ordinateur est un faux joueur `computercraft#<id>`.
6. `lc_trade_pre` ne peut PAS annuler : le Lua reçoit un booléen `canceled` en dernier paramètre, aucune méthode Lua n'annule. Il peut être émis sans achat (voir section 1).
7. Les pièces et leurs valeurs sont configurables (`config/lightmanscurrency/MasterCoinList.json`) : les lire en jeu avec `lc_money.readInventoryValues` (section 3).

## 1. Payer : événements et réglages

Mécanisme d'enregistrement : `icc/LCPeripheral` (implémente `IDynamicPeripheral`) ; chaque sous-classe implémente `registerMethods(Registration)` qui appelle `LCPeripheralMethod.builder("nomLua").simple/withArgs/withContext...(lambda)`. Le nom Lua est la chaîne du builder, pas le nom Java. Un `PeripheralMethodsEvent` permet à d'autres mods d'ajouter/retirer des méthodes (`LCPeripheral.validateMethods`). Toute méthode est exécutée sur le thread serveur (`ILuaContext.executeMainThreadTask` dans `LCPeripheral.callMethod`). Méthodes communes à tout périphérique LC : `getType()`, `getTypes()`, `isType(string)`. Seul l'`@LuaFunction` de CC est utilisé dans `apis/LuaMoneyAPI`.

| Événement | Paramètres de `os.pullEvent` dans l'ordre | Émis par |
|---|---|---|
| `lc_trade` | `"lc_trade"`, trader (objet), indice (nombre), trade (objet), joueur `{Name}`, prixPayé (monnaie), taxesPayées (monnaie) | `TraderPeripheral.postTradeEvent` (lambda$11), idem `TerminalPeripheral` |
| `lc_trade_pre` | `"lc_trade_pre"`, trader, indice, trade, joueur `{Name}`, canceled (bool) | `TraderPeripheral.preTradeEvent` (lambda$10) |
| `lc_trader_created` | `"lc_trader_created"`, trader, joueur `{Name}`, id (nombre) | `TerminalPeripheral.newTraderEvent` |
| `lc_trader_removed` | `"lc_trader_removed"`, trader, id (nombre) | `TerminalPeripheral.removeTraderEvent` |

- `trader` et `trade` sont des objets Lua (`LCPeripheralWrapper`, `IDynamicLuaObject`) dont on appelle les méthodes du trader/de l'offre directement (`trade.getPrice()`), liés à cet ordinateur.
- **Indice 0-based** dans l'événement (`TradeEvent.getTradeIndex` = `TraderData.indexOfTrade` = `List.indexOf`), mais `trader.getTrade(i)` est **1-based** (`TraderPeripheral.getTrade` : borne 1..tradeCount puis `i-1`). Conversion : `getTrade(indice + 1)`.
- Ordre réel : `runPreTradeEvent` (annulable par règles de trade/autres mods) puis `getPayment` (débit) puis action (redstone Paygate / objets) puis `addStoredMoney` puis `runPostTradeEvent` (`PaygateTraderData.ExecuteTrade`, `ItemTraderData.ExecuteTrade`, `TraderData.runPostTradeEvent` poste sur `NeoForge.EVENT_BUS`).
- Écouteurs : `NeoForge.EVENT_BUS`, priorité LOWEST ; pre avec `receiveCanceled=true` (`TraderPeripheral.onFirstAttachment`). Donc `canceled` reflète l'état final. `runPreTradeEvent` est aussi appelé par `PaygateBlockEntity` (test de ticket) et `TradeRenderManager` (alertes) : `lc_trade_pre` ne prouve pas un achat. N'utiliser que `lc_trade`.
- Réception : un ordinateur reçoit les événements d'un trader quand ce trader est un périphérique attaché à lui (adjacent, ou modem filaire activé, `AttachedComputerSet`, `AccessTrackingPeripheral.queueEvent`). Écouteurs enregistrés seulement tant qu'au moins un ordinateur est attaché. Un `lc_terminal` (blocs Terminal/Gem Terminal) reçoit les mêmes événements pour tous les traders visibles sur le réseau (`canShowOnTerminal`) + created/removed.
- Un trader n'envoie l'événement qu'à l'ordinateur où il est attaché ; plusieurs ordinateurs attachés le reçoivent tous.

### Permissions et identité de l'ordinateur
- Identifiant : `"computercraft#" .. computerId` (`AccessTrackingPeripheral.getComputerID`). Faux joueur : `PlayerReference.dummy(thatString)` (`getFakePlayer`, utilisé dans les notifications de réglage). Pas de propriétaire joueur.
- Niveau d'accès (`TraderPeripheral.getPermissionLevel`, `TradeWrapper.getPermissionLevel`) : 0 si le trader n'a pas la pièce jointe `external_authorization` (réglage `allowExternalAuthorization`) ou si la permission est dans `getBlockedPermissions()`. Sinon par niveau d'accès de l'ordinateur (`ExternalAuthorizationAttachment.getAccessLevel`, défaut NONE) : NONE = 0, ALLY = niveau de la permission dans la table des alliés, ADMIN = illimité. Une permission est accordée si niveau > 0.
- À la première connexion, `TraderPeripheral.onAttachment` appelle `flagAttemptedAccess(computerID)` : l'ordinateur apparaît dans la liste des tentatives ; le propriétaire du trader le passe en ALLY/ADMIN dans l'interface du trader (écran non inspecté, voir Non vérifié).
- Permissions relevées : `editTrades` (setPrice et réglages d'offre), `openStorage` (getStorage), `changeName` (setName, setIcon), `bankLink`, `editSettings`, `addRemoveAllies`, `editPermissions`. Un refus de réglage renvoie `false` (pas d'erreur) pour setPrice/setDuration/setRedstoneLevel/setOutputSides/setName.
- Lecture (getOwner, getStats, getLogs, getLinkedAccount, getTrades...) : aucune permission relevée.

### Forme d'un prix et réglage
- Une valeur monétaire se passe en chaîne `"coin;5-lightmanscurrency:coin_copper"` ou en table contenant `data` (`LCArgumentHelper.parseMoneyValue`) ; voir section 4.
- `trade.getPrice()` renvoie la table monnaie (`TradeWrapper.getPrice`) ; sur une offre Paygate à ticket, `getPrice()` renvoie en plus `TicketID`, `TicketColor`, `TicketItem` (`PaygateTradeWrapper.getPrice`).
- `trade.setPrice(valeur)` -> bool (`TradeWrapper.setPrice`, `TradeData.setCost`). Suffisant pour un Item Trader ; sur un Paygate à ticket utiliser `setTicketPrice`.
- Un Paygate sans ticket : prix via `setPrice`, durée via `setDuration(ticks)`, niveau via `setRedstoneLevel(0..15)`, côtés via `setOutputSide(direction, bool)`.

### Méthodes du trader (`lc_trader`, `TraderPeripheral.registerMethods`)
`isValid`, `getID`, `isVisibleOnNetwork`, `isCreative`, `isPersistent`, `getOwner` (table propriétaire), `getOwnerName`, `getStats`, `getAllies`, `addAlly(nom)`, `removeAlly(nom)`, `getAllyPermissions`, `getAllyPermissionLevel(perm)`, `setAllyPermissionLevel`, `getPlayerPermissionLevel`, `getMyPermissionLevel(perm)`, `getLogs([n|bool])` (max 2 args), `getName`, `setName`, `getIcon`, `setIcon`, `hasBankAccount`, `getLinkedAccount`, `setLinkedToBankAccount(bool)`, `showsSearchBox`, `setShowsSearchBox`, `hasPushNotifications`, `setPushNotification` (sans s final), `hasChatNotifications`, `setChatNotifications`, `teamNotificationLevel`, `setTeamNotificationLevel`, `tradeCount`, `validTradeCount`, `tradesWithStock`, `acceptableTaxRate`, `setAcceptableTaxRate`, `currentTaxRate`, `getWorldPosition`, `getCurrentUsers` (noms), `getUpgrades`, `getTrade(i)`, `getTrades()`.

### Offres
| Type | Méthodes (nom Lua) | Classe |
|---|---|---|
| toute offre (`lc_trade`) | `isValid`, `getPrice`, `setPrice`, `getStock`, `getDirection` (string), `isSale`, `isPurchase`, `isBarter`, `isOther` | `TradeWrapper` |
| `lc_trade_paygate` | `setTicketPrice(ticketId, couleur, item)`, `storesTicketStubs`, `setStoresTicketStubs`, `getDuration` (`{ticks,text}`), `setDuration(ticks)`, `getRedstoneLevel`, `setRedstoneLevel`, `getDescription`, `getTooltip`, `setTooltip`, `getOutputSides` (clés `down,up,north,south,west,east` -> bool), `setOutputSides` | `PaygateTradeWrapper` |
| `lc_trade_item` | `setDirection`, `getRestrictionType`, `getSellItems`, `getSellItemDetails`, `setSellItem`, `getBarterItems`, `getBarterItemDetails`, `setBarterItem`, `setEnforceNBT` | `ItemTradeWrapper` |
| `lc_trade_item_ticket` | `getTicketRecipe`, `setTicketRecipe`, `getTicketCode`, `setTicketCode`, `getTicketDurability`, `setTicketDurability` | `TicketItemTradeWrapper` |

Pièges : `setOutputSides` est le nom Lua de la méthode Java `setOutputSide(direction, bool)` ; `setDescription` existe en Java mais n'est pas enregistrée (le nom `setDuration` est enregistré deux fois avec le même lambda), donc pas de `setDescription` en Lua (`PaygateTradeWrapper.registerMethods`). `setTicketPrice` : args `getLong(0)` ticketId, `getInt(1)` couleur, `getString(2)` id d'un item ticket maître.

### Autres méthodes de trader
- Paygate (`PaygatePeripheral`) : `getTicketStubStorage`, `getRedstoneState`.
- Item Trader (`ItemTraderPeripheral`) : `getStorageStackLimit`, `getStorage` (objet `inventory`, section 5), plus `InputTraderPeripheral` : `allowsInputs`, `allowsInputSide(side)`, `setInputSide`, `getInputSides`, `allowsOutputs`, `allowsOutputSide`, `setOutputSide`, `getOutputSides`.

## 2. Verser de l'argent : ce qui existe

| Piste | Constat (classe) |
|---|---|
| Dépôt/retrait/virement bancaire | Inexistant. `ATMPeripheral` n'a que `getBankAccount`, `searchBankAccounts`, `getAllBankAccounts` |
| Don à un joueur | Inexistant |
| Argent stocké dans un trader | Aucune méthode (`setLinkedToBankAccount` redirige seulement les revenus futurs vers le compte du propriétaire, permission `bankLink`) |
| Stockage d'objets d'un Item Trader | `getStorage()` -> `pushItems`/`pullItems` (permission `openStorage`) : peut y déposer/retirer des pièces-objets |
| `MultiTraderPeripheral`, `CashRegisterPeripheral`, `AuctionHousePeripheral`, pocket upgrades | Lecture et gestion de traders ; aucun mouvement d'argent |
| lctech | Traders fluide/énergie (`lct_trader_fluid`, `lct_trader_energy`), rien sur la monnaie |

ATM (`ATMPeripheral`, type `lc_atm`, bloc ATM) : `getBankAccount(tableRéférence)` (table `ReferenceKey` d'un résultat précédent, erreur "Bank Account for that key could not be found!"), `searchBankAccounts(texte)` (sous-chaîne, insensible à la casse, sur le nom du compte), `getAllBankAccounts()`. Retour d'un compte : `{ReferenceKey = table, Name = string, Balance = {[typeUnique] = monnaie}}`. Les listes sont indexées par un entier. Aucun contrôle de permission : tout compte du serveur est lisible.

## 3. Les pièces

Défaut généré par `common/impl/CoinAPIImpl.generateDefaultCoins` seulement si `config/lightmanscurrency/MasterCoinList.json` n'existe pas (`ReloadCoinDataFromFile`). Chaîne `main` (obligatoire, sinon erreur) :

| Pièce | Identifiant objet (`ModItems`) | Valeur (cuivre = 1) |
|---|---|---|
| Cuivre | `lightmanscurrency:coin_copper` | 1 |
| Fer | `lightmanscurrency:coin_iron` | 10 (x10) |
| Or | `lightmanscurrency:coin_gold` | 100 (x10) |
| Émeraude | `lightmanscurrency:coin_emerald` | 1000 (x10) |
| Diamant | `lightmanscurrency:coin_diamond` | 10000 (x10) |
| Netherite | `lightmanscurrency:coin_netherite` | 100000 (x10) |

- Chaîne annexe `emeralds` (par défaut) : `minecraft:emerald` = 1, `minecraft:emerald_block` = 9 ; type monétaire distinct de `main`, donc non additionnable avec lui (`sameType`).
- Chaînes latérales `coinpile_*` (9) et `coinblock_*` (4) pour chaque métal ; non acceptés comme valeur par le parseur (`CoinValueParser.TryParseCoin` : `isSideChain` -> erreur "not a coin"). Variantes `coin_chocolate_*` et `coin_ancient` existent comme objets (`ModItems`), absentes de la chaîne par défaut.
- Configurable : oui, via le fichier `MasterCoinList.json` (clé `Chains`) et l'écran de config `master_coin_list`, synchronisé aux clients (`SPacketSyncCoinData`) ; événement `BuildDefaultMoneyDataEvent` pour d'autres mods. Les ratios ne sont donc pas à coder en dur.
- Découverte en Lua : le fichier n'est pas lisible depuis CC. Interroger : `lc_money.readInventoryValues({name="lightmanscurrency:coin_gold", count=1})` puis lire `.numeric` de l'entrée renvoyée.
- Une valeur de pièces est convertie en valeur de chaîne par `getCoreValue` = somme(valeurCoeur(pièce) x quantité), plancher 0 (`CoinValue.getCoreValue`).

## 4. `lc_money` (API globale, `apis/LuaMoneyAPI`, `getNames` = `lc_money`, enregistrée par `LCComputerHelper.setup`)

| Fonction | Arguments | Retour |
|---|---|---|
| `addMoney(a, b)` | 2 valeurs | table monnaie (somme) ; erreur "Cannot add money of incompatible types!" si types différents |
| `subtractMoney(a, b)` | 2 valeurs | `a - b` ; même message d'erreur (copié de add) ; si négatif : champ `negative = true` |
| `percentageOfMoney(v, pct)` | valeur, entier `getInt(1)`, booléen optionnel (index 2) | table monnaie |
| `multiplyMoney(v, mult)` | valeur, nombre fini `getFiniteDouble(1)` | table monnaie |
| `readInventoryValues(t)` | table d'objets | table `{[typeUnique] = monnaie}` (un type par monnaie présente) |

- Valeur en entrée : soit chaîne au format `MoneyValueArgument` (`"coin;5-lightmanscurrency:coin_copper"`, plusieurs : `n-id,n-id`), soit table avec champ `data` (`LCArgumentHelper.parseMoneyValue` : `data` -> `MoneyValue.load`), c.-à-d. une table renvoyée par LC. Pour `add/subtract/percentage/multiply` : `parseFlexibleMoneyValue` lit aussi `negative`. Les sorties de `readInventoryValues` sont des dictionnaires : passer l'entrée interne (`res["lightmanscurrency:coins!main"]`), pas le dictionnaire.
- Forme d'une monnaie renvoyée (`LCLuaTable.fromMoney`) : `{type = string (typeUnique), numeric = nombre (getCoreValue), text = string (affichage, "Empty" si vide), data = table (NBT), arg = string (réinjectable)}` ; plus `negative` si négatif.
- `typeUnique` = `<type>!<chaîne>` (`MoneyValue.generateCustomUniqueName`) ; pour les pièces `lightmanscurrency:coins!main` (`CoinCurrencyType.TYPE` = `lightmanscurrency:coins`).
- Comparer : `a.numeric` vs `b.numeric` à type identique. Construire depuis un nombre : `lc_money.addMoney(("coin;%d-lightmanscurrency:coin_copper"):format(n), "coin;0-lightmanscurrency:coin_copper")` (le parseur convertit `n` copper en valeur de chaîne, `TryParseCoin` -> `CoinValue.fromNumber`) ; non testé en jeu.
- `readInventoryValues` : n'accepte PAS un nom de périphérique. Il lit une table d'entrées `{name="mod:id", count=n}` (une seule, ou liste/dictionnaire d'entrées ; `LCArgumentHelper.parseBasicItems`), construit un inventaire virtuel (`InventoryUtil.buildInventory`) et le fait lire par `MoneyAPI.GetContainersMoneyHandler` (côté serveur). Usage : `lc_money.readInventoryValues(chest.list())`. Compte les objets reconnus comme monnaie (coins, éventuellement d'autres types monétaires) ; les piles `coinpile/coinblock` : non vérifié.
- Aide en jeu : `help lc_money` (`data/computercraft/lua/rom/help/lc_money.txt`).

## 5. Inventaires

- `InventoryPeripheral` (`icc/peripheral/InventoryPeripheral`) n'est PAS un bloc ni un périphérique attachable : c'est un objet Lua de type `inventory` retourné par `getStorage()` (Item Trader, Slot Machine, Gacha) et `getUpgrades()` (`LCPeripheral.wrapInventory`/`wrapContainer`). Méthodes : `size()`, `list()` (`{[slot] = {name,count,...}}`), `getItemDetail(slot)`, `getItemLimit(slot)`, `pushItems(toName, fromSlot, [limit], [toSlot])`, `pullItems(fromName, fromSlot, [limit], [toSlot])` (ordre des `IArguments` : string, int, optInt, optInt). Accès conditionné par un `Supplier<Boolean>` (permission `openStorage` pour `getStorage`) ; sinon erreur.
- Cibles : `computer.getAvailablePeripheral(nom)` puis `extractHandler(IPeripheral)` (capacité `IItemHandler` du bloc cible via `GenericPeripheral.side`, ou `Container`) ; erreurs "Target ... does not exist" si absent du réseau de cet ordinateur.
- CC:T générique (`shared/peripheral/generic/methods/InventoryMethods`, id `computercraft:inventory`, `@LuaFunction(mainThread)`) : `size()`, `list()`, `getItemDetail(slot)`, `getItemLimit(slot)`, `pushItems(toName, fromSlot, [limit], [toSlot])`, `pullItems(fromName, fromSlot, [limit], [toSlot])` (signatures `AbstractInventoryMethods`). `limit` défaut illimité (`Integer.MAX_VALUE`), bornes "From slot / To slot out of range". Retour : nombre d'objets déplacés.
- `toName` / `fromName` = nom tel que l'ordinateur le voit : nom de côté (`"left"`) ou nom réseau d'un modem (`"minecraft:chest_0"`), résolu par `IComputerAccess.getAvailablePeripheral`. Contrainte : l'ordinateur qui appelle doit voir les DEUX inventaires (la source est le périphérique sur lequel on appelle, la cible doit être visible par le même ordinateur, donc même réseau filaire ou adjacence). Prouvé par l'usage de `getAvailablePeripheral` ; texte de la doc tweaked.cc non consulté.

## 6. Slot Machine et Gacha

| Type | Méthodes | Classe |
|---|---|---|
| `lc_trader_slot_machine` (+`lc_trader`) | `getStorageStackLimit`, `getStorage`, `getPrice`, `setPrice`, `getEntryCount`, `getValidEntryCount`, `getEntry(i)`, `getEntries`, `getFailOdds` | `SlotMachinePeripheral` |
| `lc_slot_machine_entry` | `isValid`, `getItems`, `getItemDetails`, `addItem`, `removeItem`, `editItem`, `isMoney`, `getMoneyValue`, `getOdds`, `setOdds`, `hasCustomIcons`, `setHasCustomIcons`, `getCustomIcons`, `setCustomIcon` | `SlotMachineEntryWrapper` |
| `lc_trader_gacha` (+`lc_trader`) | `getStorageCount`, `getStorageCapacity`, `getStorage`, `getPrice`, `setPrice` | `GachaMachinePeripheral` |

Événements : mêmes `lc_trade`/`lc_trade_pre` que ci-dessus (écouteurs de `TraderPeripheral`). Une entrée de Slot Machine peut être `isMoney` : le gain en monnaie vient alors du stockage d'argent du trader, pas d'une API Lua.

## 7. Types de périphériques (`peripheral.find(type)`)

| Type(s) | Bloc / origine | Classe |
|---|---|---|
| `lc_trader_item`, `lc_trader`, `lc_trader_input` | Item Trader (`ModBlockEntities.ITEM_TRADER`, aussi ARMOR_TRADER, FREEZER_TRADER, TICKET_TRADER, BOOK_TRADER via `registerTraderCapability` si leur BE est `ItemTraderBlockEntity`) | `ItemTraderPeripheral` |
| `lc_trader_paygate`, `lc_trader` | Paygate (`PAYGATE`) | `PaygatePeripheral` |
| `lc_trader_slot_machine`, `lc_trader` | Slot Machine (`SLOT_MACHINE_TRADER`) | `SlotMachinePeripheral` |
| `lc_trader_gacha`, `lc_trader` | Gacha (`GACHA_MACHINE`) | `GachaMachinePeripheral` |
| `lc_trader_auction` | Auction Stand (`AUCTION_STAND`), seulement si l'option serveur lue par `lambda$registerCapabilities$9` est vraie | `AuctionHousePeripheral` |
| `lc_terminal`, `lc_multi_trader` | blocs `TERMINAL`, `GEM_TERMINAL` | `TerminalPeripheral` |
| `lc_cash_register`, `lc_multi_trader` | `CASH_REGISTER` | `CashRegisterPeripheral` |
| `lc_atm` | bloc `ATM` | `ATMPeripheral` |
| `lct_trader_fluid`, `lct_trader_energy` | lctech | `lctech/.../FluidTraderPeripheral`, `EnergyTraderPeripheral` |

`lc_multi_trader` (Terminal, Cash Register) : `getTraderIDs`, `getBasicTraderInfo` (`{[i] = {Name, Owner, Types, ...id}}`), `searchTraders(texte)`, `getTrader(id)` (renvoie un objet trader du même type que le périphérique direct, lié à l'ordinateur). Cash Register en plus : `getTraderPositions`, `addTraderPosition`, `removeTraderPosition`, `getCustomTitle`, `setCustomTitle`. Terminal : tous les traders `showOnTerminal`. Pocket upgrades (`data/lightmanscurrency/computercraft/pocket_upgrade/*.json`) : types `lightmanscurrency:atm` (items `atm`, `portable_atm`) et `lightmanscurrency:terminal` (`terminal`, `gem_terminal`, `portable_terminal`, `portable_gem_terminal`) : donnent à un pocket computer les périphériques `lc_atm` / `lc_terminal`.

## Non vérifié

- Écran de l'onglet « autorisation externe » du trader (libellés, qui peut le modifier : propriétaire/alliés ?) : seule la logique de permission côté Lua est lue, pas l'interface.
- Si `getBankReference`/`Balance` d'un compte joueur correspond à l'argent réellement débité par un Paygate : non lu ; un trader peut aussi se lier à la banque (`isLinkedToBank`).
- Sens exact de `percentageOfMoney` 3e argument (booléen passé à `percentageOfValue(int, boolean)`) et de l'argument interne `true` de `TradeWrapper.setPrice` -> `parseMoneyValue(args, 0, true)`.
- Forme d'une monnaie vide (type/numeric) quand `pricePaid` est vide (offres Paygate à ticket : `runPostTradeEvent` reçoit `MoneyValue.empty()`).
- Inclusion éventuelle des taxes dans `pricePaid` ; sens du champ `taxesPaid` dans le cas d'un trader à taxes.
- Valeur par défaut exacte, ordre et noms de chaînes du fichier `MasterCoinList.json` ; sens exact de `withSideChain(pile, 9, coin)` / `withCoin(block, 4)` ; identifiants des blocs `coinpile_*` / `coinblock_*` ; leur prise en compte par `readInventoryValues`.
- Si `ItemTraderBlockEntity` couvre bien les Armor/Freezer/Ticket/Book traders (le jar enregistre une capacité périphérique sur ces 5 BE, mais le lambda ne crée `ItemTraderPeripheral` que pour `ItemTraderBlockEntity`) ; liste des blocs de chaque BE ; rôle de `CapabilityInterfaceBlockEntity.easyRegisterCapProvider` (premier appel de `registerCapabilities`).
- Format des entrées de `getLogs`, de `getStats`, de `getTicketStubStorage`, de `getRedstoneState`, de `getUpgrades`.
- Valeurs acceptées par `parseEnum` pour les directions (casse), arguments de `setSellItem/setBarterItem`.
- Texte de la documentation tweaked.cc sur le réseau filaire ; comportement réel en jeu du transfert entre réseaux.
- Quel nom de joueur est fourni pour un joueur factice / commande (`PlayerReference.getName(false)`), cas du joueur hors ligne.
- Offre en mode achat (le trader paie le joueur) comme « encaissement » : le code `ItemTraderData.ExecuteTrade` appelle `givePayment` et `removeStoredMoney`, mais le flux complet n'a pas été suivi ni testé.
- Rien n'a été exécuté en jeu : tous les points ci-dessus et la totalité de la référence sont issus du bytecode statique.
