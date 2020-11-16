#########################################################
CREATE PROC prcCheckSecurity_browesSec
	@userGUID [UNIQUEIDENTIFIER],  
	@result [NVARCHAR](128) = '#result',  
	@secViol [NVARCHAR](128) = '#secViol',  
	@securityFields [NVARCHAR](2000),  
	@guidFields [NVARCHAR](2000) = '', 
	@browseSecFunc [NVARCHAR](128), 
	@HSecListFunc [NVARCHAR](128) = '', 
	@violTypeID [INT], 
	@AuxParam [BIT] = 0 -- some browse 
AS
	
/*
This procedure:
	- deletes #result records where user security is less than the targeted object browsing security.
	- depend on a dynamic aproach, it depends on:
		- @browseSecFunc (function name in a string) to get the users' browse permission on targeted objects.
		- @hSecListFunc to get a list of names and browsing security of the target objects.
*/
	SET NOCOUNT ON 
	
	DECLARE  
		@sql [NVARCHAR](max), 
		@secFld [NVARCHAR](128), 
		@guidFld [NVARCHAR](128), 
		@found [BIT], 
		@i [INT]
		
	SET @SQL = '  
		DECLARE  
			@sec [INT],  
			@count [INT]  
		SET @sec = [dbo].' + @browseSecFunc + '(''' + CAST(@userGUID AS [NVARCHAR](128)) + '''' 
	IF @AuxParam <> 0 
		SET @SQL = @SQL + ', DEFAULT' 
	SET @SQL = @SQL + ') 
		SET @count = 0'  


	-- get secFld: 
	IF RIGHT(@securityFields, 1) <> ','  
		SET @securityFields = @securityFields + ','  

	SET @found = 0 
	SET @i = CHARINDEX(',', @securityFields) 
	WHILE @i > 0  
	BEGIN  
		SET @secFld = LTRIM(LEFT(@securityFields, @i - 1)) 
		IF EXISTS(SELECT * FROM [#fields] WHERE [name] = @secFld) 
		BEGIN 
			SET @found = 1
			BREAK
		END 
		SET @securityFields = LTRIM(SUBSTRING(@securityFields, @i + 1, 1000))  
		SET @i = CHARINDEX(',', @securityFields)  
	END

	IF @found = 0 -- no secFld where found, so, exit 
		RETURN 

	-- get guidFld: 
	SET @found = 0 
	IF ISNULL(@guidFields, '') <> '' AND ISNULL(@HSecListFunc, '') <> '' 
	BEGIN 
		IF RIGHT(@guidFields, 1) <> ','  
			SET @guidFields = @guidFields + ','  
		SET @i = CHARINDEX(',', @guidFields) 
	 
		WHILE @i > 0 
		BEGIN 
			SET @guidFld = LTRIM(LEFT(@guidFields, @i - 1)) 
			IF EXISTS(SELECT * FROM [#fields] WHERE [name] = @guidFld) 
			BEGIN 
				SET @found = 1 
				BREAK 
			END
			SET @guidFields = LTRIM(SUBSTRING(@guidFields, @i + 1, 1000)) 
			SET @i = CHARINDEX(',', @guidFields) 
		END 
	END 
	 
	IF @found = 0 -- no guidFld where found, so, continue with no Heirarichal Security Checking 
		SET @SQL = @SQL + ' 
		DELETE FROM ' + @result + ' WHERE ' + @secFld + ' > @sec  
		SET @count = @count + @@ROWCOUNT' 
	ELSE 
		SET @SQL = @SQL + ' 
		DELETE ' + @result + ' FROM ' + @result + ' AS [r] INNER JOIN ' + @HSecListFunc + '() AS [f] ON [r].' + @guidFld +' = [f].[GUID] where [f].[Security] > @sec 
		SET @count = @count + @@ROWCOUNT' 

	SET @SQL = @SQL + '
		IF @count > 0  
			INSERT INTO ' + @secViol + ' SELECT ' + CAST(@violTypeID AS [NVARCHAR](7)) + ', @count' 

	EXEC (@SQL) 

#########################################################
#END