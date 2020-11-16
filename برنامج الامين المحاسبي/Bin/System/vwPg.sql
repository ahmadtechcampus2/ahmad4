####################################################
CREATE VIEW vwPg
AS
	SELECT 
		[Type] AS [pgType],
		[Number] AS [pgNumber],
		[GUID] AS [pgGUID],
		[GrpGUID] AS [pgGrpGUID],
		[GrpName] AS [pgGrpName],
		[PictureGUID] AS [pgPictureGUID],
		[ComputerName] AS [pgComputerName]
	FROM 
		[Pg000]

####################################################
#END