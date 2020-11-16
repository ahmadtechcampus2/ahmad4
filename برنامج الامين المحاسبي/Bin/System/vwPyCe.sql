#########################################################
CREATE VIEW vwPyCe
AS
	SELECT [py].*, [ce].* 
	FROM [vwPy] AS [py]
		INNER JOIN [vwEr_EntriesPays] AS [er] ON [py].[pyGUID] = [er].[erPayGUID] 
		INNER JOIN [vwCe] [ce] ON [er].[erEntryGUID] = [ce].[ceGUID]

#########################################################
#END