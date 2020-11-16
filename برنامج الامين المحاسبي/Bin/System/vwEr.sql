#########################################################
CREATE VIEW vwER 
AS 
	SELECT 
		[GUID] AS [erGUID], 
		[EntryGUID] AS [erEntryGUID], 
		[ParentGUID] AS [erParentGUID], 
		[ParentType] AS [erParentType],
		[ParentNumber] AS [erParentNumber] 
	FROM 
		[er000]

#########################################################
#END