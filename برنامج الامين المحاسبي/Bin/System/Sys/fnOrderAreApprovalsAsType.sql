#########################################################################
CREATE FUNCTION fnOrderAreApprovalsAsType (@OrderGuid UNIQUEIDENTIFIER)
	RETURNS BIT 
AS BEGIN 
	DECLARE @TypeGuid UNIQUEIDENTIFIER 
	SELECT @TypeGuid = [TypeGuid] FROM [bu000] WHERE [GUID] = @OrderGuid

	IF EXISTS 
	(
		SELECT 
			* 
		FROM 
			(SELECT * FROM UsrApp000 WHERE ParentGuid = @TypeGuid) us
			FULL JOIN 
			(SELECT * FROM OrderApprovals000 WHERE OrderGuid = @OrderGuid) ord ON us.UserGUID = ord.UserGUID AND ord.Number = us.[Order] 
		WHERE 
			ISNULL(us.UserGUID, 0x0) != ISNULL(ord.UserGUID, 0x0)
			AND 
			ISNULL(ord.Number, 0) != ISNULL(us.[Order] , 0)
	)
		RETURN 0

	RETURN 1
END 
#########################################################################
#END
