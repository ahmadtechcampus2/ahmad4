################################################################################
## 
CREATE PROC repSpForList
	/*@Index [INT] = 0*/
	@smGuid [UNIQUEIDENTIFIER] = 0x0
AS 
SET NOCOUNT ON

SELECT  
	[smGuid] AS [Guid], 
	[smNumber] AS [Number], 
	[smType] AS [Type], 
	[smMatPtr] AS [MatPtr1],  
	[smQty] AS [Qty1],  
	[smUnity] AS [Unity1],  
	[smStartDate] AS [StartDate],  
	[smEndDate] AS [EndDate],  
	[smNotes] AS [Notes],  
	[smbAddMain] AS [Main], 
	[smGroupGUID] AS [GroupGUID],
	[smbIncludeGroups] AS [bIncludeGroups],
	[smPriceType] AS [PriceType],
	[smDiscount] AS [Discount],
	[smCustAccGUID] AS [CustAccGUID],
	[smOfferAccGUID] AS [OfferAccGUID],
	[smIOfferAccGUID] AS [IOfferAccGUID],	
	-- [smDiscAccGUID] AS [DiscAccGUID],
	[smbAllBt] AS [bAllBt],
	[sdMatPtr] AS [MatPtr2],  
	[sdQty] AS [Qty2],  
	[sdUnity] AS [Unity2],  
	[sdPrice] AS [Price],  
	[sdPriceFlag] AS [Flag],  
	[sdCurrencyPtr] AS [CurPtr],  
	[sdCurrencyVal] AS [CurVal],  
	[sdPolicyType]  AS [Policy],
	[sdBonus] AS [bBonus]
FROM 	[vwSmSd]
WHERE
	( /*@smGuid = 0x0 OR*/ [smGuid] = @smGuid)
###################################################################################
#END
