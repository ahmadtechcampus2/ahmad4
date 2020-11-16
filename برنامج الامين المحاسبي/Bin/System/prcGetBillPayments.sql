###########################################################################
CREATE PROC prcGetBillPayments
	@buGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 

	DECLARE @DefCurr UNIQUEIDENTIFIER;
	SET @DefCurr = dbo.fnGetDefaultCurr()

	SELECT 
		[bu].[CustAccGUID] AS AccountGuid,
		[bu].[CurrencyGuid] AS CurrencyGuid,
		dbo.fnCalcBillTotal(@buGUID, @DefCurr) AS Value,
		CASE [bt].[bIsOutput]
			WHEN 0 THEN 0
			ELSE 1
		END AS IsDebit,
		CASE WHEN  [bp].[debtGUID] = @buGUID
			THEN [bp].[payGUID]
			ELSE [bp].[debtGUID]
		END AS BpEnGuid,
		CASE WHEN [bp].[debtGUID] = @buGUID
			THEN 0
			ELSE 1
		END AS BpIsDebit,
		[bp].[PayType] AS BpPayType,
		[bp].[Val] AS BpValue,
		[bp].[CurrencyGuid] AS BpCurrencyGuid,
		[bp].[CurrencyVal] AS BpCurrencyValue,
		[bp].[RecType] AS [BpRecType],
		[bp].[Type] AS [BpFirstPayType]
	FROM 
		[bp000] [bp] 
		INNER JOIN [bu000][bu] ON [bp].[debtGUID] = [bu].[guid] OR [bp].[payGUID] = [bu].[guid]
		INNER JOIN [bt000][bt] ON [bt].[GUID] = [bu].[TypeGUID]
	WHERE 
		[bu].[GUID] = @buGUID 
###########################################################################
CREATE PROC prcSaveBillPayment
	@BuGUID [UNIQUEIDENTIFIER],
	@AccountGuid [UNIQUEIDENTIFIER],
	@CurrencyGuid [UNIQUEIDENTIFIER],
	@Value FLOAT,
	@IsDebit [BIT],
	@BpEnGuid [UNIQUEIDENTIFIER],
	@BpIsDebit [BIT],
	@BpPayType INT,
	@BpValue FLOAT,
	@BpCurrencyGuid [UNIQUEIDENTIFIER],
	@BpCurrencyValue FLOAT,
	@BpRecType INT,
	@BpFirstPayType INT
AS 
	SET NOCOUNT ON 

	INSERT INTO bp000(GUID, DebtGuid, PayGuid, PayType, Val, CurrencyGuid, CurrencyVal, RecType, Type)
	SELECT 
		NEWID(), 
		CASE @BpIsDebit WHEN 0 THEN @BuGUID ELSE @BpEnGuid END,
		CASE @BpIsDebit WHEN 0 THEN @BpEnGuid ELSE @BuGUID END,
		@BpPayType,
		@BpValue,
		@BpCurrencyGuid,
		@BpCurrencyValue,
		@BpRecType,
		@BpFirstPayType
###########################################################################
CREATE PROC prcIsBillPaymentExists
	@buGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 

	SELECT 
		COUNT(*) AS [Cnt]
	FROM 
		[bu000] [bu]
		INNER JOIN [er000] [er] ON [bu].[guid] = [er].[parentguid] 
		INNER JOIN [ce000] [ce] ON [ce].[guid] = [er].[entryguid]  
		INNER JOIN [en000] [en] ON [ce].[guid] = [en].[parentguid] 
		INNER JOIN [bp000] [bp] ON [bp].[debtGUID] = [en].[guid] OR [bp].[payGUID] = [en].[guid]
	WHERE 
		[bu].[guid] = @buGUID
###########################################################################
CREATE PROC prcGetAttachedPays
	@ceGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 
		
	SELECT 
		TOP 1 [bp].[GUID]
	FROM 
		[en000] [en] 
		INNER JOIN [bp000] [bp] ON [en].[GUID] = [bp].[DebtGUID] OR [en].[GUID] = [bp].[PAYGUID] 
	WHERE 
		[en].[ParentGUID] = @ceGUID
