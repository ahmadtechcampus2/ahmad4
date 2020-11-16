##################################################################################
CREATE PROCEDURE prcGetDeleteMessagesDetails
	 @UserGUID	UNIQUEIDENTIFIER, 
	 @StartDate	DATETIME, 
	 @EndDate	DATETIME 
AS 
SET NOCOUNT ON 
DECLARE @CurrUserGuid	UNIQUEIDENTIFIER, 
		@Admin		INT 
SET @CurrUserGuid = [dbo].[fnGetCurrentUserGUID]()   
SET @Admin = [dbo].[fnIsAdmin](ISNULL(@CurrUserGuid,0x00))
	
IF (ISNULL(@UserGUID,0x00) <> 0x00) AND (@CurrUserGuid <> @UserGUID) AND (@Admin <> 1)
RETURN

IF (ISNULL(@UserGUID,0x00) <> 0x00)
BEGIN
	SELECT	Subject, 
			LoginName, 
			DeleteTime 
	FROM ReceivedUserMessage000 r  
	INNER JOIN SentUserMessage000 u ON u.GUID = r.ParentGuid 
	INNER JOIN us000 us ON us.GUID = r.ReceiverGuid 
	WHERE  
		IsDeleted = 1  AND
		(DeleteTime  BETWEEN @StartDate AND @EndDate)
		AND  
		(ReceiverGuid = @UserGuid) 
END
ELSE
BEGIN
	SELECT	Subject, 
			LoginName, 
			DeleteTime 
	FROM ReceivedUserMessage000 r  
	INNER JOIN SentUserMessage000 u ON u.GUID = r.ParentGuid 
	INNER JOIN us000 us ON us.GUID = r.ReceiverGuid 
	WHERE  
		IsDeleted = 1  AND (DeleteTime  BETWEEN @StartDate AND @EndDate)
		AND  
		( @Admin = 1 OR (@Admin = 0 AND ReceiverGuid = @CurrUserGuid)) 
END
##################################################################################
#END