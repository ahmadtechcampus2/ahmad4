########################################
CREATE PROCEDURE repMatSN
	@MatGUID 	[UNIQUEIDENTIFIER] ,
	@GroupGUID 	[UNIQUEIDENTIFIER] ,
	@StoreGUID 	[UNIQUEIDENTIFIER],  --0 all stores so don't check store or list of stores
	@Src		[UNIQUEIDENTIFIER] = 0X0,
	@Lang		[BIT] = 0,
	@MatCondGuid [UNIQUEIDENTIFIER] = 0X00,
	@CostGUID 		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate		DATETIME = '1/1/1980',
	@EndDate		DATETIME = '1/1/2070'
AS
	SET NOCOUNT ON
	DECLARE @CNT INT
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	--Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @Src--'ALL'
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGuid
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID
	
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	
	CREATE TABLE [#Result]
	(
		--[SN] 						[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[Id]						[INT] IDENTITY(1,1),
		[MatPtr]					[UNIQUEIDENTIFIER] ,
		[MtName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[biStorePtr]				[UNIQUEIDENTIFIER] ,
		[stName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buNumber]					[UNIQUEIDENTIFIER] ,
		[biPrice]					[FLOAT],
		[Security]					[INT],
		[UserSecurity] 				[INT],
		[UserReadPriceSecurity]		[INT],
		[BillNumber]				[FLOAT],
		[buDate]					[DATETIME],
		[buType]					[UNIQUEIDENTIFIER],
		[buBranch]					[UNIQUEIDENTIFIER],
		[buCust_Name]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buCustPtr]					[UNIQUEIDENTIFIER],
		[biCostPtr]					[UNIQUEIDENTIFIER],
		[MatSecurity] 				[INT],
		[biGuid]					[UNIQUEIDENTIFIER],
		[buDirection]				[INT]
	)

	SELECT [StoreGuid], [s].[Security],CASE @Lang WHEN 0 THEN [st].[Name] ELSE CASE [st].[LatinName]  WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END AS [stName] INTO [#StoreTbl2]
	FROM [#StoreTbl] AS [s]
		INNER JOIN  [st000] AS [st] ON  [st].[Guid] = 	[StoreGuid]
	
	SELECT [MatGuid]  , [m].[mtSecurity],[mt].[Name] AS [MtName] INTO [#MatTbl2]
	FROM [#MatTbl] AS [m]
		INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [MatGuid]
	WHERE [mt].[snFlag] = 1
	
	INSERT INTO [#Result]
	(
		[MatPtr],[MtName],[biStorePtr],[stName],[buNumber],				
		[biPrice],[Security],[UserSecurity],			
		[UserReadPriceSecurity],[BillNumber],			
		[buDate],[buType],[buBranch],[buCust_Name],			
		[buCustPtr],[biCostPtr],[MatSecurity],[biGuid],[buDirection]			
	)
	SELECT
		--[sn].[SN],
		[mtTbl].[MatGuid],
		[mtTbl].[MtName],
		[bu].[biStorePtr],
		[st].[stName],
		[bu].[buGUID],
		CASE WHEN [UserReadPriceSecurity] >= [bu].[BuSecurity] THEN 
		btAffectCostPrice * (([bu].[biPrice] * [biQty] + CASE [BUTOTAL] WHEN 0 THEN 0 
			ELSE ((btExtraAffectCost * ([buTotalExtra] - [buItemsExtra]- [DIExtra] ) - (btDiscAffectCost *([buTotalDisc] - [buItemsDisc] - [DIDiscount] - buBonusDisc ))* ( [biQty]*biprice/buTotal) ) +(btExtraAffectCost *(biExtra + TotalExtraPercent ))- (btDiscAffectCost * (biBonusDisc + biDiscount + TotalDiscountPercent))) END
			) - [bu].[biLCDisc] + [bu].[biLCExtra]) / ([biBonusQnt] + [biQty])
			  ELSE 0 END,
		[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[buNumber],
		[buDate],
		[buType],
		[buBranch],
		[buCust_Name],
		CASE WHEN (@Lang > 0) THEN [buCustPtr] ELSE NULL END,
		[biCostPtr],
		[mtTbl].[mtSecurity],[biGuid],[buDirection]
	FROM
		--[SN000] AS [sn] 
		[vwBUbi] AS [bu] --ON [bu].[biGUID] = [sn].[InGuid]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bu].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bu].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGuid] = [bu].[biStorePtr]
		INNER JOIN  [#CostTbl] AS [co] ON [co].[CostGUID] = [bu].[biCostPtr]
	WHERE
			[bu].[buIsPosted] != 0 AND
			[buDate] BETWEEN @StartDate	AND @EndDate			 
	ORDER BY
		[MatGuid],[buDate],[buSortFlag],[buNumber]
	---check sec
	CREATE CLUSTERED INDEX SERIN ON #RESULT(ID,[biGuid])
	
	EXEC [prcCheckSecurity]

	IF @Lang > 0
		UPDATE [r]
		SET [buCust_Name] = [LatinName] FROM [#Result] AS [r] INNER  JOIN [cu000] AS [Cu] ON [r].[buCustPtr] = [cu].[GUID] WHERE [LatinName] <> ''
	
	SELECT  MAX(CASE [buDirection] WHEN 1 THEN [Id] ELSE 0 END) AS ID ,SUM([buDirection]) AS cnt ,[sn].[ParentGuid] 
	INTO [#sn]
	FROM [snt000] AS [sn]
		INNER JOIN [#Result] [r] ON [sn].[biGuid] = [r].[biGuid]
	GROUP BY [sn].[ParentGuid],[stGuid]
	HAVING SUM(buDirection) > 0
	
	CREATE TABLE [#Isn2]
	(
		[SNID] [INT] IDENTITY(1,1),
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)

	CREATE TABLE [#Isn]
	(
		[SNID] [INT] ,
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)
	
	INSERT INTO [#Isn2] ([Guid],[id],[cnt],[SN],[Length])
	SELECT Guid,[ID] ,[cnt],[SN],LEN([SN])
	FROM [#sn] INNER JOIN [snC000] ON [Guid] = [ParentGuid]
	ORDER BY SN

	INSERT INTO  #Isn SELECT *  FROM [#Isn2]
	
	IF EXISTS(SELECT * FROM [#Isn] WHERE [cnt] > 1)
	BEGIN
		SET @CNT = 1 
		WHILE (@CNT > 0)
		BEGIN
			INSERT INTO [#Isn]
			SELECT  SNID,MAX([R].[Id]),1,[I].[Guid]  ,[sn].[SN],[Length]
			FROM [vcSNs] AS [sn] 
				INNER JOIN [#Result] [R] ON [sn].[biGuid] = [R].[biGuid] 
				INNER JOIN [#Isn] I ON [sn].[Guid] = [I].[Guid]  
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM [#Isn]) AND  [cnt] > 1
			GROUP BY [sn].[SN],[SNID],[Length],[I].[Guid]
			
			UPDATE [#Isn]
			SET [cnt] = [cnt] - 1 WHERE [cnt] > 1
			
			SET @CNT = @@ROWCOUNT			
		END
	END
	--- Return first Result Set -- needed data
	SELECT
		[SN].[SN],
		[r].[MatPtr],
		[r].[MtName],
		[r].[biStorePtr],
		[r].[StName],
		[r].[buType],
		[r].[buNumber],
		[r].[buCust_Name],
		[r].[buDate],
		[r].[biPrice],
		[r].[BillNumber],
		[r].[buBranch],
		[r].[biCostPtr],
		[r].[biGuid]
	FROM
		[#Result] AS [r] INNER JOIN [#ISN] AS [SN] ON [sn].[Id] = [r].[Id]
	ORDER BY
		[r].[ID],
		[Length],
		[SNID]
	
	SELECT *FROM [#SecViol]
/*
	prcConnections_add2 '„œÌ—'
	EXEC  [repMatSN] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '594fb5e6-87c4-441b-8265-27811d40d435', 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '1/1/2004 0:0:0.0', '12/31/2004 23:59:59.998'
*/
##################################################
#END