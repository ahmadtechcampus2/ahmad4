#########################################################
CREATE TRIGGER trg_us000_delete ON [us000] FOR DELETE
NOT FOR REPLICATION
AS
/*
	delete related:
	- ma000
	- branches
	- delete ui.
	- delete uix.
	- delete rt.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	DELETE [rt000]	FROM [rt000]	AS [r]	INNER JOIN [deleted] AS [d] ON [r].[ChildGUID] = [d].[GUID]
	
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0300: Can''t delete role(s). Some user(s) depends on.', [d].[GUID]
		FROM [deleted] [d] INNER JOIN [rt000] [rt] ON [rt].[ParentGUID] = [d].[GUID]
		
	DELETE [ma000]	FROM [ma000]	AS [m]	INNER JOIN [deleted] AS [d] ON [m].[ObjGUID] = [d].[GUID]
	DELETE [ui000]	FROM [ui000]	AS [u]	INNER JOIN [deleted] AS [d] ON [u].[UserGUID] = [d].[GUID]
	DELETE [uix]	FROM [uix]		AS [u]	INNER JOIN [deleted] AS [d] ON [u].[UserGUID] = [d].[GUID]
	DELETE [umd] FROM [UserMaxDiscounts000] AS [umd] INNER JOIN [deleted] AS [d] ON [umd].[UserGUID] = [d].[GUID]

#########################################################
CREATE TRIGGER trg_us000_setdirty ON [us000] FOR INSERT, UPDATE, DELETE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS (SELECT * FROM [INSERTED] WHERE [TYPE] = 1 /*ROLE*/) 
	BEGIN
		UPDATE 
			[US000] 
		SET 
			[DIRTY] = 1,
			[Number] = [u].[Number],
			[Guid] = [u].[Guid]
		FROM 
			[US000] AS [u] 
			INNER JOIN [RT000] AS [r] ON [u].[GUID] = [r].[ChildGUID] 
			INNER JOIN [INSERTED] AS [i] ON [i].[GUID] = [r].[ParentGUID]
		WHERE 
			[i].[Type] = 1
	END

	IF EXISTS (SELECT * FROM [DELETED] WHERE [TYPE] = 1 /*ROLE*/) 
	BEGIN
		UPDATE 
			[US000] 
		SET 
			[DIRTY] = 1,
			[Number] = [u].[Number],
			[Guid] = [u].[Guid]
		FROM 
			[US000] AS [u] 
			INNER JOIN [RT000] AS [r] ON [u].[GUID] = [r].[ChildGUID] 
			INNER JOIN [DELETED] AS [d] ON [d].[GUID] = [r].[ParentGUID]
		WHERE 
			[d].[Type] = 1
	END
#########################################################
CREATE TRIGGER trg_us000_modify_password ON [us000] FOR UPDATE, INSERT
	NOT FOR REPLICATION
AS
BEGIN
	IF @@ROWCOUNT = 0 RETURN
	IF NOT UPDATE ([Password]) RETURN
	SET NOCOUNT ON

	DECLARE @MxNumber BIGINT = (SELECT ISNULL(MAX(Number), 0) FROM UsPasHistory000)

	INSERT INTO UsPasHistory000 
		SELECT NEWID(), (@MxNumber + ROW_NUMBER() OVER (ORDER BY Number)), GUID, GETDATE(), LoginName, Password FROM inserted
	
	SELECT h.UserGuid
		INTO #UsersID FROM UsPasHistory000 h INNER JOIN inserted u ON h.UserGuid = u.GUID
			GROUP BY h.UserGuid
			HAVING COUNT(*) > 3

	WHILE EXISTS (SELECT TOP 1 * FROM #UsersID)
		BEGIN
		DECLARE @UserId UNIQUEIDENTIFIER = (SELECT TOP 1 UserGuid FROM #UsersID)
			DELETE FROM UsPasHistory000 WHERE UserGuid = @UserId AND GUID NOT IN 
				(SELECT TOP 3 GUID FROM UsPasHistory000 AS h WHERE h.UserGuid = @UserId ORDER BY Number DESC)
			DELETE FROM #UsersID WHERE UserGuid = @UserId
		END
END
#########################################################
#END