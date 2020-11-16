#########################################################
CREATE TRIGGER trg_nt000_CheckConstraints
	ON [nt000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to use main CostJobs.	(AmnE0250)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only
		INSERT INTO [ErrorLog] ([level], [type], c1, g1) 
			SELECT 1, 0, 'AmnE0251: Can''t delete note template, it''s being used', [c].[guid] 
			FROM [ch000] AS [c] INNER JOIN [deleted] AS d ON [c].[TypeGUID] = [d].[GUID]

	IF EXISTS( SELECT * FROM [inserted] AS [i] INNER JOIN [ch000] AS [c] ON [i].[guid] = [c].[TypeGuid] WHERE [i].[bPayable] = 0 and [c].[Dir] = 2)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], c1, g1)
			SELECT 1, 0, 'AmnE0252: Can''t update note template to unpayable, there,re payable checks.', [c].[guid]
			FROM [ch000] AS [c] INNER JOIN [inserted] AS [i] ON [c].[TypeGUID] = [i].[GUID] WHERE [i].[bPayable] = 0 and [c].[Dir] = 2
	END 

	IF EXISTS( SELECT * FROM [inserted] AS [i] INNER JOIN [ch000] AS [c] ON [i].[guid] = [c].[TypeGuid] WHERE [i].[bReceivable] = 0 and [c].[Dir] = 1)
	BEGIN 
		INSERT INTO [ErrorLog] ([level], [type], c1, g1)
			SELECT 1, 0, 'AmnE0253: Can''t update note template to unreceivable, there,re receivable checks.', [c].[guid]  
			FROM [ch000] AS [c] INNER JOIN [inserted] AS [i] ON [c].[TypeGUID] = [i].[GUID] WHERE [i].[bReceivable] = 0 and [c].[Dir] = 1
	END 
	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[CostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0240: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END
 
#########################################################
CREATE TRIGGER trg_nt000_useFlag
	ON [nt000] FOR INSERT, UPDATE, DELETE
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	IF		UPDATE([DefPayAccGUID]) OR UPDATE([DefRecAccGUID]) OR UPDATE([DefColAccGUID])
		 OR UPDATE([DefRecOrPayAccGUID]) OR UPDATE([DefUnderDisAccGUID]) OR UPDATE([DefComAccGUID])
		 OR UPDATE([DefChargAccGUID]) OR UPDATE([DefEndorseAccGUID]) OR UPDATE([DefDisAccGUID])
		 OR UPDATE([ExchangeRatesAccGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefPayAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefRecAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefColAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefRecOrPayAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefUnderDisAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefComAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefChargAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefEndorseAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefDisAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[ExchangeRatesAccGUID]
		END
		IF EXISTS(SELECT * FROM [inserted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefPayAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefRecAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefColAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefRecOrPayAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefUnderDisAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefComAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefChargAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefEndorseAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefDisAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[ExchangeRatesAccGUID]
		END
	END
#########################################################
CREATE TRIGGER trg_ChequesPortfolio_useFlag
	ON [ChequesPortfolio000] FOR INSERT, UPDATE, DELETE
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM [deleted])
	BEGIN
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[ReceiveAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[PayAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[ReceivePayAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[EndorsementAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[CollectionAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[UnderDiscountingAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DiscountingAccGUID]
	END

	IF EXISTS(SELECT * FROM [inserted])
	BEGIN
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[ReceiveAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[PayAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[ReceivePayAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[EndorsementAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[CollectionAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[UnderDiscountingAccGUID]
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN  [inserted] AS [d] ON [a].[GUID] = [d].[DiscountingAccGUID]
	END
#########################################################
#END