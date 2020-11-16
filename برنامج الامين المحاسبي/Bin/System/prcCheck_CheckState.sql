###########################################################################
CREATE PROC prcCheck_CheckState
	@chGuid UNIQUEIDENTIFIER,
	@state INT 
AS 
	SET NOCOUNT ON

	-- Check not exists
	IF NOT EXISTS( SELECT [guid] FROM [ch000] WHERE [guid] = @chGuid)
		RETURN 0

	DECLARE 
		@CheckState INT

	SET @CheckState = (SELECT [state] FROM [ch000] WHERE [guid] = @chGuid)
	
	IF @state & @CheckState != 0
		RETURN 0
		
	IF (@state = -1) OR (@state = 0)
		RETURN 0

	IF (@state = 1)
	BEGIN
		IF @CheckState = 64	-- Collected partly
			RETURN 1
		IF @CheckState != 0
			RETURN 0
		IF EXISTS (SELECT * FROM [er000] WHERE [ParentGUID] = @chGuid AND [ParentType] = 6)
			DELETE [er000] WHERE [ParentGUID] = @chGuid AND [ParentType] = 6
	END 
	RETURN 1
###########################################################################
CREATE PROC prcGetCollectedPartly
	@chGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		[ColCh].[Guid] AS [ColGUID],		
		[ColCh].[Date] AS [ColDate],
		[ColCh].[Number] AS [ColNumber],
		[ColCh].[EntryGUID] AS [EntryGUID],
		ISNULL( [Ce].[Number], 0) AS [EntryNumber]
	FROM 
		[Ch000] [Ch]
		INNER JOIN [ColCh000] [ColCh] ON [Ch].[GUID] = [ColCh].[ChGUID]
		LEFT JOIN [Ce000] [Ce] ON [Ce].[GUID] = [ColCh].[EntryGUID]
	WHERE 
		[Ch].[GUID] = @chGuid
	ORDER BY
		[ColNumber],
		[ColDate]
###########################################################################
#END
