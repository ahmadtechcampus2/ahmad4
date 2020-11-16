################################################################################
CREATE PROCEDURE prcPOSSD_rep_Inventory
	@StartDate 				[DATETIME], 
	@EndDate 				[DATETIME], 
	@MatGUID 				[UNIQUEIDENTIFIER] = 0x00, -- 0 All Mat or MatNumber 
	@GroupGUID 				[UNIQUEIDENTIFIER] = 0x00, 
	@StoreGUID 				[UNIQUEIDENTIFIER] = 0x00, -- 0 all stores so don't check store or list of stores 
	@StLevel				[INT] = 0, 
	@GroupLevel				[INT] = 0,
	@ShowEmpty 				[INT] = 0, --1 Show Empty 0 don't Show Empty 
	@ShowBalancedMat		[BIT] = 1, 
	@MatCondGuid			[UNIQUEIDENTIFIER] = 0x00,
	@ShowGroups 			[INT] = 0, -- if 1 add 3 new  columns for groups 
	@DetailsStores 			[INT] = 0, -- 1 show details 0 no details 
	@UseUnit 				[INT]
AS
/*******************************************************************************************************
	Company : Syriansoft
	SP : PRC_POSSD_RPT_MATSTOCKBALANCE
	Purpose: Show the balance of materials including the POS transactions (closed and open)
	How to Call: 
	EXEC PRC_POSSD_RPT_MATSTOCKBALANCE '2018-01-01','2018-06-10', 0x00,0x00,0x00,'0','0','0','1',0x00,'0','0'
	DECLARE @StartDate 				[DATETIME] = '2018-01-01';
	DECLARE @EndDate 				[DATETIME] = '2018-06-10';
	DECLARE @MatGUID 				[UNIQUEIDENTIFIER] = 0x00; -- 0 All Mat or MatNumber 
	DECLARE @GroupGUID 				[UNIQUEIDENTIFIER] = 0x00; 
	DECLARE @StoreGUID 				[UNIQUEIDENTIFIER] = '543C9031-1E6A-453E-8511-F86EEC605712'; -- 0 all stores so don't check store or list of stores 
	DECLARE @StLevel				[INT] = 0; 
	DECLARE @GroupLevel				[INT] = 0;
	DECLARE @ShowEmpty 				[INT] = 1; --1 Show Empty 0 don't Show Empty 
	DECLARE @ShowBalancedMat		[BIT] = 1; 
	DECLARE @MatCondGuid			[UNIQUEIDENTIFIER] = 0x00;
	DECLARE @ShowGroups 			[INT] = 1; -- if 1 add 3 new  columns for groups 
	DECLARE @DetailsStores 			[INT] = 1;	
	DECLARE @UseUnit 				[INT] = 1;	
	EXEC PRC_POSSD_RPT_INVENTORY
	@StartDate, 
	@EndDate, 
	@MatGUID, -- 0 All Mat or MatNumber 
	@GroupGUID, 
	@StoreGUID, -- 0 all stores so don't check store or list of stores 
	@StLevel, 
	@GroupLevel,
	@ShowEmpty, --1 Show Empty 0 don't Show Empty 
	@ShowBalancedMat, 
	@MatCondGuid,
	@ShowGroups , -- if 1 add 3 new  columns for groups 
	@DetailsStores,
	@UseUnit
	Create By: Hanadi Salka													Created On: 04 June 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SET NOCOUNT ON  
	-- ************************************************************************************************
	-- DECLARE LOCAL VARIABLES
	DECLARE @MatType	INT			= -1;
	DECLARE @Zero		FLOAT		=  dbo.fnGetZeroValueQTY() ;
	DECLARE @Level		INT 
	-- ************************************************************************************************
	-- DECLARE TEMP TABLES
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#GR]([Guid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#SResult]  
	(  
		[biMatPtr] 			[UNIQUEIDENTIFIER], -- PRIMARY KEY ,  
		[biQty]  			[FLOAT],  
		[biQty2]			[FLOAT],  
		[biQty3]			[FLOAT],  
		[biStorePtr]		[UNIQUEIDENTIFIER],  
		[Security]			[INT],  
		[UserSecurity] 		[INT],  
		[MtSecurity]		[INT],  
		[biClassPtr]		[NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[APrice]			[FLOAT],  
		[StSecurity]		[INT] , 
		[bMove]				[TINYINT],
		[SN]				[NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[ExpireDate]		[DATETIME] , 
		[MtVAT]				[FLOAT] 
	) 
	CREATE TABLE [#R]  
	(  
		[StoreGUID]		[UNIQUEIDENTIFIER],  
		[mtNumber]		[UNIQUEIDENTIFIER], -- PRIMARY KEY,  
		[mtQty]			[FLOAT],  
		[Qnt2]			[FLOAT],  
		[Qnt3]			[FLOAT],  
		[APrice]		[FLOAT],  
		[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[StLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[stLevel]		[INT],  
		[ClassPtr]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[id]			[INT]	DEFAULT 0,  
		[mtUnitFact]	[FLOAT] DEFAULT 1,  
		[MtGroup]		[UNIQUEIDENTIFIER],  
		[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
		[grLevel] 		[INT],  
		[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  		 
		[Move]		INT,
		[SERIALNUMBER] [NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[ExpireDate]	[DATETIME], 
		[MtVAT]				[FLOAT]  
		  
	)  
	CREATE NONCLUSTERED INDEX INX_TEMP_R ON #R ([StoreGUID]);
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, @MatType,@MatCondGuid  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#GR] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)  
	INSERT INTO [#SResult]   
				(  
					[biMatPtr],  
					[biQty],  
					[biQty2],  
					[biQty3],  
					[biStorePtr],  
					[Security],  					 
					[MtSecurity], 					
					[StSecurity], 
					[bMove],
					[SN],  
					[ExpireDate], 
					[MtVAT]	
				)
				SELECT   
					[r].[biMatPtr],   
					SUM(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]),   
					SUM([r].[biQty2]* [r].[buDirection]),   
					SUM([r].[biQty3]* [r].[buDirection]),   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   					 
					[mtTbl].[MtSecurity], 
					[st].[Security],
					1,
					'',  
					[r].[biExpireDate] , 
					[mt].[mtVat]
				FROM   
					[vwbubi] AS [r]  					
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]   
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]   
					
				WHERE   
					[budate] BETWEEN @StartDate AND @EndDate					
					AND [buIsPosted] > 0   					
				GROUP BY   
					[r].[biMatPtr],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   					
					[mtTbl].[MtSecurity],   					 
					[st].[Security],
					[r].[biExpireDate] ,
					[mt].[mtVat]
			UNION 
			SELECT   
					[r].[MatGUID],   
					SUM(([r].[BaseQty] + [r].[TxPresentQty])* [r].[BuDirection]),   
					0,
					0,    
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   					 
					[mtTbl].[MtSecurity], 
					[st].[Security],
					1,
					'',  
					[r].[biExpireDate] , 
					[mt].[mtVat]
				FROM   
					[vwPOSSDTicketItems] AS [r]  					
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[MatGUID] = [mtTbl].[MatGUID]  
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]   
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]   
					
				WHERE   
					[OpenDate] BETWEEN @StartDate AND @EndDate	
					AND R.BuType NOT IN (4,5)
					AND R.TicketStatus  IN (0,1)								
					AND ShiftCloseDate IS NULL  	
								
				GROUP BY   
					[r].[MatGUID],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   					
					[mtTbl].[MtSecurity],   					 
					[st].[Security],
					[r].[biExpireDate] ,
					[mt].[mtVat]
	IF (@ShowEmpty = 1 )
		INSERT INTO [#SResult]  
			SELECT  
				[mtTbl].[MatGUID],
				0,
				0,
				0,
				0X00,  
				0,
				0,
				[mtTbl].[MtSecurity],
				'',
				0,
				0,
				0,
				'', 
				'1/1/1980',
				0
			FROM  
				[#MatTbl] AS [mtTbl] WHERE [mtTbl].[MatGUID] NOT IN (SELECT [biMatPtr] FROM [#SResult])  
	IF    @ShowBalancedMat = 0 
		DELETE  [#SResult] WHERE ABS([biQty]) < @Zero AND [bMove] = 1 
	IF( @ShowGroups = 0)      
		ALTER TABLE       
			[#R]      
		DROP COLUMN   
			[mtName],[mtCode],[mtLatinName]    
	 
		INSERT INTO [#R]
		 ([StoreGUID],
		  [mtNumber],
		  [mtQty],
		  [Qnt2],
		  [Qnt3],
		  [APrice],
		  [StCode],
		  [StName],
		  [StLatinName],
		  [stLevel],
		  [ClassPtr],
		  [id],
		  [Move],
		  [SERIALNUMBER],
		  [ExpireDate],
		  [MtVAT])  
			SELECT  
				[biStorePtr], 
				[biMatPtr], 
				SUM([biQty]), 
				SUM([biQty2]), 
				SUM([biQty3]), 
				ISNULL([APrice],0), 
				ISNULL([stCode],''), 
				ISNULL([stName],''), 
				ISNULL([stLatinName],''), 
				0, 
				[biClassPtr], 
				'',   
				MAX([bMove]),
				[SN],
				[ExpireDate] , 
				r.[MtVAT] 
			FROM  
				[#SResult] AS [r]  
				LEFT JOIN (SELECT  
								[Guid], 
								[Code] AS [stCode],  
								[Name] as [stName],
								[LatinName] as [stLatinName]
							FROM [st000] 
						   ) AS [st] ON [st].[Guid] = [biStorePtr]  
			GROUP BY  
				[biStorePtr],  
				[biMatPtr],  
				[APrice],  
				ISNULL([stCode],''),  
				ISNULL([stName],''),
				ISNULL([stLatinName],''),  
				[SN],
				[biClassPtr] ,			
				[ExpireDate] , 
				r.[MtVAT] 		
		IF @ShowBalancedMat = 0 
			DELETE [#R] WHERE ABS([mtQty])< @Zero AND [Move] > 0 
	-- SELECT * FROM [#R];
	
	IF (@StLevel > 0)  
	BEGIN  
		CREATE TABLE [#R2]([StoreGUID] [UNIQUEIDENTIFIER], [mtNumber] [UNIQUEIDENTIFIER],[mtQty] FLOAT,[Qnt2] FLOAT, [Qnt3] FLOAT,
							[APrice] FLOAT, [stCode] NVARCHAR(256), [StName] NVARCHAR(256), [stLevel] INT ,[ClassPtr] NVARCHAR(256), [id] INT, [MtVAT] FLOAT)
		CREATE TABLE [#TStore]  
		(  
			[Id]	[INT] IDENTITY(1,1),  
			[Guid]	[UNIQUEIDENTIFIER],  
			[Level] [INT],  
			[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[StLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI
		)  
		INSERT INTO [#TStore]([Guid], [Level],[StCode],[StName], [StLatinName])  
		SELECT 
		[f].[Guid], 
		[Level] + 1 ,
		[Code] , 
		[Name] ,
		[LatinName]
		FROM [fnGetStoresListTree](@StoreGUID, 0) AS [f] INNER JOIN [st000] AS [st] ON [st].[GUID] = [f].[Guid] ORDER BY [Path]  
		SET @Level = (SELECT MAX([LEVEL]) FROM [#TStore])   
		UPDATE [r] SET [stLevel] = [Level],[Id] = [st].[Id] FROM [#R] AS [r] INNER JOIN [#TStore] AS [st] ON [StoreGUID] = [Guid]  
		WHILE (@Level > 1)  
		BEGIN  
			INSERT INTO [#R] ([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT])	    
				SELECT [t].[Guid],[mtNumber],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),ISNULL([APrice],0),[t].[stCode],[t].[StName],[t].[Level],[ClassPtr],[t].[id],R.[MtVAT]    
			FROM  [#R] AS [r] INNER JOIN [st000] AS [st] ON [st].[Guid] = [r].[StoreGUID] INNER JOIN [#TStore] AS [T] ON [t].[Guid] = [st].[ParentGuid]  
			WHERE [r].[stLevel] = @Level  
			GROUP BY   
				[t].[Guid],[mtNumber],ISNULL([APrice],0),[t].[stCode],[t].[StName],[t].[Level],[ClassPtr],[t].[id],R.[MtVAT]  
			IF (@StLevel = @Level)  
				DELETE [#R] WHERE [stLevel] > @StLevel  
			SET @Level = @Level - 1 			  
		END  
		IF (@StLevel = 1)  
			DELETE [#R] WHERE [stLevel] > @StLevel  
		INSERT INTO [#R2] SELECT [StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT] FROM [#R]    
		TRUNCATE TABLE [#R]  
		INSERT INTO #R  ([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT])	    
			 SELECT [StoreGUID],[mtNumber],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT]  FROM [#R2]    
			 GROUP BY [StoreGUID],[mtNumber],[APrice],[StName],[stLevel],[ClassPtr],[id],[stCode],[MtVAT] 
	END
		-- Show Groups  
	IF @ShowGroups > 0  
	BEGIN  
		CREATE TABLE [#grp]([Guid] [UNIQUEIDENTIFIER], [Level] INT, [grName] NVARCHAR(256), [grLatinName] NVARCHAR(256), [grCode] NVARCHAR(256), [ParentGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#grp] SELECT [f].[Guid],[f].[Level],  [Name]AS [grName], [LatinName] AS [grLatinName],[Code] AS [grCode],[ParentGuid] FROM [dbo].[fnGetGroupsListByLevel](@GroupGUID,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]  
		SELECT @Level = MAX([Level]) FROM [#grp]  		
		UPDATE [r]  
			SET   
			[MtGroup] = [GroupGuid],  
			[RecType] = 'm',  
			[grLevel] = [Level],  
			[mtName] = [Name],  
			[mtCode] = [Code],  
			[mtLatinName] = [LatinName],  
			[mtUnitFact] = CASE @UseUnit WHEN 0 THEN 1  
					WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
					WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
					ELSE  
						CASE [DefUnit]  
							WHEN 3 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
							-- WHEN 1 THEN 1  
							WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
							-- ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
							ELSE 1
						END  
					END   
					  
					 
		FROM [#R] AS [r]   
		INNER JOIN [mt000] AS [mt] ON [mtNumber] = [mt].[Guid]   
		INNER JOIN [#grp] AS [gr] ON  [gr].[Guid] = [GroupGuid]  
		INSERT INTO [#R]
		([StoreGUID],
		[mtNumber],
		[mtQty],
		[Qnt2],
		[Qnt3],
		[APrice],
		[StName],
		[stLevel],
		[ClassPtr],
		[id],
		[MtGroup],
		[RecType],
		[grLevel],
		[mtName],
		[mtCode],
		[mtLatinName])  
		SELECT 
		 0x00,
		 [gr].[Guid],
		 SUM([mtQty]/[mtUnitFact]),
		 SUM([Qnt2]),
		 SUM([Qnt3]),
		 SUM([APrice] *[mtQty]),
		 '',
		 [stLevel],
		 '',
		 [id],
		 [gr].[ParentGuid],
		 'g',
		 [gr].[Level],
		 [grName],
		 [grCode],
		 [grLatinName]   
		FROM [#R] AS [r] INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
		WHERE [stLevel] < = 1  
		GROUP BY [gr].[Guid],[stLevel],[id],[gr].[ParentGuid],[gr].[Level],[grName],[grCode],[grLatinName]   
		WHILE (@Level > 1)  
		BEGIN  
			INSERT INTO [#R]
			([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[StName],[stLevel],[ClassPtr],[id],[MtGroup],[RecType],[grLevel],[mtName],[mtCode],[mtLatinName],r.[MtVAT])   
			SELECT 0x00,[gr].[Guid],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),SUM([APrice]),'',[stLevel],'',[id],[gr].[ParentGuid],'g',[gr].[Level],[grName],[grCode],[grLatinName],r.[MtVAT]      
			FROM [#R] AS [r] INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
			WHERE [r].[grLevel] = @Level AND [RecType] = 'g'   
			GROUP BY[gr].[Guid],[stLevel],[id],[gr].[ParentGuid],[gr].[Level],[grName],[grCode],[grLatinName],r.[MtVAT]   
			SET @Level = @Level - 1  
		END  
		CREATE TABLE [#MainRes3]  
		(  
			[StoreGUID]		[UNIQUEIDENTIFIER],  
			[mtNumber]		[UNIQUEIDENTIFIER],  
			[mtQty]			[FLOAT],  
			[Qnt2]			[FLOAT],  
			[Qnt3]			[FLOAT],  
			[APrice]		[FLOAT],  
			[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[stLevel]		[INT],  
			[ClassPtr]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[id]			[INT]	DEFAULT 0,  
			[MtGroup]		[UNIQUEIDENTIFIER],  
			[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
			[grLevel] 		[INT],  
			[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtUnitFact]	[FLOAT],
			[SERIALNUMBER] [NVARCHAR](255) COLLATE Arabic_CI_AI , 
			[ExpireDate]		[DATETIME] , 
			[MtVAT]			[FLOAT] ,
			[Path]			[NVARCHAR](MAX),
			[MaterialGUID]  [UNIQUEIDENTIFIER],
			[Move]		INT
		) 
		INSERT INTO [#MainRes3]  
			SELECT 
				r.[StoreGUID],
				r.[mtNumber],
				SUM(r.[mtQty]) AS [mtQty],
				SUM(r.[Qnt2]) AS [Qnt2],
				SUM(r.[Qnt3]) AS [Qnt3],
				SUM(r.[APrice]) [APrice],
				r.[StCode],
				r.[StName],
				0,
				r.[ClassPtr],
				0,
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT],
				f.[Path],
				r.[mtNumber],
				r.[move]
			FROM 
				[#r] as r LEFT JOIN [dbo].[fnGetGroupsOfGroupSorted](0x0, 0) as f ON [r].[mtNumber] = f.[GUID]
			WHERE 
				r.[RecType] = 'g' 
			GROUP BY  
				r.[StoreGUID],
				r.[mtNumber],
				r.[StCode],
				r.[StName],
				r.[ClassPtr],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT]	,
				f.[Path],
				r.[mtNumber],
				r.[move]
			UNION ALL  
			SELECT 
				r.[StoreGUID],
				r.[mtNumber],
				SUM(r.[mtQty]),
				SUM(r.[Qnt2]),
				SUM(r.[Qnt3]),
				SUM(r.[APrice]),
				r.[StCode],
				r.[StName],
				r.[stLevel],
				r.[ClassPtr],
				0,
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT]	,
				'Material',
				r.[mtNumber],
				r.[move]
			FROM 
				[#r] as r 
			WHERE 
				r.[RecType] = 'm' 
			GROUP BY  
				r.[StoreGUID],
				r.[mtNumber],
				r.[StCode],
				r.[StName],
				r.[stLevel],
				r.[ClassPtr],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT] 
				,r.[mtNumber],
				r.[move]
	END  
	IF (@ShowGroups = 2)  
		DELETE [#MainRes3] WHERE [RecType] = 'm';
	DECLARE @FldStr [NVARCHAR](3000)  
	SET @FldStr = ''  
	DECLARE @SqlStr [NVARCHAR](MAX)  
	DECLARE @Str [NVARCHAR](MAX)  
	SET @Str = '  
		[r].[StoreGUID] AS [StorePtr], [r].[mtNumber], [r].[mtQty] AS [Qnt],   
		[Qnt2], [Qnt3],	[r].[APrice],  
		[v_mt].[mtUnity], [v_mt].[MtUnit2], [v_mt].[MtUnit3], [v_mt].[mtDefUnitFact], ISNULL([v_mt].[grName],' + '''' + '''' +') AS [grName], ISNULL([v_mt].[grCode],' + '''' + '''' +') AS [grCode],[r].[MtVAT] AS MtVAT, '    
	IF @SHOWGROUPS > 0 
	BEGIN 
		SET @Str = @Str + ' [mtUnitFact],' 
	END 
	ELSE 
	BEGIN 
		IF @UseUnit = 0  
			SET @Str = @Str + 'CASE [mtUnitFact] WHEN 0 THEN 1 ELSE [mtUnitFact] END AS [mtUnitFact],' 		 
		ELSE IF @UseUnit = 1   
			SET @Str = @Str + 'CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS [mtUnitFact],'  
		ELSE IF @UseUnit = 2   
			SET @Str = @Str + 'CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS [mtUnitFact],'  
		ELSE   
			SET @Str = @Str + ' [mtDefUnitFact] AS [mtUnitFact],'  
	END 
	 
	DECLARE @Prefix [NVARCHAR](10)  
	SET @Prefix = ' v_mt.'  
	  
	SELECT @FldStr = ''--[dbo].[fnGetMatFldsStr]( @Prefix, @ShowMtFldsFlag/*, @CheckRecType*/)  
	  
	SET @Str = @Str + @FldStr  
	SET @Str = @Str + ' ISNULL([v_mt].[mtUnit2Fact], 0 ) as mtUnit2Fact, ISNULL([v_mt].[mtUnit3Fact], 0) as mtUnit3Fact, ISNULL([v_mt].[mtDefUnitName],'+''''+''''+') AS [mtDefUnitName],'  
	  
	IF @ShowGroups > 0  
		SET @Str = @Str + ' [r].[mtName] AS MtName, [r].[mtCode] AS MtCode, [r].[mtLatinName], [r].[MtGroup], '  
	else	  
		SET @Str = @Str + ' [v_mt].[mtName] AS MtName, [v_mt].[mtCode] AS MtCode, [v_mt].[mtLatinName], [v_mt].[MtGroup], '  
	  
	--------------------------  
	SET @Str = @Str + 'CAST(0x0 AS [UNIQUEIDENTIFIER]) AS [GroupParent],'  
	IF @ShowGroups > 0  
	BEGIN  
		SET @Str = @Str + ' [RecType], '  
		SET @Str = @Str + '	[r].[grLevel]   '  
	END  
	ELSE  
	BEGIN  
		SET @Str = @Str + ' ''m'' AS [RecType], '  
		SET @Str = @Str + '	0 AS [grLevel] '  
	END  
	  
	--IF (@ShowGroups = 2)  
	--	SET @Str = @Str + ',[GroupParentPtr]  '  
	IF (@StLevel > 1) AND @DetailsStores = 1   
		SET @Str = @Str + ',ISNULL([StLevel], 0) AS [STLevel] '  
	ELSE 
		SET @Str = @Str + ',0 AS [STLevel] '  
	
	IF(@ShowGroups > 0)
	BEGIN
		  CREATE TABLE #groups(groupPath NVARCHAR(max), groupGuid [UNIQUEIDENTIFIER]) 
		  INSERT INTO #groups SELECT [path] ,mtNumber FROM [#MainRes3] WHERE RecType = 'g'
		DECLARE @Id [UNIQUEIDENTIFIER]
		DECLARE @path NVARCHAR(max)
		WHILE (SELECT Count(*) FROM #groups) > 0
		BEGIN
			SELECT TOP 1 @Id = groupGuid, @path = groupPath FROM #groups	
				
			UPDATE [#MainRes3]
			SET [path] = @path + 'mat'
			WHERE MtGroup=@Id and RecType = 'm';
			DELETE #groups WHERE groupGuid = @Id
		END
	END
	  
	--==================================================================
	IF(@ShowGroups > 0 )
	BEGIN
		  UPDATE [#MainRes3]
		  SET [MaterialGUID] = NEWID()
		  WHERE [RecType]= 'm';
	END  
	--==================================================================
	IF(@GroupLevel > 0)
	BEGIN
		CREATE TABLE #groupsList([Guid] [UNIQUEIDENTIFIER], ParentGuid [UNIQUEIDENTIFIER], Sec INT, Lev INT) 
		INSERT INTO #groupsList EXEC prcGetGroupParnetList 0x0, @GroupLevel
		DECLARE @ChildGuid  [UNIQUEIDENTIFIER]
		DECLARE @ParentGUID [UNIQUEIDENTIFIER]
		WHILE (SELECT Count(*) FROM #groupsList) > 0
		BEGIN
			SELECT TOP 1 @ChildGuid = [Guid], @ParentGUID = ParentGuid FROM #groupsList		
			UPDATE [#MainRes3]
			SET MtGroup = @ParentGUID
			WHERE MtGroup = @ChildGuid
			DELETE #groupsList WHERE [Guid] = @ChildGuid
		END
		DELETE [#MainRes3]
		WHERE grLevel > @GroupLevel
		AND RecType = 'g'
	END
	
	CREATE TABLE #FinalResult(
		[move] INT,
		[StorePtr] UNIQUEIDENTIFIER, 
		[mtNumber] UNIQUEIDENTIFIER, 
		[Qnt] FLOAT,   
		[Qnt2] FLOAT, 
		[Qnt3] FLOAT,	
		[APrice] FLOAT,  
		[mtUnity] NVARCHAR(250), 
		[MtUnit2] NVARCHAR(250), 
		[MtUnit3] NVARCHAR(250), 
		[mtDefUnitFact] FLOAT, 
		[grName] NVARCHAR(250), 
		[grCode] NVARCHAR(250),
		MtVAT FLOAT,
		[mtUnitFact] FLOAT, 
		mtUnit2Fact FLOAT, 
		mtUnit3Fact FLOAT, 
		[mtDefUnitName] NVARCHAR(250),  
		MtName NVARCHAR(250), 
		MtCode NVARCHAR(250), 
		[mtLatinName] NVARCHAR(250), 
		[MtGroup] UNIQUEIDENTIFIER,
		[GroupParent] UNIQUEIDENTIFIER,
		[RecType] NVARCHAR(10),
		[grLevel] INT,
		[STLevel] INT,
		[Quantity1] FLOAT,
		QuantityName1 NVARCHAR(250),
		[Quantity2] FLOAT,
		QuantityName2 NVARCHAR(250),
		[Quantity3] FLOAT,
		QuantityName3 NVARCHAR(250),
		UnitName NVARCHAR(250),
		[Price] FLOAT,
		[AVal] FLOAT,
		[path] NVARCHAR(250),
		MaterialGUID UNIQUEIDENTIFIER,
		[StName] NVARCHAR(250),
		[StCode] NVARCHAR(250),
		[ClassPtr] NVARCHAR(250),
		[SERIALNUMBER] NVARCHAR(250),
		[ExpireDate] DATE,
		[Qty] FLOAT, 
		[Qty2] FLOAT,
		[Qty3] FLOAT,
		NotMatchedQty BIT
	)
	--==================================================================
	SET @SqlStr =  '
		INSERT INTO #FinalResult ([move] ,[StorePtr] , [mtNumber] , [Qnt] , [Qnt2] , [Qnt3] ,[APrice] ,  [mtUnity], [MtUnit2] , [MtUnit3] , [mtDefUnitFact] , [grName] , [grCode] ,	[MtVAT] ,	[mtUnitFact] , 	[mtUnit2Fact] , [mtUnit3Fact] , [mtDefUnitName] ,  [MtName] ,[MtCode] , [mtLatinName] , [MtGroup] ,	[GroupParent] ,	[RecType] ,	[grLevel] ,	[STLevel] ,	[Quantity1] ,[QuantityName1] ,[Quantity2] ,[QuantityName2] ,[Quantity3] ,[QuantityName3] ,[UnitName] ,	[Price] ,	[AVal] ,[path] , [MaterialGUID] ,	[StName] ,	[StCode] ,	[Qty] ,	[Qty2] ,[Qty3] ,NotMatchedQty )  
		SELECT ISNULL(r.[move], -1) AS move, ' + @Str  
	
	SET @SqlStr = @SqlStr + 
			', 0 AS [Quantity1], '''' AS QuantityName1, 0 AS Quantity2, '''' AS QuantityName2, 0 AS Quantity3, '''' AS QuantityName3 '
		
	IF @UseUnit = 0
			SET @SqlStr = @SqlStr + ', CASE [mtUnity] WHEN '''' THEN [mtDefUnitName] ELSE [mtUnity] END AS UnitName'
		ELSE IF @UseUnit = 1
			SET @SqlStr = @SqlStr + ', CASE [MtUnit2] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit2] END AS UnitName'
		ELSE IF @UseUnit = 2
			SET @SqlStr = @SqlStr + ', CASE [MtUnit3] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit3] END AS UnitName'
		ELSE 
			SET @SqlStr = @SqlStr + ', [mtDefUnitName] AS UnitName'
	
	SET @SqlStr = @SqlStr + 
		', CASE RecType WHEN ''m'' THEN [APrice] ELSE 0.0 END AS [Price]
		, CASE RecType WHEN ''m'' THEN [r].[mtQty] * [APrice] ELSE 0.0 END AS [AVal] '
		
	IF (@ShowGroups > 0) 
		SET @SqlStr = @SqlStr + ' ,[path]'
	ELSE 
		SET @SqlStr = @SqlStr + ' ,'''' AS [path]'
	IF(@ShowGroups > 0 )
		SET @SqlStr = @SqlStr + ', MaterialGUID' 
	ELSE 
		SET @SqlStr = @SqlStr + ' ,0x0 AS [MaterialGUID]'
	SET @SqlStr = @SqlStr + ' ,[StName],[StCode]'  
	
	
	SET @SqlStr = @SqlStr + ' 
	,CASE 
		WHEN [RecType] = ''m'' THEN ' +
			CASE @UseUnit
				WHEN 0 THEN ' [r].[mtQty] / (CASE [mtUnitFact] WHEN 0 THEN [mtDefUnitFact] ELSE [mtUnitFact] END) '
				WHEN 1 THEN ' [r].[mtQty] / (CASE [mtUnit2Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [mtUnit2Fact] END) '
				WHEN 2 THEN ' [r].[mtQty] / (CASE [mtUnit3Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [mtUnit3Fact] END) '
				WHEN 3 THEN ' [r].[mtQty] / [mtDefUnitFact] '
				ELSE ' [r].[mtQty] '
			END
	SET @SqlStr = @SqlStr + ' 
		ELSE [r].[mtQty] 
	END AS Qty,'
	
	SET @SqlStr = @SqlStr + ' 
				[r].[Qnt2] AS [Qty2],
				[r].[Qnt3] AS [Qty3], 0 '
					
	SET @SqlStr = @SqlStr + ' FROM '  
	IF @ShowGroups > 0  
		SET @SqlStr = @SqlStr + ' [#MainRes3] AS [r] LEFT '  
	ELSE  
		SET @SqlStr = @SqlStr + ' [#R] AS [r] INNER '  
	SET @SqlStr = @SqlStr + ' JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] '  
	-- select @SqlStr ;
	EXECUTE ( @SqlStr ) 
	
	EXEC [prcCheckSecurity] @Result = '#FinalResult'
	 	 
	IF @ShowGroups > 0
	BEGIN 
		CREATE TABLE #GroupFinalResult (
			MtGroup UNIQUEIDENTIFIER,
			[AVal] FLOAT,
			[Qty2] FLOAT,
			[Qty3] FLOAT,
			[Quantity1] FLOAT,
			[Quantity2] FLOAT,
			[Quantity3] FLOAT
		)
		DECLARE @MaxLevel INT
		SET @MaxLevel = (SELECT MAX(grlevel) FROM #FinalResult)
		WHILE (ISNULL(@MaxLevel, 0) >= 1)
		BEGIN 
			TRUNCATE TABLE #GroupFinalResult
			INSERT INTO #GroupFinalResult
			SELECT 
				MtGroup,
				SUM([AVal]) AS [AVal],
				SUM([Qty2]),
				SUM([Qty3]),
				SUM([Quantity1]) AS [Quantity1],
				SUM([Quantity2]) AS [Quantity2],
				SUM([Quantity3]) AS [Quantity3]
			FROM 
				#FinalResult	
			WHERE  
				@StLevel <= 1 OR STLevel < @StLevel		
			GROUP BY MtGroup
			UPDATE fr
			SET 
				AVal = gr.[AVal],
				[Qty2] = gr.[Qty2],
				[Qty3] = gr.[Qty3],
				Quantity1 = gr.[Quantity1],
				Quantity2 = gr.[Quantity2],
				Quantity3 = gr.[Quantity3]
			FROM
				#FinalResult fr 
				INNER JOIN #GroupFinalResult gr ON fr.mtNumber = gr.MtGroup AND fr.grlevel = @MaxLevel
			SET @MaxLevel = @MaxLevel - 1
		END
	END 		
	
	-- Main result
	SELECT 
		*,
		CASE WHEN [RecType] = 'm' THEN [mtNumber] ELSE 0x0 END AS OnlyMaterialGuid
	FROM 
		#FinalResult
	
	-- Totals result (3 rows)
	SELECT
		'1' AS TotalsStr,
		SUM(AVal) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND (AVal > 0 OR Qty > 0)
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))
	UNION ALL 
	SELECT
		'2' AS TotalsStr,
		SUM(AVal) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND (AVal < 0 OR Qty < 0)
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))
	UNION ALL 
	SELECT
		'3' AS TotalsStr,
		isnull(SUM(AVal),0) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))   		
  SELECT * FROM [#SecViol]
#################################################################
#END
