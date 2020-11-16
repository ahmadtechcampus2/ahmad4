#####################################################################
CREATE FUNCTION TrnGetCurIsoNumber(@Code NVARCHAR(3))
 RETURNS  INT
AS
BEGIN
 DECLARE @Number INT
 
 SET @Number = 999
 
 IF (@Code = 'AED')
  SET @Number = 784
 ELSE
 IF (@Code = 'AUD')
  SET @Number = 036
 ELSE
 IF (@Code = 'BHD')
  SET @Number = 048 
 ELSE
 IF (@Code = 'CAD')
  SET @Number = 124 
 ELSE
 IF (@Code = 'CHF')
  SET @Number = 756 
 ELSE
 IF (@Code = 'CNY')
  SET @Number = 156 
 ELSE
 IF (@Code = 'DKK')
  SET @Number = 208
 ELSE
 IF (@Code = 'DZD')
  SET @Number = 012
 ELSE
 IF (@Code = 'EGP')
  SET @Number = 818 
 ELSE
 IF (@Code = 'EUR')
  SET @Number = 978 
 ELSE
 IF (@Code = 'GBP')
  SET @Number = 826
 ELSE
 IF (@Code = 'INR')
  SET @Number = 356 
 ELSE
 IF (@Code = 'IQD')
  SET @Number = 368 
 ELSE
 IF (@Code = 'IRR')
  SET @Number = 364 
 ELSE
 IF (@Code = 'JOD')
  SET @Number = 400 
 ELSE
 IF (@Code = 'JPY')
  SET @Number = 392 
 ELSE
 IF (@Code = 'KPW')
  SET @Number = 408 
 ELSE
 IF (@Code = 'KWD')
  SET @Number = 414 
 ELSE
 IF (@Code = 'LBP')
  SET @Number = 422 
 ELSE
 IF (@Code = 'LYD')
  SET @Number = 434
 ELSE
 IF (@Code = 'MAD')
  SET @Number = 504
 ELSE
 IF (@Code = 'NOK')
  SET @Number = 578 
 ELSE
 IF (@Code = 'OMR')
  SET @Number = 512 
 ELSE
 IF (@Code = 'PKR')
  SET @Number = 586 
 ELSE
 IF (@Code = 'PGK')
  SET @Number = 598
 ELSE
 IF (@Code = 'PHP')
  SET @Number = 608
 ELSE
 IF (@Code = 'QAR')
  SET @Number = 634 
 ELSE
 IF (@Code = 'RUB')
  SET @Number = 643
 ELSE
 IF (@Code = 'SAR')
  SET @Number = 682 
 ELSE
 IF (@Code = 'SDG')
  SET @Number = 938 
 ELSE
 IF (@Code = 'SEK')
  SET @Number = 752 
 ELSE
 IF (@Code = 'SYP')
  SET @Number = 760 
 ELSE
 IF (@Code = 'THP')
  SET @Number = 764
 ELSE
 IF (@Code = 'TND')
  SET @Number = 788
 ELSE
 IF (@Code = 'TRY')
  SET @Number = 949  
 ELSE
 IF (@Code = 'UAH')
  SET @Number = 980 
 ELSE
 IF (@Code = 'USD')
  SET @Number = 840 
 ELSE
 IF (@Code = 'UZS')
  SET @Number = 860 
 ELSE
 IF (@Code = 'VEF')
  SET @Number = 937 
 ELSE
 IF (@Code = 'YER')
  SET @Number = 886 
RETURN @Number
END
#####################################################################
CREATE FUNCTION FnTrnGetAccountCurrenciesBalances
      ( 
			@AccountGuid      [UNIQUEIDENTIFIER], 
			@BeginingDate     [DATETIME], 
			@EndingDate       [DATETIME] 
      ) 
RETURNS @Result TABLE (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBalance FLOAT, BeginCurrencyBalance FLOAT, EndBalance FLOAT, EndCurrencyBalance FLOAT) 
AS 
BEGIN 
		DECLARE  @BeginDateRes TABLE(CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBalance FLOAT, BeginCurrencyBalance FLOAT, EndBalance FLOAT, EndCurrencyBalance FLOAT) 
        DECLARE  @EndDateRes   TABLE(CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBalance FLOAT, BeginCurrencyBalance FLOAT, EndBalance FLOAT, EndCurrencyBalance FLOAT) 
        
        --1 Balances Until @BeginingDate 
        INSERT INTO @BeginDateRes      
        SELECT my.Code,  
				SUM(ISNULL(En.enDebit - En.enCredit, 0)) / 1000,  
				SUM(ISNULL((En.enDebit - En.enCredit) / ISNULL(En.enCurrencyVal,1) / 1000, 0)) ,  
                 0, 
                 0 
        From [dbo].[fnGetAccountsList](@AccountGuid, 0) AcList 
        INNER JOIN [vwAc] Ac ON AcList.GUID = Ac.acGUID 
        LEFT JOIN [vwCeEn] En ON Ac.acGUID = En.enAccount -- Ac.acCurrencyPtr = En.enCurrencyPtr 
        INNER JOIN [my000] my ON my.[GUID] = Ac.[acCurrencyPtr] 
        WHERE En.ceDate <= @BeginingDate 
        GROUP BY my.Code 
        
        --2 Balances Until @EndingDate 
        INSERT INTO @EndDateRes      
        SELECT my.Code,  
				 0, 
				 0, 
				SUM(ISNULL(En.enDebit - En.enCredit, 0)) / 1000,  
				SUM(ISNULL( (En.enDebit - En.enCredit) / ISNULL(En.enCurrencyVal,1) / 1000, 0)) 
        FROM [dbo].[fnGetAccountsList](@AccountGuid,1) AcList 
        INNER JOIN [vwAc] Ac ON AcList.GUID = Ac.acGUID 
        LEFT  JOIN [vwCeEn] En   ON Ac.acGUID = En.enAccount  -- AND Ac.acCurrencyPtr = En.enCurrencyPtr 
        INNER JOIN [my000] my ON my.[GUID] = Ac.[acCurrencyPtr] 
        WHERE En.ceDate <= @EndingDate 
        GROUP BY my.Code  
         
        ---------------------------------------------------------------------------------------------------------------- 
        ---------------------------------------F I N A L  R E S U L T--------------------------------------------------- 
        ---------------------------------------------------------------------------------------------------------------- 
        INSERT INTO @Result 
        SELECT 
			   My.code,
			   ISNULL(BeginBal.BeginBalance,0),
			   ISNULL(BeginBal.BeginCurrencyBalance, 0),  
			   ISNULL(EndBal.EndBalance,0),
			   ISNULL(EndBal.EndCurrencyBalance,0) 
		FROM MY000 AS My
		LEFT JOIN @BeginDateRes AS BeginBal  ON BeginBal.CurrencyCode = My.Code 
		LEFT JOIN @EndDateRes AS EndBal ON EndBal.CurrencyCode = My.Code
  RETURN 
END 
#####################################################################
CREATE FUNCTION fnTrnSyBkGetIncome(@incomeFinal UNIQUEIDENTIFIER, @StartDate DATETIME, @ENDDATE DATETIME)
	RETURNS TABLE---(Debit FLOAT, Credit FLOAT)
AS	
	RETURN
	(
		SELECT 
			ISNULL(SUM(en.Debit), 0) AS Debit,
			ISNULL(SUM(en.Credit), 0) AS Credit
		FROM en000 AS en
		INNER JOIN Ce000 AS Ce ON Ce.[Guid] = en.ParentGUID
		INNER JOIN Ac000 AS Ac ON ac.[Guid] = en.AccountGUID
		INNER JOIN fnGetAccountsList(@incomeFinal, 1) AS fnFinal ON fnFinal.[Guid] = ac.FinalGuid
		WHERE en.[Date] BETWEEN @StartDate AND @ENDDATE
	)
#####################################################################
CREATE FUNCTION fnSyBankGetIncome
	(
		@incomeFinal UNIQUEIDENTIFIER, 
		@FromOpeningEntry	BIT			= 0,
		@StartDate		    DATETIME	= '1-1-1900', 
		@ENDDATE			DATETIME	= '1-1-2100'
	)
	RETURNS @Result TABLE (Debit FLOAT, Credit FLOAT)
AS	
BEGIN
		--Test If Balance From Opening Entry
		IF (@FromOpeningEntry = 0)
		BEGIN
			INSERT INTO @Result
			SELECT 
				ISNULL(SUM(en.Debit), 0) ,
				ISNULL(SUM(en.Credit), 0)
			FROM en000 AS en
			INNER JOIN Ce000 AS Ce ON Ce.[Guid] = en.ParentGUID
			INNER JOIN Ac000 AS Ac ON ac.[Guid] = en.AccountGUID
			INNER JOIN fnGetAccountsList(@incomeFinal, 1) AS fnFinal ON fnFinal.[Guid] = ac.FinalGuid
			WHERE en.[Date] BETWEEN @StartDate AND @ENDDATE
		END
		
		ELSE--Balance From Opening Entry
		BEGIN
			INSERT INTO @Result
			SELECT 
				SUM(ISNULL(OpeningEn.Debit, 0)) ,
				SUM(ISNULL(OpeningEn.Credit, 0))
			FROM  Ac000 AS Ac 
			INNER JOIN fnGetAccountsList(@incomeFinal, 1) AS fnFinal ON fnFinal.[Guid] = ac.FinalGuid
			LEFT JOIN dbo.fnTrnOpeningEntry() AS OpeningEn ON Ac.[GUID] = OpeningEn.AccountGUID	
		END
	
	RETURN
END
#####################################################################
CREATE FUNCTION fnTrnOpeningEntry()
	RETURNS TABLE
RETURN 
	(
		SELECT 
			en.Debit,
			en.Credit,
			en.[Date],
			ce.Number AS EntryNumber,
			En.Number AS ItemNmber, 
			en.AccountGuid AS AccountGUID,
			ce.TypeGuid
		FROM
			en000 AS en
			INNER JOIN ce000 AS ce ON ce.Guid = en.ParentGUID
			LEFT JOIN et000 AS et ON et.GUID = ce.TypeGUID
		WHERE et.Guid = 'EA69BA80-662D-4FA4-90EE-4D2E1988A8EA' OR 
			(ISNULL(et.Guid, 0x0) = 0x0 AND ce.Number = 1 )
	)
#####################################################################
CREATE FUNCTION fnTrnOpeningEntryAccountBalance(@AccountGuid UNIQUEIDENTIFIER)
	RETURNS FLOAT
AS 
BEGIN 
	IF (ISNULL(@AccountGUID , 0x0) = 0x0)
	BEGIN
		RETURN 0
	END

	DECLARE @Balance FLOAT
	
	SELECT @Balance = SUM(fn.Debit - fn.Credit)
	FROM
		fnGetAccountsList(@AccountGUID, 1) AS ac
		INNER JOIN fnTrnOpeningEntry() AS fn ON fn.AccountGUID = ac.GUID
	SET @Balance = ISNULL(@Balance, 0)
RETURN 	@Balance
END
#####################################################################
CREATE FUNCTION fnTrnAccountBalance(@AccountGuid UNIQUEIDENTIFIER, @FromDate DATETIME, @ToDate DATETIME)
	RETURNS FLOAT 
AS 
BEGIN 
	IF (ISNULL(@AccountGUID , 0x0) = 0x0)
	BEGIN
		RETURN 0
	END

	DECLARE @Balance FLOAT
	
	SELECT @Balance = SUM(en.Debit - en.Credit)
	FROM
		en000 AS en
		INNER JOIN ce000 AS ce ON ce.Guid = en.ParentGUID
		INNER JOIN fnGetAccountsList(@AccountGUID, 1) AS ac ON ac.Guid = en.AccountGUID
	WHERE en.[Date] BETWEEN @FromDate AND @ToDate
	SET @Balance = ISNULL(@Balance, 0)
RETURN 	@Balance
END
#####################################################################
CREATE FUNCTION fnTrnCurrencyAccountBalance(@AccountGuid UNIQUEIDENTIFIER, @FromDate DATETIME, @ToDate DATETIME)
	RETURNS FLOAT 
AS 
BEGIN 
	IF (ISNULL(@AccountGUID , 0x0) = 0x0)
	BEGIN
		RETURN 0
	END

	DECLARE @Balance FLOAT
	
	SELECT 
		@Balance = SUM(dbo.fnCurrency_Fix(en.Debit, en.CurrencyGuid, en.CurrencyVal, ac.CurrencyGuid, en.Date)
		- dbo.fnCurrency_Fix(en.Credit, en.CurrencyGuid, en.CurrencyVal, ac.CurrencyGuid, en.Date))
	FROM
		en000 AS en
		INNER JOIN ce000 AS ce ON ce.Guid = en.ParentGUID
		INNER JOIN fnGetAccountsList(@AccountGUID, 1) AS fnac ON fnac.Guid = en.AccountGUID
		INNER JOIN ac000 AS ac ON ac.GUID = fnac.GUID 
	WHERE en.[Date] BETWEEN @FromDate AND @ToDate
	SET @Balance = ISNULL(@Balance, 0)
RETURN 	@Balance
END
#####################################################################
CREATE  PROC repSyrianBank13
	@FromDate DATETIME,
	@ToDate	DATETIME 
AS 
	SET NOCOUNT ON 
	  
	SELECT	 
		ex.[GUID], 
		ex.[TypeGuid], 
		--ex.[NUMBER], 
		ex.InternalNumber AS Number, 
		Type.Abbrev As TypeCode, 
		ex.date, 
		CashCurr.[myCode] AS CashCurrencyName, 
		CASE ex.[RoundDir] WHEN 1 THEN ex.[CashAmount] / ex.[CashCurrencyVal] 
			ELSE (ex.[CashAmount] + (ex.[RoundValue] * ex.[CashCurrencyVal])) / ex.[CashCurrencyVal]   
		END 
			AS CashAmount, 
		ex.[CashCurrencyVal], 
		PayCurr.[myCode] AS PayCurrencyName, 
		CASE ex.[RoundDir] WHEN 0 THEN ex.[PayAmount] / ex.[PayCurrencyVal] 
			ELSE (ex.[PayAmount] + (ex.[RoundValue] * ex.[PayCurrencyVal])) / ex.[PayCurrencyVal]   
		END 
			AS PayAmount, 
		ex.[PayCurrencyVal], 
		CustomerName, 
		ex.Reason,
		ISNULL(br.Name,'') BranchName,
		cu.lastName,
		cu.fatherName,
		ex.commissionAmount,
		cu.IdentityNo
	From  
		TrnExchange000 AS ex 
		INNER JOIN VwMy AS CashCurr ON CashCurr.myGuid = ex.CashCurrency 
		INNER JOIN VwMy AS PayCurr  ON PayCurr.myGuid  = ex.PayCurrency 
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid 
		LEFT JOIN  br000 br ON br.guid = ex.BranchGuid
		LEFT JOIN TrnCustomer000 cu ON cu.guid = ex.CustomerGuid 
		 
	WHERE 
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	 
		AND	ex.[PayCurrencyVal] <> 1 
		AND	ex.bSimple = 1 
		 
UNION 
  
      SELECT	 
		ex.[GUID], 
		ex.[TypeGuid], 
		--ex.[NUMBER], 
		detail.InternalNumber AS Number, 
		Type.Abbrev As TypeCode, 
		ex.date, 
		BasicCurr.[myCode] AS CashCurrencyName, 
		detail.Amount AS CashAmount,  
		1 As CashCurrencyVal, 
		Curr.[myCode] AS PayCurrencyName, 
		CASE WHEN detail.CurrencyVal <> 0 THEN detail.Amount / detail.CurrencyVal 
                     ELSE detail.Amount 
 		END	 
		AS PayAmount, 
		detail.CurrencyVal As PayCurrencyVal, 
		 
		CustomerName, 
		ex.Reason, 
		ISNULL(br.Name,'') BranchName,
		cu.lastName,
		cu.fatherName,
		ex.commissionAmount,
		cu.IdentityNo
	From  
		TrnExchange000 AS ex 
		INNER JOIN Trnexchangedetail000 As detail on ex.guid = detail.ExchangeGuid AND detail.Type = 1 
		INNER JOIN VwMy AS Curr ON Curr.myGuid = detail.CurrencyGuid  
		INNER JOIN VwMy AS BasicCurr ON BasicCurr.myCurrencyVal = 1 
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid 
		LEFT JOIN  br000 br ON br.guid = ex.BranchGuid
		LEFT JOIN TrnCustomer000 cu ON cu.guid = ex.CustomerGuid 
		 
	WHERE 
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	 
		AND detail.CurrencyVal <> 1 
		ORDER BY [Date], [NUMBER] 
 
GO
#####################################################################
CREATE  PROC repSyrianBank14
	@FromDate DATETIME,  
	@ToDate	DATETIME  
AS  
	SET NOCOUNT ON  
	   
	SELECT	  
		ex.[GUID],  
		ex.[TypeGuid],  
		ex.InternalNumber AS Number, 
		--ex.[NUMBER],  
		Type.Abbrev As TypeCode, 
		ex.date,  
		CashCurr.[myCode] AS CashCurrencyName,  
		CASE ex.[RoundDir] WHEN 1 THEN ex.[CashAmount] / ex.[CashCurrencyVal]  
			ELSE (ex.[CashAmount] + (ex.[RoundValue] * ex.[CashCurrencyVal])) / ex.[CashCurrencyVal]    
		END  
			AS CashAmount,  
		ex.[CashCurrencyVal],  
		PayCurr.[myCode] AS PayCurrencyName,  
		CASE ex.[RoundDir] WHEN 0 THEN ex.[PayAmount] / ex.[PayCurrencyVal]  
			ELSE (ex.[PayAmount] + (ex.[RoundValue] * ex.[PayCurrencyVal])) / ex.[PayCurrencyVal]    
		END  
			AS PayAmount,  
		ex.[PayCurrencyVal],  
		CustomerName,
		ISNULL(br.Name,'') BranchName,
		cu.lastName,
		cu.fatherName,
		cu.IdentityNo
	From   
		TrnExchange000 AS ex  
		INNER JOIN VwMy AS CashCurr ON CashCurr.myGuid = ex.CashCurrency  
		INNER JOIN VwMy AS PayCurr ON PayCurr.myGuid = ex.PayCurrency  
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid 
		LEFT JOIN  br000 br ON br.guid = ex.BranchGuid 
		Left JOIN TrnCustomer000 cu ON cu.guid = ex.CustomerGuid 
	WHERE  
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	  
		AND ex.[CashCurrencyVal] <> 1  
		AND	ex.bSimple = 1 
union 
  
      SELECT	 
		ex.[GUID], 
		ex.[TypeGuid], 
		detail.InternalNumber AS Number, 
		--ex.[NUMBER], 
		Type.Abbrev As TypeCode, 
		ex.date, 
		Curr.[myCode] AS CashCurrencyName, 
		CASE WHEN detail.CurrencyVal <> 0 THEN detail.Amount / detail.CurrencyVal 
                     ELSE detail.Amount 
 		END  
		AS CashAmount,  
		detail.CurrencyVal As CashCurrencyVal, 
		BasicCurr.[myCode] AS PayCurrencyName, 
		detail.Amount AS PayAmount, 
		1 As PayCurrencyVal, 
		CustomerName, 
		ISNULL(br.Name,'') BranchName ,
		cu.lastName,
		cu.fatherName,
		cu.IdentityNo
	From  
		TrnExchange000 AS ex 
		INNER JOIN Trnexchangedetail000 As detail on ex.guid = detail.ExchangeGuid AND detail.Type = 0 
		INNER JOIN VwMy AS Curr ON Curr.myGuid = detail.CurrencyGuid  
		INNER JOIN VwMy AS BasicCurr ON BasicCurr.myCurrencyVal = 1 
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid 
		LEFT JOIN  br000 br ON br.guid = ex.BranchGuid
		left JOIN TrnCustomer000 cu ON cu.guid = ex.CustomerGuid 
		 
	WHERE 
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	 
		AND detail.CurrencyVal <> 1 
		ORDER BY [Date], [NUMBER] 
