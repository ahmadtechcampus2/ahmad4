####################################################
CREATE PROCEDURE repPurchaseOrder
	@Acc [UNIQUEIDENTIFIER],      
	@Cost [UNIQUEIDENTIFIER],      
	@Mt AS [UNIQUEIDENTIFIER],      
	@Gr AS [UNIQUEIDENTIFIER],      
	@Store AS [UNIQUEIDENTIFIER],      
	@StartDate [DATETIME],      
	@EndDate [DATETIME],      
	@CurGUID [UNIQUEIDENTIFIER],      
	@CurVal [FLOAT],      
	@TypeGuid [UNIQUEIDENTIFIER],      
	@Src AS [UNIQUEIDENTIFIER],      
	@Unify AS [INT] = 0,    
	@UnifyQty AS [INT] = 0,   
	 @Unity AS [INT]  ,  
	/*@NoteContain [NVARCHAR](1000),   
	@NotNoteContain [NVARCHAR](1000),   
	 
	@ShipType [NVARCHAR](250) ,  
	@ShipeCompany [NVARCHAR](250) ,  
	@ReceiveCondition [NVARCHAR](250),  
	@FromReceiveDate [NVARCHAR](250),  
	@ToReceiveDate [NVARCHAR](250) */ 
	@isFinished BIT = 0  , 
	@isCancled BIT = 0  , 
	@MatCond	UNIQUEIDENTIFIER = 0x00, 
	@CustCondGuid	UNIQUEIDENTIFIER = 0x00, 
	@OrderCond	UNIQUEIDENTIFIER = 0x00,	  
	@CustFldsFlag	 BIGINT = 0, 			  
	@OrderFldsFlag	 BIGINT = 0,  		  
	@MatCFlds 		 NVARCHAR (max) = '', 		  		
	@CustCFlds 		 NVARCHAR (max) = '', 		  
	@OrderCFlds 	 NVARCHAR (max) = ''	 
AS    
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON 
	    
	--declare @NoteContain [NVARCHAR](1000)   
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])       
	-------Bill Resource ---------------------------------------------------------         
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT],[ReadPrice] [INT], [UnPostedSec] [INT])   
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src   
	-------------------------------------------------------------------         
	DECLARE @TypeTbl TABLE( [Type] [UNIQUEIDENTIFIER],  
							[Name] NVARCHAR(255) collate ARABIC_CI_AI,  
							[LatinName] NVARCHAR(255) collate ARABIC_CI_AI ,  
							[Operation] int,  
							[PostQty] int)      
	  
	INSERT INTO @TypeTbl    
		SELECT [idType], isnull( [Name], ''),  isnull( [LatinName], ''), isnull( Operation, 0) , isnull( PostQty, 0)  
		FROM    
			 [RepSrcs] [src]    
			left join [dbo].[fnGetOrderItemTypes]() as [fnType] on [fnType].[Guid] = [src].[idType]   
		WHERE    
			[IdTbl] = @TypeGuid --AND ( [fnType].Operation = [fnType].Operation)  
		GROUP BY    
			[idType], [Name], [LatinName] , Operation, PostQty  
		ORDER BY PostQty -- sequence number of Order State 
	 
	-------------------------------------------------------------------  
	--  ÌÏæá ÇáØáÈíÇÊ ãÚ ÊÍÍÞíÞ ÔÑæØ ÇáØáÈíÇÊ 
	CREATE TABLE #OrderCond ( OrderGuid UNIQUEIDENTIFIER, [Security] [INT] )  
	INSERT INTO [#OrderCond](OrderGuid, [Security]) EXEC [prcGetOrdersList] @OrderCond	     
	-------------------------------------------------------------------  
	-------------------------------------------------------------------      
	CREATE TABLE [#CustTbl]( [Number] [UNIQUEIDENTIFIER], [cuSec] [int])  
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] NULL, @Acc , @CustCondGuid     
	IF (ISNULL(@Acc,0x0) = 0x00 ) AND (ISNULL(@CustCondGuid,0x0) = 0X0)      
	BEGIN  
		INSERT INTO [#CustTbl] VALUES( 0x0,1)    
	END  
	-------Mat Table----------------------------------------------------------         
	CREATE TABLE [#MatTbl]( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])           
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  @Mt, @Gr , -1  , @MatCond              
	-------Store Table----------------------------------------------------------         
	DECLARE @StoreTbl TABLE( [Number] [UNIQUEIDENTIFIER])           
	INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @Store)           
	------Cost Table----------------------------------------------------------         
	DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER])         
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @Cost)           
	IF ISNULL( @Cost, 0x0) = 0x0      
		INSERT INTO @CostTbl VALUES( 0x0)   
	--//////////////////////////////////////////////////////////         
	CREATE TABLE #Result(   
		[MtGUID] uniqueidentifier,      
		[buGuid] uniqueidentifier,
		[CustGuid] uniqueidentifier,
		[biGuid] uniqueidentifier,   
		[biPrice] float,   
		[billUnit] int,   
		[billUnitFact] float,     
		[biQty] float,      
		[buFormatedNumber] NVARCHAR(255) collate ARABIC_CI_AI,   
		[buLatinFormatedNumber] NVARCHAR(255) collate ARABIC_CI_AI, 
		[buCust_Name] NVARCHAR(255) collate ARABIC_CI_AI,   
		[buDate] datetime,      
		[mtSecurity] [INT],   
		[buSecurity] [INT],   
		[UserSecurity][INT]   
		--[PostToBillQty] float,   
