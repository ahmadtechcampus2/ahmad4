################################################################################
CREATE PROCEDURE  repPOSSD_SepecialOffers
-- Params -------------------------------   
	@SpecialOfferGuid      UNIQUEIDENTIFIER  ,
	@MatGuid			   UNIQUEIDENTIFIER,
	@GroupGuid             UNIQUEIDENTIFIER ,
	@CustomerGuid          UNIQUEIDENTIFIER ,
	@StationGuid           UNIQUEIDENTIFIER ,
	@EmployeeGuid          UNIQUEIDENTIFIER,
	@SalesmanGuid          UNIQUEIDENTIFIER,
	@CostCenterGuid        UNIQUEIDENTIFIER,
	@StartDate			   DATETIME,
	@EndDate			   DATETIME
AS
   SET NOCOUNT ON
------------------------------------------------------------------------
	
	DECLARE @Lang INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @TicketGUID UNIQUEIDENTIFIER

	DECLARE  @SpecialOfferDetails TABLE
	(
		SpecialOfferGUID		UNIQUEIDENTIFIER,
		SpecialOfferType        INT,  
		SpecialOfferName		NVARCHAR(250),
		SpecialOfferStartDate   DateTime,
		SpecialOfferEndDate		DateTime,
		SpecialOfferStartTime   DateTime,
		SpecialOfferEndTime		DateTime,
		SpecialOfferWorksDay    NVARCHAR(250),
		SpecialOfferMaxQty		INT,
		SpecialOfferExpireQty   INT,
		CustomerGUID			UNIQUEIDENTIFIER,
		CustomerName			NVARCHAR(250),
		StationGUID				UNIQUEIDENTIFIER,
		StationName   		    NVARCHAR(250),
		EmployeeGUID			UNIQUEIDENTIFIER,
		EmployeeName			NVARCHAR(250),
		SalesmanGUID			UNIQUEIDENTIFIER,
		SalesmanName			NVARCHAR(250),
		SalesmanCostCenterGUID  UNIQUEIDENTIFIER,
		SalesmanCostCenter		NVARCHAR(250),
		ShiftGUID				UNIQUEIDENTIFIER,
		ShiftCode 				NVARCHAR(250),
		TicketGUID				UNIQUEIDENTIFIER,
		TicketDate				DateTime,
		TicketCode  			NVARCHAR(250),
		TicketTime				DateTime,
		MaterialGUID			UNIQUEIDENTIFIER,
		MaterialName			NVARCHAR(250),
		Unit					NVARCHAR(250),
		Qty						FLOAT,
		SpecialOfferQty			FLOAT,
		Price					FLOAT,
		UnitDiscount			FLOAT,
		DiscountPercentage		FLOAT,
		Discount				FLOAT,
		SalesNet				FLOAT 
	)
	
	DECLARE  @TicketItemsDiscouts TABLE
					  ( Guid					UNIQUEIDENTIFIER,
						TicketGuid				UNIQUEIDENTIFIER,
						ValueToDiscount				FLOAT,
						ValueToAdd					FLOAT ,
						ValueAfterCalc				FLOAT,
						ItemShareOfTotalDiscount	FLOAT,
						ItemShareOfTotalAddition	FLOAT 
					 )
	
	
	
	
		 DECLARE @c cursor
		 SET @c = CURSOR FAST_FORWARD FOR  
				SELECT  GUID 
				FROM POSSDTicket000 
				OPEN @c 
				FETCH FROM @c INTO @TicketGUID
					WHILE @@FETCH_STATUS = 0
					BEGIN
						INSERT INTO @TicketItemsDiscouts
						SELECT * FROM  dbo.fnPOSSD_Ticket_GetDiscountAndAddition(@TicketGUID)
						FETCH NEXT FROM @c  INTO @TicketGUID
					END 
				CLOSE @c
				DEALLOCATE @c

	INSERT INTO @SpecialOfferDetails
	SELECT 
		specialOffer.GUID									AS SpecialOfferGUID,
		specialOffer.[Type]					                AS SpecialOfferType,
		CASE @Lang WHEN 0 THEN specialOffer.Name
				   ELSE CASE specialOffer.LatinName WHEN '' THEN specialOffer.Name 
				   ELSE specialOffer.LatinName END END  
															AS SpecialOfferName,

		specialOffer.StartDate								AS SpecialOfferStartDate,
		specialOffer.EndDate								AS SpecialOfferEndDate,
		specialOffer.StartTime								AS SpecialOfferStartTime,
		specialOffer.EndTime								AS SpecialOfferEndTime,
		''													AS SpecialOfferWorkDays,
		specialOffer.MaxQty									AS SpecialOfferMaxQty, 
		specialOffer.ExpireQty								AS SpecialOfferExpireQty,
		ticket.CustomerGUID									AS CustomerGUID,
		CASE @Lang WHEN 0 THEN cu.CustomerName
				   ELSE CASE cu.LatinName WHEN '' THEN cu.CustomerName 
				   ELSE cu.LatinName END END  				AS CustomerName,
		[shift].StationGUID									AS StationGUID, 
	    CASE @Lang WHEN 0 THEN station.Name
				   ELSE CASE station.LatinName WHEN '' THEN station.Name 
				   ELSE station.LatinName END END  			AS StationName,
		[shiftDetails].EmployeeGUID							AS EmployeeGUID,
		CASE @Lang WHEN 0 THEN employee.Name
				   ELSE CASE employee.LatinName WHEN '' THEN employee.Name 
				   ELSE employee.LatinName END END  		AS EmployeeName,
		salesman.GUID										AS SalesmanGUID,
		CASE @Lang WHEN 0 THEN salesman.Name
				   ELSE CASE salesman.LatinName WHEN '' THEN salesman.Name 
				   ELSE salesman.LatinName END END  		AS SalesmanName,
		salesman.CostCenterGUID								AS SalesmanCostCenterGUID,
		CASE @Lang WHEN 0 THEN costCneter.Name
				   ELSE CASE costCneter.LatinName WHEN '' THEN costCneter.Name 
				   ELSE costCneter.LatinName END END  		AS SalesmanCostCenter,
		[shift].GUID										AS ShiftGUID,
		[shift].Code										AS ShiftCode,
		ticket.GUID											AS TicketGUID,
		ticket.PaymentDate									AS TicketDate,
		ticket.Code											AS TicketCode,
		ticket.PaymentDate									AS TicketTime,
		Mt.GUID												AS MaterialGUID, 
		CASE @Lang WHEN 0 THEN MT.Name
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END  AS MaterialName,

		CASE ticketItem.UnitType WHEN 0 THEN MT.Unity
						 WHEN 1 THEN MT.Unit2
						 WHEN 2 THEN MT.Unit3 END			AS Unit,
		
		ticketItem.Qty						                AS Qty,
		ticketItem.SpecialOfferQty			                AS SpecialOfferQty,
		ticketItem.Price					                AS Price,
		CASE ticketItem.SpecialOfferQty WHEN 0 THEN 0 ELSE Disc.ValueToDiscount / ticketItem.SpecialOfferQty END  AS UnitDiscount,
		specialOffer.Discount								AS DiscountPercentage,
		Disc.ValueToDiscount								AS Discount,
		ticket.Net											AS SalesNet
	FROM 
		POSSDSpecialOffer000 specialOffer 
		INNER JOIN POSSDStationSpecialOffer000 StationSpecialOffer ON specialOffer.GUID  = StationSpecialOffer.SpecialOfferGUID
		INNER JOIN POSSDShift000 [shift] ON [shift].StationGUID = StationSpecialOffer.StationGUID
		INNER JOIN POSSDShiftDetail000 shiftDetails ON shiftDetails.ShiftGUID = [shift].GUID
		INNer JOIN POSSDTicket000 ticket ON Ticket.ShiftGUID = shiftDetails.ShiftGUID
		INNER JOIN POSSDTicketItem000 ticketItem ON ticketItem.TicketGUID = Ticket.GUID
		INNER JOIN POSSDStation000 station ON station.GUID = [shift].StationGUID 
		INNER JOIN mt000 MT ON ticketItem.MatGUID = MT.[GUID]
		INNER JOIN gr000 GR ON Gr.GUID = MT.GroupGUID
		LEFT JOIN POSSDSalesman000 salesman ON salesman.GUID = Ticket.SalesmanGUID
		LEFT JOIN CO000 costCneter ON costCneter.GUID = salesman.CostCenterGUID
		LEFT JOIN cu000 cu ON cu.guid = ticket.CustomerGUID
		LEFT JOIN POSSDEmployee000 employee ON employee.GUID =  shift.EmployeeGUID
		INNER JOIN @TicketItemsDiscouts Disc ON  Disc.TicketGuid = ticket.GUID 
   WHERE 
		(specialOffer.GUID = @SpecialOfferGuid OR @SpecialOfferGuid = 0x0) 
	AND ( 
			(StationSpecialOffer.StationGUID = @StationGuid OR @StationGuid = 0X0) 
			OR 
			([shift].StationGUID = @StationGuid OR @StationGuid = 0X0) 
		)
	AND (Mt.GUID = @MatGuid OR @MatGuid = 0x0)
	AND (GR.GUID = @GroupGuid OR @GroupGuid = 0x0 )
	AND (ticket.CustomerGUID =  @CustomerGuid OR @CustomerGuid = 0x0 )
	AND (Ticket.PaymentDate BETWEEN @StartDate AND @EndDate )
	AND (ticket.SalesmanGUID = @SalesmanGuid OR @SalesmanGuid = 0x0)
	AND (costCneter.GUID = @CostCenterGuid OR @CostCenterGuid = 0x0)
	AND	(shiftDetails.EmployeeGUID = @EmployeeGuid OR @EmployeeGuid = 0x0)
	AND Disc.Guid = ticketItem.GUID 
	
	
	DECLARE @SpecialOffersFooterResult Table
	(
		SpecialOfferType INT,
		SpecialOfferCounts FLOAT, 
		TotalDiscountsForSpecialOffer FLOAT
	)

	INSERT INTO @SpecialOffersFooterResult
	SELECT SpecialOfferType, 
			SUM(SpecialOfferType) as SpecialOfferCounts, 
			SUM(Discount) AS TotalDiscountsForSpecialOffer
	FROM @SpecialOfferDetails
	GROUP BY SpecialOfferType

	INSERT INTO @SpecialOffersFooterResult
	SELECT 8 AS SpecialOfferType, 
			SUM(SpecialOfferCounts) as SpecialOfferCounts, 
			SUM(TotalDiscountsForSpecialOffer) AS TotalDiscountsForSpecialOffer
	FROM @SpecialOffersFooterResult
	

	---------- RESULTS ----------
	SELECT * FROM @SpecialOfferDetails
	SELECT * FROM @SpecialOffersFooterResult
#################################################################
#END
