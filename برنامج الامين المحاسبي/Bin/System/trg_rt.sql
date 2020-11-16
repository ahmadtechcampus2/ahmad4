#########################################################
CREATE TRIGGER trg_rt000_CheckConstraints
	ON [rt000] FOR INSERT, UPDATE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- that new hosting parents are never descendants of the moving branches (Short-Circuit).
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	
	
	DECLARE 
		@c			CURSOR, 
		@ChildGUID	[UNIQUEIDENTIFIER]


	DECLARE @t TABLE([Parent] [UNIQUEIDENTIFIER], [Child] [UNIQUEIDENTIFIER])

	SET @c = CURSOR FAST_FORWARD FOR 
					SELECT [ChildGUID] FROM [inserted] AS [i]

	OPEN @c FETCH FROM @c INTO @ChildGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (SELECT COUNT(*) from [fnGetUserRolesList](@ChildGUID) WHERE [GUID] = @ChildGUID) > 1
			insert into [ErrorLog] ([level], [type], [c1])
				select 1, 0, 'AmnE0120: Parent(s) found descending from own sons (Short Circuit)...'

		FETCH FROM @c INTO @ChildGUID
	END

	CLOSE @c DEALLOCATE @c
	
#########################################################
CREATE TRIGGER trg_rt000_delete
	ON [rt000] FOR DELETE
	NOT FOR REPLICATION
AS
	-- delete related ma
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DELETE [ma000] FROM [ma000] AS [m] INNER JOIN [deleted] AS [d] ON [m].[ObjGUID] = [d].[GUID]

#########################################################
CREATE TRIGGER trg_rt000_SetDirtyFlag
	ON [rt000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	UPDATE [us000] 
	SET 
		[Number] = [u].[Number],
		[GUID] = [u].[GUID],
		[Dirty] = 1
	FROM 
		[INSERTED] AS [i] 
		INNER JOIN [us000] AS [u] ON [i].[ChildGUID] = [u].[GUID]
#########################################################
#END