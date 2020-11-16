###########################################################################
CREATE FUNCTION fnGetGroupsList(@GroupGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER])
AS BEGIN

	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [LEVEL] [INT])
	DECLARE @Continue [INT]
	SET @GroupGUID = ISNULL(@GroupGUID, 0x0)

	IF @GroupGUID = 0x0
	BEGIN
		INSERT INTO @Result SELECT [grGUID] FROM [vwGr]
		RETURN
	END

	DECLARE @LEVEL [INT]
	SET @LEVEL = 0

	INSERT INTO @FatherBuf SELECT [grGUID], @LEVEL FROM [vwGr] WHERE [grGUID] = @GroupGUID

	SET @Continue = 1
	WHILE @Continue <> 0
	BEGIN
		SET @LEVEL = @LEVEL + 1
		INSERT INTO @FatherBuf
			SELECT [grGUID], @LEVEL
			FROM [vwGr] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[grParent] = [fb].[GUID]
			WHERE [fb].[Level] = @LEVEL - 1

		SET @Continue = @@ROWCOUNT
	END
	INSERT INTO @Result SELECT [GUID] FROM @FatherBuf
	RETURN
END
###########################################################################
CREATE FUNCTION fnGetGroupsOfGroup(@GroupGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(SELECT * FROM [fnGetGroupsList](@GroupGUID))

###########################################################################
CREATE FUNCTION fnGetMatsOfCollectiveGroups(@GroupGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (
		SELECT mt.mtGUID
		FROM GRI000 AS GRI
			INNER JOIN gr000 AS GR ON GR.GUID = GRI.GroupGuid
			INNER JOIN vwMt AS MT ON MT.mtGroup = GRI.MatGuid
		WHERE 
			GRI.GroupGuid = @GroupGUID
		UNION ALL
		SELECT mt.mtGUID
		FROM GRI000 AS GRI	
			INNER JOIN gr000 AS GR ON GR.GUID = GRI.GroupGuid
			INNER JOIN vwMt AS MT ON MT.mtGUID = GRI.MatGuid
		WHERE 
			GRI.GroupGuid = @GroupGUID
	)

###########################################################################
CREATE FUNCTION fnGetMatsOfCollectiveGrps (@GrpGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([mtGUID] [UNIQUEIDENTIFIER])
AS
BEGIN
	DECLARE @GrpsTbl TABLE ([GUID] [UNIQUEIDENTIFIER], [GrpKind] [INT])
	INSERT INTO @GrpsTbl SELECT * FROM [fnGetCollectiveGroupsList](@GrpGUID)
	
	INSERT INTO @Result
	SELECT [mt].[GUID]
	FROM
		[mt000] AS [mt]
		INNER JOIN @GrpsTbl AS [grp] ON [grp].[GUID] = [mt].[GroupGUID] AND [grp].[GrpKind] = 0		
	UNION
	SELECT [mt].[GUID]
	FROM 
		@GrpsTbl AS [grp]
		INNER JOIN [gri000] AS [gri] ON [gri].[GroupGuid] = [grp].[GUID] AND [gri].[ItemType] = 1
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid] OR [mt].[Parent] = [gri].[MatGuid]
	
	RETURN
END

###########################################################################
CREATE FUNCTION fnGetMatOfGroupList(@GroupGuid [UNIQUEIDENTIFIER]) 
RETURNS TABLE
AS
 RETURN (
	SELECT [mt].*
	FROM [vdmt] AS [mt]
		INNER JOIN [fnGetMatsOfCollectiveGrps](@GroupGUID) AS [FN] ON [mt].[GUID] = [FN].[mtGuid]
	 )
###########################################################################
CREATE FUNCTION fnGetCollectiveGroupsList (@GroupGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], [GroupKind] [INT])
AS
BEGIN
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Kind] [INT], [LEVEL] [INT])
	DECLARE @Continue [INT]
	SET @GroupGUID = ISNULL(@GroupGUID, 0x0)
	IF @GroupGUID = 0x0
	BEGIN		
		RETURN
	END
	
	DECLARE @LEVEL [INT]
	SET @LEVEL = 0
	INSERT INTO @FatherBuf SELECT [Guid], [Kind], @LEVEL FROM [gr000] WHERE [Guid] = @GroupGUID
	SET @Continue = 1
	
	WHILE @Continue <> 0
	BEGIN
		SET @LEVEL = @LEVEL + 1
		INSERT INTO @FatherBuf
			SELECT [gri].[MatGuid], [gr].[Kind], @LEVEL
			FROM [gri000] AS [gri]
				INNER JOIN @FatherBuf AS [fb] ON [gri].[GroupGuid] = [fb].[GUID] AND [gri].[ItemType] = 0
				INNER JOIN gr000 as gr ON gr.GUID = [gri].[MatGuid]
			WHERE [fb].[Level] = @LEVEL - 1
			UNION
			SELECT [grGUID], 0, @LEVEL
			FROM [vwGr] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[grParent] = [fb].[GUID]
			WHERE [fb].[Level] = @LEVEL - 1
		SET @Continue = @@ROWCOUNT
	END
	
	INSERT INTO @Result
		SELECT DISTINCT [GUID], [Kind] FROM @FatherBuf
	RETURN
END

###########################################################################
CREATE FUNCTION fnIsMatfound 
(
	@MatGuid UNIQUEIDENTIFIER, 
	@GroupGuid UNIQUEIDENTIFIER
)
RETURNS INT
AS
 BEGIN 
  DECLARE @isMatfound INt 

	SELECT @isMatfound = CASE [mt].[GUID] WHEN 0x0 THEN 0 ELSE 1 END 
	FROM [vdmt] AS [mt]
		INNER JOIN [fnGetMatsOfCollectiveGrps](@GroupGUID) AS [FN] ON [mt].[GUID] = [FN].[mtGuid]
	WHERE  mt.GUID = @MatGuid
	 RETURN @isMatfound
END
###########################################################################
#END