GO
############################################################################
CREATE PROC repSyrianBank84 
	@FromDate DATETIME,  
	@ToDate	DATETIME  
AS  
	SET NOCOUNT ON  
	 
	DECLARE @Result TABLE( 
						[Guid]			UNIQUEIDENTIFIER,  
						TypeGuid		UNIQUEIDENTIFIER, 
						BranchGUID      UNIQUEIDENTIFIER, 
						Number			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
						[Date]			DATETIME,  
						CurrencyName	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
						CurrencyCode	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
						CurrencyAmount	FLOAT, 
						CurrencyVal		FLOAT, 
						CustomerName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
						CustomerFatherName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
					    FamilyName      NVARCHAR(250) COLLATE ARABIC_CI_AI DEFAULT '', 
						CustomerIDNO	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Type]			BIT, -- 0 Exchange, 1 Transfer 
						CustomerCardType		NVARCHAR(250) COLLATE ARABIC_CI_AI DEFAULT 'ÂÊÌ…', 
						Dollar4Price	FLOAT 
					) 
					 
	DECLARE @DollarCurrencyGuid UNIQUEIDENTIFIER 
	SELECT @DollarCurrencyGuid = [GUID] FROM My000 WHERE Code = 'USD'					 
INSERT INTO @Result	([Guid], TypeGuid, BranchGUID, Number, [Date], CurrencyName, CurrencyCode, CurrencyAmount, 
					CurrencyVal, CustomerName, CustomerFatherName, FamilyName, CustomerIDNO, [Type], CustomerCardType, Dollar4Price) 
	SELECT	  
		ex.[GUID],  
		ex.[TypeGuid],  
		ex.BranchGUID, 
		ex.InternalNumber, 
		ex.[date],  
		my.[myName],  
		my.[myCode],  
		CASE ex.[RoundDir] WHEN 0 THEN ex.[PayAmount] / ex.[PayCurrencyVal]  
			ELSE (ex.[PayAmount] + (ex.[RoundValue] * ex.[PayCurrencyVal])) / ex.[PayCurrencyVal]    
		END,  
		ex.[PayCurrencyVal],  
		cu.Name,
		cu.FatherName, 
		cu.LastName,
		cu.IdentityNo, 
		0, 
		cu.IdentityType, 
        CASE WHEN my.mycode = 'USD' THEN 1 
             ELSE dbo.fnTrnGetAvgCurrency_4Price(@DollarCurrencyGuid, ex.[date]) / ex.[PayCurrencyVal] 
        END 
	From   
		TrnExchange000 AS ex  
		INNER JOIN VwMy AS my ON my.myGuid = ex.PayCurrency  
		LEFT JOIN trncustomer000 as cu on cu.guid = ex.CustomerGuid   
	WHERE  
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	  
		AND ex.[PayCurrencyVal] <> 1  
		AND	ex.bSimple = 1 
	UNION 
	 
      SELECT	 
		ex.[GUID], 
		ex.[TypeGuid], 
		ex.BranchGUID, 
		detail.InternalNumber, 
		ex.[date], 
		my.[myName], 
		my.[myCode], 
		CASE WHEN detail.CurrencyVal <> 0  
			THEN detail.Amount / detail.CurrencyVal 
            ELSE detail.Amount 
 		END,  
		detail.CurrencyVal As CashCurrencyVal, 
		cu.Name, 
		cu.FatherName,
		cu.LastName,
		cu.IdentityNo, 
		0, 
		cu.IdentityType, 
		CASE WHEN my.mycode = 'USD' THEN 1 
             ELSE dbo.fnTrnGetAvgCurrency_4Price(@DollarCurrencyGuid, ex.[date]) --/ ex.[PayCurrencyVal] 
        END 
	FROM  
		TrnExchange000 AS ex 
		INNER JOIN Trnexchangedetail000 As detail on ex.guid = detail.ExchangeGuid AND detail.Type = 1 
		INNER JOIN VwMy AS my ON my.myGuid = detail.CurrencyGuid  
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid 
		LEFT JOIN TrnCustomer000 as cu ON cu.Guid = ex.CustomerGuid  
	WHERE 
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	 
		AND detail.CurrencyVal <> 1 
				 
	INSERT INTO @Result	([Guid], BranchGUID, Number, [Date], CurrencyName, CurrencyCode, CurrencyAmount, 
					CurrencyVal, CustomerName, CustomerFatherName, CustomerIDNO, [Type], CustomerCardType, Dollar4Price, FamilyName ) 
	SELECT	  
		Trn.[GUID],  
		rec.BranchGUID, 
		Trn.Code, 
		payinfo.[date],  
		my.[Name],  
		my.[Code],  
		trn.MustPaidAmount / payinfo.[CurrencyVal], 
		payinfo.[CurrencyVal],  
		rec.[Name],
		'rec.FatherName',
		payinfo.IDentityCard, 
		1, 
		payinfo.IDentityCardType, 
	    CASE WHEN my.code = 'USD' THEN 1 
             ELSE dbo.fnTrnGetAvgCurrency_4Price(@DollarCurrencyGuid, payinfo.[date])-- / payinfo.[CurrencyVal] 
        END, 
        'FamilyName'
	From   
	    TrnTransferVoucher000 AS Trn 
		INNER JOIN TrnVoucherPayInfo000 AS payinfo ON payinfo.VoucherGuid = Trn.[Guid]  
		INNER JOIN TrnStatement000 AS st ON st.Guid = Trn.[StatementGuid]  
		INNER JOIN TrnSenderReceiver000 AS rec ON rec.Guid = payinfo.ActualReceiverGuid 
		INNER JOIN my000 AS my ON my.Guid = payinfo.CurrencyGuid 
	WHERE  
		payinfo.[DATE] BETWEEN @FromDate AND @ToDate 	  
		AND trn.SourceType = 2 AND trn.DestinationType = 1 
	 
	SELECT Res.*, br.brName  
	FROM @Result AS Res 
	     INNER JOIN vwBr AS br ON br.brGuid = Res.BranchGUID  
	ORDER BY [DATE], Number 
GO
#####################################################################
CREATE PROC repSyrianBank16
	@FROMDate			DATETIME,
	@ToDate				DATETIME,	
	@ExchangeForeign	INT, -- 0 according base currency , 1 according foreign currency
	@GroupBy			INT -- 0 no group, 1 group by month, 2 group by day

AS
	SET NOCOUNT ON
	DECLARE @BaseCurrency UNIQUEIDENTIFIER
	SELECT @BaseCurrency = GUID FROM my000 WHERE number = 1
	
	/*
	«· ⁄ﬁÌœ ›ﬁÿ »„« ÌŒ’ „Ê÷Ê⁄ «·‰ﬁœÌ ÕÌÀ √‰ «·‰ﬁœÌ Ì„ﬂ‰ √‰ ÌﬂÊ‰ Ã„ÂÊ— √Ê „’«—› √Ê ’Ì«—›…
	√„ «·‘Ìﬂ«  Ê«·ÕÊ«·« ° Õ Ï Ì’·‰« «· Õ·Ì· «·‰Â«∆Ì «·‘Ìﬂ«  «·ÊÕÊ«·«  ›ﬁÿ Ã„ÂÊ—
	*/
	DECLARE @Result TABLE(CurrencyGUID UNIQUEIDENTIFIER, [DayDate] DATETIME,
				Buy_CASH_Amount_Public FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ—
				Buy_CASH_Amount_Bank FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ „’«—›
				Buy_CASH_Amount_Exchanger FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
				Buy_Check_Amount FLOAT DEFAULT 0, Buy_Check_CurrAmount FLOAT DEFAULT 0, -- ° ‘—«¡ ‘Ìﬂ« 
				Buy_Transfer_Amount FLOAT DEFAULT 0, Buy_Transfer_CurrAmount FLOAT DEFAULT 0, -- ‘—«¡ ÕÊ«·« 
				Sell_CASH_Amount_Public FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
				Sell_CASH_Amount_Bank FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ „’«—›
				Sell_CASH_Amount_Exchanger FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
				Sell_Check_Amount FLOAT DEFAULT 0, Sell_Check_CurrAmount FLOAT DEFAULT 0, -- ° »Ì⁄ ‘Ìﬂ« 
				Sell_Transfer_Amount FLOAT DEFAULT 0, Sell_Transfer_CurrAmount FLOAT DEFAULT 0 -- »Ì⁄ ÕÊ«·« 
				
	)
	
	INSERT INTO @result  
	SELECT 
				CurrencyGUID , DayDate ,
				Buy_CASH_Amount_Public , Buy_CASH_CurrAmount_Public ,  -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ—
				Buy_CASH_Amount_Bank, Buy_CASH_CurrAmount_Bank ,  -- ‘—«¡ ‰ﬁœÌ „’«—›
				Buy_CASH_Amount_Exchanger , Buy_CASH_CurrAmount_Exchanger ,  -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
				Buy_Check_Amount , Buy_Check_CurrAmount , -- ° ‘—«¡ ‘Ìﬂ« 
				Buy_Transfer_Amount , Buy_Transfer_CurrAmount , -- ‘—«¡ ÕÊ«·« 
				Sell_CASH_Amount_Public , Sell_CASH_CurrAmount_Public ,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
				Sell_CASH_Amount_Bank , Sell_CASH_CurrAmount_Bank ,  -- »Ì⁄ ‰ﬁœÌ „’«—›
				Sell_CASH_Amount_Exchanger , Sell_CASH_CurrAmount_Exchanger ,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
				Sell_Check_Amount , Sell_Check_CurrAmount, -- ° »Ì⁄ ‘Ìﬂ« 
				Sell_Transfer_Amount , Sell_Transfer_CurrAmount  -- »Ì⁄ ÕÊ«·« 
	 FROM FnRepSyrianBank11(@FROMDate,@ToDate,@ExchangeForeign, 2)
	 WHERE @BaseCurrency <> CurrencyGUID
	 
	SELECT 
			m.Number AS CurrencyNumber,
			M.CODE AS CurrencyCode,
			DayDate, 
			Buy_CASH_CurrAmount_Public AS Buy_Cash_Public, -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ— 
			Buy_CASH_Amount_Public As Buy_Cash_Curr_Public,
			Buy_CASH_CurrAmount_Bank AS Buy_Cash_Bank, -- ‘—«¡ ‰ﬁœÌ „’«—›
			Buy_CASH_Amount_Bank AS Buy_Cash_Curr_Bank,
			Buy_CASH_CurrAmount_Exchanger AS Buy_Cash_Exchanger, -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
			Buy_CASH_Amount_Exchanger AS Buy_Cash_Curr_Exchanger,
			Buy_Check_CurrAmount AS Buy_Check, --  ‘—«¡ ‘Ìﬂ« 
			Buy_Check_Amount AS Buy_Curr_Check,
			Buy_Transfer_CurrAmount AS Buy_Transfer, -- ‘—«¡ ÕÊ«·« 
			Buy_Transfer_Amount AS Buy_Curr_Transfer,
			Sell_CASH_CurrAmount_Public AS Sell_Cash_Public,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
			Sell_CASH_Amount_Public AS Sell_Cash_Curr_Public,
			Sell_CASH_CurrAmount_Bank AS Sell_Cash_Bank,  -- »Ì⁄ ‰ﬁœÌ „’«—›
			Sell_CASH_Amount_Bank AS Sell_Cash_Curr_Bank, 
			Sell_CASH_CurrAmount_Exchanger AS Sell_Cash_Exchanger,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
			Sell_CASH_Amount_Exchanger AS Sell_Cash_Curr_Exchanger,
			Sell_Check_CurrAmount AS Sell_Check, -- ° »Ì⁄ ‘Ìﬂ« 
			Sell_Check_Amount AS Sell_Curr_Check,
			Sell_Transfer_CurrAmount AS Sell_Transfer, -- »Ì⁄ ÕÊ«·« 
			Sell_Transfer_Amount AS Sell_Curr_Transfer,
			0 AS IsTotal
	FROM @Result AS R
	INNER JOIN MY000 AS M ON M.GUID = CurrencyGUID
	
	UNION ALL
	SELECT	
			0 AS CurrencyNumber,
			'' AS CurrencyCode,
			[DayDate], 
			SUM(Buy_CASH_CurrAmount_Public),
			SUM(Buy_CASH_Amount_Public),  
			SUM(Buy_CASH_CurrAmount_Bank), 
			SUM(Buy_CASH_Amount_Bank), 
			SUM(Buy_CASH_CurrAmount_Exchanger),
			SUM(Buy_CASH_Amount_Exchanger), -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
			SUM(Buy_Check_CurrAmount),
			SUM(Buy_Check_Amount),  -- ‘—«¡ ‘Ìﬂ« 
			SUM(Buy_Transfer_CurrAmount),  -- ‘—«¡ ÕÊ«·« 
			SUM(Buy_Transfer_Amount),
			SUM(Sell_CASH_CurrAmount_Bank),  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
			SUM(Sell_CASH_Amount_Public),
			SUM(Sell_CASH_CurrAmount_Bank),  -- »Ì⁄ ‰ﬁœÌ „’«—›
			SUM(Sell_CASH_Amount_Bank),
			SUM(Sell_CASH_CurrAmount_Exchanger),   -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
			SUM(Sell_CASH_Amount_Exchanger),
			SUM(Sell_Check_CurrAmount),  -- »Ì⁄ ‘Ìﬂ« 
			SUM(Sell_Check_Amount),
			SUM(Sell_Transfer_CurrAmount),  -- »Ì⁄ ÕÊ«·« 
			SUM(Sell_Transfer_Amount),
			1 AS IsTotal
	FROM @Result 
	GROUP BY [DayDate]
	
	ORDER BY [DayDate], IsTotal, CurrencyNumber
#####################################################################
CREATE PROC repSyrianBank22
	@FromDate DATETIME,
	@ToDate	DATETIME
AS
	SET NOCOUNT ON
	/*
		Algorithim:
		1-Fill #Result From Simple Exchange
		2-Fill #Result From Detailed Exchange
		3-Break MultipleOperation-Records(Cash And Pay) into two detailed records:
			3-a Fill #CashAndPayOP
			3-b Fill #DetailedCashPay
			3-c Update #Result To be with Detailed Records Only
	*/
	
	CREATE TABLE #RESULT 
	(
		GUID				[UNIQUEIDENTIFIER],
		TypeGUID			[UNIQUEIDENTIFIER],
		Number				INT,
		TypeCode			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Date				DATETIME,
		CashCurrencyName	NVARCHAR(100) COLLATE ARABIC_CI_AI,
		CashAmount			FLOAT,
		CashCurrencyVal		FLOAT,
		PayCurrencyName		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		PayAmount			FLOAT,
		PayCurrencyVal		FLOAT,
		CustomerName		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		CustomerIdentityNo	NVARCHAR(100) COLLATE ARABIC_CI_AI
	)
	INSERT INTO #RESULT
	--1-Fill #Result From Simple Exchange
	SELECT	
		ex.[GUID],
		ex.[TypeGuid],
		ex.[InternalNumber],
		Type.Abbrev As TypeCode,
		ex.date,
		CashCurr.[myCode] AS CashCurrencyName,

		CASE ex.[RoundDir] WHEN 1 THEN ex.[CashAmount] / ex.[CashCurrencyVal]
			ELSE (ex.[CashAmount] + (ex.[RoundValue] * ex.[CashCurrencyVal])) / ex.[CashCurrencyVal]  
		END
			AS CashAmount,
		ex.[CashCurrencyVal],
		PayCurr.[myCode] AS PayCurrencyName,

		CASE ex.[RoundDir] WHEN 0 THEN ex.[PayAmount] / ex.[PayCurrencyVal]
			ELSE (ex.[PayAmount] + (ex.[RoundValue] * ex.[PayCurrencyVal])) / ex.[PayCurrencyVal]  
		END
			AS PayAmount,
		ex.[PayCurrencyVal],
		CustomerName,
		CutomerIdentityNo
		
	From 
		vtTrnExchange AS ex
		LEFT JOIN TrnCustomer000 AS cu on cu.Guid = ex.CustomerGuid
		INNER JOIN VwMy AS CashCurr ON CashCurr.myGuid = ex.CashCurrency
		INNER JOIN VwMy AS PayCurr ON PayCurr.myGuid = ex.PayCurrency
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid
		
	WHERE
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	
		AND ex.[CashAmount] >= 14000
		AND ex.bSimple = 1
		
	UNION
	--2-Fill #Result From Detailed Exchange
	SELECT	
		ex.[GUID],
		ex.[TypeGuid],
		ex.[InternalNumber],
		Type.Abbrev As TypeCode,
		ex.date,
		--Cash
		CASE WHEN Detail.Type = 0 THEN Curr.[myCode] ELSE BasicCurr.myCode END AS CashCurrencyName,
		CASE WHEN Detail.Type = 0 THEN Detail.Amount / Detail.CurrencyVal ELSE Detail.Amount END AS CashAmount,
		CASE WHEN Detail.Type = 0 THEN Detail.CurrencyVal ELSE 1 END AS CashCurrencyVal,
		
		--Pay
		CASE WHEN Detail.Type = 1 THEN Curr.[myCode] ELSE BasicCurr.myCode END AS PayCurrencyName,
		CASE WHEN Detail.Type = 1 THEN Detail.Amount / Detail.CurrencyVal ELSE Detail.Amount END AS PayAmount,
		CASE WHEN Detail.Type = 1 THEN Detail.CurrencyVal ELSE 1 END AS PayCurrencyVal,

		ex.CustomerName,
		ex.CutomerIdentityNo
		
	From 
		vtTrnExchange AS ex
		LEFT JOIN TrnCustomer000 AS cu on cu.Guid = ex.CustomerGuid
		INNER JOIN TrnExchangeDetail000 AS Detail ON Detail.ExchangeGuid = ex.Guid AND Detail.CurrencyVal <> 1
		INNER JOIN VwMy AS Curr ON Curr.myGuid = Detail.CurrencyGuid 
		INNER JOIN VwMy AS BasicCurr ON BasicCurr.myCurrencyVal = 1
		INNER JOIN TrnExchangeTypes000 AS Type ON ex.typeGuid = Type.Guid
		
	WHERE
		ex.[DATE] BETWEEN @FromDate AND @ToDate 	
		AND ex.[CashAmount] >= 14000
		
	ORDER BY ex.[Date], ex.[InternalNumber]
	
	--3-Break MultipleOperation-Records(Cash And Pay) into two detailed records:
	
	--	3-a Fill #CashAndPayOP 
	SELECT * 
	INTO #CashAndPayOP
	FROM #RESULT
	WHERE CashCurrencyVal <> 1 AND PayCurrencyVal <> 1
	
	--  3-b Fill #DetailedCashPay
	SELECT 
		GUID,				
		TypeGUID,			
		Number,				
		TypeCode,			
		Date,				
		CashCurrencyName,	
		CashAmount,			
		CashCurrencyVal,		
		BasicCurr.myCode AS PayCurrencyName,
		CashAmount * CashCurrencyVal AS PayAmount,			
		1 AS PayCurrencyVal,		
		CustomerName,		
		CustomerIdentityNo
	INTO #DetailedCashPay
	FROM #CashAndPayOP
	INNER JOIN VwMy AS BasicCurr ON BasicCurr.myCurrencyVal = 1
	
	INSERT INTO #DetailedCashPay
	SELECT 
		GUID,				
		TypeGUID,			
		Number,				
		TypeCode,			
		Date,				
		BasicCurr.myCode AS CashCurrencyName,	
		PayAmount * PayCurrencyVal AS CashAmount,			
		1 AS CashCurrencyVal,		
		PayCurrencyName,
		PayAmount,			
		PayCurrencyVal,		
		CustomerName,		
		CustomerIdentityNo
	FROM #CashAndPayOP
	INNER JOIN VwMy AS BasicCurr ON BasicCurr.myCurrencyVal = 1
	
	--  3-c Update #Result To be with Detailed Records Only
	DELETE FROM #RESULT WHERE [GUID] IN (SELECT GUID FROM #CashAndPayOP)
	INSERT INTO #RESULT SELECT * FROM #DetailedCashPay
	
	SELECT * FROM #RESULT ORDER BY [Date], [NUMBER]
