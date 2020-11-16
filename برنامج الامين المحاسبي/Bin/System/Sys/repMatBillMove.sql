####################################################################
CREATE PROC repMatBillMove 
		@MatGUID [UNIQUEIDENTIFIER]  
AS   
	--DECLARE @CurrMatPtr AS [UNIQUEIDENTIFIER] 
	--SELECT @CurrMatPtr = myGUID FROM vwMy WHERE myNumber = 1 
	-------------------------------------------------------------	   
	SET NOCOUNT ON 
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])    

	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])   
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 0x0
	   
	CREATE TABLE [#Result](
		[buType]		[UNIQUEIDENTIFIER],
		[buGUID] 		[UNIQUEIDENTIFIER],
		[biMatPtr] 		[UNIQUEIDENTIFIER],
		[biQty]			[FLOAT],
		[biBonusQnt] 	[INT],
		[biPrice] 		[FLOAT],
		[buSecurity] 	[INT],
		[mtSecurity]	[INT],
		[btAbbrev]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[btLatinAbbrev]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[btType]		[INT],
		[btBillType]	[INT],
		[IsInput]		[INT],
		[Security]		[INT],
		[UserSecurity]	[INT],
		[userReadPriceSecurityFieldName] [INT],
		[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtLatinName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI
		)
	-------------------------------------------------------------	   
	INSERT INTO [#Result]
	SELECT   
		[buType],    
		[buGUID],
		[r].[biMatPtr],  
		[biQty]  / CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END,   
		[biBonusQnt] / CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END,   
		([biPrice] / (CASE [biUnity] WHEN 1 THEN [mtUnitFact] WHEN 2 THEN [mtUnit2Fact] WHEN 3 THEN [mtUnit3Fact] END)) * (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END),
		[buSecurity],
		[mtSecurity],
		[btAbbrev],
		[btLatinAbbrev],
		[btType],
		[btBillType],
		[btIsInput],
		[buSecurity], 
		CASE [r].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
		[src].[ReadPrice],
		[r].[mtName],
		[r].[mtLatinName]
	FROM    
		[vwExtended_Bi] AS [r]   
		INNER JOIN [#Src] AS [src] ON [r].[BuType] = [src].[Type]
	WHERE    
		(CASE WHEN [r].[biMatPtr] != @MatGUID THEN [r].[mtParent] ELSE [r].[biMatPtr] END) = @MatGUID
		--AND ( [btType] = 1 OR [btType] = 2)   
		AND [r].[buIsPosted] <> 0  
	-------------------------------------------------------------	   
	EXEC [prcCheckSecurity]  @Check_MatBalanceSec = 1 
	-------------------------------------------------------------
	
	SELECT  
	    [mtName],
		[mtLatinName],
		[btAbbrev],   
		[btLatinAbbrev],   
		SUM( [biQty]) AS [Qty],   
		SUM( [biBonusQnt]) AS [Bonus],   
		SUM( [biQty] * [biPrice]) AS [Price],   
		[btBillType] 
	FROM    
		[#Result]   
	GROUP BY  
	    --[biGUID],
		[mtName],
		[mtLatinName],
		[btAbbrev],   
		[btLatinAbbrev],   
		[btBillType]
	ORDER BY   
		[btBillType]
	-------------------------------------------------------------	   
	SELECT    
		max( [biPrice]) AS [MaxPrice],   
		min( [biPrice]) AS [MinPrice],   
		[IsInput] AS [btType]   
	FROM    
		[#Result]   
	--WHERE    
	--	[btType] = 1 OR [btType] = 2   
	GROUP BY   
		[IsInput]   
	--------------------------------------------------------------  
	SELECT  
		SUM( CASE [IsInput] WHEN 1 THEN [biQty] * [biPrice] ELSE 0 END)/  CASE SUM( CASE [IsInput] WHEN 1 THEN [biQty] ELSE 0 END) WHEN 0 THEN 1 ELSE SUM( CASE [IsInput] WHEN 1 THEN [biQty] ELSE 0 END) END  AS [AvrInPrice],  
		SUM( CASE [IsInput] WHEN 0 THEN [biQty] * [biPrice] ELSE 0 END)/ CASE SUM( CASE [IsInput] WHEN 0 THEN [biQty] ELSE 0 END) WHEN 0 THEN 1 ELSE SUM( CASE [IsInput] WHEN 0 THEN [biQty] ELSE 0 END) END  AS [AvrOutPrice]  
	FROM    
		[#Result]   
	--WHERE    
	--	( [btType] = 1 OR [btType] = 2)  
	---------------------------------------------------------------  
	---------------------------------------------------------------  
	SELECT * FROM [#SecViol]
#############################################################
CREATE PROC repMaterials_GetBillsMove
		@MatGUID [UNIQUEIDENTIFIER]  
AS   	   
	SET NOCOUNT ON 
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])    

	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])   
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 0x0
	   
	CREATE TABLE [#Result](
		[buType]		[UNIQUEIDENTIFIER],
		[buGUID] 		[UNIQUEIDENTIFIER],
		[biMatPtr] 		[UNIQUEIDENTIFIER],
		[mtParent]      [UNIQUEIDENTIFIER],
		[biQty]			[FLOAT],
		[biBonusQnt] 	[INT],
		[biPrice] 		[FLOAT],
		[buSecurity] 	[INT],
		[mtSecurity]	[INT],
		[btAbbrev]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[btLatinAbbrev]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[btType]		[INT],
		[btBillType]	[INT],
		[IsInput]		[INT],
		[Security]		[INT],
		[UserSecurity]	[INT],
		[userReadPriceSecurityFieldName] [INT],
		[mtCompositionName]  [NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtCompositionLatinName]  [NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtCode] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		)
	-------------------------------------------------------------	   
	INSERT INTO [#Result]
	SELECT   
		[buType],    
		[buGUID],
		[r].[biMatPtr],
		[r].[mtParent],  
		[biQty]  / CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END,   
		[biBonusQnt] / CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END,   
		([biPrice] / (CASE [biUnity] WHEN 1 THEN [mtUnitFact] WHEN 2 THEN [mtUnit2Fact] WHEN 3 THEN [mtUnit3Fact] END)) * (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END),
		[buSecurity],
		[mtSecurity],
		[btAbbrev],
		[btLatinAbbrev],
		[btType],
		[btBillType],
		[btIsInput],
		[buSecurity], 
		CASE [r].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
		[src].[ReadPrice],
		[r].[mtCompositionName],
		[r].[mtCompositionLatinName],
		[r].[mtCode]
	FROM    
		[vwExtended_Bi] AS [r]   
		INNER JOIN [#Src] AS [src] ON [r].[BuType] = [src].[Type]
	WHERE    
		[r].[mtParent] = @MatGUID
		AND [r].[buIsPosted] <> 0  
	-------------------------------------------------------------	   
	EXEC [prcCheckSecurity]  @Check_MatBalanceSec = 1 
	-------------------------------------------------------------
		   
	SELECT  
	    [biMatPtr],
	    [mtCode] AS [MtCode],
		[btAbbrev],   
		[btLatinAbbrev],   
		SUM([biQty]) AS [MtQty],   
	    SUM([biBonusQnt]) AS [Bonus],   
		SUM(([biQty] * [biPrice])) AS [Price],   
		[btBillType],
		[mtCompositionName],
		[mtCompositionLatinName],
		[mtParent]
	FROM    
		[#Result] 
	GROUP BY
		[biMatPtr],
	    [mtCode] ,
		[btAbbrev],   
		[btLatinAbbrev],   
		[btBillType],
		[mtCompositionName],
		[mtCompositionLatinName],
		[mtParent]
	ORDER BY   
		[btBillType], [mtCode]

	SELECT MT.[biMatPtr], SE.Name AS ElementName, SE.LatinName AS ElementLatinName, S.Name AS SegmentName, S.LatinName AS SegmentLatinName 
	FROM 
		MaterialElements000 ME
		INNER JOIN [#Result] MT ON ME.MaterialId = MT.[biMatPtr]
		INNER JOIN SegmentElements000 SE ON SE.Id = ME.ElementId
		INNER JOIN Segments000 S on S.Id = SE.SegmentId
		INNER JOIN MaterialSegments000 MS on MS.SegmentId = S.Id AND MS.MaterialId = MT.mtParent
		INNER JOIN MaterialSegmentElements000 AS MSE ON MSE.MaterialSegmentId = MS.Id 
	WHERE MT.mtParent = @MatGUID
	ORDER BY
		MS.Number, MSE.Number
###############################################################################
#END