#################################################################
CREATE PROCEDURE prcPOSSD_Shift_CloseShift
                           @posGuid							UNIQUEIDENTIFIER,
                           @shiftGuid						UNIQUEIDENTIFIER,
                           @externalOperationCloseShiftNote NVARCHAR(265),
                           @closeShiftNote					NVARCHAR(265),
						   @centralBoxReceiptNoNote			NVARCHAR(256),
						   @deviceID						NVARCHAR(250),
						   @IsForcedClose					BIT
AS
BEGIN
	DECLARE @User UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @User, 0
	EXEC prcConnections_SetIgnoreWarnings 1
	DECLARE @externalOperationTempTable		TABLE (Result INT)
	DECLARE @defferedSalesTempTable			TABLE (Result INT)
	DECLARE @defferedSalesReturnTempTable	TABLE (Result INT)
	DECLARE @BankCardTicketEntryTemp		TABLE (Result INT)
	DECLARE @DeliveryFeeTicketEntryTemp		TABLE (Result INT)
	DECLARE @DownPaymentTicketEntryTemp		TABLE (Result INT)
	DECLARE @ReceiveReturnCouponEntryTemp	TABLE (Result INT)
	DECLARE @ReceiveReturnCardEntryTemp		TABLE (Result INT)
	DECLARE @PayReturnCouponEntryTemp		TABLE (Result INT)
	DECLARE @PayReturnCardEntryTemp			TABLE (Result INT)
	DECLARE @GCCTaxSaleTicketEntryTemp		TABLE (Result INT)
	DECLARE @GCCTaxReSaleTicketEntryTemp	TABLE (Result INT)
	DECLARE @result							INT      = -2
	DECLARE @closeDate						DATETIME = NULL
	DECLARE @closeDateUTC					DATETIME = NULL
	IF(@posGuid IS NULL OR @shiftGuid IS NULL OR (SELECT CloseDate FROM POSSDShift000 WHERE [GUID] = @shiftGuid) IS NOT NULL)
	BEGIN
		SET @result =-1
		SELECT @result AS Result, @closeDate AS CloseDate
	    RETURN
	END
	DECLARE @saleBillType			                  UNIQUEIDENTIFIER = (SELECT SaleBillTypeGUID  FROM POSSDStation000 WHERE [GUID] = @posGuid)
	DECLARE @saleReturnBillType			              UNIQUEIDENTIFIER = (SELECT SaleReturnBillTypeGUID FROM POSSDStation000 WHERE [GUID] = @posGuid)
	DECLARE	@ShiftControlAccountGuid                  UNIQUEIDENTIFIER = (SELECT ShiftControlGUID FROM POSSDStation000 WHERE [GUID] = @posGuid)
	DECLARE	@FloatCashAccountGuid	                  UNIQUEIDENTIFIER = (SELECT ContinuesCashGUID FROM POSSDStation000 WHERE [GUID] = @posGuid)
	DECLARE	@dataTransferMode		                  INT = (SELECT DataTransferMode FROM POSSDStation000 WHERE [GUID] = @posGuid)
	DECLARE	@salebillGenerateSuccess	              INT
	DECLARE	@saleReturnbillGenerateSuccess	          INT
	DECLARE	@externalOperationEntryGenerateSuccess    BIT
	DECLARE	@defferedSalesEntryGenerateSuccess		  BIT
	DECLARE	@defferedSalesRetEntryGenerateSuccess	  BIT
	DECLARE @BankCardTicketEntryGeneratedSuccess      INT
	DECLARE @DeliveryFeeTicketEntryGeneratedSuccess   INT
	DECLARE @DownPaymentTicketEntryCeneratedSuccess	  INT
	DECLARE @GCCTaxSaleTicketEntryGeneratedSuccess	  INT
	DECLARE @GCCTaxReSaleTicketEntryGeneratedSuccess  INT
	DECLARE @ReceiveReturnCouponEntryGeneratedSuccess INT
	DECLARE @ReceiveReturnCardEntryGeneratedSuccess   INT
	DECLARE @PayReturnCouponEntryGeneratedSuccess     INT
	DECLARE @PayReturnCardEntryGeneratedSuccess		  INT
	DECLARE	@IsMatchingShiftControlAccount		      BIT
	DECLARE	@IsMatchingFloatCashAccount			      BIT
	DECLARE	@IsThereMovesOutsidePos				      BIT
	DECLARE	@isRolledBack						      BIT
	DECLARE	@TransactionName					      NVARCHAR(50) = 'CloseShiftTransaction'
	DECLARE	@TicketsAndExternalOperationsTransaction  NVARCHAR(50) = 'ticketsAndExternalOperationsTransaction'
	DECLARE @IsGCCTaxSystemEnable					  BIT = ISNULL((SELECT Value FROM op000 WHERE Name = 'AmnCfg_EnableGCCTaxSystem'), 0)
	SET @isRolledBack = 0;
    
	-----Check bill types for GCC
	IF(@IsGCCTaxSystemEnable = 1)
	BEGIN
		IF((SELECT [dbo].fnPOSSD_Station_CheckBillTypesForGCCTax(@posGuid)) = 0)
		BEGIN
			SET @result = 5
			SET @closeDate = GETDATE()
			SELECT @result AS Result, @closeDate AS CloseDate
			EXEC prcConnections_SetIgnoreWarnings 0
			RETURN;
		END
	END
	  
	IF((SELECT [dbo].fnPOSSD_Shift_CheckDeliveryFeeAccountIsSet(@shiftGuid)) = 0)
	BEGIN
		SET @result = 6
		SET @closeDate = GETDATE()
		SELECT @result AS Result, @closeDate AS CloseDate
		EXEC prcConnections_SetIgnoreWarnings 0
		RETURN;
	END
	DECLARE @PostGeneratedBill INT 
	EXEC prcPOSSD_Shift_CheckSerialNumbers @shiftGuid, @PostGeneratedBill OUTPUT
	BEGIN TRANSACTION @TransactionName
		--Generate external operations
        EXEC prcPOSSD_Shift_GenerateCloseShiftExternalOperations @posGuid, @shiftGuid, @externalOperationCloseShiftNote, @centralBoxReceiptNoNote, @deviceID
       
	   	--Generate sales return Bill
		EXEC  prcPOSSD_Shift_GenerateTicketsBill @saleReturnBillType, @shiftGuid, 2, 1, @saleReturnbillGenerateSuccess output
	    --Generate sales Bill
		EXEC  prcPOSSD_Shift_GenerateTicketsBill @saleBillType, @shiftGuid, 0, @PostGeneratedBill, @salebillGenerateSuccess output
      
        --Generate External Operation Entry
        INSERT INTO @externalOperationTempTable
			EXEC prcPOSSD_Shift_GenerateExternalOperationsEntry @shiftGuid
      
        --Generate deffered Entry for sales tickets
        INSERT INTO @defferedSalesTempTable
			EXEC prcPOSSD_Shift_GenerateTicketsEntry @shiftGuid, 0
		--Generate deffered Entry for sales return tickets
        INSERT INTO @defferedSalesReturnTempTable
			EXEC prcPOSSD_Shift_GenerateTicketsEntry @shiftGuid, 2
		
		--Generate Bank Ticket Entry
		INSERT INTO @BankCardTicketEntryTemp
			EXEC prcPOSSD_Shift_GenerateBankCardsEntry @shiftGuid	
		INSERT INTO @DeliveryFeeTicketEntryTemp
			EXEC prcPOSSD_Shift_GenerateDeliveryFeeEntry @shiftGuid	
		INSERT INTO @DownPaymentTicketEntryTemp
			EXEC prcPOSSD_Shift_GenerateDownPaymentEntry @shiftGuid
			
		--GCTaxC Ticket Entry
		IF(@IsGCCTaxSystemEnable = 1)
		BEGIN
			INSERT INTO @GCCTaxSaleTicketEntryTemp
			EXEC prcPOSSD_Shift_GenerateGCCTaxEntry @shiftGuid, 0
			INSERT INTO @GCCTaxReSaleTicketEntryTemp
			EXEC prcPOSSD_Shift_GenerateGCCTaxEntry @shiftGuid, 2
		END
		--Generate Receive Return Coupon Entry
		INSERT INTO @ReceiveReturnCouponEntryTemp
			EXEC prcPOSSD_Shift_GenerateReturnCouponEntry @shiftGuid, 0, 0
		--Generate Receive Return Card Entry
		INSERT INTO @ReceiveReturnCardEntryTemp
			EXEC prcPOSSD_Shift_GenerateReturnCouponEntry @shiftGuid, 1, 0
		--Generate Pay Return Coupon Entry
		INSERT INTO @PayReturnCouponEntryTemp
			EXEC prcPOSSD_Shift_GenerateReturnCouponEntry @shiftGuid, 0, 1
		--Generate Pay Return Card Entry
		INSERT INTO @PayReturnCardEntryTemp
			EXEC prcPOSSD_Shift_GenerateReturnCouponEntry @shiftGuid, 1, 1
       
        SELECT @externalOperationEntryGenerateSuccess    = Result FROM @externalOperationTempTable
        SELECT @defferedSalesEntryGenerateSuccess        = Result FROM @defferedSalesTempTable
		SELECT @defferedSalesRetEntryGenerateSuccess     = Result FROM @defferedSalesReturnTempTable
		SELECT @BankCardTicketEntryGeneratedSuccess      = Result FROM @BankCardTicketEntryTemp
		SELECT @DeliveryFeeTicketEntryGeneratedSuccess   = Result FROM @DeliveryFeeTicketEntryTemp
		SELECT @DownPaymentTicketEntryCeneratedSuccess	 = Result FROM @DownPaymentTicketEntryTemp
		SELECT @ReceiveReturnCouponEntryGeneratedSuccess = Result FROM @ReceiveReturnCouponEntryTemp
		SELECT @ReceiveReturnCardEntryGeneratedSuccess   = Result FROM @ReceiveReturnCardEntryTemp
		SELECT @PayReturnCouponEntryGeneratedSuccess     = Result FROM @PayReturnCouponEntryTemp
		SELECT @PayReturnCardEntryGeneratedSuccess		 = Result FROM @PayReturnCardEntryTemp
		SELECT @GCCTaxSaleTicketEntryGeneratedSuccess   = CASE @IsGCCTaxSystemEnable WHEN 1 THEN Result ELSE 1 END FROM @GCCTaxSaleTicketEntryTemp
		SELECT @GCCTaxReSaleTicketEntryGeneratedSuccess = CASE @IsGCCTaxSystemEnable WHEN 1 THEN Result ELSE 1 END FROM @GCCTaxReSaleTicketEntryTemp
		IF ( @salebillGenerateSuccess = 0 OR @saleReturnbillGenerateSuccess = 0 
			OR @externalOperationEntryGenerateSuccess = 0 OR @defferedSalesEntryGenerateSuccess = 0 
			OR @defferedSalesRetEntryGenerateSuccess = 0
			OR @BankCardTicketEntryGeneratedSuccess = 0
			OR @DeliveryFeeTicketEntryGeneratedSuccess = 0
			OR @DownPaymentTicketEntryCeneratedSuccess = 0
			OR @ReceiveReturnCouponEntryGeneratedSuccess = 0
			OR @ReceiveReturnCardEntryGeneratedSuccess = 0
			OR @PayReturnCouponEntryGeneratedSuccess = 0
			OR @PayReturnCardEntryGeneratedSuccess = 0
			OR @GCCTaxSaleTicketEntryGeneratedSuccess = 0
			OR @GCCTaxReSaleTicketEntryGeneratedSuccess = 0 ) 
        BEGIN
                SET @result = 0
                SET @isRolledBack = 1
                ROLLBACK TRANSACTION @TransactionName;
        END 
              ELSE
              BEGIN
                     EXEC prcPOSSD_Shift_ControlAccountIsMatching @shiftGuid, 1, @IsMatchingShiftControlAccount OUTPUT
                     EXEC prcPOSSD_Shift_ControlAccountIsMatching @shiftGuid, 2, @IsMatchingFloatCashAccount OUTPUT
                     EXEC prcPOSSD_Station_IsThereOutsideMovesOnAccount @posGuid, @IsThereMovesOutsidePos OUTPUT
                       
                     SET @closeDate = GETDATE();
					 SET @closeDateUTC = GETUTCDATE();
                     IF (@IsMatchingShiftControlAccount = 0 AND @IsThereMovesOutsidePos = 0 AND @IsForcedClose = 0)
                     BEGIN
						 SET @result = 3
						 SET @isRolledBack = 1
						 ROLLBACK TRANSACTION @TransactionName;
                     END
                     ELSE IF ((@IsMatchingShiftControlAccount = 0 OR @IsMatchingFloatCashAccount = 0) AND @IsThereMovesOutsidePos = 1)
                     BEGIN
						 UPDATE POSSDShift000 SET CloseDate = @closeDate, CloseShiftNote= @closeShiftNote, CloseDateUTC = @closeDateUTC  WHERE [GUID] = @shiftGuid
						 SET @result =  2
						 COMMIT TRANSACTION @TransactionName;
                     END
                     ELSE IF(@IsMatchingShiftControlAccount = 1)
                     BEGIN
						 UPDATE POSSDShift000 SET CloseDate = @closeDate, CloseShiftNote= @closeShiftNote , CloseDateUTC = @closeDateUTC WHERE [GUID] = @shiftGuid
						 SET @result = 1     
						 COMMIT TRANSACTION @TransactionName;
                     END
					 ELSE IF (@IsMatchingShiftControlAccount = 0 AND @IsThereMovesOutsidePos = 0 AND @IsForcedClose = 1)
                     BEGIN
						 UPDATE POSSDShift000 SET CloseDate = @closeDate, CloseShiftNote= @closeShiftNote , CloseDateUTC = @closeDateUTC WHERE [GUID] = @shiftGuid
						 SET @result = 1     
						 COMMIT TRANSACTION @TransactionName;
                     END
					 IF(@PostGeneratedBill = 0 AND @result = 1)
					 BEGIN
					   SET @result = 4
					 END
              END
      
 
    --on offline mode
	IF @isRolledBack = 1 AND @dataTransferMode = 1
	BEGIN
		BEGIN TRANSACTION @TicketsAndExternalOperationsTransaction
 
		DELETE ticketItems
		FROM [dbo].[POSSDTicketItem000] ticketItems
		INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = ticketItems.TicketGUID
		WHERE ShiftGuid = @shiftGuid
 
        DELETE currencyPayments
		FROM [dbo].[POSSDTicketCurrency000] currencyPayments
		INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = currencyPayments.TicketGuid
		WHERE ShiftGuid = @shiftGuid
		 
        DELETE bankCardPayments
		FROM [dbo].[POSSDTicketBankCard000] bankCardPayments
		INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = bankCardPayments.TicketGuid
		WHERE ShiftGuid = @shiftGuid
		DELETE [dbo].[POSSDTicket000] WHERE  [ShiftGUID] = @shiftGuid
		DELETE [dbo].[POSSDExternalOperation000] where [ShiftGUID] = @shiftGuid
 
		COMMIT TRANSACTION @TicketsAndExternalOperationsTransaction
	END
      
       SELECT @result AS Result, @closeDate AS CloseDate
	   
	   EXEC prcConnections_SetIgnoreWarnings 0	   
END
#################################################################
#END 