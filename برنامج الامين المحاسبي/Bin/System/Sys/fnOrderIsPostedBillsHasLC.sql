#########################################################################
CREATE FUNCTION fnOrderIsPostedBillsHasLC (@OrderGUID UNIQUEIDENTIFIER)
	RETURNS BIT
AS BEGIN 
	DECLARE @PostedBillsHasLC BIT = 0
	IF EXISTS (
		SELECT *
		FROM vwExtended_bi bi
			INNER JOIN ori000 ori ON ori.BuGuid = bi.buGUID
			LEFT JOIN LC000 lc ON bi.buLCGUID = lc.GUID
		WHERE 
			ori.POGuid = @OrderGUID
			AND lc.GUID IS NOT NULL
		)
			SET @PostedBillsHasLC = 1
	RETURN @PostedBillsHasLC
END
#########################################################################
#END