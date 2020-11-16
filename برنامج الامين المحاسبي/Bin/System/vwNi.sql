#########################################################
CREATE VIEW vwNi
AS  
	SELECT   
		[GUID] AS [niGUID],
		[Number] AS [niNumber],
		[ParentGUID] AS [niParent],
		[MatGUID] AS [niMatGUID],
		[Qty] AS [niQty],
		[Unity] AS [niUnity],
		[Notes] AS [niNotes]
	FROM
		[ni000]

#########################################################
#END