#################################################################
CREATE PROCEDURE prcPOSGetAllPOSCardMaterials
@POSCardGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT 
	) 
	
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
		EXEC prcPOSGetRelatedGroups @POSCardGuid
	
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER)
	
	INSERT INTO @Materials(MatGuid)
		SELECT DISTINCT [GUID] 
		FROM @Groups groups  
		INNER JOIN mt000 mt ON mt.GroupGUID = groups.GroupGUID
	
	INSERT INTO @Materials(MatGuid)
		SELECT [mt].[GUID]
		FROM @Groups AS [grp]
		INNER JOIN [gri000] AS [gri] ON [gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid]
	-- Collective Groups Materials --
	DECLARE @GroupGUID UNIQUEIDENTIFIER
	DECLARE @GroupCursor as CURSOR;
	SET @GroupCursor = CURSOR FOR SELECT GroupGUID FROM @Groups
	
	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @GroupGUID;
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		INSERT INTO @Materials(MatGuid)
			SELECT mtGUID 
			FROM fnGetMatsOfCollectiveGrps(@GroupGUID)
			WHERE NOT EXISTS
					(	SELECT MatGuid 
						FROM @Materials
						WHERE MatGuid = mtGUID
					)
			
		 FETCH NEXT FROM @GroupCursor INTO @GroupGUID;
	END
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;
	----------------------------------------
	INSERT INTO [#Materials]
		SELECT distinct(mt.Number),
					mt.Code,
					mt.GUID,
					mt.GroupGUID,
					mt.LatinName,
					mt.Name,
					mt.Unity,
					mt.Unit2,
					mt.Unit3,
					mt.DefUnit,
					mt.Unit2Fact,
					mt.Unit3Fact,
					mt.Unit2FactFlag,
					mt.Unit3FactFlag,
					mt.Whole,
					mt.Whole2,
					mt.Whole3,
					mt.Half,
					mt.Half2,
					mt.Half3,
					mt.EndUser,
					mt.EndUser2,
					mt.EndUser3,
					mt.Vendor,
					mt.Vendor2,
					mt.Vendor3,
					mt.Export,
					mt.Export2,
					mt.Export3,
					mt.LastPrice,
					mt.LastPrice2,
					mt.LastPrice3,
					mt.AvgPrice,
					mt.BarCode,
					mt.BarCode2,
					mt.BarCode3,
					mt.PictureGUID,
					mt.Retail,
					mt.Retail2,
					mt.Retail3,
					mt.MaxPrice,
					mt.MaxPrice2,
					mt.MaxPrice3,
					mt.type,
					mt.VAT AS TaxRatio,
					CAST((CASE ISNULL(ME.GUID, 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 1 THEN 1 ELSE 0 END) END) AS BIT) AS HasCrossSaleMaterials,
					CAST((CASE ISNULL(ME.GUID, 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 2 THEN 1 ELSE 0 END) END) AS BIT) AS HasUpSaleMaterials,
					ISNULL(ME.Question, '')      AS CrossSaleQuestion,
				    ISNULL(ME.LatinQuestion, '') AS CrossSaleLatinQuestion
		FROM @Materials mats
		INNER JOIN mt000 mt ON mt.GUID = mats.MatGuid
		LEFT JOIN POSSDMaterialExtended000 ME ON mats.MatGuid = ME.MaterialGUID
END
#################################################################
CREATE PROCEDURE prcPOSGetRelatedMaterials
@POSCardGuid UNIQUEIDENTIFIER,
@PageSize INT = 200,
@PageIndex INT = 0
AS
BEGIN
	--DECLARE @material TABLE
	--(
	--    Number			INT,
	--	Code			NVARCHAR(100),
	--	GUID			UNIQUEIDENTIFIER PRIMARY KEY,
	--	GroupGUID		UNIQUEIDENTIFIER,
	--	LatinName		NVARCHAR(250),
	--	Name			NVARCHAR(250),
	--	Unity			NVARCHAR(100),
	--	Unit2			NVARCHAR(100),
	--	Unit3			NVARCHAR(100),
	--	DefUnit			INT,
	--	Unit2Fact		FLOAT,
	--	Unit3Fact		FLOAT,
	--	Unit2FactFlag	BIT,
	--	Unit3FactFlag	BIT,
	--	Whole			FLOAT,
	--	Whole2			FLOAT,
	--	Whole3			FLOAT,
	--	Half			FLOAT,
	--	Half2			FLOAT,
	--	Half3			FLOAT,
	--	EndUser			FLOAT,
	--	EndUser2		FLOAT,
	--	EndUser3		FLOAT,
	--	Vendor			FLOAT,
	--	Vendor2			FLOAT,
	--	Vendor3			FLOAT,
	--	Export			FLOAT,
	--	Export2			FLOAT,
	--	Export3			FLOAT,
	--	LastPrice		FLOAT,
	--	LastPrice2		FLOAT,
	--	LastPrice3		FLOAT,
	--	AvgPrice		FLOAT,
	--	BarCode			NVARCHAR(100),
	--	BarCode2		NVARCHAR(100),
	--	BarCode3		NVARCHAR(100),
	--	PictureGUID		UNIQUEIDENTIFIER,
	--	Retail			FLOAT,
	--	Retail2			FLOAT,
	--	Retail3			FLOAT,
	--	MaxPrice		FLOAT,
	--	MaxPrice2		FLOAT,
	--	MaxPrice3		FLOAT,
	--	type			INT,
	--	TaxRatio	FLOAT,
	--	HasCrossSaleMaterials BIT,
	--	HasUpSaleMaterials BIT,
	--	CrossSaleQuestion NVARCHAR(500),
	--	CrossSaleLatinQuestion NVARCHAR(500) )
	--SELECT * FROM @material

	CREATE TABLE [#Materials]
	(
		Number			INT,
		Code			NVARCHAR(100),
		GUID			UNIQUEIDENTIFIER,
		GroupGUID		UNIQUEIDENTIFIER,
		LatinName		NVARCHAR(250),
		Name			NVARCHAR(250),
		Unity			NVARCHAR(100),
		Unit2			NVARCHAR(100),
		Unit3			NVARCHAR(100),
		DefUnit			INT,
		Unit2Fact		FLOAT,
		Unit3Fact		FLOAT,
		Unit2FactFlag	BIT,
		Unit3FactFlag	BIT,
		Whole			FLOAT,
		Whole2			FLOAT,
		Whole3			FLOAT,
		Half			FLOAT,
		Half2			FLOAT,
		Half3			FLOAT,
		EndUser			FLOAT,
		EndUser2		FLOAT,
		EndUser3		FLOAT,
		Vendor			FLOAT,
		Vendor2			FLOAT,
		Vendor3			FLOAT,
		Export			FLOAT,
		Export2			FLOAT,
		Export3			FLOAT,
		LastPrice		FLOAT,
		LastPrice2		FLOAT,
		LastPrice3		FLOAT,
		AvgPrice		FLOAT,
		BarCode			NVARCHAR(100),
		BarCode2		NVARCHAR(100),
		BarCode3		NVARCHAR(100),
		PictureGUID		UNIQUEIDENTIFIER,
		Retail			FLOAT,
		Retail2			FLOAT,
		Retail3			FLOAT,
		MaxPrice		FLOAT,
		MaxPrice2		FLOAT,
		MaxPrice3		FLOAT,
		type			INT,
		TaxRatio	FLOAT,
		HasCrossSaleMaterials BIT,
		HasUpSaleMaterials BIT,
		CrossSaleQuestion NVARCHAR(500),
		CrossSaleLatinQuestion NVARCHAR(500)
	)
	-- Inserts result in to temp table materials
	EXEC prcPOSGetAllPOSCardMaterials @POSCardGuid
	SELECT distinct(Number),
				Code,
				GUID,
				GroupGUID,
				LatinName,
				Name,
				Unity,
				Unit2,
				Unit3,
				DefUnit,
				Unit2Fact,
				Unit3Fact,
				Unit2FactFlag,
				Unit3FactFlag,
				Whole,
				Whole2,
				Whole3,
				Half,
				Half2,
				Half3,
				EndUser,
				EndUser2,
				EndUser3,
				Vendor,
				Vendor2,
				Vendor3,
				Export,
				Export2,
				Export3,
				LastPrice,
				LastPrice2,
				LastPrice3,
				AvgPrice,
				BarCode,
				BarCode2,
				BarCode3,
				PictureGUID,
				Retail,
				Retail2,
				Retail3,
				MaxPrice,
				MaxPrice2,
				MaxPrice3,
				type,
				TaxRatio ,
				HasCrossSaleMaterials,
				HasUpSaleMaterials,
				CrossSaleQuestion,
				CrossSaleLatinQuestion
	FROM #Materials
	ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
	DROP TABLE [#Materials]
END
#################################################################
#END 