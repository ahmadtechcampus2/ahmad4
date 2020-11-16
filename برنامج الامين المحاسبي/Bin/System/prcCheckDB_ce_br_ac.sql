#################################################################
CREATE PROCEDURE prcCheckDB_ce_br_ac
	@Correct [INT] = 0 
AS 
	IF @Correct <> 1  
	BEGIN 
		INSERT INTO [ErrorLog] ( [Type], [g1], [g2], [c1], [c2])  
			SELECT 0x608, [en].[ceGUID], [ac].[Guid], [ac].[Code], [ac].[Name]
			FROM 
				[vwCeEn] AS [en] INNER JOIN [ac000] AS [ac] 
				ON [en].[enAccount] = [ac].[Guid] 
				INNER JOIN [br000] AS [br] 
				ON [ceBranch] = [br].[Guid] 
			WHERE 
				( [dbo].[fnGetBranchMask]( [br].[Number]) & [ac].[BranchMask]) = 0
	END 
	IF @Correct <> 0  
	BEGIN  
		DECLARE @Continue [INT], @CurRec [INT]
		CREATE TABLE [#Res] ( [AccGuid] [UNIQUEIDENTIFIER], [acBranchMask] [BIGINT], [ceBranchMask] [BIGINT], [Id] [INT] IDENTITY(1,1))

		INSERT INTO [#Res] ( [AccGuid], [acBranchMask], [ceBranchMask])
			SELECT 
				[ac].[Guid], 
				[ac].[BranchMask], 
				[dbo].[fnGetBranchMask]( [br].[Number])
			FROM 
				[vwCeEn] AS [en] INNER JOIN [ac000] AS [ac] 
				ON [en].[enAccount] = [ac].[Guid] 
				INNER JOIN [br000] AS [br] 
				ON [ceBranch] = [br].[Guid] 
			WHERE 
				( [dbo].[fnGetBranchMask]( [br].[Number]) & [ac].[BranchMask]) = 0

		SET @CurRec = @@ROWCOUNT

		DECLARE @Tbl TABLE( [Guid] [UNIQUEIDENTIFIER], [BranchMask] [BIGINT] DEFAULT 0)
		INSERT INTO @Tbl( [Guid]) SELECT [AccGuid] FROM [#Res] GROUP BY [AccGuid]

		WHILE @CurRec >= 0 
		BEGIN  
			UPDATE [Tbl] SET [Tbl].[BranchMask] = [Tbl].[BranchMask] | [Res].[ceBranchMask]
			FROM 
				[#Res] AS [Res] INNER JOIN @Tbl AS [Tbl]
				ON [Res].[AccGuid] = [Tbl].[Guid]
			WHERE  
				[Res].[id] = @CurRec
			SET @CurRec = @CurRec - 1
		END

		UPDATE [ac] 
			SET [ac].[BranchMask] = [ac].[BranchMask] | [Tbl].[BranchMask]
		FROM 
			[ac000] AS [ac] INNER JOIN @Tbl AS [Tbl] ON [ac].[Guid] = [Tbl].[Guid]
	END  
#################################################################
#END