#########################################################
CREATE PROC prcGetBillLayoutHeaders
	@blGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON

	SELECT 
		[h].[GUID], 
		[h].[Id], 
		[h].[Type], 
		[h].[Kind], 
		[h].[Caption], 
		[h].[ParentGUID], 
		[h].[LineNumber], 
		[h].[ColumnNumber], 
		[h].[Width], 
		[h].[AlignmentMode], 
		[h].[bShowInPrinter], 
		[h].[bShowInScreen]
FROM 	
	[BLMain000] [m]
	INNER JOIN [BLHeader000] [h] ON [m].[Guid] = [h].[ParentGUID]
WHERE 
	[m].[Guid] = @blGuid
#########################################################
CREATE PROC prcCheckPOSBillLayoutType
	@BillLayoutID [UNIQUEIDENTIFIER],
	@ComputerName [NVARCHAR]( 250) 
AS
	SET NOCOUNT ON
	
	SELECT 
		[Value] 
	FROM 
		[op000] 
	WHERE 
		[Name] = 'AmnPOSPrint_BillStyleID'
		AND [Computer] = @ComputerName
		AND [Value] = @BillLayoutID
#########################################################
CREATE PROC prcGetBillLayoutItems
	@blGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON

	SELECT 
		[ih].[GUID] AS [ItemHeaderGUID], 
		[ih].[Caption] AS [ItemHeaderCaption],
		[ih].[X] AS [ItemHeaderX],
		[ih].[ParentGUID] AS [ItemHeaderParentGUID],
		[ih].[Width] AS [ItemHeaderWidth],
		-- [i].[GUID] AS [ItemGUID],
		[i].[Y] AS [ItemY],
		[i].[FldIndex] AS [ItemFldIndex]
FROM 	
	[BLMain000] [m]
	INNER JOIN [BLItemsHeader000] [ih] ON [m].[Guid] = [ih].[ParentGUID]
	INNER JOIN [BLItems000] [i] ON [ih].[Guid] = [i].[ParentGUID]
WHERE 
	[m].[Guid] = @blGuid

#########################################################
CREATE PROC prcDeleteBillLayout
	@blGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	DELETE [BLMain000] WHERE [GUID] = @blGuid
#########################################################
CREATE PROCEDURE prcAccCost_GetBalance 
	@AccGuid [UNIQUEIDENTIFIER], 
	@CurGuid [UNIQUEIDENTIFIER] = 0x0, 
	@CostGuid [UNIQUEIDENTIFIER] = 0x0 	
AS 
	SET NOCOUNT ON 
	
	SELECT 
		[dbo].[fnAccount_getBalance](
			@AccGuid,
			@CurGuid, 
			DEFAULT,
			DEFAULT,
			@CostGuid) AS Balance
#########################################################
CREATE PROC prcDeleteBillLayoutDetails
	@blGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	DELETE [BLItemsHeader000] WHERE [ParentGUID] = @blGuid
	DELETE [BLHeader000] WHERE [ParentGUID] = @blGuid	
	
#########################################################
CREATE PROC prc_GetAssembleMatDetails
	@MatPtr			[UNIQUEIDENTIFIER], 
	@BillGuid		[UNIQUEIDENTIFIER] = 0x,
	@AssemMatBiGuid [UNIQUEIDENTIFIER]= 0x
AS
	--CHECK IF BILL TYPE IS PRESENTING THE ASSEMBLE BILL OR ITS FINAL BILL
	DECLARE @Type INT
	DECLARE @OutBGUID [UNIQUEIDENTIFIER] ,
			@InBGUID  [UNIQUEIDENTIFIER] 
	SET @OutBGUID = 0x00 
	SET @InBGUID = 0x00 
	
	SELECT @Type = Type
	FROM bt000
	WHERE GUID IN ( SELECT TypeGUID
					FROM bu000
					WHERE GUID = @BillGuid )
					
	IF (@Type <> 9) -- NOT ASSEMBLE BILL **9 IS THE OUT BILL TYPE OF ASSEMBLE BILL**
	BEGIN 
		-- GET THE ASSEMBLE BILL GUID
		SELECT @OutBGUID = OutBillGUID
		FROM AssemBill000
		WHERE FinalBillGuid = @BillGuid
		
		--THE BILL IS NOT ASSEMBLE BILL OR NOT GENERATED FROM IT.. JUST AN ORDINARY BILL
		--BRING ASSEMBLE MAT COMPONENTS FROM MD000 TABLE
		IF (@OutBGUID = 0x00)
		BEGIN
			SELECT	DISTINCT mt.Name mtName,
							 mt.Code mtCode,
							 mt.LatinName mtLatinName,
							 bi.CurrencyVal CurVal,
							 0 Price,				
							 md.*
			FROM mt000 AS mt
				INNER JOIN md000 AS md ON md.MatGUID = mt.GUID
					INNER JOIN bi000 AS bi ON bi.MatGUID = md.ParentGUID
			WHERE md.ParentGUID = @MatPtr
				AND
				  bi.ParentGUID = @BillGuid
		END
	END
	
	--THE BILL IS RESEMBLING ASSEMBLE BILL
	--BRING ASSEMBLE MAT CONTENT FROM BMD000 TABLE
	IF ((@Type = 9)OR ( @OutBGUID <> 0x00 ))
	BEGIN
		
		IF @OutBGUID = 0x00
			SET @OutBGUID = @BillGuid
			
		SELECT @InBGUID = InBillGUID
		FROM AssemBill000 
		WHERE OutBillGUID = @OutBGUID
		
		SELECT  MT.NAME mtName,
				MT.CODE mtCode,
				MT.LATINNAME mtLatinName, 
				bi.CurrencyVal CurVal,
				BMD.* 
		FROM [bmd000] AS BMD
			LEFT JOIN MT000 AS MT ON MT.GUID = BMD.MATGUID
			LEFT JOIN BI000 AS BI ON BI.GUID = BMD.BIGUID AND bmd.[BiParentGUID] = @AssemMatBiGuid
		WHERE  
			bmd.[ParentMatGUID] = @MatPtr 
		AND 
			bmd.[AssemInBillGuid] = @InBGUID
	END
