#########################################################################
CREATE PROCEDURE repDeleverOrder  
	@Acc [UNIQUEIDENTIFIER] = 0x0,      
	@Mt AS [UNIQUEIDENTIFIER] = 0x0,      
	@Gr AS [UNIQUEIDENTIFIER] = 0x0,      
	@Store AS [UNIQUEIDENTIFIER] = 0x0,  
	@OrderNum AS BIGINT = 0,     
	--@StateTypeGuid [UNIQUEIDENTIFIER],  
	@Src AS [UNIQUEIDENTIFIER] = 0x0,   
	@StartDate [DATETIME] = '1/1/2009',      
	@EndDate [DATETIME] = '12/01/2009',   
	@BillGuid [UNIQUEIDENTIFIER] = 0x0,   
	--@ShowPerform INT,   
	@Cost [UNIQUEIDENTIFIER] = 0x0,   
	@IsSellOrder INT = 1,  
	@isFinished BIT = 0  , 
	@isCancled BIT = 0 , 
	@NotApproved BIT = 0, 
	@MatCond UNIQUEIDENTIFIER = 0x00, 
	@CustCondGuid UNIQUEIDENTIFIER = 0x00, 
	@OrderCond	UNIQUEIDENTIFIER = 0x00	,  
	@SortType INT = 0  
