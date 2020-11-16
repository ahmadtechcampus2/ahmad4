################################################################################
CREATE PROCEDURE prcPOSSD_SerialNumber_GetSerialNumber
-- Params -------------------------------   
	@POSGuid				UNIQUEIDENTIFIER,
	@ShiftGuid			    UNIQUEIDENTIFIER,
	@TicketGuid             UNIQUEIDENTIFIER,
	@EmployeeGuid		    UNIQUEIDENTIFIER,
	@TicketType				INT,
	@StartDate				DATETIME,
	@EndDate				DATETIME
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	

	SELECT 
		T.[GUID]			AS TicketGUID,
		SH.Code				AS ShiftCode,
		T.[Type]			AS TicketType,
		T.Code				AS TicketCode,
		T.OpenDate			AS TicketDate,
		TI.MatGUID			AS MaterialGuid,
		SN.SN				AS SerialNumbers,

		S.Code +' - '+ CASE @language WHEN 0 THEN S.Name 
									  ELSE CASE S.LatinName WHEN '' THEN S.Name 
															ELSE S.LatinName END END AS  Station,
		
		MT.mtCode +' - '+ CASE @language WHEN 0 THEN MT.mtName 
									  ELSE CASE MT.mtLatinName WHEN '' THEN MT.mtName 
															   ELSE MT.mtLatinName END END AS  Material,

		CASE @language WHEN 0 THEN E.Name
									  ELSE CASE E.LatinName WHEN '' THEN E.Name 
															ELSE E.LatinName END END AS  Employee,

		CAST(ISNULL(CASE @language WHEN 0 THEN CU.CustomerName 
					   ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName 
											 ELSE CU.LatinName END END, ' ') AS NVARCHAR(250)) AS Customer,

		CASE TI.UnitType WHEN 0 THEN MT.mtUnity
						 WHEN 1 THEN MT.mtUnit2
						 WHEN 2 THEN MT.mtUnit3 END AS Unit
		
	FROM 
		POSSDStation000 S
		INNER JOIN POSSDShift000 SH ON S.[GUID] = SH.StationGUID
		INNER JOIN POSSDTicket000 T ON SH.[GUID] = T.ShiftGUID 
		INNER JOIN POSSDTicketItem000 TI ON T.[GUID] = TI.TicketGUID
		INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
		LEFT  JOIN POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
		LEFT  JOIN cu000 CU ON T.CustomerGUID = CU.[GUID]
		LEFT  JOIN vwmt  MT ON TI.MatGUID = MT.mtGUID

	WHERE 
		( S.[GUID]        = @POSGuid      OR @POSGuid      = 0x0 )
	AND ( SH.[GUID]       = @ShiftGuid    OR @ShiftGuid    = 0x0 )
	AND ( SH.EmployeeGUID = @EmployeeGuid OR @EmployeeGuid = 0x0 )
	AND ( T.[GUID]	      = @TicketGuid   OR @TicketGuid   = 0x0 )
	AND ( T.[Type]		  = @TicketType   OR @TicketType   = -1)
	AND ( T.[OpenDate] BETWEEN @StartDate AND @EndDate )
	AND ( T.[State] NOT IN (5, 6, 7, 8) ) 
	ORDER BY 
		T.Code,
		SN.Number
#################################################################
#END
