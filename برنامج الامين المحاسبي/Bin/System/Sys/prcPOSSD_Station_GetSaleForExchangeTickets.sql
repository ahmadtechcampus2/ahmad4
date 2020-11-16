################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSaleForExchangeTickets
	@ticketCode NVARCHAR(256),
	@customerName NVARCHAR(256),
	@startDate DATETIME2,
	@endDate DATETIME2,
	@stationGuid UNIQUEIDENTIFIER,
	@periodMonth INT,
	@periodYear INT
AS 
BEGIN

	DECLARE @CurrentYearQuery				NVARCHAR(MAX)= ''; 
	DECLARE @PrevYearQuery					NVARCHAR(MAX)= ''; 
	DECLARE @FinalQuery						NVARCHAR(MAX)= '';
	DECLARE @WhereCondition					NVARCHAR(4000) = '';
	DECLARE @PrevYearFromTable				NVARCHAR(4000) = '';
	DECLARE @CurrentWhereCondition			NVARCHAR(4000) = '';
	DECLARE @CurrentFromTable				NVARCHAR(4000) = '';
	DECLARE @databaseName					NVARCHAR(50) = NULL;

	DECLARE @returnExpireDays				INT = 0;
	DECLARE @returnPrevFile					UNIQUEIDENTIFIER = 0x0;
	DECLARE @returnExpireDaysFlag			BIT;
	DECLARE @returnFromPrevFileFlag			BIT;
	--DECLARE @returnFromOfferTicketsFlag		BIT;
	DECLARE @returnFromDiffStationsFlag		BIT;	
	
	CREATE TABLE #TicketContainsSpecialOffers ( TicketGUID UNIQUEIDENTIFIER )

	--================= Read Return sales filter condition from the POSSDStationResale000 table
	SELECT 
		@returnExpireDaysFlag		= bReturnExpireDays,
		@returnExpireDays			= ReturnExpireDays,
		@returnFromPrevFileFlag		= bRetunFromPrevYear,
		--@returnFromOfferTicketsFlag	= bAllowReturnFromOffersTicket,
		@returnFromDiffStationsFlag	= bReturnFromDiffStations
	FROM POSSDStationResale000 
	WHERE StationGUID = @stationGuid;

	--================= if return from prev year is on, then get the database name from ReportDataSources000
	IF(@returnFromPrevFileFlag = 1)
	BEGIN
		SELECT 
			@databaseName = '[' + DS.DatabaseName + ']'
		FROM ReportDataSources000 AS DS INNER JOIN POSSDStationResale000 AS RS ON (RS.PrevYearFile = DS.Guid)
		WHERE RS.StationGUID = @stationGuid;				
	END;

	--================= get ticket contains special offers
	--IF(@returnFromOfferTicketsFlag = 0)
	--BEGIN

		INSERT INTO #TicketContainsSpecialOffers 
		SELECT TicketGUID FROM POSSDTicketItem000 WHERE SpecialOfferGUID <> 0x0 AND SpecialOfferGUID IS NOT NULL  
	
		INSERT INTO #TicketContainsSpecialOffers
		SELECT [GUID] 
		FROM POSSDTicket000 T
		LEFT JOIN #TicketContainsSpecialOffers TSO on TSO.TicketGUID = T.[GUID]
		WHERE TSO.TicketGUID IS NULL
		AND (T.SpecialOfferGUID <> 0x0 AND T.SpecialOfferGUID IS NOT NULL)

		IF(@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)
		BEGIN
			DECLARE @Str NVARCHAR(MAX)
			SET @Str  = ' INSERT INTO #TicketContainsSpecialOffers '
			SET @Str += ' SELECT TicketGUID FROM '+ @databaseName +'..POSSDTicketItem000 WHERE SpecialOfferGUID <> 0x0 AND SpecialOfferGUID IS NOT NULL   '
			SET @Str += ' INSERT INTO #TicketContainsSpecialOffers '
			SET @Str += ' SELECT [GUID] '
			SET @Str += ' FROM '+ @databaseName +'..POSSDTicket000 T '
			SET @Str += ' LEFT JOIN #TicketContainsSpecialOffers TSO ON TSO.TicketGUID = T.[GUID] '
			SET @Str += ' WHERE TSO.TicketGUID IS NULL '
			SET @Str += ' AND (T.SpecialOfferGUID <> 0x0 AND T.SpecialOfferGUID IS NOT NULL) '
			EXEC sp_executesql @Str
		END

	--END

	--================= build from clause of current year
		SET @CurrentFromTable = CONCAT(@CurrentFromTable,'FROM POSSDTicket000 PT INNER JOIN  POSSDTicketItem000 AS PTI  ON (PTI.TicketGUID = PT.GUID)');		
		SET @CurrentFromTable= CONCAT(@CurrentFromTable, ' INNER JOIN POSSDShift000 AS PS ON (PS.GUID = PT.ShiftGUID) ' );
		SET @CurrentFromTable = CONCAT(@CurrentFromTable, ' LEFT JOIN cu000 AS CU ON (CU.GUID = PT.CustomerGUID) ' );
		SET @CurrentFromTable = CONCAT(@CurrentFromTable, ' LEFT JOIN (SELECT RelatedFrom   FROM POSSDTicket000 AS SRT WHERE SRT.State = 1 AND SRT.TYPE = 2) AS OS ON (PT.GUID = OS.RelatedFrom) ');

	
	--================= build from clause of previous year
	IF @databaseName IS NOT NULL AND  LEN(@databaseName) > 0
		BEGIN
			SET @PrevYearFromTable = CONCAT('FROM ', @databaseName +'..POSSDTicket000 PT INNER JOIN  ',@databaseName +'..POSSDTicketItem000 AS PTI  ON (PTI.TicketGUID = PT.GUID)');		
			SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' INNER JOIN ', @databaseName +'..POSSDShift000 AS PS ON (PS.GUID = PT.ShiftGUID) ' );
			SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' LEFT JOIN ', @databaseName +'..cu000 AS CU ON (CU.GUID = PT.CustomerGUID) ' );
			SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' LEFT JOIN (SELECT RelatedFrom   FROM POSSDTicket000 AS SRT WHERE SRT.State = 1 AND SRT.TYPE = 2) AS OS ON (PT.GUID = OS.RelatedFrom) ');
		END;

	
	--================= Buid where condition of period month and year to show as tree
	 SET @WhereCondition = CONCAT(' WHERE  MONTH(PT.PaymentDate) = ',@periodMonth,'  AND YEAR(PT.PaymentDate) = ', @periodYear);	
	
	
	--================= Buid where condition ticket type is sale and status is paied
	SET @WhereCondition = CONCAT(@WhereCondition, ' AND PT.State  = 0 AND PT.Type = 0 ');
	
	
	--================= Exclude the sales transaction in open sales return tickets
	SET @WhereCondition = CONCAT(@WhereCondition, ' AND ((PT.GUID != OS.RelatedFrom) OR (OS.RelatedFrom IS NULL)) ');

	
	--================= if ticket code is not null, add ticket code condition		
	IF @ticketCode IS NOT NULL AND LEN(@ticketCode) > 0			
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND PT.Code =  ''',@ticketCode,'''');
	
	
	--================= if customer name is not null, add ticket customer condition				
	IF @customerName IS NOT NULL AND LEN(@customerName) > 0
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CU.LatinName LIKE ''%' + @customerName + '%'' OR CU.CustomerName LIKE ''%'+ @customerName +'%''');
	
	
	--================= if start date is not null, add payment date >= start date condition		
	IF @startDate IS NOT NULL 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CONVERT(date, PaymentDate, 105) >=  ''',CONVERT(date, @startDate, 105),'''');
	
	
	--================= if end date is not null, add end date <= start date condition		
	IF @endDate IS NOT NULL 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CONVERT(date, PaymentDate, 105) <=  ''',CONVERT(date, @endDate, 105),'''');
	
	
	--================= if user can not return the sales after certain days, add the condition 
	IF @returnExpireDaysFlag IS NOT NULL AND @returnExpireDaysFlag = 1
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND DATEDIFF(day, PaymentDate, GETDATE()) <=  ', @returnExpireDays);

	
	--================= if user can not return ticket that has special offer, add the condition to include the ticket where SpecialOfferGUID is null or empty 
	--IF @returnFromOfferTicketsFlag = 0
	--	SET @WhereCondition = CONCAT(@WhereCondition, ' AND ( PT.GUID NOT IN (SELECT TicketGUID FROM  #TicketContainsSpecialOffers) )');
    
	
	--================= if user can not only return ticket from current pos station, add the condition to include the ticket that belong to current station
	IF @returnFromDiffStationsFlag = 0 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND PS.StationGUID = ''',CAST(@stationGuid AS NVARCHAR(256)),'''');
	
	
	--================= if user can y return ticket from current pos station as well as other pos station, add the condition to include the ticket that belong to current station and other posstation
	IF @returnFromDiffStationsFlag = 1 
		BEGIN
			IF (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)  
			BEGIN
				SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, 'LEFT JOIN (SELECT ReturnStationGUID AS StationGUID ',					
																	' FROM  POSSDStationReturnStations000 ',
																	' WHERE StationGUID = ''',CAST(@stationGuid AS NVARCHAR(256)),''') AS PRS ON (PS.StationGUID = PRS.StationGUID) ');
			END;
			SET @CurrentFromTable = CONCAT(@CurrentFromTable, 'LEFT JOIN (SELECT ReturnStationGUID AS StationGUID ',					
																' FROM  POSSDStationReturnStations000 ',
																' WHERE StationGUID = ''',CAST(@stationGuid AS NVARCHAR(256)),''') AS PRS ON (PS.StationGUID = PRS.StationGUID) ');

			
			SET @WhereCondition = CONCAT(@WhereCondition, ' AND ((PS.StationGUID = ''',CAST(@stationGuid AS NVARCHAR(256)),''') OR (PRS.StationGUID IS NOT NULL) )');
		END	

	
	--================= Build the sql statement of previous year and current year ticket list and then excute it		
	IF  (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)
		SET @PrevYearQuery	= CONCAT('SELECT PT.Guid  ', @PrevYearFromTable, @WhereCondition , ' GROUP BY PT.GUID ') ;
		
	SET @CurrentYearQuery		= CONCAT('SELECT PT.Guid  ', @CurrentFromTable,  @WhereCondition , ' GROUP BY PT.GUID ') ;	
		
	IF (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)  
		SET @FinalQuery = CONCAT(@PrevYearQuery, ' UNION ALL ', @CurrentYearQuery);
	ELSE
		SET @FinalQuery =  @CurrentYearQuery;
	EXECUTE sp_executesql @FinalQuery;	 
		
END
#################################################################
#END
