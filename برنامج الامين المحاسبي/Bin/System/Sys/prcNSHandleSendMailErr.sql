################################################################################
create PROCEDURE prcNSHandleSendMailErr
AS 
BEGIN
	DECLARE @RecvReqDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RecvReqMsg NVARCHAR(max);
	DECLARE @RecvReqMsgName SYSNAME;

	DECLARE @Log NVARCHAR(MAX)
	SET @Log = N'Service_Broker:handleError' + CAST(CURRENT_TIMESTAMP AS NVARCHAR(MAX))
	EXEC prcLog @Log

	WHILE (1=1)
	BEGIN

		BEGIN TRANSACTION;

		RECEIVE TOP(1)
			@RecvReqDlgHandle = conversation_handle,
			@RecvReqMsg = message_body,
			@RecvReqMsgName = message_type_name
		  FROM ErrorMailMessageQueue;

		IF (@@ROWCOUNT = 0)
		BEGIN
		  ROLLBACK TRANSACTION;
		  BREAK;
		END

		IF @RecvReqMsgName = N'DEFAULT'
		BEGIN
			
			DECLARE @handle AS UNIQUEIDENTIFIER

			BEGIN DIALOG CONVERSATION @handle  
			FROM
				SERVICE ErrorMailService
			TO
				SERVICE 'BillReadyMessageService'
			WITH
				ENCRYPTION = OFF;

			SEND ON CONVERSATION @handle (@RecvReqMsg)

			END CONVERSATION @handle

			SET @Log = N'Service_Broker:ReSendErrMailMsg' + @RecvReqMsg
			EXEC prcLog @Log

		END
		ELSE IF @RecvReqMsgName =
			N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
		BEGIN
			END CONVERSATION @RecvReqDlgHandle;
		END
		ELSE
		BEGIN
			SET @Log = CAST((N'Service_Broker:Error' + @RecvReqMsgName) AS NVARCHAR(MAX))
			EXEC prcLog @Log
			END CONVERSATION @RecvReqDlgHandle;
		END

		COMMIT TRANSACTION;
	END
END
################################################################################
#END

