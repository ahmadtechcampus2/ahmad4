################################################################################
CREATE PROCEDURE repMatMoveByPrice
	@StartDate [DATETIME],   
	@EndDate [DATETIME],   
	@ReportType [INT],   
	@PriceVal [FLOAT],   
	@Oper [INT],   
	@ViewType [INT],   
	@PriceType [INT],   
	@PricePolicy [INT],   
	@Src [UNIQUEIDENTIFIER],   
	@Cust [UNIQUEIDENTIFIER],   
	@Mt [UNIQUEIDENTIFIER], 
	@Gr [UNIQUEIDENTIFIER], 
	@Store [UNIQUEIDENTIFIER], 
	@Cost [UNIQUEIDENTIFIER], 
   	@CurGUID [UNIQUEIDENTIFIER], 
   	@CurVal [FLOAT], 
	@UseUnit [INT],
	@MatCondGuid [UNIQUEIDENTIFIER] = 0X00 
AS   
	SET NOCOUNT ON
	----------------------------  
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])  
	--Sources  Table--------------------------------------------------------------------------   
	CREATE TABLE [#STbl]( [bType] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])
	INSERT INTO [#STbl] EXEC [prcGetBillsTypesList2] @Src  
	--Mat Table ------------------------------------------------------------------------   
	CREATE TABLE [#Mat]( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])    
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @Mt, @Gr,-1,@MatCondGuid   
	--Cost Table------------------------------------------------------------------------   
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER])        
	INSERT INTO [#CostTbl] SELECT [GUID] From [fnGetCostsList]( @Cost)   
	if @Cost = 0x0   
		INSERT INTO [#CostTbl] SELECT 0x0   
	--Store  Table------------------------------------------------------------------------   
	CREATE TABLE [#StoreTbl]( [Number] [UNIQUEIDENTIFIER])    
	INSERT INTO [#StoreTbl] SELECT [GUID] From [fnGetStoresList]( @Store)   
	--Result  Table-------------------------------------------------------------------------   
	DECLARE @Option [INT]    
	SET @Option = @ReportType * 3 + @Oper   
	----------------------  
	DECLARE @MatTemp TABLE( [mtGUID] [UNIQUEIDENTIFIER], [Price] [FLOAT], [mtSecurity] [INT], CurrencyValue UNIQUEIDENTIFIER)  
	INSERT INTO @MatTemp  
		SELECT   
			[mt].[mtGUID],   
			--[dbo].[fnCurrency_fix] ( [mt].[price], [mt].[mtCurrencyPtr], [mt].[mtCurrencyVal], @CurGUID, @EndDate), 
			mt.Price, 
			[mat].[mtSecurity],
			mt.mtCurrencyPtr
		FROM  
			[dbo].[fnExtended_mt]( @PriceType, @PricePolicy, @UseUnit)  AS [mt] INNER JOIN [#Mat] AS [mat]
			ON [mat].[mtNumber] = [mt].[mtGUID]  
	-------------------------------------------------------------------------- 



	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
	BEGIN 
		UPDATE P
			SET Price =(P.Price/mt.lastpricecurval)
								 
			FROM
				@MatTemp P
				INNER JOIN mt000 mt on  mt.GUID= p.mtGUID
	END 

	ELSE IF @PriceType <> -1  AND @PriceType <> 2 AND @pricetype <> 0x800
	BEGIN 	
		BEGIN
			UPDATE P
			SET Price =(P.Price/mt.CurrencyVal)
								 
			FROM
				@MatTemp P
				INNER JOIN mt000 mt on  mt.GUID= p.mtGUID
		END
	END 
	
	

	----------------------  
	IF @ViewType = 1        
	BEGIN   
		CREATE TABLE [#Result]( 
			[BillGUID]			[UNIQUEIDENTIFIER], 
			[BillType]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[LatinBillType]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[BillNumber]		[INT], 
			[BillDate]			[DATETIME], 
			[CustName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[MatPtr]			[UNIQUEIDENTIFIER],        
			[mtCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[mtName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[mtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Qty]				[FLOAT], 
			[Bonus]				[FLOAT], 
			[MatUnit]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[MatPrice]			[FLOAT], 
			[ChosenPrice]		[FLOAT], 
			[mtSecurity]		[INT], 
			[Security]			[INT], 
			[UserSecurity]		[INT]) 

		INSERT INTO [#Result] 
		SELECT   
			[Bill].[BuGUID] AS [BillGUID],   
			[Bill].[btAbbrev]  + ': ' + cast([Bill].[buNumber] AS NVARCHAR(10)) AS [BillType],   
			[bt].[btLatinName] AS [LatinBillType],   
			[Bill].[buNumber] AS [BillNumber],        
			[Bill].[buDate] AS [BillDate],        
			ISNULL( (CASE WHEN [Bill].[buCustPtr] IS NULL THEN [cu].[cuCustomerName] ELSE [Bill].[buCust_Name] END), '') AS [CustName],   
			[Bill].[biMatPtr] AS [MatPtr],        
			[Bill].[mtCode],        
			[Bill].[mtName],        
			[Bill].[mtLatinName],        
			( [Bill].[biQty] / CASE @UseUnit 
					  	WHEN 0 THEN 1   
						WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
						WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
						ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   END) AS [Qty],    
			( [Bill].[biBonusQnt] / CASE @UseUnit   
							WHEN 0 THEN 1   
							WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
							WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
							ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
						END) AS [Bonus], 
			CASE @UseUnit        
				WHEN 0 THEN [Bill].[mtUnity]   
				WHEN 1 THEN [Bill].[mtUnit2]   
				WHEN 2 THEN [Bill].[mtUnit3]   
				ELSE [Bill].[mtDefUnitName] END AS [MatUnit],
			CASE WHEN [STbl].[ReadPrice] >= [bill].[buSecurity] THEN 1 ELSE 0 END * (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) / dbo.fnGetCurVal(@CurGUID, Bill.buDate)* CASE @UseUnit 
					  	WHEN 0 THEN 1   
						WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
						WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
						ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
				   	END AS [MatPrice],   
			-- select * from vwextended_bi
			CASE WHEN [STbl].[ReadPrice] >= [bill].[buSecurity] THEN 1 ELSE 0 END * (CASE @ReportType        
				WHEN 0 THEN CASE @UseUnit 
						WHEN 0 THEN 1   
						WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
						WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
						ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
						END * [Bill].[biUnitCostPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
				WHEN 1 THEN 
					CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
							[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
						WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
							[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
						ELSE
							[mt].[Price]
					END
				WHEN 2 THEN CAST (@PriceVal AS [NVARCHAR]( 30)) 
		 		WHEN 3 THEN [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)
		 		END) As [ChosenPrice], 
		 	[Bill].[mtSecurity], 
		 	[Bill].[buSecurity], 
		 	CASE [Bill].[buIsPosted] WHEN 1 THEN [STbl].[Sec] ELSE [STbl].[UnPostedSec] END
		FROM         
			[dbo].[fnExtended_bi_Fixed](@CurGUID) AS [Bill]        
			INNER JOIN [vwbt] AS [bt] ON [bt].[btGUID] = [Bill].[buType] 
			INNER JOIN @MatTemp AS [mt] ON [mt].[mtGUID] = [Bill].[biMatPtr]   
			INNER JOIN [#STbl] AS [STbl] ON [STbl].[bType] = [Bill].[buType]   
			INNER JOIN [#CostTbl] AS [Co] ON [Bill].[BiCostPtr] = [Co].[Number]   
			INNER JOIN [#StoreTbl] AS [St] ON [Bill].[BiStorePtr] = [St].[Number]  
			LEFT JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [Bill].[buCustPtr]   
		WHERE  
			[Bill].[buDate] between @StartDate AND @EndDate   
			AND ( [Bill].[buIsPosted] = 1)   
			AND ( @Cust = 0x0 OR [Bill].[buCustPtr] = @Cust)   
			AND (   
				( @Option = 0 AND (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END)  < [Bill].biUnitCostPrice )  
				OR ( @Option = 1 AND (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END)  > [Bill].biUnitCostPrice)   
				OR ( @Option = 2 AND (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END)  = [Bill].biUnitCostPrice)   

				OR ( @Option = 3 AND ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
						END < CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
									[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
								WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
									[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
								ELSE
									[mt].[Price] END ))
				OR (@Option = 4 AND ([Bill].biUnitPrice / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END > CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
												WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
												ELSE
													[mt].[Price] END))
				OR ( @Option = 5 AND ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].biUnitPrice END)/ dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END = CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
												WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
												ELSE
													[mt].[Price] END))
				OR ( @Option = 6 AND ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END < @PriceVal))   
				OR ( @Option = 7 AND ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END > @PriceVal))   
				OR ( @Option = 8 AND ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END = @PriceVal))

				OR ( @Option = 9 AND ( [Bill].[biUnitPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END < [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)))

				OR ( @Option = 10 AND ( [Bill].[biUnitPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END > [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)))

				OR ( @Option = 11 AND ( [Bill].[biUnitPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END = [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)))
			)  
		--------------------------------------------------------------------------- 
		EXEC [prcCheckSecurity] 
		--------------------------------------------------------------------------- 
		SELECT * 
		FROM 
			[#Result] 
		ORDER BY 
			[mtCode],
			[BillDate] ,
			[BillType],
			[BillNumber]
	END 
	ELSE 
	BEGIN   
		CREATE TABLE [#Result2]( 
				[MatPtr] [UNIQUEIDENTIFIER], 
				[mtCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
				[mtName] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
				[mtLatinName] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
				[MatUnit] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
				[Qty] [FLOAT], 
				[Bonus] [FLOAT], 
				[BillPrice] [FLOAT], 
				[mtSecurity] [INT], 
				[Security] [INT], 
				[UserSecurity] [INT]) 
		INSERT INTO [#Result2] 
		SELECT     
			[Bill].[biMatPtr] AS [MatPtr],        
			[Bill].[mtCode],        
			[Bill].[mtName],   
			[Bill].[mtLatinName], 
			CASE @UseUnit        
				WHEN 0 THEN [Bill].[mtUnity]   
				WHEN 1 THEN [Bill].[mtUnit2]   
				WHEN 2 THEN [Bill].[mtUnit3]   
				ELSE [Bill].[mtDefUnitName]   
			END  AS [MatUnit],        
			( [Bill].[biQty] / CASE @UseUnit 
					  	WHEN 0 THEN 1   
						WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
						WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
						ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   END) AS [Qty],    
			( [Bill].[biBonusQnt] / CASE @UseUnit   
							WHEN 0 THEN 1   
							WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
							WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
							ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
						END) AS [Bonus], 
			CASE WHEN [Src].[ReadPrice] >= [bill].[buSecurity] THEN 1 ELSE 0 END * ( (CASE WHEN [Bill].[btVATSystem] = 2 THEN  ([Bill].[biUnitPrice]*(1+([Bill].[biVATr]/100)))  ELSE [Bill].[biUnitPrice] END) / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
					  	WHEN 0 THEN 1   
						WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
						WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
						ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   END) AS [BillPrice], 

		 	[Bill].[mtSecurity],
		 	[Bill].[buSecurity],
		 	CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END
		FROM
			[dbo].[fnExtended_bi_Fixed](@CurGUID) AS [Bill]   
			INNER JOIN @MatTemp AS [mt] ON [mt].[mtGUID] = [Bill].[biMatPtr]   
			INNER JOIN [#STbl] AS [Src] ON [Bill].[buType] = [Src].[bType]   
			INNER JOIN [#CostTbl] AS [Co] ON [Bill].[BiCostPtr] = [Co].[Number]   
			INNER JOIN [#StoreTbl] AS [St] ON [Bill].[BiStorePtr] = [St].[Number]   
		WHERE   
			[Bill].[buDate] between @StartDate AND @EndDate   
			AND ( [Bill].[buIsPosted] = 1)   
			AND ( @Cust = 0x0 OR [Bill].[buCustPtr] = @Cust)   
			AND ( ( @ReportType = 0 
					AND (   
						( @Oper = 0 AND [Bill].[biUnitPrice] < [Bill].[biUnitCostPrice])  
						OR ( @Oper = 1 AND [Bill].[biUnitPrice] > [Bill].[biUnitCostPrice])   
						OR ( @Oper = 2 AND [Bill].[biUnitPrice] = [Bill].[biUnitCostPrice])   
										   
				))				  
				OR ( @ReportType = 1 
					AND 
						(    
						   ( @Oper = 0 AND [Bill].[biUnitPrice] * CASE @UseUnit 
										  	WHEN 0 THEN 1   
											WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
											WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
											ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
										   END < (CASE @PriceType 
											WHEN 0x8000 THEN [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)
											ELSE CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
												WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
												ELSE
													[mt].[Price]
												END END)) 
						OR ( @Oper = 1 AND [Bill].[biUnitPrice] * CASE @UseUnit 
										  	WHEN 0 THEN 1   
											WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
											WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
											ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
										   END  > (CASE @PriceType 
											WHEN 0x8000 THEN [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)
											ELSE CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
												WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
												ELSE
													[mt].[Price]
												END END))
						OR ( @Oper = 2 AND [Bill].[biUnitPrice] * CASE @UseUnit 
										  	WHEN 0 THEN 1   
											WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
											WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
											ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
										   END  = (CASE @PriceType 
											WHEN 0x8000 THEN [dbo].[fnCurrency_fix](dbo.fnGetOutbalanceAveragePriceByUnit(mt.mtGuid, bill.budate, @UseUnit + 1), NULL, 1, @CurGUID, bill.budate)
											ELSE CASE WHEN @PriceType = 2 AND (@PricePolicy = 121 OR @PricePolicy = 120) THEN
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)
												WHEN @PriceType <> -1 OR (@PriceType = 2 AND  @PricePolicy = 122) THEN 
													[mt].[Price] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * dbo.fnGetCurVal(mt.CurrencyValue, Bill.buDate)
												ELSE
													[mt].[Price]
												END END))
						)
					)  
				OR   
				( @ReportType = 2 AND  
				   ( 	 ( @Oper = 0 AND [Bill].[biUnitPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
										  	WHEN 0 THEN 1   
											WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
											WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
											ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
										   END < @PriceVal)   
					OR  ( @Oper = 1 AND [Bill].[biUnitPrice] / dbo.fnGetCurVal(@CurGUID, Bill.buDate)* CASE @UseUnit 
										  	WHEN 0 THEN 1   
											WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
											WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
											ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
										   END > @PriceVal)   
					OR  ( @Oper = 2 AND [Bill].[biUnitPrice] /dbo.fnGetCurVal(@CurGUID, Bill.buDate) * CASE @UseUnit 
									  	WHEN 0 THEN 1   
										WHEN 1 THEN ISNULL( CASE [Bill].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END, 1) 
										WHEN 2 THEN ISNULL( CASE [Bill].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END, 1) 
										ELSE ISNULL( CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END, 1) 
					   				END = @PriceVal) 
				   ) 
				)  
			)  
		--------------------------------------------------------------------------- 
		EXEC [prcCheckSecurity]  @result = '#Result2' 
		--------------------------------------------------------------------------- 
		SELECT     
			[MatPtr], 
			[mtCode], 
			[mtName], 
			[mtLatinName], 
			[MatUnit], 
			SUM( [Qty]) AS [Qty], 
			SUM( [Bonus]) AS [Bonus], 
			[BillPrice] 
		FROM  
			[#Result2]  
		GROUP BY          
			[MatPtr], 
			[mtCode], 
			[mtName], 
			[mtLatinName], 
			[MatUnit], 
			[BillPrice] 
		ORDER BY  
			[mtCode]  
	END 
################################################################################
#END