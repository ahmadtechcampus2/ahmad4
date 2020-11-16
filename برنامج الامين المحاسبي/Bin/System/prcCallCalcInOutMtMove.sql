############################################################
CREATE PROCEDURE prcCallCalcInOutMtMove
	@IsCalledByWeb		BIT,
	@StartDate 			[DATETIME],   
	@EndDate 			[DATETIME],  
	@SrcTypesguid 		[UNIQUEIDENTIFIER],  
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber  
	@GroupGUID 			[UNIQUEIDENTIFIER],  
	@PostedValue 		[INT], 	-- 0, 1 , -1  
	@Vendor 			[FLOAT],  
	@SalesMan 			[FLOAT],  
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text  
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain  
	@CustGUID 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust  
	@StoreGUID 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores  
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs  
	@AccGUID 			[UNIQUEIDENTIFIER],  
	@CurrencyGUID 		[UNIQUEIDENTIFIER],  
	@CurrencyVal 		[FLOAT],  
	@MatType 			[INT], -- 0 MatStore or 1 MAtService or -1 ALL Mats Types  
	@UseUnit 			[INT], 
	@CondGuid			[UNIQUEIDENTIFIER] = 0x00, 
	@shwallats			[BIT] = 0, -- ShowEmptyMats
	@shwBalMats			[BIT] = 0, -- Show Balanced Materials
	@ShwGrp				[BIT] = 0, 
	@ShwMats			[BIT] = 1, 
	@grpLevel			[INT] = 0, 
	@CustCond			UNIQUEIDENTIFIER = 0x00,
	@Class				NVARCHAR (200) = '',
	@ShowClass			BIT = 0,
	@ShowExpireDate		BIT = 0,
	@PriceType			[INT] = 0 , 
	@PricePolicy		[INT] = 0,
	@InS				INT = 1,
	@OutS				INT = -1
	
