#########################################################
CREATE VIEW vwBuBi
AS
	SELECT
		[bu].[buGUID],
		[bu].[buType],
		[bu].[buNumber],
		[bu].[buCustPtr],
		[bu].[buCust_Name],
		[bu].[buDate],
		[bu].[buCurrencyPtr],
		[bu].[buCurrencyVal],
		[bu].[buNotes],
		[bu].[buTotal],
		[bu].[buStorePtr],
		[bu].[buCustAcc],
		[bu].[buMatAcc],
		[bu].[buPayType],
		[bu].[buTotalDisc],
		[bu].[buTotalExtra],
		[bu].[buItemsDisc],
		[bu].[buItemsDiscAcc],
		[bu].[buBonusDisc],
		[bu].[buBonusDiscAcc],
		[bu].[buItemsExtra],
		[bu].[buItemsExtraAcc],
		[bu].[buFirstPay],
		[bu].[buFPayAcc],
		[bu].[buProfits],
		[bu].[buIsPosted],
		[bu].[buSecurity],
		[bu].[buVendor],
		[bu].[buSalesManPtr],
		[bu].[buCostPtr],
		[bu].[btBillType],
		[bu].[buDirection],
		[bu].[buSortFlag],
		[bu].[buUserGuid],
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
		[bu].[btVATSystem],
		[bu].[btAbbrev], 
		[bu].[btLatinAbbrev],
		[bu].[buBranch],
		[bu].[buVat],
		[bu].[buTotalSalesTax],
		[bu].[buFormatedNumber],
		[bu].[buLatinFormatedNumber],
		[bu].[buTextFld1],
		[bu].[buTextFld2],
		[bu].[buTextFld3],
		[bu].[buTextFld4],
		[bu].[buCheckTypeGuid],
		[bu].[btDirection],
		[bu].[btType], 
		[bu].[buTotalTaxValue],
		[bu].[buCustomerAddressGUID],
		[bi].[biGUID],
		[bi].[biParent],
		[bi].[biNumber],
		[bi].[biStorePtr],
		[bi].[biNotes],
		[bi].[biUnity],
		[bi].[biMatPtr],
		[bi].[biPrice],
		[bi].[biCurrencyPtr],
		[bi].[biCurrencyVal],
		[bi].[biDiscount],
		[bi].[biBonusDisc],
		[bi].[biExtra],
		[bi].[biVAT],
		[bi].[biVATr],
		[bi].[biQty],
		[bi].[biQty2],
		[bi].[biQty3],
		[bi].[biBonusQnt],
		[bi].[biProfits],
		[bi].[biExpireDate],
		[bi].[biProductionDate],
		-- CASE bu.btFldCostPtr WHEN NULL THEN bi.biCostPtr ELSE (CASE bu.btCostToItems WHEN 1 THEN bi.biCostPtr ELSE (CASE bi.biCostPtr WHEN NULL THEN bu.buCostPtr ELSE bi.biCostPtr END) END) END AS biCostPtr,
		(CASE ISNULL([bi].[biCostPtr], 0x0) WHEN 0x0 THEN [bu].[buCostPtr] ELSE [bi].[biCostPtr] END) AS  [biCostPtr],
		[biCostPtr] AS [biCostGuid],
		[bi].[biClassPtr],
		[bi].[biLength],
		[bi].[biWidth],
		[bi].[biHeight],
		[bi].[biCount],
		[bi].[biSoGuid],
		[bi].[biSoType],
		[bi].[biLCDisc],
		[bi].[biLCExtra],
		[bi].[biTotalTaxValue],
		ISNULL(
		CASE (buTotal - buItemsDisc) 
			WHEN 0 THEN 0 
			ELSE 
				(([biPrice] * [biQty] / (CASE [biUnity] WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
					WHEN 3 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END ELSE 1 END)) - biDiscount) * Discount  / (buTotal - buItemsDisc) END, 0) AS TotalDiscountPercent,
	    ISNULL(
		CASE (buTotal + buItemsExtra)
			WHEN 0 THEN 0
			ELSE 
				(([biPrice] * [biQty] / ( CASE [biUnity] WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
					WHEN 3 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END ELSE 1 END)) + biExtra ) * Extra  / (buTotal + buItemsExtra) END, 0) AS TotalExtraPercent,
		ISNULL(Discount ,0) AS DIDiscount,
		ISNULL(Extra ,0) AS DIExtra,
		[bi].biUnitCostPrice 
	FROM
		[vwBu] AS [bu] INNER JOIN [vwBi] AS [bi]
		ON [bu].[buGUID] = [bi].[biParent]
		INNER JOIN mt000 ON mt000.GUID=bimatptr
		OUTER APPLY dbo.fnBill_GetDiSum(bu.buGUID) AS DI
#########################################################
CREATE VIEW vwBuBi_Address
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
		vwBuBi AS bubi 
		LEFT JOIN vwCustAddress ad ON bubi.buCustomerAddressGUID = ad.GUID 
#########################################################
CREATE VIEW vwMaterialEquivelants
AS
	SELECT   
		equivalents.matguid AS MatGUID,
		equivalents.equivalentguid AS EquivalentGUID,
		equivalents.Note AS Note, 
		bi.biExpireDate, 
		SUM(bi.biQty * (CASE bi.btIsOutput WHEN 1 THEN -1 ELSE 1 END)) AS Qty
	FROM 
		DrugEquivalents000 equivalents
		INNER JOIN vwBuBi bi ON equivalents.equivalentguid = bi.biMatPtr 
  GROUP BY 
		equivalents.MatGUID,   
		equivalents.EquivalentGUID, 
		equivalents.Note,  
		bi.biExpireDate 
#########################################################
#END