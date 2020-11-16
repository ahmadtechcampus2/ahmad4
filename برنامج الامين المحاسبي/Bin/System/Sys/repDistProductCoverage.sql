##################################################################################
CREATE PROCEDURE repDistProductCoverage
	@StartDate	[DATETIME],
	@EndDate	[DATETIME],
	@HiGuid		[UNIQUEIDENTIFIER],
	@DistGuid	[UNIQUEIDENTIFIER],
	@GroupGuid	[UNIQUEIDENTIFIER],
	@ShowGroup	[INT] = 0,
	@GrLevel	[INT] = 0,
	@CrossCustMat   [INT] = 0,
	@MatCondGuid	[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	DECLARE @Level 		AS [INT],
		@MaxLevel 	AS [INT],
		@Admin		AS [INT],
		@GrpSec		AS [INT]
	CREATE TABLE [#DistTble]	( [DistGuid]	[UNIQUEIDENTIFIER],	[Security]	[INT])
	CREATE TABLE [#SecViol]		( [Type] 	[INT], 			[Cnt]		[INT]) 
	CREATE TABLE [#MatTbl]		( [MatGUID] 	[UNIQUEIDENTIFIER],	[mtSecurity] 	[INT])
	CREATE TABLE [#Cust] 		( [Number] 	[UNIQUEIDENTIFIER],	[Security] 	[INT], [FromDate] [DATETIME])    
	CREATE TABLE [#MT1]
	(
		[mtGuid] 	[UNIQUEIDENTIFIER],
		[mtCode] 	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtName] 	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtLatinName] 	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtSecurity] 	[INT],
		[mtGroup]	[UNIQUEIDENTIFIER]
	)

	INSERT INTO [#DistTble] EXEC [GetDistributionsList] 	@DistGuid, @HiGuid
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 		0X0, @GroupGUID , -1 , @MatCondGuid
	INSERT INTO [#Cust] ( [Number], [Security] ) EXEC [prcGetDistGustsList] @DistGuid, 0x00, 0x00, @HiGuid
	CREATE TABLE [#CustDistTbl]
	(
		[DistGuid]	[UNIQUEIDENTIFIER],
		[DistSecurity] 	[INT],
		[Number] 	[UNIQUEIDENTIFIER],
		[CustSecurity] 	[INT],
		[chName] 	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[chGuid] 	[UNIQUEIDENTIFIER],
		[CostGuid] 	[UNIQUEIDENTIFIER],
		[Routes]	[NVARCHAR](20) COLLATE ARABIC_CI_AI,
		[CuState]	[INT],
		[AllDistNames] 	[NVARCHAR](4000) COLLATE ARABIC_CI_AI
	)

	IF @CrossCustMat = 0
		INSERT INTO [#CustDistTbl]
		SELECT 	[D].[DistGuid], [d].[Security], [c].[Number], [c].[Security], ISNULL([ch].[Name],'<»œÊ‰  ’‰Ì›>'), 
			ISNULL([ch].[Guid],0x00), ISNULL([Sm].[CostGuid],0x00),
			CAST(Dl.Route1 AS NVARCHAR(20)) + ' - ' + CAST(Dl.Route2 AS NVARCHAR(20)) + ' - ' + CAST(Dl.Route3 AS NVARCHAR(20)) + ' - ' + CAST(Dl.Route4 AS NVARCHAR(20)),
			ISNULL(dc.Contracted, 0),
			[dbo].[fnDistGetDistsForCust] (C.Number)	AS [AllDistNames] 
		FROM [#DistTble] AS [d]
			INNER JOIN [DistDistributionLines000] 	AS [Dl] ON [Dl].[DistGUID] = [d].[DistGuid]
			LEFT JOIN [DistCe000] 			AS [Dc] ON [Dc].[CustomerGuid] = [Dl].[CustGuid]
			LEFT JOIN [DistTCh000] 			AS [ch] ON [ch].[Guid] = [dc].[TradeChannelGuid]
			INNER JOIN [#Cust] 			AS [c] 	ON [c].[Number] = [Dl].[CustGUID]
			INNER JOIN [vwDistributor]		AS [Ds] ON [Ds].[Guid]     = [D].[DistGuid]
			INNER JOIN [vwDistSalesMan]		AS [Sm] ON [Sm].[Guid]     = [Ds].[PrimSalesManGuid]
	ELSE
		INSERT INTO [#CustDistTbl]
		SELECT [D].[DistGuid], [d].[Security], [c].[Number], [c].[Security], '', 0X00, [Sm].[CostGuid],
			CAST(Dl.Route1 AS NVARCHAR(20))
			+ CASE Dl.Route2 WHEN 0 THEN '' ELSE (' - ' + CAST(Dl.Route2 AS NVARCHAR(20))) END
			+ CASE Dl.Route3 WHEN 0 THEN '' ELSE (' - ' + CAST(Dl.Route3 AS NVARCHAR(20))) END
			+ CASE Dl.Route4 WHEN 0 THEN '' ELSE (' - ' + CAST(Dl.Route4 AS NVARCHAR(20))) END,
			ISNULL(dc.Contracted, 0),
			dbo.fnDistGetDistsForCust (C.Number)	AS [AllDistNames] 
		FROM [#DistTble] AS [d]
			INNER JOIN [DistDistributionLines000] 	AS [Dl] ON [Dl].[DistGUID] = [d].[DistGuid]
			LEFT JOIN [DistCe000] 			AS [Dc] ON [Dc].[CustomerGuid] = [Dl].[CustGuid]
			INNER JOIN [#Cust] 				AS [c] 	ON [c].[Number]    = [dl].[CustGUID]
			INNER JOIN [vwDistributor]		AS [Ds] ON [Ds].[Guid]     = [D].[DistGuid]
			INNER JOIN [vwDistSalesman]		AS [Sm] ON [Sm].[Guid]     = [Ds].[PrimSalesManGuid]

-- select * from #CustDistTbl order By Number, DistGuid
	CREATE CLUSTERED INDEX [indDistCust] ON [#CustDistTbl] ([Number])

	CREATE TABLE [#Result]
	(
		[CustPtr]		[UNIQUEIDENTIFIER],
		[DistPtr]		[UNIQUEIDENTIFIER],
		[MatPtr]		[UNIQUEIDENTIFIER],
		[mtCode] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[MatSecurity]		[INT] DEFAULT 	0,
		[CustSecurity]		[INT] DEFAULT	0,
		[DistSecurity]		[INT] DEFAULT	0,
		[GroupGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X0,
		[chName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[chGuid]		[UNIQUEIDENTIFIER],
		[btSecurity]		[INT]  DEFAULT	0,
		[Flag]			[INT]  DEFAULT	0,
		[Level]			[INT]  DEFAULT  0,
		[Path]			[NVARCHAR](3000) DEFAULT ''

	)
	CREATE TABLE [#FinalResult]
	(
		[MatPtr]		[UNIQUEIDENTIFIER],
		[mtCode] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CustCount]		[INT] DEFAULT 0,
		[chName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[chGuid]		[UNIQUEIDENTIFIER],
		[Path]			[NVARCHAR](3000) DEFAULT '',
		[Flag]			[INT] DEFAULT 0,
		[mtGroup]		[UNIQUEIDENTIFIER],
		[Level]			[INT] DEFAULT 0
	)
	CREATE TABLE [#EndResult]
	(
		[MatPtr]		[UNIQUEIDENTIFIER],
		[mtGroup]		[UNIQUEIDENTIFIER],
		[CustPtr]		[UNIQUEIDENTIFIER],
		[mtCount]		[INT],
		[Level]			[INT] DEFAULT 0
	)
	
	INSERT INTO  [#MT1]
		SELECT 
			[mt1].[mtGuid],
			[mt1].[mtCode],
			[mt1].[mtName],
			CASE [mt1].[mtLatinName] WHEN '' THEN [mt1].[mtName] ELSE [mt1].[mtLatinName] END,
			[mt].[mtSecurity],
			[mtGroup]
		FROM 
			[#MatTbl]  AS [mt]
			INNER JOIN [vwMt] AS [mt1] ON [mt1].[mtGuid] = [mt].[MatGuid]
	CREATE CLUSTERED INDEX [mtind] ON [#MT1]([mtGuid])
	DECLARE	 @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SELECT [btGuid], [dbo].[fnGetUserBillSec_Browse] (@UserGUID, [btGuid]) AS [Security] INTO [#bt] FROM [vwbt] 	
	INSERT INTO [#Result]  
		SELECT DISTINCT
			[cu].[Number],
			0X00, -- [DistGuid],
			[mtGuid],
			[mtCode], 
			[mtName],
			[mtLatinName], 
			[mt].[mtSecurity],  
			[CustSecurity],
			1, -- [DistSecurity],
			[mtGroup],
			[chName],
			[chGuid],
			0,
			0,
			0,
			''
		FROM  
			[DistCm000] AS [cm]
			INNER JOIN [#CustDistTbl]  	AS [cu] ON [cu].[Number] = [cm].[CustomerGuid]  
			INNER JOIN [#MT1] 		AS [mt] ON [mt].[mtGuid] = [cm].[MatGuid]
		WHERE [cm].[Date] BETWEEN @StartDate AND @EndDate
	UNION 
		SELECT DISTINCT
			[cu].[Number],
			0X00, -- [DistGuid],
			[mtGuid],
			[mtCode], 
			[mtName],
			[mtLatinName], 
			[mt].[mtSecurity],  
			[CustSecurity],
			1, -- [DistSecurity],
			[mtGroup],
			[chName],
			[chGuid],
			[Security], -- [dbo].[fnGetUserBillSec_Browse](@UserGUID, [buType])
			0,
			0,
			''
		FROM  
			[vwBuBi] AS [bu]
			INNER JOIN [#CustDistTbl]  	AS [cu] ON [cu].[Number] = [bu].[buCustPtr]  AND [cu].[CostGuid] = [bu].[buCostPtr]  
			INNER JOIN [#MT1] 		AS [mt] ON [mt].[mtGuid] = [bu].[biMatPtr]
			INNER JOIN [#bt] 		AS [bt] ON [btGuid] = [buType]
		WHERE [bu].[buDate] BETWEEN @StartDate AND @EndDate AND [bu].[buDirection] = -1
	EXEC [prcCheckSecurity] 

	IF @ShowGroup <> 0
	BEGIN
		SELECT 	[f].[Guid], [f].[Level] + 1 AS [Level], [f].[Path], [gr].[Code], [gr].[Name], 
			CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END AS [LatinName], 
			[gr].[ParentGuid], [Security] AS [grSecurity]
		INTO [#GrpTbl]
		FROM  [fnGetGroupsOfGroupSorted] (@GroupGuid, 1) AS f 
		INNER JOIN [gr000] AS [gr] ON [f].[Guid] = [gr].[Guid]
	END
	IF @CrossCustMat = 0
	BEGIN
		IF @ShowGroup <> 0
		BEGIN
			CREATE CLUSTERED INDEX [grInd] ON [#GrpTbl]([Guid],[Level])
			SELECT @Admin = [bAdmin] FROM [US000] WHERE [GUID] = @UserGUID 
			IF @Admin = 0
			BEGIN
				SELECT @GrpSec = [Permission] FROM [UIX] WHERE ReportId = 268554240 AND [UserGuid] = @UserGUID AND [PermType] = 1
				IF EXISTS (SELECT * FROM [#GrpTbl] WHERE [grSecurity] > @GrpSec)
				BEGIN
					SELECT @MaxLevel = MAX([Level])  FROM [#GrpTbl] WHERE [grSecurity] > @GrpSec
					WHILE @MaxLevel > 0 
					BEGIN 
						UPDATE [gr] SET [ParentGuid] = [gr1].[ParentGuid], [Level] = [gr1].[Level]  
						FROM [#GrpTbl] AS [gr] INNER JOIN [#GrpTbl] AS [gr1] ON [gr].[ParentGuid] = [gr1].[Guid]
							WHERE [gr1].[Level] = @MaxLevel AND [gr1].[grSecurity] > @GrpSec
						DELETE  [#GrpTbl] WHERE [Level] = @MaxLevel AND [grSecurity] > @GrpSec
						SELECT @MaxLevel = ISNULL(MAX([Level]),0)  FROM [#GrpTbl] WHERE [grSecurity] > @GrpSec
					END
				END
			END
			
			INSERT INTO [#Result] ( [CustPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [MatSecurity], [GroupGuid], [chName], [chGuid], [Flag], [Level], [Path] )  
				SELECT [CustPtr], [gr].[Guid], [gr].[Code], [gr].[Name], [gr].[LatinName], [grSecurity], [gr].[ParentGuid], [chName], [chGuid], 1, [gr].[Level], [gr].[Path]
				FROM [#Result] AS [r] 
				INNER JOIN  [#GrpTbl] AS [gr] ON [r].[GroupGuid] = [gr].[Guid]
			
			SELECT @MaxLevel = MAX([Level]) FROM [#GrpTbl]
			SET @Level = @MaxLevel
			WHILE @Level > 1
			BEGIN
				INSERT INTO [#Result] ( [CustPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [MatSecurity], [GroupGuid], [chName], [chGuid], [Flag], [Level], [Path] )  
				SELECT [CustPtr], [gr].[Guid], [gr].[Code], [gr].[Name], [gr].[LatinName], [grSecurity], [gr].[ParentGuid], [chName], [chGuid], 1, [gr].[Level], [gr].[Path]
				FROM [#Result] AS [r] INNER JOIN  [#GrpTbl] AS [gr] ON [r].[GroupGuid] = [gr].[Guid]
				WHERE [r].[Level] = @Level
				SET @Level = @Level -1
			END
			UPDATE [#Result] SET [Path] = [gr].[Path] 
			FROM [#Result] AS [r] 
			INNER JOIN [#GrpTbl] AS [gr] ON [r].[GroupGuid] = [gr].[Guid]
			WHERE [r].[Flag] = 0
			
			IF @GrLevel > 0
			BEGIN
				SET @Level = @MaxLevel
				WHILE @Level > @GrLevel
				BEGIN
						UPDATE [r] SET [GroupGuid] = [gr].[ParentGuid] 
						FROM [#Result] AS [r]
						INNER JOIN [#GrpTbl] AS [gr] ON [r].[GroupGuid] = [gr].[Guid]
						WHERE [r].[Flag] = 0 AND [gr].[Level] = @Level
					
						SET @Level = @Level -1
				END
				DELETE [#Result] WHERE [Level] > @GrLevel AND [Flag] = 1
				
			END
		
		END
		CREATE INDEX [resInd] ON  [#Result] ( [CustPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [chName], [chGuid], [Path], [GroupGuid], [Level] )


		INSERT INTO [#FinalResult] 
			SELECT [MatPtr], [mtCode], [mtName], [mtLatinName], COUNT( DISTINCT( CAST([CustPtr] AS NVARCHAR(40)))), [chName], [chGuid], [Path], [Flag], [GroupGuid], [Level]
			FROM [#RESULT]
			WHERE (@ShowGroup <> 1) OR ([Flag] = 1) 
			GROUP BY [MatPtr], [mtCode], [mtName], [mtLatinName], [chName], [chGuid], [GroupGuid], [Level], [Path], [Flag]
			ORDER BY [Level] DESC, [Path] DESC


		INSERT INTO [#FinalResult] ( [CustCount], [chName], [chGuid], [Flag] ) SELECT COUNT( DISTINCT CAST(CustPtr AS NVARCHAR(40))), [chName], [chGuid], 15 FROM [#Result] GROUP BY [chName], [chGuid]

		IF (@ShowGroup <> 1)
		BEGIN
			DECLARE @L	INT
			SELECT @L = MAX([Level]) FROM [#FinalResult]
			WHILE @L > 0 
			BEGIN
				UPDATE RES SET CustCount = ( 	SELECT SUM(ISNULL(R.CustCount,0)) 
								FROM [#FinalResult] AS R 
								WHERE R.ChGuid = Res.ChGuid AND R.mtGroup = Res.MatPtr 
							   )
				FROM [#FinalResult]  AS Res 
				WHERE Flag = 1
	
				SET @L = @L - 1
			END

			UPDATE RES SET CustCount = ( 	SELECT SUM(ISNULL(R.CustCount,0)) FROM [#FinalResult] AS R 
							WHERE R.ChGuid = Res.ChGuid AND Flag = 0 
						   )
			FROM [#FinalResult]  AS Res
			WHERE Flag = 15
		END

		SELECT * FROM [#FinalResult] 
		ORDER BY [Path], [Flag] DESC, [mtCode], [chName], [chGuid]
	END
	ELSE
	BEGIN
		IF @ShowGroup = 1
		BEGIN
			INSERT INTO [#EndResult] 
				SELECT [gr].[Guid], [ParentGuid], [CustPtr], COUNT(DISTINCT CAST([MatPtr] AS NVARCHAR(40))), [gr].[Level] 
				FROM [#RESULT] AS [r] INNER JOIN [#GrpTbl] AS [gr] ON [gr].[Guid] = [r].[GroupGuid] 
				GROUP BY [gr].[Guid], [ParentGuid], [CustPtr], [gr].[Level]
			IF @GrLevel > 0
			BEGIN
				SELECT @MaxLevel = MAX([level]) FROM  [#EndResult]
				WHILE @MaxLevel > @GrLevel
				BEGIN
					INSERT INTO [#EndResult] 
					SELECT [gr].[Guid], [ParentGuid], [CustPtr], SUM([mtCount]), [gr].[Level] 
					FROM [#EndResult] AS [r] INNER JOIN [#GrpTbl] AS [gr] ON [gr].[Guid] = [r].[mtGroup] 
					WHERE [r].[Level] = @MaxLevel
					GROUP BY [gr].[Guid], [ParentGuid], [CustPtr], [gr].[Level]
					
					SET @MaxLevel = @MaxLevel - 1
				END
				DELETE [#EndResult] WHERE [Level] >  @GrLevel
			END
		END
		ELSE 
		BEGIN
			INSERT INTO [#EndResult] SELECT DISTINCT  [MatPtr], [GroupGuid], [CustPtr], 1, 0 FROM [#RESULT]
			IF @GrLevel > 0 AND @ShowGroup <> 0
			BEGIN
				SELECT  @MaxLevel =  MAX([gr].[Level])
					FROM [#MT1] AS [r] INNER JOIN [#GrpTbl] AS [gr] ON [gr].[Guid] = [r].[mtGroup] 
				WHILE @MaxLevel > @GrLevel
				BEGIN
					UPDATE [m] SET [mtGroup] = [gr].[ParentGuid]
					FROM [#MT1] AS [m] INNER JOIN [#GrpTbl] AS [gr] ON [gr].[Guid] = [m].[mtGroup] 
					WHERE [gr].[Level] = @MaxLevel
					
					SET @MaxLevel = @MaxLevel - 1
				END
			END
		END
		IF @ShowGroup <> 0
			SELECT [Guid], [Level], [Code], [Name], [LatinName], [ParentGuid] FROM [#GrpTbl] WHERE @GrLevel = 0 OR @GrLevel >= [Level] ORDER BY [Level]
		IF @ShowGroup <> 1
			SELECT [mtGuid], [mtCode], [mtName], [mtLatinName], [mtGroup] FROM [#MT1]
		
		SELECT 	ISNULL([MatPtr], 0x00) AS [MatPtr], [cu].[Guid] AS [CustPtr], SUM(ISNULL([mtCount], 0)) AS [mtCount], 
			[cu].[CustomerName], [cu].[LatinName],
			(SELECT TOP 1 Routes FROM [#CustDistTbl] AS Cd WHERE Cd.Number = [cu].[Guid]) AS Routes, -- '' AS Routes, 
			(SELECT TOP 1 CuState FROM [#CustDistTbl] AS Cd WHERE Cd.Number = [cu].[Guid]) AS CuState, --- 0 AS CuState -- Cd.Routes, Cd.CuState	 
			(SELECT TOP 1 AllDistNames FROM [#CustDistTbl] AS Cd WHERE Cd.Number = [cu].[Guid]) AS AllDistNames --- 0 AS CuState -- Cd.Routes, Cd.CuState	 

		FROM [#EndResult] AS [r] 
		RIGHT JOIN [cu000] AS [cu] ON [cu].[Guid] = [CustPtr]
		INNER JOIN [#Cust] AS [c]  ON [cu].[Guid] = [c].[Number]
		-- INNER JOIN [#CustDistTbl] AS Cd ON Cd.Number = [c].[Number]
		WHERE 	(@CrossCustMat = 1 AND ISNULL(mtCount,0) <> 0)	OR
			(@CrossCustMat = 2 AND ISNULL(mtCount,0) = 0)	OR
			(@CrossCustMat = 3)
		GROUP BY [MatPtr], [cu].[Guid], [CustomerName], [cu].[LatinName]-- , Cd.Routes, Cd.CuState	 
		ORDER BY [CustPtr]

	END

	SELECT * FROM [#SecViol]
	
/*
prcConnections_Add2 '„œÌ—'
exec   [repDistProductCoverage] '1/1/2006', '6/30/2006', 0x00, 0x00, 0x00, 0, 0, 1
*/
#############################
#END 