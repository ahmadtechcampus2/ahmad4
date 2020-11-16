#########################################################
CREATE TRIGGER trg_cu000_useFlag
	ON [cu000] FOR INSERT, UPDATE, DELETE
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
			UPDATE [ac000] SET [UseFlag] = [a].[UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccountGUID]

		IF EXISTS(SELECT * FROM [inserted])
			UPDATE [ac000] SET [UseFlag] = [a].[UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccountGUID]
	END

#########################################################
CREATE TRIGGER trg_cu000_CheckMaxDebit
	ON [dbo].[cu000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON  
	 
	
	DECLARE @Cust TABLE ([GUID] [UNIQUEIDENTIFIER], Warn FLOAT  ,OldBalance  FLOAT , NewBalance FLOAT , MaxDebit FLOAT)
	DECLARE @UpdatedCount	INT

	IF  UPDATE([Debit]) OR UPDATE([Credit]) OR UPDATE([MaxDebit]) OR UPDATE([Warn]) 
	BEGIN 
		INSERT INTO @Cust
		SELECT 
			ISNULL([i].[GUID], [d].[GUID])  AS [Guid], 
			ISNULL([i].[Warn], [d].[Warn]) Warn, 
			CASE [i].[Warn] WHEN 1 THEN ISNULL(([d].[Debit] - [d].[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL(([d].[Credit] - [d].[Debit]), 0) - ISNULL(ch.Value, 0)) END OldBalance, 
			CASE [i].[Warn] WHEN 1 THEN ISNULL(([i].[Debit] - [i].[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL(([i].[Credit] - [i].[Debit]), 0) - ISNULL(ch.Value, 0)) END NewBalance,
			ISNULL(i.[MaxDebit], [d].[MaxDebit])  
		FROM 
			[inserted] AS [i] 
			inner join ac000 ac on ac.GUID = [i].AccountGUID
			FULL JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID] 
			OUTER APPLY dbo.fnCheque_AccCust_GetBudgetValue(i.accountGUID, i.GUID, i.ConsiderChecksInBudget) ch
		WHERE 
			ISNULL([i].[Warn], [d].[Warn]) > 0

		SET @UpdatedCount = @@ROWCOUNT
		IF @UpdatedCount = 0 
			RETURN

		DELETE @Cust WHERE NewBalance <= MaxDebit OR Warn = 0
		IF NOT EXISTS(SELECT * FROM @Cust)
			RETURN
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 2, 0, 'AmnW0095: ' + CAST([guid] AS NVARCHAR(36)) + ' Account exceeded its Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid FROM @Cust WHERE OldBalance < MaxDebit
			UNION ALL  
			SELECT 2, 0, 'AmnW0096: ' + CAST([guid] AS NVARCHAR(36)) + ' Account is re-exceeded its Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid FROM @Cust WHERE OldBalance < NewBalance AND NOT(OldBalance < MaxDebit)
			UNION ALL  
			SELECT 2, 0, 'AmnW0097: ' + CAST([guid] AS NVARCHAR(36)) + ' Account has lowered its balance but still over Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid  FROM @Cust WHERE NOT(OldBalance < NewBalance  OR OldBalance < MaxDebit)
	END 
#########################################################
CREATE TRIGGER trg_cu000_CheckConstraints
	ON [cu000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
/* 
This trigger checks: 
	- not to delete used customers
*/
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON  
	 
	--study a case when deleting used accounts: 
	IF NOT EXISTS(SELECT * FROM [inserted]) AND EXISTS(SELECT * FROM [deleted]) 
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0800: Can''t delete customer, it''s being used in Payment',
			d.GUID 
		FROM 
			en000 en 
			INNER JOIN deleted d ON en.CustomerGUID = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0801: Can''t delete customer, it''s being used in Cheque',
			d.GUID 
		FROM 
			ch000 ch
			INNER JOIN deleted d ON ch.CustomerGUID = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0802: Can''t delete customer, it''s being used in bill',
			d.GUID 
		FROM 
			bu000 bu
			INNER JOIN deleted d ON bu.CustGUID = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0803: Can''t delete customer, it''s being used in Assets',
			d.GUID 
		FROM 
			vwAssAdded
			INNER JOIN deleted d ON vwAssAdded.axCustomerGuid = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0804: Can''t delete customer, it''s being used in AccountCost',
			d.GUID 
		FROM 
			ci000
			INNER JOIN deleted d ON ci000.CustomerGuid = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0805: Can''t delete customer, it''s being used in AccCostNewRatio',
			d.GUID 
		FROM 
			AccCostNewRatio000
			INNER JOIN deleted d ON AccCostNewRatio000.CustomerGuid = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0806: Can''t delete customer, it''s being used in bill type',
			d.GUID 
		FROM 
			bt000 bt
			INNER JOIN deleted d ON bt.CustAccGuid = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0906: Can''t delete customer, it''s being used in allotment',
			d.GUID 
		FROM 
			Allocations000
			INNER JOIN deleted d ON Allocations000.CustomerGUID = d.GUID 
			LEFT JOIN inserted i ON d.GUID = i.GUID 
		WHERE 
			i.GUID IS NULL
	END
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [Cu000] AS [cu] ON [cu].[BarCode] = [i].[BarCode] AND [cu].[Guid] <> [i].[Guid] WHERE [i].[BarCode] <> '' )
	BEGIN
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 2, 0, 'AmnW0550: BarCode is found…', [i].[guid]
		FROM [inserted] AS [i] INNER JOIN [Cu000] AS [cu] ON [cu].[BarCode] = [i].[BarCode] AND [cu].[Guid] <> [i].[Guid] WHERE [i].[BarCode] <> '' 
	END 
#########################################################
#END