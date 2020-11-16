############################################
CREATE PROC prcTrnBankTrnasferRep
	@SourceRepGuid 			UNIQUEIDENTIFIER,
	@StartDate 				DATETIME = '',
	@EndDate 				DATETIME = '2050',
	@CurrencyGuid			UNIQUEIDENTIFIER = 0x0,
	@MediatorBankGuid		UNIQUEIDENTIFIER = 0x0,
	@PayeeBankGuid			UNIQUEIDENTIFIER = 0x0,
	@SenderContians			NVARCHAR(250) = '',
	@PayeeNameContians		NVARCHAR(250) = '',
	@PayeeAccountContians	NVARCHAR(250) = '',
	@NotesContians			NVARCHAR(250) = '',
	@NotesNotContians		NVARCHAR(250) = '',
	@Grouping 				INT = 0

AS
	SET NOCOUNT ON	
	CREATE TABLE #RESULT
	(
		ExchangeType	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		ExchangeNumber	INT,
		GUID			UNIQUEIDENTIFIER,
		Number			INT,
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		SecurityNumber 	NVARCHAR(100) COLLATE ARABIC_CI_AI,
		[Date] 			DATETIME,
		CashCurrency	UNIQUEIDENTIFIER,
		CashAmount		FLOAT,
		CashVal			FLOAT,
		SenderName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MediatorBankGuid UNIQUEIDENTIFIER,
		MediatorBankName NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PayeeName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PayeeAccount	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PayeeBankGuid	UNIQUEIDENTIFIER,
		PayeeBankName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PayCurrency		UNIQUEIDENTIFIER,
		PayAmount		FLOAT,
		PayVal			FLOAT,
		Notes			NVARCHAR(250) COLLATE ARABIC_CI_AI
	)

	INSERT INTO #RESULT	
	SELECT  
		Ext.[Name],
		Ex.Number,
		trans.GUID,
		trans.Number,
		trans.Code,		
		trans.SecurityNumber,
		trans.[Date],		
		CashCurrency,	
		CashAmount,	
		CashCurrencyVal,	
		SenderName,	
		MediatorBankGuid,
		MedBank.[Name],
		trans.PayeeName,
		trans.PayeeAccount,
		trans.PayeeBankGuid,
		PayeeBank.[Name],
		PayCurrency,
		PayAmount,
		PayCurrencyVal,
		trans.Notes	
	FROM
		TrnBankTrans000 AS trans 
		INNER JOIN TrnExchange000 AS ex ON trans.ExchangeGuid = ex.GUID
		INNER JOIN TrnExchangeTypes000 AS ext ON ext.GUID = ex.TypeGuid
		INNER JOIN TrnBank000 AS MedBank ON MedBank.Guid = trans.MediatorBankGuid
		INNER JOIN TrnBank000 AS PayeeBank ON PayeeBank.Guid = trans.PayeeBankGuid
		INNER JOIN RepSrcs AS src ON src.IdType = ext.GUID 			
	WHERE
		trans.[Date] BETWEEN @StartDate AND @EndDate  
		AND (@SourceRepGuid = 0X0 OR src.IdTbl = @SourceRepGuid)
		AND (@CurrencyGuid = 0x0 OR trans.CurrencyGuid = @CurrencyGuid)	
		AND (@MediatorBankGuid = 0x0 OR trans.MediatorBankGuid = @MediatorBankGuid)	
		AND (@PayeeBankGuid = 0x0 OR trans.PayeeBankGuid = @PayeeBankGuid)	
		AND (@SenderContians = '' OR trans.SenderName LIKE '%' + @SenderContians + '%')
		AND (@PayeeNameContians = '' OR trans.PayeeName LIKE '%' + @PayeeNameContians + '%')	
		AND (@PayeeAccountContians = '' OR trans.PayeeAccount LIKE '%' + @PayeeAccountContians + '%')	
		AND (@NotesContians = '' OR trans.Notes LIKE '%' + @NotesContians + '%')	
		AND (@NotesNotContians = '' OR trans.Notes NOT LIKE '%' + @NotesNotContians + '%')

	IF (@Grouping = 0) 
	BEGIN	
			SELECT 
				*
			FROM #Result
			--INNER JOIN VwMy as MY on MY.myGuid = R.CurrencyGuid
			ORDER BY [Date], Number
	END
	ELSE	
	IF (@Grouping = 1)  
	BEGIN	
		SELECT 
			*
		FROM #Result 
		ORDER BY MediatorBankName, Date, Number
	END
	ELSE
	IF (@Grouping = 2) 
	BEGIN
		SELECT 
			*
		FROM #Result 
		ORDER BY PayeeBankName, Date, Number
	END
	ELSE
	IF (@Grouping = 3) 
	BEGIN
		SELECT 
			*
		FROM #Result 
		ORDER BY MediatorBankName, PayeeBankName,Date, Number
	END
	ELSE
	BEGIN
		SELECT 
			*
		FROM #Result 
		ORDER BY PayeeBankName, MediatorBankName, Date, Number
	END
############################################
#END