#########################################################
CREATE VIEW vwMa
AS
	SELECT
		[GUID] AS [maGUID],
		[Type] AS [maType],
		[objGUID] AS [maObjGUID],
		[BillTypeGUID] AS [maBillTypeGUID],
		[MatAccGUID] AS [maMatAccGUID],
		[DiscAccGUID] AS [maDiscAccGUID],
		[ExtraAccGUID] AS [maExtraAccGUID],
		[VATAccGUID] AS [maVATAccGUID],
		[StoreAccGUID] AS [maStoreAccGUID],
		[CostAccGUID] AS [maCostAccGUID],
		[BonusAccGuid] AS [maBonusAccGuid],
		[BonusContraAccGuid] AS [maBonusContraAccGuid],
		[CashAccGUID] AS [maCashAccGUID]
	FROM
		[ma000]

#########################################################
#END
