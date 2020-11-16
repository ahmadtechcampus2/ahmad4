###############################################################################
CREATE FUNCTION fnBP_GetFixedSumPays(@GUID UNIQUEIDENTIFIER, @CurGUID UNIQUEIDENTIFIER = 0x0)
	RETURNS FLOAT 
AS BEGIN 
	IF ISNULL(@CurGUID, 0x0) = 0x0
	BEGIN 
		DECLARE @AccountGUID UNIQUEIDENTIFIER
		SELECT TOP 1 @AccountGUID = AccountGUID FROM en000 WHERE GUID = @GUID
		SET @CurGUID = (SELECT CurrencyGUID FROM ac000 WHERE GUID = @AccountGUID)
	END
	RETURN (
		ISNULL((SELECT 
			SUM([FixedBpVal])
		FROM 
			[fnBp_Fixed](@CurGUID, 1)
		WHERE 
			[bpDebtGUID] = @GUID OR BpPayGUID = @GUID), 0)
	) 
END
###############################################################################
CREATE FUNCTION fnBP_GetFixedPays(@GUID UNIQUEIDENTIFIER, @CurGUID UNIQUEIDENTIFIER)
	RETURNS @Result TABLE(SumVal FLOAT) 
AS BEGIN 
	INSERT INTO @Result
	SELECT ISNULL((SELECT
			SUM([FixedBpVal])
		FROM 
			[fnBp_Fixed](@CurGUID, 1)
		WHERE 
			[bpDebtGUID] = @GUID OR BpPayGUID = @GUID), 0)
	RETURN
END
###############################################################################
CREATE FUNCTION fnOrder_CanRelatePay(@GUID UNIQUEIDENTIFIER)
	RETURNS BIT
AS BEGIN 
	DECLARE @CanPay BIT = 1
	IF EXISTS (
		SELECT * 
		FROM 
			bp000 bp
			INNER JOIN ori000 ori on ori.BuGUID = bp.DebtGUID OR ori.BuGUID = bp.PayGUID
			INNER JOIN vwOrderPayments orp ON orp.BillGuid = ori.POGUID
		WHERE 
			orp.PaymentGUID = @GUID)
			SET @CanPay = 0
	RETURN @CanPay
END
###############################################################################
CREATE FUNCTION fnBill_CanRelatePay(@GUID UNIQUEIDENTIFIER)
	RETURNS BIT
AS BEGIN 
	DECLARE @CanPay BIT = 1
	IF EXISTS (
		SELECT * 
		FROM 
			bp000 as b
			INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID OR  p.PaymentGuid = b.PayGUID
			INNER JOIN ori000 ori ON p.BillGuid = ori.POGUID
		WHERE ori.BuGUID = @GUID)
			SET @CanPay = 0
	RETURN @CanPay
END
###############################################################################
CREATE PROC prcCurrency_Fix
	@Value FLOAT,
	@OldCurrencyGUID UNIQUEIDENTIFIER,
	@OldCurrencyValue FLOAT,
	@NewCurrencyGUID UNIQUEIDENTIFIER,
	@Date DATE = NULL
AS 
	SET NOCOUNT ON 
	
	SELECT [dbo].[fnCurrency_fix](@Value, @OldCurrencyGUID, @OldCurrencyValue, @NewCurrencyGUID, @Date) AS [Value]
