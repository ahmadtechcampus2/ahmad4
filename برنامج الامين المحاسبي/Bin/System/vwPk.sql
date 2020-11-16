#########################################################
CREATE VIEW vwpk
AS
	SELECT 
		[Number] AS [pkNumber],
		[Type] AS [pkType],
		[GUID] AS [pkGUID],
		[ParentGUID] AS [pkParentGUID],
		[KeyCmd] AS [pkKeyCmd],
		[MatGUID] AS [pkMatGUID],
		[AccGUID] AS [pkAccGUID],
		[KeyName] AS [pkKeyName],
		[PictureGUID] AS [pkPictureGUID],
		[BColor] AS [pkBColor],
		[FColor] AS [pkFColor],
		[LinkOrder] AS [pkLinkOrder],
		[ContraAccGUID] AS [pkContraAccGUID],
		[DefPrice] AS [pkDefPrice],
		[PayType] AS [pkPayType]			
	
	FROM [pk000]
		
#########################################################
#END		