############################################
CREATE PROCEDURE prcRestIngredientItem
	@ItemID UNIQUEIDENTIFIER
AS
SET NOCOUNT ON

IF ISNULL(@ItemID, 0x0) = 0x0
	RETURN
	
SELECT mt.GUID, mt.code, mt.name, mt.latinname, raw.qty Qty, CASE raw.unity WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 ELSE mt.Unity END Unit FROM mn000 mn
		INNER JOIN mi000 ready ON ready.ParentGUID=mn.GUID AND ready.Type=0
		INNER JOIN mi000 raw ON ready.ParentGUID=raw.ParentGUID AND raw.Type=1
		INNER JOIN mt000 mt on mt.guid=raw.MatGUID 
WHERE mn.type=0  and ready.matguid=@ItemID
ORDER BY raw.Number
############################################
#END