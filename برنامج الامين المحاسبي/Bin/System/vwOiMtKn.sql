############################################################
CREATE VIEW vwOiMtKn
AS
-- ÌÃ» «·≈‰ »«Â ≈·Ï ⁄œ„  €ÌÌ—  — Ì» ÕﬁÊ· ÃœÊ· „Ê«œ «·ÿ·»Ì… 
	SELECT
		[oi].[GUID] AS [GUID],
		[oi].[Number] AS [Number],
		[oi].[MatType] AS [MatType],
		[oi].[Qty] AS [Qty],
		[oi].[Price] AS [Price],
		[oi].[Unity] AS [Unity],
		[oi].[DiscAmount] AS [DiscAmount],
		[oi].[DiscRatio] AS [DiscRatio],
		[oi].[ExtraAmount] AS [ExtraAmount],
		[oi].[ExtraRatio] AS [ExtraRatio],
		[oi].[Kitchen] AS [Kitchen],
		[oi].[Vendor] AS [Vendor],
		[oi].[ItemState] AS [ItemState],
		[oi].[Parent] AS [Parent],
		[oi].[ExpireDate] AS [ExpireDate],
		[oi].[ProductionDate] AS [ProductionDate],
		[oi].[Length] AS [Length],
		[oi].[Width] AS [Width],
		[oi].[Height] AS [Height],
		[oi].[MatGUID] AS [MatGUID],
		[oi].[StoreGUID] AS [StoreGUID],
		[oi].[ParentItemGUID] AS [ParentItemGUID],
		[oi].[ItemBillType]	AS [ItemBillType],
		[oi].[Notes] AS [Notes],
		[oi].[SoType] AS [SoType],
		[oi].[SoGuid] AS [SoGuid],
		[oi].[MatPrice] AS [MatPrice],
		[mt].[mtGroup],
		[mt].[mtName],
		ISNULL([knPrinterId], -1) AS [knPrinterId],	
		[oi].[IsPrinted]
	FROM
		[oi000] AS [oi] INNER JOIN [vwMt] AS [mt] ON [oi].[MatGUID] = [mt].[mtGUID]
		LEFT JOIN [vwkn] on [knGUID] = [oi].[Kitchen]

/* 
select * from vwOiMtKn
Select * from oi000

*/

############################################################
#END