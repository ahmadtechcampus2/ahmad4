#######################################################################################
CREATE  PROCEDURE repMinPurchasePriceMats
		@FromDate [Date], 
		@ToDate [Date], 
		@CurrencyGuid [UNIQUEIDENTIFIER] = 0x0, 
		@BranchGuid	[UNIQUEIDENTIFIER] = 0x0, 
		@ReportSourcesGuid [UNIQUEIDENTIFIER], 
		@CustomerGuid [UNIQUEIDENTIFIER] = 0x0,  
		@MatGuid [UNIQUEIDENTIFIER] = 0x0, 
		@GroupGuid [UNIQUEIDENTIFIER] = 0x0, 
		@StoreGuid [UNIQUEIDENTIFIER] = 0x0, 
		@CostGuid [UNIQUEIDENTIFIER] = 0x0 ,
		@DetailCost INT = 0,
		@DetailStore INT = 0,
		@PriceType INT =0 -- 1-->LastPurchas , 2-->lastPurchas With Discount , -->3 MinPrice , -->4 minPrice With Discount
	
	AS 
		SET NOCOUNT ON; 
	 
		CREATE TABLE [#MatTbl] ([MatGuid] [UNIQUEIDENTIFIER] , [mtSecurity] [INT]) 
		CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER])  
		CREATE TABLE [#StoreTbl] ([StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])  
		CREATE TABLE [#CostTbl] ([CostGuid] [UNIQUEIDENTIFIER], [Security] [INT], [Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI) 
		CREATE TABLE [#BrTbl] ([BranchGuid] [UNIQUEIDENTIFIER], [Level] [INT])

		CREATE TABLE #Temp(  
		    BuDate         [Date],		    
			[MaterialGuid] [UNIQUEIDENTIFIER],  
			[CustomerGuid] [UNIQUEIDENTIFIER],  
			[StorePtr] [UNIQUEIDENTIFIER],
			[CostGuid] [UNIQUEIDENTIFIER], 
			[MinPrice] FLOAT,
			[BillGuid] [UNIQUEIDENTIFIER],
			[BillNumber] INT,
			[BiGuid] [UNIQUEIDENTIFIER],
			[BiQty] FLOAT,
			BiStore [UNIQUEIDENTIFIER],
			BiCost [UNIQUEIDENTIFIER],
			BuFormatedNumber  [NVARCHAR](256));

		CREATE TABLE #MainResult(  
		    BuDate         [Date],
			[MaterialGuid] [UNIQUEIDENTIFIER],  
			[CustomerGuid] [UNIQUEIDENTIFIER],  
			[StorePtr] [UNIQUEIDENTIFIER],
			[CostGuid] [UNIQUEIDENTIFIER], 
			[MinPrice] FLOAT,
			[BillGuid] [UNIQUEIDENTIFIER],
			[BillNumber] INT,
			[BiGuid] [UNIQUEIDENTIFIER], 
			[BiQty] FLOAT,
			Row_Num INT,
			BuFormatedNumber  [NVARCHAR](256));

		CREATE TABLE #FinalResult(  
		    BuDate         [Date],
			[MaterialGuid] [UNIQUEIDENTIFIER],  
			[CustomerGuid] [UNIQUEIDENTIFIER],  
			[StorePtr] [UNIQUEIDENTIFIER],
			[CostGuid] [UNIQUEIDENTIFIER], 
			[MinPrice] FLOAT,
			[BillGuid] [UNIQUEIDENTIFIER],
			[BillNumber] INT,
			[BiGuid] [UNIQUEIDENTIFIER], 
			[BiQty] FLOAT,
			Row_Num INT,
			BuFormatedNumber  [NVARCHAR](256))
	
		INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @MatGuid, @GroupGuid,-1 
		INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @ReportSourcesGuid 
		INSERT INTO [#StoreTbl] EXEC [prcGetStoresList] @StoreGuid 
		INSERT INTO [#CostTbl] ([CostGuid], [Security]) EXEC [prcGetCostsList] @CostGuid
		INSERT INTO	[#BrTbl] ([BranchGuid], [Level]) SELECT * FROM fnGetBranchesList(@BranchGuid)
		
		;WITH T AS
		(
			SELECT
				B.buGUID,
				B.biGUID,
				B.biQty,
				B.biMatPtr,
				(B.biPrice + (CASE WHEN @PriceType = 2 THEN (biUnitExtra - biUnitDiscount) ELSE 0 END)) / CASE WHEN @CurrencyGuid =B.buCurrencyPtr THEN B.buCurrencyVal ELSE  dbo.fnGetCurVal(@CurrencyGuid, B.[buDate]) END AS biPrice,
				B.buCustPtr,
				B.biStorePtr,
				B.biCostPtr,
				B.buDate,
				ROW_NUMBER() OVER(PARTITION BY B.buCustPtr, B.biMatPtr, CASE @DetailStore WHEN 1 THEN B.biStorePtr ELSE 0x END, CASE @DetailCost WHEN 1 THEN B.biCostPtr ELSE 0x END 
				ORDER BY B.buDate DESC ,B.biNumber DESC) 
				AS Number,
				B.buFormatedNumber
			FROM 
				 vwExtended_bi AS B
				JOIN #MatTbl AS M ON B.biMatPtr = M.MatGuid
			WHERE
				B.btAffectLastPrice = 1
				AND B.[buDate] BETWEEN @FromDate AND @ToDate   
				AND (@PriceType = 1 OR @PriceType = 2)
				AND B.buCustPtr <> 0x
				
		)
		INSERT INTO #Temp
		SELECT  
		    bubi.buDate,
			BuBi.[biMatPtr] [MaterialGuid],  
			Bubi.[buCustPtr] [CustomerGuid],  
			CASE @DetailStore WHEN 1 THEN BuBi.[biStorePtr] ELSE 0x0 END,
			CASE @DetailCost WHEN 1 THEN BuBi.[biCostPtr] ELSE 0x0 END,
			ISNULL(ISNULL
			(
				T.biPrice, 
				(BuBi.biPrice + (CASE @PriceType WHEN 4 THEN (biUnitExtra - biUnitDiscount) ELSE 0 END)) / CASE WHEN @CurrencyGuid =BuBi.buCurrencyPtr THEN bubi.buCurrencyVal ELSE  dbo.fnGetCurVal(@CurrencyGuid, BuBi.[buDate]) END
				+ ((BuBi.[biLCExtra]- BuBi.[biLCDisc]) / BuBi.biQty)
			) / (NULLIF([dbo].fnGetMaterialUnitFact(MT.[mtGuid], Bubi.[biUnity]), 0) / NULLIF((CASE MT.[mtDefUnitFact] WHEN 0 THEN 1 ELSE MT.[mtDefUnitFact] END), 0)), 0),
			BuBi.[buGuid] [BillGuid],
			BuBi.[buNumber] [BillNumber],
			BuBi.[biGuid] [BiGuid],
			BuBi.biQty,
			BuBi.[biStorePtr],
			BuBi.[biCostPtr],
			BuBi.buFormatedNumber
			
		FROM 
			vwExtended_bi AS BuBi  
			INNER JOIN vwmt AS MT ON BuBi.[biMatPtr] = MT.[mtGuid]  
			INNER JOIN [#MatTbl] AS [mtTbl]	ON BuBi.[biMatPtr] = [mtTbl].[MatGuid]  
			INNER JOIN [#BillsTypesTbl]	AS BT ON BuBi.[buType] = BT.[TypeGuid]
			LEFT JOIN T ON T.buGUID = BuBi.buGUID
		WHERE  
			BuBi.btIsInput = 1 -->-- ÝÞØ ÔÑÇÁ 
			AND BT.[UserReadPriceSecurity] > 0 
			AND BuBi.[buDate] BETWEEN @FromDate AND @ToDate   
			AND( (@CustomerGuid = 0x0) OR (@CustomerGuid = Bubi.[buCustPtr]) )   
			AND( (@StoreGuid = 0x0) OR (BuBi.[biStorePtr] IN (SELECT [StoreGUID] FROM [#StoreTbl])))   
			AND( (@CostGuid = 0x0) OR (BuBi.[biCostPtr] IN (SELECT [CostGUID] FROM [#CostTbl])))
			AND( (@BranchGuid = 0x0) OR (BuBi.[buBranch] IN (SELECT [BranchGuid] FROM [#BrTbl])))
			AND BuBi.buCustPtr <> 0x
			AND(
			 ((@PriceType <> 3 AND @PriceType <> 4) AND T.biMatPtr = BuBi.biMatPtr AND T.biGUID = BUBI.biGUID AND T.biQty = BUBI.biQty AND T.Number = 1 )
			 OR (@PriceType = 3 OR @PriceType = 4)
				)
		
		INSERT INTO #MainResult 
		SELECT
		    T.buDate,
			T.[MaterialGuid],
			T.[CustomerGuid],
			CASE WHEN @DetailStore = 1 THEN T.[StorePtr] ELSE T.BiStore END,
			CASE WHEN @DetailCost = 1 THEN T.[CostGuid] ELSE T.BiCost END,
			T.[MinPrice],
			T.[BillGuid],
			T.[BillNumber],
			T.[BiGuid],
			T.[BiQty],
			ROW_NUMBER() OVER(PARTITION BY T.MaterialGuid, T.CustomerGuid, T.[StorePtr], T.[CostGuid], T.[MinPrice] ORDER BY T.[BillNumber] DESC) AS Row_Num,
		    T.buFormatedNumber
		FROM 
			#Temp AS T
			INNER JOIN 
			(
				SELECT
					T.[MaterialGuid],
					T.[CustomerGuid],
					T.[StorePtr],
					T.[CostGuid],  
					MIN(T.[MinPrice]) [MinPrice]
				FROM    
					#Temp AS T
				GROUP BY    
					T.[MaterialGuid],   
					T.[CustomerGuid],   
					T.[StorePtr],
					T.[CostGuid]
				) AS T2 ON T.MaterialGuid = T2.MaterialGuid AND T.CustomerGuid = T2.CustomerGuid AND T.[StorePtr] = T2.[StorePtr] AND T.[CostGuid] = T2.[CostGuid] AND T.[MinPrice] = T2.[MinPrice]

		INSERT INTO #FinalResult 
		SELECT * 
		FROM #MainResult
		WHERE Row_Num = 1

		DECLARE @lang INT 
		SET @lang = dbo.fnConnections_GetLanguage();

		SELECT 
			t.[MaterialGuid],
			mt.[mtCode] + '-' + 
				(CASE @lang 
					WHEN 0 
						THEN MT.[mtName] 
					ELSE 
						(CASE mt.mtLatinName WHEN '' THEN mt.[mtName] ELSE mt.mtLatinName END) 
				END) [MaterialName],
			t.[CustomerGuid],
			cu.[CustomerName],
			t.[MinPrice],
			t.BiQty,
			t.[StorePtr],
			ISNULL(st.[Code] + '-' + 
				(CASE @lang 
					WHEN 0 
						THEN st.[Name] 
					ELSE 
						(CASE st.LatinName WHEN '' THEN st.[Name] ELSE st.LatinName END) 
				END), N'') [StoreName],
			t.[CostGuid],
			(CASE 
				WHEN co.guid IS NULL THEN ''
				ELSE 
					co.[Code] + '-' + 
						(CASE @lang 
							WHEN 0 
								THEN co.[Name] 
							ELSE 
								(CASE co.LatinName WHEN '' THEN co.[Name] ELSE co.LatinName END) 
						END)
			END) CostName,
			t.[BillGuid],
			t.[BiGuid],  
			mt.[mtDefUnitName] [UnitName],  
			mt.[mtDefUnitFact] [UnitFact],
			T.BuFormatedNumber 
		FROM 
			#FinalResult T  
			INNER JOIN vwmt AS MT ON T.[MaterialGuid] = MT.[mtGuid]  
			INNER JOIN cu000 AS CU ON T.[CustomerGuid] = CU.[Guid]
			LEFT JOIN st000 st ON st.guid = T.[StorePtr] 
			LEFT JOIN co000 co ON co.Guid = T.[CostGuid]
		ORDER BY  
			mt.[mtName],  
			t.[MinPrice],
			cu.[CustomerName]

#######################################################################################
#END
