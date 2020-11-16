############################################################################
CREATE FUNCTION fnBill_IsRelated (@BuGUID UNIQUEIDENTIFIER, @CheckPFC BIT = 1, @CheckOrder BIT = 1)
	RETURNS BIT
AS
BEGIN 
	IF ISNULL(@BuGUID, 0x0) = 0x0
		RETURN 0

	-- PFC
	IF @CheckPFC = 1
	BEGIN 
		IF EXISTS (SELECT 1 FROM op000 WHERE Name = 'PFC_IsBelongToProfitCenter' AND Value = '1' AND Type = 0)
		BEGIN 
			DECLARE @BtGUID UNIQUEIDENTIFIER
			SELECT @BtGUID = TypeGUID FROM bu000 WHERE GUID = @BuGUID
			
			IF EXISTS (SELECT 1 FROM op000 WHERE Name = 'PFC_IncreasePricesBillType' AND Value = CAST(@BtGUID AS VARCHAR(100)) AND Type = 0)
				RETURN 1

			IF EXISTS (SELECT 1 FROM op000 WHERE Name = 'PFC_DecreasePricesBillType' AND Value = CAST(@BtGUID AS VARCHAR(100)) AND Type = 0)
				RETURN 1
		END 

		IF EXISTS (SELECT 1 FROM PFCPostedDays000 WHERE SalesBillGUID = @BuGUID OR ReturnBillGUID = @BuGUID)
			RETURN 1
	END
	
	-- ASSETS
	IF EXISTS (SELECT 1 FROM assTransferHeader000 WHERE InbuGuid = @BuGUID OR OutbuGuid = @BuGUID) 
		RETURN 1

	IF EXISTS (SELECT 1 FROM assetExclude000 WHERE BillGuid = @BuGUID) 
		RETURN 1
	
	-- POSSD
	IF EXISTS (
		SELECT 1 FROM 
			BillRel000 BR 
			INNER JOIN POSSDShift000 POSShift ON BR.ParentGUID = POSShift.[GUID]
		WHERE BR.BillGUID = @BuGUID) 
	BEGIN 
		RETURN 1
	END

	IF @CheckOrder = 1
	BEGIN 
		IF EXISTS (SELECT 1 FROM ori000 WHERE BuGuid = @BuGUID)
			RETURN 1
	END

	IF dbo.fnIsBillRelatedToOrder(@BuGUID) != 0
		RETURN 1

	IF EXISTS (SELECT 1 FROM bu000 bu INNER JOIN lc000 lc ON bu.LCGUID = lc.[GUID] WHERE lc.State = 0 AND BU.[GUID] = @BuGUID)
		RETURN 1

	RETURN 0	
END
############################################################################
#END
