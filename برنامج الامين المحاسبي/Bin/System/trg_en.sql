#########################################################
create trigger trg_en000_checkConstraints
	on [en000] for insert, update, delete 
	NOT FOR REPLICATION

as 
/*  
This trigger checks:  
	- missing parentGuid					(AmnE0270) 
	- not to touch posted records.	(AmnE0271) 
	- warns on bp presence.				(AmnW0272) 
*/  

	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- check to see if inserting missing parentGuid: 
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0270: missing entry header: prarent ce not found.', [i].guid
		FROM [inserted] [i] LEFT JOIN [ce000] [c] ON [i].[parentGuid] = [c].[guid]
		WHERE [c].[guid] is null

	-- check to see if touching posted related ce: excluded touching contraAccGuid
	-- the number 1 is the bitwise value of contraAccGuid column at en000, calculated from the following indian algorithm
	IF (UPDATE([Debit]) OR UPDATE([Credit]) OR UPDATE([AccountGUID]) OR UPDATE([CurrencyGUID]) OR UPDATE([CurrencyVal]) OR UPDATE([CostGUID]) OR UPDATE([ParentGUID]) OR UPDATE([Date]))
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0271: Can''t touch posted entry(ies)', [d].guid
			FROM [deleted] [d] INNER JOIN [ce000] [c] ON [d].[parentGuid] = [c].[guid] WHERE [c].[isposted] <> 0

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0271: Can''t touch posted entry(ies)', [i].guid
			FROM [inserted] [i] INNER JOIN [ce000] [c] ON [i].[parentGuid] = [c].[guid] WHERE [c].[isPosted] <> 0
 	END

#########################################################
CREATE TRIGGER trg_en000_useFlag
	ON [en000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	DECLARE @t TABLE ([g] [UNIQUEIDENTIFIER])	

	INSERT INTO @T 
	SELECT [D].[AccountGUID] FROM [DELETED] [D] LEFT JOIN [INSERTED] [I] ON [D].[GUID] = [I].[GUID] WHERE [I].[GUID] IS NULL 
	UNION ALL 
	SELECT [D].[ContraAccGUID] FROM [DELETED] [D] LEFT JOIN [INSERTED] [I] ON [D].[GUID] = [I].[GUID] WHERE [I].[GUID] IS NULL 

	IF EXISTS( SELECT * FROM @t)
	BEGIN 
		UPDATE [AC000] SET [USEFLAG] = [USEFLAG] - (SELECT COUNT(*) FROM @T WHERE [G] = [AC000].[GUID])
		FROM [AC000] 
		WHERE [GUID] IN (SELECT [G] FROM @T) 
	END 
		
	DELETE @T 

	IF UPDATE([AccountGUID]) OR UPDATE([ContraAccGUID])
	BEGIN
		INSERT INTO @t 
		SELECT [AccountGUID] FROM [deleted]
		UNION ALL 
		SELECT [ContraAccGUID] FROM [deleted]

		IF EXISTS( SELECT * FROM @t)
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - (SELECT COUNT(*) FROM @t WHERE [g] = [ac000].[guid])
			FROM [ac000]
			WHERE [guid] IN (SELECT [g] FROM @t)
		END 			
			
		DELETE @t

		INSERT INTO @t 
		SELECT [AccountGUID] FROM [inserted]
		UNION ALL 
		SELECT [ContraAccGUID] FROM [inserted]

		IF EXISTS( SELECT * FROM @t)
		BEGIN 
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + (SELECT COUNT(*) FROM @t WHERE [g] = [ac000].[guid])
			FROM [ac000]
			WHERE [guid] IN (SELECT [g] FROM @t)
		END			
	END

#########################################################
CREATE TRIGGER trg_en000_delete
	ON [en000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - deletes related bp, if any
*/
	IF @@rowcount = 0 RETURN
	SET NOCOUNT ON

	DELETE [bp000] 
	FROM 
		[bp000] [b] 
		INNER JOIN [deleted] [d] ON ([b].[debtGuid] = [d].[guid]) OR ([b].[payGuid] = [d].[guid])
	
	IF [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 0X1025, 0x00, 1, 0) <= 0
			insert into ErrorLog ([level], [type], [c1], [g1]) 
			select 1, 0, 'AmnE0066: there are checked Fields[' + c.Code + '-' + c.Name + ']', accountguid FROM [RCH000] A INNER JOIN [deleted] d ON   A.[ObjGUID]  = d.Guid INNER JOIN [ac000] c ON c.Guid = d.accountguid 
#########################################################
#END
