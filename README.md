# Gestion des commandes — SQL Server

Projet de démonstration pour une base de données de gestion des commandes sous Microsoft SQL Server.

## Contenu

- `sql/gestion_commandes.sql` : crée la base `GestionCommandes`, ses cinq tables, leurs relations et index, puis ajoute 50 lignes fictives dans chaque table.
- Les données sont destinées à la démonstration. Les adresses électroniques utilisent `example.com`; les produits, prix et transactions ne représentent pas des ventes réelles.

## Exécution

1. Ouvrez le script dans SQL Server Management Studio (SSMS) ou Azure Data Studio.
2. Connectez-vous à l’instance SQL Server souhaitée avec un compte ayant le droit `CREATE DATABASE` si la base n’existe pas.
3. Exécutez tout le fichier.

Le script crée `GestionCommandes` si elle n’existe pas. Il refuse de continuer si l’une des cinq tables cibles existe déjà; il ne remplace donc pas les tables ou leurs données. Les insertions se font dans une transaction et le script vérifie les 50 lignes par table ainsi que la cohérence des montants.

Pour charger les données dans une base vide portant un autre nom, modifiez les deux références à `GestionCommandes` en tête du script avant exécution.

## Modèle

`Clients` → `Commandes` → `LignesCommande` ← `Produits`, avec `Paiements` rattachée à `Commandes`.

| Table | Rôle |
|---|---|
| `Clients` | Clients de démonstration |
| `Produits` | Catalogue fictif et stocks |
| `Commandes` | Commandes et statuts |
| `LignesCommande` | Produits, quantités et prix historiques |
| `Paiements` | Paiements fictifs liés aux commandes |

Le script cible SQL Server 2012 ou une version ultérieure.
