################################################################################
CREATE PROCEDURE prcPOSSD_Coupon_DeleteExpiredReturnCoupon
-- Params -------------------------------
	@ExpiredReturnCouponGUID UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------
	DECLARE @User      UNIQUEIDENTIFIER = (SELECT TOP 1 [GUID] FROM us000 WHERE [bAdmin] = 1 AND [Type] = 0 ORDER BY [Number])	
	DECLARE @EntryGUID UNIQUEIDENTIFIER = (SELECT EntryGUID FROM POSSDExpiredReturnCoupon000 WHERE [GUID] = @ExpiredReturnCouponGUID)

	EXEC prcConnections_Add @User

	EXEC prcConnections_SetIgnoreWarnings 1
	UPDATE ce000 SET [IsPosted] = 0 WHERE [GUID] = @EntryGUID
	EXEC prcConnections_SetIgnoreWarnings 0

	DELETE ce000 WHERE [GUID] = @EntryGUID
	DELETE POSSDExpiredReturnCoupon000 WHERE [GUID] = @ExpiredReturnCouponGUID
	UPDATE POSSDReturnCoupon000 SET ProcessedExpiryCoupon = 0x0 WHERE ProcessedExpiryCoupon = @ExpiredReturnCouponGUID


	IF((SELECT COUNT(*) FROM er000 WHERE parentGUID = @ExpiredReturnCouponGUID) <> 0)
	BEGIN
		SELECT 0 AS IsDeleted
		RETURN;
	END

	IF((SELECT COUNT(*) FROM POSSDExpiredReturnCoupon000 WHERE [GUID] = @ExpiredReturnCouponGUID) <> 0)
	BEGIN
		SELECT 0 AS IsDeleted
		RETURN;
	END

	IF((SELECT COUNT(*) FROM POSSDReturnCoupon000 WHERE ProcessedExpiryCoupon = @ExpiredReturnCouponGUID) <> 0)
	BEGIN
		SELECT 0 AS IsDeleted
		RETURN;
	END

	SELECT 1 AS IsDeleted
#################################################################
#END
