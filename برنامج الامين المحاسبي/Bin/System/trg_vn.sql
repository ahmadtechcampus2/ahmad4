#########################################################
CREATE TRIGGER trg_vn000_useFlag
	ON [vn000] FOR INSERT, UPDATE, DELETE
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
#END