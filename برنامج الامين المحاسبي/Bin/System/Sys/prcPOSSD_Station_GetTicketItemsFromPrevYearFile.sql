################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetTicketItemsFromPrevYearFile
(
	@StationGuid UNIQUEIDENTIFIER, 
	@ticketGuid UNIQUEIDENTIFIER
)
AS 
BEGIN
	DECLARE @temp Table 
	(	
		[GUID]							UNIQUEIDENTIFIER,
		[Number]						INT,
		[TicketGUID]					UNIQUEIDENTIFIER,
		[MatGUID]						UNIQUEIDENTIFIER,
		[Qty]							FLOAT,
		[Price]							FLOAT,
		[Value]							FLOAT,
		[Unit]							INT,
		[DiscountValue]					FLOAT,
		[ItemShareOfTotalDiscount]		FLOAT,
		[IsDiscountPercentage]			BIT,
		[AdditionValue]					FLOAT,
		[ItemShareOfTotalAddition]		FLOAT,
		[IsAdditionPercentage]			BIT,
		[PriceType]						INT,
		[IsManualPrice]					BIT,
		[UnitType]						INT,
		[PresentQty]					FLOAT,
		[Tax]							FLOAT,
		[TaxRatio]						FLOAT,
		[SpecialOfferGUID]				UNIQUEIDENTIFIER,
		[SpecialOfferQty]				FLOAT,
		[ReturnedQty]					FLOAT,
		[NumberOfSpecialOfferApplied]	INT,
		[SpecialOfferSlideGUID]			UNIQUEIDENTIFIER,
		[TaxCode]						INT
	)
	DECLARE @returnExpireDaysValue INT = 0, @returnPrevFile UNIQUEIDENTIFIER = 0x0
	DECLARE  @returnFromPrevFile BIT = (select bRetunFromPrevYear from  POSSDStationResale000 WHERE StationGUID = @StationGuid)
	IF(@returnFromPrevFile = 1)
		SET @returnPrevFile =(select PrevYearFile from  POSSDStationResale000 WHERE StationGUID = @stationGuid)
    
	DECLARE @databaseName nvarchar(50) = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @returnPrevFile)
	DECLARE @query NVARCHAR(MAX), @subQuery NVARCHAR(MAX)
		SET @query = '	SELECT  TI.[GUID],					
								TI.[Number],						
								TI.[TicketGUID],					
								TI.[MatGUID],						
								TI.[Qty],							
								TI.[Price],						
								TI.[Value],						
								TI.[Unit],					
								TI.[DiscountValue],				
								TI.[ItemShareOfTotalDiscount],	
								TI.[IsDiscountPercentage],		
								TI.[AdditionValue],				
								TI.[ItemShareOfTotalAddition],	
								TI.[IsAdditionPercentage],		
								TI.[PriceType],					
								TI.[IsManualPrice],				
								TI.[UnitType],					
								TI.[PresentQty],					
								TI.[Tax],						
								TI.[TaxRatio],					
								TI.[SpecialOfferGUID],			
								TI.[SpecialOfferQty],				
								TI.[ReturnedQty],
								TI.[NumberOfSpecialOfferApplied],
								TI.[SpecialOfferSlideGUID],
								TI.[TaxCode]																														
						FROM ' + @databaseName + '..POSSDTicketItem000 TI
						INNER JOIN ' + @databaseName + '..POSSDTicket000 PT ON PT.GUID = TI.TicketGUID
						WHERE PT.GUID = ''' + CAST(@ticketGuid AS NVARCHAR(256)) + ''' '
	INSERT INTO @temp	
		 EXECUTE sp_executesql @query
		
	SELECT * FROM @temp
END
#################################################################
#END
