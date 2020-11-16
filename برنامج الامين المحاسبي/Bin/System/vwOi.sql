#########################################################
CREATE VIEW vwOi
AS
	SELECT
		[oi].[GUID] AS [oiGUID],
		[oi].[Parent] AS [oiParent],
		[oi].[Number] AS [oiNumber],
		[oi].[MatGUID] AS [oiMatGUID],
		[oi].[MatType] AS [oiMatType],
		[oi].[StoreGUID] AS [oiStoreGUID],
		[oi].[Qty] AS [oiQty],
		[oi].[Unity] AS [oiUnity],
		[oi].[Price] AS [oiPrice],		
		[oi].[ExpireDate] AS [oiExpireDate],
		[oi].[ProductionDate] AS [oiProductionDate],
		[oi].[Length] AS [oiLength],
		[oi].[Width] AS [oiWidth],
		[oi].[Height] AS [Height],
		[oi].[DiscAmount] AS [oiDiscAmount],
		[oi].[DiscRatio] AS [oiDiscRatio],
		[oi].[ExtraAmount] AS [oiExtraAmount],
		[oi].[ExtraRatio] AS [oiExtraRatio],
		[oi].[Kitchen] AS [oiKitchen],
		[oi].[Vendor] AS [oiVendor],
		[oi].[ItemState] AS [oiItemState],
		[oi].[ParentItemGUID] AS [oiParentItem],
		[oi].[ItemBillType]	AS [oiItemBillType],
		[oi].[Notes]	AS [oiNotes],
		[oi].[soType]	AS [oiSoType],
		[oi].[soGuid]	AS [oiSoGuid],
		[oi].[MatPrice]	AS [oiMatPrice],
		[mt].[mtGroup],
		[mt].[mtName],
		[mt].[MtCode]     AS [OiMatCode]		
	FROM
		[oi000] AS [oi] INNER JOIN [vwMt] AS [mt] ON [oi].[MatGUID] = [mt].[mtGUID]

#########################################################
#END