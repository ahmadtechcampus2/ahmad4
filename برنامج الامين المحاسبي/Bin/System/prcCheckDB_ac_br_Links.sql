#########################################################################
CREATE PROC prcCheckDB_ac_br_Links 
	@Correct [INT] = 0
AS
	DECLARE @AccLevel TABLE( [Guid] [UNIQUEIDENTIFIER], [LEVEL] [INT], [BranchMask] [BIGINT])
	INSERT INTO @AccLevel
		SELECT 
			[fn].[Guid], 
			[fn].[Level],
			[ac].[BranchMask]
		FROM
			[ac000] as [ac] INNER JOIN [fnGetAccountsList]( 0x0, 0) as [fn] 
			ON [ac].[Guid] = [fn].[Guid]
	
	DECLARE @Continue [INT], @CurLevel [INT]
	SELECT @CurLevel = MAX( [Level]) FROM @AccLevel
	
	DECLARE @Tbl TABLE( [Guid] [UNIQUEIDENTIFIER], [BranchMask] [BIGINT], [Guid2] [UNIQUEIDENTIFIER], [BranchMask2] [BIGINT])
	WHILE @CurLevel >= 0
	BEGIN 
		INSERT INTO @Tbl
		SELECT [ac].[Guid], [ac].[BranchMask], [acP].[Guid], [acP].[BranchMask]
		FROM
			[ac000] AS [ac] 
			INNER JOIN [ac000] AS [acP]
			ON [ac].[Guid] = [acP].[ParentGuid]
			INNER JOIN @AccLevel AS [AcLevel]
			ON [acP].[Guid] = [AcLevel].[Guid]

		WHERE 
			[AcLevel].[Level] = @CurLevel
			AND ([ac].[Branchmask] & [acP].[Branchmask]) <> [acP].[Branchmask]

		SET @CurLevel = @CurLevel - 1
	END

	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [g2], [c1],[c2])
			SELECT 
				0x8, [tb].[Guid], [tb].[Guid2], [ac].[Code], [ac].[Name]
			FROM 
				@Tbl AS [tb] 
				INNER JOIN [AC000] AS [ac] ON [tb].[Guid2] = [ac].[Guid]


	IF @Correct <> 0
	BEGIN
		CREATE TABLE [#TmpTbl]( [Guid] [UNIQUEIDENTIFIER], [Branchmask] [BIGINT], [Id] [INT] IDENTITY(1,1))
		INSERT INTO [#TmpTbl] ( [Guid], [Branchmask]) SELECT [Guid] , [BranchMask2]  FROM @Tbl GROUP BY [GUID], [BranchMask2]
		SET @Continue = @@IDENTITY
		WHILE( @Continue <> 0)
		BEGIN
			UPDATE [ac000]
				SET [ac000].[Branchmask] = [ac].[Branchmask] | [AccTbl].[Branchmask]
			FROM
				[ac000] AS [ac] INNER JOIN [#TmpTbl] AS [AccTbl]
				ON [ac].[Guid] = [AccTbl].[Guid]
			WHERE 
				[AccTbl].[Id] = @Continue

			SET @Continue = @Continue - 1
		END
	END
#########################################################################
#END