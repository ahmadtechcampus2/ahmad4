############################################################################
CREATE FUNCTION fnBill_GetDiSum(@BuGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
RETURN (
	SELECT 
		ISNULL(SUM(ISNULL(Discount,0)), 0) Discount,
		ISNULL(SUM(ISNULL(Extra,0)), 0 ) Extra
	FROM 
		di000 
	WHERE ParentGUID = @BuGUID
)
############################################################################
#END