#####################################################################
CREATE Function FnRepSyrianBank11
(
	@FROMDate			DATETIME,
	@ToDate				DATETIME,	
	@ExchangeForeign	INT, -- 0 according base currency , 1 according foreign currency, 2
	@GroupBy			INT -- 0 no group, 1 group by month, 2 group by day
)
	RETURNS @Result TABLE(CurrencyGUID UNIQUEIDENTIFIER, MonthNumber INT, DayDate DATETIME,
				Buy_CASH_Amount_Public FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ—
				Buy_CASH_Amount_Bank FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ „’«—›
				Buy_CASH_Amount_Exchanger FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
				Buy_Check_Amount FLOAT DEFAULT 0, Buy_Check_CurrAmount FLOAT DEFAULT 0, -- ° ‘—«¡ ‘Ìﬂ« 
				Buy_Transfer_Amount FLOAT DEFAULT 0, Buy_Transfer_CurrAmount FLOAT DEFAULT 0, -- ‘—«¡ ÕÊ«·« 
				Sell_CASH_Amount_Public FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
				Sell_CASH_Amount_Bank FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ „’«—›
				Sell_CASH_Amount_Exchanger FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
				Sell_Check_Amount FLOAT DEFAULT 0, Sell_Check_CurrAmount FLOAT DEFAULT 0, -- ° »Ì⁄ ‘Ìﬂ« 
				Sell_Transfer_Amount FLOAT DEFAULT 0, Sell_Transfer_CurrAmount FLOAT DEFAULT 0 -- »Ì⁄ ÕÊ«·« 
				)

