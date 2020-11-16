###########################################
CREATE PROCEDURE prcImpExpGetAccList
	@UseChecks		[INT], --- 0 , 1
	@UseManualEn	[INT],
	@StartDate		[DATETIME],
	@EndDate 		[DATETIME]
AS

CREATE TABLE [#R]
(
	[AccountGuid]		[UNIQUEIDENTIFIER]
)
IF @UseChecks = 1
BEGIN
	INSERT INTO [#R]
		SELECT
			[en].[AccountGuid]
		FROM
			[er000] AS [er] 
			INNER JOIN [ch000] AS [ch] ON [er].[ParentGuid] = [ch].[Guid]
			INNER JOIN [en000] AS [en] ON [en].[ParentGuid] = [er].[EntryGuid]
		WHERE
			[er].[ParentType] != 5
		
	INSERT INTO [#R]
		SELECT
			[DefPayAccGuid]
		FROM
			[nt000] AS [nt]
	INSERT INTO [#R]
		SELECT
			[DefRecAccGuid]
		FROM
			[nt000] AS [nt] 

-- select * from nt000 ch000 as ch inner join nt000 nt on ch.


END

IF @UseManualEn = 1
BEGIN
	INSERT INTO [#R]
	SELECT [AccountGuid] from [en000] WHERE [Date] BETWEEN @StartDate AND @EndDate
END
	SELECT * FROM [#R]
/*

prcImpExpGetAccList
select * from en000
select AccountGuid from en000 WHERE Date between

*/
###########################################
