################################################################
CREATE VIEW vwORI
AS
	SELECT 
		[Number] AS [oriNumber],
		[GUID] AS [oriGUID],
		[POIGuid] AS [oriPOIGuid],
		[Qty] AS [oriQty],
		[Type] AS [oriType],
		[Date] AS [oriDate],
		[Notes] AS [oriNotes],
		[POGUID] AS [oriPOGUID],
		[TypeGUID] AS [oriTypeGUID],
		[BuGUID] AS [oriBuGUID],
		[BonusPostedQty] AS [oriBonusPostedQty],
		[bIsRecycled] AS [oribIsRecycled],
		[PostGuid] AS [oriPostGuid],
		[PostNumber] AS [oriPostNumber],
		[BiGuid] AS [oriBiGUID]
	FROM
		[ori000]
################################################################
CREATE VIEW vwOrOri
AS
	SELECT
		[ORI].*,
		[BuBi].*,
		[mt].*
	FROM 
		[vwORI] AS [ORI]
		INNER JOIN [vwBuBi] AS [BuBi] ON [ORI].[oriPOIGuid] = [BuBi].[biGuid]
		INNER JOIN [vwMt] AS [mt] ON [BuBi].[biMatPtr] = [mt].[mtGuid]
################################################################
#END