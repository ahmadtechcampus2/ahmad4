###############################################################################
CREATE PROCEDURE RepDayBill
	@IsCalledByWeb		BIT,
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@SrcTypesGUID		[UNIQUEIDENTIFIER], 
	@PostedValue 		[INT], -- 0, 1 , -1 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text 
	@NotesNotContain 	[NVARCHAR](256), -- NULL or Not Contain 
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@AccGUID 			[UNIQUEIDENTIFIER], 
	@CurrencyGUID 		[UNIQUEIDENTIFIER], 
	@CurrencyVal 		[FLOAT], 
	@CustGUID 			[UNIQUEIDENTIFIER], 
	@StoreGUID 			[UNIQUEIDENTIFIER], 
	@SecLevel			[INT] = 0, 
	@PayType			[INT] = -1, 
	@ChkTypeGuid		[UNIQUEIDENTIFIER] = 0X0, 
	@ShowBillWithEntry	[INT] = -1, 
	@RID				[FLOAT] = 0, 
	@ShowChecked		[INT] = 0, 
	@ItemChecked		[INT] = -1, 
	@CheckForUsers		[INT] = 0, 
	@BiStart			[INT] = 0, 
	@BiEnd				[INT] = 0, 
	@CurrentUserGuid	[UNIQUEIDENTIFIER] = 0X00, 
	@CheckDetails		[BIT] = 0, 
	@ShowFromVal		[BIT] = 0, 
	@FromVal			[FLOAT] = 0, 
	@ToVal				[FLOAT] = 0, 
	@CustCondGuid		[UNIQUEIDENTIFIER] = 0X00, 
	@BillCond			[UNIQUEIDENTIFIER] = 0X00, 
	@IncludeMainCost	BIT = 0	,
	@DetBonusDisc		BIT = 0	,
	@StDetails			BIT = 0
			  
