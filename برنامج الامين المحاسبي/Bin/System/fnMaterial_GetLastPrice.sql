#########################################################
CREATE FUNCTION fnMaterial_GetLastPrice (@MaterialGUID UNIQUEIDENTIFIER)
	RETURNS @Result TABLE (LastPriceDate DATE, LastPrice FLOAT, UnitFact FLOAT, LastPriceCurVal FLOAT, FromHistory BIT)
AS BEGIN 

	DECLARE @BiGUID UNIQUEIDENTIFIER
	SET @BiGUID = (SELECT TOP 1
		FIRST_VALUE(BI.GUID) OVER(ORDER BY 
			bu.date DESC,
			bt.[SortFlag] DESC,
			bu.Number DESC,
			bi.Number DESC)
	FROM 
		bu000 bu 
		INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
		INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	WHERE 
		bt.bAffectLastPrice = 1 
		AND 
		bi.matguid = @MaterialGUID
		AND
		bu.IsPosted = 1)
	
	INSERT INTO @Result
	SELECT 
		BU.Date,
		BI.Price, 
		(CASE [bi].[Unity]
			WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
			WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
			ELSE 1
		END),
		CASE WHEN bu.CurrencyGUID = mt.CurrencyGUID THEN bu.CurrencyVal ELSE [dbo].fnGetCurVal(mt.CurrencyGUID, bu.Date) END,
		0
	FROM 
		bu000 bu
		INNER JOIN bi000 bi ON bi.ParentGUID = bu.GUID 
		INNER JOIN mt000 mt ON bi.MatGUID = mt.GUID 
	WHERE bi.GUID = @BiGUID

	IF @@ROWCOUNT > 0
	BEGIN 
		UPDATE @Result 
		SET 
			LastPrice = (CASE UnitFact WHEN 0 THEN 0 ELSE LastPrice / UnitFact END),
			LastPriceCurVal = CASE LastPriceCurVal WHEN 0 THEN 1 ELSE LastPriceCurVal END
	END ELSE BEGIN 
		INSERT INTO @Result (LastPriceDate, LastPrice, UnitFact, LastPriceCurVal, FromHistory)
		SELECT Date, LastPrice, 0, CASE CurrencyVal WHEN 0 THEN 1 ELSE CurrencyVal END, 1 
		FROM [TransferedLP000] WHERE MatGUID = @MaterialGUID
	END 

	RETURN 
END
#########################################################
#END