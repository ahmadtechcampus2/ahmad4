################################################################################
CREATE VIEW vwSpecialOffer
AS
	SELECT 
		[SpecialOffer].[Number],
		[SpecialOffer].[Guid],
		[SpecialOffer].[Name] AS [OfferName],
		[SpecialOffer].[CustomersAccountID],
		[CustomerAcc].[Code] + '-' + [CustomerAcc].[Name] AS [CustomersAccount],
		[SpecialOffer].[AccountID],
		[OfferAcc].[Code] + '-' + [OfferAcc].[Name] AS [OfferAccount],
		[SpecialOffer].[MatAccountID],
		[MatAcc].[Code] + '-' + [MatAcc].[Name] AS [MatAccount],
		[SpecialOffer].DiscountAccountID,
		[SpecialOffer].[Type],
		[SpecialOffer].[Qty],
		[SpecialOffer].[StartDate],
		[SpecialOffer].[EndDate],
		[SpecialOffer].[Discount],
		[SpecialOffer].[Security]
	FROM [SpecialOffer000] AS [SpecialOffer]
	LEFT JOIN [Ac000] AS 	[CustomerAcc] 	ON [SpecialOffer].[CustomersAccountID] = [CustomerAcc].[Guid]
	LEFT JOIN [Ac000] AS 	[OfferAcc] 		ON [SpecialOffer].[AccountID] = [OfferAcc].[Guid]
	LEFT JOIN [Ac000] AS 	[MatAcc] 		ON [SpecialOffer].[MatAccountID] = [MatAcc].[Guid]
################################################################################
CREATE VIEW vwPOSSpecialOffer
AS
	SELECT 
		*
	FROM 
		[vbSpecialOffer]
################################################################################
#END