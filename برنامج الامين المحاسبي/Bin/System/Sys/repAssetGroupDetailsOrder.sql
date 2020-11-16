######################################################################
CREATE TRIGGER trg_ad000_ui
	ON [ad000] FOR INSERT, UPDATE 
	NOT FOR REPLICATION
AS  
	IF @@ROWCOUNT = 0 
		RETURN 
	UPDATE SNC000 SET SN = ad.SN FROM [inserted] AS ad INNER JOIN SNC000 snc ON snc.Guid = ad.snGuid
######################################################################
CREATE  VIEW vwadas
AS
SELECT
	ad.adGuid Guid,
	ad.adinVal InVal,
	ad.adSn +'-'+CASE dbo.fnConnections_GetLanguage() WHEN 1 THEN ass.asName ELSE CASE ass.asLatinName WHEN '' THEN  ass.asName ELSE ass.asLatinName END END adCodeName,  
	ad.adSn Code, 
	ass.asName [Name],
	ass.asLatinName [LatinName],
	*
	FROM	vwad AS ad   
			INNER JOIN vwas AS ass   ON ad.adAssGuid = ass.asGuid
######################################################################
CREATE VIEW VWAssTrans_Details
AS
SELECT     d.GUID, 
		   d.Number, 
		   d.ParentGUID, 
		   d.adGuid, 
		   ass.Code + '-' + ass.Name as adCodeName, 
		   d.SourceStore, 
           st0.Code + '-' + st0.Name as SourceStoreCodeName, 
		   d.DestinationStore, 
           st1.Code + '-' + st1.Name as DestinationStoreCodeName, 
           d.AssVal, 
           d.AssDep, 
		   d.Notes,
		   d.SourceCost,
           co0.Code + '-' + co0.Name as SourceCostCodeName, 
		   d.DestinationCost,
           co1.Code + '-' + co1.Name as DestinationCostCodeName 
FROM         assTransferDetails000 d 
			INNER JOIN vwadas AS ass ON d.adGuid = ass.Guid  
			INNER JOIN st000  AS st0  ON d.SourceStore = st0.GUID  
			INNER JOIN st000  AS st1  ON d.DestinationStore = st1.GUID 
			LEFT JOIN co000  AS co0  ON d.SourceCost = co0.GUID  
			LEFT JOIN co000  AS co1  ON d.DestinationCost = co1.GUID
######################################################################
CREATE VIEW VwAd_Struct
AS
SELECT     sn.SN, mt.Name AS MatName, mt.LatinName AS LatinMatName, ad.GUID AS Guid, ad.[BrGuid] AS BranchGuid
FROM         dbo.ad000 AS ad INNER JOIN
                      dbo.as000 AS ass ON ass.GUID = ad.ParentGUID INNER JOIN
                      dbo.mt000 AS mt ON ass.ParentGUID = mt.GUID INNER JOIN
                      dbo.snc000 AS sn ON sn.GUID = ad.SnGuid
					  JOIN vfBr ON ad.[BrGuid] = vfBr.[GUID]
WHERE     (sn.Qty > 0)	
######################################################################
CREATE VIEW VwAd_Struct1
AS
SELECT     sn.SN, mt.GUID AS MatGuid, mt.Name AS MatName, mt.LatinName AS LatinMatName, ad.GUID AS Guid, ad.[BrGuid] AS BranchGuid
FROM         dbo.ad000 AS ad INNER JOIN
                      dbo.as000 AS ass ON ass.GUID = ad.ParentGUID INNER JOIN
                      dbo.mt000 AS mt ON ass.ParentGUID = mt.GUID INNER JOIN
                      dbo.snc000 AS sn ON sn.GUID = ad.SnGuid
WHERE     (sn.Qty > 0)	
######################################################################
CREATE VIEW VwAdWithExcluded_Struct
AS
SELECT     ad.SN, mt.Name AS MatName, mt.LatinName AS LatinMatName, ad.GUID AS Guid, ad.[BrGuid] AS BranchGuid
FROM         dbo.ad000 AS ad INNER JOIN
                      dbo.as000 AS ass ON ass.GUID = ad.ParentGUID INNER JOIN
                      dbo.mt000 AS mt ON ass.ParentGUID = mt.GUID 
					  JOIN vfBr ON ad.[BrGuid] = vfBr.[GUID]
######################################################################
CREATE VIEW VwAdWithExcluded_Struct1
AS
SELECT     ad.SN, mt.GUID AS MatGuid, mt.Name AS MatName, mt.LatinName AS LatinMatName, ad.GUID AS Guid, ad.[BrGuid] AS BranchGuid
FROM         dbo.ad000 AS ad INNER JOIN
                      dbo.as000 AS ass ON ass.GUID = ad.ParentGUID INNER JOIN
                      dbo.mt000 AS mt ON ass.ParentGUID = mt.GUID 
######################################################################
CREATE VIEW VWAssTrans
AS
SELECT * FROM AssTransferHeader000
######################################################################
CREATE PROCEDURE PrcGetSnForAssets
	@MatGUID 	[UNIQUEIDENTIFIER] = 0x0,
	@GroupGUID 	[UNIQUEIDENTIFIER] = 0x0,
	@StoreGUID 	[UNIQUEIDENTIFIER] = 0x0 ,  --0 all stores so don't check store or list of stores
	@Src		[UNIQUEIDENTIFIER] = 0x0 ,
	@Lang		[BIT] = 0,
	@ShowCust	[BIT] = 0,
	@MatCondGuid [UNIQUEIDENTIFIER] = 0x0,
	@CostGUID 	 [UNIQUEIDENTIFIER] = 0x0
