##################################################################
CREATE  PROC prcExchangeDaily
	@CurrencyGuid  UNIQUEIDENTIFIER ,
	@StartDate DATETIME,
	@EndDate DATETIME,
	@SourceRepGuid UNIQUEIDENTIFIER,
	@ShowOperation INT,
	@ShowSimpleOrBill INT,--0 Bill,  1 Simple , 2 Both , 3 nothing
	@CustContain  NVARCHAR(255),
	@IdentityContain  NVARCHAR(255),
	@NoteContain  NVARCHAR(255),
	@NoteNotContain  NVARCHAR(255),
	@CustomerType INT = 3,
	--   Ã„Ì⁄ Õ”» «·⁄„·Ì… √Ê Õ”» «·⁄„·… √Ê Õ”» «·⁄„·Ì… Ê«·⁄„·… √Ê »œÊ‰  Ã„Ì⁄
	@Grouping int = 0, -- 0 currency, 1 operation, 2 currency and operation, 3 nothig 
	@ProcessStatus int, -- 0:All, 1:Executed, 2:Canceled
	@UserGuid uniqueidentifier = 0x0
AS
	SET NOCOUNT ON	
	SET QUOTED_IDENTIFIER ON	

	DECLARE @IsArabicLang INT 
	SELECT @IsArabicLang = [dbo].fnConnections_GetLanguage()
	
	-- MoveType 0 Sell , 1 Purchase 
	DECLARE @Result TABLE 
	(
		MoveType INT ,
		MoveDESC NVARCHAR(255) COLLATE ARABIC_CI_AI ,
		[Date]	DateTime,
		EntryNumber FLOAT(53),
		EntryGuid UNIQUEIDENTIFIER,
		exNumber int,
		ExGuid  UNIQUEIDENTIFIER,
		Note NVARCHAR(250) COLLATE ARABIC_CI_AI ,
		CurrencyGUID UNIQUEIDENTIFIER,
		CurrencyCode NVARCHAR(25) COLLATE ARABIC_CI_AI ,
		CurrencyName NVARCHAR(255) COLLATE ARABIC_CI_AI ,
		CurrencyVal Float,
		Amount Float,
		ContraCurCode NVARCHAR(25) COLLATE ARABIC_CI_AI ,
		ContraCurName NVARCHAR(255) COLLATE ARABIC_CI_AI ,
		ContraCurVal FLOAT,
		ContraCurAmount FLOAT,
		CustomerType INT,
		CustomerName  NVARCHAR(250) COLLATE ARABIC_CI_AI ,
		CustomerIdentityNo  NVARCHAR(250) COLLATE ARABIC_CI_AI,
		IsSimple INT,
		IsCanceled	BIT default(0),
		UserGuid	UNIQUEIDENTIFIER DEFAULT(0x0)
	)	

	IF (@ShowOperation = 2 OR  @ShowOperation = 0)
	BEGIN
		INSERT INTO @Result( MoveType, MoveDESC, [Date], EntryNumber, EntryGuid,
				exNumber, ExGuid, Note, CurrencyGUID, CurrencyCode, CurrencyName,
				CurrencyVal, Amount, ContraCurCode, ContraCurName, ContraCurVal,
				ContraCurAmount, CustomerType, CustomerName, CustomerIdentityNo, IsSimple, IsCanceled, UserGuid)
		SELECT
			0, 	
			CASE @IsArabicLang
				WHEN 0 Then 
					T.Abbrev + ': ' + Cast(Ex.Number AS NVARCHAR(10)) 
				ELSE 
					T.LatinAbbrev + ': ' + Cast(Ex.Number AS NVARCHAR(10)) 
				END,
			ex.[date],
			ce.[Number],
			ce.[guid],
			ex.[number],
			Ex.[Guid] ,
			ex.[NOTE],
			CASE ex.bSimple WHEN 1 THEN ex.CashCurrency ELSE Detail.CurrencyGuid END,
			My.[myCODE],
			My.[myName],
			CASE ex.bSimple WHEN 1 THEN ex.CashCurrencyVal ELSE Detail.CurrencyVal END,		
			CASE ex.bSimple WHEN 1 THEN (CASE RoundDir WHEN 1 THEN (ex.CashAmount )
								  ELSE ((ex.CashAmount + (ex.RoundValue * ex.CashCurrencyVal) ) )END)
					ELSE Detail.Amount
			END,
			My2.[myCODE],
			My2.[myName],
			CASE ex.bSimple WHEN 1 THEN ex.payCurrencyVal ELSE 1 END,
			CASE ex.bSimple WHEN 1 THEN (CASE ex.RoundDir WHEN 0 THEN (ex.payAmount / ex.payCurrencyVal)
				                                      ELSE ((ex.payAmount + (ex.RoundValue * ex.payCurrencyVal)) /ex.payCurrencyVal )END)
					ELSE Detail.Amount
			END,	
			ex.customerType,
			ex.CustomerName,
			ex.CutomerIdentityNo,
			ex.bSimple,
			CASE ISNULL(ex.cancelEntryGuid, 0x0)
				WHEN 0X0 THEN 0
				ELSE 1
			END,
			ex.UserGuid
		FROM ce000 AS ce 
			INNER JOIN vtTrnExchange as Ex on Ex.EntryGuid = Ce.Guid AND (ex.bSimple = @ShowSimpleOrBill OR @ShowSimpleOrBill = 2)
			INNER JOIN RepSrcs as ExType on ExType.IdType = Ex.typeGuid 
			INNER JOIN VwTrnExchangeTypes as T ON T.Guid = Ex.TypeGuid
			LEFT  JOIN TrnExchangeDetail000 as Detail ON Detail.ExchangeGuid = Ex.Guid AND Detail.Type = 0
			INNER JOIN VWMY AS my on my.myguid = (CASE Ex.bSimple WHEN 1 THEN ex.Cashcurrency ELSE Detail.CurrencyGuid END)
			INNER JOIN VwMy as my2 on my2.myguid = (CASE Ex.bSimple WHEN 1 THEN ex.paycurrency ELSE (SELECT TOP 1 GUID FROM MY000 WHERE CurrencyVal = 1) END)
		WHERE 
			Ex.[Date] BETWEEN @StartDate AND @EndDate  
			AND (@ProcessStatus = 0 OR (@ProcessStatus = 1 AND EX.CancelEntryGuid = 0x0) OR (@ProcessStatus = 2 AND EX.CancelEntryGuid <> 0x0))
			AND (ex.UserGuid = @UserGuid OR @UserGuid = 0x0)	
				AND (@CurrencyGuid = 0x0 OR CashCurrency = @CurrencyGuid )
				AND ExType.IdTbl = @SourceRepGuid
				AND (@CustomerType = 3 OR CustomerType = @CustomerType)
				AND (@CustContain = '' OR CustomerName LIKE '%' + @CustContain + '%')
				AND (@IdentityContain = '' OR CutomerIdentityNo LIKE '%' + @IdentityContain + '%')	
				AND (@NoteContain = '' OR Note LIKE '%' + @NoteContain + '%')	
				AND (@NoteNotContain = '' OR Note NOT LIKE '%' + @NoteNotContain + '%')	
	END
	IF (@ShowOperation = 2 OR  @ShowOperation = 1)
	BEGIN
		INSERT INTO @Result( MoveType, MoveDESC, [Date], EntryNumber, EntryGuid,
				exNumber, ExGuid, Note, CurrencyGUID, CurrencyCode, CurrencyName,
				CurrencyVal, Amount, ContraCurCode, ContraCurName, ContraCurVal,
				ContraCurAmount, CustomerType, CustomerName, CustomerIdentityNo, IsSimple, IsCanceled, UserGuid)
		SELECT
			1, 	
			CASE @IsArabicLang
				WHEN 0 Then 
					T.Abbrev + ': ' + Cast(Ex.Number as NVARCHAR(10)) 
				ELSE 
					T.LatinAbbrev + ': ' + Cast(Ex.Number as NVARCHAR(10)) 
				END,
			ex.[date],
			ce.[Number],
			ce.[guid],
			ex.[number],
			Ex.[Guid] ,
			ex.[NOTE],
			CASE ex.bSimple WHEN 1 THEN ex.PayCurrency ELSE Detail.CurrencyGuid END,
			My.[myCODE],
			My.[myName],
			CASE ex.bSimple WHEN 1 THEN ex.PayCurrencyVal ELSE Detail.CurrencyVal END,		
			CASE ex.bSimple WHEN 1 THEN (CASE RoundDir WHEN 0 THEN (ex.PayAmount)
								   ELSE ((ex.PayAmount + (ex.RoundValue * ex.PayCurrencyVal)) )END)
					ELSE Detail.Amount
			END,
			My2.[myCODE],
			My2.[myName],
			CASE ex.bSimple WHEN 1 THEN ex.CashCurrencyVal ELSE 1 END,
			CASE ex.bSimple WHEN 1 THEN (CASE ex.RoundDir WHEN 1 THEN (ex.CashAmount / ex.CashCurrencyVal)
				                                      ELSE ((ex.CashAmount + (ex.RoundValue * ex.CashCurrencyVal)) / ex.CashCurrencyVal)END)
					ELSE Detail.Amount
			END,
			ex.customerType,
			ex.CustomerName,
			ex.CutomerIdentityNo,
			ex.bSimple,
			CASE ISNULL(ex.CancelEntryGuid, 0x0)
				WHEN 0x0 THEN 0
				ELSE 1
			END,
			Ex.UserGuid
		FROM ce000 AS ce 
			INNER JOIN vtTrnExchange as Ex on Ex.EntryGuid = Ce.Guid AND (ex.bSimple = @ShowSimpleOrBill OR @ShowSimpleOrBill = 2)
			INNER JOIN RepSrcs as ExType on ExType.IdType = Ex.typeGuid 
			INNER JOIN VwTrnExchangeTypes as T ON T.Guid = Ex.TypeGuid
			LEFT  JOIN TrnExchangeDetail000 as Detail ON Detail.ExchangeGuid = Ex.Guid AND Detail.Type = 1
			INNER JOIN VWMY AS my on my.myguid = (CASE Ex.bSimple WHEN 1 THEN ex.paycurrency ELSE Detail.CurrencyGuid END)
			INNER JOIN VwMy as my2 on my2.myguid = (CASE Ex.bSimple WHEN 1 THEN ex.Cashcurrency ELSE (SELECT TOP 1 GUID FROM MY000 WHERE CurrencyVal = 1) END)
		WHERE 
			Ex.[Date] BETWEEN @StartDate AND @EndDate  
			AND (@ProcessStatus = 0 OR (@ProcessStatus = 1 AND EX.CancelEntryGuid = 0x0) OR (@ProcessStatus = 2 AND EX.CancelEntryGuid <> 0x0))
			AND (ex.UserGuid = @UserGuid OR @UserGuid = 0x0)
				AND (@CurrencyGuid = 0x0 OR payCurrency = @CurrencyGuid )
				AND ExType.IdTbl = @SourceRepGuid
				AND (@CustomerType = 3 OR CustomerType = @CustomerType)
				AND (@CustContain = '' OR CustomerName LIKE '%' + @CustContain + '%')
				AND (@IdentityContain = '' OR CutomerIdentityNo LIKE '%' + @IdentityContain + '%')	
				AND (@NoteContain = '' OR Note LIKE '%' + @NoteContain + '%')	
				AND (@NoteNotContain = '' OR Note NOT LIKE '%' + @NoteNotContain + '%')	
	END	
	IF (@Grouping = 0) --grouping by currency 
	BEGIN	
			SELECT 
				R.* 
			FROM @Result AS R
			INNER JOIN VwMy as MY on MY.myGuid = R.CurrencyGuid
			ORDER BY MY.mynumber, R.[Date]
	END
	ELSE	
	IF (@Grouping = 1)  -- grouping by operation
	BEGIN	

			SELECT * FROM @Result
			ORDER BY MoveType , [Date]
	END
	ELSE
	IF (@Grouping = 2) --grouping by currency and operaion
	BEGIN
			SELECT 
				R.* 
			FROM @Result AS R
			INNER JOIN VwMy as MY on MY.myGuid = R.CurrencyGuid
			ORDER BY MY.mynumber, R.[MoveType]
	END
	ELSE --»œÊ‰ --3 
	BEGIN
			SELECT * FROM @Result
			ORDER BY [Date], exNumber, MoveType
	END

