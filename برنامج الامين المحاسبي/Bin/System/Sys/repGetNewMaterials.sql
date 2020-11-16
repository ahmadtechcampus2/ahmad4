################################################################################
CREATE PROCEDURE repGetNewMatrials
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@lang [INT]
AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]	( [Type] [INT], [Cnt] [INT] ) 

	CREATE TABLE [#RESULT] 
	(
		[mtGuid]		[UNIQUEIDENTIFIER],
		[MtName]		[NVARCHAR](250),
		[mtLatinName]	[NVARCHAR](250),
		[MtCode]		[NVARCHAR](250),
		[mtCreateDate]	[DATETIME],
		[mtSecurity]	[INT]
	)

	INSERT INTO [#RESULT]
			SELECT 
				[GUID],
				CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END as [Name],
				[LatinName],
				[Code],
				[CreateDate],
				[Security]
			FROM 
				[vcmt]
			WHERE 
				(CAST([CreateDate] AS DATE) BETWEEN @StartDate AND @EndDate )
				
	Exec [prcCheckSecurity]

	SELECT * FROM [#RESULT]
	ORDER BY [MtCode], [mtCreateDate]

	SELECT * FROM [#SecViol]
###################################################################################
#END
