###########################################################################
CREATE PROC prcUpdateCompositeMaterialSpecsInfo
	@ParentId		UNIQUEIDENTIFIER,
	@UpdateAll		BIT = 0	
AS
	SET NOCOUNT ON 

	UPDATE mt
	SET High = ParentTable.High,
		Low = ParentTable.Low,
		OrderLimit = ParentTable.OrderLimit,
		Whole = ParentTable.Whole,
		Half = ParentTable.Half,
		Retail = ParentTable.Retail,
		EndUser = ParentTable.EndUser,
		Export = ParentTable.Export,
		Vendor = ParentTable.Vendor,
		MaxPrice = ParentTable.MaxPrice,
		LastPrice = ParentTable.LastPrice,
		Whole2 = ParentTable.Whole2,
		Half2 = ParentTable.Half2,
		Retail2 = ParentTable.Retail2,
		EndUser2 = ParentTable.EndUser2,
		Export2 = ParentTable.Export2,
		Vendor2 = ParentTable.Vendor2,
		MaxPrice2 = ParentTable.MaxPrice2,
		LastPrice2 = ParentTable.LastPrice2,
		Whole3 = ParentTable.Whole3,
		Half3 = ParentTable.Half3,
		Retail3 = ParentTable.Retail3,
		EndUser3 = ParentTable.EndUser3,
		Export3 = ParentTable.Export3,
		Vendor3 = ParentTable.Vendor3,
		MaxPrice3 = ParentTable.MaxPrice3,
		LastPrice3 = ParentTable.LastPrice3,
		PriceType = ParentTable.PriceType,
		CurrencyGUID = parentTable.CurrencyGUID,
		CurrencyVal = parentTable.CurrencyVal,
		IsCompositionUpdated = CASE @UpdateAll WHEN 1 THEN 0 ELSE mt.IsCompositionUpdated END
	FROM 
		mt000 AS mt
		INNER JOIN mt000 AS parentTable ON mt.Parent = parentTable.[Guid]
	WHERE 
		mt.Parent = @ParentId
		AND mt.IsCompositionUpdated = CASE @UpdateAll WHEN 0 THEN 0 ELSE mt.IsCompositionUpdated END
		ANd mt.InheritsParentSpecs = 1
###########################################################################
CREATE PROC prcUpdateCompositeMaterialGenaralInfo
@ParentId		UNIQUEIDENTIFIER

AS

	DECLARE @IncludeCompositionInMatName INT;
	SELECT Top 1 @IncludeCompositionInMatName = Isnull(convert (int, value), 0) FROM op000 WHERE name = 'AmnCfg_IncludeCompositionInMatName'
	UPDATE mt
	SET 
		Name =   CASE WHEN @IncludeCompositionInMatName != 0 THEN  parentTable.Name + CASE WHEN mt.Parent != 0X0 THEN + ' (' + mt.CompositionName + ')' ELSE  '' END  ELSE parentTable.Name END ,
		LatinName = CASE WHEN @IncludeCompositionInMatName != 0 THEN  (CASE WHEN parentTable.LatinName = '' THEN parentTable.Name ELSE parentTable.LatinName END) + CASE WHEN mt.Parent != 0X0 THEN
					 ' (' +  CASE WHEN ( mt.CompositionLatinName = '' OR mt.CompositionLatinName = '-') THEN '' ELSE mt.CompositionLatinName END + ')' ELSE  '' END  ELSE (CASE WHEN parentTable.LatinName = '' THEN parentTable.Name ELSE parentTable.LatinName END)  END ,
		Unity = parentTable.Unity,
		Spec =		parentTable.Spec,
		SellType = parentTable.SellType,
		BonusOne = parentTable.BonusOne,
		Origin = parentTable.Origin,
		Company = parentTable.Company,
		TYPE = parentTable.Type,
		SECURITY = parentTable.Security,
		Bonus = parentTable.Bonus,
		Unit2 = parentTable.Unit2,
		Unit2Fact = parentTable.Unit2Fact,
		Unit3 = parentTable.Unit3,
		Unit3Fact = parentTable.Unit3Fact,
		Flag = parentTable.Flag,
		Pos = parentTable.Pos,
		Dim = parentTable.Dim,
		ExpireFlag = parentTable.ExpireFlag,
		ProductionFlag = parentTable.ProductionFlag,
		Unit2FactFlag = parentTable.Unit2FactFlag,
		Unit3FactFlag = parentTable.Unit3FactFlag,
		SNFlag = parentTable.SNFlag,
		ForceInSN = parentTable.ForceInSN,
		ForceOutSN = parentTable.ForceOutSN,
		VAT = parentTable.VAT,
		Color = parentTable.Color,
		Provenance = parentTable.Provenance,
		Quality = parentTable.Quality,
		Model = parentTable.Model,
		GroupGUID = parentTable.GroupGUID,
		DefUnit = parentTable.DefUnit,
		bHide = parentTable.bHide,
		branchMask = parentTable.branchMask,
		Assemble = parentTable.Assemble,
		CalPriceFromDetail = parentTable.CalPriceFromDetail,
		ForceInExpire = parentTable.ForceInExpire,
		ForceOutExpire = parentTable.ForceOutExpire,
		IsIntegerQuantity = parentTable.IsIntegerQuantity,
		ClassFlag = parentTable.ClassFlag,
		ForceInClass = parentTable.ForceInClass,
		ForceOutClass = parentTable.ForceOutClass,
		DisableLastPrice = parentTable.DisableLastPrice,
		LastPriceCurVal = parentTable.LastPriceCurVal
	FROM mt000 AS mt
	INNER JOIN mt000 AS parentTable ON mt.Parent = parentTable.[Guid]
	WHERE mt.Parent = @ParentId
