
DROP TABLE IF EXISTS Metadata.ColumnRule
DROP TABLE IF EXISTS Metadata.RuleDefinition
DROP TABLE IF EXISTS Metadata.EntityColumn
DROP TABLE IF EXISTS Metadata.Entity
DROP TABLE IF EXISTS Metadata.SourceSystem
GO

DROP PROC IF EXISTS Metadata.ObtainEntityMetadata

DROP SCHEMA IF EXISTS Metadata
GO

CREATE SCHEMA Metadata
GO

CREATE TABLE Metadata.SourceSystem
(
	 SourceSystemId INT IDENTITY(1,1) NOT NULL
	,SourceSystemName VARCHAR(100) NOT NULL

	,CONSTRAINT pk_SourceSystem PRIMARY KEY (SourceSystemId)
)
GO

CREATE TABLE Metadata.Entity
(
	 EntityId INT IDENTITY(1,1) NOT NULL
	,EntityName VARCHAR(100) NOT NULL
	,EntityType VARCHAR(10) NOT NULL
	,SourceSystemId INT NOT NULL
	,EntityObtainString NVARCHAR(500) NULL
	,EntityRootPath NVARCHAR(500) NOT NULL

	,CONSTRAINT pk_Entity PRIMARY KEY (EntityId)
	,CONSTRAINT fk_Entity_SourceSystem FOREIGN KEY (SourceSystemId) REFERENCES Metadata.SourceSystem (SourceSystemId)
)
GO

CREATE TABLE Metadata.EntityColumn
(
	 EntityColumnId INT IDENTITY(1,1) NOT NULL
	,EntityColumnName VARCHAR(100) NOT NULL
	,EntityId INT NOT NULL
	,EntitySchemaVersion INT NOT NULL
	,ColumnDataType VARCHAR(100) NOT NULL
	,ColumnOrder INT NOT NULL

	,CONSTRAINT pk_EntityColumn PRIMARY KEY (EntityColumnId)
	,CONSTRAINT fk_EntityColumn_Entity FOREIGN KEY (EntityId) REFERENCES Metadata.Entity (EntityId)
)
GO

CREATE TABLE Metadata.RuleDefinition
(
	 RuleId INT IDENTITY (1,1) NOT NULL
	,RuleCode VARCHAR(25) NOT NULL
	,RuleDefinition NVARCHAR(500) NOT NULL

	,CONSTRAINT pk_Rule PRIMARY KEY (RuleId)
)
GO

CREATE TABLE Metadata.ColumnRule
(
	 EntityColumnId INT NOT NULL
	,RuleId INT NOT NULL
	,RuleOrder INT DEFAULT 0

	,CONSTRAINT pk_ColumnRule PRIMARY KEY (RuleId, EntityColumnId)
	,CONSTRAINT fk_ColumnRule_RuleDef FOREIGN KEY (RuleId) REFERENCES Metadata.RuleDefinition (RuleId)
	,CONSTRAINT fk_ColumnRule_EntityColumn FOREIGN KEY (EntityColumnId) REFERENCES Metadata.EntityColumn (EntityColumnId)
)
GO

CREATE PROC Metadata.ObtainEntityMetadata
(
	@EntityName VARCHAR(100) = NULL
)

AS
BEGIN

	SELECT
		 e.EntityName
		,e.EntityType
	FROM Metadata.Entity AS e
	WHERE EntityName = COALESCE(@EntityName, EntityName)

	SELECT
		 e.EntityName
		,e.EntityType
		,ec.EntityColumnName
		,ec.EntitySchemaVersion
		,ec.ColumnDataType
		,ec.ColumnOrder
		,rd.RuleDefinition
	FROM Metadata.Entity AS e
		INNER JOIN Metadata.EntityColumn AS ec
			ON ec.EntityId = e.EntityId
		INNER JOIN Metadata.ColumnRule AS cr
			ON cr.EntityColumnId = ec.EntityColumnId
		INNER JOIN Metadata.RuleDefinition AS rd
			ON rd.RuleId = cr.RuleId
	WHERE EntityName = COALESCE(@EntityName, EntityName)
	ORDER BY ColumnOrder, RuleOrder

END
GO

INSERT INTO Metadata.SourceSystem
VALUES
	('SalesSystem')
GO

INSERT INTO Metadata.Entity
VALUES
	('Sales', 'Source', 1, 'SELECT * FROM dbo.Sales', '/SalesSystem/Sales/'),
	('Product', 'Source', 1, NULL, '/SalesSystem/Product/')
GO

INSERT INTO Metadata.EntityColumn
VALUES
	('SalesSystemId', 1, 0, 'INTEGER', 0),
	('SalesPerson', 1, 0, 'NVARCHAR(100)',1),
	('SalesAmount', 1, 0, 'DECIMAL(10,2)',2),
	('ProductName', 1, 0, 'NVARCHAR(100)',3),
	('ProductId', 1, 0, 'INTEGER',4),
	('CustomerId',1, 0, 'INTEGER',5)
GO

INSERT INTO Metadata.RuleDefinition
VALUES
	('CleanString', 'LTRIM(RTRIM(REPLACE(REPLACE(REPLACE([%%COLUMN_NAME%%], char(9),''''),char(10),''''),char(13),'''')))'),
	('SupplyZero', 'COALESCE([%%COLUMN_NAME%%],0)'),
	('StandariseNull','REPLACE(REPLACE([%%COLUMN_NAME%%],''Unknown'',NULL),''N/A'',NULL)')
GO

INSERT INTO Metadata.ColumnRule
VALUES
	 (2,1,0)
	,(3,2,0)
	,(4,1,0)
	,(4,3,1)
	,(5,3,0)
	,(6,3,0)
GO

SELECT COUNT(*) AS 'Metadata.ColumnRule' FROM Metadata.ColumnRule
SELECT COUNT(*) AS 'Metadata.RuleDefinition' FROM Metadata.RuleDefinition
SELECT COUNT(*) AS 'Metadata.EntityColumn' FROM Metadata.EntityColumn
SELECT COUNT(*) AS 'Metadata.Entity' FROM Metadata.Entity
SELECT COUNT(*) AS 'Metadata.SourceSystem' FROM Metadata.SourceSystem