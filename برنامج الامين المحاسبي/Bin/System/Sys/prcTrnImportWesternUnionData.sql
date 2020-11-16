################################################################################
CREATE PROC prcTrnImportWesternUnionData
	@Number			NVARCHAR(100),
	@AmmountByUSD	FLOAT,
	@CurrVal		FLOAT,
	@SenderName		NVARCHAR(100),
	@FatherName		NVARCHAR(100),
	@LastName		NVARCHAR(100),
	@Address		NVARCHAR(500),
	@DocumentType	NVARCHAR(100),
	@DocumentNumber	INT,
	@TransferReason	NVARCHAR(500),
	@IsOut		BIT,
	@TrnAmmount		FLOAT,
	@ResiverName	NVARCHAR(100),
	@TrnReceiptDate DATETIME
AS
	SET NOCOUNT ON 
	-- check parameters validity
	IF NOT EXISTS (SELECT * FROM TrnTransferCompanyCard000 WHERE TrnNumber = @Number AND IsOut = @IsOut)
	BEGIN
		SELECT -1 AS ImportResult -- number not found
		RETURN
	END
	IF NOT EXISTS (SELECT * FROM TrnTransferCompanyCard000 WHERE TrnNumber = @Number AND IsOut = @IsOut AND 
	((ValueInCardCurrency = @TrnAmmount AND @IsOut = 1) OR (@IsOut = 0))
	)
	BEGIN
		SELECT -2 AS ImportResult -- amount not matched
		RETURN
	END
	IF NOT EXISTS (SELECT * FROM TrDocType000 WHERE Name = @DocumentType)
	BEGIN
		IF @DocumentType <> ''
			INSERT INTO TrDocType000 VALUES (NEWID(),@DocumentType)
	END
	Declare @DocumentID UNIQUEIDENTIFIER
	SELECT TOP 1 @DocumentID  = GUID FROM TrDocType000 WHERE Name = @DocumentType
	SELECT
		@AmmountByUSD	= CASE @AmmountByUSD	WHEN 0 THEN ValueInCardCurrency ELSE @AmmountByUSD	END,
		@CurrVal		= CASE @CurrVal			WHEN 0  THEN ActualCurrencyValue	ELSE @CurrVal	END,
		@SenderName		= CASE @SenderName		WHEN '' THEN SecondPersonName	ELSE @SenderName END,
		@ResiverName	= CASE @ResiverName		WHEN '' THEN SecondPersonName	ELSE @ResiverName END,
		@FatherName		= CASE @FatherName		WHEN '' THEN SecondPersonFather	ELSE @FatherName	END,
		@LastName		= CASE @LastName		WHEN '' THEN SecondPersonLastName ELSE @LastName		END, 
		@Address		= CASE @Address			WHEN '' THEN [Address]			ELSE @Address		END, 
		@DocumentID		= CASE @DocumentType	WHEN '' THEN DocumentTypeID		ELSE @DocumentID	END,
		@DocumentNumber	= CASE @DocumentNumber	WHEN 0  THEN DocumentNumber		ELSE @DocumentNumber END,
		@TransferReason	= CASE @TransferReason	WHEN '' THEN TrnCause			ELSE @TransferReason END,
		@TrnReceiptDate	= CASE @TrnReceiptDate	WHEN '' THEN ReciveDate			ELSE @TrnReceiptDate END
	FROM
		TrnTransferCompanyCard000
	WHERE 
		TrnNumber = @Number 
		AND IsOut = @IsOut
	
	-- update transfer record
	UPDATE 
		TrnTransferCompanyCard000
	SET 
		ValueInCardCurrency = @AmmountByUSD,
		ActualCurrencyValue = @CurrVal,
		SecondPersonName		= CASE @IsOut WHEN 0 THEN @SenderName ELSE @ResiverName END,
		SecondPersonFather	= @FatherName,
		SecondPersonLastName = @LastName,
		Address				= @Address,
		DocumentTypeID		= @DocumentID,
		DocumentNumber		= @DocumentNumber,
		TrnCause			= @TransferReason,
		ReciveDate			= @TrnReceiptDate
	WHERE 
		TrnNumber = @Number 
		AND IsOut = @IsOut 
	
	SELECT 3 AS ImportResult -- Import completed!

###################################################################################
#END


