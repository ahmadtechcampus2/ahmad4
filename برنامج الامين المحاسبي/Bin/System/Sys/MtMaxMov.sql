################################################################################
## ÇáãæÇÏ ÇáÃßËÑ ÍÑßÉ
CREATE PROCEDURE repMatMaxMove 
	@StartDate AS [DATETIME],     --ÊÇÑíÎ ÇáÈÏÇíÉ 
	@EndDate AS [DATETIME], 	  --ÊÇÑíÎ ÇáäåÇíÉ 
	@Src AS [UNIQUEIDENTIFIER],   --áÇÆÍÉ ÇáãÕÇÏÑááÊÞÑíÑ 
	@Store AS [UNIQUEIDENTIFIER], --ÇáãÓÊæÏÚ 
	@Gr AS [UNIQUEIDENTIFIER], 	  --ÇáãÌãæÚÉ 
    @Acc AS [UNIQUEIDENTIFIER], 			--ÇáÍÓÇÈ 
	@Cost AS [UNIQUEIDENTIFIER], 			--ãÑßÒ ÇáßáÝÉ 
   	@CurPtr AS [UNIQUEIDENTIFIER],         --ÇáÚãáÉ 
    @CurVal AS [INT],			--ÇáÊÚÇÏá 
	@MatCondGuid AS [UNIQUEIDENTIFIER] = 0X00, 
	@Detailed		[BIT] = 0, 
	@ReportType		[INT] = 2, -- bill count 
	@UseUnit		TINYINT = 3 
