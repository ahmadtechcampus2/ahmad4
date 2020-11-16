#########################################################
CREATE TRIGGER trg_bi000_CheckConstraints
	ON [bi000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- new bi records have related parents. 			(AmnE0011)
	- affected records are related to non posted bills.	(AmnE0012)
	- not to use main stores.							(AmnE0013)
	- not to use main CostJobs.						(AmnE0014)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- missing parents:
	IF EXISTS(SELECT * FROM [inserted] AS [i] LEFT JOIN [bu000] AS [b] ON [i].[ParentGUID] = [b].[GUID] WHERE [b].[GUID] IS NULL)
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0011: Related Bills are missing'

	-- posted parents:
	IF NOT UPDATE([Profits]) AND NOT UPDATE(UnitCostPrice) AND EXISTS(
			SELECT * FROM [bu000] INNER JOIN (SELECT [ParentGUID] FROM [inserted] UNION ALL SELECT [ParentGUID] FROM [deleted]) AS [InsDel]
			ON [bu000].[GUID] = [InsDel].[ParentGUID] WHERE [bu000].[IsPosted] <> 0)
		insert into [ErrorLog] ([level], [type], [c1]) select 1, 0, 'AmnE0012: Related Bills found Posted'
	-- study a case when using main Stores (NSons <> 0):
	/*
	IF EXISTS(SELECT * FROM inserted AS i INNER JOIN st000 AS s ON i.StoreGuid = s.Guid INNER JOIN st000 AS s2 ON s.Guid = s2.ParentGuid)
		insert into ErrorLog (level, type, c1) select 1, 0, 'AmnE0013: Can''t use main stores'

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM inserted AS i INNER JOIN co000 AS c ON i.StoreGuid = c.Guid INNER JOIN co000 AS c2 ON c.Guid = c2.ParentGuid)
		insert into ErrorLog (level, type, c1) select 1, 0, 'AmnE0014: Can''t use main CostJobs'

	*/

#########################################################
#END
