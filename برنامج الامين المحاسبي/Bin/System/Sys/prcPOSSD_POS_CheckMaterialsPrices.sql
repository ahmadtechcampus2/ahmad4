#################################################################
CREATE PROCEDURE prcPOSCheckMatPrice
@POSGuid UNIQUEIDENTIFIER
AS
BEGIN
SET FMTONLY OFF
	
	CREATE TABLE [#MatPrice]
	(
	  MatGuid UNIQUEIDENTIFIER,
	  UnitType INT,
	  Unit  NVARCHAR(256),
	  Price Float
	) 
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
	-- Inserts result into temp table [#Materials]
	EXEC prcPOSGetAllPOSCardMaterials @POSGuid
	
	DECLARE @PriceType INT 
	DECLARE @Res BIT = 1
	DECLARE @PType NVARCHAR(256)
	
	SET @PriceType = (SELECT PriceType FROM POSCard000 WHERE Guid = @POSGuid)
	SELECT @PType = CASE @PriceType WHEN 4 THEN 'Whole'
									WHEN 8  THEN 'Half' 
									WHEN 16  THEN 'Export' 
									WHEN 32  THEN 'Vendor' 
									WHEN 64  THEN 'Retail'
									WHEN 128  THEN 'EndUser'  
									END

	-- Unit1 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			1, 
			Unity, 
			CASE @PriceType WHEN 4	THEN Whole
							WHEN 8	THEN Half
							WHEN 16	THEN Export 
							WHEN 32  THEN Vendor 
							WHEN 64  THEN Retail
							WHEN 128  THEN EndUser 
			END					
		FROM [#Materials]

	-- Unit2 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			2, 
			Unit2, 
			CASE @PriceType WHEN 4	THEN Whole2
							WHEN 8	THEN Half2 
							WHEN 16	THEN Export2 
							WHEN 32  THEN Vendor2 
							WHEN 64  THEN Retail2
							WHEN 128  THEN EndUser2 
			END					
		FROM [#Materials] 

	-- Unit3 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			3, 
			Unit3, 
			CASE @PriceType WHEN 4	THEN Whole3
							WHEN 8	THEN Half3 
							WHEN 16	THEN Export3 
							WHEN 32  THEN Vendor3 
							WHEN 64  THEN Retail3
							WHEN 128  THEN EndUser3 
			END					
		FROM [#Materials]
	IF EXISTS 
		(
			select * from #MatPrice where  (unit <> '' AND price =0)  
			UNION 
			SELECT * FROM #MatPrice mat1 
			WHERE (mat1.price= 0 AND mat1.UnitType =1) 
            AND EXISTS (SELECT 1 FROM #MatPrice mat2 WHERE mat2.MatGuid = mat1.MatGuid AND mat2.price= 0 AND mat2.UnitType = 2)
			AND EXISTS (SELECT 1 FROM #MatPrice mat3 WHERE mat3.MatGuid = mat1.MatGuid AND mat3.price= 0 AND mat3.UnitType = 3)
		 )
	BEGIN
		SET @Res =0
	END

	SELECT @Res	 AS Result 
	DROP TABLE [#MatPrice]
	DROP TABLE [#Materials]

END
#################################################################
#END 