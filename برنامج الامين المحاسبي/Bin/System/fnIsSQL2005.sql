###########################################################################
CREATE FUNCTION fnGetSQLProductVersion()
	RETURNS [FLOAT]
AS BEGIN
	DECLARE 
		@ver_str [NVARCHAR](128),
		@ver [FLOAT]

      SET @ver_str = CAST( SERVERPROPERTY('ProductVersion') AS [NVARCHAR](128))
      SET @ver = CAST( LEFT(@ver_str, 4) AS [FLOAT])
      return @ver
END
###########################################################################
CREATE FUNCTION fnIsSQL2005() 
	RETURNS [INT]
AS BEGIN

/*
This function:
	- returns 1 if the sql's version 2005+ else return 0
*/
	DECLARE @ret_val [INT]

    SET @ret_val = 0
    IF dbo.fnGetSQLProductVersion() >= 9 
        SET @ret_val = 1
    RETURN @ret_val
END

###########################################################################
CREATE FUNCTION fnIsSQL2008() 
	RETURNS [INT]
AS BEGIN

/*
This function:
	- returns 1 if the sql's version 2008+ else return 0
*/
	DECLARE @ret_val [INT]

    IF dbo.fnGetSQLProductVersion() >= 10
        SET @ret_val = 1
    RETURN @ret_val
END
###########################################################################
CREATE FUNCTION fnIsSQL2012() 
	RETURNS [INT]
AS BEGIN

/*
This function:
	- returns 1 if the sql's version 2012 else return 0
*/
	DECLARE @ret_val [INT]

      SET @ret_val = 0
      IF dbo.fnGetSQLProductVersion() >= 11
            SET @ret_val = 1
      RETURN @ret_val
END
###########################################################################
CREATE FUNCTION fnIsSQL2016() 
	RETURNS [INT]
AS BEGIN

/*
This function:
	- returns 1 if the sql's version 2016 else return 0
*/
	DECLARE @ret_val [INT]

      SET @ret_val = 0
      IF dbo.fnGetSQLProductVersion() >= 13
            SET @ret_val = 1
      RETURN @ret_val
END
###########################################################################
CREATE FUNCTION fnIsSQL2014SP1()
RETURNS BIT
BEGIN
	DECLARE @ver_str [NVARCHAR](MAX);
	SET @ver_str = LEFT(CAST( SERVERPROPERTY('ProductVersion') AS [NVARCHAR](128)), 6);
	-- SQL2014 - SP1 - SP2 - SP3
	IF @ver_str = '12.0.4' OR @ver_str = '12.0.5' OR @ver_str = '12.0.6'
		RETURN 1;

	RETURN 0;
END
###########################################################################
#END 
