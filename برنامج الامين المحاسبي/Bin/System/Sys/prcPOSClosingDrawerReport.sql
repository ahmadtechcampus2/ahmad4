#########################################
CREATE PROCEDURE prcPOS_CheckClosingDrawer
	@CashierID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE @RestDate DATETIME
	DECLARE @Result INT 
	SET @Result = 0

	SELECT @RestDate =  MAX([Date]) FROM POSResetDrawer000
	WHERE [USER] = @CashierID
	
	IF EXISTS (
		SELECT 
			* 
		FROM 
			POSOrder000 o
			LEFT JOIN BillRel000 br ON o.GUID = br.ParentGUID
		WHERE 
			br.GUID IS NULL
			AND 
			(o.[Date] >= @RestDate OR @RestDate IS NULL)
			AND 
			o.SubTotal > 0
			AND 
			o.FinishCashierID = @CashierID)
			
	BEGIN 
		SET @Result = 1
	END 

	SELECT @Result AS Result
#########################################
CREATE PROCEDURE prcPOSClosingDrawerReport
	@CashierID		UNIQUEIDENTIFIER,
	@ResetDrawerID  UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	CREATE TABLE #temp (
		ID			UNIQUEIDENTIFIER,
		Parent		UNIQUEIDENTIFIER,
		Name		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		LatinName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		TOTAL		FLOAT,
		NEW			BIT )

	CREATE TABLE #Result (
		ID				INT,
		NAME			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		LatinNAME		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		TOTAL			FLOAT,
		CurrencyID		UNIQUEIDENTIFIER )
	
	DECLARE 
		@done		BIT,
		@language	INT, 
		@RestDate	DATETIME

	SET @done = 0
	SET @language = [dbo].[fnConnections_GetLanguage]()	

	SELECT @RestDate =  MAX([Date]) FROM POSResetDrawer000
	WHERE [USER] = @CashierID 
	AND [GUID] <> @ResetDrawerID
	
	DECLARE @DeffCur UNIQUEIDENTIFIER

	SELECT TOP 1 @DeffCur = ISNULL([Value], 0x0) 
	FROM [FileOP000] 
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	IF ISNULL(@DeffCur, 0x0) = 0x0	
	BEGIN 
		SELECT TOP 1 @DeffCur = GUID FROM my000 WHERE CurrencyVal = 1 AND Number = 1
	END 

	INSERT #temp 
	SELECT 
		gr.GUID, 
		gr.ParentGUID, 
		gr.Name,
		gr.LatinName,
		SUM(
		(CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price * [Item].Qty ELSE [Item].Price * [Item].Qty END)  
		+ (CASE bt.VATSystem WHEN 1 THEN (CASE [Item].[Type] WHEN 1 THEN -1*([Item].Qty * [Item].VATValue) ELSE ([Item].Qty * [Item].VATValue) END) ELSE 0 END)
		- ((CASE [Orders].SubTotal WHEN 0 THEN 0 ELSE (CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price * [Item].Qty ELSE [Item].Price * [Item].Qty END) / [Orders].SubTotal END)* [Orders].[Discount])
		- ((CASE [Orders].SubTotal WHEN 0 THEN 0 ELSE (CASE [Item].[Type] WHEN 1 THEN -1 * [Item].VATValue * [Item].Qty ELSE [Item].VATValue * [Item].Qty END) / [Orders].SubTotal END)* [Orders].[Discount])
		+ ((CASE [Orders].SubTotal WHEN 0 THEN 0 ELSE (CASE [Item].[Type] WHEN 1 THEN -1 * [Item].Price * [Item].Qty ELSE [Item].Price * [Item].Qty END) / [Orders].SubTotal END)* [Orders].[Added])
		+ ((CASE [Orders].SubTotal WHEN 0 THEN 0 ELSE (CASE [Item].[Type] WHEN 1 THEN -1 * [Item].VATValue * [Item].Qty ELSE [Item].VATValue * [Item].Qty END) / [Orders].SubTotal END)* [Orders].[Added])
			) Total,
		0 
	FROM 
		POSOrder000 orders 
		INNER JOIN  BillRel000 br on orders.Guid = br.ParentGUID
		INNER JOIN bu000 bu on bu.GUID = br.BillGUID
		INNER JOIN bt000 bt on bu.TypeGUID = bt.GUID 
		INNER JOIN POSOrderItems000 Item ON orders.GUID=Item.ParentID 
		INNER JOIN mt000 mt ON mt.GUID=Item.MatID
		INNER JOIN gr000 gr ON gr.GUID=mt.GroupGUID
	WHERE 
		(Orders.[Date] >= @RestDate OR @RestDate IS NULL)   AND Orders.SubTotal > 0
		AND Orders.FinishCashierID = @CashierID
	GROUP BY 
		gr.GUID, 
		gr.ParentGUID, 
		gr.Name,
		gr.LatinName
	
	WHILE @done = 0
	BEGIN
		INSERT #temp 
		SELECT 
			gr.GUID, 
			gr.ParentGUID, 
			gr.NAME,gr.
			LatinName,
			SUM(child.TOTAL),
			1 
		FROM 
			gr000 gr 
			INNER JOIN #temp child ON gr.GUID = child.Parent
		GROUP BY 
			gr.GUID, 
			gr.ParentGUID, 
			gr.Name,
			gr.LatinName

		DELETE #temp WHERE  Parent<> 0x0 AND New = 0
		
		IF @@ROWCOUNT = 0
			SET @DONE = 1
		ELSE
			UPDATE #temp SET New = 0 
	END

	INSERT #Result 
	SELECT 
		1,
		'', 
		'COUNT : ', 
		COUNT(*), 
		-- 1, 
		0x0 
	FROM 
		POSOrder000
	WHERE 
		([Date] >= @RestDate OR @RestDate IS NULL )
		AND FinishCashierID = @CashierID
	INSERT #Result 
	SELECT 
		2, 
		'', 
		'FROM', 
		ISNULL(MIN(Number), 0), 
		0x0 
	FROM 
		POSOrder000
	WHERE 
		([Date] >= @RestDate OR @RestDate IS NULL)
		AND FinishCashierID = @CashierID
	INSERT #Result 
	SELECT 
		3, 
		'', 
		'TO', 
		ISNULL(MAX(Number), 0), 
		0x0 
	FROM 
		POSOrder000
	WHERE 
		([Date] >= @RestDate OR @RestDate IS NULL)
		AND FinishCashierID = @CashierID
	INSERT #Result 
	SELECT 
		6, 
		NAME, 
		LatinName, 
		SUM(TOTAL), 
		0x0 
	FROM 
		#temp 
	GROUP BY 
		Name,
		LatinName

	INSERT #Result 
	SELECT 
		7, 
		my.Name, 
		my.LatinName, 
		SUM((CASE WHEN orders.SubTotal < 0 THEN -1 ELSE 1 END) * ABS(Currency.Paid - Currency.Returned)), 
		my.GUID 
	FROM 
		POSOrder000 orders 
		INNER JOIN POSPaymentsPackageCurrency000 Currency ON Currency.ParentID = orders.PaymentsPackageID
		INNER JOIN my000 my ON my.GUID = currency.CurrencyID
	WHERE 
		(Orders.[Date] >= @RestDate OR @RestDate IS NULL)
		AND Orders.FinishCashierID = @CashierID
	GROUP BY 
		my.GUID, 
		my.Name, 
		my.LatinName

	INSERT #Result 
	SELECT 
		8, 
		'', 
		'', 
		SUM((CASE WHEN orders.SubTotal < 0 THEN -1 ELSE 1 END) * ABS(payment.DeferredAmount) / (CASE orders.CurrencyValue WHEN 0 THEN 1 ELSE orders.CurrencyValue END)), 
		orders.CurrencyID 
	FROM 
		POSOrder000 orders
		INNER JOIN POSPaymentsPackage000 payment on orders.PaymentsPackageID = payment.Guid
	WHERE 
		payment.DeferredAccount <> 0x0 AND (Orders.[Date] >= @RestDate OR @RestDate IS NULL)
		AND Orders.FinishCashierID = @CashierID
	GROUP BY 
		orders.CurrencyID

	INSERT #Result 
	SELECT 
		9, 
		nt.Name, 
		nt.LatinName, 
		SUM((CASE WHEN checks.NewVoucher = 0 AND orders.SubTotal >= 0 THEN 1 ELSE -1 END) * checks.Paid / (CASE checks.CurrencyValue WHEN 0 THEN 1 ELSE checks.CurrencyValue END)), 
		checks.CurrencyID 
	FROM 
		POSOrder000 orders 
		INNER JOIN POSPaymentsPackageCheck000 checks	ON checks.ParentID = orders.PaymentsPackageID
		INNER JOIN nt000 nt								ON nt.GUID = checks.Type
		INNER JOIN my000 my								ON my.GUID = checks.CurrencyID
	WHERE 
		(Orders.[Date] >= @RestDate OR @RestDate IS NULL)
		AND Orders.FinishCashierID = @CashierID
	GROUP BY 
		checks.CurrencyID, 
		nt.Name, 
		nt.LatinName

	-- ReturnVoucher
	DECLARE @ReturnVoucherValue FLOAT 
	SELECT @ReturnVoucherValue = 
		SUM (pak.ReturnVoucherValue / (CASE ord.CurrencyValue WHEN 0 THEN 1 ELSE ord.CurrencyValue END))
	FROM 
		[POSPaymentsPackage000] pak
		INNER JOIN POSOrder000 ord ON pak.GUID = ord.PaymentsPackageID
	WHERE 
		(ord.[Date] >= @RestDate OR @RestDate IS NULL)
		AND 
		pak.PayType = 3
		AND 
		ISNULL(pak.[ReturnVoucherValue], 0) != 0
		AND 
		ISNULL(pak.ReturnVoucherID, 0x0) != 0x0
		AND Ord.FinishCashierID = @CashierID

	IF ISNULL(@ReturnVoucherValue, 0) != 0
	BEGIN 
		INSERT #Result 
		SELECT 
			10, 
			Name, 
			LatinName, 
			@ReturnVoucherValue,
			@DeffCur 
		FROM 
			my000 
		WHERE GUID = @DeffCur
	END 

	-- BOOKED
	DECLARE @BookedValue FLOAT 
	SELECT @BookedValue = 
		SUM (CASE Type 
				WHEN 2 THEN 1
				WHEN 3 THEN 0
				ELSE -1
			END * Payment / (CASE CurrencyValue WHEN 0 THEN 1 ELSE CurrencyValue END))
	FROM 
		POSOrder000 orders 
	WHERE 
		(Orders.[Date] >= @RestDate OR @RestDate IS NULL)
		AND Orders.FinishCashierID = @CashierID
	IF ISNULL(@BookedValue, 0) != 0
	BEGIN 
		INSERT #Result 
		SELECT 
			11, 
			Name, 
			LatinName, 
			@BookedValue,
			@DeffCur 
		FROM 
			my000 
		WHERE GUID = @DeffCur
	END 

	INSERT #Result 
	SELECT 
		50, 
		my.Name, 
		my.LatinName, 
		SUM(TOTAL), 
		my.GUID 
	FROM 
		#Result r
		INNER JOIN my000 my ON my.GUID = r.CurrencyID
	WHERE 
		ID IN (7, 8, 9, 10) 
	GROUP BY 
		my.GUID, 
		my.Name, 
		my.LatinName

	INSERT #Result 
	SELECT 
		51, 
		my.Name, 
		my.LatinName, 
		SUM(payment.Total / payment.CurrencyValue), 
		my.GUID 
	FROM 
		POSPayRecieveTable000 payment
		INNER JOIN er000 er ON payment.GUID = er.ParentGUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
		INNER JOIN my000 my ON payment.CurrencyGUID = my.GUID

	WHERE 
		payment.PayGUID = 0x0 
		AND payment.Type = 2 
		AND( payment.InsertTime >= @RestDate OR @RestDate IS NULL)
		AND ce.CreateUserGuid = @CashierID
	GROUP BY 
		my.GUID, 
		my.Name, 
		my.LatinName

	INSERT #Result 
	SELECT 
		52, 
		nt.Name, 
		nt.LatinName, 
		SUM(payment.Total / payment.CurrencyValue), 
		payment.CurrencyGUID 
	FROM 
		POSPayRecieveTable000 payment
		INNER JOIN er000 er ON payment.GUID = er.ParentGUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
		INNER JOIN nt000 nt ON payment.PayGUID = nt.GUID
	WHERE 
		payment.PayGUID <> 0x0 
		AND payment.Type = 2 
		AND (payment.InsertTime >= @RestDate OR @RestDate IS NULL)
		AND ce.CreateUserGuid = @CashierID
	GROUP BY 
		payment.CurrencyGUID, 
		nt.Name, 
		nt.LatinName

	INSERT #Result 
	SELECT 
		53, 
		my.Name, 
		my.LatinName, 
		SUM(payment.Total / payment.CurrencyValue), 
		my.GUID 
	FROM 
		POSPayRecieveTable000 payment
		INNER JOIN er000 er ON payment.GUID = er.ParentGUID
		INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID
		INNER JOIN my000 my ON payment.CurrencyGUID = my.GUID
	WHERE 
		payment.PayGUID = 0x0 
		AND payment.Type = 1 
		AND( payment.InsertTime >= @RestDate OR @RestDate IS NULL) 
		AND ce.CreateUserGuid = @CashierID
	GROUP BY 
		my.GUID, 
		my.Name, 
		my.LatinName
	
	INSERT #Result 
	SELECT 
		54, 
		r.Name, 
		r.LatinName, 
		SUM((CASE ID WHEN 53 THEN -1 ELSE 1 END) * r.TOTAL), 
		r.CurrencyID 
	FROM 
		#Result r
	WHERE 
		ID IN (7, 9, 11, 51, 52, 53) 
	GROUP BY 
		r.CurrencyID, 
		r.Name, 
		r.LatinName

	SELECT * FROM #Result ORDER BY ID
###########################
#END
