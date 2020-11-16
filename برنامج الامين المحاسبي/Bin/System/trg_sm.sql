#########################################################
CREATE TRIGGER trg_sm000_CheckConstraints
	ON [sm000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to delete used special offer
*/
	IF @@ROWCOUNT = 0
		RETURN

	SET NOCOUNT ON

	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1], [i1])
		SELECT 1, 0, 'AmnE1060: Can''t delete Special offer(s), it''s being used ...', guid, [dbo].[fnIsMatBonusUsed]([GUID])
		FROM [deleted]
		WHERE  [dbo].[fnIsMatBonusUsed]([GUID]) <> 0
#########################################################
CREATE TRIGGER trg_sm000_delete
	ON [sm000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
	- deletes related records: sd000
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- deleting related data:
	DELETE [sd000] FROM [sd000] INNER JOIN [deleted] ON [sd000].[ParentGUID] = [deleted].[GUID]
	DELETE [smBt000] FROM [smBt000] INNER JOIN [deleted] ON [smBt000].[ParentGUID] = [deleted].[GUID]

#########################################################
#END