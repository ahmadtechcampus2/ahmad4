#############
CREATE FUNCTION fnGetInBillCostType(@InBillTypeName NVARCHAR(250))
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	
	RETURN
	(
		SELECT 
			btGUID
		FROM 
			vwBt
		WHERE
			btName = @InBillTypeName
			AND
			btIsInput = 1
			AND
			btAffectCostPrice = 1
			AND
			btAutoPost = 1
			AND
			btBillType = 4
	);
END
#############
CREATE FUNCTION fnGetOutBillCostType(@OutBillTypeName NVARCHAR(250))
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	
	RETURN
	(
		SELECT 
			btGUID
		FROM 
			vwBt
		WHERE
			btName = @OutBillTypeName
			AND
			btIsOutput = 1
			AND
			btAffectCostPrice = 0
			AND
			btAutoPost = 1
			AND
			btBillType = 5
	);
END
#############
#END