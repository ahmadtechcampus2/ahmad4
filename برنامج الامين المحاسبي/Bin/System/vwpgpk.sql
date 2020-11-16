#########################################################
CREATE VIEW vwPgPk
AS
	SELECT 
		[pgType],
		[pgNumber],
		[pgGUID],
		[pgGrpGUID],
		[pgGrpName],
		[pgPictureGUID],
		[pgComputerName],
		[pkNumber],
		[pkType],
		[pkGUID],
		[pkParentGUID],
		[pkKeyCmd],
		[pkMatGUID],
		[pkAccGUID],
		[pkContraAccGUID],
		[pkDefPrice],
		[pkPayType],		
		[pkKeyName],
		[pkPictureGUID],
		[pkBColor],
		[pkFColor],
		[pkLinkOrder]
	FROM 
		[vwpg] INNER JOIN [vwpk] ON [pgGUID] = [pkParentGUID]		

#########################################################
#END		