#########################################################
CREATE PROCEDURE repMissingEntriesNumber
	@SrcGUID UNIQUEIDENTIFIER,
	@FromNum FLOAT = 0
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Result
	(
		[Number] INT,
		[Branch] UNIQUEIDENTIFIER,
		[Type] UNIQUEIDENTIFIER,
		[TypeName] NVARCHAR(250) COLLATE ARABIC_CI_AI
	)

	CREATE TABLE #Num( [Number] INT, [Type] UNIQUEIDENTIFIER)

	DECLARE 
		@MaxNum INT,
		@Counter INT,
		@TypeName NVARCHAR(250) 		
	
	DECLARE 
		@C CURSOR,
		@Type UNIQUEIDENTIFIER

	SET @C = CURSOR FAST_FORWARD FOR 
		SELECT DISTINCT [IdType] FROM [dbo].[RepSrcs] WHERE [IdTbl] = @SrcGUID 
	
	OPEN @C FETCH NEXT FROM @C INTO @Type 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		TRUNCATE TABLE [#Num]
		SET @MaxNum = 0
		SET @Counter = ISNULL( @FromNum, 0)

		IF @Type = 0x0
		BEGIN 
			SET @MaxNum = (SELECT MAX([Number]) FROM [ce000])

			IF ISNULL( @MaxNum, 0) = 0
				CONTINUE

			WHILE @Counter < @MaxNum
			BEGIN 
				INSERT INTO [#Num] SELECT @Counter + 1, @Type
				SET @Counter = @Counter + 1
			END 
			
			INSERT INTO #Result
			SELECT 
				[n].[Number],
				0x0,
				0x0,
				(CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN 'ÓäÏ ÞíÏ' ELSE 'Entry' END)
			FROM 
				[#Num] [n]
				LEFT JOIN [ce000] [ce] ON [ce].[Number] = [n].[Number]
			WHERE 
				[ce].[Guid] IS NULL
			
		END ELSE IF EXISTS( SELECT * FROM [bu000] WHERE [TypeGUID] = @Type)
		BEGIN 
			SET @MaxNum = (SELECT MAX([Number]) FROM [bu000] WHERE [TypeGUID] = @Type)

			IF ISNULL( @MaxNum, 0) = 0
				CONTINUE

			WHILE @Counter < @MaxNum
			BEGIN 
				INSERT INTO [#Num] SELECT @Counter + 1, @Type
				SET @Counter = @Counter + 1
			END 
			
			SELECT 
				@TypeName = (CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [Name] ELSE [LatinName] END)
			FROM 
				[bt000]
			WHERE 
				[guid] = @Type

			INSERT INTO #Result
			SELECT 
				[n].[Number],
				0x0,
				@Type,
				@TypeName
			FROM 
				[#Num] [n]
				LEFT JOIN [bu000] [bu] ON [bu].[Number] = [n].[Number] AND [bu].[TypeGUID] = [n].[Type]
			WHERE 
				([bu].[Guid] IS NULL)

		END ELSE IF EXISTS( SELECT * FROM [py000] WHERE [TYPEGUID] = @Type)
		BEGIN 
			SET @MaxNum = (SELECT MAX([Number]) FROM [py000] WHERE [TypeGUID] = @Type)

			IF ISNULL( @MaxNum, 0) = 0
				CONTINUE

			WHILE @Counter < @MaxNum
			BEGIN 
				INSERT INTO [#Num] SELECT @Counter + 1, @Type
				SET @Counter = @Counter + 1
			END 
			
			SELECT 
				@TypeName = (CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [Name] ELSE [LatinName] END)
			FROM 
				[et000]
			WHERE 
				[guid] = @Type

			INSERT INTO #Result
			SELECT 
				[n].[Number],
				0x0,
				@Type,
				@TypeName
			FROM 
				[#Num] [n]
				LEFT JOIN [py000] [py] ON [py].[Number] = [n].[Number] AND [py].[TypeGUID] = [n].[Type]
			WHERE 
				([py].[Guid] IS NULL)

		END ELSE IF EXISTS( SELECT * FROM [ch000] WHERE [TYPEGUID] = @Type)
		BEGIN 
			SET @MaxNum = (SELECT MAX([Number]) FROM [ch000] WHERE [TypeGUID] = @Type)

			IF ISNULL( @MaxNum, 0) = 0
				CONTINUE

			WHILE @Counter < @MaxNum
			BEGIN 
				INSERT INTO [#Num] SELECT @Counter + 1, @Type
				SET @Counter = @Counter + 1
			END 
			
			SELECT 
				@TypeName = (CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [Name] ELSE [LatinName] END)
			FROM 
				[nt000]
			WHERE 
				[guid] = @Type

			INSERT INTO #Result
			SELECT 
				[n].[Number],
				0x0,
				@Type,
				@TypeName
			FROM 
				[#Num] [n]
				LEFT JOIN [ch000] [ch] ON [ch].[Number] = [n].[Number] AND [ch].[TypeGUID] = [n].[Type]
			WHERE 
				([ch].[Guid] IS NULL)

		END 
		FETCH NEXT FROM @C INTO @Type 
	END 
	CLOSE @C DEALLOCATE @C 

	SELECT 
		* 
	FROM 
		[#Result]
	ORDER BY
		[TypeName],
		[Number]

#########################################################
#END
