##############################################################
CREATE VIEW vwMatDetail
AS
	select 
		[mt].*, 
		[md].[Guid] AS [mdGUID],
		[md].[Number] AS [mdNumber],
		[md].[ParentGuid] AS [mdParentGuid],
		[md].[Qty] AS [mdQty],
		[md].[Unity] AS [mdUnity],
		[md].[bFlexible] AS [mdbFlexible],
		[md].[bRequired] AS [mdbRequired],
		[md].[bPrintInBill] AS [mdbPrintInBill],
		[md].[bPrintPriceInBill] AS [mdbPrintPriceInBill],
		[md].[bSharedFld] AS [mdbSharedFld],
		[md].[BounsFld] AS [mdbBounsFld]
	from 
		[vwMt] AS [mt] INNER JOIN [md000] AS [md]
		ON [mt].[mtGuid] = [md].[MatGuid]
##############################################################
#END