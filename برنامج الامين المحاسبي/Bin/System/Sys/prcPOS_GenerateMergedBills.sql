################################################################################
CREATE PROCEDURE prcPOS_GenerateMergedLinkPayments
	@TypeGUID			UNIQUEIDENTIFIER,
	@BranchGUID			UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@OrdersDate			DATE,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@CurrencyValue		FLOAT,
	@CurrencyAccount	UNIQUEIDENTIFIER,
	@AccountGUID		UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@UserGUID			UNIQUEIDENTIFIER,
	@PayType			INT,
	@IsReturnBill		BIT,
	@BillGUID			UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		en.GUID			AS EntryGUID,
		en.credit		AS Value,
		en.currencyguid	AS CurrencyGUID,
		en.currencyval	AS CurrencyVal,
		link.type		AS LinkType,
		ISNULL(ord.SUBTOTAL, 0) + ISNULL(ord.[Added], 0) + ISNULL(ord.[Tax], 0) - ISNULL(ord.[Discount], 0) AS Total
	INTO #links 
	FROM 
		POSPaymentLink000 link
		INNER JOIN en000 en						ON en.GUID = link.EntryGUID
		INNER JOIN POSOrder000 ord				ON ord.GUID = link.ParentGUID
		INNER JOIN #OrdersTable t				ON ord.GUID = t.OrderGUID
		INNER JOIN POSPaymentsPackage000 pak	ON pak.GUID = ord.PaymentsPackageID
	WHERE 
		pak.PayType = 3
	
	IF NOT EXISTS(SELECT * FROM #links) 
		RETURN 
	IF ISNULL((SELECT SUM(Total) FROM #links), 0) = 0
		RETURN 

	DECLARE 
		@c_link				CURSOR,
		@l_EntryGUID		UNIQUEIDENTIFIER,
		@l_Value			FLOAT,
		@l_CurrencyGUID		UNIQUEIDENTIFIER,
		@l_CurrencyValue	FLOAT

	DECLARE
		@TotalPaid	FLOAT,
		@Total		FLOAT,
		@EnSaleID	UNIQUEIDENTIFIER

	SELECT 
		@Total = SUM(ISNULL(SUBTOTAL, 0) + ISNULL([Added], 0) + ISNULL([Tax], 0) - ISNULL([Discount], 0))
	FROM
		POSOrder000 ord
		INNER JOIN #OrdersTable t				ON ord.GUID = t.OrderGUID
		INNER JOIN POSPaymentsPackage000 pak	ON pak.GUID = ord.PaymentsPackageID
	WHERE 
		pak.PayType = 3

	SELECT TOP 1
		@EnSaleID = en.GUID 
	FROM 
		BillRel000 rel
		INNER JOIN bu000 bu ON bu.GUID = rel.BillGUID
		INNER JOIN er000 er ON bu.GUID = er.ParentGUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
		INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
	WHERE 
		bu.GUID = ISNULL(@BillGUID, 0x0)
		AND 
		en.AccountGUID = @AccountGUID 
		AND 
		en.CustomerGUID = @CustomerGUID

	IF ISNULL(@Total, 0) < 1
		RETURN

	SET @c_link = CURSOR FAST_FORWARD FOR
		SELECT 
			EntryGUID,
			Value,
			CurrencyGUID,
			CurrencyVal	
		FROM #links
		ORDER BY LinkType

	SET @TotalPaid = 0

	OPEN @c_link FETCH FROM @c_link INTO @l_EntryGUID, @l_Value, @l_CurrencyGUID, @l_CurrencyValue
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @l_Value >= (@Total - @TotalPaid)
		BEGIN
			INSERT INTO bp000 (GUID, DebtGUID, PayGUID, PayType, Val, CurrencyGUID, CurrencyVal, RecType, DebitType, ParentDebitGUID, ParentPayGUID, PayVal, PayCurVal)
			VALUES (NEWID(), @EnSaleID, @l_EntryGUID, 0, @Total - @TotalPaid, @l_CurrencyGUID, @l_CurrencyValue, 0, 0, 0x0, 0x0, @Total - @TotalPaid, @l_CurrencyValue) 
			RETURN

		END ELSE
		IF @l_Value < (@Total - @TotalPaid) AND @l_Value > 0
		BEGIN
			INSERT INTO bp000 (GUID, DebtGUID, PayGUID, PayType, Val, CurrencyGUID, CurrencyVal, RecType, DebitType, ParentDebitGUID, ParentPayGUID, PayVal, PayCurVal)
			VALUES (NEWID(), @EnSaleID, @l_EntryGUID, 0, @l_Value, @l_CurrencyGUID, @l_CurrencyValue, 0, 0, 0x0, 0x0, @Total - @TotalPaid, @l_CurrencyValue) 
		END

		SET @TotalPaid = @TotalPaid + @l_Value

		FETCH FROM @c_link INTO @l_EntryGUID, @l_Value, @l_CurrencyGUID, @l_CurrencyValue
	END CLOSE @c_link DEALLOCATE @c_link
################################################################################
CREATE PROCEDURE prcPOS_GenerateMergedCheques
	@TypeGUID			UNIQUEIDENTIFIER,
	@BranchGUID			UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@OrdersDate			DATE,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@CurrencyValue		FLOAT,
	@CurrencyAccount	UNIQUEIDENTIFIER,
	@AccountGUID		UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@UserGUID			UNIQUEIDENTIFIER,
	@PayType			INT,
	@IsReturnBill		BIT,
	@BillGUID			UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN 0x0
			ELSE ch.GUID
		END											AS [GUID],
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN ''
			ELSE ch.Number
		END											AS [Number],
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN ''
			ELSE ch.Notes
		END											AS [Notes],
		SUM(ABS(ISNULL(ch.[Paid], 0)))				AS [Paid], 
		ISNULL(ch.[Type], 0x0)						AS ChequeType,
		ISNULL(ch.[CreditAccID], 0x0)				AS CreditAccID,
		ISNULL(ch.[DebitAccID], 0x0)				AS DebitAccID, 
		ISNULL(ch.CurrencyID, @CurrencyGUID)		AS CurrencyGUID,
		ISNULL(ch.CurrencyValue, @CurrencyValue)	AS CurrencyValue,
		ISNULL(ch.NewVoucher, 0)					AS NewVoucher
	INTO 
		#cheques 
	FROM 
		[POSPaymentsPackageCheck000] ch
		INNER JOIN [POSPaymentsPackage000] pak ON	pak.GUID = ch.[ParentID]
		INNER JOIN POSOrder000 ord ON				pak.GUID = ord.PaymentsPackageID
		INNER JOIN #OrdersTable t ON				ord.GUID = t.OrderGUID
	WHERE 
		pak.PayType = 3
		AND 
		ABS(ISNULL(ch.[Paid], 0)) > 0
	GROUP BY 
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN 0x0
			ELSE ch.GUID
		END,
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN ''
			ELSE ch.Number
		END,
		CASE WHEN @IsReturnBill = 0 AND ch.NewVoucher = 0
			THEN ''
			ELSE ch.Notes
		END,
		ISNULL(ch.[Type], 0x0),
		ISNULL(ch.[CreditAccID], 0x0),
		ISNULL(ch.[DebitAccID], 0x0), 
		ISNULL(ch.CurrencyID, @CurrencyGUID),
		ISNULL(ch.CurrencyValue, @CurrencyValue),
		ISNULL(ch.NewVoucher, 0)
	
	IF @@ROWCOUNT = 0
		RETURN 

	DECLARE 
		@language				INT,
		@UserNumber				INT,
		@BillNumber				INT 

	SET @language = [dbo].[fnConnections_GetLanguage]()	
	SELECT @UserNumber = ISNULL(Number, 0) FROM us000 WHERE GUID = @UserGUID
	SELECT @BillNumber = ISNULL(Number, 0) FROM bu000 WHERE GUID = ISNULL(@BillGUID, 0x0)
	
	DECLARE 
		@TypeName				NVARCHAR(250),
		@GenNote				BIT,
		@GenContraNote			BIT,
		@CanFinishing			BIT,  
		@ManualGenEntry			BIT,
		@AutoPostEntry			BIT,
		@ChequeNum				INT,  
		@Cheque_Num				NVARCHAR(1000),
		@CanbeFinishing			BIT, 
		@DefaultCurrencyGuid	UNIQUEIDENTIFIER , 
		@DefaultCurrencyVal		FLOAT,
		@State					INT,
		@debitAccountCusomterId	[UNIQUEIDENTIFIER],
		@creditAccountCusomterId	[UNIQUEIDENTIFIER],
		@Cost2Guid				[UNIQUEIDENTIFIER],
		@BankGuid				[UNIQUEIDENTIFIER],
		@chNotes1				[NVARCHAR](250),  
		@chNotes2				[NVARCHAR](250),		
		@chNumber				[FLOAT],  
		@chNum					[NVARCHAR](250),
		@chGuid					UNIQUEIDENTIFIER,
		@BillTypeAbbrev			[NVARCHAR](100),  
		@BillTypeLatinAbbrev	[NVARCHAR](100),  
		@DefCostGuid			[UNIQUEIDENTIFIER]

	SELECT 
		@BillTypeAbbrev =		ISNULL([Abbrev], ''),   
	    @BillTypeLatinAbbrev =	ISNULL([LatinAbbrev], '') , 
	    @DefCostGuid =			ISNULL([DefCostGuid], 0x0)
    FROM 
		bt000  
    WHERE [GUID] = @TypeGUID  

	IF ((@language <> 0) AND (LEN(@BillTypeLatinAbbrev) <> 0))  
		SET @BillTypeAbbrev = @BillTypeLatinAbbrev  

	CREATE TABLE #ChequeOrders (OrderGUID UNIQUEIDENTIFIER) 
	CREATE TABLE #EntriesNumbers (EntryGUID UNIQUEIDENTIFIER, EntryNumber FLOAT) 

	DECLARE 
		@c_cheques		CURSOR,
		@GUID			UNIQUEIDENTIFIER,
		@Number			NVARCHAR(250),
		@Notes			NVARCHAR(1000),
		@paid			FLOAT,
		@ChequeType		UNIQUEIDENTIFIER,
		@CreditAccID	UNIQUEIDENTIFIER,
		@DebitAccID		UNIQUEIDENTIFIER,
		@curGUID		UNIQUEIDENTIFIER,
		@curVal			FLOAT,
		@NewVoucher		INT

	SET @c_cheques = CURSOR FAST_FORWARD FOR 
		SELECT
			GUID,
			Number,
			Notes,
			[Paid], 
			ChequeType,
			CreditAccID,
			DebitAccID, 
			CurrencyGUID,
			CurrencyValue,
			NewVoucher
		FROM #cheques

	OPEN @c_cheques FETCH NEXT FROM @c_cheques INTO @GUID, @Number, @Notes, @paid, @ChequeType, @CreditAccID, @DebitAccID, @curGUID, @curVal, @NewVoucher
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @chGuid = NEWID()
		 
		SELECT 
			@TypeName = Name,
			@GenNote = bAutoGenerateNote,
			@GenContraNote = bAutoGenerateContraNote,
			@CanFinishing = bCanFinishing,
			@BankGUID = BankGUID,
			@Cost2Guid = DefaultCostcenter, 
			@ManualGenEntry = bManualGenEntry,
			@AutoPostEntry = bAutoPost,
			@CanbeFinishing = bCanFinishing
		FROM nt000 WHERE [GUID] = @ChequeType

		SET @chNumber = ISNULL((SELECT MAX(ISNULL([Number], 0)) FROM [ch000] WHERE TypeGUID = @ChequeType AND BranchGUID = @BranchGUID), 0) + 1
		SET @chNum =  @BillTypeAbbrev + ' [' + CAST(@BillNumber AS NVARCHAR(250)) + ']'  

		SELECT @ChequeNum =  ISNULL(CAST (MAX(CONVERT(INT, CASE ISNUMERIC(num) WHEN 1 THEN NUM ELSE '' END)) + 1 AS NVARCHAR(255)), 1) 
		FROM ch000 
		WHERE [TypeGUID] = @ChequeType 

		IF (NOT EXISTS(SELECT num FROM CH000 WHERE Num = @Number)) AND (@Number <>'')
			SET @Cheque_Num = @Number
		ELSE 
			SET @Cheque_Num = CONVERT(NVARCHAR(255), @ChequeNum)

		SET @chNotes1 = (CASE @GenNote WHEN 1 THEN (CASE WHEN @IsReturnBill = 0 AND @NewVoucher = 0 THEN [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) ELSE [dbo].[fnStrings_get]('POS\PAIDTO', @language) END + 
						(SELECT Code +'-'+ Name FROM ac000 WHERE GUID = ISNULL(@AccountGUID, @DebitAccID))) + ' - ' +
						(SELECT CustomerName FROM cu000 WHERE GUID = @CustomerGUID) + ' ' + @TypeName + ' '
						+ [dbo].[fnStrings_get]('POS\NUMBER', @language) + ':' + @Cheque_Num + ' ' +						 
						+ [dbo].[fnStrings_get]('POS\INNERNUMBER', @language) + ':' +  @chNum + ' ' +
						+ [dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) + ':' +  CONVERT(NVARCHAR(255), @OrdersDate, 105) + ' ' + 
						+ (CASE WHEN  @BankGUID <> 0x0 THEN [dbo].[fnStrings_get]('POS\DESTINATION', @language) + ':' + 
						+ (SELECT Code + '-' + BankName FROM Bank000 WHERE GUID = @BankGUID) + ' ' ELSE ' ' END) 
							ELSE ' ' END) + @Notes
			 
		SET @chNotes2 = (CASE @GenContraNote WHEN 1 THEN( CASE WHEN @IsReturnBill = 0 AND @NewVoucher = 0 THEN [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) ELSE [dbo].[fnStrings_get]('POS\PAIDTO', @language) END + 
						(SELECT Code +'-'+ Name from ac000 where guid = ISNULL(@AccountGUID, @DebitAccID))) + ' - ' +
						(SELECT CustomerName FROM cu000 WHERE GUID = @CustomerGUID) + ' ' + @TypeName + ' '
						+ [dbo].[fnStrings_get]('POS\NUMBER', @language) + ':' + @Cheque_Num + ' ' +
						+ [dbo].[fnStrings_get]('POS\INNERNUMBER', @language) + ':' + @chNum + ' ' +
						+ [dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) + ':' + CONVERT(NVARCHAR(255), @OrdersDate, 105) + ' ' +
						+ (CASE WHEN  @BankGUID <> 0x0  THEN [dbo].[fnStrings_get]('POS\DESTINATION', @language) + ':' + 
						+ (SELECT Code + '-' + BankName FROM Bank000 WHERE GUID = @BankGUID) + ' ' ELSE ' ' END) 
							ELSE ' ' END) + @Notes
				  
		SET @State = CASE @CanFinishing WHEN 1 THEN 1 ELSE 0 END
			 
		IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @DebitAccID HAVING COUNT(AccountGUID) = 1)
		BEGIN
			SELECT TOP 1  @debitAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @DebitAccID  
		END

		IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @CreditAccID HAVING COUNT(AccountGUID) = 1)
		BEGIN
			SELECT TOP 1  @creditAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @CreditAccID  
		END

		INSERT INTO [ch000] (
			[Number],  
			[Dir],  
			[Date],  
			[DueDate],  
			[ColDate],  
			[Num],  
			[BankGUID],  
			[Notes],  
			[Val],  
			[CurrencyVal],  
			[State],  
			[Security],  
			[PrevNum],  
			[IntNumber],  
			[FileInt],  
			[FileExt],  
			[FileDate],  
			[OrgName],  
			[GUID],  
			[TypeGUID],  
			[ParentGUID],  
			[AccountGUID],  
			[CurrencyGUID],  
			[Cost1GUID],  
			[Cost2GUID],  
			[Account2GUID],  
			[BranchGUID],  
			[Notes2],
			[CustomerGUID])  
		VALUES (
			@chNumber,
			CASE WHEN @IsReturnBill = 0 AND @NewVoucher = 0 THEN 1 ELSE 2 END, --Dir  
			@OrdersDate, --Date  
			@OrdersDate, --DueDate  
			@OrdersDate, --ColDate  
			@Cheque_Num,--
			@BankGUID, --Bank  
			@chNotes1, --Notes  
			@paid, --Val  
			@curVal, --CurrencyVal  
			@State, --State  
			1, --Security  
			0, --PrevNum  
			@chNum,
			0, --FileInt  
			0, --FileExt  
			@OrdersDate, --FileDate  
			'', --OrgName  
			@chGuid, --GUID  
			@ChequeType, --TypeGUID  
			ISNULL(@BillGUID, 0x0), --ParentGUID  
			@AccountGUID, --AccountGUID  
			@curGUID, --CurrencyGUID  
			@DefCostGuid, --Cost1GUID 
			@Cost2Guid ,--Cost2GUID 
			CASE WHEN @IsReturnBill = 0 AND @NewVoucher = 0 THEN @DebitAccID ELSE @CreditAccID END, --Account2GUID  
			@BranchGUID, --BranchGUID  
			@chNotes2, --Notes2
			@CustomerGUID) --CustomerGUID 

		IF @@ROWCOUNT > 0
		BEGIN 
			INSERT INTO LOG000 (Computer, GUID, LogTime, RecGUID, RecNum, TypeGUID, Operation, OperationType, UserGUID) 
			VALUES (HOST_NAME(), NEWID(), GETDATE(), @chGuid, @chNumber, @ChequeType, 4, 1, [dbo].[fnGetCurrentUserGUID]()) 

			IF @ManualGenEntry = 0
			BEGIN 
				INSERT INTO #EntriesNumbers EXEC [prcNote_genEntry] @chGuid

				DELETE #ChequeOrders

				INSERT INTO #ChequeOrders (OrderGUID)
				SELECT DISTINCT
					ord.GUID
				FROM 
					[POSPaymentsPackageCheck000] ch
					INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = ch.[ParentID]
					INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
					INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
				WHERE 
					pak.PayType = 3
					AND 
					ch.Type = @ChequeType
					AND 
					ch.CreditAccID = @CreditAccID
					AND 
					ch.DebitAccID = @DebitAccID 
					AND 
					ch.CurrencyID = @curGUID
					AND 
					ch.CurrencyValue = @curVal
					AND
					ch.NewVoucher = @NewVoucher
					AND 
					ABS(ISNULL(ch.[Paid], 0)) > 0

				;WITH Entries AS
				(
					SELECT 
						en.GUID AS EntryGUID,
						rn = ROW_NUMBER() OVER (PARTITION BY ce.GUID ORDER BY en.Number DESC)
					FROM 
						ch000 ch 
						INNER JOIN er000 er ON ch.GUID = er.ParentGUID
						INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
						INNER JOIN en000 en ON ce.GUID = en.ParentGUID
					WHERE ch.GUID = @chGuid
				)
				
				INSERT INTO POSPaymentLink000 (
					EntryGUID, 
					ParentGUID, 
					[Type], 
					[GUID]) 
				SELECT 
					en.EntryGUID,
					ch.OrderGUID, 
					10,
					NEWID()
				FROM 
					#ChequeOrders ch,
					(SELECT EntryGUID FROM 
						Entries
					WHERE rn = 1) AS en

				DECLARE 
					@ceGUID UNIQUEIDENTIFIER,
					@acGUID UNIQUEIDENTIFIER

				SELECT TOP 1 @ceGUID = ce.GUID 
				FROM
					ch000 ch 
					INNER JOIN er000 er ON ch.GUID = er.ParentGUID
					INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
					INNER JOIN en000 en ON ce.GUID = en.ParentGUID
				WHERE 
					ch.GUID = @chGUID
					AND 
					er.ParentType = 5
				
				IF ISNULL(@ceGUID, 0x0) != 0x0
				BEGIN 
					SELECT @acGUID = CASE WHEN @IsReturnBill = 0 AND @NewVoucher = 0 THEN @DebitAccID ELSE @CreditAccID END

					EXEC prcCheque_History_Add 
						@chGUID, @OrdersDate, @State, 33, @ceGUID, @acGUID, @AccountGUID, @paid, 5, 
						@curGUID, @curVal, 0x0, 0.0, @Cost2GUID, @DefCostGUID, 0x0, @CustomerGUID
				END
			END 

			IF ISNULL(@GUID, 0x0) != 0x0
			BEGIN 
				UPDATE [POSPaymentsPackageCheck000] 
				SET ChildID = @chGuid 
				WHERE [GUID] = @GUID --PK To Ch000
			END ELSE BEGIN 
				UPDATE ch 
				SET ChildID = @chGuid 
				FROM 
					[POSPaymentsPackageCheck000] ch
					INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = ch.[ParentID]
					INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
					INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
				WHERE 
					pak.PayType = 3
					AND 
					ch.Type = @ChequeType
					AND 
					ch.CreditAccID = @CreditAccID
					AND 
					ch.DebitAccID = @DebitAccID 
					AND 
					ch.CurrencyID = @curGUID
					AND 
					ch.CurrencyValue = @curVal
					AND
					ch.NewVoucher = @NewVoucher
					AND 
					ABS(ISNULL(ch.[Paid], 0)) > 0
			END 
		END 

		FETCH NEXT FROM @c_cheques INTO @GUID, @Number, @Notes, @paid, @ChequeType, @CreditAccID, @DebitAccID, @curGUID, @curVal, @NewVoucher
	END CLOSE @c_cheques DEALLOCATE @c_cheques
################################################################################
CREATE PROCEDURE prcPOS_GenerateMergedVoucherEntry
	@TypeGUID			UNIQUEIDENTIFIER,
	@BranchGUID			UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@OrdersDate			DATE,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@CurrencyValue		FLOAT,
	@CurrencyAccount	UNIQUEIDENTIFIER,
	@AccountGUID		UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@UserGUID			UNIQUEIDENTIFIER,
	@PayType			INT,
	@IsReturnBill		BIT,
	@BillGUID			UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT
		ord.Number AS OrderNumber,
		ord.GUID AS OrderGUID,
		ISNULL(pak.[ReturnVoucherValue], 0) AS ReturnVoucherValue,
		ABS(ISNULL([DeferredAmount], 0)) AS DeferredAmount
	INTO 
		#payments 
	FROM 
		[POSPaymentsPackage000] pak
		INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
		INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
	WHERE 
		pak.PayType = 3
		AND 
		ISNULL(pak.[ReturnVoucherValue], 0) != 0
		AND 
		ISNULL(ReturnVoucherID, 0x0) != 0x0

	IF @@ROWCOUNT = 0
		RETURN 
	
	DECLARE 
		@c CURSOR,
		@OrderGUID UNIQUEIDENTIFIER 
	SET @c = CURSOR FAST_FORWARD FOR SELECT OrderGUID FROM #payments ORDER BY OrderNumber
	OPEN @c FETCH NEXT FROM @c INTO @OrderGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		EXEC prcPOSGenerateReturnVoucherEntry @OrderGUID, 0x0, @CurrencyGUID, @CurrencyValue

		FETCH NEXT FROM @c INTO @OrderGUID
	END CLOSE @c DEALLOCATE @c 
################################################################################
CREATE PROCEDURE prcPOS_GenerateMergedCurrencies
	@TypeGUID			UNIQUEIDENTIFIER,
	@BranchGUID			UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@OrdersDate			DATE,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@CurrencyValue		FLOAT,
	@DefCurrencyValue	FLOAT,
	@CurrencyAccount	UNIQUEIDENTIFIER,
	@AccountGUID		UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@UserGUID			UNIQUEIDENTIFIER,
	@PayType			INT,
	@IsReturnBill		BIT,
	@BillGUID			UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		1 AS [Type],
		SUM(ABS(ISNULL(cu.[Paid], 0) * ISNULL(cu.[Equal], 0))) AS [Paid], 
		SUM(ABS(ISNULL(cu.[Returned], 0) * ISNULL(cu.[Equal], 0))) AS [Returned], 
		ISNULL(cu.[Equal], 0) AS [CurrencyValue], 
		ISNULL(cu.[CurrencyID], 0x0) AS [CurrencyGuid],
		ci.CashAccID AS CashAccID,
		cu.[Code] AS [Code],
		ord.Type AS [OrderType]
	INTO 
		#currencies 
	FROM 
		[POSPaymentsPackageCurrency000] cu
		INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = cu.[ParentID]
		INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
		INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
		INNER JOIN POSCurrencyItem000 ci ON ci.CurID = cu.[CurrencyID]
	WHERE 
		pak.PayType = 3
		AND 
		ci.UserID = @UserGUID
		AND 
		ISNULL(ci.CashAccID, 0x0) != 0x0
	GROUP BY 
		ISNULL(cu.[Equal], 0),
		ISNULL(cu.[CurrencyID], 0x0),
		cu.[Code],
		ci.CashAccID,
		ord.Type

	INSERT INTO #currencies 
	SELECT
		2,
		SUM(ISNULL(PointsValue, 0)),
		0,
		ord.CurrencyValue,
		ord.CurrencyID,
		pp.AccountGUID,
		'',
		ord.Type
	FROM
		[POSPaymentsPackagePoints000] pp
		INNER JOIN POSOrder000 ord ON pp.[ParentGUID] = ord.PaymentsPackageID
		INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
	GROUP BY
		pp.AccountGUID,
		ord.CurrencyValue,
		ord.CurrencyID,
		ord.Type
	
	IF NOT EXISTS(SELECT 1 FROM #currencies)
		RETURN

	DECLARE 
		@language				INT,
		@UserNumber				INT,
		@BillNumber				INT 

	SET @language = [dbo].[fnConnections_GetLanguage]()	
	SELECT @UserNumber = ISNULL(Number, 0) FROM us000 WHERE GUID = @UserGUID
	SELECT @BillNumber = ISNULL(Number, 0) FROM bu000 WHERE GUID = ISNULL(@BillGUID, 0x0)

	DECLARE 
		@ceGuid		UNIQUEIDENTIFIER,
		@ceNumber	INT,
		@ceNote		NVARCHAR(500),
		@ceDebit	FLOAT 

	SET @ceGuid = NEWID()
	SET @ceNumber = ISNULL((SELECT MAX(ISNULL([Number], 0)) FROM [ce000] WHERE Branch = @BranchGUID), 0) + 1
	SELECT @ceDebit = SUM(ABS(ISNULL([Paid], 0)) - ABS(ISNULL([Returned], 0))) FROM #currencies
	SET @ceNote = (SELECT CASE @language WHEN 0 THEN [Abbrev] ELSE CASE ISNULL([LatinAbbrev], '') WHEN '' THEN [Abbrev] ELSE [LatinAbbrev] END END FROM bt000 WHERE GUID = @TypeGUID)
	SET @ceNote = @ceNote + ' [' + CAST(@BillNumber AS NVARCHAR(250)) + ']' 

	INSERT INTO [ce000] (
		[Type],
		[Number],
		[Date], 
		[Debit],
		[Credit], 
		[Notes], 
		[CurrencyVal], 
		[IsPosted], 
		[State], 
		[Security], 
		[Num1], 
		[Num2], 
		[Branch], 
		[GUID], 
		[CurrencyGUID], 
		[TypeGUID], 
		[PostDate])   
	VALUES (
		1,--Type 
		@ceNumber,--Number 
		@OrdersDate,--Date 
		@ceDebit, --Debit 
		@ceDebit, --Credit 
		@ceNote,--Notes 
		@CurrencyValue,--CurrencyVal 
		0,--IsPosted 
		0,--State 
		1,--Security 
		0,--Num1 
		0,--Num2 
		@BranchGUID,--Branch 
		@ceGuid,--GUID 
		@CurrencyGUID,--CurrencyGUID 
		0x0, --TypeGUID  
		@OrdersDate )
		
	DECLARE 
		@c_currencies	CURSOR,
		@paid			FLOAT,
		@returned		FLOAT,
		@curVal			FLOAT,
		@curGUID		UNIQUEIDENTIFIER,
		@orderType		INT 

	DECLARE 
		@enNumber				INT,
		@EnID					UNIQUEIDENTIFIER,
		@curNotes				NVARCHAR(500),
		@enNotes				NVARCHAR(500),
		@pointsNotes			NVARCHAR(500),
		@cashAccountCusomterId	UNIQUEIDENTIFIER,
		@cashAccountID			UNIQUEIDENTIFIER

	SET @curNotes = [dbo].[fnStrings_get]('POS\CASH', @language)
	SET @pointsNotes = [dbo].[fnStrings_get]('POS\LOYALTY_POINTS', @language)
	SET @enNumber = 0

	SET @c_currencies = CURSOR FAST_FORWARD FOR
		SELECT 
			[Paid], 
			[Returned], 
			[CurrencyValue], 
			[CurrencyGuid],
			-- [Code],
			[OrderType],
			CashAccID,
			IIF( [Type] = 1, @curNotes, @pointsNotes) 
		FROM 
			#currencies
		ORDER BY 
			[Type], [CurrencyValue], [Code]

	OPEN @c_currencies FETCH NEXT FROM @c_currencies INTO @paid, @returned, @curVal, @curGUID, @orderType, @cashAccountID, @enNotes
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		SET @cashAccountCusomterId = 0x0
		IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @cashAccountID HAVING COUNT(AccountGUID) = 1)
		BEGIN
			SELECT TOP 1 @cashAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @cashAccountID 
		END

		IF @paid > 0
		BEGIN	
			SET @enNumber = @enNumber + 1
			SET @EnID = newID() 
			INSERT INTO [en000] (
				[Number],
				[Date],
				[Debit],
				[Credit],
				[Notes],
				[CurrencyVal],
				[Class],
				[Num1],
				[Num2],
				[Vendor],
				[SalesMan],
				[GUID],
				[ParentGUID],
				[AccountGUID],
				[CurrencyGUID],
				[CostGUID],
				[ContraAccGUID],
				[CustomerGUID])				
			VALUES ( 
				@enNumber, --Number 
				@OrdersDate, --Date 
				@paid, --Debit 
				0, --Credit 
				@enNotes, --Notes 
				@curVal, --CurrencyVal 
				'', --Class 
				0, --Num1 
				0, --Num2 
				0, --Vendor 
				@UserNumber, --SalesMan 
				@EnID,
				@ceGuid, --ParentGUID 
				CASE WHEN @IsReturnBill = 1 THEN @AccountGUID ELSE @cashAccountID END, --AccountGUID 
				@curGUID, --CurrencyGUID 
				0x0, --CostGUID 
				CASE WHEN @IsReturnBill = 1 THEN @cashAccountID ELSE @AccountGUID END, --ContraAccGUID)
				CASE WHEN @IsReturnBill = 1 THEN @CustomerGUID ELSE ISNULL(@cashAccountCusomterId, 0x0) END) --CustomerGUID
							
			SET @enNumber = @enNumber + 1 
			
			SET @EnID = newID() 
			INSERT INTO [en000] (
				[Number],
				[Date],
				[Debit],
				[Credit],
				[Notes],
				[CurrencyVal],
				[Class],
				[Num1],
				[Num2],
				[Vendor],
				[SalesMan],
				[GUID],
				[ParentGUID],
				[AccountGUID],
				[CurrencyGUID],
				[CostGUID],
				[ContraAccGUID],
				[CustomerGUID])				
			VALUES ( 
				@enNumber, --Number 
				@OrdersDate, --Date 
				0, --Debit 
				@paid, --Credit 
				@enNotes, --Notes 
				@curVal, --CurrencyVal 
				'', --Class 
				0, --Num1 
				0, --Num2 
				0, --Vendor 
				@UserNumber, --SalesMan 
				@EnID,
				@ceGuid, --ParentGUID 
				CASE WHEN @IsReturnBill = 1 THEN @cashAccountID ELSE @AccountGUID END, --AccountGUID 
				@curGUID, --CurrencyGUID 
				0x0, --CostGUID 
				CASE WHEN @IsReturnBill = 1 THEN @AccountGUID ELSE @cashAccountID END, --ContraAccGUID)
				CASE WHEN @IsReturnBill = 1 THEN 0x0 ELSE @CustomerGUID END) --CustomerGUID

			INSERT INTO POSPaymentLink000 (
				EntryGUID, 
				ParentGUID, 
				[Type], 
				[GUID]) 
			SELECT 
				@EnID,
				ord.GUID, 
				10,
				NEWID()
			FROM 
				[POSPaymentsPackageCurrency000] cu
				INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = cu.[ParentID]
				INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
				INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 
				INNER JOIN POSCurrencyItem000 ci ON ci.CurID = cu.[CurrencyID]
			WHERE 
				pak.PayType = 3
				AND 
				ci.UserID = @UserGUID
				AND 
				ci.CurID = @curGUID
				AND 
				ABS(ISNULL(cu.[Paid], 0) * ISNULL(cu.[Equal], 0)) > 0
			UNION ALL
			SELECT
				@EnID,
				ord.GUID, 
				10,
				NEWID()
			FROM
				[POSPaymentsPackagePoints000] pp
				INNER JOIN POSOrder000 ord ON pp.[ParentGUID] = ord.PaymentsPackageID
				INNER JOIN #OrdersTable t ON t.OrderGUID = ord.GUID 

		END
		IF @returned > 0
		BEGIN
			SET @enNumber = @enNumber + 1
			INSERT INTO [en000] (
				[Number],
				[Date],
				[Debit],
				[Credit],
				[Notes],
				[CurrencyVal],
				[Class],
				[Num1],
				[Num2],
				[Vendor],
				[SalesMan],
				[GUID],
				[ParentGUID],
				[AccountGUID],
				[CurrencyGUID],
				[CostGUID],
				[ContraAccGUID],
				[CustomerGUID])				
			VALUES (
				@enNumber, --Number 
				@OrdersDate, --Date 
				@returned, --Debit 
				0, --Credit 
				'Returned', --Notes 
				@curVal, --CurrencyVal 
				'', --Class 
				0, --Num1 
				0, --Num2 
				0, --Vendor 
				@UserNumber, --SalesMan 
				newid(),
				@ceGuid, --ParentGUID 
				CASE WHEN @IsReturnBill = 1 THEN @cashAccountID ELSE @AccountGUID END, --AccountGUID 
				@curGUID, --CurrencyGUID 
				0x0, --CostGUID 
				CASE WHEN @IsReturnBill = 1 THEN @AccountGUID ELSE @cashAccountID END, --ContraAccGUID)
				CASE WHEN @IsReturnBill = 1 THEN 0x0 ELSE @CustomerGUID END) --CusrtomerGUID

			SET @enNumber = @enNumber + 1 
			INSERT INTO [en000] (
				[Number],
				[Date],
				[Debit],
				[Credit],
				[Notes],
				[CurrencyVal],
				[Class],
				[Num1],
				[Num2],
				[Vendor],
				[SalesMan],
				[GUID],
				[ParentGUID],
				[AccountGUID],
				[CurrencyGUID],
				[CostGUID],
				[ContraAccGUID],
				[CustomerGUID])				
			VALUES (
				@enNumber, --Number 
				@OrdersDate, --Date 
				0, --Debit 
				@returned, --Credit 
				'Returned', --Notes 
				@curVal, --CurrencyVal 
				'', --Class 
				0, --Num1 
				0, --Num2 
				0, --Vendor 
				@UserNumber, --SalesMan 
				newid(),
				@ceGuid, --ParentGUID 
				CASE WHEN @IsReturnBill = 1 THEN @AccountGUID ELSE @cashAccountID END, --AccountGUID 
				@curGUID, --CurrencyGUID 
				0x0,	--CostGUID 
				CASE WHEN @IsReturnBill = 1 THEN @cashAccountID ELSE @AccountGUID END, --ContraAccGUID)
				CASE WHEN @IsReturnBill = 1 THEN @CustomerGUID ELSE 0x0 END) --CustomerGUID
		END

		FETCH NEXT FROM @c_currencies INTO @paid, @returned, @curVal, @curGUID, @orderType, @cashAccountID, @enNotes
	END CLOSE @c_currencies DEALLOCATE @c_currencies

	UPDATE [ce000] SET [IsPosted] = 1 WHERE [GUID] = @ceGUID 
