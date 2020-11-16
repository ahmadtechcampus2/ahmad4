#####################################################################################
## Update the final account field for Account table like first parent of accounts
#####################################################################################
CREATE PROC UpdateFinalAccounts @AccGuid [UNIQUEIDENTIFIER]
AS
	-- select * from fnGetAccountsList(0x0, 0) order by Level
	
	DECLARE @FinalGuid [UNIQUEIDENTIFIER], @acGuid [UNIQUEIDENTIFIER], @UpdateSec [INT]

	SELECT @UpdateSec = [dbo].[fnGetUserAccountSec](0x0, 2)

	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [acSecurity] [INT])

	IF ISNULL( @AccGuid, 0x0) = 0x0
		INSERT INTO [#AccTbl] 
			SELECT 
				[ac].[acGUID],
				[ac].[acSecurity]
			FROM 
				[fnGetAccountsList](0x0, 0) as [fn] INNER JOIN [vwAc] AS [ac]
				ON [fn].[Guid] = [ac].[acGuid]
			WHERE 
				[fn].[LEVEL] = 0
				AND [ac].[acType] = 1
	ELSE
		INSERT INTO [#AccTbl] SELECT [acGuid], [acSecurity] FROM [vwAc] WHERE [acGuid] = @AccGuid
	--dbo.fnGetUserAccountSec_Browse
	EXEC [prcCheckSecurity] @Result = '#AccTbl'

	CREATE TABLE [#SonTbl]( [acGUID] [UNIQUEIDENTIFIER], [acSecurity] [INT])

	DECLARE @c_ac CURSOR  	
	SET @c_ac = CURSOR FAST_FORWARD FOR SELECT [GUID] FROM [#AccTbl]
	OPEN @c_ac 
	FETCH NEXT FROM @c_ac INTO @acGuid
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--Print 'acGuid ' + CAST( @acGuid as varchar(100))

		SELECT @FinalGuid = [acFinal] FROM [vwAc] WHERE [acGUID] = @acGuid
	
		IF( ISNULL( @FinalGuid, 0x0) <> 0x0)	
		BEGIN
			--Print 'acFinalGuid ' + CAST( @FinalGuid as varchar(100))
			DELETE FROM [#SonTbl]

			INSERT INTO [#SonTbl]
				SELECT
					[ac].[acGuid],
					[ac].[acSecurity]
				FROM
					[dbo].[fnGetAccountsList]( @acGuid, 0) as [fn] inner join [vwAc] as [ac]
					ON [fn].[Guid] = [ac].[acGuid]
				WHERE
					[acType] = 1

			EXEC [prcCheckSecurity] @Result = '#SonTbl'
			
			UPDATE [vwAc] SET [acFinal] = @FinalGuid
			FROM 
				[vwAc] as [ac] INNER JOIN [#SonTbl] AS [Sql]
				ON [ac].[acGuid] = [Sql].[acGuid]
			WHERE 
				[ac].[acSecurity] <= @UpdateSec -- Update
		END			
		FETCH NEXT FROM @c_ac INTO @acGuid
	END
	CLOSE @c_ac 
	DEALLOCATE @c_ac
#############################################################################3
#END