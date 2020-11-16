#########################################################
CREATE VIEW vwMatEquivalents 
AS
	SELECT  
			equivalents.[MatGUID]			AS MatGUID,
			equivalents.[EquivalentGUID]	AS EquivalentGUID,
			equivalents.[Note]				AS Note,
			mt.[Name]						AS Name,
			mt.[LatinName]					AS LatinName,
			mt.[code]						AS Code 
	FROM DrugEquivalents000	AS equivalents  
	INNER JOIN mt000 AS mt ON equivalents.EquivalentGuid = mt.Guid  
	Group by
		equivalents.[MatGUID],  
		equivalents.[EquivalentGUID],
		equivalents.[Note], 
		mt.[Name],
		mt.[LatinName],
		mt.[code]
GO
#########################################################
#END