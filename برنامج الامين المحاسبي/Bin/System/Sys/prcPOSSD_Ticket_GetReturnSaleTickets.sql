################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_GetReturnSaleTickets
-- Params -------------------------------   
	@TicketGuid             UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	DECLARE @Lang INT = [dbo].[fnConnections_getLanguage]()

	SELECT 
		T.[GUID]		        AS TicketGuid,
		T.Number		        AS TicketNumber,
		SH.Code			        AS ShiftCode,
		T.OpenDate		        AS OpenDate,
		T.PaymentDate           AS PaymentDate,
		T.Net			        AS Net,

			   CASE @Lang WHEN 0 THEN E.Name
						  ELSE CASE E.LatinName WHEN '' THEN E.Name 
												ELSE E.LatinName END END         AS Employee,
		ISNULL(CASE @Lang WHEN 0 THEN CU.CustomerName
						  ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName 
												 ELSE CU.LatinName END END, '')  AS Customer

	FROM 
		POSSDTicket000 T
		INNER JOIN POSSDShift000 SH ON T.ShiftGUID = SH.[GUID]
		LEFT JOIN POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
		LEFT JOIN cu000 CU ON T.CustomerGUID = CU.[GUID]

	WHERE
		T.RelatedFrom = @TicketGuid
	AND (T.RelationType = 2 OR T.RelationType = 3)
	AND (T.[State] = 0)

	ORDER BY 
		T.Number
#################################################################
#END
