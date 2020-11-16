################################################################################
CREATE PROCEDURE prcPOSSD_rep_POSSalesAnalysis
	@StartDate 				[DATETIME], 
	@EndDate 				[DATETIME], 
	@POSStationGuid 		[UNIQUEIDENTIFIER] = 0x00,
	@CurrentShiftGuid 		[UNIQUEIDENTIFIER] = 0x00
AS
/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_rep_POSSalesAnalysis
	Purpose: Show sales analysis of current shift and current month. It also shows the sales of previous shift and prvious month

	How to Call: 
	api/Reports/RepPOSSalesAnalysis?POSStationGuid=3bfb80e6-6c43-434d-a60b-8e6a14d9bdbd&currentShiftGuid=b871e950-c02c-499b-8fe2-8a2367c3b45a&startDate=2018-07-01 00:00:00&endDate=2018-07-22 13:43:29
	api/Reports/RepPOSSalesAnalysis?POSStationGuid=41B99029-0534-4CDD-A201-14860456CAE3&currentShiftGuid=C0B021FC-7D6E-4318-B3BA-E41B28DB81B8&startDate=2018-07-01&endDate=2018-07-11 
	DECLARE @StartDate 				[DATETIME] = '2018-08-01 00:00:00';
	DECLARE @EndDate 				[DATETIME] = '2018-08-30 00:00:00';
	DECLARE @POSStationGuid 	    [UNIQUEIDENTIFIER] = '0E1F763F-47AD-4610-ACA5-743E1A70A019'; -- 0 All Mat or MatNumber 
	DECLARE @CurrentShiftGuid		[UNIQUEIDENTIFIER] = 'CF44252B-23C5-44A6-BF4F-F83770D06F74';
	
	EXEC prcPOSSD_rep_POSSalesAnalysis
	@StartDate, 
	@EndDate, 
	@POSStationGuid,
	@CurrentShiftGuid
	

	Create By: Hanadi Salka													Created On: 05 July 2018
	Updated By: Hanadi Salka												Updated On:	18 July 2018												
	Change Note:
	Use net Value to calculate the sales amount (sub total - discount + addition)
	Do not include the sales return tickets
	Do not include tickets with status canceled

	Updated By: Hanadi Salka												Updated On:	22 July 2018												
	Change Note:
	Add condition to check if shift close date is null when we get current shift sales
	change the sales qty to be count of sales transactions instead of total quantity of the sales transactions
	Show zero as varirance when current sales value or current sales qty is zero

	Updated By: Hanadi Salka												Updated On:	05 Aug 2018												
	Change Note:
	Do not include tickets with status deleted

	Updated By: Hanadi Salka												Updated On:	07 Aug 2018												
	Change Note:
	Add new column HasOpenShift to indicate if there is open shift or no for the current pos
	********************************************************************************************************/
	DECLARE @SaleBTGuid [UNIQUEIDENTIFIER] = 0x00;
	DECLARE @SaleRBTGuid [UNIQUEIDENTIFIER] = 0x00;

	DECLARE @CurrentShiftSalesValue			[FLOAT] = NULL;
	DECLARE @CurrentShiftSalesQty			[FLOAT] = NULL;
	DECLARE @CurrentMonthSalesValue			[FLOAT] = NULL;
	DECLARE @CurrentMonthSalesQty			[FLOAT] = NULL;

	DECLARE @PreviousShiftSalesValue		[FLOAT] = NULL;
	DECLARE @PreviousShiftSalesQty			[FLOAT] = NULL;
	DECLARE @PreviousMonthSalesValue		[FLOAT] = NULL;
	DECLARE @PreviousMonthSalesQty			[FLOAT] = NULL;

	DECLARE @PreviousShiftGuid				[UNIQUEIDENTIFIER] = NULL;
	DECLARE @PreviousMonthDate				[DATETIME];
	DECLARE @PreviousMonthMonthNo 			[INT];	
	DECLARE @PreviousMonthYearNo			[INT];
	DECLARE @OpenShiftCount					[INT];
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
	 
	-- ************************************************************************
	-- Get the previous month start date and previous shift guid
	SELECT @PreviousMonthDate		= DATEADD(month, -1, @StartDate);
	SELECT @PreviousMonthMonthNo	= MONTH(@PreviousMonthDate);
	SELECT @PreviousMonthYearNo		= YEAR(@PreviousMonthDate);	
	
	
	SELECT 
		TOP 1 @PreviousShiftGuid = POSShift.GUID
	FROM  POSSDShift000 AS POSShift
	WHERE POSShift.StationGUID = @POSStationGuid
		  -- AND POSShift.GUID != @CurrentShiftGuid
		  AND POSShift.CloseDate IS NOT NULL
	ORDER BY POSShift.CloseDate DESC;
    
	-- SELECT @PreviousShiftGuid;
	-- ********************************************************************************	
	-- Get current shift sales qty and sales value
	SELECT 
	
		-- @CurrentShiftSalesQty	=	ABS(SUM(BaseQty * BuDirection)),
		@CurrentShiftSalesQty	=	COUNT(DISTINCT TicketGUID),
		@CurrentShiftSalesValue =	ABS(SUM(NetValue * BuDirection))
	
	FROM	vwPOSSDTicketItems
	WHERE	vwPOSSDTicketItems.POSStationGUID = @POSStationGuid 
			AND vwPOSSDTicketItems.ShiftGUID = @CurrentShiftGuid
			AND vwPOSSDTicketItems.ShiftCloseDate IS NULL
			AND vwPOSSDTicketItems.BuGUID IN (@SaleBTGuid)
			AND vwPOSSDTicketItems.TicketStatus NOT IN ( 2, 4) ;
	-- ********************************************************************************	
	-- Get Count of open shift
	SELECT 
		@OpenShiftCount	=	COUNT(*)		
	FROM	POSSDShift000
	WHERE	POSSDShift000.StationGUID = @POSStationGuid 
			AND POSSDShift000.GUID = @CurrentShiftGuid
			AND POSSDShift000.CloseDate IS NULL;			
	
	-- ********************************************************************************	
	-- Get current month sales qty and sales value
	SELECT 
	
		-- @CurrentMonthSalesQty	=	ABS(SUM(BaseQty * BuDirection)),
		@CurrentMonthSalesQty	=	COUNT(DISTINCT TicketGUID),
		@CurrentMonthSalesValue =	ABS(SUM(NetValue * BuDirection))
	
	FROM	vwPOSSDTicketItems
	WHERE	vwPOSSDTicketItems.POSStationGUID = @POSStationGuid 
			AND CONVERT(DATE, vwPOSSDTicketItems.PaymentDate) BETWEEN CONVERT(DATE, @StartDate)  AND CONVERT(DATE, @EndDate)
			AND vwPOSSDTicketItems.BuGUID IN (@SaleBTGuid)
			AND vwPOSSDTicketItems.TicketStatus NOT IN ( 2, 4);
	
	-- ********************************************************************************	
	-- Get previous month sales qty and sales value
	SELECT 	
		-- @PreviousMonthSalesQty	=	ABS(SUM(BaseQty * BuDirection)),
		@PreviousMonthSalesQty	=	COUNT(DISTINCT TicketGUID),
		@PreviousMonthSalesValue =	ABS(SUM(NetValue * BuDirection))
	
	FROM	vwPOSSDTicketItems
	WHERE	vwPOSSDTicketItems.POSStationGUID			= @POSStationGuid 
			AND MONTH(vwPOSSDTicketItems.PaymentDate)	= @PreviousMonthMonthNo			
			AND YEAR(vwPOSSDTicketItems.PaymentDate)	= @PreviousMonthYearNo
			AND vwPOSSDTicketItems.BuGUID IN (@SaleBTGuid)
			AND vwPOSSDTicketItems.TicketStatus NOT IN ( 2, 4);


	-- ********************************************************************************	
	-- Get previous shift sales qty and sales value	
	IF @PreviousShiftGuid IS NOT NULL 
		SELECT 
	
			-- @PreviousShiftSalesQty	=	ABS(SUM(BaseQty * BuDirection)),
			@PreviousShiftSalesQty	=	COUNT(DISTINCT TicketGUID),
			@PreviousShiftSalesValue =	ABS(SUM(NetValue * BuDirection))
	
		FROM	vwPOSSDTicketItems
		WHERE	vwPOSSDTicketItems.POSStationGUID	= @POSStationGuid 
				AND vwPOSSDTicketItems.ShiftGUID	= @PreviousShiftGuid
				AND vwPOSSDTicketItems.BuGUID IN (@SaleBTGuid)
				AND vwPOSSDTicketItems.TicketStatus NOT IN ( 2, 4);
	
	-- ********************************************************************************	
	-- Display report final result
	SET @CurrentShiftSalesQty		= ISNULL(@CurrentShiftSalesQty, 0);
	SET @CurrentShiftSalesValue		= ISNULL(@CurrentShiftSalesValue, 0);
	SET @CurrentMonthSalesQty		= ISNULL(@CurrentMonthSalesQty, 0);
	SET @CurrentMonthSalesValue		= ISNULL(@CurrentMonthSalesValue, 0);
	SET @PreviousMonthSalesQty		= ISNULL(@PreviousMonthSalesQty, 0);
	SET @PreviousMonthSalesValue	= ISNULL(@PreviousMonthSalesValue, 0);
	SET @PreviousShiftSalesQty		= ISNULL(@PreviousShiftSalesQty, 0);
	SET @PreviousShiftSalesValue	= ISNULL(@PreviousShiftSalesValue, 0);
	
	SELECT 
		CASE WHEN @OpenShiftCount = 0 THEN 0 ELSE 1 END AS HasOpenShift, 
		@CurrentShiftSalesQty		AS CurrentShiftSalesQty,
		@CurrentShiftSalesValue		AS CurrentShiftSalesValue,
		@CurrentMonthSalesQty		AS CurrentMonthSalesQty,
		@CurrentMonthSalesValue		AS CurrentMonthSalesValue,
		@PreviousMonthSalesQty		AS PreviousMonthSalesQty,
		@PreviousMonthSalesValue	AS PreviousMonthSalesValue,
		@PreviousShiftSalesQty		AS PreviousShiftSalesQty,
		@PreviousShiftSalesValue	AS PreviousShiftSalesValue,
		
		CASE 
			WHEN @PreviousShiftSalesQty != 0  AND @CurrentShiftSalesQty != 0 THEN ROUND(((((@CurrentShiftSalesQty - @PreviousShiftSalesQty) /  @PreviousShiftSalesQty) * 100)),0)
			WHEN @PreviousShiftSalesQty != 0  AND @CurrentShiftSalesQty = 0 THEN 0
		ELSE 100
		END AS CurrentShiftSalesQtyVariancePercent,
		
		CASE 
			WHEN @PreviousShiftSalesValue != 0 AND @CurrentShiftSalesValue != 0  THEN ROUND(((((@CurrentShiftSalesValue - @PreviousShiftSalesValue) /  @PreviousShiftSalesValue) * 100)),0)
			WHEN @PreviousShiftSalesValue != 0 AND @CurrentShiftSalesValue = 0  THEN 0
		ELSE 100
		END AS CurrentShiftSalesValueVariancePercent,
		
		CASE 
			WHEN @PreviousMonthSalesQty != 0  AND @CurrentMonthSalesQty != 0 THEN ROUND(((((@CurrentMonthSalesQty - @PreviousMonthSalesQty) /  @PreviousMonthSalesQty) * 100)),0)
			WHEN @PreviousMonthSalesQty != 0  AND @CurrentMonthSalesQty = 0 THEN 0
		ELSE 100
		END AS CurrentMonthSalesQtyVariancePercent,

		CASE 
			WHEN @PreviousMonthSalesValue != 0 AND @CurrentMonthSalesValue != 0  THEN ROUND(((((@CurrentMonthSalesValue - @PreviousMonthSalesValue) /  @PreviousMonthSalesValue) * 100)),0)
			WHEN @PreviousMonthSalesValue != 0 AND @CurrentMonthSalesValue = 0  THEN 0
		ELSE 100
		END AS CurrentMonthSalesValueVariancePercent;
#################################################################
#END
