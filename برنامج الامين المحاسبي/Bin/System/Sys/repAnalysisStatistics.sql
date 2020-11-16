##############################################################################
CREATE PROCEDURE repAnalysisStatistics
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@PatientGuid		UNIQUEIDENTIFIER = 0x0,
	@AnalysisGuid		UNIQUEIDENTIFIER = 0x0,
	@ShowDetails		INT = 0,
	@PatientType		INT = -1 ---- 0 internal , 1 Extermal , -1 ALL
AS
	CREATE TABLE #Result
	(
		[AnaCode]			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[AnaName]			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[PatientGuid]		UNIQUEIDENTIFIER,
		[PatientName]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[Cnt]				FLOAT
	)
	INSERT INTO #Result
	SELECT
		O.[AnalysisCode],
		O.[AnalysisName],
		ISNULL( H.[PatientGUID], O.[PatientGUID]),
		ISNULL( H.[Name], O.[PatientName]),
		Count(*)
	FROM
		[vwHosToDoAnalysis] AS O
		LEFT JOIN [vwHosFile] AS H ON O.[FileGUID] = H.[GUID]
	WHERE
		O.[Date] BETWEEN @StartDate AND @EndDate
		AND ( (O.[PatientGUID] = @PatientGUID) OR ( H.[PatientGUID] = @PatientGUID) OR ( @PatientGUID = 0x0))
		AND ( (@AnalysisGuid = 0x0) OR ( @AnalysisGuid = O.AnalysisGuid))
		AND ( 
				(@PatientType = -1 ) 
				OR ( @PatientType = 0 AND O.[FileGUID] <> 0x0 AND O.[FileGUID] IS NOT NULL ) 
				OR ( @PatientType = 1 AND O.[PatientGUID] <> 0x0 AND O.[PatientGUID] IS NOT NULL )
			)
	GROUP BY
		O.[AnalysisCode],
		O.[AnalysisName],
		O.[PatientGuid],
		H.[PatientGUID],
		H.[Name], 
		O.[PatientName]

---- RETURN RESULT SET
	IF @ShowDetails = 1 
		SELECT * FROM #Result
	ELSE
		SELECT
			[AnaCode],
			[AnaName],
			SUM( Cnt) AS Cnt
		FROM
			#Result
		GROUP BY
			[AnaCode],
			[AnaName]

/*

EXEC repAnalysisStatistics
'3/1/2005',			--	@StartDate	DATETIME,
'12/30/2005',		--	@EndDate	DATETIME
0x0, 				--'E947A0B7-E2D8-4744-B565-0717429CCF6E',		--  @PatientGuid UNIQUEIDENTIFIER = 0x0
0x0,				--'D0135374-3B48-46FB-A19F-964CC024C49A', --0x0
1,					--	@ShowDetails		INT = 0
0					-- @PatientType		INT = -1 ---- 0 internal , 1 Extermal , -1 ALL
select * from vwHosToDoAnalysis
select * from HosAnalysisOrder000

select * from HosRadioGraphyOrder000 where code = '2779' or code = '19070'
select * from HosAnalysisOrder000 where code = '4082' or code= '4081'
select * from vwHosToDoAnalysis

exec [repAnalysisStatistics] '1/1/2005', '12/26/2005', 0x0, 0x0, 0, 1
exec [repAnalysisStatistics] '1/1/2005', '12/26/2005', 0x0, 0x0, 1, 1

*/

##############################################################################
#END