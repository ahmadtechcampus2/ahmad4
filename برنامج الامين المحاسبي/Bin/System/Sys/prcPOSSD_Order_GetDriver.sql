################################################################################
CREATE PROCEDURE prcPOSSD_Order_GetDriver
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER,
	@DriverState		INT -- 0: all drivers, 1: only available
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

	DECLARE @Drivers TABLE
	(
	    [GUID] UNIQUEIDENTIFIER,
        Number INT,
        Name NVARCHAR(250),
        LatinName NVARCHAR(250),
        ExtraAccGUID UNIQUEIDENTIFIER,
        ExtraAccName NVARCHAR(250),
        ExtraAccLatinName NVARCHAR(250),
        ExtraAccCode NVARCHAR(250),
        MinusAccGUID UNIQUEIDENTIFIER,
        MinusAccName NVARCHAR(250),
        MinusAccLatinName NVARCHAR(250),
        MinusAccCode NVARCHAR(250),
        Mobile NVARCHAR(50),
        Email NVARCHAR(250),
        [Address] NVARCHAR(1000),
        MinusLimitValue FLOAT,
        ReceiveAccGUID UNIQUEIDENTIFIER,
        ReceiveAccName NVARCHAR(250),
        ReceiveAccLatinName NVARCHAR(250),
        ReceiveAccCode NVARCHAR(250),
        OrderState INT,
        OrderCount INT
	)
	
	INSERT INTO @Drivers
	SELECT
		D.[GUID]							        AS [GUID],
		D.Number									AS Number,
		D.Name										AS Name,
		D.LatinName									AS LatinName,
		D.ExtraAccountGUID							AS ExtraAccGUID,
		ExtraAcc.Name								AS ExtraAccName,
		ExtraAcc.LatinName							AS ExtraAccLatinName,
		ExtraAcc.Code								AS ExtraAccCode,
		D.MinusAccountGUID							AS MinusAccGUID,
		MinusAcc.Name								AS MinusAccName,
		MinusAcc.LatinName							AS MinusAccLatinName,
		MinusAcc.Code								AS MinusAccCode,
		D.Mobile									AS Mobile,
		D.Email										AS Email,
		D.[Address]									AS [Address],
		D.MinusLimitValue							AS MinusLimitValue,
		D.ReceiveAccountGUID						AS ReceiveAccGUID,
		ReceiveAcc.Name								AS ReceiveAccName,
		ReceiveAcc.LatinName						AS ReceiveAccLatinName,
		ReceiveAcc.Code								AS ReceiveAccCode,
		0											AS OrderState,
		0											AS OrderCount 
	
	FROM 
		POSSDDriver000 D
		INNER JOIN POSSDStationDrivers000 SD ON D.[GUID] = SD.DriverGUID
		LEFT JOIN ac000 ExtraAcc ON D.ExtraAccountGUID = ExtraAcc.[GUID]
		LEFT JOIN ac000 MinusAcc ON D.MinusAccountGUID = MinusAcc.[GUID]
		LEFT JOIN ac000 ReceiveAcc ON D.ReceiveAccountGUID = ReceiveAcc.[GUID]

	WHERE 
		SD.StationGUID = @StationGuid
		AND (D.IsWorking = 1)
	ORDER BY
		D.Number 

	IF(@DriverState = 0)
	BEGIN
		SELECT * FROM @Drivers
		RETURN
	END


	SELECT 
		DISTINCT D.*	
	FROM 
		@Drivers D
		LEFT JOIN POSSDTicketOrderInfo000 OI ON D.[GUID] = OI.DriverGUID
		LEFT JOIN POSSDTicket000 T ON T.[GUID] = OI.TicketGUID
	WHERE 
		T.[State] in (5, 6)
	ORDER BY
		D.Number 
#################################################################
#END
