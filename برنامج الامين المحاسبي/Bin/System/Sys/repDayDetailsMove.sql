############################################################################
CREATE PROCEDURE repDayDetailsMove 
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@SrcTypesguid		[UNIQUEIDENTIFIER], 
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID 			[UNIQUEIDENTIFIER], 
	@PostedValue		[INT], -- 0, 1 , -1 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text  
	@NotesNotContain	[NVARCHAR](256), -- NULL or Not Contain  
	@CustGUID 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust  
	@StoreGUID 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores  
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs  
	@AccGUID			[UNIQUEIDENTIFIER],  
	@CurrencyGUID 		[UNIQUEIDENTIFIER],  
	@Flag				[BIGINT] = 0, 
	@UseUnit			[INT] = 0,-- 0 BILL UNIT 1 FIRSTUNIT 2 SECCOUND UNIT 3 THIRD UNIT 4 [DefUnit] 
	@CheckGUID			[UNIQUEIDENTIFIER] = 0X0, 
	@CustCond			[UNIQUEIDENTIFIER] = 0X00,  
	@BillCond			[UNIQUEIDENTIFIER] = 0X00, 
	@MatCond			[UNIQUEIDENTIFIER] = 0X00,
	@InS				INT = 1,
	@OutS				INT = -1
