#########################################################################
CREATE PROCEDURE GetOrderItemsDetailes
	@OrderGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON  

	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();

	SELECT 
		bi.Guid AS ItemGuid, 
		mt.Guid AS ItemMatGuid, 
		bi.ClassPtr AS Class,
		mt.GroupGuid AS GroupGuid, 
		mt.Code + '-' + (CASE @Lang WHEN 0 THEN mt.Name ELSE 
			(CASE mt.LatinName WHEN N'' THEN mt.Name ELSE Mt.LatinName END) END) AS ItemMatName,
		mt.CompositionName AS CompositionName,
		mt.CompositionLatinName AS CompositionLatinName, 
		mt.Qty AS ItemQStore,
		mt.unity AS ItemUnit,
		bi.Qty AS ItemQOrder,
		bi.Qty - ISNULL(fn.Qty, 0) AS ItemQStay
	FROM 
		bi000 bi 
		INNER JOIN mt000 mt ON bi.MatGuid = mt.Guid
		OUTER APPLY (
			SELECT SUM(fn_bi.Qty) AS QTY
			FROM 
				bi000 fn_bi 
				INNER JOIN bu000 fn_bu			ON fn_bu.GUID = fn_bi.ParentGUID
				INNER JOIN ORREL000 REL			ON fn_bu.GUID = REL.OrGUID
				INNER JOIN OrAddInfo000 AddInfo ON fn_bu.GUID = AddInfo.ParentGUID
			WHERE 
				REL.ParentGUID = @OrderGUID 
				AND ISNULL(AddInfo.Add1 , -1) <> '1' 
				AND fn_bi.ClassPtr = bi.ClassPtr
				AND fn_bi.MatGUID = bi.MatGUID) fn
	WHERE 
		bi.ParentGUID = @OrderGUID
#########################################################################
CREATE FUNCTION ISHALFREADYMAT( @GUID UNIQUEIDENTIFIER )
	RETURNS INT 
AS
BEGIN
      DECLARE @RESULT [INT] 
      SET @RESULT = (SELECT COUNT(*) FROM MI000 MI WHERE TYPE = 0 AND MATGUID IN (SELECT MATGUID FROM MI000 WHERE TYPE = 1) AND MATGUID = @GUID)
      IF ( @RESULT > 0)
            RETURN 1
      ELSE
            RETURN 0
      
      RETURN 0
END
#########################################################################
#END