#################################################################
CREATE PROCEDURE prcPOSOpenShift
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
       @shiftGuid  UNIQUEIDENTIFIER,
       @shiftControlGuid UNIQUEIDENTIFIER,
       @floatAccountGuid  UNIQUEIDENTIFIER,
       @externalOperationNumber INT ,
       @posCode NVARCHAR(50),
       @shiftCode NVARCHAR(50),
       @lastShiftGuid UNIQUEIDENTIFIER,
       @result INT = 5,
	   @currencyGUID UNIQUEIDENTIFIER,
	   @defaultCurrency UNIQUEIDENTIFIER,
	   @ContinuesCash FLOAT,
	   @ContinuesCashCurVal FLOAT
  SET @lastShiftGuid= (SELECT Guid From POSShift000 ps WHERE POSGuid = @posGuid 
	                   AND CloseDate = (SELECT MAX(CloseDate) From POSShift000 ps WHERE POSGuid = @posGuid))

  SET @shiftControlGuid = (SELECT ShiftControl FROm POSCard000 WHERE Guid = @posGuid)
  SET @shiftGuid = NEWID()
  SET @shiftNumber = (SELECT ISNULL(MAX(Number), 0) from POSshift000 sh Where POSGuid = @posGuid)
  SET @posCode = (SELECT Code FROM POSCard000 WHERE Guid = @posGuid)
  SET @shiftCode = @posCode + cast((@shiftNumber+1) as varchar)
 
  BEGIN TRANSACTION
         INSERT INTO POSshift000 (Number, [Guid], POSGuid,Code,CloseShiftNote,EmployeeId, OpenDate,CloseDate, OpenShiftNote)
                                 VALUES(@shiftNumber+1, @shiftGuid, @posGuid, @shiftCode, '', @currentUserGuid,GETDATE(), null, @note)
  
         INSERT INTO POSshiftdetails000
                Values(NEWID(), @shiftGuid,  @currentUserGuid ,@deviceID, GETDATE())
 
    DECLARE curr_cursor CURSOR FOR  
    SELECT CurrencyGUID,
	       ContinuesCash,
	       ContinuesCashCurVal
	FROM POSSDShiftCashCurrency000 
	WHERE ShiftGUID =  @lastShiftGuid

	OPEN curr_cursor   
	FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal
    WHILE @@FETCH_STATUS = 0   
	  BEGIN
	  SET @defaultCurrency = (SELECT [dbo].[fnGetDefaultCurr]())
			IF (@defaultCurrency = @currencyGUID)
			BEGIN
				SET @floatAccountGuid  = (SELECT ContinuesCash FROM POSCard000 WHERE Guid = @posGuid);
			END
			ELSE
			BEGIN
				SET @floatAccountGuid = (SELECT FloatCachAccGUID FROM POSSDRelatedCurrencies000 RC WHERE POSGUID = @posGuid AND CurGUID = @currencyGUID)
			END
	    IF (@ContinuesCash > 0)
		BEGIN
		   INSERT INTO POSSDShiftCashCurrency000([GUID], ShiftGUID, CurrencyGUID, OpeningCash, OpeningCashCurVal)
		    VALUES (NEWID(), @shiftGuid, @currencyGUID, @ContinuesCash, @ContinuesCashCurVal)
		   
		   SELECT @externalOperationNumber = MAX(Number)  FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid 

		   INSERT INTO PosExternalOperations000 VALUES
                (NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @shiftControlGuid, @floatAccountGuid, @ContinuesCash, GETDATE(),@externalOperationNote, 0, 0, 0, 0, @currencyGUID, @ContinuesCashCurVal) 
		END
		FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal
	END
	CLOSE curr_cursor   
	DEALLOCATE curr_cursor
  COMMIT
  IF EXISTS (SELECT * FROM POSshift000 WHERE Code = @shiftCode)
    SET  @result = 4
      
  SELECT @result
END
#################################################################
CREATE PROCEDURE prcPosUnCloseShift 
-- Params -------------------------------
	@ShiftGUID UNIQUEIDENTIFIER
-----------------------------------------   
AS
	DECLARE @UserGUID UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @UserGUID
	
	EXEC prcConnections_SetIgnoreWarnings 1

	BEGIN TRANSACTION 
	
	UPDATE 
		POSShift000 
	SET 
		CloseDate = NULL, 
		CloseShiftNote = NULL
	WHERE 
		Guid = @ShiftGUID
	
	UPDATE POSSDShiftCashCurrency000 
	SET 
		ContinuesCash = 0, 
		ContinuesCashCurVal = 0, 
		CountedCash = 0 
	WHERE 
		ShiftGUID = @ShiftGUID
	
	DELETE FROM POSExternalOperations000 
	WHERE 
		ShiftGuid = @ShiftGUID 
		AND 
		GenerateState = 1
	
	DECLARE @posGuid UNIQUEIDENTIFIER = (SELECT TOP 1 POSGuid FROM POSShift000 WHERE Guid = @ShiftGUID)
	DECLARE @dataTransferMode     INT = (SELECT DataTransferMode FROM POSCard000 WHERE Guid = @posGuid)

	IF (@dataTransferMode = 1) --on offline mode
	BEGIN
		DELETE 
			ticketItems
		FROM 
			[dbo].[POSTicketItem000] ticketItems
			INNER JOIN [dbo].[POSTicket000] tickets ON tickets.Guid = ticketItems.TicketGuid
		WHERE 
			ShiftGuid = @shiftGuid

		DELETE [dbo].[POSTicket000] WHERE [ShiftGuid] = @shiftGuid
		DELETE [dbo].[POSExternalOperations000] WHERE [ShiftGuid] = @shiftGuid
	END
	
	DECLARE @BillGUID [UNIQUEIDENTIFIER]
	SET @BillGUID = ISNULL((SELECT TOP 1 BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGuid), 0x0)
	
	WHILE @BillGUID != 0x0
	BEGIN 
		EXEC prcBill_Delete @BillGUID
		EXEC prcBill_Delete_Entry @BillGUID
		
		DELETE FROM BillRel000 WHERE BillGUID = @BillGUID

		SET  @BillGUID = ISNULL((SELECT TOP 1 BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGuid), 0x0)
	END 
	
	DELETE FROM er000 WHERE ParentGuid = @ShiftGuid 
	
	EXEC prcConnections_SetIgnoreWarnings 0	

	COMMIT TRAN

#################################################################
CREATE FUNCTION fnPOSSDCanUncloseShift
(
	 @ShiftGuid		          UNIQUEIDENTIFIER
)
RETURNS INT
AS
BEGIN
	DECLARE @Result								 INT = 0
	DECLARE @SaleBillTypeGeneratedFromCloseShift UNIQUEIDENTIFIER
	DECLARE @POSCardSaleBillType				 UNIQUEIDENTIFIER

	SELECT @SaleBillTypeGeneratedFromCloseShift = BU.TypeGUID
	FROM BillRel000 BR  
	INNER JOIN bu000 BU ON BU.[GUID] = BR.BillGUID
	WHERE BR.ParentGUID = @ShiftGuid

	SELECT @POSCardSaleBillType = C.SaleBillType 
	FROM POSShift000 S 
	INNER JOIN POSCard000 C ON S.[POSGuid] = C.[GUID]
	WHERE S.[GUID] = @ShiftGuid

	IF(@SaleBillTypeGeneratedFromCloseShift <> @POSCardSaleBillType)
	BEGIN
		SET @Result = 1
	END

	RETURN @Result
END
#################################################################
CREATE FUNCTION fnPOSSDCheckBillTypesIsMatched
(
	 @CurrentPOSGuid		UNIQUEIDENTIFIER,
	 @CurrentSaleBillType   UNIQUEIDENTIFIER
)
RETURNS INT
AS
BEGIN
	DECLARE @Result				INT = 0
	DECLARE @SaleBillType		UNIQUEIDENTIFIER

	SELECT @SaleBillType = SaleBillType 
	FROM POSCard000
	WHERE [GUID] = @CurrentPOSGuid

	IF(@CurrentSaleBillType <> @SaleBillType)
	BEGIN
		SET @Result = 1
	END

	RETURN @Result
END
#################################################################
CREATE FUNCTION IsThereOpenedShifts(@employeeId AS uniqueidentifier, @deviceId AS nvarchar(255))
       RETURNS INT
