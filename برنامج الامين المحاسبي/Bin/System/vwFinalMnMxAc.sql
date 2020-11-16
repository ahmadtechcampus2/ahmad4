#########################################################
CREATE VIEW vwFinalMnMiAc
AS
	SELECT
		[rv].[MnNumber],
		[rv].[mnFormGUID],
		[rv].[MnQty],
		[rv].[MnDate],
		[rv].[mnInDate],
		[rv].[mnOutDate],
		[rv].[MnInStore],
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
		[rv].[mxNumber],
		[rv].[mxAccountGUID],
		[rv].[acName],
		[rv].[acCode],
		[rv].[acSecurity],
		[rv].[mxCostGUID],
		[rv].[mxCurrencyGUID],
		[rv].[mxCurrencyVal],
		[rv].[mxNotes],
		--Error * mnQty -------- With MnType = 1 -- mnQty = 0 Always
		(Case [rv].[mxType] WHEN 0 THEN [mx].[mxExtra] ELSE [mx].[mxExtra] * [rv].[MnQty] END) AS [mnAccFormCost]
	FROM
		[vwMnMxAc] AS [rv] LEFT OUTER JOIN [vwMx] AS [mx]
		ON [rv].[mnGUID] = [mx].[mxParentGUID] AND [rv].[mxGUID] = [mx].[mxGUID]
	WHERE
		[rv].[mnType] = 0		-- mnType = 0	>> Template Manuf

#########################################################
#END