#########################################################
CREATE FUNCTION fnGetReservedQtyDetails
(
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@StoreGuid UNIQUEIDENTIFIER = 0x0,
	@BranchGuid UNIQUEIDENTIFIER = 0x0
) 
RETURNS TABLE  
AS 
	RETURN
	( 
			SELECT
				ISNULL(SUM(ori.oriQty),0) AS ReservedQty,
				bi.biMatPtr AS MatGuid,
				ori.oriTypeGUID AS TypeGUID,
				bi.biStorePtr AS StoreGuid,
				bi.buDate AS BuDate,
				bi.biGUID AS BiGuid,
				bi.buCustPtr AS CustGuid
			FROM
				vwExtended_bi bi
				INNER JOIN vwMt mt ON bi.biMatPtr = mt.mtGUID
				INNER JOIN vwORI ori ON bi.biGUID = ori.oriPOIGUID
				INNER JOIN oit000 st ON ori.oriTypeGuid = st.[Guid]
				LEFT JOIN  vwOrderInformation orderInfo ON orderInfo.ParentGuid = ori.oriPOGUID 
			WHERE
				orderInfo.Finished  = 0 
				AND orderInfo.Add1 = 0
				AND bi.biMatPtr = CASE WHEN @MatGuid = 0x0 THEN bi.biMatPtr ELSE @MatGuid END
				AND IsQtyReserved = 1
				AND bi.buStorePtr = CASE @StoreGuid WHEN 0x0 THEN  bi.buStorePtr ELSE  @StoreGuid END
				AND bi.buBranch = CASE @BranchGuid WHEN 0x0 THEN  bi.buBranch ELSE  @BranchGuid END
			GROUP BY
				bi.biMatPtr,
				bi.biGuid,
				ori.oriTypeGUID,
				bi.biStorePtr,
				bi.buDate,
				bi.buCustPtr
			HAVING SUM((ori.oriQty + bi.biBillBonusQnt) / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END)) > 0
	);
#########################################################
CREATE FUNCTION fnGetReservedQty
(
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@StoreGuid UNIQUEIDENTIFIER = 0x0,
	@BranchGuid UNIQUEIDENTIFIER = 0x0
) 
RETURNS FLOAT 
AS
BEGIN 
RETURN
	( 
		SELECT 
			ISNULL(SUM(fn.ReservedQty),0) AS Reserved_Qty
		FROM
			fnGetReservedQtyDetails(@MatGuid,@StoreGuid,@BranchGuid) fn
	)
END;
#########################################################
CREATE FUNCTION fnIsOrderTypeReserveQty
(
	@OrderTypeGuid UNIQUEIDENTIFIER = 0x0
) 
RETURNS BIT 
AS
BEGIN 
RETURN
	( 
		SELECT 
			ISNULL(IsQtyReserved,0) AS IsReserveQty
		FROM 
			oitvs000 oitvs
			LEFT JOIN oit000 oit ON oit.GUID = oitvs.ParentGuid
		WHERE 
			StateOrder = 0
			AND OTGUID = @OrderTypeGuid
	)
END;
#########################################################
CREATE FUNCTION fnGetMatStoreQtyAndReservedQty
(
	@MatGuid UNIQUEIDENTIFIER = 0x0,
	@StoreGuid UNIQUEIDENTIFIER = 0x0,
	@DistributorGUID UNIQUEIDENTIFIER = 0x0
) 
RETURNS @Result TABLE (StoreQty FLOAT, ReservedQty FLOAT)
AS 
BEGIN
	DECLARE @PostedInvenytoryAfterRealizeOrders BIT;
	DECLARE @CalcPurchaseOrderRemindedQtyIsChecked INT = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')
	SELECT @PostedInvenytoryAfterRealizeOrders = dst.PostedInvenytoryAfterRealizeOrders FROM Distributor000 dst 
			WHERE GUID = @DistributorGUID

	INSERT INTO @Result
	SELECT 
		CASE WHEN @PostedInvenytoryAfterRealizeOrders = 1 AND @CalcPurchaseOrderRemindedQtyIsChecked = 0
			      THEN ISNULL(ms.Qty,0) + dbo.fnGetPurchaseOrdRemaindedQty2(@matGuid, @storeGuid, 0x0) - dbo.fnGetSalesOrdRemaindedQty2(@matGuid, @storeGuid, 0x0)
			 WHEN @CalcPurchaseOrderRemindedQtyIsChecked = 1 AND @PostedInvenytoryAfterRealizeOrders = 0
				  THEN ISNULL(ms.Qty,0) + dbo.fnGetPurchaseOrdRemaindedQty2(@matGuid, @storeGuid, 0x0)
			 ELSE ISNULL(ms.Qty,0)
		END AS StoreQty
		,dbo.fnGetReservedQty(@MatGuid, @StoreGuid, 0x0) AS ReservedQty
	FROM 
		mt000 mt
		LEFT JOIN ms000 ms ON ms.MatGUID = mt.GUID AND ms.StoreGUID = @StoreGuid 
	WHERE 
		mt.GUID = @MatGuid

	RETURN
END
#########################################################
#END 