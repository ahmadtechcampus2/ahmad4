#############################################################################
CREATE PROCEDURE repTransAcc
 	@SourceAcc 				AS [UNIQUEIDENTIFIER],
	@TargetAcc 				AS [UNIQUEIDENTIFIER],
	@SourceCust 			AS [UNIQUEIDENTIFIER],
	@TargetCust 			AS [UNIQUEIDENTIFIER],
	@SrcGuid				AS [UNIQUEIDENTIFIER],
	@SourceCost 			AS [UNIQUEIDENTIFIER],
	@TargetCost 			AS [UNIQUEIDENTIFIER],
	@TrnsOnCostCenter		AS [BIT],
	@StartDate 				AS [DATETIME],
	@EndDate 				AS [DATETIME]
AS
	SET NOCOUNT ON
	
	DECLARE
		@UserId AS [UNIQUEIDENTIFIER],
		@RowsCnt AS [INT],
		@SqlStr1 AS [NVARCHAR](4000),
		@NormalEntry AS [INT],
		@SenderReseverSourceGuid [UNIQUEIDENTIFIER],
		@SenderReseverDistGuid [UNIQUEIDENTIFIER],
		@SQL [NVARCHAR](max),	
		@CustomerCount 	[INT]
	
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()
	SET @RowsCnt = 0
	SET @NormalEntry = [dbo].[fnIsNormalEntry]( @SrcGuid)
	
	DECLARE @Replication [BIT],@Log [BIT]
	CREATE TABLE [#Replication]( [isRep] [BIT])
	SET @Replication = 0
	SET @Log = 0
	/*
	IF EXISTS(SELECT * FROM [dbo].[sysproperties] WHERE [name] = 'rpl_role')
		SET @Replication = 1
	*/
	SET @SQL = '
		IF EXISTS( SELECT * FROM [dbo].[fnListExtProp]( ''rpl_role'')) 
			INSERT INTO [#Replication] SELECT 1		
		ELSE 
			INSERT INTO [#Replication] SELECT 0 '
	
	EXEC(@SQL)
	SET @Replication = (SELECT TOP 1 ISNULL( [isRep], 0) FROM [#Replication])
	
	CREATE TABLE #CE ( [GUID] [UNIQUEIDENTIFIER])
	SET @Log = 0
	CREATE TABLE [#Log] ( [GUID] [UNIQUEIDENTIFIER],[Type] [INT]/*0 Entry 1 Bill 2 Pay 3 Check */,[Number] [INT])
	IF EXISTS(SELECT * FROM OP000 WHERE [NAME] ='AmnCfg_UseLogging' AND [Value] = 1)
		SET @Log = 1
	BEGIN TRAN
	EXEC prcDisableTriggers 'ce000'
	EXEC prcDisableTriggers 'en000'
	
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])
	CREATE TABLE [#NotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#t1] ([t] [UNIQUEIDENTIFIER], [s] [UNIQUEIDENTIFIER], [c] [FLOAT], [d] [FLOAT])
	CREATE TABLE [#TrnVouchar]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#TrnStatement]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])
	
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID
	INSERT INTO [#NotesTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID
	
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	
		INSERT INTO [#TrnVouchar]	EXEC [prcGetTransfersTypesList] 	@SrcGuid
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0		
		INSERT INTO [#TrnStatement]
		SELECT
					[IdType],
					[dbo].[fnGetUserBillSec_Browse](@UserID, [IdType])
				FROM
					[dbo].[RepSrcs] AS [r] 
					INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]
				WHERE
					[IdTbl] = @SrcGuid

	SET @CustomerCount = (SELECT COUNT(AccountGUID) FROM cu000 WHERE AccountGUID = @SourceAcc)

	IF @NormalEntry = 1
	BEGIN
		IF (@Replication = 1)
		BEGIN
		INSERT INTO  [#CE]
			SELECT DISTINCT [ParentGuid]
			FROM
				([en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[parentGuid] = [ce].[ceGuid]) -- this will considre branchs
				LEFT JOIN [vwEr] AS [er] ON [en].[ParentGUID] = [er].[erEntryGuid]
			WHERE
				[er].[erParentGuid] IS NULL
				AND ([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[en].[date] BETWEEN @StartDate AND @EndDate
		END
		IF @Log = 1
		BEGIN
			INSERT INTO [#Log] 
				SELECT DISTINCT [ceGuid],0,[ceNumber]
				FROM
				([en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[parentGuid] = [ce].[ceGuid]) -- this will considre branchs
				LEFT JOIN [vwEr] AS [er] ON [en].[ParentGUID] = [er].[erEntryGuid]
			WHERE
				[er].[erParentGuid] IS NULL
				AND ([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[en].[date] BETWEEN @StartDate AND @EndDate
		END
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust  AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END END,
				[CustomerGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN ISNULL([en].[CustomerGUID], 0x0) = @SourceCust  AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0)  THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0)  END END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END,
				[CostGUID] = CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1 THEN  @TargetCost ELSE ISNULL(en.CostGUID, 0x0) END
			FROM
				([en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[parentGuid] = [ce].[ceGuid]) -- this will considre branchs
				LEFT JOIN [vwEr] AS [er] ON [en].[ParentGUID] = [er].[erEntryGuid]
			WHERE
				[er].[erParentGuid] IS NULL 
				AND (en.CustomerGUID = @SourceCust OR [en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc ) 
				AND	[en].[date] BETWEEN @StartDate AND @EndDate
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		
	END
	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303)
	BEGIN
		IF (@Replication = 1)
		BEGIN
			INSERT INTO #CE SELECT DISTINCT [en].[ParentGuid]
				FROM
					([en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[parentGuid] = [ce].[ceGuid]) -- this will considre branchs
					INNER JOIN [vwEr] AS [er] ON [en].[ParentGUID] = [er].[erEntryGuid]
					INNER JOIN [dbo].[HosPFile000] AS [Hos] ON [Hos].[GUID] = [er].[erParentGuid]
				WHERE
					([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
					AND	[en].[date] BETWEEN @StartDate AND @EndDate
		END
				
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END END,
				[CustomerGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END,
				[CostGUID] = CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1 THEN  @TargetCost ELSE ISNULL(en.CostGUID, 0x0) END
			FROM
				([en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[parentGuid] = [ce].[ceGuid]) -- this will considre branchs
				INNER JOIN [vwEr] AS [er] ON [en].[ParentGUID] = [er].[erEntryGuid]
				INNER JOIN [dbo].[HosPFile000] AS [Hos] ON [Hos].[GUID] = [er].[erParentGuid]
			WHERE
				(en.CustomerGUID = @SourceCust OR [en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[en].[date] BETWEEN @StartDate AND @EndDate
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
	
		
	END
	---- Bills
	-- replace the source accounts' customer with the destination accounts' customer
	IF @Log = 1
	BEGIN
		INSERT INTO [#Log] 
			SELECT DISTINCT [buGUID],1,[buNumber]
			FROM 
			[vwBu] as [vbu] 
			INNER JOIN [#BillTbl] AS [bt] ON [vbu].[buType] = [bt].[Type]
		WHERE
			([vbu].[buCustAcc] = @SourceAcc
			OR [vbu].[buMatAcc] = @SourceAcc
			OR [vbu].[buItemsDiscAcc] = @SourceAcc 
			OR [vbu].[buBonusDiscAcc] = @SourceAcc
			OR [vbu].[buFPayAcc] = @SourceAcc
			OR ([vbu].[buCustptr] = @SourceCust AND @SourceCust <> 0X0)
			)
			AND	[vbu].[buDATE] BETWEEN @StartDate AND @EndDate	
	END
	
	UPDATE [bu000] SET 
			[CustGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [bu].[CustGUID] = @SourceCust THEN @TargetCust ELSE [bu].[CustGUID] END ELSE [bu].[CustGUID] END,
			[CustAccGUID] = CASE WHEN [bu].[CustAccGUID] = @SourceAcc THEN @TargetAcc ELSE [bu].[CustAccGUID] END,
			[MatAccGUID] = CASE WHEN [bu].[MatAccGUID] = @SourceAcc THEN @TargetAcc ELSE [bu].[MatAccGUID] END,
			[ItemsDiscAccGUID] = CASE WHEN [bu].[ItemsDiscAccGUID] = @SourceAcc THEN @TargetAcc ELSE [bu].[ItemsDiscAccGUID] END,
			[BonusDiscAccGUID] = CASE WHEN [bu].[BonusDiscAccGUID] = @SourceAcc THEN @TargetAcc ELSE [bu].[BonusDiscAccGUID] END,
			[FPayAccGUID] = CASE WHEN [bu].[FPayAccGUID] = @SourceAcc THEN @TargetAcc ELSE [bu].[FPayAccGUID] END
		FROM
			[bu000] AS [bu] INNER JOIN [vwBu] as [vbu] ON [bu].[GUID] = [vbu].[buGUID] -- this will consider branches
			INNER JOIN [#BillTbl] AS [bt] ON [bu].[TypeGUID] = [bt].[Type]
		WHERE
			([bu].[CustAccGUID] = @SourceAcc
			OR [bu].[MatAccGUID] = @SourceAcc
			OR [bu].[ItemsDiscAccGUID] = @SourceAcc 
			OR [bu].[BonusDiscAccGUID] = @SourceAcc
			OR [bu].[FPayAccGUID] = @SourceAcc
			OR ([bu].[CustGUID] = @SourceCust AND @SourceCust <> 0X0)
			)
			AND @TrnsOnCostCenter = 0
			AND	[bu].[DATE] BETWEEN @StartDate AND @EndDate	
	SET @RowsCnt = @RowsCnt + @@ROWCOUNT
	-- update di000:
	UPDATE [di000] SET
			[CustomerGuid] = ISNULL(CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN ISNULL([di1].[CustomerGUID], 0x0) = @SourceCust AND [di1].[AccountGUID] = @SourceAcc THEN @TargetCust ELSE ISNULL([di1].[CustomerGUID], 0x0) END ELSE CASE WHEN  [di1].[AccountGUID] = @SourceAcc THEN ISNULL([di1].[CustomerGUID], 0x0) END END, 0x0),
			[AccountGUID] = ISNULL(CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [di1].[AccountGUID] = @SourceAcc AND ISNULL([di1].[CustomerGUID], 0x0) = @SourceCust THEN @TargetAcc ELSE [di1].[AccountGUID] END ELSE CASE WHEN [di1].[AccountGUID] = @SourceAcc  THEN @TargetAcc ELSE [di1].[AccountGUID] END END, 0x0),
			[ContraAccGUID]  = ISNULL(CASE WHEN [di1].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [di1].[ContraAccGUID] END, 0x0)
		FROM
			[di000] AS [di1] 
			INNER JOIN [vwExtended_Di] AS [di] ON [di1].[Guid] = [di].[diGuid]
			INNER JOIN [#BillTbl] AS [bt] ON [di].[buTypeGUID] = [bt].[Type]
		WHERE
			([di1].[CustomerGUID] = @SourceCust OR [di1].[AccountGUID] = @SourceAcc   OR [di1].[ContraAccGUID]  = @SourceAcc )
			AND [di].[buTypeGUID] IN (SELECT [Type] FROM [#BillTbl]) AND @TrnsOnCostCenter = 0
			AND	[di].[buDATE] BETWEEN @StartDate AND @EndDate 
	SET @RowsCnt = @RowsCnt + @@ROWCOUNT
	-- update en related to bills:
	-- this will enclose AccountGUID and ContraAccGUID
	IF (@Replication = 1)
	BEGIN
		INSERT INTO #CE
		SELECT DISTINCT [en].[ParentGuid] 
		FROM
			[en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
			INNER JOIN [vwEr_EntriesBills] AS [er] ON [ce].[ceGUID] = [er].[erEntryGUID]
			INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid]= [er].[erBillGuid]
			INNER JOIN [#BillTbl] AS [Sr] ON [bu].[buType] = [Sr].[Type]
		WHERE
			([en].[AccountGUID] = @SourceAcc
			OR [en].[ContraAccGUID] = @SourceAcc)
			AND	[en].[date] BETWEEN @StartDate AND @EndDate	
	
	END
	UPDATE [en000] SET
			[AccountGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[AccountGUID] END END,
			[CustomerGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN ISNULL([en].[CustomerGUID], 0x0) = @SourceCust THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END END,
			[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END
		FROM
			[en000] AS [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
			INNER JOIN [vwEr_EntriesBills] AS [er] ON [ce].[ceGUID] = [er].[erEntryGUID]
			INNER JOIN [vwBu] AS [bu] ON [bu].[buGuid]= [er].[erBillGuid]
			INNER JOIN [#BillTbl] AS [Sr] ON [bu].[buType] = [Sr].[Type]
		WHERE
			([en].[CustomerGUID] = @SourceCust OR [en].[AccountGUID] = @SourceAcc
			OR [en].[ContraAccGUID] = @SourceAcc) AND @TrnsOnCostCenter = 0
			AND	[en].[date] BETWEEN @StartDate AND @EndDate	
	SET @RowsCnt = @RowsCnt + @@ROWCOUNT
	
	
	--- ch:	
	IF EXISTS(SELECT * FROM [#NotesTbl])
	BEGIN
		IF @Log = 1
		BEGIN
			INSERT INTO [#Log] 
				SELECT DISTINCT [GUID],3,[Number]
				FROM 
				[ch000]
			WHERE
					[TypeGUID] IN (SELECT [Type] FROM [#NotesTbl]) 
				AND [DATE] BETWEEN @StartDate AND @EndDate
				AND ([AccountGUID] = @SourceAcc OR 	[Account2GUID] = @SourceAcc)
		END
		UPDATE [ch000] SET
				[AccountGUID] =  CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [AccountGUID] = @SourceAcc  AND ISNULL([CustomerGuid], 0x0) = @SourceCust THEN  @TargetAcc ELSE [AccountGUID] END ELSE CASE WHEN [AccountGUID] = @SourceAcc  THEN @TargetAcc ELSE [AccountGUID] END END ,
				[CustomerGuid] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [AccountGUID] = @SourceAcc AND ISNULL([CustomerGuid], 0x0) = @SourceCust THEN @TargetCust ELSE ISNULL([CustomerGuid], 0x0) END ELSE CASE WHEN [AccountGUID] = @SourceAcc THEN @TargetCust ELSE ISNULL([CustomerGuid], 0x0) END END,
				[Account2GUID] = CASE WHEN [Account2GUID] = @SourceAcc THEN  @TargetAcc ELSE [Account2GUID] END
			WHERE
				 [TypeGUID] IN (SELECT [Type] FROM [#NotesTbl]) 
				AND [DATE] BETWEEN @StartDate AND @EndDate
				AND ([AccountGUID] = @SourceAcc OR 	[Account2GUID] = @SourceAcc) AND @TrnsOnCostCenter = 0
	SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		IF (@Replication = 1)
		BEGIN
			INSERT INTO #CE SELECT DISTINCT [en].[ParentGuid]
				FROM [en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
				INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGuid]
				INNER JOIN [ch000] AS [ch] ON [ch].[Guid] = [er].[ParentGuid]
				INNER JOIN [#NotesTbl] AS [nt] ON [nt].[Type] = [ch].[TypeGUID]
			WHERE
				([en].[AccountGUID] = @SourceAcc
				OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[en].[date] BETWEEN @StartDate AND @EndDate	
		END
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc  THEN @TargetAcc ELSE [en].[AccountGUID] END END,
				[CustomerGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END
			FROM
				[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
				INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGuid]
				INNER JOIN [ch000] AS [ch] ON [ch].[Guid] = [er].[ParentGuid]
				INNER JOIN [#NotesTbl] AS [nt] ON [nt].[Type] = [ch].[TypeGUID]
			WHERE
				([en].[AccountGUID] = @SourceAcc
				OR [en].[ContraAccGUID] = @SourceAcc) 
				AND	[en].[date] BETWEEN @StartDate AND @EndDate	AND @TrnsOnCostCenter = 0
				
		-------------------
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		
	END
	
	--- collected notes:
	
	IF EXISTS(SELECT * FROM [#EntryTbl])
	BEGIN
		IF @Log = 1
		BEGIN
			INSERT INTO [#Log] 
				SELECT DISTINCT py.[GUID],2,py.[Number]
			FROM
				[py000] AS [py] 
				INNER JOIN [#EntryTbl] AS [et] ON [py].[TypeGuid] = [et].[Type]
				INNER JOIN [er000] AS [er] ON [py].[Guid] = [er].[ParentGuid]
				INNER JOIN ce000 AS ce ON [ce].[GUID] = [er].[EntryGUID]
				INNER JOIN en000 AS en ON en.ParentGUID = ce.GUID
			WHERE
				py.[AccountGUID] = @SourceAcc
				AND en.[DATE] BETWEEN @StartDate AND @EndDate
		END
		UPDATE [py000] SET
				[AccountGUID] = @TargetAcc
			FROM
				[py000] AS [py] 
				INNER JOIN [#EntryTbl] AS [et] ON [py].[TypeGuid] = [et].[Type]
				INNER JOIN [er000] AS [er] ON [py].[Guid] = [er].[ParentGuid]
				INNER JOIN ce000 AS ce ON [ce].[GUID] = [er].[EntryGUID]
				INNER JOIN en000 AS en ON en.ParentGUID = ce.GUID
			WHERE
				py.[AccountGUID] = @SourceAcc
				AND en.[DATE] BETWEEN @StartDate AND @EndDate
				
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		IF (@Replication = 1)
		BEGIN
			INSERT INTO #CE SELECT DISTINCT [en].[ParentGuid] 
				FROM
					[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
					INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
					INNER JOIN [py000] AS [py] ON [py].[Guid] = [er].[ParentGuid]
					INNER JOIN [#EntryTbl] AS [et] ON [et].[Type] = [py].[TypeGuid]
				WHERE
					([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
					AND	[en].[date] BETWEEN @StartDate AND @EndDate		
		
			UPDATE [py] SET [Guid] = [py].[Guid] FROM  [py000] AS [PY] INNER JOIN [er000] AS [er] ON [py].[Guid] = [er].[ParentGuid] INNER JOIN [#CE] AS [ce] ON [ce].[GUID] = [er].[EntryGUID]
		END
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END END,
				[CustomerGUID] = CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0)  THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0)  THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END,
				[CostGUID] = CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1 THEN  @TargetCost ELSE ISNULL(en.CostGUID, 0x0) END
			FROM
				[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
				INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
				INNER JOIN [py000] AS [py] ON [py].[Guid] = [er].[ParentGuid]
				INNER JOIN [#EntryTbl] AS [et] ON [et].[Type] = [py].[TypeGuid]
			WHERE
				([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[en].[date] BETWEEN @StartDate AND @EndDate		
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		
		
		
	END
	/*IF EXISTS(SELECT * FROM [#TrnVouchar])
	BEGIN
		SELECT @SenderReseverSourceGuid = [Guid] FROM [dbo].[TrnSenderReceiver000] where [AccountGUID] = @SourceAcc
		SELECT @SenderReseverDistGuid = [Guid] FROM [dbo].[TrnSenderReceiver000] where [AccountGUID] = @TargetAcc
		IF @SenderReseverSourceGuid IS NULL
			SET @SenderReseverSourceGuid = 0X00
		IF @SenderReseverDistGuid IS NULL
			SET @SenderReseverDistGuid = 0X00
		UPDATE [TrnTransferVoucher000] SET
				[SenderGUID] = CASE WHEN [tr].[SenderGUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tr].[SenderGUID] END,
				[Receiver1_GUID] = CASE WHEN [tr].[Receiver1_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tr].[Receiver1_GUID] END,
				[Receiver2_GUID] = CASE WHEN [tr].[Receiver2_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tr].[Receiver2_GUID] END,
				[Receiver3_GUID] = CASE WHEN [tr].[Receiver3_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tr].[Receiver3_GUID] END
			FROM
				[TrnTransferVoucher000] [tr] 
				INNER JOIN [#TrnVouchar] AS [trv] ON [trv].[Type] = [tr].[ParentGUID]
			WHERE
				[tr].[date] BETWEEN @StartDate AND @EndDate	
				AND ( [SenderGUID] = @SenderReseverSourceGuid OR [Receiver1_GUID] = @SenderReseverSourceGuid OR [Receiver2_GUID] = @SenderReseverSourceGuid OR [Receiver3_GUID] = @SenderReseverSourceGuid)
				
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		IF (@Replication = 1)
		BEGIN
			INSERT INTO #CE SELECT DISTINCT [en].[ParentGuid] 
				FROM
					[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
					INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
					INNER JOIN [TrnTransferVoucher000] [tr] ON [tr].[Guid] = [er].[ParentGuid] 
					INNER JOIN [#TrnVouchar] AS [trv] ON [trv].[Type] = [tr].[ParentGUID]
			WHERE
					([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
					AND	[tr].[date] BETWEEN @StartDate AND @EndDate	
		END
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN [en].[AccountGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[AccountGUID] END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END
			FROM
				[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
				INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
				INNER JOIN [TrnTransferVoucher000] [tr] ON [tr].[Guid] = [er].[ParentGuid] 
				INNER JOIN [#TrnVouchar] AS [trv] ON [trv].[Type] = [tr].[ParentGUID]
		WHERE
				([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[tr].[date] BETWEEN @StartDate AND @EndDate	
				
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		
	END*/
	IF EXISTS(SELECT * FROM [#TrnStatement])
	BEGIN
		SELECT @SenderReseverSourceGuid = [Guid] FROM [dbo].[TrnSenderReceiver000] where [AccountGUID] = @SourceAcc
		SELECT @SenderReseverDistGuid = [Guid] FROM [dbo].[TrnSenderReceiver000] where [AccountGUID] = @TargetAcc
		IF @SenderReseverSourceGuid IS NULL
			SET @SenderReseverSourceGuid = 0X00
		IF @SenderReseverDistGuid IS NULL
			SET @SenderReseverDistGuid = 0X00
		UPDATE [TrnStatementItems000] SET
				[SenderGUID] = CASE WHEN [tsi].[SenderGUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tsi].[SenderGUID] END,
				[Receiver1_GUID] = CASE WHEN [tsi].[Receiver1_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tsi].[Receiver1_GUID] END,
				[Receiver2_GUID] = CASE WHEN [tsi].[Receiver2_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tsi].[Receiver2_GUID] END,
				[Receiver3_GUID] = CASE WHEN [tsi].[Receiver2_GUID] = @SenderReseverSourceGuid THEN @SenderReseverDistGuid ELSE [tsi].[Receiver3_GUID] END,
				[AccountGUID] = CASE WHEN [tsi].[AccountGUID] = @SourceAcc THEN @TargetAcc ELSE [tsi].[AccountGUID] END,
				[CreditAcc] = CASE WHEN [tsi].[CreditAcc] = @SourceAcc THEN @TargetAcc ELSE [tsi].[CreditAcc] END
			FROM
				[TrnStatementItems000] [tsi]  INNER JOIN [dbo].[TrnStatement000] AS [ts] ON [tsi].[ParentGUID] = [ts].[Guid]
				INNER JOIN [#TrnStatement] AS [trv] ON [trv].[Type] = [ts].[TypeGUID]
			WHERE
				[ts].[date] BETWEEN @StartDate AND @EndDate	
				AND ( [SenderGUID] = @SenderReseverSourceGuid OR [Receiver1_GUID] = @SenderReseverSourceGuid OR [Receiver2_GUID] = @SenderReseverSourceGuid OR [Receiver3_GUID] = @SenderReseverSourceGuid)
				
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		IF (@Replication = 1)
		BEGIN
			INSERT INTO #CE SELECT DISTINCT [en].[ParentGuid] 
				FROM
					[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
					INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
					INNER JOIN [dbo].[TrnStatement000] AS [ts] ON [er].[ParentGuid] = [ts].[Guid]
					INNER JOIN [#TrnStatement] AS [trv] ON [trv].[Type] = [ts].[TypeGUID]
			WHERE
					([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
					AND	[ts].[date] BETWEEN @StartDate AND @EndDate	
		END
		UPDATE [en000] SET
				[AccountGUID] = CASE WHEN ISNULL(@CustomerCount ,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetAcc ELSE [en].[AccountGUID] END END,
				[CustomerGUID] =  CASE WHEN ISNULL(@CustomerCount,0) <> 0 THEN CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END ELSE CASE WHEN [en].[AccountGUID] = @SourceAcc AND ((ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1) OR @TrnsOnCostCenter = 0) THEN @TargetCust ELSE ISNULL([en].[CustomerGUID], 0x0) END END,
				[ContraAccGUID] = CASE WHEN [en].[ContraAccGUID] = @SourceAcc THEN @TargetAcc ELSE [en].[ContraAccGUID] END,
				[CostGUID] = CASE WHEN [en].[AccountGUID] = @SourceAcc AND ISNULL([en].[CustomerGUID], 0x0) = @SourceCust AND ISNULL(en.CostGUID, 0x0) = @SourceCost AND @TrnsOnCostCenter = 1 THEN  @TargetCost ELSE ISNULL(en.CostGUID, 0x0) END
			FROM
				[en000] [en] INNER JOIN [vwCe] AS [ce] ON [en].[ParentGUID] = [ce].[ceGUID]
				INNER JOIN [er000] AS [er] ON [ce].[ceGUID] = [er].[EntryGUID]
				INNER JOIN [dbo].[TrnStatement000] AS [ts] ON [er].[ParentGuid] = [ts].[Guid]
				INNER JOIN [#TrnStatement] AS [trv] ON [trv].[Type] = [ts].[TypeGUID]
		WHERE
				([en].[AccountGUID] = @SourceAcc OR [en].[ContraAccGUID] = @SourceAcc)
				AND	[ts].[date] BETWEEN @StartDate AND @EndDate	
		
		SET @RowsCnt = @RowsCnt + @@ROWCOUNT
		
	END
	-- update ci000:
	UPDATE [ci000] SET [SonGUID] = @TargetAcc WHERE [SonGUID] = @SourceAcc
	SET @RowsCnt = @RowsCnt + @@ROWCOUNT
	/* update mn000*/
	if EXISTS(select * from mn000)
	begin
		UPDATE mn000 set InAccountGUID=@TargetAcc where InAccountGUID= @SourceAcc
		UPDATE mn000 set OutAccountGUID=@TargetAcc where OutAccountGUID= @SourceAcc
		UPDATE mn000 set InTempAccGUID = @TargetAcc where InTempAccGUID= @SourceAcc
		UPDATE mn000 set OutTempAccGUID =@TargetAcc where OutTempAccGUID= @SourceAcc
	end
	-- return @rowscnt:
	SELECT @RowsCnt AS [Cnt]
	IF (@Replication = 1)
	BEGIN
		UPDATE [ce] SET  [Guid] = [ce].[Guid]  FROM [ce000] AS [ce] INNER JOIN [#ce] AS [c] ON [ce].[Guid] = [c].[Guid] 
	END
	
	EXEC [prcEntry_rePost]
	EXEC prcEnableTriggers 'en000'
	EXEC prcEnableTriggers 'ce000'
	
	SELECT * FROM [#Log] ORDER BY [Type],[Number]
	IF @@ERROR <> 0
		ROLLBACK TRAN
	ELSE
		COMMIT TRAN

##################################################################
#END