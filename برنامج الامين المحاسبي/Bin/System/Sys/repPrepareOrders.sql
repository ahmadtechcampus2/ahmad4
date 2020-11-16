#######################################
CREATE PROCEDURE repPrepareOrders
	@Acc [UNIQUEIDENTIFIER] = 0x0,      
	@Mt AS [UNIQUEIDENTIFIER] = 0x0,      
	@Gr AS [UNIQUEIDENTIFIER] = 0x0,      
	@Store AS [UNIQUEIDENTIFIER] = 0x0,  
	@OrderNum AS BIGINT = 0,     
	@Src AS [UNIQUEIDENTIFIER] = 0x0,   
	@StartDate [DATETIME] = '1/1/2009',      
	@EndDate [DATETIME] = '12/01/2009',   
	@Cost [UNIQUEIDENTIFIER] = 0x0,   
	@MatCond UNIQUEIDENTIFIER = 0x00, 
	@CustCondGuid UNIQUEIDENTIFIER = 0x00, 
	@OrderCond	UNIQUEIDENTIFIER = 0x00	,  
	@SortType INT = 0,
	@ShowStoreMaterial INT = 0,
	@ShowServiceMaterial INT = 0,
	@ShowAssets INT = 0
AS     
	SET NOCOUNT ON  
	DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
	-------Bill Resource ---------------------------------------------------------        
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT],[ReadPrice] [INT], [UnPostedSec] [INT]) 
	declare @UserGuid uniqueidentifier  
	set @UserGuid = dbo.fnGetCurrentUserGUID()  
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src
	-------OrderCond Table---------------------------------------------------------- 
	CREATE TABLE #OrderCond ( OrderGuid UNIQUEIDENTIFIER, [Security] [INT])  
	INSERT INTO [#OrderCond](OrderGuid, [Security]) EXEC [prcGetOrdersList] @OrderCond   
	-------Customer Table----------------------------------------------------------         
	CREATE TABLE [#CustTbl]([Guid] [UNIQUEIDENTIFIER], [cuSec] [INT]) 
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] NULL, @Acc, @CustCondGuid   
	IF ISNULL( @Acc, 0x0) = 0x0      
	BEGIN 
		INSERT INTO [#CustTbl] VALUES( 0x0,1)   
	END 
	-------Mat Table----------------------------------------------------------         
	CREATE TABLE [#MatTbl]( [mtGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])           
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  @Mt, @Gr, -1  , @MatCond
	-------Store Table----------------------------------------------------------         
	DECLARE @StoreTbl TABLE( [stGuid] [UNIQUEIDENTIFIER],[stCode] NVARCHAR(255) COLLATE ARABIC_CI_AI,[stName] NVARCHAR(255) COLLATE ARABIC_CI_AI)          
	INSERT INTO @StoreTbl SELECT [f].[Guid],[st].[Code],[st].[Name] FROM [fnGetStoresList]( @Store) AS [f] INNER JOIN [st000] AS [st] ON [st].[Guid] = [f].[Guid]          
	-------Cost Table-----------------------------------------------------------     
	DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER])         
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @Cost)           
	IF ISNULL( @Cost, 0x0) = 0x0      
		INSERT INTO @CostTbl VALUES( 0x0)          
	--------------------------------------------------------------------------------
	-------[#Result] Table----------------------------------------------------------       
	CREATE TABLE [#Result](   
		[buGuid] [uniqueidentifier],      
		[buTypeGuid] [uniqueidentifier],      
		[buDate] [datetime],  
		[biGuid] [uniqueidentifier], 
		[FromTypeGuid]  [uniqueidentifier], 
		[buNumber] [FLOAT],   
		[biNumber] [FLOAT],   
		[buNotes] NVARCHAR(1000) collate ARABIC_CI_AI,  
		[biNotes] NVARCHAR(1000) collate ARABIC_CI_AI,  
		[OrderName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[CustName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[MatGuid] [uniqueidentifier],      
		[MatCode] NVARCHAR(255) collate ARABIC_CI_AI,  
		[MatName] NVARCHAR(255) collate ARABIC_CI_AI,
		[CompositionName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[MatLatinName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[QtyOrder] [float],  
		[QtyPerform] [float],   
		[QtyBack] [float],   
		[QtyPost] [float],   
		[QtyPostToBill] [float], 
		[QtyFixedStore] [float],  
		[QtyStore] [float],   
		[StoreGuid] [UNIQUEIDENTIFIER],   
		[StoreName]  NVARCHAR(255) collate ARABIC_CI_AI,  
		[StoreCode]  NVARCHAR(255) collate ARABIC_CI_AI,  
		[Unity] [INT],   
		[UnitFact] [FLOAT],   
		[UnitName] NVARCHAR(255) COLLATE ARABIC_CI_AI,  
		[OrderPrice] [FLOAT],  
		[biCurrencyVal] [FLOAT],  
		[mtSecurity] [INT],  
		[buSecurity] [INT],  
		[UserSecurity][INT],  
		[biBillBonusQnt] [FLOAT],  
		[BIDiscountRatio]  [FLOAT],                
		[BIExtraRatio]  [FLOAT],  
		[biLength] [FLOAT],                                     
		[biWidth][FLOAT],  
		[biHeight]   [FLOAT],                                           
		[biQty2]  [FLOAT],                                             
		[biQty3]  [FLOAT], 
		[mtUnit2Fact]  [FLOAT], 
		[mtUnit3Fact]  [FLOAT],			                                           			 
		[biCostPtr]  [UNIQUEIDENTIFIER] ,                                           
		[biClassPtr] NVARCHAR(255) collate ARABIC_CI_AI,  
		[biProductionDate] [datetime],                                     
		[biExpireDate]  [datetime],  
		[biExpireFlag] [int] , 
		[StateGuid]  [UNIQUEIDENTIFIER], 
		[BillGuid]  [UNIQUEIDENTIFIER],
		[QtyStageCompleted] [BIT],
		[Operation] [int] , 
		[SNumber] [int], 
		[MatLowLimit] [FLOAT], 
		[MatOrderLimit] [FLOAT], 
		[SOType] [INT], 
		[SOGuid] [UNIQUEIDENTIFIER],
		[IsIntegerQuantity] [INT],
		SDDATE [datetime],ADDATE [datetime],coName NVARCHAR(255) collate ARABIC_CI_AI,ApprovalState  [int]
		)   
		 
		CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])       

	--/////////////////////////////////////////////////		   
	INSERT INTO #Result(   
			[buGuid], [buTypeGuid], [buDate],[biGuid], [buNumber],   
			[biNumber],[buNotes],[OrderName],[CustName],   
			[MatGuid], [MatCode], [MatName], [CompositionName], [MatLatinName], [QtyOrder],   
		    [QtyPerform], [QtyBack], [QtyPost],[QtyPostToBill] ,[QtyFixedStore],[QtyStore],   
			[StoreGuid], [StoreName], [StoreCode], [Unity], [UnitFact],   
			[UnitName], [OrderPrice], [biCurrencyVal], [mtSecurity], [buSecurity],  
			[UserSecurity] ,[biBillBonusQnt] ,[biDiscountRatio] ,[biExtraRatio] , 
			[biLength] ,[biWidth] ,[biHeight] ,[biQty2] ,[mtUnit2Fact] , 
			[biQty3] , [mtUnit3Fact] ,[biCostPtr] , 
			[biClassPtr] ,[biProductionDate] ,[biExpireDate], [biExpireFlag] , [MatLowLimit], [MatOrderLimit], 
			[SOType], [SOGuid],[IsIntegerQuantity],SDDATE,ADDATE,coName, [ApprovalState])   
	SELECT --DISTINCT  
		buGuid,   
		buType,   
		buDate, 
		biGuid,  
		buNumber,   
		biNumber,  			  
		buNotes, 
		(CASE @Lang WHEN 0 THEN [buFormatedNumber] ELSE (CASE [buLatinFormatedNumber] WHEN N'' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END) END ) AS buFormatedNumber,   
		buCust_Name,   
		biMatPtr,   
		mtCode,   
		(CASE @Lang WHEN 0 THEN mtName ELSE (CASE mtLatinName WHEN N'' THEN mtName ELSE mtLatinName END) END ) AS mtName,   
		CompositionName,   
		mtLatinName,   
		biBillQty AS [QtyOrder],   
		isnull( ori.oriQty, 0) / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) AS [QtyPerform],   
		0 AS QtyBack ,  
		0 AS [QtyPost],   
		0 AS [QtyPostToBill] ,  
		0, 
		0, 
		[stTbl].stGuid,   
		[stTbl].stName,   
		[stTbl].stCode,   
		biUnity,   
		mtUnitFact,   
		mtUnityName,  
		CASE bi.btVATSystem  
			WHEN 2 THEN ((biUnitPrice * mtUnitFact * (1 + biVATr/100))) / CASE biCurrencyVal WHEN 0 THEN 1 ELSE biCurrencyVal END 
			ELSE (biUnitPrice * mtUnitFact) / CASE biCurrencyVal WHEN 0 THEN 1 ELSE biCurrencyVal END 
		END, 
		biCurrencyVal, 
		mt.mtSecurity,  
		buSecurity,  
		CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,  
		[biBillBonusQnt] , 
		CASE biCurrencyVal WHEN 0 THEN biDiscount ELSE  biDiscount / biCurrencyVal END , 
		CASE biCurrencyVal WHEN 0 THEN biExtra ELSE  biExtra / biCurrencyVal END , 
		[biLength] ,[biWidth] ,[biHeight]  , 
		[bi].[biQty2] , [bi].[mtUnit2Fact] , 
		[bi].[biQty3] , [bi].[mtUnit3Fact] , 
		[biCostPtr] ,[biClassPtr] ,[biProductionDate] ,[biExpireDate] ,[mtExpireFlag],
		[mat].[Low], 
		[mat].[OrderLimit], 
        [bi].[biSOType], 
		[bi].[biSOGuid],
		[mat].[IsIntegerQuantity],
		OInfo.SDDATE,
		OInfo.ADDATE,
		(CASE @Lang WHEN 0 THEN coTb.Name ELSE (CASE coTb.LatinName WHEN N'' THEN coTb.Name ELSE coTb.LatinName END) END ) coName,
		dbo.fnOrderApprovalState(buGuid) AS ApprovalState
	FROM    
		[vwExtended_bi] AS [bi]   
		INNER JOIN #OrderCond OrCond ON bi.BuGuid = OrCond.OrderGuid  
		INNER join @StoreTbl AS [stTbl] on [bi].[biStorePtr] = [stTbl].[stGuid]  
		INNER join @CostTbl AS CO ON [CO].[Number] = bi.biCostPtr   
		INNER join [#MatTbl] AS [mt] ON [mt].mtGuid = bi.biMatPtr   
		INNER join [#CustTbl] AS [cu] ON cu.Guid = bi.buCustPtr   
		INNER join [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]
		LEFT Join ( select oriPOIGuid, SUM(oriQty) AS oriQty from vwori as i inner join oit000 oit on i.oriTypeGuid = oit.guid 
					WHERE i.oriDate BETWEEN  @StartDate AND @EndDate AND QtyStageCompleted > 0  
					GROUP BY oriPOIGuid) ori on [bi].biGuid = ori.oriPOIGuid
		INNER JOIN ORADDINFO000 OInfo ON bi.buGuid = OInfo.ParentGuid  
		INNER JOIN mt000 mat on bi.biMatPtr = mat.Guid 
		LEFT JOIN co000 coTb ON coTb.GUID = bi.biCostPtr 
	WHERE ((mat.type = 0 and @ShowStoreMaterial = 1 ) or (mat.type = 1 and @ShowServiceMaterial = 1) or (mat.type = 2 and @ShowAssets=1))
	AND [OInfo].[Add1] = 0 AND [OInfo].[Finished] = 0  AND buDate BETWEEN  @StartDate AND @EndDate
	AND dbo.fnOrderApprovalState(buGuid) IN (2, 3)
	AND biGuid NOT IN (SELECT ppiSoiGuid FROM [vwPPOrderItems] )
	-----------------------------------------   
	EXEC [prcCheckSecurity]   
	----------------------------------------------------------   
	DECLARE @str NVARCHAR(800)
	SET @str = 'SELECT 
				buDate, buGuid, OrderName, biGuid, CustName, MatGuid, MatCode, MatName, CompositionName, UnitName, QtyOrder, (([QtyOrder] - [QtyPerform])) as QtyBack, QtyPerform, SDDATE,ADDATE,coName,StoreName,biClassPtr,ApprovalState
				 FROM #Result '   
	SET @str = @str + (CASE @OrderNum WHEN 0 THEN '' ELSE 'WHERE buNumber = '+CAST(@OrderNum AS NVARCHAR(10)) END)
	SET @str = @str + 'GROUP BY buDate, buGuid, OrderName, biGuid, CustName, MatGuid, MatCode, MatName, CompositionName, UnitName, QtyOrder, QtyBack, QtyPerform, SDDATE, ADDATE, coName, StoreName, biClassPtr, ApprovalState '
	SET @str = @str + ' ORDER BY ' + (CASE @SortType WHEN 0 THEN 'MatCode, OrderName' WHEN 1 THEN 'MatName, OrderName' WHEN 2 THEN 'buDate, OrderName' WHEN 3 THEN 'CustName, OrderName' WHEN 4 THEN 'ADDATE, OrderName' END)   
	EXEC (@str)

--prcConnections_Add2 '„œÌ—'
--[repPrepareOrders] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 'b5a578e6-34b7-416a-b4ab-ab4c2638022a', '2015-01-01', '2015-04-06', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 1, 0, 0
###################################################
#END