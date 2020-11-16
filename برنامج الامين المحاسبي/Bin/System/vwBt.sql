#########################################################
CREATE VIEW vtBt
AS
	SELECT * FROM [bt000]

#########################################################
CREATE VIEW vbBt
AS
	SELECT [v].*
	FROM [vtBt] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcBt
AS
	SELECT 
		* 
	FROM 
		[vbBt]

#########################################################
CREATE VIEW vcBt1
AS
	SELECT * FROM [vcBt]
	WHERE [Type] = 1

#########################################################
CREATE VIEW vcBt2
AS
	SELECT * FROM [vcBt]
	WHERE [Type] = 2

#########################################################
CREATE VIEW vdBt
AS
	SELECT 
		b.*, 
		ma.CashAccGUID AS maCashAccGUID
	FROM 
		[vbBt] b left join ma000 ma
		ON b.GUID = ma.BillTypeGUID 
		and ma.ObjGUID = dbo.fnGetCurrentUserGUID() 
		and ma.Type = 3

#########################################################
CREATE VIEW vwBt
AS  
	SELECT  
		[GUID] AS [btGUID],  
		[Type] AS [btType],  
		[SortNum] AS [btSortNum],  
		[BillGroup] AS [btBillGroup],  
		[BillType] AS [btBillType],  
		[Name] AS [btName],  
		[LatinName] AS [btLatinName],  
		[Abbrev] AS [btAbbrev],  
		[LatinAbbrev] AS [btLatinAbbrev],  
		[Color1] AS [btColor1],  
		[Color2] AS [btColor2],  
		[DefPrice] AS [btDefPrice],  
		[DefCostPrice] AS [btDefCostPrice],  
		[DefBonusPrice] AS [btDefBonusPrice], 
		[DefStoreGUID] AS [btDefStore],  
		[DefBillAccGUID] AS [btDefBillAcc],  
		[DefCashAccGUID] AS [btDefCashAcc],  
		[DefDiscAccGUID] AS [btDefDiscAcc],  
		[DefExtraAccGUID] AS [btDefExtraAcc],  
		[DefVATAccGUID] AS [btDefVATAcc],  
		[DefCostAccGUID] AS [btDefCostAcc],  
		[DefStockAccGUID] AS [btDefStockAcc],  
		[DefBonusAccGuid] AS [btDefBonusAccGuid], 
		[DefBonusContraAccGuid] AS [btDefBonusContraAccGuid], 
		CAST([bIsInput] AS INT) AS [btIsInput],  
		CAST([bIsOutput] AS INT) AS [btIsOutput],  
		CASE [bIsInput] WHEN 1 THEN 1 ELSE -1 END AS [btDirection], 
		[VATSystem] AS [btVATSystem], 
		[bAffectCostPrice] AS [btAffectCostPrice],  
		[bAffectLastPrice] AS [btAffectLastPrice],  
		[bAffectCustPrice] AS [btAffectCustPrice],  
		[bAffectProfit] AS [btAffectProfit],  
		[bDiscAffectProfit] AS [btDiscAffectProfit],  
		[bExtraAffectProfit] AS [btExtraAffectProfit],  
		[bVATAffectProfit] AS [btVATAffectProfit],  
		[bDiscAffectCost] AS [btDiscAffectCost],  
		[bExtraAffectCost] AS [btExtraAffectCost],  
		[bVATAffectCost] AS [btVATAffectCost],  
		[bNoEntry] AS [btNoEntry],  
		[bAutoEntry] AS [btAutoEntry],  
		[bAutoEntryPost] AS [btAutoEntryPost],  
		[bNoPost] AS [btNoPost],  
		[bAutoPost] As [btAutoPost],  
		[bExtraToCash] AS [btExtraToCash],  
		[bNoCostFld] AS [btNoCostFld],  
		[bNoStatFld] AS [btNoStatFld],  
		[bNoVendorFld] AS [btNoVendorFld],  
		[bNoSalesManFld] AS [btNoSalesManFld],  
		[bContInv] AS [btContInv],  
		[bBarCodeBill] AS [btBarCodeBill],  
		[bPOSBill] AS [btPOSBill],  
		[bPrintReceipt] AS [btPrintReceipt],  
		[bCostToItems] AS [btCostToItems],  
		[bCostToCust] AS [btCostToCust],  
		[bCostToTaxAcc] AS [btCostToTaxAcc],  
		[bGenContraAcc] AS [btAutoGenContraAcc],  
		[bShortEntry] AS [btShortEntry],  
		[bCollectCustAccount] AS [btCollectCustAccount],  
		[FldName] AS [btFldName],  
		[FldCode] AS [btFldCode],  
		[FldLatinName] AS [btFldLatinName],  
		[FldBarCode] AS [btFldBarCode],  
		[FldBarCode2] AS [btFldBarCode2],  
		[FldBarCode3] AS [btFldBarCode3],  
		[FldUnity] AS [btFldUnity],  
		[FldUnitPrice] AS [btFldUnitPrice],  
		[FldTotalPrice] AS [btFldTotalPrice],  
		[FldBonus] AS [btFldBonus],  
		[FldBonusDisc] AS [btFldBonusDisc],  
		[FldStore] AS [btFldStore],  
		[FldCostPtr] AS [btFldCostPtr],  
		[FldStat] AS [btFldStat],  
		[FldLength] AS [btFldLength],  
		[FldWidth] AS [btFldWidth],  
		[FldHeight] AS [btFldHeight],  
		[FldCount] AS [btFldCount],
		[FldDiscValue] AS [btFldDiscValue],  
		[FldExtraValue] AS [btFldExtraValue],  
		[FldDiscRatio] AS [btFldDiscRatio],  
		[FldExtraRatio] AS [btFldExtraRatio],  
		[FldQty] AS [btFldQty],  
		[FldQty2] AS [btFldQty2],  
		[FldQty3] AS [btFldQty3],  
		[FldProdDate] AS [btFldProdDate],  
		[FldExpireDate] AS [btFldExpireDate],  
		[FldNotes] AS [btFldNotes],  
		[FldVAT] AS [btFldVAT],  
		[FldVATR] AS [btFldVATR],  
		[FldSpec] AS [btFldSpec],  
		[FldGroup] AS [btFldGroup],  
		[FldSize] AS [btFldSize],  
		[FldPos] AS [btFldPos],  
		[FldOrigin] AS [btFldOrigin],  
		[FldCompany] AS [btFldCompany],  
		[FldColor] AS [btFldColor],  
		[FldProvenance] AS [btFldProvenance],  
		[FldQuality] AS [btFldQuality],  
		[FldModel] AS [btFldModel],  
		[FldWholePrice] AS [btFldWholePrice],  
		[FldSpecialPrice] AS [btFldSpecialPrice],  
		[FldVendorPrice] AS [btFldVendorPrice],  
		[FldExportPrice] AS [btFldExportPrice],  
		[FldRetailPrice] AS [btFldRetailPrice],  
		[FldEndUserPrice] AS [btFldEndUserPrice],  
		[FldLastPrice] AS [btFldLastPrice],  
		[FldMaxPrice] AS [btFldMaxPrice],  
		[FldAvgPrice] AS [btFldAvgPrice],  
		[FldCustPrice] AS [btFldCustPrice],  
		[FldUnit1] AS [btFldUnit1],  
		[FldUnit2] AS [btFldUnit2],  
		[FldUnit2Factor] AS [btFldUnit2Factor],  
		[FldUnit3] AS [btFldUnit3],  
		[FldUnit3Factor] AS [btFldUnit3Factor],  
		[FldDefUnit] AS [btFldDefUnit],  
		[FldDefUnitFactor] AS [btFldDefUnitFactor],  
		[FldCurQty] AS [btFldCurQty],  
		[FldCurStoreQty] AS [btFldCurStoreQty],  
		[FldMaxLimit] AS [btFldMaxLimit],  
		[FldMinLimit] AS [btFldMinLimit],  
		[FldType] AS [btFldType], 
		[branchMask] AS [btBranchMask],

		(CASE -- SortFlag 
			
			WHEN (([Type] = 2) AND ([SortNum]  = 1) ) THEN 10 
			WHEN (([Type] = 1) AND ([bIsInput]  = 1) AND ([bAffectCostPrice] = 1)) THEN 20  
			WHEN (([Type] = 1) AND ([bIsInput]  = 1) AND ([bAffectCostPrice] = 0)) THEN 30 
			WHEN (([Type] = 2) AND ([SortNum]  = 5) ) THEN 35 
			WHEN (([Type] = 2) AND ([SortNum]  = 6) ) THEN 145
			WHEN (([Type] = 2) AND ([bIsOutput] = 1) AND ([bAffectCostPrice] = 1)) THEN 40
			WHEN (([Type] = 2) AND ([bIsOutput] = 1) AND ([bAffectCostPrice] = 0)) THEN 50 
			WHEN ([Type] = 3) THEN 60 
			WHEN (([Type] = 7) AND ([bIsOutput] = 1)) THEN 147
			WHEN (([Type] = 2) AND ([bIsInput]  = 1) AND ([bAffectCostPrice] = 1) AND ([SortNum]  <> 1)) THEN 80  
			WHEN (([Type] = 2) AND ([bIsInput]  = 1) AND ([bAffectCostPrice] = 0) AND ([SortNum]  <> 1)) THEN 90  
			WHEN ([Type] = 4) THEN 100 
			WHEN ([Type] = 8) THEN 37
			WHEN (([Type] = 1) AND ([bIsOutput] = 1) AND ([bAffectCostPrice] = 1)) THEN 130 
			WHEN (([Type] = 1) AND ([bIsOutput] = 1) AND ([bAffectCostPrice] = 0)) THEN 140 
			WHEN ([Type] = 5) THEN 150
			WHEN ([Type] = 6) THEN 160
			WHEN ([Type] = 9) THEN 170
			WHEN ([Type] = 10) THEN 180
			ELSE -1 
		END) AS [btSortFlag],
		[DefBranchGUID],
		[FixedDefaultValues],
		[useSalesTax] AS [btUseSalesTax],
		[TaxBeforeDiscount] AS [btTaxBeforeDiscount],
		[TaxBeforeExtra] AS [btTaxBeforeExtra],
		[IncludeTTCDiffOnSales] AS [btIncludeTTCDiffOnSales],
		[IsStopDate],
		[StopDate], 
		[DefCurrencyGUID],
		[isApplyTaxOnGifts], 
		[bCostToDiscount] AS [btCostToDiscount],
		NoAddExistBill AS btNoAddExistBill,
		DefaultGroupGUID AS btDefGroupGUID,
		[bContraCostToDiscount] AS [btContraCostToDiscount],
		DefMainAccount AS btDefMainAccount,
		[ConsideredGiftsOfSales] AS btConsideredGiftsOfSales,
		[TotalDiscRegardlessItemDisc],
		[TotalExtraRegardlessItemExtra],
		[FldClassPrice] AS [btFldClassPrice],
		DefaultLocationGUID,
		UseExciseTax AS btUseExciseTax,
		UseReverseCharges AS btUseReverseCharges,
		ShowCustAddress AS btShowCustAddress,
		ShowOrderEvaluation AS btShowOrderEvaluation
	FROM  
		[vbBt] 
		
/*  
SortFlag:  
	 0:	standard		in		cost  
	 1:	non-standard	in		cost  
	 2:	standard		in		no-cost  
	 3:	non-standard	in		no-cost  
	 4:	standard		out		cost  
	 5:	non-standard	out		cost  
	 6:	standard		out		no-cost  
	 7:	non-standard	out		no-cost 
	 8: transferes      out
	 9: transferes      in
	10: Assemble        out
	11: Assemble        in
	12: Sell Order				no-cost
	13: Purchase Order			no-cost
	-1: error <type not defined> 
*/  


#########################################################	
#END