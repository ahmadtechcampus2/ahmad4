#############################################################################
CREATE PROC repAssetsTree
		@Lang INT =0
AS
	CREATE TABLE #SecViol (Type INT, Cnt INT) 
	CREATE TABLE #Result( 
			Guid		UNIQUEIDENTIFIER,  -- Group , Mat , Asset , AssetDetail
			ParentGuid 	UNIQUEIDENTIFIER,  -- Group
			MtGUID		UNIQUEIDENTIFIER,
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Type		INT,  -- 0 Group , 1 Asset
			Security INT
		   	) 
	INSERT INTO #Result
		SELECT 
			grGUID,
			grParent,
			0x0,
			grCode,
			grName,
			0, -- Group
			grSecurity
		FROM 
			vwGr

	-- CheckSecurity
	INSERT INTO #Result
		SELECT 
			asGUID,
			mtGroup,
			mtGUID,
			asCode,
			asName,
			1, -- ASSET
			asSecurity
		FROM 
			vwAs AS Ass INNER JOIN vwMt AS Mt 
			ON Ass.asParentGUID = Mt.mtGUID

	-- CheckSecurity	
	SELECT * FROM #Result			
#############################################################################
#END
