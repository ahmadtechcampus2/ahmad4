############################################################################
CREATE FUNCTION fnBill_GetTotalQty
(
		@buGuid [UNIQUEIDENTIFIER] = 0x0,
		@StoreGUID [UNIQUEIDENTIFIER] = 0x0,
		@CostGuid [UNIQUEIDENTIFIER] = 0x0
)  
	RETURNS [FLOAT]  
AS BEGIN  
/*  
this function:  
	- returns sum of total qty for specific bill with consideration of Cost and Store.
*/  
	DECLARE @result [FLOAT]
	if ((isnull(@StoreGUID, 0x0) = 0x0) AND (isnull(@CostGuid, 0x0) = 0x0))
		SET @result = (  
				SELECT
						SUM([bi].[Qty])
				FROM  
					[bi000] [bi]  
					INNER JOIN [bu000] [bu] ON [bu].[GUID] = [bi].[ParentGUID]
				WHERE  
					[bu].[GUID]= @buGuid)
	ELSE if ((isnull(@StoreGUID, 0x0) = 0x0))
		SET @result = (  
				SELECT
						SUM([bi].[Qty])
				FROM  
					[bi000] [bi]  
					INNER JOIN [bu000] [bu] ON [bu].[GUID] = [bi].[ParentGUID]
				WHERE  
					[bu].[GUID]= @buGuid AND [bi].[CostGUID]= @CostGuid)
	ELSE if ((isnull(@CostGuid, 0x0) = 0x0))
		SET @result = (  
				SELECT
						SUM([bi].[Qty])
				FROM  
					[bi000] [bi]  
					INNER JOIN [bu000] [bu] ON [bu].[GUID] = [bi].[ParentGUID]
				WHERE  
					[bu].[GUID]= @buGuid AND [bi].[StoreGUID]= @StoreGUID)
	ELSE
		SET @result = (  
				SELECT
						SUM([bi].[Qty])
				FROM  
					[bi000] [bi]  
					INNER JOIN [bu000] [bu] ON [bu].[GUID] = [bi].[ParentGUID]
					WHERE  
					[bu].[GUID]= @buGuid AND [bi].[CostGUID]= @CostGuid AND [bi].[StoreGUID]= @StoreGUID)
		
	RETURN ISNULL(@result, 0.0)  
