#################################################################################### 
CREATE FUNCTION fnGetMaterialsList(@Parent [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (
		SELECT [GUID] FROM [dbo].[fnGetGroupsOfGroup](@Parent)
		UNION ALL
		SELECT [mtGUID] FROM [dbo].[fnGetMatsOfGroups](@Parent)
		)
#################################################################################### 
CREATE FUNCTION fnIsClassExcededStore(@Class NVARCHAR(250), @Qty FLOAT, @StoreGUID UNIQUEIDENTIFIER, @BiGUID UNIQUEIDENTIFIER)
RETURNS INT
AS
BEGIN 
	DECLARE @StoreQty FLOAT;
		
	IF @Class = N''
		RETURN 0;

	SELECT 
		@StoreQty = SUM(CASE BT.bIsInput WHEN 1 THEN Qty ELSE -Qty END) 
	FROM 
		bi000 AS BI
		JOIN bu000 AS BU ON BI.ParentGUID = BU.GUID
		JOIN bt000 AS BT ON BT.GUID = BU.TypeGUID
	WHERE 
		ClassPtr = @Class AND BI.StoreGUID = @StoreGUID 
		AND BU.IsPosted = 1
		AND BI.GUID <> ISNULL(@BiGUID, 0x)
	GROUP BY 
		ClassPtr, BI.StoreGUID;

	IF @Qty > @StoreQty
		RETURN 1
	
	RETURN 0
END
####################################################################################
#END