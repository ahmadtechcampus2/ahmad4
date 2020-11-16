################################################################################
CREATE FUNCTION fnPOSSD_Ticket_GetDiscountAndAddition (@TicketGuid AS UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
	RETURN 

	SELECT 
	  ticketItems.[Guid],

	  TicketGuid,


	  (CASE ticketItems.IsDiscountPercentage 
	  		  WHEN 0 THEN ISNULL(DiscountValue, 0)
	  		  ELSE ISNULL(DiscountValue, 0) * (CASE ticketItems.SpecialOfferGUID 
	  												WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty)))
	  												ELSE (Price * ticketItems.SpecialOfferQty - (PresentQty * (Price * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty)))
	  										   END) / 100
	   END) + (PresentQty * (CASE ticketItems.SpecialOfferGUID
	  								WHEN 0x0 THEN (Value/Qty)
	  								ELSE (Price * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty)
	  						 END)) AS ValueToDiscount,


	  (CASE ticketItems.IsAdditionPercentage 
			WHEN 0 THEN ISNULL(AdditionValue, 0)
			ELSE ISNULL(AdditionValue, 0) * Value / 100 
	   END) AS ValueToAdd,


	  (CASE ticketItems.SpecialOfferGUID 
			WHEN 0x0 THEN Value 
			ELSE Price * ticketItems.SpecialOfferQty 
	   END)  - (CASE ticketItems.IsDiscountPercentage 
						WHEN 0 THEN ISNULL(DiscountValue, 0) 
						ELSE ISNULL(DiscountValue, 0) * (CASE ticketItems.SpecialOfferGUID 
																WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty)))
																ELSE (Price * ticketItems.SpecialOfferQty - (PresentQty * (Price * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty)))
														 END) / 100
				END) + (PresentQty * (CASE ticketItems.SpecialOfferGUID 
											WHEN 0x0 THEN (Value/Qty) 
											ELSE (Price * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty)
									  END)) + (CASE ticketItems.IsAdditionPercentage 
													WHEN 0 THEN ISNULL(AdditionValue, 0)
													ELSE ISNULL(AdditionValue, 0) * Value / 100
											   END) AS ValueAfterCalc,


	  ItemShareOfTotalDiscount,

	  ItemShareOfTotalAddition

	FROM 
		POSSDTicketItem000 ticketItems
		INNER JOIN POSSDTicket000 ticket ON ticket.[GUID] = ticketItems.[TicketGUID]
	WHERE 
		ticket.[GUID] = @TicketGuid
#################################################################
#END
