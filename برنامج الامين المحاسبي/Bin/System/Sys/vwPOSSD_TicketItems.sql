################################################################################
CREATE VIEW vwPOSSDTicketItems
AS 
	SELECT  	   
		[Items].[Number] AS ItemNo, 
		[Items].[Guid] AS ItemGuid, 
		[Items].[MatGUID], 
		[Ticket].[Type] as [BuType],
		[Ticket].[OpenDate],
		[Ticket].[PaymentDate],
		[Ticket].[State] AS TicketStatus,
		[Items].[TicketGUID],
		[shift].[GUID] AS ShiftGUID,
		[shift].[OpenDate] AS ShiftOpenDate ,
		[shift].CloseDate AS ShiftCloseDate ,
		[POSStation].GUID AS POSStationGUID,
		[cu].[GUID] AS CustomerGuid,
		[cu].[Security] AS CustomerSecurity,
		[cu].[AccountGUID] AS CustomerAccountGUID,
		[Ticket].[Number] AS TicketNumber,
		CASE [Ticket].[Type] 
			WHEN 0 THEN SaleBT.btDefStore -- SALE
			WHEN 1 THEN PurchaseBT.btDefStore -- PURCHASE
			WHEN 2 THEN SaleRBT.btDefStore -- SALES RETURN
			WHEN 3 THEN PurchaseRBT.btDefStore -- PURCHASE RETURN
		ELSE
			0X00
		END  AS biStorePtr,
		1 AS buSecurity,
		'1980-01-01 00:00:00' AS biExpireDate,
		CASE [Ticket].[Type] 
			WHEN 0 THEN -1
			WHEN 1 THEN 1
			WHEN 2 THEN 1
			WHEN 3 THEN -1
		END AS [BuDirection], 

		CASE [Ticket].[Type] 
			WHEN 0 THEN SaleBT.btGUID
			WHEN 1 THEN PurchaseBT.btGUID
			WHEN 2 THEN SaleRBT.btGUID
			WHEN 3 THEN PurchaseRBT.btGUID
		END AS [BuGUID], 
		[Mat].[mtName] AS [MatName], 
		[Mat].[mtLatinName] AS [MatLatinName], 
		[Mat].[mtCode] AS [MatCode], 
		[Mat].[mtBarcode]  as  [Barcode1], 
		[Mat].[mtBarcode2] as  [Barcode2], 
		[Mat].[mtBarcode3] as  [Barcode3], 
		[Items].[Qty] AS TxQty,   
		[Items].[Qty] * 
			CASE [Items].[UnitType] 	
				WHEN 0 THEN 1.0 
				WHEN 1 THEN [mtUnit2Fact] 
				WHEN 2 THEN [mtUnit3Fact] 
			END AS BaseQty, 

		[Items].[PresentQty] AS TxPresentQty,
		[Items].[Price], 
		[Items].[DiscountValue],
        [Items].[ItemShareOfTotalDiscount],
		[Items].[IsDiscountPercentage],
		[Items].[AdditionValue],
		[Items].[ItemShareOfTotalAddition],
		[Items].[IsAdditionPercentage],
		[Items].[Price] * [Items].[Qty] AS [SubTotal], 
		[Items].[Value]  AS [Value], 
		CASE [Items].[IsAdditionPercentage] WHEN 1 THEN (([Items].[Value]) * ([Items].[AdditionValue]/100)) ELSE [Items].[AdditionValue] END AS ItemAdditionValue,
		(CASE [Items].IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) 
	  * (CASE [Items].SpecialOfferGUID WHEN 0x0 THEN (Value - (PresentQty * (Value/[Items].[Qty]))) ELSE ( ( [Items].[Value] / [Items].[Qty] ) * [Items].[SpecialOfferQty] - ([Items].[PresentQty] * (( [Items].[Value] / [Items].[Qty] ) * [Items].[SpecialOfferQty]/[Items].[SpecialOfferQty]))) END) / 100 END) 
	  + ([Items].[PresentQty] * (CASE [Items].[SpecialOfferGUID] WHEN 0x0 THEN ([Items].[Value]/[Items].[Qty]) ELSE (( [Items].[Value] / [Items].[Qty] )  * [Items].[SpecialOfferQty]/[Items].[SpecialOfferQty]) END) )  ItemDiscountValue,
		(([Items].[Value]) +

		 ((CASE [Items].[IsAdditionPercentage] WHEN 1 THEN (([Items].[Value]) * ([Items].[AdditionValue]/100)) ELSE [Items].[AdditionValue] END ) + [Items].[ItemShareOfTotalAddition]) 
		 -(((CASE [Items].IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) 
	  * (CASE [Items].SpecialOfferGUID WHEN 0x0 THEN (Value - (PresentQty * (Value/[Items].[Qty]))) ELSE ( ( [Items].[Value] / [Items].[Qty] ) * [Items].[SpecialOfferQty] - ([Items].[PresentQty] * (( [Items].[Value] / [Items].[Qty] ) * [Items].[SpecialOfferQty]/[Items].[SpecialOfferQty]))) END) / 100 END) 
	  + ([Items].[PresentQty] * (CASE [Items].[SpecialOfferGUID] WHEN 0x0 THEN ([Items].[Value]/[Items].[Qty]) ELSE (( [Items].[Value] / [Items].[Qty] )  * [Items].[SpecialOfferQty]/[Items].[SpecialOfferQty]) END) )  ) + [Items].[ItemShareOfTotalDiscount]) ) AS NetValue,

		--  - ([Items].[DiscountValue] + [Items].[ItemShareOfTotalDiscount])) AS NetValue,
		[Mat].[mtWhole] AS [WholePrice],
		[Mat].[mtHalf] AS [HalfPrice],
		[Mat].[mtRetail] AS [RetailPrice],
		[Mat].[mtEndUser] AS [EndUserPrice],
		[Mat].[mtExport] AS [ExportPrice],
		[Mat].[mtVendor] AS [VendorPrice],
		[Mat].[mtMaxPrice] AS [MaxPrice],
		[Mat].[mtAvgPrice] AS [AvgPrice],
		[Mat].[mtLastPrice] AS [LastPrice],
		[Mat].[mtDim] AS [Dimension],
		[Mat].[mtOrigin] AS [Origin],
		[Mat].[mtPos] AS [Position],
		[Mat].[mtCompany] AS [Company],
        [Mat].[mtColor] AS [Color], 
        [Mat].[mtProvenance] AS [Provenance], 
        [Mat].[mtQuality] AS [Quality],
        [Mat].[mtModel] AS [Model],
        [Mat].[mtSpec] AS [Specification],
        [Items].[PriceType], 
		[Items].[UnitType], 
		CASE [Items].[UnitType] 	
				WHEN 0 THEN [Mat].[mtUnity] 
				WHEN 1 THEN [mtUnit2] 
				WHEN 2 THEN [mtUnit3] 
			END AS [UnitName], 
		CASE [Items].[UnitType] 	
				WHEN 0 THEN 1 
				WHEN 1 THEN [mtUnit2Fact] 
				WHEN 2 THEN [mtUnit3Fact] 
			END AS [UnitFactory],		 
		[Mat].mtUnit2Fact,
		[Mat].mtUnit3Fact,		
		[Group].[grGuid]		AS  [GroupID], 
		[Group].[grCode]		AS  [GroupCode], 
		[Group].[grName]		AS  [GroupName] 	 
		
	FROM [POSSDTicket000] AS [Ticket] INNER JOIN [POSSDTicketItem000] AS [Items] ON ([Ticket].[GUID] = [Items].[TicketGUID])	
	INNER JOIN [POSSDShift000]  AS [shift]		ON [shift].[GUID] = [TICKET].ShiftGUID
	LEFT JOIN [vcCu]				AS [cu] ON [CU].[GUID] = [Ticket].CustomerGUID 
	LEFT JOIN [vwMT] 				AS [Mat]		ON [Items].[MatGUID] = [Mat].mtGUID
	LEFT JOIN [vwGr] 			AS [Group]		ON [Mat].[mtGroup] = [Group].[grGUID]
	LEFT JOIN [POSSDStation000] AS [POSStation]	ON [shift].StationGUID = POSStation.GUID
	LEFT JOIN [vwbt] AS [SaleBT] ON [POSStation].SaleBillTypeGUID = SaleBT.btGUID
	LEFT JOIN [vwbt] AS [SaleRBT] ON [POSStation].SaleReturnBillTypeGUID = SaleRBT.btGUID
	LEFT JOIN [vwbt] AS [PurchaseBT] ON [POSStation].PurchaseBillTypeGUID = PurchaseBT.btGUID
	LEFT JOIN [vwbt] AS [PurchaseRBT] ON [POSStation].PurchaseReturnBillTypeGUID = PurchaseRBT.btGUID
################################################################################
#END
