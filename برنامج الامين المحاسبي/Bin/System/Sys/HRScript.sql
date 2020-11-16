##################################################################################
CREATE FUNCTION fnIsHRConnectionActive()
RETURNS INT 
AS
BEGIN
	DECLARE @serverName NVARCHAR(50)
			
	SELECT 
		TOP 1 @serverName = [value] 
	FROM op000 
	WHERE [NAME] = 'HR_Connection_ServerName'
	
	IF ISNULL(@serverName, '') = '' 
		RETURN 0

	IF EXISTS (SELECT * FROM  master..sysservers WHERE srvName = @serverName)
		RETURN 1

	RETURN 0
END
##################################################################################
CREATE PROC PrcOpenHRConnection
AS
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
	
	CREATE Table #Servers
	(
	Name			NVARCHAR(MAx),
	Network_name	NVARCHAR(MAx),
	sstatus			NVARCHAR(MAx),
	id				INT ,
	Collation_name	NVARCHAR(MAx),
	Connect_TimeOut	INT,
	Query_TimeOut	INT
	)
	
	INSERT INTO #Servers  EXEC sp_helpserver 
	IF ISNULL(@serverName, '') = ''  OR NOT EXISTS(SELECT * FROM  #Servers WHERE Name = @serverName )
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
##################################################################################
CREATE PROC PrcCloseHRConenction	
AS
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
##################################################################################	
CREATE FUNCTION fnGetHRTablePrefix()
RETURNS NVARCHAR(110)
AS
BEGIN
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
END
##################################################################################
#END
