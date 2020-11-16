################################################################################
CREATE PROCEDURE prcPOSSD_rep_TopProductSale
	@StartDate 				[DATETIME], 
	@EndDate 				[DATETIME], 
	@POSStationGuid 		[UNIQUEIDENTIFIER] = 0x00, -- 0 All Mat or MatNumber 
	@SaleBy					VARCHAR(20) = 'QTY'
AS
/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_rep_TopProductSale
	Purpose: Show the top 5 product's sale by qunatity for a specfic POS station within the specified time period

	How to Call: 
	
	DECLARE @StartDate 				[DATETIME] = '2018-01-01 00:00:00';
	DECLARE @EndDate 				[DATETIME] = '2018-08-15 00:00:00';
	DECLARE @POSStationGuid 	    [UNIQUEIDENTIFIER] = '0E1F763F-47AD-4610-ACA5-743E1A70A019'; -- 0 All Mat or MatNumber 
	DECLARE @SaleBy	 VARCHAR(20) = 'QTY';
	
	EXEC prcPOSSD_rep_TopProductSale
	@StartDate, 
	@EndDate, 
	@POSStationGuid,
	@SaleBy
	

	Create By: Hanadi Salka													Created On: 04 June 2018
	
	Updated By: Hanadi Salka												Updated On:	18 July 2018												
	Change Note:
	Use net Value to calculate the sales amount (sub total - discount + addition)
	Do not include the sales return tickets
	Do not include tickets with status canceled
	
	Updated By: Hanadi Salka												Updated On:	05 Aug 2018												
	Change Note:
	Do not include tickets with status deleted
	********************************************************************************************************/
	DECLARE @SaleBTGuid [UNIQUEIDENTIFIER] = 0x00;
	DECLARE @SaleRBTGuid [UNIQUEIDENTIFIER] = 0x00;
	-- ************************************************************************
	-- Get the guid of sale and sales return bill 
	SELECT 
		@SaleBTGuid = [POSStation].SaleBillTypeGUID,
		@SaleRBTGuid = [POSStation].SaleReturnBillTypeGUID   
	FROM
		[POSSDStation000] AS [POSStation]
    WHERE
	[POSStation].GUID =  @POSStationGuid ;

	-- ********************************************************************************	
	 
	SELECT TOP 5
	MatGUID AS ItemGuid,
	MatName,	
	MatLatinName,
	MatCode,	
	CASE UPPER(@SaleBy)
		WHEN 'QTY' THEN ABS(SUM(BaseQty * BuDirection))
		WHEN 'VALUE' THEN ABS(SUM(NetValue * BuDirection))
	END	 AS TopSale
	FROM	vwPOSSDTicketItems
	WHERE	vwPOSSDTicketItems.POSStationGUID = @POSStationGuid 
			AND CONVERT(DATE, vwPOSSDTicketItems.PaymentDate) BETWEEN CONVERT(DATE, @StartDate)  AND CONVERT(DATE, @EndDate)
			AND vwPOSSDTicketItems.BuGUID IN (@SaleBTGuid)
			AND vwPOSSDTicketItems.TicketStatus NOT IN ( 2, 4) 

	GROUP BY MatGUID, MatName, MatLatinName, MatCode
	ORDER BY TopSale DESC;			
#################################################################
#END
