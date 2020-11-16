#########################################################
CREATE VIEW vwBp
AS
SELECT 
	[GUID] AS [BpGUID],
	[DebtGUID] AS [BpDebtGUID],
	[PayGUID] AS [BpPayGUID],
	[PayType] AS [BpPayType],
	[Val] AS [BpVal],
	[CurrencyGUID] AS [BpCurrencyGUID],
	[CurrencyVal] AS [BpCurrencyVal],
	[RecType] AS [BpRecType],
	[DebitType] AS [BpDebitType],
	[PayVal] AS [BpPayVal],
	[PayCurVal] AS [BpPayCurVal],
	type as Bptype
FROM 
	[bp000]
############################################################## 
CREATE FUNCTION fnGetOrderDate(@OrAddInfoGuid UNIQUEIDENTIFIER , @DateType TINYINT)
RETURNS DATE
AS
BEGIN
	RETURN (SELECT 
		CASE @DateType 
			WHEN 0 THEN SSDATE  -- «·‘Õ‰ «·„ﬁ —Õ
			WHEN 1 THEN SADATE  -- «·Ê’Ê· «·„ﬁ —Õ
			WHEN 2 THEN SDDATE  -- «· ”·Ì„ «·„ﬁ —Õ
			WHEN 3 THEN ASDATE  -- «·‘Õ‰ «·„ ›ﬁ ⁄·ÌÂ
			WHEN 4 THEN AADATE  -- «·Ê’Ê· «·„ ›ﬁ ⁄·ÌÂ 
			WHEN 5 THEN ADDATE  -- «· ”·Ì„ «·„ ›ﬁ ⁄·ÌÂ
			WHEN 6 THEN SPDATE  -- «·«⁄ „«œ
			WHEN 7 THEN APDATE  -- «· ”·Ì„ «·„ Êﬁ⁄
		END
		FROM ORADDINFO000
		WHERE Guid = @OrAddInfoGuid)		
END 
############################################################## 
CREATE VIEW vwOrderPayments
AS 
	SELECT 
		[bu].[buGuid] AS BillGuid,
		[o].[Guid] AS OrderGuid,
		[bu].[buDate] AS DueDate,

		p.[Guid] AS PaymentGuid,
		p.Number AS PaymentNumber,
		CASE WHEN o.PTType = 3 THEN 2 ELSE 
			CASE WHEN o.PTType = 0 THEN 0 ELSE 1 END
		END AS PaymentType, -- 0 = none, 1 = one payment, 2 = multipayments
		CASE WHEN p.[Guid] IS NULL THEN ((bu.buTotal + bu.buTotalExtra + bu.buVat) - (bu.buTotalDisc  + bu.buBonusDisc)) ELSE p.Value END / buCurrencyVal  AS PaymentValue,
		CASE WHEN p.[Guid] IS NULL THEN ((bu.buTotal + bu.buTotalExtra + bu.buVat) - (bu.buTotalDisc  + bu.buBonusDisc)) ELSE p.Value END AS PaymentValueWithCurrency,
		CASE o.PTType
			WHEN 1 THEN DATEADD(DAY, o.[PTDaysCount], dbo.fnGetOrderDate(o.GUID, o.PTOrderDate))
			WHEN 2 THEN o.PTDate
			WHEN 3 THEN p.PayDate
			ELSE [dbo].fnGetOrderDate(o.GUID, o.PTOrderDate)
		END AS PaymentDate,
		p.UpdatedValue AS UpdatedValueWithCurrency,
		p.UpdatedValue / buCurrencyVal  AS UpdatedValue
	FROM 
		vwbu bu 
		INNER JOIN vwbt bt ON [bt].[btGuid] = [bu].[buType]
		INNER JOIN orAddInfo000 [o] ON [o].[ParentGuid] = [bu].[buGuid] 
		LEFT JOIN OrderPayments000 p ON p.BillGuid = bu.[buGuid]
	WHERE 
		bu.[buPayType] = 1 
#########################################################
#END
