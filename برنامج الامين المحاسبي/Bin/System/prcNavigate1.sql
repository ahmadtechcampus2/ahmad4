#########################################################
CREATE PROCEDURE prcNavigate1
	@TableName AS [NVARCHAR](128), 
	@DirType AS [INT], -- 0: First, 1: Next, 2: Prev, 3: End, 4: Next10, 5: Prev10
	@CurGUID AS [UNIQUEIDENTIFIER], 
	@FldNumberName AS [NVARCHAR](128) = 'Number',
	@IsFirstAndLastOnly AS [BIT] = 0	,
	@CurNumber AS [INT]
AS 
	SET NOCOUNT ON 

	DECLARE 
		@CmdText AS NVARCHAR(MAX),
		@CurNumberStr AS NVARCHAR(128)

	SET @CurNumberStr = CONVERT(VARCHAR(128), @CurNumber) 

	CREATE TABLE #Result( 
		FirstGUID UNIQUEIDENTIFIER, 
		FirstNumber INT, 
		LastGUID UNIQUEIDENTIFIER,
		LastNumber INT, 
		[GUID] UNIQUEIDENTIFIER)

	SET @CmdText = '
		INSERT INTO #Result (FirstNumber, LastNumber)
		SELECT 
			MIN([' + @FldNumberName + ']), 
			MAX([' + @FldNumberName + '])
		FROM ' + @TableName + '
	
		UPDATE #Result
		SET 
			FirstGUID	= (SELECT TOP 1 [GUID] FROM ' + @TableName + ' WHERE [' + @FldNumberName + '] = FirstNumber	ORDER BY [GUID]),
			LastGUID	= (SELECT TOP 1 [GUID] FROM ' + @TableName + ' WHERE [' + @FldNumberName + '] = LastNumber	ORDER BY [GUID] DESC) '

	IF @IsFirstAndLastOnly = 0
	BEGIN 
		IF @DirType = 0 -- First 
			SET @CmdText = @CmdText + '	UPDATE [#Result] SET [GUID] = [FirstGUID] '

		IF @DirType = 3 -- Last 
			SET @CmdText = @CmdText + '	UPDATE [#Result] SET [GUID] = [LastGUID] '

		DECLARE @CurGUIDStr AS [NVARCHAR](50) 
		SET @CurGUIDStr = '''' + CAST( @CurGUID AS [NVARCHAR](40)) + '''' 
		
		IF ((@DirType = 1 /*Next*/) OR  (@DirType = 2 /*Prev*/))
		BEGIN 
			SET @CmdText = @CmdText + ' 
				DECLARE @CurNumber AS [INT]  
				SET @CurNumber = ' + @CurNumberStr + '

				UPDATE [#Result] 
				SET [GUID] = ( 
					SELECT TOP 1 [GUID] 
					FROM ' + @TableName + ' 
					WHERE 
						(([' + @FldNumberName + '] = @CurNumber) AND ([GUID] ' + (CASE @DirType WHEN 1 /*Next*/ THEN '>' ELSE /*Prev*/ '<' END) + @CurGUIDStr + '))
						OR 
						([' + @FldNumberName + '] ' + (CASE @DirType WHEN 1 /*Next*/ THEN '>' ELSE /*Prev*/ '<' END) + ' @CurNumber)
					ORDER BY [' + @FldNumberName + '] ' + (CASE @DirType WHEN 1 /*Next*/ THEN '' ELSE /*Prev*/ 'DESC' END) + ', [GUID] ' + (CASE @DirType WHEN 1 /*Next*/ THEN '' ELSE /*Prev*/ 'DESC' END) + ') '
		END 

		IF ((@DirType = 4 /*Next10*/) OR  (@DirType = 5 /*Prev10*/))
		BEGIN 
			SET @CmdText = @CmdText + ' 
				DECLARE @CurNumber AS [INT]  
				SET @CurNumber = ' + @CurNumberStr + '

				UPDATE [#Result] 
				SET [GUID] = ISNULL ( 
					( SELECT 
						TOP 1 [GUID]  ' + '
					FROM 
						' + @TableName + ' 
					WHERE 
						([' + @FldNumberName + '] ' + (CASE @DirType WHEN 4 /*Next10*/ THEN '>' ELSE /*Prev10*/ '<' END) + '= @CurNumber ' + (CASE @DirType WHEN 4 /*Next10*/ THEN '+' ELSE /*Prev10*/ '-' END) + ' 10 )
					ORDER BY [' + @FldNumberName + '] ' + (CASE @DirType WHEN 4 /*Next10*/ THEN '' ELSE /*Prev10*/ 'DESC' END) + ', [GUID] ' + (CASE @DirType WHEN 4 /*Next10*/ THEN '' ELSE /*Prev10*/ 'DESC' END) + '), '
						+ (CASE @DirType WHEN 4 THEN '[LastGUID]' ELSE '[FirstGUID]' END) + ') '
		
		END 
	END 
	EXECUTE (@CmdText) 

	IF ((@IsFirstAndLastOnly = 0) AND EXISTS (SELECT * FROM [#Result] WHERE ISNULL([GUID], 0x0) = 0x0))
	BEGIN 
		IF ((@DirType = 1)/*Next*/ OR (@DirType = 4)/*Next10*/ ) 
			UPDATE [#Result] SET [GUID] = [LastGUID]
		IF ((@DirType = 2)/*Prev*/ OR (@DirType = 5)/*Prev10*/) 
			UPDATE [#Result] SET [GUID] = [FirstGUID]
	END 
	
	SELECT FirstGUID, [GUID], LastGUID FROM [#Result]
#########################################################
#END
