################################################################################
CREATE PROCEDURE prcPOSSD_Coupon_GetExpiredReturnCoupon
-- Params -------------------------------
	@ExpiredReturnCouponGUID UNIQUEIDENTIFIER = 0x0,
	@FromDate			     DATETIME         = '1990-01-01',
	@ToDate 			     DATETIME         = '1990-01-01'
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------

	DECLARE @language            INT = [dbo].[fnConnections_getLanguage]()
	DECLARE @ExpiredReturnCoupon TABLE(ReturnCouponGUID UNIQUEIDENTIFIER)

	IF(@ExpiredReturnCouponGUID = 0x0)
	BEGIN
		INSERT INTO
			@ExpiredReturnCoupon
		SELECT 
			TRC.ReturnCouponGUID 
		FROM 
			POSSDTicketReturnCoupon000 TRC
			INNER JOIN POSSDReturnCoupon000 RC ON TRC.ReturnCouponGUID = RC.[GUID]
		WHERE 
			RC.ExpiryDays <> 0 
			AND	(DATEADD(DAY, RC.ExpiryDays, CAST(RC.TransactionDate AS DATE))) < GETDATE()
			AND (DATEADD(DAY, RC.ExpiryDays, CAST(RC.TransactionDate AS DATE))) BETWEEN @FromDate AND @ToDate
		GROUP BY 
			ReturnCouponGUID
		HAVING 
			COUNT(ReturnCouponGUID) = 1
	END
	ELSE
	BEGIN
		INSERT INTO
			@ExpiredReturnCoupon
		SELECT 
			TRC.ReturnCouponGUID 
		FROM 
			POSSDTicketReturnCoupon000 TRC
			INNER JOIN POSSDReturnCoupon000 RC ON TRC.ReturnCouponGUID = RC.[GUID]
		WHERE 
			RC.ProcessedExpiryCoupon = @ExpiredReturnCouponGUID
	END

---------------------- RESULT ----------------------

	SELECT 
		   ERC.ReturnCouponGUID,
		   T.[GUID] AS TicketGUID,
		   T.[Type] AS TicketType,
		   RC.[Type], 
		   RC.Code, 
		   SRCS.StationGUID, 
		   S.Code +' - '+ CASE @language WHEN 0 THEN S.Name 
										 ELSE CASE S.LatinName WHEN '' THEN S.Name 
															   ELSE S.LatinName END END AS  Station,
		   ISNULL(RC.CustomerGUID, 0x0)	AS CustomerGUID, 
		   ISNULL(CASE @language WHEN 0 THEN CU.CustomerName 
						  ELSE CASE CU.LatinName WHEN '' THEN CU.CustomerName 
												 ELSE CU.LatinName END END, '')   AS  CustomerName,
		   RC.Amount, 
		   RC.TransactionDate, 
		   (DATEADD(DAY, RC.ExpiryDays, RC.TransactionDate)) AS ExpiryDate,
		   RC.ExpiryDays,
		   SRCS.AccountGUID,
		   AC.Code +' - '+ CASE @language WHEN 0 THEN AC.Name 
										  ELSE CASE AC.LatinName WHEN '' THEN AC.Name 
																 ELSE AC.LatinName END END AS  Account,
		   SRCS.ExpireAccountGUID,
		   EAC.Code +' - '+ CASE @language WHEN 0 THEN EAC.Name 
										   ELSE CASE EAC.LatinName WHEN '' THEN EAC.Name 
											   					   ELSE EAC.LatinName END END AS  ExpireAccount

	FROM @ExpiredReturnCoupon ERC
	     LEFT JOIN POSSDReturnCoupon000 RC ON ERC.ReturnCouponGUID = RC.[GUID]
	     LEFT JOIN POSSDStationReturnCouponSettings000 SRCS ON RC.ReturnSettingsGUID = SRCS.[GUID]
	     LEFT JOIN POSSDStation000 S ON SRCS.StationGUID = S.[GUID]
	     LEFT JOIN cu000 CU ON RC.CustomerGUID = CU.[GUID]
	     LEFT JOIN ac000 AC ON SRCS.AccountGUID = AC.[GUID]
	     LEFT JOIN ac000 EAC ON SRCS.ExpireAccountGUID = EAC.[GUID]
		 LEFT JOIN POSSDTicketReturnCoupon000 TR ON TR.ReturnCouponGUID = ERC.ReturnCouponGUID
		 LEFT JOIN POSSDTicket000 T ON TR.TicketGUID = T.[GUID]
#################################################################
#END
