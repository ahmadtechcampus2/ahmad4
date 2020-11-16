############################################################################
CREATE PROCEDURE prcOrdersSaveNewOrderApprovals @OrderGuid UNIQUEIDENTIFIER = 0x0
											  , @OrderTypeGuid UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT EXISTS(SELECT TOP 1 GUID FROM USRAPP000 WHERE ParentGuid = @OrderTypeGuid)
		RETURN;

	INSERT INTO OrderApprovals000 
	SELECT NEWID() 
		, [Order]
		, @OrderGuid
		, [UserGUID]
	FROM USRAPP000
	WHERE [ParentGuid] = @OrderTypeGuid
------------------------------------------------
	INSERT INTO OrderApprovalStates000
	SELECT NEWID()
		, 1
		, [GUID]
		, [UserGuid]
		, 0x00
		, 0
		, GETDATE()
		, HOST_NAME()
	FROM OrderApprovals000
	WHERE [OrderGuid] = @OrderGuid
--------------------------------------------------
	-- Save Sales/Purchase Manager Approvals.
	DECLARE @isOutput BIT = 0
			, @manager UNIQUEIDENTIFIER = 0x00	
	 
	SELECT @isOutput = btIsOutput FROM vwbu WHERE buGUID = @OrderGuid 
 
 	SET @manager = (SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = (CASE @isOutput WHEN 0 THEN 'PurchaseManager' ELSE 'SalesManager' END)) 

	IF ISNULL(@manager, 0x00) = 0x00 
		RETURN;

	INSERT INTO MGRAPP000
	VALUES (NEWID(), @manager, @OrderGuid, GETDATE()) 

END;
############################################################################
#END

