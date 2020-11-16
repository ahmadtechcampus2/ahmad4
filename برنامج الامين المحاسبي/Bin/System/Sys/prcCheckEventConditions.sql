################################################################################
CREATE PROCEDURE NSPrcObjectCheckEventConditions
AS 
BEGIN

	SET NOCOUNT ON 

	EXEC NSPrcConnectionsAddAdmin

	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER
	DECLARE @RecvReqMsg NVARCHAR(MAX)
	DECLARE @RecvReqMsgName SYSNAME

	BEGIN TRY
		WHILE (1=1)
		BEGIN

			BEGIN TRANSACTION;

			WAITFOR
			( RECEIVE TOP(1)
				@RecvReqDlgHandle = conversation_handle,
				@RecvReqMsg = message_body,
				@RecvReqMsgName = message_type_name
			  FROM BillCheckEventConditionsQueue
			), TIMEOUT 5000;

			IF (@@ROWCOUNT = 0)
			BEGIN
			  ROLLBACK TRANSACTION;
			  BREAK;
			END

			IF @RecvReqMsgName = N'DEFAULT'
			BEGIN

				DECLARE @xmlMessage XML
				DECLARE @objectGuid	UNIQUEIDENTIFIER
				DECLARE @objectID	INT
				DECLARE @eventID	INT

				SET @xmlMessage = CAST(@RecvReqMsg AS XML)
				SET @objectGuid = (SELECT @xmlMessage.value('(/objectEvent/objectGuid)[1]', 'UNIQUEIDENTIFIER'))
				SET @objectID	= (SELECT @xmlMessage.value('(/objectEvent/objectID)[1]', 'int'))
				SET @eventID	= (SELECT @xmlMessage.value('(/objectEvent/eventID)[1]', 'int'))

				DECLARE @eventConditonGuid	UNIQUEIDENTIFIER
				DECLARE @eventConditionFunction VARCHAR(100)
				DECLARE @notificationGuid	UNIQUEIDENTIFIER
				DECLARE @objectConditionFunction VARCHAR(100)
				DECLARE @result INT
  
				BEGIN TRY
					DECLARE eventConditonsCursor CURSOR LOCAL
					FOR 
						SELECT EC.[Guid], EC.ConditionFunction, N.[Guid], N.ConditionFunction from NSEvent000 EV INNER JOIN NSEventCondition000 EC on ev.EventConditionGuid = ec.Guid
						INNER JOIN NSNotification000 N on ec.NotificationGuid = N.Guid
						WHERE EV.ObjectID = @objectID AND EV.EventID = @eventID

					OPEN eventConditonsCursor
					FETCH NEXT FROM eventConditonsCursor INTO @eventConditonGuid, @eventConditionFunction, @notificationGuid, @objectConditionFunction

					WHILE @@FETCH_STATUS = 0
					BEGIN
			
						EXEC @result = @eventConditionFunction @eventConditonGuid, @objectGuid
						IF @result = 1
						BEGIN
							EXEC @result = @objectConditionFunction @notificationGuid, @objectGuid
							IF @result = 1
							BEGIN
								EXEC NSSendEventCondtionMessages @eventConditonGuid, @objectGuid, 'BillCheckEventConditionsService'
							END
						End
						FETCH NEXT FROM eventConditonsCursor INTO @eventConditonGuid, @eventConditionFunction, @notificationGuid, @objectConditionFunction
					END

					CLOSE eventConditonsCursor;
					DEALLOCATE eventConditonsCursor;
				END TRY
				BEGIN CATCH
		
					DECLARE @ErrorMessage NVARCHAR(4000);
					DECLARE @ErrorSeverity INT;
					DECLARE @ErrorState INT;
					
					SELECT 
						@ErrorMessage = ERROR_MESSAGE() + N'Error Event Condition Function ' + @eventConditionFunction + ' Object Condition Function ' + @objectConditionFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
						@ErrorSeverity = ERROR_SEVERITY(),
						@ErrorState = ERROR_STATE();
		
					RAISERROR (@ErrorMessage, -- Message text.
					       @ErrorSeverity, -- Severity.
					       @ErrorState -- State.
					       );
				END CATCH
		END -- BillEventRequest Message Type
		ELSE IF @RecvReqMsgName =
		    N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
		BEGIN
			END CONVERSATION @RecvReqDlgHandle;
		END
		ELSE
		BEGIN
			INSERT INTO NSLog000 (Value, [Time]) VALUES (CAST((N'Service_Broker:Error' + @RecvReqMsgName) AS NVARCHAR(MAX)), CURRENT_TIMESTAMP)
			END CONVERSATION @RecvReqDlgHandle;
		END

		COMMIT TRANSACTION;
		END--while
	END TRY
	BEGIN CATCH
		IF ( XACT_STATE() != 0 ) 
			ROLLBACK TRAN ;

		INSERT INTO NSLog000 (Value, [Time]) VALUES (error_message() + CAST((N'NSPrcObjectCheckEventConditions Error ') AS NVARCHAR(MAX)), CURRENT_TIMESTAMP)
	END CATCH
