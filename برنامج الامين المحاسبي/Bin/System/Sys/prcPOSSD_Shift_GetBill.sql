#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetBill
-- Params -------------------------------   
	@ShiftGuid				UNIQUEIDENTIFIER,
	@BillType				INT = 0 -- 0:All, 1: Sales, 2: Purchases, 3: ReturnedSales, 4: Returned Purchases 
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

	SELECT BR.BillGUID  AS BillGuid,
		   BU.Number    AS BillNumber,
		   BU.TypeGUID  AS BillTypeGuid,
		   BU.IsPosted  AS BillIsPosted
		
	FROM  BillRel000 BR 
	INNER JOIN bu000 BU ON BR.BillGUID = BU.[GUID]
	INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]

	WHERE ParentGUID     = @ShiftGuid 
	AND 
	(
		@BillType = 0
		OR (@BillType = 1 AND BT.BillType = 1) -- Sale
		OR (@BillType = 2 AND BT.BillType = 0) -- Purchases
		OR (@BillType = 3 AND BT.BillType = 3) -- ReturnedSales
		OR (@BillType = 4 AND BT.BillType = 2) -- Returned Purchases 
	)
#################################################################
#END
