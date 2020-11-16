#########################################################
CREATE FUNCTION fnIsGenOfAssemBill ( @buGuid [UNIQUEIDENTIFIER])
	RETURNS [BIGINT] 
AS BEGIN 

	IF EXISTS
	( 
		SELECT 
			* 
		FROM 
			[AssemBill000]
		WHERE 
			[FinalBillGuid] = @buGuid
	)
		RETURN 1
	RETURN 0
END
#########################################################
#END
