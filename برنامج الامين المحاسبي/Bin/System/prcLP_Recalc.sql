################################################################################ 
CREATE PROC prcLP_Recalc
	@IgnoreLastPriceAndCost BIT = 0,
	@DisableTriggers		BIT = 0
AS
	SET NOCOUNT ON

	IF @DisableTriggers = 1
		EXEC prcDisableTriggers 'mt000'

	UPDATE	mt000 
	SET		DisableLastPrice = 0
	WHERE	DisableLastPrice = 1

	IF @IgnoreLastPriceAndCost = 0
	BEGIN
		UPDATE mt 
		SET  
			[LastPrice] =		0,
			[LastPrice2] =		0,
			[LastPrice3] =		0,
			[LastPriceDate] =	'19800101'
		FROM
			[mt000] mt
		WHERE NOT EXISTS(SELECT 1 FROM bi000 WHERE MatGUID = mt.GUID)
	END 

	UPDATE m
	SET 
		[DisableLastPrice] =	1,
		[LastPriceDate] =		fn.BillDate,
		[LastPrice] =			CASE fn.UnitFact WHEN 0 THEN 0 ELSE fn.Price / fn.UnitFact END,
		[LastPrice2] =			CASE fn.UnitFact WHEN 0 THEN 0 ELSE (fn.Price / fn.UnitFact) * m.Unit2Fact END,
		[LastPrice3] =			CASE fn.UnitFact WHEN 0 THEN 0 ELSE (fn.Price / fn.UnitFact) * m.Unit3Fact END,
		[LastPriceCurVal] =		CASE WHEN fn.BillCurrencyGUID != fn.MtCurrencyGUID THEN [dbo].fnGetCurVal(fn.MtCurrencyGUID, fn.BillDate) ELSE fn.BillCurrencyVal END
	FROM
		mt000 m
		CROSS APPLY (
			SELECT TOP 1 
				bu.date AS BillDate,
				bi.Price AS Price,
				(CASE [bi].[Unity]
					WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
					WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
					ELSE 1
				END) AS [UnitFact],
				bu.CurrencyGUID AS BillCurrencyGUID,
				bu.CurrencyVal AS BillCurrencyVal,
				mt.CurrencyGUID AS MtCurrencyGUID
			FROM
				bu000 bu 
				INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
				INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
				INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
			WHERE 
				bt.bAffectLastPrice = 1 
				AND 
				bi.matguid = m.GUID
				AND
				bu.IsPosted = 1
			ORDER BY 
				bu.date DESC,
				bt.[SortFlag] DESC,
				bu.Number DESC,
				bi.Number DESC) fn

	IF EXISTS (SELECT * FROM TransferedLP000)
	BEGIN 
		UPDATE mt000 
		SET 
			LastPrice =			lp.LastPrice,
			LastPrice2 =		lp.LastPrice2,
			LastPrice3 =		lp.LastPrice3,
			LastPriceCurVal =	lp.CurrencyVal,
			LastPriceDate =		lp.Date
		FROM 
			mt000 mt 
			INNER JOIN TransferedLP000 lp ON mt.GUID = lp.MatGUID 
		WHERE 
			mt.DisableLastPrice = 0
			AND 
			mt.CurrencyGUID = lp.CurrencyGUID
	END 

	IF @DisableTriggers = 1
		EXEC prcEnableTriggers 'mt000'
#########################################################
#END
