#########################################################
CREATE PROCEDURE  prcGetChildCost
			@CostPtr AS [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	
	SELECT
		[CoGUID] AS [Number],
		[CoCode] As [Code],
		[CoName] AS [Name],
		[CoParent] AS [Parent]
	FROM
		[vwCo]
	WHERE
		[CoParent] = @CostPtr

#########################################################
#END