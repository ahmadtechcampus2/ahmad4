################################################################################
CREATE VIEW vwOfferedItems
AS
	SELECT 
		[OfferedItems].[Number],
		[OfferedItems].[Guid],
		[OfferedItems].[ParentID],
		[OfferedItems].[MatID],
		[Mt].[Code] AS [MatCode],
		[Mt].[Name] AS [MatName],
		[OfferedItems].[Qty],
		[OfferedItems].[Unit],
		CASE [OfferedItems].[Unit] 	WHEN 1 THEN [Mt].[Unity]
									WHEN 2 THEN [Mt].[Unit2]
									WHEN 3 THEN [Mt].[Unit3]
		END AS [UnitName],
		CASE [OfferedItems].PriceKind 
			WHEN 0 THEN [OfferedItems].[Price]
			ELSE
				CASE [OfferedItems].[Unit] 
					WHEN 2 THEN 
						CASE [OfferedItems].[PriceType] 
							WHEN 2 THEN [Mt].AvgPrice
							WHEN 4 THEN [Mt].Whole2
							WHEN 8 THEN [Mt].Half2
							WHEN 16 THEN [Mt].Export2
							WHEN 32 THEN [Mt].Vendor2
							WHEN 64 THEN [Mt].Retail2
							WHEN 128 THEN [Mt].EndUser2
							WHEN 256 THEN [Mt].LastPrice2
							WHEN 512 THEN [Mt].LastPrice2
							ELSE [OfferedItems].[Price]
						END
					WHEN 3 THEN 
						CASE [OfferedItems].[PriceType] 
							WHEN 2 THEN [Mt].AvgPrice
							WHEN 4 THEN [Mt].Whole3
							WHEN 8 THEN [Mt].Half3
							WHEN 16 THEN [Mt].Export3
							WHEN 32 THEN [Mt].Vendor3
							WHEN 64 THEN [Mt].Retail3
							WHEN 128 THEN [Mt].EndUser3
							WHEN 256 THEN [Mt].LastPrice3
							WHEN 512 THEN [Mt].LastPrice3
							ELSE [OfferedItems].[Price]
						END
					ELSE
						CASE [OfferedItems].[PriceType] 
							WHEN 2 THEN [Mt].AvgPrice
							WHEN 4 THEN [Mt].Whole
							WHEN 8 THEN [Mt].Half
							WHEN 16 THEN [Mt].Export
							WHEN 32 THEN [Mt].Vendor
							WHEN 64 THEN [Mt].Retail
							WHEN 128 THEN [Mt].EndUser
							WHEN 256 THEN [Mt].LastPrice
							WHEN 512 THEN [Mt].LastPrice
							ELSE [OfferedItems].[Price]
						END
				END				
		END AS [ItemUnitPrice],
		[OfferedItems].[Qty] * CASE [OfferedItems].[Unit] 	WHEN 1 THEN 1
															WHEN 2 THEN [Mt].[Unit2Fact]
															WHEN 3 THEN [Mt].[Unit3Fact]
		END AS QtyByDefUnit,
		[OfferedItems].[Price],
		CASE [OfferedItems].[PriceType]	WHEN 1   THEN dbo.fnStrings_get('POS\PRICE_TYPE_NONE', DEFAULT)
										WHEN 2   THEN dbo.fnStrings_get('POS\PRICE_TYPE_COST', DEFAULT)
										WHEN 4   THEN dbo.fnStrings_get('POS\PRICE_TYPE_HOLE', DEFAULT)
										WHEN 8   THEN dbo.fnStrings_get('POS\PRICE_TYPE_HALF', DEFAULT)
										WHEN 16  THEN dbo.fnStrings_get('POS\PRICE_TYPE_EXPORT', DEFAULT)
										WHEN 32  THEN dbo.fnStrings_get('POS\PRICE_TYPE_DIST', DEFAULT)
										WHEN 64  THEN dbo.fnStrings_get('POS\PRICE_TYPE_PIECES', DEFAULT)
										WHEN 128 THEN dbo.fnStrings_get('POS\PRICE_TYPE_ENDUSER', DEFAULT)
										WHEN 256 THEN dbo.fnStrings_get('POS\PRICE_TYPE_LASTBUY', DEFAULT)
										WHEN 512 THEN dbo.fnStrings_get('POS\PRICE_TYPE_LASTSELL', DEFAULT)
		END AS [PriceTypeName],
		[OfferedItems].[PriceType],
		[OfferedItems].[Discount],
		[OfferedItems].[PriceKind]
	FROM [OfferedItems000] 	AS [OfferedItems]
	LEFT JOIN [Mt000]		AS [Mt] ON [OfferedItems].[MatID] = [Mt].[Guid]
################################################################################
#END
