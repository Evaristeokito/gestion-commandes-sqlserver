/* SQL Server — Exécuter le fichier complet dans SSMS ou Azure Data Studio.
   5 tables, exactement 50 enregistrements dans chacune.
   Noms de produits réels ; prix en EUR, stocks, personnes et transactions fictifs.
   Aucun lien commercial ou achat réel n'est représenté.
   Les montants sont simplifiés : aucune taxe ni livraison supplémentaire.
   Le compte doit avoir le droit CREATE DATABASE si la base n'existe pas.
   Le script refuse de modifier des tables déjà présentes sous ces noms.
*/
USE master;
GO
IF DB_ID(N'GestionCommandes') IS NULL
    EXEC(N'CREATE DATABASE GestionCommandes');
GO
USE GestionCommandes;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Clients') IS NOT NULL
       OR OBJECT_ID(N'dbo.Produits') IS NOT NULL
       OR OBJECT_ID(N'dbo.Commandes') IS NOT NULL
       OR OBJECT_ID(N'dbo.LignesCommande') IS NOT NULL
       OR OBJECT_ID(N'dbo.Paiements') IS NOT NULL
    BEGIN
        THROW 50001, N'Une table cible existe déjà. Aucune donnée ne sera remplacée.', 1;
    END;

    CREATE TABLE dbo.Clients (
        ClientID INT IDENTITY(1,1) CONSTRAINT PK_Clients PRIMARY KEY,
        Nom NVARCHAR(80) NOT NULL,
        Prenom NVARCHAR(80) NOT NULL,
        Email NVARCHAR(150) NOT NULL CONSTRAINT UQ_Clients_Email UNIQUE,
        Ville NVARCHAR(80) NOT NULL,
        Pays NVARCHAR(80) NOT NULL,
        DateInscription DATE NOT NULL
    );

    CREATE TABLE dbo.Produits (
        ProduitID INT IDENTITY(1,1) CONSTRAINT PK_Produits PRIMARY KEY,
        Reference VARCHAR(20) NOT NULL CONSTRAINT UQ_Produits_Reference UNIQUE,
        NomProduit NVARCHAR(150) NOT NULL,
        Categorie NVARCHAR(60) NOT NULL,
        PrixUnitaire DECIMAL(12,2) NOT NULL CONSTRAINT CK_Produits_Prix CHECK (PrixUnitaire > 0),
        Stock INT NOT NULL CONSTRAINT CK_Produits_Stock CHECK (Stock >= 0)
    );

    CREATE TABLE dbo.Commandes (
        CommandeID INT IDENTITY(1,1) CONSTRAINT PK_Commandes PRIMARY KEY,
        ClientID INT NOT NULL,
        DateCommande DATE NOT NULL,
        Statut NVARCHAR(20) NOT NULL
            CONSTRAINT CK_Commandes_Statut CHECK (Statut IN (N'En attente', N'Payée', N'Expédiée', N'Livrée', N'Annulée')),
        CONSTRAINT FK_Commandes_Clients FOREIGN KEY (ClientID) REFERENCES dbo.Clients(ClientID)
    );

    CREATE TABLE dbo.LignesCommande (
        LigneCommandeID INT IDENTITY(1,1) CONSTRAINT PK_LignesCommande PRIMARY KEY,
        CommandeID INT NOT NULL,
        ProduitID INT NOT NULL,
        Quantite INT NOT NULL CONSTRAINT CK_LignesCommande_Quantite CHECK (Quantite > 0),
        PrixUnitaire DECIMAL(12,2) NOT NULL CONSTRAINT CK_LignesCommande_Prix CHECK (PrixUnitaire > 0),
        MontantLigne AS CONVERT(DECIMAL(18,2), Quantite * PrixUnitaire) PERSISTED,
        CONSTRAINT FK_LignesCommande_Commandes FOREIGN KEY (CommandeID) REFERENCES dbo.Commandes(CommandeID),
        CONSTRAINT FK_LignesCommande_Produits FOREIGN KEY (ProduitID) REFERENCES dbo.Produits(ProduitID),
        CONSTRAINT UQ_LignesCommande_Produit UNIQUE (CommandeID, ProduitID)
    );

    CREATE TABLE dbo.Paiements (
        PaiementID INT IDENTITY(1,1) CONSTRAINT PK_Paiements PRIMARY KEY,
        CommandeID INT NOT NULL,
        DatePaiement DATE NOT NULL,
        Montant DECIMAL(18,2) NOT NULL CONSTRAINT CK_Paiements_Montant CHECK (Montant > 0),
        ModePaiement NVARCHAR(30) NOT NULL
            CONSTRAINT CK_Paiements_Mode CHECK (ModePaiement IN (N'Carte bancaire', N'Virement', N'PayPal')),
        ReferenceTransaction VARCHAR(30) NOT NULL CONSTRAINT UQ_Paiements_Reference UNIQUE,
        CONSTRAINT FK_Paiements_Commandes FOREIGN KEY (CommandeID) REFERENCES dbo.Commandes(CommandeID)
    );

    CREATE INDEX IX_Commandes_ClientID ON dbo.Commandes(ClientID);
    CREATE INDEX IX_LignesCommande_ProduitID ON dbo.LignesCommande(ProduitID);
    CREATE INDEX IX_Paiements_CommandeID ON dbo.Paiements(CommandeID);

    -- Suite de nombres utilisée pour créer exactement 50 lignes.
    DECLARE @N TABLE (N INT PRIMARY KEY);
    INSERT INTO @N (N)
    SELECT 10 * d.N + u.N + 1
    FROM (VALUES (0),(1),(2),(3),(4)) AS d(N)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS u(N);

    -- Identités fictives : les courriels utilisent le domaine réservé example.com.
    SET IDENTITY_INSERT dbo.Clients ON;
    INSERT INTO dbo.Clients (ClientID, Nom, Prenom, Email, Ville, Pays, DateInscription)
    SELECT N,
        CHOOSE((N - 1) % 10 + 1, N'Martin', N'Bernard', N'Dubois', N'Thomas', N'Robert', N'Richard', N'Petit', N'Durand', N'Leroy', N'Moreau'),
        CHOOSE((N - 1) / 10 + 1, N'Alice', N'Gabriel', N'Camille', N'Louis', N'Emma'),
        CONCAT(N'client', RIGHT(CONCAT('000', N), 3), N'@example.com'),
        CHOOSE((N - 1) % 10 + 1, N'Paris', N'Lyon', N'Marseille', N'Toulouse', N'Nice', N'Nantes', N'Strasbourg', N'Montpellier', N'Bordeaux', N'Lille'),
        N'France', DATEADD(DAY, N - 1, CONVERT(DATE, '20250101', 112))
    FROM @N;
    SET IDENTITY_INSERT dbo.Clients OFF;

    -- Catalogue illustratif, sans prétendre refléter les prix du marché.
    SET IDENTITY_INSERT dbo.Produits ON;
    INSERT INTO dbo.Produits (ProduitID, Reference, NomProduit, Categorie, PrixUnitaire, Stock)
    VALUES
    (1,'PRD-001',N'Apple iPhone 15 128 Go',N'Téléphonie',799.00,25),
    (2,'PRD-002',N'Samsung Galaxy S24 128 Go',N'Téléphonie',749.00,30),
    (3,'PRD-003',N'Google Pixel 8 128 Go',N'Téléphonie',599.00,20),
    (4,'PRD-004',N'Xiaomi Redmi Note 13 128 Go',N'Téléphonie',199.00,45),
    (5,'PRD-005',N'Apple iPad 10e génération 64 Go',N'Tablettes',399.00,18),
    (6,'PRD-006',N'Samsung Galaxy Tab A9 64 Go',N'Tablettes',179.00,22),
    (7,'PRD-007',N'Apple MacBook Air M2 256 Go',N'Ordinateurs',1099.00,12),
    (8,'PRD-008',N'Dell XPS 13 9315',N'Ordinateurs',1199.00,10),
    (9,'PRD-009',N'Lenovo ThinkPad T14 Gen 4',N'Ordinateurs',1299.00,15),
    (10,'PRD-010',N'HP Pavilion 15',N'Ordinateurs',699.00,20),
    (11,'PRD-011',N'Logitech MX Master 3S',N'Périphériques',99.00,40),
    (12,'PRD-012',N'Logitech MX Keys S',N'Périphériques',109.00,35),
    (13,'PRD-013',N'Logitech C920 HD Pro',N'Périphériques',69.00,30),
    (14,'PRD-014',N'Razer DeathAdder V3',N'Périphériques',79.00,25),
    (15,'PRD-015',N'Apple Magic Mouse',N'Périphériques',85.00,20),
    (16,'PRD-016',N'Dell UltraSharp U2723QE',N'Écrans',549.00,14),
    (17,'PRD-017',N'LG UltraGear 27GP850-B',N'Écrans',329.00,16),
    (18,'PRD-018',N'Samsung Odyssey G5 27 pouces',N'Écrans',249.00,18),
    (19,'PRD-019',N'Samsung 990 PRO SSD 1 To',N'Stockage',119.00,50),
    (20,'PRD-020',N'Crucial MX500 SSD 1 To',N'Stockage',79.00,45),
    (21,'PRD-021',N'WD Blue SN580 SSD 1 To',N'Stockage',69.00,40),
    (22,'PRD-022',N'Seagate Expansion 2 To',N'Stockage',75.00,32),
    (23,'PRD-023',N'SanDisk Ultra microSDXC 128 Go',N'Stockage',19.00,100),
    (24,'PRD-024',N'Kingston DataTraveler Exodia 64 Go',N'Stockage',9.00,120),
    (25,'PRD-025',N'Sony WH-1000XM5',N'Audio',329.00,24),
    (26,'PRD-026',N'Bose QuietComfort Ultra Headphones',N'Audio',399.00,18),
    (27,'PRD-027',N'Apple AirPods Pro 2',N'Audio',249.00,35),
    (28,'PRD-028',N'JBL Flip 6',N'Audio',109.00,40),
    (29,'PRD-029',N'Sonos Era 100',N'Audio',229.00,15),
    (30,'PRD-030',N'Audio-Technica ATH-M50x',N'Audio',149.00,20),
    (31,'PRD-031',N'Canon PIXMA TS5350i',N'Imprimantes',89.00,20),
    (32,'PRD-032',N'Epson EcoTank ET-2850',N'Imprimantes',279.00,14),
    (33,'PRD-033',N'Brother HL-L2350DW',N'Imprimantes',149.00,17),
    (34,'PRD-034',N'TP-Link Archer AX55',N'Réseau',99.00,28),
    (35,'PRD-035',N'ASUS RT-AX58U',N'Réseau',139.00,20),
    (36,'PRD-036',N'TP-Link TL-SG108',N'Réseau',29.00,50),
    (37,'PRD-037',N'Netgear EX6120',N'Réseau',49.00,30),
    (38,'PRD-038',N'PlayStation 5 Slim',N'Jeux vidéo',499.00,18),
    (39,'PRD-039',N'Xbox Series X',N'Jeux vidéo',499.00,16),
    (40,'PRD-040',N'Nintendo Switch OLED',N'Jeux vidéo',319.00,25),
    (41,'PRD-041',N'Sony DualSense',N'Jeux vidéo',69.00,45),
    (42,'PRD-042',N'Xbox Wireless Controller',N'Jeux vidéo',59.00,40),
    (43,'PRD-043',N'Garmin Forerunner 255',N'Objets connectés',279.00,15),
    (44,'PRD-044',N'Apple Watch Series 9 GPS 41 mm',N'Objets connectés',399.00,20),
    (45,'PRD-045',N'Samsung Galaxy Watch6 40 mm',N'Objets connectés',229.00,22),
    (46,'PRD-046',N'Amazon Kindle Paperwhite 16 Go',N'Liseuses',159.00,25),
    (47,'PRD-047',N'Kobo Clara 2E',N'Liseuses',139.00,20),
    (48,'PRD-048',N'GoPro HERO12 Black',N'Photo et vidéo',349.00,12),
    (49,'PRD-049',N'Canon EOS R50 avec RF-S 18-45 mm',N'Photo et vidéo',799.00,10),
    (50,'PRD-050',N'Sony ZV-E10 avec objectif 16-50 mm',N'Photo et vidéo',699.00,12);
    SET IDENTITY_INSERT dbo.Produits OFF;

    -- 50 commandes réparties sur 40 clients : certains ont plusieurs commandes,
    -- les 10 derniers clients n'ont pas encore commandé.
    SET IDENTITY_INSERT dbo.Commandes ON;
    INSERT INTO dbo.Commandes (CommandeID, ClientID, DateCommande, Statut)
    SELECT N, (N - 1) % 40 + 1,
        DATEADD(DAY, N - 1, CONVERT(DATE, '20250301', 112)),
        CASE WHEN N <= 35 THEN N'Livrée' WHEN N <= 45 THEN N'Expédiée' ELSE N'Payée' END
    FROM @N;
    SET IDENTITY_INSERT dbo.Commandes OFF;

    -- Une ligne par commande dans ce jeu ; le schéma accepte plusieurs lignes.
    INSERT INTO dbo.LignesCommande (CommandeID, ProduitID, Quantite, PrixUnitaire)
    SELECT n.N, p.ProduitID, (n.N - 1) % 3 + 1, p.PrixUnitaire
    FROM @N AS n
    INNER JOIN dbo.Produits AS p ON p.ProduitID = n.N;

    -- Prix historique conservé dans les lignes ; le total est calculé.
    INSERT INTO dbo.Paiements (CommandeID, DatePaiement, Montant, ModePaiement, ReferenceTransaction)
    SELECT c.CommandeID, c.DateCommande, SUM(l.MontantLigne),
        CHOOSE((c.CommandeID - 1) % 3 + 1, N'Carte bancaire', N'Virement', N'PayPal'),
        CONCAT('DEMO-TXN-', RIGHT(CONCAT('00000', c.CommandeID), 5))
    FROM dbo.Commandes AS c
    INNER JOIN dbo.LignesCommande AS l ON l.CommandeID = c.CommandeID
    GROUP BY c.CommandeID, c.DateCommande;

    -- Vérifications avant validation définitive des insertions.
    IF (SELECT COUNT(*) FROM dbo.Clients) <> 50
       OR (SELECT COUNT(*) FROM dbo.Produits) <> 50
       OR (SELECT COUNT(*) FROM dbo.Commandes) <> 50
       OR (SELECT COUNT(*) FROM dbo.LignesCommande) <> 50
       OR (SELECT COUNT(*) FROM dbo.Paiements) <> 50
    BEGIN
        THROW 50002, N'Le nombre attendu de 50 lignes par table est incorrect.', 1;
    END;

    IF EXISTS (
        SELECT c.CommandeID
        FROM dbo.Commandes AS c
        OUTER APPLY (SELECT SUM(MontantLigne) AS Total FROM dbo.LignesCommande WHERE CommandeID = c.CommandeID) AS l
        OUTER APPLY (SELECT SUM(Montant) AS Total FROM dbo.Paiements WHERE CommandeID = c.CommandeID) AS p
        WHERE l.Total IS NULL OR p.Total IS NULL OR l.Total <> p.Total
    )
    BEGIN
        THROW 50003, N'Les paiements ne correspondent pas aux montants des commandes.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Résultat attendu : 50 dans chaque table, soit 250 enregistrements.
