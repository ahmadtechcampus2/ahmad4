#########################################################
CREATE PROCEDURE prcPOSSD_Station_UpdateReturnedQtyForOriginalSaleTicketFromPrevYear
(
	@StationGuid UNIQUEIDENTIFIER, 
	@ticketItemGuid UNIQUEIDENTIFIER,
	@returnedQty FLOAT
)
AS 
BEGIN
	
	DECLARE @returnExpireDaysValue INT = 0, @returnPrevFile UNIQUEIDENTIFIER = 0x0
	DECLARE  @returnFromPrevFile BIT = (select bRetunFromPrevYear from  POSSDStationResale000 WHERE StationGUID = @StationGuid)
	IF(@returnFromPrevFile = 1)
		SET @returnPrevFile =(select PrevYearFile from  POSSDStationResale000 WHERE StationGUID = @stationGuid)
    
	DECLARE @databaseName nvarchar(50) = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @returnPrevFile)
	DECLARE @query NVARCHAR(MAX), @subQuery NVARCHAR(MAX)
		SET @query = ' UPDATE ' + @databaseName + '..POSSDTicketItem000 set ReturnedQty = ' 
		           + CAST(@returnedQty AS NVARCHAR(256)) + ' WHERE GUID= ''' + CAST(@ticketItemGuid AS NVARCHAR(256)) + ''' '
	
	EXECUTE sp_executesql @query
		
END
#########################################################
CREATE PROCEDURE prcPOSSDTicket_UpdateReturnedQty
	@ShiftGuid UNIQUEIDENTIFIER,
	@RelatedFromGuid UNIQUEIDENTIFIER
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDTicket_UpdateReturnedQty
	Purpose: Update retruned qty of the sales or purchase ticket based on all return transaction 
	How to Call: EXEC prcPOSSDTicket_UpdateReturnedQty '53A3AE21-280B-4884-81A1-BEC9CC348233','7b71319c-3a71-4dea-a222-39cc8d68967f'
	Created By: Hanadi Salka												Created On: 14 Feb 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @TicketTypeSalesRetun					INT = 2;
	DECLARE @TicketTypePurchaseReturn				INT = 3;
	DECLARE @StationGuid							UNIQUEIDENTIFIER = NULL;
	DECLARE @RelationTypeExchangeFromSale			INT = 2;
	DECLARE @RelationTypeReturnFromSale				INT = 3;
	DECLARE @Count									INT = 0;
	DECLARE @ReturnExpireDaysValue					INT = 0;
	DECLARE @ReturnPrevFile							UNIQUEIDENTIFIER = 0x0;
	DECLARE @ReturnFromPrevFile						BIT = NULL;	
	DECLARE @DatabaseName							NVARCHAR(50) = NULL;
	DECLARE @SqlQuery								NVARCHAR(MAX) = NULL;
	SELECT @Count = COUNT(*) FROM POSSDTicket000 WHERE GUID = @RelatedFromGuid;	
	IF @Count = 0 
		BEGIN			
			SET @StationGuid = (SELECT StationGUID FROM POSSDShift000 WHERE GUID = @ShiftGuid);
			-- Check if we can return from previous year
			SET @ReturnFromPrevFile = (SELECT bRetunFromPrevYear FROM  POSSDStationResale000 WHERE StationGUID = @StationGuid); 			
			IF(@ReturnFromPrevFile = 1)
				BEGIN					
					SET @ReturnPrevFile = (SELECT PrevYearFile FROM  POSSDStationResale000 WHERE StationGUID = @StationGuid)
					SET @DatabaseName = (SELECT DatabaseName FROM ReportDataSources000 WHERE Guid = @ReturnPrevFile);
					-- UPDATE THE RETURN QTY FROM ALL SALES RETURN THAT IS IN CURRENT DATABASE AND PREVIOUS DATABASE
					SET @SqlQuery = CONCAT('UPDATE	',@DatabaseName,'..POSSDTicketItem000 ',
							'SET ',@DatabaseName,'..POSSDTicketItem000.ReturnedQty = RTicket.RTDetailQty ',
							'FROM ',@DatabaseName,'..POSSDTicketItem000 INNER JOIN ',
							'( ',
								'SELECT ',
								'TH.RelatedFrom , ',
								'TD.MatGUID AS RTDetailMatGuid, ',
								'SUM(TD.Qty) AS RTDetailQty ',
								'FROM ',@DatabaseName,'..POSSDTicket000 AS TH INNER JOIN ',@DatabaseName,'..POSSDTicketItem000 AS TD ON (TD.TicketGUID = TH.GUID) ',
								'WHERE TH.RelatedFrom = ''',CAST(@RelatedFromGuid AS NVARCHAR(256)),''' ',
										'AND TH.Type IN(',@TicketTypeSalesRetun,', ',@TicketTypePurchaseReturn,') ', 
										'AND TH.RelationType IN (',@RelationTypeExchangeFromSale,',',@RelationTypeReturnFromSale,') ',
										'AND TH.State = 0 ',
								'GROUP BY TH.RelatedFrom, TD.MatGUID ',
								'UNION ALL ',
								'SELECT ',
								'TH.RelatedFrom , ',
								'TD.MatGUID AS RTDetailMatGuid, ',
								'SUM(TD.Qty) AS RTDetailQty ',
								'FROM POSSDTicket000 AS TH INNER JOIN POSSDTicketItem000 AS TD ON (TD.TicketGUID = TH.GUID) ',
								'WHERE TH.RelatedFrom = ''',CAST(@RelatedFromGuid AS NVARCHAR(256)),''' ',
										'AND TH.Type IN(',@TicketTypeSalesRetun,', ',@TicketTypePurchaseReturn,') ', 
										'AND TH.RelationType IN (',@RelationTypeExchangeFromSale,',',@RelationTypeReturnFromSale,') ',
										'AND TH.State = 0 ',
								'GROUP BY TH.RelatedFrom, TD.MatGUID ',
							') AS RTicket ON (',@DatabaseName,'..POSSDTicketItem000.TicketGUID = RTicket.RelatedFrom AND ',@DatabaseName,'..POSSDTicketItem000.MatGUID = RTicket.RTDetailMatGuid) ');
					
					EXECUTE sp_executesql @SqlQuery;
				END;
		END;
	ELSE
		BEGIN
			UPDATE	POSSDTicketItem000
			SET POSSDTicketItem000.ReturnedQty = RTicket.RTDetailQty
			FROM POSSDTicketItem000 INNER JOIN 
			(
				SELECT 
				TH.RelatedFrom ,
				TD.MatGUID AS RTDetailMatGuid,
				SUM(TD.Qty) AS RTDetailQty
				FROM POSSDTicket000 AS TH INNER JOIN POSSDTicketItem000 AS TD ON (TD.TicketGUID = TH.GUID)
				WHERE RelatedFrom = @RelatedFromGuid
						AND TH.Type IN(@TicketTypeSalesRetun, @TicketTypePurchaseReturn) 
						AND TH.RelationType IN (@RelationTypeExchangeFromSale,@RelationTypeReturnFromSale)
						AND TH.State = 0
				GROUP BY TH.RelatedFrom, TD.MatGUID
			) AS RTicket ON (POSSDTicketItem000.TicketGUID = RTicket.RelatedFrom AND POSSDTicketItem000.MatGUID = RTicket.RTDetailMatGuid)
		END;
 END
#########################################################
#END