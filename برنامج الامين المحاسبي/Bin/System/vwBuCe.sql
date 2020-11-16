#########################################################
CREATE VIEW vwBuCe
AS
	SELECT [bu].*, [ce].* 
	FROM [vwBu] AS [bu]
		INNER JOIN [vwEr_EntriesBills] AS [er] ON [bu].[buGUID] = [er].[erBillGUID] 
		INNER JOIN [vwCe] [ce] ON [er].[erEntryGUID] = [ce].[ceGUID]
 
#########################################################
#END