AS 
	SET NOCOUNT ON  

	DECLARE @SortAffectCostType BIT 
	SET @SortAffectCostType = 0
	IF @PostedValue = 1
		SET @SortAffectCostType = 1

	CREATE TABLE [#SecViol]( Type [INT], Cnt [INTEGER])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
		[UnPostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CustTbl2] ([CustGUID] [UNIQUEIDENTIFIER], [Security] INT , [CustomerName] NVARCHAR(250), [cuLatinName] NVARCHAR(250))
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList3] 	@SrcTypesguid, NULL, @SortAffectCostType 
	INSERT INTO [#CustTbl]		 EXEC [prcGetCustsList] 		@CustGUID, @AccGUID,@CustCondGuid 
	INSERT INTO [#CustTbl2] SELECT [CustGUID] , [c].[Security],[CustomerName],[LatinName] AS [cuLatinName] FROM [#CustTbl] AS [c] INNER JOIN [cu000] AS [cu] ON [cu].[Guid] =  [CustGUID] 
	IF ( @CustGUID = 0X00) AND (@AccGUID = 0X00) AND (@CustCondGuid = 0X00) 
		INSERT INTO [#CustTbl2]  VALUES (0X00,0,'','') 
	CREATE CLUSTERED INDEX dbbtInd   ON [#BillsTypesTbl]( [TypeGuid]) 
	CREATE CLUSTERED INDEX dbCustInd   ON [#CustTbl2]([CustGUID]) 
	CREATE TABLE #BU([BuGuid] [UNIQUEIDENTIFIER]) 
	CREATE TABLE [#Result](  
		[BuType]				[UNIQUEIDENTIFIER],  
		[BuNumber]				[UNIQUEIDENTIFIER],  
		[buNum]					[INT],  
		[BuSortFlag]			[INT],  
		[BuCostPtr]				[UNIQUEIDENTIFIER],  
		[Security]				[INT],  
		[BuDate]				[DATETIME],  
		[BuNotes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI,  
		[BuVendor]				[INT],  
		[BuSalesManPtr]			[INT],  
		[BuCust_Name]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[FixedBuTotal]			[FLOAT],  
		[FixedBuFirstPay]		[FLOAT],
		[FixedBuTotalDisc]		[FLOAT],  
		[FixedBuTotalExtra]		[FLOAT],  
		[FixedbuItemsDisc]		[FLOAT],  
		FixedBuTotalSalesTax	float,
		[BuBonusDisc]			[FLOAT],  
		[BuStorePtr]			[UNIQUEIDENTIFIER],  
		[BuPayType]				[INT],  
		[BuCustPtr]				[UNIQUEIDENTIFIER],  
		[BuCustAcc]				[UNIQUEIDENTIFIER],  
		[BiStorePtr]			[UNIQUEIDENTIFIER],  
		[BiCurrencyPtr]			[UNIQUEIDENTIFIER],  
		[BiCurrencyVal]			[FLOAT],  
		[BiQtyTot]				[FLOAT],  
		[BiPriceTotOld]			[FLOAT],  
		[BiDiscountTot]			[FLOAT],  
		[BiBonusDisctTot]		[FLOAT],  
		[BiExtraTot]			[FLOAT],  
		[BiVatTot]				[FLOAT],  
		[BiBonusQntTot]			[FLOAT],  
		[UserSecurity] 			[INT],  
		[UserReadPriceSecurity]	[INT],  
		[buFormatedNumber]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buLatinFormatedNumber]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[cuLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buCheckTypeGUID]		[UNIQUEIDENTIFIER],  
		[Checked]				[INT] DEFAULT 0,  
		[TotalQty]				[FLOAT],  
		[Branch]				[UNIQUEIDENTIFIER],  
		[Vendor]				FLOAT,  
		[SalesMan]				FLOAT,  
		[buTextFld1]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buTextFld2]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buTextFld3]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buTextFld4]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[cuSecurity]			[INT],
		[BuIsPosted]			INT,
		[BuIsEntryGen]			INT,
		[BtIsInput]				INT,
		[ceIsposted]			INT,
		[FixedBuTotalVat] 		[FLOAT],  
		[BuCurrencyPtr]			[UNIQUEIDENTIFIER],  
		[BuCurrencyVal]			[FLOAT], 
		VS						BIT, 
		[CurrFactor]			FLOAT,
		[PriorityNum]			[INTEGER],
		[SamePriorityOrder]		INT, 
		[SortNumber]			INT	
		) 
	
	DECLARE @IsDetails BIT 
	SET @IsDetails = 0
	
	IF  @StoreGUID <> 0x0 
		OR @CostGUID <> 0x0 
		OR ISNULL(@NotesContain,'') <> ''  
		OR ISNULL(@NotesNotContain,'') <> '' 
		OR @BillCond <> 0X00 
	BEGIN 
		EXEC [RepDayBill_BuBi] @StartDate, @EndDate, @SrcTypesGUID, @PostedValue,@NotesContain, @NotesNotContain, @CostGUID,	@AccGUID, @CurrencyGUID, @CurrencyVal, @CustGUID, @StoreGUID,@SecLevel,@PayType,@ChkTypeGuid,@ShowBillWithEntry,@RID,@ShowChecked,@ItemChecked,@CheckForUsers,@BiStart,@BiEnd,@CurrentUserGuid,@CheckDetails,@ShowFromVal,@FromVal,@ToVal,@BillCond,@IncludeMainCost
		SET @IsDetails = 1
	END 
	ELSE 
	BEGIN 
		EXEC [RepDayBill_Bu] @StartDate, @EndDate, @SrcTypesGUID,@PostedValue, @AccGUID, @CurrencyGUID, @CurrencyVal, @CustGUID,@SecLevel,@PayType,@ChkTypeGuid,@ShowBillWithEntry,@RID,@ShowChecked,@ItemChecked,@CheckForUsers,@BiStart,@BiEnd,@CurrentUserGuid,@CheckDetails,@ShowFromVal,@FromVal,@ToVal, @IncludeMainCost
	END 
		
	UPDATE r
	SET 
		[PriorityNum] = b.[PriorityNum],
		[SamePriorityOrder] = b.[SamePriorityOrder],
		[SortNumber] = b.[SortNumber]
	FROM 
		[#Result] r
		INNER JOIN [#BillsTypesTbl] b ON r.BuType = b.[TypeGuid]

	EXEC [prcCheckSecurity]  
	IF (@ShowChecked > 0)  
	BEGIN  
		DECLARE @UserGuid [UNIQUEIDENTIFIER]   
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()   
		  
		UPDATE [Res]  
		SET    
			[Checked] = 1   
			--UserCheckGuid = RCH.UserGuid   
		FROM    
			[#Result] AS [Res] INNER JOIN [RCH000] As [RCH]   
			ON [Res].[BuNumber] = [RCH].[ObjGUID]  
		WHERE    
			@rid  = [RCH].[Type]  
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGuid))  
		  
		IF( @ItemChecked = 0)    
			DELETE FROM [#Result] WHERE [Checked] <> 1   
		ELSE IF( @ItemChecked = 1)    
			DELETE FROM [#Result] WHERE [Checked] = 1   
	END  

	IF @IsDetails = 0
	BEGIN 
		UPDATE [r] SET [TotalQty] = [q].[Qty]  
		FROM 
			[#Result] [r] 
			INNER JOIN (SELECT SUM(([bi].[Qty] + bonusqnt)/CASE [bi].[Unity] WHEN 1 THEN 1 WHEN 2 THEN CASE mtunit2Fact WHEN 0 THEN 1 ELSE mtunit2Fact END ELSE  CASE mtunit3Fact WHEN 0 THEN 1 ELSE mtunit3Fact END END) AS [Qty],[ParentGuid]  
			FROM [bi000] [bi] INNER JOIN [VWMT] mt ON mtGuid = bi.MatGuid GROUP BY [ParentGuid]) q ON q.[ParentGuid] = r.[buNumber]  
	END ELSE 
		CREATE CLUSTERED INDEX rtbind ON [#Result]([buDate], [BuSortFlag], [BuNum], [BuNumber])  
	
	SELECT  
		[r].[BuType],
		[r].[BuNumber],
		[r].[BuNum],  
		[r].[BuSortFlag],  
		[r].[BuCostPtr],  
		[r].[Security],  
		[r].[BuDate],
		[r].[BuNotes],  
		[r].[BuVendor],
		[r].[BuSalesManPtr],  
		[r].[BuCust_Name],  
		[r].[FixedBuTotal] , 
		[r].[FixedBuFirstPay], 
		[r].[FixedBuTotalDisc],  
		[r].[FixedBuTotalExtra],  
		[r].[FixedBuTotalVat],  
		[r].[FixedbuItemsDisc],  
		[r].FixedBuTotalSalesTax,
		[r].[BuBonusDisc],  
		[r].[BuStorePtr],  
		[r].[BuPayType],  
		[r].[BuCustPtr], 
		[r].[BuCustAcc],  
		[r].[BiStorePtr],  
		[r].[BiCurrencyPtr],  
		[r].[BiCurrencyVal],  
		[r].[BiQtyTot],  
		[r].[BiPriceTotOld],  
		[r].[BiDiscountTot],  
		[r].[BiBonusDisctTot],  
		[r].[BiExtraTot],  
		[r].[BiVatTot],  
		[r].[BiBonusQntTot],		
		[r].[BuCurrencyPtr],  
		[r].[BuCurrencyVal],  
		[r].[UserSecurity],  
		[r].[UserReadPriceSecurity],  
		[r].[buFormatedNumber],  
		[r].[buLatinFormatedNumber],  
		[r].[buCheckTypeGUID] AS [CheckTypeGUID],  
		[st].[stName],  
		[r].[cuLatinName] ,  
		[r].[Checked],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],
		[r].[BuIsPosted],[r].[BuIsEntryGen], [r].[BtIsInput],
		ISNULL([r].[ceIsposted], 0) AS [ceIsposted]
		-------------------------------------------------------------------------------------------------------  
		,[TotalQty]
 		,[co].[Code] AS [CostCode],[co].[Name] AS [CostName],[co].[LatinName] AS [CostLatinName]
		,[dbo].[fnGetDueDate](ISNULL([ptTerm],0),ISNULL([ptDays],0),[buDate]) AS [dueDate]
		,[br].[Name] AS brName,[br].[LatinName] AS [BRLatinName]
		
		,ISNULL((CASE @StDetails WHEN 1 THEN [BiPriceTotOld] ELSE [FixedBuTotal] END), 0) AS CalcPrice
		,[FixedBuTotalExtra] * (CASE [FixedBuTotal] WHEN 0 THEN 0 ELSE (CASE @StDetails WHEN 1 THEN [BiPriceTotOld] ELSE [FixedBuTotal] END)/[FixedBuTotal] END) AS CalcExtraRatio
		,([FixedBuTotalDisc] -  [FixedbuItemsDisc]) * (CASE [FixedBuTotal] WHEN 0 THEN 0 ELSE (CASE @StDetails WHEN 1 THEN [BiPriceTotOld] ELSE [FixedBuTotal] END)/[FixedBuTotal] END) AS CalcDiscRatio
		,(CASE @DetBonusDisc WHEN 0 THEN (CASE @StDetails WHEN 1 THEN BiBonusDisctTot ELSE BuBonusDisc END) ELSE 0 END )AS CalcBonusDisc
		,ISNULL((CASE @StDetails WHEN 1 THEN BiVatTot ELSE FixedBuTotalVat END), 0)AS CalcVat
		, ISNULL(FixedBuTotalSalesTax, 0) AS CalcSalesTax
		,ISNULL((CASE @StDetails WHEN 1 THEN ([BiExtraTot] + /*CalcExtraRatio*/ [FixedBuTotalExtra] * (CASE [FixedBuTotal] WHEN 0 THEN 0 ELSE (CASE @StDetails WHEN 1 THEN [BiPriceTotOld] ELSE [FixedBuTotal] END)/[FixedBuTotal] END)) 
							ELSE [FixedBuTotalExtra] END), 0) AS CalcExtraVal
		
		,ISNULL((CASE @StDetails WHEN 1 
						THEN ([BiDiscountTot]+ /*CalcDiscRatio*/ ([FixedBuTotalDisc] -  [FixedbuItemsDisc]) * (CASE [FixedBuTotal] WHEN 0 THEN 0 ELSE  [BiPriceTotOld]/[FixedBuTotal] END)) 
						 ELSE ([FixedBuTotalDisc]) END) - 
						(CASE @DetBonusDisc WHEN 1 THEN /*[CalcBonusDisc*/  (CASE @DetBonusDisc WHEN 0 THEN  BiBonusDisctTot ELSE 0 END ) ELSE 0 END )
						, 0) AS CalcDiscVal			
		
	FROM  
		[#Result] AS [r] 
		INNER JOIN [vwst] AS [st] ON [r].[BuStorePtr] = [st].[stGUID]
		LEFT JOIN [vwpt] AS [pt] ON [r].[BuNumber] = [ptRefGuid]
		LEFT JOIN  [co000] AS [co] ON [co].[Guid] = [r].[BuCostPtr]
		LEFT JOIN  [BR000] AS [br] ON [br].[Guid] = [r].[Branch]
	WHERE  
		[UserSecurity] >= [r].[Security] 	 
	 ORDER BY 
		[buDate], [PriorityNum], [SortNumber], /*[BuSortFlag],*/ [BuNum],/*[BuNumber],*/[SamePriorityOrder]
	
	IF (@CheckDetails > 0) OR (@IsCalledByWeb = 1)
	BEGIN 
		SELECT DISTINCT 
			[r].[buCheckTypeGUID] AS [CheckTypeGUID],
			[nt].[Name] AS [CheckTypeName],
			[nt].[LatinName] AS [CheckTypeLatinName]
		FROM 
			[#Result] r 
			INNER JOIN nt000 nt ON nt.GUID = r.[buCheckTypeGUID]
	END 
	
	IF (@IsCalledByWeb = 1)
	BEGIN 
		SELECT 
			bu.GUID, 
			bt.Name AS btName, 
			bt.LatinName AS btLatinName, 
			bt.billtype,
			bu.Notes As buNotes,
			bu.TextFld1, 
			bu.TextFld2, 
			bu.TextFld3, 
			bu.TextFld4, 
			bu.FirstPay, 
			my.Name AS myName, 
			my.LatinName AS myLatinName, 
			bu.CurrencyVal, 
			bu.PayType, 
			bu.Vendor, 
			bu.SalesManPtr,
			br.Name AS brName, 
			br.LatinName AS brLatinName,
			co.Name AS coName, 
			co.LatinName AS coLatinName,
			st.Name AS stName, 
			st.LatinName AS stLatinName,
			pt.DueDate
		FROM 
			bu000 bu 
			INNER JOIN [#Result] r ON r.[BuNumber] = bu.GUID
			INNER JOIN bt000 bt ON bt.[GUID] = bu.TypeGUID
			INNER JOIN my000 my ON my.[GUID] = bu.CurrencyGUID
			LEFT JOIN br000 br ON br.[GUID] = bu.Branch
			LEFT JOIN st000 st ON st.[GUID] = bu.StoreGUID
			LEFT JOIN co000 co ON co.[GUID] = bu.CostGuid
			LEFT JOIN pt000 pt ON pt.RefGUID = bu.GUID
	END 
	
	SELECT * FROM [#SecViol] 
###############################################################################
CREATE PROCEDURE RepDayBill_BuBi
	@StartDate 				[DATETIME],  
	@EndDate 				[DATETIME],  
	@SrcTypesguid			[UNIQUEIDENTIFIER],  
	@PostedValue 			[INT], -- 0, 1 , -1  
	@NotesContain 			[NVARCHAR](256),-- NULL or Contain Text  
	@NotesNotContain 		[NVARCHAR](256), -- NULL or Not Contain  
	@CostGUID 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs  
	@AccGUID				[UNIQUEIDENTIFIER],  
	@CurrencyGUID 			[UNIQUEIDENTIFIER],  
	@CurrencyVal 			[FLOAT],  
	@CustGUID 				[UNIQUEIDENTIFIER],  
	@StoreGUID 				[UNIQUEIDENTIFIER],  
	@SecLevel				[INT] = 0,  
	@PayType				[INT] = -1,  
	@ChkTypeGuid			[UNIQUEIDENTIFIER] = 0X0,  
	@ShowBillWithEntry		[INT] = 0,  
	@RID					[FLOAT] = 0,  
	@ShowChecked			[INT] = 0,  
	@ItemChecked			[INT] = -1,  
	@CheckForUsers			[INT] = 0,  
	@BiStart				[INT] = 0,  
	@BiEnd					[INT] = 0,  
	@CurrentUserGuid		[UNIQUEIDENTIFIER] = 0X00,  
	@CheckDetails			[BIT] = 0,  
	@ShowFromVal			[BIT] = 0,  
	@FromVal				[FLOAT] = 0,  
	@ToVal					[FLOAT] = 0,   
	@BillCond				[UNIQUEIDENTIFIER] = 0X00,  
	@IncludeMainCost		BIT = 0				    
AS  
	SET NOCOUNT ON  
	DECLARE @Criteria NVARCHAR(2000)  
	SET @Criteria = '' 
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])

	--CREATE TABLE [#EntryTbl1]([BillGuid] [UNIQUEIDENTIFIER], EntryBill int, posted int)  
	--CREATE TABLE [#EntryTbl]([BillGuid] [UNIQUEIDENTIFIER])  
	
	--Filling temporary tables  
	DECLARE @s [NVARCHAR](max)  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID  
	IF @IncludeMainCost = 0  
		INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID  
	ELSE  
		INSERT INTO
			[#CostTbl]
		SELECT
			coGuid,coSecurity
		FROM
			vwco 
		WHERE
			((coGuid = @CostGUID) AND (ISNULL(@CostGUID, 0x0) <> 0x0)) OR ((ISNULL(@CostGUID, 0x0) = 0x0) AND (coParent = 0x0))  

	IF (@CostGUID = 0X00)  
		INSERT INTO [#CostTbl] VALUES (0X00,0)  
	CREATE CLUSTERED INDEX  dbstInd   ON [#StoreTbl]([StoreGUID])  
	  
	IF @NotesContain IS NULL  
		SET @NotesContain = ''  
	IF @NotesNotContain IS NULL  
		SET @NotesNotContain = ''  
	--IF (@ShowBillWithEntry <> -1)  
	--	INSERT INTO [#EntryTbl]	  
	--	SELECT 
	--		[erParentGuid]   
	--	FROM 
	--		[VWER] AS [er]   
	--		INNER JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   
	--		INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid] = [er].[erParentGuid]  
	--	WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate  

	--INSERT INTO [#EntryTbl1]	
	--	SELECT bu.buGUID,--0,0 
	--			CASE  (select [BillGuid] from [#EntryTbl] where [BillGuid] =  bu.buGUID) when  bu.buGUID then 0 ELSE 1 END,
	--			CASE bu.buisposted  when 1 then 1 else 0 END
	--		FROM [Vwbu] bu
	--		WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate  

	SET @s = 'INSERT INTO [#Result]  
		SELECT   
			[r].[BuType],  
			[r].[BuGUID],  
			[r].[BuNumber],  
			[r].[BuSortFlag],  
			[r].[BuCostPtr],  
			[r].[BuSecurity],  
			dbo.fnGetDateFromTime([r].[BuDate]),  
			[r].[BuNotes],  
			[r].[BuVendor],  
			[r].[BuSalesManPtr],  
			CASE [CustGUID] WHEN 0X00 THEN [buCust_Name] ELSE [cu].[CustomerName] END,  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal] ELSE 0 END AS [FixedBuTotal],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuFirstPay] ELSE 0 END AS [FixedBuFirstPay],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalDisc]  ELSE 0 END AS [FixedBuTotalDisc],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalExtra] -[r].[FixedbuItemExtra]  ELSE 0 END AS [FixedBuTotalExtra],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbuItemsDisc] + ([r].[buBonusDisc] * [FixedCurrencyFactor]) ELSE 0 END AS [FixedbuItemsDisc],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalSalesTax] * [FixedCurrencyFactor] ELSE 0 END AS [FixedBuTotalSalesTax],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[BuBonusDisc] ELSE 0 END AS [BuBonusDisc],  
			[r].[BuStorePtr],  
			[r].[BuPayType],  
			[r].[BuCustPtr],  
			[r].[BuCustAcc],  
			[r].[BiStorePtr],  
			[r].[BiCurrencyPtr],  
			[r].[BiCurrencyVal],  
			SUM( [r].[BiQty]) AS [BiQtyTot],  
			-- CASE WHEN ReadPriceSec >= BuSecurity THEN r.FixedBuTotal ELSE 0 END AS FixedBuTotal,  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN SUM( [r].[FixedBiPrice]/CASE [biUnity] when 1 then 1 when 2 then mtunit2fact else mtunit3fact end * [r].[BiQty] ) ELSE 0 END   AS [BiPriceTotOld],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN SUM( [r].[FixedBiDiscount] + [r].[FixedbiBonusDisc]) ELSE 0 END AS [BiDiscountTot],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN SUM( [r].[FixedBiDiscount] ) ELSE 0 END,  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  SUM([r].[FixedBiExtra])  ELSE 0 END AS [BiExtraTot],  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  SUM([r].[FixedBiVat])  ELSE 0 END,  
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN SUM( [r].[BiBonusQnt]) ELSE 0 END AS [BiBonusQntTot],  
			CASE [r].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [bt].[UnPostedSecurity] END,  
			[bt].[UserReadPriceSecurity],  
			[r].[buFormatedNumber],  
			[r].[buLatinFormatedNumber],  
			CASE [CustGUID] WHEN 0X00 THEN [buCust_Name] ELSE CASE [cu].[cuLatinName] WHEN '''' THEN [cu].[CustomerName] ELSE [cu].[cuLatinName] END END,  
			[r].[buCheckTypeGUID],  
			0,  
			SUM(([biQty] + [biBonusQnt])/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN CASE mtunit2Fact WHEN 0 THEN 1 ELSE mtunit2Fact END ELSE  CASE mtunit3Fact WHEN 0 THEN 1 ELSE mtunit3Fact END END),  
			[buBranch],[BuVendor], [BuSalesManPtr],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4], 
			[cu].Security,
			[r].[BuIsPosted],
			CASE ISNULL([ce].[ceGuid], 0x0) WHEN 0x0 THEN 0 ELSE 1 END,
			[r].[btIsInput],
			CASE ISNULL([ce].[ceIsposted], 0) WHEN 0 THEN 0 ELSE 1 END,
			0,		-- [FixedBuTotalVat]
			0x0,	-- [BuCurrencyPtr]
			1,		-- [BuCurrencyVal]
			0,		--	VS						
			0,		-- [CurrFactor]
			0,		-- [PriorityNum]
			0, 0
	FROM										   	  
		(([fnExtended_bi_Fixed](''' + CAST(@CurrencyGUID AS NVARCHAR(36)) + ''') AS [r]  
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid])  
		INNER JOIN [#StoreTbl] AS [st] ON [BiStorePtr] = [StoreGUID])  
		INNER JOIN [#CustTbl2] AS [cu] ON  [BuCustPtr] = [CustGUID]   
		INNER JOIN [#CostTbl] AS [co] ON [BuCostPtr] = [co].[CostGUID] 
		LEFT JOIN [VWER] AS [er] ON er.erParentGUID = r.[BuGUID]
		LEFT JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   

		' 
------------------------------------------------------------------------------------------------------- 
	-- to check existing Custom Filed and extracting Condition Criteria 
------------------------------------------------------------------------------------------------------- 
	DECLARE @HaveCFldCondition int 
	SET @HaveCFldCondition = 0 
	IF @BillCond <> 0X00  
	BEGIN  
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyGUID)  
		IF @Criteria <> ''  
		BEGIN  
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields  
			BEGIN  
				SET @HaveCFldCondition = 1  
				SET @Criteria = REPLACE(@Criteria,'<<>>','')   
			 
			END  
			SET @Criteria = '(' + @Criteria + ')'  
		END  
	END 
	ELSE  
		SET @Criteria = ''  
	 

------------------------------------------------------------------------------------------------------- 
-- Inserting Condition Of Custom Fields  
--------------------------------------------------------------------------------------------------------  
	IF (@HaveCFldCondition =  1) 
	BEGIN  
		DECLARE @CF_Table1 NVARCHAR(255)  
		SET @CF_Table1 = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000') 	 
		SET @s = @s + ' INNER JOIN ' + @CF_Table1 + ' ON [r].[buGuid] = ' + @CF_Table1 + '.Orginal_Guid '  
	END  
------------------------------------------------------------------------------------------------------- 
	SET @s = @s + 
	' WHERE  
		[budate] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) 
		--IF 	@PostedValue > -1  
		--	SET @s = @s + ' AND [BuIsPosted] = ' + CAST (@PostedValue AS NVARCHAR(2))  
		IF @NotesContain <> ''  
			SET @s = @s + ' AND (([BuNotes] LIKE ''%' + @NotesContain + '%'') OR ( [BiNotes] LIKE ''%' + @NotesContain + '%''))'  
		IF @NotesNotContain <> ''  
			SET @s = @s + ' AND (([BuNotes] NOT LIKE ''%' + @NotesNotContain + '%'') AND ([BiNotes] NOT LIKE ''%' + @NotesNotContain + '%''))'  
		IF @SecLevel > 0  
			SET @s = @s + ' AND [r].[BuSecurity] = '+ CAST (@SecLevel AS NVARCHAR(2) )   
		IF @PayType <> -1  
			SET @s = @s + ' AND [r].[BuPayType] = '+ CAST (@PayType AS NVARCHAR(2))  
		IF @ChkTypeGuid <> 0X00  
			SET @s = @s + ' AND [r].[BuCheckTypeGuid] = '''+ CAST (@ChkTypeGuid AS NVARCHAR(36)) +''''  
		IF  NOT(@BiStart = 0 AND @BiEnd = 0)  
			SET @s = @s + ' AND [r].[BuNumber] BETWEEN ' + CAST(@BiStart AS NVARCHAR(20)) + ' AND ' + CAST(@BiEnd AS NVARCHAR(20))   
		IF @CurrentUserGuid <> 0X00  
			SET @s = @s + ' AND  [buUserGuid] = '''+ CAST (@CurrentUserGuid AS NVARCHAR(36)) +''''  
		IF @PostedValue > -1
			 SET @s = @s + ' AND r.[buIsposted] = ' + CAST (@PostedValue AS NVARCHAR(2))

		IF @Criteria <> ''  
			SET @Criteria = ' AND (' + @Criteria + ')'  
		SET @s = @s + @Criteria  
	SET @s = @s + ' GROUP BY  
		[BuType],[BuGUID],[r].[BuNumber],[BuSortFlag],  
		[BuSortFlag],[BuIsPosted],[btIsInput],[BuCostPtr],[BuSecurity],dbo.fnGetDateFromTime([BuDate]),[BuNotes],[BuVendor],  
		[BuSalesManPtr],[CustomerName],[FixedBuTotal], ISNULL([ce].[ceGuid], 0x0), ISNULL([ce].[ceIsposted], 0), 
		[FixedBuTotalDisc] ,[FixedBuTotalExtra],[r].[FixedbuItemExtra] ,[FixedbuItemsDisc], FixedBuTotalSalesTax, [BuBonusDisc],  
		[BuStorePtr],[BuPayType],[BuCustPtr],[BuCustAcc],  
		[BiCurrencyPtr],[BiCurrencyVal],[BiStorePtr],[bt].[UserSecurity],[bt].[UserReadPriceSecurity],  
		[r].[buFormatedNumber],	[cu].[cuLatinName],  
		[r].[buLatinFormatedNumber],[r].[buCheckTypeGUID],[r].[btVatSystem],[r].[FixedbuVat],  
		[bt].[UnPostedSecurity],[CustGUID],[buCust_Name],[buBranch],[r].[buBonusDisc],[FixedCurrencyFactor],[BuVendor], [BuSalesManPtr]  
		,[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4], [cu].Security, FixedBuFirstPay'  
	IF @ShowFromVal <> 0   
			SET @s = @s + char(13) +'  HAVING  CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal] ELSE 0 END BETWEEN ' + CAST(@FromVal AS NVARCHAR(20)) + ' AND ' +CAST(@ToVal AS NVARCHAR(20))   
	EXEC(@s)  

	IF @ShowBillWithEntry > -1 
		DELETE [#Result] WHERE [BuIsEntryGen] <> @ShowBillWithEntry

	IF (@ShowFromVal > 0)  
		INSERT INTO #BU SELECT [BuNumber] FROM [#Result]  
###############################################################################
CREATE PROCEDURE RepDayBill_Bu
	@StartDate 				[DATETIME],  
	@EndDate 				[DATETIME],  
	@SrcTypesGUID			[UNIQUEIDENTIFIER],  
	@PostedValue 			[INT], -- 0, 1 , -1  
	@AccGUID				[UNIQUEIDENTIFIER],  
	@CurrencyGUID 			[UNIQUEIDENTIFIER],  
	@CurrencyVal 			[FLOAT],  
	@CustGUID 				[UNIQUEIDENTIFIER],  
	@SecLevel				[INT] = 0,  
	@PayType				[INT] = -1,  
	@ChkTypeGuid			[UNIQUEIDENTIFIER] = 0X0,  
	@ShowBillWithEntry		[INT] = 0,  
	@RID					[FLOAT] = 0,  
	@ShowChecked			[INT] = 0,  
	@ItemChecked			[INT] = -1,  
	@CheckForUsers			[INT] = 0,  
	@BiStart				[INT] = 0,  
	@BiEnd					[INT] = 0,    
	@CurrentUserGuid		[UNIQUEIDENTIFIER] = 0X00,  
	@CheckDetails			[BIT] = 0,  
	@ShowFromVal			[BIT] = 0,  
	@FromVal				[FLOAT] = 0,  
	@ToVal					[FLOAT] = 0,
	@IncludeMainCost        [BIT] = 0
				  	  
AS  
	SET NOCOUNT ON  
	DECLARE @s [NVARCHAR](max)  
	-- Creating temporary tables  
	--CREATE TABLE [#EntryTbl]([BillGuid] [UNIQUEIDENTIFIER])
	--CREATE TABLE [#EntryTbl1]([BillGuid] [UNIQUEIDENTIFIER], EntryBill int, posted int)  
	CREATE TABLE [#CostTable] ([coGuid] [UNIQUEIDENTIFIER], [coSecurity] [int])
	--Filling temporary tables  
	--IF (@ShowBillWithEntry <> -1)  

		INSERT INTO #CostTable SELECT coGuid, coSecurity FROM vwco WHERE coParent = 0x0 

		INSERT INTO #CostTable SELECT 0x00, 0

	--	INSERT INTO [#EntryTbl]	  
	--			SELECT [erParentGuid]   
	--			FROM [VWER] AS [er]   
	--			INNER JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   
	--			INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid] = [er].[erParentGuid]  
	--			WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate
	
	--INSERT INTO [#EntryTbl1]	
	--	SELECT bu.buGUID,--0,0 
	--	CASE  (select [BillGuid] from [#EntryTbl] WHERE [BillGuid] =  bu.buGUID) WHEN  bu.buGUID THEN 0 ELSE 1 END,
	--	CASE bu.buisposted  WHEN 1 THEN 1 ELSE 0 END
	--		FROM [Vwbu] bu
	--		WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate  

	SET @s = 'INSERT INTO [#Result]  
	SELECT  
		[r].[BuType],  
		[r].[BuGuid],  
		[r].[buNumber],  
		[r].[BuSortFlag],  
		[r].[BuCostPtr],  
		[r].[BuSecurity],  
		dbo.fnGetDateFromTime([r].[BuDate]),  
		[r].[BuNotes],  
		[r].[BuVendor],  
		[r].[BuSalesManPtr],  
		CASE [CustGUID] WHEN 0X00 THEN [buCust_Name] ELSE [cu].[CustomerName] END,		
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal] ELSE 0 END AS [FixedBuTotal],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuFirstPay] ELSE 0 END AS [FixedBuFirstPay],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalDisc] ELSE 0 END AS [FixedBuTotalDisc],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  [r].[FixedBuTotalExtra]  ELSE 0 END AS [FixedBuTotalExtra],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbuItemsDisc] ELSE 0 END AS [FixedbuItemsDisc],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalSalesTax] ELSE 0 END AS [FixedBuTotalSalesTax],  
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[BuBonusDisc] * [FixedCurrencyFactor] ELSE 0 END AS [BuBonusDisc],  
		[r].[BuStorePtr],  
		[r].[BuPayType],  
		[r].[BuCustPtr],
		[r].[BuCustAcc], 
		0x0, 0x0, 1, 0, 0, 0, 0, 0, 0, 0, 
		CASE [r].[buIsposted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END ,  
		[bt].[UserReadPriceSecurity],  
		[r].[buFormatedNumber],  
		[r].[buLatinFormatedNumber],  
		CASE [CustGUID] WHEN 0X00 THEN [buCust_Name] ELSE CASE [cu].[cuLatinName] WHEN '''' THEN [cu].[CustomerName] ELSE [cu].[cuLatinName] END END,  
		[r].[buCheckTypeGUID],  
		0,0,[buBranch],[BuVendor], [BuSalesManPtr],
		[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4], 		
		[cu].[Security],
		[R].[BuIsPosted],
		CASE ISNULL([ce].[ceGuid], 0x0) WHEN 0x0 THEN 0 ELSE 1 END,
		[r].[btIsInput],
		CASE ISNULL([ce].[ceIsposted], 0) WHEN 0 THEN 0 ELSE 1 END,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  [r].[FixedBuVat]  ELSE 0 END,  
		[r].[BuCurrencyPtr],  
		[r].[BuCurrencyVal],  
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS,
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  [FixedCurrencyFactor] ELSE 0 END,
		0, 0, 0
	FROM  
		[fnBu_Fixed](''' + CAST (@CurrencyGUID AS NVARCHAR(36)) + ''') AS [r]  
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
		INNER JOIN [#CustTbl2] AS [cu] ON  [BuCustPtr] = [CustGUID]
		' + CASE @IncludeMainCost WHEN 1 THEN ' INNER JOIN
			#CostTable AS [CO] ON [CO].[coGuid] = [r].[BuCostPtr] ' ELSE '' END + ' 
		LEFT JOIN [VWER] AS [er] ON er.erParentGUID = r.[BuGUID]
		LEFT JOIN [vwCE] AS [ce] ON [er].[erEntryGuid] = [ce].[ceGuid]   
	WHERE  
		[budate] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)   
	IF @PostedValue > -1
			SET @s = @s + ' AND r.[buIsposted] = ' + CAST (@PostedValue AS NVARCHAR(2))
	IF @SecLevel > 0    
		SET @s = @s + ' AND [r].[BuSecurity] = ' + CAST (@SecLevel AS NVARCHAR(2))  
	IF @PayType <> -1  
		SET @s = @s + ' AND [r].[BuPayType] ='  + CAST (@PayType AS NVARCHAR(2))  
	IF @ChkTypeGuid <> 0X00  
		SET @s = @s + ' AND [r].[BuCheckTypeGuid] =''' + CAST(@ChkTypeGuid AS NVARCHAR(36)) + ''''  
	IF  NOT(@BiStart = 0 AND @BiEnd = 0)  
		SET @s = @s + ' AND [r].[BuNumber] BETWEEN ' + CAST(@BiStart AS NVARCHAR(20)) + ' AND ' + CAST(@BiEnd AS NVARCHAR(20))   
	IF  @CurrentUserGuid <> 0X00  
		SET @s = @s + ' AND [buUserGuid] = ''' + CAST(@CurrentUserGuid AS NVARCHAR(36)) +''' '  
	IF @ShowFromVal <> 0  
		SET @s = @s + 'AND CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal] + [r].[FixedBuTotalExtra] - [r].[FixedBuTotalDisc] +  [r].[FixedBuVat] * r.FixedCurrencyFactor + r.FixedBuTotalSalesTax ELSE 0 END BETWEEN ' + CAST(@FromVal AS NVARCHAR(20)) + ' AND ' +CAST(@ToVal AS NVARCHAR(20))   
	  
	EXEC(@S)  

	IF  @ShowBillWithEntry > -1 
		DELETE [#Result] WHERE [BuIsEntryGen] <> @ShowBillWithEntry
 
	IF (@ShowFromVal > 0)  
		INSERT INTO #BU SELECT [BuNumber] FROM [#Result] 
###############################################################################
CREATE PROCEDURE repDayBillQnt
	@StartDate 			[DATETIME],  
	@EndDate 			[DATETIME],  
	@SrcTypesGUID			[UNIQUEIDENTIFIER],  
	@PostedValue 			[INT], -- 0, 1 , -1  
	@NotesContain 			[NVARCHAR](256),  
	@NotesNotContain 		[NVARCHAR](256),  
	@CustGUID 			[UNIQUEIDENTIFIER],  
	@StoreGUID 			[UNIQUEIDENTIFIER],  
	@CostGUID 			[UNIQUEIDENTIFIER],  
	@AccGUID			[UNIQUEIDENTIFIER],  
	@SecLevel			[INT] = 0,  
	@PayType			[INT] = -1,  
	@ChkTypeGuid			[UNIQUEIDENTIFIER] = 0X0,  
	@ShowBillWithEntry		[INT] = 0,  
	@RID				[FLOAT] = 0,  
	@ItemChecked			[INT] = -1,  
	@CheckForUsers			[INT] = 0,  
	@BiStart			[INT] = 0,  
	@BiEnd				[INT] = 0,  
	@CurrentUserGuid		[UNIQUEIDENTIFIER] = 0X00,  
	@ShowFromVal			[BIT] = 0,  
	@BillCond			[UNIQUEIDENTIFIER] = 0X00,  
	@CurrencyGUID			[UNIQUEIDENTIFIER] = 0X00		  
AS  
	SET NOCOUNT ON  
	DECLARE @Sql NVARCHAR(max)  
	DECLARE @Criteria NVARCHAR(2000)  
	SET @Criteria = '' 
	CREATE TABLE [#CHKFLD]([Guid] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#EntryTbl]([BillGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#EntryTbl1]([BillGuid] [UNIQUEIDENTIFIER], EntryBill int, posted int)  
	--Filling temporary tables  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID  
	IF (@CostGUID = 0X00)  
		INSERT INTO [#CostTbl] VALUES (0X00,0)  
	IF @NotesContain IS NULL  
		SET @NotesContain = ''  
	IF @NotesNotContain IS NULL  
		SET @NotesNotContain = ''  
	--IF (@ShowBillWithEntry <> -1)  
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
				  
	IF (@ItemChecked <> -1)  
	BEGIN  
		DECLARE @UserGuid [UNIQUEIDENTIFIER]   
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()   
		  
		INSERT INTO [#CHKFLD]  
		SELECT [objGuid]  
		FROM    
			[RCH000] As [RCH]   
		WHERE    
			@rid  = [RCH].[Type]  
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGuid))  
	END  
	SET @Sql = '	SELECT  
			[BuType],  
			SUM( ([BiQty] + [biBonusQnt])/ ISNULL([mtDefUnitFact], 1)) AS [SumQty]  
		FROM  
			[dbo].[vwExtended_bi_address] AS [r]  
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
			INNER JOIN [#CostTbl] AS [co] ON [CostGUID] = [BiCostPtr]  
			INNER JOIN [#CustTbl2] AS [cu] ON  [BuCustPtr] = [CustGUID]  
			INNER JOIN [#StoreTbl] AS [st] ON [BiStorePtr] = [StoreGUID]  '  
	--IF (@ShowBillWithEntry = 0)  
		--SET @Sql = @Sql + ' INNER JOIN [#EntryTbl] AS [er] ON [er].[BillGuid] = [r].[buGuid] '  
------------------------------------------------------------------------------------------------------- 
	-- to check existing Custom Filed and extracting Condition Criteria 
------------------------------------------------------------------------------------------------------- 
	DECLARE @HaveCFldCondition int 
	SET @HaveCFldCondition = 0 
	IF @BillCond <> 0X00  
	BEGIN  
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyGUID)  
		IF @Criteria <> ''  
		BEGIN  
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields  
			BEGIN  
				SET @HaveCFldCondition = 1  
				SET @Criteria = REPLACE(@Criteria,'<<>>','')   
			 
			END  
			SET @Criteria = '(' + @Criteria + ')'  
		END  
		ELSE  
		BEGIN 
			SET @Criteria = ''  
		END 
	END 
	 
------------------------------------------------------------------------------------------------------- 
-- Inserting Condition Of Custom Fields  
--------------------------------------------------------------------------------------------------------  
	IF (@HaveCFldCondition =  1) 
	BEGIN  
		DECLARE @CF_Table1 NVARCHAR(255)  
		SET @CF_Table1 = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000') 	 
		SET @Sql = @Sql + ' INNER JOIN ' + @CF_Table1 + ' ON [r].[buGuid] = ' + @CF_Table1 + '.Orginal_Guid '  
	END  
------------------------------------------------------------------------------------------------------- 
	SET @Sql = @Sql + 'WHERE [BuDate] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)   
	IF 	@PostedValue > -1  
		SET @Sql = @Sql + ' AND [BuIsPosted] = ' + CAST (@PostedValue AS NVARCHAR(2))  
	IF (@NotesContain <> '')  
		SET @Sql = @Sql + ' AND (([BuNotes] LIKE ''%' + @NotesContain + '%'') OR ( [BiNotes] LIKE ''%' + @NotesContain + '%''))'  
	IF @NotesNotContain<> ''  
		SET @Sql = @Sql + ' AND (([BuNotes] NOT LIKE ''%' + @NotesNotContain + '%'') AND ([BiNotes] NOT LIKE ''%'+ @NotesNotContain + '%'')))'  
	IF @SecLevel > 0  
		SET @Sql = @Sql + ' AND [BuSecurity] =' + CAST (@SecLevel AS NVARCHAR(2))  
	SET @Sql = @Sql + '	AND CASE [buIsPosted] WHEN 1 THEN [UserSecurity] ELSE  [UnpostedSecurity] END >= [BuSecurity] '  
	IF @PayType <> -1  
		SET @Sql = @Sql + ' AND [r].[BuPayType] = ' + CAST(@PayType AS NVARCHAR(2))  
	IF (@ChkTypeGuid <> 0X0)  
	IF (@ShowBillWithEntry > - 1) OR (@ShowBillWithEntry > -1)  
	IF (@ShowBillWithEntry > - 1) and (@ShowBillWithEntry >-1)  
		SET @Sql = @Sql + 'AND ([r].[buGuid]  IN (SELECT [en].[BillGuid] FROM  [#EntryTbl1] en WHERE en.EntryBill = '+CAST( @ShowBillWithEntry AS NVARCHAR(2))+ 'OR en.posted = ' +  CAST(@PostedValue AS NVARCHAR(2))+ ')) '  
	IF (@ItemChecked <> -1)  
		SET @Sql = @Sql + ' AND ((' + CAST(@ItemChecked as NVARCHAR(4)) + '= 0) AND ([buGuid] IN (SELECT [Guid] FROM [#CHKFLD]))) OR ((' + CAST(@ItemChecked as NVARCHAR(4)) + ' = 1) AND ([buGuid] NOT IN (SELECT [Guid] FROM [#CHKFLD])))'  
	IF @CurrentUserGuid <> 0X00  
		SET @Sql = @Sql + 'AND [buUserGuid] =''' + CAST( @CurrentUserGuid AS NVARCHAR(36)) + ''''  
	IF @ShowFromVal <> 0  
		SET @Sql = @Sql + 'AND [buGuid] IN (SELECT [buGuid] FROM #BU)'  
	--IF @BillCond <> 0X00  
	--BEGIN  
		--SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyGUID)  
	IF @Criteria <> ''  
		SET @Criteria = ' AND (' + @Criteria + ')'  
	--END	  
	SET @Sql = @Sql + '		  
		GROUP BY  
			[BuType], [buSortFlag]  
		ORDER BY  
			[BuSortFlag]'  
	EXEC(@Sql)
#################################################################
#END

