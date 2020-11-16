############################################################################################
CREATE PROCEDURE prcCheckDB_ac_Fields
	@Correct [INT] = 0
AS
	DECLARE @ep DATETIME, @fp DATETIME;

	SELECT @ep = CAST([Value] AS DATETIME) FROM [op000] WHERE [NAME] = 'AmnCfg_EPDate'
	SELECT @fp = CAST([Value] AS DATETIME) FROM [op000] WHERE [NAME] = 'AmnCfg_FPDate'

	IF @Correct <> 1
	BEGIN
		/* Check CurrencyGuid of acc*/				
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 
				0x09, [ac].[GUID], 'CurrencyGuid not found', CAST( [ac].[CurrencyGuid] AS [NVARCHAR](100))
			FROM 
				[ac000] AS [ac] LEFT JOIN [my000] AS [my] 
				ON [ac].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Guid] IS NULL

		/* Check CurrencyVal <> 1 FOR Base Currency of acc*/
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 
				0x09, [ac].[GUID], 'CurrencyVal <> 1 FOR Base Currency', CAST( [ac].[CurrencyVal] AS [NVARCHAR](100))
			FROM 
				[ac000] AS [ac] INNER JOIN [my000] AS [my] 
				ON [ac].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Number] = 1 AND [ac].[CurrencyVal] <> 1
		/* Check CheckDate > date End period*/
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT  
				0x09, [ac].[GUID], 'Check Date > End Period', CAST( [ac].[CheckDate] AS [NVARCHAR](100)) 
			FROM  
				[ac000] AS [ac]
			WHERE  
				[ac].[CheckDate] > @ep

	END
	
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'ac000'

			/* Update CurrencyGuid of acc*/
			DECLARE @CurGuid [UNIQUEIDENTIFIER]
			SELECT @CurGuid = [Guid] FROM [my000] WHERE [Number] = 1

			UPDATE [ac] SET [ac].[CurrencyGuid] = @CurGuid, [ac].[CurrencyVal] = 1
			FROM 
				[ac000] AS [ac] LEFT JOIN [my000] AS [my] 
				ON [ac].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Guid] IS NULL

			/* Update CurrencyVal <> 1 FOR Base Currency of acc*/
			UPDATE [ac] SET [ac].[CurrencyVal] = 1
			FROM 
				[ac000] AS [ac] INNER JOIN [my000] AS [my] 
				ON [ac].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Number] = 1 AND [ac].[CurrencyVal] <> 1

			/* Check CheckDate > date End period*/
			UPDATE [ac] SET [ac].[CheckDate] = @fp
			FROM  
				[ac000] AS [ac]
			WHERE  
				[ac].[CheckDate] > @ep

		ALTER TABLE [ac000] ENABLE TRIGGER ALL
	END
############################################################################################
#END