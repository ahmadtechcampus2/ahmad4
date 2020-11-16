#########################################################
CREATE TRIGGER trg_fm000_CheckConstraints
	ON [fm000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to delete fm records while used in mn				(AmnE0100)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when deleting fm records while Manufacturing record found related to it.
	-- m.Type = 1 >> Normal Manufacturing 

	IF NOT EXISTS(SELECT * FROM [inserted])
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0100: Can''t delete form(s), depending Manufacturing record(s) found', [d].guid
			from [deleted] [d] inner join [mn000] [m] on [d].[GUID] = [m].[formGuid] and [m].[Type] = 1


#########################################################
CREATE TRIGGER trg_fm000_delete
	ON [fm000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- deletes related records: Branches, Template Mn 
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- mn.Type = 0 >> Template Manufacture
	DELETE [Mn000] FROM [Mn000] INNER JOIN [deleted] ON [Mn000].[FormGUID] = [deleted].[GUID] AND [Mn000].[Type] = 0

#########################################################
#END