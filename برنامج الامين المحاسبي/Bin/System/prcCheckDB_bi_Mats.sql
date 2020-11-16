############################################################################################
CREATE PROCEDURE prcCheckDB_bi_Mats
	@Correct [INT] = 0
AS
	-- bi without MatPtr:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x402, [bi].[ParentGUID] FROM [bi000] AS [bi] LEFT JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID] WHERE [mt].[GUID] IS NULL

############################################################################################
#END