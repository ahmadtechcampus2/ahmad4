################################################################################
CREATE PROCEDURE prcPOSSD_Order_GetItems
-- Params -------------------------------------
	@StationGuid		UNIQUEIDENTIFIER,
	@CustomerGuid		UNIQUEIDENTIFIER,
	@DriverGuid         UNIQUEIDENTIFIER,
	@MaterialGuid		UNIQUEIDENTIFIER,
	@GroupGuid			UNIQUEIDENTIFIER,
	@OrderType		    INT,
	@OrderState			INT,
	@OrderNumber		INT,
	@TripNumber		    INT,
	@DateType           INT,
	@StartDate			DATETIME,
	@EndDate			DATETIME
-----------------------------------------------
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]();

	--- Filters
	DECLARE @WaitingCheckFilter    INT = 2 
	DECLARE @AssignedCheckFilter   INT = 4
	DECLARE @InDeliveryCheckFilter INT = 8
	DECLARE @CanceledCheckFilter   INT = 16
	DECLARE @PaidCheckFilter	   INT = 32
	
	--- States
	DECLARE @WaitingState    INT = 5
	DECLARE @AssignedState   INT = 6
	DECLARE @InDeliveryState INT = 7
	DECLARE @CanceledState   INT = 2
	DECLARE @PaidState       INT = 0

	SELECT 
		OI.[GUID]                                    AS OrderGuid,
		OI.TicketGUID                                AS TicketGuid,
		TI.MatGUID                                   AS MatGuid,
		S.[GUID]                                     AS StationGuid,
		CU.[GUID]                                    AS CustomerGuid,
		TI.Qty                                       AS Qty,
		TI.Price                                     AS Price,
		TI.Value                                     AS Value,
		OI.Number                                    AS OrderNumber,
		T.OrderType                                  AS OrderType,
		T.[State]                                    AS OrderState,
		ISNULL(CAST(OT.Number AS NVARCHAR(50)), '')  AS TripNumber,
		

		MT.mtCode +' - '+ CASE @language WHEN 0 THEN MT.mtName 
									  ELSE CASE MT.mtLatinName WHEN '' THEN MT.mtName 
															   ELSE MT.mtLatinName END END AS  Material,

		S.Code +' - '+ CASE @language WHEN 0 THEN S.Name 
									  ELSE CASE S.LatinName WHEN '' THEN S.Name  
															   ELSE S.LatinName END END AS  Station,

		CASE @language WHEN 0 THEN CU.CustomerName
									  ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName
															   ELSE CU.LatinName END END AS  Customer,

        CASE TI.UnitType WHEN 0 THEN MT.mtUnity
						 WHEN 1 THEN MT.mtUnit2
						 WHEN 2 THEN MT.mtUnit3 END AS Unit
		

	FROM 
		POSSDTicketItem000 TI
		INNER JOIN POSSDTicket000 T			  ON TI.TicketGUID  =  T.[GUID]
		INNER JOIN POSSDTicketOrderInfo000 OI ON OI.TicketGUID  =  T.[GUID]
		INNER JOIN vwmt MT					  ON TI.MatGUID	    = MT.mtGUID
		INNER JOIN POSSDStation000 S		  ON OI.StationGUID =  S.[GUID]
		INNER JOIN cu000 CU				      ON T.CustomerGUID = CU.[GUID]
		LEFT JOIN POSSDOrderTrip000 OT        ON OT.[GUID]		= OI.TripGUID
		


	WHERE
		( S.[GUID]  = @StationGuid OR @StationGuid = 0x0 )
	AND ( T.CustomerGUID = @CustomerGuid    OR @CustomerGuid    = 0x0 )
	AND ( OI.DriverGUID = @DriverGuid    OR @DriverGuid    = 0x0 )
	AND ( T.OrderType = @OrderType OR @OrderType = 0 )
	AND ( (T.[State] = @WaitingState    AND @OrderState & @WaitingCheckFilter    = @WaitingCheckFilter)
	   OR (T.[State] = @AssignedState   AND @OrderState & @AssignedCheckFilter   = @AssignedCheckFilter)
	   OR (T.[State] = @InDeliveryState AND @OrderState & @InDeliveryCheckFilter = @InDeliveryCheckFilter)
	   OR (T.[State] = @CanceledState   AND @OrderState & @CanceledCheckFilter   = @CanceledCheckFilter)
	   OR (T.[State] = @PaidState       AND @OrderState & @PaidCheckFilter       = @PaidCheckFilter) )
	AND ( OI.Number = @OrderNumber OR @OrderNumber = 0)
	AND ( TI.MatGUID = @MaterialGuid OR @MaterialGuid = 0x0)
	AND ( MT.mtGroup = @GroupGuid OR @GroupGuid = 0x0)
	AND ( OT.Number = @TripNumber OR @TripNumber = 0)
	AND ( ((T.[OpenDate] BETWEEN @StartDate AND @EndDate) AND @DateType = 1 )
	   OR ((OI.EDD       BETWEEN @StartDate AND @EndDate) AND @DateType = 2 ) )
	ORDER BY
		OI.Number
#################################################################
#END
