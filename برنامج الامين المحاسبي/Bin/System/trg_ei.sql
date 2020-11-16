#########################################################
CREATE TRIGGER trg_ei000_CheckConstraints
	ON [ei000] FOR INSERT
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to use main CostJobs.									(AmnE0220)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[CostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0220: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END
 
#########################################################
#END