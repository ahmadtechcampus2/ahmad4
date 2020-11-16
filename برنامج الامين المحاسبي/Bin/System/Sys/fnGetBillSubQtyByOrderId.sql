######################################################
CREATE FUNCTION fnGetBillSubQtyByOrderId (@OrderId UNIQUEIDENTIFIER)
	RETURNS TABLE
AS

 RETURN
	(
		WITH r AS(
			SELECT bi.MatGUID, SUM(bi.Qty) AS Qty FROM bi000 bi
			INNER JOIN BillRelations000 buRel ON buRel.RelatedBillGuid = bi.ParentGUID
			INNER JOIN BillRel000 posRel ON posRel.BillGUID = buRel.BillGuid
			WHERE posRel.ParentGUID = @OrderId
			GROUP BY bi.MatGUID
			)
			SELECT bi.GUID, bi.MatGUID, ISNULL(r.Qty, 0) AS ReturnedQty, bi.Qty, bi.ParentGUID 
			FROM bi000 bi 
			INNER JOIN BillRel000 rel ON bi.ParentGUID = rel.BillGuid
			LEFT JOIN r ON r.MatGUID = bi.MatGUID
			WHERE rel.ParentGUID = @OrderId
	)
######################################################
CREATE FUNCTION fnGetFixedValue(
        @Value [FLOAT],
		@OrderDate [DATETIME] )
	RETURNS [FLOAT]
AS
BEGIN
	DECLARE @PosCurrencyID	 [UNIQUEIDENTIFIER],
			@MainCurrencyID  [UNIQUEIDENTIFIER] 

	SELECT TOP 1 @PosCurrencyID = ISNULL([Value],0x0) 
	FROM [FileOP000] 
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	SELECT @MainCurrencyID = [GUID] 
	FROM [my000] 
	WHERE  [CurrencyVal] = 1

	IF (@PosCurrencyID = 0x0 or @MainCurrencyID = @PosCurrencyID) 
		RETURN @Value 
	RETURN @Value / dbo.fnGetCurVal(@PosCurrencyID,@OrderDate)
    
END
######################################################
CREATE FUNCTION fnCheckBillSubQtyByOrderId (@BillItemId UNIQUEIDENTIFIER)
	RETURNS [FLOAT]
AS
BEGIN

 RETURN
	(
		SELECT SUM(ISNULL(bi.Qty, 0)) - 
			ISNULL((
			SELECT SUM(ISNULL(bi.Qty, 0)) AS ReturnedQty 
			FROM bi000 biOrginal
			INNER JOIN BillRelations000 buRel ON buRel.BillGuid = biOrginal.ParentGUID
			INNER JOIN bi000 bi ON bi.ParentGUID = buRel.RelatedBillGuid AND biOrginal.MatGUID = bi.MatGUID
			WHERE biOrginal.GUID = @BillItemId
			), 0)
			AS Qty
		FROM bi000 bi
		WHERE bi.GUID = @BillItemId
	)
END
######################################################
#END