AS
BEGIN
	DECLARE @BaseCurrency UNIQUEIDENTIFIER
	SELECT @BaseCurrency = GUID FROM my000 WHERE number = 1
	
	-- „‘ —Ì« 
	DECLARE @Buy TABLE
	(
		CurrencyGuid	UNIQUEIDENTIFIER,
		GroupBy			NVARCHAR(10),
		--MonthNumber INT,
		CustomerType	INT, -- 0 Public, 1 Bank, 2 Exchanger
		Amount			FLOAT,
		CurrAmount		FLOAT, -- Amount ”Ê—Ì
		[Type]			INT -- 0 exchange, 1 check, 2 transfer
	)
	-- ≈Ì’«·«  ’—«›… »”Ìÿ… „‘ —«…
	INSERT  @Buy
	SELECT 
		ex.CashCurrency,
		CASE @GroupBy 
			WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
			WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
			ELSE ''
		END,	
		ex.CustomerType,
		SUM(ex.CashAmount),
		SUM((ex.CashAmount / ex.CashCurrencyVal) / 1000),
		0 -- exchange				 
	FROM trnexchange000 As ex
	WHERE 	
		ex.bSimple = 1 
		AND ex.[Date] BETWEEN @FROMDate AND @ToDate
		AND
		(	(@ExchangeForeign = 0 AND (ex.CashCurrency = @BaseCurrency OR ex.PayCurrency = @BaseCurrency))
			OR
			(@ExchangeForeign = 1 AND (ex.CashCurrency <> @BaseCurrency AND ex.PayCurrency <> @BaseCurrency))
			OR 
			@ExchangeForeign = 2
		)
	GROUP BY 
			ex.CashCurrency,
			--DATEPART(m, ex.[DATE]), 
			CASE @GroupBy 
				WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
				WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
				ELSE ''
			END,
			ex.CustomerType
	
	-- ›Ê« Ì— ’—«›… „‘ —«…
	INSERT  @Buy
	SELECT 
		CashDetail.CurrencyGUID,
		--DATEPART(m, ex.[DATE]), 
		CASE @GroupBy 
			WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
			WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
			ELSE ''
		END,
		ex.CustomerType,
		SUM(CashDetail.Amount),
		SUM((CashDetail.Amount / CashDetail.CurrencyVal) / 1000),
		0 -- exchange				 
	FROM trnexchange000 As ex
	INNER JOIN trnExchangeDetail000 As CashDetail ON ex.[GUID] = CashDetail.ExchangeGUID AND CashDetail.Type = '0'
	WHERE 	
		ex.bSimple = 0 AND
		ex.[Date] BETWEEN @FROMDate AND @ToDate
		AND
		(
			(@ExchangeForeign = 0 AND (ex.CashCurrency = @BaseCurrency OR ex.PayCurrency = @BaseCurrency))
			OR
			(@ExchangeForeign = 1 AND (ex.CashCurrency <> @BaseCurrency AND ex.PayCurrency <> @BaseCurrency))
			OR
			@ExchangeForeign = 2
		)
	GROUP BY 
			CashDetail.CurrencyGUID, 
			CASE @GroupBy 
				WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
				WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
				ELSE ''
			END,
			ex.CustomerType
			
	-- ‘—«¡ ÕÊ«·«  ⁄«œÌ… 
	-- «·ÕÊ«·«  : Ã„ÂÊ—
	INSERT  @Buy
	SELECT 
		CurrencyGuid,
		--DATEPART(m, [DATE]), 
		CASE @GroupBy 
			WHEN 1 THEN CAST (DATEPART(m, [DATE]) AS NVARCHAR(2))
			WHEN 2 THEN CAST (dbo.GetJustDate([DATE]) AS NVARCHAR(10))
			ELSE ''
		END,
		0, -- CustomerType
		SUM(MustCashedAmount),
		SUM((MustCashedAmount / CurrencyVal) / 1000), 
		2
	FROM trnTransferVoucher000
	WHERE CASHED = 1
		AND 
		([Date] BETWEEN @FROMDate AND @ToDate)
		AND
		(
			(@ExchangeFOReign = 0 AND (CurrencyGuid = @BaseCurrency OR PayCurrency = @BaseCurrency))
			OR
			(@ExchangeFOReign = 1 AND (CurrencyGuid <> @BaseCurrency AND PayCurrency <> @BaseCurrency))
			OR
			@ExchangeForeign = 2
		)		
	GROUP BY 
			CurrencyGUID, 
			--DATEPART(m, [DATE])
			CASE @GroupBy 
				WHEN 1 THEN CAST (DATEPART(m, [DATE]) AS NVARCHAR(2))
				WHEN 2 THEN CAST (dbo.GetJustDate([DATE]) AS NVARCHAR(10))
				ELSE ''
			END
	
	--SELECT * FROM @Buy
	-------------------------------------------------------------------------------------		
	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
		
	--  „»Ì⁄« 
	DECLARE @Sell TABLE
	(
		CurrencyGuid	UNIQUEIDENTIFIER,
		--MonthNumber	INT,
		GroupBy			NVARCHAR(10),
		CustomerType	INT, -- 0 Public, 1 Bank, 2 Exchanger
		Amount			FLOAT,
		CurrAmount		FLOAT, -- Amount ”Ê—Ì
		[Type]			INT -- 0 exchange, 1 check, 2 transfer
	)
	
	-- ≈Ì’«·«  ’—«›… »”Ìÿ… „»Ì⁄…
	INSERT  @Sell
	SELECT 
		ex.PayCurrency,
		--DATEPART(m, ex.[DATE]), 
		CASE @GroupBy 
			WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
			WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
			ELSE ''
		END,
		ex.CustomerType,
		SUM(ex.PayAmount),
		SUM((ex.PayAmount / ex.PayCurrencyVal) / 1000),
		0 -- exchange				 
	FROM trnexchange000 As ex
	WHERE 	
		ex.bSimple = 1 AND
		ex.[Date] BETWEEN @FROMDate AND @ToDate
		AND
		(
			(@ExchangeForeign = 0 AND (ex.CashCurrency = @BaseCurrency OR ex.PayCurrency = @BaseCurrency))
			OR
			(@ExchangeForeign = 1 AND (ex.CashCurrency <> @BaseCurrency AND ex.PayCurrency <> @BaseCurrency))
			OR
			@ExchangeForeign = 2
		)
	GROUP BY 
			ex.PayCurrency, 
			--DATEPART(m, ex.[DATE]), 
			CASE @GroupBy 
				WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
				WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
				ELSE ''
			END,
			ex.CustomerType
	
	-- ›Ê« Ì— ’—«›… „»Ì⁄…
	INSERT  @Sell
	SELECT 
		Detail.CurrencyGUID,
		--DATEPART(m, ex.[DATE]), 
		CASE @GroupBy 
			WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
			WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
			ELSE ''
		END,		
		ex.CustomerType,
		SUM(Detail.Amount),
		SUM((Detail.Amount / Detail.CurrencyVal) / 1000),
		0 -- exchange				 
	FROM trnexchange000 As ex
	INNER JOIN trnExchangeDetail000 As Detail ON ex.[GUID] = Detail.ExchangeGUID AND Detail.Type = '1'
	WHERE 	
		ex.bSimple = 0 AND
		ex.[Date] BETWEEN @FROMDate AND @ToDate
		AND
		(
			(@ExchangeForeign = 0 AND (ex.CashCurrency = @BaseCurrency OR ex.PayCurrency = @BaseCurrency))
			OR
			(@ExchangeForeign = 1 AND (ex.CashCurrency <> @BaseCurrency AND ex.PayCurrency <> @BaseCurrency))
			OR 
			@ExchangeForeign = 2
		)
	GROUP BY 
			Detail.CurrencyGUID, 
			CASE @GroupBy 
				WHEN 1 THEN CAST (DATEPART(m, ex.[DATE]) AS NVARCHAR(2))
				WHEN 2 THEN CAST (dbo.GetJustDate(ex.[DATE]) AS NVARCHAR(10))
				ELSE ''
			END,
			ex.CustomerType
			
	-- »Ì⁄ ÕÊ«·«  ⁄«œÌ… 
	-- «·ÕÊ«·«  : Ã„ÂÊ—
	INSERT  @Sell
	SELECT 
		PayCurrency,
		DATEPART(m, [DATE]), 
		0, -- CustomerType
		SUM(MustPaidAmount),
		SUM((MustPaidAmount / PayCurrencyVal) / 1000), 
		
		2
	FROM trnTransferVoucher000
	WHERE PAID = 1
		AND 
		([Date] BETWEEN @FROMDate AND @ToDate)
		AND
		(
			(@ExchangeForeign = 0 AND (CurrencyGuid = @BaseCurrency OR PayCurrency = @BaseCurrency))
			OR
			(@ExchangeForeign = 1 AND (CurrencyGuid <> @BaseCurrency AND PayCurrency <> @BaseCurrency))
			OR 
			@ExchangeForeign = 2
		)		
	GROUP BY PayCurrency, DATEPART(m, [DATE])
	
	------------------------------------------------------------------------
	------------------------------------------------------------------------
	------------------------------------------------------------------------
	IF (@GroupBy = 1)
	BEGIN
		DECLARE @FromDateMonth INT
		SET @FromDateMonth = DATEPART(MONTH, @FROMDate)
		/* spt_values not supported in Azure */
		/*
		INSERT INTO @Result(CurrencyGUID, MonthNumber)
		SELECT 
			my.[GUID],
			v.Number + @FromDateMonth
		FROM my000 AS my, master..spt_values AS V
		WHERE V.type = 'P' AND v.number <= DATEDIFF(MONTH, @FROMDate, @ToDate)
		*/
	END
	ELSE
	IF (@GroupBy = 2)
	BEGIN
		DECLARE @TempFromDate DATETIME
		SET @TempFromDate = dbo.GetJustDate(@FROMDate)
		/* spt_values not supported in Azure */
		/*
		INSERT INTO @Result(CurrencyGUID, [DayDate])
		SELECT 
			my.[GUID],
			DATEADD(DAY, V.number, @TempFromDate)
		FROM my000 AS my, master..spt_values AS V
		WHERE V.type = 'P' AND v.number <= DATEDIFF(DAY, @TempFromDate, @ToDate)
		*/
		END
	ELSE
	-- no group	
	BEGIN
		INSERT INTO @Result(CurrencyGUID, MonthNumber)
		SELECT 
			my.[GUID],
			0
		FROM my000 AS my
	END
	-- CustomerType  0 Public, 1 Bank, 2 Exchanger
	-- [Type] 0 exchange, 1 check, 2 transfer
	
	UPDATE @Result
		SET 
		-- ‰ﬁœÌ Ã„ÂÊ—
		Buy_CASH_Amount_Public = CASE Buy.[Type] WHEN 0 THEN (CASE Buy.CustomerType WHEN 0 THEN Buy.Amount ELSE 0 END) ELSE 0 END,
		Buy_CASH_CurrAmount_Public = CASE Buy.[Type] WHEN 0 THEN (CASE Buy.CustomerType WHEN 0 THEN Buy.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‰ﬁœÌ „’«—›
		Buy_CASH_Amount_Bank = CASE Buy.[Type] WHEN 0 THEN (CASE Buy.CustomerType WHEN 1 THEN Buy.Amount ELSE 0 END) ELSE 0 END,
		Buy_CASH_CurrAmount_Bank = CASE Buy.[Type] WHEN 0 THEN (CASE Buy.CustomerType WHEN 1 THEN Buy.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‰ﬁœÌ ’Ì«—›…
		Buy_CASH_Amount_Exchanger = CASE Buy.[Type] WHEN 0 THEN (CASE Buy.CustomerType WHEN 2 THEN Buy.Amount ELSE 0 END) ELSE 0 END,
		Buy_CASH_CurrAmount_Exchanger = CASE Buy.[Type] WHEN 0 THEN(CASE Buy.CustomerType WHEN 2 THEN Buy.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‘Ìﬂ«  
		Buy_Check_Amount = CASE Buy.[Type] WHEN 1 THEN Buy.Amount ELSE 0 END,
		Buy_Check_CurrAmount = CASE Buy.[Type] WHEN 1 THEN Buy.CurrAmount ELSE 0 END,
		-- ÕÊ«·« 
		Buy_Transfer_Amount = CASE Buy.[Type] WHEN 2 THEN Buy.Amount ELSE 0 END,
		Buy_Transfer_CurrAmount = CASE Buy.[Type] WHEN 2 THEN Buy.CurrAmount ELSE 0 END
	FROM @Result AS res
	INNER JOIN @Buy AS Buy ON Buy.CurrencyGUID = res.CurrencyGUID 
			AND (@GroupBy = 0 OR (@GroupBy = 1 AND Buy.GroupBy = res.MonthNumber) OR (@GroupBy = 2 AND Buy.GroupBy = CAST (res.[DayDate] AS NVARCHAR(10))))
	
	
	UPDATE @Result
		SET 
		-- ‰ﬁœÌ Ã„ÂÊ—
		Sell_CASH_Amount_Public = CASE Sell.[Type] WHEN 0 THEN (CASE Sell.CustomerType WHEN 0 THEN Sell.Amount ELSE 0 END) ELSE 0 END,
		Sell_CASH_CurrAmount_Public = CASE Sell.[Type] WHEN 0 THEN (CASE Sell.CustomerType WHEN 0 THEN Sell.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‰ﬁœÌ „’«—›
		Sell_CASH_Amount_Bank = CASE Sell.[Type] WHEN 0 THEN (CASE Sell.CustomerType WHEN 1 THEN Sell.Amount ELSE 0 END) ELSE 0 END,
		Sell_CASH_CurrAmount_Bank = CASE Sell.[Type] WHEN 0 THEN (CASE Sell.CustomerType WHEN 1 THEN Sell.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‰ﬁœÌ ’Ì«—›…
		Sell_CASH_Amount_Exchanger = CASE Sell.[Type] WHEN 0 THEN (CASE Sell.CustomerType WHEN 2 THEN Sell.Amount ELSE 0 END) ELSE 0 END,
		Sell_CASH_CurrAmount_Exchanger = CASE Sell.[Type] WHEN 0 THEN(CASE Sell.CustomerType WHEN 2 THEN Sell.CurrAmount ELSE 0 END) ELSE 0 END,
		-- ‘Ìﬂ«  
		Sell_Check_Amount = CASE Sell.[Type] WHEN 1 THEN Sell.Amount ELSE 0 END,
		Sell_Check_CurrAmount = CASE Sell.[Type] WHEN 1 THEN Sell.CurrAmount ELSE 0 END,
		-- ÕÊ«·« 
		Sell_Transfer_Amount = CASE Sell.[Type] WHEN 2 THEN Sell.Amount ELSE 0 END,
		Sell_Transfer_CurrAmount = CASE Sell.[Type] WHEN 2 THEN Sell.CurrAmount ELSE 0 END
	FROM @Result AS res
	INNER JOIN @Sell AS Sell ON Sell.CurrencyGUID = res.CurrencyGUID 
	AND (@GroupBy = 0 OR (@GroupBy = 1 AND Sell.GroupBy = res.MonthNumber) OR (@GroupBy = 2 AND Sell.GroupBy = CAST (res.[DayDate] AS NVARCHAR(10))))

RETURN
END
#####################################################################
CREATE PROC repSyrianBank11
	@FROMDate			DATETIME,
	@ToDate				DATETIME,	
	@ExchangeForeign	INT, -- 0 according base currency , 1 according foreign currency
	@GroupBy			INT -- 0 no group, 1 group by month, 2 group by day

AS
	SET NOCOUNT ON
	/*
	«· ⁄ﬁÌœ ›ﬁÿ »„« ÌŒ’ „Ê÷Ê⁄ «·‰ﬁœÌ ÕÌÀ √‰ «·‰ﬁœÌ Ì„ﬂ‰ √‰ ÌﬂÊ‰ Ã„ÂÊ— √Ê „’«—› √Ê ’Ì«—›…
	√„ «·‘Ìﬂ«  Ê«·ÕÊ«·« ° Õ Ï Ì’·‰« «· Õ·Ì· «·‰Â«∆Ì «·‘Ìﬂ«  «·ÊÕÊ«·«  ›ﬁÿ Ã„ÂÊ—
	*/
	DECLARE @Result TABLE(CurrencyGUID UNIQUEIDENTIFIER, MonthNumber INT,
				Buy_CASH_Amount_Public FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ—
				Buy_CASH_Amount_Bank FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ „’«—›
				Buy_CASH_Amount_Exchanger FLOAT DEFAULT 0, Buy_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
				Buy_Check_Amount FLOAT DEFAULT 0, Buy_Check_CurrAmount FLOAT DEFAULT 0, -- ° ‘—«¡ ‘Ìﬂ« 
				Buy_Transfer_Amount FLOAT DEFAULT 0, Buy_Transfer_CurrAmount FLOAT DEFAULT 0, -- ‘—«¡ ÕÊ«·« 
				Sell_CASH_Amount_Public FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Public FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
				Sell_CASH_Amount_Bank FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Bank FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ „’«—›
				Sell_CASH_Amount_Exchanger FLOAT DEFAULT 0, Sell_CASH_CurrAmount_Exchanger FLOAT DEFAULT 0,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
				Sell_Check_Amount FLOAT DEFAULT 0, Sell_Check_CurrAmount FLOAT DEFAULT 0, -- ° »Ì⁄ ‘Ìﬂ« 
				Sell_Transfer_Amount FLOAT DEFAULT 0, Sell_Transfer_CurrAmount FLOAT DEFAULT 0 -- »Ì⁄ ÕÊ«·« 
				
	)
	
	DECLARE @BaseCurrency UNIQUEIDENTIFIER
	SELECT @BaseCurrency = GUID FROM my000 WHERE number = 1
	
	INSERT INTO @result  
	SELECT 
				CurrencyGUID , MonthNumber ,
				Buy_CASH_Amount_Public , Buy_CASH_CurrAmount_Public ,  -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ—
				Buy_CASH_Amount_Bank, Buy_CASH_CurrAmount_Bank ,  -- ‘—«¡ ‰ﬁœÌ „’«—›
				Buy_CASH_Amount_Exchanger , Buy_CASH_CurrAmount_Exchanger ,  -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
				Buy_Check_Amount , Buy_Check_CurrAmount , -- ° ‘—«¡ ‘Ìﬂ« 
				Buy_Transfer_Amount , Buy_Transfer_CurrAmount , -- ‘—«¡ ÕÊ«·« 
				Sell_CASH_Amount_Public , Sell_CASH_CurrAmount_Public ,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
				Sell_CASH_Amount_Bank , Sell_CASH_CurrAmount_Bank ,  -- »Ì⁄ ‰ﬁœÌ „’«—›
				Sell_CASH_Amount_Exchanger , Sell_CASH_CurrAmount_Exchanger ,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
				Sell_Check_Amount , Sell_Check_CurrAmount, -- ° »Ì⁄ ‘Ìﬂ« 
				Sell_Transfer_Amount , Sell_Transfer_CurrAmount  -- »Ì⁄ ÕÊ«·« 
	 FROM FnRepSyrianBank11(@FROMDate,@ToDate,@ExchangeForeign, 1)
	 WHERE CurrencyGUID <> @BaseCurrency
	
	SELECT 
			m.Number AS CurrencyNumber,
			M.CODE AS CurrencyCode,
			MonthNumber, 
			Buy_CASH_CurrAmount_Public AS Buy_Cash_Public, -- ‘—«¡ ‰ﬁœÌ Ã„ÂÊ— 
			Buy_CASH_Amount_Public As Buy_Cash_Curr_Public,
			Buy_CASH_CurrAmount_Bank AS Buy_Cash_Bank, -- ‘—«¡ ‰ﬁœÌ „’«—›
			Buy_CASH_Amount_Bank AS Buy_Cash_Curr_Bank,
			Buy_CASH_CurrAmount_Exchanger AS Buy_Cash_Exchanger, -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
			Buy_CASH_Amount_Exchanger AS Buy_Cash_Curr_Exchanger,
			Buy_Check_CurrAmount AS Buy_Check, --  ‘—«¡ ‘Ìﬂ« 
			Buy_Check_Amount AS Buy_Curr_Check,
			Buy_Transfer_CurrAmount AS Buy_Transfer, -- ‘—«¡ ÕÊ«·« 
			Buy_Transfer_Amount AS Buy_Curr_Transfer,
			Sell_CASH_CurrAmount_Public AS Sell_Cash_Public,  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
			Sell_CASH_Amount_Public AS Sell_Cash_Curr_Public,
			Sell_CASH_CurrAmount_Bank AS Sell_Cash_Bank,  -- »Ì⁄ ‰ﬁœÌ „’«—›
			Sell_CASH_Amount_Bank AS Sell_Cash_Curr_Bank, 
			Sell_CASH_CurrAmount_Exchanger AS Sell_Cash_Exchanger,  -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
			Sell_CASH_Amount_Exchanger AS Sell_Cash_Curr_Exchanger,
			Sell_Check_CurrAmount AS Sell_Check, -- ° »Ì⁄ ‘Ìﬂ« 
			Sell_Check_Amount AS Sell_Curr_Check,
			Sell_Transfer_CurrAmount AS Sell_Transfer, -- »Ì⁄ ÕÊ«·« 
			Sell_Transfer_Amount AS Sell_Curr_Transfer,
			0 AS IsTotal
	FROM @Result AS R
	INNER JOIN MY000 AS M ON M.GUID = CurrencyGUID
	
	
	UNION ALL
	SELECT	
			0 AS CurrencyNumber,
			'' AS CurrencyCode,
			MonthNumber, 
			SUM(Buy_CASH_CurrAmount_Public),
			SUM(Buy_CASH_Amount_Public),  
			SUM(Buy_CASH_CurrAmount_Bank), 
			SUM(Buy_CASH_Amount_Bank), 
			SUM(Buy_CASH_CurrAmount_Exchanger),
			SUM(Buy_CASH_Amount_Exchanger), -- ‘—«¡ ‰ﬁœÌ ’Ì«—›…
			SUM(Buy_Check_CurrAmount),
			SUM(Buy_Check_Amount),  -- ‘—«¡ ‘Ìﬂ« 
			SUM(Buy_Transfer_CurrAmount),  -- ‘—«¡ ÕÊ«·« 
			SUM(Buy_Transfer_Amount),
			SUM(Sell_CASH_CurrAmount_Bank),  -- »Ì⁄ ‰ﬁœÌ Ã„ÂÊ—
			SUM(Sell_CASH_Amount_Public),
			SUM(Sell_CASH_CurrAmount_Bank),  -- »Ì⁄ ‰ﬁœÌ „’«—›
			SUM(Sell_CASH_Amount_Bank),
			SUM(Sell_CASH_CurrAmount_Exchanger),   -- »Ì⁄ ‰ﬁœÌ ’Ì«—›…
			SUM(Sell_CASH_Amount_Exchanger),
			SUM(Sell_Check_CurrAmount),  -- »Ì⁄ ‘Ìﬂ« 
			SUM(Sell_Check_Amount),
			SUM(Sell_Transfer_CurrAmount),  -- »Ì⁄ ÕÊ«·« 
			SUM(Sell_Transfer_Amount),
			1 AS IsTotal
	FROM @Result 
	GROUP BY MonthNumber

	ORDER BY MonthNumber, IsTotal, CurrencyNumber
	
##########################################################################
CREATE  PROC prcTrnSyBk_InStamentRep  
	@StartDate  DATETIME, 
	@EndDate	DATETIME, 
	@Local		INT 
AS 
	SET NOCOUNT ON	 

	CREATE TABLE #RESULT 
		( 
			StmType		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			StmGuid		UNIQUEIDENTIFIER, 
			StmCode		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			IsVoucherGen 	INT, 
			VoucherGuid	UNIQUEIDENTIFIER, 
			VoucherTypeGuid	UNIQUEIDENTIFIER, 
			VoucherCode	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Date] 		DATETIME, 
			Sender		UNIQUEIDENTIFIER, 
			SenderName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			SenderPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Receiver	UNIQUEIDENTIFIER, 
			ReceiverName	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			ReceiverPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			SenderAddress  NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			ReceiverIdentityCard NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Amount		FLOAT, 
			Currency	UNIQUEIDENTIFIER, 
			CurrVal 	FLOAT, 
			NetWages	FLOAT, 
			PayAmount	FLOAT, 
			PayCurrency	UNIQUEIDENTIFIER, 
			PayCurVal 	FLOAT, 
			OfficeName	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			OfficeCity	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			OfficeState	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Notes		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Reason		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			ActualReceiverAddress NVARCHAR(250) COLLATE ARABIC_CI_AI
		) 
	INSERT INTO #RESULT	 
	SELECT   
		ISNULL(stmType.[ttName], '') ,
		ISNULL(stm.Guid, 0x0),
		ISNULL(stm.Code, ''),
		ISNULL(Item.IsVoucherGenerated, 0),
		V.TVGUID, 
		V.TVGUID,
		V.TVCODE, 
		v.TVDATE, 
		Sender.SRGuid, 
		Sender.SRName, 
		Sender.SRPhone1,  
		Res.SRGuid, 
		Res.SRName, 
		Res.SRPhone1, 
		Sender.SRAddress,
		ISNULL(Pay.IdentityCard,'·„  ”·„ »⁄œ'), 
		V.TVAmount / 1000, 
		V.TVCurrencyGUID,
		V.TVCurrencyVal, 
		V.TVNetWages,
		(V.TVMustPaidAmount / V.TVPayCurrencyVal) / 1000,
		V.TVPayCurrency, 
		V.TVPayCurrencyVal,
		office.OfName,
		office.OfCity,
		office.OfState,
		V.TVNOTES,
		V.TVReason,
		Pay.ActualReceiverAddress
	FROM	

		vwTrnTransferVoucher as v
		INNER JOIN vwTrnOffice AS office ON office.OfGUID =  V.TVSourceBranch 
		INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID
		INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID 
		INNER JOIN TrnVoucherPayInfo000 AS Pay ON Pay.VoucherGuid =  V.TVGUID 
		LEFT JOIN TrnStatementItems000 AS item ON item.TransferVoucherGuid = v.TVGuid
		LEFT JOIN vwTrnStatement AS stm ON item.ParentGuid = stm.Guid 		
		LEFT JOIN vwTrnStatementTypes  AS Stmtype ON 
				stm.TypeGUID = Stmtype.ttGuid AND Stmtype.IsOut = 0 
	-- State: 15 = Canceled, call fnTrnState() for display states enumetration
	WHERE 
		pay.[Date] BETWEEN @StartDate AND @EndDate
			AND (ISNULL(office.ofbLocal, 0) =  @Local)
			AND (TVState <> 15)
		 
	IF (@Local = 1)
	BEGIN
		INSERT INTO #RESULT	 
		SELECT   
			'',	
			0x0,
			'',	
			1,	
			V.TVGUID, 
			V.TVGUID,
			V.TVCODE, 
			v.TVDATE, 
			Sender.SRGuid, 
			Sender.SRName, 
			Sender.SRPhone1,
			Res.SRGuid, 
			Res.SRName, 
			Res.SRPhone1, 
			Sender.SRAddress,  
			ISNULL(Pay.IdentityCard,'·„  ”·„ »⁄œ'), 
			V.TVAmount / 1000, 
			V.TVCurrencyGUID,
			V.TVCurrencyVal, 
			V.TVNetWages,
			(V.TVMustPaidAmount / V.TVPayCurrencyVal) / 1000,
			V.TVPayCurrency, 
			V.TVPayCurrencyVal,
			sourceBR.[Name],--office.OfName,
			sourceBR.City,
			sourceBR.State,
			V.TVNOTES,
			V.TVReason,
			Pay.ActualReceiverAddress
		FROM	

			vwTrnTransferVoucher as v
			INNER JOIN TrnBranch000 AS sourceBR ON sourceBR.GUID = V.TVSourceBranch 
			INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID
			INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID 
			INNER JOIN TrnVoucherPayInfo000 AS Pay ON Pay.VoucherGuid =  V.TVGUID 
		WHERE 
			-- SourceType: 1 = Branch, 2 = Office
			-- DestinationType: 1 = Branch, 2 = Office
			-- State: 15 = Canceled, call fnTrnState() for display states enumetration
			Pay.[Date] BETWEEN @StartDate AND @EndDate 
				AND v.TVSourceType = 1 AND v.TvDestinationType = 1 AND (TVState <> 15)     			
	END	 
	
	SELECT * FROM #result  
	ORDER BY [Date], VoucherCode 
##########################################################################
CREATE PROC prcTrnSyBk_OutStamentRep
		@StartDate DATETIME , 
		@EndDate DATETIME  , 
		@Local		INT  -- 0, 1 
AS 
	SET NOCOUNT ON	 
	 
	CREATE TABLE #RESULT  
		(  
			StmType		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			StmGuid		UNIQUEIDENTIFIER,  
			StmCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			VoucherGuid	UNIQUEIDENTIFIER,  
			VoucherCode	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Date] 		DATETIME,  
			Sender		UNIQUEIDENTIFIER,  
			SenderName	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			SenderPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			 
			SenderAddress  NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			  
			SenderIdentityCard NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Receiver	UNIQUEIDENTIFIER,  
			ReceiverName	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			ReceiverPhone	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Amount		FLOAT,  
			Currency	UNIQUEIDENTIFIER,  
			CurrVal 	FLOAT,  
			NetWages	FLOAT,  
			PayAmount	FLOAT,  
			PayCurrency	UNIQUEIDENTIFIER,  
			PayCurVal 	FLOAT,  
			OfficeName	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			OfficeCity	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			OfficeState	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Notes		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Reason		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			 
			ActualReceiverAddress NVARCHAR(250) COLLATE ARABIC_CI_AI 
			  
		)  
	INSERT INTO #RESULT	  
	SELECT    
		ISNULL(stmType.[ttName], '') ,  
		ISNULL(stm.Guid, 0x0),  
		ISNULL(stm.Code, ''),  
		V.TVGUID,  
		V.TVCODE,  
		V.[TVDate],  
		Sender.SRGuid,  
		Sender.SRName,  
		Sender.SRPhone1,  
		Sender.SRAddress, 
		Sender.SRIdentityNo,  
		Res.SRGuid,  
		Res.SRName,  
		Res.SRPhone1,  
		 
		(V.TVAmount / V.TVCurrencyVal) / 1000,  
		V.TVCurrencyGUID,  
		V.TVCurrencyVal,  
		V.TVNetWages,  
		(V.TVMustPaidAmount / V.TVPayCurrencyVal) / 1000, 
		V.TVPayCurrency,   
		V.TVPayCurrencyVal,  
		office.OfName,  
		office.OfCity,  
		office.OfState,  
		V.TVNOTES,  
		V.TVReason, 
		Res.SRAddress 
	FROM	  
		vwTrnTransferVoucher as v  
		INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID  
		INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID   
		INNER JOIN vwTrnOffice AS office ON office.OfGUID =  V.TVDestinationBranch   
		LEFT JOIN vwTrnStatement AS stm ON V.OutStatementGuid = stm.GUID  
		LEFT JOIN vwTrnStatementTypes  AS Stmtype ON  
				stm.TypeGUID = Stmtype.ttGuid AND Stmtype.IsOut = 1  
	WHERE  
		v.[TVDate] BETWEEN @StartDate AND @EndDate    
		AND (office.OfbLocal = @Local)  
		AND (TVState <> 15)--«·ÕÊ«·… ·Ì”  „·€Ì…  		  
	-- ≈÷«›… «·ÕÊ«·… «·„’—›Ì…---------------------
	IF (@Local = 0)
	BEGIN
		INSERT INTO #RESULT	  
		SELECT    
			ISNULL(stmType.[ttName], '') ,  
			ISNULL(stm.Guid, 0x0),  
			ISNULL(stm.Code, ''),  
			V.TVGUID,  
			V.TVCODE,  
			V.[TVDate],  
			Sender.SRGuid,  
			Sender.SRName,  
			Sender.SRPhone1,  
			Sender.SRAddress, 
			Sender.SRIdentityNo,  
			Res.SRGuid,  
			Res.SRName,  
			Res.SRPhone1,  
			 
			(V.TVAmount / V.TVCurrencyVal) / 1000,  
			V.TVCurrencyGUID,  
			V.TVCurrencyVal,  
			V.TVNetWages,  
			(V.TVMustPaidAmount / V.TVPayCurrencyVal) / 1000, 
			V.TVPayCurrency,   
			V.TVPayCurrencyVal,  
			'' as OfName,  
			'' as OfCity,  
			'' as OfState,  
			V.TVNOTES,  
			V.TVReason, 
			Res.SRAddress 
		FROM	  
			vwTrnTransferVoucher as v  
			INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID  
			INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID   
			INNER JOIN TrnTransferBankOrder000 AS BankVoucher ON v.TVBankOrderGuid = BankVoucher.Guid
			LEFT JOIN vwTrnStatement AS stm ON V.OutStatementGuid = stm.GUID  
			LEFT JOIN vwTrnStatementTypes  AS Stmtype ON  
					stm.TypeGUID = Stmtype.ttGuid AND Stmtype.IsOut = 1  
		WHERE  
			v.[TVDate] BETWEEN @StartDate AND @EndDate    
			AND (TVState <> 15)--«·ÕÊ«·… ·Ì”  „·€Ì…  		  
	END
	--------------------------------------
	IF (@Local = 1)  
	BEGIN  
		INSERT INTO #RESULT	  
		SELECT    
			'',	 
			0x0, 
			'', 
			V.TVGUID,  
			V.TVCODE,  
			V.[TVInternalNum],  
			Sender.SRGuid,  
			Sender.SRName,  
			Sender.SRPhone1, 
			  
			Sender.SRAddress, 
			 
			Sender.SRIdentityNo,  
			Res.SRGuid,  
			Res.SRName,  
			Res.SRPhone1,  
			(V.TVAmount / V.TVCurrencyVal) / 1000,  
			V.TVCurrencyGUID,  
			V.TVCurrencyVal,  
			V.TVNetWages,  
			(V.TVMustPaidAmount / V.TVPayCurrencyVal) / 1000,  
			V.TVPayCurrency,   
			V.TVPayCurrencyVal,  
			destBR.[Name],  
			destBR.City,  
			destBR.State,  
			V.TVNOTES,  
			V.TVReason, 
			Res.SRAddress 
			 
		FROM	  
			vwTrnTransferVoucher as v  
			INNER JOIN vwTrnSenderReceiver  AS Sender ON Sender.SRGuid = V.TVSenderGUID  
			INNER JOIN vwTrnSenderReceiver  AS Res ON Res.SRGuid = V.TVReceiver1_GUID   
			INNER JOIN TrnBranch000 AS destBR ON destBR.GUID = V.TVDestinationBranch   
	    WHERE 
			v.[TVDate] BETWEEN @StartDate AND @EndDate 
			AND v.TVSourceType = 1 
			AND v.TvDestinationType = 1 
			AND (TVState <> 15)--«·ÕÊ«·… ·Ì”  „·€Ì…  
			  
	END  
		  
	SELECT * FROM #result   
	ORDER BY  VoucherCode   
#####################################################################
CREATE  FUNCTION fnTrnGetSyBkAccountsCodesTable
		( 
			@Type INT  
			-- 0 ALL  
			-- 1 „ÊÃÊœ«  
			-- 2 „ÿ«·Ì»  
			-- 3 Œ«—Ã «·„Ì“«‰Ì… 
			-- 4 »Ì«‰ «·œŒ· 
			-- 8 ﬁ«∆„… «·œŒ·
			-- 71 „Ì“«‰Ì… - „ÊÃÊœ« 
			-- 72 „Ì“«‰Ì… - „ÿ«·Ì»
		) 
RETURNS @Result TABLE(Data [SQL_VARIANT])  
AS 
BEGIN 
	DECLARE @String NVARCHAR(max) 
	IF (@Type = 0) 
	BEGIN 
		-- „ÊÃÊœ« 
		SET @String = '10100,10110,10120,11100,11110,11120,11130,12100,12110,12170,12180,12181,12187' 
		SET @String = @String + ',13100,13110,13120,13170,13180,13181,13182,13187,14100,14110,14120,14170,14180,14181,14182,14187'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)   
		SET @String = '16100,16110,16111,16112,16119,16120,16130,16131,16132,16139'
		SET @String = @String + ',18000,18100,18110,18190,18200,18210,18220,18230,18280,18290,18300,18310,18320,18330,18340,18350,18360'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)   
		SET @String = '19100,19110,19120,19130,19140,19150,19160,19180,19190,19900,19999'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String) 
		-- „ÿ«·Ì»  
		SET @String = '20000,20100,21000,21100,21200,21300,21400,21500,22000,22100' 
		SET @String = @string + ',23000,23100,23200,29100,29300,29400,29500,29600,29610,29620,29630,29700,29900,29999' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)
		-- Œ«—Ã «·„Ì“«‰Ì…   
		SET @String = '30100,30200,30900' 
		--»Ì«‰ «·œŒ· „ ÷„‰« «·œŒ·
		SET @String = '40100,40110,40120,40130,40140,40200,40210,40220,40230,40240,40300,40310,40320,40400' 
		SET @String = @string + ',40500,40510,40520,40530,40540,40600,40610,40900,40910,40920,40930,40940,40950,40960' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)  
	 
		SET @String = '40970,40980,40990,41000,42000,43000,44000,44010,44020,44030,44040,45000,49999' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)    
		RETURN  
	END 
	IF (@Type = 1) 
	BEGIN 
		-- „ÊÃÊœ« 
		SET @String = '10100,10110,10120,11100,11110,11120,11130,12100,12110,12170,12180,12181,12187' 
		SET @String = @String + ',13100,13110,13120,13170,13180,13181,13182,13187,14100,14110,14120,14170,14180,14181,14182,14187'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)   
		SET @String = '16100,16110,16111,16112,16119,16120,16130,16131,16132,16139'
		SET @String = @String + ',18000,18100,18110,18190,18200,18210,18220,18230,18280,18290,18300,18310,18320,18330,18340,18350,18360'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)   
		SET @String = '19100,19110,19120,19130,19140,19150,19160,19180,19190,19900,19999'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)  
		RETURN  
	END 
	ELSE 
	IF (@Type = 2) 
	BEGIN 
		-- „ÿ«·Ì»  
		SET @String = '20000,20100,21000,21100,21200,21300,21400,21500,22000,22100' 
		SET @String = @string + ',23000,23100,23200,29100,29300,29400,29500,29600,29610,29620,29630,29700,29900,29999' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)
		RETURN  
	END 
	 
	ELSE 
	IF (@Type = 3) 
	BEGIN 
		-- Œ«—Ã «·„Ì“«‰Ì…
		SET @String = '30100,30200,30900' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)   
		RETURN  
	END 
	 
	ELSE 
	IF (@Type = 4) 
	BEGIN 
		--»Ì«‰ «·œŒ·
		SET @String = '40100,40110,40120,40130,40140,40200,40210,40220,40230,40240,40300,40310,40320,40400' 
		SET @String = @string + ',40500,40510,40520,40530,40540,40600,40610,40900,40910,40920,40930,40940,40950,40960' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)  
	 
		SET @String = '40970,40980,40990,41000,42000,43000,44000,44010,44020,44030,44040,45000,49999' 
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String)  
		 
		RETURN 
	END 
	
	ELSE
	IF (@Type = 8)
	BEGIN
		--ﬁ«∆„… «·œŒ·
		SET @String = '40100,40200,40300,40500,40600,40900,41000,42000,43000,44000,45000,49999'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String) 
		
		RETURN
	END
	ELSE
	IF (@Type = 71)
	BEGIN
		-- 71 „Ì“«‰Ì… - „ÊÃÊœ« 
		SET @String = '10100,11100,12100,12180,13100,13180,14100,14180,16100,18100,18200,18300,19100,19900'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String) 
		RETURN
	END
	ELSE
	IF (@Type = 72)
	BEGIN
		-- 72 „Ì“«‰Ì… - „ÿ«·Ì»
		SET @String ='20000,21000,22100,23000,29100,29300,29500,29400,29610,29620,29630,29700,29900'
		INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]( @String) 
		RETURN
	END
	INSERT INTO @Result SELECT * FROM [dbo].[fnTextToRows]('')   
	RETURN  
