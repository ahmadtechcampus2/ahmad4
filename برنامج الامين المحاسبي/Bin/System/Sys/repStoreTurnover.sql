##########################################################
CREATE PROCEDURE repStoreTurnover
	@StartDate 			[DATETIME], 
	@EndDate			[DATETIME], 
	@MatGUID 			[UNIQUEIDENTIFIER], 
	@GroupGUID 			[UNIQUEIDENTIFIER], 
	@StoreGUID  		[UNIQUEIDENTIFIER], 
	@CostGUID 			[UNIQUEIDENTIFIER], 
	@SrcTypesGUID		[UNIQUEIDENTIFIER], 
	@CurrencyGUID 		[UNIQUEIDENTIFIER], 
	@CurrencyVal		[FLOAT], 
	@UseUnit 			[INT], 
	@InOutSign			[INT], 
	@PriceType			[INT], 
	@PricePolicy		[INT], 
	@UseBillPrice		[BIT]
AS 
	SET NOCOUNT ON   
	  
	CREATE TABLE #SecViol ([Type] INT, Cnt INT);  
	CREATE TABLE #MatTbl (MatGUID UNIQUEIDENTIFIER, mtSecurity INT);  
	CREATE TABLE #BillsTypesTbl (TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER); 
	CREATE TABLE #StoreTbl (StoreGUID UNIQUEIDENTIFIER, Security INT);  
	CREATE TABLE #CostTbl (CostGUID UNIQUEIDENTIFIER, Security INT);  
	CREATE TABLE [#EntryTbl1]([BillGuid] [UNIQUEIDENTIFIER], EntryBill int, posted int) ;
	CREATE TABLE [#EntryTbl]([BillGuid] [UNIQUEIDENTIFIER]); 
	INSERT INTO #MatTbl				EXEC prcGetMatsList 		@MatGUID, @GroupGUID, -1;  
	INSERT INTO #BillsTypesTbl		EXEC prcGetBillsTypesList	@SrcTypesguid;  
	INSERT INTO #StoreTbl			EXEC prcGetStoresList		@StoreGUID;  
	INSERT INTO #CostTbl			EXEC prcGetCostsList 		@CostGUID;  
	CREATE TABLE #EndResult   
	(  
		StoreGuid			UNIQUEIDENTIFIER,  
		StoreSecurity		TINYINT,  
		MaterialGuid		UNIQUEIDENTIFIER,  
		MaterialSecurity	TINYINT,  
		CostGuid			UNIQUEIDENTIFIER,  
		CostSecurity		TINYINT,  
		IsInput				BIT,  
		IsOutput			BIT,  
		Quantity			FLOAT,  
		biBillQty			FLOAT,
		BillPrice			MONEY,
		ReportPrice			FLOAT
	); 	 
	  
	INSERT INTO [#EntryTbl]	  
				SELECT [erParentGuid]   
				FROM [VWER] AS [er]   
				INNER JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   
				INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid] = [er].[erParentGuid]  
				WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate  
	INSERT INTO [#EntryTbl1]	
		SELECT bu.buGUID,--0,0 
				CASE  (select [BillGuid] from [#EntryTbl] where [BillGuid] =  bu.buGUID) when  bu.buGUID then 0 ELSE 1 END,
				CASE bu.buisposted  when 1 then 1 else 0 END
			FROM [Vwbu] bu
			WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate  
	INSERT INTO #EndResult
	(
		StoreGuid, 
		StoreSecurity,
		MaterialGuid,
		MaterialSecurity,
		CostGuid,
		CostSecurity, 
		IsInput, 
		IsOutput, 
		Quantity, 
		biBillQty, 
		BillPrice, 
		ReportPrice	
	 )  
	SELECT   
	    T.biStorePtr, 
		S.Security,   
		T.biMatPtr,   
		M.mtSecurity,   
		T.FixedCostGuid,
		s.Security,   
		T.btIsInput,   
		T.btIsOutput,
		([T].[biQty] + [T].[biBonusQnt]) / 
		CASE @UseUnit   
			WHEN 1 THEN CASE [T].[mtunit2Fact] WHEN 0 THEN 1 ELSE [T].[mtunit2Fact] END   
			WHEN 2 THEN CASE [T].[mtunit3Fact] WHEN 0 THEN 1 ELSE [T].[mtunit3Fact] END    
			ELSE 1  
		END,
		([T].[biQty] + [T].[biBonusQnt]), 
		(T.FixedBiPrice + T.FixedbiUnitExtra -T.FixedBiUnitDiscount /* + T.FixedBiExtra - T.FixedBiDiscount + (T.FixedBiLCExtra - T.FixedBiLCDisc)*/) * ([T].[biBillQty]),
		CASE @UseBillPrice WHEN 1 THEN T.FixedBiPrice END
	FROM    
		 (
		  SELECT 
			 *, 
			 CASE 
			  	WHEN biCostPtr = 0x0 THEN buCostPtr 
				 ELSE biCostPtr 
			 END AS FixedCostGuid 
		 FROM 
			 fnExtended_bi_Fixed(@CurrencyGUID)
		) AS T
		 JOIN #MatTbl AS M ON T.biMatPtr = M.MatGUID   
		 JOIN #BillsTypesTbl AS B ON T.buType = B.TypeGuid 
		 INNER JOIN vwbt AS bt ON [bt].[btGUID] = [B].[TypeGUID] 
		 JOIN #StoreTbl AS S ON T.biStorePtr = S.StoreGUID 
		 LEFT JOIN #CostTbl AS C ON T.FixedCostGuid = C.CostGUID   
	WHERE
		((@CostGuid <> 0x0 AND T.FixedCostGuid = C.CostGUID) OR @CostGuid = 0x0)
		AND
		T.buDate BETWEEN @StartDate AND @EndDate
		AND T.buGUID NOT IN (SELECT [BillGuid] FROM [#EntryTbl1] en WHERE en.posted = 0)  
		AND ([bt].[btSortNum] <> 0)

	EXEC prcCheckSecurity @result = '#EndResult';
	IF @UseBillPrice = 0  
	BEGIN  
		CREATE TABLE [#t_Prices]   
		(   
			[mtNumber] 	[UNIQUEIDENTIFIER],   
			[APrice] 	[FLOAT]   
		)

		EXEC prcFillTempPricesTable @PriceType, @PricePolicy, @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID,   
				-1, @CurrencyGUID, @CurrencyVal, @SrcTypesGUID, 0, @UseUnit, 0, 0;
		
		UPDATE R  
			SET R.ReportPrice = P.APrice  
		FROM  
			#EndResult AS R JOIN #t_Prices AS P ON R.MaterialGuid = P.mtNumber;
	END;	  
	DECLARE  
		@InSign		INT,  
		@OutSign	INT;  
	IF @InOutSign = 0  
		SELECT @InSign = 1, @OutSign = 1  
	ELSE IF @InOutSign = 1  
		SELECT @InSign = 1, @OutSign = -1  
	ELSE  
		SELECT @InSign = -1, @OutSign = 1;  
	 
	DECLARE @Sql NVARCHAR(MAX); 
	 
	SET @Sql = ' 
	WITH C AS  
	(  
		SELECT  
			StoreGuid,  
			SUM(Quantity * IsInput) AS InQuantity,  
			SUM(BillPrice * IsInput) AS InValue,  
			SUM(Quantity * IsOutput) AS OutQuantity,  
			SUM(BillPrice * IsOutput) AS OutValue,
			SUM((@InSign * biBillQty * ReportPrice * IsInput) + (@OutSign * biBillQty * ReportPrice * IsOutput)) AS Value
		FROM  
			#EndResult  
		GROUP BY   
			StoreGuid  
	)  
	SELECT  
		C.StoreGuid		AS StoreGuid,  
		S.Name			AS StoreName,  
		S.Code			AS StoreCode,  
		C.InQuantity	AS InQuantity,  
		C.InValue		AS InValue,  
		C.OutQuantity	AS OutQuantity,  
		C.OutValue		AS OutValue,  
		@InSign * C.InQuantity + @OutSign * C.OutQuantity AS Quantity,  
		C.Value AS Value 
	FROM   
		C JOIN st000 AS S ON C.StoreGuid = S.GUID  
	ORDER BY S.Code'  
	EXEC sp_executesql @sql, N'@InSign INT, @OutSign INT', @InSign = @Insign, @OutSign = @OutSign; 
	SELECT * FROM #SecViol;
#########################################################
#END