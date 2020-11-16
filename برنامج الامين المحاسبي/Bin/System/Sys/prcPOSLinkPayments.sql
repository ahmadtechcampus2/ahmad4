################################################################################
CREATE PROCEDURE prcPOSLinkPayments
	@OrderID UNIQUEIDENTIFIER
AS

DECLARE @mediatorAccountID UNIQUEIDENTIFIER,
		@Cur CURSOR,
		@EnID UNIQUEIDENTIFIER,
		@currencyguid uniqueidentifier,
		@currencyval float,
		@Paid float,
		@totalpaid float,
		@total float,
		@EnSaleID UNIQUEIDENTIFIER,
		@UserID UNIQUEIDENTIFIER,
		@mediatorCustomerID UNIQUEIDENTIFIER

	SELECT @total = ISNULL(SUBTOTAL, 0) + ISNULL([Added], 0) + ISNULL([Tax], 0) - ISNULL([Discount], 0),
		@UserID = CashierId
		FROM [POSOrder000]
		WHERE [Guid] = @OrderID

	SELECT @mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), @mediatorAccountID = [cu].[AccountGUID] 
	  FROM UserOp000 INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
	 WHERE [UserID] = @UserID AND [Name]='AmnPOS_MediatorCustID'

	SELECT @EnSaleID=en.GUID FROM billrel000 rel
		INNER JOIN bu000 bu ON bu.GUID=rel.billguid
		INNER JOIN er000 er ON bu.GUID=er.parentguid
		INNER JOIN ce000 ce ON ce.GUID=er.entryguid
		INNER JOIN en000 en ON en.parentguid=ce.GUID
	WHERE rel.parentguid = @OrderID AND en.AccountGuid = @mediatorAccountID AND en.CustomerGUID = @mediatorCustomerID

	IF ISNULL(@total, 0)<1
		RETURN 0

	SET @cur = CURSOR FAST_FORWARD FOR
		SELECT en.GUID,en.credit,en.currencyguid,en.currencyval FROM pospaymentlink000 link
			INNER JOIN en000 en ON en.GUID=link.EntryGuid
		WHERE link.ParentGuid=@OrderID
		ORDER BY link.type

	SET @totalpaid = 0
	OPEN @cur FETCH FROM @cur INTO @EnID,@paid,@currencyguid,@currencyval
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF @paid >= (@total - @totalpaid)
		BEGIN
			INSERT INTO bp000(GUID, DebtGUID, PayGUID, PayType, Val, CurrencyGUID, CurrencyVal, RecType, DebitType, ParentDebitGUID, ParentPayGUID, PayVal, PayCurVal)
			VALUES(newID(), @EnSaleID, @EnID, 0, @total - @totalpaid, @currencyguid, @currencyval, 0, 0, 0x0, 0x0, @total - @totalpaid, @currencyval) 
			RETURN 1
		END ELSE
		IF @paid < (@total - @totalpaid) and @paid>0
		BEGIN
			INSERT INTO bp000(GUID, DebtGUID, PayGUID, PayType, Val, CurrencyGUID, CurrencyVal, RecType, DebitType, ParentDebitGUID, ParentPayGUID, PayVal, PayCurVal)
			VALUES(newID(), @EnSaleID, @EnID, 0, @paid, @currencyguid, @currencyval, 0, 0, 0x0, 0x0, @total - @totalpaid, @currencyval) 
		END
		SET @totalpaid = @totalpaid + @paid
		FETCH NEXT FROM @cur INTO @EnID,@paid,@currencyguid,@currencyval
	END
	CLOSE @cur
	DEALLOCATE @cur
RETURN 1
################################################################################
#END
