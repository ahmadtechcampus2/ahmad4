################################################################################
CREATE PROCEDURE prcPOSSD_Order_GenerateDownPaymentExternalOperations
-- Params ------------------------------------   
	@TicketGuid	UNIQUEIDENTIFIER,
	@Note		NVARCHAR(250)
	AS
    SET NOCOUNT ON
---------------------------------------------------------------------------------------
	DECLARE @Result						INT				 = 0
	DECLARE @OrderGuid					UNIQUEIDENTIFIER = (SELECT [GUID] FROM POSSDTicketOrderInfo000 WHERE TicketGUID = @TicketGuid)
---------------------------------------------------------------------------
	DECLARE @IsDownPaymentAvailable		BIT				 = (SELECT 
																CASE
																	WHEN DownPayment = 0 THEN 0
																	WHEN DownPayment > 0 THEN 1 																																
																END 																				 
															FROM POSSDTicketOrderInfo000 OI
															WHERE OI.[GUID] = @OrderGuid)
	DECLARE @IsGetDownPaymentEventExist BIT				 =  CASE 
														 	 	WHEN EXISTS (SELECT * FROM POSSDOrderEvent000 
														 	 				 WHERE OrderGUID = @OrderGuid AND [Event] = 2) THEN 1
														 	 	ELSE 0
														    END
																															
	DECLARE @State						INT				 =  CASE 
																--NO CAHNGE
														 	 	WHEN @IsDownPaymentAvailable = 0 AND @IsGetDownPaymentEventExist = 0 THEN 0 
																--INSERT DownPayment event on POSSDOrderEvent000 And new ExternalOperation POSSDExternalOperation
														 	 	WHEN @IsDownPaymentAvailable = 1 AND @IsGetDownPaymentEventExist = 0 THEN 1
																--DELETE DownPayment event on POSSDOrderEvent000 And its ExternalOperation from POSSDExternalOperation 
																WHEN @IsDownPaymentAvailable = 0 AND @IsGetDownPaymentEventExist = 1 THEN 2
																--UPDATE POSSDExternalOperation With new DownPayment value  
																WHEN @IsDownPaymentAvailable = 1 AND @IsGetDownPaymentEventExist = 1 THEN 3
														    END
------------------------------------------------------------------------------	
	IF @State = 0
	BEGIN		
		SELECT @Result
		RETURN 
	END
	DECLARE @ShiftGuid					UNIQUEIDENTIFIER 
	DECLARE @EmployeeGUID				UNIQUEIDENTIFIER				
	
	SELECT  @ShiftGuid    = [ShiftGuid], 
		    @EmployeeGUID = [UserGUID]
	FROM POSSDOrderEvent000 
	WHERE 
		OrderGUID = @OrderGuid AND [Event] = 1
-------------------------------------------------------------------------------											 
	IF @State = 1 
	BEGIN	
		BEGIN TRANSACTION [Transaction]
		DECLARE @ShiftControlAccGUID        UNIQUEIDENTIFIER = (SELECT S.ShiftControlGUID 
																FROM POSSDStation000 S 
																INNER JOIN POSSDShift000 SH ON SH.StationGUID = S.[GUID] 
																WHERE SH.[GUID] = @ShiftGuid)

		DECLARE @DownPaymentAccountGUID     UNIQUEIDENTIFIER = (SELECT DownPaymentAccountGUID 
																FROM POSSDStationOrder000 SO 
																INNER JOIN POSSDShift000 SH ON SH.StationGUID = SO.StationGUID 
																WHERE SH.[GUID] = @ShiftGuid)	 

		DECLARE @CurrencyGUID	            UNIQUEIDENTIFIER = (SELECT [GUID]  FROM my000 WHERE CurrencyVal = 1)

	-----------------------------------------------------------------------------		
		DECLARE @ExternalOperationNumber    INT				 = (SELECT ISNULL(MAX(Number), 0) FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGuid) + 1
		DECLARE @EventNumber				INT				 = (SELECT ISNULL(MAX(Number), 0) FROM POSSDOrderEvent000 WHERE OrderGUID = @OrderGuid) + 1
	-----------------------------------------------------------------------------
		INSERT INTO 
			POSSDExternalOperation000( [GUID],	
									   Number,
									   ShiftGUID,
									   DebitAccountGUID,
									   CreditAccountGUID,
									   CustomerGUID,
									   Amount,
									   [Date],
									   Note,
									   [State],
									   IsPayment,
									   [Type],
									   GenerateState,
									   CurrencyGUID,
									   CurrencyValue,
									   DeviceID,
									   RelatedToGUID,
									   RelatedToType)
		SELECT	NEWID(), 
				@ExternalOperationNumber,
				@ShiftGuid, 
				@ShiftControlAccGUID, 
				@DownPaymentAccountGUID,
				T.CustomerGUID, 
				OI.DownPayment, 
				GETDATE(), 
				@Note,			
				0, --ExternalOperationState : Addeed
				0, 
				7,-- ExternalOperationType : OrderDownpayment 
				3,-- ExternalOperationGenerateState : OrderDownpayment, 
				@CurrencyGUID, 
				1, 
				T.DeviceID,
				OI.[GUID],
				2 --ExternalOperationsRelatedToType : Order,
		FROM POSSDTicket000 T
		INNER JOIN POSSDTicketOrderInfo000 OI on T.GUID = OI.TicketGUID
		WHERE T.GUID = @TicketGuid

		INSERT INTO POSSDOrderEvent000 ([GUID], Number, OrderGUID, ShiftGUID, DriverGUID, UserGUID, [Date], [Event], Reason)
		SELECT NEWID(), 
			   @EventNumber,
			   @OrderGuid,
			   @ShiftGuid,
			   DriverGUID,
			   @EmployeeGUID,
			   GETDATE(),
			   2, ---OrderEventType : GetDownPayment 
			   ''
		FROM POSSDTicketOrderInfo000 
		WHERE [GUID] = @OrderGuid
		
		COMMIT TRANSACTION [Transaction];

		IF (@@TRANCOUNT != 0)
		BEGIN
			 ROLLBACK TRANSACTION [Transaction]; 
			 SET @Result = 0
			 SELECT @Result
			 RETURN
		END

		SET @Result = 1
		SELECT @Result
		RETURN 
	END
