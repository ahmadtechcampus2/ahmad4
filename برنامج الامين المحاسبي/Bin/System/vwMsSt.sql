#########################################################
CREATE VIEW vwMsSt
AS
/*
This view is used in info window on the bill to show the quantities of the
the product in different stores and the name of the stores
*/
	SELECT
		[ms].[msStorePtr],
		[ms].[msMatPtr],
		[ms].[msQty],
		[ms].[msBook],
		[st].[stName],
		[st].[stLatinName]
	FROM
		[vwMs] AS [ms] INNER JOIN [vwSt] AS [st]
		ON [ms].[msStorePtr] = [st].[stGUID]

#########################################################
#END