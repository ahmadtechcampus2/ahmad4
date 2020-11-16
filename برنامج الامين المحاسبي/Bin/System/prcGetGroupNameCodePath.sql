#########################################################
CREATE  PROC prcGetGroupNameCodePath
@GrGuid [UNIQUEIDENTIFIER]
AS 
	SET NOCOUNT ON
	
	DECLARE @MaxLevel [INT] 
	SELECT @MaxLevel = MAX([Level]) FROM [fnGetGroupsListByLevel](@GrGuid,0) 
	--PRINT @MaxLevel 
	CREATE TABLE [#GPRESULT] (
		[GUID]		[UNIQUEIDENTIFIER],
		[NAME]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[CODE]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[LATINNAME]	[NVARCHAR](1000) COLLATE ARABIC_CI_AI
	) 
	DECLARE @Index [INT] 
	SET @Index = 1 
	DECLARE @c CURSOR 
	DECLARE @Guid [UNIQUEIDENTIFIER], @Name [NVARCHAR](1000), @Code [NVARCHAR](1000), @LatinName [NVARCHAR](1000), @Level [INT]
	WHILE (@Index <= @MaxLevel) 
	BEGIN  
		SET @c = CURSOR FAST_FORWARD FOR SELECT [fn].[GUID], [grName], [grCode], [grLatinName] + [grCode], [Level]  
												FROM [fnGetGroupsListByLevel](@GrGuid,@Index) [fn] 
													INNER JOIN [vwGr] [gr] ON [fn].[Guid] = [gr].[grGuid] 
														WHERE [LEVEL] = @Index 
														 
		IF @Index=1 
		BEGIN 
			OPEN @c 
			FETCH @c INTO @Guid,@Name,@Code,@LatinName,@Level 
			WHILE @@FETCH_STATUS=0 
			BEGIN  
				INSERT INTO [#GPRESULT] VALUES(@Guid,@Name,@Code,@LatinName) 
				FETCH @c INTO @Guid,@Name,@Code,@LatinName,@Level 
			END 
			CLOSE @c 
		END 
		 
		ELSE 
		BEGIN 
			OPEN @c 
			FETCH @c INTO @Guid,@Name,@Code,@LatinName,@Level 
			WHILE @@FETCH_STATUS=0 
			BEGIN  
				INSERT INTO [#GPRESULT] SELECT @Guid,[NAME]+'  !'+@Name,[CODE]+'  !'+@Code,[LatinName]+'  !'+@LatinName
						FROM [#GPRESULT] [Re] INNER JOIN [vwGr] [gr] ON [gr].[grParent] = [re].[Guid] 
							WHERE [grGuid] = @Guid 
				FETCH @c INTO @Guid,@Name,@Code,@LatinName,@Level 
			END 
			CLOSE @c 
			
		END 
		SET @Index=@Index+1 
	END 
	DEALLOCATE @c
	SELECT * FROM [#GPRESULT]
	DROP TABLE [#GPRESULT] 
#########################################################
#END 