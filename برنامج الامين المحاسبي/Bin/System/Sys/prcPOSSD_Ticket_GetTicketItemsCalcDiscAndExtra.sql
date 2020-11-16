################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_GetTicketItemsCalcDiscAndExtra
-----------------------------------------  
	@TicketsType INT = 0 -- 0: Sales, 1: Purchases, 2: ReturnedSales, 3: Returned Purchases  
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	SELECT 
	  ticketItems.[Guid],
	  TicketGuid,
		(CASE ticketItems.IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) 
	  * (CASE ticketItems.SpecialOfferGUID WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty))) ELSE ( ( Value / Qty ) * ticketItems.SpecialOfferQty - (PresentQty * (( Value / Qty ) * SpecialOfferQty/SpecialOfferQty))) END) / 100 END) 
	  + (PresentQty * (CASE ticketItems.SpecialOfferGUID WHEN 0x0 THEN (Value/Qty) ELSE (( Value / Qty )  * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty) END) )                                                                 AS ValueToDiscount,

	  (CASE ticketItems.IsAdditionPercentage WHEN 0 THEN ISNULL(AdditionValue, 0) ELSE ISNULL(AdditionValue, 0) * Value / 100 END)															 AS ValueToAdd,

		(CASE ticketItems.SpecialOfferGUID WHEN 0x0 THEN Value ELSE ( Value / Qty ) * ticketItems.SpecialOfferQty END) 
	  - (CASE ticketItems.IsDiscountPercentage WHEN 0 THEN ISNULL(DiscountValue, 0) ELSE ISNULL(DiscountValue, 0) * (CASE ticketItems.SpecialOfferGUID WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty))) ELSE (( Value / Qty ) * ticketItems.SpecialOfferQty - (PresentQty * (( Value / Qty ) * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty))) END) / 100 END) 
	  + (PresentQty * (CASE ticketItems.SpecialOfferGUID WHEN 0x0 THEN (Value/Qty) ELSE (( Value / Qty ) * ticketItems.SpecialOfferQty/ticketItems.SpecialOfferQty) END) )
	  + (CASE ticketItems.IsAdditionPercentage WHEN 0 THEN ISNULL(AdditionValue, 0) ELSE ISNULL(AdditionValue, 0) * Value / 100 END)														 AS ValueAfterCalc,

	  ItemShareOfTotalDiscount,

	  ItemShareOfTotalAddition

	INTO 
		#TicketItemWithCalcValue
	FROM 
		POSSDTicketItem000 ticketItems
		INNER JOIN POSSDTicket000 ticket ON ticket.[GUID] = ticketItems.[TicketGUID]
	WHERE 
		ticket.[Type] = @TicketsType
		AND ticketItems.Qty <> 0


	SELECT TicketGuid, 
		   SUM(ValueToDiscount) AS ItemsTotalDiscount,
		   SUM(ValueToAdd)		AS ItemsTotalAddition
	INTO 
		#TotalsItemDiscAndExtra
	FROM 
		#TicketItemWithCalcValue
	GROUP BY 
		TicketGuid


	SELECT TicketGuid, 
		   (CASE T.IsDiscountPercentage WHEN 0 THEN ISNULL(T.DiscValue,  0) ELSE ISNULL(TIDE.ItemsTotalDiscount, 0) * ISNULL(T.DiscValue,  0) / 100 END) TotalDiscount,
		   (CASE T.IsAdditionPercentage WHEN 0 THEN ISNULL(T.AddedValue, 0) ELSE ISNULL(TIDE.ItemsTotalAddition, 0) * ISNULL(T.AddedValue, 0) / 100 END) TotalAddition
	INTO 
		#TotalDiscAndExtra
	FROM 
		POSSDTicket000 T 
		INNER JOIN #TotalsItemDiscAndExtra TIDE ON T.[GUID] = TIDE.TicketGuid
	WHERE 
		T.[Type] = @TicketsType


	SELECT 
		TICV.[Guid], TICV.TicketGuid, TICV.ValueToDiscount, TICV.ValueToAdd, TICV.ValueAfterCalc,
	   --CASE TIDE.ItemsTotalDiscount WHEN 0 THEN 0 ELSE TDE.TotalDiscount * TICV.ValueAfterCalc / TIDE.ItemsTotalDiscount END						 AS totalDiscount,
	   TICV.ItemShareOfTotalDiscount																												 AS totalDiscount,
	   TICV.ValueToDiscount																															 AS ItemDiscount,
	  --(CASE TIDE.ItemsTotalDiscount WHEN 0 THEN 0 ELSE TDE.TotalDiscount * TICV.ValueAfterCalc / TIDE.ItemsTotalDiscount END) + TICV.ValueToDiscount AS Discount
	   TICV.ItemShareOfTotalDiscount + TICV.ValueToDiscount																							 AS Discount,
   
   
	   --CASE TIDE.ItemsTotalAddition WHEN 0 THEN 0 ELSE TDE.TotalAddition * TICV.ValueAfterCalc / TIDE.ItemsTotalAddition END					     AS totalAddition,
	   TICV.ItemShareOfTotalAddition																												 AS totalAddition,
	   TICV.ValueToAdd																															     AS ItemAddition,
	  --(CASE TIDE.ItemsTotalAddition WHEN 0 THEN 0 ELSE TDE.TotalAddition * TICV.ValueAfterCalc / TIDE.ItemsTotalAddition END) + TICV.ValueToAdd      AS Addition
	   TICV.ItemShareOfTotalAddition + TICV.ValueToAdd																								 AS Addition

	FROM	  
		#TicketItemWithCalcValue TICV
		LEFT JOIN #TotalsItemDiscAndExtra TIDE ON TICV.TicketGuid = TIDE.TicketGuid
		LEFT JOIN #TotalDiscAndExtra TDE	   ON TICV.TicketGuid = TDE.TicketGuid 
#################################################################
#END
