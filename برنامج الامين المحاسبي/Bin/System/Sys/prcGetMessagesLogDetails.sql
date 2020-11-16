##################################################################################
CREATE PROCEDURE prcGetMessagesLogDetails
	 @UserGUID	UNIQUEIDENTIFIER,
	 @StartDate	DATETIME,
	 @EndDate	DATETIME,
	 @Subject   NVARCHAR(500),
	 @Action	INT
AS
	SET NOCOUNT ON
	
	DECLARE @Send			INT, 
			@PurgeRecycle	INT,
			@PurgeLog		INT
	SET @Send  = 0
	SET @PurgeRecycle = 5
	SET @PurgeLog = 7
	
	
	CREATE TABLE #Result 
	(
		Subject		NVARCHAR(500),
		Action		INT,
		ActionTime	DATETIME,
		LoginName	NVARCHAR(500)
	)
	
	IF (@Subject = '')
	BEGIN
		INSERT INTO #Result
		SELECT  '',
				Action,
				ActionTime,
				LoginName
		FROM	
				UserMessagesLog000 l
				INNER JOIN us000 u ON u.GUID = l.UserGuid
		WHERE
				(Action = @PurgeRecycle OR Action = @PurgeLog)
			AND
				(u.GUID = @UserGUID OR @UserGUID = 0x00)
			AND
				ActionTime BETWEEN @StartDate AND @EndDate	
			AND 
				dbo.fnDoBitwise(@Action, Action) != 0
	END
	
	
	SET @Subject = '%' + @Subject + '%'
	
	INSERT INTO #Result
	SELECT  Subject,
			Action,
			ActionTime,
			LoginName
	FROM	
			UserMessagesLog000 l
			INNER JOIN ReceivedUserMessage000 r ON r.GUID = l.MessageGUID
			INNER JOIN SentUserMessage000 s ON s.GUID = r.ParentGuid
			INNER JOIN us000 u ON u.GUID = l.UserGuid
	WHERE
			(u.GUID = @UserGUID OR @UserGUID = 0x00)
		AND
			ActionTime BETWEEN @StartDate AND @EndDate	
		AND
			Subject LIKE @Subject
		AND 
			dbo.fnDoBitwise(@Action, Action) != 0
		AND 
			((Action = @Send AND u.GUID = s.SenderGuid)
			OR
			(Action NOT IN (@Send, @PurgeRecycle, @PurgeLog) AND u.GUID = r.ReceiverGuid))
			
	SELECT * FROM #Result
##################################################################################
#END