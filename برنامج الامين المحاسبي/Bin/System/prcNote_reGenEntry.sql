#########################################################
CREATE PROC prcNote_reGenEntry
	@srcGUID [UNIQUEIDENTIFIER] = NULL,
	@startDate [DATETIME] = '1-1-1900',
	@endDate [DATETIME] = '1-1-9999'
AS
/*
this procedure:
*/
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER],
		@n [INT]

	BEGIN TRAN

	ALTER TABLE [ce000] DISABLE TRIGGER [trg_ce000_update]

	SET @c = CURSOR FAST_FORWARD FOR
				SELECT [ch].[chGUID], [ch].[ceNumber]
				FROM [fnGetNotesTypesList](@srcGUID, DEFAULT) AS [nt] INNER JOIN [vwChCe] AS [ch] ON [nt].[GUID] = [ch].[chType]
				WHERE [ch].[chDate] BETWEEN @startDate AND @endDate
				ORDER BY [ch].[chDate], [ch].[chNumber]

	OPEN @c FETCH FROM @c INTO @g, @n

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcNote_GenEntry] @g, @n
		FETCH FROM @c INTO @g, @n
	END
	CLOSE @c
	DEALLOCATE @c

	EXEC [prcEntry_rePost]

	ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_update]

	COMMIT TRAN

#########################################################
#END