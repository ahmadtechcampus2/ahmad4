##############################################################
CREATE PROC prcReGenEntry_Py
	@PyGuid UNIQUEIDENTIFIER 
AS 
---- 
	SET NOCOUNT ON; 
----------------------------------------------------  
	SELECT [en].* INTO [#enTmp]  
	FROM  
		[ce000] [ce]   
		INNER JOIN [en000] [en] on [en].[ParentGuid] = [ce].[Guid]  
		INNER JOIN [er000] [er] on [ce].[Guid] = [er].[EntryGuid]  
		INNER JOIN [py000] [py] on [py].[Guid] = [er].[ParentGuid]  
	WHERE   
		[py].[Guid] = @PyGuid  
		AND ISNULL([py].[AccountGuid], 0x0) != 0x0  
		AND [py].[AccountGuid] != [en].[AccountGuid] 
		AND (([py].[AccountGuid] = [en].[ContraAccGuid]) OR (ISNULL( [en].[ContraAccGuid], 0x0) = 0x0)) 
	----------------------------------------------------  
	IF @@ROWCOUNT = 0  
		RETURN ---عندما لايوجد حساب رئيسي في رأس السند العملية لن تتم وبالتالي حتما يوجد حساب في رأس السند 
		 
	MERGE [#enTmp] AS target 
	USING [#enTmp] AS source  
	ON (target.guid = source.ParentVATGuid) 
	WHEN MATCHED THEN  
		UPDATE SET target.Debit = target.Debit + source.Debit, target.Credit = target.Credit + source.Credit; 
	 
	DECLARE   
		@AccPyGuid UNIQUEIDENTIFIER,   
		@PyTypeGuid UNIQUEIDENTIFIER,  
		@ceGuid UNIQUEIDENTIFIER,  
		@etCostForBothAcc INT,  
		@etCostToTaxAcc BIT, 
		@etDetailed INT, 
		@etTaxType INT,
		@TaxEntry NVARCHAR(256),
		@PyCureencyGuid UNIQUEIDENTIFIER,
		@PyCureencyValue FLOAT,
		@etTaxAccountGuid UNIQUEIDENTIFIER,
		@TaxAccountGuid UNIQUEIDENTIFIER,
		@DefaultAddedValue FLOAT,
		@ReverseChargesEntryType INT

		SET @TaxEntry = [dbo].[fnStrings_get]('ENTRY\TAXENTRY', -1)  
		SET @ReverseChargesEntryType = 407

	SELECT 
		@AccPyGuid = [py].[AccountGuid], 
		@PyTypeGuid = [py].[TypeGuid], 
		@PyCureencyGuid = [py].CurrencyGUID, 
		@PyCureencyValue = [py].CurrencyVal,
		@ceGuid = [ce].[Guid]  
	FROM 
		[ce000] [ce]   
		INNER JOIN [er000] [er] ON [er].[EntryGuid] = [ce].[Guid]  
		INNER JOIN [py000] [py] ON [py].[Guid] = [er].[ParentGuid]  
	WHERE 
		[py].[Guid] = @PyGuid  

	--Delete VAT Entry items if thay are exist 
	DELETE en000 WHERE ParentVATGuid != 0x0 AND ParentGuid = @ceGuid AND [Type] != @ReverseChargesEntryType /*تفاصيل الرسوم العكسية*/
	DELETE [#enTmp] WHERE ParentVATGuid != 0x0 AND [Type] != @ReverseChargesEntryType 
	-------------------------------------------- 
	SELECT @etCostForBothAcc = [CostForBothAcc], @etCostToTaxAcc = [bCostToTaxAcc] ,  @etTaxType = [TaxType],@etDetailed = [bDetailed], 
	@etTaxAccountGuid = [TaxAccountGUID] FROM [et000] WHERE [Guid] = @PyTypeGuid  
	
	DECLARE @IsGCCSystemEnabled INT
	SET @IsGCCSystemEnabled = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0');

	IF( @etDetailed = 1)  
	BEGIN  
		IF (@etTaxType != 0) 
		BEGIN 
			DECLARE 
				@EntryItemAccountGUID UNIQUEIDENTIFIER, 
				@EntryItemGUID UNIQUEIDENTIFIER,
				@CustomerGUID UNIQUEIDENTIFIER,
				@Direction INT,
				@IsGCCTax BIT 
			 
			DECLARE EntryItemsCursor CURSOR FOR 
				SELECT AccountGUID, CustomerGUID, CASE WHEN Debit > 0 THEN 1 ELSE 0 END, GUID FROM [#enTmp] 
			OPEN EntryItemsCursor 
			FETCH NEXT FROM EntryItemsCursor INTO @EntryItemAccountGUID, @CustomerGUID, @Direction, @EntryItemGUID 
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				IF OBJECT_ID('tempdb..#CurrentEnAccRecord') IS NOT NULL 
				  DROP TABLE #CurrentEnAccRecord  
								
				SELECT @TaxAccountGuid = ac.AddedValueAccGUID
				FROM ac000 ac  
				WHERE ac.GUID = @EntryItemAccountGUID AND ac.IsUsingAddedValue = 1
				
				SET @IsGCCTax = CASE @etTaxType WHEN 0 THEN 0 ELSE CASE @IsGCCSystemEnabled WHEN 1 THEN 1 ELSE 0 END END

				IF @IsGCCTax = 1
				BEGIN 
					SET @TaxAccountGuid = 0x0
					SET @DefaultAddedValue = 0

					IF ISNULL(@CustomerGUID, 0x0) != 0x0 
						AND EXISTS(
							SELECT *
							FROM 
								ac000 ac
							WHERE	
								ac.GUID = @EntryItemAccountGUID 
								AND 
								ac.IsUsingAddedValue = 1)
					BEGIN
						SELECT 
							@TaxAccountGuid = l.ReturnAccGUID,
							@DefaultAddedValue = CASE l.IsSubscribed WHEN 1 THEN tc.TaxRatio ELSE 0 END
						FROM
							cu000 cu
							INNER JOIN GCCCustomerTax000 ct ON ct.CustGUID = cu.GUID AND ct.TaxType = 1 /*VAT*/
							INNER JOIN GCCTaxCoding000 tc ON tc.TaxType = 1 AND tc.TaxCode = ct.TaxCode 
							INNER JOIN GCCCustLocations000 l ON l.GUID = cu.GCCLocationGUID 
						WHERE 
							cu.GUID = @CustomerGUID
					END
				END

				IF @IsGCCTax = 0
				BEGIN
					IF (ISNULL(@TaxAccountGuid, 0x0) = 0x0 AND ISNULL(@etTaxAccountGuid, 0x0) = 0x0)
					BEGIN
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
						SELECT 1, 0, 'AmnE0280: missing tax account.', @EntryItemAccountGUID
						RETURN
					END 
				END
								   
				SELECT 
					en.Number, en.Date, en.Debit, en.Credit, en.Notes, en.CurrencyVal, en.class, en.num1, en.num2, 
					en.Vendor, en.salesman, en.guid, en.ParentGuid, en.AccountGuid, en.CurrencyGuid, en.CostGuid, 
					en.ContraAccGUID, AddedValue,
					CASE @IsGCCTax 
						WHEN 1 THEN @TaxAccountGuid
						ELSE (CASE ISNULL(ac.AddedValueAccGUID, 0x0) WHEN 0x0 THEN @etTaxAccountGuid ELSE ac.AddedValueAccGUID END) 
					END AS AddedValueAccGUID, 
					ac.IsUsingAddedValue, 
					CASE @IsGCCTax 
						WHEN 1 THEN @DefaultAddedValue
						ELSE ac.DefaultAddedValue
					END AS DefaultAddedValue, 
					CASE @IsGCCTax 
						WHEN 1 THEN 1
						ELSE ac.IsDefaultAddedValueFixed 
					END AS IsDefaultAddedValueFixed,
					en.GCCOriginDate,
					en.GCCOriginNumber
				INTO 
					#CurrentEnAccRecord
				FROM  
					ac000 ac  
					INNER JOIN [#enTmp] en ON ac.GUID = en.AccountGUID 
				WHERE en.GUID = @EntryItemGUID AND  
					  ac.IsUsingAddedValue = 1 AND  
					  ((ac.DefaultAddedValue > 0) OR ((@IsGCCTax = 1) AND (@DefaultAddedValue > 0)))
				 
				IF (@@ROWCOUNT > 0) 
				BEGIN 
					DECLARE @DebitTTC FLOAT, @CreditTTC FLOAT 
					 
					SET @DebitTTC = (SELECT Debit * DefaultAddedValue / ( DefaultAddedValue + 100 ) FROM #CurrentEnAccRecord) 
					SET @CreditTTC = (SELECT Credit * DefaultAddedValue / ( DefaultAddedValue + 100 ) FROM #CurrentEnAccRecord) 
					 
					UPDATE #CurrentEnAccRecord  
					SET Debit = Debit - @DebitTTC, 
						Credit = Credit - @CreditTTC 
											 
					MERGE [#enTmp] AS target 
					USING #CurrentEnAccRecord AS source  
					ON (target.guid = source.guid) 
					WHEN MATCHED THEN  
					UPDATE SET Debit = source.Debit, Credit = source.Credit; 
					 
					UPDATE #CurrentEnAccRecord  
					SET 
						Number = Number - 1,
						AccountGuid = AddedValueAccGUID, 
						Notes = Notes + @TaxEntry,
						Debit = @DebitTTC, 
						Credit = @CreditTTC, 
						GUID = NEWID(), 
						AddedValue = 0 , 
						CostGuid = CASE @etCostToTaxAcc WHEN 1 THEN CostGuid ELSE 0x0 END
					
					INSERT INTO [#enTmp] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal],
						[Class], [Num1], [Num2], [Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID],
						[CurrencyGUID], [CostGUID], [ContraAccGUID], [AddedValue], [ParentVATGuid], biGUID, Type, LCGUID, CustomerGUID,
						[GCCOriginDate], [GCCOriginNumber])
					SELECT 
						Number, Date, Debit, Credit, Notes, CurrencyVal, class, num1, num2, Vendor, salesman, guid, ParentGuid, AccountGuid, CurrencyGuid, CostGuid, ContraAccGUID, AddedValue, @EntryItemGUID, 0x0, 
						CASE @IsGCCTax 
							WHEN 1 THEN 202 -- CASE @Direction WHEN 1 THEN 202 ELSE 201 END
							ELSE CASE @etTaxType WHEN 1 THEN 101 /*vat*/ WHEN 2 THEN 102 ELSE 0 END 
						END, 
						0x0,
						@CustomerGUID, GCCOriginDate, [GCCOriginNumber]
					FROM #CurrentEnAccRecord WHERE [Debit] + [Credit] <> 0
				END 
			 
				FETCH NEXT FROM EntryItemsCursor INTO @EntryItemAccountGUID, @CustomerGUID, @Direction, @EntryItemGUID 
			END  CLOSE EntryItemsCursor DEALLOCATE EntryItemsCursor; 
		END 
		
		SELECT * INTO [#enNew1] FROM [#enTmp]
		
		MERGE [#enNew1] AS Target 
		Using [#enNew1] AS source
		ON (Target.guid = source.ParentVATGuid)
		WHEN MATCHED THEN 
		UPDATE SET Target.Debit = Target.Debit + source.Debit,
					Target.Credit = Target.Credit + source.Credit;
		
		DELETE 	[#enNew1]  WHERE 	ParentVATGuid != 0x0
		
		UPDATE [#enTmp] SET [ContraAccGuid] = @AccPyGuid  
		UPDATE [#enNew1] SET   
			[Guid] = newid(),   
			[Number] = [Number] + 1,  
			[Debit] = [Credit],   
			[Credit] = [Debit],   
			[ContraAccGuid] = [AccountGuid], 
			[AddedValue] = 0,  
			[AccountGuid] = @AccPyGuid,  
			[CostGuid] = CASE @etCostForBothAcc WHEN 1 THEN [CostGuid] ELSE 0x0 END,
			CurrencyGuid = @PyCureencyGuid,
			CurrencyVal = CASE WHEN CurrencyGuid <> @PyCureencyGuid  THEN @PyCureencyValue ELSE CurrencyVal END,
			CustomerGUID = 0x0,
			[Type] = 0,
			LCGUID = 0x0,
			[GCCOriginDate] = '1-1-1980', 
			[GCCOriginNumber] = ''

			DECLARE @AccGUID UNIQUEIDENTIFIER

			IF EXISTS(SELECT * FROM vwAcCu ac
			INNER JOIN [#enTmp] ent ON ent.AccountGUID = ac.GUID 
			INNER JOIN [#enNew1] enn1 ON enn1.AccountGUID = ac.GUID
			WHERE CustomersCount > 1 
			) 
			BEGIN
			SELECT top 1 @AccGUID = ac.GUID FROM vwAcCu ac
			INNER JOIN [#enTmp] ent ON ent.AccountGUID = ac.GUID 
			INNER JOIN [#enNew1] enn2 ON enn2.AccountGUID = ac.GUID
			WHERE CustomersCount > 1
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			RETURN 

			SET @AccGUID = 0x0
			UPDATE en
				SET CustomerGUID = cu.GUID  
				FROM   
					#enTmp en  
					INNER JOIN (   
						SELECT  cu.AccountGUID,count (*) AS cnt  
						FROM cu000 AS cu
						GROUP BY cu.AccountGUID 
						having count (*) = 1 ) cust
					ON	en.AccountGUID = cust.AccountGUID
					INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.AccountGUID	


			UPDATE en
				SET CustomerGUID = cu.GUID  
				FROM   
					#enNew1 en  
					INNER JOIN (   
						SELECT  cu.AccountGUID,count (*) AS cnt  
						FROM cu000 AS cu
						GROUP BY cu.AccountGUID 
						having count (*) = 1 ) cust
					ON	en.AccountGUID = cust.AccountGUID
					INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.AccountGUID
			END 

		EXEC prcDisableTriggers 'en000'
		DELETE FROM [en000] WHERE [ParentGuid] = @ceGuid and ( [AccountGuid] = @AccPyGuid OR [ContraAccGuid] = @AccPyGuid)  
		INSERT INTO [en000] SELECT * FROM [#enTmp]  
		INSERT INTO [en000] SELECT * FROM [#enNew1]  
		ALTER TABLE [en000] ENABLE TRIGGER ALL   
	END ELSE BEGIN  
		DECLARE @id INT  
	 	SELECT @id = MAX( [Number]) + 1 FROM  [#enTmp]  
		SELECT TOP 1 * INTO [#enNew2] FROM [#enTmp]  
		UPDATE [#enTmp] SET [ContraAccGuid] = @AccPyGuid  
		UPDATE [#enNew2] SET [Guid] = NEWID(), [Number] = @id, [Notes] = '', [CostGuid] = 0x0, [Class] = '', [Vendor] = 0, [Debit] = (SELECT SUM( [Credit]) FROM [#enTmp]), [Credit] = (SELECT SUM( [Debit]) FROM [#enTmp]), [ContraAccGuid] = 0x0, [AccountGuid] = @AccPyGuid, CustomerGUID = 0x0, LCGUID = 0x0  
		 
		IF (@etTaxType != 0) 
		BEGIN 
			DECLARE EntryItemsCursor1 CURSOR FOR SELECT AccountGUID, GUID FROM [#enTmp] 
			OPEN EntryItemsCursor1 
			FETCH NEXT FROM EntryItemsCursor1 
			INTO @EntryItemAccountGUID, @EntryItemGUID 
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				IF OBJECT_ID('tempdb..#CurrentEnAccRecord1') IS NOT NULL 
				  DROP TABLE #CurrentEnAccRecord1  
				
				SELECT @TaxAccountGuid = ac.AddedValueAccGUID
				  FROM ac000 ac  
				 WHERE ac.GUID = @EntryItemAccountGUID AND ac.IsUsingAddedValue = 1
				
				SET @IsGCCTax = CASE @etTaxType WHEN 0 THEN 0 ELSE CASE @IsGCCSystemEnabled WHEN 1 THEN 1 ELSE 0 END END

				IF @IsGCCTax = 1
				BEGIN 
					SET @TaxAccountGuid = 0x0
					SET @DefaultAddedValue = 0

					IF ISNULL(@CustomerGUID, 0x0) != 0x0 
						AND EXISTS(
							SELECT *
							FROM 
								ac000 ac
							WHERE	
								ac.GUID = @EntryItemAccountGUID 
								AND 
								ac.IsUsingAddedValue = 1)
					BEGIN
						SELECT 
							@TaxAccountGuid = l.ReturnAccGUID, -- (CASE @Direction WHEN 1 THEN l.ReturnAccGUID ELSE l.VATAccGUID END),
							@DefaultAddedValue = CASE l.IsSubscribed WHEN 1 THEN tc.TaxRatio ELSE 0 END
						FROM
							cu000 cu
							INNER JOIN GCCCustomerTax000 ct ON ct.CustGUID = cu.GUID AND ct.TaxType = 1 /*VAT*/
							INNER JOIN GCCTaxCoding000 tc ON tc.TaxType = 1 AND tc.TaxCode = ct.TaxCode 
							INNER JOIN GCCCustLocations000 l ON l.GUID = cu.GCCLocationGUID 
						WHERE cu.GUID = @CustomerGUID
					END
				END

				IF @IsGCCTax = 0
				BEGIN
					IF (ISNULL(@TaxAccountGuid, 0x0) = 0x0 AND ISNULL(@etTaxAccountGuid, 0x0) = 0x0)
					BEGIN
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
						SELECT 1, 0, 'AmnE0280: missing tax account.', @EntryItemAccountGUID
						RETURN
					END 
				END

				SELECT en.Number , en.Date, en.Debit, en.Credit, en.Notes, en.CurrencyVal, en.class, en.num1, en.num2, en.Vendor, en.salesman, en.guid, en.ParentGuid, en.AccountGuid, en.CurrencyGuid, 
				en.CostGuid , en.ContraAccGUID, AddedValue,
					CASE @IsGCCTax 
						WHEN 1 THEN @TaxAccountGuid
						ELSE (CASE ISNULL(ac.AddedValueAccGUID, 0x0) WHEN 0x0 THEN @etTaxAccountGuid ELSE ac.AddedValueAccGUID END) 
					END AS AddedValueAccGUID, 
					ac.IsUsingAddedValue, 
					CASE @IsGCCTax 
						WHEN 1 THEN @DefaultAddedValue
						ELSE ac.DefaultAddedValue
					END AS DefaultAddedValue, 
					CASE @IsGCCTax 
						WHEN 1 THEN 1
						ELSE ac.IsDefaultAddedValueFixed 
					END AS IsDefaultAddedValueFixed,
					en.[GCCOriginDate], 
					en.[GCCOriginNumber]
				INTO 
					#CurrentEnAccRecord1
				FROM  
					ac000 ac  
					INNER JOIN [#enTmp] en ON ac.GUID = en.AccountGUID 
				WHERE en.GUID = @EntryItemGUID AND  
						ac.IsUsingAddedValue = 1 AND  
						((ac.DefaultAddedValue > 0) OR ((@IsGCCTax = 1) AND (@DefaultAddedValue > 0)))

				IF (@@ROWCOUNT > 0) 
				BEGIN					 
					SET @DebitTTC = (SELECT Debit * DefaultAddedValue / ( DefaultAddedValue + 100 ) FROM #CurrentEnAccRecord1) 
					SET @CreditTTC = (SELECT Credit * DefaultAddedValue / ( DefaultAddedValue + 100 ) FROM #CurrentEnAccRecord1) 
							 
					UPDATE #CurrentEnAccRecord1 
					SET 
						Debit  = Debit - @DebitTTC, 
						Credit = Credit - @CreditTTC 
											 
					MERGE [#enTmp] AS target 
					USING #CurrentEnAccRecord1 AS source  
					ON (target.guid = source.guid) 
					WHEN MATCHED THEN  
					UPDATE SET Debit = source.Debit, Credit = source.Credit; 
					 
					UPDATE #CurrentEnAccRecord1  
					SET Number = (SELECT MAX(Number) + 1 FROM [#enTmp]) ,#CurrentEnAccRecord1.AccountGuid = #CurrentEnAccRecord1.AddedValueAccGUID , 
					#CurrentEnAccRecord1.Notes =  #CurrentEnAccRecord1.Notes + @TaxEntry , #CurrentEnAccRecord1.Debit = @DebitTTC, #CurrentEnAccRecord1.Credit = @CreditTTC, 
					GUID = NEWID(), AddedValue = 0 , CostGUID = (CASE @etCostToTaxAcc WHEN 1 THEN CostGuid ELSE 0x0 END )
					 
					INSERT INTO [#enTmp] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal],
						[Class], [Num1], [Num2], [Vendor], [SalesMan], [GUID], [ParentGUID], [AccountGUID],
						[CurrencyGUID], [CostGUID], [ContraAccGUID], [AddedValue], [ParentVATGuid], biGUID, Type, LCGUID, CustomerGUID,
						[GCCOriginDate], [GCCOriginNumber])  
					SELECT Number, Date, Debit, Credit, Notes, CurrencyVal, class, num1, num2, Vendor, salesman, guid, ParentGuid, AccountGuid, CurrencyGuid, CostGuid, ContraAccGUID, AddedValue,@EntryItemGUID,0x0,
					CASE @IsGCCTax 
						WHEN 1 THEN 202 -- CASE @Direction WHEN 1 THEN 202 ELSE 201 END
						ELSE CASE @etTaxType WHEN 1 THEN 101 /*vat*/ WHEN 2 THEN 102 ELSE 0 END
					END,
					0x0, 
					@CustomerGUID, [GCCOriginDate], [GCCOriginNumber] FROM #CurrentEnAccRecord1 WHERE [Debit] + [Credit] <> 0
				END 
			 		 
				FETCH NEXT FROM EntryItemsCursor1 INTO @EntryItemAccountGUID, @EntryItemGUID 
			END CLOSE EntryItemsCursor1 DEALLOCATE EntryItemsCursor1; 
		END 

		SET @AccGUID = 0x0
		IF EXISTS(
			SELECT * FROM 
				vwAcCu ac
				INNER JOIN [#enTmp] ent ON ent.AccountGUID = ac.GUID 
				INNER JOIN [#enNew2] ennew2 ON ennew2.AccountGUID = ac.GUID
			WHERE CustomersCount > 1) 
		BEGIN
			SELECT 
				top 1 @AccGUID = ac.GUID 
			FROM 
				vwAcCu ac
				INNER JOIN [#enTmp] ent ON ent.AccountGUID = ac.GUID 
				INNER JOIN [#enNew2] ennew2 ON ennew2.AccountGUID = ac.GUID
			WHERE CustomersCount > 1

			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
			SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
			
			RETURN 

			UPDATE en
				SET CustomerGUID = cu.GUID  
				FROM   
					#enTmp en  
					INNER JOIN (   
						SELECT  cu.AccountGUID,count (*) AS cnt  
						FROM cu000 AS cu
						GROUP BY cu.AccountGUID 
						having count (*) = 1 ) cust
					ON	en.AccountGUID = cust.AccountGUID
					INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.AccountGUID	

			UPDATE en
				SET CustomerGUID = cu.GUID  
				FROM   
					#enNew2 en  
					INNER JOIN (   
						SELECT  cu.AccountGUID,count (*) AS cnt  
						FROM cu000 AS cu
						GROUP BY cu.AccountGUID 
						having count (*) = 1 ) cust
					ON	en.AccountGUID = cust.AccountGUID
					INNER JOIN cu000 AS cu ON cu.AccountGUID = cust.AccountGUID
		END 
		
		EXEC prcDisableTriggers 'en000' 
		DELETE FROM [en000] WHERE [ParentGuid] = @ceGuid and ( [AccountGuid] = @AccPyGuid OR [ContraAccGuid] = @AccPyGuid)  
		INSERT INTO [en000] SELECT * FROM [#enTmp]  
		INSERT INTO [en000] SELECT * FROM [#enNew2]  
		ALTER TABLE [en000] ENABLE TRIGGER ALL   
	END      
##############################################################
CREATE PROCEDURE prcCheckBudjet
	@EntryGuid UNIQUEIDENTIFIER,
	@Post INT = 1
AS
	SET NOCOUNT ON
	DECLARE @Level INT,@cnt INT
	SELECT  DISTINCT en.AccountGuid AS [account],[en].[CostGuid] AS Cost,[i].[Branch],ac.ParentGuid, 0 AS [Level]
	INTO #ce
	FROM ce000  AS [i] --INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID] 
	INNER JOIN en000 en ON en.ParentGuid = i.Guid
	INNER JOIN ac000 ac ON ac.Guid = en.accountGuid
	WHERE i.GUID = @EntryGuid
			
	SET @cnt = @@RowCount
	SET @Level = 0
	WHILE @cnt > 0
	BEGIN
		INSERT INTO #ce
			SELECT c.ParentGuid,Cost,[Branch],ac.ParentGuid,@Level + 1
			FROM #ce c INNER JOIN ac000 ac ON ac.Guid = c.ParentGuid
			WHERE [Level] = @Level
			GROUP BY c.ParentGuid,Cost,[Branch],ac.ParentGuid
			SET @cnt = @@rowCount
			SET @Level = @Level + 1
	END
	SELECT [account],Cost,[Branch],[Level],Bal
	,ISNULL(StartDate,'1/1/1980') StartDate,ISNULL(EndDate,'1/1/2070') EndDate
	,CAST([account] AS NVARCHAR(36)) + CAST(Cost AS NVARCHAR(36)) QFLAG,[debitBal]
	INTO #bgu
	FROM (
			SELECT   [account],Cost,[Branch],[Level],periodGuid,Bal,[debitBal]
			FROM
			(
				SELECT  [account],ce.Cost,ce.[Branch],abd.Branch abdBranch,[Level],ab.Guid,abd.CostGuid,abd.Debit - abd.Credit Bal ,periodGuid,CASE WHEN abd.Debit > 0 THEN 1 ELSE 0 END [debitBal]
				FROM #ce ce INNER JOIN ab000 ab ON AB.AccGuid = [account]
				INNER JOIN abd000 abd ON abd.ParentGuid = ab.Guid
			  ) q 
			WHERE Cost =  CostGuid AND (abdBranch = 0x00 OR Branch = abdBranch)
		) q2 
		LEFT JOIN bdp000 bdp ON bdp.Guid = periodGuid
				
		SELECT StartDate,EndDate INTO #bdp FROM bdp000 WHERE GUID NOT IN (SELECT ParentGUID FROM pd000)
		IF (@@ROWCOUNT > 0) 
		BEGIN 
			DECLARE @Sd DATETIME,@Ed DATETIME
			SET @Sd = DATEADD(dd,-1,(SELECT TOP 1 StartDate FROM #bdp ORDER BY StartDate))
			SET @Ed = DATEADD(dd,1,(SELECT TOP 1 EndDate FROM #bdp ORDER BY StartDate DESC))
			INSERT INTO #bdp 
				SELECT '1/1/1980',@Sd
				UNION ALL 
				SELECT @Ed,'1/1/2070'
		END
			
		SELECT AccountGuid,en.Costguid,Sum(en.Debit) - SUM (en.Credit) AS BAL 
		,ISNULL(StartDate,'1/1/1980') StartDate,ISNULL(EndDate,'1/1/2070') EndDate
		,c.Branch,v.ParentGuid,0 as acLevel
		,CAST(AccountGuid AS NVARCHAR(36)) + CAST(en.Costguid AS NVARCHAR(36))   QFLAG
		INTO #qq
			 from en000 en INNER JOIN ce000 ce ON ce.Guid = en.ParentGuid
				INNER JOIN #ce c ON c.[account] = AccountGuid
				INNER JOIN ac000 v ON v.Guid = AccountGuid
				LEFT JOIN #bdp ON en.Date BETWEEN StartDate AND EndDate
			WHERE (@Post = -1 OR ce.Isposted = @Post) AND en.CostGUID = Cost  
			GROUP BY AccountGuid,en.Costguid,c.Branch,v.ParentGuid,StartDate,EndDate 
		SET @cnt = @@rowCount
		IF EXISTS (SELECT * FROM #bgu WHERE [Level] > 0)
		BEGIN
			SET @Level = 0
			WHILE	@cnt > 0
			BEGIN
				INSERT INTO #qq(AccountGuid,Costguid,BAL,Branch,ParentGuid,acLevel,StartDate,EndDate,QFLAG)
				SELECT a.ParentGuid,a.Costguid,SUM(BAL),Branch,ac.ParentGuid,@Level + 1,StartDate,EndDate,
				CAST( a.ParentGuid AS NVARCHAR(36)) + CAST(a.Costguid AS NVARCHAR(36))
				FROM #qq a INNER JOIN AC000 ac ON ac.Guid = a.ParentGuid
				WHERE acLevel = @Level
				GROUP BY a.ParentGuid,a.Costguid,Branch,ac.ParentGuid,StartDate,EndDate 
				SET @cnt = @@rowCount
				SET @Level = @Level + 1
				
			END
		END
		
		SELECT DISTINCT AccountGuid,a.Costguid ,A.StartDate
		INTO #Budjet
		FROM 
			#qq a INNER JOIN #bgu b ON b.QFLAG = a.QFLAG
			WHERE  (b.Branch = 0x00 OR [a].[Branch] = [b].[Branch])
			AND (([debitBal] = 1 AND a.Bal > b.Bal) OR ([debitBal] = 0 AND (-a.Bal) > (-b.Bal)))
			AND a.StartDate = b.StartDate
		
		SELECT ac.Name,ac.Code,ISNULL(co.Name,'') coName
		FROM  
			#Budjet b
			INNER JOIN ac000 ac ON ac.GUID = AccountGuid
			LEFT JOIN co000 co ON co.GUID = b.Costguid
##############################################################
#END
