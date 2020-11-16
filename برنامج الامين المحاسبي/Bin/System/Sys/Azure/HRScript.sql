##################################################################################
CREATE FUNCTION fnIsHRConnectionActive()
RETURNS INT 
AS
BEGIN
	/*
	DECLARE @serverName NVARCHAR(50)
			
	SELECT 
		TOP 1 @serverName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_ServerName'
	
	IF ISNULL(@serverName, '') = '' 
		RETURN 0

	IF EXISTS (SELECT * FROM  master..sysservers WHERE srvName = @serverName)
		RETURN 1

	*/
	RETURN 0
END
##################################################################################
CREATE PROC PrcOpenHRConnection
AS
	EXECUTE prcNotSupportedInAzure
	/*
	SET NOCOUNT ON
	DECLARE @serverName NVARCHAR(50),
			@userName	NVARCHAR(50),
			@password	NVARCHAR(50),
			@isWindowsAuthintication BIT,
			@Result	INT
	
	DECLARE @ResultTable TABLE(Succes INT)
	
	SELECT 
		TOP 1 @serverName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_ServerName'
	

	IF ISNULL(@serverName, '') = '' 
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN
	END
	
	IF (dbo.fnIsHRConnectionActive() = 1)
	BEGIN
		SELECT 1 AS 'Success' 
		RETURN
	END
	
	SELECT 
		TOP 1 @isWindowsAuthintication = CAST ([value] AS BIT)
	FROM op000 
	WHERE [NAME] = 'HR_Connection_IsWindowsAuthentication'				
	
	IF @isWindowsAuthintication IS NULL
	BEGIN
		SELECT 0 AS 'Success' 
		RETURN 
	END
	IF 	@isWindowsAuthintication = 0
	BEGIN
		SELECT 
			TOP 1 @userName = [value]
		FROM op000 
		WHERE [NAME] = 'HR_Connection_UserName'
	
		IF ISNULL(@userName, '') = ''
		BEGIN
			SELECT 0 AS 'Success' 
			RETURN 
		END
		SELECT 
			TOP 1 @password = [value]
		FROM op000 
		WHERE [NAME] = 'HR_Connection_Password'				
		
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
*/
##################################################################################
CREATE PROC PrcCloseHRConenction	
AS
	EXECUTE prcNotSupportedInAzure
	/*
	SET NOCOUNT ON
	DECLARE @serverName NVARCHAR(50),
		@Result	INT
	SELECT 
		TOP 1 @serverName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_ServerName'
	
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
	*/
##################################################################################	
CREATE FUNCTION fnGetHRTablePrefix()
RETURNS NVARCHAR(110)
AS
BEGIN
	/*
	DECLARE @serverName NVARCHAR(50),
			@databaseName NVARCHAR(50)

	SELECT 
		TOP 1 @serverName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_ServerName'
	
	IF ISNULL(@serverName, '') = '' 
		RETURN '' 
	
	SELECT 
		TOP 1 @databaseName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_DatabaseName'
	
	IF ISNULL(@databaseName, '') = '' 
		RETURN '' 
	
	RETURN '[' + @serverName + '].[' + @databaseName + '].[dbo].'
	*/
	/* 	prcNotSupportedInAzure*/
	RETURN 0
END
##################################################################################
#END
