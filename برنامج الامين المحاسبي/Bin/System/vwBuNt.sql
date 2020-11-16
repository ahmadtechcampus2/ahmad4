#########################################################
CREATE VIEW vwBuNt
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
		CASE WHEN [bu].[buPayType] > 1 AND [bu].[btAutoEntry] <> 0 THEN 0
			 WHEN [bu].[buPayType] > 1 AND [bu].[btAutoEntry] = 0 THEN 1
			 ELSE [bu].[buPayType] END AS [buIsCash],
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
		[bu].[buVAT],
		[bu].[buIsPosted],
		[bu].[buSecurity],
		[bu].[buVendor],
		[bu].[buSalesManPtr],
		[bu].[buCostPtr],
		[bu].[buBranch],
		[bu].[buDirection],
		[bu].[btName],
		[bu].[btBillType],
		(CASE -- SortFlag
			WHEN (([bu].[btType] = 2) AND ([bu].[btIsInput]  = 1) AND ([bu].[btAffectCostPrice] = 1)) THEN 0
			WHEN (([bu].[btType] = 1) AND ([bu].[btIsInput]  = 1) AND ([bu].[btAffectCostPrice] = 1)) THEN 10
			WHEN (([bu].[btType] = 2) AND ([bu].[btIsInput]  = 1) AND ([bu].[btAffectCostPrice] = 0)) THEN 20
			WHEN (([bu].[btType] = 1) AND ([bu].[btIsInput]  = 1) AND ([bu].[btAffectCostPrice] = 0)) THEN 30
			WHEN (([bu].[btType] = 2) AND ([bu].[btIsOutput] = 1) AND ([bu].[btAffectCostPrice] = 1)) THEN 40
			WHEN (([bu].[btType] = 1) AND ([bu].[btIsOutput] = 1) AND ([bu].[btAffectCostPrice] = 1)) THEN 50
			WHEN (([bu].[btType] = 2) AND ([bu].[btIsOutput] = 1) AND ([bu].[btAffectCostPrice] = 0)) THEN 60
			WHEN (([bu].[btType] = 1) AND ([bu].[btIsOutput] = 1) AND ([bu].[btAffectCostPrice] = 0)) THEN 70
		END) AS [buSortFlag],
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
		[bu].[btFldCostPtr],
		[bu].[btFldBonus],
		[bu].[btCostToItems],
		[bu].[buFormatedNumber],
		[bu].[buLatinFormatedNumber]
	FROM
		[vwbu] AS [bu] LEFT JOIN [vwNt] AS [nt]
		ON [bu].[buCheckTypeGUID] = [nt].[ntGUID]

/*  
SortFlag: 
	1:	standard		in		cost 
	2:	non-standard	in		cost 
	3:	standard		in		no-cost 
	4:	non-standard	in		no-cost	 
	5:	standard		out		cost 
	6:	non-standard	out		cost 
	7:	standard		out		no-cost 
	8:	non-standard	out		no-cost 
*/

#########################################################
#END