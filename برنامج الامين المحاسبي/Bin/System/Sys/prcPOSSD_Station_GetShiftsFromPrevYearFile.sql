################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetShiftsFromPrevYearFile
(@stationGuid UNIQUEIDENTIFIER)
AS 
BEGIN
	DECLARE @temp Table 
	(
	    [Number]							[int],
		[GUID]								[uniqueidentifier],
		[StationGUID]				        [uniqueidentifier],
		[Code]								[nvarchar](100),
		[CloseShiftNote]					[nvarchar](250),
		[EmployeeGUID]						[uniqueidentifier],
		[OpenDate]				            [DATETIME],
		[CloseDate]						    [DATETIME],
		[OpenShiftNote]						[nvarchar](250),
		[OpenDateUTC]				            [DATETIME],
		[CloseDateUTC]						    [DATETIME]
	)

	DECLARE @returnExpireDaysValue INT = 0, @returnPrevFile UNIQUEIDENTIFIER = 0x0
	DECLARE  @returnFromPrevFile BIT = (select bRetunFromPrevYear from  POSSDStationResale000 WHERE StationGUID = @StationGuid)
	IF(@returnFromPrevFile = 1)
		SET @returnPrevFile =(select PrevYearFile from  POSSDStationResale000 WHERE StationGUID = @stationGuid)
    
	DECLARE @databaseName nvarchar(50) = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @returnPrevFile)
	DECLARE @query2 NVARCHAR(MAX), @query NVARCHAR(MAX)
	
	SET @query = ' SELECT  * FROM POSSDShift000 '

	SET @query2 = ' UNION SELECT  * FROM '  + @databaseName + '..POSSDShift000 '
	IF(@returnFromPrevFile = 1  AND @databaseName IS NOT NULL)
		SET @query = @query + @query2

	INSERT INTO @temp	
		 EXECUTE sp_executesql @query
		
	SELECT * FROM @temp
END
#################################################################
#END
