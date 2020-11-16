###################################################
CREATE FUNCTION fnHosGetUncollected(@FileGUID UNIQUEIDENTIFIER )
	RETURNS FLOAT
AS
BEGIN
	DECLARE @AccGuid  	     AS UNIQUEIDENTIFIER
	DECLARE @CostGuid 	     AS UNIQUEIDENTIFIER
	DECLARE @Sum1		     AS FLOAT
	DECLARE @Sum2		     AS FLOAT

	SELECT @AccGuid=AccGuid , @CostGuid=CostGuid 
	FROM hospfile000 
	WHERE GUID=@FileGUID

	SELECT @Sum1 = SUM(ch.Val - clch.Val) 
	FROM 
		ch000 AS ch INNER JOIN colch000 AS clch 
			ON (ch.GUID = clch.ChGUID)
	WHERE 	
		ch.Cost1Guid = @CostGuid AND ch.AccountGuid = @AccGuid
		AND
		ch.State = 64

	SELECT @Sum2=SUM(Val)
	FROM ch000
	WHERE 
		Cost1Guid = @CostGuid AND AccountGuid = @AccGuid
		AND
		State = 0
	
		
	RETURN (ISNULL(@Sum1,0)+ ISNULL(@Sum2,0))
END
###################################################
#END