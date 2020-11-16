#########################################################
CREATE VIEW vwFinalMnMiMt
AS
	SELECT
		[rv].[mnNumber],
		[rv].[mnFormGUID],
		[rv].[mnQty],
		[rv].[mnDate],
		[rv].[mnInDate],
		[rv].[mnOutDate],
		[rv].[mnInStore],
		[rv].[mnOutStore],
		[rv].[mnInAccount],
		[rv].[mnOutAccount],
		[rv].[mnSecurity],
		[rv].[mnInCost],
		[rv].[mnOutCost],
		[rv].[mnPriceType],
		[rv].[mnUnitPrice],
		[rv].[mnTotalPrice],
		[rv].[mnInTempAcc],
		[rv].[mnOutTempAcc],
		[rv].[miType],
		[rv].[miGUID],
		[rv].[mtName],
		[rv].[mtCode],
		[rv].[mtLatinName],
		[rv].[miQty],
		[rv].[miUnity],
		[rv].[miPrice],
		[rv].[miStoreGUID],
		[rv].[miCurrencyGUID],
		[rv].[miCurrencyVal],
		[rv].[mtDefUnit],
		[rv].[mtUnit2Fact],
		[rv].[mtUnit3Fact],
		[rv].[mtType],
		[rv].[mtSecurity],
		(CASE [mi].[miUnity]
			WHEN 1 THEN [mi].[miQty] / ISNULL( CASE [rv].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [rv].[mtDefUnitFact] END, 1) * [rv].[MnQty]
			WHEN 2 THEN (CASE [rv].[mtDefUnit]
					WHEN 1 THEN [mi].[miQty] * [mtUnit2Fact] * [rv].[MnQty]
					WHEN 2 THEN [mi].[miQty] * [rv].[MnQty]
					ELSE ((mi.[miQty] * [mtUnit2Fact]) / ISNULL( CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END , 1)) * [rv].[MnQty] END)
			ELSE (CASE [rv].[mtDefUnit]
					WHEN 1 THEN (mi.[miQty] * [mtUnit3Fact]) * [rv].[MnQty]
					WHEN 2 THEN ((mi.[miQty] * [mtUnit3Fact]) / ISNULL( CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END, 1)) * [rv].[MnQty]
					ELSE [mi].[miQty] * [rv].[MnQty] END)
		END) AS [MnItemFormQty]
	FROM
		[vwMnMiMt] [rv] LEFT JOIN [vwMi] AS [mi]
		ON	[rv].[mnGUID] = [mi].[miParent] AND 
			[rv].[miMatGUID] = [mi].[miMatGUID] AND [rv].[mnType] = 0		--	mn.mnType = 0	>> Manuf Template

#########################################################
#END