############################################################################################
CREATE PROC prcCheckDB_bi_QtyMinus
	@Correct [INT] = 0
AS
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [c1], [c2], [g1], [g2])
			SELECT 0x40A, CAST( [bi].[Qty] AS [NVARCHAR](100)), '1', [bu].[GUID], [bi].[MatGuid]
			FROM 
				[bu000] AS [bu] INNER JOIN [bi000] AS [bi]
				ON [bu].[GUID] = [bi].[ParentGUID]
			WHERE
				[bi].[Qty] < 0.00 OR [bi].[Qty] > 10000000000000000.0


	-- correct qty in bill item set 1
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers  'bi000'
		UPDATE [bi000] SET [Qty] = 1 WHERE [Qty] < 0.00 or [Qty] > 10000000000000000.0
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END
############################################################################################
#END