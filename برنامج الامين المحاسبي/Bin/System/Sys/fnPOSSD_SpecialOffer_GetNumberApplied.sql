################################################################################
CREATE FUNCTION fnPOSSD_SpecialOffer_GetNumberApplied
-- Param ------------------------------------------------
		( @SpecialOfferGuid	UNIQUEIDENTIFIER )
-- Return -----------------------------------------------
RETURNS INT
---------------------------------------------------------
AS
BEGIN

	DECLARE @Result INT = 0
	DECLARE @SpecialOfferType INT = (SELECT [Type] FROM POSSDSpecialOffer000 WHERE [GUID] = @SpecialOfferGuid)



	--============================== DISCOUNT
	IF(@SpecialOfferType = 1)
	BEGIN
		
		SET @Result = (SELECT SUM(TI.SpecialOfferQty)
					   FROM POSSDTicketItem000 TI 
					   INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
					   WHERE TI.SpecialOfferGUID = @SpecialOfferGuid AND T.[State] IN (0, 5, 6, 7))
 
	END

	--============================== SLIDES
	IF(@SpecialOfferType = 3)
	BEGIN

		SET @Result = (SELECT SUM(SpecialOfferQty) 
					   FROM POSSDTicketItem000 TI 
					   INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
					   WHERE TI.SpecialOfferGUID = @SpecialOfferGuid AND (T.[State] IN (0, 5, 6, 7)))

	END

	--============================== BOGO, BOGSE
	IF(@SpecialOfferType = 2 OR @SpecialOfferType = 4)
	BEGIN
		
		SET @Result = ( (SELECT SUM(TI.SpecialOfferQty)
						 FROM POSSDTicket000 T INNER JOIN POSSDTicketItem000 TI ON T.[GUID] = TI.TicketGUID
						 WHERE TI.SpecialOfferGUID = @SpecialOfferGuid AND (T.[State] IN (0, 5, 6, 7)))
					  / (SELECT GrantQty
						 FROM POSSDSpecialOffer000 
						 WHERE [GUID] = @SpecialOfferGuid ) )

	END

	--============================== bundle
	IF(@SpecialOfferType = 5)
	BEGIN
		
		SET @Result = ( (SELECT SUM(TI.SpecialOfferQty)
						 FROM POSSDTicket000 T INNER JOIN POSSDTicketItem000 TI ON T.[GUID] = TI.TicketGUID
						 WHERE TI.SpecialOfferGUID = @SpecialOfferGuid AND (T.[State] IN (0, 5, 6, 7)))
					  / (SELECT SUM(QTY) 
						 FROM POSSDSpecialOfferGroup000 
						 WHERE SpecialOfferGUID = @SpecialOfferGuid AND IsOfferGroup = 0) )
	END


	RETURN @Result

END
################################################################
#END
