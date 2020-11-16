##########################################################################
CREATE PROCEDURE prcDisableTriggers
	@Tbl [NVARCHAR](256),
	@bExcludeReplicTriggers [BIT] = 1
AS
	DECLARE @Sql [NVARCHAR](max)
	IF @bExcludeReplicTriggers = 1 
	BEGIN 
		DECLARE 
			@c		CURSOR,
			@Tr [NVARCHAR](300),
			@Id [INT],
			@TrRep [NVARCHAR](300)
			SET @TrRep = 'trg_' + @Tbl + '_replic'
		SELECT @Id = [Id] FROM [dbo].[sysobjects] WHERE [Name] = @Tbl
	
		SET @c = CURSOR FAST_FORWARD FOR  
			SELECT [Name] FROM  [dbo].[sysobjects]  
			WHERE xtype = 'TR' AND [Name] NOT LIKE @TrRep + '%' AND [parent_obj] = @Id
			AND [Name] NOT LIKE 'MSmerg%'
		OPEN @c FETCH FROM @c INTO @Tr
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @Sql = 'ALTER TABLE [' + @Tbl + '] DISABLE TRIGGER [' + @Tr + ']'
			EXEC (@Sql)
			FETCH FROM @c INTO @Tr
		END
		CLOSE @c DEALLOCATE @c
	END ELSE BEGIN
		SET @Sql = 'ALTER TABLE [' + @Tbl + '] DISABLE TRIGGER ALL'
		EXEC (@Sql)
	END 	
##########################################################################
CREATE PROCEDURE prcEnableTriggers
	@Tbl NVARCHAR(256)
AS
	EXEC ('ALTER TABLE [' + @Tbl + '] ENABLE TRIGGER ALL') 
##########################################################################
#END
