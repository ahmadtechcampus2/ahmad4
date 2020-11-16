#################################################################
CREATE PROCEDURE prcPOSSD_Shift_OpenShift
@deviceID NVARCHAR(Max),
@posGuid UNIQUEIDENTIFIER,
@currentUserGuid UNIQUEIDENTIFIER,
@note NVARCHAR(Max) = '',
@externalOperationNote  NVARCHAR(Max) = ''
AS
BEGIN
	--ÝÊÍ ÌáÓÉ ÌÏíÏÉ
DECLARE
       @shiftNumber INT,
       @ShiftGUID  UNIQUEIDENTIFIER,
       @shiftControlGuid UNIQUEIDENTIFIER,
       @floatAccountGuid  UNIQUEIDENTIFIER,
       @externalOperationNumber INT ,
       @posCode NVARCHAR(50),
       @shiftCode NVARCHAR(50),
       @lastShiftGUID UNIQUEIDENTIFIER,
       @result INT = 5,
	   @currencyGUID UNIQUEIDENTIFIER,
	   @defaultCurrency UNIQUEIDENTIFIER,
	   @ContinuesCash FLOAT,
	   @ContinuesCashCurVal FLOAT
DECLARE @MaxCloseDate DATETIME = (SELECT MAX(CloseDate) From POSSDShift000 WHERE StationGUID = @posGuid)
 IF (@MaxCloseDate > GETDATE())	
 BEGIN
   SET @result = 5 
   RETURN 
 END
  SET @lastShiftGUID= (SELECT [GUID] From POSSDShift000 ps WHERE StationGUID = @posGuid 
	                   AND CloseDate = @MaxCloseDate)
  SET @shiftControlGuid = (SELECT ShiftControlGUID FROm POSSDStation000 WHERE Guid = @posGuid)
  SET @ShiftGUID = NEWID()
  SET @shiftNumber = (SELECT ISNULL(MAX(Number), 0) from POSSDShift000 sh Where StationGUID = @posGuid)
  SET @posCode = (SELECT Code FROM POSSDStation000 WHERE Guid = @posGuid)
  SET @shiftCode = @posCode + cast((@shiftNumber+1) as varchar)
 
  BEGIN TRANSACTION
         INSERT INTO POSSDShift000 (Number, [GUID], StationGUID,Code,CloseShiftNote,EmployeeGUID, OpenDate,CloseDate, OpenShiftNote, OpenDateUTC)
                                 VALUES(@shiftNumber+1, @ShiftGUID, @posGuid, @shiftCode, '', @currentUserGuid,GETDATE(), null, @note, GETUTCDATE())
  
         INSERT INTO POSSDShiftdetail000
                Values(NEWID(), @ShiftGUID,  @currentUserGuid ,@deviceID, GETDATE())
 
    DECLARE curr_cursor CURSOR FOR  
    SELECT CurrencyGUID,
	       FloatCash,
	       FloatCashCurVal
	FROM POSSDShiftCashCurrency000 
	WHERE ShiftGUID =  @lastShiftGUID
	OPEN curr_cursor   
	FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal
    WHILE @@FETCH_STATUS = 0   
	  BEGIN
	  SET @defaultCurrency = (SELECT [dbo].[fnGetDefaultCurr]())
			IF (@defaultCurrency = @currencyGUID)
			BEGIN
				SET @floatAccountGuid  = (SELECT ContinuesCashGUID FROM POSSDStation000 WHERE Guid = @posGuid);
			END
			ELSE
			BEGIN
				SET @floatAccountGuid = (SELECT FloatCachAccGUID FROM POSSDStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)
				IF (@floatAccountGuid IS NULL OR @floatAccountGuid = 0X0)
					SET @floatAccountGuid = (SELECT FloatCachAccGUID FROM POSSDExtendStationCurrency000 RC WHERE StationGUID = @posGuid AND CurrencyGUID = @currencyGUID)
			END
	    IF (@ContinuesCash > 0)
		BEGIN
		   INSERT INTO POSSDShiftCashCurrency000([GUID], ShiftGUID, CurrencyGUID, OpeningCash, OpeningCashCurVal)
		    VALUES (NEWID(), @ShiftGUID, @currencyGUID, @ContinuesCash, @ContinuesCashCurVal)
		   
		   SELECT @externalOperationNumber = MAX(Number)  FROM POSSDExternalOperation000 WHERE ShiftGUID = @ShiftGUID 
		   INSERT INTO POSSDExternalOperation000 ([GUID], 
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
											  	  CurrencyValue)
              VALUES(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @ShiftGUID, @shiftControlGuid, @floatAccountGuid, 0x0, @ContinuesCash, GETDATE(),@externalOperationNote, 0, 0, 0, 0, @currencyGUID, @ContinuesCashCurVal) 
		END
		FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal
	END
	CLOSE curr_cursor   
	DEALLOCATE curr_cursor
  COMMIT
  IF EXISTS (SELECT * FROM POSSDShift000 WHERE Code = @shiftCode)
    SET  @result = 4
      
  SELECT @result
END
#################################################################
#END 