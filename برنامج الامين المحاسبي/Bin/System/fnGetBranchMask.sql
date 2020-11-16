################################################################
CREATE FUNCTION fnGetBranchMask( @Number [INT]) 
	RETURNS [BIGINT]
AS BEGIN 
/* 
	- this functions convert branch number (INT) to branch mask (BIGINT)
*/ 
	RETURN ( SELECT [dbo].[fnPowerOf2](@Number - 1)) 
END 
################################################################
#END