#########################################################
CREATE TRIGGER trg_ac000_CheckConstraints
	ON [ac000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
/* 
This trigger checks: 
	- not to delete used accounts 
	- that new Parent(s) are already present (Orphants). 
	- that new hosting parents are never descendants of the moving branches (Short-Circuit). 
	- that no Account should be descending from used accounts 
*/
AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON  
	 
	DECLARE 
		@c				CURSOR, 
		@GUID			[NVARCHAR](128), 
		@Parent			[UNIQUEIDENTIFIER], 
		@NewParent		[UNIQUEIDENTIFIER],
		@UpdatedParent	BIT,
		@UpdatedCount	INT
	
	DECLARE @t TABLE( [g] [UNIQUEIDENTIFIER])
	DECLARE @DelUsed TABLE( [guid] [UNIQUEIDENTIFIER],  [Used] [BIGINT]) 

-- «·Õ”«» „” Œœ„ ›Ì ŒÌ«—«  «·ÿ·»Ì«  «·Œ«’… »«·ÃÂ«“ «·ﬂ›Ì	
	IF NOT EXISTS(SELECT * FROM [inserted]) AND EXISTS(SELECT * FROM deleted d 
			WHERE d.Guid = CAST(((select Value from op000 where name = 'Orders_PocketNewCustomersParentAccount')) AS UNIQUEIDENTIFIER))
	BEGIN
		INSERT INTO [ErrorLog]( [level], [type], [c1]) SELECT 1, 0, 'AmnE0054: Account is used in orders pocket options'
	END

	--study a case when deleting used accounts: 
	IF NOT EXISTS(SELECT * FROM [inserted]) AND EXISTS(SELECT * FROM [deleted]) 
	BEGIN 
		IF EXISTS (SELECT
			 *
		  FROM SubProfitCenter000 PfC
			INNER JOIN  [deleted] d ON d.GUID IN 
			(MainCurrentAccGuid, MainGoodsOfSaleAccGuid, MainCashAccGuid, MainDebitorsAccGuid, MainCreditorsAccGuid))
	   BEGIN
		  INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			 SELECT
				1,
				0,
				'AmnE0155: Can''t delete account, it''s being used in subProfitCenter',
				d.[guid]
				FROM SubProfitCenter000 PfC
				INNER JOIN  [deleted] d ON d.GUID IN 
			(MainCurrentAccGuid, MainGoodsOfSaleAccGuid, MainCashAccGuid, MainDebitorsAccGuid, MainCreditorsAccGuid)
	END 

		IF EXISTS (SELECT
			 *  FROM [ChequesPortfolio000] CP 
			 INNER JOIN [deleted] d ON d.GUID 
						 IN   ([ReceiveAccGUID]
								,[PayAccGUID]
								,[ReceivePayAccGUID]
								,[EndorsementAccGUID]
								,[CollectionAccGUID]
								,[UnderDiscountingAccGUID]
								,[DiscountingAccGUID]))
		 BEGIN
		  INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			 SELECT
				1,
				0,
				'AmnE0156: Can''t delete account, it''s being used in ChequesPortfolio',
				  d.[guid]
				FROM [ChequesPortfolio000] CP 
				 INNER JOIN [deleted] d ON d.GUID 
						 IN   ([ReceiveAccGUID]
								,[PayAccGUID]
								,[ReceivePayAccGUID]
								,[EndorsementAccGUID]
								,[CollectionAccGUID]
								,[UnderDiscountingAccGUID]
								,[DiscountingAccGUID])
		 END


		 IF EXISTS (SELECT * FROM UserOP000 AS O INNER JOIN [deleted] AS D ON CAST(Value AS UNIQUEIDENTIFIER) = D.GUID
			   WHERE O.Name IN ('AmnRest_ZeroCashAccID','AmnRest_DefCashAccID', 'AmnRest_AdjustAccID', 'AmnRest_AdjustAccIDDec',
				'AmnPOS_ZeroCashAccID', 'AmnPOS_AdjustAccID', 'AmnPOS_EarnestAccID', 'AmnPOS_DrawerID'))
		 BEGIN
			  INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				 SELECT
					1,
					0,
					'AmnE0158: Can''t delete account, it''s used in a POS',
					D.[GUID]
					FROM UserOP000 AS O INNER JOIN [deleted] AS D ON CAST(Value AS UNIQUEIDENTIFIER) = D.GUID
			   WHERE O.Name IN ('AmnRest_ZeroCashAccID','AmnRest_DefCashAccID', 'AmnRest_AdjustAccID', 'AmnRest_AdjustAccIDDec',
				'AmnPOS_ZeroCashAccID', 'AmnPOS_AdjustAccID', 'AmnPOS_EarnestAccID', 'AmnPOS_DrawerID')
		 END


		BEGIN
			DECLARE @CustAcc [UNIQUEIDENTIFIER]
			SELECT @CustAcc = D.GUID  FROM deleted D
			IF EXISTS(SELECT 1 FROM Distributor000 WHERE CustomersAccGUID = @CustAcc OR CustAccGUID = @CustAcc)
				BEGIN
					INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
						   SELECT 1, 
								  0,  
								  'AmnE0789: Can''t delete acc, the account used in distribution unit', 
								  @CustAcc
				END
		 END
		-- DELETE @t 
		INSERT INTO 
			@DelUsed
		SELECT 
			[guid], 
			[dbo].[fnAccount_IsUsed]([guid], DEFAULT) Used 
		FROM 
			[deleted]
		
		INSERT INTO @t 
		SELECT 
			[guid] 
		FROM 
			@DelUsed 
		WHERE 
			Used != 0 
				
		IF @@rowcount != 0 
			INSERT INTO [ErrorLog]( [level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0400: ' + CAST ([g] AS VARCHAR(50)) + ' Can''t delete account, it''s being used...Uf:' + CAST ([dbo].[fnAccount_IsUsed]([g],1) AS NVARCHAR(20)), [g] FROM @t 

		-- Notification system		
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0157: card already used in Notification system .can''t delete card', d.[guid]
			from  NSGetAccountUse() fn  inner join [deleted] [d] ON [d].[guid] = [fn].[GUID]

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT
			1,
			0,
			'AmnE0159: Can''t delete account, it''s being used in xPOS',
			d.[guid]
		FROM 
			[deleted] d
			INNER JOIN BankCard000 bc ON d.GUID = bc.ReceiveAccGUID
	END

	IF((SELECT TOP 1 [Type] FROM inserted) = 2 AND UPDATE([IncomeType]))
		UPDATE ac000 SET IncomeType = 0, CashFlowType = 0 WHERE [Type] <> 2 AND FinalGUID = (SELECT TOP 1[Guid] FROM inserted)

	IF(UPDATE(IncomeType))
	BEGIN
		UPDATE FABalanceSheetAccount000 
		SET FSType = FA.IncomeType, IncomeType = AC.IncomeType, CashFlowType = AC.CashFlowType, ClassificationGuid = AC.BalsheetGuid
		FROM inserted AC INNER JOIN ac000 FA ON FA.[GUID] = AC.FinalGUID
		WHERE AccountGUID = AC.[GUID] AND Known = 1
	END

	IF UPDATE([ParentGUID])
		SET @UpdatedParent = 1
	ELSE 
		SET @UpdatedParent = 0

	-- when updating Parents: 
	DECLARE @ACC TABLE ([GUID] [UNIQUEIDENTIFIER], OldParent [UNIQUEIDENTIFIER] , NewParent [UNIQUEIDENTIFIER] , Warn FLOAT  ,OldBalance  FLOAT , NewBalance FLOAT , MaxDebit FLOAT)
	IF @UpdatedParent = 1 OR UPDATE([Debit]) OR UPDATE([Credit]) OR UPDATE([MaxDebit]) OR UPDATE([Warn]) 
	BEGIN 
		INSERT INTO @ACC
		SELECT 
			ISNULL([i].[GUID], [d].[GUID])  AS [Guid], 
			ISNULL([d].[ParentGUID], 0x0) OldParent, 
			ISNULL([i].[ParentGUID], 0x0) NewParent, 
			ISNULL([i].[Warn], [d].[Warn]) Warn, 
			CASE [i].[Warn] WHEN 1 THEN ISNULL(([d].[Debit] - [d].[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL(([d].[Credit] - [d].[Debit]), 0) - ISNULL(ch.Value, 0)) END OldBalance, 
			CASE [i].[Warn] WHEN 1 THEN ISNULL(([i].[Debit] - [i].[Credit]) + ISNULL(ch.Value, 0), 0) ELSE (ISNULL(([i].[Credit] - [i].[Debit]), 0) - ISNULL(ch.Value, 0)) END NewBalance,
			ISNULL(i.[MaxDebit], [d].[MaxDebit])  
		FROM 
			[inserted] AS [i] 
			FULL JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID] 
			OUTER APPLY dbo.fnCheque_GetBudgetValue(i.GUID, i.ConsiderChecksInBudget) ch
		WHERE 
			@UpdatedParent = 1 
			OR 
			ISNULL([i].[Warn], [d].[Warn]) > 0
			
		SET @UpdatedCount = @@ROWCOUNT

		IF @UpdatedCount = 0 
			RETURN

		IF @UpdatedParent = 1
		BEGIN
			SET @c = CURSOR FAST_FORWARD FOR SELECT [Guid], NewParent FROM @ACC WHERE NewParent <> 0X00
			
			OPEN @c FETCH FROM @c INTO @GUID, @NewParent
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				SET @Parent = @NewParent 
				WHILE @Parent <> 0x0 
				BEGIN
					-- orphants 
					SET @Parent = (SELECT [ParentGUID] FROM [ac000] WHERE [GUID] = @Parent) 
					IF @Parent IS NULL 
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0051: Parent not found (Orphants)', @guid 
					-- short-circuit check: 
					IF @Parent = @GUID 
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0052: Parent found descending from own sons (Short Circuit)', @guid 

					FETCH FROM @c INTO @GUID, @NewParent
				END 

				-- descending from a used account: 				
				IF [dbo].[fnAccount_IsUsed](@NewParent, DEFAULT) > 0x000000000001 -- The vaue 0x000000000001 means that the account is used as parent. 
					INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0053: Account(s) found descend from used account(s)...', @guid 
			END CLOSE @c DEALLOCATE @c 
		END
	
		DELETE @ACC WHERE NewBalance <= MaxDebit OR Warn = 0
		IF NOT EXISTS(SELECT * FROM @ACC)
			RETURN

		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 2, 0, 'AmnW0055: ' + CAST([guid] AS NVARCHAR(36)) + ' Account exceeded its Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid FROM @ACC WHERE OldBalance < MaxDebit
			UNION ALL  
			SELECT 2, 0, 'AmnW0056: ' + CAST([guid] AS NVARCHAR(36)) + ' Account is re-exceeded its Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid FROM @ACC WHERE OldBalance < NewBalance AND NOT(OldBalance < MaxDebit)
			UNION ALL  
			SELECT 2, 0, 'AmnW0057: ' + CAST([guid] AS NVARCHAR(36)) + ' Account has lowered its balance but still over Max Balance: [' + CAST([MaxDebit] AS NVARCHAR) + '] by: [' + CAST(([NewBalance] - [MaxDebit]) AS NVARCHAR) + ']', guid  FROM @ACC WHERE NOT(OldBalance < NewBalance  OR OldBalance < MaxDebit)

	END
#########################################################
CREATE TRIGGER trg_ac000_general
	ON [ac000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS  
	/*  
	This trigger:  
	- increases NSons, Debit and Credit of new hosting parents. and decreases them for old hosting parents.  
	- Sets the UseFlag for old and new hosting parents.  
	- Can manage multiple ac000 records transfering to multiple ac000 parents.  
	*/  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON 

	IF NOT(UPDATE([ParentGUID]) OR UPDATE([FinalGUID]))
		RETURN

	DECLARE @t_Parents TABLE([Parent] [UNIQUEIDENTIFIER])  
	DECLARE @t_Sum TABLE([GUID] [UNIQUEIDENTIFIER], [SumDebit] [FLOAT], [SumCredit] [FLOAT])  

	INSERT INTO @t_Parents  
		SELECT [ParentGUID]	FROM [inserted] WHERE [guid] != [parentGuid]  UNION ALL -- this will deal with short circuits 
		SELECT [FinalGUID]	FROM [inserted] WHERE [guid] != [parentGuid]  UNION ALL
		SELECT [ParentGUID]	FROM [deleted]	WHERE [guid] != [parentGuid]  UNION ALL
		SELECT [FinalGUID]	FROM [deleted]	WHERE [guid] != [parentGuid]   
	if @@ROWCOUNT = 0 
		RETURN 

	INSERT INTO @t_Sum  
	SELECT [ac].[ParentGUID], SUM([ac].[Debit]), SUM([ac].[Credit])  
	FROM 
		[ac000] AS [ac] 
		INNER JOIN @t_Parents [t] ON [ac].[ParentGUID] = [t].[Parent] 
	GROUP BY [ac].[ParentGUID]

	UPDATE [ac]
	SET  
		[NSons] = [dbo].[fnGetAccountNSons]([ac].[GUID]),  
		[Debit] = ISNULL([SumDebit], 0),  
		[Credit] = ISNULL([SumCredit], 0)  
	FROM 
		[ac000] AS [ac] 
		INNER JOIN @t_Parents AS [tp] ON [ac].[GUID] = [tp].[Parent] 
		LEFT JOIN @t_Sum AS [ts] ON [ac].[GUID] = [ts].[GUID]  
#########################################################
CREATE TRIGGER trg_ac000_delete
	ON [ac000] FOR DELETE 
	NOT FOR REPLICATION
AS 
	IF @@ROWCOUNT = 0 RETURN 

	SET NOCOUNT ON 

	UPDATE [ac] SET  
		[NSons] = [dbo].[fnGetAccountNSons]([ac].[GUID])
	FROM [ac000] AS [ac] 
		INNER JOIN [deleted] [d] ON [d].[parentGuid] = [ac].[guid]

	DELETE [ci000] FROM [ci000] [c] INNER JOIN [deleted] [d] ON [d].[guid] = [c].[parentGuid]
##########################################################################################
CREATE TRIGGER trgBuSubAccount
  ON [ac000] FOR INSERT, UPDATE 
	NOT FOR REPLICATION

AS  
BEGIN 
	IF @@ROWCOUNT = 0 RETURN	
	SET NOCOUNT ON
	IF NOT(UPDATE([ParentGUID]))
		RETURN

	DECLARE @TempAcc TABLE([Used] [BIGINT], [ParentGUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO 
		@TempAcc
	SELECT 
		[dbo].[fnAccount_IsUsed]( [i].[ParentGUID], 2) AS [used], 
		[i].[ParentGUID] 
	FROM 
		[INSERTED] [i] 
		LEFT JOIN [DELETED] [d] ON [i].[GUID] = [d].[GUID] 
	WHERE 
		[i].[ParentGUID] <> 0x0 
		AND 
		[i].[ParentGUID] <> ISNULL( [d].[ParentGUID], 0X0)

	IF EXISTS( SELECT * FROM @TempAcc WHERE ([used] > 0x000000000003) AND (([used] | 0x008000000000) = 0)) 
	BEGIN  
		INSERT INTO [ErrorLog]( [level], [type], [c1], [g1]) 
		SELECT DISTINCT 1, 0, 'AmnE00508 Can''t Add Children to Used Acount', [ParentGUID]
		FROM @TempAcc
	END 
END 

##########################################################################################
CREATE TRIGGER trg_ac000_POSSDCheckConstraints
       ON [ac000] INSTEAD OF DELETE
AS
BEGIN
  SET NOCOUNT ON;
			
			--================== POSSD Driver
			IF EXISTS(SELECT * FROM POSSDDriver000 Driver INNER JOIN [deleted] D ON Driver.ExtraAccountGUID   = D.[Guid]
																				 OR Driver.MinusAccountGUID   = D.[Guid]
																				 OR Driver.ReceiveAccountGUID = D.[Guid])
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0900: card already used in POSSD Driver', (SELECT TOP 1 [guid] FROM [deleted])
			END

			--================== POSSD Employee
			ELSE IF EXISTS(SELECT * FROM POSSDEmployee000 Employee INNER JOIN [deleted] D ON Employee.ExtraAccountGUID = D.[Guid]
																						  OR Employee.MinusAccountGUID = D.[Guid])
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0901: card already used in POSSD Employee', (SELECT TOP 1 [guid] FROM [deleted])
			END

			--================== POSSD Order 
			ELSE IF EXISTS(SELECT * FROM POSSDStationOrder000 [Order] INNER JOIN [deleted] D ON [Order].DownPaymentAccountGUID = D.[Guid])
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0902: card already used in POSSD Order', (SELECT TOP 1 [guid] FROM [deleted])
			END

			--================== POSSD Currency
			ELSE IF EXISTS(SELECT * FROM POSSDStationCurrency000 Currency INNER JOIN [deleted] D ON Currency.CentralBoxAccGUID = D.[Guid]
																							     OR Currency.FloatCachAccGUID  = D.[Guid])
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0903: card already used in POSSD Currency', (SELECT TOP 1 [guid] FROM [deleted])
			END

			--================== POSSD Return Coupon
			ELSE IF EXISTS(SELECT * FROM POSSDStationReturnCouponSettings000 Coupon INNER JOIN [deleted] D ON Coupon.AccountGUID = D.[Guid]
																										   OR Coupon.ExpireAccountGUID  = D.[Guid])
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0904: card already used in POSSD Coupon', (SELECT TOP 1 [guid] FROM [deleted])
			END

			--================== POSSD Station
			ELSE IF EXISTS(SELECT [POSfn].[Guid] FROM fnPOSSD_Station_AccountIsUsed() [POSfn] INNER JOIN [deleted] d ON [POSfn].[Guid] = d.[Guid] )
			BEGIN
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
				SELECT 1, 0, 'AmnE0905: card already used in Smart Devices Options', (SELECT TOP 1 [guid] FROM [deleted])
			END

			ELSE
			BEGIN
				DELETE ac000 FROM ac000 AC INNER JOIN deleted d ON Ac.[GUID] = d.[GUID]
			END

END
##########################################################################################
#END