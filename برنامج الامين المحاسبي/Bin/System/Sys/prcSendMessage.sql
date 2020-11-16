################################################################################
CREATE PROCEDURE NSSendMailMessage
	@receiverName	VARCHAR(100),
	@mailAddress	VARCHAR(100),
	@message		NVARCHAR(MAX),
	@messageGuid	UNIQUEIDENTIFIER,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	NVARCHAR(256)
AS
BEGIN
	DECLARE @Log NVARCHAR(MAX)
	DECLARE @CheckEventConditionsMessage    NVARCHAR(MAX)
	DECLARE @FunctionsTag					NVARCHAR(MAX)
	DECLARE @messageFieldsTag				NVARCHAR(MAX)
	DECLARE @messageData					NVARCHAR(MAX)
	DECLARE @messageTemplete				NVARCHAR(MAX)

	CREATE TABLE #messageTags (messageFieldsTag NVARCHAR(MAX), FunctionsTag NVARCHAR(MAX))

	INSERT INTO #messageTags EXEC NSGetMessageTags @messageGuid, @ObjectGuid
	------------------   
	SET @mailAddress = (SELECT @mailAddress AS EmailAddress FOR XML PATH(''))
	SET @messageTemplete = @message + @mailAddress
	SET @messageData = (SELECT CAST(messageFieldsTag as xml) AS MessageFields, CAST(FunctionsTag as xml) AS Functions from #messageTags FOR XML PATH(''));
	SET @CheckEventConditionsMessage = (SELECT cast(@messageTemplete as xml) AS Template,  CAST(@messageData as xml) AS Data, @ObjectGuid AS ObjectGuid FOR XML PATH('MailMessage'));
	-------------------

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE @fromService
	TO
		SERVICE 'BillReadyMessageService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@CheckEventConditionsMessage)

	END CONVERSATION @handle

	SET @Log = N'Service_Broker:MailMessage' --+ CAST(@CheckEventConditionsMessage AS NVARCHAR(MAX))
	EXEC prcLog @Log
END
################################################################################
CREATE PROCEDURE NSSendManualMailMessage
	@receiverName	VARCHAR(100),
	@mailAddress	VARCHAR(100),
	@message		NVARCHAR(MAX),
	@xmlmessage	xml,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	NVARCHAR(256)
AS
BEGIN
	DECLARE @Log NVARCHAR(MAX)
	DECLARE @CheckEventConditionsMessage    NVARCHAR(MAX)
	DECLARE @FunctionsTag					NVARCHAR(MAX)
	DECLARE @messageFieldsTag				xml
	DECLARE @messageData					NVARCHAR(MAX)
	DECLARE @messageTemplete				NVARCHAR(MAX)

	CREATE TABLE #messageTags (messageFieldsTag xml, FunctionsTag NVARCHAR(MAX))

	INSERT INTO #messageTags EXEC NSGetManualMessageTags @xmlMessage, @ObjectGuid
	------------------   
	SET @mailAddress = (SELECT @mailAddress AS EmailAddress FOR XML PATH(''))
	SET @messageTemplete = @message + @mailAddress
	SET @messageData = (SELECT messageFieldsTag AS MessageFields, CAST(FunctionsTag as xml) AS Functions from #messageTags FOR XML PATH(''));
	SET @CheckEventConditionsMessage = (SELECT cast(@messageTemplete as xml) AS Template,  CAST(@messageData as xml) AS Data FOR XML PATH('MailMessage'));
	-------------------

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE @fromService
	TO
		SERVICE 'BillReadyMessageService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@CheckEventConditionsMessage)

	END CONVERSATION @handle

	SET @Log = N'Service_Broker:MailMessage' --+ CAST(@CheckEventConditionsMessage AS NVARCHAR(MAX))
	EXEC prcLog @Log
END
################################################################################
CREATE PROCEDURE NSSendSmsMessage
	@receiverName	VARCHAR(100),
	@phoneNumber	VARCHAR(100),
	@message		NVARCHAR(MAX),
	@messageGuid	UNIQUEIDENTIFIER,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	NVARCHAR(256)
AS
BEGIN
	DECLARE @Log NVARCHAR(MAX)
	DECLARE @CheckEventConditionsMessage    NVARCHAR(MAX)
	DECLARE @FunctionsTag					NVARCHAR(MAX)
	DECLARE @messageFieldsTag				NVARCHAR(MAX)
	DECLARE @messageData					NVARCHAR(MAX)
	DECLARE @messageTemplete				NVARCHAR(MAX)

	CREATE TABLE #messageTags (messageFieldsTag NVARCHAR(MAX), FunctionsTag NVARCHAR(MAX))

	INSERT INTO #messageTags exec NSGetMessageTags @messageGuid, @ObjectGuid
	------------------   
	SET @phoneNumber = (SELECT @phoneNumber AS PhoneNumber FOR XML PATH(''))
	SET @messageTemplete = @message + @phoneNumber
	SET @messageData = (SELECT CAST(messageFieldsTag as xml) AS MessageFields, CAST(FunctionsTag as xml) AS Functions from #messageTags FOR XML PATH(''));
	SET @CheckEventConditionsMessage = (SELECT cast(@messageTemplete as xml) AS Template,  CAST(@messageData as xml) AS Data FOR XML PATH('SmsMessage'));
	-------------------

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE @fromService
	TO
		SERVICE 'ReadySmsMessageService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@CheckEventConditionsMessage)

	END CONVERSATION @handle

	SET @Log = N'Service_Broker:MailMessage' --+ CAST(@CheckEventConditionsMessage AS NVARCHAR(MAX))
	EXEC prcLog @Log

END
################################################################################
CREATE PROCEDURE NSSendManualSmsMessage
	@receiverName	VARCHAR(100),
	@phoneNumber	VARCHAR(100),
	@message		NVARCHAR(MAX),
	@xmlmessage		xml,
	@ObjectGuid		UNIQUEIDENTIFIER,
	@fromService	NVARCHAR(256)
AS
BEGIN
	DECLARE @Log NVARCHAR(MAX)
	DECLARE @CheckEventConditionsMessage    NVARCHAR(MAX)
	DECLARE @FunctionsTag					NVARCHAR(MAX)
	DECLARE @messageFieldsTag				xml
	DECLARE @messageData					NVARCHAR(MAX)
	DECLARE @messageTemplete				NVARCHAR(MAX)

	CREATE TABLE #messageTags (messageFieldsTag xml, FunctionsTag NVARCHAR(MAX))

	INSERT INTO #messageTags exec NSGetManualMessageTags @xmlmessage, @ObjectGuid
	------------------   
	SET @phoneNumber = (SELECT @phoneNumber AS PhoneNumber FOR XML PATH(''))
	SET @messageTemplete = @message + @phoneNumber
	SET @messageData = (SELECT messageFieldsTag AS MessageFields, CAST(FunctionsTag as xml) AS Functions from #messageTags FOR XML PATH(''));
	SET @CheckEventConditionsMessage = (SELECT cast(@messageTemplete as xml) AS Template,  CAST(@messageData as xml) AS Data FOR XML PATH('SmsMessage'));
	-------------------

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE @fromService
	TO
		SERVICE 'ReadySmsMessageService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@CheckEventConditionsMessage)

	END CONVERSATION @handle

	SET @Log = N'Service_Broker:MailMessage' --+ CAST(@CheckEventConditionsMessage AS NVARCHAR(MAX))
	EXEC prcLog @Log

END
################################################################################
CREATE PROCEDURE NSGetMessageTags
	@messageGuid	UNIQUEIDENTIFIER,
	@ObjectGuid		UNIQUEIDENTIFIER
AS
BEGIN

	--------------
	DECLARE @messageFieldsTag AS NVARCHAR(MAX)
	SET @messageFieldsTag = ISNull((SELECT FieldID AS '@FieldID', [Column] AS '@Column' FROM NSMessageFields000 WHERE MessageGuid = @messageGuid
							FOR XML PATH('Field')), N'')
	--------------
	DECLARE @function		VARCHAR(100)
	DECLARE @sql			NVARCHAR(max)
	DECLARE @ParmDefinition NVARCHAR(500);
	DECLARE @xmlout			NVARCHAR(max);
	DECLARE @FunctionsTag   NVARCHAR(max);
	set @FunctionsTag = ''

	BEGIN TRY

		DECLARE fieldsCursor CURSOR
		FOR 
			SELECT DISTINCT [Function] FROM NSMessageFields000 WHERE MessageGuid = @messageGuid 

		OPEN fieldsCursor
		FETCH NEXT FROM fieldsCursor INTO @function

		WHILE @@FETCH_STATUS = 0
		BEGIN
			---------------
			SET @ParmDefinition = N'@OGuid UNIQUEIDENTIFIER, @xml nvarchar(max) OUTPUT , @MSGGuid UNIQUEIDENTIFIER';
			SET @sql = 'SET @xml = (SELECT * FROM ' + @function + '(@OGuid ,@MSGGuid) FOR XML RAW(''Function''))';
			
			EXECUTE sp_executesql  @SQL, @ParmDefinition, @OGuid = @ObjectGuid, @MSGGuid = @messageGuid , @xml = @xmlout OUTPUT

			SET @FunctionsTag = @FunctionsTag + ISNULL(@xmlout, '')
			----------------
			FETCH NEXT FROM fieldsCursor INTO @function
		END

		CLOSE fieldsCursor;
		DEALLOCATE fieldsCursor;

		END TRY
		BEGIN CATCH
		
		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		
		SELECT 
		    @ErrorMessage = ERROR_MESSAGE() + N'Error Data Field Function ' + @function + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
		    @ErrorSeverity = ERROR_SEVERITY(),
		    @ErrorState = ERROR_STATE();
		
			 RAISERROR (@ErrorMessage, -- Message text.
		           @ErrorSeverity, -- Severity.
		           @ErrorState -- State.
		           );
		END CATCH

	SELECT @messageFieldsTag, @FunctionsTag
end
################################################################################
CREATE PROCEDURE NSGetManualMessageTags
	@message		xml,
	@ObjectGuid		UNIQUEIDENTIFIER
AS
BEGIN

	--------------
	DECLARE @messageFieldsTag AS xml
	SET @messageFieldsTag = @message.query('/Message/Fields')
	--------------
	DECLARE @function		VARCHAR(100)
	DECLARE @sql			NVARCHAR(max)
	DECLARE @ParmDefinition NVARCHAR(500);
	DECLARE @xmlout			NVARCHAR(max);
	DECLARE @FunctionsTag   NVARCHAR(max);
	set @FunctionsTag = ''

	BEGIN TRY

		DECLARE fieldsCursor CURSOR
		FOR 
			SELECT DISTINCT M.f.value('./@Function', 'VARCHAR(100)') FROM @message.nodes('/Message/Fields/Field') M(f)

		OPEN fieldsCursor
		FETCH NEXT FROM fieldsCursor INTO @function

		WHILE @@FETCH_STATUS = 0
		BEGIN
			---------------
			SET @ParmDefinition = N'@OGuid UNIQUEIDENTIFIER, @xml nvarchar(max) OUTPUT , @MSGGuid UNIQUEIDENTIFIER';
			SET @sql = 'SET @xml = (SELECT * FROM ' + @function + '(@OGuid, @MSGGuid) FOR XML RAW(''Function''))';
			
			EXECUTE sp_executesql  @SQL, @ParmDefinition, @OGuid = @ObjectGuid, @MSGGuid = 0x0 , @xml = @xmlout OUTPUT

			SET @FunctionsTag = @FunctionsTag + ISNULL(@xmlout, '')
			----------------
			FETCH NEXT FROM fieldsCursor INTO @function
		END

		CLOSE fieldsCursor;
		DEALLOCATE fieldsCursor;

		END TRY
		BEGIN CATCH
		
		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		
		SELECT 
		    @ErrorMessage = ERROR_MESSAGE() + N'Error Data Field Function ' + @function + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
		    @ErrorSeverity = ERROR_SEVERITY(),
		    @ErrorState = ERROR_STATE();
		
			 RAISERROR (@ErrorMessage, -- Message text.
		           @ErrorSeverity, -- Severity.
		           @ErrorState -- State.
		           );
		END CATCH

	SELECT @messageFieldsTag, @FunctionsTag
end
################################################################################
CREATE PROCEDURE prcSendBillMessage
AS 
BEGIN
	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RecvReqMsg NVARCHAR(max);
	DECLARE @RecvReqMsgName SYSNAME;

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		WAITFOR
		( RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM BillReadyMessageQueue
		), TIMEOUT 5000;

		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END

		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
		
			IF [dbo].[fnOption_get]('NS_DISABLEEMAIL', '0') <> 1
			BEGIN
			
				DECLARE @sendresult		BIT
				declare @message		xml
				declare @objectGuid		UNIQUEIDENTIFIER
				declare @sendAttachment BIT
				declare @attachmentFile	varbinary(max) = NULL
				declare @attachmentName nvarchar(256)
				declare @messageSubject nvarchar(256)
				declare @messageBody	nvarchar(max)
				declare @mailAddress	nvarchar(100)
				declare @errorMessage   nvarchar(max)

				set @message = cast(@RecvReqMsg as xml)
				set @sendAttachment = @message.value('(/MailMessage/Template/SendAttachment)[1]', 'BIT')

				IF(@sendAttachment = 1)
				BEGIN
					SET @objectGuid = (SELECT @message.value('(/MailMessage/ObjectGuid)[1]', 'UNIQUEIDENTIFIER'))
					SELECT @attachmentFile = FileBytes, @attachmentName = [FileName] FROM fnNSGetMessageAttachment(@objectGuid)
				END

				exec @sendresult = NSSendMail @message, @attachmentFile, @attachmentName, @messageSubject output, @messageBody output, @mailAddress output, @errorMessage output

				IF @sendresult = 0
				BEGIN				
					INSERT INTO NSMailMessage000 select NEWID(), @messageSubject, @messageBody, @mailAddress, 1, @errorMessage, @errorMessage, CURRENT_TIMESTAMP, @attachmentFile, @attachmentName
				END
			END
		END
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
	END
END
################################################################################
CREATE PROCEDURE prcSendSmsMessage
AS 
BEGIN
	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RecvReqMsg NVARCHAR(max);
	DECLARE @RecvReqMsgName SYSNAME;

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		WAITFOR
		( RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM ReadySmsMessageQueue
		), TIMEOUT 5000;

		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END

		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
		
			IF [dbo].[fnOption_get]('NS_DISABLESMS', '0') <> 1
			BEGIN

				DECLARE @sendresult		BIT
				DECLARE @mcresult		BIT
				declare @message		xml
				declare @messageText	NVARCHAR(MAX)
				declare @phoneNumber    NVARCHAR(20)
				DECLARE @errorMessage   NVARCHAR(MAX)
				
				set @message = cast(@RecvReqMsg as xml)

				exec @sendresult = NSSendSms @message, @messageText output, @phoneNumber output, @errorMessage OUTPUT 

				IF @sendresult = 0
				BEGIN
					INSERT INTO NSSmsMessage000 SELECT NEWID(), @messageText, @phoneNumber, 1, @errorMessage, @errorMessage, CURRENT_TIMESTAMP
				END
			END
		END
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
	END
END
################################################################################
CREATE PROCEDURE prcSendMail
	@messageSubject	NVARCHAR(256),
	@messageText	NVARCHAR(MAX),
	@toMailAddress	NVARCHAR(256)
AS
BEGIN

	SET NOCOUNT ON
	DECLARE @sendresult		BIT
	DECLARE @mcresult		BIT
	DECLARE @errorMessage   NVARCHAR(MAX)
	DECLARE @message        XML
	declare @messageBody	nvarchar(max)
	declare @mailAddress	nvarchar(100)
	declare @templete       nvarchar(max)
	declare @data			nvarchar(max)

	set @templete = (select @messageSubject AS [Subject], @messageText AS [Body], @toMailAddress AS EmailAddress for xml path(''))
	set @data = (select '' AS MessageFields, '' AS Functions for XML PATH(''))

	SET @message = (SELECT  cast(@templete as xml) AS Template, cast(@data as xml) as Data for XML PATH('MailMessage'))
	EXEC @mcresult = NSSendMail @message, NULL, '', @messageSubject output, @messageBody output, @mailAddress output, @errorMessage output

	SELECT @mcresult as sendResult, @errorMessage errorMessage
END
################################################################################
CREATE PROCEDURE prcReSendMail
	@messageGuid UNIQUEIDENTIFIER
AS
BEGIN

	SET NOCOUNT ON

	BEGIN TRANSACTION

	update NSMailMessage000 set Status = 2 where [Guid] = @messageGuid
	DECLARE @ReSendMessage AS XML

    SET @ReSendMessage = (SELECT @messageGuid AS [Guid] FOR XML PATH(''), ROOT('MailMessage'), ELEMENTS)

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE ReSendMailService
	TO
		SERVICE 'ReSendMailService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@ReSendMessage)

	END CONVERSATION @handle

	COMMIT TRANSACTION
END
################################################################################
CREATE PROCEDURE prcReSendSms
	@messageGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRANSACTION

	UPDATE NSSmsMessage000 SET STATUS = 2 WHERE [Guid] = @messageGuid
	DECLARE @ReSendMessage AS XML

    SET @ReSendMessage = (SELECT @messageGuid AS [Guid] FOR XML PATH(''), ROOT('SmsMessage'), ELEMENTS)

	DECLARE @handle AS UNIQUEIDENTIFIER

	BEGIN DIALOG CONVERSATION @handle  
	FROM
		SERVICE ReSendSmsService
	TO
		SERVICE 'ReSendSmsService'
	WITH
		ENCRYPTION = OFF;

	SEND ON CONVERSATION @handle (@ReSendMessage)

	END CONVERSATION @handle

	COMMIT TRANSACTION
END
################################################################################
CREATE procedure prcSendSms
	@messageText NVARCHAR(MAX),
	@toPhoneNumber NVARCHAR(256)
AS
BEGIN

	SET NOCOUNT ON
	DECLARE @sendresult		BIT
	DECLARE @mcresult		BIT
	DECLARE @errorMessage   NVARCHAR(MAX)
	declare @phoneNumber    NVARCHAR(20)
	DECLARE @message        XML
	declare @templete       nvarchar(max)
	declare @data       nvarchar(max)

	set @templete = (select @messageText AS [Body], @toPhoneNumber AS PhoneNumber for xml path(''))
	set @data = (select '' AS MessageFields, '' AS Functions for XML PATH(''))

	SET @message = (SELECT  cast(@templete as xml) AS Template, cast(@data as xml) as Data for XML PATH('SmsMessage'))
	EXEC @mcresult = NSSendSms @message, @messageText output, @phoneNumber output, @errorMessage OUTPUT

	SELECT @mcresult AS sendResult, @errorMessage errorMessage
END
################################################################################
CREATE procedure prcSendAccountBalancesSms
	@templateGuid UNIQUEIDENTIFIER,
	@UserGuid UNIQUEIDENTIFIER

	
AS
BEGIN

	SET NOCOUNT ON
	DECLARE @sendresult		BIT
	DECLARE @mcresult		BIT
	DECLARE @errorMessage   NVARCHAR(MAX)
	declare @phoneNumber    NVARCHAR(20)
	declare @messageText NVARCHAR(MAX)
	DECLARE @message        XML
	DECLARE @body			xml
	DECLARE @toPhoneNumber NVARCHAR(256)

	SET @toPhoneNumber = (SELECT MobilePhone From us000 WHere Guid = @UserGuid)
	
	EXEC GetAccountBalancesMessage @templateGuid,@body OUTPUT

	SET @message = ( SELECT 'AccountBalances' AS '@Type' , @Body , @toPhoneNumber AS PhoneNumber For XML PATH('SmsMessage'))

	EXEC @mcresult = NSSendSms @message, @messageText output, @phoneNumber output, @errorMessage OUTPUT
	IF @mcresult = 0
	BEGIN
	INSERT INTO NSSmsMessage000 SELECT NEWID(), @messageText, @phoneNumber, 1, @errorMessage, @errorMessage, CURRENT_TIMESTAMP
	END
	SELECT @mcresult AS sendResult, @errorMessage errorMessage
END
################################################################################
CREATE PROCEDURE prcSendAccountBalancesMail
	@templateGuid UNIQUEIDENTIFIER,
	@UserGuid UNIQUEIDENTIFIER,
	@Subject   NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @sendresult		BIT
	DECLARE @mcresult		BIT
	DECLARE @errorMessage   NVARCHAR(MAX)
	DECLARE @message        XML
	DECLARE @Body      XML
	declare @messageSubject nvarchar(256)
	declare @messageBody	nvarchar(max)
	declare @mailAddress	nvarchar(100)
	declare	@toMailAddress nvarchar(100)

	SET @toMailAddress = (SELECT Email From us000 WHere Guid = @UserGuid)
	EXEC GetAccountBalancesMessage @templateGuid,@Body OUTPUT

	SET @message = ( SELECT 'AccountBalances' AS '@Type' ,@Subject AS Subject, @Body , @toMailAddress AS EmailAddress For XML PATH('MailMessage'))
	EXEC @mcresult = NSSendMail @message, NULL, '', @messageSubject output, @messageBody output, @mailAddress output, @errorMessage output
	IF @mcresult = 0
	BEGIN				
		INSERT INTO NSMailMessage000 select NEWID(), @messageSubject, @messageBody, @mailAddress, 1, @errorMessage, @errorMessage, CURRENT_TIMESTAMP, NULL, ''
	END
	SELECT @mcresult as sendResult, @errorMessage errorMessage
END
################################################################################
CREATE PROCEDURE NSPrcReSendMailMessage
AS
BEGIN
	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RecvReqMsg NVARCHAR(max);
	DECLARE @RecvReqMsgName SYSNAME;

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		WAITFOR
		( RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM ReSendMailQueue
		), TIMEOUT 5000;

		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END

		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
			
			DECLARE @message		xml
			DECLARE @messageGuid	UNIQUEIDENTIFIER

			SET @message = CAST(@RecvReqMsg AS XML)
			SET @messageGuid = (SELECT @message.value('(/MailMessage/Guid)[1]', 'UNIQUEIDENTIFIER'))

			DECLARE @sendresult		BIT	
			DECLARE @messageSubject NVARCHAR(256)
			DECLARE @messageBody	NVARCHAR(MAX)
			DECLARE @attachmentFile	VARBINARY(MAX)
			DECLARE @attachmentName	NVARCHAR(256)
			DECLARE @mailAddress	NVARCHAR(100)
			DECLARE @errorMessage   NVARCHAR(MAX)
			
			DECLARE @templete       NVARCHAR(MAX)
			DECLARE @data			NVARCHAR(MAX)

			SELECT @messageSubject = MessageSubject, @messageBody = MessageBody, @mailAddress = MailAddress, 
				@attachmentFile = AttachmentFile, @attachmentName = AttachmentName
			from NSMailMessage000 
			where [Guid] = @messageGuid

			SET @templete = (SELECT @messageSubject AS [Subject], @messageBody AS [Body], @mailAddress AS EmailAddress for xml path(''))
			SET @data = (SELECT '' AS MessageFields, '' AS Functions for XML PATH(''))
			SET @message = (SELECT  cast(@templete as xml) AS Template, cast(@data as xml) as Data for XML PATH('MailMessage'))

			EXEC @sendresult = NSSendMail @message, @attachmentFile, @attachmentName, @messageSubject output, @messageBody output, @mailAddress output, @errorMessage output

			UPDATE NSMailMessage000 SET 
				Status = CASE @sendresult WHEN 0 THEN 1 ELSE 0 END,
				ErrorMessage = @errorMessage,
				MailAddress = @mailAddress,
				[Time] = CURRENT_TIMESTAMP						
			  WHERE [Guid] = @messageGuid

		END
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
	END
END
################################################################################
CREATE PROCEDURE NSPrcReSendSmsMessage
AS
BEGIN
	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RecvReqMsg NVARCHAR(max);
	DECLARE @RecvReqMsgName SYSNAME;

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		WAITFOR
		( RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM ReSendSmsQueue
		), TIMEOUT 5000;

		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END

		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
			
			DECLARE @message		xml
			DECLARE @messageGuid	UNIQUEIDENTIFIER

			SET @message = CAST(@RecvReqMsg AS XML)
			SET @messageGuid = (SELECT @message.value('(/SmsMessage/Guid)[1]', 'UNIQUEIDENTIFIER'))

			DECLARE @sendresult		BIT	
			DECLARE @messageBody	NVARCHAR(MAX)
			DECLARE @phoneNumber	NVARCHAR(100)
			DECLARE @errorMessage   NVARCHAR(MAX)
			
			DECLARE @templete       NVARCHAR(MAX)
			DECLARE @data			NVARCHAR(MAX)

			SELECT @messageBody = MessageText, @phoneNumber = PhoneNumber FROM NSSmsMessage000 WHERE [Guid] = @messageGuid

			SET @templete = (SELECT @messageBody AS [Body], @phoneNumber AS PhoneNumber for xml path(''))
			SET @data = (SELECT '' AS MessageFields, '' AS Functions for XML PATH(''))
			SET @message = (SELECT  cast(@templete as xml) AS Template, cast(@data as xml) as Data for XML PATH('SmsMessage'))

			EXEC @sendresult = NSSendSms @message, @messageBody output, @phoneNumber output, @errorMessage output

			UPDATE NSSmsMessage000 SET 
				Status = CASE @sendresult WHEN 0 THEN 1 ELSE 0 END,
				ErrorMessage = @errorMessage,
				PhoneNumber = @phoneNumber,
				[Time] = CURRENT_TIMESTAMP						
			  WHERE [Guid] = @messageGuid

		END
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
	END
END
################################################################################
CREATE FUNCTION fnNSGetMessageAttachment(@objectGuid UNIQUEIDENTIFIER)
RETURNS @attachment TABLE 
(
		FileBytes	VARBINARY(MAX),
		[FileName]	NVARCHAR(250)
)
AS
BEGIN
	IF(ISNULL(@objectGuid, 0x0) = 0x0)
		RETURN

	DECLARE @AUTO_ARCHIVE_FIELD_ID UNIQUEIDENTIFIER = '8CA10DE1-DA26-44E6-88D0-18F1C3EA86C9'

	INSERT INTO @attachment
		SELECT TOP 1 f.FileBytes, f.[FileName] + N'.' + f.FileExtension
		FROM DMSTblFile f 
			INNER JOIN DMSTblDocument d ON f.DocumentId = d.ID
			INNER JOIN DMSTblDocumentFieldValue v ON v.DocumentID = d.ID AND v.[Value] = CAST(@objectGuid AS NVARCHAR(100))
			INNER JOIN DMSTblDocumentFieldValue ar ON ar.DocumentID = d.ID AND ar.FieldID = @AUTO_ARCHIVE_FIELD_ID
		ORDER BY d.CreationDate DESC
	RETURN
END
################################################################################
#END