AS  
		SET NOCOUNT ON 

	DECLARE @IsAdmin AS [BIT] = 0
	SET @IsAdmin = [dbo].[fnIsAdmin]( [dbo].[fnGetCurrentUserGUID]()) 
	 
	DECLARE 
		@BuStr NVARCHAR(MAX), 
		-- For Bill Custome Filed  
		@Criteria NVARCHAR(4000) 
	SET @Criteria = ''

	DECLARE 
	    @SortAffectCostType BIT 
	SET @SortAffectCostType = 0
	IF @PostedValue = 1
		SET @SortAffectCostType = 1

	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
		[UnpostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	CREATE TABLE [#StoreTbl]([StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CustTbl2] ([CustGuid] [UNIQUEIDENTIFIER], [Security] [INT], [cuCustomerName] NVARCHAR(256), [cuLatinName] NVARCHAR(256))
	
	CREATE TABLE [#MatTbl2] ([MatGuid] [UNIQUEIDENTIFIER], [mtCode] NVARCHAR(256), [mtName] NVARCHAR(256), [mtLatinName] NVARCHAR(256), 
		[mtDefUnitFact] FLOAT, [mtDefUnitName] NVARCHAR(256), [mtUnity] NVARCHAR(256), [mtUnit2] NVARCHAR(256), [mtUnit3] NVARCHAR(256), 
		[mtUnit2Fact] FLOAT, [mtUnit3Fact] FLOAT, [mtBarCode] NVARCHAR(256), [mtBarCode2] NVARCHAR(256), [mtBarCode3] NVARCHAR(256),
		[mtType] INT, [mtSpec] NVARCHAR(1000), [mtOrigin] NVARCHAR(256), [mtPos] NVARCHAR(256), [mtCompany] NVARCHAR(256), [mtColor] NVARCHAR(256), 
		[mtDim] NVARCHAR(256), [mtProvenance] NVARCHAR(256), [mtQuality] NVARCHAR(256), [mtModel] NVARCHAR(256), [mtUnit2FactFlag] BIT, 
		[mtUnit3FactFlag] BIT, [mtDefUnit] INT, [GroupGuid] [UNIQUEIDENTIFIER],[mtVAT] FLOAT, [mtFlag] FLOAT)
	  
	--Filling temporary tables  
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, -1 ,@MatCond 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList3] 	@SrcTypesguid, NULL, @SortAffectCostType
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID  
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGuid  
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGUID, @AccGUID,@CustCond  

	INSERT INTO  [#CustTbl2] 
	SELECT [CustGuid],[c].[Security],[CustomerName] AS [cuCustomerName],CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END AS [cuLatinName] 
	FROM [#CustTbl] AS [C] INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [CustGuid] 
	
	IF ISNULL(@CustGUID,0X00) = 0X00 AND ISNULL(@AccGUID,0X00) = 0X00 AND @CustCond = 0X00 
		INSERT INTO [#CustTbl2] VALUES(0X00,0,'','')  
	
	IF ISNULL(@CostGuid,0X00) =0X00 
		INSERT INTO [#CostTbl] VALUES (0X00,0) 
	
	IF @NotesContain IS NULL 
		SET @NotesContain = ''  
	IF @NotesNotContain IS NULL  
		SET @NotesNotContain = ''  

	CREATE TABLE [#Result]( 
		[buCostPtr]				[UNIQUEIDENTIFIER],
		[buIsPosted]			[INT], 
		[buGUID]				[UNIQUEIDENTIFIER],
		[ItemGUID]				[UNIQUEIDENTIFIER],
		[buType] 				[UNIQUEIDENTIFIER], 
		[buNumber] 				[UNIQUEIDENTIFIER],  
		[biMatPtr] 				[UNIQUEIDENTIFIER],  
		[biStorePtr]			[UNIQUEIDENTIFIER],  
		[Security]				[INT],  
		[UserSecurity] 			[INT],  
		[UserReadPriceSecurity]	[INT], 
		[MatSecurity]			[INT], 
		[budate]				[DATETIME], 
		[FixedBuTotal]			[FLOAT], 
		[FixedBuTotalExtra]		[FLOAT], 
		[FixedBuTotalDisc]		[FLOAT], 
		[FixedbuItemsDisc]		[FLOAT], 
		[FixedbuItemsExtra]		[FLOAT], 
		[FixedbuVat]			[FLOAT],
		[FixedBuTotalSalesTax]  [FLOAT],
		[FixedBuFirstPay]		[FLOAT],
		[FixedBiDiscount]		[FLOAT], 
		[FixedBiBonusDisc]		[FLOAT], 
		[FixedBiextra]			[FLOAT], 
		[FixedBiVAT]			[FLOAT], 
		[FixedBiPrice]			[FLOAT], 
		[biQty]					[FLOAT], 
		[biQty2]				[FLOAT], 
		[biQty3]				[FLOAT], 
		[biBonusQnt]			[FLOAT], 
		[cuCustomerName]		[NVARCHAR](256) ,  
		[cuLatinName]			[NVARCHAR](256) , 
		[buLatinFormatedNumber]	[NVARCHAR](256) , 
		[buFormatedNumber]		[NVARCHAR](256) ,	 
		[biUnity]				[INT], 
		[buPayType]				[INT], 
		[biNotes]				[NVARCHAR](MAX) , 
		[buNotes]				[NVARCHAR](MAX) , 
		[biLength]				[FLOAT], 
		[biWidth]				[FLOAT], 
		[biHeight]				[FLOAT], 
		[biCount]				[FLOAT], 
		[BuNum]					[FLOAT], 
		[BiNumber]				[FLOAT], 
		[BuSortFlag]			[INT], 
		[BuSalesManPtr]			[FLOAT], 
		[BuVendor]				[FLOAT], 
		[biCostPtr]				[UNIQUEIDENTIFIER], 
		[biExpireDate]			[DATETIME], 
		[biProductionDate]		[DATETIME], 
		[biClassPtr]			[NVARCHAR](256) , 
		[biSoGuid]				[UNIQUEIDENTIFIER], 
		[biSoType]				[INT], 
		[buCheckTypeGuid]		[UNIQUEIDENTIFIER], 
		[Branch]				[UNIQUEIDENTIFIER], 
		[Cust]					[UNIQUEIDENTIFIER], 
		[buTextFld1]			[NVARCHAR](256) , 
		[buTextFld2]			[NVARCHAR](256) , 
		[buTextFld3]			[NVARCHAR](256) , 
		[buTextFld4]			[NVARCHAR](256) ,
		ShowPrice				[TINYINT],
		cuSecurity				[INT],
		[ManGUID]				[UNIQUEIDENTIFIER],
		[PriorityNum]			[INT], 
		[SamePriorityOrder]		INT, 
		[SortNumber]			INT,
		btIsInput               INT,
		FixedBiProfits          [FLOAT],
		btAffectProfit          INT ,
		btDiscAffectProfit      INT ,
		btExtraAffectProfit     INT ,
		TotalDiscountPercent    [FLOAT],
		TotalExtraPercent       [FLOAT]
		) 
	
	SET @BuStr = 'INSERT INTO [#Result] SELECT ISNULL([a].[buCostPtr],0X0) AS buCostPtr ,[a].[buIsPosted],a.[buGUID],
			a.[biGUID] as ItemGUID ,a.[buType],a.[buGuid],a.[biMatPtr], [biStorePtr],[buSecurity], 
			[Sec],a.[UserReadPriceSecurity],[mtSecurity], a.[budate], a.[FixedBuTotal], 
			[FixedBuTotalExtra],ISNULL([FixedBuTotalDisc],0.0),	a.[FixedbuItemsDisc],a.[buItemsExtra], a.[FixedbuVat], 
			a.[FixedBuTotalSalesTax], a.[FixedBuFirstPay], a.[FixedBiDiscount], a.[FixedBiBonusDisc], 
			[BiExtra], 
			a.[BiVAT], a.[BiPrice], a.[biQty], a.[biQty2], [biQty3],a.[biBonusQnt],a.[cuCustomerName],	 
			[cuLatinName],a.[buLatinFormatedNumber], [buFormatedNumber],a.[biUnity],a.[buPayType],a.[biNotes],a.[buNotes], 
			[biLength],a.[biWidth],a.[biHeight],a.[biCount],a.[BuNumber], 
			[BiNumber],a.[BuSortFlag],a.[BuSalesManPtr],a.[BuVendor],a.[biCostPtr], 
			[biExpireDate],[biProductionDate],[biClassPtr],[biSoGuid],a.[biSoType],ISNULL(a.[buCheckTypeGuid],0x0),a.[buBranch],a.[Cust], 
			[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],PRSEC,
			cuSecurity,[a].[ManGuid],[PriorityNum],[SamePriorityOrder],[SortNumber],[btIsInput],FixedBiProfits,btAffectProfit,btDiscAffectProfit, btExtraAffectProfit,FixedTotalDiscountPercent ,FixedTotalExtraPercent
		FROM 
		( 
		SELECT 
			ISNULL([buCostPtr],0X0) AS buCostPtr,
			[r].[buIsPosted],
			[r].[buType],[r].[buGuid], [r].[biGUID],
			[biMatPtr],[biStorePtr],[buSecurity], 
			CASE [r].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnpostedSecurity] END AS [Sec], 
			[UserReadPriceSecurity],[mtSecurity],[budate],[FixedBuTotal], 
			[FixedBuTotalExtra],[FixedBuTotalDisc] - [FixedBuBonusDisc] [FixedBuTotalDisc], 
			[FixedbuItemsDisc],	[buItemsExtra]*[FixedCurrencyFactor] [buItemsExtra], [FixedbuVat], [FixedBuTotalSalesTax],
			[FixedBuFirstPay] , [FixedBiDiscount] [FixedBiDiscount], [FixedBiBonusDisc], 
			[BiExtra]*[FixedCurrencyFactor] [BiExtra],
			[biTotalTaxValue] * [FixedCurrencyFactor] [BiVAT], 
			[BiPrice]*[FixedCurrencyFactor] [BiPrice], 
			[biQty],[biQty2], 
			[biQty3],[biBonusQnt],	 
			CASE [BuCustPtr] WHEN 0X00  THEN [buCust_Name] ELSE [cuCustomerName] END [cuCustomerName],CASE [BuCustPtr] WHEN 0X00  THEN [buCust_Name] ELSE [cuLatinName] END as [cuLatinName], 
			[buLatinFormatedNumber], 
			[buFormatedNumber], 
			[biUnity],[buPayType], 
			[biNotes],[buNotes], 
			[biLength],[biWidth], 
			[biHeight],[biCount],[BuNumber], 
			[r].[BiNumber],[BuSortFlag],buUserGuid, 
			[BuSalesManPtr],[BuVendor],biBonusDisc,biDiscount,biCurrencyVal,bucostptr AS [biCostPtr],[biExpireDate],[biProductionDate],[biClassPtr], 
			[biSoGuid],[biSoType],[buCheckTypeGuid],[buBranch],biCurrencyPtr,[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[buCustPtr] [Cust]	,
			CASE WHEN [bt].[UserReadPriceSecurity] >= [BUSecurity] THEN 1 ELSE 0 END PRSEC,
			[cu].[Security] AS cuSecurity,ISNULL([MB].[ManGuid],0x0) AS [ManGuid], [bt].[PriorityNum],bt.[SamePriorityOrder],bt.[SortNumber],r.[btIsInput],r.[FixedBiProfits],r.[btAffectProfit],r.[btDiscAffectProfit], r.[btExtraAffectProfit],r.[FixedTotalDiscountPercent] ,r.[FixedTotalExtraPercent]
		FROM 																  
			[fn_bubi_Fixed](''' + CAST ( @CurrencyGUID AS  NVARCHAR(36) ) + ''') AS [r]  
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid] 
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]  
			INNER JOIN [#CustTbl2] AS [cu] ON [cu].[CustGuid] = [BuCustPtr]			 
			INNER JOIN [#StoreTbl] AS [st] ON  [BiStorePtr] = [st].[StoreGuid] ' 
		 
	-- For Bill Custom Fields 
	IF @BillCond <> 0X00 
	BEGIN			 
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyGUID) 
		IF @Criteria <> '' AND RIGHT ( RTRIM (@Criteria) , 4 ) ='<<>>' 
		BEGIN	 
			SET @Criteria = REPLACE(@Criteria ,'<<>>','') 
			DECLARE @CFTableName NVARCHAR(255) 
			Set @CFTableName = (SELECT CFGroup_Table From CFMapping000 Where Orginal_Table = 'bu000' ) 
			SET @BuStr = @BuStr + ' INNER JOIN ['+ @CFTableName +'] ON [r].[buGuid] = ['+ @CFTableName +'].[Orginal_Guid] '			 
		END 
	END 
	SET @BuStr = @BuStr +' LEFT JOIN [MB000] [MB] ON [r].[buGuid] = [MB].[BillGuid] '
	SET @BuStr = @BuStr + ' WHERE 
		[budate] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)  
	IF (@PostedValue <> -1) 			 
		SET @BuStr = @BuStr + ' AND [BuIsPosted] =' + CAST( @PostedValue AS NVARCHAR(2)) 
	IF @NotesContain <>  '' 
		 SET @BuStr = @BuStr + ' AND (([BuNotes] LIKE ''%'' + '''+ REPLACE(@NotesContain,'''', '''''') + ''' +''%'') OR ( [BiNotes] LIKE ''%'' + ''' + REPLACE(@NotesContain,'''', '''''') + ''' + ''%''))'  
	IF @NotesNotContain <> '' 
		SET @BuStr = @BuStr + ' AND (([BuNotes] NOT LIKE ''%'' + ''' + REPLACE(@NotesNotContain,'''', '''''') + ''' + ''%'') AND ([BiNotes] NOT LIKE ''%''+  ''' + REPLACE(@NotesNotContain,'''', '''''') + ''' + ''%''))'	  
	IF  @CheckGUID <> 0X00	  
		SET @BuStr = @BuStr + ' AND [buCheckTypeGuid] = ''' + CAST (@CheckGUID AS NVARCHAR(36)) + '''' 
	IF @Criteria <> '' 
	BEGIN			 
		SET @Criteria = ' AND (' + @Criteria + ')' 
		SET @BuStr = @BuStr + @Criteria 
	END 
	SET @BuStr = @BuStr + ') a INNER JOIN [#CostTbl] AS [CO] ON [CostGuid] = [biCostPtr]'
		 
	EXEC sp_executesql @BuStr 
	
	DROP TABLE [#CustTbl2] 
	DROP TABLE [#CostTbl] 
	
	IF @IsAdmin = 0  
		EXEC [prcCheckSecurity]  

	INSERT INTO [#MatTbl2]  
	SELECT [MatGuid],[Code] AS [mtCode],[Name] AS [mtName],[LatinName] AS [mtLatinName], 
		CASE [DefUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE  [Unit3Fact] END [mtDefUnitFact], 
		CASE [DefUnit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE  [Unit3] END [mtDefUnitName], 
		[Unity] AS [mtUnity], 
		[Unit2] AS [mtUnit2], 
		[Unit3] AS [mtUnit3], 
		[Unit2Fact] AS [mtUnit2Fact], 
		[Unit3Fact] AS [mtUnit3Fact], 
		[BarCode] AS [mtBarCode],[BarCode2] AS [mtBarCode2],[BarCode3] AS [mtBarCode3],[Type] AS [mtType], 
		[Spec] AS [mtSpec],  
		[Origin] AS [mtOrigin], 
		[Pos] AS [mtPos],  
		[Company] AS [mtCompany], 
		[Color] AS [mtColor], 
		[Dim] AS [mtDim],  
		[Provenance] AS [mtProvenance], 
		[Quality] AS [mtQuality], 
		[Model] AS [mtModel], 
		[Unit2FactFlag] AS [mtUnit2FactFlag], 
		[Unit3FactFlag] AS [mtUnit3FactFlag], 
		[DefUnit] AS [mtDefUnit],[GroupGuid],
		[VAT]  AS [mtVAT], 
		[Flag] AS [mtFlag] 
	FROM 
		[mt000] AS [mt] 
		INNER JOIN [#MatTbl] AS [m] ON [mt].[Guid] = [m].[MatGuid] 
	DROP TABLE [#MatTbl] 
	CREATE INDEX mttInd ON #MatTbl2([MatGuid] ) 
	CREATE INDEX rInd ON #Result([biMatPtr], [BuDate], [BuSortFlag], [BuNum])
	SET @BuStr = '  
		SELECT 
			ISNULL([buCostPtr],0X0) AS buCostPtr, [r].[buIsPosted],r.Cust AS CustGuid ,r.buType, r.buDate, CONVERT(VARCHAR(8), r.buDate, 108) AS BuTime, r.buNumber, r.buPayType, r.ItemGUID,
			CASE r.buPayType WHEN 2 THEN r.buCheckTypeGuid ELSE NULL END buCheckTypeGuid,' 
	IF [dbo].[fnConnections_GetLanguage]() = 0 
		SET @BuStr = @BuStr + ' [cuCustomerName] [buCust_Name], ' 
	ELSE 
		SET @BuStr = @BuStr + ' CASE [cuLatinName] WHEN ' + '''' + ''' THEN [cuCustomerName] ELSE [cuLatinName]  END [buCust_Name], '  
	IF @Flag & 0x00000100 > 0 
		SET @BuStr = @BuStr + ' r.buLatinFormatedNumber [buFormatedNumber],' 
	ELSE 
		SET @BuStr = @BuStr + ' r.buFormatedNumber,' 
	 
	IF @IsAdmin = 1  
		SET @BuStr = @BuStr + ' 
			[r].[FixedBuTotal] [buTotal],  
			[r].[FixedBuTotalExtra] [buTotalExtra],  
			[r].[FixedBuTotalDisc] [buTotalDisc],  
			[r].[FixedbuItemsDisc] [buItemsDisc], 
			[r].[FixedbuItemsExtra] [buItemsExtra], 
			[r].[FixedbuVat] [buVat], 
			[r].[FixedBuTotalSalesTax] [buTotalSalesTax],
			[r].[FixedBuFirstPay] [buFirstPay],
			ISNULL([r].[FixedBiVAT], 0) [biVat], 
			ISNULL([r].[FixedBiExtra], 0) [biExtra],' 
	ELSE 
		SET @BuStr = @BuStr + ' 
			ShowPrice * r.FixedBuTotal buTotal,  
			ShowPrice * r.FixedBuTotalExtra buTotalExtra,  
			ShowPrice * r.FixedBuTotalDisc buTotalDisc,  
			ShowPrice * [r].[FixedbuItemsDisc] [buItemsDisc], 
			ShowPrice * [r].[FixedbuItemsExtra] [buItemsExtra], 
			ShowPrice * [r].[FixedbuVat] [buVat], 
			ShowPrice * [r].[FixedBuTotalSalesTax] [buTotalSalesTax],
			ShowPrice * [r].[FixedBuFirstPay] [buFirstPay] ,
			ShowPrice * ISNULL([r].[FixedBiVAT], 0)  [biVat], 
			ShowPrice * ISNULL([r].[FixedBiExtra], 0) [biExtra],' 
	
	SET @BuStr = @BuStr + '	r.biStorePtr,' 
	SET @BuStr = @BuStr + '	[r].[biNotes],' 
	SET @BuStr = @BuStr +'[r].[biUnity],[r].[biMatPtr], ' 
	IF @IsAdmin = 1  
	BEGIN 
		IF @UseUnit = 4 
			SET @BuStr = @BuStr + ' 
				[r].[FixedBiPrice] [biPrice],'  
		ELSE IF @UseUnit = 0 
			SET @BuStr = @BuStr +  
				' [r].[FixedBiPrice]/CASE r.biUnity WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END [biPrice],' 
		ELSE IF @UseUnit = 1  
			SET @BuStr = @BuStr +  
				'(CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END)*r.FixedBiPrice/CASE r.biUnity WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END [biPrice],' 
		ELSE IF @UseUnit = 2  
			SET @BuStr = @BuStr +  
				' (CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END) *[r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END [biPrice],' 
		ELSE 
			SET @BuStr = @BuStr +  
					'  [mt].[mtDefUnitFact]*[r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END [biPrice],' 
	END 
	ELSE	 
		IF @UseUnit = 4 
			SET @BuStr = @BuStr + ' 
				ShowPrice *  [r].[FixedBiPrice] [biPrice], 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN '  
		ELSE IF @UseUnit = 0 
			SET @BuStr = @BuStr + ' 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END ELSE 0 END [biPrice], 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN '   
		ELSE IF @UseUnit = 1 
			SET @BuStr = @BuStr + ' 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN  (CASE mt.mtUnit2Fact WHEN 0 THEN 1 ELSE mt.mtUnit2Fact END) *[r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END ELSE 0 END [biPrice], 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN '   
		ELSE IF @UseUnit = 2  
			SET @BuStr = @BuStr + ' 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN  (CASE mt.mtUnit3Fact WHEN 0 THEN 1 ELSE mt.mtUnit3Fact END) *[r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END ELSE 0 END [biPrice], 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN ' 
		ELSE 
			SET @BuStr = @BuStr + ' 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [mt].[mtDefUnitFact]*[r].[FixedBiPrice]/CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  [mt].[mtUnit2Fact] ELSE  [mt].[mtUnit3Fact] END ELSE 0 END [biPrice], 
				CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN '  
	SET @BuStr = @BuStr +'	[r].[FixedBiDiscount] ' 
	 
	IF @IsAdmin = 1  
		SET @BuStr = @BuStr +' [biDiscount],' 
	ELSE 
		SET @BuStr = @BuStr +'	ELSE 0 END [biDiscount],' 
	IF @IsAdmin = 1  
		SET @BuStr = @BuStr +'	[r].[FixedBiBonusDisc] BiBonusDisc,'  
	ELSE 
		SET @BuStr = @BuStr +' CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBiBonusDisc] END BiBonusDisc,'  
	SET @BuStr = @BuStr + ' [r].[biQty], ' 
	IF @Flag & 0x00000080 > 0 
	BEGIN 
		SET @BuStr = @BuStr + ' 
		CASE [mtUnit2FactFlag] WHEN 0 THEN CASE [mtUnit2Fact] WHEN 0 THEN 0 ELSE [r].[biQty] /  [mt].[mtUnit2Fact] END ELSE [r].[biQty2] END [biQty2], 
		CASE [mtUnit3FactFlag] WHEN 0 THEN CASE [mtUnit3Fact] WHEN 0 THEN 0 ELSE [r].[biQty] /  [mt].[mtUnit3Fact] END ELSE [r].[biQty3] END [biQty3],[mt].[mtUnity] [Unity1],[mtUnit2],[mtUnit3],' 
	END 
	ELSE
		SET @BuStr = @BuStr + ' 0 AS [biQty2], 0 AS [biQty3], '''' AS [Unity1], '''' AS [mtUnit2], '''' AS [mtUnit3], '
	SET @BuStr = @BuStr + ' 
		r.biBonusQnt,  
		mt.mtName, ' 
	SET @BuStr = @BuStr + '	[mtCode], ' 
	
	IF @UseUnit = 4 
		SET @BuStr = @BuStr + '	CASE [biUnity] WHEN 1 THEN [mtUnity] WHEN 2 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END  ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END END [mtUnityName],' 
	ELSE IF @UseUnit = 0 
		SET @BuStr = @BuStr + '[mtUnity] [mtUnityName],' 
	ELSE IF @UseUnit = 1 
		SET @BuStr = @BuStr + '	CASE [mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END [mtUnityName],' 
	ELSE IF @UseUnit = 2 
		SET @BuStr = @BuStr + ' CASE [mtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END [mtUnityName] ,' 
	ELSE 
		SET @BuStr = @BuStr + ' 
		[mtDefUnitName] [mtUnityName],' 
	IF @Flag & 0x20000000 > 0 
	BEGIN 
		IF @UseUnit = 4 
			SET @BuStr = @BuStr + '	CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END  ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END END [UnitFact],' 
		 ELSE IF @UseUnit = 0 
			SET @BuStr = @BuStr + ' 1 AS [UnitFact],'
		ELSE IF @UseUnit = 1 
			SET @BuStr = @BuStr + '	CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END [UnitFact],' 
		ELSE IF @UseUnit = 2 
			SET @BuStr = @BuStr + ' CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END [UnitFact],' 
		ELSE 
			SET @BuStr = @BuStr + '  [mtDefUnitFact] [UnitFact],' 
	END 
	ELSE
	SET @BuStr = @BuStr + ' '' [UnitFact],' 
	 
	IF @UseUnit = 4 
		SET @BuStr = @BuStr +  
			' CASE [r].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN  CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END END [mtUnitFact]' 
	ELSE IF @UseUnit = 0  
		SET @BuStr = @BuStr +  
			' 1 [mtUnitFact]' 
	ELSE IF @UseUnit = 1  
		SET @BuStr = @BuStr +  
			' CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE  [mt].[mtUnit2Fact] END [mtUnitFact]' 
	ELSE IF @UseUnit = 2  
		SET @BuStr = @BuStr +  
			' CASE  [mtUnit3Fact] WHEN 0 THEN 1 ELSE  [mt].[mtUnit3Fact] END [mtUnitFact]' 
	ELSE 
		SET @BuStr = @BuStr +  
				'  [mtDefUnitFact] [mtUnitFact]' 
	------------------------------------------------------------------------------------------------------- 
	SET @BuStr = @BuStr + ',co.GUID CostGUID ' 
	SET @BuStr = @BuStr + ',ISNULL(co.Code,' + '''' + '''' +') CostCode ' 
	SET @BuStr = @BuStr + ',ISNULL([co].[Name],' + '''' + '''' + ') [CostName] ' 
	SET @BuStr = @BuStr + ',ISNULL(CASE [co].[LatinName] WHEN '  + '''' + '''' + ' THEN [co].[Name] ELSE [co].[LatinName] END,' + '''' + '''' + ') [CostLatinName] ' 
	 
	IF @Flag &  0x80000000 > 0 
		SET @BuStr = @BuStr + ',ISNULL(CustomerNumber,0) CustomerNumber'  
	ELSE 
		SET @BuStr = @BuStr + ',0 CustomerNumber'  
	SET @BuStr = @BuStr + ',r.[ManGUID] , r.[BuSortFlag],r.[BuNum],r.[BiNumber],r.[PriorityNum],r.[SamePriorityOrder],r.[SortNumber] ,r.[btIsInput] ,r.[FixedBiProfits] ,r.[btAffectProfit],r.[btDiscAffectProfit], r.[btExtraAffectProfit],r.[TotalDiscountPercent] ,r.[TotalExtraPercent]'  
	------------------------------------------------------------------------------------------------------- 
	SET @BuStr = @BuStr + NCHAR(13) + 'FROM ' 
	 
	SET @BuStr = @BuStr + NCHAR(13) + '#Result r INNER JOIN #MatTbl2 mt ON r.biMatPtr = MatGuid ' 
	 
	-------------------------------------------------------------------------------------------------------  
	
		SET @BuStr = @BuStr + NCHAR(13) + 'INNER JOIN vwst st ON r.biStorePtr = st.stGUID' 
	
		SET @BuStr = @BuStr + NCHAR(13) + 'LEFT JOIN co000 co ON r.biCostPtr=co.Guid' 
	-------------------------------------------------------------------------------------------------------
	
	IF @Flag &  0x80000000 > 0 
		SET @BuStr = @BuStr  + NCHAR(13) + 'LEFT JOIN (SELECT BillGUID,CustomerNumber FROM  BillRel000 qq INNER JOIN SCPurchases000 VV  ON qq.PARENTGUID = VV.Guid) bre ON  [r].[BuNumber] = bre.BillGUID' 
	 
	IF @IsAdmin = 0 
		SET @BuStr = @BuStr + NCHAR(13) + 'WHERE r.UserSecurity >= r.Security' 
	SET @BuStr = @BuStr  + NCHAR(13) + 'ORDER BY ' 
	SET @BuStr = @BuStr + ' r.BuDate, r.[PriorityNum], r.[SortNumber], r.BuNum, r.BuNumber, r.[SamePriorityOrder], r.BiNumber'
    -----------------------------------------------------------------------------------------------------------------------
	CREATE TABLE [#AllResult]( 
	    buCostPtr				[UNIQUEIDENTIFIER],
		buIsPosted				[INT],
		CustGuid				[UNIQUEIDENTIFIER],
		buType					[UNIQUEIDENTIFIER],
		BuDate					[DATETIME], 
		BuTime					[nvarchar](8),
		buNumber				[UNIQUEIDENTIFIER],
		buPayType				[INT], 
		ItemGUID				[UNIQUEIDENTIFIER] PRIMARY KEY,
		buCheckTypeGuid			[UNIQUEIDENTIFIER],
		buCust_Name				[NVARCHAR](256),
		buFormatedNumber		[NVARCHAR](256),
		buTotal					[FLOAT],
		buTotalExtra			[FLOAT],
		buTotalDisc				[FLOAT],
		buItemsDisc				[FLOAT],
		buItemsExtra			[FLOAT],
		buVat					[FLOAT],
		buTotalSalesTax			[FLOAT],
		buFirstPay				[FLOAT],
		biVat					[FLOAT],
		biExtra					[FLOAT],
		biStorePtr				[UNIQUEIDENTIFIER],
		biNotes					[NVARCHAR](MAX) , 
		biUnity					[INT], 
		biMatPtr				[UNIQUEIDENTIFIER],
		biPrice					[FLOAT],
		biDiscount				[FLOAT],
		BiBonusDisc				[FLOAT],
		biQty					[FLOAT],
		biQty2					[FLOAT],
		biQty3					[FLOAT],
		Unity1					[NVARCHAR](256),
		mtUnit2					[NVARCHAR](256),
		mtUnit3					[NVARCHAR](256),
		biBonusQnt				[FLOAT],
		mtName					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		mtCode					[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		mtUnityName				[NVARCHAR](256),
		UnitFact				[FLOAT],
		mtUnitFact				[FLOAT],
		CostGUID				[UNIQUEIDENTIFIER],
		CostCode				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		CostName				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		CostLatinName			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		CustomerNumber			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		ManGUID					[UNIQUEIDENTIFIER],
		BuSortFlag				[INT], 
		BuNum					[FLOAT],
		BiNumber				[FLOAT],
		[PriorityNum]			[INT],
		[SamePriorityOrder]		INT,
		[SortNumber]			INT,
		btIsInput               INT,
		FixedBiProfits          FLOAT,
		btAffectProfit          INT,
		btDiscAffectProfit      INT,
		btExtraAffectProfit     INT,
		TotalDiscountPercent    FLOAT,
		TotalExtraPercent       FLOAT
	)
	
	INSERT INTO [#AllResult] EXEC sp_executesql @BuStr
    CREATE TABLE [#RequiredResult]
	(
	   	biMatPtr                [UNIQUEIDENTIFIER],
		buNumber                [UNIQUEIDENTIFIER],
		buCostPtr				[UNIQUEIDENTIFIER],
		CustGuid				[UNIQUEIDENTIFIER],
		BuDate					[DATETIME], 
		ItemGUID				[UNIQUEIDENTIFIER],
		buFormatedNumber		[NVARCHAR](256),
		buCust_Name				[NVARCHAR](256),
		mtName                  [NVARCHAR](256),
		biQty					[FLOAT],
		TotalDisc               [FLOAT],
		biPrice                 [FLOAT],
		BiTotalExtra            [FLOAT],
		BiTotal                 [FLOAT],
		VatVal                  [FLOAT],
		TotalPrice              [FLOAT],
		buTotalSalesTax         [FLOAT],
		biTotalWithVAT          [FLOAT],
		biDiscount              [FLOAT],
		BiBounsDisc             [FLOAT],
		biBonusQnt              [FLOAT],
		biExtra                 [FLOAT],
		buTotalExtra            [FLOAT],
		TotalDiscountPercent    [FLOAT],
		mtCode                  [NVARCHAR](256),
		mtUnityName             [NVARCHAR](256),
		biQty2					[FLOAT],
		mtUnit2					[NVARCHAR](256),
		biQty3					[FLOAT],
		mtUnit3					[NVARCHAR](256),
		btIsInput               [INT],
		FixedBiProfits          [FLOAT],
		Cost                    [FLOAT],
		BuTotal			        [FLOAT],
		btDiscAffectProfit      INT,
		btExtraAffectProfit     INT,
	)

	CREATE TABLE #Profit
	(
		BiGUID [UNIQUEIDENTIFIER] PRIMARY KEY, 
		Cost [FLOAT], 
		Profit [FLOAT]
	)

	DECLARE @DefCurr UNIQUEIDENTIFIER = (SELECT dbo.fnGetDefaultCurr())

	IF @DefCurr = @CurrencyGUID
		INSERT INTO #Profit 
		SELECT biGUID, biUnitCostPrice, biProfits 
		FROM vwbubi
		WHERE [buDate] BETWEEN @StartDate AND @EndDate
	ELSE
		INSERT INTO #Profit 
		SELECT BiGuid, Cost, Profit 
		FROM dbo.fnGetBillMaterialsCost(0x0, 0x0, @CurrencyGUID, @EndDate) t

	INSERT INTO #RequiredResult 
	SELECT 
		biMatPtr,
		buNumber, 
		buCostPtr, 
		CustGuid, 
		BuDate, 
		ItemGUID, 
		buFormatedNumber, 
		buCust_Name, 
		mtName,
		(biQty / [UnitFact]) * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biQty,
		0,
		biPrice,
		0, 
		0,
		biVat as VatVal,      			
        ([biPrice] * ([biQty] / [UnitFact])) AS TotalPrice,
		buTotalSalesTax,
		0,
		biDiscount,
		BiBonusDisc,
		biBonusQnt * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biBonusQnt,
		biExtra,
        TotalExtraPercent,
		TotalDiscountPercent,
		mtCode,
		mtUnityName,
		biQty2 * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biQty2,
		mtUnit2,
		biQty3 * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biQty3,
		mtUnit3,
		btIsInput,
		(CASE btAffectProfit WHEN 0 THEN 0 ELSE prf.Profit END),
		(CASE btAffectProfit WHEN 0 THEN 0 ELSE prf.Cost * ( biQty + biBonusQnt) END),
		buTotal,
		btDiscAffectProfit,
		btExtraAffectProfit 
	FROM 
		[#AllResult] R
		INNER JOIN #Profit prf ON prf.BiGuid = R.ItemGUID

	UPDATE #RequiredResult
	SET buTotalSalesTax = (CASE buTotal WHEN 0 THEN 0 ELSE (TotalPrice * buTotalSalesTax) / buTotal END)

	UPDATE #RequiredResult
	SET BiTotal = TotalPrice - TotalDiscountPercent - BiBounsDisc - biDiscount + (buTotalExtra + [biExtra])

	SELECT 
		biMatPtr, 
		buNumber, 
		buCostPtr, 
		CustGuid, 
		BuDate, 
		ItemGUID, 
		buFormatedNumber, 
		buCust_Name, 
		mtName,
		biQty,
		(TotalDiscountPercent + BiBounsDisc + biDiscount) * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) as TotalDisc,
		biPrice,
		(buTotalExtra + [biExtra]) * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS BiTotalExtra,
		BiTotal * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS BiTotal, 
		VatVal * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS VatVal,
		TotalPrice  * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS TotalPrice, 
		buTotalSalesTax * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biSalesTax,
		(BiTotal + buTotalSalesTax + VatVal) * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biTotalWithVAT, 
		biDiscount * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biDiscount,
		BiBounsDisc * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS BiBonusDisc,	
		biBonusQnt, 
		biExtra * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS biExtra, 
		buTotalExtra * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS buTotalExtra, 
		TotalDiscountPercent * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS TotalDiscountPercent,
		mtCode, 
		mtUnityName, 
		biQty2, 
		mtUnit2, 
		biQty3, 
		mtUnit3, 
		btIsInput,
		FixedBiProfits * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS FixedBiProfits, 	
		Cost * (CASE btIsInput WHEN 1 THEN @InS ELSE @OutS END) AS Cost  
	From #RequiredResult
	ORDER BY BuDate ,buFormatedNumber

	SELECT * FROM [#SecViol] 
###################################################################################
#END
