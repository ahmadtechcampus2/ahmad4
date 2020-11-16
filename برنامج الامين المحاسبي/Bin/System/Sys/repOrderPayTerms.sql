#######################################
CREATE PROCEDURE repOrderPayTerms
	@OrderGuid UNIQUEIDENTIFIER
AS
	SELECT
		orInf.GUID AS OrderInfoGuid,
		orInf.PTType AS PayTermType,
		orInf.PTOrderDate AS OrderDateType,
		orInf.PTDaysCount AS DaysCount,
		orInf.PTDate AS OrderPayDate,
		bu.Total / (CASE WHEN bu.CurrencyGUID <> 0x00 THEN (CASE WHEN bu.CurrencyVal <> 0 THEN bu.CurrencyVal ELSE 1 END) ELSE 1 END) AS Total,
		bt.Name + ': ' + CAST(bu.Number AS NVARCHAR) AS BillName,
		orInf.SSDATE,
		orInf.SADATE,
		orInf.SDDATE,
		orInf.ASDATE,
		orInf.AADATE,
		orInf.ADDATE,
		orInf.SPDATE AS PDate,
		orInf.ExpectedDate AS ExpectedDeliverDate,
		ISNULL(op.PayDate, GetDate()) AS PayDate,
		ISNULL(op.Percentage, 0.0) AS PayPercentage,
		ISNULL(op.Value, 0) / (CASE WHEN bu.CurrencyVal <> 0 THEN ISNULL(bu.CurrencyVal, 1)ELSE 1 END) AS PayValue
	FROM
		OrAddinfo000 orInf
		INNER JOIN bu000 bu ON bu.Guid = orInf.ParentGuid
		INNER JOIN bt000 bt ON bt.Guid = bu.TypeGuid
		LEFT JOIN OrderPayments000 op ON op.BillGuid = orInf.ParentGuid
	WHERE 
		orInf.ParentGuid = @OrderGuid
	ORDER BY 
		ISNULL(op.Number, 0),
		ISNULL(op.PayDate, GetDate())
#########################################
#END