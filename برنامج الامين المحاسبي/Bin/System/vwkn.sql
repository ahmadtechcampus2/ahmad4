#####################################################################
CREATE VIEW vwkn
AS
SELECT 
	[Number] AS [knNumber],
	[GUID]	AS [knGUID],
	[Code]	AS [knCode], 
	[Name]	AS [knName], 
	[LatinName]	AS [knLatinName], 
	[ChefName]	AS [knChefName], 
	[KitchenSpec]	AS [knKitchenSpec], 
	[Notes]	AS [knNotes], 
	[Security] AS [knSecurity], 
	[PrinterId] AS [knPrinterId], 
	[LineCount] AS [knLineCount]
FROM 
	[kn000]
	
#########################################################
#END