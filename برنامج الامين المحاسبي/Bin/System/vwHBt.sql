#########################################################
CREATE VIEW vtHBt
AS
	SELECT * FROM [HBt000]

#########################################################
CREATE VIEW vbHBt
AS
	SELECT [HBt].*
	FROM 
		[vtHBt] AS [HBt] 
		INNER JOIN [vwBt] AS [bt] ON [bt].[btGUID] = [HBt].[BillTypeGUID]
#########################################################
CREATE VIEW vcHBt
AS
	SELECT * FROM [vbHBt]

#########################################################
CREATE VIEW vwHBt
AS
	SELECT
		[GUID] AS [hbtGUID], 
		[Name] AS [hbtName], 
		[LatinName] AS [hbtLatinName], 
		[SortNum] AS [hbtSortNum], 
		[BillTypeGUID] AS [hbtBillTypeGUID], 
		[DefGroupGUID] AS [hbtDefGroupGUID], 
		[DefCostGUID] AS [hbtDefCostGUID], 
		[DefStoreGUID] AS [hbtDefStoreGUID], 
		[HCoord] AS [hbtHCoord], 
		[VCoord1] AS [hbtVCoord1], 
		[VCoord2] AS [hbtVCoord2], 
		[VCoord3] AS [hbtVCoord3], 
		[FldDiscValue] AS [hbtFldDiscValue], 
		[FldExtraValue] AS [hbtFldExtraValue], 
		[FldDiscRatio] AS [hbtFldDiscRatio], 
		[FldExtraRatio] AS [hbtFldExtraRatio], 
		[FldTotalQty] AS [hbtFldTotalQty], 
		[FldPrice] AS [hbtFldPrice], 
		[FldTotalPrice] AS [hbtFldTotalPrice], 
		[bCostFld] AS [hbtBCostFld], 
		[bStoreFld] AS [hbtBStoreFld], 
		[bCurrencyFld] AS [hbtBCurrencyFld], 
		[bVendorFld] AS [hbtBVendorFld], 
		[bSalesManFld] AS [hbtBSalesManFld], 
		[bAutoVCoord] AS [hbtBAutoVCoord],
		[FldQtyFlds] AS [hbtFldQtyFlds]
	FROM  
		[vbHBt] 
#########################################################
#END

