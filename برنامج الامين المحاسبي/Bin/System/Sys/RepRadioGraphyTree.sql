###################################################
CREATE PROCEDURE RepRadioGraphyTree
	@Lang		INT = 0
AS
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			Guid		UNIQUEIDENTIFIER,  
			ParentGuid 	UNIQUEIDENTIFIER,  
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[LatinName]	NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Number		FLOAT,  
			Security	INT,  
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
			vwHosRadioGraphyAll as ana INNER JOIN dbo.fnGetRadioGraphyListSorted( 0x0, 1) AS fn  
			ON ana.Guid = fn.Guid 
	EXEC prcCheckSecurity  
	SELECT * FROM #Result ORDER BY Path  
	SELECT * FROM #SecViol 
##################################################################################
#END
