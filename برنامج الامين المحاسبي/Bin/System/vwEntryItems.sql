#########################################################
CREATE VIEW vwEntryItems
AS
SELECT
	en.Number,
	en.[Date],
	en.Debit,
	en.Credit,
	en.Notes,
	en.CurrencyVal,
	en.Class,
	en.Num1,
	en.Num2,
	en.Vendor,
	en.SalesMan,
	en.[GUID],
	en.ParentGUID,
	en.AccountGUID,
	ac.Code AS acCode,
	ac.[Name] AS acName,
	ac.LatinName AS acLatinName,
	ac.Security AS acSecurity,
	en.CurrencyGUID,
	en.CostGUID,
	en.ContraAccGUID,
	en.AddedValue,
	en.ParentVATGuid,
	en.BiGUID,
	CASE ISNULL(et.GUID, 0x0) WHEN 0x0 THEN 0 ELSE en.Type END AS [Type],
	[dbo].[fnItemSecViol]([en].[accountGuid], 0x0, 0x0, [en].[costGuid]) AS [SecViol],
	(CASE ISNULL(ac.AddedValueAccGUID, 0x0) WHEN 0x0 THEN ISNULL(et.TaxAccountGUID, 0x0) ELSE ac.AddedValueAccGUID END) AS AddedValueAccGUID,
	ac.IsDefaultAddedValueFixed,
	ac.IsUsingAddedValue,
	ac.DefaultAddedValue,
	ISNULL(et.TaxAccountGUID, 0x0) AS TaxAccountGUID,
	ISNULL(et.TaxType, 0) AS TaxType,
	LCGUID,
	en.CustomerGUID,
	en.GCCOriginDate, 
	en.GCCOriginNumber
FROM [en000] AS [en]
	 INNER JOIN [vtac] AS [ac] ON [en].[AccountGUID] = [ac].[GUID]
	 INNER JOIN [ce000] AS [ce] ON [ce].[GUID] = [en].[ParentGUID]
	 LEFT JOIN [et000] AS [et] ON [et].[GUID] = [ce].[TypeGUID]
##########################################################
#END
