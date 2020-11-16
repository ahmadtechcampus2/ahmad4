################################################################################
CREATE TRIGGER trg_NSAccountBalancesScheduling000_delete
	ON [NSAccountBalancesScheduling000] FOR DELETE
	NOT FOR REPLICATION
AS 
	SET NOCOUNT ON 
	
	DECLARE @JobName NVARCHAR(MAX) = '[Ameen NS SJ][' + DB_NAME() + ']' + (SELECT [Name] FROM DELETED)

	BEGIN TRY
		EXECUTE [msdb].[dbo].[sp_delete_job] @job_name = @JobName
	END TRY
	BEGIN CATCH
		IF ERROR_NUMBER() <> 14262
		BEGIN
			DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
			SELECT @ErrorMessage = ERROR_MESSAGE() + ' Line ' + CAST(ERROR_LINE() AS NVARCHAR(5)), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
		END
	END CATCH
################################################################################
#END
