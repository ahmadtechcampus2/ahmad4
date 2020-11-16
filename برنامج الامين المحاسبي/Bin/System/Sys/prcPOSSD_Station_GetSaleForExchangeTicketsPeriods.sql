################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSaleForExchangeTicketsPeriods
@ticketCode NVARCHAR(256),
@customerName NVARCHAR(256),
@startDate DATETIME2,
@endDate DATETIME2,
@stationGuid UNIQUEIDENTIFIER
AS 
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDTicket_UpdateReturnedQty
	Purpose: Update retruned qty of the sales or purchase ticket based on all return transaction 
	How to Call: EXEC prcPOSSDTicket_UpdateReturnedQty '53A3AE21-280B-4884-81A1-BEC9CC348233','7b71319c-3a71-4dea-a222-39cc8d68967f'
	Created By: 												Created On:
	Updated By:Hanadi Salka										Updated On:	13-Mar-2019												
	Change Note:
	Fix bug# 197546: the filter of sales transaction that belong to last year is not applied and the application returns all the sales transaction
	Fix bug# 198069: the system does not show the sales transaction that belong to previous year and different POS station
	Updated By:Hanadi Salka										Updated On:	14-Mar-2019												
	Change Note:
	Fix bug #198006: The system should exclude the sales transaction related to open sales return from the search result
	********************************************************************************************************/

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

	-- **************************************************************************************
	-- Read Return sales filter condition from the POSSDStationResale000 table
	SELECT 
		@returnExpireDaysFlag		= bReturnExpireDays,
		@returnExpireDays			= ReturnExpireDays,
		@returnFromPrevFileFlag		= bRetunFromPrevYear,
		--@returnFromOfferTicketsFlag	= bAllowReturnFromOffersTicket,
		@returnFromDiffStationsFlag	= bReturnFromDiffStations
	FROM POSSDStationResale000 
	WHERE StationGUID = @stationGuid;
    -- **************************************************************************************
	-- if return from prev year is on, then get the database name from ReportDataSources000 
	IF(@returnFromPrevFileFlag = 1)
	BEGIN
		SELECT 
			@databaseName = DS.DatabaseName
		FROM ReportDataSources000 AS DS INNER JOIN POSSDStationResale000 AS RS ON (RS.PrevYearFile = DS.Guid)
		WHERE RS.StationGUID = @stationGuid;				
	END;
	-- *********************************************************************************************
	-- build from clause of current year
		SET @CurrentFromTable = CONCAT(@CurrentFromTable,' FROM POSSDTicket000 PT INNER JOIN  POSSDTicketItem000 AS PTI  ON (PTI.TicketGUID = PT.GUID)');		
		SET @CurrentFromTable= CONCAT(@CurrentFromTable, ' INNER JOIN POSSDShift000 AS PS ON (PS.GUID = PT.ShiftGUID) ' );
		SET @CurrentFromTable = CONCAT(@CurrentFromTable, ' LEFT JOIN cu000 AS CU ON (CU.GUID = PT.CustomerGUID) ' );
		-- SET @CurrentFromTable = CONCAT(@CurrentFromTable, ' LEFT JOIN (SELECT RelatedFrom   FROM POSSDTicket000 AS SRT WHERE SRT.State IN (1,-1) AND SRT.TYPE = 2) AS OS ON (PT.GUID = OS.RelatedFrom) ');

	-- ******************************************************************************************
	-- build from clause of previous year
	IF @databaseName IS NOT NULL AND  LEN(@databaseName) > 0
		BEGIN
			SET @PrevYearFromTable = CONCAT(' FROM ', @databaseName +'..POSSDTicket000 PT INNER JOIN  ',@databaseName +'..POSSDTicketItem000 AS PTI  ON (PTI.TicketGUID = PT.GUID)');		
			SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' INNER JOIN ', @databaseName +'..POSSDShift000 AS PS ON (PS.GUID = PT.ShiftGUID) ' );
			SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' LEFT JOIN ', @databaseName +'..cu000 AS CU ON (CU.GUID = PT.CustomerGUID) ' );
			-- SET @PrevYearFromTable = CONCAT(@PrevYearFromTable, ' LEFT JOIN (SELECT RelatedFrom   FROM POSSDTicket000 AS SRT WHERE SRT.State IN (1,-1) AND SRT.TYPE = 2) AS OS ON (PT.GUID = OS.RelatedFrom) ');
		END;
	
	
	-- ******************************************************************************************
	-- Buid where condition ticket type is sale and status is paied
	SET @WhereCondition = CONCAT(@WhereCondition, ' WHERE  PT.State  = 0 AND PT.Type = 0 ');
	
	-- ****************************************************************************************** 
	-- if ticket code is not null, add ticket code condition		
	IF @ticketCode IS NOT NULL AND LEN(@ticketCode) > 0			
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND PT.Code =  ''',@ticketCode,'''');
	
	-- ************************************************************************************************
	-- Exclude the sales transaction in open sales return tickets
	-- SET @WhereCondition = CONCAT(@WhereCondition, ' AND ((PT.GUID != OS.RelatedFrom) OR (OS.RelatedFrom IS NULL)) ');
	-- ****************************************************************************************** 
	-- if customer name is not null, add ticket customer condition				
	IF @customerName IS NOT NULL AND LEN(@customerName) > 0
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CU.LatinName LIKE ''%' + @customerName + '%'' OR CU.CustomerName LIKE ''%'+ @customerName +'%''');
	
	-- ****************************************************************************************** 
	-- if start date is not null, add payment date >= start date condition		
	IF @startDate IS NOT NULL 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CONVERT(date, PaymentDate, 105) >=  ''',CONVERT(date, @startDate, 105),'''');
	
	-- ****************************************************************************************** 
	-- if end date is not null, add end date <= start date condition		
	IF @endDate IS NOT NULL 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND CONVERT(date, PaymentDate, 105) <=  ''',CONVERT(date, @endDate, 105),'''');
	
	-- ****************************************************************************************** 
	-- if user can not return the sales after certain days, add the condition 
	IF @returnExpireDaysFlag IS NOT NULL AND @returnExpireDaysFlag = 1
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND DATEDIFF(day, PaymentDate, GETDATE()) <=  ', @returnExpireDays);
	-- ****************************************************************************************** 
	-- if user can not return ticket that has special offer, add the condition 	to include the ticket where SpecialOfferGUID is null or empty 
	--IF @returnFromOfferTicketsFlag = 0
	--	SET @WhereCondition = CONCAT(@WhereCondition, ' AND ((PT.SpecialOfferGUID IS NULL OR PT.SpecialOfferGUID =  0x0 ) OR (PTI.SpecialOfferGUID IS NULL OR PTI.SpecialOfferGUID =  0x0 ))');
    
	-- ****************************************************************************************** 
	-- if user can not only return ticket from current pos station, add the condition to include the ticket that belong to current station
	IF @returnFromDiffStationsFlag = 0 
		SET @WhereCondition = CONCAT(@WhereCondition, ' AND PS.StationGUID = ''',CAST(@stationGuid AS NVARCHAR(256)),'''');
	
	-- ****************************************************************************************** 
	-- if user can y return ticket from current pos station as well as other pos station, add the condition to include the ticket that belong to current station and other posstation
	IF @returnFromDiffStationsFlag = 1 
		BEGIN
			IF  (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)  
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
		-- *********************************************************************************************************************
		-- Build the sql statement of previous year and current year ticket list and then excute it		
		IF  (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)
			SET @PrevYearQuery	= CONCAT('SELECT YEAR(PT.PaymentDate) AS Year, MONTH(PT.PaymentDate) AS Month ', @PrevYearFromTable, @WhereCondition , ' GROUP BY YEAR(PT.PaymentDate), MONTH(PT.PaymentDate)  ') ;
		
		SET @CurrentYearQuery		= CONCAT('SELECT YEAR(PT.PaymentDate) AS Year, MONTH(PT.PaymentDate) AS Month  ', @CurrentFromTable,  @WhereCondition , ' GROUP BY YEAR(PT.PaymentDate), MONTH(PT.PaymentDate)   ORDER BY Year, Month') ;	
		
		IF (@databaseName IS NOT NULL AND  LEN(@databaseName) > 0)  
			SET @FinalQuery = CONCAT(@PrevYearQuery, ' UNION ALL ', @CurrentYearQuery);
		ELSE
			SET @FinalQuery =  @CurrentYearQuery;
		EXECUTE sp_executesql @FinalQuery;

 
END
#################################################################
#END
