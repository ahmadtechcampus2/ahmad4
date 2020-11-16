#########################################################
CREATE TRIGGER trg_dd000_CheckConstraints
	ON [dd000] FOR INSERT
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to insert a dd000 record without parent:		(AmnE0140)
	- not to use main CostJobs.									(AmnE0141)

*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON 
		
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0140: parent record(s) not found…', [i].[guid]
		FROM [inserted] [i] LEFT JOIN [dp000] [d] ON [i].[parentGUID] = [d].[guid]
		WHERE [d].[guid] is null

/*
	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM inserted AS i INNER JOIN co000 AS c ON i.CostGuid = c.Guid INNER JOIN co000 AS c2 ON c.Guid = c2.ParentGuid)
	BEGIN
		RAISERROR('AmnE0141: Can''t use main CostJobs', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END
*/

#########################################################
#END