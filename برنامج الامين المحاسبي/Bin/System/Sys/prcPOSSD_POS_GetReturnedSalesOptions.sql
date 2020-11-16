#################################################################
CREATE PROCEDURE prcPOSGetPosReturnedSalesOptions
-- Param -------------------------------   
	   @POSCardGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
BEGIN
    SET NOCOUNT ON
------------------------------------------------------------------------
	SELECT *
	FROM POSSDReturenedSales000 ReturnedSales
	WHERE ReturnedSales.[POSCardGUID] = @POSCardGuid
END
#################################################################
#END 