##################################################################
## exec repMatOverflow 0,0,1,0,0,1
CREATE PROCEDURE repMatOverflow
		@Store AS [UNIQUEIDENTIFIER], 	--????????
	@Gr AS [UNIQUEIDENTIFIER] , 	--????????
	@Type AS [INT], 
	@Val_A AS [FLOAT], 
	@Val_B AS [FLOAT], 
	@ShowEmpty AS [INT],
	@MatCond [UNIQUEIDENTIFIER] = 0X00,
	@CollectType	[INT] = 0,
	@DetStr	[BIT] = 0,
	@Lang [BIT] = 0,
	@ShowBalanced [BIT] = 0,
	@EndDate DATETIME,  
	@USEUNIT INT = 0
	/* 
	Type = 0 -> more than max level,  
	Type = 1 -> less then min level,  
	Type = 2 -> more value, 
	Type = 3 -> less value, 
	Type = 4 -> between values 
	TYpe = 5 -> Less Than Order
	*/ 
AS 
	SET NOCOUNT ON
	----------------------------
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	----------------------------
	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @Gr ,0,@MatCond
	CREATE CLUSTERED INDEX [ovFlow] ON [#Mat]([mtNumber])
	----------------------------
	CREATE TABLE [#Store] ( [Number] [UNIQUEIDENTIFIER])  
	insert into [#Store] select [GUID] from [fnGetStoresList]( @Store)  
	----------------------------  
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 0x0
	
	CREATE TABLE [#Result]
	( 	
		[mtGUID] [UNIQUEIDENTIFIER],
		[mtQty] [FLOAT],
		[mtSecurity] [INT],
		[buSecurity] [INT],
		[UserSecurity] [INT],
		[mtCol] [NVARCHAR](256)  COLLATE ARABIC_CI_AI DEFAULT '',
		[stGuid] UNIQUEIDENTIFIER,
		[stName] [NVARCHAR](256)  COLLATE ARABIC_CI_AI DEFAULT ''
	)
	----------------------------
	CREATE TABLE [#mt3]
		(
			[mtCol] [NVARCHAR](256)  COLLATE ARABIC_CI_AI DEFAULT '',
			[mtHigh] [FLOAT],
			[mtLow] [FLOAT], 
			[mtOrder] [FLOAT]
		)
	----------------------------
	CREATE TABLE [#mt2](
		[mtGUID] UNIQUEIDENTIFIER,  
		[mtName] NVARCHAR(256),  
		[mtCode] NVARCHAR(256),
		[GroupCode] NVARCHAR(256),
		[GroupName] NVARCHAR(256),    
		[mtLatinName] NVARCHAR(256),
		[mtDefUnitName] NVARCHAR(256),
		[mtDefUnit] INT,
		[mtHigh] FLOAT,
		[mtOrder] FLOAT,
		[mtLow] FLOAT,           
		[mtDefUnitFact] FLOAT,
		[mtSpec] NVARCHAR(1000),   
		[mtDim] NVARCHAR(256),   
		[mtOrigin] NVARCHAR(256), 
		[mtPos] NVARCHAR(256),
		[mtCompany] NVARCHAR(256),
		[mtColor] NVARCHAR(256),
		[mtProvenance] NVARCHAR(256),
		[mtQuality] NVARCHAR(256),
		[mtModel] NVARCHAR(256),
		[mtSecurity] INT
	)
	INSERT INTO [#mt2]
	SELECT  
		[vwMt].[mtGUID],  
		[vwMt].[mtName],  
		[vwMt].[mtCode],
		[Gr].[Code] AS [GroupCode],
		[Gr].[Name] AS [GroupName],    
		[vwMt].[mtLatinName],
		
		(case @useUnit when 0 then [vwMt].[mtUnity]       
			           when 1 then case [vwMt].[mtUnit2Fact] when 0 then [vwMt].[mtUnity] else [vwMt].[mtUnit2] end     
			           when 2 then case [vwMt].[mtUnit3Fact] when 0 then [vwMt].[mtUnity] else [vwMt].[mtUnit3] end      
			           else case [vwMt].[mtDefUnit]  
			                        when 1 then [vwMt].[mtUnity]      
					                when 2 then [vwMt].[mtUnit2]      
					                else [vwMt].[mtUnit3] end end) AS [mtDefUnitName],
		 
		(case  @useUnit when 0 then 1       
			            when 1 then 2      
			            when 2 then 3
			            else case [vwMt].mtDefUnit 
			                         when 1 then 1
			                         when 2 then 2
						             else 3 end end) AS [mtDefUnit],
		
		(case  @useUnit when 0 then ISNULL([vwMt].[mtHigh], 0.00)       
			            when 1 then ISNULL([vwMt].[mtHigh], 0.00) / case [vwMt].[mtUnit2Fact] when 0 then 1 else [vwMt].[mtUnit2Fact] end      
			            when 2 then ISNULL([vwMt].[mtHigh], 0.00) / case [vwMt].[mtUnit3Fact] when 0 then 1 else [vwMt].[mtUnit3Fact] end
			            else ISNULL([vwMt].[mtHigh], 0.00) / case [vwMt].mtDefUnit 
			                                                     when 2 then [vwMt].[mtUnit2Fact] 
			                                                     when 3 then [vwMt].[mtUnit3Fact]     
						                                         else 1 end end) AS [mtHigh],
		
		(case  @useUnit when 0 then ISNULL([vwMt].[mtOrder], 0.00)       
			            when 1 then ISNULL([vwMt].[mtOrder], 0.00) / case [vwMt].[mtUnit2Fact] when 0 then 1 else [vwMt].[mtUnit2Fact] end      
			            when 2 then ISNULL([vwMt].[mtOrder], 0.00) / case [vwMt].[mtUnit3Fact] when 0 then 1 else [vwMt].[mtUnit3Fact] end
			            else ISNULL([vwMt].[mtOrder], 0.00) / case [vwMt].mtDefUnit 
			                                                     when 2 then [vwMt].[mtUnit2Fact] 
			                                                     when 3 then [vwMt].[mtUnit3Fact]     
						                                         else 1 end end) AS [mtOrder],
		
		(case  @useUnit when 0 then ISNULL([vwMt].[mtLow], 0.00)       
			            when 1 then ISNULL([vwMt].[mtLow], 0.00) / case [vwMt].[mtUnit2Fact] when 0 then 1 else [vwMt].[mtUnit2Fact] end      
			            when 2 then ISNULL([vwMt].[mtLow], 0.00) / case [vwMt].[mtUnit3Fact] when 0 then 1 else [vwMt].[mtUnit3Fact] end
			            else ISNULL([vwMt].[mtLow], 0.00) / case [vwMt].mtDefUnit 
			                                                     when 2 then [vwMt].[mtUnit2Fact] 
			                                                     when 3 then [vwMt].[mtUnit3Fact]     
						                                         else 1 end end) AS [mtLow],
						           
		(case  @useUnit when 0 then 1       
			            when 1 then case [vwMt].[mtUnit2Fact] when 0 then 1 else [vwMt].[mtUnit2Fact] end
			            when 2 then case [vwMt].[mtUnit3Fact] when 0 then 1 else [vwMt].[mtUnit3Fact] end
			            else case [vwMt].mtDefUnit 
			                   when 2 then [vwMt].[mtUnit2Fact] 
			                   when 3 then [vwMt].[mtUnit3Fact]     
						       else 1 end end) AS [mtDefUnitFact],
		
		[vwMt].[mtSpec],   
		[vwMt].[mtDim],   
		[vwMt].[mtOrigin], 
		[vwMt].[mtPos],
		[vwMt].[mtCompany],
		[vwMt].[mtColor],
		[vwMt].[mtProvenance],
		[vwMt].[mtQuality],
		[vwMt].[mtModel],
		[vwMt].[mtSecurity]
	FROM [vwMt] INNER JOIN [#Mat] AS [mt] ON  [vwMt].[mtGUID] = [mt].[mtNumber] 
				INNER jOIN [gr000] AS [Gr] ON [Gr].[Guid] = [vwMt].[mtGroup]
	IF @CollectType = 0
		INSERT INTO [#Result]([mtGUID] ,[mtQty],[mtSecurity],[buSecurity],[UserSecurity],[mtCol],[stGuid],[stName])
		SELECT
			[biMatPtr],
			SUM(( [biQty] + [biBonusQnt]) * [buDirection] / CASE [mat].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mat].[mtDefUnitFact] END),--// ·«Ì√Œ– «·ÊÕœ… »⁄Ì‰ «·≈⁄ »«—
			[mat].[mtSecurity],
			[buSecurity],
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			'',
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END ,
			N''
		FROM
			[vwbubi] AS  [bi]
			INNER JOIN [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]
			INNER JOIN [#mt2] AS [mat] ON [bi].[BiMatPtr] = [mat].[mtGUID] 
			INNER JOIN [#Store] AS [stor] ON [bi].[BiStorePtr] = [stor].[Number] 
		    WHERE [buDate] <= @EndDate
		GROUP BY 
			[biMatPtr],
			[mat].[mtSecurity],
			[buSecurity],
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END 
	ELSE
		INSERT INTO [#Result]([mtGUID] ,[mtQty],[mtSecurity],[buSecurity],[UserSecurity],[mtCol],[stGuid],[stName])
		SELECT
			0X00,
			SUM(( [biQty] + [biBonusQnt]) * [buDirection] / CASE [mat].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mat].[mtDefUnitFact] END),--[mat].[mtDefUnitFact]  „ Õ”«»Â „”»ﬁ«
			[mat].[mtSecurity],
			[buSecurity],
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			CASE @CollectType 
				WHEN 1 THEN [mat].[mtSpec]   
				WHEN 2 THEN [mat].[mtDim]   
				WHEN 3 THEN [mat].[mtOrigin] 
				WHEN 4 THEN [mat].[mtPos]
				WHEN 5 THEN [mat].[mtCompany]
				WHEN 6 THEN [mat].[mtColor]
				WHEN 7 THEN [mat].[mtProvenance]
				WHEN 8 THEN [mat].[mtQuality]
				WHEN 9 THEN [mat].[mtModel]
				ELSE ''
			END, 
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END , N''
		FROM
			[vwbubi] AS  [bi]
			INNER JOIN [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]
			INNER JOIN [#Mt2] AS [mat] ON [bi].[BiMatPtr] = [mat].[mtGUID]
			INNER JOIN [#Store] AS [stor] ON [bi].[BiStorePtr] = [stor].[Number] 
			WHERE [buDate] <= @EndDate
		GROUP BY 
			[mat].[mtSecurity],
			[buSecurity],
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			CASE @CollectType 
				WHEN 1 THEN [mat].[mtSpec]   
				WHEN 2 THEN [mat].[mtDim]   
				WHEN 3 THEN [mat].[mtOrigin] 
				WHEN 4 THEN [mat].[mtPos]
				WHEN 5 THEN [mat].[mtCompany]
				WHEN 6 THEN [mat].[mtColor]
				WHEN 7 THEN [mat].[mtProvenance]
				WHEN 8 THEN [mat].[mtQuality]
				WHEN 9 THEN [mat].[mtModel]
				ELSE ''
			END,
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END 
		
	----------------------------
	EXEC [prcCheckSecurity]
	---------------------------- 
	IF @DetStr > 0
		UPDATE [R] SET [stName] = st.Code + '-' + CASE @Lang WHEN 0 THEN st.Name ELSE CASE st.LatinName WHEN '' THEN  st.Name  ELSE  st.LatinName END END FROM [#Result] [r] INNER JOIN [st000] st ON st.Guid = [stGuid]
	IF @CollectType = 0
		SELECT 
			[vwMt].[mtGUID] AS [MtNumber],  
			[vwMt].[mtName] AS [MtName],  
			[vwMt].[mtCode] AS [MtCode], 
			[vwMt].[GroupCode],
			[vwMt].[GroupName],   
			[vwMt].[mtLatinName] AS [MtLatinName],  
			[vwMt].[mtDefUnitName] AS [DefUnitName],  
			[vwMt].[mtDefUnit] AS [DefUnit],
			ISNULL( [vwMt].[mtHigh] ,0) AS [High], 
			ISNULL( [vwMt].[mtLow], 0) AS [Low], 
			ISNULL( [vwMt].[mtOrder], 0) AS [Order], 
			ISNULL( SUM( [Res].[mtQty]) ,0) AS [Qty], 
			ISNULL( CASE 
					WHEN [vwMt].[mtDefUnitFact] < 0.001 THEN 1
					ELSE [vwMt].[mtDefUnitFact] 
				END , 0) AS [DefUnitFact],
			 [stName],
			ISNULL([stGuid],0x00) [stGuid]
		FROM
			[#mt2] AS [vwMt] 
			LEFT JOIN [#Result] AS [Res] ON [Res].[mtGUID] = [vwMt].[mtGUID]
		GROUP BY  
			[vwMt].[mtGUID],  
			[vwMt].[mtName],  
			[vwMt].[mtCode],  
			[vwMt].[mtLatinName],  
			[vwMt].[mtDefUnitName], 
			[vwMt].[mtDefUnit],
			[vwMt].[mtHigh],
			[vwMt].[mtOrder], 
			[vwMt].[mtLow], 
			[vwMt].[mtDefUnitFact],[stName],[stGuid],[vwMt].[GroupCode],
			[vwMt].[GroupName]
		HAVING  
			(
				(
					( @Type = 0 AND ISNULL( SUM( [Res].[mtQty]),0) > [mtHigh] )
					OR 
					( @Type = 1 AND ISNULL( SUM( [Res].[mtQty]),0) < [mtLow] )
					OR 
					( @Type = 2 AND ISNULL( SUM( [Res].[mtQty]),0) > @Val_A )
					OR 
					( @Type = 3 AND ISNULL( SUM( [Res].[mtQty]),0) < @Val_A )
					OR 
					( @Type = 4 AND ISNULL( SUM( [Res].[mtQty]),0) BETWEEN @Val_A AND @Val_B )
					OR 
					( @Type = 5 AND ISNULL( SUM( [Res].[mtQty]),0) < [mtOrder] )
				)
				
			)
			AND
			(
				( @ShowEmpty = 1
				    AND
				  SUM ([Res].[mtQty]) IS NULL
				)
				OR
				( ABS (ISNULL (SUM ([Res].[mtQty]), 0)) > 0.00001
				)
				OR
				( @ShowBalanced = 1
				    AND
				  ABS (ISNULL (SUM ([Res].[mtQty]), 0)) >= 0 AND SUM([Res].[mtQty]) IS NOT NULL
				)
			)
		ORDER BY  
			[vwMt].[mtCode],[stName]
	ELSE
	BEGIN
		INSERT INTO [#mt3]
		SELECT 
			CASE @CollectType 
				WHEN 1 THEN [mt2].[mtSpec]   
				WHEN 2 THEN [mt2].[mtDim]   
				WHEN 3 THEN [mt2].[mtOrigin] 
				WHEN 4 THEN [mt2].[mtPos]
				WHEN 5 THEN [mt2].[mtCompany]
				WHEN 6 THEN [mt2].[mtColor]
				WHEN 7 THEN [mt2].[mtProvenance]
				WHEN 8 THEN [mt2].[mtQuality]
				WHEN 9 THEN [mt2].[mtModel]
				ELSE ''
			END AS [mtCol],
			SUM([mt2].[mtHigh]), --  „ Õ”«» «·ﬂ„Ì«  „”»ﬁ« »«·ÊÕœ… «·„ÿ·Ê»…
			SUM([mt2].[mtLow]), 
			SUM([mt2].[mtOrder])
		FROM
			[#MT2] AS [mt2]
		GROUP BY 
			CASE @CollectType 
				WHEN 1 THEN [mt2].[mtSpec]   
				WHEN 2 THEN [mt2].[mtDim]   
				WHEN 3 THEN [mt2].[mtOrigin] 
				WHEN 4 THEN [mt2].[mtPos]
				WHEN 5 THEN [mt2].[mtCompany]
				WHEN 6 THEN [mt2].[mtColor]
				WHEN 7 THEN [mt2].[mtProvenance]
				WHEN 8 THEN [mt2].[mtQuality]
				WHEN 9 THEN [mt2].[mtModel]
				ELSE ''
			END
		
		SELECT 
			[mt2].[mtCol] AS [MtName],
			[mt2].[mtHigh] AS [High], 
			[mt2].[mtLow] AS [Low], 
			[mt2].[mtOrder] AS [Order], 
			ISNULL(SUM( [Res].[mtQty]) ,0) AS [Qty] ,
			[stName],
			ISNULL([stGuid],0x00) [stGuid]
		FROM
			[#mt3] AS [mt2] 
			LEFT JOIN [#Result] AS [Res] ON [Res].[mtCol] = [mt2].[mtCol]
		GROUP BY  
			[mt2].[mtCol],
			[mt2].[mtHigh], 
			[mt2].[mtLow], 
			[mt2].[mtOrder],
			[stName],
			ISNULL([stGuid],0x00) 
			
		HAVING  
			(
				(
					( @Type = 0 AND ISNULL( SUM( [Res].[mtQty]),0) > [mtHigh] )
					OR 
					( @Type = 1 AND ISNULL( SUM( [Res].[mtQty]),0) <[mtLow] )
					OR 
					( @Type = 2 AND ISNULL( SUM( [Res].[mtQty]),0) > @Val_A )
					OR 
					( @Type = 3 AND ISNULL( SUM( [Res].[mtQty]),0) < @Val_A )
					OR 
					( @Type = 4 AND ISNULL( SUM( [Res].[mtQty]),0) BETWEEN @Val_A AND @Val_B )
					OR 
					( @Type = 5 AND ISNULL( SUM( [Res].[mtQty]),0) < [mtOrder] )
				)
				
			)
			AND
			(
				( @ShowEmpty = 1
				    AND
				  SUM ([Res].[mtQty]) IS NULL
				)
				OR
				( ABS (ISNULL (SUM ([Res].[mtQty]), 0)) > 0.00001
				)
				OR
				( @ShowBalanced = 1
				    AND
				  ABS (ISNULL (SUM ([Res].[mtQty]), 0)) >= 0
				)
			)
		ORDER BY 
			[mt2].[mtCol],[stName]
	END
	SELECT * FROM [#SecViol]
/*
	prcConnections_add2 '„œÌ—'
 [repMatOverflow] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 0.000000, 0.000000, 0, '00000000-0000-0000-0000-000000000000', 0, 0, 0, 0, 3
 */
#####################################################################################
#END