END--sp
################################################################################
CREATE PROCEDURE NSSendEventCondtionMessages
	@eventConditonGuid	UNIQUEIDENTIFIER,
	@ObjectGuid			UNIQUEIDENTIFIER,
	@fromService		nvarchar(256)
AS
BEGIN
	DECLARE @messageGuid	UNIQUEIDENTIFIER

	DECLARE messagesCursor CURSOR
	FOR 
		SELECT M.[Guid] FROM NSMessage000 M INNER JOIN NSEventCondition000 EC on M.EventConditionGuid = EC.[Guid] AND EC.[Guid] = @eventConditonGuid

	OPEN messagesCursor
	FETCH NEXT FROM messagesCursor INTO @messageGuid

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		exec NSSendMessage @messageGuid, @objectGuid, @fromService

		FETCH NEXT FROM messagesCursor INTO @messageGuid
	END

	CLOSE messagesCursor;
	DEALLOCATE messagesCursor;
END
################################################################################
CREATE PROCEDURE NSSendMessage
	@messageGuid	UNIQUEIDENTIFIER,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	nvarchar(256)
AS
BEGIN
	
	DECLARE @SendMethod				TINYINT
	DECLARE @SendToCustomer			BIT
	DECLARE @getCustomersFunction	VARCHAR(100)
	DECLARE @mailAddress1			VARCHAR(100)
	DECLARE @smsAddress1			VARCHAR(20)
	DECLARE @mailAddress2			VARCHAR(100)
	DECLARE @smsAddress2			VARCHAR(20)
	DECLARE @users					VARCHAR(MAX)
	DECLARE @message				NVARCHAR(MAX)

	create TABLE #receiver
	(
		[GUID]			UNIQUEIDENTIFIER,
		receiverName	CHAR(15),
		mailAddress1	NVARCHAR(100),
		smsAddress1		VARCHAR(20),
		mailAddress2	NVARCHAR(100),
		smsAddress2		VARCHAR(20)
	)

	SELECT @SendMethod = M.SendMethod, @SendToCustomer = M.SendToCustomer, @getCustomersFunction = M.SendFunction, @users = Users, @message = M.[Message] FROM NSMessage000 M WHERE [GUID] = @messageGuid

	INSERT INTO #receiver (guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2) SELECT [guid], receiverName, mailAddress, smsAddress, '', '' FROM NSGetUsersInfo(@users)

	IF @SendToCustomer = 1
	BEGIN
		BEGIN TRY
			DECLARE @sql NVARCHAR(MAX)

			SET @sql = 'INSERT INTO #receiver (guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2) SELECT guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2  FROM ' + @getCustomersFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ')' + ' WHERE ' +  CASE @SendMethod WHEN 0 THEN 'NSNotSendEmail = 0' WHEN 1 THEN 'NSNotSendSMS = 0' END
			EXECUTE sp_executesql  @SQL
		END TRY
		BEGIN CATCH
		
			DECLARE @ErrorMessage NVARCHAR(4000);
			DECLARE @ErrorSeverity INT;
			DECLARE @ErrorState INT;
			
			SELECT 
				@ErrorMessage = ERROR_MESSAGE() + N'Error Receiver Function ' + @getCustomersFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();
		
			RAISERROR (@ErrorMessage, -- Message text.
		           @ErrorSeverity, -- Severity.
		           @ErrorState -- State.
		           );
		END CATCH
	END

	DECLARE @receiverGUID		UNIQUEIDENTIFIER
	DECLARE @receiverName		CHAR(15)
			
	DECLARE ReceiverCursor CURSOR
    FOR 
		SELECT * FROM #receiver

	OPEN ReceiverCursor
	FETCH NEXT FROM ReceiverCursor INTO @receiverGUID, @receiverName, @mailAddress1, @smsAddress1, @mailAddress2, @smsAddress2

	WHILE @@FETCH_STATUS = 0
    BEGIN
		
		IF @SendMethod = 0
		BEGIN
			EXEC NSSendMailMessage  @receiverName, @mailAddress1, @message, @messageGuid, @ObjectGuid, @fromService  

			IF @mailAddress2 <> ''
			BEGIN
				EXEC NSSendMailMessage  @receiverName, @mailAddress2, @message, @messageGuid, @ObjectGuid, @fromService  	
			END
		END

		IF @SendMethod = 1
		BEGIN
			EXEC NSSendSmsMessage  @receiverName, @smsAddress1, @message, @messageGuid, @ObjectGuid, @fromService  

			IF @smsAddress2 <> ''
			BEGIN
				EXEC NSSendSmsMessage  @receiverName, @smsAddress2, @message, @messageGuid, @ObjectGuid, @fromService  
			END
		END

		FETCH NEXT FROM ReceiverCursor INTO @receiverGUID, @receiverName, @mailAddress1, @smsAddress1, @mailAddress2, @smsAddress2
    END

	CLOSE ReceiverCursor;
	DEALLOCATE ReceiverCursor;

