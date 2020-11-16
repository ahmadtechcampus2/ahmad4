########################################
## repDistributionTree
CREATE PROCEDURE repDistributionTree
	@RouteCount INT = 1,
	@Lang		INT = 0,		-- Language	(0=Arabic; 1=English) 
	@Type		INT = 0,
	@Number		INT = 0,
	@ParentGUID	uniqueidentifier	= 0x0
AS
SET NOCOUNT ON
	CREATE TABLE #SecViol (Type INT, Cnt INT) 
	CREATE TABLE #Result( 
			Guid		UNIQUEIDENTIFIER, 
			ParentGuid 	UNIQUEIDENTIFIER, 
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			UseFlag		INT, 
			NSons		INT, 
			Type		INT, 
			Security 	INT, 
			[Path] 		NVARCHAR(800), 
			[Level] 	INT,
			[Number] 	float
		   	) 
	DECLARE @DistAccGuid [UNIQUEIDENTIFIER]
	IF (@Type = 0)
	BEGIN
		INSERT INTO #Result
		SELECT 
				hi.Guid,
				ISNULL( ParentGuid, 0x0) AS ParentGuid,
				Code,
				CASE WHEN (@Lang = 1)AND(LatinName <> '') THEN  LatinName ELSE Name END AS Name, 
				0,			--UseFlag
				1,			--NSons
				fn.type,
				Security, 
				fn.Path,
				fn.Level,
				0
		FROM
			vwDistHi AS hi 
			INNER JOIN dbo.fnDistGetHierarchyList(@RouteCount, 1) AS fn ON hi.Guid = fn.Guid
	
		INSERT INTO #Result
		SELECT 
				di.Guid,
				ISNULL( HierarchyGuid, 0x0) AS ParentGuid,
				Code,
				CASE WHEN (@Lang = 1)AND(LatinName <> '') THEN  LatinName ELSE Name END AS Name, 
				0,			--UseFlag
				1,			--NSons
				fn.type,
				Security, 
				fn.Path,
				fn.Level,
				0
		FROM
			vwDistributor AS di 
			INNER JOIN dbo.fnDistGetHierarchyList(@RouteCount, 1) AS fn ON di.Guid = fn.Guid
		WHERE
			Type = 2
		INSERT INTO #Result
		SELECT 
				fn.Guid,
				ISNULL( Guid, 0x0) AS ParentGuid,
				CAST(1000 + Number As NVARCHAR(100)),
				CAST(Number As NVARCHAR(100)),
				0,
				1,
				fn.type,
				1, 
				fn.Path,
				fn.Level,
				fn.Number
		FROM
			dbo.fnDistGetHierarchyList(@RouteCount, 1) AS fn
		WHERE
			fn.Type = 4
	END
	------- Customer Of Rote
	IF (@Type = 2)	-- Customer Of Distributor
	BEGIN
	--Distributor000
		CREATE TABLE [#Cust]( [GUID] [UNIQUEIDENTIFIER], [Security] INT)  
		INSERT INTO [#Cust] EXEC prcGetDistGustsList @ParentGUID
			INSERT INTO #Result
			SELECT 
					[cu].[cuGuid],
					ISNULL( @ParentGUID, 0x0) AS ParentGuid,
					[ac].[acCode],
					[cu].[cuCustomerName],
					0,
					1,
					8,
					1, 
					'',
					1,
					0
			FROM
				[#Cust] AS [ex]
				INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [ex].[GUID] 
				INNER JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [cu].[cuAccount] 
			
		
	END
	------- Customer Of Rote
	IF (@Type = 4)	-- Customer Of Route
	BEGIN
		INSERT INTO #Result
		SELECT 
				fn.CustomerGuid,
				ISNULL( @ParentGUID, 0x0) AS ParentGuid,
				ac.acCode,
				cu.cuCustomerName,
				0,
				1,
				8,
				1, 
				'',
				1,
				0
		FROM
			dbo.fnDistGetRouteOfDistributor(@ParentGUID, @Number) AS fn
			INNER JOIN vwCu AS cu ON cu.cuGUID = fn.CustomerGUID
			INNER JOIN vwAc AS ac ON ac.acGUID = cu.cuAccount
	END
	SELECT * FROM #Result ORDER BY [Path]
	SELECT * FROM #SecViol 


--	repDistributionTree 12, 0, 2, 1, '0F7686B9-1D47-4959-B6CE-B403CF9EE953'
--	SELECT * FROM Distributor000		
#############################
#END
