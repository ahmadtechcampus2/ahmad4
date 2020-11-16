CREATE PROC prcGetGroupParnetList
--This proucedure returns a List of Gruop and its Parent
	@GrpGuid [UNIQUEIDENTIFIER],
	@Level [INT] = 0
AS 
	SET NOCOUNT ON
	
	DECLARE @RESULT TABLE ([GUID] [UNIQUEIDENTIFIER], [ptrGUID] [UNIQUEIDENTIFIER], [Level] [INT])
	DECLARE @c CURSOR
	DECLARE @Guid [UNIQUEIDENTIFIER]
	
	SET @c = CURSOR FAST_FORWARD FOR SELECT [GUID]
											FROM [fnGetGroupsList](@GrpGuid)
	OPEN @c		
	FETCH @c INTO @GUID
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF EXISTS(SELECT  @GUID, [A].[GUID], [Level]
											 FROM [fnGetGroupParents](@GUID) [A]
												INNER JOIN [fnGetGroupsListByLevel](@GrpGuid,@Level) [B]
													ON [A].[GUID] = [B].[GUID]
												 WHERE [LEVEL] = @Level)
			INSERT INTO @RESULT SELECT  @GUID, [A].[GUID], [Level]
												 FROM [fnGetGroupParents](@GUID) [A]
													INNER JOIN [fnGetGroupsListByLevel](@GrpGuid,@Level) [B]
														ON [A].[GUID] = [B].[GUID] WHERE [LEVEL] = @Level
		ELSE 
			INSERT INTO @RESULT  SELECT @GUID,@GUID,[Level] 
													FROM [fnGetGroupsListByLevel](@GrpGuid,@Level) 
													WHERE [GUID] = @GUID
		FETCH @c INTO @GUID
	END
	CLOSE @c
	DEALLOCATE @c

	SELECT 
		[r].[GUID],
		[r].[ptrGUID], 
		[gr].[grSecurity] AS [Security], 
		[r].[Level] 
	FROM 
		@RESULT AS [r] INNER JOIN [vwGr] AS [gr] 
		ON [r].[GUID] = [gr].[grGUID]
###################################################
#END