AS 
	SET NOCOUNT ON  
	
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)
	
	CREATE TABLE [#Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[Value] 	[FLOAT],
		[Group]		[UNIQUEIDENTIFIER],
		[lv]		[INT]
	)
	DECLARE @SQL  NVARCHAR(max),@col1  NVARCHAR(100),@col2  NVARCHAR(100),@col3  NVARCHAR(100) ,@Rcnt INT
	DECLARE @shwmt	[BIT] 
	SET @shwmt = 1 
	IF (@MatType = -2) 
	BEGIN 
		SET @MatType = -1 
		SET @shwmt = 0 
	END 
	-- Creating temporary tables  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER])  
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#GrpTbl] 
	( 
		[GrptGUID]		[UNIQUEIDENTIFIER], 
		[Level]			INT,  
		[Path]			NVARCHAR(max), 
		[grName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[grCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[grLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI, 
		[ParentGuid]	UNIQUEIDENTIFIER 
	)  
	
	IF @shwGrp > 0 
	BEGIN 
		INSERT INTO [#GrpTbl] SELECT a.[GUID],a.[Level],a.[Path],b.[Name],b.[Code],b.[LatinName],[ParentGuid] FROM dbo.fnGetGroupsOfGroupSorted(@GroupGUID,1) a INNER JOIN [gr000] b ON b.Guid = a.Guid 
		CREATE CLUSTERED INDEX grpInd ON [#GrpTbl]([GrptGUID]) 
	END 
	--Filling temporary tables  
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, @MatType,@CondGuid 
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList2] @SrcTypesguid  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID  
	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 		@CustGUID, @AccGUID ,@CustCond
	
	IF (@CustGUID = 0X00) AND (@AccGUID = 0X00) AND @CustCond = 0X00
		INSERT INTO [#CustTbl] VALUES(0X00,0) 
	
	IF @NotesContain IS NULL  
		SET @NotesContain = ''  
	
	IF @NotesNotContain IS NULL  
		SET @NotesNotContain = ''  
	
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
	BEGIN 
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0 
	END 
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
	BEGIN 
		EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @CurrencyVal, @SrcTypesguid, 0, 0 
	END 
	ELSE IF @PriceType = 2 AND @PricePolicy = 121  -- COST And AvgPrice NO STORE DETAILS 
	BEGIN 
		EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,	0, 0 
	END 
	ELSE IF @PriceType = -1 
		INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl] 
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
	BEGIN 
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
	END 
	ELSE 
	BEGIN 
		EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, 0, @UseUnit ,@EndDate
		
		IF @UseUnit > 0
		BEGIN
			UPDATE p
			SET APrice = APrice * (CASE @UseUnit WHEN 1 THEN mt.mtUnit2Fact WHEN 2 THEN mt.mtUnit3Fact WHEN 3 THEN mt.mtDefUnitFact END)
			FROM
				#t_Prices AS p
				INNER JOIN vwMt AS mt ON p.mtNumber = mt.[mtGUID]
		END
	END 
	
	CREATE CLUSTERED INDEX [cuind] ON [#CustTbl]( [CustGUID]) 
	CREATE CLUSTERED INDEX [BTind] ON [#BillsTypesTbl]( [TypeGuid]) 
	
	SELECT [buGuid],[buType],[btIsInput],[btIsOutput], 
		[bt].[UserReadPriceSecurity] UserReadPriceSecurity,
		[B].[buSecurity] buSecurity,
		[buPayType], 
		[FixedCurrencyFactor],[BuNotes],[buCostPtr], 
		CASE WHEN  [bt].[UserReadPriceSecurity] >= [B].[buSecurity] THEN 1 ELSE 0 END ReadPrc,  
		CASE [buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [bt].[UnPostedSecurity] END AS [btSecurity],
		[FixedbuTotal],
		[FixedbuItemsExtra],
		[FixedbuItemsDisc]
	INTO [#BU] 
	FROM 
		[fnbu_fixed](@CurrencyGUID)AS [b] 
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [b].[buType] = [bt].[TypeGuid] 
		INNER JOIN [#CustTbl] AS [cu] ON [cu].[CustGUID] = [buCustPtr] 
	WHERE  
		([b].[Budate] BETWEEN @StartDate AND @EndDate)  
		AND( (@PostedValue = -1) 				OR ([b].[BuIsPosted] = @PostedValue))  
		AND( (BuVendor = @Vendor) 				OR (@Vendor = 0 ))  
		AND( (BuSalesManPtr = @SalesMan) 		OR (@SalesMan = 0))  
	CREATE CLUSTERED INDEX BUind ON [#BU]( [BUGuid]) 
	SELECT  
		bi.[MatGuid] AS [biMatPtr], 
		SUM([Qty]) AS [biQty], 
		SUM([Qty2]) AS [biQty2], 
		SUM([Qty3]) AS [biQty3], 
		SUM([BonusQnt]) AS [biBonusQnt], 
		SUM([Qty]*[Price]*[FixedCurrencyFactor]*[ReadPrc]) AS [biTotalPrice], 
		[Unity] AS [biUnity], 
		SUM([Extra] *[FixedCurrencyFactor] * [ReadPrc]) AS [biExtra], 
		SUM(([Discount] * [ReadPrc] + [BonusDisc]) * [FixedCurrencyFactor] * [ReadPrc]) AS [biDiscount],  
		SUM(([bi].[Vat] + ISNULL(bi.ExciseTaxVal, 0) + ISNULL(bi.ReversChargeVal, 0)) * [FixedCurrencyFactor] * [ReadPrc]) AS [biVat], 
		[buSecurity], 
		[buPayType], 
		[buType], 
		[StoreGuid] AS [biStorePtr], 
		CASE [CostGuid] WHEN 0X00 THEN [buCostPtr] ELSE [CostGuid] END AS [biCostPtr],
		[btIsInput],
		[btIsOutput],
		[btSecurity],
		CASE @ShowClass WHEN 1 THEN [bi].[ClassPtr] ELSE '' END ClassPtr,
		CASE @ShowExpireDate WHEN 1 THEN 
		                            ( CASE [bi].[ExpireDate] WHEN '1/1/1980' THEN NULL ELSE [bi].[ExpireDate] END )
									 ELSE '1/1/1980' END ExpireDate,
		CASE WHEN SUM([Qty]) = 0 THEN 0 ELSE SUM(bi.LCDisc) / SUM([Qty]) END AS LCDisc,
		CASE WHEN SUM([Qty]) = 0 THEN 0 ELSE SUM(bi.LCExtra) / SUM([Qty])END AS LCExtra,
		bu.buguid,
		SUM(bu.FixedBuTotal) AS FixedBuTotal,
		SUM(bu.FixedbuItemsDisc) AS FixedbuItemsDisc,
		SUM(bu.FixedbuItemsExtra) AS FixedbuItemsExtra,
		FixedCurrencyFactor
	INTO [#Bill] 
	FROM  
		[#BU] AS [bu] 
		INNER JOIN  [bi000] [bi] ON [bu].[buGuid] = [bi].[ParentGuid] 
		INNER JOIN [#MatTbl] AS [m] ON [m].[MatGUID] = [bi].[MatGUID]
	WHERE ((@NotesContain = '')	OR ([BuNotes] LIKE '%'+ @NotesContain + '%')  OR ( [Bi].[Notes] LIKE '%' + @NotesContain + '%'))  
		AND ((@NotesNotContain ='')				OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([Bi].[Notes] NOT LIKE '%'+ @NotesNotContain + '%')))  
		AND ((ClassPtr = @Class) OR (@Class = ''))
	GROUP BY 
		bi.[MatGuid], 
		[Unity], 
		[buSecurity], 
		[buPayType], 
		[buType], 
		[StoreGuid], 
		CASE [CostGuid] WHEN 0X00 THEN [buCostPtr] ELSE [CostGuid] END, 
		[btIsInput],
		[btIsOutput],
		[btSecurity],
		CASE @ShowClass WHEN 1 THEN [bi].[ClassPtr] ELSE '' END,
		CASE @ShowExpireDate WHEN 1 THEN 
		                           ( CASE [bi].[ExpireDate] WHEN '1/1/1980' THEN NULL ELSE [bi].[ExpireDate] END )
								    ELSE '1/1/1980' END ,
		bi.guid,
		bu.buguid,
		FixedCurrencyFactor
	SELECT [Code] AS [MtCode],[Name] AS [MtName],[LatinName] AS [MtLatinName],[Unity] AS [mtUnity] 
		,[Unit2] AS [mtUnit2],[Unit3] AS [mtUnit3], 
		CASE [defunit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE  [Unit3] END AS [mtDefUnitName], 
		[Unit2Fact] AS [mtUnit2Fact],  
		[Unit3Fact] AS [mtUnit3Fact],  
		CASE [defunit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE  [Unit3Fact] END AS [mtDefUnitFact], 
		CASE @UseUnit 	WHEN 0 THEN 1  
				WHEN 1 THEN	CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
				WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END 
				WHEN 3 THEN 
					CASE [defunit] WHEN 1 THEN 1 WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE  [Unit2Fact] END ELSE  CASE [Unit3Fact] WHEN 0 THEN 1 ELSE  [Unit3Fact] END END END AS [mtDefaultUnit], 
		[MatGUID] , [mtSecurity], 
		[Unit2FactFlag]  AS [mtUnit2FactFlag], 
		[Unit3FactFlag]  AS [mtUnit3FactFlag],GroupGuid 
		INTO [#MatTbl2] 
	FROM [mt000] AS [mt]
		INNER JOIN [#MatTbl] AS [m] ON [m].[MatGUID] = [mt].[Guid] 
		
	CREATE CLUSTERED INDEX [buuind] ON #Bill([BiMatPtr]) 
	CREATE CLUSTERED INDEX [mtind] ON #MatTbl2([MatGUID]) 
	CREATE CLUSTERED INDEX [stind] ON [#StoreTbl]([StoreGUID]) 
	CREATE TABLE [#Result]  
	( 
		[buType]							[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[MtName]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtCode]							[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtLatinName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtUnity]							[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtUnit2]							[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtUnit3]							[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtDefUnitName]						[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',    
		[BiMatPtr]							[UNIQUEIDENTIFIER],  
		[btIsInput] 						[INT],  
		[biQty] 							[FLOAT],  
		[mtUnit2Fact]						[FLOAT] DEFAULT 0,   
		[mtUnit3Fact]						[FLOAT] DEFAULT 0,  
		[mtDefUnitFact]						[FLOAT] DEFAULT 0,  
		[btIsOutput] 						[INT],  
		[biBonusQnt] 						[FLOAT],  
		[biQty2]							[FLOAT],  
		[biQty3]							[FLOAT],  
		[SumPrice]							[FLOAT],  
		[SumVat]							[FLOAT],  
		[SumTotalExtra]						[FLOAT],  
		[SumTotalDisc] 						[FLOAT], 
		[SumItemDisc] 						[FLOAT],  
		[Security]							[INT]  DEFAULT 0,  
		[UserSecurity] 						[INT]  DEFAULT 0,  
		[mtDefaultUnit]						[FLOAT],  
		[MtSecurity]						[INT], 
		[buPayType]							[INT], 
		[IsMat]								[INT], 
		[GroupGuid]							[UNIQUEIDENTIFIER], 
		[Path]								NVARCHAR(max), 
		[Class]								NVARCHAR(1000),
		[ExpireDate]						SMALLDATETIME,
		[IsBalMat]							[INT],
		SumItemLCDisc 						[FLOAT],  
		SumItemLCExtra 						[FLOAT],  
	) 
	 
	DROP TABLE [#BU] 
	
	IF @shwallats = 0 
		INSERT INTO [#Result] 
		SELECT  
			[buType], 
			[MtName],  
			[MtCode],  
			[MtLatinName],  
			[mtUnity], 
			[mtUnit2],  
			[mtUnit3],  
			[mtDefUnitName],  
			[BiMatPtr],  
			[btIsInput],  
			SUM([rv].[biQty] / [mtDefaultUnit]),  
			CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END ,  
			CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END,  
			[mtDefUnitFact], 
			[btIsOutput],   
			SUM([biBonusQnt]/[mtDefaultUnit]), 
			SUM(CASE [mtTbl].[mtUnit2FactFlag]
					WHEN 0 THEN
						CASE [mtTbl].[mtUnit2Fact]
							WHEN 0 THEN 0 ELSE [rv].[biQty] / [mtTbl].[mtUnit2Fact]
						END
					ELSE [rv].[biQty2]
				END),
			SUM(CASE [mtTbl].[mtUnit3FactFlag]
					WHEN 0 THEN
						CASE [mtTbl].[mtUnit3Fact]
							WHEN 0 THEN 0 ELSE [rv].[biQty] / [mtTbl].[mtUnit3Fact]
						END
					ELSE [rv].[biQty3]
				END),  
			SUM([biTotalPrice] / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END),
			SUM([BiVat]),   
			--[MtUnitFact],  
			SUM((((biTotalPrice / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END)  + biExtra) * (Extra * FixedCurrencyFactor) / CASE (FixedBuTotal + FixedbuItemsExtra) WHEN 0 THEN 1 ELSE (FixedBuTotal + FixedbuItemsExtra) END  ) + biExtra),
			SUM((((biTotalPrice / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END) - biDiscount) * (Discount * FixedCurrencyFactor) /CASE (FixedBuTotal - FixedbuItemsDisc) WHEN 0 THEN 1 ELSE (FixedBuTotal - FixedbuItemsDisc) END  )),
			SUM([biDiscount]),  
			[BuSecurity],  
			[btSecurity],  
			[mtDefaultUnit],  
			[mtTbl].[MtSecurity], 
			[buPayType],
			1,
			GroupGuid,
			'', -- path
			[ClassPtr],
			[ExpireDate],
			0, -- [IsBalMat]
			SUM(rv.LCDisc),
			SUM(rv.LCExtra)
		FROM ([#Bill] AS [rv] INNER JOIN [#MatTbl2] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid]) 
		INNER JOIN [#StoreTbl] AS [st] ON [BiStorePtr] = [StoreGUID]  
		OUTER APPLY dbo.fnBill_GetDiSum(rv.buguid) AS DI  
		WHERE
			(@CostGUID = 0x0) OR ([BiCostPtr] IN (SELECT [CostGUID] FROM [#CostTbl])) 
		GROUP BY 
			[buType], 
			[MtName], 
			[MtCode], 
			[MtLatinName], 
			[mtDefaultUnit], 
			[mtUnity], 
			[mtUnit2], 
			[mtUnit3], 
			[mtDefUnitName], 
			[BiMatPtr], 
			[btIsInput], 
			[mtUnit2Fact], 
			[mtUnit3Fact], 
			[mtDefUnitFact], 
			[btIsOutput], 
			[BuSecurity], 
			[btSecurity], 
			[mtTbl].[MtSecurity], 
			[buPayType],
			GroupGuid,
			[ClassPtr],[ExpireDate] 
	ELSE 
		INSERT INTO [#Result] 
		SELECT  
			ISNULL([buType],0X00), 
			[MtName],  
			[MtCode],  
			[MtLatinName],  
			[mtUnity], 
			[mtUnit2],  
			[mtUnit3],  
			[mtDefUnitName],  
			[mtTbl].[MatGuid],  
			ISNULL([btIsInput],0),  
			ISNULL(SUM([rv].[biQty]/[mtDefaultUnit]),0),
			CASE  [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END ,  
			CASE  [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ,
			[mtDefUnitFact], 
			ISNULL([btIsOutput],0),   
			ISNULL(SUM([biBonusQnt]/[mtDefaultUnit] ),0),
			ISNULL(SUM(CASE [mtTbl].[mtUnit2FactFlag]
							WHEN 0 THEN
								CASE [mtTbl].[mtUnit2Fact]
									WHEN 0 THEN 0 ELSE [rv].[biQty] / [mtTbl].[mtUnit2Fact]
								END
							ELSE [rv].[biQty2]
						END), 0),
			ISNULL(SUM(CASE [mtTbl].[mtUnit3FactFlag]
							WHEN 0 THEN
								CASE [mtTbl].[mtUnit3Fact]
									WHEN 0 THEN 0
									ELSE [rv].[biQty] / [mtTbl].[mtUnit3Fact]
								END
							ELSE [rv].[biQty3]
						END), 0),  
			ISNULL(SUM([biTotalPrice] / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END), 0),
			ISNULL(SUM([BiVat]), 0),
			--[MtUnitFact],  
			ISNULL(SUM((((biTotalPrice / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END)  + biExtra) * (Extra * FixedCurrencyFactor)/(CASE(FixedBuTotal + FixedbuItemsExtra) WHEN 0 THEN 1 ELSE (FixedBuTotal + FixedbuItemsExtra) end) )+ biExtra), 0),
			ISNULL(SUM((((biTotalPrice / CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mtTbl].[mtUnit2Fact] ELSE [mtTbl].[mtUnit3Fact] END) - biDiscount) * (Discount * FixedCurrencyFactor)/ CASE(FixedBuTotal - FixedbuItemsDisc) WHEN 0 THEN 1 ELSE (FixedBuTotal - FixedbuItemsDisc) end  )), 0),
			ISNULL(SUM([biDiscount]), 0),
			ISNULL([BuSecurity], 0),
			ISNULL([btSecurity], 0),
			[mtDefaultUnit],  
			[mtTbl].[MtSecurity], 
			ISNULL([buPayType], 0),
			1,
			GroupGuid,
			'',
			[ClassPtr],
			[ExpireDate],
			0, -- [IsBalMat] 	 
			SUM(rv.LCDisc),
			SUM(rv.LCExtra)	 
		FROM
			([#Bill] AS [rv] INNER JOIN [#StoreTbl] AS [st] ON [BiStorePtr] = [StoreGUID])
			RIGHT JOIN [#MatTbl2] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid]
			OUTER APPLY dbo.fnBill_GetDiSum(rv.buguid) AS DI  
		WHERE
			(@CostGUID = 0x0) OR ([BiCostPtr] IN(SELECT [CostGUID] FROM [#CostTbl]))  
		GROUP BY 
			[buType], 
			[MtName],  
			[MtCode],  
			[MtLatinName],  
			[mtUnity], 
			[mtUnit2],  
			[mtUnit3],  
			[mtDefUnitName],  
			[mtDefaultUnit], 
			[mtTbl].[MatGuid],  
			[btIsInput],  
			[mtUnit2Fact],  
			[mtUnit3Fact],  
			[mtDefUnitFact],  
			[btIsOutput], 
			[BuSecurity],  
			[btSecurity],  
			--[UserReadPriceSecurity],  
			[mtTbl].[MtSecurity], 
			[buPayType],
			GroupGuid,
			[ClassPtr],
			[ExpireDate] 
		IF (@shwBalMats = 0)
			BEGIN
				DELETE FROM [#Result]
				WHERE [BiMatPtr] IN (SELECT [BiMatPtr] FROM (
										SELECT
											[BiMatPtr],
											SUM(CASE [btIsInput] WHEN 1 THEN ([biQty] + [biBonusQnt]) ELSE -([biQty] + [biBonusQnt]) END) AS [Qty]
										FROM
											[#Result]
										WHERE
											[buType] <> 0x00
										GROUP BY
											[BiMatPtr]) AS [SubResult]
									WHERE [SubResult].[Qty] = 0)
			END
			ELSE
			BEGIN
				UPDATE r
				SET [IsBalMat] = 1
				FROM [#Result] r
				WHERE [BiMatPtr] IN (SELECT [BiMatPtr] FROM (
											SELECT
												[BiMatPtr],
												SUM(CASE [btIsInput] WHEN 1 THEN ([biQty] + [biBonusQnt]) ELSE -([biQty] + [biBonusQnt]) END) AS [Qty]
											FROM
												[#Result]
											WHERE
												[buType] <> 0x00
											GROUP BY
												[BiMatPtr]) AS [SubResult]
										WHERE [SubResult].[Qty] = 0)
			END
	
	DROP TABLE [#BILL] 
		SELECT  
		[rv].[BuType],  
		[rv].[btIsInput], 
		ISNULL(SUM( [rv].[biQty] ), 0)AS [SumQty], 
		ISNULL(SUM([rv].[biQty2]), 0) AS [SumQty2], 
		ISNULL(SUM([rv].[biQty3]), 0) AS [SumQty3], 
		ISNULL(SUM([rv].[BiBonusQnt]), 0) AS [SumBonusQty], 
		ISNULL(SUM((CASE [BuPayType] WHEN 0 THEN [SumPrice] ELSE 0 END)), 0) AS [SumCashPrice],  
		ISNULL(SUM((CASE WHEN [BuPayType] >= 1 THEN [SumPrice] ELSE 0 END)), 0) AS [SumCreditPrice],  
		ISNULL(SUM((CASE [BuPayType]  
					WHEN 0 THEN [SumTotalDisc] +  [SumItemDisc] 
					ELSE 0 END)), 0) AS [SumCashDisc],  
		ISNULL(SUM((CASE WHEN [BuPayType] >= 1 THEN [SumTotalDisc] +  [SumItemDisc] 
				ELSE 0	END)), 0) AS [SumCreditDisc],  
		ISNULL(SUM((CASE [BuPayType]   
					WHEN 0 THEN [SumTotalExtra] 
					ELSE 0 END)), 0) AS [SumCashExtra],  
		ISNULL(SUM((CASE  
				WHEN [BuPayType] >= 1 THEN [SumTotalExtra] 
				ELSE 0 END )), 0) AS [SumCreditExtra],  
		 
		ISNULL(SUM((CASE [BuPayType]   
				WHEN 0 THEN [SumVat] ELSE 0 END)), 0) AS [SumCashVat],   
		ISNULL(SUM((CASE   
				WHEN [BuPayType] >= 1 THEN [SumVat] ELSE 0 END)), 0) AS [SumCreditVat],
		ISNULL(CASE WHEN (@PriceType <> 2 OR @PricePolicy <> 121) THEN 0 ELSE SUM(SumItemLCDisc) END, 0) AS [SumLCDisc],  
		ISNULL(CASE WHEN (@PriceType <> 2 OR @PricePolicy <> 121) THEN 0 ELSE SUM(SumItemLCExtra) END, 0) AS [SumLCExtra],
		[bt].[btName],
		[bt].[btLatinName]
	INTO #Total 
	FROM [#Result] AS [rv] INNER JOIN vwbt bt ON [rv].[buType] = [bt].[btGUID] 
	WHERE [UserSecurity] >= [Security] AND [rv].[BuType] <> 0X00 AND [bt].[btSortNum] <> 0
	GROUP BY  
		[rv].[BuType], [rv].[btIsInput], [bt].[btName], [bt].[btLatinName]
	
	IF (@PriceType<> -1) -- @PriceType <> 'BILL PRICE = -1'
	BEGIN
		INSERT INTO [#Prices] 
		SELECT	[r].[BiMatPtr] ,
				SUM((([r].[biQty] + [r].[BiBonusQnt])  * (CASE [r].[btIsInput] WHEN 1 THEN @InS ELSE @OutS END))
					* ISNULL([p].[APrice],0) * (CASE @PriceType WHEN 2 THEN 
						(CASE @UseUnit WHEN 1 THEN [r].[mtUnit2Fact] WHEN 2 THEN [r].[mtUnit3Fact] WHEN 3 THEN [r].[mtDefUnitFact] ELSE 1 END)
					 ELSE 1 END)) AS [Value],
				[r].[GroupGuid],
				-1
		FROM [#Result] [r] 
			 LEFT  JOIN [#t_Prices] [p] ON [p].[mtNumber] = [r].[BiMatPtr] 
		GROUP BY [r].[BiMatPtr], [r].[GroupGuid], [p].[APrice]	
	END
	
	IF @shwGrp > 0 
	BEGIN 
		DECLARE @ind INT 
		IF @grpLevel > 0 
		BEGIN 
			SET @ind = 1 
			WHILE @ind > 0 
			BEGIN 
				UPDATE r SET [GroupGuid] = b.[ParentGuid]   FROM [#Result] r INNER JOIN [#GrpTbl] b ON b.[GrptGUID] = [GroupGuid] where [Level] > @grpLevel - 1 
				SET @ind = @@ROWCOUNT 
			
				-- 
				IF (@PriceType<> -1) -- @PriceType <> 'BILL PRICE = -1'
				BEGIN
					UPDATE [r] 
						SET [r].[Group] = [b].[ParentGuid] 
					FROM [#Prices] [r] INNER JOIN [#GrpTbl] [b] ON [b].[GrptGUID] = [r].[Group]  
					WHERE [b].[Level] > @grpLevel - 1 
				END
				
			END 
		END 
		UPDATE r SET [Path] = b.[Path]   FROM [#Result] r INNER JOIN [#GrpTbl] b ON b.[GrptGUID] = [GroupGuid] 
		
		INSERT INTO [#Result] ([BiMatPtr], [MtCode], [MtName], [MtLatinName], [btIsInput], [biQty], [btIsOutput], [biBonusQnt], [biQty2], [biQty3], [SumPrice], [SumVat], [SumTotalExtra], [SumTotalDisc], [SumItemDisc], [buPayType], [IsMat], [GroupGuid], [Path],[Class],[ExpireDate],[SumItemLCDisc],[SumItemLCExtra])
		SELECT  b.[GrptGUID], 
				[grCode], 
				[grName], 
				[grLatinName], 
				[btIsInput], 
				SUM([biQty]), 
				[btIsOutput], 
				SUM([biBonusQnt]), 
				SUM([biQty2]), 
				SUM([biQty3]), 
				SUM([SumPrice]), 
				SUM([SumVat]), 
				SUM([SumTotalExtra]), 
				SUM([SumTotalDisc]), 
				SUM([SumItemDisc]), 
				[buPayType], 
				0, 
				b.[ParentGuid], 
				b.[Path],
				[Class], [ExpireDate],
				SUM([SumItemLCDisc]),
				SUM([SumItemLCExtra])
		FROM [#Result] r 
		INNER JOIN [#GrpTbl] b ON b.[GrptGUID] = [GroupGuid] 
		GROUP BY  
				b.[GrptGUID], 
				[grCode], 
				[grName], 
				[grLatinName], 
				[btIsInput], 
				[btIsOutput], 
				[buPayType], 
				b.[ParentGuid], 
				b.[Path],
				[Class], [ExpireDate]
		
		IF @shwmt = 0  OR @ShwMats = 0
			DELETE [#Result] WHERE [IsMat] = 1  
		SET @ind = 0 
		
		--
		IF (@PriceType<> -1) -- @PriceType <> 'BILL PRICE = -1'
		BEGIN
			INSERT INTO [#Prices] 
			SELECT	[b].[GrptGUID] , 
					SUM([r].[Value]), 
					[b].[ParentGuid],
					0
			FROM [#Prices] [r] INNER JOIN [#GrpTbl] [b] ON [b].[GrptGUID] = [r].[Group]  
			GROUP BY [b].[GrptGUID],[b].[ParentGuid]
		END
		
		
		WHILE @ind <= 0 
		BEGIN 
			INSERT INTO [#Result] ([BiMatPtr], [MtCode], [MtName], [MtLatinName], [btIsInput], [biQty], [btIsOutput], [biBonusQnt], [biQty2], [biQty3], [SumPrice], [SumVat], [SumTotalExtra], [SumTotalDisc], [SumItemDisc], [buPayType], [IsMat], [GroupGuid], [Path], [Class],ExpireDate,[SumItemLCDisc],[SumItemLCExtra]) 
			SELECT  b.[GrptGUID],
					[grCode],
					[grName],
					[grLatinName],
					[btIsInput],
					SUM([biQty]), 
					[btIsOutput],
					SUM([biBonusQnt]),
					SUM([biQty2]),
					SUM([biQty3]),  
					SUM([SumPrice]),
					SUM([SumVat]),
					SUM([SumTotalExtra]),
					SUM([SumTotalDisc]), 
					SUM([SumItemDisc]),
					[buPayType],
					@ind - 1,
					b.[ParentGuid],
					b.[Path],
					[Class],[ExpireDate],
					SUM([SumItemLCDisc]),
					SUM([SumItemLCExtra])
			FROM [#Result] r INNER JOIN [#GrpTbl] b ON b.[GrptGUID] = [GroupGuid] 
			WHERE [IsMat] = @ind 
			GROUP BY 
					b.[GrptGUID],
					[grCode],
					[grName],
					[grLatinName],
					[btIsInput],
					[btIsOutput],
					[buPayType],
					b.[ParentGuid],
					b.[Path],
					[Class],[ExpireDate]
			SET @Rcnt = @@ROWCOUNT
			
			--
			IF (@PriceType<> -1) -- @PriceType <> 'BILL PRICE = -1'
			BEGIN
				INSERT INTO [#Prices] 
				SELECT	[b].[GrptGUID] , 
						SUM([r].[Value]), 
						[b].[ParentGuid],
						@ind - 1
				FROM [#Prices] [r] INNER JOIN [#GrpTbl] [b] ON [b].[GrptGUID] = [r].[Group] 
				WHERE [b].[Level] = @ind -- b.Level or What? there was only lvl word
				GROUP BY [b].[GrptGUID],[b].[ParentGuid]
			END
			
			IF @Rcnt = 0 
				BREAK 
			SET @ind = @ind - 1 
		END 
	END 
	
	IF(@PriceType <> 2 OR @PricePolicy <> 121) -- not avg cost price
	BEGIN
		UPDATE r SET [SumItemLCDisc] = 0, [SumItemLCExtra] = 0   FROM [#Result] r
	END
	EXEC [prcCheckSecurity]  
	
	Declare @CF_Table NVARCHAR(255) --Mapped Table for Custom Fields
	
	CREATE TABLE [#MainResult]
	(
		[MtNumber]					[UNIQUEIDENTIFIER] DEFAULT 0X00,
		[MtGuid]					[UNIQUEIDENTIFIER] DEFAULT 0X00,
		[GroupGuid]					[UNIQUEIDENTIFIER] DEFAULT 0X00,
		[MtName]					[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtCode]					[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[MtLatinName]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtUnity]					[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtUnit2]					[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtUnit3]					[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtDefUnitName]				[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtDefaultUnit]				[FLOAT],
		[ParentGuid]				[UNIQUEIDENTIFIER] DEFAULT 0X00,
		[IsBalMat]					[INT],
		[IsMat]						[INT], 
		[SumInQty]					[FLOAT],
		[SumOutQty]					[FLOAT],
		[SumInQty2]					[FLOAT],
		[SumOutQty2]				[FLOAT],
		[SumInQty3]					[FLOAT],
		[SumOutQty3]				[FLOAT],
		[SumInBonusQty]				[FLOAT],
		[SumOutBonusQty]			[FLOAT],
		[SumInPrice]				[FLOAT],
		[SumInVat]					[FLOAT],
		[SumOutPrice]				[FLOAT],
		[SumOutVat]					[FLOAT],
		[SumInExtra]				[FLOAT],
		[SumOutExtra]				[FLOAT],
		[SumInDisc]					[FLOAT],
		[SumOutDisc]				[FLOAT],
		[SumInDiscVal]				[FLOAT],
		[SumOutDiscVal]				[FLOAT],
		[SumInLCDisc]				[FLOAT],
		[SumOutLCDisc]				[FLOAT],
		[SumInLCExtra]				[FLOAT],
		[SumOutLCExtra]				[FLOAT],
		[Class]						[NVARCHAR](1000),
		[ExpireDate]				[SMALLDATETIME],
		[OutbalanceAveragePrice]	[FLOAT],
		[PriceValue]				[FLOAT]
	)
		--SELECT * FROM [#Result]
		SET @Sql = '  
		SELECT  
			[BiMatPtr] AS [MtNumber],[MtName], [MtCode],  
			[MtLatinName],[MtUnity],[mtUnit2],  
			[mtUnit3],[mtDefUnitName],[mtDefaultUnit], [GroupGuid], [IsBalMat],
			CASE [IsMat] WHEN 1 THEN 1 ELSE 0 END [IsMat],' 
 			
		--SET @Sql = @Sql + '	CASE [IsMat] WHEN 1 THEN 1 ELSE 0 END [IsMat],  (Select Top 1 ([GroupGuid]))  AS ParentGUID,' 
		
		SET @Sql = @Sql + 'SUM( [r].[btIsInput] * [biQty]) AS [SumInQty],  
			ISNULL(SUM( [r].[btIsOutput] * [biQty] ), 0) AS [SumOutQty],  
			ISNULL(SUM( [r].[btIsInput] * [biQty2] ), 0) AS  [SumInQty2],  
			ISNULL(SUM([r].[btIsOutput] * [biQty2] ), 0) AS [SumOutQty2],  
			ISNULL(SUM( [r].[btIsInput] * [biQty3] ), 0) AS [SumInQty3],  
			ISNULL(SUM([r].[btIsOutput] * [biQty3] ), 0) AS [SumOutQty3],  
			ISNULL(SUM(  [r].[btIsInput] * [biBonusQnt] ), 0) AS [SumInBonusQty],  
			ISNULL(SUM(  [r].[btIsOutput] * [biBonusQnt] ), 0) AS [SumOutBonusQty],  
			ISNULL(SUM([r].[btIsInput] * ([SumPrice] + (([SumItemLCExtra] - [SumItemLCDisc]) * [biQty]) ) ), 0) AS [SumInPrice], 
			ISNULL(SUM( [r].[btIsInput] * [SumVat] ), 0) AS [SumInVat],   
			ISNULL(SUM([r].[btIsOutput] * ([SumPrice] + (([SumItemLCExtra] - [SumItemLCDisc]) * [biQty]) ) ), 0) AS [SumOutPrice], 
			ISNULL(SUM(  [r].[btIsOutput] * [SumVat]), 0) AS [SumOutVat]	,  
			ISNULL(SUM( [r].[btIsInput] * [SumTotalExtra]), 0) AS [SumInExtra],  
			ISNULL(SUM( [r].[btIsOutput] * [SumTotalExtra]), 0) AS [SumOutExtra],  
			ISNULL(SUM( [r].[btIsInput] * [SumTotalDisc] ), 0) AS [SumInDisc]	,  
			ISNULL(SUM( [r].[btIsOutput] * [SumTotalDisc] ), 0) AS [SumOutDisc],  
			ISNULL(SUM( [r].[btIsInput] * [SumItemDisc] ), 0) AS [SumInDiscVal],  
			ISNULL(SUM( [r].[btIsOutput] *[SumItemDisc] ), 0) AS [SumOutDiscVal],
			ISNULL(SUM( [r].[btIsInput] * [SumItemLCDisc] * [biQty] ), 0) AS [SumInLCDisc],  
			ISNULL(SUM( [SumItemLCDisc] ) * SUM( [r].[btIsOutput] * [biQty] ), 0) AS [SumOutLCDisc],
			ISNULL(SUM( [r].[btIsInput] * [SumItemLCExtra] * [biQty] ), 0) AS [SumInLCExtra],  
			ISNULL(SUM( [SumItemLCExtra] ) * SUM( [r].[btIsOutput] * [biQty] ), 0) AS [SumOutLCExtra],  
			CASE ' + CAST(@ShowClass AS NVARCHAR(2)) + ' WHEN 1 THEN [Class] ELSE '''' END Class'

			
			
		SET @Sql = @Sql + ', CASE '+ CAST(@ShowExpireDate AS NVARCHAR(2)) + ' WHEN 1 THEN [ExpireDate] ELSE ''1/1/1980'' END  AS [ExpireDate]'
		SET @SQL= @Sql+' ,ISNULL(dbo.fnGetOutbalanceAveragePrice(BiMatPtr,' + [dbo].[fnDateString](@EndDate) + ') /dbo.fnGetCurVal('''+CAST(@CurrencyGUID AS NVARCHAR(MAX))+''','+[dbo].[fnDateString](@EndDate)+'), 0)  as OutbalanceAveragePrice'
		SET @Sql = @Sql + ', 0 AS [PriceValue] FROM [#Result] [r] LEFT JOIN vwbt bt ON [r].[buType] = [bt].[btGUID] ' 
		SET @Sql = @Sql + 'WHERE 	[r].[UserSecurity] >= [r].[Security]  AND ([btSortNum] <> 0 OR [btSortNum] IS NULL) 
		GROUP BY 
			[BiMatPtr], [MtName], [MtCode], [MtLatinName], [mtDefaultUnit],[MtUnity], 
			[mtUnit2], 	[mtUnit3], [mtDefUnitName], [GroupGuid], [IsBalMat]' 
		SET @Sql = @Sql + ', 
			CASE '+ CAST(@ShowExpireDate AS NVARCHAR(2)) + ' WHEN 1 THEN [ExpireDate] ELSE ''1/1/1980'' END'
		SET @Sql = @Sql + ',
			CASE ' + CAST(@ShowClass AS NVARCHAR(2)) + ' WHEN 1 THEN [Class] ELSE '''' END'
		------------------------------------------------------------------------------------------------------ 
		SET @Sql = @Sql + ',CASE [IsMat] WHEN 1 THEN 1 ELSE 0 END '
		IF (@shwGrp > 0) 
		BEGIN 
			SET @Sql = @Sql + ',[Path]'	 
			SET @Sql = @Sql + 'ORDER BY [Path],[IsMat],[MtName]' 	 
		END	 
	
	INSERT INTO [#MainResult] 
			([MtNumber], [MtName], [MtCode], [MtLatinName], [mtUnity], [mtUnit2], [mtUnit3], [mtDefUnitName]
			,[mtDefaultUnit], [ParentGuid],[IsBalMat], [IsMat]
			,[SumInQty], [SumOutQty], [SumInQty2],[SumOutQty2],[SumInQty3]				
			,[SumOutQty3], [SumInBonusQty], [SumOutBonusQty], [SumInPrice], [SumInVat]
			,[SumOutPrice], [SumOutVat], [SumInExtra]			
			,[SumOutExtra], [SumInDisc], [SumOutDisc], [SumInDiscVal]
			,[SumOutDiscVal], [SumInLCDisc],
			[SumOutLCDisc],[SumInLCExtra],[SumOutLCExtra],
			[Class], [ExpireDate], [OutbalanceAveragePrice], [PriceValue])
	EXEC (@Sql) 
	
	IF (@IsCalledByWeb = 1) OR (@PriceType<> -1) -- @PriceType <> 'BILL PRICE = -1'
	BEGIN
		UPDATE [#MainResult]
			SET [PriceValue] = [Value]
		FROM [#MainResult] AS MainRes
		INNER JOIN [#Prices] AS Prices ON Prices.[mtNumber] = MainRes.[MtNumber]
	END
	UPDATE [#MainResult]
			SET [MtGuid] = (CASE [IsMat] WHEN 1 THEN [MtNumber] ELSE 0x00 END),
				[GroupGuid] = (CASE [IsMat] WHEN 0 THEN [MtNumber] ELSE 0x00 END),
				[MtLatinName] = (CASE [MtLatinName] WHEN '' THEN [MtName] ELSE [MtLatinName] END)
	FROM [#MainResult] AS MainRes
	SELECT * FROM [#MainResult]
	SELECT * FROM [#Total] 
	
	SELECT * FROM [#SecViol]		
	/*
prcConnections_add2 '„œÌ—'
EXECUTE [prcCallCalcInOutMtMove] '1/1/2015 0:0:0.0', '6/3/2015 23:59:38.194', '6709046f-61b2-43e7-8093-1102ebcf6be4', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 0, 0, N'', N'', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '3b79ab4a-ae8c-4002-a3f9-c6265d55e41e', 1.000000, -1, 3, '00000000-0000-0000-0000-000000000000', 1, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, '00000000-0000-0000-0000-000000000000', N'', 0, 0, -1, 120, 1.000000, -1.000000
*/

############################################################
#END