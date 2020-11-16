################################################################################
CREATE VIEW vcBuOrderSell
AS
	SELECT [bu].*, [cu].[cuCustomerName]
	FROM 
		[vwBu] AS [bu] 
		INNER JOIN [vwBt] AS [bt] ON [bt].[btType] = 5 AND [bt].[btGUID] = [bu].[buType]
		INNER JOIN [vwCu] AS [cu] ON [cu].[cuGUID] = [bu].[buCustPtr]
#########################################
#END