END  
############################################################################
CREATE PROCEDURE repDayMove 
	@IsCalledByWeb		BIT, 
	@StartDate 			[DATETIME], 
	@EndDate 			[DATETIME], 
	@SrcTypesguid		[UNIQUEIDENTIFIER], 
	@MatGuid 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGuid 			[UNIQUEIDENTIFIER], 
	@PostedValue		[INT], -- 0, 1 , -1 
	@NotesContain 		[NVARCHAR](256),-- NULL or Contain Text  
	@NotesNotContain	[NVARCHAR](256), -- NULL or Not Contain  
	@CustGuid 			[UNIQUEIDENTIFIER], -- 0 all cust or one cust  
	@StoreGuid 			[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores  
	@CostGuid 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs  
	@AccGuid			[UNIQUEIDENTIFIER],  
	@CurrencyPtr 		[UNIQUEIDENTIFIER],  
	@CurrencyVal 		[FLOAT],  
	@Flag				[BIGINT] = 0, 
	@UseUnit			[INT] = 0,-- 0 BILL UNIT 1 FIRSTUNIT 2 SECCOUND UNIT 3 THIRD UNIT 4 [DefUnit] 
	@PayType			[INT] = -1, 
	@CheckGuid			[UNIQUEIDENTIFIER] = 0X0, 
	@CustCond			[UNIQUEIDENTIFIER] = 0X00, 
	@DetDiscExtra		[INT] = 0, 
	@Lang				[BIT] = 0, 
	@BillCond			[UNIQUEIDENTIFIER] = 0X00, 
	@MatCond			[UNIQUEIDENTIFIER] = 0X00, 
	@UserGuid			[UNIQUEIDENTIFIER] = 0X00, 
	@CostType			[INT] = -1, ---1 ALL 1 BU 0 BI	 
	@ShowLoterPaper		[BIT] = 0,
	@HideBonus			[BIT] = 0,
	@ShowColumnForBonus	[BIT] = 0,
	@ShowDiscount		[BIT] = 0,
	@ShowVAT			[BIT] = 0,
	@ShowSalesTax		[BIT] = 0
AS  
	--- To do Later use vwbu inner join vwbi instead of vwExtended_bi and test optimization 
	SET NOCOUNT ON 

	DECLARE @IsAdmin AS [BIT] = 0
	SET @IsAdmin = [dbo].[fnIsAdmin]( [dbo].[fnGetCurrentUserGUID]()) 
	 
	DECLARE 
		@BuStr NVARCHAR(4000), 
		-- For Bill Custome Filed  
		@Criteria NVARCHAR(4000) 
	SET @Criteria = ''

	DECLARE @SortAffectCostType BIT 
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
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid, -1 ,@MatCond 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList3] 	@SrcTypesguid, NULL, @SortAffectCostType
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGuid  
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGuid  
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGuid, @AccGuid,@CustCond  
	INSERT INTO  [#CustTbl2] 
	SELECT [CustGuid],[c].[Security],[CustomerName] AS [cuCustomerName],CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END AS [cuLatinName] 
	FROM [#CustTbl] AS [C] INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [CustGuid] 
	IF ISNULL(@CustGuid,0X00) = 0X00 AND ISNULL(@AccGuid,0X00) = 0X00 AND @CustCond = 0X00 
		INSERT INTO [#CustTbl2] VALUES(0X00,0,'','')  
	IF ISNULL(@CostGuid,0X00) =0X00 
		INSERT INTO [#CostTbl] VALUES (0X00,0) 
	--EXEC [prcGetBillsTypesList] 	@SrcTypesguid--, @UserGuid  
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
		[UserReadPriceSecurity]		[INT], 
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
		[buLatinFormatedNumber]		[NVARCHAR](256) , 
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
		[SortNumber]			INT ,
		TotalDiscountPercent    [FLOAT],
		TotalExtraPercent       [FLOAT]) 
	
	SET @BuStr = 'INSERT INTO [#Result] SELECT ISNULL([a].[buCostPtr],0X0) AS buCostPtr ,[a].[buIsPosted],a.[buGUID],a.[biGUID] as ItemGUID ,a.[buType],a.[buGuid],a.[biMatPtr], 
			[biStorePtr],[buSecurity], 
			[Sec],a.[UserReadPriceSecurity],[mtSecurity], 
			a.[budate], a.[FixedBuTotal], 
			[FixedBuTotalExtra],ISNULL([FixedBuTotalDisc],0.0),	a.[FixedbuItemsDisc],a.[buItemsExtra], a.[FixedbuVat], 
			a.[FixedBuTotalSalesTax], a.[FixedBuFirstPay] , a.[FixedBiDiscount], a.[FixedBiBonusDisc], 
			[BiExtra],
			a.[BiVAT],	a.[BiPrice],a.[biQty],a.[biQty2], 
			[biQty3],a.[biBonusQnt],a.[cuCustomerName],	 
			[cuLatinName],a.[buLatinFormatedNumber], 
			[buFormatedNumber],a.[biUnity],a.[buPayType],a.[biNotes],a.[buNotes], 
			[biLength],a.[biWidth],a.[biHeight],a.[biCount],a.[BuNumber], 
			[BiNumber],a.[BuSortFlag],a.[BuSalesManPtr],a.[BuVendor],a.[biCostPtr], 
			[biExpireDate],[biProductionDate],[biClassPtr],[biSoGuid],a.[biSoType],ISNULL(a.[buCheckTypeGuid],0x0),a.[buBranch],a.[Cust], 
			[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],PRSEC,
			cuSecurity,[a].[ManGuid],[PriorityNum],[SamePriorityOrder],[SortNumber],FixedTotalDiscountPercent ,FixedTotalExtraPercent
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
			[BuSalesManPtr],[BuVendor],biBonusDisc,biDiscount,biCurrencyVal,' 
			IF @CostType = -1  
				SET @BuStr = @BuStr + '[biCostPtr]'  
			ELSE IF @CostType = 0 
				SET @BuStr = @BuStr + '[biCostGuid]' 
			ELSE  
				SET @BuStr = @BuStr + 'bucostptr' 
	SET @BuStr = @BuStr + ' AS [biCostPtr],[biExpireDate],[biProductionDate],[biClassPtr], 
			[biSoGuid],[biSoType],[buCheckTypeGuid],[buBranch],biCurrencyPtr,[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[buCustPtr] [Cust]	,
			CASE WHEN [bt].[UserReadPriceSecurity] >= [BUSecurity] THEN 1 ELSE 0 END PRSEC,
			[cu].[Security] AS cuSecurity,ISNULL([MB].[ManGuid],0x0) AS [ManGuid], [bt].[PriorityNum],bt.[SamePriorityOrder],bt.[SortNumber],r.FixedTotalDiscountPercent ,r.FixedTotalExtraPercent
		FROM 																  
			[fn_bubi_Fixed](''' +CAST ( @CurrencyPtr AS  NVARCHAR(36) ) +''') AS [r]  
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid] 
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]  
			INNER JOIN [#CustTbl2] AS [cu] ON [cu].[CustGuid] = [BuCustPtr]			 
			INNER JOIN [#StoreTbl] AS [st] ON  [BiStorePtr] = [st].[StoreGuid]' 
		 
	-- For Bill Custom Fields 
	IF @BillCond <> 0X00 
	BEGIN			 
		SET @Criteria = [dbo].[fnGetBillConditionStr]( NULL,@BillCond,@CurrencyPtr) 
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
	IF @PayType <> -1 
		SET @BuStr = @BuStr + ' AND [buPayType] = ' + CAST( @PayType AS NVARCHAR(2)) 
	IF  @CheckGuid <> 0X00	  
		SET @BuStr = @BuStr + ' AND [buCheckTypeGuid] = ''' + CAST (@CheckGuid AS NVARCHAR(36)) + '''' 
	IF @UserGuid <> 0X00 
		SET @BuStr = @BuStr + ' AND buUserGuid = ''' + CAST(@UserGuid AS NVARCHAR(36)) + '''' 
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
	IF @Lang = 0 
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
			ShowPrice*r.FixedBuTotal buTotal,  
			ShowPrice*r.FixedBuTotalExtra buTotalExtra,  
			ShowPrice*r.FixedBuTotalDisc buTotalDisc,  
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
	SET @BuStr = @BuStr + ',r.[ManGUID] , r.[BuSortFlag],r.[BuNum],r.[BiNumber],r.[PriorityNum],r.[SamePriorityOrder],r.[SortNumber],r.[TotalDiscountPercent] ,r.[TotalExtraPercent]'  
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
	SET @BuStr = @BuStr + ' r.BuDate, r.[PriorityNum], r.[SortNumber], /*r.BuSortFlag,*/r.BuNum, r.BuNumber, r.[SamePriorityOrder], r.BiNumber'
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
		ItemGUID				[UNIQUEIDENTIFIER],
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
		TotalDiscountPercent    FLOAT,
		TotalExtraPercent       FLOAT
	)
	
	INSERT INTO [#AllResult] EXEC sp_executesql @BuStr
	DECLARE @AddDX BIT = ( CASE (@ShowDiscount | @DetDiscExtra) WHEN 0 THEN 1 ELSE  0 END )
	----------------------------------------------------Master Result
	CREATE TABLE [#MasterResult]( 
		buCostPtr				[UNIQUEIDENTIFIER],
		buIsPosted				[INT],
		Dir						[INT],
		UnPosted				[BIT],
		MasterFormatedNumber	[NVARCHAR](256),
		MasterBuDate			[DATETIME], 
		MasterBuTime			[nvarchar](8),
		MasterBuGuid			[UNIQUEIDENTIFIER],
		MasterBiGuid			[UNIQUEIDENTIFIER],
		CuName					[NVARCHAR](256),
		MasterBuCustomerGuid	[UNIQUEIDENTIFIER],
		MasterCustSubNum		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		ManGUID					[UNIQUEIDENTIFIER],
		MasterBuTotalPrice		[FLOAT],
		MasterBuTotalExtra		[FLOAT],
		MasterBuTotalDisc		[FLOAT],
		MasterBuTotalVat		[FLOAT],
		MasterBuTotalSalesTax	[FLOAT],
		MasterBuFirstPay		[FLOAT],
		MasterBuTotalQty		[FLOAT],
		MasterBuTotalQty2		[FLOAT],
		MasterBuTotalQty3		[FLOAT],
		MasterBuTTotalBounsQty	[FLOAT],
		MasterBuNetPrice		[FLOAT],
		BuPayType				[INT], 
		BuCheckTypeGuid			[UNIQUEIDENTIFIER],
		BuType					[UNIQUEIDENTIFIER],
		BuCash					[FLOAT],
		BuLater					[FLOAT],
		BuCashExtra				[FLOAT],
		BuLaterExtra			[FLOAT],
		BuCashDisc				[FLOAT],
		BuLaterDisc				[FLOAT],
		BuCashVat				[FLOAT],
		BuLaterVat				[FLOAT],
		BuSortFlag				[INT],
		BuNum					[INT], 
		BuNoteValue				[FLOAT]
	)
	INSERT INTO [#MasterResult]
	SELECT 
	ISNULL([buCostPtr], 0x0) As buCostPtr,
	a.[buIsPosted],
	(CASE BT.[bIsInput] WHEN 1 THEN 1 ELSE -1 END )		AS Dir,
	(CASE [buIsPosted] WHEN 1 THEN 0 ELSE 1 END )		AS UnPosted,
	[buFormatedNumber]	AS MasterFormatedNumber,
	[BuDate]			AS MasterBuDate,	
	[BuTime]			AS MasterBuTime,	
	[buNumber]			AS MasterBuGuid,
	[ItemGUID]			AS MasterBiGuid,
	[buCust_Name]		AS CuName,	
	[CustGuid]			AS MasterBuCustomerGuid,
	[CustomerNumber]	AS MasterCustSubNum,
	[ManGUID]			AS ManGUID,
	--[buTotal] + (CASE ( @ShowDiscount | @DetDiscExtra)WHEN 1 THEN 0 ELSE ([buTotalExtra] - [buTotalDisc]-[TotalBonusDisc]) END ) + 
	--	(CASE @ShowVAT WHEN 0 THEN  [buVat] ELSE 0 END) + (CASE @ShowSalesTax WHEN 0 THEN [buTotalSalesTax] ELSE 0 END) AS MasterBuTotalPrice,
	TotalPrice AS MasterBuTotalPrice,
	[buTotalExtra]		AS MasterBuTotalExtra,
	[buTotalDisc] + [TotalBonusDisc]		AS MasterBuTotalDisc,
	[buVat]		AS MasterBuTotalVat,
	[buTotalSalesTax] AS MasterBuTotalSalesTax,
	[buFirstPay]  As MasterBuFirstPay , 
	([TotalQty])	AS MasterBuTotalQty,
	[TotalQty2] AS MasterBuTotalQty2,
	[TotalQty3] AS MasterBuTotalQty3,
	[TotalBonusQnt] /[UnitFact] AS MasterBuTTotalBounsQty,
	
	--[buTotal]
	--+ (CASE ( @ShowDiscount | @DetDiscExtra)WHEN 0 THEN 0 ELSE ([buTotalExtra] - [buTotalDisc] -[TotalBonusDisc]) END )
	--+ (CASE @ShowVAT WHEN 0 THEN  0 ELSE [buVat] END) + (CASE @ShowSalesTax WHEN 0 THEN [buTotalSalesTax] ELSE 0 END)
	NetTotalPrice AS MasterBuNetPrice ,
	--Bill.Total + (m_ShowDiscount || m_shwDED ? Bill.ExtraVal - Bill.DiscVal : 0) + (m_bShowVAT ? Bill.VatVal : 0);
	
	[buPayType],	
	[buCheckTypeGuid],
	[buType],
	
	(CASE [buPayType] WHEN 0 THEN [buTotal]
		+ (CASE ( @ShowDiscount | @DetDiscExtra)WHEN 1 THEN 0 ELSE ([buTotalExtra] - [buTotalDisc]-[TotalBonusDisc])  END )
		+ (CASE @ShowVAT WHEN 0 THEN  [buVat] ELSE 0 END) + (CASE @ShowSalesTax WHEN 0 THEN [buTotalSalesTax] ELSE 0 END)
	ELSE 0 END),--TOTAL CASH
	
	(CASE WHEN (ISNULL([buCheckTypeGuid],0x0) = 0x0 ) OR (@ShowLoterPaper = 0) THEN  
		(CASE [buPayType] WHEN 0 THEN 0 ELSE [buTotal]
		+ (CASE ( @ShowDiscount | @DetDiscExtra)WHEN 1 THEN 0 ELSE ([buTotalExtra] - [buTotalDisc]-[TotalBonusDisc]) END ) 
		+ (CASE @ShowVAT WHEN 0 THEN  [buVat] ELSE 0 END) + (CASE @ShowSalesTax WHEN 0 THEN [buTotalSalesTax] ELSE 0 END)
		END )
	ELSE 0 END),--TOTAL LATER
	(CASE [buPayType] WHEN 0 THEN [buTotalExtra] ELSE 0 END ),
	(CASE [buPayType] WHEN 0 THEN 0 ELSE [buTotalExtra] END ), 
	(CASE [buPayType] WHEN 0 THEN [buTotalDisc] ELSE 0 END ),
	(CASE [buPayType] WHEN 0 THEN 0 ELSE [buTotalDisc] END ), 
	(CASE [buPayType] WHEN 0 THEN [buVat] ELSE 0 END ),
	(CASE [buPayType] WHEN 0 THEN 0 ELSE [buVat] END ),
	BuSortFlag,
	BuNum,
	
	(CASE [buCheckTypeGuid] WHEN 0x0 THEN 0 ELSE [buTotal]
	+ (CASE ( @ShowDiscount | @DetDiscExtra)WHEN 1 THEN 0 ELSE ([buTotalExtra] - [buTotalDisc]-[TotalBonusDisc]) END ) 	
	+ (CASE @ShowVAT WHEN 0 THEN  [buVat] ELSE 0 END) + (CASE @ShowSalesTax WHEN 0 THEN [buTotalSalesTax] ELSE 0 END)
	 END)--TOTAL NOTES
	FROM    (SELECT 
	 SUM(biQty / UnitFact) OVER (PARTITION BY BuNumber ORDER BY BuDate)AS TotalQty 
				,SUM(biQty2) OVER (PARTITION BY BuNumber ORDER BY BuDate)AS TotalQty2
				,SUM(biQty3) OVER (PARTITION BY BuNumber ORDER BY BuDate)AS TotalQty3 
				,SUM(biBonusQnt) OVER (PARTITION BY BuNumber ORDER BY BuDate)As TotalBonusQnt
				,SUM(BiBonusDisc) OVER (PARTITION BY BuNumber ORDER BY BuDate)As TotalBonusDisc
				,SUM((CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
				(
					(CASE @AddDX WHEN 1 THEN [biPrice] ELSE 
							(
							  ([biPrice] * (CASE [BuTotal] WHEN 0 THEN 0 ELSE  ([BuTotal] - ([buTotalDisc] - [BuItemsDisc])+ ([buTotalExtra] - [BuItemsExtra])) / [BuTotal]END))
							  + 
							  (CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] - [biDiscount] - [BiBonusDisc]) / ([biQty] / [UnitFact]) END)
							)
					END )
					* ([biQty] / [UnitFact])
				) + CASE @ShowVAT WHEN 1 THEN 0 ELSE biVat END
				END)) OVER (PARTITION BY BuNumber ORDER BY BuDate) AS NetTotalPrice
				
				,SUM((CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
				(
					(CASE @AddDX WHEN 0 THEN [biPrice] ELSE 
							(
							  ([biPrice] * (CASE [BuTotal] WHEN 0 THEN 0 ELSE  ([BuTotal] - ([buTotalDisc] - [BuItemsDisc])+ ([buTotalExtra] - [BuItemsExtra])) / [BuTotal]END))
							  + 
							  (CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] - [biDiscount] - [BiBonusDisc]) / ([biQty] / [UnitFact]) END)
							)
					END )
					* ([biQty] / [UnitFact])
				) + CASE @ShowVAT WHEN 1 THEN 0 ELSE biVat END
				END)) OVER (PARTITION BY BuNumber ORDER BY BuDate) AS TotalPrice
				,ROW_NUMBER() OVER (PARTITION BY BuNumber ORDER BY BuDate) AS RowNumber
					,*
	         FROM   [#AllResult]
	         ) AS a
			 LEFT JOIN bt000 BT ON BT.GUID = a.buType
	WHERE   a.RowNumber = 1
	ORDER BY 
	BuDate,BuSortFlag,BuNum,BuNumber,BiNumber
	
	-- Resultset[0]: Master Rows
	SELECT 
		m.* , b.[PriorityNum] 
	FROM 
		[#MasterResult] m 
		INNER JOIN [#BillsTypesTbl] b ON m.BuType = b.[TypeGuid]
	ORDER BY 
		MasterBuDate, b.[PriorityNum], b.[SortNumber],/*BuSortFlag,*/ BuNum, b.[SamePriorityOrder], MasterBuGuid
	----------------------------------------------------Details Result
	CREATE TABLE [#DetailsResult]( 
		BuFormatedNumber			[NVARCHAR](256),
		BuDate						[DATETIME], 
		BuTime						[nvarchar](8),
		BuCuName					[NVARCHAR](256),
		CustSubNum					[NVARCHAR](256),
		BuCustomerGuid				[UNIQUEIDENTIFIER],
		Dir							[INT],
		UnPosted					[BIT],
		ParentGuid					[UNIQUEIDENTIFIER],
		ItemGuid					[UNIQUEIDENTIFIER],
		MatGuid						[UNIQUEIDENTIFIER],
		ManGUID						[UNIQUEIDENTIFIER],
		MtCode						[NVARCHAR](256),
		MtName						[NVARCHAR](256),
		Qty							[FLOAT],
		Bouns						[FLOAT],
		Unit						[NVARCHAR](256),
		Notes						[NVARCHAR](MAX),
		Qty2						[FLOAT],
		Unit2						[NVARCHAR](256),
		Qty3						[FLOAT],
		Unit3						[NVARCHAR](256),
		biPrice						[FLOAT],
		buTotal						[FLOAT],
		INGLEVALUE					[FLOAT],
		TotalPrice					[FLOAT],
		Discount					[FLOAT],
		BounsDisc					[FLOAT],
		Extra						[FLOAT],
		VatVal						[FLOAT],
		CostGUID					[UNIQUEIDENTIFIER],
		CostCode					[NVARCHAR](256),
		CostName					[NVARCHAR](256),
		CostLatinName				[NVARCHAR](256),
		DiscountRate				[FLOAT],
		ExtraRate					[FLOAT],
		BiCash						[FLOAT],
		BiLater						[FLOAT],
		BuType						[UNIQUEIDENTIFIER],
		BuSortFlag					[INT],
		BuNum						[INT],
		BuCheckTypeGuid				[UNIQUEIDENTIFIER],
		BuNoteValue					[FLOAT],
		[PriorityNum]				[INT],
		[SortNumber]				INT
	)
	INSERT INTO [#DetailsResult]
	SELECT 
	[buFormatedNumber]	AS BuFormatedNumber,
	[BuDate]			AS BuDate,
	[BuTime]			AS BuTime,
	[buCust_Name]		AS BuCuName,
	[CustomerNumber]	AS CustSubNum,
	[CustGuid]			AS BuCustomerGuid,
	(CASE BT.[bIsInput] WHEN 1 THEN 1 ELSE -1 END )		AS Dir,
	(CASE [buIsPosted] WHEN 1 THEN 0 ELSE 1 END )		AS UnPosted,
	[buNumber]			AS ParentGuid,
	[ItemGUID]			AS ItemGuid,
	[biMatPtr]			AS MatGuid,
	[ManGUID]			AS ManGUID,
	[Mtcode]			As MtCode,
	[mtName]			As MtName,
	[biQty]	/[UnitFact]			AS Qty,
	[biBonusQnt]/[UnitFact]		AS Bouns,
	[mtUnityName]		AS Unit,
	[biNotes]			AS Notes,
	[biQty2]			AS Qty2,
	[mtUnit2]			AS Unit2,
	[biQty3]			AS Qty3,
	[mtUnit3]			AS Unit3,
	[biPrice],
	[buTotal],
	--if (bu_Total != 0)
	--			ratio = (bu_Total - DISC + EXTRA) / bu_Total;
	--		ldouble Vq = 0;
	--		if (br.Qnt != 0)
	--			Vq = (br.ExtraVal - (br.DiscVal + br.BonusDisc)) / (br.Qnt / br.UnitFact);
	--		if (m_AddDX)
	--			br.Price = br.Price * ratio + Vq;
    0,
	(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
				(
					(CASE @AddDX WHEN  0 THEN [biPrice]* ([biQty] / [UnitFact]) ELSE 
							([biPrice] * ([biQty] / [UnitFact])) + TotalExtraPercent + biExtra
							 -TotalDiscountPercent- biDiscount - BiBonusDisc		
					END )		
				) + CASE @ShowVAT WHEN 1 THEN 0 ELSE biVat END
	 END ) AS TotalPrice,

	[biDiscount]		AS Discount,
	[BiBonusDisc]		AS BounsDisc,
	[biExtra]			AS Extra,
	[biVat]				AS VatVal,
	ISNULL([CostGUID], 0x0) As CostGUID,
	[CostCode],
	[CostName],
	[CostLatinName],
	(CASE [biPrice] WHEN 0 THEN 0 ELSE  (CASE [biQty] WHEN 0 THEN 0 ELSE
	[biDiscount] / ( ([biQty]/[UnitFact] )* [biPrice] )  END)END)	AS DiscountRate,
	(CASE [biPrice] WHEN 0 THEN 0 ELSE  (CASE [biQty] WHEN 0 THEN 0 ELSE
	[biExtra] / ( ([biQty]/[UnitFact] )* [biPrice] )  END)END)	AS ExtraRate,
	
	(CASE [buPayType] WHEN 0 THEN  
		(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
			(
					(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
						(
							(CASE @AddDX WHEN  0 THEN [biPrice] ELSE 
							(
							  ([biPrice] * (CASE [BuTotal] WHEN 0 THEN 0 ELSE  ([BuTotal] - ([buTotalDisc] - [BuItemsDisc])+ ([buTotalExtra] - [BuItemsExtra])) / [BuTotal]END))
							  + 
							  (CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] - [biDiscount] - [BiBonusDisc]) / ([biQty] / [UnitFact]) END)
							)
							END )
							* ([biQty] / [UnitFact])
						)
					 END)
			)
		END)
	ELSE 0 END ),--CASH
	
	(CASE WHEN (ISNULL([buCheckTypeGuid],0x0) = 0x0 ) OR (@ShowLoterPaper = 0) THEN 
		(CASE [buPayType] WHEN 0 THEN 0 ELSE 
			(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
			(
				(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
					(
						(CASE @AddDX WHEN  0 THEN [biPrice] ELSE 
						(
							([biPrice] * (CASE [BuTotal] WHEN 0 THEN 0 ELSE  ([BuTotal] - ([buTotalDisc] - [BuItemsDisc])+ ([buTotalExtra] - [BuItemsExtra])) / [BuTotal]END))
							+ 
							(CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] - [biDiscount] - [BiBonusDisc]) / ([biQty] / [UnitFact]) END)
						)
						END )
					* ([biQty] / [UnitFact])
					)END )
			)END )
		END )
	ELSE 0 END),--LATER
	
	[buType],
	BuSortFlag,
	BuNum,
	[buCheckTypeGuid],
	
	(CASE [buCheckTypeGuid] WHEN 0x0 THEN 0 ELSE 
			(CASE [biMatPtr] WHEN 0x0 THEN 0 ELSE 
				(
					(CASE @AddDX WHEN  0 THEN [biPrice] ELSE 
					(
						([biPrice] * (CASE [BuTotal] WHEN 0 THEN 0 ELSE  ([BuTotal] - ([buTotalDisc] - [BuItemsDisc])+ ([buTotalExtra] - [BuItemsExtra])) / [BuTotal]END))
						+ 
						(CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] - [biDiscount] - [BiBonusDisc]) / ([biQty] / [UnitFact]) END)
					)
					END )
					
					* ([biQty] / [UnitFact])
				)
		END )
	 END),
	[PriorityNum],
	[SortNumber] 
	FROM [#AllResult]
	LEFT JOIN bt000 BT ON BT.GUID = buType
	ORDER BY 
	BuDate,BuSortFlag,BuNum,BuNumber,BiNumber
	UPDATE #DetailsResult
	SET INGLEVALUE= CASE Qty WHEN 0 THEN 0 ELSE TotalPrice / Qty END
	-- Resultset[1]: Details Rows
	IF (@IsCalledByWeb = 0)
	BEGIN
		SELECT * FROM [#DetailsResult]
	END
	--ELSE -- (@IsCalledByWeb = 1)
	--BEGIN
	-- Sending Details Rows to output is delayed
	--END
	----------------------------------------------------Footer Result 
	CREATE TABLE [#FooterResult]( 
		BillTypeName			[NVARCHAR](256),
		Total					[FLOAT],
		Extra					[FLOAT],
		Discount				[FLOAT],
		Vat					    [FLOAT],
		SalesTax				[FLOAT],
		TotalCash				[FLOAT],
		TotalLater				[FLOAT],
		Qty					    [FLOAT],
		Bouns					[FLOAT],
		BuMinDate			    [DATETIME],
		BuGuid			        [UNIQUEIDENTIFIER],
		BuSortFlag				[INT],
		BuNum					[INT],
		BuType				    [UNIQUEIDENTIFIER],
		Dir						[INT],
		[PriorityNum]			INT, 
		[SortNumber]			INT
	)
	
	CREATE TABLE [#ResultDiscDetails](
		[buType] [UNIQUEIDENTIFIER],
		[buGUID] [UNIQUEIDENTIFIER],
		[AccCode] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[AccName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[DiscVal] [FLOAT],
		[ExtraVal] [FLOAT]
	)
	IF (@ShowDiscount = 1) OR (@DetDiscExtra = 1)
	BEGIN
	  INSERT INTO [#ResultDiscDetails] EXEC RepGetDiscDetails  @CurrencyPtr 
	END

	 SELECT 	
		[buType]			AS BUTYPE,
		SUM ([DiscVal])		AS Discount,
		SUM ([ExtraVal])	AS Extra,
		NULL				AS [AccCode],
		NULL				AS [AccName] INTO #ResDiscExtraTotal 
	  FROM [#ResultDiscDetails]
	  GROUP BY 
		[buType] 
	
		INSERT INTO [#FooterResult]
		SELECT 
			(CASE @Lang WHEN 0 THEN MIN(BT.[Name]) ELSE CASE MIN(BT.[LatinName]) WHEN '' THEN MIN(BT.[Name]) ELSE MIN(BT.[LatinName]) END END) AS BillTypeName,
			SUM([TotalPrice]) 	AS Total,
			SUM(D.Extra) + (CASE WHEN @MatGuid = 0x THEN ISNULL(MIN(res.Extra), 0) ELSE 0 END) AS Extra,
			SUM(D.Discount) + (CASE WHEN @MatGuid = 0x THEN ISNULL(MIN(res.Discount), 0) ELSE 0 END) AS Discount,
			SUM(VatVal)												AS Vat,
			0														AS SalesTax,
			SUM(BiCash) 														AS TotalCash,
			SUM(BiLater)														AS TotalLater,
			SUM([Qty])											AS Qty,
			SUM([Bouns])										AS Bouns,
			Min(BuDate) AS BuMinDate,
			Min(ParentGuid) AS BuGuid,
			MIN(BuSortFlag)  AS BuSortFlag,
			MIN(BuNum)		AS BuNum,
			D.BuType AS BuType,
			(CASE MIN (CAST(BT.bIsInput AS INT)) WHEN 0 THEN -1 ELSE 1 END),
			MIN([PriorityNum]), 
			MIN([SortNumber])
		FROM   
			#DetailsResult D
			LEFT JOIN bt000 BT ON BT.GUID = D.BuType
			LEFT JOIN #ResDiscExtraTotal  res ON res.BUTYPE = D.BuType
		GROUP BY 
			D.BuType
		ORDER BY 
			BuMinDate, BuSortFlag, BuNum, BuGuid
	-- END
	-- Insert Grand Total 
	INSERT INTO [#FooterResult]
	SELECT 
	'',
	ISNULL(SUM(Total * Dir),0) ,
	ISNULL(SUM(Extra * Dir),0) ,
	ISNULL(SUM(Discount * Dir),0) ,
	ISNULL(SUM(Vat * Dir),0) ,
	ISNULL(SUM(SalesTax * Dir), 0),
	ISNULL(SUM(TotalCash * Dir),0) ,
	ISNULL(SUM(TotalLater * Dir) ,0),
	ISNULL(SUM(Qty * Dir),0) ,
	ISNULL(SUM(Bouns * Dir),0) ,
	GETDATE() ,
	0x0,
	-1,
	-1,
	0x0,
	-1, -1, -1
	FROM [#FooterResult]	

	IF (@IsCalledByWeb = 0)
	BEGIN
		-- Resultset[2]: Footer
		SELECT * FROM 	[#FooterResult]
		ORDER BY 
			BuMinDate,/*BuSortFlag,*/PriorityNum, [SortNumber], BuNum, BuGuid
	END
	
	----------------------------------------------------Show Discount
	-- Resultset[3]: Discount/Extra Details
	IF (@ShowDiscount = 1) OR (@DetDiscExtra = 1)
	BEGIN
		IF (@IsCalledByWeb = 0) 
		BEGIN
			IF (@DetDiscExtra = 1)
			BEGIN 
				SELECT 
					[buGUID]		AS ParentGuid,
					[DiscVal]		AS Discount,
					[ExtraVal]		AS Extra,
					[AccCode],
					[AccName]
				FROM [#ResultDiscDetails]
			END 
			ELSE
			BEGIN 
				SELECT 	
					[buGUID]			AS ParentGuid,
					SUM ([DiscVal])		AS Discount,
					SUM ([ExtraVal])	AS Extra,
					NULL				AS [AccCode],
					NULL				AS [AccName]
				FROM [#ResultDiscDetails]
				GROUP BY 
					[buGUID]
			END
		END
		ELSE -- (@IsCalledByWeb = 1)
		BEGIN
			-- Resultset[1]: Details Rows Merged with Resultset[3] Discount/Extra
			IF (@DetDiscExtra = 1)
			BEGIN 
				SELECT 
					BuFormatedNumber,
					BuDate,
					BuTime,
					BuCuName,
					CustSubNum,
					BuCustomerGuid,
					Dir,
					UnPosted,
					ParentGuid,
					ItemGuid,
					MatGuid,
					ManGUID,
					MtCode,
					MtName,
					Qty,
					Bouns,
					Unit,
					Notes,
					Qty2,
					Unit2,
					Qty3,
					Unit3,
					[biPrice],
					[buTotal],
					INGLEVALUE,
					TotalPrice,
					Discount,
					BounsDisc,
					Extra,
					VatVal,
					[CostGUID],
					[CostCode],
					[CostName],
					[CostLatinName],
					DiscountRate,
					ExtraRate,
					BiCash,
					BiLater,
					BuType,
					BuSortFlag,
					BuNum,
					[buCheckTypeGuid],
					BuNoteValue,
					'details' AS Resultset,
					NULL AS DiscExtraRes_ParentGuid,
					NULL AS DiscExtraRes_Discount,
					NULL AS DiscExtraRes_Extra,
					NULL AS DiscExtraRes_AccCode,
					NULL AS DiscExtraRes_AccName
				FROM [#DetailsResult]
				UNION ALL
				SELECT
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					[buGUID]
					,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					'disc-extra' AS Resultset,
					[buGUID]		AS DiscExtraRes_ParentGuid,
					[DiscVal]		AS DiscExtraRes_Discount,
					[ExtraVal]		AS DiscExtraRes_Extra,
					[AccCode]		AS DiscExtraRes_AccCode,
					[AccName]		AS DiscExtraRes_AccName
				FROM [#ResultDiscDetails]
			END
			ELSE
			BEGIN
				SELECT 
					BuFormatedNumber,
					BuDate,
					BuTime,
					BuCuName,
					CustSubNum,
					BuCustomerGuid,
					Dir,
					UnPosted,
					ParentGuid,
					ItemGuid,
					MatGuid,
					ManGUID,
					MtCode,
					MtName,
					Qty,
					Bouns,
					Unit,
					Notes,
					Qty2,
					Unit2,
					Qty3,
					Unit3,
					[biPrice],
					[buTotal],
					INGLEVALUE,
					TotalPrice,
					Discount,
					BounsDisc,
					Extra,
					VatVal,
					[CostGUID],
					[CostCode],
					[CostName],
					[CostLatinName],
					DiscountRate,
					ExtraRate,
					BiCash,
					BiLater,
					BuType,
					BuSortFlag,
					BuNum,
					[buCheckTypeGuid],
					BuNoteValue,
					'details' AS Resultset,
					NULL AS DiscExtraRes_ParentGuid,
					NULL AS DiscExtraRes_Discount,
					NULL AS DiscExtraRes_Extra,
					NULL AS DiscExtraRes_AccCode,
					NULL AS DiscExtraRes_AccName
				FROM [#DetailsResult]
				UNION ALL
				SELECT
					NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					[buGUID]
					,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
					'disc-extra'		AS Resultset,
					[buGUID]			AS DiscExtraRes_ParentGuid,
					SUM ([DiscVal])		AS DiscExtraRes_Discount,
					SUM ([ExtraVal])	AS DiscExtraRes_Extra,
					NULL				AS DiscExtraRes_AccCode,
					NULL				AS DiscExtraRes_AccName
				FROM [#ResultDiscDetails]
				GROUP BY 
					[buGUID]
			END
			-- Resultset[2]: Footer
			SELECT * FROM 	[#FooterResult]
			ORDER BY 
				BuMinDate,BuSortFlag,BuNum,BuGuid 
			-- DUMMY (to keep Resultset[3] in its position)
			SELECT TOP 0 0x00 AS ParentGuid, 0 AS Discount, 0 AS Extra, NULL AS [AccCode], NULL AS [AccName]
		END
	END
	ELSE IF (@IsCalledByWeb > 0)
	BEGIN
		-- Resultset[1]: Details Rows Merged with Disc Extra Resultset Schema
		SELECT 
			BuFormatedNumber,
			BuDate,
			BuTime,
			BuCuName,
			CustSubNum,
			BuCustomerGuid,
			Dir,
			UnPosted,
			ParentGuid,
			ItemGuid,
			MatGuid,
			ManGUID,
			MtCode,
			MtName,
			Qty,
			Bouns,
			Unit,
			Notes,
			Qty2,
			Unit2,
			Qty3,
			Unit3,
			[biPrice],
			[buTotal],
			INGLEVALUE,
			TotalPrice,
			Discount,
			BounsDisc,
			Extra,
			VatVal,
			[CostCode],
			[CostName],
			[CostLatinName],
			DiscountRate,
			ExtraRate,
			BiCash,
			BiLater,
			BuType,
			BuSortFlag,
			BuNum,
			[buCheckTypeGuid],
			BuNoteValue,
			'details' AS Resultset,
			NULL AS DiscExtraRes_ParentGuid,
			NULL AS DiscExtraRes_Discount,
			NULL AS DiscExtraRes_Extra,
			NULL AS DiscExtraRes_AccCode,
			NULL AS DiscExtraRes_AccName
		FROM [#DetailsResult]
		-- Resultset[2]: Footer
		SELECT * FROM 	[#FooterResult]
		ORDER BY 
			BuMinDate,BuSortFlag,BuNum,BuGuid 
		-- Resultset[3]: <DUMMY> Discount/Extra Details
		SELECT TOP 0 0x00 AS ParentGuid, 0 AS Discount, 0 AS Extra, NULL AS [AccCode], NULL AS [AccName]
	END
	-----------------------------------------------------------------------------------------------------------------------
	IF (@ShowLoterPaper = 1)	
	BEGIN
		CREATE TABLE [#ResultCheckType](
			[buCheckTypeGUID] [UNIQUEIDENTIFIER],
			[Name] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[LatinName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[Index] int IDENTITY
		)
		INSERT INTO [#ResultCheckType]
		SELECT DISTINCT nt.[GUID] , nt.[Name], nt.[LatinName] 
		FROM nt000 nt INNER JOIN  [#Result] rs on rs.[buCheckTypeGUID] = nt.[GUID]
	
		--Check Desc
		SELECT * FROM [#ResultCheckType]
		--Check Values
		IF(@MatGuid = 0x0) -- Multi matrial then get Data From Master Result
		BEGIN
			IF (@IsCalledByWeb = 0)
			BEGIN
				SELECT 
					Min(nt.[BuCheckTypeGuid]) AS BuCheckTypeGuid,
					Min(MasterResult.[BuType]) AS BuTypeGuid,
					Min(nt.[Index]) AS [Index],
					MIN(nt.[Name]) AS Name, 
					MIN( nt.[LatinName] ) AS LatinName,
					ISNULL(SUM([BuNoteValue]),0) AS Val,
					MIN(MasterResult.Dir) AS Dir
				FROM   [#MasterResult] MasterResult
					INNER JOIN [#ResultCheckType] nt on MasterResult.[buCheckTypeGUID] = nt.[buCheckTypeGUID]
				GROUP BY 
					[BuType],
					MasterResult.[BuCheckTypeGuid]
			END
			ELSE -- (@IsCalledByWeb = 1)
			BEGIN
				-- Merging resultset[2] with resultset[5]
				SELECT
					BillTypeName,
					Total,
					Extra,
					Discount,
					Vat,
					TotalCash,
					TotalLater,
					Qty,
					Bouns,
					BuMinDate,
					BuGuid,
					BuSortFlag,
					BuNum,
					BuType,		
					ft.Dir,
					ISNULL(rs5.BuCheckTypeGuid, 0x00) AS BuCheckTypeGuid,
					rs5.[Index],			
					rs5.Name AS NoteName,
					rs5.LatinName AS NoteLatinName,
					rs5.Val AS NoteVal
				FROM 	[#FooterResult] ft
					LEFT JOIN  (
						SELECT 
							Min(nt.[BuCheckTypeGuid]) AS BuCheckTypeGuid,
							Min(MasterResult.[BuType]) AS BuTypeGuid,
							Min(nt.[Index]) AS [Index],
							MIN(nt.[Name]) AS Name, 
							MIN( nt.[LatinName] ) AS LatinName,
							ISNULL(SUM([BuNoteValue]),0) AS Val,
							MIN(MasterResult.Dir) AS Dir
							FROM   [#MasterResult] MasterResult
							INNER JOIN [#ResultCheckType] nt on MasterResult.[buCheckTypeGUID] = nt.[buCheckTypeGUID]
							GROUP BY 
							[BuType],
							MasterResult.[BuCheckTypeGuid]
					) rs5 ON ft.BuType = rs5.BuTypeGuid
				ORDER BY 
					BuMinDate,
					BuSortFlag,
					BuNum,
					BuGuid 
			END
		END
		ELSE	 -- One Matrial then get Data From Details Result
		BEGIN
			IF (@IsCalledByWeb = 0)
			BEGIN
				SELECT 
					Min(nt.[BuCheckTypeGuid]) AS BuCheckTypeGuid,
					Min(DetailsResult.[BuType]) AS BuTypeGuid,
					Min(nt.[Index]) AS [Index],
					MIN(nt.[Name]) AS Name, 
					MIN( nt.[LatinName] ) AS LatinName,
					ISNULL(SUM([BuNoteValue]),0) AS Val,
					MIN(DetailsResult.Dir) AS Dir
				FROM   [#DetailsResult] DetailsResult
					INNER JOIN [#ResultCheckType] nt on DetailsResult.[buCheckTypeGUID] = nt.[buCheckTypeGUID]
				GROUP BY 
					[BuType],
					DetailsResult.[BuCheckTypeGuid]
			END
			ELSE -- @IsCalledByWeb = 1
			BEGIN
				-- Merging resultset[2] with resultset[5]
				SELECT
					BillTypeName,
					Total,
					Extra,
					Discount,
					Vat,
					TotalCash,
					TotalLater,
					Qty,
					Bouns,
					BuMinDate,
					BuGuid,
					BuSortFlag,
					BuNum,
					BuType,		
					ft.Dir,
					ISNULL(rs5.BuCheckTypeGuid, 0x00) AS BuCheckTypeGuid,
					rs5.[Index],			
					rs5.Name AS NoteName,
					rs5.LatinName AS NoteLatinName,
					rs5.Val AS NoteVal
				FROM 	[#FooterResult] ft
					LEFT JOIN  (
						SELECT 
							Min(nt.[BuCheckTypeGuid]) AS BuCheckTypeGuid,
							Min(DetailsResult.[BuType]) AS BuTypeGuid,
							Min(nt.[Index]) AS [Index],
							MIN(nt.[Name]) AS Name, 
							MIN( nt.[LatinName] ) AS LatinName,
							ISNULL(SUM([BuNoteValue]),0) AS Val,
							MIN(DetailsResult.Dir) AS Dir
						FROM   [#DetailsResult] DetailsResult
							INNER JOIN [#ResultCheckType] nt on DetailsResult.[buCheckTypeGUID] = nt.[buCheckTypeGUID]
						GROUP BY 
							[BuType],
							DetailsResult.[BuCheckTypeGuid]
					) rs5 ON ft.BuType = rs5.BuTypeGuid
				ORDER BY 
					BuMinDate,
					BuSortFlag,
					BuNum,
					BuGuid 
			END
		END
	END
	ELSE IF (@IsCalledByWeb > 0)
	BEGIN
		-- Resultset[4]: <DUMMY> Notes Lookup Data {
		SELECT TOP 0
			0x00 AS [buCheckTypeGUID],
			'' AS [Name],
			'' AS [LatinName],
			0 AS [Index]
		-- }
		-- Resultset[5]: Dummy Data merged with resultset[2]
		SELECT
			BillTypeName,
			Total,
			Extra,
			Discount,
			Vat,
			TotalCash,
			TotalLater,
			Qty,
			Bouns,
			BuMinDate,
			BuGuid,
			BuSortFlag,
			BuNum,
			BuType,		
			ft.Dir,
			CONVERT(uniqueidentifier, 0x00) AS BuCheckTypeGuid,
			0 AS [Index],
			'' AS NoteName, 
			'' AS NoteLatinName,
			0 AS NoteVal
		FROM 	[#FooterResult] ft
		ORDER BY 
			BuMinDate,
			BuSortFlag,
			BuNum,
			BuGuid 
	END
	-----------------------------------------------------------------------------------------------------------------------
	
	IF (@IsAdmin <> 1) OR (@IsCalledByWeb > 0) 
		SELECT * FROM [#SecViol]

###################################################################################
CREATE PROCEDURE RepGetDiscDetails
	@CurrencyPtr 		[UNIQUEIDENTIFIER]
AS
	CREATE TABLE [#T_Result](
						[buType] [UNIQUEIDENTIFIER],
						[buGUID] [UNIQUEIDENTIFIER],
						[AccCode] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
						[AccName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
						[DiscVal] [FLOAT],
						[ExtraVal] [FLOAT],
						[FixedCurrencyFact] [FLOAT]
					)

	INSERT INTO [#T_Result] 
		SELECT DISTINCT
				[buType],[buNumber], [acCode], [acName],
				[diDiscount] , [diExtra],
				[dbo].[fnCurrency_fix](1,[d].[diCurrencyPtr], [d].[diCurrencyVal], @CurrencyPtr, [buDate])
				FROM [vwDi] AS [d]
					INNER JOIN (SELECT DISTINCT [buType] , [buNumber],[buDate]  FROM [#Result]) AS  [b] ON [d].[diParent] = [b].[buNumber]	
					LEFT JOIN [vwAc] AS [ac] ON [acGuid] = [diAccount]
					
		 
	EXEC [prcCheckSecurity]  @Result = '#T_Result'

	SELECT 	[buType],[buGUID],[AccCode],[AccName],[DiscVal]*[FixedCurrencyFact] AS [DiscVal],[ExtraVal] *[FixedCurrencyFact] AS [ExtraVal] FROM [#T_Result] ORDER BY [buGuid], [ExtraVal], [DiscVal]
###################################################################################
#END