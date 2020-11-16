#################################################################
CREATE FUNCTION fnPOSSD_Order_IsCollectedFromDriver(@OrderGUID AS UNIQUEIDENTIFIER)
       RETURNS INT
AS BEGIN

	DECLARE @LastCollectFromDriverEventNumber INT
	DECLARE @LastToWaitingEventNumber		  INT
	DECLARE @LastCancelEventNumber			  INT
	
	SET @LastCollectFromDriverEventNumber = (SELECT TOP 1 Number FROM POSSDOrderEvent000 WHERE OrderGUID = @OrderGUID AND [Event] = 12 ORDER BY  Number DESC)

	IF(@LastCollectFromDriverEventNumber IS NULL)
	BEGIN 
		RETURN 0
	END


	SET @LastToWaitingEventNumber = ISNULL((SELECT TOP 1 Number FROM POSSDOrderEvent000 WHERE OrderGUID = @OrderGUID AND [Event] = 7 ORDER BY  Number DESC), 0)
	SET @LastCancelEventNumber    = ISNULL((SELECT TOP 1 Number FROM POSSDOrderEvent000 WHERE OrderGUID = @OrderGUID AND [Event] = 9 ORDER BY  Number DESC), 0)

	IF(@LastCollectFromDriverEventNumber < @LastToWaitingEventNumber OR @LastCollectFromDriverEventNumber < @LastCancelEventNumber)
	BEGIN 
		RETURN 0
	END


    RETURN 1
END
#################################################################
#END 