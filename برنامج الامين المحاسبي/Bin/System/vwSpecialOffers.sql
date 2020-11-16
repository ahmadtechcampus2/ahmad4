#########################################################
CREATE FUNCTION fnIsSpcialOfferUsed( @SOGUID UNIQUEIDENTIFIER) 
      RETURNS BIT  
AS  
BEGIN  
      --
      IF EXISTS( SELECT TOP 1 [bi].[GUID]
                     FROM bi000 bi
                     INNER JOIN 
                              SOItems000 soi ON soi.GUID = bi.SOGUID    
                     INNER JOIN 
                              SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
                     WHERE so.GUID = @SOGUID)
            RETURN 1
      ELSE IF EXISTS(SELECT TOP 1 [bi].[GUID]
                           FROM bi000 bi
                         INNER JOIN 
                                    SOOfferedItems000 soi ON soi.GUID = bi.SOGUID   
                           INNER JOIN 
                                    SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID
                           WHERE so.GUID = @SOGUID)
            RETURN 1 
      ELSE IF EXISTS(SELECT TOP 1 cbItem.GUID
                           FROM ContractBillItems000 cbItem
                           INNER JOIN
                                    SOItems000 soi ON soi.GUID = cbItem.ContractItemGUID
                           INNER JOIN 
                                    SpecialOffers000 so ON so.GUID = soi.SpecialOfferGUID 
                              WHERE so.GUID = @SOGUID)
            RETURN 1
      RETURN 0 
END
#########################################################
CREATE VIEW vtSpecialOffers
AS
	SELECT * FROM SpecialOffers000
#########################################################
CREATE VIEW vbSpecialOffers
AS
	SELECT * FROM vtSpecialOffers
#########################################################
CREATE VIEW vwSpecialOffers
AS
	SELECT * FROM vbSpecialOffers
#########################################################
CREATE VIEW vwSO_Items
AS 
	SELECT  
		[SO].[GUID] AS [soGUID],  
		[SO].[Number] AS [soNumber],  
		[SO].[Code] AS [soCode],
		[SO].[Name] AS [soName],  
		[SO].[LatinName] AS [soLatinName],  
		[SO].[Type] AS [soType],  
		[SO].[StartDate] AS [soStartDate],  
		[SO].[EndDate] AS [soEndDate], 
		[SO].[AccountGUID] AS [soCustAccGUID],  
		[SO].[CostGUID] AS [soCostGUID], 
		[SO].[IsAllBillTypes] AS [soAllBillTypes],  
		[SO].[CustCondGUID] AS [soCustCondGUID], 
		[SO].[IsActive] AS [soActive], 
		[SO].[Class] AS [soClassStr], 
		[SO].[Group] AS [soGroupStr], 
		[SO].[ItemsCondition] AS [soItemsCondition],
		[SO].[OfferedItemsCondition] AS [soOfferedItemsCondition],
		[SO].[Quantity] AS [soQty],  
		[SO].[Unit] AS [soUnity],
		[SO].[ItemsAccount] AS [soItemsAccount],
		[SO].[ItemsDiscountAccount] AS [soItemsDiscountAccount],
		[SO].[OfferedItemsAccount] AS [soOfferedItemsAccount],
		[SO].[OfferedItemsDiscountAccount] AS [soOfferedItemsDiscountAccount],
		[SO].[branchMask] AS [soBranchMask],
		[SO].[IsApplicableToCombine] AS [soIsApplicableToCombine],
		[SO].[CanOfferedSelected] AS [soCanOfferedSelected],
		[SOItems].[GUID] AS [SOIGUID],
		[SOItems].[ItemType] AS [SOItemType],  
		[SOItems].[ItemGUID] AS [SOItemGUID],  
		[SOItems].[IsSpecified] AS [SOIsSpecified],
		[SOItems].[IsIncludeGroups] AS [SOIsIncludeGroups], 
		[SOItems].[Number] AS [SOItemNumber],
		[SOItems].[Quantity] AS [SOItemQty],
		[SOItems].[Unit] AS [SOItemUnit],
		[SOItems].[PriceKind] AS [SOItemPriceKind],
		[SOItems].[PriceType] AS [SOItemPriceType],  
		[SOItems].[Price] AS [SOItemPrice],
		[SOItems].[DiscountType] AS [SOItemDiscType],
		[SOItems].[Discount] AS [SOItemDiscount],  
		[SOItems].[BonusQuantity] AS [SOItemBonusQty],
		[SOItems].[DiscountRatio] AS [SOItemDiscountRatio],
		[dbo].[fnIsSpcialOfferUsed]( [SO].[GUID]) AS [IsUsed] 
	FROM   
		[vbSpecialOffers] SO
	INNER JOIN SOItems000 SOItems ON SOItems.SpecialOfferGUID = SO.GUID
	
