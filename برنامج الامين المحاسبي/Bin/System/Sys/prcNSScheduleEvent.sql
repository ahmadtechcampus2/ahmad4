################################################################################
CREATE PROCEDURE NSPrcSchedulingEvent
	@type	AS int,
	@templateGuid AS UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventMessage AS XML
	DECLARE @sendType BIGINT= 0
	DECLARE @Subject  NVARCHAR(100)


	DECLARE @xmlUsers AS XML = (SELECT UserGuid AS [Guid] FROM NSAccountBalancesSchedulingUser000 WHERE ParentGuid = @templateGuid FOR XML RAW('User'))
	SELECT @sendType = sendtype, @Subject = [Subject] FROM NSAccountBalancesScheduling000 WHERE [Guid] =  @templateGuid
    SET @EventMessage = (SELECT @type as Type, @templateGuid  AS TemplateGuid, @xmlUsers AS Users, @sendType AS SendType, @Subject AS [Subject]
							FOR XML PATH(''), ROOT('scheduleEvent'), ELEMENTS)

    DECLARE @handle    AS UNIQUEIDENTIFIER

    BEGIN DIALOG CONVERSATION @handle  
        FROM
            SERVICE BillEventService
        TO
            SERVICE 'ScheduleEventService'
        WITH
            ENCRYPTION = OFF;

    SEND ON CONVERSATION @handle (@EventMessage)
	END CONVERSATION @handle

END
################################################################################
CREATE PROCEDURE NSPrcManualAccountBalanceEvent
	@type	AS int,
	@templateGuid AS UNIQUEIDENTIFIER,
	@users AS XML,
	@sendType BIGINT,
	@subject NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventMessage AS XML

    SET @EventMessage = (SELECT @type as Type, @templateGuid  AS TemplateGuid, @users, @sendType AS SendType, @subject AS [Subject]
							FOR XML PATH(''), ROOT('scheduleEvent'), ELEMENTS)

    DECLARE @handle    AS UNIQUEIDENTIFIER

    BEGIN DIALOG CONVERSATION @handle  
    FROM
        SERVICE BillEventService
    TO
        SERVICE 'ScheduleEventService'
    WITH
        ENCRYPTION = OFF;

    SEND ON CONVERSATION @handle (@EventMessage)
	END CONVERSATION @handle

END
################################################################################
CREATE PROCEDURE NSPrcSendScheduleMessage
AS 
BEGIN

	SET NOCOUNT ON

	EXEC NSPrcConnectionsAddAdmin

	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER
	DECLARE @RecvReqMsg NVARCHAR(MAX)
	DECLARE @RecvReqMsgName SYSNAME
	WHILE (1=1)
	BEGIN
		BEGIN TRANSACTION;
		WAITFOR
		( RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM ScheduleEventQueue
		), TIMEOUT 5000;
		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END
		
	
		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
			DECLARE @sql			NVARCHAR(MAX)
			DECLARE @xmlMessage		XML
			DECLARE @templateGuid	UNIQUEIDENTIFIER
			DECLARE @sendType		BIGINT = 0;
			DECLARE @xmlUsers		XML
			DECLARE @type			INT
			DECLARE @Subject	NVARCHAR(100)

			SET @xmlMessage = CAST(@RecvReqMsg AS XML)
			SET @type	= (SELECT @xmlMessage.value('(/scheduleEvent/Type)[1]', 'int'))
			SET @templateGuid	= (SELECT @xmlMessage.value('(/scheduleEvent/TemplateGuid)[1]', 'UNIQUEIDENTIFIER'))
			SET @xmlUsers = @xmlMessage.query('/scheduleEvent/Users')
			SET @sendType = (SELECT @xmlMessage.value('(/scheduleEvent/SendType)[1]', 'BIGINT'))
			SET @Subject = (SELECT @xmlMessage.value('(/scheduleEvent/Subject)[1]', 'NVARCHAR(100)'))

			IF @type = 1 
			Begin
				DECLARE @UserGuid UNIQUEIDENTIFIER
				DECLARE @body			xml = ''
				EXEC GetAccountBalancesMessage @templateGuid, @body OUTPUT

				DECLARE UserCursor CURSOR FOR
				SELECT  T.c.value('./@Guid', 'UNIQUEIDENTIFIER') from @xmlUsers.nodes('/Users/User') T(c)

				OPEN UserCursor
				FETCH NEXT FROM UserCursor INTO @userGuid

				WHILE @@FETCH_STATUS = 0
				BEGIN
		
					IF (@sendType & 0x00000001 > 0)
					BEGIN
						DECLARE	@toMailAddress nvarchar(100) = (SELECT Email From us000 WHere Guid = @UserGuid)
						DECLARE @message   XML  = ( SELECT 'AccountBalances' AS '@Type' ,@Subject AS Subject, @body , @toMailAddress AS EmailAddress For XML PATH('MailMessage'))
						DECLARE @handle    AS UNIQUEIDENTIFIER

						BEGIN DIALOG CONVERSATION @handle  
						FROM
							SERVICE BillEventService
						TO
							SERVICE 'BillReadyMessageService'
						 WITH
							ENCRYPTION = OFF;

						 SEND ON CONVERSATION @handle (@message)
						 END CONVERSATION @handle
					END
					IF (@sendType & 0x00000002 > 0)
					BEGIN
						DECLARE	@toPhoneNumber nvarchar(100)   = (SELECT MobilePhone From us000 WHere Guid = @UserGuid)
						DECLARE @SMSmessage   XML  = ( SELECT 'AccountBalances' AS '@Type' , @body , @toPhoneNumber AS PhoneNumber For XML PATH('SmsMessage'))
						DECLARE @SMShandle    AS UNIQUEIDENTIFIER

						BEGIN DIALOG CONVERSATION @SMShandle  
						FROM
							SERVICE BillEventService
						TO
							SERVICE 'ReadySmsMessageService'
						 WITH
							ENCRYPTION = OFF;

						 SEND ON CONVERSATION @SMShandle (@SMSmessage)
						 END CONVERSATION @SMShandle
					END

					FETCH NEXT FROM UserCursor INTO @userGuid
				END

				CLOSE UserCursor;
				DEALLOCATE UserCursor;
			END
		END
		ELSE IF @RecvReqMsgName = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
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
#END