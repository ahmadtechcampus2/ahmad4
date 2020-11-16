################################################################################
CREATE VIEW vwPOSOrderItemsTemp
AS 
	SELECT  
		[Items].[Number], 
		[Items].[Guid], 
		[MatID], 
		[Items].[Type], 
		[Mat].[Name] AS [MatName], 
		[Mat].[LatinName] AS [MatLatinName], 
		[Mat].[Code] AS [MatCode], 
		[Mat].[Barcode]  as  [Barcode1], 
		[Mat].[Barcode2] as  [Barcode2], 
		[Mat].[Barcode3] as  [Barcode3], 
		[Items].[Qty],   
		[Items].[Qty] * 
			CASE [Items].[Unity] 	
				WHEN 1 THEN 1.0 
				WHEN 2 THEN [Unit2Fact] 
				WHEN 3 THEN [Unit3Fact] 
			END AS QtyByDefUnit, 
		[Items].[MatPrice], 
		[Items].[Price], 
		[Mat].[Whole] AS [WholePrice],
		[Mat].[Half] AS [HalfPrice],
		[Mat].[Retail] AS [RetailPrice],
		[Mat].[EndUser] AS [EndUserPrice],
		[Mat].[Export] AS [ExportPrice],
		[Mat].[Vendor] AS [VendorPrice],
		[Mat].[MaxPrice] AS [MaxPrice],
		[Mat].[AvgPrice] AS [AvgPrice],
		[Mat].[LastPrice] AS [LastPrice],
		[Mat].[Dim] AS [Dimension],
		[Mat].[Origin] AS [Origin],
		[Mat].[Pos] AS [Position],
		[Mat].[Company] AS [Company],
        [Mat].[Color] AS [Color], 
        [Mat].[Provenance] AS [Provenance], 
        [Mat].[Quality] AS [Quality],
        [Mat].[Model] AS [Model],
        [Mat].[Spec] AS [Specification],
        [Items].[PriceType], 
		[Items].[Unity], 
		CASE [Items].[Unity] 	
				WHEN 1 THEN [Mat].[Unity] 
				WHEN 2 THEN [Unit2] 
				WHEN 3 THEN [Unit3] 
			END AS [UnitName], 
		CASE [Items].[Unity] 	
				WHEN 1 THEN 1 
				WHEN 2 THEN [Unit2Fact] 
				WHEN 3 THEN [Unit3Fact] 
			END AS [UnitFactory],		 
		[Items].[State], 
		[Items].[Discount] AS [DiscountValue],
		([Items].[Discount] * 100)/ (CASE WHEN [Items].[Qty] * [Items].[Price] = 0 THEN 1 ELSE [Items].[Qty] * [Items].[Price] END)  AS [DiscountPercent], 
		[Items].[Added] AS [AddedValue],	 
		CASE WHEN [Items].[Price] = 0 THEN
			CASE WHEN [Items].[Qty] = 0 THEN
 				[Items].[Added] / 1
			ELSE
				[Items].[Added] / [Items].[Qty]
			END
		ELSE
			CASE WHEN [Items].[Qty] = 0 THEN
 				[Items].[Added] / [Items].[Price]
			ELSE
				([Items].[Added] * 100) / ([Items].[Qty] * [Items].[Price])
			END
		END AS [AddedPercent], 
		[Items].[Price] * [Items].[Qty] AS [SubTotal], 
		[Items].[Price] * [Items].[Qty] AS [Total], 
		[ParentID], 
		[ItemParentID], 
		[Salesman].[Guid]	AS  [SalesmanID], 
		[Salesman].[Code]	AS  [SalesmanCode], 
		[Salesman].[Name]	AS  [SalesmanName], 	 
		[Items].[PrinterID], 
		[Items].[ExpirationDate], 
		[Items].[ProductionDate], 
		[Group].[Guid]		AS  [GroupID], 
		[Group].[Code]		AS  [GroupCode], 
		[Group].[Name]		AS  [GroupName], 	 
		[Items].[BillType], 
		[BillType].[VatSystem] AS [VatSys], 
		--[Items].[StoreID], 
		[Items].[VATValue], 
		CASE [BillType].[VatSystem] 
			WHEN 0 THEN '' 
			WHEN 1 THEN 'VAT' 
			WHEN 2 THEN 'TTC' 
		END AS [VatName], 
		[Items].[Note], 
		[Items].[SpecialOfferID], 
		[Items].[SpecialOfferIndex], 
		[Items].[OfferedItem], 
		[Items].[IsPrinted], 
		[Items].[SerialNumber],
		[Items].[DiscountType],
		[Items].[ClassPtr],
		[Items].[SOGroup],
		[Mat].[CompositionName],
		[Items].[MatBarcode],
		([Items].[Tax] / IIF([Items].[Qty] = 0, 1, [Items].[Qty] )) + [Items].[Price] AS PriceIncludedTax
	FROM [POSOrderItemsTemp000]	[Items] 
	LEFT JOIN [Mt000] 			AS [Mat]		ON [Items].[MatID] = [Mat].[Guid] 
	LEFT JOIN [Gr000] 			AS [Group]		ON [Mat].[GroupGuid] = [Group].[Guid] 
	LEFT JOIN [Co000] 			AS [Salesman]	ON [Items].[SalesmanID] = [Salesman].[Guid] 
	LEFT JOIN [Bt000]			AS [BillType] 	ON [Items].[BillType] = [BillType].[Guid]
################################################################################
#END
