######################################################
CREATE PROC prcRestCanceledOreders 
	@UserGuid	UNIQUEIDENTIFIER = 0x00, 
	@StartDate	DATETIME,
	@EndDate	DATETIME
AS
	SELECT 
		OrderNumber, 
		CancelationDate,
		loginName,
		total,
		CASE 
			WHEN ISNULL(OldState, -1) = -1 THEN -1	-- unknown
			WHEN OldState < 2 THEN 0				-- before prepare 
			WHEN OldState = 2 THEN 1				-- after prepare 
			WHEN OldState <= 4 THEN 2				-- after start prepare 
			ELSE 3									-- after finish prepare
		END AS [State]
	FROM 
		canceledOrdersView
	WHERE 
		((ISNULL(@UserGuid, 0x0) = 0x0) OR (userGuid = @UserGuid))
		AND 
		(CancelationDate BETWEEN @StartDate AND @EndDate)
	GROUP BY 
		ordernumber, CancelationDate, loginName, total, OldState

	SELECT SUM(total) AS summarytotal 
	FROM canceledOrdersView 
	WHERE 
		((ISNULL(@UserGuid, 0x0) = 0x0) OR (userGuid = @UserGuid))
		AND 
		(CancelationDate BETWEEN @StartDate AND @EndDate)
######################################################
#END