SELECT N'Clients' AS NomTable, COUNT(*) AS NombreEnregistrements FROM dbo.Clients
UNION ALL SELECT N'Produits', COUNT(*) FROM dbo.Produits
UNION ALL SELECT N'Commandes', COUNT(*) FROM dbo.Commandes
UNION ALL SELECT N'LignesCommande', COUNT(*) FROM dbo.LignesCommande
UNION ALL SELECT N'Paiements', COUNT(*) FROM dbo.Paiements;

-- Nombre de commandes par client, y compris les clients sans commande.
SELECT c.ClientID, c.Nom, c.Prenom, COUNT(co.CommandeID) AS NombreCommandes
FROM dbo.Clients AS c
LEFT JOIN dbo.Commandes AS co ON co.ClientID = c.ClientID
GROUP BY c.ClientID, c.Nom, c.Prenom
ORDER BY NombreCommandes DESC, c.ClientID;

-- Détail et montant de chaque commande, en euros.
SELECT co.CommandeID, co.DateCommande, c.Nom, c.Prenom, co.Statut,
       SUM(l.MontantLigne) AS TotalCommandeEUR
FROM dbo.Commandes AS co
INNER JOIN dbo.Clients AS c ON c.ClientID = co.ClientID
INNER JOIN dbo.LignesCommande AS l ON l.CommandeID = co.CommandeID
GROUP BY co.CommandeID, co.DateCommande, c.Nom, c.Prenom, co.Statut
ORDER BY co.CommandeID;
