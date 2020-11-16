#########################################################
CREATE VIEW vtTrnExchangeTypes
AS
	SELECT * FROM [trnExchangeTypes000]
#########################################################
CREATE VIEW vbTrnExchangeTypes
AS
	SELECT [v].*
	FROM [vtTrnExchangeTypes] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcTrnExchangeTypes
AS
	SELECT * FROM [vbTrnExchangeTypes]

#########################################################
CREATE VIEW vdTrnExchangeTypes
AS
	SELECT * FROM [vbTrnExchangeTypes]

#########################################################
CREATE VIEW vwTrnExchangeTypes
AS  
	SELECT
		*
	FROM  
		[vbTrnExchangeTypes] 
#########################################################
#END