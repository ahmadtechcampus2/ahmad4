################################################################################ 
CREATE TRIGGER trg_errorLog ON [ErrorLog] FOR INSERT
	NOT FOR REPLICATION

AS
	IF @@ROWCOUNT = 0
		RETURN

	SET NOCOUNT ON
	-- level 0 means here: Do Nothing

	-- raiserror for level 1 and 2, only if flag 1000 is not set:
	IF EXISTS( SELECT  * FROM [inserted] WHERE [level] IN (1, 2))
		IF [dbo].[fnFlag_isSet](1000) = 0
		BEGIN
			DECLARE
				@c CURSOR,
				@msg [NVARCHAR](255),
				@level INT				

			SET @c = CURSOR FAST_FORWARD FOR SELECT DISTINCT TOP 5 [c1], [level] FROM [inserted] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID() AND (ISNULL( [c1], '') != '')
			OPEN @c FETCH FROM @c INTO @msg, @level
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @msg = REPLACE( @msg, '%', '%%')			
				IF ISNULL( @msg, '') != ''
				BEGIN
					IF ((@level = 1) OR ((@level = 2) AND (dbo.fnConnections_IsIgnoreWarnings() = 0)))
						RAISERROR ( @msg, 16, 1)
				END
				FETCH FROM @c INTO @msg, @level
			END
			CLOSE @c DEALLOCATE @c
		END

	/*
	-- rollback for level 1 only if flag 1001 is not set, and a transaction is pending:
	IF EXISTS( SELECT * FROM [inserted] WHERE [level] = 1)
		IF [dbo].[fnFlag_isSet](1001) = 0 AND @@TRANCOUNT != 0
			ROLLBACK TRAN
	*/
################################################################################
#END
