#################################################################
CREATE PROCEDURE prcPOSSD_Shift_UncloseShift 
-- Params -------------------------------
	@ShiftGUID UNIQUEIDENTIFIER
-----------------------------------------   
AS
	DECLARE @UserGUID UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	EXEC prcConnections_Add @UserGUID, 0
	
	EXEC prcConnections_SetIgnoreWarnings 1
	BEGIN TRANSACTION 
	
	UPDATE 
		POSSDShift000 
	SET 
		CloseDate = NULL, 
		CloseShiftNote = NULL
	WHERE 
		[GUID] = @ShiftGUID
	
	UPDATE POSSDShiftCashCurrency000 
	SET 
		FloatCash = 0, 
		FloatCashCurVal = 0, 
		CountedCash = 0 ,
		CentralBoxReceiptId = ''
	WHERE 
		ShiftGUID = @ShiftGUID
	
	DELETE FROM POSSDExternalOperation000 
	WHERE 
		ShiftGUID = @ShiftGUID 
		AND 
		GenerateState = 1
	
	DECLARE @posGuid UNIQUEIDENTIFIER = (SELECT TOP 1 StationGUID FROM POSSDShift000 WHERE [GUID] = @ShiftGUID)
	DECLARE @dataTransferMode     INT = (SELECT DataTransferMode FROM POSSDStation000 WHERE [GUID] = @posGuid)
	
	IF (@dataTransferMode = 1) --on offline mode
	BEGIN
		DELETE 
			ticketItems
		FROM 
			[dbo].[POSSDTicketItem000] ticketItems
			INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = ticketItems.TicketGUID
		WHERE 
			ShiftGUID = @ShiftGUID AND tickets.GUID NOT IN (SELECT TicketGUID FROM POSSDTicketReturnCoupon000)
       
	    DELETE currencyPayments
		FROM [dbo].[POSSDTicketCurrency000] currencyPayments
		INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = currencyPayments.TicketGuid
		WHERE ShiftGUID = @ShiftGUID AND tickets.GUID NOT IN (SELECT TicketGUID FROM POSSDTicketReturnCoupon000 )
		 
        DELETE bankCardPayments
		FROM [dbo].[POSSDTicketBankCard000] bankCardPayments
		INNER JOIN [dbo].[POSSDTicket000] tickets ON tickets.GUID = bankCardPayments.TicketGuid
		WHERE ShiftGUID = @ShiftGUID AND tickets.GUID NOT IN (SELECT TicketGUID FROM POSSDTicketReturnCoupon000)
		DELETE [dbo].[POSSDTicket000] WHERE [ShiftGUID] = @ShiftGUID AND GUID NOT IN (SELECT TicketGUID FROM POSSDTicketReturnCoupon000 )
		DELETE [dbo].POSSDExternalOperation000 WHERE [ShiftGUID] = @ShiftGUID 
	END
	
	DECLARE @BillGUID [UNIQUEIDENTIFIER]
	SET @BillGUID = ISNULL((SELECT TOP 1 BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGUID), 0x0)
	
	WHILE @BillGUID != 0x0
	BEGIN 
		EXEC prcBill_Delete @BillGUID
		EXEC prcBill_Delete_Entry @BillGUID
		
		DELETE FROM BillRel000 WHERE BillGUID = @BillGUID
		SET  @BillGUID = ISNULL((SELECT TOP 1 BillGUID FROM BillRel000 WHERE ParentGUID = @ShiftGUID), 0x0)
	END 
	
	DELETE FROM er000 WHERE ParentGuid = @ShiftGUID 
	
	EXEC prcConnections_SetIgnoreWarnings 0	
	COMMIT TRAN
#################################################################
#END 