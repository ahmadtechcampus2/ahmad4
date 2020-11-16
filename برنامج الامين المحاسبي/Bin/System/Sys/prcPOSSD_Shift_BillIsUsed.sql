################################################################################
CREATE PROCEDURE prcPOSSD_Shift_BillIsUsed
-- Param -------------------------------   
	   @CurrentBill UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

SELECT BR.[GUID] FROM BillRel000 BR 
INNER JOIN POSSDShift000 POSShift ON BR.ParentGUID = POSShift.[GUID]
WHERE BR.BillGUID = @CurrentBill
#################################################################
#END
