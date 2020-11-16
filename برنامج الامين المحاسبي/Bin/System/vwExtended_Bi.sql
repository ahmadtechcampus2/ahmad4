#########################################################
CREATE VIEW vwExtended_bi
AS 
	SELECT  
		[bu].[buGUID],  
		[bu].[buType],  
		[bu].[buNumber],  
		[bu].[buIsPosted],  
		[bu].[buCostPtr],  
		[bu].[buSecurity],  
		[bu].[buDate],  
		[bu].[buDate] AS [buMaturityDate], -- changed this field to MaturityDate, 
		[bu].[buNotes],  
		[bu].[buVendor],  
		[bu].[buSalesmanPtr],   
		[bu].[buCust_Name],  
		[bu].[buStorePtr],  
		[bu].[buPayType],  
		[bu].[buIsCash],  
		[bu].[buCustPtr],  
		[bu].[buMatAcc],  
		[bu].[buCurrencyPtr],  
		[bu].[buCurrencyVal],  
		[bu].[buTotal],  
		[bu].[buTotalExtra],  
		[bu].[buTotalDisc],  
		[bu].[buItemsDisc],  
		[bu].[buItemsExtra],  
		[bu].[buBonusDisc],  
		[bu].[buSortFlag],  
		[bu].[buDirection],  
		[bu].[btDirection], 
		[bu].[buProfits],  
		[bu].[buVAT],  
		[bu].buTotalSalesTax,
		[bu].[buCustAcc],  
		[bu].[buFirstPay],  
		[bu].[buFPayAcc],  
		[bu].[buUserGUID], 
		[bu].[btBillType],  
		[bu].[btType], 
		[bu].[btName],  
		[bu].[btLatinName],  
		[bu].[btAbbrev], 
		[bu].[btLatinAbbrev], 
		[bu].[btDefBillAcc],  
		[bu].[btIsInput],  
		[bu].[btIsOutput],  
		[bu].[btAffectLastPrice],  
		[bu].[btAffectCostPrice],  
		[bu].[btAffectProfit],  
		[bu].[btAffectCustPrice],  
		[bu].[btDiscAffectCost],  
		[bu].[btExtraAffectCost],  
		[bu].[btDiscAffectProfit],  
		[bu].[btExtraAffectProfit],  
		[bu].[btExtraToCash],
		[bu].[isApplyTaxOnGifts],  
		[bu].[buCheckTypeGUID], 
		[bu].[buFormatedNumber], 
		[bu].[buLatinFormatedNumber], 
		[bu].[buBranch], 
		[bu].[btVATSystem], 
		[bu].[buTextFld1],
		[bu].[buTextFld2],
		[bu].[buTextFld3],
		[bu].[buTextFld4],
		[bu].[buLCGUID],
		[bu].[buLCType],
		[bu].[btTaxBeforeDiscount],
		[bu].[btTaxBeforeExtra],
		[bu].[btIncludeTTCDiffOnSales],
		[bu].[ReturendBillNumber] AS [buReturendBillNumber],
		[bu].[ReturendBillDate] AS [buReturendBillDate],
		[bu].[buTotalTaxValue],
		[bu].[buCustomerAddressGUID],
		[bi].[biGUID],  
		[bi].[biNumber],  
		[bi].[biStorePtr],  
		[bi].[biNotes],  
		[bi].[biUnity],  
		[bi].[biMatPtr],  
		[bi].[biPrice],		
		(CASE [bi].[mtUnitFact] WHEN 0 THEN 0 ELSE [bi].[biPrice] / [bi].[mtUnitFact] END) AS [biUnitPrice],  
		((CASE (buTotal - buItemsDisc) WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biDiscount] / [biQty] END) + [biBonusDisc] ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biDiscount] / [biQty]) END) + (
			ISNULL(Discount, 0) * (biPrice - (CASE biDiscount WHEN 0 THEN 0 ELSE biDiscount / biQty END) * CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END ) / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END
			) / (buTotal - buItemsDisc)) END) + (CASE biQty WHEN 0 THEN 0 ELSE (biBonusDisc / biQty) END)) AS [biUnitDiscount],  
		((CASE (buTotal + buItemExtra)    WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biExtra] / [biQty] END) ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] / [biQty]) END) + (
			ISNULL(Extra,0) * (biPrice + (CASE biExtra WHEN 0 THEN 0 ELSE biExtra / biQty END) * CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END ) / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END
			) / (buTotal + buItemExtra)) END)) AS [biUnitExtra],
		[bi].[biCurrencyPtr],  
		[bi].[biCurrencyVal],  
		[bi].[biDiscount],  
		[bi].[biBonusDisc],  
		[bi].[biExtra],  
		[bi].[biVAT] AS [biVAT],  
		[bi].[biVATr],  
		[bi].[biBillQty],  
		[bi].[biBillBonusQnt],  
		[bi].[biQty],  
		[bi].[biQty2],  
		[bi].[biQty3],  
		[bi].[biCalculatedQty2],  
		[bi].[biCalculatedQty3],  
		[bi].[biExpireDate],  
		[bi].[biProductionDate],  
		[bi].[biCostPtr] AS [biOrgCostPtr],  
		(CASE ISNULL([bi].[biCostPtr], 0x0) WHEN 0x0 THEN [bu].[buCostPtr] ELSE [bi].[biCostPtr] END) AS  [biCostPtr],  
		[bi].[biClassPtr],  
		[bi].[biLength],  
		[bi].[biWidth],  
		[bi].[biHeight],  
		[bi].[biCount],
		[bi].[biBonusQnt],
		[bi].[biOrginalTaxCode],
		[bi].[mtUnitFact],  
		[bi].[mtUnityName],  
		[bi].[mtName],  
		[bi].[mtCode],  
		[bi].[mtLatinName],  
		[bi].[mtSecurity],  
		[bi].[mtFlag],  
		[bi].[mtUnit2Fact],  
		[bi].[mtUnit3Fact],  
		[bi].[mtBarCode],  
		[bi].[mtBarCode2],  
		[bi].[mtBarCode3],  
		[bi].[mtGroup],  
		[bi].[mtSpec],  
		[bi].[mtDim],  
		[bi].[mtOrigin],  
		[bi].[mtPos],  
		[bi].[mtCompany],  
		[bi].[mtColor],  
		[bi].[mtProvenance],  
		[bi].[mtQuality],  
		[bi].[mtModel],  
		[bi].[mtType],  
		[bi].[mtWhole],  
		[bi].[mtHalf],  
		[bi].[mtRetail],  
		[bi].[mtEndUser],  
		[bi].[mtExport],  
		[bi].[mtVendor],  
		[bi].[mtWhole2], 
		[bi].[mtHalf2], 
		[bi].[mtRetail2], 
		[bi].[mtEndUser2], 
		[bi].[mtExport2], 
		[bi].[mtVendor2], 
		[bi].[mtLastprice2], 
		[bi].[mtWhole3], 
		[bi].[mtHalf3], 
		[bi].[mtRetail3], 
		[bi].[mtEndUser3], 
		[bi].[mtExport3], 
		[bi].[mtVendor3], 
		[bi].[mtLastprice3], 
		[bi].[mtAvgPrice],  
		[bi].[mtLastPrice],  
		[bi].[mtMaxPrice],  
		[bi].[mtQty],  
		[bi].[MtUnity],  
		[bi].[MtUnit2],  
		[bi].[MtUnit3],  
		[bi].[mtDefUnitFact],  
		[bi].[mtDefUnit],  
		[bi].[mtDefUnitName],  
		[bi].[biProfits],  
		[bi].[biUnitCostPrice],
		[bi].[mtSNFlag],  
		[bi].[mtForceInSN],  
		[bi].[mtForceOutSN],  
		[bi].[mtExpireFlag], 
		ISNULL(T.ProfitMargin, 0) AS mtVATIsProfitMargin,
		[bi].[mtParent],
		[bi].[mtHasSegments],
		[bi].[biSOType],
		[bi].[biSOGuid],
		ISNULL(
		CASE (buTotal - buItemsDisc) 
			WHEN 0 THEN 0 
			ELSE 
				(([biPrice] * [biQty] / (CASE [biUnity] WHEN 2 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END 
					WHEN 3 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ELSE 1 END)) - biDiscount) * Discount  / (buTotal - buItemsDisc) END, 0) AS biTotalDiscountPercent,
	    ISNULL(
		CASE (buTotal + buItemsExtra)
			WHEN 0 THEN 0
			ELSE 
				(([biPrice] * [biQty] / ( CASE [biUnity] WHEN 2 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END 
					WHEN 3 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END ELSE 1 END)) + biExtra ) * Extra  / (buTotal + buItemsExtra) END, 0) AS biTotalExtraPercent,
		[bi].biTaxCode,
		[bi].biExciseTaxVal,
		[bi].biExciseTaxPercent,
		[bi].biPurchaseVal,
		[bi].biReversChargeVal,
		[bi].biExciseTaxCode,
		[bi].biLCDisc,
		[bi].biLCExtra,
		[bi].biCustomsRate,
		[bi].[biTotalTaxValue],
		[bi].[mtCompositionName],
		[bi].[mtCompositionLatinName]
	FROM  
		[vwBu] AS [bu] INNER JOIN [vwBiMt] AS [bi] ON [bu].[buGUID] = [bi].[biParent] 
		OUTER APPLY dbo.fnGCC_GetMaterialTax_VAT(bi.biMatPtr) AS T
		OUTER APPLY dbo.fnBill_GetDiSum(bu.buGUID) AS DI