--		,[ShipType] NVARCHAR(255) collate ARABIC_CI_AI,   
--		[ShipeCompany] NVARCHAR(255) collate ARABIC_CI_AI,   
--		[ReceiveCondition] NVARCHAR(255) collate ARABIC_CI_AI,  
--		[ReceiveDate] NVARCHAR(255) collate ARABIC_CI_AI,  
--		[OrderNumber] NVARCHAR(1000) collate ARABIC_CI_AI 
	)    
	INSERT INTO #Result   
	SELECT      
		[bu].[biMatPtr],      
		[bu].[buGuid],
		[bu].[BuCustPtr],
		[bu].[biGuid],   
		case when ReadPrice < busecurity then 0 else    
			case @UnifyQty when 0 then [FixedbiUnitPrice] * CASE @Unity   
						WHEN 2 THEN CASE [bu].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [bu].[mtUnit2Fact] END    
						WHEN 3 THEN CASE [bu].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [bu].[mtUnit3Fact] END    
						WHEN 4 THEN CASE [bu].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [bu].[mtDefUnitFact] END   
						ELSE 1 END else 0 end  end AS [biPrice],   
		CASE @Unity   
			WHEN 2 THEN 2    
			WHEN 3 THEN 3    
			WHEN 4 THEN [bu].[mtDefUnit]   
			ELSE 1 END AS [billUnit],   
		case @UnifyQty when 0 then [mtUnitFact] else 1 end AS [billUnitFact],   
		([biQty] /    
					CASE @Unity     
						WHEN 2 THEN CASE ISNULL( [bu].[mtUnit2Fact], 0) WHEN 0 THEN 1 ELSE [bu].[mtUnit2Fact] END    
						WHEN 3 THEN CASE ISNULL( [bu].[mtUnit3Fact], 0) WHEN 0 THEN 1 ELSE [bu].[mtUnit3Fact] END    
						WHEN 4 THEN CASE ISNULL( [bu].[mtDefUnitFact], 0) WHEN 0 THEN 1 ELSE [bu].[mtDefUnitFact] END   
						ELSE 1    
					END   
			) AS [biQty],      
		CASE @UnifyQty WHEN 0 THEN [buFormatedNumber] ELSE '' END AS [buFormatedNumber], 
		CASE @UnifyQty WHEN 0 THEN [buLatinFormatedNumber] ELSE '' END AS [buLatinFormatedNumber], 
		CASE @UnifyQty WHEN 0 THEN [buCust_Name] ELSE '' END AS [buCust_Name],   
		CASE @UnifyQty WHEN 0 THEN [buDate] ELSE '01-01-1980' END AS [buDate],   
		[bu].[mtSecurity],   
		[bu].[buSecurity],   
		CASE [bu].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END   
		--[ori].[Qty] as PostToBillQty ,  
