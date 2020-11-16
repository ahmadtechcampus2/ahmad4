############################################################## 
CREATE PROC prcSaveOrderMsgReciver 
	@BuGuid			UNIQUEIDENTIFIER,
	@OperationType	INT = 0, -- 0 New, 1 Edit, 2 Cancel, 3 Close, 4 Delete
	@Subject		NVARCHAR(500) = '', 
	@Body			NVARCHAR(4000) = '' 
AS
	SET NOCOUNT ON;
	
	DECLARE @language INT =  ([dbo].[fnConnections_GetLanguage]());
	DECLARE @buDate DATETIME,
	@typeGuid UNIQUEIDENTIFIER,
	@orderNumber NVARCHAR(10)
	
	SELECT @buDate = Date, @typeGuid = TypeGUID, @orderNumber = (CONVERT(nvarchar(10), Number)) FROM bu000 WHERE GUID = @BuGuid
	
	IF NOT EXISTS (SELECT ReciverGUID FROM OMsg000 WHERE ParentGuid = @typeGuid)
		RETURN;

	DECLARE @senderGuid UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM us000 WHERE bAdmin =1 ORDER BY Number)
	DECLARE @currentDate DATETIME  = (SELECT CONVERT(DATE, GETDATE()) )
	DECLARE @msgGuid UNIQUEIDENTIFIER = NEWID()
	DECLARE @opTypeName NVARCHAR(25)
	
	SELECT 
	@opTypeName = CASE @OperationType
						WHEN 0 THEN (dbo.fnStrings_get('AmnOrders\SaveOrderMsgReciver\OpType\New', @language))
						WHEN 1 THEN (dbo.fnStrings_get('AmnOrders\SaveOrderMsgReciver\OpType\Edit', @language))
						WHEN 2 THEN (dbo.fnStrings_get('AmnOrders\SaveOrderMsgReciver\OpType\Cancel', @language))
						WHEN 3 THEN (dbo.fnStrings_get('AmnOrders\SaveOrderMsgReciver\OpType\Close', @language))
						WHEN 4 THEN (dbo.fnStrings_get('AmnOrders\SaveOrderMsgReciver\OpType\Delete', @language))
						ELSE '()'
                     END

	IF(@Subject = '' OR @Body = '')
	BEGIN
		DECLARE @temp NVARCHAR(500) = '',
		@OrderTypeName NVARCHAR (250)

		SELECT @OrderTypeName = (CASE WHEN (@language = 1) AND (LatinName <> '') THEN LatinName ELSE name END)
		FROM bt000 WHERE GUID = @typeGuid

		SET @temp = @OrderTypeName + @orderNumber
		
		IF(@Subject = '')
			SET @Subject = @temp;

		IF(@Body = '')
			SET @Body = @temp
	END

	INSERT INTO SentUserMessage000 
	(GUID, SenderGuid, Subject, Body, SendTime, Priority, ContentType, Flag)
	VALUES 
	(	
		@msgGuid
		,@senderGuid
		,@opTypeName + @Subject
		,@opTypeName + @Body
		,GETDATE()
		,3
		,2
		,1
	)
	
	DECLARE @cursor CURSOR
	DECLARE @receiverGuid UNIQUEIDENTIFIER
	
	SET @cursor = CURSOR FAST_FORWARD FOR 
	SELECT ReciverGUID FROM OMsg000 WHERE ParentGuid = @typeGuid
	
	OPEN @cursor 
	FETCH NEXT FROM @cursor INTO @receiverGuid
	   
	WHILE @@FETCH_STATUS = 0
	BEGIN
			INSERT INTO ReceivedUserMessage000 
			(GUID, ParentGuid, ReceiverGuid, Flag, IsReplied, State, ReplyTime, IsForwarded , ForwardTime, IsDeleted, DeleteTime, IsCompleted, CompletionTime) 
			VALUES 
			(
				NEWID()
				,@MsgGuid
				,@receiverGuid
				,1
				,0
				,0
				,@currentDate
				,0
				,@currentDate
				,0
				,@currentDate
				,0
				,@currentDate
			)
	FETCH NEXT FROM @cursor INTO @receiverGuid
	END
	      
	CLOSE @cursor
	DEALLOCATE @cursor
#################################################################
CREATE PROC prcDistSaveOrderMsgReciver
	@BuGuid					UNIQUEIDENTIFIER,
	@DistributorGuid		UNIQUEIDENTIFIER
AS

	SET NOCOUNT ON;
	
	DECLARE @language INT =  ([dbo].[fnConnections_GetLanguage]());
	DECLARE @typeGuid UNIQUEIDENTIFIER,
	@orderNumber NVARCHAR(10)

	SELECT @typeGuid = TypeGUID, @orderNumber = (CONVERT(nvarchar(10), Number)) FROM bu000 WHERE GUID = @BuGuid
	
	IF NOT EXISTS (SELECT ReciverGUID FROM OMsg000 WHERE ParentGuid = @typeGuid)
		RETURN;

	DECLARE @OrderTypeName NVARCHAR (250),
	@distUnitName NVARCHAR (250)

	SELECT @orderTypeName = (CASE WHEN (@language = 1) AND (LatinName <> '') THEN LatinName ELSE name END)
	FROM bt000 WHERE GUID = @typeGuid

	SELECT @DistUnitName = (CASE WHEN (@language = 1) AND (LatinName <> '') THEN LatinName ELSE name END)
	FROM Distributor000 WHERE GUID = @DistributorGuid

	DECLARE @temp NVARCHAR (500),
	@subject		NVARCHAR(500), 
	@body			NVARCHAR(4000) 
	
	SET @temp = @orderTypeName + @orderNumber

	SET @subject = @temp + ' - ' + (dbo.fnStrings_get('Distribution\AndroidDistribution', @language))
	SET @body = @temp + CHAR(13) + CHAR(10) + (dbo.fnStrings_get('Distribution\DistributionUnit', @language)) + ' : ' + @DistUnitName

	EXEC prcSaveOrderMsgReciver @BuGuid, 0, @Subject, @Body
#################################################################
#END     