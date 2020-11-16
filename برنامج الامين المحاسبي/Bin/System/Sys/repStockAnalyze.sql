################################################################################
## «Ã—«¡  Õ·Ì· „” Êœ⁄Ì
CREATE PROCEDURE repStockAnalyzer  
	@GroupGuid AS [UNIQUEIDENTIFIER] ,  
	@StoreGuid AS [UNIQUEIDENTIFIER] ,  
	@CostGuid AS [UNIQUEIDENTIFIER] ,  
	@Price AS [INT],
	@BSrcGuid AS [UNIQUEIDENTIFIER] ,  
	@CurVal AS [FLOAT],  
	@StartDate AS [DateTime] ,  
	@EndDate AS [DateTime]  
	-- @UserId AS INT  
AS  
	SET NOCOUNT ON
	DECLARE	@UserGUID 		[UNIQUEIDENTIFIER] , 
		@UserMatSec	[INT],
		@UserStoreSec	[INT] 
	
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @UserMatSec = [dbo].[fnGetUserMaterialSec_Browse]( @UserGUID)
	SET @UserStoreSec = [dbo].[fnGetUserStoreSec_Browse]( @UserGUID)
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [BillBrowseSec] [INTEGER], [ReadPriceSec] [INTEGER])
	CREATE TABLE [#StoreTbl](	[StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#GroupTbl]( [GroupGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	
	--Filling temporary tables
	INSERT INTO [#GroupTbl]		EXEC [prcGetGroupsList] 		@GroupGuid
	INSERT INTO [#BTypesTbl]	EXEC [prcGetBillsTypesList] 	@BSrcGuid
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGuid
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGuid

	CREATE TABLE [#Result]	
				(	 
					[Security]		[INT], 
					[TypeSecurity]	[INT], 
					[MatPtr]		[UNIQUEIDENTIFIER] , 
					[mtSecurity]	[INT], 
					[Price]			[FLOAT], 
					[buDirection] 	[INT], 
					[biQty]			[FLOAT], 
					[biBonus]		[FLOAT] 
				) 

	INSERT INTO [#Result]
		SELECT  
			[bi].[buSecurity], 
			[bt].[BillBrowseSec],
			[bi].[biMatPtr], 
			[bi].[mtSecurity],  
			CASE @Price  
				WHEN 0 THEN [bi].[mtEndUser] 
				WHEN 6 THEN [bi].[mtAvgPrice] 
				WHEN 1 THEN [bi].[mtWhole] 
				WHEN 2 THEN [bi].[mtHalf] 
				WHEN 3 THEN [bi].[mtExport] 
				WHEN 4 THEN [bi].[mtVendor]  
			ELSE 
				[bi].[mtRetail]  
			END, 
			[bi].[buDirection], 
			[bi].[biQty], 
			[bi].[biBonusQnt]  
		FROM [vwExtended_bi] AS [bi] INNER JOIN [#BTypesTbl] AS [bt] ON [bi].[buType] = [bt].[TypeGuid]
		WHERE  
			[buIsPosted] <> 0 AND
			( @GroupGUID = 0x0 OR EXISTS (SELECT [GroupGuid] FROM [#GroupTbl] WHERE [mtGroup] = [GroupGUID]))AND
			( @StoreGUID = 0x0 OR EXISTS (SELECT [StoreGuid] FROM [#StoreTbl] WHERE [biStorePtr] = [StoreGuid]))AND
			( @CostGuid = 0x0 OR EXISTS (SELECT [CostGuid] FROM [#CostTbl] WHERE	[biCostPtr] = [CostGuid]))AND
			[buDate] BETWEEN @StartDate AND @EndDate 
	EXEC [prcCheckSecurity] @UserGUID

	SELECT  
		[MatPtr],  
		[Price],  
		COUNT(*) AS [MoveCount],  
		Sum([buDirection] * ([biQty] + [biBonus])) AS [SumQty],  
		Sum([buDirection] * ([biQty] + [biBonus]))* [Price] / @CurVal AS [Total]  
	FROM  
		[#Result]
	GROUP BY 
		[MatPtr], [Price] 
	-- ORDER BY 
	-- 	MatPtr 
	SELECT * FROM [#SecViol]
################################################################################
#End