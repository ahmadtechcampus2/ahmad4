################################################################
CREATE PROCEDURE prcOrderGetAlternativeUsers
	@OrderApprovalGuid UNIQUEIDENTIFIER, 
	@OrderTypeGuid UNIQUEIDENTIFIER,
	@IsManager BIT = 0
AS
	SET NOCOUNT ON;
	
	DECLARE @IsOutput BIT
	DECLARE @CurrentDate DATETIME = GETDATE()
	DECLARE @Result TABLE(
		UserGuid UNIQUEIDENTIFIER,
		UserName NVARCHAR(250))
	
	SELECT 
		@IsOutput = bIsOutput
	FROM 
		bt000
	WHERE 
		[GUID] = @OrderTypeGuid
	
	IF ISNULL(@OrderApprovalGuid, 0x0) = 0x0
	BEGIN 
		DECLARE @Manager UNIQUEIDENTIFIER
		IF @IsOutput = 0  
			SET @Manager =(SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'PurchaseManager') 
		ELSE  
			SET @Manager = (SELECT CONVERT(UNIQUEIDENTIFIER, Value) FROM op000 WHERE Name = 'SalesManager')
		IF ISNULL(@Manager, 0x0) = 0x0
		BEGIN 
			SELECT * FROM @Result 
			
			RETURN 
		END ELSE BEGIN
			INSERT INTO @Result
			SELECT 
				@Manager, loginName
			FROM
				us000 us 
			WHERE [GUID] = @Manager
		END
	END ELSE BEGIN 
		INSERT INTO @Result
		SELECT TOP 1
			us.GUID, us.loginName
		FROM 
			us000 us 
			INNER JOIN OrderApprovals000 oa ON oa.UserGuid = us.Guid 
		WHERE 
			oa.GUID = @OrderApprovalGuid
	END 
	---------------------------------------------------------------------
	INSERT INTO @Result
	SELECT DISTINCT us.GUID, us.LoginName
	FROM  	
		OrderAlternativeUsers000 oau  
		LEFT JOIN OrderAlternativeUserTypes000 AS oautypes ON oau.GUID = oautypes.ParentGUID 
		INNER JOIN us000 us ON us.GUID = oau.AlternativeUserGUID
	WHERE 
		((oau.IsActive = 1) OR (oau.IsLimitedActive = 1 AND @CurrentDate BETWEEN oau.StartDate AND oau.ExpireDate))
		AND 
		((oau.IsAllAvailableTypes = 1) OR (oautypes.OrderTypeGUID = @OrderTypeGuid))
		AND 
		oau.UserGUID = (SELECT TOP 1 [UserGuid] FROM @Result)
		AND 
		(
			((oau.[Type] = 0) AND (@IsManager = 0)) 
			OR 
			((@IsOutput = 1) AND (oau.[Type] = 1) AND (@IsManager = 1)) 
			OR 
			((@IsOutput = 0) AND (oau.[Type] = 2) AND (@IsManager = 1)) 
		)
	
	SELECT [UserName] FROM @Result
################################################################
#END