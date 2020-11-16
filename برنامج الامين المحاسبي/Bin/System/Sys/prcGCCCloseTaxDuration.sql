##################################################################################
CREATE PROCEDURE prcGCCCloseTaxDuration
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 

	UPDATE GCCTaxDurations000 
	SET 
		[State] = 1,
		[CloseDate] = GETDATE(),
		CloseUserGUID = [dbo].[fnGetCurrentUserGUID]()
	WHERE [GUID] = @TaxDurationGUID AND [State] != 1
	
	IF @@ROWCOUNT > 0
		EXEC prcGCC_VATTaxReport_Save @TaxDurationGUID
##################################################################################
CREATE PROCEDURE prcGCCGenerateCloseTaxDurationEntry
	@TaxDurationGuid UNIQUEIDENTIFIER,
	@Notes NVARCHAR(500)
AS
	SET NOCOUNT ON

	IF @TaxDurationGuid = 0x0 
		RETURN;
	
	DECLARE @TaxAccount			UNIQUEIDENTIFIER
	DECLARE @CEGuid				UNIQUEIDENTIFIER = NEWID()
	DECLARE @MaxCENumber		INT = (ISNULL((SELECT MAX(Number) FROM ce000), 0) + 1)
	DECLARE @BasicCurrency		UNIQUEIDENTIFIER = (SELECT Guid FROM my000 where Number = 1 )
	DECLARE @NetVATAccGUID		UNIQUEIDENTIFIER = (SELECT TOP 1 NetVATAccGUID FROM GCCTaxSettings000)
	DECLARE @CEDate				DATE = (SELECT EndDate FROM GCCTaxDurations000 WHERE Guid = @TaxDurationGuid)
	
	DECLARE @ENTaxAccount TABLE( 
		[Number]			[INT] IDENTITY(0, 1), 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT], 
		[date]				[DATETIME], 
		[currencyVal]		[FLOAT], 
		[vendor]			[INT], 
		[salesMan]			[INT], 
		[parentGUID]		[UNIQUEIDENTIFIER],  
		[accountGUID]		[UNIQUEIDENTIFIER], 
		[currencyGUID]		[UNIQUEIDENTIFIER], 
		[contraAccGUID]		[UNIQUEIDENTIFIER]) 
	
	-- location vat accounts
	INSERT INTO @ENTaxAccount(accountGUID,Debit,Credit,parentGUID,vendor,salesMan,currencyVal,currencyGUID,date, contraAccGUID)
	SELECT DISTINCT
		loc.VATAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM GCCCustLocations000 loc
	-- location return vat accounts
	INSERT INTO @ENTaxAccount(accountGUID,Debit,Credit,parentGUID,vendor,salesMan,currencyVal,currencyGUID,date, contraAccGUID)
	SELECT DISTINCT
		loc.ReturnAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM GCCCustLocations000 loc
	-- reverse charges accounts
	UNION ALL
	SELECT DISTINCT
		bt.ReverseChargesAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM
	bt000 bt 
	-- reverse charges contra accounts
	UNION ALL
	SELECT DISTINCT
		bt.ReverseChargesContraAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM
	bt000 bt 
	-- excise accounts
	UNION ALL
	SELECT DISTINCT
		bt.ExciseAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM
	bt000 bt 
	-- excise contra accounts
	UNION ALL
	SELECT DISTINCT
		bt.ExciseContraAccGUID,
		0,
		0,
		@CEGuid,
		0,
		0,
		1,
		@BasicCurrency,
		@CEDate,
		0x0
	FROM
	bt000 bt 

	-- Delete duplicate accounts
	
	;WITH cte
    AS (SELECT ROW_NUMBER() OVER (PARTITION BY accountGUID ORDER BY (SELECT 0)) RN
         FROM   @ENTaxAccount)
	DELETE FROM cte
	WHERE  RN > 1;

	;WITH ACBal AS
	(
		SELECT 
			EN.AccountGUID,
			SUM(EN.Debit) AS Debit,
			SUM(EN.Credit) AS Credit
		FROM
			en000 AS EN 
			INNER JOIN ce000 AS CE ON CE.GUID = EN.ParentGUID
		WHERE
			CE.IsPosted = 1
			AND EXISTS(SELECT 1 FROM @ENTaxAccount WHERE accountGUID = EN.AccountGUID)
			AND CAST(CE.Date AS DATE) <= @CEDate
		GROUP BY
			EN.AccountGUID
	)
	UPDATE @ENTaxAccount
	SET
		Debit = B.Debit,
		Credit = B.Credit
	FROM
		@ENTaxAccount AS AC
		INNER JOIN ACBal AS B ON AC.accountGUID = B.AccountGUID
	
	DELETE @ENTaxAccount WHERE Debit = 0 AND Credit = 0
	-- Check there are balance in accounts
	IF EXISTS(SELECT * FROM @ENTaxAccount WHERE Credit - Debit <> 0)
	BEGIN
		SELECT 1
	END
	ELSE 
		RETURN ;

	IF EXISTS(SELECT * FROM @ENTaxAccount)
	BEGIN
		-- accounts
		INSERT INTO ce000 (GUID, Type, Number, Security, Date, Debit, Credit, TypeGUID, PostDate, CurrencyGUID, CurrencyVal, Notes)
		values (@CEGuid, 1, @MaxCENumber, 1, @CEDate, 0, 0, 0x0, @CEDate, @BasicCurrency, 1, @Notes)
		INSERT INTO [en000] (
						[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
						[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type]) 
					SELECT 
						(Number * 2), @CEDate, 
						CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
						CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
						' ', currencyVal, '', 0, 0, @CEGuid, accountGUID, currencyGUID, 0x0, @NetVATAccGUID, 0x0 , 210
					FROM @ENTaxAccount
		-- contra account
		INSERT INTO [en000] (
					[Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], 
					[SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type]) 
					SELECT 
						(Number * 2) + 1, @CEDate, 
						CASE WHEN Debit - Credit > 0 THEN Debit - Credit ELSE 0 END, 
						CASE WHEN Debit - Credit < 0 THEN -(Debit - Credit) ELSE 0 END,  
						'', currencyVal, '', 0, 0, @CEGuid, @NetVATAccGUID, currencyGUID, 0x0, accountGUID, 0x0, 211
					FROM @ENTaxAccount
	
		UPDATE ce000 SET Debit = EN.DEBIT, Credit = EN.CREDIT, IsPosted = 1
		FROM 
			(SELECT ParentGUID, SUM(Debit) DEBIT, SUM(Credit) CREDIT
			FROM en000 EN WHERE EN.ParentGUID = @CEGuid
			GROUP BY EN.ParentGUID) EN
		WHERE GUID = EN.ParentGUID
		-- Update entry guid in closed tax duration
		UPDATE GCCTaxDurations000 SET CloseEntryGuid = @CEGuid WHERE GUID = @TaxDurationGuid
	END
##################################################################################
#END
