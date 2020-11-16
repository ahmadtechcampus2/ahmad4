##################################################################################
CREATE PROCEDURE RepAnalysisTree
	@Lang		INT = 0
AS 
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT) 
	CREATE TABLE #Result( 
			Guid		UNIQUEIDENTIFIER, 
			ParentGuid 	UNIQUEIDENTIFIER, 
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Name]	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[LatinName]	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Number		FLOAT, 
			Security INT, 
			Type 		INT,
			[Level] 	INT, 
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI 
		   	) 
	 
	INSERT INTO #Result  
	SELECT  
			ana.Guid,  
			ISNull(ana.ParentGUID , 0x0) AS Parent, 
			ana.Code,  
			Ana.Name,
			Ana.LatinName,
			ana.Number, 
			ana.Security, 
			ana.Type,
			fn.[Level],
			fn.Path 
		FROM 	
			vwHosAnalysisAll as ana INNER JOIN dbo.fnGetAnalysisListSorted( 0x0, 1) AS fn 
			ON ana.Guid = fn.Guid
	EXEC prcCheckSecurity 
	SELECT * FROM #Result ORDER BY Path 
	SELECT * FROM #SecViol
##################################################################################
CREATE PROCEDURE RepHosAnalysisOrder
	@PatientGUID 	UNIQUEIDENTIFIER = 0x0,
	@FileGUID  		UNIQUEIDENTIFIER = 0x0,
	@AccGUID  		UNIQUEIDENTIFIER = 0x0,
	@FromDate  		DATETIME = '1-1-2000',
	@ToDate  		DATETIME = '1-1-2050',
	@Status  		NVARCHAR(250) = '',
	@SortBy			INT = 0
AS
SET NOCOUNT ON
if ( @Status = '' ) 
	SET @Status = '0'
	
CREATE TABLE #T ( Status INT )
INSERT INTO #T  SELECT CAST(DATA AS  INT )FROM dbo.fnTextToRows(@Status)
SELECT 
	* 
FROM 
	vwHosAnalysisOrder   O INNER JOIN #T  S  ON O.Status = S.Status
WHERE 
	(O.PatientGUID = @PatientGUID OR  @PatientGUID = 0x0)
	AND
	(O.FileGUID = @FileGUID OR @FileGUID = 0x0)
	AND
	(O.AccGUID = @AccGUID OR @FileGUID = 0x0)
	AND
	(O.[Date] BETWEEN @FromDate AND  @ToDate)
ORDER BY CASE WHEN @SortBy = 0 THEN O.[Date] ELSE O.Number END
##################################################################################
#END
