#########################################################
CREATE TRIGGER trg_br000_general
	ON [br000] FOR INSERT, DELETE , UPDATE
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@oldBrCnt	[INT], 
		@newBrCnt	[INT], 
		@delBrCnt	[INT],
		@InsBrCnt	[INT],
		@c			CURSOR,
		@GUID		[NVARCHAR](128), 
		@Parent		[UNIQUEIDENTIFIER], 
		@OldParent	[UNIQUEIDENTIFIER], 
		@BrGUID			[UNIQUEIDENTIFIER],
		@BrParentGUID	[UNIQUEIDENTIFIER],
		@ParentNumber	[FLOAT],
		@NewNumber		[int],
		@NewParent		[UNIQUEIDENTIFIER]

	SET @newBrCnt = (SELECT COUNT(*) FROM [br000]) 
	SET @delBrCnt = (SELECT COUNT(*) FROM [deleted]) 
	SET @InsBrCnt = (SELECT COUNT(*) FROM [inserted])
	SET @OldBrCnt = @newBrCnt - @InsBrCnt +  @delBrCnt
	 
	IF((@OldBrCnt < 2) AND (@NewBrCnt > 1)) OR ((@OldBrCnt > 2) AND (@NewBrCnt < 2)) 
		EXEC [prcBranch_Optimize]

	IF ( @InsBrCnt > 0) AND ( @delBrCnt = 0 )
	BEGIN
		DECLARE @CC CURSOR
		SET @CC = CURSOR FAST_FORWARD FOR SELECT [GUID], [ParentGUID] FROM [INSERTED]
		OPEN @CC 	
		FETCH FROM @CC INTO @BrGUID,@BrParentGUID
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			  DECLARE @BrCount [INT]
			  SELECT  @BrCount = COUNT( [Number]) FROM [br000]
			  IF (EXISTS( SELECT * FROM [Br000] WHERE [ParentGUID] = @BrParentGUID))   OR ( @BrCount = 1 ) 
			  BEGIN
				UPDATE [Br000] SET [NUMBER] = [dbo].[FnGetNewBranchNumber]()  WHERE [GUID] = @BrGUID
			  END
			  ELSE -- Åä ßÇä ÇáÝÑÚ Ãæá ÝÑÚ íÖÇÝ 
			  BEGIN
			  	SELECT @ParentNumber = [Number] FROM [Br000] WHERE [GUID] = @BrParentGUID
				UPDATE [Br000] SET [NUMBER]  = @ParentNumber  WHERE [GUID] = @BrGUID
				UPDATE [Br000] SET [NUMBER] = 0  WHERE [GUID] = @BrParentGUID
			  END
			  FETCH FROM @CC INTO @BrGUID,@BrParentGUID
		END
		CLOSE @CC
		DEALLOCATE @CC
	END

	IF UPDATE([ParentGUID])
	BEGIN
		SET @c = CURSOR FAST_FORWARD FOR 
					SELECT 
						CAST(ISNULL([i].[GUID], [d].[GUID]) AS [NVARCHAR](128)), 
						ISNULL([d].[ParentGUID], 0x0), 
						ISNULL([i].[ParentGUID], 0x0)
					FROM [inserted] AS [i] FULL JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]

		OPEN @c FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @Parent = @NewParent
			WHILE @Parent <> 0x0
			BEGIN 
				-- orphants 
				SET @Parent = (SELECT ISNULL( [ParentGUID], 0x0) FROM [Br000] WHERE [GUID] = @Parent )
				IF @Parent IS NULL 
					INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0091: Parent not found (Orphants)', @guid 
				-- short-circuit check: 
				IF @Parent = @GUID 
					INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT 1, 0, 'AmnE0092: Parent found descending from own sons (Short Circuit)', @guid 
			END 
			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END 
		CLOSE @c DEALLOCATE @c
	END
	-----------------------------------------------------------------------------------------------------------
	-- test the movements if Branch have a move and convert it to main branch----------------------------------	
	declare 
		@c1			CURSOR, 
		@c2			CURSOR

	IF ( UPDATE([ParentGUID])  or  @InsBrCnt > 0) 
	begin
		declare
			@Tbl NVARCHAR(255), @FldName NVARCHAR(255), @IsSingle INT,
			@BranchMask BIGINT,
			@ParentGuid UNIQUEIDENTIFIER,
			@Sql NVARCHAR(max),
			@BranchNumber INT,
			@used INT
			CREATE table #TblResS ( Guid uniqueidentifier)
			CREATE table #TblResNS ( Mask BIGINT)
		
		SET @used = 0
		
		SET @c1 = CURSOR FAST_FORWARD FOR SELECT Guid, ParentGuid FROM inserted
		OPEN @c1 FETCH FROM @c1 INTO @Guid, @ParentGuid
		WHILE @@FETCH_STATUS = 0  
		BEGIN
 			IF( ( ISNULL( @ParentGuid, 0x0) != 0x0) and ( not exists(select * from br000 where Guid != @Guid and ParentGuid = @ParentGuid)))
			BEGIN	
				SELECT @BranchNumber = Number FROM br000 WHERE Guid = @ParentGuid
				SET @BranchMask = dbo.fnGetBranchMask( @BranchNumber)
	
				SET @c2 = CURSOR FAST_FORWARD FOR SELECT TableName, SingleBranchFldName, SingleBranch from brt	

				OPEN @c2 FETCH FROM @c2 INTO @Tbl, @FldName, @IsSingle
				WHILE @@FETCH_STATUS = 0  
				BEGIN
					IF( @IsSingle = 1)
					BEGIN
						SET @Sql = 'select top 1 [%1] from [%0] where [%1] = ''%2'''
						INSERT INTO #TblResS( Guid) EXEC [prcExecuteSql] @Sql, @Tbl, @FldName, @ParentGuid
						set @used = @@rowcount
					END
					ELSE
					BEGIN
						SET @Sql = 'select top 1 [BranchMask] from [%0] where [%1] & %2 != 0'
						INSERT INTO #TblResNS( Mask) EXEC [prcExecuteSql] @Sql, @Tbl, 'BranchMask', @BranchMask
						set @used = @@rowcount
					END
					IF ( @used > 0)
					BEGIN
						--RAISERROR('AmnE0092: Can''t Save.. branch is used', 16, 1)
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
							SELECT 1, 0, 'AmnE0083: Main branch is used', @ParentGuid

						ROLLBACK TRANSACTION 
						RETURN
					END
					FETCH FROM @c2 INTO @Tbl, @FldName, @IsSingle
				END
				CLOSE @c2 DEALLOCATE @c2 
			END

			FETCH FROM @c1 INTO @Guid, @ParentGuid
		END
		CLOSE @c1 DEALLOCATE @c1 

	END
	--Update the ad000.BrGuid default branch which is not handled. 
	UPDATE ad000  
		SET BrGuid = (SELECT br.[GUID] FROM br000 br WHERE br.[Number] = 1)
		WHERE BrGuid = 0x0  AND ((SELECT COUNT (*)FROM br000) > 1)

	-- refresh use security data:
	EXEC [prcConnections_Refresh]
