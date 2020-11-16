################################################################################
CREATE PROCEDURE  repPOSSD_SepecialOffers
-- Params -------------------------------   
	@SpecialOfferGuid      UNIQUEIDENTIFIER,
	@MatGuid			   UNIQUEIDENTIFIER,
	@GroupGuid             UNIQUEIDENTIFIER,
	@CustomerGuid          UNIQUEIDENTIFIER,
	@StationGuid           UNIQUEIDENTIFIER,
	@EmployeeGuid          UNIQUEIDENTIFIER,
	@SalesmanGuid          UNIQUEIDENTIFIER,
	@CostCenterGuid        UNIQUEIDENTIFIER,
	@ShiftGuid			   UNIQUEIDENTIFIER,	
	@ShowDiscountOffer	   BIT,
	@ShowBOGOOffer		   BIT,
	@ShowSlidesOffer       BIT,
	@ShowBOGSEOffer        BIT,
	@ShowBundleOffer       BIT,
	@ShowSXGDOffer         BIT,
	@ShowSGPOffer          BIT,
	@StartDate			   DATETIME,
	@EndDate			   DATETIME
AS
   SET NOCOUNT ON
------------------------------------------------------------------------
       
       DECLARE @Lang INT = [dbo].[fnConnections_getLanguage]()
       DECLARE @TicketGUID UNIQUEIDENTIFIER
       
       
       DECLARE @SpecialOfferDetails TABLE ( SpecialOfferGUID            UNIQUEIDENTIFIER,
											SpecialOfferType            INT,
											CustomerGUID                UNIQUEIDENTIFIER,
											StationGUID                 UNIQUEIDENTIFIER,
											EmployeeGUID                UNIQUEIDENTIFIER,
											TicketGUID                  UNIQUEIDENTIFIER,
											TicketType					INT,
											TicketDate                  DATE,
											TicketTime                  NVARCHAR(20),
											ShiftCode                   NVARCHAR(250),
											TicketCode                  NVARCHAR(250),
											MaterialGUID                UNIQUEIDENTIFIER,
											Qty                         FLOAT,
											SpecialOfferQty             FLOAT,
											Price                       FLOAT,
											Discount                    FLOAT,
											SpecialOfferName            NVARCHAR(250),
											CustomerName                NVARCHAR(250),
											StationName                 NVARCHAR(250),
											EmployeeName                NVARCHAR(250),
											SalesmanName                NVARCHAR(250),
											CostCenterName              NVARCHAR(250),
											MaterialName                NVARCHAR(250),
											DiscountPercentage          FLOAT,
											UnitDiscount                FLOAT,
											Unit                        NVARCHAR(250),
											NumberOfSpecialOfferApplied INT,
											SpecialOfferGrantQty		INT)

       DECLARE @TicketItemsDiscouts TABLE ( [Guid]                      UNIQUEIDENTIFIER,
                                            TicketGuid                  UNIQUEIDENTIFIER,
                                            ValueToDiscount             FLOAT,
                                            ValueToAdd                  FLOAT ,
                                            ValueAfterCalc              FLOAT,
                                            ItemShareOfTotalDiscount    FLOAT,
                                            ItemShareOfTotalAddition    FLOAT )
       
	   DECLARE @SpecialOffersFooterResult TABLE ( TotalSpecialOfferType         INT,
												  SpecialOfferCounts            FLOAT, 
												  TotalDiscountsForSpecialOffer FLOAT )

	  DECLARE @SpecialOffersAppliedCount TABLE ( SpecialOfferGuid	UNIQUEIDENTIFIER,
												 TotalDiscount      FLOAT,
												 SpecialOfferType	INT,
											     AppliedCount		INT)

	  DECLARE @TempShiftDetails TABLE ( ShiftGUID	UNIQUEIDENTIFIER,
									    EmployeeGUID	UNIQUEIDENTIFIER)
            
       
       DECLARE @ItemDiscountCursor CURSOR
       SET @ItemDiscountCursor = CURSOR FAST_FORWARD FOR  
       SELECT [GUID] FROM POSSDTicket000 
       OPEN @ItemDiscountCursor 
       FETCH FROM @ItemDiscountCursor INTO @TicketGUID

			WHILE @@FETCH_STATUS = 0
			BEGIN
				INSERT INTO @TicketItemsDiscouts
				SELECT * FROM  dbo.fnPOSSD_Ticket_GetDiscountAndAddition(@TicketGUID)
				FETCH NEXT FROM @ItemDiscountCursor  INTO @TicketGUID
			END 

       CLOSE @ItemDiscountCursor
       DEALLOCATE @ItemDiscountCursor

	   INSERT INTO @TempShiftDetails
       SELECT 
			shiftDetails.ShiftGUID			AS ShiftGUID,
			shiftDetails.EmployeeGUID		AS EmployeeGUID

		FROM 
            POSSDSpecialOffer000 specialOffer 
            INNER JOIN POSSDStationSpecialOffer000 StationSpecialOffer ON specialOffer.[GUID] = StationSpecialOffer.SpecialOfferGUID
            INNER JOIN POSSDShift000 [shift] ON [shift].StationGUID = StationSpecialOffer.StationGUID
            INNER JOIN POSSDShiftDetail000 shiftDetails ON shiftDetails.ShiftGUID = [shift].[GUID]
			GROUP BY shiftDetails.ShiftGUID ,shiftDetails.EmployeeGUID
	   --============================================================= Fill Special Offers Details Table
       INSERT INTO @SpecialOfferDetails
       SELECT 
			specialOffer.[GUID]					   AS SpecialOfferGUID,
            specialOffer.[Type]					   AS SpecialOfferType,
			ticket.CustomerGUID					   AS CustomerGUID,
			[shift].StationGUID					   AS StationGUID,
			shiftDetails.EmployeeGUID			   AS EmployeeGUID,
			ticket.[GUID]						   AS TicketGUID,
			ticket.[Type]						   AS TicketType,
			ticket.PaymentDate					   AS TicketDate,
			FORMAT(ticket.PaymentDate, 'hh:mm tt') AS TicketTime,
			[shift].Code						   AS ShiftCode,
			ticket.Code							   AS TicketCode,
			Mt.[GUID]							   AS MaterialGUID,
			ticketItem.Qty						   AS Qty,
			ticketItem.SpecialOfferQty			   AS SpecialOfferQty,
			ticketItem.Price					   AS Price,
			Disc.ValueToDiscount				   AS Discount,

            CASE @Lang WHEN 0 THEN specialOffer.Name ELSE CASE specialOffer.LatinName WHEN '' THEN specialOffer.Name ELSE specialOffer.LatinName END END           AS SpecialOfferName,
            CASE @Lang WHEN 0 THEN cu.CustomerName ELSE CASE cu.LatinName WHEN '' THEN cu.CustomerName ELSE cu.LatinName END END						           AS CustomerName,
            CASE @Lang WHEN 0 THEN station.Name ELSE CASE station.LatinName WHEN '' THEN station.Name ELSE station.LatinName END END					           AS StationName,
            CASE @Lang WHEN 0 THEN employee.Name ELSE CASE employee.LatinName WHEN '' THEN employee.Name ELSE employee.LatinName END END				           AS EmployeeName,
            CASE @Lang WHEN 0 THEN salesman.Name ELSE CASE salesman.LatinName WHEN '' THEN salesman.Name  ELSE salesman.LatinName END END                          AS SalesmanName,
            CASE @Lang WHEN 0 THEN costCenter.Name ELSE CASE costCenter.LatinName WHEN '' THEN costCenter.Name  ELSE costCenter.LatinName END END                  AS CostCenterName,
            CASE WHEN specialOffer.[Type] = 7 THEN '' ELSE  CASE @Lang WHEN 0 THEN MT.Name ELSE CASE MT.LatinName WHEN '' THEN MT.Name ELSE MT.LatinName END END END AS MaterialName,

            ( ((CASE ticketItem.IsDiscountPercentage WHEN 0 THEN ISNULL(ticketItem.DiscountValue, 0)
													 ELSE ISNULL(ticketItem.DiscountValue, 0) * (CASE ticketItem.SpecialOfferGUID WHEN 0x0 THEN (ticketItem.Value - (ticketItem.PresentQty * (ticketItem.Value/ticketItem.Qty)))
																																  ELSE (ticketItem.Price * ticketItem.SpecialOfferQty - (ticketItem.PresentQty * (ticketItem.Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty))) END) / 100 END) 
			+ (PresentQty * (CASE ticketItem.SpecialOfferGUID WHEN 0x0 THEN (ticketItem.Value/ticketItem.Qty)
                                                              ELSE (ticketItem.Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty) END))) / (ticketItem.Price * ticketItem.Qty ))  AS DiscountPercentage,

			CASE ticketItem.SpecialOfferQty WHEN 0 THEN 0 
											ELSE Disc.ValueToDiscount / ticketItem.SpecialOfferQty END AS UnitDiscount,
              
			CASE ticketItem.UnitType WHEN 0 THEN MT.Unity  
							         WHEN 1 THEN MT.Unit2 
									 WHEN 2 THEN MT.Unit3  END AS Unit,    

			ticketItem.NumberOfSpecialOfferApplied AS  NumberOfSpecialOfferApplied,
			specialOffer.GrantQty AS  SpecialOfferGrantQty

		FROM 
            POSSDSpecialOffer000 specialOffer 
            INNER JOIN POSSDStationSpecialOffer000 StationSpecialOffer ON specialOffer.[GUID] = StationSpecialOffer.SpecialOfferGUID
            INNER JOIN POSSDShift000 [shift] ON [shift].StationGUID = StationSpecialOffer.StationGUID
            INNER JOIN @TempShiftDetails shiftDetails ON shiftDetails.ShiftGUID = [shift].[GUID]
            INNer JOIN POSSDTicket000 ticket ON Ticket.ShiftGUID = shiftDetails.ShiftGUID
            INNER JOIN POSSDTicketItem000 ticketItem ON ticketItem.TicketGUID = Ticket.[GUID]
            INNER JOIN POSSDStation000 station ON station.[GUID] = [shift].StationGUID 
            INNER JOIN mt000 MT ON ticketItem.MatGUID = MT.[GUID]
            INNER JOIN gr000 GR ON Gr.[GUID] = MT.GroupGUID
            LEFT  JOIN POSSDSalesman000 salesman ON salesman.[GUID] = Ticket.SalesmanGUID
            LEFT  JOIN CO000 costCenter ON costCenter.[GUID] = salesman.CostCenterGUID
            LEFT  JOIN cu000 cu ON cu.[GUID] = ticket.CustomerGUID
            LEFT  JOIN POSSDEmployee000 employee ON employee.[GUID] =  [shift].EmployeeGUID
            INNER JOIN @TicketItemsDiscouts Disc ON  Disc.TicketGuid = ticket.[GUID] 

		WHERE 
			Ticket.[State] IN (0, 5, 6, 7) 
	   AND (specialOffer.[GUID] = @SpecialOfferGuid OR @SpecialOfferGuid = 0x0) 
       AND ((StationSpecialOffer.StationGUID = @StationGuid OR @StationGuid = 0X0) OR  ([shift].StationGUID = @StationGuid OR @StationGuid = 0X0))
	   AND ([shift].[GUID] = @ShiftGuid OR @ShiftGuid = 0x0)
       AND (Mt.[GUID] = @MatGuid OR @MatGuid = 0x0)
       AND (GR.[GUID] = @GroupGuid OR @GroupGuid = 0x0 )
       AND (ticket.CustomerGUID =  @CustomerGuid OR @CustomerGuid = 0x0 )
       AND ((Ticket.PaymentDate BETWEEN @StartDate AND @EndDate) 
		 OR (Ticket.[State] IN (5, 6, 7) AND Ticket.OpenDate BETWEEN @StartDate AND @EndDate) )
       AND (ticket.SalesmanGUID = @SalesmanGuid OR @SalesmanGuid = 0x0)
       AND (costCenter.[GUID] = @CostCenterGuid OR @CostCenterGuid = 0x0)
       AND (shiftDetails.EmployeeGUID = @EmployeeGuid OR @EmployeeGuid = 0x0)
       AND (Disc.[GUID] = ticketItem.[GUID]) 
       AND (specialOffer.[Type] = 1 AND @ShowDiscountOffer = 1 
         OR specialOffer.[Type] = 2 AND @ShowBOGOOffer	   = 1 
         OR specialOffer.[Type] = 3 AND @ShowSlidesOffer   = 1 
         OR specialOffer.[Type] = 4 AND @ShowBOGSEOffer    = 1 
         OR specialOffer.[Type] = 5 AND @ShowBundleOffer   = 1 
         OR specialOffer.[Type] = 7 AND @ShowSGPOffer      = 1)
       AND (ticket.SpecialOfferGUID = specialOffer.[GUID] OR ticketItem.SpecialOfferGUID = specialOffer.[GUID])

	   --=============================================================عرض أنفق وخذ حسما 
       INSERT INTO @SpecialOfferDetails
       SELECT
           specialOffer.[GUID]					  AS SpecialOfferGUID,
           specialOffer.[Type]					  AS SpecialOfferType,
		   ticket.CustomerGUID					  AS CustomerGUID,
		   [shift].StationGUID					  AS StationGUID, 
		   [shiftDetails].EmployeeGUID			  AS EmployeeGUID,
		   ticket.[GUID]						  AS TicketGUID,
		   ticket.[Type]						  AS TicketType,
		   ticket.PaymentDate					  AS TicketDate,
		   FORMAT(ticket.PaymentDate, 'hh:mm tt') AS TicketTime,
		   [shift].Code							  AS ShiftCode,
           ticket.Code							  AS TicketCode,
		   0x0									  AS MaterialGUID, 
		   0									  AS Qty,
		   0									  AS SpecialOfferQty,
		   0									  AS Price,
		   SUM(Disc.ItemShareOfTotalDiscount)     AS Discount,

           CASE @Lang WHEN 0 THEN specialOffer.Name ELSE CASE specialOffer.LatinName WHEN '' THEN specialOffer.Name ELSE specialOffer.LatinName END END AS SpecialOfferName,
           CASE @Lang WHEN 0 THEN cu.CustomerName ELSE CASE cu.LatinName WHEN '' THEN cu.CustomerName ELSE cu.LatinName END END                         AS CustomerName,
           CASE @Lang WHEN 0 THEN station.Name ELSE CASE station.LatinName WHEN '' THEN station.Name ELSE station.LatinName END END                     AS StationName, 
           CASE @Lang WHEN 0 THEN employee.Name ELSE CASE employee.LatinName WHEN '' THEN employee.Name ELSE employee.LatinName END END					AS EmployeeName,
           CASE @Lang WHEN 0 THEN salesman.Name ELSE CASE salesman.LatinName WHEN '' THEN salesman.Name ELSE salesman.LatinName END END                 AS SalesmanName,
           CASE @Lang WHEN 0 THEN costCenter.Name ELSE CASE costCenter.LatinName WHEN '' THEN costCenter.Name ELSE costCenter.LatinName END END         AS CostCenterName,
           ''  AS MaterialName,

		   CASE WHEN ticket.IsDiscountPercentage = 1 THEN IsNULL(ticket.DiscValue, 0) / 100 
				ELSE CASE (SUM(ticketItem.Value  + ticketItem.AdditionValue - CASE ticketItem.IsDiscountPercentage WHEN 1 THEN (ticketItem.Value/ticketItem.Qty)*ticketItem.DiscountValue 
																												   ELSE  ticketItem.DiscountValue END) + ticket.AddedValue) WHEN 0 THEN 0 
																																											ELSE IsNULL(ticket.DiscValue, 0) / (SUM(ticketItem.Value  + ticketItem.AdditionValue - CASE ticketItem.IsDiscountPercentage WHEN 1 THEN (ticketItem.Value)*ticketItem.DiscountValue / 100  
																																																																										ELSE ticketItem.DiscountValue END) + ticket.AddedValue) END  END  AS DiscountPercentage,

			0   AS UnitDiscount,
            ''  AS Unit,
          
			FLOOR(CASE specialOffer.IsAppliedOnValueMultiplies WHEN 1 THEN ((SELECT SUM (ticketItem.Value  + ticketItem.AdditionValue - CASE ticketItem.IsDiscountPercentage WHEN 1 THEN (ticketItem.Value)*ticketItem.DiscountValue / 100  
																																													ELSE  ticketItem.DiscountValue END) + (CASE ticket.IsAdditionPercentage WHEN 1 THEN SUM(ticketItem.Value + ticketItem.AdditionValue) * ticket.AddedValue / 100 
																																																																    ELSE ticket.AddedValue END )) /specialOffer.OfferSpentAmount)
															          ELSE 1 END)  AS  NumberOfSpecialOfferApplied,
			-1 AS  SpecialOfferGrantQty

		FROM 
            POSSDSpecialOffer000 specialOffer 
            INNER JOIN POSSDStationSpecialOffer000 StationSpecialOffer ON specialOffer.[GUID]  = StationSpecialOffer.SpecialOfferGUID
            INNER JOIN POSSDShift000 [shift] ON [shift].StationGUID = StationSpecialOffer.StationGUID
            INNER JOIN @TempShiftDetails shiftDetails ON shiftDetails.ShiftGUID = [shift].[GUID]
            INNer JOIN POSSDTicket000 ticket ON Ticket.ShiftGUID = shiftDetails.ShiftGUID
            INNER JOIN POSSDTicketItem000 ticketItem ON ticketItem.TicketGUID = Ticket.[GUID]
            INNER JOIN POSSDStation000 station ON station.[GUID] = [shift].StationGUID 
            INNER JOIN mt000 MT ON ticketItem.MatGUID = MT.[GUID]
            INNER JOIN gr000 GR ON Gr.[GUID] = MT.GroupGUID
            LEFT  JOIN POSSDSalesman000 salesman ON salesman.[GUID] = Ticket.SalesmanGUID
            LEFT  JOIN CO000 costCenter ON costCenter.[GUID] = salesman.CostCenterGUID
            LEFT  JOIN cu000 cu ON cu.[GUID] = ticket.CustomerGUID
            LEFT  JOIN POSSDEmployee000 employee ON employee.[GUID] =  [shift].EmployeeGUID
            INNER JOIN @TicketItemsDiscouts Disc ON  Disc.TicketGuid = ticket.[GUID] 

		WHERE 
			Ticket.[State] = 0 
	   AND (specialOffer.[GUID] = @SpecialOfferGuid OR @SpecialOfferGuid = 0x0) 
       AND ((StationSpecialOffer.StationGUID = @StationGuid OR @StationGuid = 0X0) 
         OR ([shift].StationGUID = @StationGuid OR @StationGuid = 0X0))
       AND ([shift].[GUID] = @ShiftGuid OR @ShiftGuid = 0x0)
       AND (Mt.[GUID] = @MatGuid OR @MatGuid = 0x0)
       AND (GR.[GUID] = @GroupGuid OR @GroupGuid = 0x0 )
       AND (ticket.CustomerGUID =  @CustomerGuid OR @CustomerGuid = 0x0 )
       AND (Ticket.PaymentDate BETWEEN @StartDate AND @EndDate )
       AND (ticket.SalesmanGUID = @SalesmanGuid OR @SalesmanGuid = 0x0)
       AND (costCenter.[GUID] = @CostCenterGuid OR @CostCenterGuid = 0x0)
       AND (shiftDetails.EmployeeGUID = @EmployeeGuid OR @EmployeeGuid = 0x0)
       AND Disc.[GUID] = ticketItem.[GUID] 
       AND specialOffer.[Type] = 6 AND @ShowSXGDOffer = 1 
       AND (ticket.SpecialOfferGUID = specialOffer.[GUID] OR ticketItem.SpecialOfferGUID = specialOffer.[GUID])

       GROUP BY 
		   ticket.[GUID], specialOffer.[GUID], specialOffer.[Type], TICKET.CustomerGUID, [SHIFT].StationGUID, shiftDetails.EmployeeGUID, salesman.[GUID], [SHIFT].[GUID],
           ticket.PaymentDate, ticket.Net, specialOffer.Discount, specialOffer.Name, specialOffer.LatinName, Ticket.Code, [shift].Code, employee.Name, employee.LatinName,
           cu.CustomerName, cu.LatinName, station.Name, station.LatinName, costCenter.Name, costCenter.LatinName, salesman.Name,salesman.LatinName, ticket.AddedValue, ticket.DiscValue, ticket.IsDiscountPercentage,
           specialOffer.IsAppliedOnValueMultiplies, specialOffer.OfferSpentAmount, ticket.IsAdditionPercentage, ticket.[Type]

       
 
	   ------------------ Prepare Totals
	   INSERT INTO @SpecialOffersAppliedCount
	   SELECT SpecialOfferGuid, SUM(Discount), SpecialOfferType, 0 
	   FROM @SpecialOfferDetails 
	   WHERE  SpecialOfferType  IN (1, 2, 3, 5, 4) 
	   GROUP BY SpecialOfferGuid, SpecialOfferType
	   UPDATE @SpecialOffersAppliedCount SET AppliedCount = (SELECT dbo.fnPOSSD_SpecialOffer_GetNumberApplied(SpecialOfferGuid))
		
	   

	    SELECT 
			SpecialOfferGuid													  AS SpecialOfferGuid,
			SpecialOfferType													  AS SpecialOfferType, 
			NumberOfspecialOfferApplied											  AS NumberOfspecialOfferApplied,
            Discount															  AS Discount,
			SpecialOfferQty														  AS SpecialOfferQty,
			SpecialOfferGrantQty												  AS SpecialOfferGrantQty,
			ROW_NUMBER() OVER (PARTITION BY TicketGUID ORDER BY SpecialOfferType) AS SpecialOfferRank
	   INTO #SpecialOffersFooterTemp
       FROM @SpecialOfferDetails
	   WHERE SpecialOfferType NOT IN  (1, 2, 3, 5, 4)

	  
		UPDATE #SpecialOffersFooterTemp
		SET NumberOfspecialOfferApplied = 0 
		WHERE 
			SpecialOfferType = 7 
		AND SpecialOfferRank > 1

	   --====================== Fill Footer Table
	   --=============== Add Special offers Types Totals

	   --======== insert BOGO, bundel, BOGSE, Discount, Slides Types
	   INSERT INTO @SpecialOffersFooterResult
	   SELECT SpecialOfferType, 
			  SUM(AppliedCount), 
			  SUM(TotalDiscount) 
	   FROM @SpecialOffersAppliedCount 
	   GROUP BY SpecialOfferType
	   
	   --======== insert Other Types
       INSERT INTO @SpecialOffersFooterResult
       SELECT SpecialOfferType,
			  SUM(NumberOfspecialOfferApplied),
              SUM(Discount)
        FROM #SpecialOffersFooterTemp
	    GROUP BY SPecialOfferType, SpecialOfferGrantQty


	   --=============== insert total of totals
       INSERT INTO @SpecialOffersFooterResult
       SELECT 
			8								   AS TotalSpecialOfferType, 
			SUM(SpecialOfferCounts)            AS SpecialOfferCounts, 
			SUM(TotalDiscountsForSpecialOffer) AS TotalDiscountsForSpecialOffer
        FROM 
			@SpecialOffersFooterResult
       

       --------------- RESULTS ---------------
       SELECT * FROM @SpecialOfferDetails
       ORDER BY  SpecialOfferType, SpecialOfferName
       
       SELECT * FROM @SpecialOffersFooterResult
################################################################
#END