AS BEGIN
       DECLARE       @Result							[INT]
       DECLARE       @anyShiftWithSameUserSameDevice	[INT]
       DECLARE       @anyShiftWithSameUserAnotherDevice [INT]
       DECLARE       @anyShiftWithSameDeviceAnotherUser [INT]
	   DECLARE		 @UserIsWorking						[INT]

	   SELECT @UserIsWorking = IsWorking
	   FROM POSEmployee000
	   WHERE [Guid] = @employeeId

	   IF(@UserIsWorking = 0)
	   BEGIN
		  SET    @Result = 6;
		  RETURN @Result;
	   END
      
       SELECT @anyShiftWithSameUserSameDevice = COUNT(*)
       FROM POSshift000 POSShift
       INNER JOIN  POSShiftDetails000 POSShiftDetails
       ON POSShift.Guid = POSShiftDetails.ShiftGuid
       WHERE
              POSShift.CloseDate is NULL
              AND POSShiftDetails.DeviceID = @deviceId
              AND POSShiftDetails.POSUser = @employeeId
              AND POSShiftDetails.EntryDate >= (SELECT MAX(EntryDate) FROM POSShiftDetails000 POSDetails WHERE POSDetails.POSUser = @employeeId)
      
       SELECT @anyShiftWithSameUserAnotherDevice=COUNT(*)
       FROM POSshift000 POSShift
       INNER JOIN  POSShiftDetails000 POSShiftDetails
       ON POSShift.Guid = POSShiftDetails.ShiftGuid
       WHERE
              POSShift.CloseDate is NULL
              AND POSShiftDetails.DeviceID != @deviceId
              AND POSShiftDetails.POSUser = @employeeId
              AND POSShiftDetails.EntryDate >= (SELECT MAX(EntryDate) FROM POSShiftDetails000 POSDetails WHERE POSDetails.POSUser = @employeeId)
 
       SET @Result = 0;
 
       IF @anyShiftWithSameUserSameDevice > 0
              SET @Result = 1
      
       ELSE IF @anyShiftWithSameUserAnotherDevice > 0
              SET @Result = 2
      
       RETURN @Result
END
################################################################################
CREATE PROCEDURE GetPosChildrenAccounts
@parentAccount uniqueidentifier
AS
BEGIN
	SELECT DISTINCT 
			AC.Name  AS AccountName,
			AC.LatinName  AS  AccountLatinName,
			AC.GUID AS AccountGuid,
			customers.GUID AS CustomerGuid, 
			customers.Number AS CustomerNumber,  
			customers.CustomerName AS CustomerName, 
			customers.LatinName AS CustomerLatinName, 
			
			customers.NSEMail1 AS EMail, 
			customers.NSMobile1 AS Phone1, 
			customers.NSMobile2 AS Phone2,
			@parentAccount AS ParentGuid
	FROM 
			dbo.fnGetAccountsList(@parentAccount, 0) accountList
			INNER JOIN ac000 AC ON AC.GUID = accountList.GUID
			LEFT JOIN cu000 customers	ON customers.AccountGUID = accountList.GUID
	WHERE 
			AC.NSons = 0
	
END
################################################################################
CREATE Procedure prcPOSGetRelatedEmployees
@posGuid UNIQUEIDENTIFIER
AS
BEGIN
	SELECT PE.* FROM POSEmployee000 PE INNER JOIN POSRelatedEmployees000 PR ON PE.Guid = PR.EmployeeGuid
	WHERE POSGuid = @posGuid
	AND PE.IsWorking = 1
END
################################################################################
CREATE PROCEDURE prcPOSGetPosAccounts
@posGuid uniqueidentifier
AS
BEGIN
       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSCard000 PC ON AC.GUID = PC.ContinuesCash
       WHERE PC.Guid = @posGuid

       UNION ALL

       SELECT 
                     AC.Name  AS AccountName,
                     AC.LatinName  AS  AccountLatinName,
                     AC.GUID AS AccountGuid
       FROM 
                     ac000 AC INNER JOIN POSEmployee000 PE ON AC.GUID = PE.MinusAccount OR AC.GUID = PE.ExtraAccount
                     INNER JOIN POSRelatedEmployees000 PR ON PR.EmployeeGuid = PE.Guid AND PR.POSGuid = @posGuid
       
END
#################################################################
create PROCEDURE prcPOSInsertShiftDetails
 @ShiftGuid UNIQUEIDENTIFIER,
@DeviceID NVARCHAR(Max),
@CurrentUserGuid UNIQUEIDENTIFIER
AS
BEGIN
INSERT INTO POSshiftdetails000 Values(NEWID(), @ShiftGuid,  @CurrentUserGuid ,@DeviceID, GETDATE())
END
#################################################################
CREATE PROCEDURE prcPosGetCurrentShift
@posGuid UNIQUEIDENTIFIER,
@currentUserGuid UNIQUEIDENTIFIER
AS
BEGIN
 SELECT ps.*,
        e.Name AS EmployeeName,
        e.LatinName AS EmployeeLatineName
 FROM POSShift000 ps 
 INNER JOIN POSEmployee000 e ON ps.EmployeeId = e.Guid
 WHERE ps.POSGuid = @posGuid AND ps.EmployeeId = @currentUserGuid 
 AND (ps.CloseDate is NULL
 OR (ps.CloseDate is NOT NULL 
 AND ps.CloseDate = (SELECT MAX(CloseDate) 
								FROM POSShift000 ps1
								WHERE ps1.POSGuid = @posGuid 
								AND ps1.EmployeeId = @currentUserGuid
								AND not exists (SELECT 1 FROM POSShift000 ps2 WHERE  ps2.POSGuid = @posGuid 
								AND ps2.EmployeeId = @currentUserGuid AND Ps2.CloseDate is null)))) 
END
#################################################################
CREATE FUNCTION GetPosShiftCash (@shiftGuid AS uniqueidentifier, @currency AS uniqueidentifier = 0x00, @isEquivalent AS BIT = 0)
RETURNS FLOAT
AS 
BEGIN
	DECLARE	@externalPaymentAmount [FLOAT]
	DECLARE	@externalRecievedAmount [FLOAT]
	DECLARE	@TicketRecievedAmount [FLOAT]
	DECLARE	@TicketPaymentAmount [FLOAT]
    DECLARE	@TotalTicketAmount [FLOAT]
	DECLARE	@currencyVal [FLOAT] = 1
	DECLARE	@result [FLOAT]
   
	SELECT @TicketRecievedAmount =	CASE @isEquivalent WHEN 0 THEN  SUM(tc.Value) ELSE SUM(tc.Value * tc.CurrencyVal) END
									FROM POSSDTicketCurrency000 tc
									INNER JOIN POSTicket000 pt ON tc.TicketGUID = pt.GUID									
									WHERE pt.ShiftGuid = @shiftGuid AND [State] = 0
									AND ([Type] = 0 OR [Type] = 3) -- Sales or Returned Purchase
									AND (tc.CurrencyGUID = @currency OR @currency = 0x0)
									AND (tc.PayType = 1 OR tc.PayType = 3) -- cash or currencies 
	
	SELECT @TicketPaymentAmount =	CASE @isEquivalent WHEN 0 THEN  SUM(tc.Value) ELSE SUM(tc.Value * tc.CurrencyVal) END
									FROM POSSDTicketCurrency000 tc
									INNER JOIN POSTicket000 pt ON tc.TicketGUID = pt.GUID									
									WHERE pt.ShiftGuid = @shiftGuid AND [State] = 0
									AND ([Type] = 1 OR [Type] = 2) -- Purchase or Returned Sales
									AND (tc.CurrencyGUID = @currency OR @currency = 0x0)
									AND (tc.PayType = 1 OR tc.PayType = 3) -- cash or currencies 
	
	SET @TotalTicketAmount = ISNULL(@TicketRecievedAmount, 0) - ISNULL(@TicketPaymentAmount, 0)
	
	SELECT @externalPaymentAmount = CASE @isEquivalent WHEN 0 THEN  SUM(Amount) ELSE SUM(Amount * CurrencyValue) END
									FROM PosExternalOperations000  WHERE ShiftGuid = @shiftGuid AND IsPayment =1
									AND [State] = 0 AND GenerateState <> 1 AND CurrencyGUID = @currency OR @currency = 0x0
   
	SELECT @externalRecievedAmount = CASE @isEquivalent WHEN 0 THEN  SUM(Amount) ELSE SUM(Amount * CurrencyValue) END
									 FROM PosExternalOperations000  WHERE ShiftGuid = @shiftGuid 
									 AND IsPayment = 0 AND [State] = 0 AND GenerateState <> 1 AND CurrencyGUID = @currency OR @currency = 0x0
   
	SET @result = ISNULL (@TotalTicketAmount,0) + ISNULL(@externalRecievedAmount,0) - ISNULL(@externalPaymentAmount,0)
   
	return @result
