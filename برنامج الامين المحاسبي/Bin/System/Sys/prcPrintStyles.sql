##########################################################################
CREATE PROCEDURE prcGetUsersByPrsName
	@prsName NVARCHAR(250)
AS 
	SET NOCOUNT ON

	SELECT 
		ISNULL( [us].[GUID], 0x0) AS [GUID],
		ISNULL( [us].[LoginName], '') AS [LoginName]
	FROM 
		[us000] [us]
		RIGHT JOIN [prs000] [prs] ON [prs].[UserGUID] = [us].[GUID]
	WHERE
		[prs].[Name] = @prsName OR [prs].[LatinName] = @prsName
	ORDER BY 
		[us].[LoginName]
##########################################################################
CREATE PROCEDURE prcDeleteAllPrintStyles
AS 
	SET NOCOUNT ON 
	
	DELETE 
		[fn000] 
	FROM 
		[fn000] [fn]
		INNER JOIN [prh000] [prh] ON [prh].[FontGUID] = [fn].[GUID]
		
	DELETE 
		[prh000]
	FROM 
		[prh000] [prh]
		INNER JOIN [prs000] [prs] ON [prh].[ParentGUID] = [prs].[GUID]

	DELETE [prs000]
##########################################################################
CREATE PROCEDURE prcCopyPrsToPrs
	@UserGUID UNIQUEIDENTIFIER,
	@FromPrsGUID UNIQUEIDENTIFIER,
	@ToPrsGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 
	
	IF NOT EXISTS( SELECT * FROM [prs000] WHERE [GUID] = @FromPrsGUID)
		RETURN

	DECLARE 
		@C_PRS CURSOR,
		@prsGUID UNIQUEIDENTIFIER,
		@prsName NVARCHAR(250),
		@prsLatinName NVARCHAR(250)

	SELECT * INTO [#prs] FROM [prs000] WHERE ([GUID] = @FromPrsGUID)

	SELECT 
		[prh].* 
	INTO 
		[#prh] 
	FROM 
		[prh000] [prh] 
		INNER JOIN [#prs] [prs] ON [prs].[guid] = [prh].[ParentGUID]

	SELECT 
		[fn].*
	INTO 
		[#fn] 
	FROM 
		[fn000] [fn] 
		INNER JOIN [#prh] [prh] ON [fn].[guid] = [prh].[FontGUID]

	CREATE TABLE [#fnOld]( NewGUID UNIQUEIDENTIFIER, OldGUID UNIQUEIDENTIFIER)
	
	SET @C_PRS = CURSOR FAST_FORWARD FOR 
		SELECT 
			[GUID], [Name], [LatinName] 
		FROM 
			[prs000] 
		WHERE 
			([UserGUID] = @UserGUID) AND (([GUID] = @ToPrsGUID) OR ((ISNULL( @ToPrsGUID, 0x0) = 0x0) AND ([GUID] != @FromPrsGUID)))

	OPEN @C_PRS FETCH NEXT FROM @C_PRS INTO @prsGUID, @prsName, @prsLatinName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE 
			[#prs]
		SET 
			[GUID] = @prsGUID,
			[Name] = @prsName,
			[LatinName] = @prsLatinName

		UPDATE 
			[#prh]
		SET 
			[guid] = newid(),
			[ParentGUID] = @prsGUID

		DELETE [#fnOld]
		INSERT INTO [#fnOld] SELECT newid(), [guid] FROM [#fn]

		UPDATE [#fn]
		SET 
			[GUID] = [f].[NewGUID]
		FROM 
			[#fn] [fn]
			INNER JOIN [#fnOld] [f] ON [f].[OldGUID] = [fn].[GUID]

		UPDATE [#prh]
		SET 
			[FontGUID] = [f].[NewGUID]
		FROM 
			[#prh] [prh]
			INNER JOIN [#fnOld] [f] ON [f].[OldGUID] = [prh].[FontGUID]

		EXEC prcDeletePrintStyle @prsGUID

		INSERT INTO [prs000] SELECT * FROM [#prs]
		INSERT INTO [prh000] SELECT * FROM [#prh]
		INSERT INTO [fn000] SELECT * FROM [#fn]

		FETCH NEXT FROM @C_PRS INTO @prsGUID, @prsName, @prsLatinName
	END
	CLOSE @C_PRS DEALLOCATE @C_PRS
##########################################################################
CREATE PROCEDURE prcCopyPrsToUser
	@FromUserGUID UNIQUEIDENTIFIER,
	@PrsGUID UNIQUEIDENTIFIER,
	@ToUserGUID UNIQUEIDENTIFIER = 0x0,
	@Type INT = 0
AS 
	SET NOCOUNT ON 
	
	IF NOT EXISTS( SELECT [GUID] FROM [US000] WHERE [GUID] = @FromUserGUID UNION ALL SELECT 0x0)
		RETURN

	DECLARE 
		@C_USER CURSOR,
		@usGUID UNIQUEIDENTIFIER,
		@prsName NVARCHAR(250)

	SET @prsName = (SELECT [Name] FROM [prs000] WHERE [guid] = @PrsGUID)
	IF ISNULL( @prsName, '') = ''
		RETURN

	SELECT * INTO [#prs] FROM [prs000] WHERE ([UserGUID] = @FromUserGUID) AND ([guid] = @PrsGUID)
	SELECT 
		[prh].* 
	INTO 
		[#prh] 
	FROM 
		[prh000] [prh] 
		INNER JOIN [#prs] [prs] ON [prs].[guid] = [prh].[ParentGUID]

	SELECT 
		[fn].*
	INTO 
		[#fn] 
	FROM 
		[fn000] [fn] 
		INNER JOIN [#prh] [prh] ON [fn].[guid] = [prh].[FontGUID]

	CREATE TABLE [#fnOld]( [NewGUID] UNIQUEIDENTIFIER, [OldGUID] UNIQUEIDENTIFIER)
	CREATE TABLE [#Users]( [GUID] UNIQUEIDENTIFIER)

	IF ISNULL( @ToUserGUID, 0x0) = 0x0 AND @Type = 0
	BEGIN 
		INSERT INTO [#Users]
		SELECT 0x0
	END ELSE BEGIN 
		INSERT INTO [#Users]
		SELECT [GUID] 
		FROM [us000] 
		WHERE 
			(
				([GUID] = @ToUserGUID) 
				OR 
				((ISNULL( @ToUserGUID, 0x0) = 0x0) AND ([GUID] != @FromUserGUID))
			) 
			AND 
				[Type] = 0	
	END 
	
	
	SET @C_USER = CURSOR FAST_FORWARD FOR SELECT [GUID] FROM [#Users]
	OPEN @C_USER FETCH NEXT FROM @C_USER INTO @usGUID

	DECLARE @prsToUser UNIQUEIDENTIFIER

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @prsToUser = (SELECT [guid] FROM [prs000] WHERE ([UserGUID] = @usGUID) AND ([Name] = @prsName))
		IF ISNULL( @prsToUser, 0x0) != 0x0
			EXEC prcDeletePrintStyle @prsToUser
		
		DECLARE @pGuid UNIQUEIDENTIFIER
		SET @pGuid = newid()

		UPDATE [#prs]
		SET 
			[guid] = @pGuid,
			[UserGUID] = @usGUID

		DELETE [#fnOld]
		INSERT INTO [#fnOld] SELECT newid(), [guid] FROM [#fn]

		UPDATE [#prh]
		SET 
			[guid] = newid(),
			[ParentGUID] = @pGuid
		
		UPDATE [#fn]
		SET 
			[GUID] = [f].[NewGUID]
		FROM 
			[#fn] [fn]
			INNER JOIN [#fnOld] [f] ON [f].[OldGUID] = [fn].[GUID]

		UPDATE [#prh]
		SET 
			[FontGUID] = [f].[NewGUID]
		FROM 
			[#prh] [prh]
			INNER JOIN [#fnOld] [f] ON [f].[OldGUID] = [prh].[FontGUID]

		INSERT INTO [prs000] SELECT * FROM [#prs]
		INSERT INTO [prh000] SELECT * FROM [#prh]
		INSERT INTO [fn000] SELECT * FROM [#fn]

		FETCH NEXT FROM @C_USER INTO @usGUID
	END
	CLOSE @C_USER DEALLOCATE @C_USER
##########################################################################
#END