END	 
#####################################################################
CREATE FUNCTION fnTrnSyBkAccountsBalances
		(
			@AccPtr				[UNIQUEIDENTIFIER] = 0x0,
			@FromOpeningEntry	[BIT]			   = 0,
			@StartDate			[DATETIME]		   = '1-1-1900',
			@EndDate			[DATETIME]		   = '1-1-2100'
		)

RETURNS @EndResult TABLE
	( 
		[ID]							INT IDENTITY(1,1),
		[Level]							[INT] DEFAULT 0, 
		[GUID]							[UNIQUEIDENTIFIER], 
		[Code]							[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]							[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[LatinName]						[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[ParentGUID]					[UNIQUEIDENTIFIER], 
		--[acCurrGuid]					[UNIQUEIDENTIFIER], 
		[TotalBalance]					[FLOAT]	DEFAULT 0, -- «·—’Ìœ «·⁄«„
		[ResidentBalance]				[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì «·„ﬁÌ„
		[Non_ResidentBalance]			[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì €Ì— «·„ﬁÌ„
		[ResidentForeignBalance]		[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì «·„ﬁÌ„
		[Non_ResidentForeignBalance]	[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì €Ì— «·„ﬁÌ„
		-- €Ì— „ﬁÌ„ 0
		-- „ﬁÌ„ 1
		-- -1 Õ”«» —∆Ì”Ì ·« ‰Â „ ≈–« ﬂ«‰ „ﬁÌ„ √Ê €Ì— „ﬁÌ„
		[IsResidentAccount]	INT DEFAULT -1,
		-- √Ã‰»Ì 0
		-- „Õ·Ì 1
		-- -1 Õ”«» —∆Ì”Ì ·« ‰Â „ ≈–« ﬂ«‰ √Ã‰»Ì √Ê „Õ·Ì
		[IsLocalAccount]	INT DEFAULT -1
	)  
AS
BEGIN

	DECLARE @Balances TABLE
	(
		[GUID]			[UNIQUEIDENTIFIER], 
		[TotalDebit]		[FLOAT], 
		[TotalCredit]		[FLOAT]
	)
	
	DECLARE @BaseCurrency			[UNIQUEIDENTIFIER],
			@NonResidentBaseAccount [UNIQUEIDENTIFIER]
			
	SELECT @BaseCurrency = [GUID] FROM My000 WHERE Number = 1
	SELECT @NonResidentBaseAccount = CAST([Value] AS [UNIQUEIDENTIFIER]) FROM OP000 WHERE [Name] = 'TrnCfg_SyBank_NonResidentAccount'
	
	DECLARE @NonResidentAccountTable TABLE 
	( 
		[Guid]	[UNIQUEIDENTIFIER]
	)
	
	IF (ISNULL(@NonResidentBaseAccount, 0x0) <> 0x0)
		INSERT INTO @NonResidentAccountTable
			SELECT [GUID] FROM [fnGetAccountsList](@NonResidentBaseAccount, 1)
	
	INSERT INTO @EndResult([GUID], [Code], [Name], [LatinName], [ParentGUID], [Level], [IsResidentAccount], [IsLocalAccount])
		SELECT 
			[ac].[GUID], 
			[ac].[Code], 
			[ac].[Name], 
			[ac].[LatinName], 
			[ac].[ParentGuid], 
			[fn].[Level],
			CASE ISNULL(NonResAc.[GUID], 0x0) WHEN 0x0 THEN 1 ELSE 0 END,
			CASE Ac.CurrencyGUID WHEN @BaseCurrency THEN 1 ELSE 0 END
		FROM 
			[dbo].[fnGetAccountsList](@AccPtr, 1) AS [fn] 
			INNER JOIN [ac000] AS [ac] ON [fn].[GUID] = [ac].[GUID]
			LEFT JOIN @NonResidentAccountTable AS NonResAc ON NonResAc.[GUID] = Ac.[GUID]
	--Test If Balance From Opening Entry
	IF (@FromOpeningEntry = 0)
	BEGIN
		INSERT INTO @Balances
			SELECT 
				Ac.[Guid],
				SUM(en.[Debit]) / 1000,
				SUM(en.[Credit]) / 1000
			FROM 	
				en000 AS en
				INNER JOIN ce000 AS ce ON ce.[Guid] = en.ParentGuid
				INNER JOIN @EndResult AS Ac ON Ac.[GUID] = en.AccountGUID
			WHERE ([en].[Date] BETWEEN @StartDate AND @EndDate)
			GROUP BY 
				Ac.[Guid]
	END
	
	ELSE--Balance From Opening Entry
	BEGIN
		 INSERT INTO @Balances
			SELECT 
				Ac.[Guid],
				SUM(ISNULL(OpeningEn.[Debit], 0)) / 1000,
				SUM(ISNULL(OpeningEn.[Credit], 0)) / 1000
			FROM  @EndResult AS Ac 
				  LEFT JOIN dbo.fnTrnOpeningEntry() AS OpeningEn ON Ac.[GUID] = OpeningEn.AccountGUID	
			GROUP BY 
				Ac.[Guid]
	END
	
	UPDATE r SET 
			r.[TotalBalance] = bal.TotalDebit - bal.TotalCredit,
			r.[ResidentBalance] = CASE WHEN r.[IsResidentAccount] = 1 AND r.[IsLocalAccount] = 1 
										THEN  bal.TotalDebit - bal.TotalCredit ELSE 0 END,
			r.[Non_ResidentBalance] = CASE WHEN r.[IsResidentAccount] = 0 AND r.[IsLocalAccount] = 1 
										THEN  bal.TotalDebit - bal.TotalCredit ELSE 0 END,
			r.[ResidentForeignBalance] = CASE WHEN r.[IsResidentAccount] = 1 AND r.[IsLocalAccount] = 0 
											THEN  bal.TotalDebit - bal.TotalCredit ELSE 0 END,
			r.[Non_ResidentForeignBalance] = CASE WHEN r.[IsResidentAccount] = 0 AND r.[IsLocalAccount] = 0 
											THEN  bal.TotalDebit - bal.TotalCredit  ELSE 0 END										  
		FROM  @EndResult AS r
		INNER JOIN @Balances AS bal ON r.[GUID] = bal.[GUID]
		
		DECLARE @Level INT
		SET @Level = (SELECT MAX([Level]) FROM @EndResult)
		WHILE @Level >= 0 
		BEGIN 
			UPDATE @EndResult SET 
					[TotalBalance]				= ISNULL([SumTotalBalance], 0),
					[ResidentBalance]			= ISNULL([SumResidentBalance], 0),
					[Non_ResidentBalance]		= ISNULL([SumNon_ResidentBalance], 0),
					[ResidentForeignBalance]	= ISNULL([SumResidentForeignBalance], 0),
					[Non_ResidentForeignBalance]= ISNULL([SumNon_ResidentForeignBalance], 0)
				FROM 
					@EndResult AS [Father] 
					INNER JOIN ( 
						SELECT
							[ParentGUID],
							SUM([TotalBalance]) 				AS [SumTotalBalance],
							SUM([ResidentBalance]) 				AS [SumResidentBalance],
							SUM([Non_ResidentBalance]) 			AS [SumNon_ResidentBalance],
							SUM([ResidentForeignBalance])	 	AS [SumResidentForeignBalance],
							SUM([Non_ResidentForeignBalance]) 	AS [SumNon_ResidentForeignBalance]
						FROM
							@EndResult 
						WHERE 
							[Level] = @Level
						GROUP BY
							[ParentGUID]
						) AS [Sons] -- sum sons
					ON [Father].[GUID] = [Sons].[ParentGUID]
			
			SET @Level = @Level - 1
		END
	RETURN
END
#####################################################################
CREATE PROCEDURE repSyrianBank0
	@ToDate 			[DATETIME]
AS

	SET NOCOUNT ON
	
	SELECT 
		fn.[GUID], fn.[Code], fn.[Name], fn.[LatinName], fn.[TotalBalance]	
	FROM fnTrnSyBkAccountsBalances(0x0, 0, '', @ToDate) AS fn
	INNER JOIN fnTrnGetSyBkAccountsCodesTable(0) AS fncodes ON fncodes.Data = fn.Code
	ORDER BY fn.code
#####################################################################
CREATE PROCEDURE repSyrianBank1
	@ToDate 	[DATETIME]
	
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_AssetsAccount'
	
	DECLARE @Result TABLE
	( 
		[ID]							INT IDENTITY(1,1),
		[Level]							[INT] DEFAULT 0, 
		[GUID]							[UNIQUEIDENTIFIER], 
		[Code]							[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]							[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[TotalBalance]					[FLOAT]	DEFAULT 0, -- «·—’Ìœ «·⁄«„
		[ResidentBalance]				[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì «·„ﬁÌ„
		[Non_ResidentBalance]			[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì €Ì— «·„ﬁÌ„
		[ResidentForeignBalance]		[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì «·„ﬁÌ„
		[Non_ResidentForeignBalance]	[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì €Ì— «·„ﬁÌ„
		IsBankAccount					[BIT]	DEFAULT 1  -- Â· «·Õ”«» Õ”«» „’—›Ì	
	)
	
	INSERT INTO @Result(GUID, [Level], Code, [Name], [TotalBalance], [ResidentBalance],
		[Non_ResidentBalance], [ResidentForeignBalance], [Non_ResidentForeignBalance], IsBankAccount)
	SELECT 
		fn.GUID,
		fn.[Level],
		fn.Code,
		fn.[Name],
		fn.[TotalBalance], 
		fn.[ResidentBalance],
		fn.[Non_ResidentBalance],
		fn.[ResidentForeignBalance],
		fn.[Non_ResidentForeignBalance],
		CASE WHEN fncodes.Data IS NULL THEN 0 ELSE 1 END
	FROM fnTrnSyBkAccountsBalances(@BaseAccount, 0, '', @ToDate) AS fn
	LEFT JOIN fnTrnGetSyBkAccountsCodesTable(1) AS fncodes ON fncodes.Data = fn.Code
	WHERE fn.Code <> '19999'
	ORDER BY fn.code
	
	--'„Ã„Ê⁄ «·„ÊÃÊœ« '
	--UPDATE @Result
	--SET Code = '19999'
	--WHERE CODE = '1'
	DECLARE @FirstLevel INT
	SELECT @FirstLevel = MIN([Level])
	FROM @Result
	
	INSERT INTO @Result(GUID, Code, [Name], [TotalBalance], [ResidentBalance],
		[Non_ResidentBalance], [ResidentForeignBalance], [Non_ResidentForeignBalance]) 
	SELECT 
		0x0,
		'19999',
		'„Ã„Ê⁄ «·„ÊÃÊœ« ',
		SUM([TotalBalance]),
		SUM([ResidentBalance]),
		SUM([Non_ResidentBalance]),
		SUM([ResidentForeignBalance]),
		SUM([Non_ResidentForeignBalance])
	FROM @Result
	WHERE [Level] = @FirstLevel
	
	SELECT * FROM @Result
	WHERE IsBankAccount = 1
	ORDER BY CODE		
#####################################################################
CREATE PROCEDURE repSyrianBank2
	@ToDate 	[DATETIME]
AS
	SET NOCOUNT ON
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_LiabilitiesAccount'

	DECLARE @Result TABLE
	( 
		[ID]				INT IDENTITY(1,1),
		[Level]				[INT] DEFAULT 0, 
		[GUID]				[UNIQUEIDENTIFIER], 
		[Code]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[TotalBalance]			[FLOAT]	DEFAULT 0, -- «·—’Ìœ «·⁄«„
		[ResidentBalance]		[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì «·„ﬁÌ„
		[Non_ResidentBalance]		[FLOAT]	DEFAULT 0, -- —’Ìœ «·”Ê—Ì €Ì— «·„ﬁÌ„
		[ResidentForeignBalance]	[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì «·„ﬁÌ„
		[Non_ResidentForeignBalance]	[FLOAT] DEFAULT 0, -- —’Ìœ «·√Ã‰»Ì €Ì— «·„ﬁÌ„
		IsBankAccount			BIT	DEFAULT 1 -- Â· «·Õ”«» Õ”«» „’—›Ì	
	)
	
	INSERT INTO @Result(GUID, [Level], Code, [Name], [TotalBalance], [ResidentBalance],
		[Non_ResidentBalance], [ResidentForeignBalance], [Non_ResidentForeignBalance], IsBankAccount)
	SELECT 
		fn.GUID,
		fn.[Level],
		fn.Code,
		fn.[Name],
		-fn.[TotalBalance], 
		-fn.[ResidentBalance],
		-fn.[Non_ResidentBalance],
		-fn.[ResidentForeignBalance],
		-fn.[Non_ResidentForeignBalance],
		CASE WHEN fncodes.Data IS NULL THEN 0 ELSE 1 END
	FROM fnTrnSyBkAccountsBalances(@BaseAccount, 0, '', @ToDate) AS fn
	LEFT JOIN fnTrnGetSyBkAccountsCodesTable(2) AS fncodes ON fncodes.Data = fn.Code
	WHERE fn.Code <> '29999'
	ORDER BY fn.code

	DECLARE @FirstLevel INT
	SELECT @FirstLevel = MIN([Level])
	FROM @Result
	
	DECLARE @SumTotalBalance FLOAT
	SELECT 
		@SumTotalBalance = SUM([TotalBalance])
	FROM @Result
	WHERE [Level] = @FirstLevel
	
 
	DECLARE @AssetsBalance FLOAT
	DECLARE @AssetsBaseAccount UNIQUEIDENTIFIER
	SELECT @AssetsBaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_AssetsAccount'
	
	SELECT 	
		@AssetsBalance = ISNULL((SUM(en.Debit) - SUM(en.Credit))/ 1000, 0)
	FROM en000 AS en
	INNER JOIN Ce000 AS Ce ON ce.Guid = en.ParentGuid
	INNER JOIN [fnGetAccountsList](@AssetsBaseAccount, 1) AS ac ON  ac.Guid = en.AccountGUID
	WHERE en.[Date] <= @ToDate
	
	--select @SumTotalBalance,@AssetsBalance
	--29300			
	DECLARE @Balance_29300 FLOAT
	SET @Balance_29300 = @AssetsBalance - @SumTotalBalance
	UPDATE @Result SET 
		[TotalBalance] = @Balance_29300,
		[ResidentBalance] = @Balance_29300,
		[Level] = @FirstLevel
	WHERE Code = '29300'	
		
	INSERT INTO @Result(GUID, Code, [Name], [TotalBalance], [ResidentBalance],
		[Non_ResidentBalance], [ResidentForeignBalance], [Non_ResidentForeignBalance]) 
	SELECT 
		0x0,
		'29999',
		'„Ã„Ê⁄ «·„ÿ«·Ì» Ê ÕﬁÊﬁ «·„·ﬂÌ…',
		SUM([TotalBalance]),
		SUM([ResidentBalance]),
		SUM([Non_ResidentBalance]),
		SUM([ResidentForeignBalance]),
		SUM([Non_ResidentForeignBalance])
	FROM @Result
	WHERE [Level] = @FirstLevel
	
	SELECT * FROM @Result
	WHERE IsBankAccount = 1
	ORDER BY CODE	
#####################################################################
CREATE PROCEDURE repSyrianBank3
	@ToDate 	[DATETIME]
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_OutOfBudgetAccount'

	SELECT 
		fn.GUID,
		fn.Code,
		fn.[Name],
		fn.[TotalBalance], 
		fn.[ResidentBalance],
		fn.[Non_ResidentBalance],
		fn.[ResidentForeignBalance],
		fn.[Non_ResidentForeignBalance]
	FROM fnTrnSyBkAccountsBalances(@BaseAccount, 0, '', @ToDate) AS fn
	INNER JOIN fnTrnGetSyBkAccountsCodesTable(3) AS fncodes ON fncodes.Data = fn.Code
	ORDER BY fn.code
#####################################################################
CREATE FUNCTION FnSyrianBank12
(
      @Begin datetime,
      @End	 datetime
 )RETURNS @Result TABLE (curguid uniqueidentifier,accguid uniqueidentifier,
       
       BeginBalance float  ,BeginBalanceSY float, -- 0
       
       -- DO nothing «·„»«·€ «·Ê«—œ… ≈·Ï «·Ã„ÂÊ—Ì… «·⁄—»Ì… «·”Ê—Ì…
       InTransfer   float  ,InTransferSY   float, -- 1
       
       -- function ‰ﬁœÌ Ã„ÂÊ „’«—› ’Ì«—›…
       CashBalance  float  ,CashBalanceSY  float, -- 2
       
       -- function ‰ﬁœÌ Ã„ÂÊ „’«—› ’Ì«—›…
       PayBalance  float  ,PayBalanceSY   float, -- 3
     
       -- DO nothing «·„»«·€ «·„⁄«œ  ’œÌ—Â«
       OUTTransfer  float  ,OUTTransferSY  float, -- 4
       
       EndBalance   float, EndBalanceSY   float) -- 5
 
AS
BEGIN

declare @BasicCurrencyGroup uniqueidentifier
select @BasicCurrencyGroup = CAST(VALUE AS [UNIQUEIDENTIFIER]) 
FROM OP000 WHERE NAME  = 'TrnCfg_CurrencyAccount'

--create table #result
      

insert into @result 
      select 
            my.guid,
            ca.accountguid,
            ----------------------------
            0,0,
            ---------------------------
           -- do nothing 
            0,0,
            ---------------------------
           (Buy_CASH_CurrAmount_Public + Buy_CASH_CurrAmount_Bank + Buy_CASH_CurrAmount_Exchanger)  AS  SumBuyCash,  
           (Buy_CASH_Amount_Public + Buy_CASH_Amount_Bank + Buy_CASH_Amount_Exchanger) / 1000  AS SumBuyCashSY,
            -----------------
           (Sell_CASH_CurrAmount_Public + Sell_CASH_CurrAmount_Bank + Sell_CASH_CurrAmount_Exchanger)  AS SumSellCash,
           (Sell_CASH_Amount_Public + Sell_CASH_Amount_Bank + Sell_CASH_Amount_Exchanger) / 1000 AS SumSellCashSY,
            ----------------------------
            -- do nothing 
            0,0,
            --------------------------
           (Buy_Transfer_CurrAmount + Buy_CASH_CurrAmount_Public + Buy_CASH_CurrAmount_Bank + Buy_CASH_CurrAmount_Exchanger) -
           (Sell_CASH_CurrAmount_Public + Sell_CASH_CurrAmount_Bank + Sell_CASH_CurrAmount_Exchanger + Sell_Transfer_CurrAmount) AS endBalance,
           (Buy_Transfer_Amount + Buy_CASH_Amount_Public + Buy_CASH_Amount_Bank + Buy_CASH_Amount_Exchanger) - 
           (Sell_CASH_Amount_Public + Sell_CASH_Amount_Bank + Sell_CASH_Amount_Exchanger + Sell_Transfer_Amount) / 1000 AS endBalanceSY
      From
            my000 as my 
            inner join TrnCurrencyAccount000 as ca on my.guid = ca.currencyguid
            inner join FnRepSyrianBank11(@Begin,@End, 2, 0) as bank11 on ca.currencyguid = bank11.currencyguid
			where   ca.parentguid = @BasicCurrencyGroup
	 ORDER BY my.Number

DECLARE @CurrencyGuid uniqueidentifier
DECLARE @AccountGUID uniqueidentifier

update @result

          SET InTransferSY = ISNULL((select sum(trn.Amount )   
                                                               from trnTransferVoucher000 as trn 
                                                               where trn.SourceBranch IN (select OfGUID from vwTrnOffice where OfbLocal <> 1) 
                                                             AND  trn.exchangeCurrency = @CurrencyGuid 
                                                             AND  trn.date between @Begin  AND @End),0),
                                                
      
            InTransfer = ISNULL((select sum(trn.Amount / trn.exchangeCurrencyVal) 

                                                                 from trnTransferVoucher000 as trn 
                                                                   where trn.SourceBranch IN (select OfGUID from vwTrnOffice where OfbLocal <> 1) 
                                                                 AND  trn.exchangeCurrency = @CurrencyGuid 
                                                                 AND  trn.date between @Begin  AND @End),0),
        
      
       



             OUTTransferSY = ISNULL((select sum(trn.Amount ) 
                                                                 
                                                                 from trnTransferVoucher000 as trn 
                                                                   where trn.DestinationBranch IN (select OfGUID from vwTrnOffice where OfbLocal <> 1) 
                                                                 AND  trn.exchangeCurrency = @CurrencyGuid 
                                                                 AND  trn.date between @Begin  AND @End),0),
      
            OUTTransfer = ISNULL((select sum(trn.Amount / trn.exchangeCurrencyVal) 

                                                                 from trnTransferVoucher000 as trn 
                                                                   where trn.DestinationBranch IN (select OfGUID from vwTrnOffice where OfbLocal <> 1) 
                                                                 AND  trn.exchangeCurrency = @CurrencyGuid 
                                                                 AND  trn.date between @Begin  AND @End),0)

WHERE curguid = @CurrencyGuid 
AND   accguid = @AccountGUID        --End Update
  

RETURN 
END
#####################################################################
CREATE PROCEDURE RepInOutForienCurrencies
      @Begin DATETIME,
      @End DATETIME
as

SET NOCOUNT ON

DECLARE @date2 DATETIME 
SET @date2 = DATEADD(ss,-1,@begin)

SELECT 
	fnCurrent.curguid,
	fnCurrent.accguid,
	fnOld.endbalance AS BeginBalance,
	fnOld.endbalanceSY AS BeginBalanceSY,
	fnCurrent.InTransfer,
	fnCurrent.InTransferSY,
	fnCurrent.CashBalance,
	fnCurrent.CashBalanceSY,
	fnCurrent.PayBalance,
	fnCurrent.PayBalanceSY,
	fnCurrent.OUTTransfer,
	fnCurrent.OUTTransferSY,
	fnCurrent.EndBalance,
	fnCurrent.EndBalanceSY	
FROM FnSyrianBank12('1900',@date2) AS fnOld 
INNER JOIN  FnSyrianBank12(@begin,@end) AS fnCurrent ON fnOld.curguid = fnCurrent.curguid
#####################################################################
CREATE PROCEDURE repTrnSyrianBank9
(
	@BeginingDate     [DATETIME],
	@EndingDate       [DATETIME],
	@PrintAsBank      [BIT]
)
AS
      SET NOCOUNT ON
      
      Declare @SyBankReport9_Account1 [UNIQUEIDENTIFIER],
                  @SyBankReport9_Account2 [UNIQUEIDENTIFIER],
                  @SyBankReport9_Account3 [UNIQUEIDENTIFIER],
                  @SyBankReport9_Account4 [UNIQUEIDENTIFIER],
                  @SyBankReport9_Account5 [UNIQUEIDENTIFIER]
      
      SET @SyBankReport9_Account1 = ISNULL((SELECT CAST(Value As [UNIQUEIDENTIFIER]) FROM op000 WHERE NAME LIKE 'TrnCfg_SyBankReport9_Account1'), 0x0)
      SET @SyBankReport9_Account2 = ISNULL((SELECT CAST(Value As [UNIQUEIDENTIFIER]) FROM op000 WHERE NAME LIKE 'TrnCfg_SyBankReport9_Account2'), 0x0)
      SET @SyBankReport9_Account3 = ISNULL((SELECT CAST(Value As [UNIQUEIDENTIFIER]) FROM op000 WHERE NAME LIKE 'TrnCfg_SyBankReport9_Account3'), 0x0)
      SET @SyBankReport9_Account4 = ISNULL((SELECT CAST(Value As [UNIQUEIDENTIFIER]) FROM op000 WHERE NAME LIKE 'TrnCfg_SyBankReport9_Account4'), 0x0)
      SET @SyBankReport9_Account5 = ISNULL((SELECT CAST(Value As [UNIQUEIDENTIFIER]) FROM op000 WHERE NAME LIKE 'TrnCfg_SyBankReport9_Account5'), 0x0)
      
      CREATE TABLE #Res1 (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBaseCurrBal FLOAT, BeginAccCurrBal FLOAT, EndBaseCurrBal FLOAT, EndAccCurrBal FLOAT)
      CREATE TABLE #Res2 (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBaseCurrBal FLOAT, BeginAccCurrBal FLOAT, EndBaseCurrBal FLOAT, EndAccCurrBal FLOAT)
      CREATE TABLE #Res3 (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBaseCurrBal FLOAT, BeginAccCurrBal FLOAT, EndBaseCurrBal FLOAT, EndAccCurrBal FLOAT)
      CREATE TABLE #Res4 (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBaseCurrBal FLOAT, BeginAccCurrBal FLOAT, EndBaseCurrBal FLOAT, EndAccCurrBal FLOAT)
      CREATE TABLE #Res5 (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, BeginBaseCurrBal FLOAT, BeginAccCurrBal FLOAT, EndBaseCurrBal FLOAT, EndAccCurrBal FLOAT)
     
      CREATE TABLE #Result (CurrencyCode NVARCHAR(100) COLLATE Arabic_CI_AI, 
                        BeginBalance_Acc1 FLOAT, BeginCurrencyBalance_Acc1 FLOAT, EndBalance_Acc1 FLOAT, EndCurrencyBalance_Acc1 FLOAT,
                        BeginBalance_Acc2 FLOAT, BeginCurrencyBalance_Acc2 FLOAT, EndBalance_Acc2 FLOAT, EndCurrencyBalance_Acc2 FLOAT,
                        BeginBalance_Acc3 FLOAT, BeginCurrencyBalance_Acc3 FLOAT, EndBalance_Acc3 FLOAT, EndCurrencyBalance_Acc3 FLOAT,
                        BeginBalance_Acc4 FLOAT, BeginCurrencyBalance_Acc4 FLOAT, EndBalance_Acc4 FLOAT, EndCurrencyBalance_Acc4 FLOAT,
                        BeginBalance_Acc5 FLOAT, BeginCurrencyBalance_Acc5 FLOAT, EndBalance_Acc5 FLOAT, EndCurrencyBalance_Acc5 FLOAT)
      
      IF (@SyBankReport9_Account1 <> 0x0)
            INSERT INTO #Res1 SELECT *  From  dbo.FnTrnGetAccountCurrenciesBalances(@SyBankReport9_Account1, @BeginingDate,@EndingDate)
      IF (@SyBankReport9_Account2 <> 0x0)
            INSERT INTO #Res2 SELECT *  From  dbo.FnTrnGetAccountCurrenciesBalances(@SyBankReport9_Account2, @BeginingDate,@EndingDate)
      IF (@SyBankReport9_Account3 <> 0x0)
            INSERT INTO #Res3 SELECT * From  dbo.FnTrnGetAccountCurrenciesBalances(@SyBankReport9_Account3, @BeginingDate,@EndingDate)
      IF (@SyBankReport9_Account4 <> 0x0)
            INSERT INTO #Res4 SELECT * From  dbo.FnTrnGetAccountCurrenciesBalances(@SyBankReport9_Account4, @BeginingDate,@EndingDate)
      IF (@SyBankReport9_Account5 <> 0x0)
            INSERT  INTO #Res5 SELECT * From  dbo.FnTrnGetAccountCurrenciesBalances(@SyBankReport9_Account5, @BeginingDate,@EndingDate)
	
	  INSERT INTO #Result 
	  SELECT Code, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 
	  FROM my000
		
	/*      
      INSERT INTO #Result 
      SELECT 
		ISNULL(#Res1.CurrencyCode, '') ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 
      FROM #Res1 
		LEFT JOIN #Res2 ON #Res1.CurrencyCode = #Res2.CurrencyCode 
		LEFT JOIN #Res3 ON #Res1.CurrencyCode = #Res3.CurrencyCode 
		LEFT JOIN #Res4 ON #Res1.CurrencyCode = #Res4.CurrencyCode 
		LEFT JOIN #Res5 ON #Res1.CurrencyCode = #Res5.CurrencyCode
      
      UNION
      SELECT ISNULL(#Res2.CurrencyCode, '') ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      FROM #Res1 LEFT JOIN #Res2 ON #Res1.CurrencyCode = #Res2.CurrencyCode LEFT JOIN #Res3 ON #Res1.CurrencyCode = #Res3.CurrencyCode LEFT JOIN #Res4 ON #Res1.CurrencyCode = #Res4.CurrencyCode LEFT JOIN #Res5 ON #Res1.CurrencyCode = #Res5.CurrencyCode
      UNION
      SELECT ISNULL(#Res3.CurrencyCode, '') ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      FROM #Res1 LEFT JOIN #Res2 ON #Res1.CurrencyCode = #Res2.CurrencyCode LEFT JOIN #Res3 ON #Res1.CurrencyCode = #Res3.CurrencyCode LEFT JOIN #Res4 ON #Res1.CurrencyCode = #Res4.CurrencyCode LEFT JOIN #Res5 ON #Res1.CurrencyCode = #Res5.CurrencyCode
      UNION
      SELECT ISNULL(#Res4.CurrencyCode, '') ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      FROM #Res1 LEFT JOIN #Res2 ON #Res1.CurrencyCode = #Res2.CurrencyCode LEFT JOIN #Res3 ON #Res1.CurrencyCode = #Res3.CurrencyCode LEFT JOIN #Res4 ON #Res1.CurrencyCode = #Res4.CurrencyCode LEFT JOIN #Res5 ON #Res1.CurrencyCode = #Res5.CurrencyCode
      UNION
      SELECT ISNULL(#Res5.CurrencyCode, '') ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      FROM #Res1 LEFT JOIN #Res2 ON #Res1.CurrencyCode = #Res2.CurrencyCode LEFT JOIN #Res3 ON #Res1.CurrencyCode = #Res3.CurrencyCode LEFT JOIN #Res4 ON #Res1.CurrencyCode = #Res4.CurrencyCode LEFT JOIN #Res5 ON #Res1.CurrencyCode = #Res5.CurrencyCode
 
      DELETE FROM #Result WHERE CurrencyCode = ''
      */
      
      UPDATE RES 
		SET BeginBalance_Acc1 = #Res1.BeginBaseCurrBal,
			BeginCurrencyBalance_Acc1 = #Res1.BeginAccCurrBal,
			EndBalance_Acc1 = #Res1.EndBaseCurrBal,
			EndCurrencyBalance_Acc1 = #Res1.EndAccCurrBal
      FROM #Result RES
		INNER JOIN #Res1 ON RES.CurrencyCode = #Res1.CurrencyCode
      
      UPDATE RES  
		SET BeginBalance_Acc2 = #Res2.BeginBaseCurrBal,
			BeginCurrencyBalance_Acc2 = #Res2.BeginAccCurrBal,
			EndBalance_Acc2 = #Res2.EndBaseCurrBal,
			EndCurrencyBalance_Acc2 = #Res2.EndAccCurrBal
      FROM #Result RES
		INNER JOIN #Res2 ON RES.CurrencyCode = #Res2.CurrencyCode
      
      UPDATE RES
		SET BeginBalance_Acc3 = #Res3.BeginBaseCurrBal,
			BeginCurrencyBalance_Acc3 = #Res3.BeginAccCurrBal,
			EndBalance_Acc3 = #Res3.EndBaseCurrBal,
			EndCurrencyBalance_Acc3 = #Res3.EndAccCurrBal
      FROM #Result RES
      INNER JOIN #Res3 ON RES.CurrencyCode = #Res3.CurrencyCode
      
      UPDATE RES
		SET BeginBalance_Acc4 = #Res4.BeginBaseCurrBal,
			BeginCurrencyBalance_Acc4 = #Res4.BeginAccCurrBal,
			EndBalance_Acc4 = #Res4.EndBaseCurrBal,
			EndCurrencyBalance_Acc4 = #Res4.EndAccCurrBal
      FROM #Result RES
      INNER JOIN #Res4 ON RES.CurrencyCode = #Res4.CurrencyCode
      
      UPDATE RES
		SET BeginBalance_Acc5 = #Res5.BeginBaseCurrBal,
			BeginCurrencyBalance_Acc5 = #Res5.BeginAccCurrBal,
			EndBalance_Acc5 = #Res5.EndBaseCurrBal,
			EndCurrencyBalance_Acc5 = #Res5.EndAccCurrBal
      FROM #Result RES
      INNER JOIN #Res5 ON RES.CurrencyCode = #Res5.CurrencyCode
  
   IF ( @PrintAsBank = 0 )
   BEGIN
		SELECT 
			my.Number AS Number,
			res.* 
		FROM #Result AS res
		INNER JOIN my000 AS my ON my.Code = res.CurrencyCode
 
		UNION
		
		SELECT 
		    1000 AS Number,
			'All Currencies' AS CurrencyCode,
			SUM(BeginBalance_Acc1) AS BeginBalance_Acc1 , 
			SUM(BeginBalance_Acc1) AS BeginCurrencyBalance_Acc1,
			SUM(EndBalance_Acc1) AS EndBalance_Acc1,  
			SUM(EndBalance_Acc1) AS EndCurrencyBalance_Acc1,
			SUM(BeginBalance_Acc2) AS BeginBalance_Acc2 ,  
			SUM(BeginBalance_Acc2) AS BeginCurrencyBalance_Acc2, 
			SUM(EndBalance_Acc2) AS EndBalance_Acc2,
			SUM(EndBalance_Acc2)AS EndCurrencyBalance_Acc2,
			SUM(BeginBalance_Acc3) AS BeginBalance_Acc3 ,  
			SUM(BeginBalance_Acc3) AS BeginCurrencyBalance_Acc3,  
			SUM(EndBalance_Acc3)AS EndBalance_Acc3,
			SUM(EndBalance_Acc3)AS EndCurrencyBalance_Acc3,
			SUM(BeginBalance_Acc4) AS BeginBalance_Acc4 ,  
			SUM(BeginBalance_Acc4) AS BeginCurrencyBalance_Acc4,  
			SUM(EndBalance_Acc4)AS EndBalance_Acc4,
			SUM(EndBalance_Acc4)AS EndCurrencyBalance_Acc4,
			SUM(BeginBalance_Acc5) AS BeginBalance_Acc5 ,  
			SUM(BeginBalance_Acc5)AS BeginCurrencyBalance_Acc5,
			SUM(EndBalance_Acc5)AS EndBalance_Acc5,
			SUM(EndBalance_Acc5) AS EndCurrencyBalance_Acc5
		FROM #Result
		ORDER BY Number 
	END
	ELSE
	BEGIN 
	    SELECT 
			1 AS Number, * 
		FROM #Result
		WHERE CurrencyCode = 'SYP'

		UNION
	      
		SELECT 
			2 AS Number, * 
		FROM #Result
		WHERE CurrencyCode = 'USD'

		UNION
		
		SELECT 
			3 AS Number, * 
		FROM #Result
		WHERE CurrencyCode = 'EUR'

		UNION

		SELECT 
			4 AS Number, * 
		FROM #Result
		WHERE CurrencyCode = 'GBP'
		UNION

		SELECT
			5 AS Number, 
			'Without Basic Currencies' AS CurrencyCode,
			SUM(BeginBalance_Acc1) AS BeginBalance_Acc1 , 
			SUM(BeginBalance_Acc1) AS BeginCurrencyBalance_Acc1,
			SUM(EndBalance_Acc1) AS EndBalance_Acc1,  
			SUM(EndBalance_Acc1) AS EndCurrencyBalance_Acc1,
			SUM(BeginBalance_Acc2) AS BeginBalance_Acc2 ,  
			SUM(BeginBalance_Acc2) AS BeginCurrencyBalance_Acc2, 
			SUM(EndBalance_Acc2) AS EndBalance_Acc2,
			SUM(EndBalance_Acc2)AS EndCurrencyBalance_Acc2,
			SUM(BeginBalance_Acc3) AS BeginBalance_Acc3 ,  
			SUM(BeginBalance_Acc3) AS BeginCurrencyBalance_Acc3,  
			SUM(EndBalance_Acc3)AS EndBalance_Acc3,
			SUM(EndBalance_Acc3)AS EndCurrencyBalance_Acc3,
			SUM(BeginBalance_Acc4) AS BeginBalance_Acc4 ,  
			SUM(BeginBalance_Acc4) AS BeginCurrencyBalance_Acc4,  
			SUM(EndBalance_Acc4)AS EndBalance_Acc4,
			SUM(EndBalance_Acc4)AS EndCurrencyBalance_Acc4,
			SUM(BeginBalance_Acc5) AS BeginBalance_Acc5 ,  
			SUM(BeginBalance_Acc5)AS BeginCurrencyBalance_Acc5,
			SUM(EndBalance_Acc5)AS EndBalance_Acc5,
			SUM(EndBalance_Acc5) AS EndCurrencyBalance_Acc5
		FROM #Result
		WHERE CurrencyCode NOT IN ('SYP', 'USD', 'EUR', 'GBP') 

		UNION
		
		SELECT 
			6 AS Number,
			'All Currencies' AS CurrencyCode,
			SUM(BeginBalance_Acc1) AS BeginBalance_Acc1 , 
			SUM(BeginBalance_Acc1) AS BeginCurrencyBalance_Acc1,
			SUM(EndBalance_Acc1) AS EndBalance_Acc1,  
			SUM(EndBalance_Acc1) AS EndCurrencyBalance_Acc1,
			SUM(BeginBalance_Acc2) AS BeginBalance_Acc2 ,  
			SUM(BeginBalance_Acc2) AS BeginCurrencyBalance_Acc2, 
			SUM(EndBalance_Acc2) AS EndBalance_Acc2,
			SUM(EndBalance_Acc2)AS EndCurrencyBalance_Acc2,
			SUM(BeginBalance_Acc3) AS BeginBalance_Acc3 ,  
			SUM(BeginBalance_Acc3) AS BeginCurrencyBalance_Acc3,  
			SUM(EndBalance_Acc3)AS EndBalance_Acc3,
			SUM(EndBalance_Acc3)AS EndCurrencyBalance_Acc3,
			SUM(BeginBalance_Acc4) AS BeginBalance_Acc4 ,  
			SUM(BeginBalance_Acc4) AS BeginCurrencyBalance_Acc4,  
			SUM(EndBalance_Acc4)AS EndBalance_Acc4,
			SUM(EndBalance_Acc4)AS EndCurrencyBalance_Acc4,
			SUM(BeginBalance_Acc5) AS BeginBalance_Acc5 ,  
			SUM(BeginBalance_Acc5)AS BeginCurrencyBalance_Acc5,
			SUM(EndBalance_Acc5)AS EndBalance_Acc5,
			SUM(EndBalance_Acc5) AS EndCurrencyBalance_Acc5
		FROM #Result
		ORDER BY Number
	END
#####################################################################
CREATE PROCEDURE SyrianBankRep4And8
	--@FromOpeningEntry	[BIT]	 = 0,
	@ToDate1			DateTime = '1-1-2100',
	@ToDate2			DateTime = '1-1-2100',
	@RepType			INT		 =  4				-- 4 Rep4,	8 Rep8

AS

SET NOCOUNT ON
CREATE TABLE #Result( AccountName		NVARCHAR(100) COLLATE ARABIC_CI_AI,
				      AccountCode		NVARCHAR(100),		
					  BalUntilDate1		FLOAT,
					  BalUntilDate2		FLOAT
					)

	INSERT INTO #Result
	SELECT	Ac.Name,	
			Ac.Code, 
			-fnBalance1.TotalBalance, 
			-fnBalance2.TotalBalance 
	FROM AC000 AS AC 
		INNER JOIN  dbo.fnTrnGetSyBkAccountsCodesTable(@RepType) AS AccountCode ON AC.Code = AccountCode.Data
		INNER JOIN fnTrnSyBkAccountsBalances(0x0, 0, '1-1-1900', @ToDate1) AS fnBalance1 ON fnBalance1.GUID = Ac.GUID
		INNER JOIN fnTrnSyBkAccountsBalances(0x0, 0, '1-1-1900', @ToDate2) AS fnBalance2 ON fnBalance2.GUID = Ac.GUID

-----------------------------------------------------------------------------------------------
--------------------------------------------C A L C U L A T I O N------------------------------
-----------------------------------------------------------------------------------------------
--1 Calc 40400
IF (NOT EXISTS (SELECT * FROM #Result WHERE AccountCode LIKE '40400') AND @RepType = 4)
	INSERT INTO #Result VALUES ('«·≈Ã„«·Ì', '40400', 0, 0)
UPDATE Res 
SET BalUntilDate1 = A.BalUntilDate1 + B.BalUntilDate1 - C.BalUntilDate1,
	BalUntilDate2 = A.BalUntilDate2 + B.BalUntilDate2 - C.BalUntilDate2
FROM #Result	   AS Res
INNER JOIN #Result AS A ON A.AccountCode = '40100'
INNER JOIN #Result AS B ON B.AccountCode = '40200'
INNER JOIN #Result AS C ON C.AccountCode = '40300'
WHERE Res.AccountCode = '40400'

--2 Calc 41000
IF NOT EXISTS (SELECT * FROM #Result WHERE AccountCode LIKE '41000')
	INSERT INTO #Result VALUES ('’«›Ì «·‰ ÌÃ… ﬁ»· «·÷—Ì»…', '41000', 0, 0)
UPDATE Res 
SET BalUntilDate1 = A.BalUntilDate1 - B.BalUntilDate1 + C.BalUntilDate1 - D.BalUntilDate1,
	BalUntilDate2 = A.BalUntilDate2 - B.BalUntilDate2 + C.BalUntilDate2 - D.BalUntilDate2
FROM #Result	   AS Res
INNER JOIN #Result AS A ON A.AccountCode = '40400'
INNER JOIN #Result AS B ON B.AccountCode = '40500'
INNER JOIN #Result AS C ON C.AccountCode = '40600'
INNER JOIN #Result AS D ON D.AccountCode = '40900'
WHERE Res.AccountCode = '41000'

--3 Calc 43000
IF NOT EXISTS (SELECT * FROM #Result WHERE AccountCode LIKE '43000')
	INSERT INTO #Result VALUES ('’«›Ì «·‰ ÌÃ… »⁄œ «·÷—Ì»…', '43000', 0, 0)
UPDATE Res 
SET BalUntilDate1 = A.BalUntilDate1 - B.BalUntilDate1,
	BalUntilDate2 = A.BalUntilDate2 - B.BalUntilDate2
FROM #Result	   AS Res
INNER JOIN #Result AS A ON A.AccountCode = '41000'
INNER JOIN #Result AS B ON B.AccountCode = '42000'
WHERE Res.AccountCode = '43000'

--4 Calc 49999
IF NOT EXISTS (SELECT * FROM #Result WHERE AccountCode LIKE '49999')
	INSERT INTO #Result VALUES ('’«›Ì ‰ ÌÃ… «·› —…', '49999', 0, 0)
UPDATE Res 
SET BalUntilDate1 = A.BalUntilDate1 + B.BalUntilDate1 - C.BalUntilDate1,
	BalUntilDate2 = A.BalUntilDate2 + B.BalUntilDate2 - C.BalUntilDate2
FROM #Result	   AS Res
INNER JOIN #Result AS A ON A.AccountCode = '43000'
INNER JOIN #Result AS B ON B.AccountCode = '44000'
INNER JOIN #Result AS C ON C.AccountCode = '45000'
WHERE Res.AccountCode = '49999'

--------------------------------------------------------------------------------------------------------
------------------------------F I N A L   R E S U L T---------------------------------------------------
--------------------------------------------------------------------------------------------------------
SELECT * FROM #Result ORDER BY AccountCode
#####################################################################
CREATE PROCEDURE repTrnSyrianBank5
	@Final				UNIQUEIDENTIFIER, 
	@incomeFinal		UNIQUEIDENTIFIER, 
	--@PreviousStartDate	DATETIME,
	@FromOpeningEntry	BIT	= 0,
	@PreviousEndDate	DATETIME = '1-1-1900',
	--@StartDate 			DATETIME,   
	@EndDate 			DATETIME = '1-1-2100'

	
AS 
	SET NOCOUNT ON  
	
	DECLARE @StartDate DATETIME,
			@PreviousStartDate DATETIME
	SET @StartDate = ''		
	SET @PreviousStartDate = ''
	   
	CREATE TABLE [#FAcc] ([Guid] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])   
	INSERT INTO [#FAcc] 
	EXEC [prcGetAccountsList] @Final 
	
	DECLARE @AccTable TABLE(
		[GUID] [UNIQUEIDENTIFIER], 
		[FinalGUID] [UNIQUEIDENTIFIER], 
		[Code] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[Name] NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[LatinName] NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		[ParentGUID] [UNIQUEIDENTIFIER],
		BalSheetGUID [UNIQUEIDENTIFIER], 
		CashFlowType INT)
		
		
	INSERT INTO @AccTable
	SELECT  
		ac.[Guid], 
		ac.[FinalGuid] AS [Final],
		ac.[Code],
		ac.[Name],
		ac.[LatinName],
		ac.[ParentGuid], 
		ac.[BalsheetGuid],
		ac.[CashFlowType]
	
	FROM Ac000 AS ac 
		--INNER JOIN dbo.fnGetAccountsList(0X00, 1) AS fnAcc ON fnAcc.GUID = ac.GUID
		INNER JOIN [#FAcc] AS fAcc ON fAcc.Guid = ac.FinalGUID
	
	CREATE TABLE [#T_RESULT] 
	(          
		[Debit] 				[FLOAT] DEFAULT 0,      
		[Credit] 				[FLOAT] DEFAULT 0,
		[BalSheetGuid]				[UNIQUEIDENTIFIER],      
		[BalsheetIsCash]			[INT]	DEFAULT 0, 
		[BalSheetName]				NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[BalSheetParent]			[INT],
		[BalSheetNumber]			[INT], 
		[CashFlowType]				[INT]	DEFAULT 0, 
		[InTime]				[BIT] DEFAULT 1, 
		[accGuid]				UNIQUEIDENTIFIER DEFAULT 0X00,
		[AccName]			NVARCHAR(255) COLLATE ARABIC_CI_AI,
	)  
	-- just one record : income
	INSERT INTO [#T_RESULT] 
	([Debit],[Credit],[BalSheetGuid],[BalsheetIsCash],[BalSheetNumber],[BalSheetName], [CashFlowType],[InTime])  
	SELECT
		Debit / 1000,
		Credit / 1000,
		0x0,
		-1, -- BalsheetIsCash
		0,	-- BalSheetNumber
		'', -- BalSheetName
		0,	-- CashFlowType
		1	-- In time
	FROM fnTrnSyBkGetIncome(@incomeFinal, @StartDate, @EndDate)

	INSERT INTO [#T_RESULT]
	 ([Debit],[Credit],[BalSheetGuid],[BalsheetIsCash],
	 [BalSheetName],[BalSheetParent],[BalSheetNumber],
	 [CashFlowType], [InTime],
	 [accGuid],[accname])  
	SELECT 
		SUM(en.Debit) / 1000,
		SUM(en.Credit) / 1000,
		[BalSheetGuid],
		bs.[IsCash],
		[bs].[Name],
		[bs].[Parent],
		[bs].[Number],
		CASE bs.[IsCash] WHEN 0 THEN [CashFlowType] ELSE 4 END,
		1,
		ac.[GUID],
		ac.[Name]
	FROM en000 AS en
		INNER JOIN Ce000 AS Ce ON ce.GUID = en.ParentGUID
		INNER JOIN @AccTable AS Ac ON Ac.GUID = en.AccountGUID
		INNER JOIN [BalSheet000] AS [bs] ON [bs].[Guid] = [ac].[BalsheetGuid]
	WHERE 
		en.[Date] BETWEEN @StartDate AND @EndDate 
		AND ([CashFlowType]  > 0 OR bs.[IsCash] = 1)
	GROUP BY [bs].[Parent],[BalSheetGuid],bs.[IsCash],[bs].[Name],[bs].[Number],[CashFlowType], ac.GUID, Ac.Name

	--Test IF Balance From Opening Entry 
	IF (@FromOpeningEntry = 0)
	BEGIN
		INSERT INTO [#T_RESULT] 
			( [Debit],[Credit],[BalSheetGuid],[BalsheetIsCash],
			[BalSheetName],[BalSheetParent],[BalSheetNumber],
			[CashFlowType],[InTime],
			[accGuid], [AccName])  
		SELECT 
			SUM(en.[Debit]) / 1000,
			SUM(en.[Credit]) / 1000,
			[BalSheetGuid],
			bs.[IsCash],
			[bs].[Name],
			[bs].[Parent],
			[bs].[Number],
			CASE bs.[IsCash] WHEN 0 THEN [CashFlowType] ELSE 4 END,
			0,
			ac.[GUID],
			ac.[Name]
		FROM En000 AS En 
			 INNER JOIN Ce000 AS Ce ON ce.[GUID] = En.ParentGUID
			INNER JOIN @AccTable AS Ac ON Ac.GUID = en.AccountGUID
			INNER JOIN [BalSheet000] AS [bs] ON [bs].[Guid] = [ac].[BalsheetGuid]
		WHERE  (en.[Date] BETWEEN  @PreviousStartDate AND @PreviousEndDate )
				AND ([CashFlowType]  > 0 OR bs.[IsCash] = 1)
		GROUP BY [bs].[Parent],[BalSheetGuid],[BalSheetGuid],bs.[IsCash],[bs].[Name],[bs].[Number],[CashFlowType],ac.[GUID], Ac.[Name]
	END
	
	ELSE--Balance From Opening Entry 
	BEGIN
		INSERT INTO [#T_RESULT] 
			( [Debit],[Credit],[BalSheetGuid],[BalsheetIsCash],
			[BalSheetName],[BalSheetParent],[BalSheetNumber],
			[CashFlowType],[InTime],
			[accGuid], [AccName])  
		SELECT 
			SUM(ISNULL(OpeningEn.Debit, 0)) / 1000,
			SUM(ISNULL(OpeningEn.Credit, 0)) / 1000,
			[BalSheetGuid],
			[bs].[IsCash],
			[bs].[Name],
			[bs].[Parent],
			[bs].[Number],
			CASE bs.[IsCash] WHEN 0 THEN [CashFlowType] ELSE 4 END,
			0,
			ac.[GUID],
			ac.[Name]
		FROM  @AccTable AS Ac 
			INNER JOIN [BalSheet000] AS [bs] ON [bs].[Guid] = [ac].[BalsheetGuid]
			LEFT JOIN dbo.fnTrnOpeningEntry() AS OpeningEn ON Ac.[GUID] = OpeningEn.AccountGUID	
		WHERE [CashFlowType]  > 0 OR bs.[IsCash] = 1	
		GROUP BY [bs].[Parent],[BalSheetGuid],[BalSheetGuid],bs.[IsCash],[bs].[Name],[bs].[Number],[CashFlowType],ac.[GUID], Ac.[Name]
	END
	
	INSERT INTO [#T_RESULT] 
	([Debit],[Credit],[BalSheetGuid],[BalsheetIsCash],[CashFlowType],[InTime])  
	VALUES(0,0,0x0,	-1, 0, 0)
	--FROM dbo.fnSyBankGetIncome(@incomeFinal, @FromOpeningEntry, @PreviousStartDate, @PreviousEndDate)

	--UPDATE [#T_RESULT] 
		--SET [CashFlowType] = 4
		--[BalSheetParent] = 0,
		--[BalSheetGuid] = 0x0
	--WHERE [BalsheetIsCash] = 1 
	
	SELECT 
		ISNULL([Balance], 0) AS Balance,
		ISNULL([PrevBalance],0) AS [PrevBalance], 
		ISNULL([Total].[CashFlowType], [PrevTotal].[CashFlowType]) AS [CashFlowType] ,
		ISNULL([Total].[BalsheetGuid], [PrevTotal].[BalsheetGuid]) AS [BalsheetGuid],
		ISNULL([Total].[BalSheetNumber], [PrevTotal].BalSheetNumber) AS BalSheetNumber,
		ISNULL([Total].[BalSheetName], [PrevTotal].[BalSheetName]) AS BalSheetName,
		0 AS IsTotal
	FROM  
			(
				SELECT 
					((SUM([Debit]) - SUM([Credit]))) AS [Balance],
					[BalsheetGuid], 
					[CashFlowType],
					[BalSheetNumber],
					[BalSheetName]
				FROM [#T_RESULT] 
				WHERE [InTime] = 1  AND CashFlowType <> 0 -- ’«›Ì «·œŒ· ÂÊ ”Ã· Ê«Õœ
				GROUP BY [BalsheetGuid], [CashFlowType], [BalSheetNumber], [BalSheetName]
			) AS [Total] 
			
			FULL JOIN  
			
			(
				SELECT 
					(SUM([Debit]) - SUM([Credit])) AS [PrevBalance],			 
					[BalsheetGuid], 
					[CashFlowType],
					[BalSheetNumber],
					[BalSheetName]
				FROM [#T_RESULT] 
				WHERE  [InTime] = 0  AND CashFlowType <> 0 -- ’«›Ì «·œŒ· ÂÊ ”Ã· Ê«Õœ
				GROUP BY [BalsheetGuid], [CashFlowType], [BalSheetNumber], [BalSheetName]
			) AS [PrevTotal] 
			ON [Total].[CashFlowType]  = [PrevTotal].[CashFlowType] AND [Total].[BalsheetGuid] = [PrevTotal].[BalsheetGuid] 
	
	UNION ALL
		
	SELECT 
		ISNULL([Total].[Balance], 0) AS Balance,
		ISNULL([PrevTotal].[PrevBalance],0) AS [PrevBalance], 
		ISNULL([Total].[CashFlowType], [PrevTotal].[CashFlowType]) AS [CashFlowType] ,
		0x0 AS [BalsheetGuid] ,
		0 AS BalSheetNumber,
		'',
		1 AS IsTotal
	FROM  
			(
				SELECT 
					((SUM([Debit]) - SUM([Credit]))) AS [Balance],		 
					[CashFlowType]  
				FROM [#T_RESULT] 
				WHERE [InTime] = 1
				GROUP BY [CashFlowType]) AS [Total] 
		FULL JOIN  
			(
				SELECT 
					(SUM([Debit]) - SUM([Credit])) AS [PrevBalance],			 
					[CashFlowType]  
				FROM [#T_RESULT] 
				WHERE  [InTime] = 0 
				GROUP BY [CashFlowType]
			) AS [PrevTotal] 
			ON [Total].[CashFlowType]  = [PrevTotal].[CashFlowType]
	ORDER BY CashFlowType, IsTotal, BalSheetNumber --ISNULL([Bal].[CashFlowType],[Prev].[CashFlowType])  
#####################################################################
CREATE PROCEDURE repSyrianBank7_1
	@FromOpeningEntry	[BIT]		= 0,
	@ToDate1			[DATETIME]	= '1-1-1900',
	@ToDate2			[DATETIME]  = '1-1-2100'
	
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_AssetsAccount'
	
	DECLARE @Result TABLE
	( 
		[ID]			INT IDENTITY(1,1),
		[Level]			[INT] DEFAULT 0, 
		[GUID]			[UNIQUEIDENTIFIER], 
		[Code]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[BalanceUntilDate1]	[FLOAT]	DEFAULT 0,
		[BalanceUntilDate2]	[FLOAT]	DEFAULT 0,
		[IsTotal]		BIT
	)

	INSERT INTO @Result(GUID, [Level], Code, [Name], [BalanceUntilDate1], [BalanceUntilDate2], [IsTotal])
	SELECT 
		fnBalance1.GUID,
		fnBalance1.[Level],
		fnBalance1.Code,
		fnBalance1.[Name],
		fnBalance1.[TotalBalance], 
		fnBalance2.[TotalBalance],
		CASE WHEN fnBalance1.Code IN ('12180', '13180', '14180') THEN 0 ELSE 1 END
	FROM 
		fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate1) AS fnBalance1 
		INNER JOIN fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate2) AS fnBalance2 ON fnBalance2.GUID = fnBalance1.GUID
		INNER JOIN fnTrnGetSyBkAccountsCodesTable(71) AS fncodes ON fncodes.Data = fnBalance1.Code  
	WHERE fnBalance1.Code <> '19999'
	ORDER BY fnBalance1.code
	
	DECLARE @FirstLevel INT
	SELECT @FirstLevel = MIN([Level])
	FROM @Result
	
	INSERT INTO @Result(GUID,Code, [Name], [BalanceUntilDate1], [BalanceUntilDate2], [IsTotal])
	SELECT 
		0x0,
		'19999',
		'„Ã„Ê⁄ «·„ÊÃÊœ« ',
		SUM([BalanceUntilDate1]),
		SUM([BalanceUntilDate2]),
		1
	FROM @Result
	WHERE [Level] = @FirstLevel
	
	SELECT * FROM @Result
#####################################################################
CREATE PROCEDURE repSyrianBank7_2
	@FromOpeningEntry	[BIT]		= 0,
	@ToDate1			[DATETIME]	= '1-1-1900',
	@ToDate2			[DATETIME]  = '1-1-2100'
	
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_LiabilitiesAccount'
	
	DECLARE @Result TABLE
	( 
		[ID]				INT IDENTITY(1,1),
		[Level]				[INT] DEFAULT 0, 
		[GUID]				[UNIQUEIDENTIFIER], 
		[Code]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Name]				[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[BalanceUntilDate1]	[FLOAT]	DEFAULT 0,
		[BalanceUntilDate2]	[FLOAT]	DEFAULT 0,
		[IsTotal]			BIT
	)

	INSERT INTO @Result(GUID, [Level], Code, [Name], [BalanceUntilDate1], [BalanceUntilDate2], [IsTotal])
	SELECT 
		fnBalance1.GUID,
		fnBalance1.[Level],
		fnBalance1.Code,
		fnBalance1.[Name],
		fnBalance1.[TotalBalance], 
		fnBalance2.[TotalBalance],
		CASE WHEN fnBalance1.Code IN ('20000', '21000', '22100', '23000') THEN 1 ELSE 0 END
	FROM 
		fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate1) AS fnBalance1 
		INNER JOIN fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate2) AS fnBalance2 ON fnBalance2.GUID = fnBalance1.GUID
		INNER JOIN fnTrnGetSyBkAccountsCodesTable(72) AS fncodes ON fncodes.Data = fnBalance1.Code  
	WHERE fnBalance1.Code  NOT IN ('29999')
	ORDER BY fnBalance1.code
	
	DECLARE @FirstLevel INT
	SELECT @FirstLevel = MIN([Level])
	FROM @Result

	DECLARE @SumBalance1 FLOAT, @SumBalance2 FLOAT
	SELECT 
		@SumBalance1 = SUM([BalanceUntilDate1]),
		@SumBalance2 = SUM([BalanceUntilDate2])
	FROM @Result
	WHERE [Level] = @FirstLevel
	
	DECLARE @AssetsBalance1 FLOAT, @AssetsBalance2 FLOAT
	DECLARE @AssetsBaseAccount UNIQUEIDENTIFIER
	SELECT @AssetsBaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_AssetsAccount'
		
	SELECT
		@AssetsBalance1 = ISNULL((SUM(en.Debit) - SUM(en.Credit))/ 1000, 0)
	FROM en000 AS en
		INNER JOIN Ce000 AS Ce ON ce.Guid = en.ParentGuid
		INNER JOIN [fnGetAccountsList](@AssetsBaseAccount, 1) AS ac ON  ac.Guid = en.AccountGUID
	WHERE en.[Date] <= @ToDate1

	SELECT
		@AssetsBalance2 = ISNULL((SUM(en.Debit) - SUM(en.Credit))/ 1000, 0)
	FROM en000 AS en
		INNER JOIN Ce000 AS Ce ON ce.Guid = en.ParentGuid
		INNER JOIN [fnGetAccountsList](@AssetsBaseAccount, 1) AS ac ON  ac.Guid = en.AccountGUID
	WHERE en.[Date] <= @ToDate2

	DECLARE @Acc_29300_Balance1 FLOAT, @Acc_29300_Balance2 FLOAT
	SET @Acc_29300_Balance1 = @SumBalance1 - @AssetsBalance1
	SET @Acc_29300_Balance2 = @SumBalance2 - @AssetsBalance2
	
	UPDATE @Result SET
		BalanceUntilDate1 = @Acc_29300_Balance1,
		BalanceUntilDate2 = @Acc_29300_Balance2
	WHERE Code = '29300'	 

	--UPDATE @Result SET
	--	[BalanceUntilDate1] = [BalanceUntilDate1] + @Acc_29300_Balance1,
	--	[BalanceUntilDate2] = [BalanceUntilDate2] + @Acc_29300_Balance2
	--WHERE CODE IN ('2', '29000')
	-- «·Õ”«»«  «·√» ··Õ”«» 29300 Õ· „ƒﬁ  

	INSERT INTO @Result(GUID, Code, [Name], [BalanceUntilDate1], [BalanceUntilDate2], [IsTotal])
	SELECT 
		0x0,
		'29999',
		'„Ã„Ê⁄ «·„ÿ«·Ì» Ê ÕﬁÊﬁ «·„·ﬂÌ…',
		SUM([BalanceUntilDate1]),
		SUM([BalanceUntilDate2]),
		0
	FROM @Result
	WHERE [Level] = @FirstLevel
	
	SELECT * FROM @Result ORDER BY CODE	
#####################################################################	
CREATE PROCEDURE repSyrianBank7_3
	@FromOpeningEntry	[BIT]		= 0,
	@ToDate1			[DATETIME]	= '1-1-1900',
	@ToDate2			[DATETIME]  = '1-1-2100'
	
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_OutOfBudgetAccount'
	
	SELECT 
		fnBalance1.GUID,
		fnBalance1.[Level],
		fnBalance1.Code,
		fnBalance1.[Name],
		fnBalance1.[TotalBalance] AS BalanceUntilDate1, 
		fnBalance2.[TotalBalance] AS BalanceUntilDate2,
		0 AS IsTotal
	FROM 
		fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate1) AS fnBalance1 
		INNER JOIN fnTrnSyBkAccountsBalances(@BaseAccount, @FromOpeningEntry, '', @ToDate2) AS fnBalance2 ON fnBalance2.GUID = fnBalance1.GUID
		INNER JOIN fnTrnGetSyBkAccountsCodesTable(7) AS fncodes ON fncodes.Data = fnBalance1.Code  
	ORDER BY fnBalance1.code
#####################################################################
CREATE PROCEDURE prcSyrianBank_check
	@CheckType	INT = 31
	/*
		1	—„Ê“ «·⁄„·« 
		2	œ·Ì· «·Õ”«»« 
		4	≈⁄œ«œ«  „’—›Ì…
		8	Õ”«»«  ‰„Ê–Ã —ﬁ„ 9
		16	»ÿ«ﬁ… „”«Â„
		31	«·ﬂ·
	*/
AS
	SET NOCOUNT ON
	DECLARE @Result TABLE (
							[InfluencedReps]	NVARCHAR(100) COLLATE ARABIC_CI_AI,
							[ErrMsg]			NVARCHAR(100) COLLATE ARABIC_CI_AI,
							[Code]				NVARCHAR(100),
							[ErrorType]			INT
							)
	
	--—„“ ⁄„·… €Ì— „Ê’› Õ”» «·√Ì“Ê
	IF (@CheckType & 1 = 1)
	BEGIN
		INSERT INTO @Result
		SELECT	'9, 10, 11, 13, 14, 15, 16, 18, 19, 20, 21, 22',
				'—„“ «·⁄„·… ' + Code + ' €Ì— „Ê’› Õ”» «·√Ì“Ê', 
				Code, 
				1
		FROM my000 
		WHERE (SELECT [dbo].[TrnGetCurIsoNumber](Code)) = 999	
	END
	
	--Õ”«»«  ‰«ﬁ’… „‰ œ·Ì· «·Õ”«»« 
	IF (@CheckType & 2 = 2)
	BEGIN
		INSERT INTO @Result
		SELECT  'ﬂ·  ﬁ«—Ì— «·„’—› «·„—ﬂ“Ì „« ⁄œ« 17',
				'—„“ «·Õ”«» ' + CAST(ISNULL(AccDirectory.Data, '') AS NVARCHAR(100)) + ' €Ì— „ÊÃÊœ ÷„‰ œ·Ì· «·Õ”«»« ', 
				CAST(ISNULL(AccDirectory.Data, '') AS NVARCHAR(100)), 
				2
		FROM fnTrnGetSyBkAccountsCodesTable(0) AS AccDirectory 
		LEFT JOIN Ac000 AS AC ON AC.Code = CAST(AccDirectory.Data AS NVARCHAR(100))
		WHERE Ac.GUID IS NULL
	END
	
	--‰ﬁ’ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…
	IF (@CheckType & 4 = 4)
	BEGIN
		--—ﬁ„ «·‘—ﬂ…€Ì— „ÊÃÊœ
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_CompanyNumber' AND Value <> '')
			INSERT INTO @Result	VALUES ('ﬂ· «· ﬁ«—Ì—','—ﬁ„ «·‘—ﬂ… ·œÏ «·„’—› «·„—ﬂ“Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_CompanyNumber', 3)
		--Õ”«»«  —∆Ì”Ì… ‰«ﬁ’…
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_AssetsAccount' AND Value <> '00000000-0000-0000-0000-000000000000')
			INSERT INTO @Result	VALUES ('1, 2', 'Õ”«» «·„ÊÃÊœ«  «·—∆Ì”Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_AssetsAccount', 3)
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_LiabilitiesAccount' AND Value <> '00000000-0000-0000-0000-000000000000')
			INSERT INTO @Result	VALUES ('2', 'Õ”«» «·„ÿ«·Ì» «·—∆Ì”Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_LiabilitiesAccount', 3)
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_IncomeAccount' AND Value <> '00000000-0000-0000-0000-000000000000')
			INSERT INTO @Result	VALUES ('4, 8', 'Õ”«» »Ì«‰ «·œŒ· «·—∆Ì”Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_IncomeAccount', 3)
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_OutOfBudgetAccount' AND Value <> '00000000-0000-0000-0000-000000000000')
			INSERT INTO @Result	VALUES ('3', 'Õ”«» Œ«—Ã «·„Ì“«‰Ì… «·—∆Ì”Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_OutOfBudgetAccount', 3)
		IF NOT EXISTS(SELECT Value FROM op000 WHERE Name LIKE 'TrnCfg_SyBank_NonResidentAccount' AND Value <> '00000000-0000-0000-0000-000000000000')
			INSERT INTO @Result	VALUES ('1, 2, 3', 'Õ”«» €Ì— «·„ﬁÌ„… «·—∆Ì”Ì €Ì— „ÊÃÊœ ›Ì «·≈⁄œ«œ«  «·„’—›Ì…', 'SyBank_NonResidentAccount', 3)
	END
	
	--‰ﬁ’ ›Ì Õ”«»«  ‰„Ê–Ã —ﬁ„ 9
	IF (@CheckType & 8 = 8)
	BEGIN
		IF (SELECT COUNT(Value) FROM op000 WHERE Name LIKE 'TrnCfg_SyBankReport9_Account%' AND Value <> '00000000-0000-0000-0000-000000000000') <> 5
			INSERT INTO @Result	VALUES ('9', '‰ﬁ’ ›Ì Õ”«»«  ‰„Ê–Ã —ﬁ„ 9', 'SyBankReport9_Accounts', 4)
	END
	
	--·« ÌÊÃœ „”«Â„ „⁄—›
	IF (@CheckType & 16 = 16)
	BEGIN
		IF NOT EXISTS(SELECT * FROM TrnParticipator000)
			INSERT INTO @Result	VALUES ('17', '·« ÌÊÃœ „”«Â„ „⁄—›', 'No Participator', 5)
	END
	
	------------------------------------------------------------------------------------
	--------------------------------Final Result----------------------------------------
	------------------------------------------------------------------------------------
	SELECT * FROM @Result ORDER by ErrorType
#####################################################################
CREATE PROCEDURE repTrnSyrianBank6
	@ToDate [DATETIME]
AS
	SET NOCOUNT ON
	
	DECLARE @BaseAccount UNIQUEIDENTIFIER
	SELECT @BaseAccount = CAST([Value] AS UNIQUEIDENTIFIER)
	FROM Op000 WHERE [Name] = 'TrnCfg_SyBank_AssetsAccount'
	
	DECLARE @Result TABLE
	( 
		[Serial]		INT ,
		[RecordName]		[NVARCHAR](100) COLLATE ARABIC_CI_AI, 
		[Capital]		[FLOAT]	DEFAULT 0,
		[Allowance]		[FLOAT]	DEFAULT 0,
		[Reserve1]		[FLOAT]	DEFAULT 0,
		[Reserve2]		[FLOAT]	DEFAULT 0,
		[Reserve3]		[FLOAT]	DEFAULT 0,
		[ProfitsLossesCycle]	[FLOAT]	DEFAULT 0,
		[Exchange]	[FLOAT]	DEFAULT 0,
		[Evaluation]	[FLOAT]	DEFAULT 0,
		[ProfitLosses]		[FLOAT]	DEFAULT 0
	)
	
	DECLARE @acc_Capital 	UNIQUEIDENTIFIER,
		@acc_Allowance 		UNIQUEIDENTIFIER,
		@acc_Reserve1 		UNIQUEIDENTIFIER,
		@acc_Reserve2 		UNIQUEIDENTIFIER,
		@acc_Reserve3 		UNIQUEIDENTIFIER,
		@acc_Cycle 			UNIQUEIDENTIFIER,
		@acc_ProfitLosses 	UNIQUEIDENTIFIER,
		@acc_ProfitExchange UNIQUEIDENTIFIER,
		@acc_LosessExchange UNIQUEIDENTIFIER,
		@acc_ProfitEval 	UNIQUEIDENTIFIER,
		@acc_LosessEval 	UNIQUEIDENTIFIER
	
	SELECT 	@acc_Capital = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29900'
	SELECT 	@acc_Allowance = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29700'
	SELECT 	@acc_Reserve1 = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29610'
	SELECT 	@acc_Reserve2 = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29620'
	SELECT 	@acc_Reserve3 = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29630'
	SELECT 	@acc_Cycle = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29400'
	SELECT  @acc_ProfitExchange = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '40110'
	SELECT  @acc_LosessExchange = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '40120'
	SELECT  @acc_ProfitEval = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '40130'
	SELECT  @acc_LosessEval = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '40140'
	SELECT 	@acc_ProfitLosses = ISNULL(GUID, 0x0) FROM AC000 WHERE CODE = '29100'

	INSERT INTO @Result(Serial, RecordName)	VALUES(1, '«·—’Ìœ ›Ì √Ê· «·”‰… ')
	UPDATE @Result SET
		Capital = dbo.fnTrnOpeningEntryAccountBalance(@acc_Capital) / 1000  * -1,
		Allowance = dbo.fnTrnOpeningEntryAccountBalance(@acc_Allowance) / 1000,
		Reserve1 = dbo.fnTrnOpeningEntryAccountBalance(@acc_Reserve1) / 1000,
		Reserve2 = dbo.fnTrnOpeningEntryAccountBalance(@acc_Reserve2) / 1000,
		Reserve3 = dbo.fnTrnOpeningEntryAccountBalance(@acc_Reserve3) / 1000,
		ProfitsLossesCycle = dbo.fnTrnOpeningEntryAccountBalance(@acc_Cycle) / 1000,
		ProfitLosses = dbo.fnTrnOpeningEntryAccountBalance(@acc_ProfitLosses) / 1000
	WHERE Serial = 1
			
	DECLARE @Balance FLOAT
	INSERT INTO @Result(Serial, RecordName)	VALUES(2, '«·“Ì«œ… («ﬂ  «»« ) ›Ì —√” «·„«·')
	INSERT INTO @Result(Serial, RecordName)	VALUES(3, '⁄·«Ê… (Œ’„) «’œ«—')
	INSERT INTO @Result(Serial, RecordName)	VALUES(4, ' Œ’Ì’ √—»«Õ √Ê ( «·Œ”«∆—)«·œÊ—… «·„«·Ì…')
	UPDATE @Result SET
		ProfitsLossesCycle = (SELECT ProfitsLossesCycle * -1 FROM @Result WHERE Serial = 6),
		Exchange = (dbo.fnTrnAccountBalance(@acc_ProfitExchange, '', @ToDate) + dbo.fnTrnAccountBalance(@acc_LosessExchange, '', @ToDate)) / 1000, 
		Evaluation = (dbo.fnTrnAccountBalance(@acc_ProfitEval, '', @ToDate) + dbo.fnTrnAccountBalance(@acc_LosessEval, '', @ToDate)) / 1000 
	WHERE Serial = 4

	INSERT INTO @Result(Serial, RecordName)	VALUES(5, '«·„ÕÊ· ≈·Ï «·≈Õ Ì«ÿÌ« ')

	INSERT INTO @Result(Serial, RecordName)	VALUES(6, '«·„ÕÊ· ≈·Ï «·‰ «∆Ã «·„œÊ—…')
	UPDATE @Result SET
		ProfitsLossesCycle = dbo.fnTrnAccountBalance(@acc_Cycle, '', @ToDate)
	WHERE Serial = 6	

	INSERT INTO @Result(Serial, RecordName)	VALUES(7, '«·„ÕÊ· ≈·Ï «·√—»«Õ ·· Ê“Ì⁄')	
	INSERT INTO @Result(Serial, RecordName)	VALUES(8, '√—»«Õ (Œ”«∆—) ≈⁄«œ… «· Œ„Ì‰')
	
	INSERT INTO @Result(Serial, RecordName, Capital, Allowance, Reserve1, Reserve2, Reserve3, 
			ProfitsLossesCycle, Exchange, Evaluation, ProfitLosses)	
	SELECT
		9, 
		'«·—’Ìœ ›Ì «Œ— «·”‰…',
		SUM(Capital),
		SUM(Allowance),
		SUM(Reserve1),
		SUM(Reserve2),
		SUM(Reserve3),
		SUM(ProfitsLossesCycle),
		SUM(Exchange),
		SUM(Evaluation),
		SUM(ProfitLosses)
	FROM @Result

	SELECT * FROM @Result ORDER BY Serial
#####################################################################	
CREATE PROC syrianBank24
	@ToDate DATETIME
AS
	DECLARE @Result TABLE
		(	Number 		INT, 
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			State 		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			BankRating	NVARCHAR(100) COLLATE ARABIC_CI_AI,
			ApprovalNumber 	NVARCHAR(100) COLLATE ARABIC_CI_AI,
			ApprovalDate 	DATETIME,
			AccountType 	NVARCHAR(100) COLLATE ARABIC_CI_AI,
			CurrencyBalance FLOAT,
			Balance 	FLOAT,
			CurrencyCode	NVARCHAR(50) COLLATE ARABIC_CI_AI,	
			RateOfCapital	FLOAT,
			RateOver30	FLOAT
		)
	DECLARE @Cpaital FLOAT

	SELECT @Cpaital = SUM(en.Debit) - SUM(en.Credit) 
	FROM En000 AS en
		INNER JOIN Ce000 AS ce ON ce.Guid = en.ParentGuid
		INNER JOIN Ac000 AS ac ON ac.Guid = en.AccountGuid
	WHERE Ac.Code = '29900'
	
	INSERT INTO @Result(Number, [Name], State, BankRating, ApprovalNumber, ApprovalDate, 
		AccountType, CurrencyBalance, Balance, CurrencyCode)
	SELECT 
		ofice.Number,
		ofice.[Name],
		ofice.State,
		'',
		0,

		GetDate(),
		'Ã«—Ì',
		dbo.fnTrnCurrencyAccountBalance(ac.GUID, '1-1-1980', @ToDate),
		dbo.fnTrnAccountBalance(ac.GUID, '1-1-1980', @ToDate),
		my.Code
	FROM 
		TrnOffice000 AS ofice
		INNER JOIN Ac000 AS ac ON ac.GUID = ofice.AccGUID
		INNER JOIN My000 AS my ON ac.CurrencyGUID = my.GUID


	UPDATE @Result SET
		RateOfCapital = (Balance / @Cpaital) * 100,
		RateOver30 =  CASE WHEN RateOfCapital < 30 THEN 0 ELSE RateOfCapital - 30 END		
#####################################################################					
#END
			