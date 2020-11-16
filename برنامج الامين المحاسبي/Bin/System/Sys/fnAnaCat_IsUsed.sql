###################################
CREATE FUNCTION fnAnaCat_IsUsed(@AnaCatGUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
/*  
this function:  
	- returns a constanct integer representing the existance of a given analysis category in the database tables.  
	- is usually called from trg_HosAnaCat000_CheckConstraints.  
*/  
	DECLARE @result [INT]

	SET @result = 0 

	IF EXISTS(SELECT * FROM [HosAnaCat000] WHERE [ParentGUID]		= @AnaCatGUID)
		SET @result = 0x010001 

	--ELSE IF EXISTS(SELECT * FROM [HosAnalysis000] WHERE [AnalysisGUID]	= @AnaCatGUID)
	--	SET @result = 0x010002 

-- select * from HosAnalysis000
	RETURN @result
END 
###################################
#END
