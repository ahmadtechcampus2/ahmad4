#######################################################################
CREATE FUNCTION fnExtPropName (@name sysname)
	RETURNS sysname
AS
BEGIN
	RETURN @name
END
#######################################################################
CREATE FUNCTION fnListExtProp( @name sysname)
	RETURNS @Result TABLE( 
		objtype sysname, 
		objname sysname, 
		name sysname, 
		value sql_variant)
AS
BEGIN
	INSERT INTO @Result SELECT ISNULL(objname, ''), ISNULL(objtype, ''), name, value FROM sys.fn_listextendedproperty(@name, NULL, NULL, NULL, NULL, NULL, NULL)
	RETURN
END
#######################################################################
CREATE PROCEDURE prcDropExtProp
	@name VARCHAR(128)
AS
	if EXISTS (SELECT * FROM fnListExtProp(@name))
		EXECUTE sp_dropextendedproperty @name = @name
#######################################################################
CREATE PROCEDURE prcAddExtProp
	@name sysname,
	@value NVARCHAR(4000),
	@bUpdateIfExist INT = 0
AS
	IF (@bUpdateIfExist = 1)
	BEGIN
		EXECUTE prcDropExtProp @name 
		EXECUTE sp_addextendedproperty @name = @name, @value = @value
	END
	ELSE
	BEGIN
		if NOT  EXISTS (SELECT * FROM fnListExtProp(@name)) 
		EXECUTE sp_addextendedproperty @name = @name, @value = @value
	END
#######################################################################
#END
