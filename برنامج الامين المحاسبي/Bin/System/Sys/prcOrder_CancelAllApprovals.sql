######################################################
CREATE PROCEDURE prcOrder_CancelAllApprovals
	@OrderGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DECLARE @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	INSERT INTO OrderApprovalStates000 ([GUID], [Number], ParentGuid, UserGuid, AlternativeUserGUID, IsApproved, OperationTime, ComputerName)
	SELECT 
		NEWID(), oas.Number + 1, oa.GUID, @UserGUID, 0x0, 0, GetDate(), HOST_NAME()
	FROM
		OrderApprovals000 oa 
		CROSS APPLY dbo.fnGetLastApprovalState(oa.GUID) oas
	WHERE 
		oa.OrderGuid = @OrderGuid
		AND
		oas.IsApproved = 1


	INSERT INTO OrderApprovalStates000 ([GUID], [Number], ParentGuid, UserGuid, AlternativeUserGUID, IsApproved, OperationTime, ComputerName)
	SELECT 
		NEWID(), oas.Number + 1, oa.GUID, @UserGUID, 0x0, 0, GetDate(), HOST_NAME()
	FROM
		MgrApp000 oa 
		CROSS APPLY dbo.fnGetLastApprovalState(oa.GUID) oas
	WHERE 
		oa.OrderGuid = @OrderGuid
		AND
		oas.IsApproved = 1
######################################################
CREATE PROCEDURE prcOrder_ResetApprovals
	@OrderGuid UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DELETE OrderApprovals000 WHERE OrderGuid = @OrderGuid
	DELETE MgrApp000 WHERE OrderGuid = @OrderGuid

	INSERT INTO OrderApprovals000([GUID], [Number], [OrderGuid], [UserGuid])
	SELECT NEWID(), [Order], @OrderGuid, [UserGuid] FROM [UsrApp000] WHERE [ParentGUID] = (SELECT [TypeGuid] FROM bu000 WHERE [GUID] = @OrderGuid)
######################################################
#END