END
#################################################################
CREATE PROCEDURE prcPOSGenerateCloseShiftExternalOperations
	@posGuid UNIQUEIDENTIFIER,
	@shiftGuid UNIQUEIDENTIFIER,
	@ExternalOperationCloseShiftNote NVARCHAR(265)
AS
BEGIN
    --توليد العمليات الخارجية عند إقفال الجلسة 
	DECLARE 
		@ShiftControlAccountGuid UNIQUEIDENTIFIER =(SELECT ShiftControl FROM POSCard000 WHERE Guid = @posGuid),
		@FloatCashAccountGuid UNIQUEIDENTIFIER ,
		@employeeGuid UNIQUEIDENTIFIER= (SELECT EmployeeId FROM POSShift000 WHERE Guid = @shiftGuid),
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
		@withDrawnCash FLOAT

    SELECT @employeeMinusAccountGuid = MinusAccount FROM POSEmployee000 WHERE Guid = @employeeGuid
    SELECT @employeeExtraAccountGuid = ExtraAccount FROM POSEmployee000 WHERE Guid = @employeeGuid
    
	DECLARE curr_cursor CURSOR FOR  
    SELECT CurrencyGUID,
	       ContinuesCash,
	       ContinuesCashCurVal, 
	       CountedCash 
	FROM POSSDShiftCashCurrency000 
	WHERE ShiftGUID =  @shiftGuid

	OPEN curr_cursor   
	FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal, @CountedCash

    WHILE @@FETCH_STATUS = 0   
	  BEGIN
	        SET @shiftCach = (SELECT [dbo].GetPosShiftCash(@shiftGuid, @currencyGUID, default))
			SET @shortage = @CountedCash - @shiftCach
			SET @withDrawnCash = @CountedCash - @ContinuesCash
			SET @defaultCurrency = (SELECT [dbo].[fnGetDefaultCurr]())
			
			IF (@defaultCurrency = @currencyGUID)
			BEGIN
				SET @centralBoxAccount  = (SELECT CentralAccGUID FROM POSCard000 WHERE Guid = @posGuid);
				SET @FloatCashAccountGuid  = (SELECT ContinuesCash FROM POSCard000 WHERE Guid = @posGuid);
			END
			ELSE
			BEGIN
				SET @centralBoxAccount = (SELECT CentralBoxAccGUID FROM POSSDRelatedCurrencies000 RC WHERE POSGUID = @posGuid AND CurGUID = @currencyGUID)
				SET @FloatCashAccountGuid = (SELECT FloatCachAccGUID FROM POSSDRelatedCurrencies000 RC WHERE POSGUID = @posGuid AND CurGUID = @currencyGUID)
			END

			IF (@shortage < 0)
			BEGIN
				SELECT @externalOperationNumber = MAX(Number) FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSExternalOperations000 Values(NEWID(), ISNULL(@externalOperationNumber,0)+1, @shiftGuid, @employeeMinusAccountGuid, @ShiftControlAccountGuid, ABS(@shortage), GETDATE(), @ExternalOperationCloseShiftNote, 0, 1, 6, 1, @currencyGUID, @ContinuesCashCurVal)
			END
  
			ELSE IF (@shortage > 0) 
			BEGIN
				SELECT @externalOperationNumber = MAX(Number)  FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSExternalOperations000 Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @ShiftControlAccountGuid, @employeeExtraAccountGuid, ABS(@shortage), GETDATE(), @ExternalOperationCloseShiftNote, 0, 0, 6, 1, @currencyGUID, @ContinuesCashCurVal)
			END
       
			IF (@withDrawnCash > 0)
			BEGIN
				SELECT @externalOperationNumber = MAX(ISNULL(Number, 0))  FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSExternalOperations000 Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @centralBoxAccount, @ShiftControlAccountGuid, ABS(@withDrawnCash), GETDATE(), @ExternalOperationCloseShiftNote, 0, 1, 3, 1, @currencyGUID, @ContinuesCashCurVal)
			END       
			IF (@ContinuesCash > 0)
			BEGIN
				SELECT @externalOperationNumber = MAX(ISNULL(Number, 0))  FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid 
				INSERT INTO POSExternalOperations000 Values(NEWID(), ISNULL(@externalOperationNumber, 0)+1, @shiftGuid, @FloatCashAccountGuid, @ShiftControlAccountGuid, ABS(@ContinuesCash), GETDATE(), @ExternalOperationCloseShiftNote, 0, 1, 0, 1, @currencyGUID, @ContinuesCashCurVal)
			END
	
		FETCH NEXT FROM curr_cursor INTO @currencyGUID, @ContinuesCash, @ContinuesCashCurVal, @CountedCash
	END
	CLOSE curr_cursor   
	DEALLOCATE curr_cursor

END
#################################################################
CREATE PROCEDURE prcPOSCloseShift
                           @posGuid UNIQUEIDENTIFIER,
                           @shiftGuid UNIQUEIDENTIFIER,
                           @externalOperationCloseShiftNote NVARCHAR(265),
                           @closeShiftNote NVARCHAR(265)
