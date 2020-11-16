#################################################################################
CREATE PROC prcExtSec_Tree
	@UserNumber [INT] = 0,
	@Filter [INT] = 0, -- 0 no filtering, 1 checked only, 2 unchecked only
	@Lang	[INT] = 0 -- Language	(0=Arabic; 1=English)  
AS
/*
	@Filter:
		0. no filtering, all #result columns are returned, usualy used to fill/refresh tree
		1. checked only,
		2. unchecked only

Result:
	icons ids:
		1. accounts root.
		2. normal account.
		3. normal account with customer
		4. final account.
		5 collective account.
		6. distributed account.
	
		11. costs root.
		12. cost.
	
		21. materials and groups root.
		22. group.
		23. material
	
		31. stores root
		32. store.
*/

	SET NOCOUNT ON

	DECLARE
		@c CURSOR,
		@tableName [NVARCHAR](128),
		@func [NVARCHAR](128),
		@LangFldName [NVARCHAR](100),
		@SQL [NVARCHAR](max),
		@Crt [NVARCHAR](1000),
		@UserMask [BIGINT],
		@MaskStr [NVARCHAR](10),
		@UserNum [INT]

		if( @UserNumber between 1 and 63)
		begin
			set @UserNum = @UserNumber
			SET @MaskStr = 'Mask1'
		end
	
		if( @UserNumber between 64 and 127)
		begin
			set @UserNum = @UserNumber - 63
			SET @MaskStr = 'Mask2'
		end
		if( @UserNumber between 128 and 191)
		begin
			set @UserNum = @UserNumber - 127
			SET @MaskStr = 'Mask3'
		end
		if( @UserNumber between 192 and 255)
		begin
			set @UserNum = @UserNumber - 191
			SET @MaskStr = 'Mask4'
		end
		SELECT @UserMask = dbo.fnGetBranchMask( @UserNum)

		CREATE TABLE [#Result] (
			[GUID] [UNIQUEIDENTIFIER],
			[ParentGUID] [UNIQUEIDENTIFIER],
			[Code] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[tableName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Mask1] [BIGINT],
			[Mask2] [BIGINT],
			[Mask3] [BIGINT],
			[Mask4] [BIGINT],
			[SortNum] [INT],
			[IconID] [INT],
			[Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI,
			[Level] [INT])
	
		DECLARE @id AS [INT], @idStr AS [NVARCHAR](10)

		SET @id = 0
		SET @idStr = CAST( @id AS [NVARCHAR](10))
		
		SET @LangFldName = CASE WHEN (@Lang = 1) 
					THEN 'CASE WHEN ( [LatinName] <> '''') THEN  [LatinName] ELSE [Name] END'
					ELSE '[Name]' END
		SET @c = CURSOR FAST_FORWARD FOR SELECT [tableName],[ListingFunctionName] FROM [isrt] WHERE [ListingFunctionName] <> ''

		OPEN @c FETCH FROM @c INTO @tableName, @func
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @SQL =  'INSERT INTO [#Result] SELECT [GUID],[ParentGUID],[Code], case ' + @LangFldName + ' when '''' then name else ' + @LangFldName + ' end, [tableName], 0, 0, 0, 0, [SortNum], [IconID], (''' + @idStr + ''' + [Path]) AS [Path], [Level] FROM [dbo].' + @func + '()'
			EXEC(@SQL)
			SET @id = @id + 1		
			SET @idStr = CAST( @id AS [NVARCHAR](10))
			FETCH FROM @c INTO @tableName, @func
		END
		CLOSE @c DEALLOCATE @c

		-----------------------------------------------------------------------------------------
		UPDATE [Result] SET 
			[Mask1] = [iss].[Mask1],
			[Mask2] = [iss].[Mask2],
			[Mask3] = [iss].[Mask3],
			[Mask4] = [iss].[Mask4]
		FROM
			[#Result] [Result] inner join [isx000] [iss] on [Result].[Guid] = [iss].[ObjGuid]

		IF @Filter = 0
			SET @Crt = ''
		ELSE 
		BEGIN
			IF @Filter = 1
			begin
				SET @Crt = ' WHERE ParentGuid = 0x0 OR ( '+ @MaskStr + ' & ' +  CAST( @UserMask AS NVARCHAR(10)) + ' <> 0)'
			end
			ELSE
				SET @Crt = ' WHERE ParentGuid = 0x0 OR ( '+ @MaskStr + ' & ' +  CAST( @UserMask AS NVARCHAR(10)) + ' = 0)'
		END
	
		SET @SQL = 'SELECT * FROM [#Result]' + @Crt +  ' ORDER BY [Path]'--ParentGUID'
		EXEC (@SQL)
		--print (@SQL)
		DROP TABLE [#Result]
#################################################################################
#END