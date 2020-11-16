############################################################################################
CREATE PROCEDURE prcCheckDB_ce_Sums
	@Correct [INT] = 0
AS
	DECLARE @zero [FLOAT]
	
	SELECT @zero = [dbo].[fnGetZeroValuePrice]()

	-- Sums:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x505, [GUID]
			FROM [ce000]
			WHERE
				ABS(ISNULL([Debit], 0) - ISNULL((SELECT SUM( [en].[Debit]) FROM [en000] AS [en] WHERE [en].[ParentGUID] = [ce000].[GUID]), 0)) > @zero
				OR
				ABS(ISNULL([Credit], 0) - ISNULL((SELECT SUM( [en].[Credit]) FROM [en000] AS [en] WHERE [en].[ParentGUID] = [ce000].[GUID]), 0)) > @zero

	-- correct Totals if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET
			[Debit] = (SELECT SUM([Debit]) FROM [en000] WHERE [en000].[ParentGUID] = [ce000].[GUID]),
			[Credit] = (SELECT SUM([Credit]) FROM [en000] WHERE [en000].[ParentGUID] = [ce000].[GUID])
		FROM
			[ce000]
		WHERE
			ABS(ISNULL([Debit], 0) - ISNULL((SELECT SUM( [en].[Debit]) FROM [en000] AS [en] WHERE [en].[ParentGUID] = [ce000].[GUID]), 0)) > @zero
			OR
			ABS(ISNULL([Credit], 0) - ISNULL((SELECT SUM( [en].[Credit]) FROM [en000] AS [en] WHERE [en].[ParentGUID] = [ce000].[GUID]), 0)) > @zero
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

	-- unbalancing:
	IF @Correct <> 1
	BEGIN
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x50C, [parentGuid]
			FROM [en000]
			GROUP BY [parentGuid]
			HAVING ABS(SUM([debit]) - SUM([credit])) > @zero
	END

############################################################################################
#END