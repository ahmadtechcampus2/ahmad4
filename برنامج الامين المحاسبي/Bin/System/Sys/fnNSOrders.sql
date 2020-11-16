################################################################################
CREATE PROCEDURE NSPrcGetOrderStates
	@SrcGuids      AS NVARCHAR(max)
As
	SET NOCOUNT ON
create table #OrderStates
(
Name nvarchar(25),
Number int, 
StateType int
)

DECLARE @SrcGuid AS VARCHAR(37)
WHILE len(@SrcGuids) > 0
BEGIN
	SET @SrcGuid=(SELECT substring(@SrcGuids,1,36))
	INSERT INTO #OrderStates(Name,Number,StateType)
	SELECT oit.Name,oit.Number,oit.Type 
	FROM oit000 oit
	INNER JOIN oitvs000 oitvs on oitvs.ParentGuid = oit.GUID
	and oitvs.Selected=1
	and oitvs.OTGUID = (select convert(UNIQUEIDENTIFIER, @SrcGuid))
	SET @SrcGuids=(SELECT replace(@SrcGuids,@SrcGuid,''))
END
	SELECT  DISTINCT * FROM #OrderStates
################################################################################
CREATE FUNCTION fnGetOrdersDueDates()
RETURNS @result TABLE 
(
		[Guid] UNIQUEIDENTIFIER,
		Number INT,
		IsPayment BIT,
		ParentGuid UNIQUEIDENTIFIER,
		DueDate DATETIME,
		Value FLOAT,
		CurrencyGuid UNIQUEIDENTIFIER,
		CurrencyValue FLOAT,
		Paid FLOAT,
		Remainder FLOAT
)
BEGIN 
	DECLARE @OrderCurrencyGUID AS UNIQUEIDENTIFIER
	DECLARE @OrderCurrencyValue AS INT
	SELECT @OrderCurrencyGUID = buCurrencyPtr, @OrderCurrencyValue = buCurrencyVal FROM vwBu 
	-- fill order payment info from orAddInfo000
	INSERT INTO @result
	SELECT 
		o.PaymentGuid,
		o.PaymentNumber,  -- Number
		0, -- IsPayment
		o.BillGuid,
		o.PaymentDate,
		o.PaymentValueWithCurrency / (CASE WHEN bu.CurrencyVal <> 0 THEN bu.CurrencyVal ELSE 1 END) AS PaymentValue, -- Value
		bu.CurrencyGUID, -- CurrencyGuid
		bu.CurrencyVal,  -- CurrencyValue
		0,  -- Paid
		0  -- Remainder
	FROM
		vwOrderPayments o
		INNER JOIN bu000 bu ON o.BillGuid = bu.Guid
		INNER JOIN bt000 bt ON bu.TypeGuid = bt.Guid

	
	INSERT INTO @result
	SELECT 
		ISNULL(en.[Guid], bi.buGuid),
		o.PaymentNumber,
		1,
		o.PaymentGuid, -- ParentGuid
		ISNULL(en.[Date], bi.buDate),
		(CASE WHEN bp.CurrencyGUID <> @OrderCurrencyGUID THEN (CASE WHEN bp.CurrencyVal = 1 THEN bp.Val / @OrderCurrencyValue ELSE bp.Val END) ELSE bp.Val / @OrderCurrencyValue END),
		bp.CurrencyGUID,
		bp.CurrencyVal,
		0,
		0
	FROM 
		bp000 bp
		INNER JOIN vwOrderPayments o ON (bp.DebtGUID = o.PaymentGuid OR  bp.PayGUID = o.PaymentGuid) 
		LEFT JOIN vwOrderPayments oPay ON (bp.DebtGUID = oPay.PaymentGuid OR  bp.PayGUID = oPay.PaymentGuid) 
		LEFT JOIN en000 en ON bp.DebtGUID = en.[Guid] OR bp.PayGUID = en.[Guid]
		LEFT JOIN ce000 ce ON en.ParentGUID = ce.[GUID]
		LEFT JOIN er000 er ON er.EntryGUID = ce.[GUID]
		LEFT JOIN py000 py ON py.[GUID] = er.ParentGUID
		LEFT JOIN et000 et ON et.[Guid] = ce.TypeGUID
		LEFT JOIN my000 my ON my.[GUID] = bp.CurrencyGUID
		LEFT JOIN vwExtended_bi bi ON bi.buGuid = parentpayguid;
	WITH payments AS
	(
		SELECT
			Sum(Value) AS Value,
			ParentGuid
		FROM 
			@result
		WHERE 
			IsPayment = 1
		GROUP BY 
			ParentGuid
	)
	UPDATE r
	SET
		r.Paid = ISNULL(p.Value, 0),
		r.Remainder = r.Value - ISNULL(p.Value, 0)
	FROM 
		@result r 
		LEFT JOIN payments p ON p.ParentGuid = r.Guid
	WHERE 
		r.IsPayment = 0;

	DELETE FROM @result WHERE IsPayment = 1 OR Remainder = 0;
	return
END 
################################################################################
#END
