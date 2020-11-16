##########################################################################
CREATE FUNCTION fnIsMainCostCenter(@CostGuid UNIQUEIDENTIFIER) 
RETURNS INT 
AS
BEGIN
	RETURN (SELECT CASE WHEN EXISTS(SELECT * FROM co000 WHERE ParentGUID = @CostGuid) THEN 1 ELSE 0 END);
END
##########################################################################
#END
