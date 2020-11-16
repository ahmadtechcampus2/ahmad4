############################################### 
CREATE PROCEDURE repNegativeOut  
	@MatGUID	[UNIQUEIDENTIFIER] ,  
		@GroupGUID	[UNIQUEIDENTIFIER] ,  
		@StoreGUID	[UNIQUEIDENTIFIER] ,  
		@SrcGUID	[UNIQUEIDENTIFIER] ,  
		@StartDate	[DateTime] ,  
		@EndDate	[DateTime] ,  
		@Total		[INT], -- 0: Details, 1:Summary 
		@ShowStore  [INT] = 0,
		@Sort		[INT] = 0,
		@Lang		[INT] = 0,
		@ShowNote	[INT] = 0,
		@MatCondGuid [UNIQUEIDENTIFIER] =0X00,
		@UseUnit	[INT] = 3
		,@CostGUID   [UNIQUEIDENTIFIER] =0x00
AS  
	SET NOCOUNT ON  
	CREATE TABLE [#Result]	( 
		[buType] [UNIQUEIDENTIFIER] ,
		[buGUID] [UNIQUEIDENTIFIER] ,
		[buNumber] [INT],
		[Security] [INT],
		[UserSecurity] [INT],
		[MatGUID] [UNIQUEIDENTIFIER],
		[MatSecurity] [INT],
		[Qnt] [FLOAT],
		[CurrentQnt] [FLOAT],
		[biStorePtr] [UNIQUEIDENTIFIER],
		[buSortFlag] [INT],
		[buDate] [DATETIME],
		[biGuid] [UNIQUEIDENTIFIER],
		[biNote] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtDefUnitName] [NVARCHAR](256) COLLATE ARABIC_CI_AI
		,[CostGuid] [UNIQUEIDENTIFIER]
		)   
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])  
	CREATE TABLE [#MatTbl](	GUID [UNIQUEIDENTIFIER] , [Security] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [BillType] [UNIQUEIDENTIFIER] , [BillBrowseSec] [INT], [ReadPriceSec] [INT])  
	CREATE TABLE [#StoreTbl](	[GUID] [UNIQUEIDENTIFIER] , [Security] [INT])  
	CREATE TABLE [#CostTbl]([CostGUID] [UNIQUEIDENTIFIER], [Security] SMALLINT)
	-- bi cursor, and cursor's input variables declarations:  
	DECLARE  
		@mtNumber [UNIQUEIDENTIFIER] ,  
		@mtQnt [FLOAT],  
		@c_bi CURSOR,  
		@buType [UNIQUEIDENTIFIER] ,  
		@buGUID [UNIQUEIDENTIFIER] ,  
		@buNumber [INT],  
		@buSecurity [INT],  
		@buDate [DateTime] ,  
		@biMatGUID [UNIQUEIDENTIFIER] ,  
		@mtSecurity [INT],  
		@biQty [FLOAT],  
		@mtDefUnitFact [FLOAT],  
		@biBonusQnt [FLOAT],  
		@buDirection [INT],  
		@buSortFlag [INT],
		@biStoreGUID [UNIQUEIDENTIFIER],
		@biStorePtr [UNIQUEIDENTIFIER],
		@biGuid		[UNIQUEIDENTIFIER],
		@mtDefUnitName [NVARCHAR](255) 
		,@biCostGuid [UNIQUEIDENTIFIER] 
	
	DECLARE @UserGUID [UNIQUEIDENTIFIER]   
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()  
	SET @mtQnt = 0  
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,257 ,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList] @SrcGUID, @UserGUID  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @CostGUID
	IF  ISNULL(@CostGUID,0X00) = 0X0
		INSERT INTO [#CostTbl] VALUES(0X0, 0) 
	SET @c_bi = CURSOR FAST_FORWARD FOR  
			SELECT  
				[buType],  
				[buGUID], 
				[buNumber],  
				[buSecurity],  
				[buDate],  
				[biMatPtr],  
				[mtSecurity],  
				[biQty],  
				CASE @UseUnit 
				WHEN 0 THEN 1
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END
				ELSE [mtDefUnitFact] END,  
				[biBonusQnt],  
				[buDirection],  
				[buSortFlag],
				[biStorePtr],
				[biGuid],
				CASE @UseUnit 
				WHEN 0 THEN [mtUnity]
				WHEN 1 THEN CASE [mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END
				WHEN 2 THEN CASE [mtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END
				ELSE [mtDefUnitName] END
				,CASE [biCostPtr] WHEN 0x00 THEN [buCostPtr] ELSE [biCostPtr] END [CostGuid]				
			FROM  
				[dbo].[vwExtended_bi] as [bi]  
				INNER JOIN [#MatTbl] AS [mt] ON [bi].[biMatPtr] = [mt].[GUID] 
				INNER JOIN [#StoreTbl] AS [st] ON [bi].[biStorePtr] = [st].[GUID] 
				INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = (CASE [bi].[biCostPtr] WHEN 0x00 THEN [bi].[buCostPtr] ELSE [bi].[biCostPtr] END)  
			WHERE  
				[buIsPosted] <> 0  
			ORDER BY  
				[biMatPtr],[biStorePtr], [buDate],[buDirection] desc, [buSortFlag], [buNumber]  
	-- for neg inv in transfer
	OPEN @c_bi FETCH FROM @c_bi INTO  
			@buType, @buGUID, @buNumber, @buSecurity, @buDate, @biMatGUID, @mtSecurity,  
			@biQty, @mtDefUnitFact, @biBonusQnt, @buDirection, @buSortFlag,@biStoreGUID,@biGuid,@mtDefUnitName, @biCostGuid
	-- prepare variables:  
	SET @mtNumber = @biMatGUID  
	SET @biStorePtr = @biStoreGUID
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		IF @mtNumber <> @biMatGUID  OR @biStorePtr <> @biStoreGUID
			SELECT  
				@mtNumber = @biMatGUID, 
				@biStorePtr  = @biStoreGUID,
				@mtQnt = 0  
		SET @mtQnt = @mtQnt + @buDirection * ( @biQty + @biBonusQnt)/CASE @mtDefUnitFact WHEN 0 THEN 1 ELSE  @mtDefUnitFact END
		IF @mtQnt < 0 AND @buDirection = -1 
				AND @buDate BETWEEN @StartDate AND @EndDate  
				AND EXISTS ( SELECT [BillType] FROM [#BillsTypesTbl] WHERE [BillType] = @buType)
				
				INSERT INTO [#Result] VALUES (@buType, @buGUID, @buNumber, @buSecurity, 0 , @biMatGUID, @mtSecurity, @mtQnt,( @biQty + @biBonusQnt)/@mtDefUnitFact,@biStoreGUID,@buSortFlag,@buDate,@biGuid,'',@mtDefUnitName, @biCostGuid)   
		FETCH NEXT FROM @c_bi INTO  
							@buType, @buGUID, @buNumber, @buSecurity, @buDate,  
							@biMatGUID, @mtSecurity, @biQty, @mtDefUnitFact,  
							@biBonusQnt, @buDirection, @buSortFlag,@biStoreGUID,@biGuid,@mtDefUnitName,@biCostGuid 
	END -- @c_bi loop  
	-- free the bi cursor:  
	CLOSE @c_bi  
	DEALLOCATE @c_bi
	
	UPDATE [#Result]  
		SET [UserSecurity] = [b].[BillBrowseSec]  
		FROM [#Result] AS [r] INNER JOIN [#BillsTypesTbl] AS [b] ON [r].[buType] = [b].[BillType] 
	EXEC [prcCheckSecurity] @UserGUID  
	
	IF (@ShowNote = 1)
		UPDATE [r] SET [biNote] = CASE [bi].[biNotes] WHEN '' THEN [bi].[buNotes] ELSE [bi].[biNotes] END FROM [#Result] AS [r] INNER JOIN [vwbubi] AS [bi] ON [r].[biGuid] = [bi].[biGuid]
	IF( @Total <> 0)   
		SELECT [MatGUID] AS [MatGUID], 
		MIN( [Qnt])AS [Qnt],
		[mt].[Code] AS [mtCode], 
		[mt].[Name] AS [mtName], 
		[mt].[LatinName] AS [mtLatinName],
		[mtDefUnitName],
		[r].[biStorePtr] AS [StoreGuid],
		[st].[Code] AS [StoreCode],
		[st].[Name] AS [StoreName],
		[st].[LatinName]  AS [StoreLatinName]  
		FROM         
		[#Result] AS [r] 
		  INNER JOIN [MT000] AS [mt] ON [r].[MatGUID] = [mt].[Guid] 
		  LEFT  JOIN [st000] AS [st] ON [st].[guid] = [r].[biStorePtr]
		GROUP BY 
		[MatGUID],
		[mt].[Code], 
		[mt].[Name],
		[mt].[LatinName],
		[mtDefUnitName],
		[r].[biStorePtr],
		[st].[Name],
		[st].[code],
		[st].[LatinName]  	
	ELSE  
	BEGIN 
		IF @ShowStore = 0  
			SELECT [buType], [billTypes].Abbrev, [billTypes].LatinAbbrev  ,[biNote],[buGUID],[buNumber],[MatGUID],[Qnt],[CurrentQnt],[buDate],[mt].[Code] AS [mtCode], [mt].[Name] AS [mtName], [mt].[LatinName] AS [mtLatinName],[mtDefUnitName],[r].[CostGuid],[co].[Code] + '-' + [co].[Name] AS [CostName],[co].[Code] +'-' + CASE [co].[LatinName] WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END AS [CostLatinName] 
			FROM       [#Result] AS [r] 
			INNER JOIN [MT000] AS [mt] ON [r].[MatGUID] = [mt].[Guid]
			LEFT  JOIN [co000] AS [co] ON [co].[guid] =[r].[CostGuid]
			INNER JOIN [bt000] AS [billTypes] ON [billTypes].GUID = [r].buType
		ELSE 
			SELECT [buType], [billTypes].Abbrev, [billTypes].LatinAbbrev  , [biNote],[buGUID],[buNumber],[MatGUID],[buDate],[Qnt],[CurrentQnt],[st].[Code] + '-' + [st].[Name] AS [stName],[st].[Code] +'-' + CASE [st].[LatinName] WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END   AS [stLatinName],[mt].[Code] AS [mtCode], [mt].[Name] AS [mtName], [mt].[LatinName] AS [mtLatinName],[mtDefUnitName],[r].[CostGuid] 
					,[co].[Code] + '-' + [co].[Name] AS [CostName],[co].[Code] +'-' + CASE [co].[LatinName] WHEN '' THEN [co].[Name] ELSE [co].[LatinName] END AS [CostLatinName] 
			FROM           [#Result] AS [r] 
				INNER JOIN [MT000] AS [mt] ON [r].[MatGUID] = [mt].[Guid] 
				INNER JOIN [st000]  AS [st] ON [st].[Guid] = [r].[biStorePtr] 
				LEFT JOIN [co000] AS [co] ON [co].[guid] =[r].[CostGuid]
				INNER JOIN [bt000] AS [billTypes] ON [billTypes].GUID = [r].buType
	END   
	SELECT * FROM [#SecViol]  
/* 
	prcConnections_add2 'ãÏíÑ' 
	exec  [repNegativeOut] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '187b3802-5a30-4eae-b334-166b349801ad', '1/1/2006', '3/11/2006', 0, 0, 0, 0, 0 
*/ 
##############################
#END