AS	SET NOCOUNT ON
	DECLARE @CNT INT
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	--Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @Src--'ALL'
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGuid
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID
	
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	CREATE TABLE [#ResultSN]
	(
		--[SN] 						[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[Id]						[INT] IDENTITY(1,1),
		[MatPtr]					[UNIQUEIDENTIFIER] ,
		[MtName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[biStorePtr]				[UNIQUEIDENTIFIER] ,
		[stName]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buNumber]					[UNIQUEIDENTIFIER] ,
		[biPrice]					[FLOAT],
		[Security]					[INT],
		[UserSecurity] 				[INT],
		[UserReadPriceSecurity]		[INT],
		[BillNumber]				[FLOAT],
		[buDate]					[DATETIME],
		[buType]					[UNIQUEIDENTIFIER],
		[buBranch]					[UNIQUEIDENTIFIER],
		[buCust_Name]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[buCustPtr]					[UNIQUEIDENTIFIER],
		[biCostPtr]					[UNIQUEIDENTIFIER],
		[MatSecurity] 				[INT],
		[biGuid]					[UNIQUEIDENTIFIER],
		[buDirection]				[INT]
	)
	SELECT [StoreGuid], [s].[Security],CASE @Lang WHEN 0 THEN [st].[Name] ELSE CASE [st].[LatinName]  WHEN '' THEN [st].[Name] ELSE [st].[LatinName] END END AS [stName] INTO [#StoreTbl2] FROM [#StoreTbl] AS [s] INNER JOIN  [st000] AS [st] ON  [st].[Guid] = 	[StoreGuid]
	SELECT [MatGuid]  , [m].[mtSecurity],[mt].[Name] AS [MtName] INTO [#MatTbl2] FROM [#MatTbl] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [MatGuid] WHERE [mt].[snFlag] = 1
	INSERT INTO [#ResultSN]
	(
		[MatPtr],[MtName],[biStorePtr],[stName],[buNumber],				
		[biPrice],[Security],[UserSecurity],			
		[UserReadPriceSecurity],[BillNumber],			
		[buDate],[buType],[buBranch],[buCust_Name],			
		[buCustPtr],[biCostPtr],[MatSecurity],[biGuid],[buDirection]			
	)
	SELECT
		--[sn].[SN],
		[mtTbl].[MatGuid],
		[mtTbl].[MtName],
		[bu].[biStorePtr],
		[st].[stName],
		[bu].[buGUID],
		CASE WHEN [UserReadPriceSecurity] >= [bu].[BuSecurity] THEN [bu].[biPrice] ELSE 0 END,
		[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[buNumber],
		[buDate],
		[buType],
		[buBranch],
		[buCust_Name],
		CASE WHEN (@Lang > 0 AND @ShowCust > 0) THEN [buCustPtr] ELSE NULL END,
		[biCostPtr],
		[mtTbl].[mtSecurity],[biGuid],[buDirection]
	FROM
		--[SN000] AS [sn] 
		[vwBUbi] AS [bu] --ON [bu].[biGUID] = [sn].[InGuid]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bu].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bu].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGuid] = [bu].[biStorePtr]
		INNER JOIN  [#CostTbl] AS [co] ON [co].[CostGUID] = [bu].[biCostPtr]
	WHERE
		 [bu].[buIsPosted] != 0
	ORDER BY
		[MatGuid],[buDate],[buSortFlag],[buNumber]


---check sec
	CREATE CLUSTERED INDEX SERIN ON #ResultSN(ID,[biGuid])
	EXEC [prcCheckSecurity]
	IF @Lang > 0 AND @ShowCust > 0
		UPDATE [r] SET [buCust_Name] = [LatinName] FROM [#ResultSN] AS [r] INNER  JOIN [cu000] AS [Cu] ON [r].[buCustPtr] = [cu].[GUID] WHERE [LatinName] <> ''

	SELECT  MAX([Id]) AS ID ,SUM(buDirection) AS cnt ,[ParentGuid] INTO [#sn] FROM [snt000] AS [sn] INNER JOIN [#ResultSN] [r] ON [sn].[biGuid] = [r].[biGuid] GROUP BY [ParentGuid],[stGuid] HAVING SUM(buDirection) > 0
	CREATE TABLE [#Isn2]
	(
		[SNID] [INT] IDENTITY(1,1),
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)
	CREATE TABLE [#Isn]
	(
		[SNID] [INT] ,
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)

	
	INSERT INTO [#Isn2] ([Guid],[id],[cnt],[SN],[Length]) SELECT   Guid,[ID] ,[cnt],[SN],LEN([SN])  FROM [#sn] INNER JOIN [snC000] ON [Guid] = [ParentGuid] ORDER BY SN
	INSERT INTO  #Isn SELECT *  FROM [#Isn2]
	IF EXISTS(SELECT * FROM [#Isn] WHERE [cnt] > 1)
	BEGIN
		SET @CNT = 1 
		WHILE (@CNT > 0)
		BEGIN
			INSERT INTO [#Isn] 
			SELECT  SNID, MAX([R].[Id]), 1, [I].[Guid], [sn].[SN], [Length]  
			FROM [vcSNs] AS [sn] 	INNER JOIN [#ResultSN] [R] ON [sn].[biGuid] = [R].[biGuid] 
									INNER JOIN [#Isn] I ON [sn].[Guid] = [I].[Guid]  
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM [#Isn]) 
			GROUP BY [sn].[SN],[SNID],[Length],[I].[Guid]
			UPDATE [#Isn] SET [cnt] = [cnt] - 1 WHERE [cnt] > 1
			SET @CNT = @@ROWCOUNT
		END
	END
	--- Return first Result Set -- needed data
	INSERT INTO  #SNALL (
				Sn, 
				SNGuid, 
				MatGUID,
				MatName,
				StoreGUID,
				StoreName,
				BillTypeGUID,
				BillGUID,
				CustomerName,
				BillDate,
				BillPrice,
				BillNumber,
				BillBranchGUID,
				CostGUID
				)
	SELECT
		[SN].[SN],
		[SN].[GUID], 
		[r].[MatPtr],
		[r].[MtName],
		[r].[biStorePtr],
		[r].[StName],
		[r].[buType],
		[r].[buNumber],
		[r].[buCust_Name],
		[r].[buDate],
		[r].[biPrice],
		[r].[BillNumber],
		[r].[buBranch],
		[r].[biCostPtr] CostGUID
	FROM
		[#ResultSN] AS [r] INNER JOIN [#ISN] AS [SN] ON [sn].[Id] = [r].[Id]
	ORDER BY
		[r].[ID],
		[Length],
		[SNID]

/*
	exec PrcGetSnForAssets 0x0, 0x0, 0x0,	0x0, 0,	0, 0x0,	0x0
	select * from #SNAll

	prcConnections_add2 '„œÌ—'

	EXEC  [repMatSN] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0x00, 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000'


*/
#####################################################################################
CREATE  Function fnGetLastSn2()
	returns @snt table 
	(
		biguid 	   uniqueidentifier ,  
		biCostGuid uniqueidentifier ,  
		[id] int ,
		sn NVARCHAR(250)	COLLATE Arabic_CI_AI 
	)

As
 BEGIN
	declare  @bu table (ID int identity(1,1), biCostGuid uniqueidentifier, biGuid uniqueidentifier)
	insert into @bu  
	(biCostGuid,biGuid) select biCostptr, biGuid from vwbubi order by buDate, busortflag, buNumber

	declare @nsn table 
		(
		    [id] int , sn NVARCHAR(250)	COLLATE Arabic_CI_AI ,
		    matguid uniqueidentifier, cnt int
		)	
	insert into @nsn	
	select max(id) as [ID], sn.sn , matGuid, count(1) as Cnt 
	--into @nsn
	from sn000 sn  inner join @bu bu on sn.InGuid = bu.biGuid
	group by sn.sn , matGuid

	declare @osn table 
		(
		    sn NVARCHAR(250)	COLLATE Arabic_CI_AI ,
		    matguid uniqueidentifier, cnt int
		)

	insert into @osn
	select sn.sn , matGuid, count(1) as Cnt 
	--into @osn
	from sn000 sn  inner join @bu bu on sn.outGuid = bu.biGuid
	group by sn.sn , matGuid

	--select sum(ad.inVal)
	insert into @snt 
	select	biGuid, b.biCostGuid, n.id, n.sn 
	from  @nsn n left join @osn o  on n.sn = o.sn and n.matGuid  = o.matGuid
	inner join @bu b on b.id = n.id
	inner join ad000 ad on ad.sn = n.sn
	where (n.cnt - isnull(o.Cnt, 0))  > 0 

RETURN
END
#####################################################################################
CREATE PROC repAssetGroupDetailsOrder
                      @GrpGUID UNIQUEIDENTIFIER   = 0x0,									--1    
            @AssGUID UNIQUEIDENTIFIER   = 0x0,									--2   
            @StoreGUID UNIQUEIDENTIFIER = 0x0,									--3   
            @SupplierName NVARCHAR (200) = '',									--4   
            @StartDate									 DATETIME = '1980-1-1',	--5         
            @EndDate									 DATETIME = '2050-1-1', --6      
            @From_purchaseOrderDate                      DATETIME = '1980-1-1', --7        
            @To_purchaseOrderDate                        DATETIME = '1980-1-1', --8        
            @From_GUARANTEE_BEGINDATE					 DATETIME = '1980-1-1', --9        
            @To_GUARANTEE_BEGINDATE                      DATETIME = '1980-1-1', --10      
            @From_GUARANTEE_ENDDATE                      DATETIME = '1980-1-1', --11      
            @To_GUARANTEE_ENDDATE						 DATETIME = '1980-1-1', --12      
            @From_ContractGuarantyDate					 DATETIME = '1980-1-1', --13      
            @To_ContractGuarantyDate					 DATETIME = '1980-1-1', --14      
            @From_ContractGuarantyEndDate				 DATETIME = '1980-1-1', --15      
            @To_ContractGuarantyEndDate					 DATETIME = '1980-1-1', --16      
            @CostGuid                               UNIQUEIDENTIFIER = 0x0,		--17   
            @SN                                        NVARCHAR(250) = '',		--18   
            @BarCode                                NVARCHAR(250) = '',			--19   
            @ToDate DateTime    = '2050-1-1',									--20   
            @CurGuid UNIQUEIDENTIFIER = 0x0,									--21   
            @AdGuid UNIQUEIDENTIFIER = 0x0,										--22   
			@ShowZeroAssets	INT	= 0,											--23  
			@ShowGroup	INT	= 0,												--24
			@Grouping	INT	= 0,												--25
			@IsCalledByTransCard	INT	= 1,									--26 // Call by report or Asset Transfer Card  
			@ShowExcludeAsset	INT	= 0,										--27  
			@ShowExcludeAssetOnly	INT	= 0,									--28
			@ShowTotalDeprAssetOnly	INT = 0										--29
AS    
	SET NOCOUNT ON    
	DECLARE @Language bit
	SET @Language = (SELECT dbo.fnConnections_GetLanguage())    
	
	CREATE TABLE [#SN_lastcheck]  
	(  
		[GID]         [INT] ,[SN]     [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[SNGuid]          [UNIQUEIDENTIFIER],[MatGuid]          [UNIQUEIDENTIFIER],  
		[MatName]        [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[StoreGuid]          [UNIQUEIDENTIFIER],[StoreName]   [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[BillTypeGuid]          [UNIQUEIDENTIFIER], [BillGuid]          [UNIQUEIDENTIFIER], [CustomerName] [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[BillDate]        [DATETIME],  
		[Bill]		  [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[PRICE]       [FLOAT],[Number]      [FLOAT],[BranchGuid]  [UNIQUEIDENTIFIER],[CostGUID]    [UNIQUEIDENTIFIER],  
		[Direction]   [INT],[Gr_GUID]     [UNIQUEIDENTIFIER],[Ac_GUID]     [UNIQUEIDENTIFIER]  
	 )
	INSERT INTO [#SN_lastcheck]       ([GID],[SN],[SNGuid],[MatGuid],[MatName],[StoreGuid],[StoreName],[BillTypeGuid],[BillGuid],[CustomerName],[BillDate],[Bill],  
	[PRICE],[Number],[BranchGuid],[CostGUID],[Direction],[Gr_GUID],[Ac_GUID])      
	EXEC SN_lastcheck @AssGUID , 0x0 , 0x0 , 0x0 , '1980-1-1' , @EndDate , 0x0  
	
	DECLARE @LastStatment NVARCHAR(max)  
	CREATE TABLE [#SNALL]   
	(   
		[GID]         [INT] ,[SN]     [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[SNGuid]          [UNIQUEIDENTIFIER],[MatGuid]          [UNIQUEIDENTIFIER],   
		[MatName]        [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[StoreGuid]          [UNIQUEIDENTIFIER],[StoreName]   [NVARCHAR](255)  COLLATE ARABIC_CI_AI,   
		[BillTypeGuid]          [UNIQUEIDENTIFIER], [BillGuid]          [UNIQUEIDENTIFIER], [CustomerName] [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[BillDate]        [DATETIME],   
		[Bill]		  [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[PRICE]       [FLOAT],[Number]      [FLOAT],[BranchGuid]  [UNIQUEIDENTIFIER],[CostGUID]    [UNIQUEIDENTIFIER],   
		[Direction]   [INT],[Gr_GUID]     [UNIQUEIDENTIFIER],[Ac_GUID]     [UNIQUEIDENTIFIER], [BranchName]  [NVARCHAR](255)  COLLATE ARABIC_CI_AI   ,[IsExcludeAsset]   [INT]
	 )   
    CREATE TABLE #Result   
    (                 
		Guid UNIQUEIDENTIFIER,Code NVARCHAR(250) COLLATE ARABIC_CI_AI,Name NVARCHAR(250) COLLATE ARABIC_CI_AI,     
        LatinName NVARCHAR(250) COLLATE ARABIC_CI_AI,adAddedCurrent FLOAT,adDeductCurrent FLOAT,adMaintainCurrent FLOAT,adDeprecationCurrent FLOAT,     
        adLastDepDate DATETIME,[Type] INT,[Level] INT, mtSecurity INT,grSecurity INT, Path NVARCHAR(1000),ParentGuid UNIQUEIDENTIFIER,       
        CostGuid  UNIQUEIDENTIFIER,CostName  NVARCHAR(250) COLLATE ARABIC_CI_AI,StoreGuid  UNIQUEIDENTIFIER, StoreName  NVARCHAR(250)  COLLATE ARABIC_CI_AI,BarCode   NVARCHAR(250),ID INT IDENTITY( 1, 1),   
		asLifeExp FLOAT, BranchName  NVARCHAR(250) COLLATE ARABIC_CI_AI,[IsExcludeAsset]   [INT]
    )   
    DECLARE @MatGUID UNIQUEIDENTIFIER   
    SET @MatGUID = 0x0   
       
	IF(ISNULL( @AdGUID, 0x0) <> 0x0)   
    BEGIN   
			SELECT @MatGUID = mt.guid from ad000 ad    
						 inner join as000 ass on ass.Guid = ad.ParentGuid   
						 inner join mt000 mt on ass.ParentGuid = mt.Guid   
			WHERE ad.guid = @AdGUID   
	END   
	   
      DECLARE @BranchMask BIGINT   
		SET @BranchMask = -1  
		IF EXISTS(select ISNULL([value],0) from op000 where [name] = 'EnableBranches')  
			BEGIN  
				DECLARE @En_br BIGINT  
				SET @En_br = (select TOP 1 ISNULL([value],0) from op000 where [name] = 'EnableBranches')  
				IF (@En_br = 1)  
					SET @BranchMask = (SELECT [dbo].[fnConnections_getBranchMask] ())  
			END  
		CREATE TABLE #hsh  
		(  
		[GID]         [INT] IDENTITY(0,1),  
		[SN]     [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[SNGuid]          [UNIQUEIDENTIFIER],  
		[MatGuid]          [UNIQUEIDENTIFIER],  
		[MatName]        [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[StoreGuid]          [UNIQUEIDENTIFIER],  
		[StoreName]   [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[BillTypeGuid]          [UNIQUEIDENTIFIER],   
		[BillGuid]          [UNIQUEIDENTIFIER],   
		[CustomerName] [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[BillDate]        [DATETIME],  
		[Bill]		  [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
		[PRICE]       [FLOAT],  
		[Number]      [FLOAT],  
		[BranchGuid]  [UNIQUEIDENTIFIER],  
		[CostGUID]    [UNIQUEIDENTIFIER],  
		[Direction]   [INT],  
		[Gr_GUID]     [UNIQUEIDENTIFIER],  
		[Ac_GUID]     [UNIQUEIDENTIFIER],
		[BranchName]  [NVARCHAR](255)  COLLATE ARABIC_CI_AI 
		 )  
		INSERT INTO #hsh  
		SELECT  
			ISNULL([snc].[SN] , '') AS [SN],  
			ISNULL([snc].[GUID] , 0x0)      AS [SNGuid],  
			ISNULL([mt].[GUID] , 0x0) AS [MatGuid],	  
			ISNULL([mt].[Name],'') AS [MatName],  
			ISNULL([bi].[StoreGUID],0x0) AS [StoreGuid],  
			ISNULL(CASE [bi].[StoreGUID]   WHEN 0x0 THEN '' ELSE (SELECT NAME FROM [st000] WHERE [GUID]	= [bi].[StoreGUID]  ) END,'') AS [StoreName],  
			ISNULL([bt].[Guid] , 0x0) AS [BillTypeGuid],  
			ISNULL([bi].[GUID] , 0x0) AS [BillGuid],  
			ISNULL(CASE [bu].[CustAccGUID] WHEN 0x0 THEN '' ELSE (SELECT NAME FROM [ac000] WHERE [GUID] = [bu].[CustAccGUID]) END,'') AS [CustomerName],  
			[bu].[Date] AS [BillDate],  
			ISNULL([bt].[Abbrev] + ' ' +  CAST ([bu].[Number] AS NVARCHAR),'') AS [Bill],  
			[bi].[Price],  
			ISNULL([bu].[Number]	, 0    )   AS    [NUMBER],  
			ISNULL([bu].[Branch]    , 0x0  )   AS    [BranchGuid],  
			CASE ISNULL([bi].[CostGUID], 0x0) WHEN 0x0 THEN [bu].[CostGUID] ELSE ISNULL([bi].[CostGUID], 0x0) END   AS    [CostGUID],  
			CASE bt.BillType   
						WHEN 0 THEN  (CASE bt.Type WHEN 3 THEN -1 WHEN  4 THEN 1 ELSE 1 END )  
						WHEN 1 THEN -1  
						WHEN 2 THEN -1  
						WHEN 3 THEN  1  
						WHEN 4 THEN  1  
						WHEN 5 THEN -1  
						ELSE 0   
			END AS  [Direction],  
			ISNULL([mt].[GroupGUID]		,0x0) AS    [Gr_GUID]  ,  
			ISNULL([bu].[CustAccGUID]	,0x0) AS    [Ac_GUID]  , 
			ISNULL([br].[brName], '')		  AS	[BranchName]
		FROM [snc000] AS snc	  
			INNER JOIN [snt000]AS snt ON [snc].[GUID]    = [snt].ParentGUID  
			INNER JOIN [bu000] AS bu  ON [snt].[buGuid]  = [bu].[GUID]  
			INNER JOIN [bi000] AS bi  ON [snt].[biGUID]  = [bi].[GUID]  
			INNER JOIN [bt000] AS bt  ON [bu].[TypeGUID] = [bt].[GUID]  
			INNER JOIN [mt000] AS mt  ON [snc].[MatGUID] = [mt].[GUID]  
			LEFT  JOIN [vwbr]  AS br  ON [br].[brGUID]   = [bu].[Branch]  
		WHERE       ((@BranchMask = 0 OR  @BranchMask = -1) OR (([br].[brBranchMask] & @BranchMask) = [br].[brBranchMask]))  
				AND bu.IsPosted != 0  
		ORDER BY [BillDate], [SN], [Direction], [NUMBER]   
		------------------------------------------------------------------------------------------  
		IF    @MatGUID <> 0x0               DELETE FROM  #hsh WHERE MatGuid <> @MatGUID
		IF    @GrpGUID <> 0x0               DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].Gr_GUID   NOT IN (SELECT GUID FROM dbo.fnGetGroupsList  (@GrpGUID))  
		IF    @StoreGUID <> 0x0                DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].StoreGuid NOT IN (SELECT GUID FROM dbo.fnGetStoresList  (@StoreGUID))  
		IF    @CostGuid <> 0x0                DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].CostGUID  NOT IN (SELECT GUID FROM dbo.fnGetCostsList   (@CostGuid))  
		IF    @StartDate <> '1/1/1800'       DELETE FROM  #hsh WHERE [BillDate] < @StartDate
		IF    @EndDate <> '1/1/1800'         DELETE FROM  #hsh WHERE [BillDate] > @EndDate
		CREATE TABLE #temp1 ([SN] [NVARCHAR](255)  COLLATE ARABIC_CI_AI , _SUM [INT] , [GID] [INT])  
		INSERT INTO #temp1  
		SELECT ISNULL(SN,'') AS SN , SUM(Direction) AS [Direction] , MAX(GID) AS [GID]  
		FROM #hsh  
		GROUP BY [SN] , [MatGuid]  
		
		IF @ShowExcludeAssetOnly = 1 
		BEGIN 
			DELETE FROM #temp1 WHERE _Sum <> 0  
		END

		ELSE IF @ShowExcludeAsset <> 1
		BEGIN 
			DELETE FROM #temp1 WHERE _Sum = 0  
		END
		
		INSERT INTO [#SNALL]       ([GID],[SN],[SNGuid],[MatGuid],[MatName],[StoreGuid],[StoreName],[BillTypeGuid],[BillGuid],[CustomerName],[BillDate],[Bill],    
			[PRICE],[Number],[BranchGuid],[CostGUID],[Direction],[Gr_GUID],[Ac_GUID], [BranchName],IsExcludeAsset)
		SELECT [a].* ,
		(CASE [b]._SUM WHEN 0 THEN 1 ELSE 0 END)  
		FROM #hsh AS [a]  
		INNER JOIN #temp1 AS [b] ON [a].[GID] = [b].[GID]  
		ORDER BY [BillDate], [a].[GID], [a].[SN]
		
		SELECT DISTINCT     
			sn.[GID],sn.Sn,sn.SNGuid,sn.MatGUID,sn.MatName,   
			sn.StoreGUID AS StoreGUID,      
			sn.StoreName StoreName, sn.BillTypeGUID,sn.BillGUID,      
			sn.CustomerName,sn.BillDate,sn.Price AS BillPrice,sn.Number AS BillNumber,      
			sn.BranchGUID AS BillBranchGUID ,(SELECT SUM(VALUE) FROM dd000 WHERE ADGUID = dd.adguid GROUP BY ADGUID) AS VALUE ,sn.CostGUID, sn.BranchName,
			sn.IsExcludeAsset
		INTO #SNAll_DETAILED      
		FROM #SNAll sn    
			INNER JOIN ad000 ad on ad.snGuid     =  sn.SnGuid      
			LEFT  JOIN dd000 dd on dd.adGuid     =  ad.Guid     
			LEFT  JOIN dp000 dp on dd.ParentGuid =  dp.Guid       
			LEFT  JOIN st000 st on st.Guid       =  dd.StoreGuid 
		ORDER BY sn.[BillDate], sn.[GID], sn.[SN]
			IF ( ISNULL( @AssGUID, 0x0) <> 0x0)         
				BEGIN         
	---------------------------------------------------------------------------------------------------------------------------   
									INSERT INTO #Result      
									SELECT          
												GUID,          
												grCode,         
												grName,         
												grLatinName,         
												0,         
												0,         
												0,         
												0,         
												'1-1-1980',         
												0, -- 0 Group , 1 Asset , 2 AssetDetail         
												[Level],         
												0, -- mtSecurity         
												grSecurity,         
												[Path],         
												gr.grParent,       
												0x0,       
												'' ,       
												0x0,       
												'' ,       
												'' ,
												0  ,
												'' ,
												0    
									FROM          
												dbo.fnGetGroupsOfGroupSorted(@GrpGUID, 1)  AS fn         
												INNER JOIN vwGr AS gr ON fn.GUID = gr.grGuid         
									------------------------------------         
									--UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))         
									------------------------------------         
									INSERT INTO #Result         
									SELECT          
												asGUID,                     
												mtCode,         
												mtName,         
												mtLatinName,         
												0,         
												0,         
												0,         
												0,         
												'1-1-1980',         
												1, -- 0 Group , 1 Asset , 2 AssetDetail              
												Res.[Level],         
												mt.mtSecurity,         
												0,         
												Res.[Path],         
												mtGroup,       
												0x0,       
												'',      
												0x0,            
												'',        
												'',
												ass.asLifeExp,
												'',
												0
									FROM         
												vwAs AS ass        
												INNER JOIN vwMt AS mt ON ass.asParentGuid = mt.mtGUID         
												INNER JOIN #Result AS Res ON Res.Guid = mt.mtGroup       
									------------------------------------         
									UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) WHERE Type = 1     
	-----------------------------------------------------------------------------------------------------------------------    
							INSERT INTO #Result         
							SELECT  distinct      
										adGuid,      
										adSn,      
										'',      
										'',      
										0,      
										0,      
										0,      
										0,      
										Sn.BillDate,      
										2, -- 0 Group , 1 Asset , 2 AssetDetail              
										0,      
										mtSecurity,      
										0,       
										'',      
										ass.asGUID,      
										LastCheck.CostGUID,      
										(CASE @Language WHEN 0 THEN co.coName ELSE co.coLatinName END),     
										LastCheck.StoreGuid,      
										LastCheck.StoreName,      
										ad.adBarCode,
										ass.asLifeExp,
										sn.BranchName,
										Sn.IsExcludeAsset
							FROM          
													#SNAll_DETAILED  Sn       
													INNER JOIN vwad AS ad   ON ad.adSnGuid = Sn.SnGuid      
													INNER JOIN vwAs AS ass  ON ass.asGuid = ad.adAssGUID        
													INNER JOIN vwmt AS mt  ON mt.mtGuid = ass.asParentGUID   
													inner join vwst as st on st.stguid = sn.storeguid   
													LEFT JOIN [#SN_lastcheck]  AS LastCheck ON LastCheck.SNGuid =  Sn.SnGuid  
													left JOIN vwco AS co  ON co.coGuid = LastCheck.CostGUID        
							WHERE         
										mt.mtGUID = @AssGUID        
										AND ad.adInDate BETWEEN @StartDate AND @EndDate        
										AND ( @SupplierName ='' OR ad.adSupplier LIKE '%' + @SupplierName + '%')       
										AND ad.adPurchaseOrderDate between @From_purchaseOrderDate  AND @To_purchaseOrderDate         
										AND ad.adGuarantyBeginDate between @From_GUARANTEE_BEGINDATE AND @To_GUARANTEE_BEGINDATE        
										AND ad.adGuarantyEndDate between @From_GUARANTEE_ENDDATE AND @To_GUARANTEE_ENDDATE        
										AND ad.adContractGuarantyDate    between @From_ContractGuarantyDate AND @To_ContractGuarantyDate       
										AND ad.adContractGuarantyEndDate between @From_ContractGuarantyEndDate AND @To_ContractGuarantyEndDate       
										AND (@SN = '' OR ad.adSN LIKE '%' + @SN + '%')       
										AND (@BarCOde = '' OR ad.adBarCode LIKE '%' + @BarCode +'%')        
							ORDER BY         
										BillDate,adSn    
	                                       
									--select distinct * FROM          
									--                #SNAll_DETAILED  Sn       
									--                left JOIN vwad AS ad   ON ad.adSnGuid = Sn.SnGuid      
									--                --INNER JOIN vwAs AS ass  ON ass.asGuid = ad.adAssGUID        
									--                --INNER JOIN vwmt AS mt  ON mt.mtGuid = ass.asParentGUID        
									--                --left JOIN vwco AS co  ON co.coGuid = Sn.CostGUID   
						  UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) WHERE Type = 2         
	         
				END         
				ELSE         
				BEGIN        
							------------------------------------   
						IF(ISNULL( @AdGUID, 0x0) = 0x0)   
						BEGIN         
								INSERT INTO #Result      
								SELECT          
											GUID,          
											grCode,         
											grName,         
											grLatinName,         
											0,         
											0,         
											0,         
											0,         
											'1-1-1980',         
											0, -- 0 Group , 1 Asset , 2 AssetDetail         
											[Level],         
											0, -- mtSecurity         
											grSecurity,         
											[Path],         
											gr.grParent,       
											0x0,       
											'' ,       
											0x0,       
											'' ,       
											'' ,
											0  ,
											'' ,
											0
								FROM          
											dbo.fnGetGroupsOfGroupSorted(@GrpGUID, 1)  AS fn         
											INNER JOIN vwGr AS gr ON fn.GUID = gr.grGuid         
								------------------------------------         
								--UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))         
								------------------------------------         
								INSERT INTO #Result         
								SELECT          
											asGUID,                     
											mtCode,         
											mtName,         
											mtLatinName,         
											0,         
											0,         
											0,         
											0,         
											'1-1-1980',         
											1, -- 0 Group , 1 Asset , 2 AssetDetail              
											Res.[Level],         
											mt.mtSecurity,         
											0,         
											Res.[Path],         
											mtGroup,       
											0x0,       
											'',      
											0x0,            
											'',        
											'',
											ass.asLifeExp,
											'',
											0        
								FROM         
											vwAs AS ass        
											INNER JOIN vwMt AS mt ON ass.asParentGuid = mt.mtGUID         
											INNER JOIN #Result AS Res ON Res.Guid = mt.mtGroup       
								------------------------------------         
								UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) WHERE Type = 1         
								------------------------------------         
								INSERT INTO #Result         
								SELECT   distinct       
											adGuid,         
											adSn,         
											'',         
											'',         
											0,         
											0,         
											0,         
											0,         
											Sn.BillDate,         
											2, -- 0 Group , 1 Asset , 2 AssetDetail              
											Res.[Level],         
											mt.mtSecurity,         
											0,         
											Res.[Path],         
											adAssGUID,       
											LastCheck.CostGUID,       
											(CASE @Language WHEN 0 THEN co.coName ELSE co.coLatinName END),       
											LastCheck.StoreGuid,       
											LastCheck.StoreName,       
											ad.adBarCode,
											ass.asLifeExp,
											sn.BranchName,
											Sn.IsExcludeAsset
								FROM          
														#SNAll_DETAILED  Sn         
														INNER JOIN vwad AS ad   ON ad.adSnGuid = Sn.SnGuid      
														INNER JOIN vwAs AS ass  ON ass.asGuid = ad.adAssGUID        
														INNER JOIN vwmt AS mt  ON mt.mtGuid = ass.asParentGUID        
														INNER JOIN #Result AS Res ON Res.Guid = ad.adAssGUID   
														LEFT JOIN [#SN_lastcheck]  AS LastCheck ON LastCheck.SNGuid =  Sn.SnGuid 
														left JOIN vwco AS co  ON co.coGuid = LastCheck.CostGUID        
														left JOIN vwst AS st  ON st.stGuid = LastCheck.StoreGUID        
							   WHERE         
											ad.adInDate BETWEEN @StartDate AND @EndDate        
											AND ( @SupplierName ='' OR ad.adSupplier LIKE '%' + @SupplierName + '%')       
											AND ad.adPurchaseOrderDate between @From_purchaseOrderDate  AND @To_purchaseOrderDate         
											AND ad.adGuarantyBeginDate between @From_GUARANTEE_BEGINDATE AND @To_GUARANTEE_BEGINDATE        
											AND ad.adGuarantyEndDate between @From_GUARANTEE_ENDDATE AND @To_GUARANTEE_ENDDATE        
											AND ad.adContractGuarantyDate    between @From_ContractGuarantyDate AND @To_ContractGuarantyDate       
											AND ad.adContractGuarantyEndDate between @From_ContractGuarantyEndDate AND @To_ContractGuarantyEndDate       
											AND (co.coGuid IN (SELECT GUID FROM dbo.fnGetCostsList   (@CostGuid))  OR @CostGuid = 0x0)       
											AND (@SN = '' OR ad.adSN LIKE '%' + @SN + '%')       
											AND (@BarCOde = '' OR ad.adBarCode LIKE '%' + @BarCode +'%')      
								ORDER BY         
											Sn.BillDate,adSn         
					 ------------------------------------         
								UPDATE #Result SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40)) WHERE Type = 2    
					END   
					ELSE   
					BEGIN   
								INSERT INTO #Result         
								SELECT   distinct       
											adGuid,         
											adSn,         
											'',         
											'',         
											0,         
											0,         
											0,         
											0,         
											'1-1-1980',         
											2, -- 0 Group , 1 Asset , 2 AssetDetail              
											0,         
											mt.mtSecurity,         
											0,         
											'0',         
											adAssGUID,       
											co.coguid,       
											co.coname,       
											Sn.StoreGuid,       
											st.stName,       
											ad.adBarCode,
											ass.asLifeExp,
											sn.BranchName,
											Sn.IsExcludeAsset
								FROM          
														#SNAll_DETAILED  Sn         
														INNER JOIN vwad AS ad   ON ad.adSnGuid = Sn.SnGuid      
														INNER JOIN vwAs AS ass  ON ass.asGuid = ad.adAssGUID        
														INNER JOIN vwmt AS mt  ON mt.mtGuid = ass.asParentGUID    
														LEFT JOIN [#SN_lastcheck]  AS LastCheck ON LastCheck.SNGuid =  Sn.SnGuid     
														left JOIN vwco AS co  ON co.coGuid = LastCheck.CostGUID        
														left JOIN vwst AS st  ON st.stGuid = LastCheck.StoreGUID        
							   WHERE   ad.adguid =  @AdGUID   
							   ORDER BY         
											adSn   
												    
					END                                                                
				END   
	---------------------------------------------------------------------------------------------------   
				IF(ISNULL( @AdGUID, 0x0) <> 0x0)   
				BEGIN   
				   
					UPDATE #RESULT SET NAME = mt.name   
					FROM #RESULT r    
							 inner join ad000 ad on r.guid = ad.guid   
							 inner join as000 ass on ass.Guid = ad.ParentGuid   
							 inner join mt000 mt on ass.ParentGuid = mt.Guid   
				END   
	---------------------------------------------------------------------------------------------------         
		--		IF( ( @ShowCurAdedd = 1) OR ( @ShowCurVal = 1) )         
							UPDATE Result SET adAddedCurrent = Ax.Val         
							FROM #Result Result INNER JOIN    
							(      
										   SELECT SUM( CASE WHEN axx.Type = 0 THEN axx.Value * [FixedFactor] ELSE 0 END) AS Val,      
												ADGUID    
												FROM (   
														 SELECT    
															*    
															, ISNULL([dbo].[fnCurrency_fix](1, CurrencyGUID, CurrencyVal, @CurGUID, NULL),1) AS [FixedFactor]   
														 FROM   
															Ax000   
														 WHERE Date BETWEEN @StartDate AND @EndDate
												 )axx GROUP BY ADGUID   
							)Ax ON Result.Guid = Ax.AdGUID         
				    
		--		IF((@showCurDeduct = 1) OR (@ShowCurVal = 1))      
							UPDATE Result SET adDeductCurrent = Ax.Val         
							FROM #Result Result INNER JOIN    
							(   
										SELECT SUM( CASE WHEN axx.Type = 1 THEN axx.Value * [FixedFactor] ELSE 0 END) AS Val,   
												ADGUID    
												FROM (   
													 SELECT    
														*    
														, ISNULL([dbo].[fnCurrency_fix](1, CurrencyGUID, CurrencyVal, @CurGUID, NULL),1) AS [FixedFactor]   
													 FROM   
														Ax000   
													 WHERE Date BETWEEN @StartDate AND @EndDate
													 )axx GROUP BY ADGUID   
							) Ax ON Result.Guid = Ax.AdGUID        
	       
	--			IF( ( @ShowCurMainten = 1) OR ( @ShowCurVal = 1) )         
							UPDATE Result SET adMaintainCurrent = Ax.Val         
							FROM #Result Result INNER JOIN    
							(   
									SELECT SUM( CASE WHEN axx.Type = 2 THEN axx.Value * [FixedFactor] ELSE 0 END) AS Val,   
										   ADGUID   
										   FROM (   
														 SELECT    
															*    
															, ISNULL([dbo].[fnCurrency_fix](1, CurrencyGUID, CurrencyVal, @CurGUID, NULL),1) AS [FixedFactor]   
														 FROM   
															Ax000   
														 WHERE Date BETWEEN @StartDate AND @EndDate
												)axx GROUP BY ADGUID   
							) Ax ON Result.Guid = Ax.AdGUID         
	                                 
	--		   IF( ( @ShowCurDep = 1) OR ( @ShowCurVal = 1) )         
							UPDATE Result SET adDeprecationCurrent = DD.Val, adLastDepDate = DD.MaxDepDate         
							FROM #Result Result INNER JOIN       
							(       
								SELECT	SUM( Value * [FixedFactor]) AS Val,       
										Max( dd.ToDate) AS MaxDepDate,       
										ADGUID     
								FROM (   
									SELECT    
									*    
									, ISNULL([dbo].[fnCurrency_fix](1, CurrencyGUID, CurrencyVal, @CurGUID, NULL),1) AS [FixedFactor]   
									FROM   
										dd000   
								) dd inner join dp000 dp on dp.Guid = dd.ParentGuid      
								WHERE dd.ToDate <= @Todate       
								GROUP BY AdGuid --ADGUID, dd.StoreGuid      
							)AS DD ON Result.Guid = DD.AdGUID  -- and dd.StoreGuid = Result.StoreGuid      
	------------------------------------------------------------------------------------------------------  
	CREATE TABLE #endResult_Detail(      
				Guid UNIQUEIDENTIFIER,      
				adGuid UNIQUEIDENTIFIER,      
				[Name]  NVARCHAR(200) ,      
				adAddedCurrent FLOAT,         
				adDeductCurrent FLOAT,         
				adMaintainCurrent FLOAT,         
				adDeprecationCurrent FLOAT,         
				[Type] INT,  -- 0 Group , 1 Asset , 2 AssetDetail         
				ParentGuid UNIQUEIDENTIFIER,         
				adInVal FLOAT,         
				adOutVal FLOAT,         
				adScrapValue FLOAT,         
				adDailyRental FLOAT,         
				adAddedVal FLOAT,         
				adDeductVal FLOAT,         
				adMaintenVal FLOAT,         
				adDeprecationVal FLOAT,         
				StoreGUID UNIQUEIDENTIFIER,      
				RecCount INT,         
				Updated INT default 0,  
				Rate FLOAT,
				IsExcludeAsset INT)         
	--------------------------------------------------------------      
	INSERT INTO #endResult_Detail      
	SELECT         
							Guid,   
							ad.adGuid,    
							[Name],    
							ISNULL(adAddedCurrent,0),   
							ISNULL(adDeductCurrent,0),      
							ISNULL(adMaintainCurrent,0),      
							ISNULL(adDeprecationCurrent,0),      
							[Type],      
							ParentGuid ,      
							ISNULL([FixedInFactor] * adInVal,0),      
							ISNULL([FixedOutFactor] * adOutVal,0),      
							ISNULL([FixedOther] * adScrapValue,0),      
							ISNULL([FixedOther] * adDailyRental,0),      
							ISNULL([FixedOther] * adAddedVal,0),      
							ISNULL([FixedOther] * adDeductVal,0),      
							ISNULL([FixedOther] * adMaintenVal,0),      
							ISNULL([FixedOther] * adDeprecationVal,0),      
							StoreGuid,   
							0,   
							1,  
							ISNULL(1/[FixedInFactor],0),
							Res.IsExcludeAsset     
	                              
	FROM          
				#Result AS Res inner JOIN (   
												SELECT     
												*,     
												ISNULL([dbo].[fnCurrency_fix](1, [adInCurrencyGUID], [adInCurrencyVal], @CurGUID, [adInDate]),1) AS [FixedInFactor],   
												ISNULL([dbo].[fnCurrency_fix](1, [adOutCurrencyGUID], [adOutCurrencyVal], @CurGUID, [adOutDate]),1) AS [FixedOutFactor],   
												ISNULL([dbo].[fnCurrency_fix](1, 0x0, 1, @CurGUID, NULL),1) AS [FixedOther]		   
											FROM     
												[vwAd]   
										 ) AS [ad] ON Res.Guid = Ad.adGuid         
	WHERE [type] = 2     

	IF(@ShowTotalDeprAssetOnly = 1 )
	BEGIN
		DELETE FROM #endResult_Detail 
		WHERE adInval + adAddedCurrent + adAddedVal - adDeductCurrent - adDeductVal - adDeprecationCurrent - adDeprecationVal > 0
	END  
	   
IF(ISNULL( @AdGUID, 0x0) = 0x0)   
BEGIN   
		SELECT    
			  ParentGuid ,   
			  SUM(adAddedCurrent)		AS adAddedCurrent,      
			  SUM(adDeductCurrent)		AS adDeductCurrent,      
			  SUM(adMaintainCurrent)	AS  adMaintainCurrent,      
			  SUM(adDeprecationCurrent)	AS adDeprecationCurrent   
		INTO #hsh_1   
		FROM #endResult_Detail   
		WHERE TYPE = 2   
		GROUP BY ParentGuid   
			   
		SELECT    
				  ParentGuid,   
					SUM(ADINVAL)			AS ADINVAL,       
					SUM(ADOUTVAL)			AS ADOUTVAL,        
					SUM(adScrapValue)		AS adScrapValue,      
					SUM(adDailyRental)		AS adDailyRental,         
					SUM(adAddedVal)			AS adAddedVal,            
					SUM(adDeductVal)		AS adDeductVal,            
					SUM(adMaintenVal)		AS adMaintenVal,            
					SUM(adDeprecationVal)	AS adDeprecationVal    
		INTO #hsh_2   
		FROM    
			(    
				SELECT    
					  adGuid,   
					  ParentGuid,   
						MAX(ADINVAL)			AS ADINVAL,       
						MAX(ADOUTVAL)			AS ADOUTVAL,        
						MAX(adScrapValue)		AS adScrapValue,      
						MAX(adDailyRental)		AS adDailyRental,         
						MAX(adAddedVal)			AS adAddedVal,            
						MAX(adDeductVal)		AS adDeductVal,            
						MAX(adMaintenVal)		AS adMaintenVal,            
						MAX(adDeprecationVal)	AS adDeprecationVal        
				FROM #endResult_Detail   
				WHERE TYPE = 2   
				GROUP BY adGuid,ParentGuid   
			) a   
		GROUP BY ParentGuid   
		INSERT INTO #endResult_Detail   
				SELECT  GUID,   
						0x0,   
						Name,   
						h1.adAddedCurrent,      
						h1.adDeductCurrent,      
						h1.adMaintainCurrent,      
						h1.adDeprecationCurrent,      
						1 as type,      
						r.ParentGuid,      
						h2.adInVal,      
						h2.adOutVal,      
						h2.adScrapValue,      
						h2.adDailyRental,      
						h2.adAddedVal,         
						h2.adDeductVal,         
						h2.adMaintenVal,         
						h2.adDeprecationVal,         
						StoreGuid,       
						0 RecCount ,      
						1, -- update 
						1,--ISNULL(1/[FixedInFactor],0)
						r.IsExcludeAsset 
				FROM #Result AS r   
				INNER JOIN #hsh_1 AS h1 ON r.guid = h1.ParentGuid   
				INNER JOIN #hsh_2 AS h2 ON r.guid = h2.ParentGuid   
				   
		SELECT    
			  ParentGuid,   
				SUM(ADINVAL)				AS ADINVAL,       
				SUM(ADOUTVAL)				AS ADOUTVAL,        
				SUM(adScrapValue)			AS adScrapValue,      
				SUM(adDailyRental)			AS adDailyRental,         
				SUM(adAddedVal)				AS adAddedVal,            
				SUM(adDeductVal)			AS adDeductVal,            
				SUM(adMaintenVal)			AS adMaintenVal,            
				SUM(adDeprecationVal)		AS adDeprecationVal,   
				SUM(adAddedCurrent)			AS adAddedCurrent,      
				SUM(adDeductCurrent)		AS adDeductCurrent,      
				SUM(adMaintainCurrent)		AS  adMaintainCurrent,      
				SUM(adDeprecationCurrent)	AS adDeprecationCurrent   
		INTO #hsh_SUM   
		FROM #endResult_Detail   
		WHERE type = 1   
		GROUP BY ParentGuid   
		SELECT    
			  Guid   
			 ,path   
		INTO #hsh_select   
		FROM #Result   
		WHERE type = 0   
		DECLARE @cnt INT   
		DECLARE @id UNIQUEIDENTIFIER   
		DECLARE @parent_id UNIQUEIDENTIFIER   
		DECLARE						@ADINVAL				FLOAT,      
									@ADOUTVAL				FLOAT,      
									@adScrapValue			FLOAT,    
									@adDailyRental			FLOAT,          
									@adAddedVal				FLOAT,             
									@adDeductVal			FLOAT,            
									@adMaintenVal			FLOAT,             
									@adDeprecationVal		FLOAT,    
									@adAddedCurrent			FLOAT,       
									@adDeductCurrent		FLOAT,       
									@adMaintainCurrent		FLOAT,      
									@adDeprecationCurrent	FLOAT   
									   
		SET @cnt = (SELECT COUNT(*) FROM #hsh_select)   
		WHILE ( @cnt > 0)   
		BEGIN   
					SET @id = (SELECT TOP 1 Guid FROM #hsh_select ORDER BY PATH DESC )		   
					DELETE FROM #hsh_select WHERE Guid = @id   
					   
					SELECT @parent_id = r.ParentGuid   
								FROM #Result r   
								WHERE r.guid = @id   
								GROUP BY r.ParentGuid   
								   
					IF NOT EXISTS(SELECT * FROM #hsh_sum WHERE ParentGuid = @parent_id)   
						INSERT INTO #hsh_sum   
							SELECT DISTINCT   
									r.ParentGuid,   
									SUM(h.ADINVAL)		AS ADINVAL,       
									SUM(h.ADOUTVAL)		AS ADOUTVAL	,        
									SUM(h.adScrapValue)	AS adScrapValue,      
									SUM(h.adDailyRental)AS adDailyRental,         
									SUM(h.adAddedVal)	AS adAddedVal	,            
									SUM(h.adDeductVal)	AS adDeductVal,            
									SUM(h.adMaintenVal)	AS adMaintenVal,            
									SUM(h.adDeprecationVal) AS adDeprecationVal	,   
									SUM(h.adAddedCurrent)	AS adAddedCurrent	,      
									SUM(h.adDeductCurrent)	AS adDeductCurrent,      
									SUM(h.adMaintainCurrent)AS adMaintainCurrent ,      
									SUM(h.adDeprecationCurrent) AS adDeprecationCurrent   
							FROM #hsh_sum h   
							INNER JOIN #Result r on r.guid = h.ParentGuid    
							WHERE r.ParentGuid = @id   
							GROUP BY r.ParentGuid   
					   
										   
					SET @cnt = @cnt - 1   
		END   
				   
		INSERT INTO #endResult_Detail   
				SELECT  r.guid,   
						0x0,   
						Name,   
						h.adAddedCurrent,      
						h.adDeductCurrent,      
						h.adMaintainCurrent,      
						h.adDeprecationCurrent,      
						0 as type,      
						0x0,      
						h.adInVal,      
						h.adOutVal,      
						h.adScrapValue,      
						h.adDailyRental,      
						h.adAddedVal,         
						h.adDeductVal,         
						h.adMaintenVal,         
						h.adDeprecationVal,         
						StoreGuid,       
						0 RecCount ,      
						1, -- update      
						1,
						r.IsExcludeAsset 
				FROM #Result AS r   
				inner join #hsh_sum AS h on r.guid = h.ParentGuid   
				--select * from #result  
END  
SET @LastStatment = 
	' select r.guid,    
			r.[name],      
			r.Code,     
			d.adInval, 
			d.adInval + d.adAddedCurrent + d.adAddedVal - d.adDeductCurrent - d.adDeductVal AS AdNetVal,          
			r.Type,     
			R.LatinName,         
			d.adOutVal,         
			d.adScrapValue,         
			d.adDailyRental,         
			d.adAddedVal,         
			d.adDeductVal,         
			d.adMaintenVal,      
			ISNULL(ad.adInDate, ''1980'') AS adInDate,       
			ISNULL(ad.adInCurrencyGuid,0x0) AS adInCurrencyGuid,         
			ISNULL(ad.adInCurrencyVal,0) AS adInCurrencyVal,         
			ISNULL(ad.adOutDate, ''1980'') AS adOutDate,         
			ISNULL(ad.adOutCurrencyGuid,0x0) AS adOutCurrencyGuid,         
			ISNULL(ad.adOutCurrencyVal,0) AS adOutCurrencyVal,         
			ISNULL(ad.adPurChaseOrder,'''') AS adPurChaseOrder,         
			ISNULL(ad.adPurChaseOrderDate,''1980'') AS adPurChaseOrderDate,         
			ISNULL(ad.adModel,'''') AS adModel,         
			ISNULL(ad.adOrigin,'''') AS adOrigin,         
			ISNULL(ad.adCompany,'''') AS adCompany,         
			ISNULL(ad.adManufdate, ''1980'') AS adManufdate,         
			ISNULL(ad.adSupplier,'''') AS adSupplier,        
			ISNULL(ad.adLKind,'''') AS adLKind,         
			ISNULL(ad.adLCNum,'''') AS adLCNum,         
			ISNULL(ad.adLCDate, ''1980'') AS adLCDate,        
			ISNULL(ad.adImportPermit,'''') AS adImportPermit,         
			ISNULL(ad.adArrvDate, ''1980'') AS adArrvDate,        
			r.ParentGuid,         
			ISNULL(ad.adCustomStatement,'''') AS adCustomStatement,         
			ISNULL(ad.adCustomCost,'''') AS adCustomCost,         
			ISNULL(ad.adCustomDate, ''1980'') AS adCustomDate,        
			ISNULL(ad.adContractGuaranty,'''') AS adContractGuaranty,         
			ISNULL(ad.adContractGuarantyDate, ''1980'') AS adContractGuarantyDate,       
			ISNULL(ad.adContractGuarantyEndDate,''1980'') AS adContractGuarantyEndDate,       
			ISNULL(ad.adGuarantyBeginDate, ''1980'') AS adGuarantyBeginDate,       
			ISNULL(ad.adGuarantyEndDate, ''1980'') AS adGuarantyEndDate,       
			ISNULL(r.CostGuid,0x0) AS CostGuid,       
			ISNULL(r.CostName,'''') AS CostName,       
			ISNULL(ad.adBarcode,'''') AS adBarcode,         
			ISNULL(ad.adJobPolicy,'''') AS adJobPolicy,         
			ISNULL(ad.adNotes,'''') AS adNotes,      
			r.adLastDepDate,      
			d.RecCount,       
			d.adAddedCurrent,         
			d.adDeductCurrent,       
			d.adMaintainCurrent,         
			d.adDeprecationCurrent,        
			d.adDeprecationVal, 
			d.adDeprecationCurrent + d.adDeprecationVal AS adTotalDeprecation,        
			ISNULL(ad.adArrvPlace,'''') as adArrvPlace,   
			ISNULL(r.StoreGuid,0x0),
			ISNULL(r.StoreName,''''),  
			d.Rate,
			ISNULL(CASE ad.adAge WHEN 0 THEN r.asLifeExp ELSE ad.adAge END, r.asLifeExp) AS asLifeExpire,
			r.BranchName,
			ISNULL(vwAs.asParentGUID,0x0) AS MatGuid ,'
			+ CASE @Language when 0 then ' ISNULL(bu.buFormatedNumber,'''')' else ' ISNULL(bu.buLatinFormatedNumber,'''')' END + ' AS BillName ,
			r.path,
			d.adInval + (d.adAddedVal + d.adAddedCurrent) - (d.adDeductVal + d.adDeductCurrent) - (d.adDeprecationVal + d.adDeprecationCurrent),
			d.IsExcludeAsset'   
			--  - ((r.Code == m_PrevAD && r.Type == E_ASSDETAILS) ? m_PrevDep : 0);
		+' FROM #endResult_Detail d    
		INNER JOIN  #Result r ON r.Guid = d.guid     
		LEFT JOIN vwAd AS ad ON R.Guid = Ad.adGuid
		LEFT JOIN vwAs AS vwAs ON vwAs.asGUID = r.Guid
		LEFT JOIN vwBu AS bu ON ad.adBillGUID = bu.buGUID '
IF @ShowGroup  <> 1
BEGIN  
	SET @LastStatment = @LastStatment +	' where r.Type <> 0 '  
END 
ELSE 
SET @LastStatment = @LastStatment +	' where r.Type  = r.Type '  
IF @ShowZeroAssets <> 1  
BEGIN  
	SET @LastStatment = @LastStatment +	' AND d.adinval <> 0 '  
END 
SET @LastStatment = @LastStatment + ' order by r.path, r.Code, r.adLastDepDate '  

CREATE TABLE #FinalResult  
		(
			guid						[UNIQUEIDENTIFIER],    
			name						[NVARCHAR](255)  COLLATE ARABIC_CI_AI,     
			Code						[NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
			adInval						[FLOAT],  
			AdNetVal					[FLOAT],  
			Type						[INT],     
			LatinName					[NVARCHAR](255) ,         
			adOutVal					[FLOAT],         
			adScrapValue				[FLOAT],         
			adDailyRental				[FLOAT],         
			adAddedVal					[FLOAT],         
			adDeductVal					[FLOAT],         
			adMaintenVal				[FLOAT],      
			adInDate					[DATETIME],       
			adInCurrencyGuid			[UNIQUEIDENTIFIER],           
			adInCurrencyVal				[FLOAT],
			adOutDate					[DATETIME],                
			adOutCurrencyGuid			[UNIQUEIDENTIFIER],           
			adOutCurrencyVal			[FLOAT],      
			adPurChaseOrder				[NVARCHAR](255) ,          
			adPurChaseOrderDate			[DATETIME],                
			adModel						[NVARCHAR](255) ,         
			adOrigin					[NVARCHAR](255) ,          
			adCompany					[NVARCHAR](255) ,          
			adManufdate					[DATETIME],                
			adSupplier					[NVARCHAR](255) ,        
			adLKind						[NVARCHAR](255) ,          
			adLCNum						[NVARCHAR](255) ,          
			adLCDate					[DATETIME],        
			adImportPermit				[NVARCHAR](255) ,          
			adArrvDate					[DATETIME],               
			ParentGuid					[UNIQUEIDENTIFIER],           
			adCustomStatement			[NVARCHAR](255) ,         
			adCustomCost				[NVARCHAR](255) ,          
			adCustomDate				[DATETIME],        
			adContractGuaranty			[NVARCHAR](255) ,         
			adContractGuarantyDate		[DATETIME],              
			adContractGuarantyEndDate	[DATETIME],              
			adGuarantyBeginDate			[DATETIME],              
			adGuarantyEndDate			[DATETIME],              
			CostGuid					[UNIQUEIDENTIFIER],         
			CostName					[NVARCHAR](255) ,        
			adBarcode					[NVARCHAR](255) ,          
			adJobPolicy					[NVARCHAR](255) ,         
			adNotes						[NVARCHAR](255) ,       
			adLastDepDate				[DATETIME],             
			RecCount					[int],       
			adAddedCurrent				[FLOAT],   
			adDeductCurrent				[FLOAT],      
			adMaintainCurrent			[FLOAT],         
			adDeprecationCurrent		[FLOAT],        
			adDeprecationVal			[FLOAT],    
			adTotalDeprecation			[FLOAT],  
			adArrvPlace					[NVARCHAR](255) ,   
			StoreGuid					[UNIQUEIDENTIFIER],  
			StoreName					[NVARCHAR](255) ,   
			Rate						[FLOAT],
			asLifeExpire				[INT],
			BranchName					[NVARCHAR](255) , 
			MatGuid						[UNIQUEIDENTIFIER],  
			BillName					[NVARCHAR](255) ,
			path						[NVARCHAR](1000) ,
			AssetValCurrent				[FLOAT],
			IsExcludeAsset				[INT]
		 )  


INSERT INTO #FinalResult
EXEC (@LastStatment) 
 
IF @IsCalledByTransCard = 1
BEGIN 

	SELECT * FROM #FinalResult
	ORDER BY path, Code, adLastDepDate
	
	SELECT 
		r.ParentGuid AssetGuid
		,r.StoreName
		,COUNT(*) AssetsCount
	FROM  #endResult_Detail d
	INNER JOIN #Result r ON r.Guid = d.guid
	LEFT JOIN vwAd AS ad ON R.Guid = Ad.adGuid
	WHERE r.Type = 2
	GROUP BY r.ParentGuid, r.StoreName
	ORDER BY r.ParentGuid
END
ELSE 
BEGIN 
	IF @Grouping = 0
	BEGIN
--Tree Result 
		CREATE TABLE #MatAssetCount
		(
			[Guid]         [UNIQUEIDENTIFIER] ,
			[Count]			[INT]
		)

		INSERT INTO #MatAssetCount
		SELECT ParentGuid ,COUNT(*)
		FROM #FinalResult
		WHERE Type = 2
		GROUP BY ParentGuid

		SELECT FR.*,
		(CASE ISNULL(MATAssCount.Guid,0x0) WHEN 0x0 THEN 0x0 ELSE MATAssCount.Count END) AS AssetCount,
		(CASE adInCurrencyGuid WHEN 0x0 THEN '' ELSE (MY.Code + ' : ' + CONVERT(NVARCHAR(250), adInCurrencyVal))END) AS CurCodeVal
		FROM #FinalResult FR
		LEFT JOIN my000 MY ON my.GUID = FR.adInCurrencyGuid
		LEFT JOIN #MatAssetCount MATAssCount ON MATAssCount.Guid = FR.guid
		ORDER BY path, FR.Code, adLastDepDate
	END
	ELSE
	BEGIN
--Master Result 
		SELECT *,
		0.0 AS AssetCount,
		name AS AssMatName
		FROM #FinalResult
		WHERE Type = 1
--Details Result 
		SELECT FR.* ,
		1.0 AS AssetCount,
		MY.Code + ' : ' + CONVERT(NVARCHAR(250), adInCurrencyVal) AS CurCodeVal
		FROM #FinalResult FR
		LEFT JOIN my000 MY ON my.GUID = FR.adInCurrencyGuid
		WHERE Type = 2
	END
--Footer Result

CREATE TABLE #FooterResult
	(
		TotalType				[INT],
		AdNetVal				[FLOAT],             
		adInval					[FLOAT],
		adScrapValue			[FLOAT],
		adDailyRental			[FLOAT],
		adAddedVal				[FLOAT],
		adDeductVal				[FLOAT],
		adMaintenVal			[FLOAT],
		adDeprecationVal		[FLOAT],
		adDeductCurrent			[FLOAT],
		adMaintainCurrent		[FLOAT],
		adDeprecationCurrent	[FLOAT],
		AssetValCurrent			[FLOAT],
		adAddedCurrent			[FLOAT],
		adTotalDeprecation		[FLOAT],
		Type					[INT],
		IsExcludeAsset			[INT],
		AssetCount				[INT]
	)
	
	--Add Total Asset 
IF  @ShowExcludeAssetOnly <> 1
BEGIN
	
	INSERT INTO #FooterResult
	SELECT 
		1							AS TotalType,
		SUM(AdNetVal)				AS AdNetVal,                  
		SUM(adInval)				AS adInval,
		SUM(adScrapValue)			AS adScrapValue,
		SUM(adDailyRental)			AS adDailyRental,
		SUM(adAddedVal)				AS adAddedVal,
		SUM(adDeductVal)			AS adDeductVal,
		SUM(adMaintenVal)			AS adMaintenVal,
		SUM(adDeprecationVal)		AS adDeprecationVal,
		SUM(adDeductCurrent)		AS adDeductCurrent,
		SUM(adMaintainCurrent)		AS adMaintainCurrent,
		SUM(adDeprecationCurrent)	AS adDeprecationCurrent,
		SUM(AssetValCurrent)		AS AssetValCurrent,
		SUM(adAddedCurrent)			AS adAddedCurrent,
		SUM(adTotalDeprecation)		AS adTotalDeprecation,
		MIN([Type])					AS Type,
		0,
		count([Type])
	FROM #FinalResult FR
	GROUP BY [type]
	HAVING [type]  = 2 
END

	--Add Total Excluded Asset 
IF @ShowExcludeAsset = 1 OR @ShowExcludeAssetOnly = 1
BEGIN
		
	IF NOT EXISTS (SELECT * FROM #FinalResult WHERE IsExcludeAsset = 1 AND Type = 2)
	BEGIN 
			INSERT INTO #FooterResult SELECT 2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	END 
	ELSE 
	BEGIN
		INSERT INTO #FooterResult
		SELECT 
			2,
			SUM(AdNetVal) AS AdNetVal,                  
			SUM(adInval) AS adInval,
			SUM(adScrapValue) AS adScrapValue,
			SUM(adDailyRental) AS adDailyRental,
			SUM(adAddedVal) AS adAddedVal,
			SUM(adDeductVal) AS adDeductVal,
			SUM(adMaintenVal) AS adMaintenVal,
			SUM(adDeprecationVal) AS adDeprecationVal,
			SUM(adDeductCurrent) AS adDeductCurrent,
			SUM(adMaintainCurrent) AS adMaintainCurrent,
			SUM(adDeprecationCurrent) AS adDeprecationCurrent,
			SUM(AssetValCurrent) AS AssetValCurrent,
			SUM(adAddedCurrent) AS adAddedCurrent,
			SUM(adTotalDeprecation) AS adTotalDeprecation,
			MIN(Type) AS Type,
			MIN (IsExcludeAsset) AS IsExcludeAsset,
			count(Type)
		FROM 
			(SELECT * FROM #FinalResult WHERE Type = 2) AS FR
		GROUP BY IsExcludeAsset
		HAVING IsExcludeAsset = 1
	END
END
	
	--Add Total Net Asset 
IF @ShowExcludeAsset = 1
BEGIN
		
	IF NOT EXISTS (SELECT * FROM #FinalResult WHERE IsExcludeAsset <> 1 AND Type = 2)
	BEGIN 
			INSERT INTO #FooterResult SELECT 3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	END 
	ELSE 
	BEGIN
		INSERT INTO #FooterResult
		SELECT 
			3,
			SUM(AdNetVal) AS AdNetVal,                  
			SUM(adInval) AS adInval,
			SUM(adScrapValue) AS adScrapValue,
			SUM(adDailyRental) AS adDailyRental,
			SUM(adAddedVal) AS adAddedVal,
			SUM(adDeductVal) AS adDeductVal,
			SUM(adMaintenVal) AS adMaintenVal,
			SUM(adDeprecationVal) AS adDeprecationVal,
			SUM(adDeductCurrent) AS adDeductCurrent,
			SUM(adMaintainCurrent) AS adMaintainCurrent,
			SUM(adDeprecationCurrent) AS adDeprecationCurrent,
			SUM(AssetValCurrent) AS AssetValCurrent,
			SUM(adAddedCurrent) AS adAddedCurrent,
			SUM(adTotalDeprecation) AS adTotalDeprecation,
			MIN(Type) AS Type,
			MIN (IsExcludeAsset) AS IsExcludeAsset,
			count(Type)
		FROM 
		(SELECT * FROM #FinalResult WHERE Type = 2) AS FR
		GROUP BY IsExcludeAsset
		HAVING  IsExcludeAsset <> 1 
	END
END
SELECT * FROM #FooterResult

END
#####################################################################################
CREATE PROC SN_lastcheck
      @Mat_GUID UNIQUEIDENTIFIER = 0x0,   
      @Grp_GUID UNIQUEIDENTIFIER = 0x0,    
      @st_GUID UNIQUEIDENTIFIER = 0x0,    
      @co_GUID UNIQUEIDENTIFIER = 0x0,  
      @from_date DATETIME = '1/1/1800',  
      @to_date DATETIME = '1/1/1800',  
      @Currency_GUID UNIQUEIDENTIFIER = 0x0  
AS    
SET NOCOUNT ON  
DECLARE @BranchMask BIGINT  
SET @BranchMask = -1 
IF EXISTS(select ISNULL([value],0) from op000 where [name] = 'EnableBranches') 
	BEGIN 
		DECLARE @En_br BIGINT 
		SET @En_br = (select TOP 1 ISNULL([value],0) from op000 where [name] = 'EnableBranches') 
		IF (@En_br = 1) 
			SET @BranchMask = (SELECT [dbo].[fnConnections_getBranchMask] ()) 
	END 
CREATE TABLE #hsh 
( 
[GID]         [INT] IDENTITY(0,1), 
[SN]     [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
[SNGuid]          [UNIQUEIDENTIFIER], 
[MatGuid]          [UNIQUEIDENTIFIER], 
[MatName]        [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
[StoreGuid]          [UNIQUEIDENTIFIER], 
[StoreName]   [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
[BillTypeGuid]          [UNIQUEIDENTIFIER],  
[BillGuid]          [UNIQUEIDENTIFIER],  
[CustomerName] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
[BillDate]        [DATETIME], 
[Bill]		  [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
[PRICE]       [FLOAT], 
[Number]      [FLOAT], 
[BranchGuid]  [UNIQUEIDENTIFIER], 
[CostGUID]    [UNIQUEIDENTIFIER], 
[Direction]   [INT], 
[Gr_GUID]     [UNIQUEIDENTIFIER], 
[Ac_GUID]     [UNIQUEIDENTIFIER] 
 ) 

INSERT INTO #hsh 
SELECT 
	ISNULL([snc].[SN] , '') AS [SN], 
	ISNULL([snc].[GUID] , 0x0)      AS [SNGuid], 
	ISNULL([mt].[GUID] , 0x0) AS [MatGuid],	 
	ISNULL([mt].[Name],'') AS [MatName], 
	ISNULL([bi].[StoreGUID],0x0) AS [StoreGuid], 
	ISNULL(CASE [bi].[StoreGUID]   WHEN 0x0 THEN '' ELSE (SELECT NAME FROM [st000] WHERE [GUID]	= [bi].[StoreGUID]  ) END,'') AS [StoreName], 
	ISNULL([bt].[Guid] , 0x0) AS [BillTypeGuid], 
	ISNULL([bi].[GUID] , 0x0) AS [BillGuid], 
	ISNULL(CASE [bu].[CustAccGUID] WHEN 0x0 THEN '' ELSE (SELECT NAME FROM [ac000] WHERE [GUID] = [bu].[CustAccGUID]) END,'') AS [CustomerName], 
	[bu].[Date] AS [BillDate], 
	ISNULL([bt].[Abbrev] + ' ' +  CAST ([bu].[Number] AS NVARCHAR),'') AS [Bill], 
	[bi].[Price], 
	ISNULL([bu].[Number]	, 0    )   AS    [NUMBER], 
	ISNULL([bu].[Branch]    , 0x0  )   AS    [BranchGuid], 
	CASE ISNULL([bi].[CostGUID], 0x0) WHEN 0x0 THEN [bu].[CostGUID] ELSE ISNULL([bi].[CostGUID], 0x0) END   AS    [CostGUID], 
	CASE bt.BillType  
                WHEN 0 THEN  (CASE bt.Type WHEN 3 THEN -1 WHEN  4 THEN 1 ELSE 1 END ) 
                WHEN 1 THEN -1 
                WHEN 2 THEN -1 
                WHEN 3 THEN  1 
                WHEN 4 THEN  1 
                WHEN 5 THEN -1 
                ELSE 0  
	END AS  [Direction], 
	ISNULL([mt].[GroupGUID]		,0x0) AS    [Gr_GUID]  , 
	ISNULL([bu].[CustAccGUID]	,0x0) AS    [Ac_GUID]   
FROM [snc000] AS snc	 
	INNER JOIN [snt000]AS snt ON [snc].[GUID]    = [snt].ParentGUID 
	INNER JOIN [bu000] AS bu  ON [snt].[buGuid]  = [bu].[GUID] 
	INNER JOIN [bi000] AS bi  ON [snt].[biGUID]  = [bi].[GUID] 
	INNER JOIN [bt000] AS bt  ON [bu].[TypeGUID] = [bt].[GUID] 
	INNER JOIN [mt000] AS mt  ON [snc].[MatGUID] = [mt].[GUID] 
	LEFT  JOIN [vwbr]  AS br  ON [br].[brGUID]   = [bu].[Branch] 
WHERE       ((@BranchMask = 0 OR  @BranchMask = -1) OR (([br].[brBranchMask] & @BranchMask) = [br].[brBranchMask])) 
		AND bu.IsPosted != 0 
ORDER BY [SN]  , [BillDate] , [Direction]  , [NUMBER]  
------------------------------------------------------------------------------------------ 
IF    @Mat_GUID <> 0x0               DELETE FROM  #hsh WHERE MatGuid <> @Mat_GUID 
IF    @Grp_GUID <> 0x0               DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].Gr_GUID   NOT IN (SELECT GUID FROM dbo.fnGetGroupsList  (@Grp_GUID)) 
IF    @st_GUID <> 0x0                DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].StoreGuid NOT IN (SELECT GUID FROM dbo.fnGetStoresList  (@st_GUID)) 
IF    @co_GUID <> 0x0                DELETE FROM  #hsh FROM  #hsh WHERE [#hsh].CostGUID  NOT IN (SELECT GUID FROM dbo.fnGetCostsList   (@co_GUID)) 
IF    @from_date <> '1/1/1800'       DELETE FROM  #hsh WHERE [BillDate] < @from_date 
IF    @to_date <> '1/1/1800'         DELETE FROM  #hsh WHERE [BillDate] > @to_date 

CREATE TABLE #temp1 ([SN] [NVARCHAR](255)  COLLATE ARABIC_CI_AI , _SUM [INT] , [GID] [INT]) 

INSERT INTO #temp1 
SELECT ISNULL(SN,'') AS SN , SUM(Direction) AS [Direction] , MAX(GID) AS [GID] 
FROM #hsh 
GROUP BY [SN] , [MatGuid] 

DELETE FROM #temp1 WHERE _Sum = 0 

SELECT [a].* 
FROM #hsh AS [a] 
INNER JOIN #temp1 AS [b] ON [a].[GID] = [b].[GID] 
ORDER BY [a].[SN]
#########################################################################################
CREATE  FUNCTION FnAssets()
RETURNS @result TABLE (
		[SN] NVARCHAR (256) COLLATE ARABIC_CI_AI,
		[SNGuid] UNIQUEIDENTIFIER,  
		[Guid] UNIQUEIDENTIFIER,  
		[adIndate] DATETIME,  
		[MatName] NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[MatGuid] UNIQUEIDENTIFIER,  
		[StoreName] NVARCHAR (256) COLLATE ARABIC_CI_AI,
		[StoreGuid] UNIQUEIDENTIFIER,  
		[CostName] NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[CostGuid] UNIQUEIDENTIFIER,  
		[GroupName] NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[GroupGuid] UNIQUEIDENTIFIER,  

		[billType]  NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[BillGuid]  UNIQUEIDENTIFIER,  
		[BillDate] DATETIME,
		[CurrencyGuid] UNIQUEIDENTIFIER,  
		[CurrencyVal] FLOAT, 
		[biPrice] FLOAT, 
		[InVal] FLOAT, 		
		[AddedVal] FLOAT, 		
		[DeductVal] FLOAT, 		
		[MaintenVal] FLOAT, 		
		[DeprecationVal]	FLOAT, 
		[BillBranch] UNIQUEIDENTIFIER)
BEGIN
	DECLARE @CNT INT
	DECLARE  @CostTbl TABLE  ( [GUID] [UNIQUEIDENTIFIER] ,Name  [NVARCHAR] (256) COLLATE ARABIC_CI_AI, LatinName  [NVARCHAR] (256) COLLATE ARABIC_CI_AI) 	
	INSERT INTO @CostTbl select Guid, Name , LatinName from co000
	INSERT INTO @CostTbl values(0x0, '', '')
	
	DECLARE @Lang	 int 
	SET @Lang  = dbo.fnConnections_GetLanguage()
	DECLARE   @ResultSN TABLE 
	( 
		[Id]						[INT] IDENTITY(1,1), 
		[MatName]					NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[StoreName]					NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[MatGuid]					UNIQUEIDENTIFIER,  
		[StoreGuid] 				UNIQUEIDENTIFIER,  
		[CostName]					NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[CostGuid] 					UNIQUEIDENTIFIER,  
		[GroupName] 				NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[GroupGuid] 				UNIQUEIDENTIFIER,
		[BillGuid]					UNIQUEIDENTIFIER , 
		[biPrice]					FLOAT, 
		[billDate]					DATETIME, 
		[CurrencyGuid] 				UNIQUEIDENTIFIER,  
		[CurrencyVal]				FLOAT, 
		[billType]					NVARCHAR (256) COLLATE ARABIC_CI_AI, 
		[BillBranch]				UNIQUEIDENTIFIER,
		[biGuid]					UNIQUEIDENTIFIER, 
		[buDirection]				INT 
	) 
	INSERT INTO @ResultSN
	( 
		[MatName], 
		[MatGuid],
		[StoreName], 
		[StoreGuid],
		[CostName],
		[CostGuid],
		[GroupName],
		[GroupGuid],
		[BillGuid], 
		[biPrice], 
		[billDate], 
		[CurrencyGuid] ,  
		[CurrencyVal], 
		[billType], 
		[BillBranch],
		[biGuid], 
		[buDirection]
	) 
	SELECT 
		CASE @Lang  WHEN 0 THEN mt.[Name] ELSE  CASE mt.[LatinName] WHEN '' THEN mt.[Name] ELSE mt.[LatinName] END END,
		mt.Guid,
		CASE @Lang  WHEN 0 THEN st.[Name] ELSE  CASE st.[LatinName] WHEN '' THEN st.[Name] ELSE st.[LatinName] END END,
		st.Guid,
		CASE @Lang  WHEN 0 THEN co.[Name] ELSE  CASE co.[LatinName] WHEN '' THEN co.[Name] ELSE co.[LatinName] END END,
		co.Guid,
		CASE @Lang  WHEN 0 THEN gr.[Name] ELSE  CASE gr.[LatinName] WHEN '' THEN gr.[Name] ELSE gr.[LatinName] END END,
		gr.Guid,
		[buGuid],
		[biPrice],
		[buDate],
		[buCurrencyPtr],
		[buCurrencyVal], 
		CASE @Lang  WHEN 0 THEN bt.[Name] ELSE  CASE bt.[LatinName] WHEN '' THEN bt.[Name] ELSE bt.[LatinName] END END,
		[buBranch],
		[biGuid],
		[buDirection]			 
	FROM 
		[vwBUbi] AS [bubi] 
		INNER JOIN bt000 AS [bt] ON bubi.[buType] = [bt].[Guid] 
		INNER JOIN mt000 AS [mt] ON bubi.[biMatPtr] = [mt].[Guid] 
		INNER JOIN gr000 AS [gr] ON gr.[Guid] = [mt].[GroupGuid] 
		INNER JOIN st000 AS [st] ON st.[Guid] = [bubi].[biStorePtr] 
		INNER JOIN @CostTbl AS [co] ON [co].[GUID] = [bubi].[biCostPtr] 
	WHERE 
		 [bubi].[buIsPosted] != 0 
	ORDER BY 
		Mt.[Name],
		bubi.[buDate]
	DECLARE  @sn TABLE
	( 
		[id] [INT],  
		[cnt] [INT],  
		[ParentGuid] UNIQUEIDENTIFIER
	) 
	INSERT INTO @sn --( [id],  [cnt], [ParentGuid]) 
		SELECT  MAX([Id]) AS ID ,SUM(buDirection) AS cnt ,[ParentGuid]  FROM [snt000] AS [sn] INNER JOIN @ResultSN [r] ON [sn].[biGuid] = [r].[biGuid] GROUP BY [ParentGuid],[stGuid] HAVING SUM(buDirection) > 0 
	DECLARE  @Isn2 TABLE
	( 
		[SNID] [INT] IDENTITY(1,1), 
		[id] [INT],  
		[cnt] [INT],  
		[Guid] UNIQUEIDENTIFIER, 
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Length]	[INT] 
	) 
	DECLARE   @Isn TABLE
	( 
		[SNID] [INT] , 
		[id] [INT],  
		[cnt] [INT],  
		[Guid] UNIQUEIDENTIFIER, 
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Length]	[INT] 
	) 
	 
	INSERT INTO @Isn2 ([Guid],[id],[cnt],[SN],[Length]) SELECT   Guid,[ID] ,[cnt],[SN],LEN([SN])  FROM @sn INNER JOIN [snC000] ON [Guid] = [ParentGuid] ORDER BY SN 
	INSERT INTO  @Isn SELECT *  FROM @Isn2
	IF EXISTS(SELECT * FROM @Isn WHERE [cnt] > 1) 
	BEGIN 
		SET @CNT = 1  
		WHILE (@CNT > 0) 
		BEGIN 
			INSERT INTO @Isn  
			SELECT  SNID, MAX([R].[Id]), 1, [I].[Guid], [sn].[SN], [Length]   
			FROM [vcSNs] AS [sn] 	INNER JOIN @ResultSN [R] ON [sn].[biGuid] = [R].[biGuid]  
									INNER JOIN @Isn I ON [sn].[Guid] = [I].[Guid]   
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM @Isn)  
			GROUP BY [sn].[SN],[SNID],[Length],[I].[Guid] 
			UPDATE @Isn SET [cnt] = [cnt] - 1 WHERE [cnt] > 1 
			SET @CNT = @@ROWCOUNT 
		END 
	END 
	--- Return first Result Set -- needed data 
	INSERT INTO @result
	SELECT 
		[SN].[SN], 
		[SN].[GUID] AS SNGuid,  
		[ad].[GUID] AS Guid,  
		[ad].[Indate] AS ADInDate,  
		[r].[MatName], 
		[r].[MatGuid], 
		[r].[StoreName], 
		[r].[StoreGuid], 
		[r].[CostName], 
		[r].[CostGuid], 
		[r].[GroupName], 
		[r].[GroupGuid], 
		[r].[billType], 
		[r].[BillGuid], 
		[r].[BillDate], 
		[r].[CurrencyGuid], 
		[r].[CurrencyVal], 
		[r].[biPrice], 
		[ad].[InVal], 
		[ad].[AddedVal] + SUM(CASE [ax].[Type] WHEN 0 THEN [ax].[Value] ELSE 0 END),
		[ad].[DeductVal] + SUM(CASE [ax].[Type] WHEN 1 THEN [ax].[Value] ELSE 0 END),
		[ad].[MaintenVal], 		
		[ad].[DeprecationVal], 
		[r].[BillBranch]
	FROM 
		@ResultSN AS [r] 	INNER JOIN @ISN AS [SN] ON [sn].[Id] = [r].[Id]
							INNER JOIN ad000 AS [ad] ON [sn].[Guid] = [ad].[snGuid]
							LEFT JOIN AX000 AS [ax] ON [ad].[GUID] = [ax].[ADGUID]
	GROUP BY
		[r].[ID],
		[SN].[Length],
		[SN].[SNID],
		[SN].[SN],
		[SN].[GUID],
		[ad].[GUID],
		[ad].[Indate],
		[r].[MatName],
		[r].[MatGuid],
		[r].[StoreName],
		[r].[StoreGuid],
		[r].[CostName],
		[r].[CostGuid],
		[r].[GroupName],
		[r].[GroupGuid],
		[r].[billType],
		[r].[BillGuid],
		[r].[BillDate],
		[r].[CurrencyGuid],
		[r].[CurrencyVal],
		[r].[biPrice],
		[ad].[InVal],
		[ad].[AddedVal],
		[ad].[DeductVal],
		[ad].[MaintenVal],
		[ad].[DeprecationVal],
		[r].[BillBranch]
	ORDER BY
		[r].[ID],
		[Length],
		[SNID]
	RETURN
END
#########################################################################################
CREATE PROC PrcAssetsRecalcIndate
            @StoreGUID    [UNIQUEIDENTIFIER] = 0x0,  
            @GroupGUID   [UNIQUEIDENTIFIER] = 0x0,
            @CostGUID       [UNIQUEIDENTIFIER] = 0x0, 
            @MatGUID      [UNIQUEIDENTIFIER] = 0x0,
            @INDATE                     DateTime = '1-1-2008'
AS
	SET NOCOUNT ON 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT],[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI) 
	INSERT INTO [#CostTbl]([CostGuid], [Security])		EXEC [prcGetCostsList] 			@CostGUID
	INSERT INTO [#CostTbl] ([CostGuid], [Security])	 VALUES (0x0, 1)
	--SELECT * from  #CostTbl
	CREATE TABLE [#StoreTbl](	[StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StoreGUID 

	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  NULL, @GroupGUID ,2

	SELECT 	Guid adGuid, 
			Sn  	adSN,
			MatName, 
			StoreName, 
			GroupName,
			BillDate
	into #Result			
	FROM dbo.fnAssets() fn  INNER JOIN #StoreTbl st ON st.StoreGuid =   fn.StoreGuid
							INNER JOIN #Mat mt ON mt.mtNumber =   fn.MatGuid
							INNER JOIN #CostTbl co ON (ISNULL(fn.CostGuid, 0x0) = co.CostGuid)
	WHERE MatGuid = @MatGUID OR @MatGUID = 0x0
	ORDER by MatName, Sn
	
	UPDATE AD000 SET  Indate = CASE @INDATE WHEN '1-1-1980' THEN SN.BillDate ELSE @INDATE END  
	FROM #Result Sn  INNER JOIN AD000 AD On SN.adGuid  =  AD.Guid
	SELECT  * FROM  #Result
#########################################################################################
CREATE PROCEDURE AssetsTrasferDelete
    @Guid        uniqueidentifier 
	,@Termination INT  
  AS    
	IF( ISNULL( @Termination , 0) = 1 )
	BEGIN
			DECLARE       
					  @BillGuidOut         UNIQUEIDENTIFIER 
					, @BillGuidIn          UNIQUEIDENTIFIER
					, @EntryGuidOut        UNIQUEIDENTIFIER      
					, @EntryGuidIn         UNIQUEIDENTIFIER 
					, @PyInGuid            UNIQUEIDENTIFIER
					, @PyOutGuid           UNIQUEIDENTIFIER
 
			SELECT      
						@BillGuidOut     = OutbuGuid            ,      
						@BillGuidIn      = InbuGuid             ,      
						@EntryGuidOut    = EntryGuidOut         ,      
						@EntryGuidIn     = EntryGuidIn          ,      
						@pyInGuid        = SrcEntryParent		,
						@pyOutGuid		 = DesEntryParent
			FROM AssTransferHeader000 h      
			WHERE guid = @Guid
			
			DELETE FROM PY000 WHERE Guid = @pyInGuid  OR Guid = @pyOutGuid 

			EXEC	prcBill_delete   @BillGuidOut   
			EXEC	prcBill_delete   @BillGuidIn   
			EXEC 	prcER_delete     @Guid, 4 
			EXEC    prcEntry_delete  @EntryGuidOut   
			EXEC    prcEntry_delete  @EntryGuidIn
	END

	DELETE FROM AssTransferHeader000  WHERE GUID = @GUID
	DELETE FROM AssTransferDetails000 WHERE ParentGuid = @GUID
#########################################################################################
CREATE PROC prcTransAssSaveBills  
@Guid UNIQUEIDENTIFIER = 0x0  ,      
 @EntryInType UNIQUEIDENTIFIER ,      
 @EntryOutType UNIQUEIDENTIFIER      
AS
	DECLARE @bAutoPost INT
	SET @bAutoPost = (SELECT TOP 1 bAutoPost FROM et000 WHERE GUID IN( @EntryInType ,@EntryOutType ))
SET NOCOUNT ON
			IF( ISNULL(@Guid,0x0) <> 0x0)          
			BEGIN                 
					DECLARE           
					  @BillNumberOut       BIGINT     
					, @BillNumberIn        BIGINT    
					, @StoreGuidOut        UNIQUEIDENTIFIER     
					, @StoreGuidIn         UNIQUEIDENTIFIER     
					, @CostGuidOut         UNIQUEIDENTIFIER     
					, @CostGuidIn          UNIQUEIDENTIFIER             
					, @BranchGUIDOut       UNIQUEIDENTIFIER     
					, @BranchGUIDIn        UNIQUEIDENTIFIER     
					, @NOTES               NVARCHAR(250)    
					, @DateOut             DATETIME     
					, @DateIn              DATETIME     
					, @CurrencyVal         FLOAT     
					, @CurrencyGuid        UNIQUEIDENTIFIER                
					, @CustomerGuid        UNIQUEIDENTIFIER    
					, @Security            INT    
					, @BillGuidOut         UNIQUEIDENTIFIER     
					, @BillGuidIn          UNIQUEIDENTIFIER    
					, @EntryGuidOut        UNIQUEIDENTIFIER          
					, @EntryGuidIn         UNIQUEIDENTIFIER     
					, @OutBillTypeGuid     UNIQUEIDENTIFIER    
					, @InBillTypeGuid      UNIQUEIDENTIFIER     
					, @BillTypeOut         UNIQUEIDENTIFIER	          
					, @BillTypeIn          UNIQUEIDENTIFIER    
					, @MidAccGuid          UNIQUEIDENTIFIER     
					, @entryNumOut         INT    
					, @entryNumIn          INT    
					, @CustomerAccGuid     UNIQUEIDENTIFIER    
					, @DefStoreDestination UNIQUEIDENTIFIER    
					, @DefStoreSource      UNIQUEIDENTIFIER     
					, @PyInGuid            UNIQUEIDENTIFIER    
					, @PyOutGuid           UNIQUEIDENTIFIER     
					, @PyInNumber          INT     
					, @PyOutNumber         INT       
					, @MidCustGuid		   UNIQUEIDENTIFIER
				    , @CustGuid            UNIQUEIDENTIFIER 
					, @AccGuid			   UNIQUEIDENTIFIER 
	 				
					SET @DefStoreDestination = (SELECT TOP 1(DESTINATIONSTORE) FROM ASSTRANSFERDETAILS000 WHERE PARENTGUID = @GUID)             
	 				SET @DefStoreSource      = (SELECT TOP 1(SourceSTORE) FROM ASSTRANSFERDETAILS000 WHERE PARENTGUID = @GUID)             		    
					
					SELECT          
							@BillGuidOut     = OutbuGuid            ,          
							@BillGuidIn      = InbuGuid             ,          
							@OutBillTypeGuid = OutBuTypeGuid        ,          
							@InBillTypeGuid  = InbuTypeGuid         ,          
							@EntryGuidOut    = EntryGuidOut         ,          
							@EntryGuidIn     = EntryGuidIn          ,          
							@MidAccGuid      = MidAccGuid           ,          
							@DateIn          = DateIn               ,              
							@DateOut         = DateOut              ,              
							@CurrencyGuid    = CurGuid              ,             
							@Notes           = Note + ' ' + CAST (Number as NVARCHAR(100)),  
							@BranchGuidOut   = BranchDestination    ,          
							@BranchGuidIn    = BranchSource         ,          
							@Security        = [Security]           ,          
							@CostGuidOut     = CostCenterSource     ,          
							@CostGuidIn      = CostCenterDestination,          
							@CustomerAccGuid = CustemerAccount      ,          
							@CurrencyVal     = CurrencyVal			,    
							@pyInGuid        = SrcEntryParent		,    
							@pyOutGuid		 = DesEntryParent    
					FROM AssTransferHeader000 h          
					WHERE guid = @Guid      
				    DECLARE @TotalAssVal FLOAT   
					SET @TotalAssVal = (SELECT SUM(AssVal) FROM VWAssTrans_Details WHERE ParentGuid = @Guid)   
 					
					--SELECT  CASE ISNULL((SELECT ISNULL(number,0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
						--				     WHEN 0 THEN (SELECT ISNULL(MAX(Number), 0 ) + 1 FROM py000)    
						--					 ELSE ISNULL((SELECT ISNULL(number , 0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
						--				    END    
  	    
					SELECT @PyInNumber    = CASE ISNULL((SELECT ISNULL(number,0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
													WHEN 0 THEN (SELECT ISNULL(MAX(Number), 0 ) + 1 FROM py000)    
													ELSE ISNULL((SELECT ISNULL(number , 0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
										    END    
						 , @PyOutNumber   = CASE ISNULL((SELECT ISNULL(number,0) FROM py000 WHERE Guid  = @pyOutGuid) , 0)    
										     WHEN 0 THEN (SELECT ISNULL(MAX(Number), 0 ) + 2 FROM py000)    
											 ELSE ISNULL((SELECT ISNULL(number , 0) FROM py000 WHERE Guid  = @pyOutGuid) , 0)    
										    END    
						 , @BillNumberOut = CASE ISNULL((SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidOut) ,   0)    
												WHEN 0 THEN ([dbo].[fnBill_getNewNum] (@OutBillTypeGuid , @BranchGuidIn ))    
												ELSE (SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidOut)    
											END    
						 , @BillNumberIn  = CASE ISNULL((SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidIn) , 0 )    
												WHEN 0 THEN ([dbo].[fnBill_getNewNum] (@InBillTypeGuid , @BranchGuidOut) + 1)    
												ELSE (SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidIn)    
											END    
						 , @entryNumOut   = CASE ISNULL((SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidOut) , 0)    
												WHEN 0 THEN ([dbo].[fnEntry_getNewNum](@BranchGUIDOut))    
												ELSE (SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidOut)    
											END    
						 , @entryNumIn    = CASE ISNULL((SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidIn) ,   0)    
												WHEN 0 THEN ([dbo].[fnEntry_getNewNum](@BranchGUIDIn) + 1)    
												ELSE (SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidIn)    
											END    
					--DECLARE @BuCreateUserGuid UNIQUEIDENTIFIER = ( SELECT CreateUserGUID FROM bu000 WHERE GUID = @BillGuidOut)  
					--DECLARE @BuCreateDate DATETIME = ( SELECT CreateDate FROM bu000 WHERE GUID = @BillGuidOut)  
					--DECLARE @CreateUserGuid UNIQUEIDENTIFIER = ( SELECT CreateUserGUID FROM ce000 WHERE GUID = @EntryGuidOut)  
					--DECLARE @CreateDate DATETIME = ( SELECT CreateDate FROM ce000 WHERE GUID = @EntryGuidOut)  
									 
					DELETE FROM PY000 WHERE Guid = @pyInGuid  OR Guid = @pyOutGuid     
					EXEC	prcBill_delete   @BillGuidOut       
					EXEC	prcBill_delete   @BillGuidIn       
					EXEC 	prcER_delete     @Guid, 4     
					EXEC    prcEntry_delete  @EntryGuidOut       
					EXEC    prcEntry_delete  @EntryGuidIn    
					IF( ISNULL( @PyInGuid , 0x0 ) = 0x0 OR ISNULL( @entryGUIDOut , 0x0) = 0x0 )    
					BEGIN     
							SET @BillGuidOut    = NEWID()    
							SET @BillGuidIn     = NEWID()   
							IF(@TotalAssVal > 0)   
							BEGIN   
								SET @PyInGuid       = NEWID()        
								SET @PyOutGuid      = NEWID()      
								SET @entryGUIDOut   = NEWID()           
								SET @entryGUIDIn    = NEWID()   
							END   
							ELSE   
							BEGIN   
								SET @PyInGuid       = 0x0       
								SET @PyOutGuid      = 0x0      
								SET @entryGUIDOut   = 0x0           
								SET @entryGUIDIn    = 0x0   
							END   
							SELECT @PyInNumber    = CASE ISNULL((SELECT ISNULL(number,0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
															WHEN 0 THEN (SELECT ISNULL(MAX(Number), 0 ) + 1 FROM py000)    
															ELSE ISNULL((SELECT ISNULL(number , 0) FROM py000 WHERE Guid  = @pyInGuid) , 0)    
													END    
								 , @PyOutNumber   = CASE ISNULL((SELECT ISNULL(number,0) FROM py000 WHERE Guid  = @pyOutGuid) , 0)    
													 WHEN 0 THEN (SELECT ISNULL(MAX(Number), 0 ) + 2 FROM py000)    
													 ELSE ISNULL((SELECT ISNULL(number , 0) FROM py000 WHERE Guid  = @pyOutGuid) , 0)    
													END    
								 , @BillNumberOut = CASE ISNULL((SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidOut) ,   0)    
														WHEN 0 THEN ([dbo].[fnBill_getNewNum] (@OutBillTypeGuid , @BranchGuidIn ))    
														ELSE (SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidOut)    
													END    
								 , @BillNumberIn  = CASE ISNULL((SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidIn) , 0 )    
														WHEN 0 THEN ([dbo].[fnBill_getNewNum] (@InBillTypeGuid , @BranchGuidOut) )    
														ELSE (SELECT ISNULL(Number ,0) FROM bu000 WHERE  Guid = @BillGuidIn)    
													END    
								 , @entryNumOut   = CASE ISNULL((SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidOut) , 0)    
														WHEN 0 THEN ([dbo].[fnEntry_getNewNum](@BranchGUIDOut))    
														ELSE (SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidOut)    
													END    
								 , @entryNumIn    = CASE ISNULL((SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidIn) ,   0)    
														WHEN 0 THEN ([dbo].[fnEntry_getNewNum](@BranchGUIDIn) + 1)    
														ELSE (SELECT ISNULL(Number ,0) FROM ce000 WHERE  Guid = @EntryGuidIn)    
													END    
					END   
					   
					IF(@TotalAssVal > 0)   
					BEGIN   
						INSERT INTO py000 (Number, Date, CurrencyVal,[Security], AccountGuid, Guid, TypeGuid, CurrencyGuid , BranchGuid, Notes)        
								SELECT @PyInNumber, At.DateOut, At.CurrencyVal , At.Security, et.DefAccGUID,  @PyInGuid, @EntryInType, At.CurGuid ,At.BranchSource, At.Note       
								FROM AssTransferHeader000 AS At      
								INNER JOIN et000 et ON et.Guid = @EntryInType        
								WHERE At.guid = @Guid    
	  	          
						INSERT INTO py000 (Number, Date, CurrencyVal,[Security], AccountGuid, Guid, TypeGuid, CurrencyGuid , BranchGuid, Notes)        
								SELECT @PyOutNumber, At.DateIn, At.CurrencyVal , At.Security, et.DefAccGUID,  @PyOutGuid, @EntryOutType, At.CurGuid ,At.BranchDestination, At.Note      
								FROM AssTransferHeader000 AS At      
								INNER JOIN et000 et ON et.Guid = @EntryOutType        
								WHERE At.guid = @Guid   								
					END
					-----------------------------------------------------------BILL OUT--------------------------------------------------------------------          
									DECLARE @BillCustGuid UNIQUEIDENTIFIER 
									SET @BillCustGuid = 0x0  
									SELECT @BillCustGuid = Guid FROM CU000 WHERE AccountGuid = @CustomerAccGuid 
									INSERT INTO Bu000 (Guid,  number, [Date],  Notes, PayType, TypeGuid			,  CurrencyGuid ,  CurrencyVal , StoreGuid  ,CostGuid  , [Security] ,CustGuid , CustAccGuid , Branch)              
									VALUES (@BillGuidOut , @BillNumberOut , @DateOut,  @Notes, 1, @OutBillTypeGuid , @CurrencyGuid , @CurrencyVal , @DefStoreSource, @CostGuidOut, @Security  , @BillCustGuid ,  @CustomerAccGuid , @BranchGuidIn)              
									SELECT  		              
												NewID() AS Guid,              
												ad.Guid adguid,             
												1 AS Qty,              
												1 AS Unity,               
												d.AssVal As Price,               
												h.CurGuid as CurrencyGuid,               
												@CurrencyVal as CurrencyVal,               
		 										d.Notes AS Notes,               
												d.SourceStore as StoreGuid,               
												@BillGuidOut AS BillGuid,               
												CASE WHEN d.SourceCost <> 0x0 THEN d.SourceCost ELSE h.CostCenterSource END as CostGuid,           
												@BillGuidOut as ParentGuid,          
												mt.Guid  as MatGuid          
									INTO #bi             
									FROM VWAssTrans_Details d          
											INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
											INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
											INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
											INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
									WHERE d.ParentGuid = @Guid          
									INSERT  INTO bi000               
										( Guid , Qty,  Unity,  Price,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  ParentGuid,  CostGuid,  MatGuid )              
									SELECT 	             
										 Guid , Qty,  Unity,  Price*CurrencyVal,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  BillGuid,  CostGuid,  MatGuid              
									FROM #bi          
									INSERT INTO snt000              
									(             
										Guid, Item,	biGuid,	stGuid, ParentGuid, Notes, buGuid            
									)             
									SELECT               
										NEWID(), 0, b.Guid, b.StoreGuid, Sn.Guid, '',  b.BillGuid               
									FROM #bi b           
														INNER JOIN ad000 ad ON ad.Guid = b.adGuid             
														INNER JOIN SNC000 SN ON ad.SnGuid = Sn.Guid            
									DROP TABLE #bi          
					------------------------------------------POST BILLS OUT------------------------------------------------------------------------------------             
						UPDATE bu000
						 SET
							Total = (SELECT SUM(Price) FROM bi000 WHERE ParentGuid = @BillGuidOut),
							Isposted = 1--,
							--LastUpdateDate = GETDATE(),
							--LastUpdateUserGUID = [dbo].fnGetCurrentUserGUID(),
							--CreateDate = CASE @BuCreateDate WHEN NULL THEN createdate ELSE @BuCreateDate END ,
							--CreateUserGUID = @BuCreateUserGuid
						WHERE
							Guid = @BillGuidOut
						EXEC 	prcBill_post @BillGuidOut, 1     
					--------------------------------------------------------------------IN BILL----------------------------------------------------------------          
									SET @BillCustGuid = 0x0 
									SELECT @BillCustGuid = Guid FROM CU000 WHERE AccountGuid = @MidAccGuid 
									INSERT INTO Bu000 (Guid,  number, [Date],  Notes, PayType, TypeGuid			,  CurrencyGuid ,  CurrencyVal , StoreGuid  ,CostGuid  , [Security] ,CustGuid , CustAccGuid , Branch)              
									VALUES (@BillGuidIn , @BillNumberIn , @DateIn,  @Notes, 1		 , @InBillTypeGuid , @CurrencyGuid , @CurrencyVal , @DefStoreDestination, @CostGuidIn, @Security  , @BillCustGuid , @MidAccGuid, @BranchGuidOut)              
									SELECT  		              
												NewID() AS Guid,              
												ad.Guid adguid,             
												1 AS Qty,              
												1 AS Unity,               
												d.AssVal As Price,               
												h.CurGuid as CurrencyGuid,               
												@CurrencyVal as CurrencyVal,               
		 										d.Notes AS Notes,               
												d.DestinationStore as StoreGuid,               
												@BillGuidIn AS BillGuid,               
												CASE WHEN d.DestinationCost <> 0x0 THEN d.DestinationCost ELSE h.CostCenterDestination END as CostGuid, 
												@BillGuidIn as ParentGuid,          
												mt.Guid  as MatGuid          
									INTO #bi1             
									FROM VWAssTrans_Details d          
											INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
											INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
											INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
											INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
									WHERE d.ParentGuid = @Guid          
									INSERT  INTO bi000               
										( Guid , Qty,  Unity,  Price,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  ParentGuid,  CostGuid,  MatGuid )              
									SELECT 	             
										 Guid , Qty,  Unity,  Price*CurrencyVal,  CurrencyGuid,  CurrencyVal,  Notes,  StoreGuid,  BillGuid,  CostGuid,  MatGuid              
									FROM #bi1          
									INSERT INTO snt000              
									(             
										Guid, Item,	biGuid,	stGuid, ParentGuid, Notes, buGuid            
									)             
									SELECT               
										NEWID(), 0, b.Guid, b.StoreGuid, Sn.Guid, '',  b.BillGuid               
									FROM #bi1 b           
														INNER JOIN ad000 ad ON ad.Guid = b.adGuid             
														INNER JOIN SNC000 SN ON ad.SnGuid = Sn.Guid            
									DROP TABLE #bi1					          
			------------------------------------------POST BILLS IN------------------------------------------------------------------------------------          
								UPDATE bu000
									SET
										Total = (SELECT SUM(Price) FROM bi000 WHERE ParentGuid = @BillGuidIn),
		             					Isposted = 1--,
										--LastUpdateDate = GETDATE(),
										--LastUpdateUserGUID = [dbo].fnGetCurrentUserGUID(),
										--CreateDate = @BuCreateDate,
										--CreateUserGUID = @BuCreateUserGuid
									WHERE
										Guid = @BillGuidIn        
								          
								EXEC 	prcBill_post @BillGuidIn, 1				          
			-----------------------------------------------OUT ENTRY-------------------------------------------------------------------------------          
			-------------------------------------------------------------------------------------------------------------------------------------------						             
								   
								IF(@TotalAssVal > 0)   
								BEGIN      
									INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [PostDate])                
										SELECT			  @EntryOutType, 1, @entryNumOut, @DateIn, @Notes, @CurrencyVal, 0, @Security, @BranchGUIDOut, @entryGUIDOut, @CurrencyGuid, GETDATE()                
								END   
								
								  IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @MidAccGuid and CustomersCount > 1)
								  BEGIN
									  INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									  SELECT 1, 0, 'AmnE0052: [' + CAST(@MidAccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									  RETURN 
								  END 
								  ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @MidAccGuid and CustomersCount = 1)
								  BEGIN
									SELECT @MidCustGuid = CuGUID FROM vwCu WHERE cuAccount = @MidAccGuid 
								  END
								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
											1 as number,              
											@MidAccGuid as accountGUID,             
											h.DateOut as [date],              
											0 as Debit,               
											d.AssVal*@CurrencyVal As Credit,               
											d.Notes + '-' + mt.Code + '-' + mt.Name,          
											h.CurGuid as CurrencyGUID,               
											@CurrencyVal as CurrencyVal,               
											@entryGUIDOut as ParentGuid,               
											0x0,--CASE WHEN d.DestinationCost <> 0x0 THEN d.DestinationCost ELSE h.CostCenterDestination END as CostGuid, 
											Ass.AccGuid  as ContraAccGUID,
											ISNULL(@MidCustGuid, 0x0)          
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0         
								SET @AccGuid = 0x0 
								SET	@CustGuid = 0x0
								
								SELECT @AccGuid = Ass.AccGuid             
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid   
										INNER JOIN vwAcCu ac on ac.GUID =  ass.AccGUID  
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 
								IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1 )
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END 
								ELSE if EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount = 1) 
								BEGIN
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @AccGuid 
								END

								INSERT INTO en000           
									([number], [accountGUID], [Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
									1 as number,              
									Ass.AccGuid as accountGUID,             
									h.DateOut as [date],              
									d.AssVal*@CurrencyVal as Debit,               
									0        As Credit,               
									d.Notes + '-' + mt.Code + '-' + mt.Name,          
									h.CurGuid as CurrencyGUID,               
									@CurrencyVal as CurrencyVal,          
									@entryGUIDOut as ParentGuid,               
									CASE WHEN d.DestinationCost <> 0x0 THEN d.DestinationCost ELSE h.CostCenterDestination END as CostGuid, 
									@MidAccGuid  as ContraAccGUID,
									ISNULL(@CustGuid, 0x0)          
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0           
								         
								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
											1 as number,              
											@MidAccGuid as accountGUID,             
											h.DateOut as [date],              
											d.AssDep as Debit,               
											0 As Credit,               
											d.Notes + '-' + mt.Code + '-' + mt.Name,          
											h.CurGuid as CurrencyGUID,               
											@CurrencyVal as CurrencyVal,               
											@entryGUIDOut as ParentGuid,               
											0x0,--CASE WHEN d.DestinationCost <> 0x0 THEN d.DestinationCost ELSE h.CostCenterDestination END as CostGuid, 
											Ass.AccuDepAccGuid  as ContraAccGUID,
											ISNULL(@MidCustGuid, 0x0)          
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 AND d.AssDep > 0
								
								SET @AccGuid = 0x0 
								SET	@CustGuid = 0x0
								
								SELECT @AccGuid = Ass.AccuDepAccGuid             
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid
										INNER JOIN vwAcCu ac  on ac.GUID =  ass.AccGUID           
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 AND d.AssDep > 0
								IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1 )
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END 
								ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount = 1 )
								BEGIN
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @AccGuid 
								END
								       
								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
											1 as number,              
											Ass.AccuDepAccGuid as accountGUID,             
											h.DateOut as [date],              
											0        As Debit,               
											d.AssDep as Credit,               
											d.Notes + '-' + mt.Code + '-' + mt.Name,          
											h.CurGuid as CurrencyGUID,               
											@CurrencyVal as CurrencyVal,          
											@entryGUIDOut as ParentGuid,               
											CASE WHEN d.DestinationCost <> 0x0 THEN d.DestinationCost ELSE h.CostCenterDestination END as CostGuid, 
											@MidAccGuid  as ContraAccGUID,
											ISNULL(@CustGuid, 0x0)          
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 AND d.AssDep > 0          
			------------------------------------------------------------POST ENTRY OUT----------------------------------------------------------		          
					IF(@TotalAssVal > 0)   
					BEGIN     
						UPDATE ce000 
							SET           
								Debit = (SELECT SUM(Debit) FROM en000 WHERE ParentGuid = @EntryGuidOut),          
								Credit = (SELECT SUM(Credit) FROM en000 WHERE ParentGuid = @EntryGuidOut)--, 
								--LastUpdateDate = GETDATE(),
								--LastUpdateUserGUID = [dbo].fnGetCurrentUserGUID(),
								--CreateDate = @CreateDate,
								--CreateUserGUID = @CreateUserGuid           
							WHERE 
								Guid = @EntryGuidOut          
						          
						INSERT INTO [er000]           
								([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])                 
						VALUES          
								(@EntryGuidOut, @PyOutGuid, 103, @BillNumberOut)          
									          
						EXEC prcEntry_post @EntryGuidOut, 1
						IF(@bAutoPost=1)
						BEGIN
							UPDATE Ce000 SET IsPosted = 1 WHERE GUID = @EntryGuidOut
						END
				   END   
			-------------------------------------------------IN ENTRY-------------------------------------------------------------------------------          
								IF(@TotalAssVal > 0)   
								BEGIN   	
								  
									INSERT INTO [ce000] ([typeGUID], [Type], [Number], [Date], [Notes], [CurrencyVal], [IsPosted], [Security], [Branch], [GUID], [CurrencyGUID], [PostDate])          
										SELECT			  @EntryInType, 1, @entryNumIn, @DateOut, @Notes, @CurrencyVal, 0, @Security, @BranchGUIDIn, @entryGUIDIn, @CurrencyGuid, GETDATE()                
								END   
                                SET @CustGuid = 0x0

								IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @CustomerAccGuid and CustomersCount > 1)
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@CustomerAccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END 
								ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @CustomerAccGuid and CustomersCount = 1)
								BEGIN
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @CustomerAccGuid 
								END
						
								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
									1 as number,              
									@CustomerAccGuid as accountGUID,             
									h.DateIn as [date],              
									d.AssVal*@CurrencyVal as Debit,               
									0 As Credit,               
									d.Notes + '-' + mt.Code + '-' + mt.Name,          
									h.CurGuid as CurrencyGUID,               
									@CurrencyVal as CurrencyVal,               
									@entryGUIDIn as ParentGuid,               
									0x0,--CASE WHEN d.SourceCost <> 0x0 THEN d.SourceCost ELSE h.CostCenterSource END as  CostGuid, 
									Ass.AccGuid  as ContraAccGUID  ,
									ISNULL(@CustGuid, 0x0)        
								FROM VWAssTrans_Details d          
									INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
									INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
									INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
									INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid   AND d.AssVal > 0         
								  
								SET @AccGuid = 0x0 
								SET	@CustGuid = 0x0
								
								SELECT @AccGuid = Ass.AccGuid             
								FROM VWAssTrans_Details d          
									INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
									INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
									INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
									INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid    
									INNER JOIN vwAcCu ac on ac.GUID =  ass.AccGUID        
								WHERE d.ParentGuid = @Guid  AND d.AssVal > 0
								IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1 )
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END
								ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount = 1 ) 
								BEGIN
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @AccGuid 
								END  
								         
								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
									1 as number,              
									Ass.AccGuid as accountGUID,             
									h.DateIn as [date],              
									0        As Debit,               
									d.AssVal*@CurrencyVal as Credit,               
									d.Notes + '-' + mt.Code + '-' + mt.Name,          
									h.CurGuid as CurrencyGUID,               
									@CurrencyVal as CurrencyVal,          
									@entryGUIDIn as ParentGuid,               
									CASE WHEN d.SourceCost <> 0x0 THEN d.SourceCost ELSE h.CostCenterSource END as CostGuid, 
									@CustomerAccGuid  as ContraAccGUID,
									ISNULL(@CustGuid, 0x0)         
								FROM VWAssTrans_Details d          
									INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
									INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
									INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
									INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid  AND d.AssVal > 0          
								
								SET @CustGuid = 0x0;
								
								IF EXISTS( SELECT * FROM vwAcCu WHERE GUID = @CustomerAccGuid and CustomersCount > 1)
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@CustomerAccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END 
								ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @CustomerAccGuid and CustomersCount = 1)
								BEGIN
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @CustomerAccGuid 
								END

								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID],[CustomerGUID])	              
								SELECT  		              
											1 as number,              
											@CustomerAccGuid as accountGUID,             
											h.DateIn as [date],              
											0 as Debit,               
											d.AssDep as Credit,               
											d.Notes + '-' + mt.Code + '-' + mt.Name,          
											h.CurGuid as CurrencyGUID,               
											@CurrencyVal as CurrencyVal,               
											@entryGUIDIn as ParentGuid,               
											0x0,--CASE WHEN d.SourceCost <> 0x0 THEN d.SourceCost ELSE h.CostCenterSource END as CostGuid, 
											Ass.AccuDepAccGuid  as ContraAccGUID,
											ISNULL(@CustGuid, 0x0)          
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid  AND d.AssVal > 0 AND d.AssDep > 0         
								        
								SET @AccGuid = 0x0 
								SET	@CustGuid = 0x0
								
								SELECT @AccGuid = Ass.AccuDepAccGuid             
								FROM VWAssTrans_Details d          
										INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
										INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
										INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
										INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid
										INNER JOIN vwAcCu ac  on ac.GUID =  ass.AccGUID           
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 AND d.AssDep > 0
								IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount > 1 )							
								BEGIN
									INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
									SELECT 1, 0, 'AmnE0052: [' + CAST(@AccGuid AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
									RETURN 
								END 
								ELSE IF EXISTS(SELECT * FROM vwAcCu WHERE GUID = @AccGuid and CustomersCount = 1 )	
								BEGIN 
									SELECT @CustGuid = CuGUID FROM vwCu WHERE cuAccount = @AccGuid 
								END

								INSERT INTO en000           
									([number], [accountGUID],	[Date], [Debit], [Credit], [Notes], [CurrencyGUID],[CurrencyVal], [ParentGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])	              
								SELECT  		              
									1 as number,              
									Ass.AccuDepAccGuid as accountGUID,             
									h.DateIn as [date],              
									d.AssDep as Debit,               
									0        As Credit,               
									d.Notes  +'-' + mt.Code + '-' + mt.Name,          
									h.CurGuid as CurrencyGUID,               
									@CurrencyVal as CurrencyVal,          
									@entryGUIDIn as ParentGuid,               
									CASE WHEN d.SourceCost <> 0x0 THEN d.SourceCost ELSE h.CostCenterSource END as CostGuid, 
									@CustomerAccGuid  as ContraAccGUID,
									ISNULL(@CustGuid, 0x0)      
								FROM VWAssTrans_Details d          
									INNER JOIN AssTransferHeader000 h   on d.ParentGuid = h.guid	          
									INNER JOIN ad000  ad  on d.adGuid = ad.Guid              
									INNER JOIN as000  ass on ass.Guid = ad.ParentGuid              
									INNER JOIN mt000  mt  on mt.Guid = ass.ParentGuid          
								WHERE d.ParentGuid = @Guid AND d.AssVal > 0 AND d.AssDep > 0							          
			--------------------------------------------------------------POST ENTRY OUT----------------------------------------------------------		          
					IF(@TotalAssVal > 0)   
					BEGIN      
						UPDATE ce000
							SET        
								Debit = (SELECT SUM(Debit) FROM en000 WHERE ParentGuid = @entryGUIDIn),          
								Credit = (SELECT SUM(Credit) FROM en000 WHERE ParentGuid = @entryGUIDIn)--,
								--LastUpdateDate = GETDATE(),
								--LastUpdateUserGUID = [dbo].fnGetCurrentUserGUID(),
								--CreateDate = @CreateDate,
								--CreateUserGUID = @CreateUserGuid          
							WHERE
								Guid = @entryGUIDIn          
						          
						INSERT INTO [er000]           
								([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])                 
						VALUES          
								(@entryGUIDIn, @PyInGuid, 103, @entryNumIn)          
									          
						EXEC prcEntry_post @entryGUIDIn, 1   
						IF(@bAutoPost=1)
						BEGIN
							UPDATE Ce000 SET IsPosted = 1 WHERE GUID = @entryGUIDIn
						END
				    END      			          
			------------------------------------------------------------POST ENTRY----------------------------------------------------------		          
				UPDATE AssTransferHeader000 SET           
						  OutbuGuid      = @BillGuidOut    
						, InbuGuid       = @BillGuidIn    
						, OutBuTypeGuid  = @OutBillTypeGuid    
						, InbuTypeGuid   = @InBillTypeGuid    
						, EntryGuidOut   = @EntryGuidOut    
						, EntryGuidIn    = @EntryGuidIn    
						, MidAccGuid     = @MidAccGuid    
						, SrcEntryParent = @PyInGuid    
						, DesEntryParent = @PyOutGuid       
				WHERE [Guid] = @Guid		          
			END
#########################################################################################
CREATE PROC repAssTrans
(
       @GUID                  UNIQUEIDENTIFIER        = 0x0
      ,@ASSGUID         UNIQUEIDENTIFIER        = 0X0 
      ,@SOURCEBRANCH  UNIQUEIDENTIFIER        = 0X0 
      ,@SOURCESTORE     UNIQUEIDENTIFIER        = 0X0 
      ,@DESBRANCH       UNIQUEIDENTIFIER        = 0X0 
      ,@DESSTORE        UNIQUEIDENTIFIER        = 0X0 
      ,@DATEFROM        DATETIME                    = '1-1-1800' 
      ,@DATETO          DATETIME                = '1-1-2070'
) 
AS  
SET NOCOUNT ON 
IF (@GUID = 0x0)
BEGIN
            SELECT  
                               DET.ADGUID                                                                                       [GUID]
                               , AD.SN + '-' + MT.CODE + '-' + MT.NAME                                                    [SN]
                               , BR1.GUID                                                                                             BRANCHSOURCEGUID 
                               , BR1.NAME                                                                                             BRANCHSOURCE
                               , ST1.GUID                                                                                             STORESOURCEGUID
                               , ST1.NAME                                                                                             STORESOURCE
                               , BR2.GUID                                                                                             BRANCHDESTINATIONGUID
                               , BR2.NAME                                                                                             BRANCHDESTINATION
                               , ST2.GUID                                                                                             STOREDESTINATIONGUID
                               , ST2.NAME                                                                                             STOREDESTINATION 
                               , CAST (0 AS FLOAT) /*DD.TOTALDEP*/                                                                              TOTALDEP 
                               , CAST('1-1-1890' AS DATETIME)  /*DD.UNTILDATE*/                                     UNTILDATE 
                               , HDR.NOTE                                                                                             NOTE
                               , (SELECT TOP 1 CURRENCYGUID FROM DD000 DD WHERE DD.ADGUID = DET.ADGUID) CURRENCYGUID 
                               , HDR.[SECURITY]                                                                                 [SECURITY] 
                               , HDR.DATEOUT                                                                                          DATEOUT 
                               , [AS].ACCUDEPACCGUID                                                                            ACCUDEPACCGUID
                               , DET.SourceCost                                                                           SourceCost
                               , DET.DestinationCost                                                                      DestinationCost

                               
            INTO #HSH 
            FROM ASSTRANSFERDETAILS000            DET
            INNER JOIN  ASSTRANSFERHEADER000  HDR   ON DET.PARENTGUID                 = HDR.GUID  
            INNER JOIN  AD000                     AD    ON AD.GUID                                    = DET.ADGUID 
            LEFT  JOIN  AS000                     [AS]  ON AD.PARENTGUID                        = [AS].GUID    
            LEFT  JOIN  BR000                     BR1   ON HDR.BRANCHSOURCE                   = BR1.GUID 
            LEFT  JOIN  BR000                     BR2   ON HDR.BRANCHDESTINATION        = BR2.GUID               
            LEFT  JOIN  ST000                     ST1   ON DET.SOURCESTORE                    = ST1.GUID 
            LEFT  JOIN  ST000                     ST2   ON DET.DESTINATIONSTORE               = ST2.GUID  
            LEFT  JOIN  SNC000                          SNC   ON SNC.GUID                    = AD.SNGUID                              
            LEFT  JOIN  MT000                     MT    ON SNC.MATGUID              = MT.GUID
            WHERE HDR.DateOut >= @DATEFROM AND HDR.DateOut <= @DATETO
            GROUP BY      DET.ADGUID
                                , AD.SN + '-' + MT.CODE + '-' + MT.NAME
                                , BR1.GUID
                                , BR1.NAME
                                , ST1.GUID
                                , ST1.NAME
                                , BR2.GUID
                                , BR2.NAME
                                , ST2.GUID
                                , ST2.NAME
                                , HDR.NOTE
                                , HDR.[SECURITY]
                                , HDR.DATEOUT
                                , [AS].ACCUDEPACCGUID
                                , DET.SourceCost
								, DET.DestinationCost


            UPDATE #HSH SET  TOTALDEP  = dd.TOTALDEP
                                    ,UNTILDATE = dd.UNTILDATE
            FROM #HSH hsh
            INNER JOIN 
            (
                  SELECT 
                               GUID 
                           , SN
                           , CASE ISNULL(BRANCHSOURCEGUID , 0x0) WHEN 0x0 THEN (SELECT TOP 1 GUID FROM br000 ORDER BY Number) ELSE BRANCHSOURCEGUID END AS BRANCHSOURCEGUID
                           , SUM(TOTALDEP) TOTALDEP
                           , UNTILDATE
                  FROM
                        (
                              SELECT 
                                     AD.GUID                                                                                              AS [GUID] 
                                ,  AD.SN + '-' + MT.CODE + '-' + MT.NAME                                                      AS SN 
                                ,  DP.BRANCHGUID                                                                                          AS BRANCHSOURCEGUID
                                , (ISNULL(DD.VALUE    , 0 ))                                                                        AS TOTALDEP
                                , (ISNULL((SELECT MAX(TODATE) FROM DD000 WHERE ADGUID = DD.ADGUID), 0 ))  AS UNTILDATE
                              FROM        DP000                     DP 
                              INNER JOIN  DD000                     DD  ON DP.GUID                    = DD.PARENTGUID
                              INNER JOIN  AD000                     AD    ON AD.GUID                        = DD.ADGUID 
                              LEFT  JOIN  AS000                     [AS]  ON AD.PARENTGUID         = [AS].GUID 
                              LEFT  JOIN  SNC000                          SNC   ON SNC.GUID                     = AD.SNGUID                                 
                              LEFT  JOIN  MT000                     MT    ON SNC.MATGUID           = MT.GUID   
                              WHERE DD.ToDATE >= @DATEFROM AND DD.ToDATE <= @DATETO                            
                        ) a
                  GROUP BY           GUID
                                       , SN
                                       , BRANCHSOURCEGUID
                                       , UNTILDATE
            )dd  ON hsh.GUID = dd.GUID AND hsh.BRANCHSOURCEGUID = dd.BRANCHSOURCEGUID
            

                  IF(@ASSGUID <> 0X0) 
                              DELETE FROM #HSH WHERE GUID <> @ASSGUID 
                               
                  IF(@SOURCEBRANCH <> 0X0) 
                              DELETE FROM #HSH WHERE BRANCHSOURCEGUID <> @SOURCEBRANCH 
                                                             
                  IF(@SOURCESTORE <> 0X0) 
                              DELETE FROM #HSH WHERE STORESOURCEGUID <> @SOURCESTORE 
                                     
                  IF(@DESBRANCH <> 0X0) 
                              DELETE FROM #HSH WHERE BRANCHDESTINATIONGUID <> @DESBRANCH 
                                           
                  IF(@DESSTORE <> 0X0) 
                              DELETE FROM #HSH WHERE STOREDESTINATIONGUID <> @DESSTORE 


                  UPDATE #HSH SET TOTALDEP = ISNULL(hsh.TOTALDEP,0) - ISNULL(h.Val , 0)
                  FROM #HSH hsh 
                  LEFT JOIN   
                  ( 
                         SELECT  HSH.GUID ,
                                     HSH.BRANCHSOURCEGUID BRANCHGUID, 
                                     SUM( ISNULL(DET.AssDep,0) ) Val
                               FROM       #HSH        HSH
                               LEFT JOIN   assTransferReportDetails000        DET   ON HSH.Guid         = DET.AssGuid AND HSH.BRANCHSOURCEGUID = DET.SourceBranch
                          GROUP BY HSH.Guid ,HSH.BRANCHSOURCEGUID ,DET.AssGuid
                  )h ON h.GUID = hsh.GUID AND h.BRANCHGUID = hsh.BRANCHSOURCEGUID
                  

                  DELETE FROM #HSH WHERE TOTALDEP <= 0
				  UPDATE #HSH SET TOTALDEP = TOTALDEP - ( SELECT ISNULL(SUM(value), 0) from dd000 dd inner join dp000 dp on dp.guid = dd.parentguid where BranchGuid = BRANCHSOURCEGUID AND dd.ToDate > DateOut AND dd.AdGuid = #HSH.Guid  ) 
                  SELECT * INTO #TMPHSH FROM #HSH
				  UPDATE #HSH SET TOTALDEP = TOTALDEP - ISNULL(( SELECT Top 1 TOTALDEP FROM #TMPHSH TMPHSH WHERE TMPHSH.DateOut < #HSH.DateOut AND TMPHSH.Guid = #HSH.Guid AND TMPHSH.BRANCHSOURCEGUID = #HSH.BRANCHSOURCEGUID ORDER BY TMPHSH.DateOut DESC ), 0)
                  SELECT * FROM #HSH Order By SN, DateOut DESC
END
ELSE
BEGIN
                  SELECT 
                    AD.GUID, 
                    AD.SN + '-' + MT.CODE + '-' + MT.NAME SN   , 
                    BR1.GUID AS BRANCHSOURCEGUID                        , 
                    BR1.NAME AS BRANCHSOURCE                            , 
                    ST1.GUID AS STORESOURCEGUID                   , 
                    ST1.NAME AS STORESOURCE                             , 
                    BR2.GUID AS BRANCHDESTINATIONGUID             , 
                    BR2.NAME AS BRANCHDESTINATION                       , 
                    ST2.GUID AS STOREDESTINATIONGUID              , 
                    ST2.NAME AS STOREDESTINATION                        , 
                   (ISNULL(DET.AssDep              , 0 )) AS TOTALDEP, 
                   (ISNULL(DET.LastDepDate    , 0 )) AS UNTILDATE 
                  FROM      assTransferReportHeader000  HDR
                  INNER JOIN  assTransferReportDetails000 DET   ON DET.ParentGUID              = HDR.GUID   
                  INNER JOIN  AD000                               AD    ON AD.GUID                    = DET.AssGuid 
                  LEFT  JOIN  BR000                               BR1   ON DET.SOURCEBRANCH            = BR1.GUID 
                  LEFT  JOIN  BR000                               BR2   ON DET.DESTINATIONBRANCH   = BR2.GUID            
                  LEFT  JOIN  ST000                               ST1   ON DET.SOURCESTORE            = ST1.GUID                  
                  LEFT  JOIN  ST000                               ST2   ON DET.DESTINATIONSTORE    = ST2.GUID            
                  LEFT  JOIN  AS000                               [AS]  ON AD.PARENTGUID              = [AS].GUID 
                  LEFT  JOIN  SNC000                                    SNC   ON SNC.GUID                = AD.SNGUID                                 
                  LEFT  JOIN  MT000                               MT    ON SNC.MATGUID                = MT.GUID
                  WHERE HDR.GUID = @GUID
                  ORDER BY DET.Number
END          
#########################################################################################
CREATE FUNCTION fnAssGetNewEntryNumber()
RETURNS INT 
BEGIN
	RETURN (SELECT ISNULL( MAX(Number) + 1, 1)  FROM ce000)
END
#########################################################################################
CREATE PROC prcGenAssReportEntries
(
			 @Guid				UNIQUEIDENTIFIER 
			,@MidAccGuid		UNIQUEIDENTIFIER = 0x0   
			,@MidAccDesGuid		UNIQUEIDENTIFIER = 0x0
            ,@assGuid			UNIQUEIDENTIFIER = 0x0   
            ,@SourceBranch		UNIQUEIDENTIFIER = 0x0   
            ,@SourceStore		UNIQUEIDENTIFIER = 0x0   
            ,@DesBranch			UNIQUEIDENTIFIER = 0x0   
            ,@DesStore			UNIQUEIDENTIFIER = 0x0   
            ,@DateFrom			DATETIME		 = '1-1-1800'   
            ,@DateTo			DATETIME		 = '1-1-2070'
			,@Security			INT				 = 1
			,@IncludeAllCostCenters bit			 = 0
			,@EntryTypeGuid		UNIQUEIDENTIFIER = 0x0
			,@CreateDate		DATETIME
			,@CreateUserGUID	UNIQUEIDENTIFIER
			,@isModify			BIT  
)
AS 
SET NOCOUNT ON
	DECLARE @bAutoPost INT
	SET @bAutoPost = (SELECT TOP 1 bAutoPost FROM et000 WHERE GUID = @EntryTypeGuid)
BEGIN TRAN
          

			DECLARE @Hrd_Num INT 
			SET @Hrd_Num = ( SELECT ISNULL( MAX(Number) + 1 , 1 )  FROM assTransferReportHeader000)
			DECLARE @Py_Num INT
			SET @Py_Num = ( SELECT ISNULL( MAX(Number) + 1 , 1 )  FROM py000 where [TypeGUID] = @EntryTypeGuid ) 
			
			CREATE TABLE #HSH
			(
					    GUID					UNIQUEIDENTIFIER, 
						SN						NVARCHAR(200)    , 
						BRANCHSOURCEGUID		UNIQUEIDENTIFIER, 
						BRANCHSOURCE			NVARCHAR(200)    , 
						STORESOURCEGUID			UNIQUEIDENTIFIER, 
						STORESOURCE				NVARCHAR(200)    , 
						BRANCHDESTINATIONGUID	UNIQUEIDENTIFIER, 
						BRANCHDESTINATION		NVARCHAR(200)    , 
						STOREDESTINATIONGUID	UNIQUEIDENTIFIER, 
						STOREDESTINATION		NVARCHAR(200)    , 
						TOTALDEP				FLOAT           , 
						UNTILDATE				DATETIME	    ,
					    NOTE					NVARCHAR(200)	,
						CURRENCYGUID			UNIQUEIDENTIFIER,
						[SECURITY]				INT				,
						DATEOUT					DATETIME		,
						ACCUDEPACCGUID			UNIQUEIDENTIFIER,
						SOURCECOST				UNIQUEIDENTIFIER,
						DESTINATIONCOST			UNIQUEIDENTIFIER 
			)

			INSERT INTO #HSH 
							(
							   GUID, 	  
							   SN,
							   BRANCHSOURCEGUID,
							   BRANCHSOURCE,
							   STORESOURCEGUID,
							   STORESOURCE,
							   BRANCHDESTINATIONGUID,
							   BRANCHDESTINATION, 
							   STOREDESTINATIONGUID, 
							   STOREDESTINATION, 
							   TOTALDEP, 
							   UNTILDATE,
							   NOTE,
		                       CURRENCYGUID,
							   [SECURITY],
							   DATEOUT,
							   ACCUDEPACCGUID,
							   SOURCECOST,
							   DESTINATIONCOST
							)
			EXEC repAssTrans 0x0, @assGuid, @SourceBranch, @SourceStore, @DesBranch, @DesStore, @DateFrom, @DateTo
IF((SELECT COUNT(*) FROM #HSH) > 0)
BEGIN
				INSERT INTO assTransferReportDetails000
				SELECT   NEWID() AS GUID,
						 (SELECT ISNULL( MAX(Number) + 1, 1)  FROM assTransferReportDetails000) Number,
						 @Guid					ParentGuid,
						 [GUID]					AssGuid,
						 BranchSourceGuid		SourceBranch,
						 StoreSourceGuid		SourceStore,
						 StoreDestinationGuid	DestinationStore,
						 BranchDestinationGuid	DestinationBranch,
						 TotalDep				AssDep,
						 UntilDate				LastDepDate
				FROM         #HSH
				
				
				INSERT INTO assTransferReportHeader000
						   (
								 [GUID] 
								,Number
								,[Security]
								,AssGuid
								,SourceBranch
								,SourceStore
								,DestinationBranch
								,DestinationStore
								,FromDate
								,ToDate
								,MidAccGuid
								,MidAccDesGuid
								,IncludeAllCostCenters 
								,EntryTypeGuid
							)
				VALUES     
							(
								@Guid
							  , @Hrd_Num
							  , @Security
							  ,	@assGuid
							  , @SourceBranch
							  , @SourceStore
							  , @DesBranch
							  , @DesStore
							  , @DateFrom
							  , @DateTo
							  , @MidAccGuid
							  , @MidAccDesGuid
							  , @IncludeAllCostCenters 
							  , @EntryTypeGuid
							)
				
				

				INSERT INTO assTransferReportEntries000
				SELECT NEWID() GUID,
					   @Guid					ParentGuid,
					   NEWID()					EntryGuidSource,
					   BranchSourceGuid			BranchGuidSource,
					   NEWID()					EntryGuidDestination,
					   BranchDestinationGuid	BranchGuidDestination
				FROM #hsh
				GROUP BY  BranchSourceGuid, BranchDestinationGuid
				
				
				CREATE TABLE #Ce_Hash
				(   
							NumberIdn			  INT IDENTITY(1,1),   
							Guid				  uniqueidentifier,   
							Number				  INT,   
							OutEntryGUID		  uniqueidentifier,
							BranchSourceGuid	  uniqueidentifier,   
							InEntryGUID			  uniqueidentifier,
							BranchDestinationGuid uniqueidentifier,   
							DateOut				  datetime,   
							[Security]			  int,   
							CurrencyGuid		  uniqueidentifier,   
							value				  float   
				)

				INSERT INTO #Ce_Hash
				SELECT   
							 Guid
							,([dbo].[fnEntry_getNewNum](ent.BranchGuidSource)) Number   
							, ent.EntryGuidSource
							, ent.BranchGuidSource
							, ent.EntryGuidDestination
							, ent.BranchGuidDestination  
							, (SELECT TOP 1 DateOut
							   FROM #hsh h 
							   WHERE h.BranchDestinationGuid = ent.BranchGuidDestination AND h.BranchSourceGuid = ent.BranchGuidSource) as DateOut
							,  (SELECT TOP 1 [Security] 
							   FROM #hsh h 
							   WHERE h.BranchDestinationGuid = ent.BranchGuidDestination AND h.BranchSourceGuid = ent.BranchGuidSource) as [Security]   
							, (SELECT TOP 1 CurrencyGuid 
							   FROM #hsh h 
							   WHERE h.BranchDestinationGuid = ent.BranchGuidDestination AND h.BranchSourceGuid = ent.BranchGuidSource) as CurrencyGuid
							, (SELECT TOP 1 Sum(TotalDep)
							   FROM    #hsh h 
							   WHERE h.BranchDestinationGuid = ent.BranchGuidDestination AND h.BranchSourceGuid = ent.BranchGuidSource) as value   
				FROM assTransferReportEntries000 ent
				WHERE ParentGuid = @Guid
				SELECT * FROM #Ce_Hash

				DECLARE @TotalValue FLOAT 

				SET @TotalValue = (SELECT SUM(ISNULL([value],0)) FROM #Ce_Hash) 
	IF (@TotalValue > 0) 
	BEGIN
				INSERT INTO [py000] (
										Number,
										Date, 
										CurrencyVal,
										Security, 
										AccountGuid, 
										Guid, 
										TypeGuid, 
										CurrencyGuid , 
										BranchGuid
									)
				SELECT					@Py_Num,
										DateOut,
										1,
										Security,
										0x0,
										OutEntryGUID,
										@EntryTypeGuid,
										CurrencyGuid,
										BranchSourceGuid
				FROM #Ce_Hash
				
				INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])        
				SELECT	OutEntryGUID, 
						OutEntryGUID, 
						1, 
						0
				FROM #Ce_Hash

				INSERT INTO [ce000]		(
																 [typeGUID],   
																 [Type],   
																 [Number],   
																 [Date]  ,   
																 [Notes] ,   
																 [CurrencyVal],   
																 [IsPosted],   
																 [Security],   
																 [Branch],   
																 [GUID]  ,   
																 [CurrencyGUID],   
																 Debit,   
																 Credit,
																 PostDate
										)            
				SELECT											 0x0											  as typeGUID		,   
																 1												  as Type			,   
																 dbo.fnAssGetNewEntryNumber()						as Number			,   
																 DateOut										  as Date			,   
																 'ﬁÌœ „‰«ﬁ·… «·«Â ·«ﬂ«  «·Õ«·Ì… »Ì‰ «·›—Ê⁄'			  as Notes			,   
																 1												  as CurrencyVal	,
																 0												  as IsPosted		,   
																 [Security]															,   
																 BranchSourceGuid								  as Branch			,   
																 OutEntryGUID									  as GUID			,   
																 CurrencyGuid									  as CurrencyGUID	,   
																 value																,   
																 value															    ,
																 GETDATE()
				FROM #Ce_Hash  
	                
				SELECT OutEntryGUID EntryGuid, NEWID() NewGuid
	            INTO #TmpCeGuids
	            FROM #Ce_Hash
				
				UPDATE ER000 
				SET EntryGuid = TmpCeGuids.NewGuid
				FROM Er000 Er
				INNER JOIN #TmpCeGuids TmpCeGuids ON TmpCeGuids.EntryGuid = Er.ParentGuid
				WHERE Er.ParentGuid = Er.EntryGuid
				
				UPDATE Ce000
				SET Guid = TmpCeGuids.NewGuid,
					CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
					CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
					LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
					LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
				FROM Ce000 Ce
				INNER JOIN #TmpCeGuids TmpCeGuids ON TmpCeGuids.EntryGuid = Ce.Guid
				DELETE FROM #TmpCeGuids
					           
				INSERT INTO en000       
									(
													 CostGUID, 
													 [number]      , 
													 [accountGUID] , 
													 [Date]		   , 
													 [Debit]       , 
													 [Credit]      , 
													 [Notes]	   , 
													 [CurrencyGUID], 
													 [CurrencyVal] , 
													 [ParentGUID]  , 
													 [ContraAccGUID]
									)                   
				SELECT								CASE @IncludeAllCostCenters WHEN 0 THEN 0x0 ELSE hsh.SourceCost END,   
													1                    as number       ,          
													hsh.AccuDepAccGuid   as accountGUID  ,         
													hsh.DateOut          as [date]       ,          
													(
													 SELECT SUM(TotalDep) 
													 FROM #hsh sumhsh
													 WHERE      sumhsh.DateOut               <= hsh.DateOut
														   AND  sumhsh.GUID					  = hsh.GUID 
													)					 as Debit											  ,           
													0                    as Credit											  ,           
													'„‰«ﬁ·… „Ã„⁄ «Â ·«ﬂ √’· ' + ISNULL((SELECT SN FROM AD000 WHERE Guid = hsh.Guid ) , '') ,      
													hsh.CurrencyGuid														  ,           
													1																		  ,           
													Er.EntryGuid		as ParentGuid										  ,           
													@MidAccGuid			as ContraAccGUID        
				FROM #hsh hsh
				INNER JOIN #Ce_Hash ce on hsh.BranchDestinationGuid = ce.BranchDestinationGuid AND hsh.BranchSourceGuid = ce.BranchSourceGuid 
				INNER JOIN Er000 Er ON ce.OutEntryGUID = Er.ParentGuid
				
				INSERT INTO en000       
							(
													 CostGUID, 
													 [number]      , 
													 [accountGUID] , 
													 [Date]		   , 
													 [Debit]       , 
													 [Credit]      , 
													 [Notes]	   , 
													 [CurrencyGUID], 
													 [CurrencyVal] , 
													 [ParentGUID]  , 
													 [ContraAccGUID]
							)                   
				SELECT								0x0, 
													1					   as number		  ,          
													@MidAccGuid            as accountGUID     ,         
													hsh.DateOut            as [date]          ,          
													0                      as Debit           ,           
													(
													 SELECT SUM(TotalDep) 
													 FROM #hsh sumhsh
													 WHERE      sumhsh.DateOut               <= hsh.DateOut
														   AND  sumhsh.GUID					  = hsh.GUID 													)						as Credit		  ,           
													'„‰«ﬁ·… „Ã„⁄ «Â ·«ﬂ √’· ' + ISNULL((SELECT SN FROM AD000 WHERE Guid = hsh.Guid ) , '') ,      
													hsh.CurrencyGuid                          ,           
													1                                         ,           
													Er.EntryGuid        as ParentGuid	  ,           
													hsh.AccuDepAccGuid     as ContraAccGUID        
				FROM #hsh hsh
				INNER JOIN #Ce_Hash ce on hsh.BranchDestinationGuid = ce.BranchDestinationGuid AND hsh.BranchSourceGuid = ce.BranchSourceGuid 			
				INNER JOIN Er000 Er ON ce.OutEntryGUID = Er.ParentGuid
				IF(@bAutoPost = 1)
				BEGIN
					UPDATE ce000 SET IsPosted = 1 WHERE Guid IN (SELECT OutEntryGUID FROM #Ce_Hash)
				END
	------------------------------------------------------- The Oposit Entry --------------------------------------------------------------------------   
				INSERT INTO [py000] (
										Number,
										Date, 
										CurrencyVal,
										Security, 
										AccountGuid, 
										Guid, 
										TypeGuid, 
										CurrencyGuid , 
										BranchGuid									
									)
				SELECT					@Py_Num+1,
										DateOut,
										1,
										Security,
										0x0,
										InEntryGUID,
										@EntryTypeGuid,
										CurrencyGuid,
										BranchDestinationGuid									
				FROM #Ce_Hash
				
				INSERT INTO [er000] ([EntryGUID], [ParentGUID], [ParentType], [ParentNumber])        
				SELECT	InEntryGUID, 
						InEntryGUID, 
						1, 
						0
				FROM #Ce_Hash
				
				INSERT INTO [ce000]							    ([typeGUID],   
																 [Type],   
																 [Number],   
																 [Date]  ,   
																 [Notes] ,   
																 [CurrencyVal],   
																 [IsPosted],   
																 [Security],   
																 [Branch],   
																 [GUID]  ,   
																 [CurrencyGUID],   
																 Debit,   
																 Credit,
																 PostDate)            
				SELECT											 0x0													as typeGUID		,   
																 1														as Type			,   
																 dbo.fnAssGetNewEntryNumber()							as Number		,   
																 DateOut												as Date			,   
																 'ﬁÌœ „‰«ﬁ·… «·«Â ·«ﬂ«  «·Õ«·Ì… »Ì‰ «·›—Ê⁄'					as Notes		,   
																 1														as CurrencyVal	,   
																 0														as IsPosted		,   
																 [Security]																,   
																 BranchDestinationGuid									as Branch		,   
																 InEntryGUID											as GUID			,   
																 CurrencyGuid											as CurrencyGUID ,   
																 value																	,   
																 value																	,
																 GETDATE()   
				FROM #Ce_Hash   
	            
				INSERT INTO #TmpCeGuids            
	            SELECT InEntryGUID EntryGuid, NEWID() NewGuid
	            FROM #Ce_Hash
				
				UPDATE ER000 
				SET EntryGuid = TmpCeGuids.NewGuid
				FROM Er000 Er
				INNER JOIN #TmpCeGuids TmpCeGuids ON TmpCeGuids.EntryGuid = Er.ParentGuid
				WHERE Er.ParentGuid = Er.EntryGuid
				
				UPDATE Ce000
				SET Guid = TmpCeGuids.NewGuid,
					CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
					CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
					LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
					LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
				FROM Ce000 Ce
				INNER JOIN #TmpCeGuids TmpCeGuids ON TmpCeGuids.EntryGuid = Ce.Guid
				DELETE FROM #TmpCeGuids
				               
				INSERT INTO en000       
													(CostGUID, 
													 [number]      , 
													 [accountGUID] , 
													 [Date]		   , 
													 [Debit]       , 
													 [Credit]      , 
													 [Notes]	   , 
													 [CurrencyGUID], 
													 [CurrencyVal] , 
													 [ParentGUID]  , 
													 [ContraAccGUID])                   
				SELECT								0x0, 
													1                   as number        ,          
													@MidAccDesGuid         as accountGUID   ,         
													hsh.DateOut         as [date]		 ,          
													(
													 SELECT SUM(TotalDep) 
													 FROM #hsh sumhsh
													 WHERE      sumhsh.DateOut               <= hsh.DateOut
														   AND  sumhsh.GUID					  = hsh.GUID 													)				    as Debit         ,           
													0					as Credit        ,           
													'„‰«ﬁ·… „Ã„⁄ «Â ·«ﬂ √’· ' + ISNULL((SELECT SN FROM AD000 WHERE Guid = hsh.Guid ) , '') ,      
													hsh.CurrencyGuid                     ,           
													1                                    ,           
													Er.EntryGuid      as ParentGuid    ,           
													hsh.AccuDepAccGuid  as ContraAccGUID        
				FROM #hsh hsh
				INNER JOIN #Ce_Hash ce on hsh.BranchDestinationGuid = ce.BranchDestinationGuid AND hsh.BranchSourceGuid = ce.BranchSourceGuid 
				INNER JOIN Er000 Er ON ce.InEntryGUID = Er.ParentGuid
				
				INSERT INTO en000       
													(CostGUID, 
													 [number]      , 
													 [accountGUID] , 
													 [Date]		   , 
													 [Debit]       , 
													 [Credit]      , 
													 [Notes]	   , 
													 [CurrencyGUID], 
													 [CurrencyVal] , 
													 [ParentGUID]  , 
													 [ContraAccGUID])                   
				SELECT								CASE @IncludeAllCostCenters WHEN 0 THEN 0x0 ELSE hsh.DestinationCost END,  
													1						  as number       ,          
													hsh.AccuDepAccGuid        as accountGUID  ,         
													hsh.DateOut               as [date]       ,          
													0                         as Debit        ,           
													(
													 SELECT SUM(TotalDep) 
													 FROM #hsh sumhsh
													 WHERE      sumhsh.DateOut               <= hsh.DateOut
														   AND  sumhsh.GUID					  = hsh.GUID 													)					      as Credit       ,           
													'„‰«ﬁ·… „Ã„⁄ «Â ·«ﬂ √’· ' + ISNULL((SELECT SN FROM AD000 WHERE Guid = hsh.Guid ) , '') ,      
													hsh.CurrencyGuid                          ,           
													1                                         ,           
													Er.EntryGuid			  as ParentGuid   ,           
													@MidAccDesGuid				  as ContraAccGUID        
				FROM #hsh hsh
				INNER JOIN #Ce_Hash ce on hsh.BranchDestinationGuid = ce.BranchDestinationGuid AND hsh.BranchSourceGuid = ce.BranchSourceGuid 
				INNER JOIN Er000 Er ON ce.InEntryGUID = Er.ParentGuid
				
				SELECT OutEntryGUID Guid INTO #TMPCE FROM #Ce_Hash  
				INSERT INTO #TMPCE SELECT InEntryGUID Guid FROM #Ce_Hash 
				
				DELETE FROM #TMPCE WHERE Guid IN (SELECT Guid FROM Ce000 WHERE Debit <> 0 OR Credit <> 0)
				IF(@bAutoPost = 0)
				BEGIN
					UPDATE ce000 SET IsPosted = 0 WHERE Guid IN (SELECT Guid FROM #TMPCE)
				END
				DELETE FROM ce000 WHERE Guid IN (SELECT Guid FROM #TMPCE)
				
				UPDATE Py000 
				SET	CreateDate = CASE WHEN @isModify = 1 THEN  @CreateDate ELSE GETDATE() END,
					CreateUserGUID = CASE WHEN @isModify = 1 THEN  @CreateUserGUID ELSE [dbo].[fnGetCurrentUserGUID]() END,
					LastUpdateDate = CASE WHEN @isModify = 1 THEN  GETDATE() ELSE LastUpdateDate END,
					LastUpdateUserGUID = CASE WHEN @isModify = 1 THEN  [dbo].[fnGetCurrentUserGUID]() ELSE LastUpdateUserGUID END
				from  Py000  Py
				INNER JOIN assTransferReportEntries000 ATRE ON Py.Guid = ATRE.EntryGuidSource OR Py.Guid = ATRE.EntryGuidDestination 
				WHERE ATRE.ParentGuid = @Guid

				UPDATE Py000			 
				SET AccountGuid = En.AccountGuid					
				FROM Py000 Py 
				INNER JOIN assTransferReportEntries000 ATRE ON Py.Guid = ATRE.EntryGuidSource OR Py.Guid = ATRE.EntryGuidDestination
				INNER JOIN Er000 Er ON Py.Guid = Er.ParentGuid
				INNER JOIN Ce000 Ce ON Ce.Guid = Er.EntryGuid
				INNER JOIN En000 En ON En.ParentGuid = Ce.Guid
				INNER JOIN et000 et ON et.Guid = @EntryTypeGuid
				WHERE ATRE.ParentGuid = @Guid
				AND
				(
				/* œ›⁄ */ et.FldCredit = 0 AND et.FldDebit = 1 AND En.Credit > 0
				OR
				/* ﬁ»÷ */ et.FldCredit = 1 AND et.FldDebit = 0 AND En.Debit > 0
				)
				CREATE TABLE #TmpOrderTbl( id int identity(1,1), SourceGuid UNIQUEIDENTIFIER, DestinationGuid UNIQUEIDENTIFIER)
				INSERT INTO #TmpOrderTbl (SourceGuid, DestinationGuid) 
				SELECT EntryGuidSource, EntryGuidDestination
				FROM assTransferReportEntries000
				WHERE ParentGuid = @Guid
				
				
				DELETE FROM En000
				WHERE ParentGuid IN
				(
					SELECT Er.EntryGuid
					FROM Py000 Py 
					INNER JOIN assTransferReportEntries000 ATRE ON Py.Guid = ATRE.EntryGuidSource OR Py.Guid = ATRE.EntryGuidDestination
					INNER JOIN Er000 Er ON Py.Guid = Er.ParentGuid
					WHERE ATRE.ParentGuid = @Guid
				)
				AND Debit = 0 AND Credit = 0
				
				DELETE FROM Ce000
				WHERE 
				Guid IN
				(
					SELECT Er.EntryGuid
					FROM Py000 Py 
					INNER JOIN assTransferReportEntries000 ATRE ON Py.Guid = ATRE.EntryGuidSource OR Py.Guid = ATRE.EntryGuidDestination
					INNER JOIN Er000 Er ON Py.Guid = Er.ParentGuid
				)
				AND Guid NOT IN
				(
					SELECT ParentGuid FROM En000
				)
				
				DELETE FROM Er000
				WHERE 
				(
				ParentGuid IN ( SELECT EntryGuidSource FROM assTransferReportEntries000 WHERE ParentGuid = @Guid )
				OR
				ParentGuid IN ( SELECT EntryGuidDestination FROM assTransferReportEntries000 WHERE ParentGuid = @Guid )
				)
				AND
				EntryGuid NOT IN (SELECT Guid FROM Ce000)
				
				DELETE FROM Py000
				WHERE 
				(
				Guid IN ( SELECT EntryGuidSource FROM assTransferReportEntries000 WHERE ParentGuid = @Guid )
				OR
				Guid IN ( SELECT EntryGuidDestination FROM assTransferReportEntries000 WHERE ParentGuid = @Guid )
				)
				AND
				Guid NOT IN (SELECT ParentGuid FROM Er000)
				
				UPDATE ce000 SET IsPosted = 1 WHERE Guid IN (SELECT InEntryGUID FROM #Ce_Hash)
	END
END
COMMIT TRAN
#########################################################################################
CREATE VIEW vwassTransferReportEntries
AS
SELECT ent.[ParentGuid]
	 , [EntryGuidSource]
	 , [EntryGuidDestination]
	 , br0.Name BranchSource
	 , br1.Name BranchDestination
FROM assTransferReportEntries000 ent
INNER JOIN br000 br0 ON ent.[BranchGuidSource]      = br0.Guid
INNER JOIN br000 br1 ON ent.[BranchGuidDestination] = br1.Guid

#########################################################################################
CREATE PROC DeleteAssetsTransReport
(
	@Guid UNIQUEIDENTIFIER
)
AS
BEGIN TRAN
		
		DELETE FROM assTransferReportHeader000  WHERE GUID       = @Guid
		DELETE FROM assTransferReportDetails000 WHERE PARENTGUID = @Guid
		DELETE FROM assTransferReportEntries000 WHERE ParentGuid  = @Guid 
	
COMMIT TRAN
#########################################################################################
CREATE PROC GetAssDetailsLastPos
(
	@adGuid uniqueidentifier
)
AS
SET NOCOUNT ON

DECLARE @SN Uniqueidentifier
DECLARE @Mat Uniqueidentifier

SELECT @SN  = SnGuid,
	   @Mat = MatGuid
FROM       AD000  AD0
INNER JOIN AS000  AS0 ON AD0.Parentguid = AS0.Guid
INNER JOIN SNC000 SN0 ON AD0.SnGuid     = SN0.Guid
WHERE AD0.GUID = @adGuid

CREATE TABLE [#SNALL]  
(  
	[GID]         [INT] ,[SN]     [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[SNGuid]          [UNIQUEIDENTIFIER],[MatGuid]          [UNIQUEIDENTIFIER],  
	[MatName]        [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[StoreGuid]          [UNIQUEIDENTIFIER],[StoreName]   [NVARCHAR](255)  COLLATE ARABIC_CI_AI,  
	[BillTypeGuid]          [UNIQUEIDENTIFIER], [BillGuid]          [UNIQUEIDENTIFIER], [CustomerName] [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[BillDate]        [DATETIME],  
	[Bill]		  [NVARCHAR](255)  COLLATE ARABIC_CI_AI,[PRICE]       [FLOAT],[Number]      [FLOAT],[BranchGuid]  [UNIQUEIDENTIFIER],[CostGUID]    [UNIQUEIDENTIFIER],  
	[Direction]   [INT],[Gr_GUID]     [UNIQUEIDENTIFIER],[Ac_GUID]     [UNIQUEIDENTIFIER]  
 )

INSERT INTO [#SNALL]       ([GID],[SN],[SNGuid],[MatGuid],[MatName],[StoreGuid],[StoreName],[BillTypeGuid],[BillGuid],[CustomerName],[BillDate],[Bill],  
	[PRICE],[Number],[BranchGuid],[CostGUID],[Direction],[Gr_GUID],[Ac_GUID])      
EXEC SN_lastcheck @Mat , 0x0 , 0x0 , 0x0 , '1980-1-1' , '2050-1-1' , 0x0  



SELECT 
		ISNULL(br0.Code + ' - ' + br0.Name , '') BranchName,
		ISNULL(st0.Code + ' - ' + st0.Name , '') StoreName,
		ISNULL(co0.Code + ' - ' + co0.Name , '') CostCenterName
FROM [#SNALL] sn
LEFT JOIN br000 br0 ON br0.[Guid] = sn.[BranchGuid]
LEFT JOIN st000 st0 ON st0.[Guid] = sn.[StoreGuid]
LEFT JOIN co000 co0 ON co0.[Guid] = sn.[CostGUID]
WHERE SnGuid = @Sn
#########################################################################################
#END
