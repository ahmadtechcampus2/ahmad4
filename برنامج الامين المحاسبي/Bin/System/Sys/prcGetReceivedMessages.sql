##################################################################################
CREATE PROCEDURE prcGetReceivedMessages (@UserGUID UNIQUEIDENTIFIER)
AS
	SET NOCOUNT ON
	
	-- 1. GET MESSAGE FILTER OPTIONS TO THE SPECIFIED USER.
	DECLARE @FilterBySender UNIQUEIDENTIFIER,
			@FilterMessagesSentFrom INT,
			@FilterByRecieverFlag INT,
			@FilterBySenderFlag INT,
			@FilterByType INT,
			@FilterByPriority INT,
			@FilterByStatus INT,
			@SortBy NVARCHAR(500),
			@FilterByAction INT,
			@MatchedUserGUID UNIQUEIDENTIFIER

	SELECT	@MatchedUserGUID = UserGuid,
			@FilterMessagesSentFrom = FilterMessagesSentFrom,
			@FilterByRecieverFlag = FilterByRecieverFlag,
			@FilterBySenderFlag = FilterBySenderFlag,
			@FilterByType = FilterByType,
			@FilterByPriority = FilterByPriority,
			@FilterByStatus = FilterByStatus,
			@SortBy = SortBy,
			@FilterByAction = FilterByAction,
			@FilterBySender = FilterBySender
	FROM UserMessagesProfile000
	WHERE UserGuid = @UserGUID

	IF (@SortBy = '')
		SET @SortBy = 'SendTime desc'
	
	-- 2. STORE ACTION ON MESSAGES
	CREATE TABLE [#ReceivedMessageDetails] 
	(
		[ReceivedMessageGuid]	[UNIQUEIDENTIFIER], 
		[ReceiverGuid]			[UNIQUEIDENTIFIER], 
		[ActionOnMessage]		[INT],
		[MessageType]			[INT]
	)
	INSERT	INTO #ReceivedMessageDetails 
	SELECT	r.GUID, 
			r.ReceiverGuid, 
			(CASE WHEN IsReplied = 1 THEN 1 WHEN IsForwarded = 1 THEN 2 ELSE 0 END), 
			(CASE WHEN ContentType <= 2 -- NOT MISSION 
				  THEN ContentType  
				  ELSE -- EITHER COMPLETED OR IN COMPLETED TASK 
				  (CASE WHEN IsCompleted = 1 THEN 3 
						ELSE 4 END) 
			 END)
	FROM ReceivedUserMessage000 r 
	INNER JOIN SentUserMessage000 s ON s.Guid = r.ParentGuid 
	WHERE 
		(s.SenderGuid = @FilterBySender OR (ISNULL(@FilterBySender, 0x00) = 0x00))
	AND 
		r.ReceiverGuid = @UserGUID
	
	IF (@UserGUID = @MatchedUserGUID)
	BEGIN
		SELECT	R.GUID, 
				SenderGuid, 
				Subject, 
				SendTime, 
				ContentType, 
				S.Flag AS SenderFlag, 
				R.Flag AS ReceiverFlag, 
				Priority, 
				State ReadStatus, 
				IsCompleted, 
				LoginName 
		INTO #Result1 
		FROM ReceivedUserMessage000 R 
		INNER JOIN SentUserMessage000 S ON S.Guid = R.ParentGuid 
		INNER JOIN #ReceivedMessageDetails A ON A.ReceivedMessageGuid = R.GUID 
		INNER JOIN us000 us ON us.GUID = S.SenderGuid 	
		WHERE dbo.fnDoBitwise(@FilterByAction, A.ActionOnMessage) != 0 
		AND   dbo.fnDoBitwise(@FilterByStatus, R.State) != 0 
		AND   dbo.fnDoBitwise(@FilterByType, A.MessageType) != 0 
		AND   (((@FilterByPriority > 0) AND (dbo.fnDoBitwise(@FilterByPriority, Priority - 1) != 0)) OR (@FilterByPriority = 0)) 
		AND   (((@FilterByRecieverFlag > 0) AND (dbo.fnDoBitwise(@FilterByRecieverFlag, R.Flag - 1) != 0)) OR (@FilterByRecieverFlag = 0)) 
		AND   (((@FilterBySenderFlag   > 0) AND (dbo.fnDoBitwise(@FilterBySenderFlag,   S.Flag - 1) != 0)) OR (@FilterBySenderFlag   = 0)) 
		AND   DATEDIFF(DAY,S.SendTime, GETDATE()) <= @FilterMessagesSentFrom
		AND   (@FilterBySender = S.SenderGuid OR @FilterBySender = 0x0)
		AND	  IsDeleted != 1
		
		DECLARE @SelectQuery NVARCHAR(500)
		SET @SelectQuery = 'SELECT * FROM #Result1'					
		IF (@SortBy <> '')
		BEGIN
			SET @SelectQuery = @SelectQuery + ' ORDER BY ' + @SortBy
		END
		EXEC (@SelectQuery)
	END
	ELSE
	BEGIN 
		SELECT	R.GUID, 
				SenderGuid, 
				Subject, 
				SendTime, 
				ContentType, 
				S.Flag AS SenderFlag, 
				R.Flag AS ReceiverFlag, 
				Priority, 
				State ReadStatus, 
				IsCompleted, 
				LoginName 
		FROM ReceivedUserMessage000 R 
		INNER JOIN SentUserMessage000 S ON S.Guid = R.ParentGuid 
		INNER JOIN #ReceivedMessageDetails A ON A.ReceivedMessageGuid = R.GUID 
		INNER JOIN us000 us ON us.GUID = S.SenderGuid 
		WHERE R.IsDeleted != 1	
	END
##################################################################################
#END