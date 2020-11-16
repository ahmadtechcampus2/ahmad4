#########################################################################
CREATE PROCEDURE repOrderMatOverflow
	@Store AS [UNIQUEIDENTIFIER], 	  
	@Gr AS [UNIQUEIDENTIFIER] , 	 
	@Type AS [INT],   
	@Val_A AS [FLOAT],   
	@Val_B AS [FLOAT],   
	@ShowEmpty AS [INT],  
	@MatCond [UNIQUEIDENTIFIER] = 0X00,  
	@CollectType	[INT] = 0,  
	@DetStr	[BIT] = 0,  
	@Lang [BIT] = 0,  
	@ShowBalanced [BIT] = 0, 
	@OrderTypeGuid [UNIQUEIDENTIFIER] = 0x00, 
	/*   
	Type = 0 -> more than max level,    
	Type = 1 -> less then min level,    
	Type = 2 -> more value,   
	Type = 3 -> less value,   
	Type = 4 -> between values   
	TYpe = 5 -> Less Than Order  
	*/   	  
	@MatFldsFlag	BIGINT = 0,
	@MatCFlds 	NVARCHAR (max) = ''
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
	SELECT    
		[vwMt].[mtGUID],    
		[vwMt].[mtName],    
		[vwMt].[mtCode],    
		[vwMt].[mtLatinName],    
		[vwMt].[mtDefUnitName],   
		[vwMt].[mtDefUnit],  
		[vwMt].[mtHigh],  
		[vwMt].[mtOrder],   
		[vwMt].[mtLow],   
		[vwMt].[mtDefUnitFact],  
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
	INTO [#mt2]  
	FROM [vwMt] INNER JOIN [#Mat] AS [mt] ON  [vwMt].[mtGUID] = [mt].[mtNumber]   
	IF @CollectType = 0  
		INSERT INTO [#Result]([mtGUID] ,[mtQty],[mtSecurity],[buSecurity],[UserSecurity],[mtCol],[stGuid])  
		SELECT  
			[biMatPtr],  
			SUM(( [biQty] + [biBonusQnt]) * [buDirection]),  
			[mat].[mtSecurity],  
			[buSecurity],  
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,  
			'',  
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END   
		FROM  
			[vwbubi] AS  [bi]  
			INNER JOIN [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]  
			INNER JOIN [#Mat] AS [mat] ON [bi].[BiMatPtr] = [mat].[mtNumber]   
			INNER JOIN [#Store] AS [stor] ON [bi].[BiStorePtr] = [stor].[Number]   
		GROUP BY   
			[biMatPtr],  
			[mat].[mtSecurity],  
			[buSecurity],  
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,  
			CASE @DetStr WHEN 0 THEN 0x00 ELSE [bi].[BiStorePtr] END   
	ELSE  
		INSERT INTO [#Result]([mtGUID] ,[mtQty],[mtSecurity],[buSecurity],[UserSecurity],[mtCol],[stGuid])  
		SELECT  
			0X00,  
			SUM(( [biQty] + [biBonusQnt]) * [buDirection]/ CASE [mat].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [mat].[mtDefUnitFact] END),  
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
		FROM  
			[vwbubi] AS  [bi]  
			INNER JOIN [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]  
			INNER JOIN [#Mt2] AS [mat] ON [bi].[BiMatPtr] = [mat].[mtGUID]  
			INNER JOIN [#Store] AS [stor] ON [bi].[BiStorePtr] = [stor].[Number]   
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
CREATE TABLE #EndResult	(MtNumber UNIQUEIDENTIFIER, 
			 MtName NVARCHAR(255) COLLATE ARABIC_CI_AI DEFAULT '',  
			 MtCode NVARCHAR(255)  COLLATE ARABIC_CI_AI DEFAULT '',  
			 MtLatinName NVARCHAR(255)  COLLATE ARABIC_CI_AI DEFAULT '',     
			 DefUnitName NVARCHAR(255)  COLLATE ARABIC_CI_AI DEFAULT '',  
			 DefUnit INT,  [High] FLOAT , [Low] FLOAT  ,  [ORDER] FLOAT, MtQty FLOAT,   
			 DefUnitFact FLOAT,  
			 stName NVARCHAR(255)  COLLATE ARABIC_CI_AI DEFAULT '',  
			 stGuid UNIQUEIDENTIFIER ) 
	IF @DetStr > 0  
		UPDATE [R] SET [stName] = st.Code + '-' + CASE @Lang WHEN 0 THEN st.Name ELSE CASE st.LatinName WHEN '' THEN  st.Name  ELSE  st.LatinName END END FROM [#Result] [r] INNER JOIN [st000] st ON st.Guid = [stGuid]  
	IF @CollectType = 0  
		INSERT INTO #EndResult 
		SELECT   
			[vwMt].[mtGUID] AS [MtNumber],    
			[vwMt].[mtName] AS [MtName],    
			[vwMt].[mtCode] AS [MtCode],    
			[vwMt].[mtLatinName] AS [MtLatinName],    
			[vwMt].[mtDefUnitName] AS [DefUnitName],    
			[vwMt].[mtDefUnit] AS [DefUnit],  
			ISNULL( [vwMt].[mtHigh] ,0) AS [High],   
			ISNULL( [vwMt].[mtLow], 0) AS [Low],   
			ISNULL( [vwMt].[mtOrder], 0) AS [Order],   
			ISNULL( SUM( [Res].[mtQty]) ,0) AS [MtQty],   
			ISNULL( CASE   
					WHEN [vwMt].[mtDefUnitFact] < 0.001 THEN 1  
					ELSE [vwMt].[mtDefUnitFact]   
				END , 0) AS [DefUnitFact],  
			ISNULL([stName],'') [stName],  
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
			[vwMt].[mtDefUnitFact],[stName],[stGuid]  
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
				  ABS (ISNULL (SUM ([Res].[mtQty]), 0)) >= 0  
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
			ISNULL( SUM([mt2].[mtHigh]/ CASE [Mt2].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Mt2].[mtDefUnitFact] END) ,0) AS [mtHigh],   
			ISNULL( SUM([mt2].[mtLow]/ CASE [Mt2].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Mt2].[mtDefUnitFact] END), 0) AS [mtLow],   
			ISNULL( SUM([mt2].[mtOrder]/ CASE [Mt2].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Mt2].[mtDefUnitFact] END), 0) AS [mtOrder]   
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
		  
		INSERT INTO #EndResult (MtName , High, [Low], [Order], mtQty, stName,stGuid) 
		SELECT   
			[mt2].[mtCol] AS [MtName],  
			[mt2].[mtHigh] AS [High],   
			[mt2].[mtLow] AS [Low],   
			[mt2].[mtOrder] AS [Order],   
			ISNULL( SUM( [Res].[mtQty]) ,0) AS [Qty] ,  
			ISNULL([stName],'') [stName],  
			ISNULL([stGuid],0x00) [stGuid]  
		 
		FROM  
			[#mt3] AS [mt2]   
			LEFT JOIN [#Result] AS [Res] ON [Res].[mtCol] = [mt2].[mtCol]  
		GROUP BY    
			[mt2].[mtCol],  
			[mt2].[mtHigh],   
			[mt2].[mtLow],   
			[mt2].[mtOrder],  
			ISNULL([stName],''),  
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
	DECLARE @OrderName NVARCHAR(255)  
	SET @OrderName = (SELECT Abbrev FROM bt000 WHERE guid = @OrderTypeGuid)  
	  
	SELECT 
		bu.Guid OrderGuid,
		bu.TypeGuid OrderTypeGuid,
		(@OrderName + ' : ' + Convert(NVARCHAR(10), bu.Number)) As OrderName,
	    bu.Number OrderNumber
	    ,bi.MatGuid AS MatGuid, 
	    SUM(bi.Qty) AS QTY  
	INTO #TempQty1
	FROM bi000 bi 
		INNER join bu000 bu ON bu.Guid= bi.ParentGuid
		INNER JOIN ORADDINFO000 OAI ON OAI.ParentGuid = bu.Guid
	WHERE bu.TypeGuid = @OrderTypeGuid AND OAI.Finished = 0 AND  OAI.Add1 = '0' -- 0 : Order is canceled  
	GROUP BY 
			bu.Guid,
			bu.TypeGuid, 
			@OrderName + '' + Convert(NVARCHAR(10),
			bu.Number),
			bu.Number,
			bi.MatGuid  
--select * from #TempQty1  
	SELECT 
		 bu.Guid OrderGuid,
		 bu.typeguid ParentGuid ,
		 bu.TypeGuid OrderTypeGuid , 
		 bi.MatGuid, 
		 SUM(bi.Qty) AS QTY  
	INTO #TempQty2  
	FROM bi000 bi 
		INNER JOIN bu000 bu ON bu.Guid= bi.ParentGuid  
		LEFT JOIN ORREL000 REL ON REL.ORGuid = bu.Guid  
		INNER JOIN ORADDINFO000 OAI ON OAI.ParentGuid = bu.Guid	  
	WHERE bu.typeGuid= @OrderTypeGuid  AND OAI.Add1 = '0' -- 0 : Order is canceled  
	GROUP BY  
		bu.Guid,
		bu.TypeGuid,
		bi.MatGuid  --REL.ParentGuid ,
	
--select * from #TempQty2
--select * from ORREL000  
	SELECT 
		 TQ1.OrderGuid ,
		 TQ1.OrderTypeGuid,
		 TQ1.OrderName,
		 TQ1.OrderNumber, 
		 TQ1.MatGuid AS MatGuid , 
		 TQ1.QTY OrderQty, 
		 SUM ( TQ2.QTY) AS StayQTY   
	INTO #OrderEndResult   
	FROM #TempQty1 TQ1 
		INNER JOIN #TempQty2 TQ2 ON  TQ1.OrderGuid = TQ2.OrderGuid AND  TQ1.MatGuid = TQ2.MatGuid  
	GROUP BY 
		TQ1.OrderGuid,
		TQ1.OrderTypeGuid,
		TQ1.OrderName,
		TQ1.OrderNumber, 
		TQ1.MatGuid,
		TQ1.QTY
--select 'error'
--select * from #OrderEndResult  
	EXEC GetMatFlds @MatFldsFlag, @MatCFlds  
	SELECT 
		ER.*,
		OER.OrderQty,
		OER.OrderTypeGuid,
		OER.OrderGuid,
		OER.OrderName,
		OER.OrderNumber,
		OER.OrderQty - OER.StayQTY AS StayOrderQTY,
		M.* 
	INTO #FinalResult 
	FROM #EndResult ER 
		LEFT OUTER JOIN #OrderEndResult OER ON ER.MtNumber= OER.MatGuid  
		INNER JOIN ##MatFlds M ON M.MatFldGuid = ER.MtNumber 
	--where  OER.OrderQty - OER.StayQTY > 0  
	ORDER BY 
		MTCode,
		MtName  
	SELECT DISTINCT * FROM #FinalResult 
	SELECT * FROM [#SecViol]   
#########################################################################
#END