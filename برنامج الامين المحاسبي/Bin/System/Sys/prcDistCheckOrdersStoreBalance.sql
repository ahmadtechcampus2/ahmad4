############################################################## 
CREATE PROC prcDistCheckOrdersStoreBalance
	@OrderGuid UNIQUEIDENTIFIER,
	@OrderTypeGuid UNIQUEIDENTIFIER,
	@DistributorGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON;
	
	IF ((dbo.fnOption_GetInt('AmnCfg_EnableOrderReservationSystem', '0') <> 1) 
		OR (dbo.fnOption_GetInt('AmnCfg_PreventNegativeOutputAfterReservation', '0') <> 1)
		OR (dbo.fnIsOrderTypeReserveQty(@OrderTypeGuid) <> 1))
	RETURN;
	
	DECLARE @PostedInvenytoryAfterRealizeOrders BIT
	DECLARE @CalcPurchaseOrderRemindedQtyIsChecked INT = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')
	SELECT @PostedInvenytoryAfterRealizeOrders = dst.PostedInvenytoryAfterRealizeOrders FROM Distributor000 dst 
			WHERE GUID = @DistributorGUID

	DECLARE @cursor CURSOR
	DECLARE @matGuid UNIQUEIDENTIFIER,  
			@storeGuid UNIQUEIDENTIFIER,
			@itemQty FLOAT

	SET @cursor = CURSOR FAST_FORWARD FOR 
	SELECT MatGUID, StoreGUID, Qty FROM bi000 WHERE ParentGUID = @OrderGuid ORDER BY Number ASC

	OPEN @cursor 
	FETCH NEXT FROM @cursor INTO @matGuid, @storeGuid, @itemQty
   
	WHILE @@FETCH_STATUS = 0
	BEGIN
			DECLARE @storeQty FLOAT, @reservedQty FLOAT 
			SELECT TOP 1 @storeQty = StoreQty,
			@reservedQty = ReservedQty FROM fnGetMatStoreQtyAndReservedQty(@matGuid,@storeGuid, @DistributorGUID)

			IF(@itemQty > (@storeQty - @reservedQty))
			BEGIN
					RAISERROR('AmnE1501: Negatavie output after reservation', 16, 1)
					RETURN;
			END

	FETCH NEXT FROM @cursor INTO @matGuid, @storeGuid, @itemQty
	END
      
	CLOSE @cursor
	DEALLOCATE @cursor
#################################################################
#END     