################################################################################
CREATE PROCEDURE prcPOS_GenMergedBill
	@TypeGUID			UNIQUEIDENTIFIER,
	@BranchGUID			UNIQUEIDENTIFIER,
	@CostGUID			UNIQUEIDENTIFIER,
	@OrdersDate			DATE,
	@CurrencyGUID		UNIQUEIDENTIFIER,
	@CurrencyValue		FLOAT,
	@DefCurrencyValue	FLOAT,
	@CurrencyAccount	UNIQUEIDENTIFIER,
	@AccountGUID		UNIQUEIDENTIFIER,
	@CustomerGUID		UNIQUEIDENTIFIER,
	@UserGUID			UNIQUEIDENTIFIER,
	@PayType			INT,
	@IsReturnBill		BIT,
	@BillGUID			UNIQUEIDENTIFIER OUTPUT 
AS 
	SET NOCOUNT ON 

	DECLARE 
		@BillNumber			INT,		
		@GCCTaxEnable		INT
		-- @IsFoundSN			BIT

	DECLARE 
		@BtDefStoreGUID		UNIQUEIDENTIFIER,
		@BtVatSystem		INT,
		@BtAutoPost			INT,
		@BtAutoGenEntry		INT,
		@BtCustomerGuid		UNIQUEIDENTIFIER,
		@BtCashAccGUID		UNIQUEIDENTIFIER,
		@BtDefCostGUID		UNIQUEIDENTIFIER,
		@BtDiscAccGUID		UNIQUEIDENTIFIER,
		@BtExtraAccGUID		UNIQUEIDENTIFIER

	DECLARE @BuTable TABLE (
		Total				FLOAT,
		Discount			FLOAT,
		Extra				FLOAT,
		ItemsDiscount		FLOAT,
		ItemsExtra			FLOAT,
		Tax					FLOAT)

	DECLARE @BiTable TABLE (
		Number				INT IDENTITY(1, 1),
		GUID				UNIQUEIDENTIFIER,
		ParentGUID			UNIQUEIDENTIFIER,
		MaterialGUID		UNIQUEIDENTIFIER,
		Qty					FLOAT,
		BonusQnt			FLOAT,
		Unity				INT,
		Price				FLOAT,
		Discount			FLOAT,
		Extra				FLOAT,
		Tax					FLOAT,
		Vat					FLOAT,
		CostGUID			UNIQUEIDENTIFIER,
		StroeGUID			UNIQUEIDENTIFIER,
		[ExpireDate]		DATE,
		[ProductionDate]	DATE,
		SOType				INT,
		SOGuid				UNIQUEIDENTIFIER,
		ClassPtr			NVARCHAR(100),
		UnitFact			FLOAT)

	DECLARE @SnTable TABLE (
		Number				INT IDENTITY(1, 1),
		BiGUID				UNIQUEIDENTIFIER,
		MaterialGUID		UNIQUEIDENTIFIER,
		Unity				INT,
		Price				FLOAT,
		SalesmanID			UNIQUEIDENTIFIER,
		[ExpireDate]		DATE,
		[ProductionDate]	DATE,
		SOType				INT,
		SOGuid				UNIQUEIDENTIFIER,
		SN					NVARCHAR(100),
		RelatedToGUID		UNIQUEIDENTIFIER,
		ClassPtr			NVARCHAR(100))

	CREATE TABLE #OrdersTable (
		OrderGUID			UNIQUEIDENTIFIER)

	DECLARE @DiTable TABLE (
		[Number]		INT IDENTITY(1, 1),
		[Value]			FLOAT,
		[AccountID]		UNIQUEIDENTIFIER,
		[IsDiscount]	BIT,
		[Notes]			NVARCHAR(500) )
	
	SET @GCCTaxEnable = ISNULL((SELECT [Value] FROM op000 WHERE [Name] = 'AmnCfg_EnableGCCTaxSystem'), 0)
	
	--SET @IsFoundSN = 0
	--IF EXISTS(SELECT 1 FROM snc000)
	--	SET @IsFoundSN = 1

	SELECT
		@BtVatSystem =		CASE @GCCTaxEnable WHEN 1 THEN 1 ELSE ISNULL([VATSystem], 0) END,
		@BtAutoPost =		ISNULL([bAutoPost], 0),
		@BtAutoGenEntry =	ISNULL([bAutoEntry], 0),
		@BtDefStoreGUID =	ISNULL(DefStoreGUID, 0x0),
		@BtDefCostGUID =	ISNULL(DefCostGUID, 0x0),
		@BtCustomerGUID =	ISNULL(CustAccGUID, 0x0),
		@BtCashAccGUID =	ISNULL(DefCashAccGUID, 0x0),
		@BtDiscAccGUID =	ISNULL([DefDiscAccGuid], 0x0),
		@BtExtraAccGUID =	ISNULL([DefExtraAccGuid], 0x0)
	FROM [bt000]
	WHERE [GUID] = @TypeGUID

	IF @CostGUID = 0x0
		SET @CostGUID = @BtDefCostGUID 

	IF @PayType != 2 AND ISNULL(@AccountGUID, 0x0) = 0x0
		SET @AccountGUID = [dbo].fnGetDAcc(@BtCashAccGUID)

	IF @GCCTaxEnable = 1 AND ISNULL(@CustomerGUID, 0x0) = 0x0
		SET @CustomerGUID = @BtCustomerGUID

	INSERT INTO #OrdersTable (OrderGUID)
	SELECT DISTINCT
		ord.GUID 
	FROM 
		POSOrder000 ord
		INNER JOIN POSOrderItems000 ordI ON ordI.[ParentID] = ord.GUID
		INNER JOIN POSUserBills000 usb ON ord.UserBillsID = usb.GUID
		INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = ord.PaymentsPackageID
		OUTER APPLY (
			SELECT 
				TOP 1 [CurrencyID], [Equal]
			FROM 
				[POSPaymentsPackageCurrency000]
			WHERE [ParentID] = ord.[PaymentsPackageID] AND Paid <> 0) cu

	WHERE 
		(
			((@IsReturnBill = 0) AND (usb.SalesID = @TypeGUID))
			OR 
			((@IsReturnBill = 1) AND (usb.ReturnedID = @TypeGUID))
		)
		AND  
		ord.BranchID = @BranchGUID
		AND 
		ord.SalesManID = @CostGUID
		AND 
		CONVERT(DATE, ord.Date) = @OrdersDate
		AND 
		(
			(@PayType = 3) 
			OR 
			((@PayType = 1) AND ((CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyID ELSE cu.[CurrencyID] END) = @CurrencyGUID))
			OR 
			(ord.CurrencyID = @CurrencyGUID)			
		)
		AND 
		(
			(@PayType = 3) 
			OR 
			((@PayType = 1) AND ((CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyValue ELSE cu.[Equal] END) = @CurrencyValue))
			OR 
			((@PayType = 2) AND (ord.CurrencyValue = @CurrencyValue))
		)		
		AND 
		((ord.CustomerID = 0x0) OR (ord.CustomerID = @CustomerGUID))
		AND 
		ord.FinishCashierID = @UserGUID
		AND
		ordI.State = 0 
		AND 
		NOT EXISTS(SELECT 1 FROM BillRel000 WHERE ParentGUID = ord.GUID AND ((@IsReturnBill = 0) OR ((@IsReturnBill = 1) AND (BillGUID != ISNULL(@BillGUID, 0x0)))))
		AND 
		(
			((@IsReturnBill = 0) AND (ord.[Type] IN (0, 1)) AND (ordI.Type != 1))
			OR 
			((@IsReturnBill = 1) AND (ord.[Type] IN (0, 1)) AND (ordI.Type = 1))
		)
		AND 
		pak.PayType = @PayType
	
	IF @@ROWCOUNT = 0
		RETURN 
	------------------------------------------------
	------------------------------------------------
	SET @BillGUID = NEWID()

	DECLARE 
		@OrdersDiscount		FLOAT,
		@OrdersExtra		FLOAT,
		@OrdersTax			FLOAT,
		@FPay				FLOAT,
		@RoundedValue		FLOAT,
		@UserNumber			INT 

	SELECT 
		@OrdersDiscount = ISNULL(SUM(ISNULL([Value], 0)), 0)
	FROM 
		[POSOrderDiscount000] ordD
		INNER JOIN #OrdersTable ord ON ordD.[ParentID] = ord.OrderGUID
	WHERE 
		((@IsReturnBill = 0) AND (ordD.[OrderType] = 0))  -- Sales
		OR 
		((@IsReturnBill = 1) AND (ordD.[OrderType] = 1))  -- Return Sales

	SELECT 
		@OrdersExtra = ISNULL(SUM(ISNULL([Value], 0)), 0)
	FROM 
		[POSOrderAdded000] ordE
		INNER JOIN #OrdersTable ord ON ordE.[ParentID] = ord.OrderGUID
	WHERE 
		((@IsReturnBill = 0) AND (ordE.[OrderType] = 0))  -- Sales
		OR 
		((@IsReturnBill = 1) AND (ordE.[OrderType] = 1))  -- Return Sales

	SELECT 
		@OrdersTax =	ISNULL(SUM(ISNULL(o.[Tax], 0)), 0),
		@FPay =			0,
		@RoundedValue = ISNULL(ABS(SUM(pak.[RoundedValue])), 0)
	FROM 
		[POSOrder000] o
		INNER JOIN #OrdersTable ord ON o.[GUID] = ord.OrderGUID
		INNER JOIN [POSPaymentsPackage000] pak ON pak.[GUID] = o.[PaymentsPackageID]

	SELECT @UserNumber = ISNULL(Number, 0) FROM us000 WHERE GUID = @UserGUID
	------------------------------------------------
	------------------------------------------------		
	INSERT INTO @BiTable (
		GUID,
		ParentGUID,
		MaterialGUID,
		Qty,
		BonusQnt,
		Unity,
		Price,
		Discount,
		Extra,
		Tax,
		Vat,
		CostGUID,
		StroeGUID,
		[ExpireDate],
		[ProductionDate],
		SOType,
		SOGuid,
		ClassPtr,
		UnitFact)
	SELECT 
		NEWID(),
		@BillGUID, 
		ordI.MatID,
		SUM (
			CASE 
				WHEN ordI.[Type] != 2 THEN 
					(CASE ordI.[Unity]
						WHEN 2 THEN ISNULL([mt].[Unit2Fact], 1)
						WHEN 3 THEN ISNULL([mt].[Unit3Fact], 1)
						ELSE 1 
					END) * ordI.[Qty] 
				ELSE 0 
			END),
		SUM (
			CASE 
				WHEN ordI.[Type] = 2 THEN 
					(CASE ordI.[Unity]
						WHEN 2 THEN ISNULL([mt].[Unit2Fact], 1)
						WHEN 3 THEN ISNULL([mt].[Unit3Fact], 1)
						ELSE 1 
					END) * ordI.[Qty] 
				ELSE 0 
			END),
		ISNULL(ordI.Unity, 1),
		ordI.[Price],			
		SUM(ordI.Discount),
		SUM(ordI.Added),
		SUM(ordI.Tax),
		ordI.VATValue,
		ordI.SalesmanID, 
		@BtDefStoreGUID,
		ordI.[ExpirationDate],
		ordI.[ProductionDate],
		ordI.OfferedItem, 
		ordI.[SpecialOfferID],
		ordI.ClassPtr,
		(CASE ordI.[Unity]
			WHEN 2 THEN ISNULL([mt].[Unit2Fact], 1)
			WHEN 3 THEN ISNULL([mt].[Unit3Fact], 1)
			ELSE 1 
		END)
	FROM 
		POSOrder000 ord
		INNER JOIN #OrdersTable t			ON ord.GUID = t.OrderGUID
		INNER JOIN POSOrderItems000 ordI	ON ord.GUID = ordI.[ParentID]
		INNER JOIN POSUserBills000 usb		ON usb.GUID = ord.UserBillsID 
		INNER JOIN mt000 AS mt				ON mt.GUID = ordI.[MatID]
	WHERE 
		ordI.State = 0
		AND 
		(
			((@IsReturnBill = 0) AND (ord.[Type] IN (0, 1)) AND (ordI.Type != 1))
			OR 
			((@IsReturnBill = 1) AND (ord.[Type] IN (0, 1)) AND (ordI.Type = 1))
		)
	GROUP BY 
		ordI.MatID,
		ordI.Unity,
		ordI.Price,
		ordI.VATValue,
		ordI.SalesmanID, 
		ordI.[ExpirationDate],
		ordI.[ProductionDate],
		ordI.OfferedItem, 
		ordI.[SpecialOfferID],
		ordI.ClassPtr,
		(CASE ordI.[Unity]
			WHEN 2 THEN ISNULL([mt].[Unit2Fact], 1)
			WHEN 3 THEN ISNULL([mt].[Unit3Fact], 1)
			ELSE 1 
		END)

	IF @@ROWCOUNT = 0
		RETURN 

	--IF @IsFoundSN = 1
	--BEGIN 
		INSERT INTO @SnTable (
			MaterialGUID,
			Unity,
			Price,
			SalesmanID,
			[ExpireDate],
			[ProductionDate],
			SOType,
			SOGuid,
			SN,
			RelatedToGUID,
			ClassPtr)
		SELECT 
			ordI.MatID,
			ISNULL(ordI.Unity, 1),
			ordI.[Price],			
			ordI.SalesmanID, 
			ordI.[ExpirationDate],
			ordI.[ProductionDate],
			ordI.OfferedItem, 
			ordI.[SpecialOfferID],
			ordI.[SerialNumber],
			ordI.[GUID],
			ordI.ClassPtr
		FROM 
			POSOrder000 ord
			INNER JOIN #OrdersTable t			ON ord.GUID = t.OrderGUID
			INNER JOIN POSOrderItems000 ordI	ON ord.GUID = ordI.[ParentID]
			INNER JOIN POSUserBills000 usb		ON usb.GUID = ord.UserBillsID 
			INNER JOIN mt000 AS mt				ON mt.GUID = ordI.[MatID]
		WHERE 
			ordI.State = 0
			AND 
			(
				((@IsReturnBill = 0) AND (ord.[Type] IN (0, 1)) AND (ordI.Type != 1))
				OR 
				((@IsReturnBill = 1) AND (ord.[Type] IN (0, 1)) AND (ordI.Type = 1))
			)
			AND 
			(LEN(ordI.[SerialNumber]) > 0)
			AND 
			(ordI.[Type] != 2)
		
		IF @@ROWCOUNT > 0
		BEGIN 
			UPDATE @SnTable
			SET BiGUID = bi.GUID
			FROM 
				@SnTable sn
				CROSS APPLY (
					SELECT TOP 1 GUID 
					FROM @BiTable 
					WHERE 
						MaterialGUID = sn.MaterialGUID
						AND 
						Unity = sn.Unity
						AND 
						Price = sn.Price
						AND 
						SalesmanID = sn.SalesmanID
						AND 
						ExpireDate = sn.ExpireDate
						AND 
						ProductionDate = sn.ProductionDate
						AND 
						SOType = sn.SOType
						AND 
						SOGuid = sn.SOGuid
						AND 
						ClassPtr = sn.ClassPtr) bi
		END 

		DELETE @SnTable WHERE ISNULL(BiGUID, 0x0) = 0x0
	-- END 

	INSERT INTO @BuTable (
		Total,
		Discount,
		Extra,
		ItemsDiscount,
		ItemsExtra,
		Tax)
	SELECT 
		SUM((Qty / (CASE UnitFact WHEN 0 THEN 1 ELSE UnitFact END)) * Price),
		@OrdersDiscount + @RoundedValue,
		@OrdersExtra,
		SUM(Discount),
		SUM(Extra),
		@OrdersTax + SUM(Tax)
	FROM 
		@BiTable

	IF @@ROWCOUNT = 0
		RETURN 

	INSERT INTO @DiTable ([Value], [AccountID], [IsDiscount], [Notes])
	SELECT 
		ISNULL(SUM(di.[Value]), 0),
		ISNULL(di.[AccountID], 0x0),
		1,
		''
	FROM 
		[POSOrderDiscount000] di
		INNER JOIN #OrdersTable ord ON ord.OrderGUID = di.[ParentID]
	WHERE 
		((@IsReturnBill = 0) AND (di.[OrderType] = 0))  -- Sales
		OR 
		((@IsReturnBill = 1) AND (di.[OrderType] = 1))  -- Return Sales
	GROUP BY di.[AccountID]

	INSERT INTO @DiTable ([Value], [AccountID], [IsDiscount], [Notes])
	SELECT 
		ISNULL(SUM(di.[Value]), 0),
		ISNULL(di.[AccountID], 0x0),
		0,
		''
	FROM 
		[POSOrderAdded000] di
		INNER JOIN #OrdersTable ord ON ord.OrderGUID = di.[ParentID]
	WHERE 
		((@IsReturnBill = 0) AND (di.[OrderType] = 0))  -- Sales
		OR 
		((@IsReturnBill = 1) AND (di.[OrderType] = 1))  -- Return Sales
	GROUP BY di.[AccountID]

	IF @RoundedValue > 0
	BEGIN 
		INSERT INTO @DiTable ([Value], [AccountID], [IsDiscount], [Notes])
		SELECT 
			@RoundedValue,
			@BtDiscAccGUID,
			1,
			'Round'
	END 
	------------------------------------------------
	------------------------------------------------		
	SET @BillNumber = dbo.fnGetNextBillNumber(@TypeGUID, @BranchGUID)

	INSERT INTO [bu000] (
		[Number],
	    [Cust_Name], 
		[Date], 
		[CurrencyVal], 
		[Notes], 
		[Total],
		[PayType], 
		[TotalDisc], 
		[TotalExtra], 
		[ItemsDisc], 
		[BonusDisc],
		[FirstPay], 
		[Profits], 
		[IsPosted], 
		[Security], 
		[Vendor], 
		[SalesManPtr], 
		[Branch], 
		[VAT], 
		[GUID], 
		[TypeGUID], 
		[CustGUID],
		[CurrencyGUID], 
		[StoreGUID], 
		[CustAccGUID], 
		[MatAccGUID], 
		[ItemsDiscAccGUID], 
		[BonusDiscAccGUID], 
		[FPayAccGUID], 
		[CostGUID],
		[UserGUID], 
		[CheckTypeGUID], 
		[TextFld1], 
		[TextFld2], 
		[TextFld3],
		[TextFld4], 
		[RecState], 
		[ItemsExtra], 
		[ItemsExtraAccGUID], 
		[CostAccGUID], 
		[StockAccGUID], 
		[VATAccGUID], 
		[BonusAccGUID],
		[BonusContraAccGUID],
		[CustomerAddressGUID])
	SELECT 
		@BillNumber,
		'',
		@OrdersDate,
		@CurrencyValue,
		'', --Notes
		Total,
		CASE @PayType WHEN 1 THEN 0 ELSE 1 END, 
		Discount + ItemsDiscount, 
		Extra + ItemsExtra, 
		ItemsDiscount, 
		0, 
		@FPay, 
		0, 
		0, -- IsPosted
		1, 
		0, 
		@UserNumber, 
		@BranchGUID,
		Tax, -- VAT
		ISNULL(@BillGUID, 0x0),
		@TypeGUID,
		@CustomerGUID,
		@CurrencyGUID,
		@BtDefStoreGUID,
		@AccountGUID,
		0x0, 
		0x0, 
		@BtDiscAccGUID, 
		@CurrencyAccount,
		@CostGUID,
		@UserGUID, -- UserGUID
		0x0,
		'Merged Bill', 
		'', 
		'', 
		'', 
		0, 
		ItemsExtra, 
		0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
	FROM 
		@BuTable

	INSERT INTO [bi000] (
		[Number], 
		[Qty], 
		[Order],  
		[OrderQnt],  
		[Unity],  
		[Price],
		[BonusQnt],  
		[Discount],  
		[BonusDisc],  
		[Extra],  
		[CurrencyVal],  
		[Notes],  
		[Profits],  
		[Num1],  
		[Num2],  
		[Qty2],  
		[Qty3],  
		[ClassPtr],  
		[ExpireDate],  
		[ProductionDate],  
		[Length],  
		[Width],  
		[Height],  
		[GUID],  
		[VAT],  
		[VATRatio],  
		[ParentGUID],  
		[MatGUID],  
		[CurrencyGUID],  
		[StoreGUID],  
		[CostGUID],  
		[SOType],  
		[SOGuid],  
		[Count],
		[TaxCode],
		[IsPOSSpecialOffer])	
	SELECT	
		[Number],
		Qty,
		0, --Order
		0, --OrderQnt
		Unity,
		CASE @BtVatSystem WHEN 2 THEN ISNULL([Price], 0) /(1 + (VAT / 100)) ELSE [Price] END,
		BonusQnt,
		[Discount],
		0, --BonusDisc
		[Extra],
		@CurrencyValue, --CurrencyVal
		'', -- Notes
		0, --Profits
		0, --Num1
		0, --Num2
		0, --Qty2
		0, --Qty3
		ClassPtr,
		[ExpireDate],
		[ProductionDate],
		0, --Length
		0, --Width
		0, --Height
		bi.GUID,
		ISNULL([Tax], 0),
		ISNULL(bi.[VAT], 0),
		ISNULL(@BillGUID, 0x0), --ParentGUID
		MaterialGUID,
		@CurrencyGUID, --CurrencyGUID
		StroeGUID,--StoreGUID
		ISNULL([CostGUID], 0x0),
		CASE ISNULL(SoGUID, 0x0) 
			WHEN 0x0 THEN 0
			ELSE CASE SOType WHEN 0 THEN 1 ELSE 2 END
		END, --SOType
		ISNULL(SoGUID, 0x0),
		0, --Count
		CASE @GCCTaxEnable WHEN 0 THEN 0 ELSE [TAX].TaxCode END,
		CASE ISNULL(SoGUID, 0x0)
			WHEN 0x0 THEN 0
			ELSE 1
		END
	FROM 
		@BiTable bi
		LEFT JOIN [GCCMaterialTax000] AS [TAX] ON bi.MaterialGUID = [TAX].[MatGUID]
	WHERE
		ISNULL([TAX].[TaxType], 1) = 1

	IF EXISTS(SELECT * FROM @SnTable)
     BEGIN
		-- Save Serail Numbers
		DECLARE @snGuid UNIQUEIDENTIFIER 
		SET @snGuid = NEWID()
		
		INSERT INTO [TempSn] (
			[ID],  
			[Guid],  
			[SN],  
			[MatGuid],  
			[stGuid],  
			[biGuid] ) 
		SELECT	
			Number,
			@snGuid,
			SN,
			MaterialGUID,
			@BtDefStoreGUID,
			[biGUID]
		FROM 
			@SnTable
		
		IF ISNULL(@BillGUID, 0x0) != 0x0
			EXEC [prcInsertIntoSN] @BillGUID, @snGuid
	END
	
	INSERT INTO [di000] (
		Number,  
		Discount,  
		Extra,  
		CurrencyVal,  
		Notes,  
		Flag,  
		GUID,  
		ClassPtr,  
		ParentGUID,  
		AccountGUID,  
		CustomerGUID , 
		CurrencyGUID,  
		CostGUID,  
		ContraAccGUID,
		IsGeneratedByPayTerms,
		IsValue,
		IsRatio )
	SELECT 
		Number,
		CASE [IsDiscount] WHEN 1 THEN [Value] ELSE 0 END,
		CASE [IsDiscount] WHEN 0 THEN [Value] ELSE 0 END,
		@CurrencyValue,
		Notes,
		0,
		NEWID(),
		'',
		ISNULL(@BillGUID, 0x0),
		[AccountID],
		0x0,
		@CurrencyGUID,
		0x0,
		0x0, 0, 0, 0
	FROM 
		@DiTable 
	WHERE 
		ISNULL([AccountID], 0x0) != 0x0 AND [Value] != 0

	INSERT INTO [BillRel000] (
		[GUID],
		[Type],
		[BillGUID],
		[ParentGUID],
		[ParentNumber])
	SELECT
		NEWID(), --GUID
		CASE @IsReturnBill WHEN 1 THEN 2 ELSE 1 END, --Type
		ISNULL(@BillGUID, 0x0), --BillGUID
		ord.GUID, --ParentGUID
		ord.Number
	FROM 
		#OrdersTable t
		INNER JOIN POSOrder000 ord ON t.OrderGUID = ord.GUID 

	IF @BtAutoPost = 1 AND ISNULL(@BillGUID, 0x0) != 0x0
	BEGIN
		EXECUTE [prcBill_Post1] @BillGUID, 1
	END

	IF @BtAutoGenEntry = 1 AND ISNULL(@BillGUID, 0x0) != 0x0
	BEGIN
		EXECUTE [prcBill_GenEntry] @BillGUID, 1, 0, 0, 0, 0, 1, @GCCTaxEnable
	END

	UPDATE #TransactionsCount SET Bills = Bills + 1

	UPDATE ord
	SET [BillNumber] = @BillNumber
	FROM 
		#OrdersTable t
		INNER JOIN POSOrder000 ord ON t.OrderGUID = ord.GUID 

	IF @PayType = 3
	BEGIN 
		EXEC prcPOS_GenerateMergedCurrencies 
			@TypeGUID,
			@BranchGUID,
			@CostGUID,
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@DefCurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,
			@IsReturnBill,
			@BillGUID
		
		EXEC prcPOS_GenerateMergedCheques
			@TypeGUID,
			@BranchGUID,
			@CostGUID,
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,
			@IsReturnBill,
			@BillGUID

		EXEC prcPOS_GenerateMergedVoucherEntry
			@TypeGUID,
			@BranchGUID,
			@CostGUID,
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,
			@IsReturnBill,
			@BillGUID
		
		EXEC prcPOS_GenerateMergedLinkPayments
			@TypeGUID,
			@BranchGUID,
			@CostGUID,
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,
			@IsReturnBill,
			@BillGUID
	END 
