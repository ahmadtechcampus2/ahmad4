###############################################
## repBillExpNum
## this procedure gets all numbers of every type of bills between two dates
############################################### 
CREATE PROCEDURE repBillExpNum
	@StartDate 	[DATETIME],
	@EndDate 	[DATETIME],
	@SrcGuid	[UNIQUEIDENTIFIER],
	@Type		[INT] = 0 -- 0 Bills, 1 Pay, 2 Checks , 3 Manual entries
AS
	SET NOCOUNT ON
	IF @Type = 0 
	BEGIN
		CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])   
		INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid
	
		SELECT
			[buType] AS [Type],
			[buGuid] AS [Number],
			[BuSortFlag]
		FROM
			[vwBu] AS [bu] INNER JOIN [#BillTbl] As [bt] ON [bu].[buType] = [bt].[Type]
		WHERE
			[buDate] BETWEEN @StartDate AND @EndDate 
		ORDER BY
			[BuDate],
			[BuSortFlag],
			[buType],
			[buNumber]
			/*buType, buDate, buNumber --, buBranch later*/
	END
	ELSE IF @Type = 1
	BEGIN
		CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
		INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid
		SELECT
			[pyTypeGuid] AS [Type],
			[pyGuid] AS [Number]
		FROM [vwPy] AS [py] RIGHT JOIN [#EntryTbl] AS [et] ON [py].[pyTypeGuid] = [et].[Type]
		WHERE
			[pyDate] BETWEEN @StartDate AND @EndDate
		ORDER BY
			[pyTypeGuid], [pyDate], [pyNumber] --,pyBranch
	END
	ELSE IF @Type = 2
	BEGIN
		CREATE TABLE [#NotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
		INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid

		SELECT
			[chType]	AS [Type],
			[chGuid]	AS [Number],
			[wn].[ntDefPayAcc],
			[wn].[ntDefRecAcc]
		FROM
			[vwch] AS [ch] INNER JOIN [#NotesTbl] As [nt] ON [ch].[chType] = [nt].[Type]
			INNER JOIN [vwnt] AS [wn] ON [ch].[chtype] = [wn].[ntGuid] --- select * from vwnt
		WHERE
			[chDate] BETWEEN @StartDate AND @EndDate
		ORDER BY
			[chType], [chDate], [chNumber]--, chBranchGuid
	END
	ELSE IF @Type = 3
	BEGIN
		--CREATE TABLE #EnTbl( Type [UNIQUEIDENTIFIER], Security INT)
		--INSERT INTO #EnTbl EXEC prcGetEntriesTypesList @SrcGuid
		--select * from #EnTbl
		SELECT
			[ceGuid]
		FROM [vwCe]
		WHERE
			[ceTypeGuid] = 0x0
			AND [ceDate] BETWEEN @StartDate AND @EndDate
		ORDER BY
			[ceDate], [ceNumber] --,ceBranch
	END

/*
select buSortFlag from vwbu
CREATE TABLE #EnTbl( Type [UNIQUEIDENTIFIER], Security INT)
INSERT INTO #EnTbl EXEC prcGetEntriesTypesList 0x0 
select * from vwce 
select * from #EnTbl
drop table #EnTbl
EXEC repBillExpNum '1/1/2004', '12/31/2004', 0x0, 0

	BuDate,
	BuSortFlag,
	buType,
	BuNumber

EXEC repBillExpNum '2/21/2003', '2/21/2005', 0x0, 2

select * from st000 0de89fb0-5162-4a34-b645-8975d201e678
*/
############################################### 
#END