###########################################################################
CREATE PROC prcGetOrderAttachedPays
	@orAddInfoGuid [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	
	SELECT 
		TOP 1 [bp].[GUID]
	FROM 
		vwOrderPayments [or]
		INNER JOIN [bp000] [bp] ON [or].[PaymentGuid] = [bp].[DebtGUID] OR [or].[PaymentGuid] = [bp].[PAYGUID] 
	WHERE 
		[or].[BillGuid] = @orAddInfoGuid
###########################################################################
CREATE PROC prcDeleteOrderAttachedPays
	@OrderGuid [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	DELETE [bp000]
	FROM 	
		vwOrderPayments [or]
		INNER JOIN [bp000] [bp] ON [or].[PaymentGuid] = [bp].[DebtGUID] OR [or].[PaymentGuid] = [bp].[PAYGUID] 
	WHERE 
		[or].[BillGuid] = @OrderGuid
###########################################################################
CREATE PROC prcBill_GetAttachedPaysAmount
	@BillGUID UNIQUEIDENTIFIER,
	@BillDate Date,
	@CurrencyGUID UNIQUEIDENTIFIER,
	@CurrencyValue FLOAT,
	@Type INT =  0
AS 
	SET NOCOUNT ON 
	
	DECLARE @AccountGUID UNIQUEIDENTIFIER, @AccountCurrencyGUID UNIQUEIDENTIFIER
	SELECT TOP 1
		@AccountGUID = bu.CustAccGUID,
		@AccountCurrencyGUID = ac.CurrencyGUID 
	FROM 
		bu000 bu 
		INNER JOIN ac000 ac ON ac.GUID = bu.CustAccGUID
	WHERE 
		bu.GUID = @BillGUID
		 
	IF ISNULL(@AccountGUID, 0x0) = 0x0
		RETURN 
	
	SELECT 
		SUM((CASE WHEN @BillGUID = DebtGUID THEN Val / (CASE CurrencyVal WHEN 0 THEN 1 ELSE CurrencyVal END) 
				ELSE PayVal / (CASE PayCurVal WHEN 0 THEN 1 ELSE PayCurVal END) END) 
			* (CASE WHEN @CurrencyGUID = @AccountCurrencyGUID THEN @CurrencyValue ELSE [dbo].fnGetCurVal(@AccountCurrencyGUID, @BillDate) END)) AS Amount,
		COUNT(*) Cnt  
	FROM 
		bp000 
	WHERE 
		((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) 
		AND 
		((@Type=0 AND [Type] = 0 ) OR (@Type = 1))
###########################################################################
CREATE PROCEDURE IsPackedBill
@Bill UNIQUEIDENTIFIER
as
SET NOCOUNT ON

	SELECT 
			*
		FROM 
			[dbo].[vbPackingLists] pl 
			INNER JOIN  [dbo].[PackingListsBills000] bu ON pl.[GUID] = bu.PackingListGUID AND bu.BillGUID=@Bill
		
			
############################################################################
CREATE Procedure Prc_ConnectChequeWithBill
	@ChGuid	[UNIQUEIDENTIFIER]
AS
	DECLARE @buGuid [UNIQUEIDENTIFIER],
			@EnChGuid [UNIQUEIDENTIFIER],
			@AccGuid [UNIQUEIDENTIFIER]

	SET @buGuid=(SELECT[ParentGuid] FROM [ch000] WHERE Guid=@chGuid)
	SET @AccGuid=(SELECT [CustAccGUID] FROM [bu000]  WHERE [Guid]= @buGuid)
	SET @EnChGuid=(SELECT TOP 1 [en].[GUID] FROM 
					[er000] [er] inner join [en000] [en]  ON [en].[ParentGUID] = [er].[EntryGUID] 
					AND [er].[ParentGUID] = @ChGuid AND [en].[AccountGUID] =@AccGuid)
	
	EXEC prcEntry_ConnectDebtPay @buGuid,@EnChGuid,2
###########################################################################
CREATE PROC prcCheqqueBill_reConnectPayments
	@BillGUID UNIQUEIDENTIFIER,
	@chGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	IF ISNULL(@BillGUID, 0x0) = 0x0
		RETURN
	
	CREATE TABLE #bp_result([DebtGUID] UNIQUEIDENTIFIER, [PayGUID] UNIQUEIDENTIFIER)

	DECLARE
			@EnChGuid [UNIQUEIDENTIFIER],
			@AccGuid [UNIQUEIDENTIFIER]

	SET @AccGuid=(SELECT [CustAccGUID] FROM [bu000]  WHERE [Guid]= @BillGUID)
	SET @EnChGuid=(SELECT [en].[GUID] from 
					[er000] [er] inner join [en000] [en]  ON [en].[ParentGUID] = [er].[EntryGUID] 
					AND [er].[ParentGUID] = @ChGuid AND [en].[AccountGUID] =@AccGuid)
	
	SELECT * INTO #temp FROM bp000

	DELETE  FROM bp000 
	 WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0)

	INSERT INTO #bp_result EXEC prcEntry_ConnectDebtPay @BillGUID,@EnChGuid,2

	IF NOT EXISTS (SELECT * FROM #temp WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0))
	BEGIN 
		RETURN 
	END
	SELECT * INTO #bp FROM #temp WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0)
	SELECT TOP 0 * INTO #bp_temp FROM #bp

	DELETE bp000 WHERE ((DebtGUID = @BillGUID) OR (PayGUID = @BillGUID)) AND ([Type] = 0)
	
	DECLARE @c_bp CURSOR, @payGUID UNIQUEIDENTIFIER, @bpGUID UNIQUEIDENTIFIER
	SET @c_bp = CURSOR FAST_FORWARD FOR SELECT bp.GUID, (CASE WHEN bp.DebtGUID = @BillGUID THEN bp.PayGUID ELSE DebtGUID END) FROM 
		#bp bp 
		INNER JOIN en000 en ON ((bp.DebtGUID = en.GUID) OR (bp.PayGUID = en.GUID))
		INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
	ORDER BY ce.Date, ce.Number
	
	OPEN @c_bp FETCH NEXT FROM @c_bp INTO @bpGUID, @payGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		DELETE #bp_result
		INSERT INTO #bp_result EXEC prcEntry_ConnectDebtPay @BillGUID, @payGUID
		IF EXISTS(SELECT * FROM #bp_result)
			INSERT INTO #bp_temp SELECT * FROM #bp WHERE [GUID] = @bpGUID

		FETCH NEXT FROM @c_bp INTO @bpGUID, @payGUID
	END CLOSE @c_bp DEALLOCATE @c_bp

	IF (SELECT COUNT(*) FROM  #bp_temp) != (SELECT COUNT(*) FROM #bp) 
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 2, 0, 'AmnW0083: Can''t reconnect related payments.', @BillGUID
###########################################################################
CREATE PROC prcEntry_GetAttachedPayments
	@CeGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE #Result(
		AccountGuid UNIQUEIDENTIFIER,
		CustomerGuid UNIQUEIDENTIFIER,
		PayCostGuid UNIQUEIDENTIFIER,
		PayGuid UNIQUEIDENTIFIER,
		Amount FLOAT,
		CurrencyVal FLOAT,
		IsDebitPay BIT,
		[Type] INT,
		Number INT,
		PayNumber INT,
		PayDate DATE,
		Balance FLOAT)
	
	CREATE TABLE #Pays(
		PayGUID UNIQUEIDENTIFIER,
		EnGUID UNIQUEIDENTIFIER,
		Amount FLOAT,
		CurrencyVal FLOAT,
		[Type] INT, 
		Number INT,
		Balance FLOAT)
	
	INSERT INTO #Pays
	SELECT 
		(CASE en.GUID WHEN bp.DebtGUID THEN bp.PayGUID ELSE bp.DebtGUID END),
		en.GUID,
		bp.Val,
		bp.CurrencyVal,
		bp.[Type],
		en.Number,
		(CASE WHEN en.Debit > 0 THEN en.Debit ELSE en.Credit END) 
	FROM 
		ce000 ce 
		INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
		INNER JOIN bp000 bp ON bp.DebtGUID = en.GUID OR bp.PayGUID = en.GUID 
	WHERE ce.GUID = @CeGUID

	IF NOT EXISTS(SELECT * FROM #Pays)
	BEGIN 
		SELECT * FROM #Result 
		RETURN 
	END 
	
	INSERT INTO #Result 
	SELECT 
		bu.CustAccGUID,
		bu.CustGUID,
		bu.CostGUID,
		bu.GUID,
		p.Amount,
		p.CurrencyVal,
		CASE bt.bIsInput WHEN 0 THEN 1 ELSE 0 END,
		p.[Type],
		p.Number,
		bu.Number,
		bu.Date,
		p.Balance
	FROM 
		#Pays p
		INNER JOIN bu000 bu ON bu.GUID = p.PayGUID 
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	UNION ALL
	SELECT 
		en.AccountGUID,
		en.CustomerGUID,
		en.CostGUID,
		en.GUID,
		p.Amount,
		p.CurrencyVal,
		CASE WHEN en.Debit > 0 THEN 1 ELSE 0 END,
		p.[Type],
		p.Number,
		ce.Number,
		ce.Date,
		p.Balance
	FROM 
		#Pays p
		INNER JOIN en000 en ON en.GUID = p.PayGUID 
		INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
	UNION ALL
	SELECT 
		bu.CustAccGUID,
		bu.CustGUID,
		bu.CostGUID,
		[orp].[PaymentGUID],
		p.Amount,
		p.CurrencyVal,
		CASE bt.bIsInput WHEN 0 THEN 1 ELSE 0 END,
		p.[Type],
		p.Number,
		orp.PaymentNumber,
		orp.PaymentDate,
		p.Balance
	FROM 
		#Pays p
		INNER JOIN [vwOrderPayments] As [orp] ON [orp].[PaymentGUID] = p.PayGUID 
		INNER JOIN [bu000] [bu] ON [bu].[Guid] = [orp].[BillGuid] 
		INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid] 

	SELECT * FROM #Result ORDER BY Number, PayDate, PayNumber, Amount 
###########################################################################
CREATE PROC prcEntry_ReconnectAttachedPayment
	@CeGUID UNIQUEIDENTIFIER,
	@AccountGUID UNIQUEIDENTIFIER,
	@CustomerGUID UNIQUEIDENTIFIER,
	@CostGUID UNIQUEIDENTIFIER,
	@PayGUID UNIQUEIDENTIFIER,
	@IsDebitPay BIT,
	@Amount FLOAT,
	@CurrencyVal FLOAT,
	@Balance FLOAT,
	@Type INT = 0
AS 
	SET NOCOUNT ON

	DECLARE @EnGUID UNIQUEIDENTIFIER
	CREATE TABLE #bp_res([DebtGUID] UNIQUEIDENTIFIER, [PayGUID] UNIQUEIDENTIFIER)

	SELECT TOP 1 @EnGUID = en.[GUID] 
	FROM 
		ce000 ce 
		INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
		INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
		INNER JOIN (SELECT [GUID] FROM co000 UNION ALL SELECT 0x0) co ON co.GUID = en.CostGUID 
		LEFT JOIN (SELECT SUM([Val]) AS Value, DebtGUID FROM bp000 GROUP BY DebtGUID) bpD ON bpD.DebtGUID = en.GUID
		LEFT JOIN (SELECT SUM([Val]) AS Value, PayGUID FROM bp000 GROUP BY PayGUID) bpP ON bpP.PayGUID = en.GUID
	WHERE 
		ce.GUID = @CeGUID
		AND
		ac.GUID = @AccountGUID
		AND 
		co.GUID = @CostGUID
		AND 
		(((@IsDebitPay = 0) AND (en.Debit > 0)) OR ((@IsDebitPay = 1) AND (en.Credit > 0)))
		AND 
		en.Debit + en.Credit - ISNULL(bpD.Value, 0) - ISNULL(bpP.Value, 0) - @Amount >= 0
		AND 
		en.Debit + en.Credit = @Balance
		AND 
		en.CustomerGUID = @CustomerGUID 

	IF ISNULL(@EnGUID, 0x0) = 0x0
	BEGIN
		SELECT TOP 1 @EnGUID = en.[GUID] 
		FROM 
			ce000 ce 
			INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
			INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
			INNER JOIN (SELECT [GUID] FROM co000 UNION ALL SELECT 0x0) co ON co.GUID = en.CostGUID 
			LEFT JOIN (SELECT SUM([Val]) AS Value, DebtGUID FROM bp000 GROUP BY DebtGUID) bpD ON bpD.DebtGUID = en.GUID
			LEFT JOIN (SELECT SUM([Val]) AS Value, PayGUID FROM bp000 GROUP BY PayGUID) bpP ON bpP.PayGUID = en.GUID
		WHERE 
			ce.GUID = @CeGUID
			AND
			ac.GUID = @AccountGUID
			AND 
			co.GUID = @CostGUID
			AND 
			(((@IsDebitPay = 0) AND (en.Debit > 0)) OR ((@IsDebitPay = 1) AND (en.Credit > 0)))
			AND 
			en.Debit + en.Credit - ISNULL(bpD.Value, 0) - ISNULL(bpP.Value, 0) - @Amount >= 0
			AND 
			en.CustomerGUID = @CustomerGUID 
	END 

	IF ISNULL(@EnGUID, 0x0) = 0x0
	BEGIN
		DECLARE @option INT 
		SET @option = ISNULL((SELECT TOP 1 CAST([Value] AS INT) FROM op000 where Name = 'AmnCfg_LinkBillPaymentWithCost'), 0) 
		IF @option = 0
		BEGIN 
			SELECT TOP 1 @EnGUID = en.[GUID] 
			FROM 
				ce000 ce 
				INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
				INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
				LEFT JOIN (SELECT SUM([Val]) AS Value, DebtGUID FROM bp000 GROUP BY DebtGUID) bpD ON bpD.DebtGUID = en.GUID
				LEFT JOIN (SELECT SUM([Val]) AS Value, PayGUID FROM bp000 GROUP BY PayGUID) bpP ON bpP.PayGUID = en.GUID
			WHERE 
				ce.GUID = @CeGUID
				AND
				ac.GUID = @AccountGUID
				AND 
				(((@IsDebitPay = 0) AND (en.Debit > 0)) OR ((@IsDebitPay = 1) AND (en.Credit > 0)))
				AND 
				en.Debit + en.Credit - ISNULL(bpD.Value, 0) - ISNULL(bpP.Value, 0) - @Amount >= 0
				AND 
				en.Debit + en.Credit = @Balance
				AND 
				en.CustomerGUID = @CustomerGUID 

			IF ISNULL(@EnGUID, 0x0) = 0x0
			BEGIN
				SELECT TOP 1 @EnGUID = en.[GUID] 
				FROM 
					ce000 ce 
					INNER JOIN en000 en ON ce.GUID = en.ParentGUID 
					INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID 
					LEFT JOIN (SELECT SUM([Val]) AS Value, DebtGUID FROM bp000 GROUP BY DebtGUID) bpD ON bpD.DebtGUID = en.GUID
					LEFT JOIN (SELECT SUM([Val]) AS Value, PayGUID FROM bp000 GROUP BY PayGUID) bpP ON bpP.PayGUID = en.GUID
				WHERE 
					ce.GUID = @CeGUID
					AND
					ac.GUID = @AccountGUID
					AND 
					(((@IsDebitPay = 0) AND (en.Debit > 0)) OR ((@IsDebitPay = 1) AND (en.Credit > 0)))
					AND 
					en.Debit + en.Credit - ISNULL(bpD.Value, 0) - ISNULL(bpP.Value, 0) - @Amount >= 0
					AND 
					en.CustomerGUID = @CustomerGUID 
			END
		END 

		IF ISNULL(@EnGUID, 0x0) = 0x0
		BEGIN
			SELECT * FROM #bp_res
			RETURN 
		END 
	END
	SET @Amount = @Amount / (CASE @CurrencyVal WHEN 0 THEN 1 ELSE @CurrencyVal END)
	INSERT INTO #bp_res EXEC prcEntry_ConnectDebtPay @EnGUID, @PayGUID, @Type, @Amount
	SELECT * FROM #bp_res
###########################################################################
CREATE PROC Prc_ConnectChequesToBill
@buGuid [UNIQUEIDENTIFIER] 
AS 
    DECLARE @ch [UNIQUEIDENTIFIER]; 
    DECLARE c CURSOR FOR 
      SELECT guid 
      FROM   ch000 
      WHERE  parentguid = @buGuid 

    OPEN c 
    FETCH next FROM c INTO @ch 
    WHILE @@FETCH_STATUS = 0 
      BEGIN 
          EXEC Prc_connectchequewithbill 
            @ch 

          FETCH next FROM c INTO @ch 
      END 
    CLOSE c 
    DEALLOCATE c 
###########################################################################
CREATE function FnGetPOSPayRecieveAttachedPays(@BillGuid UNIQUEIDENTIFIER)
RETURNS int
AS
BEGIN
DECLARE @result [BIT] = 0
   select @result = count(*) from bu000 where Guid = @BillGuid 
                                        AND number in (select billnumber from POSPayRecieveTable000)
  RETURN @result
END
###########################################################################
#END
