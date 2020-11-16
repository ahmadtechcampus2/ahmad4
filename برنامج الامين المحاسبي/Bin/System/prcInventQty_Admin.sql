#########################################
CREATE PROCEDURE prcInventQty_Admin
	@StartDate 				[DATETIME],
	@EndDate 				[DATETIME],
	@MatGUID 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 				[UNIQUEIDENTIFIER],
	@StoreGUID 				[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 				[INT], -- 0 Store or 1 Service or -1 ALL
	@DetailsStores 			[INT], -- 1 show details 0 no details
	@ShowEmpty 				[INT], --1 Show Empty 0 don't Show Empty
	@SrcTypesguid			[UNIQUEIDENTIFIER],
	@SortType 				[INT] = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store
	@ShowUnLinked 			[INT] = 0,
	--@AccGUID 				UNIQUEIDENTIFIER,-- 0 all acounts or one cust when @ForCustomer not 0 or AccNumber
	--@CustGUID 				UNIQUEIDENTIFIER, -- 0 all custs or group of custs when @ForAccount not 0 or CustNumber
	@ShowGroups 			[INT] = 0, -- if 1 add 3 new  columns for groups
	--@CalcPrices 			INT = 1,
	@UseUnit 				[INT],--,
	@StLevel				[INT] = 0,
	@Lang					[INT] = 0
AS
	SET NOCOUNT ON

	/*
		@ShowGroups INT = 0, -- if 1 add 3 new  columns for groups
	*/
	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	--Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			@MatGUID, @GroupGUID, @MatType
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	@SrcTypesguid
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 			@CostGUID

		
	IF @ShowGroups = 0
	BEGIN -- hide groups
	
		--EXEC prcPreparePricesProc @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @DetailsStores, @ShowEmpty, @SrcTypesguid, @PriceType, @PricePolicy, @SortType, @ShowUnLinked, @ShowGroups, @UseUnit--, @ShowMtFldsFlag
		CREATE TABLE [#t_Qtys]
			(
				[mtNumber] 	[UNIQUEIDENTIFIER],
				[Qnt] 		[FLOAT],
				[Qnt2] 		[FLOAT],
				[Qnt3] 		[FLOAT],
				[StoreGUID]	[UNIQUEIDENTIFIER]
			)
		
			CREATE TABLE [#t_QtysWithEmpty]
			(
				[mtNumber] 	[UNIQUEIDENTIFIER],
				[Qnt] 		[FLOAT],
				[Qnt2] 		[FLOAT],
				[Qnt3] 		[FLOAT],
				[StoreGUID]	[UNIQUEIDENTIFIER],
				[StName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI
			)
		
			CREATE INDEX [Qty_mt_Number] ON [#t_Qtys] ([mtNumber])
			
		
			EXEC [prcGetQnt_Admin] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @DetailsStores, @SrcTypesguid, @ShowUnLinked
		
			--select * from #t_Qtys
		
			--RETURN 8 sec
			IF @ShowEmpty = 0
				INSERT INTO [#t_QtysWithEmpty]
					SELECT
						[q].[mtNumber],
						ISNULL([q].[Qnt], 0),
						ISNULL([q].[Qnt2],0),
						ISNULL([q].[Qnt3],0),
						[q].[StoreGUID],
						ISNULL( CASE @Lang WHEN 0 THEN [st].[Name] ELSE CASE [st].[LatinName] WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END , '')
					FROM 
						[#t_Qtys] AS [q] LEFT JOIN [st000] AS [st] ON  [q].[StoreGUID] = [st].[Guid]
			ELSE
				INSERT INTO [#t_QtysWithEmpty]
					SELECT
						[mt].[mtGUID],
						ISNULL([q].[Qnt], 0),
						ISNULL([q].[Qnt2],0),
						ISNULL([q].[Qnt3],0),
						[q].[StoreGUID],
						ISNULL([stName],'')
						
					FROM
						[vwmt] AS [mt] INNER JOIN [#MatTbl] AS [mtTbl] ON [mt].[mtGUID] = [mtTbl].[MatGUID] 
						LEFT JOIN (SELECT [Qnt] ,[Qnt2],[Qnt3],[StoreGUID],[mtNumber],ISNULL( CASE @Lang WHEN 0 THEN [st].[Name] ELSE CASE [st].[LatinName] WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END , '') AS [StName] FROM [#t_Qtys] AS [q1] 
				LEFT JOIN [st000] AS [st] ON  [q1].[StoreGUID] = [st].[Guid]
				) AS [q] ON [mt].[mtGUID] = [q].[mtNumber]
					--WHERE
					--	( (@MatType = -1) 						OR (mtType = @MatType))
						--AND( (@IsAllMats = 1) OR (mt.mtNumber IN( SELECT MatGUID FROM #MatTbl)))
		CREATE INDEX [QtyWithEmpty_mt_Number] ON [#t_QtysWithEmpty] ([mtNumber])
		DECLARE @c CURSOR
		DECLARE @Guid [UNIQUEIDENTIFIER]
		DECLARE @stName [NVARCHAR](256)
		DECLARE @cnt [INT]
		IF (@StLevel<>0)
			BEGIN
				SET @Cnt = (SELECT MAX([LEVEL]) FROM [fnGetStoresListByLevel](@StoreGUID,0 )) 
				
				SELECT [f].[Guid],[Level],[Name] INTO [#TStore] FROM [fnGetStoresListByLevel](@StoreGUID, @stLevel) AS [f] INNER JOIN [st000] AS [St] ON [st].[GUID] = [f].[Guid]
				WHILE @Cnt != 0
				BEGIN
					UPDATE [#t_QtysWithEmpty]	SET [StoreGUID] = [st].[ParentGuid], [StName] =''
					FROM [#t_QtysWithEmpty] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[StoreGUID]
					
					WHERE [StoreGUID] NOT IN (SELECT [GUID] FROM [#TStore])
					SET @Cnt = @Cnt -1 
				END
				UPDATE [#t_QtysWithEmpty]	SET [StName] = [st].[Name]
					FROM [#t_QtysWithEmpty] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[StoreGuid]
					WHERE [T].[StName] = ''
				SET @c=CURSOR FAST_FORWARD FOR  SELECT [GUID], [Name] FROM [#TStore] WHERE [LEVEL] < @stLevel ORDER BY [LEVEL] DESC
				OPEN @c
				FETCH @c INTO @Guid,@stName
				WHILE @@FETCH_STATUS =0 
				BEGIN
					INSERT INTO  [#t_QtysWithEmpty]
						SELECT [mtNumber], SUM([Qnt]), SUM([Qnt2]), SUM([Qnt3]), @Guid, @stName
						FROM [#t_QtysWithEmpty] AS [r] INNER JOIN [vwSt] [st] ON [st].[stGuid] = [r].[StoreGUID] 
						WHERE [st].[stParent] =@Guid
						GROUP BY [mtNumber]
					FETCH @c INTO @Guid,@stName
				END
				CLOSE @c
				DEALLOCATE @c
				SELECT [mtNumber], SUM([Qnt]) AS [Qnt], SUM([Qnt2]) AS [Qnt2], SUM([Qnt3]) AS [Qnt3], [StoreGUID], [StName] INTO [#t_QtysWithEmpty1] FROM [#t_QtysWithEmpty] GROUP BY [mtNumber], [StoreGUID], [StName]
				DELETE  [#t_QtysWithEmpty]
				INSERT INTO  [#t_QtysWithEmpty] SELECT * FROM  [#t_QtysWithEmpty1] 
			END
			DECLARE @FldStr [NVARCHAR](3000)
			DECLARE @SqlStr [NVARCHAR](3000)
			SET @FldStr = '
				[r].[StoreGUID] AS [StorePtr], [r].[mtNumber], [r].[Qnt] AS [Qnt], --r.mtQty AS Qnt,
				[Qnt2], [Qnt3],/*	[r].[APrice],*/
				[v_mt].[MtUnity], [v_mt].[MtUnit2], [v_mt].[MtUnit3], [v_mt].[mtDefUnitFact], [v_mt].[grName], [v_mt].[mtName], 
				[v_mt].[mtCode], [v_mt].[mtLatinName], [v_mt].[mtUnit2Fact], [v_mt].[mtUnit3Fact], [v_mt].[mtBarCode], [v_mt].[mtSpec], 
				[v_mt].[mtDim], [v_mt].[mtOrigin],	[v_mt].[mtPos],	[v_mt].[mtCompany], [v_mt].[mtColor], [v_mt].[mtProvenance],
				[v_mt].[mtQuality],	[v_mt].[mtModel], [v_mt].[mtBarCode2], [v_mt].[mtBarCode3], [v_mt].[mtType], [v_mt].[mtDefUnitName],
				[v_mt].[MtGroup],[v_mt].[GrCode],'
			
			DECLARE @NullGUID [UNIQUEIDENTIFIER]
			SET @NullGUID = '{00000000-0000-0000-0000-000000000000}'
		
		--	SET @FldStr = @FldStr + CAST(@NullGUID AS NVARCHAR(256))
			SET @FldStr = @FldStr + 'CAST(0x0 AS [UNIQUEIDENTIFIER]) AS [GroupParent],
				''m'' AS [RecType],
				0 AS [Level] '
		
			SET @SqlStr =
				' SELECT ' + @FldStr
			--IF @DetailsStores = 1
				SET @SqlStr = @SqlStr + ' ,[StName]'
				
			IF (@StLevel > 1) AND @DetailsStores = 1 
				SET @SqlStr = @SqlStr + ',ISNULL([St].[Level], 0) AS [STLevel] '
			SET @SqlStr = @SqlStr + ' FROM
				[#t_QtysWithEmpty] AS [r] INNER JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] '
			IF (@StLevel > 1) AND @DetailsStores = 1
				SET @SqlStr = @SqlStr + 'INNER JOIN [fnGetStoresListTree] (' + '''' +  CONVERT( [NVARCHAR](2000), @StoreGUID)+ ''',' + CAST( @SortType AS NVARCHAR)+' ) AS [ST] ON [ST].[Guid] = [r].[StoreGuid] INNER JOIN [fnGetStoresListTree] ( 0X0,1) AS [ST1] ON [ST1].[Guid] = [ST].[GUID] '
			SET @SqlStr = @SqlStr + 'ORDER BY '
			
				
			--select * from vwmtgr
			IF @SortType = 3 AND @DetailsStores = 1 AND @StLevel <= 1
				SET @SqlStr = @SqlStr + ' [StName]'
			ELSE IF @SortType = 3 AND @DetailsStores = 1 AND @StLevel > 1
				SET @SqlStr = @SqlStr + ' [St1].[Path]'  
			ELSE IF @SortType = 2 
				SET @SqlStr = @SqlStr + ' [mtName]' 
			ELSE IF @SortType = 1 
				SET @SqlStr = @SqlStr + ' [mtCode]' 
			ELSE IF  @SortType = 0 -- By Mat Input 
				SET @SqlStr = @SqlStr + ' [v_mt].[mtNumber]' 
			ELSE IF  @SortType = 4 -- By Mat Latin Name 
				SET @SqlStr = @SqlStr + ' [v_mt].[mtLatinName]' 
			ELSE IF  @SortType = 5 -- By Mat Type 
				SET @SqlStr = @SqlStr + ' [v_mt].[mtType]'
			ELSE IF  @SortType = 6 -- By Mat Specification  
				SET @SqlStr = @SqlStr + ' [v_mt].[mtSpec]'
			ELSE IF  @SortType = 7 -- By Mat Color 
				SET @SqlStr = @SqlStr + ' [v_mt].[mtColor]'
			ELSE IF  @SortType = 8 -- By Mat Orign
				SET @SqlStr = @SqlStr + ' [v_mt].[mtOrigin]'
			ELSE IF  @SortType = 9 -- By Mat Magerment
				SET @SqlStr = @SqlStr + ' [v_mt].[mtDim]'
			ELSE IF @SortType = 10-- By Mat COMPANY
				SET @SqlStr = @SqlStr + ' [v_mt].[mtCompany]'
			ELSE  -- By Mat BARCOD
				SET @SqlStr = @SqlStr + ' [v_mt].[mtBarCode]'
		
			IF @SortType <> 3 AND @DetailsStores = 1 AND @StLevel > 1
				SET @SqlStr = @SqlStr + ' ,[St1].[Path]' 
			--print @SqlStr
			
			EXECUTE ( @SqlStr)
	END
	
	SELECT * FROM [#SecViol]
/*

PRCCONNECTIONS_ADD2 '„œÌ—'
EXEC prcCallPricesProcs2 '1/1/2001', '1/1/2005', 0x0, 0x0, 0x0, 0x0, 0, 'a2ea85dd-3dea-487a-b9f2-cc1918d88577', 1.000000, 1, 0, 0x0, 128, 120, 0, 0, 0x0, 0x0, 0, 0, 3

*/

#########################################
#END