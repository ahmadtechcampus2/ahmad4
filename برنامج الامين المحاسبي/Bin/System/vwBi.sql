#########################################################
CREATE VIEW vwBi
AS      
	SELECT
		[GUID] AS [biGUID],
		[ParentGUID] AS [biParent],
		[Number] AS [biNumber],
		[StoreGUID] AS [biStorePtr],
		[Notes] AS [biNotes],
		[Unity] AS [biUnity],
		[MatGUID] AS [biMatPtr],
		[Price] AS [biPrice],
		[CurrencyGUID] AS [biCurrencyPtr],
		[CurrencyVal] AS [biCurrencyVal],
		ISNULL([Discount], 0) AS [biDiscount],
		ISNULL([BonusDisc], 0) AS [biBonusDisc],
		ISNULL([Extra], 0) AS [biExtra],
		[VAT] AS [biVAT], -- is the value of bi VAT calculated from c.
		([VAT] + ISNULL(ExciseTaxVal, 0) + ISNULL(ReversChargeVal, 0)) AS [biTotalTaxValue],
		[VATRatio] AS [biVATr], -- VAT Ration is the original value found in bi000
		[Qty] AS [biQty],
		[Qty2] AS [biQty2],
		[Qty3] AS [biQty3],
		[BonusQnt] AS [biBonusQnt],
		[Profits] AS [biProfits],
		[UnitCostPrice] AS [biUnitCostPrice],
		[ExpireDate] AS [biExpireDate],
		[ProductionDate] AS [biProductionDate],
		[CostGUID] AS [biCostPtr],
		[ClassPtr] AS [biClassPtr], 
		[Length] AS [biLength], 
		[Width] AS [biWidth], 
		[Height] AS [biHeight],
		[Count] AS [biCount],
		[SOType] AS [biSOType],
		[SOGuid] AS [biSOGuid],
		[VatRatio] AS [biVatRatio],
		TotalDiscountPercent AS biTotalDiscountPercent,
		TotalExtraPercent AS biTotalExtraPercent,
		TaxCode AS biTaxCode,
		ExciseTaxVal AS biExciseTaxVal,
		ExciseTaxPercent AS biExciseTaxPercent,
		PurchaseVal AS biPurchaseVal,
		ReversChargeVal AS biReversChargeVal,
		ExciseTaxCode AS biExciseTaxCode,
		LCDisc AS biLCDisc,
		LCExtra AS biLCExtra,
		CustomsRate AS biCustomsRate,
		OrginalTaxCode AS [biOrginalTaxCode]
	FROM      
		[bi000] AS [bi]  

#########################################################
#END