########################################
## repDistRoutes
CREATE PROCEDURE repDistRoutes
	@HierarchyGUID 		[UNIQUEIDENTIFIER] = 0X0,
	@DistributorGUID 	[UNIQUEIDENTIFIER] = 0X0,
	@bShowDetails 		[BIT] = 0,
	@Contracted 		[BIT] = 0,
	@bShowAddress 		[BIT] = 0,
	@bShowCnt 			[BIT] = 0,
	@StartDateRoute		DATETIME = '01-01-2008'	 

AS 
	SET NOCOUNT ON 
-- Select * from #aa

	SET @HierarchyGUID 	= ISNULL(@HierarchyGUID, 0x0)
	SET @DistributorGUID 	= ISNULL(@DistributorGUID, 0x0)
	CREATE TABLE [#SecViol] ( [Type] 	[INT], 			[Cnt] 		[INT] )
	CREATE TABLE [#Cust] 	( [GUID] 	[UNIQUEIDENTIFIER], 	[Security] 	[INT] )      
	INSERT INTO [#Cust] EXEC prcGetDistGustsList @DistributorGuid
	CREATE TABLE [#DistTble]( [DistGuid]	[UNIQUEIDENTIFIER], 	[Security] 	[INT] )
	CREATE TABLE [#Result] 
	(
		[HierarchyGUID]		[UNIQUEIDENTIFIER],
		[DistributorGUID]	[UNIQUEIDENTIFIER],
		[DistSecurtiy]		[INT],
		[CustomerGUID]		[UNIQUEIDENTIFIER],
		[CustSecurtiy]		[INT],
		[CustomerName]		[NVARCHAR](250) COLLATE Arabic_CI_AI DEFAULT '',
		[Route1]		[INT],
		[Route2]		[INT],
		[Route3]		[INT],
		[Route4]		[INT],
		[Contracted]		[NVARCHAR](20)
		
	)

	INSERT INTO [#DistTble] EXEC GetDistributionsList @DistributorGUID, @HierarchyGUID
	SELECT 	[c].[Guid], [cu].[Security], 
		[CU].[CustomerName] + CASE @bShowAddress WHEN 1 THEN ' (' + [CU].[Area] + '-' + [Cu].[Street] + ') ' ELSE '' END   AS [CustomerName]
	INTO [#Cust2]
	FROM [#Cust] AS [c]  INNER JOIN [vexCu] [CU] ON [CU].[GUID] = [c].[Guid]

	INSERT INTO [#Result]	
	SELECT 
		[HierarchyGUID] ,
		[D].[GUID] ,
		[d].[Security],
		[cl] .[CUSTGUID],
		[c].[Security],
		[CustomerName],
		[cl].[Route1] ,
		[cl].[Route2] ,
		[cl].[Route3] ,
		[cl].[Route4] ,
		ISNULL([CE].[Contracted], '0')
	FROM 
		[DistDistributionLines000] [cl] 
		INNER JOIN [#Cust2] 		AS [c] 	ON [c].[Guid]      = [cl] .[CustGuid]
		INNER JOIN [vwDistributor] 	AS [D] 	ON [cl].[DistGUID] = [D].[GUID] 
		INNER JOIN [#DistTble] 		AS [d2] ON [d2].[DistGuid] = [D].[GUID]
		LEFT JOIN [DistCe000] 		AS [ce] ON [c].[Guid] 	   = [ce].[CustomerGuid]
	WHERE 
		((( ISNULL([CE].[Contracted],0) = 1) AND (@Contracted = 1)) OR (@Contracted = 0))
		AND ISNULL([CustomersAccGUID],0X00) <> 0X00

	EXEC [prcCheckSecurity]

	CREATE TABLE [#Result2] 
	(
		[HierarchyGUID]		[UNIQUEIDENTIFIER],
		[DistributorGUID]	[UNIQUEIDENTIFIER],
		[CustomerGUID]		[UNIQUEIDENTIFIER],
		[CustomerName]		[NVARCHAR](250) COLLATE Arabic_CI_AI DEFAULT '',
		[Route] 			[INT],
		[RoutCount]			[INT],
		[Contracted]		[INT]
	)
	CREATE INDEX [r_2Ind] ON [#Result] ([HierarchyGUID],[DistributorGUID],[CustomerName])
	INSERT INTO [#Result2] SELECT [HierarchyGUID], [DistributorGUID], [CustomerGUID], [CustomerName], [Route1], 0, [Contracted] FROM [#Result] WHERE [Route1] <> 0
	INSERT INTO [#Result2] SELECT [HierarchyGUID], [DistributorGUID], [CustomerGUID], [CustomerName], [Route2], 0, [Contracted] FROM [#Result] WHERE [Route2] <> 0
	INSERT INTO [#Result2] SELECT [HierarchyGUID], [DistributorGUID], [CustomerGUID], [CustomerName], [Route3], 0, [Contracted] FROM [#Result] WHERE [Route3] <> 0
	INSERT INTO [#Result2] SELECT [HierarchyGUID], [DistributorGUID], [CustomerGUID], [CustomerName], [Route4], 0, [Contracted] FROM [#Result] WHERE [Route4] <> 0
	INSERT INTO [#Result2] SELECT [HierarchyGUID], [DistributorGUID], [CustomerGUID], [CustomerName], 0, 0, [Contracted] FROM [#Result] WHERE [Route1] = 0 AND [Route2] = 0 AND [Route3] = 0 AND [Route4] = 0
	
	CREATE TABLE [#EndResult]( 	[DistributorGUID] 	[UNIQUEIDENTIFIER], 
					[HierarchyGUID] 	[UNIQUEIDENTIFIER], 
					[DistributorCode] 	[NVARCHAR](250) COLLATE Arabic_CI_AI DEFAULT '', 
					[DistributorName] 	[NVARCHAR](250) COLLATE Arabic_CI_AI DEFAULT '', 
					[Rout] 			[INT], 
					[RoutCount] 		[INT],
					[Flag] 			[INT],
					[Level] 		[INT]
				) 

	INSERT INTO [#EndResult] 
	SELECT 		[d].[Guid], [d].[HierarchyGUID], [d].[Code], [d].[Name], [Route], COUNT(CAST([CustomerGUID] AS NVARCHAR(40))), 0, 0 
	FROM [vwDistributor] AS [d] 
	INNER JOIN [#Result2] AS [r] ON [r].[DistributorGUID] = [d].[Guid]
	GROUP BY [d].[Guid], [d].[HierarchyGUID], [d].[Code], [d].[Name], [Route]
	
	DECLARE @Level [INT]
	DECLARE @Level2 [INT]
	SET @Level = 1 
	INSERT INTO [#EndResult] 
		SELECT  [hi].[Guid], [hi].[ParentGUID], [hi].[Code], [hi].[Name], [Rout], SUM([RoutCount]), -1, @Level
		FROM [#EndResult] AS [e] INNER JOIN [vwDistHi] AS [hi] ON [hi].[Guid] = [e].[HierarchyGUID]
		GROUP BY [hi].[Guid], [hi].[ParentGUID], [hi].[Code], [hi].[Name], [Rout]
	WHILE (@Level > 0)
	BEGIN
		SET @Level2 = @Level + 1
		INSERT INTO [#EndResult] 
		SELECT [hi].[Guid], [hi].[ParentGUID], [hi].[Code], [hi].[Name], [Rout], SUM([RoutCount]), -1, @Level2
		FROM [#EndResult] AS [e] 
		INNER JOIN [vwDistHi] AS [hi] ON [hi].[Guid] = [e].[HierarchyGUID]
		WHERE [e].[Level] = @Level
		GROUP BY [hi].[Guid], [hi].[ParentGUID], [hi].[Code], [hi].[Name], [Rout]
		IF (@@ROWCOUNT = 0)
			SET @Level = 0
		ELSE
			SET @Level = @Level2
			
	END
	----------------- Routes Dates
	CREATE TABLE #RouteDate(
		[Index]		INT IDENTITY(1,1),
		RouteDate	DATETIME,
		RouteNum	INT
	)
	INSERT INTO #RouteDate(RouteDate, RouteNum) SELECT Date, Route FROM fnDistGetRoutesNumListOfDate (@StartDateRoute) ORDER BY Date
	INSERT INTO #RouteDate(RouteDate, RouteNum) VALUES (@StartDateRoute-1, 0)

	--------------------- PROCEDURE RESULT 
	
	SELECT 
		[DistributorGUID], [HierarchyGUID], [DistributorCode], [DistributorName], [Rout], [RoutCount], [Flag], rd.[Index] 
	FROM 
		[#EndResult] AS er	
		INNER JOIN #RouteDate AS rd ON rd.RouteNum = er.Rout
	ORDER BY  
		[Flag], [DistributorCode], [DistributorGUID], rd.[Index]  --[Rout]

	IF @bShowDetails = 1
	BEGIN
		IF @bShowCnt = 1
		BEGIN
			SELECT COUNT([Route]) AS [cnt], [DistributorGUID], [CustomerGUID] 
			INTO [#Cnt] 
			FROM [#RESULT2] 
			GROUP BY [DistributorGUID], [CustomerGUID]

			UPDATE [R] SET [RoutCount] = [cnt] 
			FROM [#RESULT2] AS [r] 
			INNER JOIN [#Cnt] AS [c] ON [c].[DistributorGUID] = [r].[DistributorGUID] AND [c].[CustomerGUID] = [r].[CustomerGUID]
		END
		SELECT 
			[DistributorGUID], [CustomerGUID], [CustomerName], [Route], [RoutCount], [Contracted], rd.[Index] 
		FROM 
			[#RESULT2] AS rs
			INNER JOIN #RouteDate AS rd ON rd.RouteNum = rs.Route
		ORDER BY 
			[DistributorGUID], [CustomerGUID], [rd].[Index]-- [Route]
		
	END

	SELECT RouteDate, RouteNum FROM #RouteDate ORDER BY [Index]

/*
prcConnections_Add2 '„œÌ—'
EXEC [repDistRoutes] '00000000-0000-0000-0000-000000000000', 'f6adb10a-0de6-40a0-94d5-04409efa8293', 1, 0, 0, 0, '04-10-2008'  
*/
#############################
#END
