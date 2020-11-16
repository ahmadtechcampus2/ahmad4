#########################################################
CREATE TRIGGER trg_bt000_CheckConstraints
	ON [bt000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to delete used bill templates.
	- not to use main accounts.
	- not to use main stores.
	- not to use main costJobs.
*/
	-- study a case when deletinf used bts:
	SET NOCOUNT ON 
	
	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only
		INSERT INTO [ErrorLog] ([level], [type], c1, g1) 
			SELECT 1, 0, 'AmnE0150: Can''t delete bill template, it''s being used', [b].[guid] 
			FROM [bu000] AS [b] INNER JOIN [deleted] AS d ON [b].[TypeGUID] = [d].[GUID]

	-- ”‰œ«  «·«” Õﬁ«ﬁ «·„œÊ—…
	IF NOT EXISTS (SELECT * FROM [inserted]) -- deleteing only
		INSERT INTO [ErrorLog] ([level], [type], c1, g1) 
			SELECT 1, 0, 'AmnE0150: Can''t delete bill template, it''s being used', [ce].[guid] 
			FROM [ce000] AS [ce] INNER JOIN [deleted] AS d ON [ce].[TypeGUID] = [d].[GUID]

	IF EXISTS(
			SELECT *
			FROM [inserted] AS [i] INNER JOIN [ac000] AS [a] ON 
				[i].[DefBillAccGUID] = [a].[GUID] OR
				[i].[DefCashAccGUID] = [a].[GUID] OR
				[i].[DefDiscAccGUID] = [a].[GUID] OR
				[i].[DefExtraAccGUID] = [a].[GUID] OR
				[i].[DefVATAccGUID] = [a].[GUID] OR
				[i].[DefCostAccGUID] = [a].[GUID] OR
				[i].[DefStockAccGUID] = [a].[GUID]
			WHERE [a].[NSons] <> 0)
	BEGIN
		RAISERROR('AmnE0151: Can''t use main Accounts', 16, 1)
		ROLLBACK TRANSACTION
		RETURN
	END

	-- study a case when using main Stores (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [st000] AS [s] ON [i].[DefStoreGuid] = [s].[Guid] INNER JOIN [st000] AS [s2] ON [s].[Guid] = [s2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0152: Can''t use main stores', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[DefCostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0153: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

#########################################################
CREATE TRIGGER trg_bt000_useFlag
	ON [bt000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([DefBillAccGUID]) OR UPDATE([DefCashAccGUID]) OR UPDATE([DefDiscAccGUID]) OR UPDATE([DefExtraAccGUID]) OR UPDATE([DefVATAccGUID]) OR UPDATE([DefCostAccGUID]) OR UPDATE([DefStockAccGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefBillAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefCashAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefDiscAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefExtraAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefVATAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefCostAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[DefStockAccGUID]
            -------------------------------------------
		END
		IF EXISTS(SELECT * FROM [inserted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefBillAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefCashAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefDiscAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefExtraAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefVATAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefCostAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[DefStockAccGUID]
		END
			
	END
#########################################################
CREATE TRIGGER trg_bt000_MaturityBills
	ON [bt000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

	As
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM [inserted])
	BEGIN
	---------------ÃœÊ·  Œ’Ì’ «·›Ê« Ì— ›Ì ·ÊÕ…  Õ–Ì—«  ”ÿÕ «·„ﬂ »
		INSERT INTO
			MaturityBills000 ([BillTypeGuid], [BillTypeName], [DaysCount], [Type] , [IsChecked])
		SELECT
			[i].[GUID],
			CASE [dbo].[fnConnections_getLanguage]()  WHEN 0 THEN [i].[Name] ELSE [i].[LatinName] END,
			0,
			[i].[Type],
			0
		FROM 
			[INSERTED] [i] 
		WHERE
			([i].[bPayTerms] = 1   --›Ê« Ì— »‘—ÿ „”»ﬁ… «·œ›⁄
            OR [i].[Type] = 5 OR [i].[Type] = 6) --ÿ·»Ì« 
			AND NOT EXISTS(SELECT * FROM MaturityBills000 MB WHERE MB.BillTypeGuid = I.[Guid])

		IF UPDATE(Name) OR UPDATE(LatinName) OR UPDATE([Type])
		BEGIN
			UPDATE MB
			SET BillTypeName = CASE [dbo].[fnConnections_getLanguage]()  WHEN 0 THEN [i].[Name] ELSE [i].[LatinName] END,
				[Type] = I.[Type]
			FROM 
				MaturityBills000 MB 
				JOIN inserted I ON I.Guid = MB.BillTypeGuid
		END

		IF Update([bPayTerms]) 
		BEGIN
			DELETE [m]
			FROM 
				MaturityBills000 [m]
				INNER JOIN inserted [i] ON [i].[Guid] = [m].[BillTypeGuid]
			WHERE 
				[i].[bPayTerms] = 0   --›Ê« Ì— »‘—ÿ „”»ﬁ… «·œ›⁄
	            AND [i].[Type] NOT IN (5,6) --ÿ·»Ì« 
		END
	END

	IF EXISTS(SELECT * FROM [deleted]) AND NOT EXISTS(SELECT * FROM inserted)
	BEGIN
		Delete [m]
		FROM 
			MaturityBills000 [m]
			INNER JOIN deleted [d] ON [d].[Guid] = [m].[BillTypeGuid]
		WHERE
			[d].[Guid] = [m].[BillTypeGuid]
	END
#########################################################
CREATE TRIGGER trg_bt000_delete
	ON [bt000] FOR DELETE
	NOT FOR REPLICATION

AS
	SET NOCOUNT ON 

	IF [dbo].[fnObjectExists]('Manufactory000') <> 0 
	BEGIN
		IF EXISTS( SELECT * FROM  [Manufactory000] manuf WHERE manuf.FinishedGoodsBillType in (select [Guid] from [deleted] )
		                                                    or manuf.MatRequestBillType in (select [Guid] from [deleted]) 
															or manuf.MatReturnBillType in (select [Guid] from [deleted]) 
															or manuf.OutTransBillType in (select [Guid] from [deleted]) 
															or manuf.InTransBillType in (select [Guid] from [deleted])    )
		BEGIN
			RAISERROR('AmnE0154: bill type is used', 16, 1)
			ROLLBACK TRANSACTION
		    RETURN
		EnD
	END

	-- delete related ma
	DELETE [ma000] FROM [ma000] AS [m] INNER JOIN [deleted] AS [d] ON [m].[BillTypeGUID] = [d].[GUID]
	UPDATE BNO 
    SET BNO.orderindex = (BNO.orderindex - 1)
    FROM [BillNumberOrder000] BNO 
    WHERE BNO.orderindex >
    (   
    select b.orderindex
    from  [BillNumberOrder000] b
    INNER JOIN deleted AS del ON del.GUID = b.GUID 
    )
	DELETE [BillNumberOrder000] FROM [BillNumberOrder000] AS BN INNER JOIN [deleted] AS del ON del.[GUID]=BN.[GUID]

#########################################################
CREATE TRIGGER trg_bt000_update
   ON  [dbo].[bt000] 
   AFTER UPDATE
	NOT FOR REPLICATION

AS 
BEGIN
	SET NOCOUNT ON;

	IF [dbo].[fnObjectExists]('Manufactory000') <> 0 
	BEGIN

	    declare @AffectCostPriceBefore bit
		declare @AffectCostPriceAfter bit
		select @AffectCostPriceBefore=bAffectCostPrice from [deleted]
	    select @AffectCostPriceAfter=bAffectCostPrice from [inserted]


		declare @BillTypeBefore int
		declare @BillTypeAfter int
		select @BillTypeBefore=BillType from [deleted]
	    select @BillTypeAfter=BillType from [inserted]

		IF ((@BillTypeBefore = 4 or @BillTypeBefore = 5) and @BillTypeBefore<>@BillTypeAfter)  or @AffectCostPriceBefore <> @AffectCostPriceAfter
		BEGIN
		         IF EXISTS( SELECT * FROM  [Manufactory000] manuf WHERE manuf.FinishedGoodsBillType in (select [Guid] from [deleted] )
		                                                    or manuf.MatRequestBillType in (select [Guid] from [deleted]) 
															or manuf.MatReturnBillType in (select [Guid] from [deleted]) 
															or manuf.OutTransBillType in (select [Guid] from [deleted]) 
															or manuf.InTransBillType in (select [Guid] from [deleted])    )
		          BEGIN
		            	RAISERROR('AmnE0155: bill type is used', 16, 1)
			            ROLLBACK TRANSACTION
		                 RETURN
		          EnD

		END
		
	END
END
#########################################################
#END