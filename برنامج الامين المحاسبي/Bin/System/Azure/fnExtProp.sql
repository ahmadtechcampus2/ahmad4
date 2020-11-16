#######################################################################
CREATE FUNCTION fnExtPropName (@name sysname)
	RETURNS sysname
AS
BEGIN
	RETURN 'ext_prop_'  + @name
END
#######################################################################
CREATE FUNCTION fnListExtProp( @name NVARCHAR(128))
	RETURNS @Result TABLE( 
		objtype sysname, 
		objname 
		sysname, 
		name sysname, 
		value sql_variant)
AS
BEGIN
	INSERT INTO @Result SELECT N'' AS objname, N'' AS objtype, name, value FROM [op000] WHERE name = dbo.fnExtPropName( @name)
	RETURN
END
#######################################################################
CREATE PROCEDURE prcDropExtProp
	@name VARCHAR(128)
AS
	DELETE [op000] WHERE name = dbo.fnExtPropName( @name)
#######################################################################
CREATE PROCEDURE prcAddExtProp
	@name sysname,
	@value NVARCHAR(4000),
	@bUpdateIfExist INT = 0
AS
	DECLARE @prevValue NVARCHAR(4000)
	IF @bUpdateIfExist <> 0
	BEGIN
		SELECT TOP 1 @prevValue = value FROM op000 WHERE name = dbo.fnExtPropName( @name)
		EXECUTE prcDropExtProp @name
	END
	INSERT INTO [op000] (Name, Value, PrevValue) VALUES( dbo.fnExtPropName(@name), @value, ISNULL( @prevValue, ''))
#######################################################################
#END