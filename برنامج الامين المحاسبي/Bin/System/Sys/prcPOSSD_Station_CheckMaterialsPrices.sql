#################################################################
CREATE PROCEDURE prcPOSSD_Station_CheckMaterialsPrices
@POSGuid UNIQUEIDENTIFIER
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_CheckMaterialsPrices
	Purpose: Check if all products has price
	How to Call: EXEC prcPOSSD_Station_CheckMaterialsPrices '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	SET FMTONLY OFF	
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT 
	);
	CREATE TABLE [#MatPrice]
	(
	  MatGuid UNIQUEIDENTIFIER,
	  UnitType INT,
	  Unit  NVARCHAR(256),
	  Price Float
	);
	DECLARE @PriceType INT 
	DECLARE @Res BIT = 1
	DECLARE @PType NVARCHAR(256)
	
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER)
	

	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	  EXEC prcPOSSD_Station_GetGroups @POSGuid

	

   --Fetch materials related to POS   
	INSERT INTO @Materials(MatGuid)
		SELECT MT.[GUID]
		FROM @Groups AS GR  
		INNER JOIN mt000 AS MT ON mt.GroupGUID = GR.GroupGUID;

	

	SET @PriceType = (SELECT PriceType FROM POSSDStation000 WHERE [GUID] = @POSGuid)
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
			MT.Guid, 
			1, 
			MT.Unity, 
			CASE @PriceType WHEN 4	THEN MT.Whole
							WHEN 8	THEN MT.Half
							WHEN 16	THEN MT.Export 
							WHEN 32  THEN MT.Vendor 
							WHEN 64  THEN MT.Retail
							WHEN 128  THEN MT.EndUser 
			END					
		FROM @Materials AS FMT INNER JOIN mt000 AS MT ON (MT.GUID = FMT.MatGuid)
	-- Unit2 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			MT.Guid, 
			2, 
			MT.Unit2, 
			CASE @PriceType WHEN 4	THEN MT.Whole2
							WHEN 8	THEN MT.Half2 
							WHEN 16	THEN MT.Export2 
							WHEN 32  THEN MT.Vendor2 
							WHEN 64  THEN MT.Retail2
							WHEN 128  THEN MT.EndUser2 
			END					
		FROM @Materials AS FMT INNER JOIN mt000 AS MT ON (MT.GUID = FMT.MatGuid)
	-- Unit3 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			MT.Guid, 
			3, 
			MT.Unit3, 
			CASE @PriceType WHEN 4	THEN MT.Whole3
							WHEN 8	THEN MT.Half3 
							WHEN 16	THEN MT.Export3 
							WHEN 32  THEN MT.Vendor3 
							WHEN 64  THEN MT.Retail3
							WHEN 128  THEN MT.EndUser3 
			END					
		FROM @Materials AS FMT INNER JOIN mt000 AS MT ON (MT.GUID = FMT.MatGuid)
	
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
END
#################################################################
#END 