#########################################################
CREATE VIEW vwSO_Items_OfferedItems
AS 
	SELECT 
		[so].*, 
		ISNULL([SOOffered].[GUID], 0X0) AS [SOOfferedGUID], 
		ISNULL([SOOffered].[Number],0)  AS [SOOfferedNumber], 
		ISNULL([SOOffered].[ItemGuid], 0X0) AS [SOOfferedItemGUID], 
		ISNULL([SOOffered].[ItemType], 0) AS [SOOfferedItemType], 
		ISNULL([SOOffered].[Quantity], 0) AS [SOOfferedQty], 
		ISNULL([SOOffered].[Unit], 1) AS [SOOfferedUnity], 
		ISNULL([SOOffered].[Price], 0) AS [SOOfferedPrice], 
		ISNULL([SOOffered].[PriceKind], 0) AS [SOOfferedPriceKind], 
		ISNULL([SOOffered].[CurrencyGuid], 0X0) AS [SOOfferedCurrencyPtr], 
		ISNULL([SOOffered].[CurrencyValue], 1) AS [SOOfferedCurrencyVal], 
		ISNULL([SOOffered].[PriceType], 0) AS [SOOfferedPriceType], 
		ISNULL([SOOffered].[IsBonus], 0) AS [SOOfferedIsBonus],
		ISNULL([SOOffered].[DiscountType], 0) AS [SOOfferedDiscountType],
		ISNULL([SOOffered].[Discount], 0) AS [SOOfferedDiscount]		
	FROM 
		[vwSO_Items] [so]  
		LEFT JOIN [SOOfferedItems000] as [SOOffered] ON [so].[soGUID] = [SOOffered].[SpecialOfferGuid] 
#########################################################
CREATE VIEW vwSOAccounts
AS
	SELECT 
		so.Guid		AS SOGuid,
		items.Guid	AS SODetailGuid,
		so.ItemsAccount AS SOMatAccAccount, 
		so.ItemsDiscountAccount AS SODiscAccAccount
	FROM 
		SpecialOffers000 AS so
		INNER JOIN SOItems000	AS items	ON items.SpecialOfferGuid = so.Guid
	UNION
	SELECT 
		so.Guid		AS SOGuid,
		Offered.Guid	AS SODetailGuid,
		so.OfferedItemsAccount AS SOMatAccAccount, 
		so.OfferedItemsDiscountAccount AS SODiscAccAccount
	FROM 
		SpecialOffers000 AS so
		INNER JOIN SOOfferedItems000	AS offered	ON offered.SpecialOfferGuid = so.Guid
	UNION
	SELECT
		so.Guid AS SOGuid,
		sop.Guid AS SODetailGuid,
		so.ItemsAccount AS SOMatAccAccount, 
		so.ItemsDiscountAccount AS SODiscAccAccount
	FROM 
		SpecialOffers000 AS so
		INNER JOIN SOPeriodBudgetItem000 AS sop	ON sop.SpecialOfferGuid = so.Guid
		
-- SELECT * From vwSOAccounts
#########################################################
#END    



	
