################################################################################
CREATE PROCEDURE prcPOSSD_GetLastMonthBestProfitMaterials
	( @StationGUID UNIQUEIDENTIFIER = 0x0 )
AS
BEGIN
	DECLARE @CurrentDate  DATETIME
	SET @CurrentDate = GETDATE()

	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User
	DECLARE @startDate Date = CAST(DATEADD(DAY,-DAY(GETDATE())+1, CAST(GETDATE() AS DATE)) AS DATETIME)
	
	DECLARE @StationBillTypes AS TABLE ([BillTypeGUID] UNIQUEIDENTIFIER)
	INSERT INTO @StationBillTypes
		SELECT SaleBillTypeGUID FROM POSSDStation000 WHERE GUID = @StationGUID
	INSERT INTO @StationBillTypes
		SELECT SaleReturnBillTypeGUID FROM POSSDStation000 WHERE GUID = @StationGUID
	--INSERT INTO @StationBillTypes
	--	SELECT PurchaseBillTypeGUID FROM POSSDStation000 WHERE GUID = @StationGUID
	--INSERT INTO @StationBillTypes
	--	SELECT PurchaseReturnBillTypeGUID FROM POSSDStation000 WHERE GUID = @StationGUID
	
	DECLARE @CurGUID UNIQUEIDENTIFIER
	SELECT @CurGUID = GUID FROM my000 WHERE CurrencyVal = 1
	-- Get Close shift bills
	DECLARE @ClosShiftBillItems AS TABLE 
	( 
		[BillGUID]			UNIQUEIDENTIFIER, 
		[BiGUID]			UNIQUEIDENTIFIER,
		[BillDate]			DATETIME,
		[BiMatGUID]			UNIQUEIDENTIFIER,
		[BiUnitCostPrice]	FLOAT,
		[BiQty]				FLOAT,
		[BiPrice]			FLOAT
	)

	DECLARE  @billNoteArabic [NVARCHAR](250), @billNoteEnglish  [NVARCHAR](250)
	SET @billNoteArabic  = [dbo].[fnStrings_get]('POS\BILLGENERATED', 0)
	SET @billNoteEnglish = [dbo].[fnStrings_get]('POS\BILLGENERATED', 1)

	INSERT INTO @ClosShiftBillItems
		SELECT fixed.[buGUID], fixed.[biGUID],  bubi.[buDate], bubi.[biMatPtr] , 0, 
				ABS(SUM(fixed.[buDirection] * (fixed.[BiQty] + fixed.[biBonusQnt]))), 
				ABS(SUM(fixed.[buDirection] * (fixed.[biUnitPrice] + fixed.[biUnitExtra] - fixed.[biUnitDiscount])))
		FROM [dbo].[fnExtended_Bi_Fixed](@CurGUID) fixed 
		INNER JOIN vwbubi bubi ON bubi.biGUID = fixed.[biGUID]
		WHERE bubi.buType IN (SELECT [BillTypeGUID] FROM @StationBillTypes)
		AND ( bubi.buNotes LIKE '%' + @billNoteArabic + '%'
			OR bubi.buNotes LIKE '%' + @billNoteEnglish + '%' )
		AND bubi.[buDate] BETWEEN @startDate AND @CurrentDate
		GROUP BY fixed.[buGUID], fixed.[biGUID],  bubi.[buDate], bubi.[biMatPtr]
	
	--------- Avg price calculations ------------------------------------------------------------------------------------------
	CREATE TABLE [#t_Prices] ( [MatGUID] UNIQUEIDENTIFIER, [AvgPrice] FLOAT)
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	
	DECLARE @SrcTypes UNIQUEIDENTIFIER = NEWID()
	EXEC prcRSCreateBill @SrcTypes
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypes
	
	-- declare cursors: 
	DECLARE @C_BillItems CURSOR 
	SET  @C_BillItems = CURSOR FAST_FORWARD FOR  
			SELECT [BillGUID], [BiGUID], [BillDate], [BiMatGUID] 
			FROM @ClosShiftBillItems 
			ORDER BY [BillGUID], [BillDate], [BiGUID], [BiMatGUID]
	-- declare variables for cursor:
	DECLARE	@buGUID	   [UNIQUEIDENTIFIER],
			@biBUID	   [UNIQUEIDENTIFIER], 
			@buDate    [DATETIME], 
			@BiMatGUID [UNIQUEIDENTIFIER]
	OPEN @C_BillItems FETCH NEXT FROM @C_BillItems INTO @buGUID, @biBUID, @buDate, @BiMatGUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- Bill Materials
		DELETE FROM [#MatTbl]
		DELETE FROM [#t_Prices]
		INSERT INTO  [#MatTbl]
			SELECT @BiMatGUID, 0
	 
		EXEC [prcGetAvgPrice]
				@StartDate = '1/1/1980',
				@EndDate  = @buDate,
				@MatGUID  = @BiMatGUID, @GroupGUID = 0x00, @StoreGUID  = 0x00, @CostGUID  = 0x00,
				@MatType = -1,
				@CurrencyGUID  = @CurGUID,
				@CurrencyVal  = 1,
				@SrcTypes  = @SrcTypes,
				@ShowUnLinked  = 0, 
				@UseUnit  = 0,
				@IsIncludeOpenedLC  = 0
		-- Calc current bill item cost price
		UPDATE bi
		SET [BiUnitCostPrice] = prices.[AvgPrice]
		FROM @ClosShiftBillItems bi
		INNER JOIN [#t_Prices] prices ON prices.[MatGUID] = bi.[BiMatGUID]
		WHERE bi.BiGUID = @biBUID
		FETCH NEXT FROM @C_BillItems INTO @buGUID, @biBUID, @buDate, @BiMatGUID
	END
	-- Calc current bill item cost price for last item
	UPDATE bi
		SET [BiUnitCostPrice] = prices.[AvgPrice]
		FROM @ClosShiftBillItems bi
		INNER JOIN [#t_Prices] prices ON prices.[MatGUID] = bi.[BiMatGUID]		
		WHERE bi.BiGUID = @biBUID
	
	--  -- Calculate Total Sales Price for this month
	DECLARE @Materials AS TABLE
	(
		[GUID]				UNIQUEIDENTIFIER,
		[Name]				NVARCHAR(255),
		[LatinName]			NVARCHAR(255),
		[Qty]				FLOAT,
		[Price]				FLOAT,
		[CostPrice]			FLOAT,
		[Profit]			FLOAT,
		[ProfitPercentage]	FLOAT
	)
	INSERT INTO @Materials
		SELECT [BiMatGUID], 
				mt.mtName,
				mt.mtLatinName,  
				ABS(SUM(fixedBi.buDirection * billItems.BiQty)),
				ABS(SUM(fixedBi.buDirection * billItems.BiQty * billItems.BiPrice)),
				ABS(SUM(fixedBi.buDirection * billItems.BiQty * billItems.BiUnitCostPrice)),
				0, 0
		FROM @ClosShiftBillItems billItems
		INNER JOIN [dbo].[fnExtended_Bi_Fixed](@CurGUID) fixedBi ON fixedBi.[biGUID] = billItems.[BiGUID]
		INNER JOIN vwMt mt ON mt.[mtGUID] = billItems.[BiMatGUID]
		GROUP BY [BiMatGUID], mt.[mtName], mt.[mtLatinName]
	
	UPDATE @Materials
		SET [Profit] = [Price] - [CostPrice],
		    [ProfitPercentage] = CASE [CostPrice] WHEN 0 THEN 0 ELSE ((([Price] - [CostPrice]) / [CostPrice]) * 100.0) END

	SELECT TOP 5 [GUID], [Name], [LatinName], [Qty], [Price], [CostPrice], [Profit], [ProfitPercentage] FROM @Materials ORDER BY Profit DESC
	
	DROP TABLE [#t_Prices]
	DROP TABLE [#MatTbl]
	DROP TABLE [#BillsTypesTbl]

END
#################################################################
#END
