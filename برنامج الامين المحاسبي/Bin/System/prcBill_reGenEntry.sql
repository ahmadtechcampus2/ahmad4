#########################################################
CREATE PROC prcBill_reGenEntry
	@srcGUID [UNIQUEIDENTIFIER] = NULL,
	@startDate [DATETIME] = '1-1-1900',
	@endDate [DATETIME] = '1-1-9999'
AS
/*
this procedure:
	- regenerate entries for given srcGuid, between two dates.
	- THIS PROC IS NOT USED FROM AL-AMEEN BECAUSE IT CAN'T RETURN A PROGRESS PARAMETER FOR THE USER. THOUGH ITS 30% FASTER.

*/
	SET NOCOUNT ON
	
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER],
		@n [INT]

	BEGIN TRAN

	EXEC prcDisableTriggers	'ce000', 0
	ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_delete] -- necessary for er000 handling
	EXEC prcDisableTriggers	'en000', 0
	EXEC prcDisableTriggers	'bu000', 0
	EXEC prcDisableTriggers	'bi000', 0

	SET @c = CURSOR FAST_FORWARD FOR
				SELECT [bu].[buGUID],[bu].[ceNumber]
				FROM [fnGetBillsTypesList](@srcGUID, DEFAULT) AS [bt] INNER JOIN [vwBuCe] AS [bu] ON [bt].[GUID] = [bu].[butype]
				WHERE [bu].[buDate] BETWEEN @startDate AND @endDate
				ORDER BY [bu].[buSortFlag],[bu].[buDate],[bu].[buNumber]

	OPEN @c FETCH FROM @c INTO @g, @n

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcBill_GenEntry] @g, @n, @maintenanceMode = 1
		FETCH FROM @c INTO @g, @n
	END
	CLOSE @c
	DEALLOCATE @c

	EXEC [prcBill_rePost] 1
	EXEC [prcEntry_rePost]

	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'
	EXEC prcEnableTriggers 'bu000'
	EXEC prcEnableTriggers 'bi000'

	COMMIT TRAN

#########################################################
#END
