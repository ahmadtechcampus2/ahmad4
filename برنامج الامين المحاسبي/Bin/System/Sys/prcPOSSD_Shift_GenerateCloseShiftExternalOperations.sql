#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GenerateCloseShiftExternalOperations
	@posGuid UNIQUEIDENTIFIER,
	@shiftGuid UNIQUEIDENTIFIER,
	@ExternalOperationCloseShiftNote NVARCHAR(265),
	@centralBoxReceiptNoNote NVARCHAR(256),
	@deviceID NVARCHAR(250)	
AS
BEGIN
    --توليد العمليات الخارجية عند إقفال الجلسة 
	DECLARE 
		@ShiftControlAccountGuid UNIQUEIDENTIFIER =(SELECT ShiftControlGUID FROM POSSDStation000 WHERE GUID = @posGuid),
		@FloatCashAccountGuid UNIQUEIDENTIFIER ,
		@employeeGuid UNIQUEIDENTIFIER= (SELECT EmployeeGUID FROM POSSDShift000 WHERE [GUID] = @shiftGuid),
		@employeeMinusAccountGuid UNIQUEIDENTIFIER,
		@employeeExtraAccountGuid UNIQUEIDENTIFIER,
		@centralBoxAccount UNIQUEIDENTIFIER,
		@shiftCach FLOAT,
		@shortage FLOAT,
		@externalOperationNumber INT,
		@currencyGUID UNIQUEIDENTIFIER,
		@defaultCurrency UNIQUEIDENTIFIER,
		@ContinuesCash FLOAT,
		@ContinuesCashCurVal FLOAT,
		@CountedCash  FLOAT,
		@withDrawnCash FLOAT,
		@centralBoxReceiptId nvarchar(100)
    SELECT @employeeMinusAccountGuid = MinusAccountGUID FROM POSSDEmployee000 WHERE Guid = @employeeGuid
    SELECT @employeeExtraAccountGuid = ExtraAccountGUID FROM POSSDEmployee000 WHERE Guid = @employeeGuid
    
	DECLARE @Note NVARCHAR(250)

	DECLARE curr_cursor CURSOR FOR  
    SELECT CurrencyGUID,
	       FloatCash,
	       FloatCashCurVal, 
	       CountedCash,
		   CentralBoxReceiptId 
	FROM POSSDShiftCashCurrency000 
	WHERE ShiftGUID =  @shiftGuid
	OPEN curr_cursor   
	FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal, @CountedCash, @centralBoxReceiptId
    WHILE @@FETCH_STATUS = 0   
	  BEGIN
	        SET @shiftCach = (SELECT [dbo].fnPOSSD_Shift_GetShiftCash(@shiftGuid, @currencyGUID, default))
			SET @shortage = @CountedCash - @shiftCach
			SET @withDrawnCash = @CountedCash - @ContinuesCash
			SET @defaultCurrency = (SELECT [dbo].[fnGetDefaultCurr]())
			
			IF (@defaultCurrency = @currencyGUID)
			BEGIN
				SET @centralBoxAccount  = (SELECT CentralAccGUID FROM POSSDStation000 WHERE [GUID] = @posGuid);
				SET @FloatCashAccountGuid  = (SELECT ContinuesCashGUID FROM POSSDStation000 WHERE [GUID] = @posGuid);
			END
			ELSE
			BEGIN
				SET @centralBoxAccount = (SELECT CentralBoxAccGUID FROM POSSDStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)
				SET @FloatCashAccountGuid = (SELECT FloatCachAccGUID FROM POSSDStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)

				IF(@centralBoxAccount IS NULL OR @centralBoxAccount = 0x0)
					SET @centralBoxAccount = (SELECT CentralBoxAccGUID FROM POSSDExtendStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)

				IF(@FloatCashAccountGuid IS NULL OR @FloatCashAccountGuid = 0x0)
					SET @FloatCashAccountGuid = (SELECT FloatCachAccGUID FROM POSSDExtendStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)
			END
						

			IF (@shortage < 0)
			BEGIN
				SELECT @externalOperationNumber = MAX(Number) FROM POSSDExternalOperation000 WHERE ShiftGUID = @shiftGuid 
				INSERT INTO POSSDExternalOperation000( [GUID], 
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
													   DeviceID) Values(NEWID(), ISNULL(@externalOperationNumber,0)+1, @shiftGuid, @employeeMinusAccountGuid, @ShiftControlAccountGuid, 0x0, ABS(@shortage), GETDATE(), @ExternalOperationCloseShiftNote, 0, 1, 6, 1, @CurrencyGUID, @ContinuesCashCurVal, @deviceID)
			END
  
			ELSE IF (@shortage > 0) 
			BEGIN
				SELECT @externalOperationNumber = MAX(Number)  FROM POSSDExternalOperation000 WHERE ShiftGUID = @shiftGuid 
				INSERT INTO POSSDExternalOperation000( [GUID], 
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
											  	       CurrencyValue ) Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @ShiftControlAccountGuid, @employeeExtraAccountGuid, 0x0, ABS(@shortage), GETDATE(), @ExternalOperationCloseShiftNote, 0, 0, 6, 1, @currencyGUID, @ContinuesCashCurVal)
			END
       
			IF (@withDrawnCash > 0)
			BEGIN
				SET @Note = @ExternalOperationCloseShiftNote + CASE WHEN LEN(@centralBoxReceiptId) > 0 THEN @centralBoxReceiptNoNote + @centralBoxReceiptId ELSE '' END
				SELECT @externalOperationNumber = MAX(ISNULL(Number, 0))  FROM POSSDExternalOperation000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSSDExternalOperation000 ( [GUID], 
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
											  	        CurrencyValue )Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @centralBoxAccount, @ShiftControlAccountGuid, 0x0, ABS(@withDrawnCash), GETDATE(), @Note, 0, 1, 3, 1, @currencyGUID, @ContinuesCashCurVal)
			END       
			IF (@ContinuesCash > 0)
			BEGIN
				SELECT @externalOperationNumber = MAX(ISNULL(Number, 0))  FROM POSSDExternalOperation000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSSDExternalOperation000 ( [GUID], 
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
											  		    CurrencyValue )Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @FloatCashAccountGuid, @ShiftControlAccountGuid, 0x0, ABS(@ContinuesCash), GETDATE(), @ExternalOperationCloseShiftNote, 0, 1, 0, 1, @currencyGUID, @ContinuesCashCurVal)
			END
	
		FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal, @CountedCash, @centralBoxReceiptId
	END
	CLOSE curr_cursor   
	DEALLOCATE curr_cursor
END
#################################################################
#END 