END
################################################################################
CREATE PROCEDURE NSSendManualMessage
	@xmlmessage		xml,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	nvarchar(256)
AS
BEGIN
	
	DECLARE @SendMethod				TINYINT
	DECLARE @SendToCustomer			BIT
	DECLARE @getCustomersFunction	VARCHAR(100)
	DECLARE @mailAddress1			VARCHAR(100)
	DECLARE @smsAddress1			VARCHAR(20)
	DECLARE @mailAddress2			VARCHAR(100)
	DECLARE @smsAddress2			VARCHAR(20)
	DECLARE @users					VARCHAR(MAX)
	DECLARE @message				NVARCHAR(MAX)

	create TABLE #receiver
	(
		[GUID]			UNIQUEIDENTIFIER,
		receiverName	CHAR(15),
		mailAddress1	NVARCHAR(100),
		smsAddress1		VARCHAR(20),
		mailAddress2	NVARCHAR(100),
		smsAddress2		VARCHAR(20)
	)

	 SET @SendMethod = (SELECT @xmlMessage.value('(/Message/SendMethod)[1]', 'TINYINT'))
	 SET @SendToCustomer = (SELECT @xmlMessage.value('(/Message/SendToCustomer)[1]', 'BIT'))
	 SET @getCustomersFunction = (SELECT @xmlMessage.value('(/Message/SendFunction)[1]', 'VARCHAR(100)'))
	 SET @users = CAST((SELECT T.C.query('.') FROM @xmlMessage.nodes('/Message/Users') AS T(C)) AS NVARCHAR(MAX))
	 SET @message = cast(@xmlMessage.query('/Message/Message') as nvarchar(max)) --(SELECT @xmlMessage.value('(/Message/Message)[1]', 'XML'))


	INSERT INTO #receiver (guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2) SELECT [guid], receiverName, mailAddress, smsAddress, '', '' FROM NSGetUsersInfo(@users)

	IF @SendToCustomer = 1
	BEGIN
		BEGIN TRY
			DECLARE @sql NVARCHAR(MAX)

			SET @sql = 'INSERT INTO #receiver (guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2) SELECT guid, receiverName, mailAddress1, smsAddress1, mailAddress2, smsAddress2  FROM ' + @getCustomersFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ')' + ' WHERE ' +  CASE @SendMethod WHEN 0 THEN 'NSNotSendEmail = 0' WHEN 1 THEN 'NSNotSendSMS = 0' END
			EXECUTE sp_executesql  @SQL
		END TRY
		BEGIN CATCH
		
			DECLARE @ErrorMessage NVARCHAR(4000);
			DECLARE @ErrorSeverity INT;
			DECLARE @ErrorState INT;
			
			SELECT 
				@ErrorMessage = ERROR_MESSAGE() + N'Error Receiver Function ' + @getCustomersFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();
		
			RAISERROR (@ErrorMessage, -- Message text.
		           @ErrorSeverity, -- Severity.
		           @ErrorState -- State.
		           );
		END CATCH
	END

	DECLARE @receiverGUID		UNIQUEIDENTIFIER
	DECLARE @receiverName		CHAR(15)
			
	DECLARE ReceiverCursor CURSOR
    FOR 
		SELECT * FROM #receiver

	OPEN ReceiverCursor
	FETCH NEXT FROM ReceiverCursor INTO @receiverGUID, @receiverName, @mailAddress1, @smsAddress1, @mailAddress2, @smsAddress2

	WHILE @@FETCH_STATUS = 0
    BEGIN
		
		IF @SendMethod = 0
		BEGIN
			EXEC NSSendManualMailMessage  @receiverName, @mailAddress1, @message, @xmlmessage, @ObjectGuid, @fromService  

			IF @mailAddress2 <> ''
			BEGIN
				EXEC NSSendManualMailMessage  @receiverName, @mailAddress2, @message, @xmlmessage, @ObjectGuid, @fromService  	
			END
		END

		IF @SendMethod = 1
		BEGIN
			EXEC NSSendManualSmsMessage  @receiverName, @smsAddress1, @message, @xmlmessage, @ObjectGuid, @fromService  

			IF @smsAddress2 <> ''
			BEGIN
				EXEC NSSendManualSmsMessage  @receiverName, @smsAddress2, @message, @xmlmessage, @ObjectGuid, @fromService  
			END
		END

		FETCH NEXT FROM ReceiverCursor INTO @receiverGUID, @receiverName, @mailAddress1, @smsAddress1, @mailAddress2, @smsAddress2
    END

	CLOSE ReceiverCursor;
	DEALLOCATE ReceiverCursor;

END
################################################################################
#END