################################################################################
CREATE PROCEDURE prcPOS_GenMergedBills
	@CashierID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON

	DECLARE 
		@c					CURSOR,
		@SalesID			UNIQUEIDENTIFIER,
		@ReturnedID			UNIQUEIDENTIFIER,
		@CostGUID			UNIQUEIDENTIFIER,
		@BranchGUID			UNIQUEIDENTIFIER,
		@OrdersDate			DATE,
		@CurrencyGUID		UNIQUEIDENTIFIER,
		@CurrencyValue		FLOAT,
		@CurrencyAccount	UNIQUEIDENTIFIER,
		@AccountGUID		UNIQUEIDENTIFIER,
		@CustomerGUID		UNIQUEIDENTIFIER,
		@UserGUID			UNIQUEIDENTIFIER,
		@PayType			INT		

	DECLARE	
		@DefCurrencyID			[UNIQUEIDENTIFIER],
		@DefCurrencyValue		[FLOAT]
  
	SELECT TOP 1 @DefCurrencyID = ISNULL([Value], 0x0) 
	FROM FileOP000
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'
	
	IF ISNULL(@DefCurrencyID, 0x0) = 0X0
	BEGIN
		SELECT TOP 1 @DefCurrencyID = [Value] 
		FROM [op000] 
		WHERE [Name] = 'AmnCfg_DefaultCurrency'
		IF @@ROWCOUNT <> 1
			RETURN -200101

		SELECT @DefCurrencyValue = [CurrencyVal] 
		FROM [my000] 
		WHERE [Guid] = @DefCurrencyID
	END
	ELSE 
		SET @DefCurrencyValue = dbo.fnGetCurVal(@DefCurrencyID, GetDate())	
	
	SET @DefCurrencyValue = CASE @DefCurrencyValue WHEN 0 THEN 1 ELSE @DefCurrencyValue END 

	CREATE TABLE #TransactionsCount (Bills INT)
	INSERT INTO #TransactionsCount (Bills) 
	SELECT 0

	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			usb.SalesID					AS SalesID,
			usb.ReturnedID				AS ReturnedID,
			ord.BranchID				AS BranchID,
			ord.SalesManID				AS CostID,
			CONVERT(DATE, ord.[Date])	AS OrderDate,
			CASE pak.[PayType] 
				WHEN 3 THEN @DefCurrencyID
				WHEN 1 THEN CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyID ELSE cu.[CurrencyID] END
				ELSE ord.CurrencyID
			END							AS CurrencyGUID,
			CASE pak.[PayType] 
				WHEN 3 THEN @DefCurrencyValue
				WHEN 1 THEN CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyValue ELSE cu.[Equal] END
				ELSE ord.CurrencyValue
			END							AS CurrencyValue,
			ISNULL(FN.CashAccID, 0x0)	AS CurrencyAccount,
			CASE pak.[PayType]
				WHEN 1 THEN ISNULL(FN.CashAccID, 0x0)
				ELSE /*2, 3*/0x0
			END							AS AccountGUID,
			CASE pak.[PayType]
				WHEN 2 THEN ISNULL([pak].[DeferredAccount], 0x0)
				ELSE /*1, 3*/ISNULL(ord.CustomerID, 0x0)
			END							AS CustomerGUID,
			ord.FinishCashierID			AS UserGUID,
			pak.[PayType]				AS PayType
		FROM 
			POSOrder000 ord
			INNER JOIN POSUserBills000 usb ON usb.GUID = ord.UserBillsID
			INNER JOIN [POSPaymentsPackage000] pak ON pak.GUID = ord.PaymentsPackageID
			OUTER APPLY (
				SELECT 
					TOP 1 [CurrencyID], [Equal]
				FROM 
					[POSPaymentsPackageCurrency000]
				WHERE [ParentID] = ord.[PaymentsPackageID] AND Paid <> 0) cu
			OUTER APPLY (
				SELECT 
					TOP 1 CashAccID
				FROM 
					POSCurrencyItem000
				WHERE CurID = CASE pak.[PayType] WHEN 3 THEN @DefCurrencyID ELSE CASE ISNULL(ord.CurrencyID, 0x0) WHEN 0x0 THEN @DefCurrencyID ELSE ord.CurrencyID END END AND UserID = ord.FinishCashierID) FN
		WHERE 
			(ord.[Type] IN (0, 1))
			AND 
			EXISTS (SELECT * FROM [POSOrderItems000] WHERE [ParentID] = ord.GUID AND [State] = 0)
			AND 
			((@CashierID = 0x0) OR (ord.FinishCashierID = @CashierID))
			AND 
			NOT EXISTS(SELECT 1 FROM BillRel000 WHERE ParentGUID = ord.GUID)
		GROUP BY
			usb.SalesID,
			usb.ReturnedID,
			ord.BranchID,
			ord.SalesManID,
			CONVERT(DATE, ord.Date),
			CASE pak.[PayType] 
				WHEN 3 THEN @DefCurrencyID
				WHEN 1 THEN CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyID ELSE cu.[CurrencyID] END
				ELSE ord.CurrencyID
			END,
			CASE pak.[PayType] 
				WHEN 3 THEN @DefCurrencyValue
				WHEN 1 THEN CASE WHEN ISNULL(cu.[CurrencyID], 0x0) = 0x0 THEN ord.CurrencyValue ELSE cu.[Equal] END
				ELSE ord.CurrencyValue
			END,
			ISNULL(FN.CashAccID, 0x0),
			CASE pak.[PayType]
				WHEN 1 THEN ISNULL(FN.CashAccID, 0x0)
				ELSE /*2, 3*/0x0
			END,
			CASE pak.[PayType]
				WHEN 2 THEN ISNULL([pak].[DeferredAccount], 0x0)
				ELSE /*1, 3*/ISNULL(ord.CustomerID, 0x0)
			END,
			ord.FinishCashierID,
			pak.[PayType]

	OPEN @c 
	FETCH NEXT FROM @c INTO @SalesID, @ReturnedID, @BranchGUID, @CostGUID, @OrdersDate, @CurrencyGUID, 
							@CurrencyValue, @CurrencyAccount, @AccountGUID, @CustomerGUID, @UserGUID, @PayType

	BEGIN TRAN

	EXEC prcConnections_SetIgnoreWarnings 1

	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF @PayType != 1 
		BEGIN 
			SET @AccountGUID = (SELECT AccountGUID FROM cu000 WHERE GUID = @CustomerGUID)
		END 
		IF @PayType = 3 AND ISNULL(@CustomerGUID, 0x0) = 0x0 
		BEGIN 
			SELECT 
				@CustomerGUID =	CAST([Value] AS [UNIQUEIDENTIFIER]), 
				@AccountGUID =	[cu].[AccountGUID] 
			FROM 
				UserOp000 
				INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
			WHERE 
				[UserID] = @UserGUID 
				AND 
				[Name] = 'AmnPOS_MediatorCustID'
		END 

		DECLARE @BillGUID UNIQUEIDENTIFIER 
		SET @BillGUID = NULL

		EXEC prcPOS_GenMergedBill
			@SalesID,
			@BranchGUID,
			@CostGUID,			
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@DefCurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,			
			0,
			@BillGUID OUTPUT 

		-- return bills 
		EXEC prcPOS_GenMergedBill
			@ReturnedID,
			@BranchGUID,
			@CostGUID,			
			@OrdersDate,
			@CurrencyGUID,
			@CurrencyValue,
			@DefCurrencyValue,
			@CurrencyAccount,
			@AccountGUID,
			@CustomerGUID,
			@UserGUID,
			@PayType,			
			1, 
			@BillGUID OUTPUT

		FETCH NEXT FROM @c INTO @SalesID, @ReturnedID, @BranchGUID, @CostGUID, @OrdersDate, @CurrencyGUID, 
								@CurrencyValue, @CurrencyAccount, @AccountGUID, @CustomerGUID, @UserGUID, @PayType
	END CLOSE @c DEALLOCATE @c 

	EXEC prcConnections_SetIgnoreWarnings 0

	COMMIT TRAN

	SELECT * FROM #TransactionsCount
################################################################################
#END
