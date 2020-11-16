############################################################################################
CREATE PROCEDURE prcCheckDB_bu_Nulls
	@Correct [INT] = 0
AS
	-- check NULLs:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x30F, [bu].[GUID] FROM [bu000] AS [bu]
			WHERE
				[Total] IS NULL OR
				[TotalDisc] IS NULL OR
				[TotalExtra] IS NULL OR
				[ItemsDisc] IS NULL OR
				[ItemsDiscAccGUID] IS NULL OR
				[BonusDisc] IS NULL OR
				[FirstPay] IS NULL OR
				[Profits] IS NULL OR
				[IsPosted] IS NULL

	-- correct if necessary:
	IF @Correct <> 0
	BEGIN
			EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET
			[Total] = ISNULL([Total], 0),
			[TotalDisc] = ISNULL([TotalDisc], 0),
			[TotalExtra] = ISNULL([TotalExtra], 0),
			[ItemsDisc] = ISNULL([ItemsDisc], 0),
			[ItemsDiscAccGUID] = ISNULL([ItemsDiscAccGUID], 0x0),
			[BonusDisc] = ISNULL([BonusDisc], 0),
			[FirstPay] = ISNULL([FirstPay], 0),
			[Profits] = ISNULL([Profits], 0),
			[IsPosted] = ISNULL([IsPosted], 0)
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END

############################################################################################
#END