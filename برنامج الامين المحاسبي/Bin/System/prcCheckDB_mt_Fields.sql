############################################################################################
CREATE PROCEDURE prcCheckDB_mt_Fields
	@Correct [INT] = 0
AS
	IF @Correct <> 1
	BEGIN
		/* Check ForceInSn = 0, ForceOutSn = 0, SNFlag = 0*/
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 
				0x0C, [mt].[GUID], 'ForceInSn OR ForceOutSn without SNFlag'
			FROM 
				[mt000] AS [mt] 
			WHERE
				ISNULL( [SNFlag], 0) <> 1 AND ( ISNULL( [ForceInSn], 0) > 0 OR ISNULL( [ForceOutSn], 0) > 0)

		/* Check CurrencyGuid of mat*/				
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 
				0x0C, [mt].[GUID], 'CurrencyGuid not found', CAST( [mt].[CurrencyGuid] AS [NVARCHAR](100))
			FROM 
				[mt000] AS [mt] LEFT JOIN [my000] AS [my] 
				ON [mt].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Guid] IS NULL

		/* Check CurrencyVal <> 1 FOR Base Currency of mat*/				
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 
				0x0C, [mt].[GUID], 'CurrencyVal <> 1 FOR Base Currency', CAST( [mt].[CurrencyVal] AS [NVARCHAR](100))
			FROM 
				[mt000] AS [mt] INNER JOIN [my000] AS [my] 
				ON [mt].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Number] = 1 AND [mt].[CurrencyVal] <> 1

		/* Check PriceType of mat*/
		INSERT INTO [ErrorLog]([Type], [g1], [c1])
			SELECT 
				0x0C, [mt].[GUID], 'PriceType not found'
			FROM 
				[mt000] AS [mt]
			WHERE 
				ISNULL( [PriceType], 0) NOT IN( 15, 120, 121, 122, 128)
	END
	
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'mt000'
			/* Update ForceInSn = 0, ForceOutSn = 0, SNFlag = 0*/
			UPDATE [mt000] SET 
				[ForceInSn] = CASE WHEN [Type] = 2 THEN 1 ELSE 0 END,
				[ForceOutSn] = CASE WHEN [Type] = 2 THEN 1 ELSE 0 END,
				[SNFlag] = CASE WHEN [Type] = 2 THEN 1 ELSE 0 END
			WHERE
				ISNULL( [SNFlag], 0) <> 1 AND ( ISNULL( [ForceInSn], 0) > 0 OR ISNULL( [ForceOutSn], 0) > 0)
			
			/* Update CurrencyGuid of mat*/
			DECLARE @CurGuid [UNIQUEIDENTIFIER]
			SELECT @CurGuid = [Guid] FROM [my000] WHERE [Number] = 1

			UPDATE [mt] SET [mt].[CurrencyGuid] = @CurGuid, [mt].[CurrencyVal] = 1
			FROM 
				[mt000] AS [mt] LEFT JOIN [my000] AS [my] 
				ON [mt].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Guid] IS NULL

			/* Update CurrencyVal <> 1 FOR Base Currency of mat*/				
			UPDATE [mt] SET [mt].[CurrencyVal] = 1
			FROM 
				[mt000] AS [mt] INNER JOIN [my000] AS [my] 
				ON [mt].[CurrencyGuid] = [my].[Guid]
			WHERE 
				[my].[Number] = 1 AND [mt].[CurrencyVal] <> 1

			/* Update PriceType of mat*/
			UPDATE [mt] SET [mt].[PriceType] = 15
			FROM 
				[mt000] AS [mt] 
			WHERE 
				ISNULL( [PriceType], 0) NOT IN( 15, 120, 121, 122, 128)

		ALTER TABLE [mt000] ENABLE TRIGGER ALL
	END
############################################################################################
#END