######################################################
CREATE PROCEDURE prcPOSZeroingEntry
	@ZeroingID		UNIQUEIDENTIFIER, 
	@BranchID		UNIQUEIDENTIFIER, 
	@AdjustIDInc	UNIQUEIDENTIFIER, 
	@AdjustIDDec	UNIQUEIDENTIFIER, 
	@Note			NVARCHAR(250) = '' 
AS 
	SET NOCOUNT ON

	DECLARE 
		@currencyID		UNIQUEIDENTIFIER, 
		@currencyValue	FLOAT, 
		@UserID			UNIQUEIDENTIFIER, 
		@UserNum		FLOAT, 
		@Date			DATETIME, 
		@EntryNumber	FLOAT, 
		@CeID			UNIQUEIDENTIFIER 

	SET @CeID = NEWID() 

	--To log Zeroing Entry 
	SELECT @CeID AS CeId

	SELECT 
		@UserID =	[User], 
		@Date =		[Date] 
	FROM 
		POSResetDrawer000 
	WHERE @ZeroingID = GUID 

	SELECT @UserNum = ISNULL(Number, 1) FROM us000 WHERE GUID = @UserID  
	SELECT @EntryNumber = ISNULL(MAX(Number), 0) + 1 FROM ce000 WHERE [Branch] = ISNULL(@BranchID, 0x0)

	DECLARE @CeTable TABLE ( 
		ID				INT IDENTITY(1, 1) NOT NULL, 
		DEBIT			FLOAT, 
		CREDIT			FLOAT, 
		CurValue		FLOAT, 
		CurID			UNIQUEIDENTIFIER, 
		AccountID		UNIQUEIDENTIFIER, 
		ContraAccountID	UNIQUEIDENTIFIER ) 

	INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID)  
	SELECT  
		CASE WHEN Recycled > value THEN (Recycled - Value) * CurrencyValue ELSE 0.0 END,  
		CASE WHEN Recycled > value THEN 0.0 ELSE Paid*CurrencyValue + (CASE WHEN Value>(Paid+Recycled) THEN (Value-(Paid+Recycled))*CurrencyValue  ELSE 0.0 END) - (CASE WHEN Value<(Paid+Recycled) THEN ((Paid+Recycled)-Value)*CurrencyValue  ELSE 0.0 END) END ,  
		CurrencyValue, 
		CurrencyID,   
		CashAccID,  
		ResetAccID   
	FROM POSResetDrawerItem000 WHERE ParentID = @ZeroingID AND Value > 0 AND Recycled <> Value

	INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID)
	SELECT  
		Paid*CurrencyValue,  
		0.0,  
		CurrencyValue,  
		CurrencyID,  
		ResetAccID,  
		CashAccID   
	FROM POSResetDrawerItem000 
	WHERE ParentID = @ZeroingID AND Paid > 0 AND Recycled <> Value

	INSERT @CeTable(DEBIT, CREDIT, CurValue, CurID, AccountID, ContraAccountID)
	SELECT  
		CASE WHEN Value > (Paid+Recycled) THEN (Value - (Paid + Recycled)) * CurrencyValue  ELSE 0.0 END,  
		CASE WHEN Value < (Paid+Recycled) THEN ((Paid + Recycled) - Value) * CurrencyValue  ELSE 0.0 END,  
		CurrencyValue,  
		CurrencyID,  
		CASE WHEN Value > (Paid + Recycled) THEN @AdjustIDDec ELSE @AdjustIDInc END,
		ResetAccID   
	FROM POSResetDrawerItem000 
	WHERE ParentID = @ZeroingID AND Value > 0 AND Paid >= 0 AND (Paid + Recycled) <> Value  AND Recycled <> Value

	SELECT 
		@currencyID = CurID, 
		@currencyValue = CurValue  
	FROM 
		@CeTable 
	WHERE CurValue = (SELECT MIN(CurValue) FROM @CeTable) 

	IF @@ROWCOUNT <= 0 --Ignore Generating Entry When Recycled equals Total Value
		RETURN

	INSERT INTO [CE000] ([Type], [Number], [Date], [PostDate], [Debit], [Credit], [Notes], [CurrencyVal], [IsPosted],
	   [State], [Security], [Branch], [GUID], [CurrencyGUID], [TypeGUID])   
	SELECT 1, @EntryNumber, @Date, @Date, SUM(DEBIT), SUM(CREDIT), @Note, @currencyValue,   
		0,--IsPosted   
		0,--State   
		1,--Security   
		@BranchID, 
		@CeID,--GUID   
		@currencyID,--CurrencyGUID   
		0x0 
	FROM @CeTable 
	
	INSERT INTO [en000] ([Number],[Date],[Debit],[Credit] 
		  ,[Notes],[CurrencyVal] ,[SalesMan] ,[GUID] 
		  ,[ParentGUID],[AccountGUID],[CurrencyGUID],[ContraAccGUID]) 
	SELECT ID, @Date, DEBIT, CREDIT, @Note, CurValue, @UserNum, NEWID(),  
			@CeID, AccountID, CurID, ContraAccountID 
	FROM @CeTable 
	WHERE 
		([Debit] > 0 OR [Credit] > 0)
		AND 
		(ABS([Debit] - [Credit]) > dbo.fnGetZeroValuePrice())

	DECLARE @EntryTypeID UNIQUEIDENTIFIER
	SELECT TOP 1
		@EntryTypeID = CAST(value as uniqueidentifier)
	FROM UserOp000 
	WHERE Name = 'AmnPOS_ZeroEntryID' AND UserID = @UserID

	IF (@EntryTypeID = 0x0 OR @@ROWCOUNT = 0) --No Entry Type Selected
	BEGIN
		UPDATE ce000 SET IsPosted = 1 WHERE GUID = @CeID
		RETURN 
	END

	DECLARE @PaymentGUID UNIQUEIDENTIFIER
	DECLARE @Number BIGINT

	SET @PaymentGuid = NEWID() 
	SELECT @Number = ISNULL(Max(Number), 0) + 1 FROM py000 WHERE [BranchGUID] = ISNULL(@BranchID, 0x0)

	INSERT INTO py000 (Number, [Date], Notes, CurrencyVal, [Security], [GUID], TypeGUID, AccountGUID, CurrencyGUID, BranchGUID)
	VALUES (@Number, @Date, @Note, @CurrencyValue, 1, @PaymentGuid, @EntryTypeID, 0x0, @currencyID, @BranchID)
	
	INSERT INTO er000 ([GUID], EntryGUID, ParentGUID, ParentType, ParentNumber) 
	VALUES (NEWID(), @CeID, @paymentGUID, 4, @Number)
	
	UPDATE ce000 SET IsPosted = 1 WHERE GUID = @CeID
######################################################
#END