#########################################################
CREATE PROC prcGetMatPricesByUnit
	@MaterialGUID UNIQUEIDENTIFIER,
	@CurrencyDate DATE = '19800101'
AS
	SET NOCOUNT ON
	DECLARE @CurrencyFix FLOAT = 1;
	DECLARE @DefUnit INT = 1;

	SET @DefUnit = (SELECT TOP 1 DefUnit FROM mt000 WHERE GUID = @MaterialGUID);

	IF @CurrencyDate <> '19800101'
	BEGIN
		SET @CurrencyFix = (SELECT TOP 1 dbo.fnGetCurVal(CurrencyGUID, @CurrencyDate) / CurrencyVal FROM mt000 WHERE GUID = @MaterialGUID);
	END

	SELECT
		@MaterialGUID AS MaterialGUID,
		mtType AS MaterialType,
		mtSecurity AS [Security],
		mtWhole * @CurrencyFix AS Whole1,
		mtWhole2 * @CurrencyFix AS Whole2,
		mtWhole3 * @CurrencyFix AS Whole3,
		CASE @DefUnit
			WHEN 1 THEN mtWhole
			WHEN 2 THEN mtWhole2
			WHEN 3 THEN mtWhole3
			ELSE mtWhole
		END * @CurrencyFix AS WholeDefault,
		mtHalf * @CurrencyFix AS Half1,
		mtHalf2 * @CurrencyFix AS Half2,
		mtHalf3 * @CurrencyFix AS Half3,
		CASE @DefUnit
			WHEN 1 THEN mtHalf
			WHEN 2 THEN mtHalf2
			WHEN 3 THEN mtHalf3
			ELSE mtHalf
		END * @CurrencyFix AS HalfDefault,
		mtVendor * @CurrencyFix AS Vendor1,
		mtVendor2 * @CurrencyFix AS Vendor2,
		mtVendor3 * @CurrencyFix AS Vendor3,
		CASE @DefUnit
			WHEN 1 THEN mtVendor
			WHEN 2 THEN mtVendor2
			WHEN 3 THEN mtVendor3
			ELSE mtVendor
		END * @CurrencyFix AS VendorDefault,
		mtExport * @CurrencyFix AS Export1,
		mtExport2 * @CurrencyFix AS Export2,
		mtExport3 * @CurrencyFix AS Export3,
		CASE @DefUnit
			WHEN 1 THEN mtExport
			WHEN 2 THEN mtExport2
			WHEN 3 THEN mtExport3
			ELSE mtExport
		END * @CurrencyFix AS ExportDefault,
		mtRetail * @CurrencyFix AS Retail1,
		mtRetail2 * @CurrencyFix AS Retail2,
		mtRetail3 * @CurrencyFix AS Retail3,
		CASE @DefUnit
			WHEN 1 THEN mtRetail
			WHEN 2 THEN mtRetail2
			WHEN 3 THEN mtRetail3
			ELSE mtRetail
		END * @CurrencyFix AS RetailDefault,
		mtEndUser * @CurrencyFix AS EndUser1,
		mtEndUser2 * @CurrencyFix AS EndUser2,
		mtEndUser3 * @CurrencyFix AS EndUser3,
		CASE @DefUnit
			WHEN 1 THEN mtEndUser
			WHEN 2 THEN mtEndUser2
			WHEN 3 THEN mtEndUser3
			ELSE mtEndUser
		END * @CurrencyFix AS EndUserDefault,
		mtMaxPrice * @CurrencyFix AS MaxPrice1,
		mtMaxPrice2 * @CurrencyFix AS MaxPrice2,
		mtMaxPrice3 * @CurrencyFix AS MaxPrice3,
		CASE @DefUnit
			WHEN 1 THEN mtMaxPrice
			WHEN 2 THEN mtMaxPrice2
			WHEN 3 THEN mtMaxPrice3
			ELSE mtMaxPrice
		END * @CurrencyFix AS MaxPriceDefault,
		mtLastPrice * @CurrencyFix AS LastPrice1,
		mtLastPrice2 * @CurrencyFix AS LastPrice2,
		mtLastPrice3 * @CurrencyFix AS LastPrice3,
		CASE @DefUnit
			WHEN 1 THEN mtLastPrice
			WHEN 2 THEN mtLastPrice2
			WHEN 3 THEN mtLastPrice3
			ELSE mtLastPrice
		END * @CurrencyFix AS LastPriceDefault,
		mtAvgPrice AS AvgPrice1,
		mtAvgPrice / CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END AS AvgPrice2,
		mtAvgPrice / CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END AS AvgPrice3,
		CASE @DefUnit
			WHEN 1 THEN mtAvgPrice
			WHEN 2 THEN mtAvgPrice / CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END 
			WHEN 3 THEN mtAvgPrice / CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END
			ELSE mtAvgPrice
		END AS AvgPriceDefault
	FROM
		vwMt
	WHERE 
		mtGUID = @MaterialGUID
#########################################################
#END
