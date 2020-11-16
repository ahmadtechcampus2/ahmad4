############################################################################
CREATE FUNCTION fnGetCustsOfAcc(@AccGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
/*
This function:
	- returns a list of customers related to a given account (@AccGUID) and its descnedants
*/
	RETURN (
		SELECT [cuGUID] AS [Guid] FROM [vwCu] AS [c] INNER JOIN [fnGetAcDescList](@AccGUID) AS [f]
		ON [c].[cuAccount] = [f].[GUID])

/*
select * from fnGetCustsOfAcc( '1A494C78-800A-452D-80BE-3849FDC93148')
*/
############################################################################
#END