#########################################################
CREATE TRIGGER trg_py000_useFlag
	ON [py000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([AccountGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccountGUID]

		IF EXISTS(SELECT * FROM [inserted])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccountGUID]
	END

#########################################################
CREATE TRIGGER trg_py000_delete
	ON [py000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
	- deletes related records in er and ce and LCRelatedExpense
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	DELETE [LCRelatedExpense000] FROM [LCRelatedExpense000] INNER JOIN [deleted] ON [deleted].[GUID] = [ItemParentGUID]
	
	-- currently this trigger needs followup programming in C++
	-- so it will do nothing right now.
	--DELETE [en000] FROM [en000] [e] INNER JOIN [deleted] [d] ON [e].[parentGuid] = [d].[GUID]
	--DELETE [er000] FROM [er000] [e] INNER JOIN [deleted] [d] ON [e].[ParentGUID] = [d].[GUID]

#########################################################
CREATE TRIGGER trg_py000_insert
	ON [dbo].[py000] FOR INSERT
	NOT FOR REPLICATION

AS   
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	IF EXISTS (SELECT * FROM inserted WHERE ISNULL(CreateUserGUID, 0x0) = 0x0)
	BEGIN 
		UPDATE py 
		SET 
			CreateUserGUID = [dbo].[fnGetCurrentUserGUID](),
			CreateDate = GETDATE()
		FROM 
			py000 py 
			INNER JOIN inserted i ON py.GUID = i.GUID 
		WHERE 
			ISNULL(i.CreateUserGUID, 0x0) = 0x0
	END 
#########################################################
#END