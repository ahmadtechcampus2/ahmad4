##########################################################################
CREATE PROCEDURE repGetStoreSalesCompareStore
	@srcGuid		UNIQUEIDENTIFIER,
	@GrpGuid		UNIQUEIDENTIFIER,
	@MtGuid			UNIQUEIDENTIFIER,
	@MtCondGuid		UNIQUEIDENTIFIER,
	@FromDate		DATETIME,
	@EndDate		DATETIME,
	@Store			UNIQUEIDENTIFIER,
	@SecoundStore		UNIQUEIDENTIFIER,
	@coGuid			UNIQUEIDENTIFIER,
	@UseUnit		INT,
	@Sort			INT = 0,
	@Posted			INT  = -1,
	@Lang			BIT = 0,
	@ShwEmpty		BIT = 0,
	@ShwEmptystk		BIT = 0
AS
	SET NOCOUNT ON
	DECLARE @ReadMatSecBal	INT,@Sql	NVARCHAR(max),@Zero FLOAT
	SET @Zero = [dbo].[fnGetZeroValueQTY]()
	SET @ReadMatSecBal = [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGUID]() ) 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], mtSecurity [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#SrcStoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#SecoundStoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MtGuid, @GrpGuid ,-1,@MtCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@srcGuid 
	INSERT INTO [#SrcStoreTbl]		EXEC [prcGetStoresList] 		@Store
	INSERT INTO [#SecoundStoreTbl]	EXEC [prcGetStoresList] 		@SecoundStore 	 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@coGuid
	IF @coGuid = 0X00
		INSERT  #CostTbl VALUES(0X00,0)
	CREATE TABLE [#Result] 
	( 
		[biMatPtr]				[UNIQUEIDENTIFIER], 
		[biQty]					[FLOAT],
		[bistk]					[FLOAT] DEFAULT 0,
		[stQty]					[FLOAT] DEFAULT 0,
		[Security]				[INT], 
		[UserSecurity] 			[INT], 
		[MtSecurity]			[INT],
		[Unit]					NVARCHAR(256) COLLATE ARABIC_CI_AI,
		[Unity]					INT,
		BarCode					NVARCHAR(256) COLLATE ARABIC_CI_AI
	) 
	SELECT [MatGUID] , mtSecurity ,
	CASE @UseUnit WHEN 0 THEN 1  
		WHEN 1 THEN 2  
		WHEN 2 THEN 3  
		ELSE  
			CASE [DefUnit]  
				WHEN 1 THEN 1  
				WHEN 2 THEN 2  
				ELSE 3  			   
			END  
		END Unity,
	CASE @UseUnit WHEN 0 THEN 1  
		WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
		WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
		ELSE  
			CASE [DefUnit]  
				WHEN 1 THEN 1  
				WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
				ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  				   
			END  
		END UnitFact,
	CASE @UseUnit WHEN 0 THEN Unity  
		WHEN 1 THEN [Unit2] 
		WHEN 2 THEN [Unit3]
		ELSE  
			CASE [DefUnit]  
				WHEN 1 THEN Unity  
				WHEN 2 THEN [Unit2]  
				ELSE [Unit3]  			   
			END  
		END UnitName,
	CASE @UseUnit WHEN 0 THEN BarCode  
		WHEN 1 THEN BarCode2 
		WHEN 2 THEN BarCode3
		ELSE  
			CASE [DefUnit]  
				WHEN 1 THEN BarCode  
				WHEN 2 THEN BarCode2  
				ELSE BarCode3  			   
			END  
		END BarCode
	INTO #MatTbl2
	FROM [#MatTbl] A INNER JOIN [mt000] b ON b.Guid = [MatGUID]
	--------------------------------------------------------------------------------------------------
	INSERT INTO [#Result]([biMatPtr],[biQty],[bistk],[Security],[UserSecurity],[MtSecurity],[Unit],[Unity],BarCode) 
	SELECT [biMatPtr],SUM([btIsOutput]*([biQty] + [biBonusQnt])/UnitFact),0,[Security],CASE [bi].[buIsPosted] WHEN 1 THEN [c].[UserSecurity] ELSE [UnPostedSecurity] END,b.mtSecurity,b.UnitName,b.[Unity],b.BarCode
	FROM [vwbubi] [bi] INNER JOIN #MatTbl2 b ON [MatGUID] = [biMatPtr]
	INNER JOIN [#SrcStoreTbl] s ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#BillsTypesTbl] c ON  [TypeGuid] = [buType]
	WHERE [buDate] BETWEEN @FromDate AND @EndDate AND (@Posted = -1 OR @Posted = buIsPosted)
	GROUP BY [biMatPtr],[Security],CASE [bi].[buIsPosted] WHEN 1 THEN [c].[UserSecurity] ELSE [UnPostedSecurity] END,b.mtSecurity,b.UnitName,b.[Unity],BarCode
	--------------------------------------------------------------------------------------------------
	TRUNCATE TABLE #BillsTypesTbl
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	0x00 
	--------------------------------------------------------------------------------------------------
	INSERT INTO [#Result]([biMatPtr],[biQty],[bistk],[Security],[UserSecurity],[MtSecurity],[Unit],[Unity],BarCode) 
		SELECT [biMatPtr],0,SUM([buDirection] * ([biQty] + [biBonusQnt]) / UnitFact),CASE WHEN @ReadMatSecBal > b.mtSecurity THEN 0 ELSE [Security] END,CASE [bi].[buIsPosted] WHEN 1 THEN [c].[UserSecurity] ELSE [UnPostedSecurity] END,b.mtSecurity,b.UnitName,b.[Unity],BarCode
	FROM [vwbubi] [bi] INNER JOIN  #MatTbl2 b ON [MatGUID] = [biMatPtr]
	INNER JOIN [#SecoundStoreTbl] s ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#BillsTypesTbl] c ON  [TypeGuid] = [buType]
	WHERE (@Posted = -1 OR @Posted = buIsPosted)
	GROUP BY
	[biMatPtr],CASE WHEN @ReadMatSecBal > b.mtSecurity THEN 0 ELSE [Security] END,CASE [bi].[buIsPosted] WHEN 1 THEN [c].[UserSecurity] ELSE [UnPostedSecurity] END,b.mtSecurity,b.UnitName,b.[Unity],BarCode
	--------------------------------------------------------------------------------------------------
	INSERT INTO [#Result]([biMatPtr],[biQty],[stQty],[Security],[UserSecurity],[MtSecurity],[Unit],[Unity],BarCode) 
		SELECT [biMatPtr],0,SUM([buDirection] * ([biQty] + [biBonusQnt]) /UnitFact),CASE WHEN @ReadMatSecBal > b.mtSecurity THEN 0 ELSE [Security] END,[UserReadPriceSecurity],b.mtSecurity,b.UnitName,b.[Unity],BarCode
	FROM [vwbubi] [bi] INNER JOIN  #MatTbl2 b ON [MatGUID] = [biMatPtr]
	INNER JOIN [#SrcStoreTbl] s ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#BillsTypesTbl] c ON  [TypeGuid] = [buType]
	WHERE (@Posted = -1 OR @Posted = buIsPosted)
	GROUP BY
		[biMatPtr],CASE WHEN @ReadMatSecBal > b.mtSecurity THEN 0 ELSE [Security] END,[UserReadPriceSecurity],b.mtSecurity,b.UnitName,b.[Unity],BarCode
	--------------------------------------------------------------------------------------------------
	EXEC [prcCheckSecurity] 
	SELECT [biMatPtr],SUM([biQty])[Qty],SUM([bistk])[StkQty],SUM([stQty]) [stQty],[Unit],[Unity],BarCode
	INTO #EndResult	
	FROM #Result
	GROUP BY  [biMatPtr],[Unit],[Unity],BarCode
	--------------------------------------------------------------------------------------------------
	Declare @CF_Table NVARCHAR(255) --Mapped Table for Custom Fields
	SET @Sql = ' SELECT [biMatPtr],r.[Qty],r.[StkQty],r.[stQty],[Unit],r.[Unity],[mt].[Code] [MtCode],'
	SET @Sql = @Sql + '[mt].Name [MtName],[mt].LatinName [MtLatinName],[mt].CompositionName [MtCompositionName],[mt].CompositionLatinName [MtCompositionLatinName]'
	
		+ ',[mt].Spec [MtSpec]'
		+ ',[mt].Origin [MtOrigin]'
		+ ',[mt].Company [MtCompany]'
		+ ',[mt].Pos [MtPos]'
		+ ',[mt].Dim [MtDim]'
		+ ',[mt].Color [MtColor]'
		+ ',[mt].[Provenance] AS [MtProvenance]'
		+ ',[mt].[Model] AS [MtModel]'
		+ ',[mt].[Quality] AS [MtQuality]'
		+ ',[r].BarCode [MtBarCode]'
		+ ',[mt].Type [MtType1]'
		+ ',[mt].[Vat] [MtVAT]'
		+ ',[gr].Code [MtGroupCode]'
		IF @Lang = 0
			SET @Sql = @Sql + ',[gr].Name [MtGroupName]'
		ELSE
			SET @Sql = @Sql + ',CASE [gr].LatinName WHEN '''' THEN [gr].Name ELSE [gr].LatinName END [MtGroupName]'
	------------------------------------------------------------------------------------------------------ 
 
	SET @Sql = @Sql + ' FROM #EndResult r INNER JOIN mt000 mt ON mt.Guid = [biMatPtr]'
	------------------------------------------------------------------------------------------------------- 
		SET @Sql = @Sql + ' INNER JOIN [gr000] gr ON gr.Guid = mt.GroupGuid'
	IF @ShwEmpty = 0
		SET @Sql = @Sql + ' WHERE ABS(r.[Qty]) > ' + CAST(@Zero AS NVARCHAR(10)) 
	IF @ShwEmptystk = 0 
	BEGIN
		IF @ShwEmpty = 0
			SET @Sql = @Sql + ' AND '
		ELSE
			SET @Sql = @Sql + ' WHERE '
		SET @Sql = @Sql + ' ABS(r.[StkQty]) >' + CAST(@Zero AS NVARCHAR(10)) 
	END
	SET @Sql = @Sql + ' ORDER BY  '
	IF @Sort = 0
		SET @Sql = @Sql + '[mt].[Code] '
	ELSE IF @Sort = 1
		SET @Sql =  @Sql + '[mt].Name'
	ELSE IF @Sort = 2
		SET @Sql =  @Sql + '[mt].LatinName'	
	ELSE IF @Sort = 3
		SET @Sql =  @Sql + '[mt].Type'	
	ELSE IF @Sort = 4
		SET @Sql =  @Sql + '[mt].Spec'	
	ELSE IF @Sort = 5
		SET @Sql =  @Sql + '[mt].Color'
	ELSE IF @Sort = 6
		SET @Sql =  @Sql + '[mt].Origin '	
	ELSE IF @Sort = 7
		SET @Sql =  @Sql + '[mt].Dim '	
	ELSE IF @Sort = 8
		SET @Sql =  @Sql + '[mt].Company '	
	ELSE
		SET @Sql =  @Sql + '[r].BarCode '
	
	------------------------------------------------------------------------------------------------------ 
	EXEC(@Sql)
	SELECT * FROM [#SecViol]
/*
	prcConnections_add2 'Œ«·œ'
	exec  [repGetStoreSalesCompareStore] 'abb101d3-d1c9-4151-98be-4919f5f21db5', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '1/1/2009 0:0:0.0', '1/1/2009 0:0:0.0', '16b2f73d-92c4-4cc9-aaff-2754655d9f39', '829507db-9160-4c52-876b-adb95494ccbd', 0, '00000000-0000-0000-0000-000000000000', 3, 0, 1, 0, 0, 0, ''
*/
###############################################################################
#END

		
