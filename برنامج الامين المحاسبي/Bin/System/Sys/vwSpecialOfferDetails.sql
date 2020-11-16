################################################################################
CREATE VIEW vwSpecialOfferDetails
AS
	SELECT 
		[SpecialOfferDetails].[Number],
		[SpecialOfferDetails].[Guid],
		[SpecialOfferDetails].[ParentID],
		[SpecialOfferDetails].[MatID],
		[SpecialOfferDetails].[Group],
		CASE WHEN [SpecialOfferDetails].[Group]=0 THEN [Mt].[Code] ELSE [Gr].[Code] END AS [MatCode],
		CASE WHEN [SpecialOfferDetails].[Group]=0 THEN [Mt].[Name] ELSE [Gr].[Name] END AS [MatName], 
		[SpecialOfferDetails].[Qty],
		[SpecialOfferDetails].[Qty] * 
			CASE [SpecialOfferDetails].[Unit] WHEN 1 THEN 1
				WHEN 2 THEN [Mt].[Unit2Fact]
				WHEN 3 THEN [Mt].[Unit3Fact]
		END AS QtyByDefUnit,
		CASE [SpecialOfferDetails].[Unit] WHEN 1 THEN [Mt].[Unity]
			WHEN 2 THEN [Mt].[Unit2]
			WHEN 3 THEN [Mt].[Unit3]
		END AS [UnitName],
		[Unit]
	FROM [SpecialOfferDetails000] [SpecialOfferDetails]
	LEFT JOIN [Mt000] [Mt]	ON  [SpecialOfferDetails].[MatID] = [Mt].[Guid] and [SpecialOfferDetails].[Group]=0
	LEFT JOIN [Gr000] [Gr]	ON  [SpecialOfferDetails].[MatID] = [Gr].[Guid] and [SpecialOfferDetails].[Group]=1
################################################################################
#END