#########################################################
CREATE PROCEDURE  prcGetChildStore
			@StorePtr AS [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	
	SELECT
		[stGUID] AS [Number],
		[stCode] As [Code],
		[stName] AS [Name],
		[stParent] AS [Parent]
	FROM
		[vwSt]
	WHERE
		[stParent] = @StorePtr

#########################################################
#END
