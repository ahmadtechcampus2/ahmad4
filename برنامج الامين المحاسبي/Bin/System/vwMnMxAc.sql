#########################################################
CREATE VIEW vwMnMxAc
AS
	SELECT
		[mn].[mnType],
		[mn].[mnNumber],
		[mn].[mnGUID],
		[mn].[mnFormGUID],
		[mn].[mnQty],
		[mn].[mnDate],
		[mn].[mnInDate],
		[mn].[mnoutDate],
		[mn].[mnInStore],
		[mn].[mnOutStore],
		[mn].[mnInAccount],
		[mn].[mnOutAccount],
		[mn].[mnSecurity],
		[mn].[mnInCost],
		[mn].[mnOutCost],
		[mn].[mnPriceType],
		[mn].[mnUnitPrice],
		[mn].[mnTotalPrice],
		[mn].[mnInTempAcc],
		[mn].[mnOutTempAcc],

		[mx].[mxType],
		[mx].[mxGUID],
		[mx].[mxNumber],
		[mx].[mxExtra],
		[mx].[mxCurrencyVal],
		[mx].[mxNotes],
		[mx].[mxAccountGUID],
		[mx].[mxCostGUID],
		[mx].[mxCurrencyGUID],

		[ac].[acName],
		[ac].[acCode],
		[ac].[acSecurity]

	FROM
		[vwMn] AS [mn] INNER JOIN [vwMx] AS [mx]
		ON /*mn.mntype = 1 AND */[mn].[mnGUID] = [mx].[mxParentGUID]
		INNER JOIN [vwac] AS [ac]
		ON [mx].[mxAccountGUID] = [ac].[acGUID]

#########################################################
#END