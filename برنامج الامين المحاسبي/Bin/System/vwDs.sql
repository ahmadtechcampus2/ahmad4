#########################################################
CREATE VIEW vwDS
AS 
	SELECT 
		[GUID] AS [dsGUID],
		[Number] AS [dsNumber], 
		[Type] AS [dsType],
		[Name] AS [dsName], 
		[LatinName] AS [dsLatinName], 
		[Width] AS [dsWidth], 
		[Height] AS [dsHeight],
		[BackgroundColor] AS [dsBackgroundColor]
	FROM 
		[ds000]

#########################################################
#END