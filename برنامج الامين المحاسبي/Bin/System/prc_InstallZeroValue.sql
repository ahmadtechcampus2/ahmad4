###########################################################################
CREATE PROCEDURE prc_InstallZeroValue
AS
	DECLARE @ZerCount INT,@Sql NVARCHAR(max)
	SELECT @ZerCount = CAST([Value] AS INT) FROM op000 WHERE [Name] = 'AMNCFGZerAccuracy'
	IF @@ROWCOUNT = 0
		SET @ZerCount = 4
	IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE NAME = 'fnGetZeroValuePrice')
		DROP FUNCTION [dbo].[fnGetZeroValuePrice]
	SET @Sql = 'CREATE FUNCTION [dbo].[fnGetZeroValuePrice]() 
			RETURNS [FLOAT] 
		AS BEGIN 
			RETURN 9.E-' + CAST (@ZerCount AS NVARCHAR(2)) +'
		END '
	EXEC (@Sql)	
	SELECT @ZerCount = CAST([Value] AS INT) FROM op000 WHERE [Name] = 'AmnCFGZerAccuracyQty'
	IF @@ROWCOUNT = 0
		SET @ZerCount = 4
	IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE NAME = 'fnGetZeroValueQTY')
		DROP FUNCTION [dbo].[fnGetZeroValueQTY]
	SET @Sql = 'CREATE FUNCTION [dbo].[fnGetZeroValueQTY]() 
			RETURNS [FLOAT] 
		AS BEGIN 
			RETURN 9.E-' + CAST (@ZerCount AS NVARCHAR(2)) +'
		END '
	EXEC (@Sql)	

###########################################################################
#END