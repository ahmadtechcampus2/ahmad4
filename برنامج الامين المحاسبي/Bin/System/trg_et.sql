#########################################################
CREATE TRIGGER trg_et000_useFlag
	ON [et000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([DefAccGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefAccGUID]

		IF EXISTS(SELECT * FROM [inserted]) AND UPDATE([DefAccGUID])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefAccGUID]
	END
	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only
		INSERT INTO [ErrorLog] ([level], [type], c1, g1) 
			SELECT 1, 0, 'AmnE0310: Can''t delete pay template, it''s being used', [p].[guid] 
			FROM [py000] AS [p] INNER JOIN [deleted] AS d ON [p].[TypeGUID] = [d].[GUID]

	IF NOT EXISTS (SELECT * FROM [inserted])
		BEGIN
			IF EXISTS(SELECT TOP(1) DirectExpensesEntryTypeGuid FROM Manufactory000 m inner join deleted d ON d.GUID = m.DirectExpensesEntryTypeGuid)
				BEGIN			
					INSERT INTO ErrorLog ([level], [type], [c1], [g1])
						   SELECT 1, 
								  0,  
								  'AmnE0313 : Can''t delete pay template it''s being used in factory type ' ,
								  GUID 
						   FROM deleted
				END
		END
	IF EXISTS(SELECT * FROM INSERTED I INNER JOIN DELETED D ON D.GUID = I.GUID WHERE D.FldDebit <> 0 AND D.FldCredit = 0)
		BEGIN	
			IF EXISTS(SELECT * FROM INSERTED I WHERE I.FldDebit = 0 OR I.FldCredit <> 0) AND EXISTS(SELECT DirectExpensesEntryTypeGuid FROM Manufactory000 m inner join deleted d ON d.GUID = m.DirectExpensesEntryTypeGuid)
				BEGIN
					INSERT INTO ErrorLog ([level], [type], [c1], [g1])
						   SELECT TOP(1) 1, 
										 0,  
										 'AmnE0314 :  Can''t update pay template it''s being used in factory type,' + m.Name,
										  D.[GUID]
							FROM deleted AS D INNER JOIN Manufactory000 AS M ON M.DirectExpensesEntryTypeGuid = D.GUID
				END
		END
#########################################################
#END