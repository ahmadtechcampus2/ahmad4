################################################################################
CREATE PROCEDURE prcPOSSD_Order_GetEvents
-- Params -----------------------------------------------------
	@OrderGuid		     UNIQUEIDENTIFIER

AS
    SET NOCOUNT ON
---------------------------------------------------------------
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()

	SELECT
		OE.[GUID]						 AS [Guid],
		OE.Number						 AS Number,
		OE.OrderGUID					 AS OrderGuid,
		OE.ShiftGUID					 AS ShiftGuid,
		OE.DriverGUID					 AS DriverGuid,
		OE.UserGUID						 AS UserGuid,
		OE.[Event]					     AS [Event],
		SH.Code							 AS ShiftCode,
		CONVERT(CHAR(5), OE.[Date], 108) AS EventTime,   
		OE.[Date]						 AS [Date],
		OE.Reason						 AS Reason,
		ISNULL(D.Name, '')				 AS DrivName,
		ISNULL(D.LatinName, '')			 AS DrivLatinName,
		ISNULL(E.Name, '')				 AS EmpName,
		ISNULL(E.LatinName, '')			 AS EmpLatinName,

	    ISNULL(CASE @language WHEN 0 THEN D.Name
					   ELSE CASE D.LatinName WHEN '' THEN D.Name 
											 ELSE D.LatinName END END, '') AS DriverName,
		CASE @language WHEN 0 THEN E.Name
					   ELSE CASE E.LatinName WHEN '' THEN E.Name 
											 ELSE E.LatinName END END AS EmployeeName,

		RANK() OVER ( PARTITION BY OE.[Event] ORDER BY OE.Number ) AS [Rank]

	FROM 
		POSSDOrderEvent000 OE
		INNER JOIN POSSDShift000 SH   ON OE.ShiftGUID    = SH.[GUID]
		LEFT  JOIN POSSDDriver000 D   ON OE.DriverGUID   =  D.[GUID]
		LEFT  JOIN POSSDEmployee000 E ON SH.EmployeeGUID =  E.[GUID]

	WHERE 
		OE.OrderGUID = @OrderGuid

	ORDER BY
		OE.Number
#################################################################
#END