AS 
	SET NOCOUNT ON 
	DECLARE @Sql NVARCHAR(max) 
	DECLARE @Col1 NVARCHAR(100) 
	DECLARE @Col2 NVARCHAR(100) 
	DECLARE @Col3 NVARCHAR(100) 
	DECLARE @Collect1	AS	[INT] = 0 
	DECLARE @Collect2	AS	[INT] = 0
	DECLARE @Collect3	AS	[INT] = 0
	-------------- 
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec][INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src 
	------------- 
	CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @Gr,-1,@MatCondGuid  
	---------------------------- 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER]) 
	INSERT INTO [#Cust] SELECT [GUID] from [fnGetCustsOfAcc] ( @Acc) 
	IF @Acc = 0x0 
		INSERT INTO [#Cust] SELECT 0x0 
	---------------------------- 
	CREATE TABLE [#Store] ( [Number] [UNIQUEIDENTIFIER]) 
	INSERT INTO  [#Store] select [GUID] from [fnGetStoresList]( @Store) 
	---------------------------- 
	CREATE TABLE [#Cost] ( [Number] [UNIQUEIDENTIFIER]) 
	INSERT INTO  [#Cost] select [GUID] from [fnGetCostsList]( @Cost) 
	IF @Cost = 0x0 
		INSERT INTO [#Cost] SELECT 0x0 
	---------------------------- 
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	CREATE TABLE #mat2 (
	mtGuid [UNIQUEIDENTIFIER], 
	mtName NVARCHAR(Max), 
	mtCode NVARCHAR(Max), 
	mtLatinName NVARCHAR(Max), 
	mtBarCode NVARCHAR(Max), 
	mtSpec NVARCHAR(Max), 
	mtQty FLOAT, 
	mtOrigin NVARCHAR(Max), 
	mtCompany NVARCHAR(Max), 
	mtType INT, 
	mtPos NVARCHAR(Max), 
	mtDim NVARCHAR(Max), 
	mtColor NVARCHAR(Max), 
	mtQuality NVARCHAR(Max), 
	mtModel NVARCHAR(Max), 
	mtProvenance NVARCHAR(Max), 
	grName NVARCHAR(Max),
	mtVAT FLOAT, 
	[mtDefUnitName] NVARCHAR(Max), 		                
	[mtDefUnitFact] FLOAT)
	INSERT INTO #mat2
	SELECT mt.mtGuid, 
				mtName, 
				mtCode, 
				mtLatinName, 
				mtBarCode, 
				mtSpec, 
				mtQty, 
				mtOrigin, 
				mtCompany, 
				mtType, 
				mtPos, 
				mtDim, 
				mtColor, 
				mtQuality, 
				mtModel, 
				mtProvenance, 
				grName,
				mtVAT, 
				CASE @useUnit WHEN 0 THEN [mtUnity]        
			           WHEN 1 then CASE [mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END      
			           WHEN 2 then CASE [mtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END       
			           ELSE CASE [mtDefUnit]   
			                       WHEN 1 THEN [mtUnity]       
					               WHEN 2 THEN [mtUnit2]       
					               ELSE [mtUnit3] END  
				END  [mtDefUnitName], 
					                
				CASE @UseUnit WHEN 0 THEN 1 
					WHEN 1 THEN CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END 
					WHEN 2 THEN CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END 
					ELSE CASE [mt].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END 
				END [mtDefUnitFact] 
				  
				 FROM vwMtGr mt INNER JOIN [#Mat] m ON m.[mtGUID] = mt.mtGuid 
	CREATE TABLE [#Result](  
		[biNumber] [INT], 
		[mtGUID] [UNIQUEIDENTIFIER], 
		[biQty] [FLOAT], 
		[biBonusQnt] [FLOAT], 
		[biUnitPrice] [FLOAT], 
		[biUnitDiscount] [FLOAT], 
		[biUnitExtra] [FLOAT], 
		[biCurrencyPtr] [UNIQUEIDENTIFIER],  
		[biCurrencyVal] [FLOAT],  
		[buDate] [DATETIME], 
		[btIsInput] [INT], --[BIT], 
		[btIsOutput] [INT], --[BIT], 
		[Security] [TINYINT], 
		[mtSecurity] [TINYINT], 
		[UserSecurity] [TINYINT]) 
	INSERT INTO [#Result] 
	SELECT 
		[Bill].[BiNumber], 
		[Bill].[biMatPtr], 
		[Bill].[biQty], 
		[Bill].[biBonusQnt], 
		CASE WHEN [src].[ReadPrice] >= [BuSecurity] THEN [Bill].[biUnitPrice] ELSE 0 END, 
		CASE WHEN [src].[ReadPrice] >= [BuSecurity] THEN [Bill].[biUnitDiscount] ELSE 0 END, 
		CASE WHEN [src].[ReadPrice] >= [BuSecurity] THEN [Bill].[biUnitExtra] ELSE 0 END, 
		[Bill].[biCurrencyPtr],  
		[Bill].[biCurrencyVal],  
		[Bill].[buDate], 
		[Bill].[btIsInput], 
		[Bill].[btIsOutput], 
		[Bill].[buSecurity], 
		[mt].[mtSecurity], 
		CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END 
	FROM 
		[vwExtended_bi] AS [Bill]  
		INNER JOIN [#Mat] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtGUID] 
		INNER JOIN [#Src] AS [src] ON [Bill].[buType] = [src].[Type] 
		INNER JOIN [#Cust] AS [cu] ON  [Bill].[buCustPtr] = [cu].[Number] 
		INNER JOIN [#Store] AS [stor] ON [Bill].[biStorePtr] = [stor].[Number] 
		INNER JOIN [#Cost] AS [cost] ON [Bill].[biCostPtr] = [cost].[Number] 
	WHERE 
		[Bill].[buDate] between @StartDate AND @EndDate 
		AND ( [bill].[buIsPosted] = 1) 
	---------------------------- 
	exec [prcCheckSecurity] 
	---------------------------- 
	
	DECLARE @col NVARCHAR(500) 
	SET @col = 'COUNT([Bill].[biNumber])'	-- bill count 
	IF (@ReportType = 1) 					-- qty 
		SET @col = ' SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) / [mt].[mtDefUnitFact] )),'  
			      
			       + 'SUM( [Bill].[btIsOutput]* (( [biQty] + [biBonusQnt]) / [mt].[mtDefUnitFact]) )' 
	ELSE IF (@ReportType = 3)				-- val 
		SET @col = ' SUM( [Bill].[btIsOutput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], ' + CASE @CurPtr WHEN 0X00 THEN '0X00' ELSE '''' + CAST(@CurPtr AS NVARCHAR(40)) + '''' END + ', [buDate] )))) 
			     + 
			     SUM( [Bill].[btIsInput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], ' + CASE @CurPtr WHEN 0X00 THEN '0X00' ELSE '''' + CAST(@CurPtr AS NVARCHAR(40)) + '''' END + ', [buDate])))) ' 
	---------------------------- 
	IF @Detailed > 0 
	BEGIN 
		---------------------------- 
		DECLARE @SQLStatement NVARCHAR(max) 
		SET @SQLStatement =  
		'SELECT  
			' + @col + ' MaxMove, 
			[mt].[mtName] AS [MtName],  
			
			--[mt].[grName] AS [GrName],  
			[mt].[mtDefUnitName] AS [Unity],  
			 
			--[Bill].[btIsInput] AS [btIN], 
			--[Bill].[btIsOutput] AS [btOUT], 
			SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) /  [mt].[mtDefUnitFact])) AS [SumIn],  
			SUM( [Bill].[btIsOutput] * (( [biQty] + [biBonusQnt]) / [mt].[mtDefUnitFact])) AS [SumOut],  
			SUM( [Bill].[btIsOutput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] ,  
			[biCurrencyPtr],  
			[biCurrencyVal],  
			' + CASE @CurPtr WHEN 0X00 THEN '0X00' ELSE '''' + CAST(@CurPtr AS NVARCHAR(40)) + '''' END + ', [buDate])))) AS [PriceOut],  
			
			SUM( [Bill].[btIsInput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] ,  
			[biCurrencyPtr],  
			[biCurrencyVal],  
			' + CASE @CurPtr WHEN 0X00 THEN '0X00' ELSE '''' + CAST(@CurPtr AS NVARCHAR(40)) + '''' END + ', [buDate])))) AS [PriceIn], 
			 
			SUM( [btIsInput]) AS [MoveCntIn],  
			SUM( [btIsOutput]) AS [MoveCntOUT]  
		FROM  
			[#Result] AS [Bill] INNER JOIN #mat2 AS [mt]   
			ON [Bill].[mtGuid] = [mt].[mtGUID]  
		GROUP BY  
			[mt].[mtName],  
			
			[mt].[mtDefUnitName] ' 
	
		EXEC (@SQLStatement) 
				 
		----------------------------  
		 
	END 
	ELSE 
	BEGIN 
		IF @Collect1 = 0 
			SELECT 
				mt.mtGuid, 
				mtName AS mName, 
				mtCode AS mCode, 
				mtLatinName AS mLatinName, 
				mtQty, 
				[mtDefUnitName] Unity, 
				SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END)) AS [SumIn], 
				SUM( [Bill].[btIsOutput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END)) AS [SumOut], 
				SUM( [Bill].[btIsOutput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], @CurPtr, [buDate] )))) AS [PriceOut], 
				SUM( [Bill].[btIsInput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], @CurPtr  , [buDate])))) AS [PriceIn], 
				SUM( [btIsInput]) AS [MoveCntIn], 
				SUM( [btIsOutput]) AS [MoveCntOUT] 
			FROM 
				[#Result] AS [Bill] INNER JOIN [#Mat2] AS [mt] ON [Bill].[mtGuid] = [mt].[mtGUID] 
			GROUP BY 
				mt.mtGuid, 
				mtName, 
				mtCode, 
				mtLatinName, 
				mtQty, 
				[mtDefUnitName] 
			ORDER BY 
				CASE @ReportType  
					WHEN 2 THEN COUNT([bill].[biNumber])  
					WHEN 3 THEN SUM( [Bill].[btIsOutput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], @CurPtr, [buDate] )))) + SUM( [Bill].[btIsInput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra] , [biCurrencyPtr], [biCurrencyVal], @CurPtr, [buDate]))))  
					WHEN 1 THEN SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END)) + SUM( [Bill].[btIsOutput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END))  
				END 
		ELSE 
		BEGIN 
			SET @Col1 = dbo.fnGetMatCollectedFieldName(@Collect1, CASE @Collect1 WHEN 11 THEN 'GR' ELSE 'mt' END) 
			SET @Col2 = dbo.fnGetMatCollectedFieldName(@Collect2, CASE @Collect2 WHEN 11 THEN 'GR' ELSE  'mt' END) 
			SET @Col3 = dbo.fnGetMatCollectedFieldName(@Collect3,  CASE @Collect3 WHEN 11 THEN 'GR' ELSE  'mt' END) 
			SET @Sql = 'SELECT  mt.' + @col1 + ' [Col1],' 
			
			IF @Collect2 > 0 
				SET @Sql = @Sql + @col2 + ' [Col2],' 
			IF @Collect3 > 0 
				SET @Sql = @Sql +  @col3 + ' [Col3],' 
			SET @Sql = @Sql + ' SUM( [Bill].[btIsInput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END)) AS [SumIn], 
				SUM( [Bill].[btIsOutput] * (( [biQty] + [biBonusQnt]) / CASE( [mt].[mtDefUnitFact]) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END)) AS [SumOut], 
				SUM( [Bill].[btIsOutput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra], 
				[biCurrencyPtr],  
				[biCurrencyVal],  
				''' + cast(@CurPtr as NVARCHAR(36)) +''', [buDate] )))) AS [PriceOut], 
				SUM( [Bill].[btIsInput] * ( [biQty] * ( [dbo].[fnCurrency_fix]( [biUnitPrice] - [biUnitDiscount] + [biUnitExtra], 
				[biCurrencyPtr], 
				[biCurrencyVal], 
				''' + cast(@CurPtr as NVARCHAR(36)) +'''  , [buDate])))) AS [PriceIn], 
				SUM( [btIsInput]) AS [MoveCntIn], 
				SUM( [btIsOutput]) AS [MoveCntOUT] 
			FROM 
				[#Result] AS [Bill] INNER JOIN #mat2 AS [mt]  
				ON [Bill].[mtGuid] = [mt].[mtGUID] ' +' 
			GROUP BY '	+ @col1  
			IF @Collect2 > 0 
				SET @Sql = @Sql + ',' + @col2  
			IF @Collect3 > 0 
				SET @Sql = @Sql + ',' + @col3  
			SET @Sql = @Sql + 'ORDER BY ' + @col + ' desc' 
			 
			
			EXEC (@Sql) 
			
		END 
	END 
	 
	SELECT * FROM [#SecViol] 
################################################################################
#END