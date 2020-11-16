#################################################################
CREATE FUNCTION fnPOSSD_Shift_GetShiftCash (@shiftGuid AS uniqueidentifier, @currency AS uniqueidentifier = 0x00, @isEquivalent AS BIT = 0)
RETURNS FLOAT
AS 
BEGIN
	DECLARE	@result					FLOAT
	DECLARE	@externalPaymentAmount  FLOAT = 0
	DECLARE	@externalRecievedAmount FLOAT = 0
	DECLARE	@TicketRecievedAmount   FLOAT = 0
	DECLARE	@TicketPaymentAmount    FLOAT = 0
    DECLARE	@TotalTicketAmount		FLOAT = 0
	DECLARE	@currencyVal			FLOAT = 1
    DECLARE @defaultCurrency		UNIQUEIDENTIFIER = (SELECT [dbo].[fnGetDefaultCurr]())
	

	SELECT 
		@TicketRecievedAmount =	CASE @isEquivalent WHEN 0 THEN  ISNULL(SUM(tc.Value), 0) ELSE ISNULL(SUM(tc.Value * tc.CurrencyVal), 0) END
	FROM 
		POSSDTicketCurrency000 tc
		INNER JOIN POSSDTicket000 pt ON tc.TicketGUID = pt.[GUID]
	WHERE 
		pt.ShiftGUID = @shiftGuid AND [State] = 0
		AND ([Type] = 0 OR [Type] = 3) -- Sales or Returned Purchase
		AND (Net >= 0)
		AND (tc.CurrencyGUID = @currency OR @currency = 0x0)
		AND (tc.PayType = 1 OR tc.PayType = 3) -- cash or currencies


	IF (@defaultCurrency = @currency)
	BEGIN
		SET @TicketRecievedAmount = @TicketRecievedAmount + (( SELECT 
																  ISNULL(SUM(T.Net), 0)
		                                                       FROM 
																  POSSDTicket000 T
															   WHERE 
																  T.ShiftGUID = @shiftGuid
																  AND T.[State] = 0 
																  AND T.[type] = 2 
																  AND T.RelatedTo IN (SELECT [GUID] FROM POSSDTicket000 WHERE T.RelationType = 1 OR T.RelationType = 2)) 

														  - (  SELECT  
																  ISNULL(SUM(TC.Value)  , 0)
															   FROM 
																  POSSDTicketCurrency000 TC 
																  INNER JOIN POSSDTicket000 T ON TC.TicketGUID = T.[GUID]
															   WHERE T.ShiftGUID = @shiftGuid
															      AND T.[Type] = 0
															      AND T.Net < 0
															      AND (TC.CurrencyGUID = @currency OR @currency = 0x0)
																  AND (TC.PayType = 1 OR TC.PayType = 3) ) )
	END 
	ELSE
	BEGIN
		SET @TicketRecievedAmount = @TicketRecievedAmount - ISNULL( (SELECT SUM(Value)  
																		  FROM POSSDTicketCurrency000 tc 
																		  INNER JOIN POSSDTicket000 pt 
																		  ON tc.TicketGUID = pt.GUID 
																		  WHERE pt.ShiftGUID = @shiftGuid AND [State] = 0 AND  pt.Net < 0
																		  AND (tc.CurrencyGUID = @currency OR @currency = 0x0)
																		  AND (tc.PayType = 1 OR tc.PayType = 3)), 0)
	END


	SELECT @TicketPaymentAmount =	CASE @isEquivalent WHEN 0 THEN  SUM(tc.Value) ELSE SUM(tc.Value * tc.CurrencyVal) END
									FROM POSSDTicketCurrency000 tc
									INNER JOIN POSSDTicket000 pt ON tc.TicketGUID = pt.GUID									
									WHERE pt.ShiftGUID = @shiftGuid AND [State] = 0
									AND ([Type] = 1 OR [Type] = 2 ) -- Purchase or Returned Sales
									AND (tc.CurrencyGUID = @currency OR @currency = 0x0)
									AND (tc.PayType = 1 OR tc.PayType = 3) -- cash or currencies 
	
	IF(@defaultCurrency = @currency)
		SET @TicketPaymentAmount = ISNULL(@TicketPaymentAmount, 0) +  ISNULL( (SELECT SUM (Net) FROM POSSDTicket000 pt WHERE pt.ShiftGUID = @shiftGuid AND [State] = 0 AND  pt.Type = 2 AND (pt.RelationType = 1 OR pt.RelationType = 2)), 0)
 
	SET @TotalTicketAmount = ISNULL(@TicketRecievedAmount, 0)  - ISNULL(@TicketPaymentAmount, 0)
	
	SELECT @externalPaymentAmount = CASE @isEquivalent WHEN 0 THEN  SUM(Amount) ELSE SUM(Amount * CurrencyValue) END
									FROM POSSDExternalOperation000  WHERE ShiftGUID = @shiftGuid AND IsPayment =1
									AND [State] = 0 AND GenerateState <> 1 AND CurrencyGUID = @currency OR @currency = 0x0
   
	SELECT @externalRecievedAmount = CASE @isEquivalent WHEN 0 THEN  SUM(Amount) ELSE SUM(Amount * CurrencyValue) END
									 FROM POSSDExternalOperation000  WHERE ShiftGuid = @shiftGuid 
									 AND IsPayment = 0 AND [State] = 0 AND GenerateState <> 1 AND CurrencyGUID = @currency OR @currency = 0x0
   
	SET @result = ISNULL (@TotalTicketAmount,0) + ISNULL(@externalRecievedAmount,0) - ISNULL(@externalPaymentAmount,0)
   
	return @result
END
#################################################################
#END 