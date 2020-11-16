#########################################################
CREATE PROC prcBill_recalcCP
AS
	-- insert cp statistics:
	SET NOCOUNT ON

	TRUNCATE TABLE [cp000]

	CREATE TABLE [#cp] ( 
		[BiGUID]		[UNIQUEIDENTIFIER], 
		[CustGUID]		[UNIQUEIDENTIFIER], 
		[CurrencyGUID]	[UNIQUEIDENTIFIER], 
		[CurrencyVal]	[FLOAT],
		[MatGUID]		[UNIQUEIDENTIFIER], 
		[BiPrice]		[FLOAT], 
		[BiDiscount]	[FLOAT], 
		[BiExtra]		[FLOAT],
		[Unity]			[FLOAT],
		[Date]			[DATE],
		[BiUnitFact]	[FLOAT],
		[BiUnitFact_2]	[FLOAT])

	;WITH Bill AS
	(
		SELECT
			bu.GUID AS BuGUID,
			bi.GUID AS BiGUID,
			rn = ROW_NUMBER() OVER (PARTITION BY bu.CustGUID, mt.GUID, bi.Unity, bu.Date ORDER BY bu.Date DESC, bu.Number DESC),
			bu.CustGUID AS CustGUID,
			mt.GUID AS MtGUID,
			bi.Unity AS BiUnity,
			bu.Date AS BuDate,
			(CASE bi.[Unity] 
				WHEN 2 THEN mt.[Unit2Fact]  
				WHEN 3 THEN mt.[Unit3Fact]  
				ELSE 1  
			END) AS BiUnitFact,
			(CASE [bi].[Unity]
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
				ELSE 1
			END) AS BiUnitFact_2
		FROM 
			bi000 bi
			INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
			INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
			INNER JOIN er000 er ON bu.GUID = er.ParentGUID
			INNER JOIN ce000 ce ON ce.GUID = er.EntryGuid
		WHERE   
			([bt].[bAffectCustPrice] <> 0)
			AND 
			([bu].[IsPosted] <> 0)  
			AND 
			([bi].[Price] <> 0)   
	)

	INSERT INTO #cp
	SELECT
		BiGUID,
		CustGUID,
		0x0,	-- CurrencyGUID
		0,		-- CurrencyVal
		MtGUID,
		0,		-- BiPrice
		0,		-- BiDiscount
		0,		-- BiExtra
		BiUnity,
		BuDate,
		BiUnitFact,
		BiUnitFact_2
	FROM
		Bill
	WHERE 
		rn = 1

	IF EXISTS(SELECT * FROM #cp)
	BEGIN
		UPDATE cp
		SET
			[CurrencyVal] = CASE WHEN mt.CurrencyGUID = bu.CurrencyGUID THEN bu.CurrencyVal ELSE dbo.fnGetCurVal(mt.CurrencyGUID, bu.Date) END,
			[CurrencyGUID] = mt.CurrencyGUID,
			[BiPrice] = (CASE cp.BiUnitFact_2 WHEN 0 THEN 0 ELSE [bi].[Price] / cp.BiUnitFact_2 END) *
				(CASE bt.[VATSystem]  WHEN 2 THEN  (1 + (bi.[VATRatio] / 100)) ELSE 1 END) * cp.BiUnitFact,
			[BiDiscount] = bi.Discount / (CASE bi.Qty WHEN 0 THEN 1 ELSE bi.Qty END)  * cp.BiUnitFact,
			[BiExtra] = bi.Extra / (CASE bi.Qty WHEN 0 THEN 1 ELSE bi.Qty END) * cp.BiUnitFact
		FROM 
			#cp cp
			INNER JOIN bi000 bi ON bi.GUID = cp.BiGUID
			INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
			INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID

		INSERT INTO cp000 (
			[Price],
			[Unity],
			[CustGUID],
			[MatGUID],
			[DiscValue],
			[ExtraValue],
			[CurrencyVal],
			[CurrencyGUID],
			[Date],
			[BiGUID],
			[IsTransfered])
		SELECT 
			[BiPrice],
			[Unity],
			[CustGUID],
			[MatGUID],
			[BiDiscount],
			[BiExtra],
			[CurrencyVal],
			[CurrencyGUID],
			Date,
			[BiGUID],
			0
		FROM
			#cp
	END

	INSERT INTO cp000 (
		[Price],
		[Unity],
		[CustGUID],
		[MatGUID],
		[DiscValue],
		[ExtraValue],
		[CurrencyVal],
		[CurrencyGUID],
		[Date],
		[BiGUID],
		[IsTransfered])
	SELECT 
		[Price],
		[Unity],
		[CustGUID],
		[MatGUID],
		[DiscValue],
		[ExtraValue],
		[CurrencyVal],
		[CurrencyGUID],
		[Date],
		0x0,
		1
	FROM 
		[TransferedCP000] cp
	WHERE NOT EXISTS(SELECT 1 FROM cp000 WHERE CustGUID = cp.CustGUID AND MatGUID = cp.MatGUID AND Unity = cp.Unity)
#########################################################
#END
