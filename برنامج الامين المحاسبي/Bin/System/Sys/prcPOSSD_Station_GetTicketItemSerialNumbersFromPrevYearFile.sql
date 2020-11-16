################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetTicketItemSerialNumbersFromPrevYearFile
(
	@StationGuid UNIQUEIDENTIFIER, 
	@ticketItemGuid UNIQUEIDENTIFIER
)
AS 
BEGIN

	DECLARE @temp Table 
	(	
		GUID			UNIQUEIDENTIFIER,		
		TicketItemGUID	UNIQUEIDENTIFIER,
		SN				[nvarchar](1000),
		Number			INT
	)

	DECLARE @returnExpireDaysValue INT = 0, @returnPrevFile UNIQUEIDENTIFIER = 0x0
	DECLARE  @returnFromPrevFile BIT = (select bRetunFromPrevYear from  POSSDStationResale000 WHERE StationGUID = @StationGuid)

	IF(@returnFromPrevFile = 1)
		SET @returnPrevFile =(select PrevYearFile from  POSSDStationResale000 WHERE StationGUID = @stationGuid)
    
	DECLARE @databaseName nvarchar(50) = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @returnPrevFile)
	DECLARE @query NVARCHAR(MAX), @subQuery NVARCHAR(MAX)

	SET @query = '	SELECT  TSn.GUID,			
							TSn.TicketItemGUID,	
							TSn.SN,	
							TSn.Number													
					FROM ' + @databaseName + '..POSSDTicketItemSerialNumbers000 TSn
					WHERE TSn.TicketItemGUID = ''' + CAST(@ticketItemGuid AS NVARCHAR(256)) + ''' '

	INSERT INTO @temp	
		 EXECUTE sp_executesql @query
		
	SELECT * FROM @temp
END
#################################################################
#END
