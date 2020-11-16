#################################################################
CREATE  PROC repHosOperationStatistics
	@Operation	UNIQUEIDENTIFIER,
	@Account	UNIQUEIDENTIFIER,
	@Patient	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@ReportType	INT
AS
SET NOCOUNT ON 
	CREATE TABLE #SecViol
	(
		Type	INT, 
		Cnt 	INTEGER
	) 

	CREATE TABLE #Result 
	(
		OperationName	NVARCHAR(250) COLLATE ARABIC_CI_AI,
		PatientName		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		FileCode		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Date]			DATETIME,
		Cost			FLOAT
	)

	INSERT INTO #Result
		SELECT
			HGO.[Name], F.[Name],F.[Code] ,GT.[Date], GT.Cost - GT.Discount
		FROM
			vwHosFile F INNER JOIN HosGeneralTest000 GT ON F.GUID = GT.FileGUID
			INNER JOIN HosGeneralOperation000 HGO ON HGO.GUID = GT.OperationGUID
		WHERE
			GT.[Date] BETWEEN @StartDate AND @EndDate
			AND (@Operation = 0x0 OR HGO.GUID = @Operation)
			AND (@Account = 0x0 OR GT.AccGUID = @Account)
			AND (@Patient = 0x0 OR F.PatientGUID = @Patient)
		ORDER BY
			HGO.[Name], F.[Name], GT.[Date]

	EXEC [prcCheckSecurity]

	IF @ReportType = 0
		SELECT
			OperationName, COUNT(*) AS OperationCount, SUM(Cost) AS TotalCost
		FROM
			#Result
		GROUP BY
			OperationName
	ELSE
		SELECT
			OperationName, PatientName, FileCode,[Date], SUM(Cost) AS TotalCost
		FROM
			#Result
		GROUP BY
			OperationName, [Date], PatientName,  FileCode

	SELECT * FROM #SecViol	

/*
	EXEC repHosOperationStatistics '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '1/1/2004', '12/31/2005', 1	
*/

#################################################################
#END