#########################################################
CREATE VIEW vwChCe
AS 
	SELECT [ch].*, [ce].*  
	FROM [vwch] AS [ch]  
		INNER JOIN [vwEr] AS [er] ON [ch].[chGUID] = [er].[erParentGUID]  
		INNER JOIN [vwCe] [ce] ON [er].[erEntryGUID] = [ce].[ceGUID] 
  
#########################################################
#END