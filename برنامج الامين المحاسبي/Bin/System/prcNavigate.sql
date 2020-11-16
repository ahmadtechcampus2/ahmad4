#########################################################
CREATE PROCEDURE prcNavigate
	@tbl AS [NVARCHAR](128),
	@dir AS [INT], -- 0: First, 1: Next, 2: Prev, 3: End
	@g AS [UNIQUEIDENTIFIER] OUTPUT,
	@c AS [INT] = 1,
	@FldNum AS [NVARCHAR](128) = 'Number'
AS
	SET NOCOUNT ON
	DECLARE @str AS [NVARCHAR](1000)
	DECLARE @str1 AS [NVARCHAR](1000)
	IF @dir = 0 -- First
		BEGIN
		SET @str = 'SELECT TOP 1 [GUID] FROM ' + @tbl+ ' ORDER BY [' + @FldNum + '], [GUID]'
		EXECUTE (@str)
		RETURN
	END
	IF @dir = 1 -- Next
		BEGIN
		DECLARE @gs AS [NVARCHAR](50)
		DECLARE @ns AS [NVARCHAR](20)
		SET @gs = '''' + CAST( @g AS [NVARCHAR](40)) + ''''
		SET @str = 'DECLARE @N AS [INT]
					DECLARE @g1 AS [UNIQUEIDENTIFIER]
					SET NOCOUNT ON
					SELECT @n = [' + @FldNum + '] FROM ' + @tbl + ' WHERE [GUID] = ' + @gs
		SET @str1 = '
					SELECT TOP 1 @g1 = [mt].[GUID] FROM ' + @tbl + ' AS [mt] '
		SET @str = @str + @str1 + '
					WHERE [mt].[GUID] > ' + @gs + ' and [mt].[' + @FldNum + '] = @n
					ORDER BY [' + @FldNum + '], [GUID]
				IF @@ROWCOUNT = 0 ' +
					@str1 + '
					WHERE [mt].[' + @FldNum + '] > @n
					ORDER BY [' + @FldNum + '], [GUID]
					SET NOCOUNT OFF
					SELECT @g1'
		EXECUTE( @str)
		RETURN
	END
	IF @dir = 2 -- PREV
		BEGIN
		SET @gs = '''' + CAST( @g AS [NVARCHAR](40)) + ''''
		SET @str = 'DECLARE @N AS [INT]
					DECLARE @g1 AS [UNIQUEIDENTIFIER]
					SET NOCOUNT ON
					SELECT @n = [' + @FldNum + '] FROM ' + @tbl + ' WHERE [GUID] = ' + @gs
		SET @str1 = '
					SELECT TOP 1 @g1 = [mt].[GUID] FROM ' + @tbl + ' AS [mt] '
		SET @str = @str + @str1 + '
					WHERE [mt].[GUID] < ' + @gs + ' and [mt].[' + @FldNum + '] = @n
					ORDER BY ' + @FldNum + ' DESC, [GUID] DESC
				IF @@ROWCOUNT = 0 ' +
					@str1 + '
					WHERE [mt].[' + @FldNum + '] < @n
					ORDER BY ' + @FldNum + ' DESC, [GUID] DESC
					SET NOCOUNT OFF
					SELECT @g1'
		EXECUTE( @str)
		RETURN
	END
	IF @dir = 3 -- Last
		BEGIN
		SET @str = 'SELECT TOP 1 [GUID] FROM ' + @tbl+ ' ORDER BY [' + @FldNum + '] DESC, [GUID] DESC'
		EXECUTE (@str)
		RETURN
	END
 
#########################################################
#END