###############################################################################
CREATE PROC prcBP_GetPays
	@AccountGUID UNIQUEIDENTIFIER,
	@CustomerGUID UNIQUEIDENTIFIER,
	@IsDebit BIT,
	@IsAllSources BIT = 1,
	@SrcGuid UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE 
		@CurGUID	UNIQUEIDENTIFIER,
		@Zero		FLOAT,
		@lang		INT,
		@EntryStr	NVARCHAR(250),
		@UserGUID	UNIQUEIDENTIFIER,
		@UserSecurity [INT] 
	
	CREATE TABLE [#BillTbl] ([Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])    
	CREATE TABLE [#EntryTbl] ([Type] [UNIQUEIDENTIFIER], [Security] [INT])

	SELECT @CurGUID = CurrencyGUID FROM ac000 WHERE GUID = @AccountGUID
	SELECT @lang = [dbo].[fnConnections_GetLanguage]()
	SET @Zero = [dbo].[fnGetZeroValuePrice]()
	SET @EntryStr = dbo.fnStrings_get('Entry', DEFAULT)
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	SET @UserSecurity = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT) 

	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID
	INSERT INTO [#EntryTbl] SELECT [Type], [Security] FROM [#BillTbl] 
	CREATE TABLE [#SecViol]( [Type] [INT],[Cnt] [INTEGER])  

	CREATE TABLE #Result(PayGUID UNIQUEIDENTIFIER, PayDesc NVARCHAR(500), PayDate DATETIME, 
		TotalValue FLOAT, PaidValue FLOAT, ParentGUID UNIQUEIDENTIFIER, PayType INT /*0: Entry, 1: Payment, 2: Bill, 3: Order, 4: Cheque*/,
		[Security] [INT], [UserSecurity] [INT], OriginNumber INT, Number INT, SortNumber INT, ClassStr NVARCHAR(500),
		CostName NVARCHAR(500), CostLatinName NVARCHAR(500), Notes NVARCHAR(500))

	INSERT INTO #Result(PayGUID, PayDesc, PayDate, TotalValue, PaidValue, ParentGUID, PayType, [Security], [UserSecurity], OriginNumber, Number, SortNumber, ClassStr, CostName, CostLatinName, Notes)
	SELECT 
		en.enGUID,
		@EntryStr + ': ' + CAST(en.ceNumber AS NVARCHAR(10)),
		en.enDate,
		([en].[FixedEnCredit]) + [en].[FixedEnDebit],
		ISNULL([fn].[SumVal], 0),
		ISNULL(erParentGUID, en.ceGUID),
		0,
		[en].[ceSecurity],
		@UserSecurity,
		en.ceNumber,
		en.enNumber,
		0,
		en.enClass,
		ISNULL(co.Name, ''),
		ISNULL(co.LatinName, ''),
		en.enNotes
	FROM 
		[dbo].[fnExtended_En_Fixed](@CurGUID) As [en]
		OUTER APPLY dbo.fnBP_GetFixedPays([en].enGUID, @CurGUID) fn
		LEFT JOIN [vwEr] As [er] on [en].[ceGUID] = [er].[erEntryGUID]
		LEFT JOIN [co000] As [co] on [en].[enCostPoint] = [co].[GUID]
		LEFT JOIN [#EntryTbl] [ent] ON [ent].[Type] = [en].[ceTypeGuid]
	WHERE 
		en.enAccount = @AccountGUID 
		AND en.enCustomerGUID = @CustomerGUID
		AND ((@IsDebit = 0  AND [en].[FixedEnDebit] > 0) OR (@IsDebit = 1  AND [en].[FixedEnCredit] > 0))
		AND (([en].[FixedEnCredit] - ISNULL([fn].[SumVal], 0) > @Zero) OR ([en].[FixedEnDebit] - ISNULL([fn].[SumVal], 0) > @Zero))
		AND (ISNULL(er.erParentType, 0) <> 2) 
		AND ((@IsAllSources = 1) OR ([ent].[Type] IS NOT NULL))

	DECLARE @ShowOrderBills	[BIT]
	SET @ShowOrderBills = ISNULL((SELECT (CASE [Value] WHEN '1' THEN 1 ELSE 0 END) FROM op000 WHERE Name = 'AmnCfg_ShowOrderBills' AND UserGUID = @UserGUID), 0)

	INSERT INTO #Result(PayGUID, PayDesc, PayDate, TotalValue, PaidValue, ParentGUID, PayType, [Security], [UserSecurity], OriginNumber, Number, SortNumber, ClassStr, CostName, CostLatinName, Notes)
	SELECT 
		bu.buGUID,
		(CASE @lang 
			WHEN 0 THEN bt.Abbrev
			ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
		END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10)),
		bu.buDate,
		dbo.fnCalcBillTotal(bu.buGUID, @CurGUID), 
		ISNULL(bpPart.SumTotal, 0),
		bu.buGUID,
		2,
		[bu].[buSecurity],  
		@UserSecurity,
		bu.buNumber,
		bu.buNumber,
		bt.SortNum,
		'',
		ISNULL(co.Name, ''),
		ISNULL(co.LatinName, ''),
		bu.buNotes
	FROM 
		vwBu As [bu]
		INNER JOIN bt000 bt ON bt.GUID = bu.buType 
		LEFT JOIN 
				(
					SELECT 
						SUM([FixedBpVal]) SumTotal,
						[bu].[GUID] AS buGuid
					FROM 
						[fnBp_Fixed](@CurGUID, 1)
						INNER JOIN [bu000] As bu ON [bu].[GUID] = [bpDebtGUID] OR [bu].[GUID] = BpPayGUID
					GROUP BY 
						[bu].[GUID]
				) AS bpPart
				ON bpPart.buGuid = bu.buGUID
		LEFT JOIN [co000] As [co] on [bu].[buCostPtr] = [co].[GUID]
		LEFT JOIN [#EntryTbl] [ent] ON [ent].[Type] = bt.GUID
		LEFT  JOIN (SELECT DISTINCT buGUID FROM ori000) ori ON ori.buGUID = bu.buGUID
	WHERE 
		bu.buCustAcc = @AccountGUID 
		AND bu.buCustPtr = @CustomerGUID
		AND ((@IsDebit = 0  AND [bt].[bIsInput] = 0) OR (@IsDebit = 1  AND [bt].[bIsInput] > 0))
		AND (ISNULL(bpPart.SumTotal, 0) < dbo.fnCalcBillTotal(bu.buGUID, @CurGUID))
		AND ((@IsAllSources = 1) OR ([ent].[Type] IS NOT NULL))
		AND ((@ShowOrderBills = 1) OR ((@ShowOrderBills = 0) AND (ori.buGUID IS NULL)))
		AND NOT EXISTS
			(SELECT * FROM 
				bp000 as b
				INNER JOIN vwOrderPayments p on p.PaymentGuid = b.DebtGUID OR  p.PaymentGuid = b.PayGUID
				INNER JOIN ori000 ori1 ON p.BillGuid = ori1.POGUID
			WHERE ori1.BuGUID != 0x0 AND ori1.BuGUID = bu.BuGUID)

	IF @ShowOrderBills = 0
	BEGIN 
		DECLARE @defCurrency UNIQUEIDENTIFIER
		SELECT TOP 1 @defCurrency = [myGUID] FROM vwMy WHERE myCurrencyVal = 1

		INSERT INTO #Result(PayGUID, PayDesc, PayDate, TotalValue, PaidValue, ParentGUID, PayType, [Security], [UserSecurity], OriginNumber, Number, SortNumber, ClassStr, CostName, CostLatinName, Notes)
		SELECT DISTINCT 
			[orp].[PaymentGuid],
			(CASE @lang 
				WHEN 0 THEN bt.Abbrev
				ELSE (CASE bt.LatinAbbrev WHEN '' THEN bt.Abbrev ELSE bt.LatinAbbrev END)
			END) + ': ' + CAST(bu.buNumber AS NVARCHAR(10)),
			orp.PaymentDate,
			orp.UpdatedValue, 
			ISNULL(bpPart.SumTotal, 0),
			bu.buGUID,
			3,
			[bu].[buSecurity],  
			@UserSecurity,
			bu.buNumber,
			bu.buNumber,
			bt.SortNum,
			'',
			ISNULL(co.Name, ''),
			ISNULL(co.LatinName, ''),
			bu.buNotes
		FROM
			vwBu As [bu]
			INNER JOIN bt000 bt ON bt.GUID = bu.buType 
			INNER JOIN [vwOrderPayments] As [orp] on [bu].[buGUID] = [orp].[BillGUID]
			LEFT JOIN 
					(
						SELECT 
							SUM([FixedBpVal]) SumTotal,
							o.PaymentGuid
						FROM 
							[fnBp_Fixed](@CurGUID, 1)
							INNER JOIN [vwOrderPayments] As o ON o.[PaymentGuid] = [bpDebtGUID] OR o.[PaymentGuid] = BpPayGUID 
						GROUP BY 
							o.PaymentGuid
					) AS bpPart ON bpPart.PaymentGuid = orp.PaymentGuid
			LEFT JOIN [co000] As [co] on [bu].[buCostPtr] = [co].[GUID]
			LEFT JOIN [#EntryTbl] [ent] ON [ent].[Type] = bt.GUID
		WHERE 
			bu.buCustAcc = @AccountGUID 
			AND bu.buCustPtr = @CustomerGUID
			AND ((@IsDebit = 0  AND [bt].[bIsInput] = 0) OR (@IsDebit = 1  AND [bt].[bIsInput] > 0))
			AND (ISNULL(bpPart.SumTotal, 0) < orp.UpdatedValue)
			AND orp.UpdatedValueWithCurrency <> 0
			AND NOT EXISTS
				(SELECT * FROM 
					bp000 as b
					INNER JOIN ori000 ori on ori.BuGUID = b.DebtGUID OR ori.BuGUID = b.PayGUID
					INNER JOIN vwOrderPayments p ON p.BillGuid = ori.POGUID
				WHERE p.PaymentGUID = orp.PaymentGUID)
	END 

	EXEC prcCheckSecurity

	UPDATE r
	SET 
		PayDesc = (CASE @lang 
						WHEN 0 THEN nt.Abbrev
						ELSE (CASE nt.LatinAbbrev WHEN '' THEN nt.Abbrev ELSE nt.LatinAbbrev END)
					END) + ': ' + CAST(ch.chNumber AS NVARCHAR(10)),
		PayType = 4,
		OriginNumber = ch.chNumber
	FROM
		#Result r 
		INNER JOIN vwCh ch ON ch.chGUID = r.ParentGUID
		INNER JOIN nt000 nt ON nt.GUID = ch.chType

	UPDATE r
	SET 
		PayDesc = (CASE @lang 
						WHEN 0 THEN [et].[Abbrev] 
						ELSE (CASE [et].[LatinAbbrev] WHEN '' THEN [et].[Abbrev] ELSE [et].[LatinAbbrev] END) 
					END) + ': ' + CAST(py.pyNumber AS VARCHAR(10)),
		PayType = 1,
		OriginNumber = py.pyNumber
	FROM
		#Result r 
		INNER JOIN vwPy py ON py.pyGUID = r.ParentGUID
		INNER JOIN et000 et ON et.GUID = py.pyTypeGUID

	SELECT * FROM #Result ORDER BY PayDate, OriginNumber, Number
###########################################################################
CREATE PROC prcBP_SavePayments
	@DebitGUID		UNIQUEIDENTIFIER,
	@PayGUID		UNIQUEIDENTIFIER,
	@CurrencyGUID	UNIQUEIDENTIFIER,
	@PayValue		FLOAT
AS 
	SET NOCOUNT ON 

	EXEC prcEntry_ConnectDebtPay @DebitGUID, @PayGUID, 0, @PayValue
###########################################################################
CREATE PROCEDURE prc_GetPaysInfo
		@BuGUID 		[UNIQUEIDENTIFIER], --biil or enEntry
		@AccGuid		[UNIQUEIDENTIFIER],
		@CustGuid       [UNIQUEIDENTIFIER] = 0x0,
		@IsOrder		[BIT] = 0
AS 
	DECLARE 
		@CurGUID 		[UNIQUEIDENTIFIER],
		@CurVAL 		[FLOAT]
	
	SET NOCOUNT ON

	SET @CurGUID = (SELECT acCurrencyPtr from vwAc WHERE acGUID = @AccGuid)
	SET @CurVAL = ISNULL((SELECT TOP 1 CurrencyVal FROM mh000 WHERE CurrencyGUID = @CurGUID ORDER BY DATE DESC), (SELECT CurrencyVal FROM my000 WHERE GUID = @CurGUID)) -- Remainig Date Condition on mh
	
	IF @IsOrder = 1
		SET @BuGUID = (SELECT PaymentGuid FROM [vwOrderPayments] WHERE BillGuid = @BuGUID)

	EXEC repBillPayment_DebtPay @BuGUID, @CurGUID, @CurVAL, @CustGuid
###########################################################################
CREATE PROCEDURE prcEntry_GetPaysInfo
		@PyGUID 		[UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	DECLARE 
		@ShowOrderBills		[BIT],
		@UserGUID 			[UNIQUEIDENTIFIER], 
		@UserSecurity		[INT],
		@lang				[INT],
		@EnGUID 			[UNIQUEIDENTIFIER],
		@AccGuid			[UNIQUEIDENTIFIER],
		@CustGuid			[UNIQUEIDENTIFIER],
		@CurGUID 			[UNIQUEIDENTIFIER],
		@CurVAL 			[FLOAT],
		@Count				[INT]

	CREATE TABLE [#SecViol]
	( 
		[Type]						[INT],
		[Cnt]						[INTEGER])  

	CREATE TABLE [#Result] 
	(
		[AccGUID]					[UNIQUEIDENTIFIER], 
		[AccSecurity]				[INT],   
		[AccName]					[NVARCHAR](255)COLLATE ARABIC_CI_AI,  
		[CustName]					[NVARCHAR](255)COLLATE ARABIC_CI_AI, 
		[CustGUID]					[UNIQUEIDENTIFIER], 
		[AccCode]					[NVARCHAR](255)COLLATE ARABIC_CI_AI,  
		[Security]					[INT], 
		[UserSecurity]				[INT], 
		[Date]						[DATETIME], 
		[ParentGUID]				[UNIQUEIDENTIFIER], 
		[ParentType]				[INT], 
		[ceNumber]					[INT], 
		[enGUID]					[UNIQUEIDENTIFIER], 
		[ceGUID]					[UNIQUEIDENTIFIER], 
		[bpGUID]					[UNIQUEIDENTIFIER], 
		[Debit]						[FLOAT], 
		[Credit]					[FLOAT], 
		[Notes]						[NVARCHAR](1000)COLLATE ARABIC_CI_AI,
		[Val]						[FLOAT] ,
		[enCostPoint]				[UNIQUEIDENTIFIER],
		[coName]					[NVARCHAR](255)COLLATE ARABIC_CI_AI,
		[coLatinName]				[NVARCHAR](255)COLLATE ARABIC_CI_AI,
		[coCode]					[NVARCHAR](255)COLLATE ARABIC_CI_AI,
		[class]						[NVARCHAR](255)COLLATE ARABIC_CI_AI,
		[PaymentFormattedNumber]	[NVARCHAR](255)COLLATE ARABIC_CI_AI)
	
	CREATE TABLE [#SelectedEN] 
	(
		[EnGuid]			[UNIQUEIDENTIFIER], 
		[AccGuid]			[UNIQUEIDENTIFIER], 
		[CustGuid]			[UNIQUEIDENTIFIER], 
		[Number]			[INT] PRIMARY KEY IDENTITY(1,1))
			
	INSERT INTO [#SelectedEN] (EnGuid, AccGuid, CustGuid) 
	SELECT 
		en.[GUID], 
		en.[AccountGUID], 
		en.[CustomerGUID]		 
	FROM 
		En000 en 
		INNER JOIN Ce000 ce ON en.ParentGUID = ce.GUID
		INNER JOIN Er000 er ON er.EntryGUID = ce.GUID
	WHERE 
		er.ParentGUID = @PyGUID

	SET @Count = (SELECT MAX (Number) FROM [#SelectedEN])

	WHILE @Count > 0
	BEGIN
		SET @EnGUID = (SELECT EnGuid FROM [#SelectedEN] WHERE Number = @Count)
		SET @AccGuid = (SELECT AccGuid FROM [#SelectedEN] WHERE Number = @Count)
		SET @CustGuid = (SELECT CustGuid FROM [#SelectedEN] WHERE Number = @Count)

		SET @CurGUID = (SELECT acCurrencyPtr from vwAc WHERE acGUID = @AccGuid)
		SET @CurVAL = ISNULL((SELECT TOP 1 CurrencyVal FROM mh000 WHERE CurrencyGUID = @CurGUID ORDER BY DATE DESC), (SELECT CurrencyVal FROM my000 WHERE GUID = @CurGUID)) -- Remainig Date Condition on mh
		
		INSERT INTO [#Result] EXEC prcGetRelatedPays @EnGUID, @CurGUID, @CurVAL, @CustGuid

		SET @Count = @Count - 1
	END

	EXEC prcCheckBillPaySec

	SELECT * FROM [#Result] ORDER BY [Date], [ceNumber]
	SELECT * FROM [#SecViol]
###########################################################################
#END