#################################################################
CREATE PROCEDURE prcCheckOpenedShiftInPOSCard
@BillType UNIQUEIDENTIFIER,
@billId UNIQUEIDENTIFIER 
AS 
BEGIN 

DECLARE @Result INT 
SET @Result = 0

	SELECT @Result = COUNT(*)
		FROM POSCard000 posCard INNER JOIN POSShift000 posShift ON posCard.Guid = posShift.POSGuid
		INNER JOIN BillRel000 billRel ON billRel.ParentGUID = posShift.Guid
	WHERE posCard.SaleBillType = @BillType AND CloseDate  IS NOT NULL   AND billRel.BillGUID = @billId

	SELECT @Result AS Result
END
#################################################################
#END 