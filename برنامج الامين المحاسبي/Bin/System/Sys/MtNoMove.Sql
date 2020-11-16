################################################################################
##ÇáãæÇÏ ÇáÑÇßÏÉ
CREATE PROCEDURE repMatNoMove
	@MinMove	 AS [INT],		  	 
	@StartDate	 AS [DATETIME],	          
	@EndDate	 AS [DATETIME],	  	 	
	@Src		 AS [UNIQUEIDENTIFIER],	  	 	
	@Store		 AS [UNIQUEIDENTIFIER],			  
	@Gr 		 AS [UNIQUEIDENTIFIER],			  
	@Cost 		 AS [UNIQUEIDENTIFIER],			  	
	@CurPtr		 AS [UNIQUEIDENTIFIER],  
	@ShowEmpty	 AS [BIT],
	@MatCondGuid AS [UNIQUEIDENTIFIER] = 0X00,
	@AccGuid	 AS	[UNIQUEIDENTIFIER] = 0X00, 
	@CustGuid 	 AS [UNIQUEIDENTIFIER] = 0X00,
	@ShwBalanced AS [BIT] = 1
AS  
	SET NOCOUNT ON 
	----------------------------------------------------------   
	CREATE TABLE [#Src]([Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])    
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src   
	----------------------------------------------------------    
	CREATE TABLE [#mat]([mtGUID] [UNIQUEIDENTIFIER],[Sec] [INT])    
	CREATE TABLE [#Cost]([coGUID] [UNIQUEIDENTIFIER])    
	CREATE TABLE [#Store]([stGUID] [UNIQUEIDENTIFIER])  
	CREATE TABLE [#CustTbl]([CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])   
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])	 
	----------------------------------------------------------    
	INSERT INTO [#mat] EXEC [prcGetMatsList]  NULL, @Gr,-1,@MatCondGuid 
	EXEC [prcCheckSecurity]  @result = '#Mat' 
	INSERT INTO [#Cost] SELECT [GUID] FROM [fnGetCostsList]( @Cost )    
	IF( @Cost = 0x0)    
		INSERT INTO [#Cost] VALUES( 0x0) 
	INSERT INTO [#Store] SELECT [GUID] FROM [fnGetStoresList] (@Store)  
	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGuid, @AccGuid,0X00 
	IF (@CustGuid = 0X00 AND @AccGuid = 0X00) 
		INSERT INTO [#CustTbl] VALUES (0X00,0) 
	----------------------------------------------------------   
	CREATE TABLE [#ms]([stQty] FLOAT, [mtGUID] [UNIQUEIDENTIFIER], [Sec] INT)
	CREATE TABLE [#mat2](  
		[mtGuid] [UNIQUEIDENTIFIER], 
		[mtCode] NVARCHAR(256),  
		[mtName] NVARCHAR(500),  		
		[mtLatinName] NVARCHAR(500),  
		[Unity] NVARCHAR(256), 
		[mtDefUnitFact] FLOAT, 
		[mtDefUnit] INT, 
		[stQty] FLOAT, 
		[MaterialSecurity]	[INT]) 
	  
	INSERT INTO [#ms] SELECT ISNULL(SUM([biQty] * [buDirection]),0) AS [stQty],[mtGUID],[Sec] 
	FROM [vwbubi] AS [ms]  
	INNER JOIN [#Store] AS [Store] ON [Store].[stGUID] = [biStoreptr] 
	RIGHT JOIN [#mat] AS [TempMat] ON [TempMat].[mtGUID] = [biMatptr] 
	GROUP BY [mtGUID],[Sec] 
	INSERT INTO [#mat2] 	 
	SELECT  
		[mt].[Guid] AS [mtGuid], 
		[mt].[Code] AS [mtCode],  
		[mt].[Name] AS [mtName],  
		[mt].[LatinName] AS [mtLatinName],  
		CASE [DefUnit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE [Unit3] END AS [Unity], 
		CASE [DefUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END AS [mtDefUnitFact], 
		[DefUnit] AS [mtDefUnit], 
		SUM([stQty]) AS [stQty], 
		[mt].[Security] AS [MaterialSecurity]
				FROM  [#ms] AS [ms]  
			INNER JOIN [mt000] AS [mt] ON [mtGUID] = [mt].[Guid] 
			INNER JOIN [vwGr] AS [gr] ON [grGuid] = [mt].[GroupGuid]
		GROUP BY 
			[mt].[Guid] , 
			[mt].[Code],  
			[mt].[Name],  			
			[mt].[LatinName],  
			CASE [DefUnit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE [Unit3] END, 
			CASE [DefUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END, 
			[DefUnit], 
			[mt].[Security]

	CREATE CLUSTERED INDEX [mtInd] ON [#mat2]([mtGuid]) 
	
	CREATE TABLE [#Result]( 
				[biMatPtr] [UNIQUEIDENTIFIER], 
				[MoveQty]	[FLOAT], 
				[moveCnt] [INT], 
				[Security] [INT],
				[FirstPurchase] [smalldatetime],
				[LastSale] [smalldatetime],
				[MaterialSecurity] [INT])  
	 
	INSERT INTO [#Result]  
		SELECT  
			 [Bill].[biMatPtr] ,  
			SUM([biQty] * [buDirection]), 
			COUNT( DISTINCT (CAST([Bill].[buGUID] AS [NVARCHAR](40)))), 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END ,
			min(case btbillType when 0 then [budate] else '1/1/2050' end),
			max(case btbillType when 1 then [budate] else '1/1/1980' end),
			[TempMat].[MaterialSecurity]
		FROM  
			[vwBuBi] AS [Bill]  
			INNER JOIN [#mat2] AS [TempMat] ON [TempMat].[mtGUID] = [Bill].[biMatPtr]
			INNER JOIN [#Cost] AS [Cost] ON [Cost].[coGUID] = [Bill].[BiCostPtr] 
			INNER JOIN [#Src] AS [Src] ON [Src].[type] = [Bill].[BuType] 
			INNER JOIN [#CustTbl] AS [cu] ON  [cu].[CustGuid] = [Bill].[buCustPtr] 
		WHERE  
			[Bill].[buDate] BETWEEN @StartDate AND @EndDate  
			AND [Bill].[buIsPosted] = 1 
		GROUP BY 
			[Bill].[biMatPtr],  
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END ,[TempMat].[MaterialSecurity]
			 
	---------------------  
	EXEC [prcCheckSecurity]  
	----------------------------------------------------------  
	CREATE TABLE [#ResultCnt]  
	( [mtGUID] [UNIQUEIDENTIFIER], [MoveCnt] [INT], [MoveQnt] [FLOAT], [FirstPurchase] [smalldatetime], [LastSale] [smalldatetime], [Security] [INT])
	-------------------------------------------  
	INSERT INTO [#ResultCnt]( [mtGUID], [MoveCnt],[MoveQnt],[FirstPurchase], [LastSale], [Security]) 
	SELECT  
		[biMatPtr],  
		SUM([MoveCnt]), 
		SUM([MoveQty]),
		MAX([FirstPurchase]),
		MIN([LastSale]),
		[MaterialSecurity] 
	FROM  
		[#Result] AS [Res] 
	GROUP BY   
		[biMatPtr] ,[MaterialSecurity]
	------------------------------------------------------------- 
	DECLARE @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	DECLARE @Admin INT 
	SET @Admin = (SELECT bAdmin FROM us000 WHERE [GUID] = @UserGUID)

	SELECT 	   
		[mt].[mtGUID],  
		[mt].[mtCode],  
		[mt].[mtName],  				
		[mt].[mtLatinName],  
		[mt].[stQty] / [mtDefUnitFact] AS [mtQty], 
		[mt].[Unity], 
		[mtDefUnit] AS [mtDefUnit], 
		ISNULL( [ResultCnt].[MoveCnt], 0) AS [MoveCnt], 
		ISNULL( [ResultCnt].[MoveQnt], 0) AS [MoveQnt], 
		[mt].[MaterialSecurity],
		CASE [FirstPurchase] WHEN '1/1/2050' THEN '1/1/1980' ELSE [FirstPurchase] END AS [FirstPurchase],
		[LastSale]  
	FROM    
		[#mat2] AS [mt]  
		LEFT JOIN [#ResultCnt] AS [ResultCnt] ON [mt].[mtGUID] = [ResultCnt].[mtGUID] 
	WHERE 
		((@ShowEmpty = 1)  
			AND (@ShwBalanced = 1 OR [mt].[stQty] > 0 OR [ResultCnt].[MoveCnt] IS NOT NULL) 
			AND (ISNULL( [ResultCnt].[MoveCnt], 0) < @MinMove) 
			AND ([mt].[MaterialSecurity] = (SELECT permission 
												FROM ui000 
												WHERE UserGUID = @UserGUID
												AND reportid = 536899696
												AND permtype = 1) 
					OR @Admin = 1)
		)
		OR  
		((@ShowEmpty = 0)
			AND (ISNULL([ResultCnt].[MoveCnt], 0) < @MinMove)  
			AND (ISNULL([ResultCnt].[MoveCnt], 0) > 0)  
			AND ([mt].[stQty] > 0) 
		)
	ORDER BY 
		[mt].[mtCode] 
	----------------------------------------------------------
	SELECT * FROM [#SecViol]
################################################################################
#END
