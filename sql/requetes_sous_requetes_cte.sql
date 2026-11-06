/*
    GestionCommandes — 10 requêtes d'analyse avec sous-requêtes et CTE
    Compatible SQL Server 2012+.
    Ces requêtes sont en lecture seule. Exécutez le fichier dans la base GestionCommandes.
*/
USE GestionCommandes;
GO

/* 1. Clients dont les dépenses dépassent la dépense moyenne des clients ayant commandé.
   Notions : CTE, sous-requête scalaire, agrégation. */
;WITH TotalParClient AS
(
    SELECT c.ClientID, c.Nom, c.Prenom,
           SUM(COALESCE(l.MontantLigne, 0)) AS TotalDepense
    FROM dbo.Clients AS c
    LEFT JOIN dbo.Commandes AS co ON co.ClientID = c.ClientID
    LEFT JOIN dbo.LignesCommande AS l ON l.CommandeID = co.CommandeID
    GROUP BY c.ClientID, c.Nom, c.Prenom
)
SELECT ClientID, Nom, Prenom, TotalDepense
FROM TotalParClient
WHERE TotalDepense >
(
    SELECT AVG(CONVERT(DECIMAL(18,2), TotalDepense))
    FROM TotalParClient
    WHERE TotalDepense > 0
)
ORDER BY TotalDepense DESC;

/* 2. Produits dont le prix dépasse le prix moyen de leur catégorie.
   Notions : sous-requête corrélée. */
SELECT p.ProduitID, p.NomProduit, p.Categorie, p.PrixUnitaire
FROM dbo.Produits AS p
WHERE p.PrixUnitaire >
(
    SELECT AVG(p2.PrixUnitaire)
    FROM dbo.Produits AS p2
    WHERE p2.Categorie = p.Categorie
)
ORDER BY p.Categorie, p.PrixUnitaire DESC;

/* 3. Clients qui n'ont encore passé aucune commande.
   Notions : sous-requête avec NOT EXISTS. */
SELECT c.ClientID, c.Nom, c.Prenom, c.Ville, c.Email
FROM dbo.Clients AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Commandes AS co
    WHERE co.ClientID = c.ClientID
)
ORDER BY c.ClientID;

/* 4. Commandes dont le montant dépasse le montant moyen des commandes.
   Notions : CTE et sous-requête scalaire. */
;WITH TotalParCommande AS
(
    SELECT co.CommandeID, co.ClientID, co.DateCommande, co.Statut,
           SUM(l.MontantLigne) AS TotalCommande
    FROM dbo.Commandes AS co
    INNER JOIN dbo.LignesCommande AS l ON l.CommandeID = co.CommandeID
    GROUP BY co.CommandeID, co.ClientID, co.DateCommande, co.Statut
)
SELECT t.CommandeID, t.ClientID, t.DateCommande, t.Statut, t.TotalCommande
FROM TotalParCommande AS t
WHERE t.TotalCommande >
(
    SELECT AVG(TotalCommande)
    FROM TotalParCommande
)
ORDER BY t.TotalCommande DESC;

/* 5. Chiffre d'affaires par catégorie, avec classement des catégories.
   Les commandes annulées sont exclues.
   Notions : CTE et fonction de classement RANK. */
;WITH ChiffreAffairesCategorie AS
(
    SELECT p.Categorie, SUM(l.MontantLigne) AS ChiffreAffaires
    FROM dbo.Produits AS p
    INNER JOIN dbo.LignesCommande AS l ON l.ProduitID = p.ProduitID
    INNER JOIN dbo.Commandes AS co ON co.CommandeID = l.CommandeID
    WHERE co.Statut <> N'Annulée'
    GROUP BY p.Categorie
)
SELECT Categorie, ChiffreAffaires,
       RANK() OVER (ORDER BY ChiffreAffaires DESC) AS RangCategorie
FROM ChiffreAffairesCategorie
ORDER BY RangCategorie, Categorie;

/* 6. Chiffre d'affaires mensuel et évolution par rapport au mois précédent.
   Les commandes annulées sont exclues.
   Notions : deux CTE et fonction analytique LAG. */
