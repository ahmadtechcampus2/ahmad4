#########################################################
CREATE VIEW vtBu
AS
	SELECT * FROM [bu000]

#########################################################
CREATE VIEW vbBu
AS
	SELECT [bu].*
	FROM [vtBu] AS [bu] INNER JOIN [vwBr] AS [br] ON [bu].[Branch] = [br].[brGUID]

#########################################################
CREATE VIEW vcBu
AS
	SELECT * FROM [vbBu]

#########################################################
CREATE VIEW vdBu
AS
	SELECT DISTINCT * FROM [vbBu]

#########################################################
CREATE VIEW vwBu
AS   
	SELECT   
		[bu].[GUID] AS [buGUID],  
		[bu].[TypeGUID] AS [buType],  
		[bu].[Number] AS [buNumber],  
		[bu].[CustGUID] AS [buCustPtr],  
		[bu].[Cust_Name] AS [buCust_Name],  
		[bu].[Date] AS [buDate],  
		[bu].[CurrencyGUID] AS [buCurrencyPtr],  
		[bu].[CurrencyVal] AS [buCurrencyVal],  
		[bu].[Notes] AS [buNotes],  
		[bu].[Total] AS [buTotal],  
		[bu].[StoreGUID] AS [buStorePtr],  
		[bu].[CustAccGUID] AS [buCustAcc],  
		[bu].[MatAccGUID] AS [buMatAcc],  
		[bu].[PayType] AS [buPayType],  
		[bu].[TotalDisc] AS [buTotalDisc],  
		[bu].[TotalExtra] AS [buTotalExtra],  
		[bu].[ItemsDisc] AS [buItemsDisc],  
		[bu].[ItemsDiscAccGUID] AS [buItemsDiscAcc],  
		[bu].[BonusDisc] AS [buBonusDisc],  
		[bu].[BonusDiscAccGUID] AS [buBonusDiscAcc],  
		[bu].[ItemsExtra] AS [buItemsExtra],  
		[bu].[ItemsExtraAccGUID] AS [buItemsExtraAcc],  
		[bu].[FirstPay] AS [buFirstPay],  
		[bu].[FPayAccGUID] AS [buFPayAcc],  
		[bu].[Profits] AS [buProfits],  
		[bu].[VAT] AS [buVAT],  
		[bu].[TotalSalesTax] AS [buTotalSalesTax],
		([bu].[VAT] + ISNULL([bu].TotalExciseTax, 0) + ISNULL(TotalReversChargeTax, 0)) AS [buTotalTaxValue],
		[bu].[IsPosted] AS [buIsPosted],  
		[bu].[Security] AS [buSecurity],  
		[bu].[Vendor] AS [buVendor],  
		[bu].[SalesManPtr] AS [buSalesManPtr],  
		[bu].[CostGUID] AS [buCostPtr],  
		[bu].[Branch] AS [buBranch],  
		[bu].[CheckTypeGUID] AS [buCheckTypeGUID],  
		[bu].[IsPosted] * [bt].[btDirection] AS [buDirection], -- 0(not posted), -1(posted output) and 1(posted input)  
		CASE WHEN [bu].[PayType] > 1 AND [bt].[btAutoEntry] <> 0 THEN 0  
			WHEN [bu].[PayType] > 1 AND [bt].[btAutoEntry] = 0 THEN 1  
			ELSE [bu].[PayType] END AS [buIsCash],  
		[bt].[btSortFlag] AS [buSortFlag],
		[bu].[userGUID] AS [buUserGUID],
		[bu].[TextFld1] AS [buTextFld1],
		[bu].[TextFld2] AS [buTextFld2],
		[bu].[TextFld3] AS [buTextFld3],
		[bu].[TextFld4] AS [buTextFld4], 
		[bu].[ItemsExtraAccGUID]	AS [buItemsExtraAccGUID],
		[bu].[CostAccGUID]			AS [buCostAccGUID],
		[bu].[StockAccGUID]		AS [buStockAccGUID],
		[bu].[BonusAccGUID]		AS [buBonusAccGUID],
		[bu].[BonusContraAccGUID]	AS [buBonusContraAccGUID],
		[bu].[VATAccGUID] AS  [buVATAccGUID], 
		[bu].[LCGUID] AS [buLCGUID],
		[bu].[LCType] AS [buLCType],
		ISNULL([bu].[GCCLocationGUID], 0x0) AS buGCCLocationGUID,
		ISNULL([bu].[CustomerAddressGUID], 0x0) AS buCustomerAddressGUID,
		[bt].[btName],  
		[bt].[btLatinName], 
		[bt].[btAbbrev],  
		[bt].[btLatinAbbrev],  
		[bt].[btType],  
		[bt].[btBillType],  
		[bt].[btSortNum], 
		[bt].[btDefBillAcc],  
		[bt].[btIsInput],  
		[bt].[btIsOutput],  
		[bt].[btAffectLastPrice],  
		[bt].[btAffectCostPrice],  
		[bt].[btAffectProfit],  
		[bt].[btAffectCustPrice],  
		[bt].[btDiscAffectCost],  
		[bt].[btExtraAffectCost],  
		[bt].[btDiscAffectProfit],  
		[bt].[btExtraAffectProfit],  
		[bt].[btExtraToCash],  
		[bt].[btAutoEntry],  
		[bt].[btFldCostPtr],  
		[bt].[btFldBonus],  
		[bt].[btCostToItems], 
		[bt].[btAbbrev] + ': ' + CAST([bu].[Number] AS NVARCHAR) AS [buFormatedNumber], 
		[bt].[btLatinAbbrev] + ': ' + CAST([bu].[Number] AS NVARCHAR) AS [buLatinFormatedNumber], 
		[bt].[btVATSystem],
		[bt].[btDirection],
		[bt].[isApplyTaxOnGifts],
		[bt].[btIncludeTTCDiffOnSales],
		ItemsExtra buItemExtra,
		bt.btTaxBeforeDiscount,
		bt.btTaxBeforeExtra,
		bu.ReturendBillDate,
		bu.ReturendBillNumber,
		bt.btNoEntry,
		bt.btUseExciseTax,
		bt.btUseReverseCharges,
		bu.ImportViaCustoms,
		bu.CustomerAddressGuid
	FROM  
		[vbBu] AS [bu] INNER JOIN [vwBT] AS [bt]  
		ON [bu].[TypeGUID] = [bt].[btGUID] 
#########################################################
CREATE FUNCTION fbBu
	( @TypeGUID AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
	AS
		RETURN (SELECT * FROM [vcBu] AS [bu] WHERE [bu].[TypeGUID] = @TypeGUID)

#########################################################
CREATE VIEW vwBuBills
AS
	SELECT bu.* FROM vwBu bu
	WHERE bu.btType NOT IN(5, 6)
#########################################################
#END