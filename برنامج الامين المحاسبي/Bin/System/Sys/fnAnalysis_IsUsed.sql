#################################
CREATE FUNCTION fnAnalysis_IsUsed(@AnalysisGUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
/*  
this function:  
	- returns a constanct integer representing the existance of a given analysis in the database tables.  
	- is usually called from trg_HosAnalysis000_CheckConstraints.  
*/  
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS(SELECT * FROM [HosAnalysis000] WHERE [ParentGUID]		= @AnalysisGUID)
		SET @result = 0x010001 

	ELSE IF EXISTS(SELECT * FROM [HosToDoAnalysis000] WHERE [AnalysisGUID]	= @AnalysisGUID)
		SET @result = 0x010002 
-- select * from dbo.HosToDoAnalysis000
	RETURN @result
END 

#############################################
#END