##################################################################
CREATE PROC prcExchangeMove
	@StartDate DATETIME,
	@EndDate DATETIME,
	@SourceRepGuid UNIQUEIDENTIFIER,
	@CustContain  NVARCHAR(255)='',
	@IdentityContain  NVARCHAR(255)='',
	@CustomerType INT = 3,
	@ProcessStatus int =0, -- 0:All, 1:Executed, 2:Canceled
	@UserGuid uniqueidentifier = 0x0
	--,@i int
AS
	SET NOCOUNT ON	
	SET QUOTED_IDENTIFIER ON	

	DECLARE @IsArabicLang INT 
	SELECT @IsArabicLang = [dbo].fnConnections_GetLanguage()
	
	SELECT	
		Ex.[Guid]  ExGuid,
		ex.Number ExNumber,
		ex.[date] Date,
		CASE @IsArabicLang
			WHEN 0 Then 
				T.Abbrev + ': ' + Cast(Ex.Number AS NVARCHAR(10)) 
			ELSE 
				T.LatinAbbrev + ': ' + Cast(Ex.Number AS NVARCHAR(10)) 
			END AS MoveDESC,
		ce.[Number] EntryNumber,
		ce.[guid] EntryGuid,
		ex.customerType,
		ex.CashAmount/ex.CashCurrencyVal cashAmount,
		CASE @IsArabicLang
			WHEN 0 Then 
			myCash.myName
			ELSE
				myCash.myLatinName
			END CashCurrencyName,
		ex.CashCurrencyVal,
		ex.PayAmount/ex.PayCurrencyVal payAmount,
		CASE @IsArabicLang
			WHEN 0 Then 
			myPay.myName
			ELSE
				myPay.myLatinName
			END payCurrencyName,
		ex.PayCurrencyVal,
		ex.[NOTE],
		CASE ISNULL(ex.cancelEntryGuid, 0x0)
			WHEN 0X0 THEN 0
			ELSE 1
		END stateOp,
		ex.UserGuid,
		ex.CustomerName,
		cust.FatherName,
		cust.LastName,
		cust.MotherName,
		cust.Phone,
		cust.Address,
		cust.IdentityType IdentityType,
		ex.CutomerIdentityNo CustomerIdentityNo,
		cust.Nation,
		cust.IdentityPlace,
		cust.IdentityDate,
		cust.BirthPlace,
		cust.BirthDate,
		ex.CommissionAmount,
		ex.CommissionRatio,
		(SELECT CASE @IsArabicLang
			WHEN 0 Then 
			myName
			ELSE
				myLatinName
			END FROM VWMY
			WHERE myGUID=ex.CommissionCurrency) CommissionCurrency,
		(SELECT 
				CASE @IsArabicLang
				WHEN 0 Then 
					Name
				ELSE
					LastName
				END
				FROM br000 
			WHERE 
			GUID=ex.BranchGuid) BranchName,
			ex.CashCurrency,
			ex.PayCurrency,
			ex.RoundDir,
			ex.RoundValue,
			ex.Reason
			
	FROM ce000 AS ce 
		INNER JOIN vtTrnExchange as Ex on Ex.EntryGuid = Ce.Guid 
		INNER JOIN RepSrcs as ExType on ExType.IdType = Ex.typeGuid 
		INNER JOIN VwTrnExchangeTypes as T ON T.Guid = Ex.TypeGuid
		LEFT JOIN TrnCustomer000 cust on cust.Guid=ex.CustomerGuid
		INNER JOIN VWMY AS myCash on myCash.myguid =  ex.Cashcurrency 
		INNER JOIN VwMy as myPay on myPay.myguid = ex.paycurrency 
	WHERE 
		Ex.[Date] BETWEEN @StartDate AND @EndDate  
		AND (@ProcessStatus = 0 OR (@ProcessStatus = 1 AND EX.CancelEntryGuid = 0x0) OR (@ProcessStatus = 2 AND EX.CancelEntryGuid <> 0x0))
		AND (ex.UserGuid = @UserGuid OR @UserGuid = 0x0)	
		
			AND ExType.IdTbl = @SourceRepGuid
			AND (@CustomerType = 3 OR CustomerType = @CustomerType)
			AND (@CustContain = '' OR CustomerName LIKE '%' + @CustContain + '%')
			AND (@IdentityContain = '' OR CutomerIdentityNo LIKE '%' + @IdentityContain + '%')	
	ORDER BY 
			ex.Date,
			ex.Number
##################################################################
#END