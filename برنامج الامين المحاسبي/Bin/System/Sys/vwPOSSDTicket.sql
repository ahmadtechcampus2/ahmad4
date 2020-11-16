################################################################################
CREATE VIEW vwPOSSDTicket
AS 
	SELECT  
		[Ticket] .[GUID] AS TicketGUID,
		[Ticket].[Type] as BuType,
		[Ticket].[Note] AS TicketNote,
		[Ticket].[OpenDate],
		[Ticket].[PaymentDate],
		[Ticket].[State] AS TicketStatus,
		[shift].[GUID] AS ShiftGUID,
		[shift].[OpenDate] AS ShiftOpenDate ,
		[shift].CloseDate AS ShiftCloseDate ,
		[POSStation].GUID AS POSStationGUID,
		[cu].[cuGUID] AS CustomerGuid,
		[cu].[cuSecurity] AS CustomerSecurity,
		[cu].[acGUID] AS CustomerGLAccountGUID,
		[cu].acSecurity AS CustomerGLAccountSecurity,
		[Ticket].[Number] AS TicketNumber,
		CASE [Ticket].[Type] 
			WHEN 0 THEN SaleBT.btDefStore -- SALE
			WHEN 1 THEN PurchaseBT.btDefStore -- PURCHASE
			WHEN 2 THEN SaleRBT.btDefStore -- SALES RETURN
			WHEN 3 THEN PurchaseRBT.btDefStore -- PURCHASE RETURN
		ELSE
			0X00
		END  AS biStorePtr,
		CASE [Ticket].[Type] 
			WHEN 0 THEN [Ticket].[LaterValue] -- SALE
			WHEN 1 THEN 0
			WHEN 2 THEN 0 -- SALES RETURN
			WHEN 3 THEN [Ticket].[LaterValue] -- PURCHASE RETURN
		ELSE
			0
		END  AS DEBIT,

		CASE [Ticket].[Type] 
			WHEN 0 THEN 0 -- SALE
			WHEN 1 THEN [Ticket].[LaterValue]
			WHEN 2 THEN [Ticket].[LaterValue] -- SALES RETURN
			WHEN 3 THEN 0 -- PURCHASE RETURN
		ELSE
			0
		END  AS CREDIT,
		1 AS buSecurity,
		'1980-01-01 00:00:00' AS biExpireDate,
		CASE [Ticket].[Type] 
			WHEN 0 THEN -1
			WHEN 1 THEN 1
			WHEN 2 THEN 1
			WHEN 3 THEN -1
		END AS [BuDirection], 

		CASE [Ticket].[Type] 
			WHEN 0 THEN SaleBT.btGUID
			WHEN 1 THEN PurchaseBT.btGUID
			WHEN 2 THEN SaleRBT.btGUID
			WHEN 3 THEN PurchaseRBT.btGUID
		END AS [BuGUID],
	 [Ticket].[Total],
	 [Ticket].[Net],
	 [Ticket].[LaterValue],
	 [Ticket].[CollectedValue]

	FROM [POSSDTicket000] AS [Ticket] 
	INNER JOIN [POSSDShift000]  AS [shift]		ON [shift].[GUID] = [TICKET].ShiftGUID
	LEFT JOIN [vWCuAC]		    AS [cu] ON [CU].[cuGUID] = [Ticket].CustomerGUID 
	LEFT JOIN [POSSDStation000] AS [POSStation]	ON [shift].StationGUID = POSStation.GUID
	LEFT JOIN [vwbt] AS [SaleBT] ON [POSStation].SaleBillTypeGUID = SaleBT.btGUID
	LEFT JOIN [vwbt] AS [SaleRBT] ON [POSStation].SaleReturnBillTypeGUID = SaleRBT.btGUID
	LEFT JOIN [vwbt] AS [PurchaseBT] ON [POSStation].PurchaseBillTypeGUID = PurchaseBT.btGUID
	LEFT JOIN [vwbt] AS [PurchaseRBT] ON [POSStation].PurchaseReturnBillTypeGUID = PurchaseRBT.btGUID
################################################################################
#END
