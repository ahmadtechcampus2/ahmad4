############################################################################################
CREATE PROCEDURE prcCheckDB_bi_Units
	@Correct [INT] = 0
AS
	-- Qty2 or Qty3 <> 0 for relative units:
	IF @Correct <> 0 
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		UPDATE [bi000] SET [Qty2] = [bi].[Qty] / CASE [mt].Unit2Fact WHEN 0 THEN 1 ELSE [mt].Unit2Fact  END FROM [bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID] WHERE [mt].[Unit2FactFlag] = 0

		UPDATE [bi000] SET [Qty3] = [bi].[Qty] / CASE [mt].Unit3Fact WHEN 0 THEN 1 ELSE [mt].Unit3Fact END FROM [bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID] WHERE [mt].[Unit3FactFlag] = 0
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END

	-- Qty2 or Qty3 = 0 for a non-relative units:
	IF @Correct <> 1
	BEGIN
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x406, [bi].[ParentGUID]
			FROM [bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]
			WHERE [mt].[Unit2FactFlag] <> 0 AND [bi].[Qty2] = 0
			UNION ALL
			SELECT 0x406, [bi].[ParentGUID]
			FROM [bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]
			WHERE [mt].[Unit3FactFlag] <> 0 AND [bi].[Qty3] = 0
	END
	
	INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x40C, [bi].[ParentGUID]
				FROM [bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID] 
				WHERE ([bi].Unity = 2 AND [mt].Unit2 = '')OR
					  ([bi].Unity = 3 AND [mt].Unit3 = '')

	INSERT INTO [ErrorLog] ([Type], [c1], [c2]) 
			SELECT 0x40D, [Fm].[Number], [Fm].[Name]
				FROM Mi000 Mi 
				INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid
				INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid
				INNER JOIN FM000 Fm ON Fm.Guid = Mn.FormGuid
				WHERE MN.Type = 0
					AND
					(
						([mi].Unity = 2 AND [mt].Unit2 = '')
						OR 
						([mi].Unity = 3 AND [mt].Unit3 = '') 
					)
		
	INSERT INTO [ErrorLog] ([Type], [g1], [c1]) 
			SELECT 0x40E, [Mn].[Guid], Mt.Name
				FROM Mi000 Mi 
				INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid
				INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid
				WHERE MN.Type = 1
					AND
					(
						([mi].Unity = 2 AND [mt].Unit2 = '')
						OR 
						([mi].Unity = 3 AND [mt].Unit3 = '') 
					)
############################################################################################
#END