AS     
	SET NOCOUNT ON  
	--///////////////////////////////////////////////////////////////////////////////  
	-------Bill Resource ---------------------------------------------------------        
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT],[ReadPrice] [INT], [UnPostedSec] [INT])  
	-------------------------------------------------------------------       
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
		[OrderLatinName] NVARCHAR(255) collate ARABIC_CI_AI, 
		[CustName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[CustLatinName] NVARCHAR(255) collate ARABIC_CI_AI,
		[MatGuid] [uniqueidentifier],      
		[MatCode] NVARCHAR(255) collate ARABIC_CI_AI,  
		[MatName] NVARCHAR(255) collate ARABIC_CI_AI,  
		[MatLatinName] NVARCHAR(255) collate ARABIC_CI_AI,
		[CompositionName] NVARCHAR(255) COLLATE ARABIC_CI_AI,   
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
		[biCount]   [FLOAT],                                                 
		[biQty2]  [FLOAT],                                             
		[biQty3]  [FLOAT], 
		[mtUnit2Fact]  [FLOAT], 
		[mtUnit3Fact]  [FLOAT],			                                           			 
		[biCostPtr]  [UNIQUEIDENTIFIER] ,
		[CostName]  NVARCHAR(255) collate ARABIC_CI_AI,                                           
		[biClassPtr] NVARCHAR(255) collate ARABIC_CI_AI,  
		[biProductionDate] [datetime],                                     
		[biExpireDate]  [datetime],  
		--[biProdFlag]  [int] , 
		[biExpireFlag] [int] , 
		--[biUnit2Flag]  [int] , 
		--[biUnit3Flag]  [int] , 
		[StateGuid]  [UNIQUEIDENTIFIER], 
		[BillGuid]  [UNIQUEIDENTIFIER],
		[QtyStageCompleted] [BIT],
		[Operation] [int] , 
		[SNumber] [int], 
		[MatLowLimit] [FLOAT], 
		[MatHighLimit] [FLOAT],
		[MatOrderLimit] [FLOAT], 
		[SOType] [INT], 
		[SOGuid] [UNIQUEIDENTIFIER],
		[IsIntegerQuantity] [INT], 
		[GrpCode] NVARCHAR(255) collate ARABIC_CI_AI, 
		[GrpName] NVARCHAR(255) collate ARABIC_CI_AI,
		[MatDim] NVARCHAR(255),
		[MatOrigin] NVARCHAR(255),
		[MatPos] NVARCHAR(255),
		[MatCompany] NVARCHAR(255),
		[MatColor] NVARCHAR(255),
		[MatProvenance] NVARCHAR(255),
		[MatQuality] NVARCHAR(255),
		[MatModel] NVARCHAR(255),
		[MatSpec] NVARCHAR(1000),
		[QtyReserved] [float],
		[PurchaseOrderRemaindedQty] [FLOAT],
		[BranchGuid] [UNIQUEIDENTIFIER],
		[OrderType]	 [INT]
		);
		CREATE NONCLUSTERED INDEX [inx_temp_result] ON [dbo].[#Result] ([biGuid]) 
		INCLUDE ([QtyStore], [UnitFact], [QtyPost]);
		CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])       
		 
    
	IF( ISNULL( @BillGuid, 0x0) = 0x0)   
	BEGIN   
		-------Bill Resource ---------------------------------------------------------     
		/*DECLARE @TypeTbl TABLE( [StateGuid] [UNIQUEIDENTIFIER], [Type] [INT], PostToBill [INT])      
		INSERT INTO @TypeTbl SELECT RS.[idType], oit.PostToBill FROM [dbo].[RepSrcs] RS INNER JOIN oit000 oit 
		ON oit.Guid = RS.idType WHERE RS.IdTbl = @ItemTypeGuid GROUP BY [idType] , oit.PostToBill */ 
		-------------------------------------------------------------------   
		declare @UserGuid uniqueidentifier  
		set @UserGuid = dbo.fnGetCurrentUserGUID()  
		--INSERT INTO #Src  
			--SELECT	@Src,  
				--[dbo].[fnGetUserBillSec_Browse]( @UserGuid, @Src),  
				--[dbo].[fnGetUserBillSec_ReadPrice] ( @UserGuid, @Src),  
				--[dbo].[fnGetUserBillSec_BrowseUnPosted] ( @UserGuid, @Src) 
		INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src   
		--  ÌÏæá ÇáØáÈíÇÊ ãÚ ÊÍÍÞíÞ ÔÑæØ ÇáØáÈíÇÊ 
		CREATE TABLE #OrderCond ( OrderGuid UNIQUEIDENTIFIER, [Security] [INT])  
		INSERT INTO [#OrderCond](OrderGuid, [Security]) EXEC [prcGetOrdersList] @OrderCond 
		-------------------------------------------------------------------  
		 
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
		--/////////////////////////////////////////////////   
		DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER])         
		INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @Cost)           
		IF ISNULL( @Cost, 0x0) = 0x0      
			INSERT INTO @CostTbl VALUES( 0x0)          
		--/////////////////////////////////////////////////		   
		INSERT INTO #Result(   
				[buGuid], [buTypeGuid], [buDate],[biGuid], [buNumber],   
				[biNumber],[buNotes],[biNotes],	[OrderName],[OrderLatinName],[CustName],[CustLatinName],   
				[MatGuid], [MatCode], [MatName], [MatLatinName],[CompositionName], [QtyOrder],   
				[QtyPerform], [QtyBack], [QtyPost],[QtyPostToBill] ,[QtyFixedStore],[QtyStore],   
				[StoreGuid], [StoreName], [StoreCode], [Unity], [UnitFact],   
				[UnitName], [OrderPrice], [biCurrencyVal], [mtSecurity], [buSecurity],  
				[UserSecurity] ,[biBillBonusQnt] ,[biDiscountRatio] ,[biExtraRatio] , 
								[biLength] ,[biWidth] ,[biHeight] ,[biCount] ,[biQty2] ,[mtUnit2Fact] , 
				[biQty3] , [mtUnit3Fact] ,[biCostPtr] , [CostName],
				[biClassPtr] ,[biProductionDate] ,[biExpireDate], [biExpireFlag] , [StateGuid] , [BillGuid], [QtyStageCompleted], [Operation], [SNumber], [MatLowLimit], [MatHighLimit], [MatOrderLimit], 
				[SOType], [SOGuid],[IsIntegerQuantity], [GrpCode], [GrpName],
				[MatDim], [MatOrigin], [MatPos], [MatCompany], [MatColor], 
				[MatProvenance], [MatQuality], [MatModel], [MatSpec],[BranchGuid],[OrderType])   
		SELECT --DISTINCT  
			buGuid,   
			buType,   
			buDate, 
			biGuid,  
			buNumber,   
			biNumber,  			  
			buNotes, 
			ori.oriNotes,  
			buFormatedNumber,
			buLatinFormatedNumber,   
			buCust_Name,
			ISNULL(Cust.LatinName, N'') AS CustLatinName,   
			biMatPtr,   
			mtCode,   
			mtName,   
			mtLatinName,
			CompositionName,   
			biBillQty AS [QtyOrder],   
			 isnull( ori.oriQty, 0) / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) AS [QtyPerform],  
			biBillQty,  
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
			[biLength] ,[biWidth] ,[biHeight]  ,[biCount] ,
			[bi].[biQty2] , [bi].[mtUnit2Fact] , 
			[bi].[biQty3] , [bi].[mtUnit3Fact] , 
			[biCostPtr] ,
			[coTbl].[Code] + '-' + [coTbl].[Name] COLLATE ARABIC_CI_AI AS CostName,
			[biClassPtr] ,[biProductionDate] ,[biExpireDate] ,[mtExpireFlag], [StateGuid], [BillGuid], [QtyStageCompleted] , [Operation], [SNumber], 
			[mat].[Low], 
			[mat].[High],
			[mat].[OrderLimit], 
            [bi].[biSOType], 
			[bi].[biSOGuid],
			[mat].[IsIntegerQuantity],
			[gr].[Code],
			[gr].[Name],
			[mat].[Dim],
			[mat].[Origin],
			[mat].[Pos],
			[mat].[Company],
			[mat].[Color],
			[mat].[Provenance],
			[mat].[Quality],
			[mat].[Model],
			[mat].[Spec],
			[bi].[buBranch],
			[bi].[btIsOutput]
		FROM    
			[vwExtended_bi] AS [bi]   
			INNER JOIN #OrderCond OrCond ON bi.BuGuid = OrCond.OrderGuid  
			INNER join @StoreTbl AS [stTbl] on [bi].[biStorePtr] = [stTbl].[stGuid]  
			INNER join @CostTbl AS CO ON [CO].[Number] = bi.biCostPtr 
			LEFT JOIN co000 [coTbl] ON [coTbl].[GUID] = bi.biCostPtr 
			INNER join [#MatTbl] AS [mt] ON [mt].mtGuid = bi.biMatPtr   
			INNER join [#CustTbl] AS [cu] ON cu.Guid = bi.buCustPtr   
			INNER join [#Src] AS [Src] ON [bi].[buType] = [Src].[Type] 
			INNER Join ( select oriPOIGuid, i.oriNotes, i.oriBuGuid AS BillGuid, oit.Guid AS StateGuid , oit.QtyStageCompleted, oit.Operation, oit.PostQty as SNumber  
					  , oriQty from vwori as i inner join oit000 oit on i.oriTypeGuid = oit.guid 
					WHERE i.oriDate BETWEEN  @StartDate AND @EndDate   ) ori 			 
			on [bi].biGuid = ori.oriPOIGuid 	 
			INNER JOIN ORADDINFO000 OInfo ON bi.buGuid = OInfo.ParentGuid  
			INNER JOIN mt000 mat on bi.biMatPtr = mat.Guid 
			INNER JOIN gr000 gr on mat.GroupGUID = gr.GUID
			LEFT JOIN cu000 AS Cust on cu.Guid = Cust.GUID
		WHERE  
			    (OInfo.Finished =( Case @isFinished WHEN 0 THEN 0 else OInfo.Finished end  ) ) 
			AND (OInfo.Add1 =( Case @isCancled WHEN 0 THEN '0' else OInfo.Add1 end  ) )  
			AND  
			( 
				( 
					(@NotApproved = 0) 
					AND 
					( 
						dbo.fnOrderApprovalState(buGuid) BETWEEN  2 AND 3  --2:Fully Approved, 3:Do Not Need Approvals
						--buGuid IN ( 
						--	select orderguid from orapp000 
						--	group by orderguid 
						--	having COUNT(*) = SUM(Approved) 
						--	)  
						--OR 
						--((select count(*) from orapp000 where orderguid = buGuid) = 0) 
					) 
				) 
				OR 
				(@NotApproved = 1) 
			) 
	-----------------------------------------   
	EXEC [prcCheckSecurity]   
	----------------------------------------------------------   
	END 
	IF( ISNULL( @BillGuid, 0x0) <> 0x0)   
	BEGIN   
		  
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 0x0  
		INSERT INTO #Result(   
				[buGuid],   
				[buTypeGuid],   
				[buDate],   
				[biGuid], 
				[buNumber],   
				[biNumber],   
				[buNotes],   
				[biNotes],     
				[OrderName],
				[OrderLatinName],  
				[CustName], 
				[CustLatinName],  
				[MatGuid],   
				[MatCode],   
				[MatName],   
				[MatLatinName],
				[CompositionName],   
				[QtyOrder],   
				[QtyPerform],   
				[QtyBack],   
				[QtyPost],   
				[QtyPostToBill] , 
				[QtyFixedStore], 
				[QtyStore],   
				[StoreGuid],   
				[StoreName],   
				[StoreCode],   
				[Unity],   
				[UnitFact],   
				[UnitName],   
				[OrderPrice],  
				[biCurrencyVal], 
				[mtSecurity],  
				[buSecurity],  
				[UserSecurity], [biBillBonusQnt] , 
				[biDiscountRatio] ,[biExtraRatio] , 
				[biLength] ,[biWidth] ,[biHeight] ,[biCount] ,[biQty2] ,[mtUnit2Fact] , 
				[biQty3] , [mtUnit3Fact] ,[biCostPtr] , [CostName],
				[biClassPtr] ,[biProductionDate] ,[biExpireDate] ,[biExpireFlag], [StateGuid], [BillGuid], [QtyStageCompleted], [Operation], [SNumber], 
				[MatLowLimit], [MatHighLimit], [MatOrderLimit], 
				[SOType], [SOGuid],
				[IsIntegerQuantity],
				[GrpCode], [GrpName],
				[MatDim], [MatOrigin], [MatPos], [MatCompany], [MatColor], [MatProvenance], 
				[MatQuality], [MatModel], [MatSpec],[BranchGuid],[OrderType]) 
		SELECT --DISTINCT   
			buGuid,   
			buType,   
			buDate , 
			biGuid , 
			buNumber,   
			biNumber, 
			buNotes,   
			ori.oriNotes,  
			buFormatedNumber,
			buLatinFormatedNumber,   
			buCust_Name,
			ISNULL(Cust.LatinName, N''),   
			biMatPtr,   
			mtCode,   
			mtName,   
			mtLatinName,
			CompositionName,   
			biBillQty AS [QtyOrder],   
			isnull( ori.oriQty, 0) / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) AS [QtyPerform],   
			biBillQty,  
			0 AS [QtyPost],   
			0 AS [QtyPostToBill] ,  
			0, 
			0, -- temp ms.msQty / mtUnitFact AS [QtyStore],   
			St.stGuid AS [StoreGuid],   
			St.stName AS [StoreName],   
			St.stCode AS [StoreCode],   
			biUnity,   
			mtUnitFact,   
			mtUnityName,  
			CASE bi.btVATSystem  
				WHEN 2 THEN ((biUnitPrice * mtUnitFact * (1 + biVATr/100))) / CASE biCurrencyVal WHEN 0 THEN 1 ELSE biCurrencyVal END 
				ELSE (biUnitPrice * mtUnitFact) / CASE biCurrencyVal WHEN 0 THEN 1 ELSE biCurrencyVal END 
			END, 
			biCurrencyVal, 
			mtSecurity,  
			buSecurity,  
			CASE [bi].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,  
			[biBillBonusQnt] , 
			CASE biCurrencyVal WHEN 0 THEN biDiscount ELSE  biDiscount / biCurrencyVal END , 
			CASE biCurrencyVal WHEN 0 THEN biExtra ELSE  biExtra / biCurrencyVal END , 
			[biLength] ,[biWidth] ,[biHeight] ,[biCount] ,  
			[bi].[biQty2] , [bi].[mtUnit2Fact] , 
			[bi].[biQty3] , [bi].[mtUnit3Fact] , 
			[biCostPtr],
			[co].[coCode] + '-' + [co].[coName] COLLATE ARABIC_CI_AI AS CostName ,
			[biClassPtr] ,[biProductionDate] ,[biExpireDate] , [mtExpireFlag] , [StateGuid] , [BillGuid], [QtyStageCompleted], [Operation], [SNumber], 
			[mat].[Low], [mat].[High], [mat].[OrderLimit], 
            [bi].[biSOType], 
			[bi].[biSOGuid],
			[mat].[IsIntegerQuantity],
			[gr].[Code],
			[gr].[Name],
			[mat].[Dim],
			[mat].[Origin],
			[mat].[Pos],
			[mat].[Company],
			[mat].[Color],
			[mat].[Provenance],
			[mat].[Quality],
			[mat].[Model],
			[mat].[Spec],
			[bi].[buBranch],
			[bi].[btIsOutput]
			FROM    
			vwExtended_bi bi 
			 
			INNER join [#Src] AS [Src] ON [bi].[buType] = [Src].[Type]  
			INNER join vwSt st on bi.biStorePtr = St.stGuid 
			LEFT JOIN vwCo co ON bi.biCostPtr = co.coGUID  
			INNER Join ( select oriPOIGuid, i.oriNotes, i.oriBuGUID AS BillGuid, oit.Guid AS StateGuid, oit.QtyStageCompleted , oit.Operation,  
				            oit.PostQty as SNumber , oriQty from vwori as i inner join oit000 oit  
					    on i.oriTypeGuid = oit.guid  ) ori   
			ON [bi].biGuid = ori.oriPOIGuid  
			INNER JOIN mt000 mat ON mat.Guid = bi.biMatPtr 
			INNER JOIN gr000 gr on mat.GroupGUID = gr.GUID
			LEFT JOIN cu000 AS Cust on bi.buCustPtr = Cust.GUID
	
		WHERE    
			buGuid = @BillGuid  
--			AND  
--			( 
--				buGuid IN ( 
--						select orderguid /*,COUNT(*) Num, SUM(Approved) s*/ from orapp000 
--						where @NotApproved = 0 
--						group by orderguid 
--						having COUNT(*) = SUM(Approved) 
--						)  
--				OR 
--				(@NotApproved = 1) 
--			) 
			 
		 
		-----------------------------------------   
		EXEC [prcCheckSecurity]   
		----------------------------------------------------------   
	END   
	DECLARE @EnableBranches INT = (SELECT dbo.fnOption_GetInt('EnableBranches', '0'))
	
	UPDATE Res SET   
		[QtyFixedStore] = (CASE WHEN @EnableBranches = 1 THEN (SELECT dbo.fnGetStoreQtyByBranch (Res.MatGuid, Res.StoreGuid, Res.BranchGuid))
								ELSE (ms.msQty) END) / (CASE UnitFact when 0 then 1 else UnitFact END)  ,  
		[QtyStore] = ms.msQty / CASE UnitFact when 0 then 1 else UnitFact END   
	FROM    
		#Result Res INNER join vwMs ms    
		ON Res.MatGuid = ms.msMatPtr and ms.msStorePtr = Res.StoreGuid   
	
	---------------------------------------
	IF((SELECT dbo.fnOption_GetInt('AmnCfg_EnableOrderReservationSystem', '0')) <> 0)
	BEGIN
		UPDATE #Result SET   
		[QtyReserved] = ISNULL((SELECT dbo.fnGetReservedQty(MatGuid, StoreGuid, (CASE WHEN @EnableBranches = 1 THEN BranchGuid ELSE 0x0 END))) / (CASE UnitFact WHEN 0 THEN 1 ELSE UnitFact END),0)
	END
	
	IF((SELECT dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0')) <> 0)
	BEGIN
		UPDATE #Result SET   
		[PurchaseOrderRemaindedQty] = ISNULL((SELECT dbo.fnGetPurchaseOrderRemaindedQty(MatGuid, StoreGuid, (CASE WHEN @EnableBranches = 1 THEN BranchGuid ELSE 0x0 END))) / (CASE UnitFact WHEN 0 THEN 1 ELSE UnitFact END),0)
	END
	---------------------------------------   
	IF( @IsSellOrder = 1 and isnull( @BillGuid, 0x0) = 0x0 )   
	BEGIN   
		DECLARE @c CURSOR,    
				@buDate Datetime,   
				@biGuid uniqueidentifier,   
				@MatGuid uniqueidentifier,   
				@MatGuid2 uniqueidentifier,   
				@QtyOrder float,   
				@QtyBack float,   
				@QtyPost float,   
				@QtyPostToBill float , 
				@QtyStore float,   
				@QtyStore2 float,   
				@StoreGuid uniqueidentifier,   
				@StoreGuid2 uniqueidentifier,   
				@Unity int,   
				@UnitFact float   
		SET @MatGuid2 = 0x0   
		SET @StoreGuid2 = 0x0   
		SET @c = CURSOR FAST_FORWARD FOR  
			SELECT   
				[buDate],   
				[biGuid],   
				[MatGuid],   
				[QtyOrder],   
				[QtyBack],   
				[QtyPost],  
				[QtyPostToBill] ,  
				[QtyStore],   
				[StoreGuid],   
				[Unity],   
				[UnitFact]   
			FROM    
				#Result   
			ORDER BY   
				[MatGuid],   
				[StoreGuid],   
				[buDate],   
				[buNumber]   
		OPEN @c FETCH FROM @c INTO 			   
				@buDate,   
				@biGuid,   
				@MatGuid,   
				@QtyOrder,   
				@QtyBack,   
				@QtyPost,   
				@QtyPostToBill , 
				@QtyStore,   
				@StoreGuid,   
				@Unity,   
				@UnitFact   
		   
		   
		WHILE @@FETCH_STATUS = 0   
		BEGIN   
			if( ( @MatGuid = @MatGuid2 and @MatGuid2 <> 0x0) and (@StoreGuid = @StoreGuid2 and @StoreGuid2 <> 0x0))   
			begin   
				UPDATE [#Result]    
					SET [QtyStore] = CASE WHEN ( @QtyStore2 / UnitFact - @QtyBack) < 0 THEN @QtyStore2 / UnitFact ELSE (@QtyStore2 / UnitFact - @QtyBack) END,   
						[QtyPost] = CASE WHEN ( @QtyStore2 / UnitFact - @QtyBack) < 0 THEN @QtyStore2 / UnitFact ELSE @QtyBack END   
				WHERE biGuid = @biGuid   
			END   
			ELSE   
			BEGIN   
				IF( (@MatGuid <> @MatGuid2 or @MatGuid2 = 0x0) or (@StoreGuid <> @StoreGuid2 or @StoreGuid2 = 0x0))   
				begin   
					SET @QtyStore2 = @QtyStore * @UnitFact - CASE WHEN @QtyStore - @QtyBack < 0 THEN @QtyStore * @UnitFact ELSE @QtyBack * @UnitFact END   
				end   
				--ELSE   
				--	SET @QtyStore2 = CASE WHEN ( (@QtyStore2 - @QtyBack) * @UnitFact) < 0 THEN ( (@QtyStore2 - @QtyBack) * @UnitFact) + @QtyBack * @UnitFact ELSE @QtyStore2 - @QtyBack* @UnitFact END    
				UPDATE #Result    
					SET --[QtyStore] = CASE WHEN ( [QtyStore] - @QtyBack) <= 0 THEN ([QtyStore] - @QtyBack) + @QtyBack ELSE ( [QtyStore] - ISNULL( @QtyBack,0)) END,   
						[QtyPost] = CASE WHEN ( [QtyStore] - @QtyBack) < 0 THEN ( [QtyStore] - @QtyBack) + @QtyBack ELSE @QtyBack END   
				WHERE biGuid = @biGuid   
			   
				SET @MatGuid2 = @MatGuid    
				SET @StoreGuid2 = @StoreGuid   
			END   
			FETCH FROM @c   
			INTO   
				@buDate,   
				@biGuid,   
				@MatGuid,   
				@QtyOrder,   
				@QtyBack,   
				@QtyPost,   
				@QtyPostToBill , 
				@QtyStore,   
				@StoreGuid,   
				@Unity,   
				@UnitFact   
		END  	 
		CLOSE @c
		DEALLOCATE @c
	END  
	
	--IF @OrderNum <> 0    
	--	SELECT * FROM #Result   
	--	WHERE buNumber = @OrderNum   
	--	ORDER BY [buTypeGuid], [buNumber], [biNumber]    
	--ELSE   
	--	IF @SortType = 0   
	--		SELECT * FROM #Result ORDER BY [buTypeGuid], [buNumber], [biNumber]     
	--	ELSE   
	--		SELECT * FROM #Result ORDER BY [MatCode], [buTypeGuid], [buNumber], [biNumber]  
	 
	DECLARE @str NVARCHAR(255)
	SET @str = 'SELECT * FROM #Result '   
	SET @str = @str + (CASE @OrderNum WHEN 0 THEN '' ELSE 'WHERE buNumber = '+CAST(@OrderNum AS NVARCHAR(10)) END)
	SET @str = @str + ' ORDER BY ' 
			   +(CASE @SortType 
					  WHEN 0 THEN 'OrderName, MatCode, biNumber' 
					  WHEN 1 THEN 'MatCode, OrderName'
					  WHEN 2 THEN 'MatName, MatCode, OrderName'
					  WHEN 3 THEN 'MatDim, MatCode, OrderName'
					  WHEN 4 THEN 'MatOrigin, MatCode, OrderName'
					  WHEN 5 THEN 'MatPos, MatCode, OrderName'
					  WHEN 6 THEN 'MatCompany, MatCode, OrderName'
					  WHEN 7 THEN 'MatColor, MatCode, OrderName'
					  WHEN 8 THEN 'MatProvenance, MatCode, OrderName'
					  WHEN 9 THEN 'MatQuality, MatCode, OrderName'
					  WHEN 10 THEN 'MatModel, MatCode, OrderName'
					  WHEN 11 THEN 'MatSpec, MatCode, OrderName'
					  WHEN 12 THEN 'GrpName, MatCode, OrderName'
				 END)  
						 
	EXEC (@str) 

#############################################################################
#END
