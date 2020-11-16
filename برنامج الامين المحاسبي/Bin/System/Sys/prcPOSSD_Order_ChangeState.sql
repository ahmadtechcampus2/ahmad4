################################################################################
CREATE PROCEDURE prcPOSSD_Order_ChangeState
-- Params ------------------------------------   
	@DriverGuid				UNIQUEIDENTIFIER,
	@TicketGuid				UNIQUEIDENTIFIER,
	@ShiftGuid			    UNIQUEIDENTIFIER,
	@UserGuid				UNIQUEIDENTIFIER,
	@ChangeStateType		INT, --1: Waiting -> Assigned, 2: Assigned -> Waiting, 3: Assigned -> InDelivery
	@NewTicketState         INT,
	@Event					INT,
	@ExternalOperationNote1 NVARCHAR(250),
	@ExternalOperationNote2 NVARCHAR(250)
----------------------------------------------
 -- RESULT:
 -- 1: success
 -- 2: driver minus account balance > allow minus value
 -- 3: Order state are changed from another station
 -- 4: The driver has order in Delivery
 -- 5: No order assigned to driver
 -- 6: Unknown error
 -- 7: Driver is not working
 -- 8: Driver has assgin order from unrelated station
----------------------------------------------
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @Result	TABLE (Result          INT, 
						  [Event]          INT, 
						  StationName	   NVARCHAR(100), 
						  StationLatinName NVARCHAR(100), 
						  TicketState      INT, 
						  DriverGuid	   UNIQUEIDENTIFIER, 
						  DriverName	   NVARCHAR(100), 
						  DriverLatinName  NVARCHAR(100))

	DECLARE @OrderGuid	              UNIQUEIDENTIFIER = (SELECT [GUID] FROM POSSDTicketOrderInfo000 WHERE TicketGUID = @TicketGuid)
	DECLARE @DriverReceiveAccountGUID UNIQUEIDENTIFIER = (SELECT ISNULL(ReceiveAccountGUID, 0x0) FROM POSSDDriver000 WHERE [GUID] = @DriverGuid)
	DECLARE @EventNumber              INT 
	DECLARE @OldState                 INT
	DECLARE @OldDriver                UNIQUEIDENTIFIER
	DECLARE @LastEvent		          INT
	DECLARE @StationName              NVARCHAR(100)
	DECLARE @StationLatinName         NVARCHAR(100)
	DECLARE @TripGUID		          UNIQUEIDENTIFIER
	DECLARE @TripNumber		          INT
	DECLARE @CurrentTicketState       INT
	DECLARE @CurrentDriverGuid        UNIQUEIDENTIFIER
	DECLARE @CurrentDriverName        NVARCHAR(100)
	DECLARE @CurrentDriverLatinName   NVARCHAR(100)
	

	---- check if driver has assgined order from unrelated station
	IF(((SELECT [dbo].fnPOSSD_Order_IsDriverHasAssginOrderFromUnrelatedStation(@DriverGuid, @ShiftGuid)) = 1) AND @ChangeStateType <> 2)
	BEGIN

		SELECT @CurrentDriverName = Name,
				@CurrentDriverLatinName = LatinName 
		FROM POSSDDriver000 
		WHERE [GUID] = @DriverGuid

		INSERT INTO @Result VALUES (8, -1, '','', 6, @DriverGuid, @CurrentDriverName, @CurrentDriverLatinName)
		SELECT * FROM @Result
		RETURN
	END
	


	IF(@ChangeStateType = 3)-- Assigned -> InDelivery
	BEGIN
		

		----check if driver has indelivery orders
		IF EXISTS( SELECT * 
				   FROM POSSDTicket000 T INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID
				   WHERE T.OrderType = 2 AND T.[State] = 7 AND OI.DriverGUID = @DriverGuid )
		BEGIN
			INSERT INTO @Result VALUES (4, -1, '','', 6, 0x0, '', '')
			SELECT * FROM @Result
			RETURN
		END


		DECLARE @OrdersToBeStartDelivery TABLE (OrderGUID UNIQUEIDENTIFIER, TicketGUID UNIQUEIDENTIFIER, EventNumber INT)
		INSERT INTO 
			@OrdersToBeStartDelivery
		SELECT 
			OI.[GUID], T.[GUID] , MAX(OE.Number) + 1
		FROM 
			POSSDTicket000 T 
			INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID
			INNER JOIN POSSDOrderEvent000 OE ON OE.OrderGUID = OI.[GUID]
		WHERE 
			T.OrderType = 2 AND T.[State] = 6 AND OI.DriverGUID = @DriverGuid
		GROUP BY 
			OI.[GUID], T.[GUID]

		----check driver has assigned orders
		IF NOT EXISTS( SELECT * FROM @OrdersToBeStartDelivery )
		BEGIN
			INSERT INTO @Result VALUES (5, -1, '','', 6, 0x0, '', '')
			SELECT * FROM @Result
			RETURN
		END


		SET @TripGUID = NEWID()
		SET @TripNumber = (SELECT COUNT(Number) FROM POSSDOrderTrip000 WHERE DriverGUID = @DriverGuid) + 1

		BEGIN TRANSACTION [Transaction]
			
			----Insert new trip
			INSERT INTO POSSDOrderTrip000([GUID], Number, DriverGUID, StartDate)
			VALUES(@TripGUID, @TripNumber, @DriverGuid, GETDATE())

			----Update tickets state
			UPDATE POSSDTicket000 SET [State] = @NewTicketState
			FROM   POSSDTicket000 T INNER JOIN @OrdersToBeStartDelivery O ON T.[GUID] = O.TicketGUID
		
			----Update orders Trip
			UPDATE POSSDTicketOrderInfo000 SET TripGUID = @TripGUID
			FROM   POSSDTicketOrderInfo000 OI INNER JOIN @OrdersToBeStartDelivery O ON OI.[GUID] = O.OrderGUID
		

			IF(@DriverReceiveAccountGUID <> 0x0)
			BEGIN
				
				DECLARE @Lang						INT
				DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER
				DECLARE @CustomerGUID	            UNIQUEIDENTIFIER
				DECLARE @CurrencyGUID	            UNIQUEIDENTIFIER
				DECLARE @ExternalOperationMaxNumber INT 
				DECLARE @ExternalOperationInfo		TABLE (TicketGUID UNIQUEIDENTIFIER, CustomerGUID UNIQUEIDENTIFIER, Amount FLOAT, Note NVARCHAR(250))

				SELECT @ShiftControlAccGUID = S.ShiftControlGUID FROM POSSDStation000 S INNER JOIN POSSDShift000 SH ON SH.StationGUID = S.[GUID] WHERE SH.[GUID] = @ShiftGuid
				SELECT @CustomerGUID = CustomerGUID FROM POSSDTicket000 WHERE [GUID] = @TicketGuid
				SELECT @CurrencyGUID = [GUID]  FROM my000 WHERE CurrencyVal = 1
				SELECT @ExternalOperationMaxNumber = ISNULL(MAX(Number), 0) FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGuid
				SET @Lang = (SELECT  PATINDEX(N'%[A-Za-z]%', LTRIM(@ExternalOperationNote1)))

				INSERT INTO @ExternalOperationInfo
				SELECT  SDO.TicketGUID, T.CustomerGUID ,T.Net AS Amount, CAST(T.Number AS NVARCHAR(250)) AS Note
				FROM @OrdersToBeStartDelivery SDO 
				INNER JOIN 	POSSDTicket000 T ON SDO.TicketGUID = T.[GUID]
				INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID


				----Insert collect orders value from driver external operations
				INSERT INTO POSSDExternalOperation000( [GUID],	
													   Number,
													   ShiftGUID,
													   DebitAccountGUID,
													   CreditAccountGUID,
													   Amount,
													   [Date],
													   Note,
													   [State],
													   IsPayment,
													   [Type],
													   GenerateState,
													   CurrencyGUID,
													   CurrencyValue,
													   CustomerGUID,
													   RelatedToGUID,
													   RelatedToType)
				SELECT	NEWID(), 
						@ExternalOperationMaxNumber + ROW_NUMBER() OVER (ORDER BY EXO.Note),
						@ShiftGuid, 
						@ShiftControlAccGUID, 
						@DriverReceiveAccountGUID, 
						EXO.Amount, 
						GETDATE(), 
						@ExternalOperationNote1 + ' ' +  EXO.Note + ' ' + @ExternalOperationNote2 + 
						ISNULL(CASE @Lang WHEN 0 THEN CU.CustomerName 
							  ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName
													ELSE CU.LatinName END END, ''), 
						0, 
						0, 
						9, 
						3, 
						@CurrencyGUID, 
						1, 
						0x0, -- Customer Guid
						OI.[GUID],
						2
				FROM @ExternalOperationInfo EXO
				INNER JOIN POSSDTicketOrderInfo000 OI on EXO.TicketGUID = OI.TicketGUID
				LEFT JOIN cu000 CU ON EXO.CustomerGUID = CU.[GUID]


				----Collect orders value from driver event
				MERGE POSSDOrderEvent000	   AS [TARGET]
				USING @OrdersToBeStartDelivery AS [SOURCE]
				ON [TARGET].OrderGUID = [SOURCE].OrderGUID
				AND [TARGET].Number = [SOURCE].EventNumber
				WHEN NOT MATCHED THEN
				INSERT ([GUID], Number, OrderGUID, ShiftGUID, DriverGUID, UserGUID, [Date], [Event], Reason)			
				VALUES(NEWID(), [SOURCE].EventNumber, [SOURCE].OrderGUID, @ShiftGuid, @DriverGuid, @UserGuid, GETDATE(), 12, '');

			END

			----Insert start delivery event
			MERGE POSSDOrderEvent000	   AS [TARGET]
			USING @OrdersToBeStartDelivery AS [SOURCE]
			ON [TARGET].OrderGUID = [SOURCE].OrderGUID
			AND (([TARGET].Number = [SOURCE].EventNumber + 1 AND @DriverReceiveAccountGUID <> 0x0) 
			OR   ([TARGET].Number = [SOURCE].EventNumber AND @DriverReceiveAccountGUID = 0x0))
			WHEN NOT MATCHED THEN
			INSERT ([GUID], Number, OrderGUID, ShiftGUID, DriverGUID, UserGUID, [Date], [Event], Reason)			
			VALUES (NEWID(), 
				   (CASE @DriverReceiveAccountGUID WHEN 0x0 THEN [SOURCE].EventNumber ELSE [SOURCE].EventNumber + 1 END), 
				   [SOURCE].OrderGUID, 
				   @ShiftGuid, 
				   @DriverGuid, 
				   @UserGuid, 
				   GETDATE(), 
				   @Event, 
				   '');

		COMMIT TRANSACTION [Transaction];

		IF (@@TRANCOUNT != 0)
		BEGIN
			ROLLBACK TRANSACTION [Transaction]; 

			INSERT INTO @Result VALUES (6, -1, '','', 6, @DriverGuid, '', '')
			SELECT * FROM @Result
			RETURN
		END

		INSERT INTO @Result VALUES (1, -1, '','', 7, @DriverGuid, '', '')
		SELECT * FROM @Result
		RETURN

	END



	SELECT 
		@OldState  = T.[State],
		@OldDriver = OI.DriverGUID
	FROM 
		POSSDTicket000 T 
		INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID 
	WHERE 
		T.[GUID] = @TicketGuid


	IF(@ChangeStateType = 1)-- Waiting -> Assigned
	BEGIN

		----check if driver has indelivery orders
		IF EXISTS( SELECT * 
				   FROM POSSDTicket000 T INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID
				   WHERE T.OrderType = 2 AND T.[State] = 7 AND OI.DriverGUID = @DriverGuid )
		BEGIN
			INSERT INTO @Result VALUES (4, -1, '','', 5, 0x0, '', '')
			SELECT * FROM @Result
			RETURN
		END
		
		----Check if the driver are working
		IF((SELECT IsWorking FROM POSSDDriver000 WHERE [GUID] = @DriverGuid) = 0)
		BEGIN 
			INSERT INTO @Result VALUES (7, -1, '','', 5, @DriverGuid, '', '')
			SELECT * FROM @Result
			RETURN
		END

		----Check if Order state changed from another station
		IF(@OldState <> 5 OR @OldDriver <> 0x0)
		BEGIN	

			SELECT TOP 1 
				 @LastEvent = OE.[Event],
				 @StationName = S.Name,
				 @StationLatinName = S.LatinName,
				 @CurrentTicketState = T.[State],
				 @CurrentDriverGuid = ISNULL(D.[GUID], 0x0),
				 @CurrentDriverName = ISNULL(D.Name, ''),
				 @CurrentDriverLatinName = ISNULL(D.LatinName, '')
	
			FROM 
				POSSDOrderEvent000 OE 
				INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
				INNER JOIN POSSDTicket000 T  ON OI.TicketGUID  = T.[GUID]
				INNER JOIN POSSDShift000 SH  ON OE.ShiftGUID   = SH.[GUID]
				INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
				LEFT JOIN  POSSDDriver000 D  ON OE.DriverGUID  = D.[GUID]
			WHERE 
				OE.OrderGUID = @OrderGuid
			ORDER BY 
				OE.Number DESC


			INSERT INTO @Result VALUES (3, @LastEvent, @StationName, @StationLatinName, @CurrentTicketState, @CurrentDriverGuid, @CurrentDriverName, @CurrentDriverLatinName)
			SELECT * FROM @Result
			RETURN
		END

		----Check driver minus account balance
		IF(((SELECT MinusLimitValue FROM POSSDDriver000 WHERE [GUID] = @DriverGuid) <> 0) AND ((SELECT [dbo].fnPOSSD_Driver_CheckMinusAccountBalance(@DriverGuid)) <> 1))
		BEGIN
			INSERT INTO @Result VALUES (2, -1, '','', 5, @DriverGuid, '', '')
			SELECT * FROM @Result
			RETURN
		END

	END

	IF(@ChangeStateType = 2)-- Assigned -> Waiting
	BEGIN

		----Check if Order state changed from another station
		IF(@OldState <> 6 OR @OldDriver = 0x0)
		BEGIN	
			SELECT TOP 1 
				 @LastEvent = OE.[Event],
				 @StationName = S.Name,
				 @StationLatinName = S.LatinName,
				 @CurrentTicketState = T.[State],
				 @CurrentDriverGuid = ISNULL(D.[GUID], 0x0),
				 @CurrentDriverName = ISNULL(D.Name, ''),
				 @CurrentDriverLatinName = ISNULL(D.LatinName, '')
	
			FROM 
				POSSDOrderEvent000 OE 
				INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
				INNER JOIN POSSDTicket000 T  ON OI.TicketGUID  = T.[GUID]
				INNER JOIN POSSDShift000 SH  ON OE.ShiftGUID   = SH.[GUID]
				INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
				LEFT JOIN  POSSDDriver000 D  ON OE.DriverGUID  = D.[GUID]
			WHERE 
				OE.OrderGUID = @OrderGuid
			ORDER BY 
				OE.Number DESC


			INSERT INTO @Result VALUES (3, @LastEvent, @StationName, @StationLatinName, @CurrentTicketState, @CurrentDriverGuid, @CurrentDriverName, @CurrentDriverLatinName)
			SELECT * FROM @Result
			RETURN
		END

	END


	SET @EventNumber = (SELECT MAX(Number) FROM POSSDOrderEvent000 WHERE OrderGUID = @OrderGuid) + 1

	BEGIN TRANSACTION [Transaction]

		----Update ticket state
		UPDATE POSSDTicket000 SET [State] = @NewTicketState WHERE [GUID] = @TicketGuid

		----Update order driver 
		UPDATE POSSDTicketOrderInfo000 SET DriverGUID = @DriverGuid WHERE TicketGUID = @TicketGuid

		----Insert event
		INSERT INTO POSSDOrderEvent000 ([GUID], Number, OrderGUID, ShiftGUID, DriverGUID, UserGUID, [Date], [Event], Reason)
		VALUES(NEWID(), @EventNumber, @OrderGuid, @ShiftGuid, @DriverGuid, @UserGuid, GETDATE(), @Event, '')

	COMMIT TRANSACTION [Transaction];

	IF (@@TRANCOUNT != 0)
	BEGIN
		ROLLBACK TRANSACTION [Transaction]; 

		INSERT INTO @Result VALUES (6, -1, '','', 6, @DriverGuid, '', '')
		SELECT * FROM @Result
		RETURN
	END

	INSERT INTO @Result VALUES (1, -1, '','', @NewTicketState, @DriverGuid, '', '')
	SELECT * FROM @Result
	RETURN
