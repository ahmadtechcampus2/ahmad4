##################################################################################
CREATE FUNCTION fnIsHRConnectionActiveForManuFactory( @ManufactoryGuid UNIQUEIDENTIFIER,@serverName NVARCHAR(50))
RETURNS INT 
AS
BEGIN
	IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
	BEGIN
		SELECT 
			TOP 1 @serverName = [ServerAddress] 
		FROM Manufactory000 
		WHERE [Guid] = @ManufactoryGuid
	END
	
	IF ISNULL(@serverName, '') = '' 
		RETURN 0

	IF EXISTS (SELECT * FROM  master..sysservers WHERE srvName = @serverName)
		RETURN 1

	RETURN 0
END
##################################################################################
CREATE PROC PrcOpenHRConnectionForManuFactory
@ManufactoryGuid UNIQUEIDENTIFIER,
@serverName NVARCHAR(50),
@userName	NVARCHAR(50),
@password	NVARCHAR(50),
@isWindowsAuthintication BIT
AS
	SET NOCOUNT ON
	DECLARE  @Result	INT
	
	DECLARE @ResultTable TABLE(Succes INT)
	IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
	BEGIN
	SELECT 
		TOP 1 @serverName = [ServerAddress] 
	FROM Manufactory000 
	WHERE [Guid] = @ManufactoryGuid
	END
	

	IF ISNULL(@serverName, '') = '' 
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END
	
	IF (dbo.fnIsHRConnectionActiveForManuFactory(@ManufactoryGuid,@serverName) = 1)
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END
	
	IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
	BEGIN
	SELECT 
		TOP 1 @isWindowsAuthintication = [AuthType] 
	FROM Manufactory000 
	WHERE [Guid] = @ManufactoryGuid			
	END
	
	IF @isWindowsAuthintication IS NULL
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN 
	END
	IF 	@isWindowsAuthintication = 0
	BEGIN
	IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
	BEGIN
		SELECT 
			TOP 1 @userName = [UserName]
		FROM Manufactory000 
		WHERE [Guid] = @ManufactoryGuid	
	END
		IF ISNULL(@userName, '') = ''
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN 
		END
		IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
		BEGIN
		SELECT 
			TOP 1 @password = [UserPassword]
		FROM Manufactory000  
		WHERE [Guid] = @ManufactoryGuid				
		
		END
		
		EXEC @Result = sp_addlinkedsrvlogin  @serverName, 'FALSE', NULL, @userName, @password
		 
		IF @Result = 1
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN
		END	
		ELSE
		BEGIN
			SELECT 1 AS 'Success' 
			RETURN
		END	
	END
	
	EXEC @Result = sp_addlinkedserver @serverName 
	IF @Result = 1
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END	
	ELSE
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END	
	
SELECT 0 AS 'Success' 
##################################################################################
CREATE PROC PrcCloseHRConenctionForManuFactory	
@ManufactoryGuid UNIQUEIDENTIFIER,
@serverName NVARCHAR(50)
AS
	SET NOCOUNT ON
	DECLARE  @Result	INT
	
	IF NOT ISNULL(@ManufactoryGuid,0x0)=0x0	
	BEGIN
	SELECT 
		TOP 1 @serverName = [ServerAddress] 
	FROM Manufactory000 
	WHERE [Guid] = @ManufactoryGuid
	END
	
	IF ISNULL(@serverName, '') = ''
	BEGIN 
		SELECT 0 AS 'Success' 
		RETURN 
	END
	EXEC @Result = sp_dropserver @serverName

	IF @Result = 1
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END	
	
	SELECT 1 AS 'Success'
##################################################################################
#END
