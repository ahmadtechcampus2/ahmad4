#########################################################
CREATE PROCEDURE prcBillType_GetDefAccs
	@btGUID [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON 
	
	DECLARE @DefAcc TABLE( [accGUID] [UNIQUEIDENTIFIER])
	
	INSERT INTO @DefAcc 
	-- DefAccGUID
	SELECT [DefBillAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefDiscGUID
	UNION ALL
	SELECT [DefDiscAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefExtraAcc
	UNION ALL
	SELECT [DefExtraAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefVATAcc
	UNION ALL
	SELECT [DefVATAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefBonusAcc
	UNION ALL
	SELECT [DefBonusAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefBonusContraAcc
	UNION ALL
	SELECT [DefBonusContraAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefCostAccGUID
	UNION ALL
	SELECT [DefCostAccGUID] FROM [bt000] WHERE [GUID] = @btGUID
	-- DefStockAcc
	UNION ALL
	SELECT [DefStockAccGUID] FROM [bt000] WHERE [GUID] = @btGUID

	SELECT 
		[ac].[GUID] AS [acGUID], 
		[ac].[Code] AS [acCode], 
		[ac].[Name] AS [acName],
		[ac].[LatinName] AS [acLatinName], 
		[ac].[Type] AS [acType], 
		[ac].[NSons] AS [acNSons]
	FROM 
		[ac000] [ac] 
		INNER JOIN @DefAcc [def] ON [def].[accGUID] = [ac].[GUID]
#########################################################
CREATE PROCEDURE prcGetInfoUnpostedMatQty
	@MatGuid UNIQUEIDENTIFIER
AS
	SELECT SUM((Qty + BonusQnt) * CASE bISInput WHEN 1 THEN 1 ELSE -1 END) AS [msQty],CAST(0x00 AS UNIQUEIDENTIFIER) AS [biStorePtr],'' AS StName,[IsPosted] as [buIsPosted] FROM bi000 bi INNER JOIN bu000 bu ON bu.Guid = bi.ParentGuid INNER JOIN bt000 bt ON bt.Guid = BU.TypeGuid  WHERE MatGuid = @MatGuid
	GROUP BY [IsPosted] HAVING  SUM((Qty + BonusQnt) * CASE bISInput WHEN 1 THEN 1 ELSE -1 END) <> 0 
	UNION ALL 
	SELECT SUM((Qty + BonusQnt) * CASE bISInput WHEN 1 THEN 1 ELSE -1 END) AS [msQty],bi.[StoreGuid][biStorePtr], StName,[IsPosted] as [buIsPosted] FROM bi000 bi INNER JOIN bu000 bu ON bu.Guid = bi.ParentGuid INNER JOIN bt000 bt ON bt.Guid = BU.TypeGuid  INNER JOIN vwSt st ON bi.StoreGuid = st.stGuid WHERE MatGuid = @MatGuid
	GROUP BY [IsPosted],bi.[StoreGuid] ,[StName] HAVING  SUM((Qty + BonusQnt) * CASE bISInput WHEN 1 THEN 1 ELSE -1 END) <> 0 ORDER BY [StName]
#########################################################
#END