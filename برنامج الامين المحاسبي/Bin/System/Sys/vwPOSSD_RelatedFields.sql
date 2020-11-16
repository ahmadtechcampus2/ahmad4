##################################################################################
CREATE View vwPOSSDSpecialOfferFields
AS
SELECT [GUID]
      ,[Number]
      ,[Name]
      ,[LatinName]
      ,CASE WHEN  [Type] = 1 THEN  [dbo].[fnStrings_get]('POSSD\DISCOUNT ',           [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 2 THEN   [dbo].[fnStrings_get]('POSSD\BOGO ',              [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 3 THEN   [dbo].[fnStrings_get]('POSSD\SLIDE ',             [dbo].[fnConnections_getLanguage]())
				WHEN [Type] = 4 THEN   [dbo].[fnStrings_get]('POSSD\BOGSE ',          [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 5 THEN   [dbo].[fnStrings_get]('POSSD\BUNDLE ',			  [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 6 THEN   [dbo].[fnStrings_get]('POSSD\SXGD ',			  [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 7 THEN   [dbo].[fnStrings_get]('POSSD\SGP ',				  [dbo].[fnConnections_getLanguage]())
		     WHEN [Type] = 8 THEN  [dbo].[fnStrings_get]('POSSD\ALLSPECIALOFFERS ',   [dbo].[fnConnections_getLanguage]())
		 END AS SpecialOfferTypeText
	  ,[Discount] 
      ,[IsDiscountPercentage]
      ,[MaxQty]
      ,[ExpireQty]
	  ,[OfferQty]
      ,[GrantQty]
      ,[StartDate]
	  ,[EndDate]
	  ,FORMAT(StartTime, 'hh:mm tt')	AS StartTime 
	  ,FORMAT(EndTime, 'hh:mm tt')		AS EndTime
      ,[OfferSpentAmount]
	  ,CASE 
			WHEN (
					     Saturday  = 1 AND  Sunday =1 AND   Monday  = 1  
					AND  Tuesday= 1 AND  Wednesday= 1 AND  Thursday= 1 
					AND  Friday = 1
				 ) 
				OR
				(
					 Saturday  = 0 AND  Sunday = 0 AND   Monday  = 0 
					AND  Tuesday= 0 AND  Wednesday= 0 AND  Thursday= 0 
					AND  Friday = 0
				)  
		THEN [dbo].[fnStrings_get]('POSSD\ALLDAYSOFWEEK ',   [dbo].[fnConnections_getLanguage]())
		 ELSE 
			CONCAT
			(	CASE      WHEN   Saturday = 1 THEN [dbo].[fnStrings_get]('POSSD\SATURDAY ',          [dbo].[fnConnections_getLanguage]())+' ' END,
				CASE	  WHEN  Sunday  = 1 THEN [dbo].[fnStrings_get]('POSSD\SUNDAY ',            [dbo].[fnConnections_getLanguage]())+' ' END,
				CASE	  WHEN  Monday  = 1 THEN [dbo].[fnStrings_get]('POSSD\MONDAY ',            [dbo].[fnConnections_getLanguage]())+' ' END,
				CASE	  WHEN  Tuesday = 1 THEN [dbo].[fnStrings_get]('POSSD\TUESDAY ',           [dbo].[fnConnections_getLanguage]())+' ' END,
				CASE	  WHEN  Wednesday= 1 THEN [dbo].[fnStrings_get]('POSSD\WEDNESDAY ',         [dbo].[fnConnections_getLanguage]())+' ' END,
				CASE	  WHEN  Thursday= 1 THEN [dbo].[fnStrings_get]('POSSD\THURSDAY ',          [dbo].[fnConnections_getLanguage]())+' '	END,
				CASE	  WHEN  Friday = 1  THEN [dbo].[fnStrings_get]('POSSD\FRIDAY ',            [dbo].[fnConnections_getLanguage]())+' ' END)
		  END
               AS SpecialOfferWorkDays
	  
  FROM vwPOSSDSpecialOffer
##################################################################################
CREATE View vwPOSSDStationInfoFields
AS
SELECT
              station.GUID                                                         AS StationGUID, 
              ticketItem.Qty                                                         AS Qty,
              ticketItem.SpecialOfferQty                               AS SpecialOfferQty,
              CASE ticketItem.SpecialOfferQty WHEN 0 THEN 0 
                                  ELSE  (CASE ticketItem.IsDiscountPercentage 
                       WHEN 0 THEN ISNULL(DiscountValue, 0)
                       ELSE ISNULL(DiscountValue, 0) * (CASE ticketItem.SpecialOfferGUID 
                                                                                         WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty)))
                                                                                         ELSE (Price * ticketItem.SpecialOfferQty - (PresentQty * (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)))
                                                                               END) / 100
          END) + (PresentQty * (CASE ticketItem.SpecialOfferGUID
                                                              WHEN 0x0 THEN (Value/Qty)
                                                              ELSE (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)
                                                 END)) / ticketItem.SpecialOfferQty END  AS UnitDiscount,
              (CASE ticketItem.IsDiscountPercentage 
                       WHEN 0 THEN ISNULL(DiscountValue, 0)
                       ELSE ISNULL(DiscountValue, 0) * (CASE ticketItem.SpecialOfferGUID 
                                                                                         WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty)))
                                                                                         ELSE (Price * ticketItem.SpecialOfferQty - (PresentQty * (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)))
                                                                               END) / 100
          END) + (PresentQty * (CASE ticketItem.SpecialOfferGUID
                                                              WHEN 0x0 THEN (Value/Qty)
                                                              ELSE (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)
                                                 END))                                          AS Discount,
       ( ((CASE ticketItem.IsDiscountPercentage 
                       WHEN 0 THEN ISNULL(DiscountValue, 0)
                       ELSE ISNULL(DiscountValue, 0) * (CASE ticketItem.SpecialOfferGUID 
                                                                                         WHEN 0x0 THEN (Value - (PresentQty * (Value/Qty)))
                                                                                         ELSE (Price * ticketItem.SpecialOfferQty - (PresentQty * (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)))
                                                                               END) / 100
          END) + (PresentQty * (CASE ticketItem.SpecialOfferGUID
                                                              WHEN 0x0 THEN (Value/Qty)
                                                              ELSE (Price * ticketItem.SpecialOfferQty/ticketItem.SpecialOfferQty)
                                                 END))) / (ticketItem.Price * ticketItem.Qty ) )          AS DiscountPercentage
         
  FROM  POSSDStation000 station 
                     INNER JOIN POSSDShift000 sh ON sh.StationGUID = station.GUID
                     INNER JOIN POSSDShiftDetail000 shiftDetails ON shiftDetails.ShiftGUID = sh.GUID
                     INNER JOIN POSSDTicket000 ticket ON Ticket.ShiftGUID = shiftDetails.ShiftGUID
                     INNER JOIN POSSDTicketItem000 ticketItem ON ticketItem.TicketGUID = Ticket.GUID
##################################################################################
#END