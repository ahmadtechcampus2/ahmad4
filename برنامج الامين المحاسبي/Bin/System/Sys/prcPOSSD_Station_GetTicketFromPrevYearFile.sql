################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetTicketFromPrevYearFile
(
	@StationGuid UNIQUEIDENTIFIER, 
	@ticketGuid UNIQUEIDENTIFIER
)
AS 
BEGIN
	DECLARE @temp Table 
	(
		[GUID]								[uniqueidentifier],
		[Number]							[int],
		[Code]								[nvarchar](100),
		[ShiftGUID]							[uniqueidentifier],
		[CustomerGUID]						[uniqueidentifier],
		[Note]								[nvarchar](250),
		[DiscValue]							[float],
		[IsDiscountPercentage]				[bit],
		[AddedValue]						[float],
		[IsAdditionPercentage]				[bit],
		[Total]								[float],
		[State]								[int],
		[CollectedValue]					[float],
		[LaterValue]						[float],
		[Net]								[float],
		[OpenDate]							[datetime],
		[PaymentDate]						[datetime],
		[TaxTotal]							[float],
		[Type]								[int],
		[SalesmanGUID]						[uniqueidentifier],
		[RelatedTo]							[uniqueidentifier],
		[RelationType]						[int],
		[RelatedFrom]						[uniqueidentifier],
		[RelatedFromInfo]					[nvarchar](MAX),
		[SpecialOfferGuid]					[uniqueidentifier],
		[TaxType]							[int],
		[bIsPrinted]						[BIT],
		[IsTaxCalculationBeforeAddition]	[BIT],
		[IsTaxCalculationBeforeDiscount]	[BIT],
		[OrderType]							[INT],
		[DeviceID]							[nvarchar](250),
		[GCCLocationGUID]					[uniqueidentifier]
	)
	DECLARE @returnExpireDaysValue INT = 0, @returnPrevFile UNIQUEIDENTIFIER = 0x0
	
	DECLARE  @returnFromPrevFile BIT = (select bRetunFromPrevYear from  POSSDStationResale000 WHERE StationGUID = @StationGuid)
	IF(@returnFromPrevFile = 1)
		SET @returnPrevFile =(select PrevYearFile from  POSSDStationResale000 WHERE StationGUID = @stationGuid)
    
	DECLARE @databaseName nvarchar(50) = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @returnPrevFile)
	DECLARE @query NVARCHAR(MAX), @subQuery NVARCHAR(MAX)
		SET @query = '	SELECT  PT.[GUID],
								PT.[Number],
								PT.[Code],
								PT.[ShiftGUID],
								PT.[CustomerGUID],
								PT.[Note],
								PT.[DiscValue],
								PT.[IsDiscountPercentage],
								PT.[AddedValue],
								PT.[IsAdditionPercentage],
								PT.[Total],
								PT.[State],
								PT.[CollectedValue],
								PT.[LaterValue],
								PT.[Net],
								PT.[OpenDate],
								PT.[PaymentDate],
								PT.[TaxTotal],
								PT.[Type],
								PT.[SalesmanGUID],
								PT.[RelatedTo],
								PT.[RelationType],
								PT.[RelatedFrom],
								PT.[RelatedFromInfo],
								PT.[SpecialOfferGuid],
								PT.[TaxType],
								PT.[bIsPrinted],
								PT.[IsTaxCalculationBeforeAddition],
								PT.[IsTaxCalculationBeforeDiscount],
								PT.[OrderType],
								PT.[DeviceID], 
								PT.[GCCLocationGUID] 
						FROM '  + @databaseName + '..POSSDTicket000 PT 
						WHERE PT.GUID = ''' + CAST(@ticketGuid AS NVARCHAR(256)) + ''' '
	INSERT INTO @temp	
		 EXECUTE sp_executesql @query
		
	SELECT * FROM @temp
END
#################################################################
#END