AS
BEGIN

	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User
	
	DECLARE @externalOperationTempTable		TABLE (Result INT)
	DECLARE @defferedSalesTempTable			TABLE (Result INT)
	DECLARE @defferedSalesReturnTempTable	TABLE (Result INT)
	DECLARE @BankCardTicketEntryTemp		TABLE (Result INT)
	DECLARE @result		INT      = -2
	DECLARE @closeDate  DATETIME = NULL
	
	IF(@posGuid IS NULL OR @shiftGuid IS NULL OR (SELECT CloseDate FROM POSShift000 WHERE [Guid] = @shiftGuid) IS NOT NULL)
	BEGIN
		SET @result =-1
		SELECT @result AS Result, @closeDate AS CloseDate
	    RETURN
	END

	DECLARE @saleBillType			                 UNIQUEIDENTIFIER = (SELECT SaleBillType  FROM POSCard000 WHERE [Guid] = @posGuid)
	DECLARE @saleReturnBillType			             UNIQUEIDENTIFIER = (SELECT SaleReturnBillType  FROM POSCard000 WHERE [Guid] = @posGuid)
	DECLARE	@ShiftControlAccountGuid                 UNIQUEIDENTIFIER = (SELECT ShiftControl  FROM POSCard000 WHERE [Guid] = @posGuid)
	DECLARE	@FloatCashAccountGuid	                 UNIQUEIDENTIFIER = (SELECT ContinuesCash FROM POSCard000 WHERE [Guid] = @posGuid)
	DECLARE	@dataTransferMode		                 INT = (SELECT DataTransferMode FROM POSCard000 WHERE Guid = @posGuid)
	DECLARE	@salebillGenerateSuccess	             INT
	DECLARE	@saleReturnbillGenerateSuccess	         INT
	DECLARE	@externalOperationEntryGenerateSuccess   BIT
	DECLARE	@defferedSalesEntryGenerateSuccess		 BIT
	DECLARE	@defferedSalesRetEntryGenerateSuccess	 BIT
	DECLARE @BankCardTicketEntryGeneratedSuccess     INT
	DECLARE	@IsMatchingShiftControlAccount		     BIT
	DECLARE	@IsMatchingFloatCashAccount			     BIT
	DECLARE	@IsThereMovesOutsidePos				     BIT
	DECLARE	@isRolledBack						     BIT
	DECLARE	@TransactionName					     NVARCHAR(50) = 'CloseShiftTransaction'
	DECLARE	@TicketsAndExternalOperationsTransaction NVARCHAR(50) = 'ticketsAndExternalOperationsTransaction'
 
	SET @isRolledBack = 0;
      
	BEGIN TRANSACTION @TransactionName
		--Generate external operations
        EXEC prcPOSGenerateCloseShiftExternalOperations @posGuid, @shiftGuid, @externalOperationCloseShiftNote
       
	    --Generate sales Bill
		EXEC  prcPOSGenerateBillForTickets @saleBillType, @shiftGuid, 0, @salebillGenerateSuccess output
      
		--Generate sales return Bill
		EXEC  prcPOSGenerateBillForTickets @saleReturnBillType, @shiftGuid, 2, @saleReturnbillGenerateSuccess output

        --Generate External Operation Entry
        INSERT INTO @externalOperationTempTable
			EXEC POSprcExternalOperationGenerateEntry @shiftGuid
      
        --Generate deffered Entry for sales tickets
        INSERT INTO @defferedSalesTempTable
			EXEC POSprcTicketGenerateEntry @shiftGuid, 0

		--Generate deffered Entry for sales return tickets
        INSERT INTO @defferedSalesReturnTempTable
			EXEC POSprcTicketGenerateEntry @shiftGuid, 2
		
		--Generate Bank Ticket Entry
		INSERT INTO @BankCardTicketEntryTemp
			EXEC prcPOSSD_Shift_BankCardsGenEntry @shiftGuid
       
        SELECT @externalOperationEntryGenerateSuccess = Result FROM @externalOperationTempTable
        SELECT @defferedSalesEntryGenerateSuccess     = Result FROM @defferedSalesTempTable
		SELECT @defferedSalesRetEntryGenerateSuccess  = Result FROM @defferedSalesReturnTempTable
		SELECT @BankCardTicketEntryGeneratedSuccess   = Result FROM @BankCardTicketEntryTemp
        
		IF ( @salebillGenerateSuccess = 0 OR @saleReturnbillGenerateSuccess = 0 
			OR @externalOperationEntryGenerateSuccess = 0 OR @defferedSalesEntryGenerateSuccess = 0 
			OR @defferedSalesRetEntryGenerateSuccess = 0
			OR @BankCardTicketEntryGeneratedSuccess = 0)
        BEGIN
                SET @result = 0
                SET @isRolledBack = 1
                ROLLBACK TRANSACTION @TransactionName;
        END 
              ELSE
              BEGIN
                     EXEC IsMatchingShiftControlAccount @ShiftControlAccountGuid, @IsMatchingShiftControlAccount OUTPUT
                     EXEC IsMatchingShiftControlAccount @FloatCashAccountGuid, @IsMatchingFloatCashAccount OUTPUT
                     EXEC IsTherePOSAccountOutsidePosMoves @posGuid, @IsThereMovesOutsidePos OUTPUT
                       
                     SET @closeDate = GETDATE()
                      
                     IF (@IsMatchingShiftControlAccount = 0 AND @IsThereMovesOutsidePos = 0)
                     BEGIN
						 SET @result = 3
						 SET @isRolledBack = 1
						 ROLLBACK TRANSACTION @TransactionName;
                     END
                     ELSE IF ((@IsMatchingShiftControlAccount = 0 OR @IsMatchingFloatCashAccount = 0) AND @IsThereMovesOutsidePos = 1)
                     BEGIN
						 UPDATE POSShift000 SET CloseDate = @closeDate, CloseShiftNote= @closeShiftNote WHERE Guid = @shiftGuid
						 SET @result =  2
						 COMMIT TRANSACTION @TransactionName;
                     END
                     ELSE 
					 IF(@IsMatchingShiftControlAccount = 1)
                     BEGIN
						 UPDATE POSShift000 SET CloseDate = @closeDate, CloseShiftNote= @closeShiftNote WHERE Guid = @shiftGuid
						 SET @result = 1     
						 COMMIT TRANSACTION @TransactionName;
                     END
              END
      
 
         --on offline mode
	IF @isRolledBack = 1 AND @dataTransferMode = 1
	BEGIN
		BEGIN TRANSACTION @TicketsAndExternalOperationsTransaction
 
		DELETE ticketItems
		FROM [dbo].[POSTicketItem000] ticketItems
		INNER JOIN [dbo].[POSTicket000] tickets ON tickets.Guid = ticketItems.TicketGuid
		WHERE ShiftGuid = @shiftGuid
 
		DELETE [dbo].[POSTicket000] WHERE  [ShiftGuid] = @shiftGuid
		DELETE [dbo].[POSExternalOperations000] where [ShiftGuid] = @shiftGuid
 
		COMMIT TRANSACTION @TicketsAndExternalOperationsTransaction
	END
      
       SELECT @result AS Result, @closeDate AS CloseDate
END
#################################################################
CREATE PROCEDURE prcPOSSDGetCurrenciesExchangeRate
@shiftGuid UNIQUEIDENTIFIER,
@rtl BIT

AS 
BEGIN
	DECLARE @posGuid UNIQUEIDENTIFIER = (SELECT PosGuid FROM POSShift000 WHERE Guid = @shiftGuid);
	DECLARE @sumCurrencyValue FLOAT,
	        @sumCurrEquilavent FLOAT,
		    @curGUID UNIQUEIDENTIFIER,
			@defaultCurGUID UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]()),
			@currName  NVARCHAR(256), @CurrencyName NVARCHAR(256),
			@currLatineName  NVARCHAR(256)

	DECLARE @CurrCash TABLE (CurrGUID UNIQUEIDENTIFIER, ExchangeAverage FLOAT, ExpectedCash FLOAT, CurrencyName NVARCHAR(256))
	
	DECLARE @RelatedCurrencies TABLE (CurGUID UNIQUEIDENTIFIER,
			Code NVARCHAR(256), Name NVARCHAR(256),Number INT,
			CurrencyVal FLOAT,
			PartName NVARCHAR(256),
			LatinName NVARCHAR(256),
			LatinPartName NVARCHAR(256),
			PictureGUID UNIQUEIDENTIFIER, 
			GUID UNIQUEIDENTIFIER,
			POSGuid UNIQUEIDENTIFIER,
			Used BIT,
			CentralBoxAccGUID UNIQUEIDENTIFIER,
			FloatCachAccGUID UNIQUEIDENTIFIER)

	INSERT INTO @RelatedCurrencies
	 EXEC prcPOSSDGetRelatedCurrencies @posGuid

	DECLARE curr_cursor CURSOR FOR  
		SELECT CurGUID, Name, LatinName FROM @RelatedCurrencies 

	OPEN curr_cursor   
		FETCH NEXT FROM curr_cursor INTO @curGUID, @currName, @currLatineName

		WHILE @@FETCH_STATUS = 0   
		BEGIN  
		       
			   SET @sumCurrencyValue = (SELECT [dbo].GetPosShiftCash(@shiftGuid, @curGUID, DEFAULT))
			   SET @sumCurrEquilavent = (SELECT [dbo].GetPosShiftCash(@shiftGuid, @curGUID, 1))
               SET @CurrencyName = CASE @rtl WHEN 1 THEN @currName ELSE (CASE @currLatineName WHEN '' THEN @currName ELSE @currLatineName END) END 
			   
			   IF (@sumCurrencyValue = 0 AND @curGUID = @defaultCurGUID)
			   BEGIN
			     INSERT INTO @CurrCash VALUES (@curGUID, 1, @sumCurrencyValue, @CurrencyName)
			   END
			   ELSE
			   BEGIN
				IF (@sumCurrencyValue <> 0)
					INSERT INTO @CurrCash VALUES (@curGUID, @sumCurrEquilavent/@sumCurrencyValue, @sumCurrencyValue, @CurrencyName)
			   END
			FETCH NEXT FROM curr_cursor INTO @curGUID, @currName, @currLatineName
		END   

	CLOSE curr_cursor   
	DEALLOCATE curr_cursor

	SELECT * FROM @CurrCash

END
#################################################################
CREATE PROCEDURE prcPOSSDGetShiftOpeningCash
@posGuid AS uniqueidentifier,
@rtl BIT
AS 
BEGIN
   DECLARE	@lastShiftGuid [uniqueidentifier]
   DECLARE	@LatFlostCash TABLE (CurrenceyGUID uniqueidentifier, CurrenceyName NVARCHAR(256), OpeningCash FLOAT)
   
   DECLARE @RelatedCurrencies TABLE (CurGUID UNIQUEIDENTIFIER,
			Code NVARCHAR(256), Name NVARCHAR(256),Number INT,
			CurrencyVal FLOAT,
			PartName NVARCHAR(256),
			LatinName NVARCHAR(256),
			LatinPartName NVARCHAR(256),
			PictureGUID UNIQUEIDENTIFIER, 
			GUID UNIQUEIDENTIFIER,
			POSGuid UNIQUEIDENTIFIER,
			Used BIT,
			CentralBoxAccGUID UNIQUEIDENTIFIER,
			FloatCachAccGUID UNIQUEIDENTIFIER)

	INSERT INTO @RelatedCurrencies
	 EXEC prcPOSSDGetRelatedCurrencies @posGuid
    
	SET @lastShiftGuid = (SELECT Guid From POSShift000 ps WHERE POSGuid = @posGuid 
	                             AND CloseDate = (SELECT MAX(CloseDate) From POSShift000 ps WHERE POSGuid = @posGuid))
	
	INSERT INTO @LatFlostCash 
     SELECT PRC.CurGUID
	        ,(SELECT CASE @rtl WHEN 1 THEN Name ELSE (CASE LatinName WHEN '' THEN Name ELSE LatinName END) END  FROM my000 WHERE Guid = PRC.CurGUID)
			,ISNULL(ContinuesCash , 0)
	 FROM @RelatedCurrencies PRC 
	 LEFT JOIN POSSDShiftCashCurrency000 SC 
	 ON PRC.CurGUID = SC.CurrencyGUID AND SC.ShiftGUID = @lastShiftGuid
	
	SELECT * FROM @LatFlostCash