#########################################################
CREATE VIEW vwExtended_bi_address
AS 
	SELECT  
		bubi.*,
		ISNULL(ad.[Country], '') AS [AddressCountry],
		ISNULL(ad.[City], '') AS [AddressCity],
		ISNULL(ad.[Area], '') AS [AddressArea],
		ISNULL(ad.[Street], '') AS [AddressStreet],
		ISNULL(ad.[BulidingNumber], '') AS [AddressBulidingNumber],
		ISNULL(ad.[FloorNumber], '') AS [AddressFloorNumber],
		ISNULL(ad.[POBox], '') AS [AddressPOBox],
		ISNULL(ad.[ZipCode], '') AS [AddressZipCode]
	FROM  
		vwExtended_bi AS bubi 
		LEFT JOIN vwCustAddress ad ON bubi.buCustomerAddressGUID = ad.GUID 
#########################################################
CREATE VIEW vwGCCMaterialTax
AS 
	SELECT 
		T.*, mt.IsCalcTaxForPUTaxCode AS IsCalcTaxForPUTaxCode
	FROM 
		GCCMaterialTax000 T
		INNER JOIN mt000 mt ON mt.GUID = T.MatGUID 
#########################################################
CREATE VIEW vwGCCCustomerTax
AS 
	SELECT 
		T.CustGUID AS CustGuid,
		T.TaxCode AS VATTaxCode,
		T.TaxNumber AS VATTaxNumber,
		ISNULL(Excise.TaxCode, 0) AS ExciseTaxCode,
		ISNULL(Excise.TaxNumber, '') AS ExciseTaxNumber,
		ISNULL(cu.GCCLocationGUID, 0x0) AS cuGCCLocationGUID,
		ISNULL(cu.ReverseCharges, 0) AS cuReverseCharges
	FROM 
		cu000 cu 
		INNER JOIN GCCCustomerTax000 T ON cu.GUID = T.CustGUID AND T.TaxType = 1 -- Vat
		LEFT JOIN GCCCustomerTax000 Excise ON cu.GUID = Excise.CustGUID AND Excise.TaxType = 2 -- Excise 
#########################################################
#END
