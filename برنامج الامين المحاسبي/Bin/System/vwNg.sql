#########################################################
CREATE VIEW vwNg
AS 	
	SELECT
		[GUID] AS [ngGUID],
		[Number] AS [ngNumber],
		[MatGUID] AS [ngMatGUID],
		[PrepareTime] AS [ngPrepareTime],
		[StoreGUID] AS [ngStoreGUID],
		[Price] AS [ngPrice],
		[Qty] AS [ngQty],
		[Notes] AS [ngNotes]
	FROM
		[ng000]

#########################################################
#END