# Auctionator backport TBC 2.4.3

## Objectif de cette passe

Cette adaptation vise une base chargeable et testable sur un client World of Warcraft The Burning Crusade 2.4.3 avec hotel des ventes legacy.

Priorites de cette passe :

- chargement sans erreurs Lua au login
- ouverture de l'addon sans casser l'HV Blizzard
- recherche d'objets avec l'API legacy
- affichage d'une liste simple de resultats
- aide simple a la vente via l'emplacement de vente Blizzard

## Ce qui a ete desactive

Le `.toc` 2.4.3 ne charge plus la pile moderne multi-clients. Les repertoires suivants sont neutralises pour cette premiere passe :

- `Source_Mainline`
- `Source_ModernAH`
- `Imports_ModernAH`
- `Libs_ModernAH`
- `Source_Classic`
- `Data_Cata`
- la quasi-totalite de `Source`
- la quasi-totalite de `Source_LegacyAH`
- la quasi-totalite de `Source_Vanilla`

Raison :

- ces fichiers utilisent massivement des APIs et patterns absents en 2.4.3
- meme la branche `LegacyAH` depend encore de mixins, wrappers et utilitaires modernes
- les templates XML et scroll lists modernes sont une source de casse immediate sur un client 2.4.3

## Ce qui fonctionne dans cette version

- chargement via `## Interface: 20400`
- bouton `ATR` ajoute a cote de l'HV Blizzard
- panneau lateral Auctionator attache a l'HV Blizzard
- recherche par nom d'objet avec `QueryAuctionItems`
- pagination simple via `Prev` et `Next`
- filtre "nom exact" applique cote addon sur les resultats recus
- affichage d'une liste simple : nom, taille de pile, prix unitaire, prix total, vendeur
- scan rapide de l'objet place dans l'emplacement de vente Blizzard
- remplissage automatique d'un prix de depart et d'un prix d'achat immediat a partir du meilleur resultat visible
- creation d'une vente via `StartAuction`
- petit mode debug activable avec `/atr debug`

## APIs modernes remplacees ou neutralisees

Neutralisees par exclusion du chargement :

- `C_AuctionHouse`
- `C_Timer`
- `C_Item`
- `C_Container`
- `Enum.*`
- `CreateFromMixins`
- `Mixin`
- `BackdropTemplateMixin`
- `ScrollUtil`
- `Settings`
- les layouts/options modernes

Remplacements utilises dans le backport :

- `QueryAuctionItems`
- `GetAuctionItemInfo`
- `GetAuctionItemLink`
- `GetNumAuctionItems`
- `CanSendAuctionQuery`
- `StartAuction`
- `AUCTION_HOUSE_SHOW`
- `AUCTION_HOUSE_CLOSED`
- `AUCTION_ITEM_LIST_UPDATE`
- `AUCTION_OWNED_LIST_UPDATE`
- `NEW_AUCTION_UPDATE`

## Ce qui reste a faire

- achat direct et enchere depuis la liste de resultats
- scan complet / historique de prix plus riche
- integration de listes d'achat
- annulation d'encheres
- options persistantes plus fines
- meilleure integration UI avec les onglets Blizzard
- meilleure gestion des recherches exactes sur plusieurs pages
- validation en conditions reelles sur Cmangos si l'ordre des retours API differe legerement

## Installation

1. Copier ce dossier sous `Interface/AddOns/Auctionator`
2. Verifier que le fichier s'appelle `Auctionator.toc`
3. Lancer le client WoW TBC 2.4.3
4. Ouvrir l'hotel des ventes
5. Cliquer sur `ATR` pour afficher ou masquer le panneau

## Tests en jeu recommandes

- verifier qu'aucune erreur Lua ne se produit au login
- verifier que l'HV Blizzard s'ouvre normalement
- rechercher un objet simple comme `Netherweave Cloth`
- verifier que la pagination `Prev/Next` fonctionne
- placer un objet dans l'emplacement de vente Blizzard
- cliquer sur `Scanner l'objet`
- verifier le remplissage automatique des prix
- cliquer sur `Creer la vente`
- verifier que l'enchere apparait dans l'onglet Blizzard des ventes
