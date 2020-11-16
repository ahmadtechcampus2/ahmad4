################################################################################
CREATE PROCEDURE NSPrcCheckManualEventConditions
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
			  FROM ManualEventConditionsQueue
			), TIMEOUT 5000;

			IF (@@ROWCOUNT = 0)
			BEGIN
			  ROLLBACK TRANSACTION;
			  BREAK;
			END
			
			IF @RecvReqMsgName = N'DEFAULT'
			BEGIN

				DECLARE @sql				NVARCHAR(MAX)
				DECLARE @xmlMessage			XML
				DECLARE @objectGuid			UNIQUEIDENTIFIER
				DECLARE @message			XML

				SET @xmlMessage = CAST(@RecvReqMsg AS XML)
				SET @objectGuid = (SELECT @xmlMessage.value('(/manualEvent/objectGuid)[1]', 'UNIQUEIDENTIFIER'))
				SET @message = @xmlMessage.query('/manualEvent/Message/Message');

				BEGIN TRY

					EXEC NSSendManualMessage @message, @objectGuid, ManualEventConditionsService

				END TRY
				BEGIN CATCH
			
					DECLARE @ErrorMessage NVARCHAR(4000);
					DECLARE @ErrorSeverity INT;
					DECLARE @ErrorState INT;
					
					SELECT 
						@ErrorMessage = ERROR_MESSAGE() + 'NSPrcCheckManualEventConditions1 Error',
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

		INSERT INTO NSLog000 (Value, [Time]) VALUES (error_message() + CAST((N'NSPrcCheckManualEventConditions Error ') AS NVARCHAR(MAX)), CURRENT_TIMESTAMP)
	END CATCH
END
################################################################################
#END