#################################################################
CREATE FUNCTION fnPOSSD_Order_IsDriverHasAssginOrderFromUnrelatedStation
	  (@DriverGUID UNIQUEIDENTIFIER,
	   @ShiftGUID  UNIQUEIDENTIFIER)
       RETURNS BIT
AS BEGIN

	DECLARE @UnrelatedStationCount INT
	DECLARE @CurrentStationGUID UNIQUEIDENTIFIER = (SELECT S.[GUID]
											        FROM POSSDShift000 SH 
												    INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
												    WHERE SH.[GUID] =  @ShiftGUID)


	SELECT @UnrelatedStationCount = COUNT(*)
	FROM 
		POSSDTicketOrderInfo000 OI 
		INNER JOIN POSSDTicket000 T  ON OI.TicketGUID  = T.[GUID]
		INNER JOIN POSSDShift000 SH  ON T.ShiftGUID    = SH.[GUID]
		INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
		LEFT  JOIN POSSDStationOrderAssociatedStations000 OAS ON OAS.AssociatedStationGUID = S.[GUID] AND OAS.StationGUID = @CurrentStationGUID
	WHERE 
		DriverGUID = @DriverGUID
		AND T.[State] IN (5, 6, 7)
		AND S.[GUID] <> @CurrentStationGUID
		AND OAS.StationGUID IS NULL


	IF(@UnrelatedStationCount > 0)
	BEGIN 
		RETURN 1
	END

    RETURN 0
END
#################################################################
#END