;WITH ChiffreAffairesMensuel AS
(
    SELECT DATEFROMPARTS(YEAR(co.DateCommande), MONTH(co.DateCommande), 1) AS Mois,
           SUM(l.MontantLigne) AS ChiffreAffaires
    FROM dbo.Commandes AS co
    INNER JOIN dbo.LignesCommande AS l ON l.CommandeID = co.CommandeID
    WHERE co.Statut <> N'Annulée'
    GROUP BY YEAR(co.DateCommande), MONTH(co.DateCommande)
), EvolutionMensuelle AS
(
    SELECT Mois, ChiffreAffaires,
           LAG(ChiffreAffaires, 1, 0) OVER (ORDER BY Mois) AS CA_MoisPrecedent
    FROM ChiffreAffairesMensuel
)
SELECT Mois, ChiffreAffaires, CA_MoisPrecedent,
       ChiffreAffaires - CA_MoisPrecedent AS VariationMontant
FROM EvolutionMensuelle
ORDER BY Mois;

/* 7. Produits qui ne figurent dans aucune ligne de commande.
   Notions : sous-requête avec NOT EXISTS. */
SELECT p.ProduitID, p.Reference, p.NomProduit, p.Categorie, p.Stock
FROM dbo.Produits AS p
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.LignesCommande AS l
    WHERE l.ProduitID = p.ProduitID
)
ORDER BY p.Categorie, p.NomProduit;

/* 8. Commandes dont le total des lignes diffère du total des paiements.
   Les totaux sont calculés séparément pour éviter de multiplier les montants
   lorsqu'une commande contient plusieurs lignes et plusieurs paiements.
   Notions : CTE, LEFT JOIN et contrôle d'écart. */
;WITH TotalParCommande AS
(
    SELECT co.CommandeID, COALESCE(SUM(l.MontantLigne), 0) AS TotalCommande
    FROM dbo.Commandes AS co
    LEFT JOIN dbo.LignesCommande AS l ON l.CommandeID = co.CommandeID
    GROUP BY co.CommandeID
), TotalPaiements AS
(
    SELECT co.CommandeID, COALESCE(SUM(p.Montant), 0) AS TotalPaye
    FROM dbo.Commandes AS co
    LEFT JOIN dbo.Paiements AS p ON p.CommandeID = co.CommandeID
    GROUP BY co.CommandeID
)
SELECT co.CommandeID, co.Statut, tc.TotalCommande, tp.TotalPaye,
       tc.TotalCommande - tp.TotalPaye AS Ecart
FROM dbo.Commandes AS co
INNER JOIN TotalParCommande AS tc ON tc.CommandeID = co.CommandeID
INNER JOIN TotalPaiements AS tp ON tp.CommandeID = co.CommandeID
WHERE tc.TotalCommande <> tp.TotalPaye
ORDER BY co.CommandeID;

/* 9. Produit le plus vendu en quantité dans chaque catégorie.
   Les commandes annulées sont exclues.
   Notions : CTE et ROW_NUMBER partitionné par catégorie. */
;WITH QuantitesVendues AS
(
    SELECT p.ProduitID, p.NomProduit, p.Categorie,
           SUM(l.Quantite) AS QuantiteVendue
    FROM dbo.Produits AS p
    INNER JOIN dbo.LignesCommande AS l ON l.ProduitID = p.ProduitID
    INNER JOIN dbo.Commandes AS co ON co.CommandeID = l.CommandeID
    WHERE co.Statut <> N'Annulée'
    GROUP BY p.ProduitID, p.NomProduit, p.Categorie
), ClassementProduits AS
(
    SELECT ProduitID, NomProduit, Categorie, QuantiteVendue,
           ROW_NUMBER() OVER
           (
               PARTITION BY Categorie
               ORDER BY QuantiteVendue DESC, ProduitID
           ) AS RangDansCategorie
    FROM QuantitesVendues
)
SELECT Categorie, ProduitID, NomProduit, QuantiteVendue
FROM ClassementProduits
WHERE RangDansCategorie = 1
ORDER BY Categorie;

/* 10. Produits dont le stock est inférieur au stock moyen de leur catégorie.
    Notions : sous-requête corrélée avec moyenne. */
SELECT p.ProduitID, p.NomProduit, p.Categorie, p.Stock
FROM dbo.Produits AS p
WHERE p.Stock <
(
    SELECT AVG(CONVERT(DECIMAL(10,2), p2.Stock))
    FROM dbo.Produits AS p2
    WHERE p2.Categorie = p.Categorie
)
ORDER BY p.Categorie, p.Stock;