--		,[buTextFld1] as ShipType ,   
--		[buTextFld2] as ShipeCompany ,   
--		[buTextFld3] as ReceiveCondition,  
--		[buTextFld4] as ReceiveDate,	  
--		[bu].[buNotes] as OrderNumber   
	FROM     
		[dbo].[fnExtended_bi_Fixed]( @CurGUID) AS [bu] 
		INNER JOIN #OrderCond OrCond ON  OrCond.OrderGuid = bu.BuGuid    
		INNER JOIN ORADDINFO000 OInfo ON bu.buGuid = OInfo.ParentGuid	  
		--INNER JOIN ori000 ori ON bu.Guid = ori.POGuid  
		--INNER JOIN [bt000] as [bt] ON [bu].[buType] = [bt].[Guid]      
		INNER JOIN [#MatTbl] AS [mtTbl] ON [mtTbl].[mtNumber] = [bu].[biMatPtr]     
		inner JOIN [#CustTbl] AS [CU] ON [CU].[Number] = [bu].[BuCustPtr]       
		INNER JOIN [#Src] AS [Src] ON [Src].[Type] = [bu].[buType]     
		INNER JOIN @CostTbl AS [CO] ON [CO].[Number] = [bu].[biCostPtr]       
		INNER JOIN @StoreTbl AS [ST] ON [ST].[Number] = [bu].[biStorePtr]        
		--INNER JOIN [vwMt] AS [mt] ON [Bu].[biMatPtr] = [mt].[mtGuid]     
	WHERE  
		    (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end  ) ) 
		AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end  ) ) 
	----------------------------------------   
	exec prcCheckSecurity   
	-----------------------------------------   
	CREATE TABLE #Result2(   
		[biGuid]uniqueidentifier,   
		[MtGUID] uniqueidentifier,    
		[buGuid] uniqueidentifier,
		[CustGuid] uniqueidentifier, 
		[oriTypeGuid]uniqueidentifier,  
		[oriTypeNUmber] int,  
		[biPrice] float,   
		[billUnit] int,   
		[billUnitFact] float,     
		[oriQty] float,      
		[biQty] float,      
		[buFormatedNumber] NVARCHAR(255) collate ARABIC_CI_AI,   
		[buLatinFormatedNumber] NVARCHAR(255) collate ARABIC_CI_AI,  
		[buCust_Name] NVARCHAR(255) collate ARABIC_CI_AI,   
		[buDate] datetime,      
		[oriDate] datetime,      
		[oriNotes] NVARCHAR(255) collate ARABIC_CI_AI,      
		[oriTypeName] NVARCHAR(255) collate ARABIC_CI_AI,   
		[oriTypeLatinName] NVARCHAR(255) collate ARABIC_CI_AI, 
		[oriNumber] int  
--		,[ShipType] NVARCHAR(255) collate ARABIC_CI_AI,   
--		[ShipeCompany] NVARCHAR(255) collate ARABIC_CI_AI,   
--		[ReceiveCondition] NVARCHAR(255) collate ARABIC_CI_AI,  
--		[ReceiveDate] NVARCHAR(255) collate ARABIC_CI_AI,  
--		[OrderNumber] NVARCHAR(1000) collate ARABIC_CI_AI 
	)     
	INSERT INTO #Result2      
	SELECT    
		case @UnifyQty when 0 then [bu].[biGuid] else 0x00 end,  
		[bu].[mtGUID], 
		case @UnifyQty when 0 then [bu].[buGuid] else 0x00 end,    
		case @UnifyQty when 0 then [bu].[CustGuid] else 0x00 end,  
		[t].[Type],  
		[t].[PostQty],  
		case @UnifyQty WHEN 0 then [biPrice] ELSE 0.00 END,   
		case @UnifyQty WHEN 0 then [billUnit] Else 0 END,   
		case @UnifyQty WHEN 0 then [billUnitFact] Else 0 END,     
		SUM([oriQty]  / CASE @Unity     
						WHEN 2 THEN CASE ISNULL( [mt].[mtUnit2Fact], 0) WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END    
						WHEN 3 THEN CASE ISNULL( [mt].[mtUnit3Fact], 0) WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END    
						WHEN 4 THEN CASE ISNULL( [mt].[mtDefUnitFact], 0) WHEN 0 THEN 1 ELSE [mt].[mtDefUnitFact] END   
						ELSE 1 END) as [oriQty],   
		SUM([biQty]) AS [biQty],      
		case @UnifyQty WHEN 0 then [buFormatedNumber] ELSE '' END,   
		case @UnifyQty WHEN 0 then [buLatinFormatedNumber] ELSE '' END,   
		case @UnifyQty WHEN 0 then [buCust_Name] ELSE '' END,   
		case @UnifyQty WHEN 0 then [buDate] else '01-01-1980' END,   
		case @UnifyQty when 0 then [oriDate] else '01-01-1980' end as [oriDate],   
		case @UnifyQty when 0 then [oriNotes] else '' end as [oriNotes],   
		case @UnifyQty when 0 then [t].[Name]  else '' end as [oriTypeName],   
		case @UnifyQty when 0 then [t].[LatinName]  else '' end as [oriTypeLatinName],  
 		case @UnifyQty when 0 then [ori].[oriNumber]  else 0 end as [oriNumber] 
