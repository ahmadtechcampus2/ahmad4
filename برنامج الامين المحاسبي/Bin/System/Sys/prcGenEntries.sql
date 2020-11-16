#####################################################################################
CREATE PROCEDURE prcGenEntriesPrepareWithDisableTrigger
	@SrcGuid	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@Lang		[BIT]	
AS
		SET NOCOUNT ON

		EXEC prcDisableTriggers 'ce000'
		ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_delete] -- necessary for er000 handling
		EXEC prcDisableTriggers 'en000'
		EXEC prcDisableTriggers 'bu000'
		EXEC prcDisableTriggers 'bi000'
		ALTER TABLE [en000] ENABLE TRIGGER [trg_en000_delete]

		EXEC prcGenEntriesPrepare @SrcGuid,@StartDate,@EndDate,@Lang
#####################################################################################
CREATE PROCEDURE prcGenEntriesPrepare
	@SrcGuid	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@Lang		[BIT]	
AS
		SET NOCOUNT ON
		DECLARE @Cnt INT
		
		select a.Guid,bAutoEntry,CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [Name] 
		INTO #bu from  [fnGetBillsTypesList](@SrcGuid, DEFAULT) a INNER JOIN bt000 b ON b.Guid = a.Guid
		CREATE TABLE #Bill
		(
			[ID] INT IDENTITY(1,1),
			BuGuid UNIQUEIDENTIFIER,
			BtGuid UNIQUEIDENTIFIER,
			[btName] [NVARCHAR] (256) COLLATE ARABIC_CI_AI,
			buNumber INT,ceGuid UNIQUEIDENTIFIER,
			bAutoEntry BIT,
			BuDate DATETIME
		)
		INSERT INTO #Bill(BuGuid,BtGuid,[btName],buNumber,ceGuid,bAutoEntry,BuDate)
		SELECT bu.Guid,bu.TypeGuid,[Name],bu.Number,ISNULL(entryGuid,0x00),bAutoEntry,bu.Date
		FROM vbbu bu INNER JOIN #bu b ON bu.TypeGuid = b.Guid
		LEFT JOIN er000 er ON er.ParentGuid = bu.Guid
		WHERE [bu].[Date] BETWEEN @StartDate AND @EndDate
		ORDER BY [bu].[Date],[bu].[Number]
		
		SELECT  @Cnt = COUNT(*) FROM #Bill
		SELECT BuGuid,[btName],BtGuid,buNumber,ceGuid,bAutoEntry,ISNULL(b.Number,0) AS ceNumber,@Cnt as [Count],BuDate
		FROM #Bill a LEFT JOIN ce000 b ON b.Guid = a.ceGuid
		WHERE bAutoEntry > 0 OR a.ceGuid <> 0X00
		ORDER BY [ID]
#####################################################################################
CREATE PROCEDURE prcGenEntriesFinalize
AS
	SET NOCOUNT ON
	EXEC prcEnableTriggers 'ce000'
	EXEC prcEnableTriggers 'en000'
	EXEC prcEnableTriggers 'bu000'
	EXEC prcEnableTriggers 'bi000'

	-- EXEC prcEntry_rePost -- will be invoked from C
#####################################################################################	
CREATE PROCEDURE prcBill_Delete_Entry @BillGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	DECLARE @EntryGuid UNIQUEIDENTIFIER
	SELECT @EntryGuid = EntryGuid FROM er000 WHERE ParentGuid = @BillGuid
	IF ( ISNULL( @EntryGuid, 0x0) <> 0x0)
	BEGIN 
		EXEC prcDisableTriggers  'ce000'
		EXEC prcDisableTriggers  'en000'
		EXEC prcDisableTriggers  'er000'

		DELETE FROM ce000 WHERE Guid = @EntryGuid
		DELETE FROM en000 WHERE ParentGuid = @EntryGuid
		DELETE FROM er000 WHERE ParentGuid = @BillGuid

		EXEC prcEnableTriggers 'ce000'
		EXEC prcEnableTriggers 'en000'
		EXEC prcEnableTriggers 'er000'
	END
#####################################################################################
#END