#################################################################
CREATE PROCEDURE prcPOSSD_Station_CheckOpenedShift
@BillType UNIQUEIDENTIFIER,
@billId UNIQUEIDENTIFIER 
AS 
BEGIN 

DECLARE @Result INT 
SET @Result = 0

	SELECT @Result = COUNT(*)
		FROM POSSDStation000 posCard INNER JOIN POSSDShift000 posShift ON posCard.GUID = posShift.StationGUID
		INNER JOIN BillRel000 billRel ON billRel.ParentGUID = posShift.[GUID]
	WHERE posCard.SaleBillTypeGUID = @BillType AND CloseDate  IS NOT NULL   AND billRel.BillGUID = @billId

	SELECT @Result AS Result
END
#################################################################
#END 