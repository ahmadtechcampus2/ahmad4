#########################################################
CREATE PROC prcSetOrderManagerApprovals
	@OrderGuid [UNIQUEIDENTIFIER],  
	@UserGuid [UNIQUEIDENTIFIER],
	@AlternativeUserGUID UNIQUEIDENTIFIER,
	@IsApproved BIT
AS  
	SET NOCOUNT ON 
	
	DECLARE @g UNIQUEIDENTIFIER 
	IF NOT EXISTS (SELECT * FROM [MgrApp000] WHERE OrderGUID = @OrderGuid)
	BEGIN 
		SET @g = NEWID() 
		INSERT INTO [MgrApp000]([GUID], UserGUID, OrderGUID, ApprovalDate)
		VALUES(@g, @UserGuid, @OrderGuid, GETDATE()) 
	END ELSE BEGIN 
		SELECT TOP 1 @g = [GUID] FROM [MgrApp000] WHERE OrderGUID = @OrderGuid
	END 
	

	EXEC prcInsertOrderApprovalState @g, @UserGUID, @AlternativeUserGUID, @IsApproved

#########################################################
#END