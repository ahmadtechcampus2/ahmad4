###############################################################################
CREATE PROC prcSOContractCondDiscounts_GenEntry
	@FromDate DATETIME,
	@ToDate DATETIME,
	@Type INT = 0, -- 0: monthly, 1: yearly
	@BranchGUID UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON

	CREATE TABLE #ApplicableBillItems(
		BillCustomerGUID UNIQUEIDENTIFIER,
		BillGUID UNIQUEIDENTIFIER,
		BillItemGUID UNIQUEIDENTIFIER,
		BillItemTotalPrice FLOAT,
		BillItemQuantity FLOAT,
		BillItemUnit TINYINT,
		SOGUID UNIQUEIDENTIFIER,
		SOStartDate DATETIME,
		SOCondItemGUID UNIQUEIDENTIFIER,
		SOCondItemType TINYINT,
		SOCondItemItemGUID UNIQUEIDENTIFIER,
		IsOutput BIT,
		BranchGUID UNIQUEIDENTIFIER)
			
	CREATE TABLE #Entry(
		Number BIGINT IDENTITY,
		Account UNIQUEIDENTIFIER,
		ContraAccount UNIQUEIDENTIFIER,
		Debit FLOAT,
		Credit FLOAT,
		Class NVARCHAR(1000))
		
	CREATE TABLE #TempEntry(
		Account UNIQUEIDENTIFIER,
		ContraAccount UNIQUEIDENTIFIER,
		Debit FLOAT,
		Credit FLOAT,
		Class NVARCHAR(1000))
			
	IF @Type = 0
	BEGIN
		IF EXISTS(SELECT * FROM SOContractPeriodEntries000 WHERE ((FromDate BETWEEN @FromDate AND @ToDate) OR (ToDate BETWEEN @FromDate AND @ToDate)) AND [Type] = 1 AND BranchGUID = @BranchGUID)
		BEGIN
			SELECT 0x0 EntryGUID, -1 EntryNumber
			RETURN
		END
		
		UPDATE ce
		SET IsPosted = 0
		FROM ce000 ce
		WHERE
			EXISTS(
				SELECT EntryGUID FROM SOContractPeriodEntries000 
				WHERE 
				(
					(FromDate >= @FromDate AND FromDate <= @ToDate) OR (ToDate >= @FromDate AND ToDate <= @ToDate)
					OR (@FromDate >= FromDate AND @FromDate <= ToDate) OR (@ToDate >= FromDate AND @ToDate <= ToDate)
				)
				AND [Type] = 0
				AND BranchGUID = @BranchGUID
				AND ce.[GUID] = EntryGUID)
		
		DELETE FROM en000
		WHERE
			Exists(
				SELECT [GUID] FROM ce000 
				WHERE 
					[GUID] = ParentGUID 
					AND 
					EXISTS(
						SELECT EntryGUID FROM SOContractPeriodEntries000 
						WHERE
						(
							(FromDate >= @FromDate AND FromDate <= @ToDate) OR (ToDate >= @FromDate AND ToDate <= @ToDate)
							OR (@FromDate >= FromDate AND @FromDate <= ToDate) OR (@ToDate >= FromDate AND @ToDate <= ToDate)
						)
						AND [Type] = 0
						AND BranchGUID = @BranchGUID
						AND ParentGUID = EntryGUID)
				)
				
		DELETE ce FROM ce000 ce
		WHERE
			EXISTS(
				SELECT EntryGUID FROM SOContractPeriodEntries000 
				WHERE 
				(
					(FromDate >= @FromDate AND FromDate <= @ToDate) OR (ToDate >= @FromDate AND ToDate <= @ToDate)
					OR (@FromDate >= FromDate AND @FromDate <= ToDate) OR (@ToDate >= FromDate AND @ToDate <= ToDate)
				)
				AND [Type] = 0
				AND BranchGUID = @BranchGUID
				AND ce.[GUID] = EntryGUID)
			
		DELETE FROM SOContractPeriodEntries000 
		WHERE 
			(
				(FromDate >= @FromDate AND FromDate <= @ToDate) OR (ToDate >= @FromDate AND ToDate <= @ToDate)
				OR (@FromDate >= FromDate AND @FromDate <= ToDate) OR (@ToDate >= FromDate AND @ToDate <= ToDate)
			)
			AND [Type] = 0
			AND BranchGUID = @BranchGUID

		INSERT INTO #ApplicableBillItems EXEC prcSOContractCondCusts @FromDate, @ToDate, 0x0, 1, @BranchGUID
		
		DELETE #ApplicableBillItems
		WHERE
			BillCustomerGUID = 0x0
			
		IF EXISTS(SELECT * FROM #ApplicableBillItems ab WHERE EXISTS(SELECT * FROM cu000 WHERE [GUID] = ab.BillCustomerGUID AND ConditionalContraDiscAccGUID = 0x0))
		BEGIN
			SELECT
				CustomerName,
				LatinName,
				-2 EntryNumber
			FROM
				cu000 cu
				INNER JOIN #ApplicableBillItems ab ON ab.BillCustomerGUID = cu.[GUID]
			WHERE
				cu.ConditionalContraDiscAccGUID = 0x0
				
			return
		END
			
		INSERT INTO #TempEntry
		SELECT
			CASE
				WHEN (SELECT ItemsDiscountAccount FROM SpecialOffers000 WHERE [GUID] = api.SOGUID) <> 0x0 
					THEN (SELECT ItemsDiscountAccount FROM SpecialOffers000 WHERE [GUID] = api.SOGUID)
				ELSE
					CASE
						WHEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT MatGUID FROM bi000 WHERE [GUID] = api.BillItemGUID) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = api.BillGUID)) <> 0x0
							THEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT MatGUID FROM bi000 WHERE [GUID] = api.BillItemGUID) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = api.BillGUID))
						ELSE
							CASE
								WHEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT GroupGUID FROM mt000 WHERE [GUID] = (SELECT MatGUID FROM bi000 WHERE [GUID] = api.BillItemGUID)) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = api.BillGUID)) <> 0x0
									THEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT GroupGUID FROM mt000 WHERE [GUID] = (SELECT MatGUID FROM bi000 WHERE [GUID] = api.BillItemGUID)) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = api.BillGUID))
								ELSE
									(SELECT DefDiscAccGUID FROM bt000 WHERE [GUID] = (SELECT TypeGUID FROM bu000 WHERE [GUID] = api.BillGUID))
							END
					END
			END Account,
			(SELECT ConditionalContraDiscAccGUID FROM cu000 WHERE [GUID] = BillCustomerGUID) ContraAcc,
			CASE IsOutput
				WHEN 1 THEN 
					BillItemTotalPrice * (SELECT DiscountRatio FROM SOConditionalDiscounts000 WHERE [GUID] = SOCondItemGUID) / 100
				ELSE 0
			END Debit,
			CASE IsOutput
				WHEN 0 THEN 
					BillItemTotalPrice * (SELECT DiscountRatio FROM SOConditionalDiscounts000 WHERE [GUID] = SOCondItemGUID) / 100
				ELSE 0
			END Credit,
			SOCondItemGUID Class
		FROM
			#ApplicableBillItems api
			
		DELETE FROM #TempEntry
		WHERE Account = 0x0 OR ContraAccount = 0x0
		
		INSERT INTO #Entry
		SELECT
			Account,
			ContraAccount,
			CASE
					WHEN SUM(Debit - Credit) > 0 THEN SUM(Debit - Credit)
					ELSE 0
			END,
			CASE
					WHEN SUM(Credit - Debit) > 0 THEN SUM(Credit - Debit)
					ELSE 0
			END,
			Class
		FROM
			#TempEntry
		GROUP BY
			Account,
			ContraAccount,
			Class
			
		INSERT INTO #Entry
		SELECT
			ContraAccount,
			0x0,
			CASE
				WHEN SUM(Credit) - SUM(Debit) > 0 THEN SUM(Credit) - SUM(Debit)
				ELSE 0
			END,
			CASE
				WHEN SUM(Debit) - SUM(Credit) > 0 THEN SUM(Debit) - SUM(Credit)
				ELSE 0
			END,
			''
		FROM
			#Entry
		GROUP BY
			ContraAccount
			
		DECLARE
			@EntryGUID UNIQUEIDENTIFIER,
			@EntryNumber BIGINT
			
		SET @EntryGUID = 0x0
		SET @EntryNumber = 0
			
		IF EXISTS(SELECT * FROM #Entry)
		BEGIN
			DECLARE
				@DefCurrencyGUID UNIQUEIDENTIFIER,
				@DefCurrencyValue FLOAT,
				@EntryNote NVARCHAR(2000),
				@FromDateStr NVARCHAR(15),
				@ToDateStr NVARCHAR(15)
				
			SET @EntryGUID = NEWID()
			SET @EntryNumber  = ((SELECT ISNULL(MAX(Number), 0) FROM ce000) + 1)
			SET @DefCurrencyGUID = 0x0
			SET	@DefCurrencyValue = 1
			
			SELECT @DefCurrencyGUID = Value FROM op000 WHERE Name like '%AmnCfg_DefaultCurrency%'
			
			IF @DefCurrencyGUID = 0x0
			BEGIN
				SELECT @DefCurrencyGUID = [GUID] FROM my000 WHERE Number = 1
			END
			
			SELECT @DefCurrencyValue = CurrencyVal FROM my000 WHERE [GUID] = @DefCurrencyGUID
			
			--IF @BranchGUID = 0x0
			--BEGIN
				--SET @BranchGUID = (SELECT TOP 1 brGUID FROM vwBr WHERE brNumber = (SELECT MIN(brNumber) FROM vwBr))
			--END
			
			SET @FromDateStr = CAST(
				CAST(DatePart(dd, @FromDate) AS [NVARCHAR]) + '-' + 
				CAST(DatePart(mm, @FromDate) AS [NVARCHAR]) + '-' + 
				CAST(DatePart(yy, @FromDate) AS [NVARCHAR]) 
				AS [NVARCHAR])
	           
			SET @ToDateStr = CAST(
				CAST(DatePart(dd, @ToDate) AS [NVARCHAR]) + '-' + 
				CAST(DatePart(mm, @ToDate) AS [NVARCHAR]) + '-' + 
				CAST(DatePart(yy, @ToDate) AS [NVARCHAR]) 
				AS [NVARCHAR])
			
			SET @EntryNote = 'ﬁÌœ „ Ê·œ ⁄‰ «Õ ”«» «·Õ”„ «·„‘—Êÿ «·‘Â—Ì ··› —… „‰ ' + @FromDateStr+ ' ≈·Ï ' + @ToDateStr
			
			DECLARE
				@SumDebit FLOAT,
				@SumCredit FLOAT
				
			SET @SumDebit = (SELECT SUM(Debit) FROM #Entry)
			SET @SumCredit = (SELECT SUM(Credit) FROM #Entry)

			ALTER TABLE [ce000] DISABLE TRIGGER trg_ce000_post
			
			INSERT INTO ce000 (Type, Number, Date, Debit, Credit, Notes, CurrencyVal, IsPosted, State, Security, Num1, Num2, Branch, GUID, CurrencyGUID, TypeGUID, IsPrinted, PostDate)
			VALUES(
				1, -- Type
				@EntryNumber, -- Number
				@ToDate, -- Date
				@SumDebit, -- Debit
				@SumCredit, -- Credit
				@EntryNote, -- Note
				@DefCurrencyValue, -- CurrencyVal
				0, -- IsPosted
				0, -- State
				1, -- Security
				0, -- Num1
				0, --Num2
				@BranchGUID, -- Branch
				@EntryGUID, -- GUID
				@DefCurrencyGUID,
				0x0, -- TypeGuid
				0, -- IsPrinted
				@ToDate
				)
				
			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			SELECT 
				Number, -- Number
				@ToDate, -- Date
				Debit, -- Debit
				Credit, -- Credit
				'', -- Note
				@DefCurrencyValue, -- CurrencyVal
				Class, -- Class
				0, -- Num1
				0, -- Num2
				0, -- Vendor
				1, -- SalesMan
				NEWID(), -- GUID
				@EntryGUID, -- ParentGUID
				Account, -- AccountGUID
				@DefCurrencyGUID, -- CurrencyGUID
				0x0, -- CostGUID
				ContraAccount -- ContraAccGUID
			FROM
				#Entry
				
			UPDATE ce000
			SET IsPosted = 1
			WHERE [GUID] = @EntryGUID
			
			ALTER TABLE [ce000] ENABLE TRIGGER trg_ce000_post
		END
		
		INSERT INTO SOContractPeriodEntries000 VALUES(NEWID(), @EntryGUID, @FromDate, @ToDate, 0, @BranchGUID)
		
		SELECT @EntryGUID EntryGUID, @EntryNumber EntryNumber
	END
	ELSE IF @Type = 1
	BEGIN
	
		DECLARE 
			@PeriodsCursor CURSOR,
			@PRFromDate DATETIME,
			@PRToDate DATETIME,
			@FirstRec BIT,
			@PrevToDate DATETIME
		
		CREATE TABLE #UnCalcPeriods(
			EntryNumber INT,
			FromDate DATETIME,
			ToDate DATETIME)
			
		SET @FirstRec = 0
		SET @PeriodsCursor = 
			CURSOR FAST_FORWARD FOR
				SELECT 
					FromDate,
					ToDate
				FROM SOContractPeriodEntries000
				WHERE 
					[Type] = 0
					AND
					BranchGUID = @BranchGUID
					AND 
					((FromDate Between @FromDate AND @ToDate) AND (ToDate Between @FromDate AND @ToDate))
				ORDER BY
					FromDate
					
		OPEN @PeriodsCursor
		FETCH NEXT FROM @PeriodsCursor INTO @PRFromDate, @PRToDate
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @FirstRec = 0
			BEGIN
				IF (MONTH(@PRFromDate) <> 1 OR DAY(@PRFromDate) <> 1)
				BEGIN
					INSERT INTO #UnCalcPeriods VALUES(-3, '1/1/' + CAST(YEAR(@PRFromDate) AS NVARCHAR), DATEADD(DAY, -1, @PRFromDate))
				END
				SET @FirstRec = 1
				SET @PrevToDate = @PRToDate
				FETCH NEXT FROM @PeriodsCursor INTO @PRFromDate, @PRToDate
				CONTINUE
			END
			
			IF (DATEDIFF(DAY, @PrevToDate, @PRFromDate) > 1)
			BEGIN
				INSERT INTO #UnCalcPeriods VALUES(-3, DATEADD(DAY, 1, @PrevToDate), DATEADD(DAY, -1, @PRFromDate))
			END
			SET @PrevToDate = @PRToDate
			FETCH NEXT FROM @PeriodsCursor INTO @PRFromDate, @PRToDate
		END
		CLOSE @PeriodsCursor
		DEALLOCATE @PeriodsCursor
		
		IF @PrevToDate <> '12/31/' + CAST(YEAR(@FromDate) AS NVARCHAR)
		BEGIN
			INSERT INTO #UnCalcPeriods VALUES(-3, DATEADD(DAY, 1, @PrevToDate), '12/31/' + CAST(YEAR(@FromDate) AS NVARCHAR))
		END
				
		IF EXISTS(SELECT * FROM #UnCalcPeriods)
		BEGIN
			SELECT * FROM #UnCalcPeriods
			RETURN
		END
		
		UPDATE SOContractPeriodEntries000
		SET [Type] = 0
		WHERE 
			[Type] = 1 
			AND 
			BranchGUID = @BranchGUID
			AND
			((FromDate Between @FromDate AND @ToDate) OR (ToDate Between @FromDate AND @ToDate))
			
		CREATE TABLE #CustSo(
			BillCustomerGUID UNIQUEIDENTIFIER,
			SOCondGUID UNIQUEIDENTIFIER,
			BillItemTotalPrice FLOAT,
			BillItemQuantity FLOAT)
			
		INSERT INTO #ApplicableBillItems EXEC prcSOContractCondCusts @FromDate, @ToDate, 0x0, 0, @BranchGUID
		
		--EXEC prcSOContractCondCusts @FromDate, @ToDate, 0x0, 0, @BranchGUID
		--return 
		DELETE #ApplicableBillItems
		WHERE
			BillCustomerGUID = 0x0
			
		IF EXISTS(SELECT * FROM #ApplicableBillItems ab WHERE EXISTS(SELECT * FROM cu000 WHERE [GUID] = ab.BillCustomerGUID AND ConditionalContraDiscAccGUID = 0x0))
		BEGIN
			SELECT
				CustomerName,
				LatinName,
				-2 EntryNumber
			FROM
				cu000 cu
				INNER JOIN #ApplicableBillItems ab ON ab.BillCustomerGUID = cu.[GUID]
			WHERE
				cu.ConditionalContraDiscAccGUID = 0x0
				
			return
		END
		
		INSERT INTO #CustSo
		SELECT
			BillCustomerGUID,
			SOCondItemGUID,
			SUM(CASE IsOutput WHEN 1 THEN BillItemTotalPrice ELSE -BillItemTotalPrice END),
			SUM(CASE IsOutput WHEN 1 THEN BillItemQuantity ELSE -BillItemQuantity END)
		FROM
			#ApplicableBillItems
		GROUP BY
			BillCustomerGUID,
			SOCondItemGUID
			
		DELETE cs
		FROM
			#CustSo cs
			INNER JOIN SOConditionalDiscounts000 soCond ON cs.SOCondGUID = soCond.[GUID]
		WHERE
			(soCond.ConditionType = 0 AND cs.BillItemQuantity < soCond.Value)
			OR
			(soCond.ConditionType = 1 AND cs.BillItemTotalPrice < soCond.Value)
		
		DECLARE
			@SOContPeriodEntriesCursor CURSOR,
			@GUID UNIQUEIDENTIFIER,
			@SOEntryGUID UNIQUEIDENTIFIER,
			@SOFromDate DATETIME,
			@SOToDate DATETIME,
			@SOEntryType TINYINT
		
		SET @SOContPeriodEntriesCursor = 
			CURSOR FAST_FORWARD FOR
				SELECT [GUID], EntryGUID, FromDate, ToDate, [Type] FROM SOContractPeriodEntries000 WHERE BranchGUID = @BranchGUID
			
		OPEN @SOContPeriodEntriesCursor
		FETCH NEXT FROM @SOContPeriodEntriesCursor INTO @GUID, @SOEntryGUID, @SOFromDate, @SOToDate, @SOEntryType
		WHILE @@FETCH_STATUS = 0
		BEGIN
			DELETE FROM en000
			WHERE ParentGUID = @SOEntryGUID
			
			UPDATE ce000
			SET IsPosted = 0
			WHERE [GUID] = @SOEntryGUID
			
			DELETE FROM ce000 WHERE [GUID] = @SOEntryGUID
			
			INSERT INTO #TempEntry
			SELECT
			CASE
				WHEN (SELECT ItemsDiscountAccount FROM SpecialOffers000 WHERE [GUID] = abi.SOGUID) <> 0x0 
					THEN (SELECT ItemsDiscountAccount FROM SpecialOffers000 WHERE [GUID] = abi.SOGUID)
				ELSE
					CASE
						WHEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT MatGUID FROM bi000 WHERE [GUID] = abi.BillItemGUID) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = abi.BillGUID)) <> 0x0
							THEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT MatGUID FROM bi000 WHERE [GUID] = abi.BillItemGUID) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = abi.BillGUID))
						ELSE
							CASE
								WHEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT GroupGUID FROM mt000 WHERE [GUID] = (SELECT MatGUID FROM bi000 WHERE [GUID] = abi.BillItemGUID)) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = abi.BillGUID)) <> 0x0
									THEN (SELECT DiscAccGUID FROM ma000 WHERE ObjGUID = (SELECT GroupGUID FROM mt000 WHERE [GUID] = (SELECT MatGUID FROM bi000 WHERE [GUID] = abi.BillItemGUID)) AND BillTypeGUID = (SELECT TypeGUID FROM bu000 WHERE [GUID] = abi.BillGUID))
								ELSE
									(SELECT DefDiscAccGUID FROM bt000 WHERE [GUID] = (SELECT TypeGUID FROM bu000 WHERE [GUID] = abi.BillGUID))
							END
					END
			END Account,
			(SELECT ConditionalContraDiscAccGUID FROM cu000 WHERE [GUID] = abi.BillCustomerGUID) ContraAcc,
			CASE IsOutput
				WHEN 1 THEN 
					abi.BillItemTotalPrice * (SELECT DiscountRatio FROM SOConditionalDiscounts000 WHERE [GUID] = SOCondItemGUID) / 100
				ELSE 0
			END Debit,
			CASE IsOutput
				WHEN 0 THEN 
					abi.BillItemTotalPrice * (SELECT DiscountRatio FROM SOConditionalDiscounts000 WHERE [GUID] = SOCondItemGUID) / 100
				ELSE 0
			END Credit,
			SOCondItemGUID Class
			FROM
				#ApplicableBillItems abi
				INNER JOIN bu000 bu ON abi.BillGUID = bu.[GUID]
				INNER JOIN #CustSo cs ON abi.BillCustomerGUID = cs.BillCustomerGUID AND abi.SOCondItemGUID = cs.SOCondGUID
			WHERE
				bu.[Date] BETWEEN @SOFromDate AND @SOToDate
				
			INSERT INTO #Entry
			SELECT
				Account,
				ContraAccount,
				CASE
					WHEN SUM(Debit - Credit) > 0 THEN SUM(Debit - Credit)
					ELSE 0
				END,
				CASE
					WHEN SUM(Credit - Debit) > 0 THEN SUM(Credit - Debit)
					ELSE 0
				END,
				Class
			FROM
				#TempEntry
			GROUP BY
				Account,
				ContraAccount,
				Class
				
			INSERT INTO #Entry
			SELECT
				ContraAccount,
				0x0,
				CASE
					WHEN SUM(Credit) - SUM(Debit) > 0 THEN SUM(Credit) - SUM(Debit)
					ELSE 0
				END,
				CASE
					WHEN SUM(Debit) - SUM(Credit) > 0 THEN SUM(Debit) - SUM(Credit)
					ELSE 0
				END,
				''
			FROM
				#Entry
			GROUP BY
				ContraAccount
				
			DECLARE
				@SOEntryNumber BIGINT
				
			IF EXISTS(SELECT * FROM #Entry)
			BEGIN
				DECLARE
					@SODefCurrencyGUID UNIQUEIDENTIFIER,
					@SODefCurrencyValue FLOAT,
					@SOEntryNote NVARCHAR(2000),
					@SOFromDateStr NVARCHAR(15),
					@SOToDateStr NVARCHAR(15)
					
				SET @SOEntryNumber  = ((SELECT ISNULL(MAX(Number), 0) FROM ce000) + 1)
				SET @SODefCurrencyGUID = 0x0
				SET	@SODefCurrencyValue = 1
				
				SELECT @SODefCurrencyGUID = Value FROM op000 WHERE Name like '%AmnCfg_DefaultCurrency%'
				
				IF @SODefCurrencyGUID = 0x0
				BEGIN
					SELECT @SODefCurrencyGUID = [GUID] FROM my000 WHERE Number = 1
				END
				
				SELECT @SODefCurrencyValue = CurrencyVal FROM my000 WHERE [GUID] = @SODefCurrencyGUID
				
				--IF @BranchGUID = 0x0
				--BEGIN
					--SET @BranchGUID = (SELECT TOP 1 brGUID FROM vwBr WHERE brNumber = (SELECT MIN(brNumber) FROM vwBr))
				--END
				
				SET @SOFromDateStr = CAST(
					CAST(DatePart(dd, @SOFromDate) AS [NVARCHAR]) + '-' + 
					CAST(DatePart(mm, @SOFromDate) AS [NVARCHAR]) + '-' + 
					CAST(DatePart(yy, @SOFromDate) AS [NVARCHAR]) 
					AS [NVARCHAR])
		           
				SET @SOToDateStr = CAST(
					CAST(DatePart(dd, @SOToDate) AS [NVARCHAR]) + '-' + 
					CAST(DatePart(mm, @SOToDate) AS [NVARCHAR]) + '-' + 
					CAST(DatePart(yy, @SOToDate) AS [NVARCHAR]) 
					AS [NVARCHAR])
				
				SET @SOEntryNote = 'ﬁÌœ „ Ê·œ ⁄‰ «Õ ”«» «·Õ”„ «·„‘—Êÿ «·”‰ÊÌ ' + @SOFromDateStr+ ' ≈·Ï ' + @SOToDateStr
				
				IF @SOEntryGUID = 0x0
					SET @SOEntryGUID = NEWID()
				
				DECLARE
				@SOSumDebit FLOAT,
				@SOSumCredit FLOAT
				
				SET @SOSumDebit = (SELECT SUM(Debit) FROM #Entry)
				SET @SOSumCredit = (SELECT SUM(Credit) FROM #Entry)
			
				ALTER TABLE [ce000] DISABLE TRIGGER trg_ce000_post
				INSERT INTO ce000 (Type, Number, Date, Debit, Credit, Notes, CurrencyVal, IsPosted, State, Security, Num1, Num2, Branch, GUID, CurrencyGUID, TypeGUID, IsPrinted, PostDate)
				VALUES(
					1, -- Type
					@SOEntryNumber, -- Number
					@SOToDate, -- Date
					@SOSumDebit, -- Debit
					@SOSumCredit, -- Credit
					@SOEntryNote, -- Note
					@SODefCurrencyValue, -- CurrencyVal
					0, -- IsPosted
					0, -- State
					1, -- Security
					0, -- Num1
					0, --Num2
					@BranchGUID, -- Branch
					@SOEntryGUID, -- GUID
					@SODefCurrencyGUID,
					0x0, -- TypeGuid
					0, -- IsPrinted
					@SOToDate -- PostDate
					)
					
				INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
				SELECT 
					Number, -- Number
					@SOToDate, -- Date
					Debit, -- Debit
					Credit, -- Credit
					'', -- Note
					@SODefCurrencyValue, -- CurrencyVal
					Class, -- Class
					0, -- Num1
					0, -- Num2
					0, -- Vendor
					1, -- SalesMan
					NEWID(), -- GUID
					@SOEntryGUID, -- ParentGUID
					Account, -- AccountGUID
					@SODefCurrencyGUID, -- CurrencyGUID
					0x0, -- CostGUID
					ContraAccount -- ContraAccGUID
				FROM
					#Entry
					
				UPDATE ce000
				SET IsPosted = 1
				WHERE [GUID] = @SOEntryGUID
				
				ALTER TABLE [ce000] ENABLE TRIGGER trg_ce000_post
				
				UPDATE SOContractPeriodEntries000
				SET 
					[Type] = 1,
					EntryGUID = @SOEntryGUID
				WHERE
					[GUID] = @GUID
			END
			ELSE
			BEGIN
				UPDATE SOContractPeriodEntries000
				SET
					[Type] = 1,
					EntryGUID = 0x0
				WHERE
					[GUID] = @GUID
			END

			DELETE FROM #TempEntry
			DELETE FROM #Entry
			
		FETCH NEXT FROM @SOContPeriodEntriesCursor INTO @GUID, @SOEntryGUID, @SOFromDate, @SOToDate, @SOEntryType
		END
		CLOSE @SOContPeriodEntriesCursor
		DEALLOCATE @SOContPeriodEntriesCursor
	END
################################################################################
#END