#########################################################
CREATE TRIGGER trg_br000_delete
	ON [br000] FOR DELETE
	NOT FOR REPLICATION

AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@c CURSOR,  
		@TableName [NVARCHAR](128),  
		@SingleBranchFldName [NVARCHAR](128), 
		@SQL [NVARCHAR](2000) 

	DECLARE 
		@C_BRANCH CURSOR,  
		@branchMask [BIGINT],
		@ChildNumber [INT], 
		@BrGUID [UNIQUEIDENTIFIER], 
		@BrParentGUID [UNIQUEIDENTIFIER] 
--------------------------  CHECK  IF DELTETED USED IN CARDS ---------------------------------------------- 
	CREATE TABLE [#deleted] ([guid] [uniqueidentifier]) 
	INSERT INTO [#deleted] SELECT [Guid] FROM [deleted] 

	SET @C_BRANCH = CURSOR FAST_FORWARD FOR SELECT [GUID], POWER(CAST(2 AS BIGINT), [number] - 1) AS [branchMask] FROM [deleted]
	OPEN @C_BRANCH FETCH FROM @C_BRANCH INTO @BrGUID, @branchMask

	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		SET @c = CURSOR FAST_FORWARD FOR SELECT [TableName], [SingleBranchFldName] FROM [brt]
		OPEN @c FETCH FROM @c INTO @TableName, @SingleBranchFldName  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			IF @SingleBranchFldName != ''
			BEGIN 
				SET @SQL = ' 
					if exists(select * from [#deleted] [d] inner join [%0] [x] on [d].[guid] = [x].[%1]) 
						INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
							SELECT 1, 0, ''AmnE0082: Branch already used'', [d].[guid] FROM [#deleted] [d] inner join [%0] [x] on [d].[guid] = [x].[%1] ' 

				EXEC [prcExecuteSql] @SQL, @tableName, @SingleBranchFldName, @BrGUID, @branchMask 
			END 
			FETCH FROM @c INTO @TableName, @SingleBranchFldName 
		END  
		CLOSE @c 
		FETCH FROM @C_BRANCH INTO @BrGUID, @branchMask
	END 
	CLOSE @C_BRANCH
	DEALLOCATE @C_BRANCH
----------------------------- CHECK Number of sons for deleted branches --------------------------------------------- 
	INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])  
		select 1, 0, 'AmnE0093: No. of sons is not zero can''t delete card', [d].[guid] 
		from [Br000] [b] inner join [deleted] [d] on [b].[parentGuid] = [d].[guid] 
	if @@rowcount != 0 
		return 
	-- if deleted branch is the last child for his parent, assign its number to its parent: 
	SET @C = CURSOR FAST_FORWARD FOR SELECT [GUID], [ParentGUID] FROM [deleted] 
	OPEN @C FETCH FROM @C INTO @BrGUID,@BrParentGUID 
	WHILE @@FETCH_STATUS = 0  
	BEGIN 
		-- is this the last child for his parent ? 
		IF NOT EXISTS( SELECT * FROM [Br000] WHERE [ParentGUID] = @BrParentGUID) 
		BEGIN 
			-- get the deleted child number: 
			SET @ChildNumber = (select [number] from [deleted] where [guid] = @brGuid) 
			-- assign the deleted child Number to his parent: 
			UPDATE [Br000] SET [NUMBER] = @ChildNumber WHERE [GUID] = @BrParentGUID 
		END 
		FETCH FROM @C INTO @BrGUID,@BrParentGUID 
	END 
	CLOSE @C
	DEALLOCATE @C
	EXEC [prcBranch_fix] 

#########################################################	
#END