-------------------------------------------------------------------------------	
	DECLARE @ExternalOperationInfo	TABLE (Number INT , IsDownPaymentChanged BIT, DownPayment FLOAT, ExternalOperationGUID UNIQUEIDENTIFIER)
	
	INSERT INTO @ExternalOperationInfo(Number, IsDownPaymentChanged, DownPayment, ExternalOperationGUID )
	SELECT
		EXO.Number		AS Number,
		CASE 
			WHEN OI.DownPayment <> EXO.Amount THEN 1
			ELSE 0
		END				AS IsDownPaymentChanged,
		OI.DownPayment 	AS DownPayment,									 
		EXO.GUID		AS ExternalOperationGUID					 
	FROM POSSDTicketOrderInfo000 OI
	INNER JOIN  POSSDExternalOperation000  EXO ON EXO.RelatedToGUID = OI.GUID
	WHERE
		EXO.GenerateState = 3
		AND OI.[GUID]	  = @OrderGuid 
		AND ShiftGUID	  = @ShiftGuid 		  
		AND EXO.[Type]	  = 7 
		AND IsPayment	  = 0
-------------------------------------------------------------------------------
	IF @State = 2 
	BEGIN

		BEGIN TRANSACTION [Transaction]

		DECLARE @DeletedExternalOperationNumber INT = (SELECT Number FROM @ExternalOperationInfo) 		
		DELETE POSSDExternalOperation000 
		WHERE [GUID] = (SELECT ExternalOperationGUID FROM @ExternalOperationInfo)

		UPDATE POSSDExternalOperation000
		SET Number = Number - 1
		WHERE ShiftGUID = @ShiftGuid AND @DeletedExternalOperationNumber < Number

		DELETE POSSDOrderEvent000 
		WHERE OrderGUID = @OrderGuid AND [Event] = 2

		UPDATE POSSDOrderEvent000
		SET Number = Number - 1
		WHERE OrderGUID = @OrderGuid AND [Event] <> 1
		
		COMMIT TRANSACTION [Transaction];

		IF (@@TRANCOUNT != 0)
		BEGIN
			 ROLLBACK TRANSACTION [Transaction]; 
			 SET @Result = 0
			 SELECT @Result
			 RETURN
		END

		SET @Result = 2
		SELECT @Result
		RETURN 
	END
-------------------------------------------------------------------------------	
	IF @State = 3
	BEGIN
		IF EXISTS(SELECT * FROM @ExternalOperationInfo WHERE IsDownPaymentChanged = 0)
		BEGIN			
			SET @Result = 0
			SELECT @Result
			RETURN
		END

		DECLARE @DeviceID NVARCHAR(300) = (SELECT DeviceID FROM POSSDTicket000 WHERE [GUID] = @TicketGuid)

		MERGE POSSDExternalOperation000	    AS [TARGET]
		USING @ExternalOperationInfo		AS [SOURCE]
		ON [TARGET].[GUID] = [SOURCE].ExternalOperationGUID
		WHEN MATCHED THEN
			UPDATE
			SET [TARGET].Amount   = [SOURCE].DownPayment,
				[TARGET].DeviceID = @DeviceID;
		
		SET @Result = 3
		SELECT @Result
		RETURN 
	END																			 	
#################################################################
#END
