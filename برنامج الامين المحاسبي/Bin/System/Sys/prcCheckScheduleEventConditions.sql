################################################################################
CREATE PROCEDURE NSPrcCheckScheduleEventConditions
AS 
BEGIN

	SET NOCOUNT ON

	EXEC NSPrcConnectionsAddAdmin

	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER
	DECLARE @RecvReqMsg NVARCHAR(MAX)
	DECLARE @RecvReqMsgName SYSNAME

	create TABLE #object
	(
		[GUID]	UNIQUEIDENTIFIER
	)

	BEGIN TRY
		WHILE (1=1)
		BEGIN

			BEGIN TRANSACTION;

			WAITFOR
			( RECEIVE TOP(1)
				@RecvReqDlgHandle = conversation_handle,
				@RecvReqMsg = message_body,
				@RecvReqMsgName = message_type_name
			  FROM ScheduleEventConditionsQueue
			), TIMEOUT 5000;

			IF (@@ROWCOUNT = 0)
			BEGIN
			  ROLLBACK TRANSACTION;
			  BREAK;
			END
			
			IF @RecvReqMsgName = N'DEFAULT'
			BEGIN

				DECLARE @sql		NVARCHAR(MAX)
				DECLARE @xmlMessage XML
				DECLARE @objectGuid	UNIQUEIDENTIFIER
				DECLARE @objectID	INT
				DECLARE @eventID	INT

				SET @xmlMessage = CAST(@RecvReqMsg AS XML)
				SET @objectID	= (SELECT @xmlMessage.value('(/scheduleEvent/objectID)[1]', 'int'))
				SET @eventID	= (SELECT @xmlMessage.value('(/scheduleEvent/eventID)[1]', 'int'))

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

						DELETE #object
						SET @sql = 'INSERT INTO #object (guid) SELECT GUID FROM ' + @eventConditionFunction + '(' +'''' + CAST (@eventConditonGuid AS VARCHAR(50)) + '''' + ' , '+ 'current_timestamp' + ')'

						EXECUTE sp_executesql  @SQL
						--------------------------------
						DECLARE objectCursor CURSOR
						FOR 
							SELECT * FROM #object

						OPEN objectCursor
						FETCH NEXT FROM objectCursor INTO @objectGuid

						WHILE @@FETCH_STATUS = 0
						BEGIN

							EXEC @result = @objectConditionFunction @notificationGuid, @objectGuid
							IF @result = 1
							BEGIN
								EXEC NSSendEventCondtionMessages @eventConditonGuid, @objectGuid, ScheduleEventConditionsService
							END				

							FETCH NEXT FROM objectCursor INTO @objectGuid
						END

						CLOSE objectCursor;
						DEALLOCATE objectCursor;
						--------------------------------

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
						@ErrorMessage = ERROR_MESSAGE() + N'Error Schedule Event Condition Function ' + @eventConditionFunction + ' Object Condition Function ' + @objectConditionFunction + '(' +'''' + CAST (@ObjectGuid AS varCHAR(50)) + '''' + ') ',
						@ErrorSeverity = ERROR_SEVERITY(),
						@ErrorState = ERROR_STATE();
			
					RAISERROR (@ErrorMessage, -- Message text.
					       @ErrorSeverity, -- Severity.
					       @ErrorState -- State.
					       );
				END CATCH
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

			COMMIT TRANSACTION
		END -- while
	END TRY
	BEGIN CATCH
		IF ( XACT_STATE() != 0 ) 
			ROLLBACK TRAN ;

		INSERT INTO NSLog000 (Value, [Time]) VALUES (error_message() + CAST((N'NSPrcCheckScheduleEventConditions Error ') AS NVARCHAR(MAX)), CURRENT_TIMESTAMP)
	END CATCH
END
################################################################################
#END
--exec NSPrcObjectEvent 0x0, 0, 0

--NSPrcObjectCheckEventConditions

--select * from  NSEvent000
--select * from  NSEventCondition000
--select * from  NSNotification000
--select * from  NSMessage000


--delete NSNotification000
--delete NSEvent000
--delete NSEventCondition000
--delete NSMessage000

--update NSNotification000 set ConditionFunction = 'NSFnCheckNotificationCondition1'
--update NSEventCondition000 set ConditionFunction = 'NSFnCheckNotificationCondition1'

----DELETE DBLog WHERE Notes LIKE '%service_broker%'
--SELECT * FROM DBLog WHERE Notes LIKE '%service_broker%' ORDER BY TIME


--drop proc NSPrcCheckScheduleEventConditions
--
--select * from NSEvent000
--
--select * from 
--
--exec NSPrcSchedulevent 0, 5
--NSPrcCheckScheduleEventConditions
--SELECT * FROM DBLog WHERE Notes LIKE '%service_broker%' ORDER BY TIME
--
--
--select * from sys.transmission_queue



