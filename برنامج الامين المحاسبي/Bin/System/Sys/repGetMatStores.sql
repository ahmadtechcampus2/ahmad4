#############################################################################
CREATE PROC repGetMatStores @mtGuid AS [UNIQUEIDENTIFIER] 
AS
	SET NOCOUNT ON 

	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) <= 0
		RETURN

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]);  

	CREATE TABLE [#Result](
		[mtName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[StorePtr] 			[UNIQUEIDENTIFIER],  
		[MatPtr] 			[UNIQUEIDENTIFIER],
		[stCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Qty]				[FLOAT],	
		[mtSecurity]		[INT],
		[stSecurity]		[INT],
		);

	INSERT INTO [#Result]
	SELECT
	    [mt].mtName,
		[mt].mtLatinName,
		[msStorePtr],
		[msMatPtr],
		[St].[stCode],
		[St].[stName],
		[St].[stLatinName],
		[ms].[msQty],
		[mt].[mtSecurity],
		[St].[stSecurity]
	
	FROM 
		[vwms] AS [ms] 
		INNER JOIN [vwSt] AS [St] ON [ms].[msStorePtr] = [St].[stGUID]
		INNER JOIN [vwMt] AS [mt] ON [msMatPtr] = [mt].[mtGuid]
	WHERE
        (CASE WHEN [msMatPtr] != @mtGuid THEN [mt].[mtparent] ELSE ms.msMatPtr END) = @mtGuid

	EXEC [prcCheckSecurity]  @Check_MatBalanceSec = 1
	
	SELECT 
	    [mtName],
		[mtLatinName],
		[StorePtr], 	
		[stCode],		
		[stName],		
		[stLatinName],
		SUM([Qty])AS QTY
	FROM
		[#Result]
	GROUP BY
	    [mtName],
		[mtLatinName],
	    [StorePtr], 	
		[stCode],		
		[stName],		
		[stLatinName]
	ORDER BY
		 stName, stLatinName;
	  
###############################################################################
CREATE PROC repMaterials_GetStoresQty 
		@mtGuid AS [UNIQUEIDENTIFIER] 
AS
	SET NOCOUNT ON 

	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) <= 0
		RETURN
		print 1
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]);  

	CREATE TABLE [#Result](
	    [mtParent]              [UNIQUEIDENTIFIER],
	    [mtCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stGUID] 				[UNIQUEIDENTIFIER],  
		[mtGUID] 				[UNIQUEIDENTIFIER],
		[stCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[stName]				[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[stLatinName]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[Qty]					[FLOAT],	
		[mtSecurity]			[INT],
		[stSecurity]			[INT],
		[mtCompositionName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtCompositionLName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI
		);

	INSERT INTO [#Result]
	SELECT
	    [mt].[mtParent],
	    [mt].mtCode,
		[msStorePtr],
		[msMatPtr],
		[St].[stCode],
		[St].[stName],
		[St].[stLatinName],
		[ms].[msQty],
		[mt].[mtSecurity],
		[St].[stSecurity],
		[mt].[mtCompositionName],
		[mt].[mtCompositionLatinName]
	FROM 
	    [vwms] AS [ms] 
		INNER JOIN [vwSt] AS [St] ON [ms].[msStorePtr] = [St].[stGUID]
	    INNER JOIN [vwMt] AS [mt] ON [msMatPtr] = [mt].[mtGuid]
	WHERE [mt].[mtparent] = @mtGuid
	    
	EXEC [prcCheckSecurity]  @Check_MatBalanceSec = 1

	SELECT mtCode, mtGUID, stName, stLatinName, Qty, mtCompositionName, mtCompositionLName 
	FROM [#Result]
	ORDER BY stName, stLatinName, mtCode;

	SELECT MT.mtGUID, SE.Name AS ElementName, SE.LatinName AS ElementLatinName, S.Name AS SegmentName, S.LatinName AS SegmentLatinName 
	FROM 
		MaterialElements000 ME
		INNER JOIN [#Result] MT ON ME.MaterialId = MT.mtGUID
		INNER JOIN SegmentElements000 SE ON SE.Id = ME.ElementId
		INNER JOIN Segments000 S on S.Id = SE.SegmentId
		INNER JOIN MaterialSegments000 MS on MS.SegmentId = S.Id AND MS.MaterialId = MT.mtParent
		INNER JOIN MaterialSegmentElements000 AS MSE ON MSE.MaterialSegmentId = MS.Id 
	WHERE MT.mtParent = @mtGuid
	ORDER BY
		MS.Number, MSE.Number
###############################################################################3
#END