END
#################################################################
CREATE PROCEDURE prcPOSCheckMatPrice
@POSGuid UNIQUEIDENTIFIER
AS
BEGIN
SET FMTONLY OFF
	
	CREATE TABLE [#MatPrice]
	(
	  MatGuid UNIQUEIDENTIFIER,
	  UnitType INT,
	  Unit  NVARCHAR(256),
	  Price Float
	) 
	CREATE TABLE [#Materials]
	(
		Number			INT,
		Code			NVARCHAR(100),
		GUID			UNIQUEIDENTIFIER,
		GroupGUID		UNIQUEIDENTIFIER,
		LatinName		NVARCHAR(250),
		Name			NVARCHAR(250),
		Unity			NVARCHAR(100),
		Unit2			NVARCHAR(100),
		Unit3			NVARCHAR(100),
		DefUnit			INT,
		Unit2Fact		FLOAT,
		Unit3Fact		FLOAT,
		Unit2FactFlag	BIT,
		Unit3FactFlag	BIT,
		Whole			FLOAT,
		Whole2			FLOAT,
		Whole3			FLOAT,
		Half			FLOAT,
		Half2			FLOAT,
		Half3			FLOAT,
		EndUser			FLOAT,
		EndUser2		FLOAT,
		EndUser3		FLOAT,
		Vendor			FLOAT,
		Vendor2			FLOAT,
		Vendor3			FLOAT,
		Export			FLOAT,
		Export2			FLOAT,
		Export3			FLOAT,
		LastPrice		FLOAT,
		LastPrice2		FLOAT,
		LastPrice3		FLOAT,
		AvgPrice		FLOAT,
		BarCode			NVARCHAR(100),
		BarCode2		NVARCHAR(100),
		BarCode3		NVARCHAR(100),
		PictureGUID		UNIQUEIDENTIFIER,
		Retail			FLOAT,
		Retail2			FLOAT,
		Retail3			FLOAT,
		MaxPrice		FLOAT,
		MaxPrice2		FLOAT,
		MaxPrice3		FLOAT,
		type			INT,
		TaxRatio	FLOAT,
		HasCrossSaleMaterials BIT,
		HasUpSaleMaterials BIT,
		CrossSaleQuestion NVARCHAR(500),
		CrossSaleLatinQuestion NVARCHAR(500)
	)
	-- Inserts result into temp table [#Materials]
	EXEC prcPOSGetAllPOSCardMaterials @POSGuid
	
	DECLARE @PriceType INT 
	DECLARE @Res BIT = 1
	DECLARE @PType NVARCHAR(256)
	
	SET @PriceType = (SELECT PriceType FROM POSCard000 WHERE Guid = @POSGuid)
	SELECT @PType = CASE @PriceType WHEN 4 THEN 'Whole'
									WHEN 8  THEN 'Half' 
									WHEN 16  THEN 'Export' 
									WHEN 32  THEN 'Vendor' 
									WHEN 64  THEN 'Retail'
									WHEN 128  THEN 'EndUser'  
									END

	-- Unit1 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			1, 
			Unity, 
			CASE @PriceType WHEN 4	THEN Whole
							WHEN 8	THEN Half
							WHEN 16	THEN Export 
							WHEN 32  THEN Vendor 
							WHEN 64  THEN Retail
							WHEN 128  THEN EndUser 
			END					
		FROM [#Materials]

	-- Unit2 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			2, 
			Unit2, 
			CASE @PriceType WHEN 4	THEN Whole2
							WHEN 8	THEN Half2 
							WHEN 16	THEN Export2 
							WHEN 32  THEN Vendor2 
							WHEN 64  THEN Retail2
							WHEN 128  THEN EndUser2 
			END					
		FROM [#Materials] 

	-- Unit3 prices
	INSERT INTO #MatPrice (MatGuid, UnitType, Unit, Price)
		SELECT 
			Guid, 
			3, 
			Unit3, 
			CASE @PriceType WHEN 4	THEN Whole3
							WHEN 8	THEN Half3 
							WHEN 16	THEN Export3 
							WHEN 32  THEN Vendor3 
							WHEN 64  THEN Retail3
							WHEN 128  THEN EndUser3 
			END					
		FROM [#Materials]
	IF EXISTS 
		(
			select * from #MatPrice where  (unit <> '' AND price =0)  
			UNION 
			SELECT * FROM #MatPrice mat1 
			WHERE (mat1.price= 0 AND mat1.UnitType =1) 
            AND EXISTS (SELECT 1 FROM #MatPrice mat2 WHERE mat2.MatGuid = mat1.MatGuid AND mat2.price= 0 AND mat2.UnitType = 2)
			AND EXISTS (SELECT 1 FROM #MatPrice mat3 WHERE mat3.MatGuid = mat1.MatGuid AND mat3.price= 0 AND mat3.UnitType = 3)
		 )
	BEGIN
		SET @Res =0
	END

	SELECT @Res	 AS Result 
	DROP TABLE [#MatPrice]
	DROP TABLE [#Materials]

END
#################################################################
CREATE PROCEDURE prcPosDeleteShiftBillAndEntries
-- Params -------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
 DECLARE @billGuid [UNIQUEIDENTIFIER]

 SELECT @billGuid = BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGuid
 
 EXEC prcBill_delete @billGuid
 EXEC prcBill_Delete_Entry @billGuid
 DELETE FROM BillRel000 WHERE BillGUID = @billGuid

 DECLARE @defferdEntryGuid UNIQUEIDENTIFIER, @externalOperationEntryGuid UNIQUEIDENTIFIER
	
	SELECT @defferdEntryGuid = EntryGuid FROM er000 WHERE ParentGuid = @ShiftGuid AND ParentType = 701
	SELECT @externalOperationEntryGuid = EntryGuid FROM er000 WHERE ParentGuid = @ShiftGuid AND ParentType = 702
	
	EXEC prcDisableTriggers  'ce000'
	EXEC prcDisableTriggers  'en000'
	EXEC prcDisableTriggers  'er000'
	IF ( ISNULL( @defferdEntryGuid, 0x0) <> 0x0)
	BEGIN 
		
		DELETE FROM ce000 WHERE Guid = @defferdEntryGuid
		DELETE FROM en000 WHERE ParentGuid = @defferdEntryGuid
		DELETE FROM er000 WHERE EntryGUID = @defferdEntryGuid
	END
	IF ( ISNULL( @externalOperationEntryGuid, 0x0) <> 0x0)
		 BEGIN
			DELETE FROM ce000 WHERE Guid = @externalOperationEntryGuid
			DELETE FROM en000 WHERE ParentGuid = @externalOperationEntryGuid
			DELETE FROM er000 WHERE EntryGUID = @externalOperationEntryGuid
    END	
		
		EXEC prcEnableTriggers 'ce000'
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'
	
END
#################################################################
CREATE FUNCTION fnGetPOSShifts
	(@POSGuid AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN SELECT * 
		   FROM
				[POSShift000]
		   WHERE
				[POSGuid] = @POSGuid 
#################################################################
CREATE PROCEDURE prcPOSGetAllPOSCardMaterials
@POSCardGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT 
	) 
	
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
		EXEC prcPOSGetRelatedGroups @POSCardGuid
	
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER)
	
	INSERT INTO @Materials(MatGuid)
		SELECT DISTINCT [GUID] 
		FROM @Groups groups  
		INNER JOIN mt000 mt ON mt.GroupGUID = groups.GroupGUID
	
	INSERT INTO @Materials(MatGuid)
		SELECT [mt].[GUID]
		FROM @Groups AS [grp]
		INNER JOIN [gri000] AS [gri] ON [gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid]
	-- Collective Groups Materials --
	DECLARE @GroupGUID UNIQUEIDENTIFIER
	DECLARE @GroupCursor as CURSOR;
	SET @GroupCursor = CURSOR FOR SELECT GroupGUID FROM @Groups
	
	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @GroupGUID;
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		INSERT INTO @Materials(MatGuid)
			SELECT mtGUID 
			FROM fnGetMatsOfCollectiveGrps(@GroupGUID)
			WHERE NOT EXISTS
					(	SELECT MatGuid 
						FROM @Materials
						WHERE MatGuid = mtGUID
					)
			
		 FETCH NEXT FROM @GroupCursor INTO @GroupGUID;
	END
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;
	----------------------------------------
	INSERT INTO [#Materials]
		SELECT distinct(mt.Number),
					mt.Code,
					mt.GUID,
					mt.GroupGUID,
					mt.LatinName,
					mt.Name,
					mt.Unity,
					mt.Unit2,
					mt.Unit3,
					mt.DefUnit,
					mt.Unit2Fact,
					mt.Unit3Fact,
					mt.Unit2FactFlag,
					mt.Unit3FactFlag,
					mt.Whole,
					mt.Whole2,
					mt.Whole3,
					mt.Half,
					mt.Half2,
					mt.Half3,
					mt.EndUser,
					mt.EndUser2,
					mt.EndUser3,
					mt.Vendor,
					mt.Vendor2,
					mt.Vendor3,
					mt.Export,
					mt.Export2,
					mt.Export3,
					mt.LastPrice,
					mt.LastPrice2,
					mt.LastPrice3,
					mt.AvgPrice,
					mt.BarCode,
					mt.BarCode2,
					mt.BarCode3,
					mt.PictureGUID,
					mt.Retail,
					mt.Retail2,
					mt.Retail3,
					mt.MaxPrice,
					mt.MaxPrice2,
					mt.MaxPrice3,
					mt.type,
					mt.VAT AS TaxRatio,
					CAST((CASE ISNULL(ME.GUID, 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 1 THEN 1 ELSE 0 END) END) AS BIT) AS HasCrossSaleMaterials,
					CAST((CASE ISNULL(ME.GUID, 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 2 THEN 1 ELSE 0 END) END) AS BIT) AS HasUpSaleMaterials,
					ISNULL(ME.Question, '')      AS CrossSaleQuestion,
				    ISNULL(ME.LatinQuestion, '') AS CrossSaleLatinQuestion
		FROM @Materials mats
		INNER JOIN mt000 mt ON mt.GUID = mats.MatGuid
		LEFT JOIN POSSDMaterialExtended000 ME ON mats.MatGuid = ME.MaterialGUID
END

#################################################################
CREATE PROCEDURE prcPOSGetRelatedGroups
@POSCardGuid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Groups TABLE
	(
		Number		INT,
		GroupGUID	UNIQUEIDENTIFIER,  
		Name		NVARCHAR(MAX),
		Code		NVARCHAR(MAX),
		ParentGUID	UNIQUEIDENTIFIER,  
		LatinName	NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT
	) 
	DECLARE @GroupGUID UNIQUEIDENTIFIER , @GroupIndex INT
	DECLARE @GroupCursor as CURSOR;
 
	SET @GroupCursor = CURSOR FOR
		SELECT relatedgroup.[GroupGuid], relatedgroup.[Number]
		FROM POSRelatedGroupS000 relatedgroup 
		INNER JOIN gr000 gr on gr.GUID = relatedgroup.GroupGuid 
		WHERE POSGuid = @POSCardGuid
 

	 INSERT INTO @Groups(Name,Number, Code,LatinName, GroupGUID, ParentGUID, PictureGUID, GroupIndex)
		SELECT DISTINCT(gr.Name),gr.Number,gr.Code,gr.LatinName,gr.Guid as GroupGUID, gr.ParentGUID, gr.PictureGUID, pos.Number
		FROM gr000 gr
		INNER JOIN POSRelatedGroupS000 pos ON pos.[GroupGuid] = gr.[GUID]
		WHERE pos.[POSGuid] = @POSCardGuid

	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @GroupGUID, @GroupIndex;
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
	
	 INSERT INTO @Groups (Name,Number, Code,LatinName, GroupGUID, ParentGUID, PictureGUID, GroupIndex)
			SELECT  DISTINCT(gr.Name),gr.Number,gr.Code,gr.LatinName,gr.Guid as GroupGUID, gr.ParentGUID, gr.PictureGUID, @GroupIndex
			FROM fnGetGroupsList(@GroupGUID) AS tempTb 
			INNER JOIN gr000 gr ON gr.GUID = tempTb.GUID
			INNER JOIN mt000 material ON material.GroupGUID = tempTb.Guid
			WHERE  NOT EXISTS(SELECT GroupGUID
						FROM @Groups t2
					   WHERE t2.GroupGUID = gr.Guid)
			 
	 FETCH NEXT FROM @GroupCursor INTO @GroupGUID, @GroupIndex;
	
	END
 
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;

	SELECT Number,		 
		   GroupGUID,	
		   Name,		
		   Code,	
		   ParentGUID,	
		   LatinName,	
		   PictureGUID, 
		   GroupIndex
	FROM @Groups
END
#################################################################
CREATE PROCEDURE prcPOSGetRelatedMaterials
@POSCardGuid UNIQUEIDENTIFIER,
@PageSize INT = 200,
@PageIndex INT = 0
AS
BEGIN
	--DECLARE @material TABLE
	--(
	--    Number			INT,
	--	Code			NVARCHAR(100),
	--	GUID			UNIQUEIDENTIFIER PRIMARY KEY,
	--	GroupGUID		UNIQUEIDENTIFIER,
	--	LatinName		NVARCHAR(250),
	--	Name			NVARCHAR(250),
	--	Unity			NVARCHAR(100),
	--	Unit2			NVARCHAR(100),
	--	Unit3			NVARCHAR(100),
	--	DefUnit			INT,
	--	Unit2Fact		FLOAT,
	--	Unit3Fact		FLOAT,
	--	Unit2FactFlag	BIT,
	--	Unit3FactFlag	BIT,
	--	Whole			FLOAT,
	--	Whole2			FLOAT,
	--	Whole3			FLOAT,
	--	Half			FLOAT,
	--	Half2			FLOAT,
	--	Half3			FLOAT,
	--	EndUser			FLOAT,
	--	EndUser2		FLOAT,
	--	EndUser3		FLOAT,
	--	Vendor			FLOAT,
	--	Vendor2			FLOAT,
	--	Vendor3			FLOAT,
	--	Export			FLOAT,
	--	Export2			FLOAT,
	--	Export3			FLOAT,
	--	LastPrice		FLOAT,
	--	LastPrice2		FLOAT,
	--	LastPrice3		FLOAT,
	--	AvgPrice		FLOAT,
	--	BarCode			NVARCHAR(100),
	--	BarCode2		NVARCHAR(100),
	--	BarCode3		NVARCHAR(100),
	--	PictureGUID		UNIQUEIDENTIFIER,
	--	Retail			FLOAT,
	--	Retail2			FLOAT,
	--	Retail3			FLOAT,
	--	MaxPrice		FLOAT,
	--	MaxPrice2		FLOAT,
	--	MaxPrice3		FLOAT,
	--	type			INT,
	--	TaxRatio	FLOAT,
	--	HasCrossSaleMaterials BIT,
	--	HasUpSaleMaterials BIT,
	--	CrossSaleQuestion NVARCHAR(500),
	--	CrossSaleLatinQuestion NVARCHAR(500) )
	--SELECT * FROM @material

	CREATE TABLE [#Materials]
	(
		Number			INT,
		Code			NVARCHAR(100),
		GUID			UNIQUEIDENTIFIER,
		GroupGUID		UNIQUEIDENTIFIER,
		LatinName		NVARCHAR(250),
		Name			NVARCHAR(250),
		Unity			NVARCHAR(100),
		Unit2			NVARCHAR(100),
		Unit3			NVARCHAR(100),
		DefUnit			INT,
		Unit2Fact		FLOAT,
		Unit3Fact		FLOAT,
		Unit2FactFlag	BIT,
		Unit3FactFlag	BIT,
		Whole			FLOAT,
		Whole2			FLOAT,
		Whole3			FLOAT,
		Half			FLOAT,
		Half2			FLOAT,
		Half3			FLOAT,
		EndUser			FLOAT,
		EndUser2		FLOAT,
		EndUser3		FLOAT,
		Vendor			FLOAT,
		Vendor2			FLOAT,
		Vendor3			FLOAT,
		Export			FLOAT,
		Export2			FLOAT,
		Export3			FLOAT,
		LastPrice		FLOAT,
		LastPrice2		FLOAT,
		LastPrice3		FLOAT,
		AvgPrice		FLOAT,
		BarCode			NVARCHAR(100),
		BarCode2		NVARCHAR(100),
		BarCode3		NVARCHAR(100),
		PictureGUID		UNIQUEIDENTIFIER,
		Retail			FLOAT,
		Retail2			FLOAT,
		Retail3			FLOAT,
		MaxPrice		FLOAT,
		MaxPrice2		FLOAT,
		MaxPrice3		FLOAT,
		type			INT,
		TaxRatio	FLOAT,
		HasCrossSaleMaterials BIT,
		HasUpSaleMaterials BIT,
		CrossSaleQuestion NVARCHAR(500),
		CrossSaleLatinQuestion NVARCHAR(500)
	)
	-- Inserts result in to temp table materials
	EXEC prcPOSGetAllPOSCardMaterials @POSCardGuid
	SELECT distinct(Number),
				Code,
				GUID,
				GroupGUID,
				LatinName,
				Name,
				Unity,
				Unit2,
				Unit3,
				DefUnit,
				Unit2Fact,
				Unit3Fact,
				Unit2FactFlag,
				Unit3FactFlag,
				Whole,
				Whole2,
				Whole3,
				Half,
				Half2,
				Half3,
				EndUser,
				EndUser2,
				EndUser3,
				Vendor,
				Vendor2,
				Vendor3,
				Export,
				Export2,
				Export3,
				LastPrice,
				LastPrice2,
				LastPrice3,
				AvgPrice,
				BarCode,
				BarCode2,
				BarCode3,
				PictureGUID,
				Retail,
				Retail2,
				Retail3,
				MaxPrice,
				MaxPrice2,
				MaxPrice3,
				type,
				TaxRatio ,
				HasCrossSaleMaterials,
				HasUpSaleMaterials,
				CrossSaleQuestion,
				CrossSaleLatinQuestion
	FROM #Materials
	ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
	DROP TABLE [#Materials]
END
#################################################################
CREATE PROCEDURE prcPOSGetRelatedMaterialsBarcodes
 @POSCardGuid UNIQUEIDENTIFIER

AS
BEGIN

 DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT 
	) 
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
	  EXEC prcPOSGetRelatedGroups @POSCardGuid

	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER)

   --Fetch materials related to POS   
	INSERT INTO @Materials(MatGuid)
		SELECT DISTINCT [GUID] 
		FROM @Groups groups  
		INNER JOIN mt000 mt ON mt.GroupGUID = groups.GroupGUID

	INSERT INTO @Materials(MatGuid)
		SELECT [mt].[GUID]
		FROM @Groups AS [grp]
		INNER JOIN [gri000] AS [gri] ON [gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1
		INNER JOIN [mt000] AS [mt] ON [mt].[GUID] = [gri].[MatGuid]
		
 --Get barcodes related to materials
  SELECT MB.Guid, MB.MatGuid, MB.MatUnit - 1 AS MatUnit, MB.Barcode, MB.IsDefault 
   FROM MatExBarcode000 MB 
   INNER JOIN  @Materials MT 
   ON MB.MatGuid = MT.MatGuid
   ORDER BY MB.MatGuid

END
#################################################################
--CREATE PROCEDURE PrcPOSGetShiftDigestInfo
--	@shiftGuid  [UNIQUEIDENTIFIER]
--AS
--BEGIN

--DECLARE @SalesTicketTotal [FLOAT] ,
--		@SalesTicketTotalCount [INT] ,
--		@GrantingDebit [FLOAT] ,
--		@GrantingDebitCount [INT],
--		@ExternalPayment [FLOAT] ,
--		@ExternalPaymentCount [INT],
--		@ExternalReceivce [FLOAT],
--		@ExternalReceivceCount [INT],
--		@CentralCashPayemnt [FLOAT],
--		@CentralCashPayemntCount [INT],
--		@CentralCashReceive [FLOAT],
--		@CentralCashReceiveCount [INT],
--		@CashDifference [FLOAT],
--		@OpeningAmount [FLOAT],
--		@FloatingAmount [FLOAT],
--		@CashDifferenceCount [INT],
--		@OpeningAmountCount [INT],
--		@FloatingAmountCount [INT],
--		@CurrentCash [FLOAT] ,
--		@ExternalOperationsCash [FLOAT],
--		@ExternalOperationsCashCount [INT],
--	    @ExpectedCash [FLOAT],
--	    @CashReceivedFromTickets [FLOAT]
	  

--SELECT
--	@SalesTicketTotal = ISNULL(SUM(POSticket.Net),0),
--	@SalesTicketTotalCount =  ISNULL(COUNT(*),0),
--	@GrantingDebit =  ISNULL(SUM(POSticket.LaterValue),0)
--FROM 
--		POSTicket000 POSticket
--	WHERE POSticket.State = 0 AND POSticket.ShiftGuid = @shiftGuid


--SELECT
--	@GrantingDebitCount =  ISNULL(COUNT(*),0)
--FROM 
--		POSTicket000 POSticket
--	WHERE POSticket.State = 0 AND POSticket.ShiftGuid = @shiftGuid AND POSticket.LaterValue > 0



--SELECT 
--	@ExternalPayment =  ISNULL(SUM(POSExternalOperation.Amount),0),
--	@ExternalPaymentCount =	  ISNULL(COUNT(*) ,0)
--FROM 
--	POSExternalOperations000 POSExternalOperation
--	WHERE POSExternalOperation.ShiftGuid = @shiftGuid  AND POSExternalOperation.State = 0
--	 AND POSExternalOperation.IsPayment = 1 AND POSExternalOperation.Type <> 3 AND POSExternalOperation.GenerateState <> 1

--SELECT 
--	@ExternalReceivce = ISNULL( SUM(POSExternalOperation.Amount),0),
--	@ExternalReceivceCount =  ISNULL(COUNT(*) , 0)
--FROM 
--	POSExternalOperations000 POSExternalOperation
--	WHERE POSExternalOperation.ShiftGuid = @shiftGuid  AND POSExternalOperation.State = 0 AND POSExternalOperation.Type <> 0
--	AND POSExternalOperation.IsPayment = 0 AND POSExternalOperation.Type <> 3 AND POSExternalOperation.GenerateState <> 1


	  
--SELECT 
--	@CentralCashPayemnt =  ISNULL(SUM(POSExternalOperation.Amount),0),
--	@CentralCashPayemntCount =  ISNULL(COUNT(*) ,0)
--FROM 
--	POSExternalOperations000 POSExternalOperation
--	WHERE POSExternalOperation.ShiftGuid = @shiftGuid  AND POSExternalOperation.State = 0 AND POSExternalOperation.IsPayment = 1 
--	AND POSExternalOperation.Type = 3 

--SELECT @CentralCashReceive =  ISNULL(SUM(POSExternalOperation.Amount),0),
--	   @CentralCashReceiveCount =  ISNULL(COUNT(*),0)
--FROM 
--	POSExternalOperations000 POSExternalOperation
--	WHERE POSExternalOperation.ShiftGuid = @shiftGuid AND POSExternalOperation.State = 0  AND POSExternalOperation.IsPayment = 0 AND POSExternalOperation.Type = 3 
	

--SET @ExpectedCash = ( SELECT [dbo].GetPosShiftCash(@shiftGuid, default, default))



--SELECT @OpeningAmount =  ISNULL(OpeningCash,0),
--	   @FloatingAmount =  ISNULL(FloatCash,0),
--	   @OpeningAmountCount = CASE WHEN OpeningCash > 0   THEN 1 ELSE 0 END,
--	   @FloatingAmountCount= CASE WHEN FloatCash > 0  THEN 1 ELSE 0 END,
--	   @CashDifference  = CASE  WHEN CloseDate IS NULL THEN  0 ELSE ISNULL(CountedCash,0) - @ExpectedCash  END,
--	   @CashDifferenceCount =  CASE WHEN CloseDate IS  NULL THEN  0 ELSE CASE WHEN (@ExpectedCash = CountedCash) THEN 0 ELSE 1 END END
--FROM 
-- POSShift000 WHERE Guid = @shiftGuid

--SET @ExternalOperationsCash = @OpeningAmount - @FloatingAmount - @CentralCashPayemnt + @CentralCashReceive - @ExternalPayment + @ExternalReceivce + @CashDifference
--SET @ExternalOperationsCashCount = @OpeningAmountCount + @FloatingAmountCount + @CentralCashPayemntCount + @CentralCashReceiveCount+ @ExternalReceivceCount + @CashDifferenceCount + @ExternalPaymentCount

--SET @CashReceivedFromTickets =  @SalesTicketTotal - @GrantingDebit 


--SET @CurrentCash =  @CashReceivedFromTickets + @ExternalOperationsCash

--SELECT @SalesTicketTotal AS SalesTicketTotal , 
--	   @SalesTicketTotalCount as SalesTicketTotalCount,
--	   @GrantingDebit AS GrantingDebit,
--	   @GrantingDebitCount AS GrantingDebitCount,
--	   @CashReceivedFromTickets AS CashReceivedFromTickets,
--	   @ExternalPayment AS ExternalPayment,
--	   @ExternalPaymentCount AS ExternalPaymentCount,
--	   @ExternalReceivce AS ExternalReceive,
--	   @ExternalReceivceCount AS ExternalReceiveCount, 
--	   @CentralCashPayemnt AS CentralCashPayment,
--	   @CentralCashPayemntCount AS CentralCashPaymentCount,
--	   @CentralCashReceive AS CentralCashReceive, 
--	   @CentralCashReceiveCount AS CentralCashReceiveCount,
--	   @ExternalOperationsCash AS ExternalOperationsCash,
--	   @ExternalOperationsCashCount AS ExternalOperationsCashCount,
--	   @CashDifference  AS CashDifference,
--	   @CashDifferenceCount AS CashDifferenceCount,
--	   Round(@CurrentCash,2) AS CurrentCash,
--	   @OpeningAmount AS OpeningAmount,
--	   @OpeningAmountCount AS OpeningAmountCount,
--	   @FloatingAmount AS FloatingAmount,
--	   @FloatingAmountCount AS FloatingAmountCount

--END
#################################################################
CREATE PROCEDURE prcCheckOpenedShiftInPOSCard
@BillType UNIQUEIDENTIFIER,
@billId UNIQUEIDENTIFIER 
AS 
BEGIN 

DECLARE @Result INT 
SET @Result = 0

	SELECT @Result = COUNT(*)
		FROM POSCard000 posCard INNER JOIN POSShift000 posShift ON posCard.Guid = posShift.POSGuid
		INNER JOIN BillRel000 billRel ON billRel.ParentGUID = posShift.Guid
	WHERE posCard.SaleBillType = @BillType AND CloseDate  IS NOT NULL   AND billRel.BillGUID = @billId

	SELECT @Result AS Result
END
#################################################################
CREATE PROCEDURE IsMatchingShiftControlAccount
	@accountGuid UNIQUEIDENTIFIER,
	@Result BIT   OUT
AS 
BEGIN

	SET NOCOUNT ON

	SET @Result = 1

	DECLARE @temp TABLE
	(
		Balance FLOAT,
		Debit FLOAT,
		Credit FLOAT,
		CurrValue FLOAT
	)
	 
	DECLARE @currencyGuid UNIQUEIDENTIFIER, @accountBalance FLOAT
	DECLARE  @pricePrec INT = CAST(dbo.fnOption_GetValue('AmnCfg_PricePrec', 0) AS INT)

	SELECT @currencyGuid =  [Value] FROM [dbo].[OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency'

	INSERT INTO @temp
    EXEC prcAccount_getBalance @accountGuid, @currencyGuid

	SELECT @accountBalance = ISNULL(ROUND(ABS(Debit - Credit), @pricePrec) ,0) FROM @temp
	
    IF(@accountBalance <> 0)
	   SET @Result = 0
END
#################################################################
CREATE PROCEDURE prcPOSGetCollectiveGroups
(
	@POSCardGuid UNIQUEIDENTIFIER
)
AS
BEGIN
	DECLARE @RelatedGroups TABLE
	(
		GroupGuid	UNIQUEIDENTIFIER,
		RelatedGuid UNIQUEIDENTIFIER,
		GroupKind	INT
	)

	DECLARE @Groups TABLE
	(
		Number		INT,
		GroupGUID	UNIQUEIDENTIFIER,  
		Name		NVARCHAR(MAX),
		Code		NVARCHAR(MAX),
		ParentGUID	UNIQUEIDENTIFIER,  
		LatinName	NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT 
	) 

	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
		EXEC prcPOSGetRelatedGroups @POSCardGuid

	DECLARE @GroupCursor AS CURSOR;
	DECLARE @CurrentGroupGUID UNIQUEIDENTIFIER

	SET @GroupCursor = CURSOR FOR
		SELECT GroupGUID from @Groups

	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @CurrentGroupGUID;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	
		INSERT INTO @RelatedGroups (GroupGuid, RelatedGuid, GroupKind)
			SELECT DISTINCT @CurrentGroupGUID, Collective.[GUID], Collective.[GroupKind]
			FROM fnGetCollectiveGroupsList(@CurrentGroupGUID) AS Collective 
	
		INSERT INTO @RelatedGroups (GroupGuid, RelatedGuid, GroupKind)
			SELECT DISTINCT @CurrentGroupGUID, Mats.[mtGUID], 2 FROM fnGetMatsOfCollectiveGrps(@CurrentGroupGUID) Mats

		FETCH NEXT FROM @GroupCursor INTO @CurrentGroupGUID

	END
 
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;

	SELECT DISTINCT GroupGuid, RelatedGuid, GroupKind FROM @RelatedGroups WHERE GroupGuid <> RelatedGuid 
END
#################################################################
CREATE PROCEDURE prcPOSGetPosInfo
@deviceId NVARCHAR(50)
AS 
BEGIN

	SELECT PC.* 
	 FROM POSCard000 PC 
	 INNER JOIN POSCardDevice000 PD 
	 ON PC.Guid = PD.POSCardGuid
	WHERE PD.DeviceID = @deviceId

END 
#################################################################
CREATE PROCEDURE prcPOSGetShiftInfo
@shiftGuid uniqueidentifier
AS
BEGIN
        DECLARE @maxTicketNumber int = (SELECT MAX(number) FROM POSTicket000 WHERE ShiftGuid = @shiftGuid),
        @maxExternalOperationNumber int = (SELECT MAX(number) FROM POSExternalOperations000 WHERE ShiftGuid = @shiftGuid),
        @currentShiftCash FLOAT = (SELECT [dbo].GetPosShiftCash(@shiftGuid, default, default))

		SELECT @shiftGuid AS ShiftGuid, ISNULL(@maxTicketNumber, 0) MaxTicketNumber, ISNULL(@maxExternalOperationNumber, 0) MaxExternalOperationNumber, @currentShiftCash CurrentShiftCash
END
#################################################################
CREATE PROCEDURE prcPOSSDGetRelatedCurrencies
-- Param -------------------------------   
	   @PosGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
 SELECT my.GUID CurGUID,
	    MY.Code, Name,Number,
		CASE WHEN mh.CurrencyVal IS NOT NULL THEN mh.CurrencyVal ELSE my.CurrencyVal END CurrencyVal,
		PartName,
		LatinName,
		LatinPartName,
		PictureGUID, 
		RC.GUID,
		RC.POSGuid,
		RC.Used,
		RC.CentralBoxAccGUID,
		RC.FloatCachAccGUID 
 FROM my000 my 
      LEFT JOIN mh000 mh ON my.GUID = mh.CurrencyGUID 
      LEFT JOIN POSSDRelatedCurrencies000 RC ON my.GUID = RC.CurGUID AND POSGuid = @PosGuid
 WHERE (Used = 1 OR my.CurrencyVal = 1) 
	    AND (EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID) 
		      AND (mh.Date = (SELECT MAX ([Date]) FROM mh000 mhe GROUP BY CurrencyGUID HAVING CurrencyGUID = mh.CurrencyGUID )) 
			  OR (NOT EXISTS (SELECT 1 FROM mh000 WHERE CurrencyGUID = my.GUID)))
 ORDER BY Number
END
#################################################################
CREATE PROCEDURE prcPOSSDGetRelatedBankCards
-- Param -------------------------------   
	   @PosGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
 SELECT BC.*, 
		RC.POSGuid,
		RC.Used
 FROM BankCard000 BC 
      LEFT JOIN POSSDRelatedBankCards000 RC
      ON BC.GUID = RC.BankCardGUID AND  POSGuid = @PosGuid 
 WHERE Used = 1	   
 ORDER BY Number
END
#################################################################
CREATE PROCEDURE prcPOSGetPosReturnedSalesOptions
-- Param -------------------------------   
	   @POSCardGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
	SELECT *
	FROM POSSDReturenedSales000 ReturnedSales
	WHERE ReturnedSales.[POSCardGUID] = @POSCardGuid
END
#################################################################
#END 