###########################################################################
CREATE PROC prcUpdateCompositeMaterialPicture
@ParentId		UNIQUEIDENTIFIER,
@CompositeMaterialId UNIQUEIDENTIFIER = 0x0,
@UpdateAll		BIT = 0	

AS

	DECLARE @ParentPicGuid UNIQUEIDENTIFIER = (SELECT PictureGUID FROM mt000 WHERE guid = @ParentId)			
	DECLARE @PicPath NVARCHAR(260) = 
				(SELECT top 1 Name 
					FROM bm000 
					WHERE guid = @ParentPicGuid)
	
	DECLARE @MatGuid UNIQUEIDENTIFIER; 
	DECLARE @PicGuid UNIQUEIDENTIFIER; 
	DECLARE MatCursor CURSOR FOR
	SELECT 
	GUID ,
	PictureGUID
	FROM mt000 
	WHERE Parent = @ParentId 
	AND IsCompositionUpdated = CASE @UpdateAll WHEN 0 THEN 0 ELSE IsCompositionUpdated END
	ANd InheritsParentSpecs = 1
	AND guid = CASE @CompositeMaterialId WHEN 0x0 THEN guid ELSE @CompositeMaterialId END;

	OPEN MatCursor; 
	FETCH NEXT FROM MatCursor INTO @MatGuid,@PicGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		IF (@ParentPicGuid = 0x0) -- Delete Pic 
		BEGIN
			DELETE bm000 WHERE GUID = @PicGuid
			UPDATE mt000 SET PictureGUID = 0x0 WHERE guid = @MatGuid
		END

		IF(@PicGuid != 0x0) -- Update pic
		BEGIN
			UPDATE bm000 SET Name = @PicPath WHERE GUID = @PicGuid
		END

		ELSE IF (@PicGuid = 0x0) -- Insert Pic
		BEGIN 
			DECLARE @NewPicGuid UNIQUEIDENTIFIER = NEWID()
			INSERT INTO bm000 (name , Guid ) values (@PicPath , @NewPicGuid)
			UPDATE mt000 SET PictureGUID = @NewPicGuid WHERE guid = @MatGuid
		END

		FETCH NEXT FROM MatCursor INTO @MatGuid,@PicGuid
	END

	CLOSE MatCursor
	DEALLOCATE MatCursor
###########################################################################
CREATE PROC	prcUpdateCompositeMaterialGCCTax
	@ParentId		UNIQUEIDENTIFIER
AS

	SET NOCOUNT ON
	----------------------------------------------------
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	--------------------------------------------------
	
	IF(@IsGCCEnabled = 0)
		RETURN;

	DELETE matTax
	FROM 
		GCCMaterialTax000 matTax
	INNER JOIN mt000 mt ON mt.GUID = matTax.MatGUID
	WHERE 
		mt.Parent = @ParentId


	INSERT INTO GCCMaterialTax000 
		([GUID]
		,[TaxType]
		,[TaxCode]
		,[Ratio]
		,[MatGUID]
		,[ProfitMargin])
	SELECT
		NEWID()
		,parentTax.TaxType
		,parentTax.TaxCode
		,parentTax.Ratio
		,mt.GUID
		,parentTax.ProfitMargin 
	FROM 
	mt000 mt
	LEFT JOIN GCCMaterialTax000  parentTax ON parentTax.MatGUID = mt.Parent
	WHERE 
	mt.Parent = @ParentId
	AND parentTax.MatGUID IS NOT NULL
###########################################################################
CREATE PROC prcUpdateCompositeMaterialCode
@ParentId		UNIQUEIDENTIFIER
AS
	SELECT 
		se.Code AS ElementCode,
		me.[Order] AS Number, 
		mt.GUID AS MaterialGuid
	INTO
		 #CompositionsElements
	FROM 
		Segments000 i
		JOIN SegmentElements000 se ON i.Id = se.SegmentId
		JOIN MaterialElements000 me ON se.Id = me.ElementId
		JOIN mt000 mt ON me.MaterialId = mt.GUID
	WHERE 
		mt.Parent = @ParentId

	SELECT DISTINCT
	SUBSTRING(
	        (
	            SELECT '-'+ C1.ElementCode  AS [text()]
	            FROM dbo.#CompositionsElements C1
	            WHERE C1.MaterialGuid = C2.MaterialGuid
	            ORDER BY C1.Number
	            For XML PATH ('')
	        ), 2, 1000) AS Code,
			C2.MaterialGuid
	INTO
		 #Result
	FROM
		 dbo.#CompositionsElements C2

	UPDATE mt 
	SET 
		mt.Code = parent.Code + '-' +  r.Code
	FROM 
		mt000 mt
		JOIN #Result r ON mt.[GUID] = r.MaterialGuid
		JOIN mt000 parent ON mt.Parent = parent.GUID
	WHERE 
		mt.Parent = @ParentId
	
	DROP TABLE #CompositionsElements
	DROP TABLE #Result
###########################################################################
CREATE PROC prcUpdateCompositeMaterialInfo
@ParentId					UNIQUEIDENTIFIER,
@UpdateAll		BIT = 0			

AS

	EXEC prcUpdateCompositeMaterialGenaralInfo @ParentId 
	EXEC prcUpdateCompositeMaterialCode @ParentId 
	EXEC prcUpdateCompositeMaterialGCCTax @ParentId 
	EXEC prcUpdateCompositeMaterialSpecsInfo @ParentId ,@UpdateAll
	EXEC prcUpdateCompositeMaterialPicture @ParentId , 0x0 ,@UpdateAll

###########################################################################
#END