--		,case @UnifyQty when 0 then [ShipType]  else '' end as [ShipType],   
--		case @UnifyQty when 0 then [ShipeCompany]  else '' end as [ShipeCompany] ,   
--		case @UnifyQty when 0 then [ReceiveCondition]  else '' end as [ReceiveCondition],  
--		case @UnifyQty when 0 then [ReceiveDate]  else '' end as [ReceiveDate],  
--		case @UnifyQty when 0 then [OrderNumber]  else '' end as [OrderNumber] 	  
		  
	FROM      
		[#Result] AS [bu]   
		INNER JOIN [vwMt] AS [mt] ON [Bu].[mtGuid] = [mt].[mtGuid]   
		INNER JOIN   
			( SELECT   
				[o].[oriPOIGuid],   
				[o].[oriTypeGuid],   
				SUM( [o].[oriQty]) AS [oriQty],   
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [o].[oriDate] ELSE '01-01-1980' END AS [oriDate],   
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [o].[oriNotes] ELSE '' END AS [oriNotes] ,  
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [o].[oriNumber] ELSE 0 END AS [oriNumber] 
			 	FROM   
				[vwORI][o] WHERE oriQty > 0 
				AND o.oriDate BETWEEN @StartDate AND @EndDate	 
				  
						  
			GROUP BY   
				[oriPOIGuid],   
				[o].[oriTypeGuid],   
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [oriDate] ELSE '01-01-1980' END,  
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [oriNumber] ELSE 0 END,  
				CASE WHEN @UnifyQty = 0 /*and @Unify = 1*/ THEN [oriNotes] ELSE '' END   
			) AS [ori]   
		ON [ori].[oriPOIGuid] = [bu].[biGuid]   
		inner join @TypeTbl [t] on isnull( [ori].[oriTypeGuid],0x0) = [t].[Type] 		  
	GROUP BY   
		case @UnifyQty when 0 then [bu].[biGuid] else 0x00 end,  
		[bu].[mtGUID],  
		case @UnifyQty when 0 then [bu].[buGuid] else 0x00 end,    
		case @UnifyQty when 0 then [bu].[CustGuid] else 0x00 end,   
		[t].[Type],  
		[t].[PostQty],  
		case @UnifyQty WHEN 0 then [biPrice] ELSE 0.00 END,   
		case @UnifyQty WHEN 0 then [billUnit] Else 0 END,   
		case @UnifyQty WHEN 0 then [billUnitFact] Else 0 END,     
		case @UnifyQty WHEN 0 then [buFormatedNumber] ELSE '' END, 
  		case @UnifyQty WHEN 0 then [buLatinFormatedNumber] ELSE '' END, 
		case @UnifyQty WHEN 0 then [buCust_Name] ELSE '' END,   
		case @UnifyQty WHEN 0 then [buDate] else '01-01-1980' END,   
		case @UnifyQty WHEN 0 then [oriDate] else '01-01-1980' END,   
		case @UnifyQty WHEN 0 then [oriNumber] else 0 END, 
		case @UnifyQty WHEN 0 then [oriNotes] else '' end,   
		case @UnifyQty WHEN 0 then [t].[Name]  else '' END,   
		case @UnifyQty WHEN 0 then [t].[LatinName]  else '' end   
--		,case @UnifyQty WHEN 0 then [OrderNumber]  else '' end,   
--		case @UnifyQty WHEN 0 then [ShipType]  else '' end,   
--		case @UnifyQty WHEN 0 then [ShipeCompany]  else '' end,   
--		case @UnifyQty WHEN 0 then [ReceiveCondition]  else '' end,  
--		case @UnifyQty WHEN 0 then [ReceiveDate]  else '' end  
	--------------------------------------------------------------------------
	EXEC GetCustFlds  @CustFldsFlag,  @CustCFlds 
	EXEC GetOrderFlds @OrderFldsFlag, @OrderCFlds  
	
	DECLARE @SelectStr AS NVARCHAR(max)
	SET @SelectStr = '
		SELECT    
			[Res].[biGuid],  
			[Res].[MtGUID],  
			[Res].[buGuid],  
			[Res].[CustGUID], 
			[Res].[oriTypeGuid],  
			[Res].[oriTypeNUmber],   
			[Res].[biPrice],   
			[Res].[billUnit],   
			[Res].[billUnitFact],   
			[Res].[oriQty],   
			[Res].[biQty],     
			[Res].[buFormatedNumber],  
			[Res].[buLatinFormatedNumber],  
			[Res].[buCust_Name],   
			[Res].[buDate],   
			[Res].[oriDate],   
			[Res].[oriNotes],   
			[Res].[oriTypeName],   
			[Res].[oriTypeLatinName], 
  			[Res].[oriNumber],
			[mt].[MtCode],   
			[mt].[MtName] AS [MtName],   
			[mt].[MtLatinName] AS [MtLatinName],   
			[mt].[MtBarCode],      
			[mt].[MtBarCode2],      
			[mt].[MtBarCode3],'      
		IF @Unity = 2	  
			SET @SelectStr = @SelectStr + '[mt].[MtUnit2] AS [MtDefUnitName],'      
		ELSE IF @Unity = 3	  
			SET @SelectStr = @SelectStr + '[mt].[MtUnit3] AS [MtDefUnitName],'      
		ELSE IF @Unity = 4	  
			SET @SelectStr = @SelectStr + '[mt].[MtDefUnitName] AS [MtDefUnitName],'      
		ELSE
			SET @SelectStr = @SelectStr + '[mt].[MtUnity] AS [MtDefUnitName],'
			
		SET @SelectStr = @SelectStr + 
		   '[mt].[MtType],   
			[mt].[MtSpec],      
			[mt].[MtDim],      
			[mt].[MtOrigin],      
			[mt].[MtPos],      
			[mt].[MtGroup],      
			[mt].[grName] AS [MtGrpName],   
			[mt].[MtCompany],      
			[mt].[MtColor],      
			[mt].[MtProvenance],      
			[mt].[MtQuality],      
			[mt].[MtModel],      
			[mt].[MtQty] / '
      
		IF @Unity = 2	  
			SET @SelectStr = @SelectStr + 'CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END AS [MtQty]'      
		ELSE IF @Unity = 3	  
			SET @SelectStr = @SelectStr + 'CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END AS [MtQty]'      
		ELSE IF @Unity = 4	  
			SET @SelectStr = @SelectStr + 'CASE [mt].[MtDefUnitFact] WHEN 0 THEN 1 ELSE [mt].[MtDefUnitFact] END AS [MtQty]'      
		ELSE
			SET @SelectStr = @SelectStr + '1 AS [MtQty]'
	IF @MatCFlds <> ''	  
		SET @SelectStr = @SelectStr + @MatCFlds
		
	SET @SelectStr = @SelectStr +
		' INTO ##Result3
		 FROM    
			#Result2 [Res] inner join [vwMtGr] [mt] ON [Res].[mtGuid] = [mt].[mtGuid]'

	DECLARE	@CF_Table NVARCHAR(255)  
	SET @CF_Table = ''
	IF @MatCFlds  <> '' 
	BEGIN		 
		SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000')  -- Mapping Table	  
		SET @SelectStr = @SelectStr + ' LEFT JOIN ' + @CF_Table + ' mt_' + @CF_Table + ' ON mt.mtGuid = mt_' + @CF_Table + '.Orginal_Guid ' 	   
	END 
		
	SET @SelectStr = @SelectStr +
		'ORDER BY      
			[mt].[MtName],      
			[Res].[budate], 
			[Res].[buFormatedNumber],   
			[Res].[oriDate],  
			[Res].[oriNumber], 
			[Res].[oriTypeNumber]'
	
	EXEC (@SelectStr)
	IF @UnifyQty = 0
	BEGIN 
		SELECT Res.*, C.*, O.*
		INTO #U
		FROM    
			##Result3 [Res] LEFT  JOIN ##CustFlds  C ON C.CustFldGUid  = Res.CustGuid
						   INNER JOIN ##OrderFlds O ON O.OrderFldGuid = Res.buGuid
		
		SELECT DISTINCT * FROM #U
		ORDER BY      
			[MtName],      
			[budate], 
			[buFormatedNumber],   
			[oriDate],  
			[oriNumber], 
			[oriTypeNumber]
	END
	ELSE
		SELECT * 
		FROM ##Result3
		ORDER BY      
			[MtName],      
			[budate], 
			[buFormatedNumber],   
			[oriDate],  
			[oriNumber], 
			[oriTypeNumber]
	DROP TABLE ##Result3 
	*/
##################################################
#END