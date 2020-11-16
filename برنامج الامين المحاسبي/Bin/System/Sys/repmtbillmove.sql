###########################################################################
CREATE PROCEDURE repMatMoveByBill
	@StartDate AS [DateTime] ,  
	@EndDate AS [DateTime] ,  
	@Src [UNIQUEIDENTIFIER] ,  
	@Acc AS [UNIQUEIDENTIFIER] ,  
	@Gr AS [UNIQUEIDENTIFIER] ,  
	@Store AS [UNIQUEIDENTIFIER] ,  
	@Cost AS [UNIQUEIDENTIFIER],
   	@CurPtr AS [UNIQUEIDENTIFIER] ,  
   	@CurVal AS [FLOAT],  
	@ShowVal AS [INT],  
	@ShowQty AS [INT],  
	@ShowBonus AS [INT],  
	@AddBonusToQty AS [INT],  
	@AddDiscToVal AS [INT],  
	@AddVatToVal AS [BIT],
	@IncludeSubStores AS [INT],  
	@ShowGroups AS [INT],  
	@ShowPrevBalance AS [INT],  
	@InOut AS [INT],  
	@CollectByMcBillType [INT],  
	@UseUnit AS [INT], 
	@Posted	AS [INT], 
	@CostPrice AS [INT] = 0, 
	@MatCondGuid [UNIQUEIDENTIFIER] = 0x00, 
	@grLevel	[INT]	= 0, 
	@VeiwCFlds 	NVARCHAR (max) = '' ,	-- New Parameter to check veiwing of Custom Fields
	@ShowEmptyBills [int] = 0, 				  
	@ShowCostDetls [BIT] = 0 
AS      
	SET NOCOUNT ON 
	
	DECLARE @LangDirection AS [INT]
	SELECT @LangDirection = [dbo].fnConnections_GetLanguage()
		
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 
	--------------------------------------------------------------------------  
	CREATE TABLE [#GrpTbl] ( [Number] [UNIQUEIDENTIFIER],[Level] INT ,[grParent] UNIQUEIDENTIFIER )       
	INSERT INTO [#GrpTbl] SELECT a.[GUID],[Level],ParentGuid From dbo.fnGetGroupsListByLevel(@Gr,0) a INNER JOIN [gr000] b ON a.Guid = b.Guid 
	--Mat Table ------------------------------------------------------------------------  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  NULL, @Gr,-1,@MatCondGuid 
	------------------------------------------------------------------------------------ 
	CREATE TABLE [#MatTbl2] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT, UnitFact FLOAT,
							[Unit2Fact] FLOAT, [Unit3Fact] FLOAT, mtGroup [UNIQUEIDENTIFIER])
	INSERT INTO [#MatTbl2] SELECT [MatGUID],[mtSecurity], 
	CASE @UseUnit   
				WHEN 0 THEN 1   
				WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
				WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
				WHEN 3 THEN  
					CASE [DefUnit]   
						WHEN 1 THEN 1   
						WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
						WHEN 3 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
					END  
			END UnitFact,  
			CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END [Unit2Fact],  
			CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END [Unit3Fact],mt.groupGuid mtGroup 
	FROM [#MatTbl] m INNER JOIN mt000 mt ON mt.Guid = m.[MatGUID] 
	--Cost Table------------------------------------------------------------------------  
	CREATE TABLE [#CostTbl]( [Number] [UNIQUEIDENTIFIER] )       
	INSERT INTO [#CostTbl]  SELECT [GUID] From [fnGetCostsList]( @Cost)  
	if @Cost = 0x0  
		INSERT INTO [#CostTbl] SELECT 0x0  
	--Store  Table------------------------------------------------------------------------  
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER] )   
	IF ( @IncludeSubStores <> 0 OR  ISNULL( @Store, 0x0) = 0x0 ) 
		INSERT INTO [#StoreTbl] SELECT [GUID] From [fnGetStoresList]( @Store)  
	ELSE 
		INSERT INTO [#StoreTbl] SELECT @Store 
	--Customer  Table------------------------------------------------------------------------  
	CREATE TABLE [#CustTbl]( [Number] [UNIQUEIDENTIFIER] )  
	CREATE TABLE [#t_Prices]([mtNumber] 	[UNIQUEIDENTIFIER],	[APrice] 	[FLOAT] 
	) 
	INSERT INTO [#CustTbl]  
		SELECT    
			[vwCu].[cuGUID]  
		FROM    
			[vwCu] INNER JOIN [dbo].[fnGetCustsOfAcc]( @Acc) AS [f]  
			On [vwCu].[cuGUID] = [f].[GUID]  
	if( @Acc = 0x0)  
		INSERT INTO [#CustTbl] SELECT 0x0  
	--Sources  Table--------------------------------------------------------------------------  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSec][INT])  
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList2] @Src  
     CREATE TABLE [#BillsTypesTblALL]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSec][INT])   
	INSERT INTO [#BillsTypesTblALL] EXEC [prcGetBillsTypesList2] 0x0   
	DECLARE @ShowMats AS INT
	SET @ShowMats = 1  
	IF 	@CostPrice = 1 
		EXEC [prcGetAvgPrice]	@StartDate,@EndDate,0X0,@Gr,@Store, @Cost, -1, @CurPtr, 1, @Src,0, 0 
	--Result  Table-------------------------------------------------------------------------  
	CREATE TABLE  [#MatBillType](
			[Type] [INT],   
				[MatPtr] [UNIQUEIDENTIFIER] ,   
				[newMatPtr] [UNIQUEIDENTIFIER] DEFAULT 0x0,
				[mtGroup] [UNIQUEIDENTIFIER] ,  
				[BillType] [NVARCHAR] (250) COLLATE ARABIC_CI_AI,   
				[Val] [FLOAT],   
				[Qty] [FLOAT],   
				[Bonus] [FLOAT],   
				[PrevBal] [FLOAT],   
			[Ok] [INT],
			[CostStr] [NVARCHAR] (250) COLLATE ARABIC_CI_AI)
		CREATE TABLE  [#FinalResult](
			[Type] [INT],   
			[MatPtr] [UNIQUEIDENTIFIER] ,   
			[newMatPtr] [UNIQUEIDENTIFIER] DEFAULT 0x0,
			[mtGroup] [UNIQUEIDENTIFIER] ,   
			[BillType] [NVARCHAR] (250) COLLATE ARABIC_CI_AI,   
			[Val] [FLOAT],   
			[Qty] [FLOAT],   
			[Bonus] [FLOAT],   
			[PrevBal] [FLOAT],   
			[CostStr] [NVARCHAR] (250) COLLATE ARABIC_CI_AI DEFAULT 0x0)
	DECLARE @EndResult TABLE (  
				[BillType] [NVARCHAR] (250) COLLATE ARABIC_CI_AI, 
				[Val] [FLOAT],   
				[Qty] [FLOAT],   
				[Bonus] [FLOAT],   
				[PrevBal] FLOAT,
				[CostStr] [NVARCHAR] (250) COLLATE ARABIC_CI_AI) 
	---------------------------------------------------------------------------------------- 
	CREATE TABLE [#T_Result]([Type] [INT],   
				[MatPtr] [UNIQUEIDENTIFIER] ,   
				[mtGroup] [UNIQUEIDENTIFIER] ,   
				[buDate] [DateTime] ,
				[buIsPosted] [INT],  
				[BillType] [NVARCHAR] (250) COLLATE ARABIC_CI_AI, 
				[Val] [FLOAT],   
				[Qty] [FLOAT],   
				[Bonus] [FLOAT],  
				[mtSecurity] [INT], 
				[Security] [INT], 
				[UserSecurity] [INT], 
				[TQty] [FLOAT] DEFAULT 0,
				[CostStr] [NVARCHAR] (250) COLLATE ARABIC_CI_AI	) 
	IF (@ShowCostDetls <> 0 )
	BEGIN 
	INSERT INTO [#T_Result]  
		SELECT 
			0, 
			[Bill].[biMatPtr],   
			[Mt].[mtGroup],    
			[Bill].[buDate],
			[Bill].[buIsPosted],
			CASE @CollectByMcBillType  
				WHEN 0 THEN CAST( [Bill].[buType]  AS [NVARCHAR] (100))  
				ELSE CAST( [Bill].[btBillType] AS [NVARCHAR] (100)) END  
				AS [BillType],  
			CASE WHEN [Src].[UserReadPriceSecurity] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				* CASE @AddDiscToVal WHEN 1 THEN 
				[FixedCurrencyFactor] *  ( 
				([Bill].[biPrice]*[Bill].[biQty]  
				/CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)  
				 + [biExtra] - [biDiscount] - [biBonusDisc] + CASE @AddVatToVal WHEN 1 THEN [biTotalTaxValue] ELSE 0 END) -[FixedTotalDiscountPercent] + [FixedTotalExtraPercent] 
				ELSE  
					[FixedCurrencyFactor] *  ((([Bill].[biPrice]*[Bill].[biQty]) / (CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)) + CASE @AddVatToVal WHEN 1 THEN [biTotalTaxValue] ELSE 0 END)
				END 
				* @ShowVal AS [Val],  
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END 
				*([biQty] +( [biBonusQnt] * @AddBonusToQty)) /[UnitFact] 
				* @ShowQty , 
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				* [biBonusQnt] * @ShowBonus /[UnitFact]	AS [Bonus], 
			[Mt].[mtSecurity], 
			[Bill].[buSecurity], 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[UserSecurity] ELSE [Src].[UnPostedSec] END, 
			([biQty]  + [biBonusQnt])*CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END ,
			IsNull(cost.Code+'-'+cost.Name, N'')
	FROM          
		[#MatTbl2] AS [Mt] --INNER JOIN [vwMtGr] AS [Gr] ON [Gr].[mtGUID] = [Mt].[MatGUID] 
		LEFT JOIN [dbo]. [fn_bubi_Fixed]( @CurPtr) AS [bill]   
		ON [Mt].[MatGUID] = [Bill].[biMatPtr] 
		LEFT JOIN co000 cost on cost.Guid = [Bill].[biCostPtr]
		INNER JOIN [#CustTbl] AS [CU] ON [CU].[Number] = [Bill].[BuCustPtr]  
		INNER JOIN [#CostTbl] AS [CO] ON [CO].[Number] = [Bill].[BiCostPtr] 
		INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGUID] = [Bill].[BiStorePtr]   
		INNER JOIN [#BillsTypesTbl] AS [Src] ON [Src].[TypeGuid] = [Bill].[BuType] 
	WHERE      
		[Bill].[buDate] <= @EndDate 
		AND (  ( @Posted > 2)  
			OR ( @Posted = 1 AND [bill].[buIsPosted] = 1 ) 
			OR ( @Posted = 2 AND [bill].[buIsPosted] = 0 )  ) 
	END 
	ELSE 
	BEGIN
	
		INSERT INTO [#T_Result] ([Type]  ,[MatPtr] , [mtGroup], [buDate], [buIsPosted], [BillType], [Val], [Qty], [Bonus], [mtSecurity],  [Security],  [UserSecurity], [TQty]) 
		SELECT 
			0, 
			[Bill].[biMatPtr],   
			[Mt].[mtGroup],    
			[Bill].[buDate],
			[Bill].[buIsPosted],
			CASE @CollectByMcBillType  
				WHEN 0 THEN CAST( [Bill].[buType]  AS [NVARCHAR] (100))  
				ELSE CAST( [Bill].[btBillType] AS [NVARCHAR] (100)) END  
				AS [BillType],  
			CASE WHEN [Src].[UserReadPriceSecurity] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				* CASE @AddDiscToVal WHEN 1 THEN 
				[FixedCurrencyFactor] *  ( 
				([Bill].[biPrice]*[Bill].[biQty]  
				/CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)  
				 + [biExtra] - [biDiscount] - [biBonusDisc] + CASE @AddVatToVal WHEN 1 THEN [biTotalTaxValue] ELSE 0 END) + [FixedTotalExtraPercent]-[FixedTotalDiscountPercent]
				ELSE  
					[FixedCurrencyFactor] *  ((([Bill].[biPrice]*[Bill].[biQty]) / (CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)) + CASE @AddVatToVal WHEN 1 THEN [biTotalTaxValue] ELSE 0 END)
				END 
				* @ShowVal AS [Val],  
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END 
				*([biQty] +( [biBonusQnt] * @AddBonusToQty)) /[UnitFact] 
				* @ShowQty , 
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				* [biBonusQnt] * @ShowBonus /[UnitFact]	AS [Bonus], 
			[Mt].[mtSecurity], 
			[Bill].[buSecurity], 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[UserSecurity] ELSE [Src].[UnPostedSec] END, 
			([biQty]  + [biBonusQnt])*CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END 
	FROM          
		[#MatTbl2] AS [Mt] --INNER JOIN [vwMtGr] AS [Gr] ON [Gr].[mtGUID] = [Mt].[MatGUID] 
		LEFT JOIN [dbo]. [fn_bubi_Fixed]( @CurPtr) AS [bill]   
		ON [Mt].[MatGUID] = [Bill].[biMatPtr] 
		--LEFT JOIN co000 cost on cost.Guid = [Bill].[biCostPtr]
		INNER JOIN [#CustTbl] AS [CU] ON [CU].[Number] = [Bill].[BuCustPtr]  
		INNER JOIN [#CostTbl] AS [CO] ON [CO].[Number] = [Bill].[BiCostPtr]  
		INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGUID] = [Bill].[BiStorePtr]   
		INNER JOIN [#BillsTypesTbl] AS [Src] ON [Src].[TypeGuid] = [Bill].[BuType] 
	WHERE      
		[Bill].[buDate] <= @EndDate 
		AND (  ( @Posted > 2)  
			OR ( @Posted = 1 AND [bill].[buIsPosted] = 1 ) 
			OR ( @Posted = 2 AND [bill].[buIsPosted] = 0 )  ) 
	END 
   ----------------------------------------------------------------------------------------
    CREATE TABLE [#T_ResultALlSource](	[Type] [INT],    
				[MatPtr] [UNIQUEIDENTIFIER] ,    
				[mtGroup] [UNIQUEIDENTIFIER] ,    
				[buDate] [DateTime] , 
				[buIsPosted] [INT],   
				[BillType] [VARCHAR] (250) COLLATE ARABIC_CI_AI,  
				[Val] [FLOAT],    
				[Qty] [FLOAT],    
				[Bonus] [FLOAT],   
				[mtSecurity] [INT],  
				[Security] [INT],  
				[UserSecurity] [INT],  
				[TQty] [FLOAT] DEFAULT 0,
				[CostStr] [NVARCHAR] (250) COLLATE ARABIC_CI_AI) 
                     
	IF (@ShowCostDetls <> 0 )
	BEGIN 
	INSERT INTO [#T_ResultALlSource]   
		SELECT  
			0,  
			[Bill].[biMatPtr],    
			[Mt].[mtGroup],     
			[Bill].[buDate], 
			[Bill].[buIsPosted], 
			CASE @CollectByMcBillType   
				WHEN 0 THEN CAST( [Bill].[buType]  AS [VARCHAR] (100))   
				ELSE CAST( [Bill].[btBillType] AS [VARCHAR] (100)) END   
				AS [BillType],   
			CASE WHEN [Src].[UserReadPriceSecurity] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END   
				* CASE @AddDiscToVal WHEN 1 THEN  
				[FixedCurrencyFactor] *  (  
				([Bill].[biPrice]*[Bill].[biQty]  
				/CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)   
				 + [biExtra] - [biDiscount] - [biBonusDisc] + [biTotalTaxValue])+ [FixedTotalExtraPercent]-[FixedTotalDiscountPercent]  
				ELSE   
					([FixedCurrencyFactor] *  [Bill].[biPrice]*[Bill].[biQty]) /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END   
				END  
				* @ShowVal AS [Val],   
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				*([biQty] +( [biBonusQnt] * @AddBonusToQty)) /[UnitFact]  
				* @ShowQty,  
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END   
				* [biBonusQnt] * @ShowBonus /[UnitFact]	AS [Bonus],  
			[Mt].[mtSecurity],  
			[Bill].[buSecurity],  
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[UserSecurity] ELSE [Src].[UnPostedSec] END,  
			([biQty]  + [biBonusQnt])*CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  ,
			IsNull(cost.Code+'-'+cost.Name, N'')
	FROM           
		[#MatTbl2] AS [Mt] --INNER JOIN [vwMtGr] AS [Gr] ON [Gr].[mtGUID] = [Mt].[MatGUID]  
		LEFT JOIN [dbo]. [fn_bubi_Fixed]( @CurPtr) AS [bill]    
		ON [Mt].[MatGUID] = [Bill].[biMatPtr]  
		LEFT JOIN co000 cost on cost.Guid = bill.biCostPtr
		INNER JOIN [#CustTbl] AS [CU] ON [CU].[Number] = [Bill].[BuCustPtr]   
		INNER JOIN [#CostTbl] AS [CO] ON [CO].[Number] = [Bill].[BiCostPtr]   
		INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGUID] = [Bill].[BiStorePtr]    
		INNER JOIN [#BillsTypesTblALL] AS [Src] ON [Src].[TypeGuid] = [Bill].[BuType] 
	WHERE       
		[Bill].[buDate] <= @EndDate  
	     and [bill].[buIsPosted] = 1  
	END 
	ELSE 
	BEGIN 
		INSERT INTO [#T_ResultALlSource]([Type] ,[MatPtr] , [mtGroup], [buDate] ,[buIsPosted], [BillType], [Val], [Qty], [Bonus], [mtSecurity], [Security], [UserSecurity] , [TQty] )
		SELECT  
			0,  
			[Bill].[biMatPtr],    
			[Mt].[mtGroup],     
			[Bill].[buDate], 
			[Bill].[buIsPosted], 
			CASE @CollectByMcBillType   
				WHEN 0 THEN CAST( [Bill].[buType]  AS [VARCHAR] (100))   
				ELSE CAST( [Bill].[btBillType] AS [VARCHAR] (100)) END   
				AS [BillType],   
			CASE WHEN [Src].[UserReadPriceSecurity] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END   
				* CASE @AddDiscToVal WHEN 1 THEN  
				[FixedCurrencyFactor] *  (  
				([Bill].[biPrice]*[Bill].[biQty]  
				/CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END)   
				 + [biExtra] - [biDiscount] - [biBonusDisc] + [biTotalTaxValue]) + [FixedTotalExtraPercent]-[FixedTotalDiscountPercent]  
				ELSE   
					([FixedCurrencyFactor] *  [Bill].[biPrice]*[Bill].[biQty]) /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE [Unit3Fact] END   
				END  
				* @ShowVal AS [Val],   
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				*([biQty] +( [biBonusQnt] * @AddBonusToQty)) /[UnitFact]  
				* @ShowQty,  
			CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END   
				* [biBonusQnt] * @ShowBonus /[UnitFact]	AS [Bonus],  
			[Mt].[mtSecurity],  
			[Bill].[buSecurity],  
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[UserSecurity] ELSE [Src].[UnPostedSec] END,  
			([biQty]  + [biBonusQnt])*CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
	FROM           
		[#MatTbl2] AS [Mt] --INNER JOIN [vwMtGr] AS [Gr] ON [Gr].[mtGUID] = [Mt].[MatGUID]  
		LEFT JOIN [dbo]. [fn_bubi_Fixed]( @CurPtr) AS [bill]    
		ON [Mt].[MatGUID] = [Bill].[biMatPtr]  
		--LEFT JOIN co000 cost on cost.Guid = bill.biCostPtr
		INNER JOIN [#CustTbl] AS [CU] ON [CU].[Number] = [Bill].[BuCustPtr]   
		INNER JOIN [#CostTbl] AS [CO] ON [CO].[Number] = [Bill].[BiCostPtr]   
		INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGUID] = [Bill].[BiStorePtr]    
		INNER JOIN [#BillsTypesTblALL] AS [Src] ON [Src].[TypeGuid] = [Bill].[BuType] 
	WHERE       
		[Bill].[buDate] <= @EndDate  
	     and [bill].[buIsPosted] = 1  	 
	END 	 	 
	---------------------------------------------------------------------------------------- 
	EXEC [prcCheckSecurity]  @result = '#T_Result' 
	----------------------------------------------------------------------------------------  
	
	IF 	@CostPrice = 1 
     BEGIN
		UPDATE [t] SET [Val] = [TQty] * [APrice] FROM [#T_Result] AS [t] LEFT JOIN [#t_Prices]  AS [a] ON  [mtNumber] = [MatPtr] 
		UPDATE [t] SET [Val] = [TQty] * [APrice] FROM [#T_ResultALlSource] AS [t] LEFT JOIN [#t_Prices]  AS [a] ON  [mtNumber] = [MatPtr]
     END
	  if (@ShowCostDetls <> 0) 
	  BEGIN 
     INSERT INTO [#MatBillType]   
		SELECT  
			1,     
			[Res].[MatPtr], 0X0,
			[Res].[mtGroup], 
			[Res].[BillType], 
			SUM( [Res].[Val]),  
			SUM( [Res].[Qty]), 
			SUM( [Res].[Bonus]), 
			0, 
			0,
			[Res].CostStr
		FROM          
			[#T_Result] AS [Res] 
		WHERE      
			[Res].[buDate] between @StartDate AND @EndDate 
		GROUP BY      
			[Res].[MatPtr],      
			[Res].[CostStr], 
			[Res].[mtGroup], 
			[Res].[BillType]
	  END 
	ELSE 
	BEGIN 
	 INSERT INTO [#MatBillType]   ([Type], MatPtr,mtGroup,BillType,Val,Qty,Bonus,[PrevBal],[Ok])
		SELECT  
			1,     
			[Res].[MatPtr],
			[Res].[mtGroup], 
			[Res].[BillType], 
			SUM( [Res].[Val]),  
			SUM( [Res].[Qty]), 
			SUM( [Res].[Bonus]), 
			0, 
			0 
		FROM          
			[#T_Result] AS [Res] 
		WHERE      
			[Res].[buDate] between @StartDate AND @EndDate 
		GROUP BY      
			[Res].[MatPtr],      
			[Res].[mtGroup], 
			[Res].[BillType] 
		END
	 
--------------------------------------------------------------------------------- 
IF (@ShowEmptyBills = 1)
BEGIN 
DECLARE @someMovementBillType AS [NVARCHAR] (250)
SELECT Top 1 @someMovementBillType = BillType FROM [#T_Result]
if (@ShowCostDetls <> 0 )
	BEGIN 
	INSERT INTO [#MatBillType]   
		SELECT  distinct
			1 AS [Type],     
			[MAT].[matguid]  AS [MatPtr], 0X0  AS [newMatPtr],
			[MAT].[mtGroup]  AS [mtGroup], 
			NULL  AS [BillType], 
			0  AS [Val],  
			0  AS [Qty], 
			0  AS [Bonus], 
			0  AS [PrevBal], 
			0  AS [Ok],
			' '  AS [CostStr]
		FROM 
		[#MatTbl2] [MAT]  
		WHERE [MAT].[matguid] NOT IN (SELECT [MatPtr] FROM [#T_Result])
	END 
ELSE 
	BEGIN
	INSERT INTO [#MatBillType]  ([Type], MatPtr,mtGroup,BillType,Val,Qty,Bonus,[PrevBal],[Ok])
		
		SELECT  distinct
			1,     
			[MAT].[matguid], 
			[MAT].[mtGroup], 
			NULL, 
			0,  
			0, 
			0, 
			0, 
			0 
		FROM 
		 [#MatTbl2] [MAT]  
		WHERE [MAT].[matguid] NOT IN (SELECT [MatPtr] FROM [#T_Result])
	END 
END 
	--------------------------------------------------------------------------------- 
	IF @ShowPrevBalance <> 0 AND @ShowQty <> 0     
	BEGIN     
		UPDATE [#MatBillType] SET [PrevBal] = [t].[PrevBal]     
		FROM  (SELECT     
				[Res].[MatPtr] AS [MPtr],     
				SUM( [Res].[Qty]) AS [PrevBal] 
			FROM 
				[#T_ResultALlSource] AS [Res] 
			WHERE      
				( [Res].[buDate] < @StartDate)  AND [Type] = 0 and [Res].[buIsPosted]=1
			GROUP BY      
				[Res].[MatPtr] 
			) AS [t] INNER JOIN [#MatBillType] ON [MatPtr] = [t].[MPtr] 
		WHERE
		  Qty <> 0 
	
	END  
	---------------------------------------------------------- 
	------- End Result collected by bill type 
	IF(@ShowCostDetls <> 0)
	BEGIN 
	INSERT INTO @EndResult 
			SELECT       
				[BillType],  
				SUM( [Val]) AS [Val],  
				Sum( [QTy]) AS [Qty],  
				SUM( [Bonus]) AS [Bonus], 
				SUM( [PrevBal])  AS [PrevBal],
				[CostStr] 
			FROM       
				[#MatBillType] 
			GROUP By 
				   [CostStr],[BillType] 
	END 
	ELSE 
	BEGIN 
	INSERT INTO @EndResult ([BillType] ,[Val], [Qty],[Bonus], [PrevBal] )
			SELECT       
				[BillType],  
				SUM( [Val]) AS [Val],  
				Sum( [QTy]) AS [Qty],  
				SUM( [Bonus]) AS [Bonus], 
				SUM( [PrevBal])  AS [PrevBal] 
			FROM       
				[#MatBillType] 
			GROUP By 
				[BillType] 
	END 
	---------------------------------------------------------- 
	IF @ShowGroups <> 0     
	BEGIN  
		DECLARE @counter INT  
		CREATE CLUSTERED INDEX ccvcv ON  [#GrpTbl]([Number]) 
		IF @grLevel > 0 
		BEGIN 
			SET @counter = 1   
			WHILE @counter > 0 
			BEGIN 
				UPDATE a SET [mtGroup] = [grParent] FROM [#MatBillType] a INNER JOIN [#GrpTbl] [b] ON a.[mtGroup] = B.[Number] 
				WHERE [Level] > @grLevel 
				SET @counter = @@ROWCOUNT 
			END 
		END    
		    
		SET @counter = 1       
		WHILE @@ROWCOUNT > 0      
		BEGIN 
				INSERT INTO [#MatBillType]   ([Type], MatPtr,mtGroup,BillType,Val,Qty,Bonus,[PrevBal],[Ok])
				SELECT     
					0,     
					[MatPtr], 
					[grParent],     
					[billType],   
					[Val],  
					[Qty],  
					[Bonus],  
					[PrevBal],  
					@counter as [Ok]      
				FROM       
					(SELECT       
						[mtGroup] AS [MatPtr],      
						[BillType],  
						SUM( [Val]) AS [Val],  
						Sum( [QTy]) AS [Qty],  
						SUM( [Bonus])  AS [Bonus],  
						SUM( [PrevBal])  AS [PrevBal]  
					FROM       
						[#MatBillType]     
					WHERE       
						[ok] = @counter - 1      
					GROUP By       
						[mtGroup] ,      
						[BillType]      
					)AS [grRes]  
					INNER JOIN [#GrpTbl] As [GrTbl] ON [grRes].[MatPtr] = [GrTbl].[Number]  
				 	 
			IF @@ROWCOUNT = 0      
				BREAK     
			SET @counter = @counter + 1		      
		END  
	END     
	
	if (@showCostDetls <> 0)
	BEGIN
	INSERT [#FinalResult]     
	SELECT   
		[res].[Type],  
		[MatPtr], 
		[newMatPtr], 
		[mtGroup],  
		[res].[BillType],  
		Sum( [Val]) AS [Val],  
		Sum( [Qty]) AS [Qty],  
		Sum( [Bonus]) AS [Bonus],  
		Sum( [PrevBal]) AS [PrevBal],
		CASE [res].[Type] WHEN 0 THEN 0x0 ELSE [CostStr] END AS CostStr
	FROM   
		[#MatBillType]  res
	WHERE   
		( @ShowMats = 0 AND [res].[type] = 0 ) OR ( @ShowMats = 1)   
	Group By  
		[res].[Type],  
		[MatPtr],
		[newMatPtr], 
		[mtGroup],   
		[CostStr],
		[res].[BillType]
	ORDER BY [MatPtr]
	END 
	ELSE 
	BEGIN 
	INSERT [#FinalResult]     
	SELECT   
		[res].[Type],  
		[MatPtr], 
		[newMatPtr],  
		[mtGroup],  
		[res].[BillType],  
		Sum( [Val]) AS [Val],  
		Sum( [Qty]) AS [Qty],  
		Sum( [Bonus]) AS [Bonus],  
		Sum( [PrevBal]) AS [PrevBal]
		, 0x0
	FROM   
		[#MatBillType]  res
	WHERE   
		( @ShowMats = 0 AND [res].[type] = 0 ) OR ( @ShowMats = 1)   
	Group By  
		[res].[Type],  
		[MatPtr],  
		[newMatPtr], 
		[mtGroup],  
		[res].[BillType]
	ORDER BY [MatPtr]
	END 
	update [#FinalResult]
	SET [newMatPtr] =  CASE [Type] WHEN 1 THEN NEWID() ELSE [MatPtr] END
	if (@showCostDetls <> 0)
	SELECT 
		[Type],  
		[MatPtr],
		CASE [Res].[Type] WHEN 1 THEN [Mt].[mtName] ELSE [Gr].[grName] END AS [mName],
		CASE [Res].[Type] 
		WHEN 1 THEN 
			CASE @UseUnit    
				WHEN 0 THEN [Mt].[mtUnity]    
				WHEN 1 THEN [Mt].[mtUnit2]    
				WHEN 2 THEN [Mt].[mtUnit3]    
				ELSE [Mt].[mtDefUnitName]    
			END 
		ELSE ' ' END AS [DefUnit],  
		[newMatPtr], 
		Res.[mtGroup],  
		[BillType],  
		ISNULL([Val], 0) AS [Val],  
		[Qty],  
		[Bonus],  
		[PrevBal],
		CASE [Type] WHEN 0 THEN 0x0 ELSE [CostStr] END AS CostStr
   FROM  [#FinalResult]	[Res]
	  LEFT JOIN vwMt [Mt] ON [Mt].[mtGuid] = [Res].[MatPtr]	
	  LEFT JOIN vwGr [Gr] ON [Gr].[grGuid] = [Res].[MatPtr] 
   ORDER BY [Res].[MatPtr], [Res].[CostStr]
   ELSE
     SELECT 
		[Res].[Type],  
		[Res].[MatPtr], 
		CASE [Res].[Type] WHEN 1 THEN [Mt].[mtName] ELSE [Gr].[grName] END AS [mName],
		CASE [Res].[Type] 
		WHEN 1 THEN 
			CASE @UseUnit    
				WHEN 0 THEN [Mt].[mtUnity]    
				WHEN 1 THEN [Mt].[mtUnit2]    
				WHEN 2 THEN [Mt].[mtUnit3]    
				ELSE [Mt].[mtDefUnitName]    
			END 
		ELSE ' ' END AS [DefUnit],  
		[Res].[newMatPtr], 
		[Res].[mtGroup],  
		[Res].[BillType],  
		ISNULL([Res].[Val], 0) AS [Val],  
		[Res].[Qty],  
		[Res].[Bonus],  
		[Res].[PrevBal]
	  FROM  [#FinalResult]	[Res]
	  LEFT JOIN vwMt [Mt] ON [Mt].[mtGuid] = [Res].[MatPtr]	
	  LEFT JOIN vwGr [Gr] ON [Gr].[grGuid] = [Res].[MatPtr]
	  ORDER BY [Res].[MatPtr]
	--
	
	IF @ShowMats <> 0     
	BEGIN    
		DECLARE @Sql NVARCHAR(max) 
		SET @Sql = 'DECLARE @UseUnit AS [INT] ' 
		SET @Sql = @Sql + 'SET @UseUnit = '+ CONVERT(NVARCHAR(5),@UseUnit) + ' ' 
		SET @Sql = @Sql +  
		' SELECT distinct      
			1 AS [Type],     
			[mtGUID] AS [MatPtr],     
			[mtCode] AS [Code],     
			[mtName] AS [Name],  
			[mtLatinName] AS [LatinName],  
			CASE [dbo].fnConnections_GetLanguage() WHEN 0 THEN [mtName] WHEN 1 THEN CASE [mtLatinName] WHEN '''' THEN [mtName] ELSE [mtLatinName] END END AS [mName],
			[mtBarCode] AS [BarCode],   
			CASE @UseUnit    
				WHEN 0 THEN [mtUnity]    
				WHEN 1 THEN [mtUnit2]    
				WHEN 2 THEN [mtUnit3]    
				ELSE [mtDefUnitName]    
				END AS [DefUnit],  
			[mtType] AS [MatType],  
			[mtSpec] AS [Spec],  
			[mtDim] AS [Dim],  
			[mtOrigin] AS [Origin],  
			[mtPos] AS [Pos],  
			[grName] AS [GrName], 
			[grLatinName] AS [GrLatinName], 
			[mtCompany] AS [Company], 
			[mtColor]	AS [Color], 
			[mtProvenance] AS [Provenance], 
			[mtQuality] AS [Quality], 
			[mtModel] AS [Model], 
			[mtBarCode2] AS [BarCode2],  
			[mtBarCode3] AS [BarCode3],
			[mtVAT] AS [VAT],
			IsNull([costStr], N'''') as [CostStr]'  
		SET @Sql = @Sql +  
		' FROM      
			[vwMt] as [mt]  
			INNER JOIN [#MatBillType] AS [Tbl]      
			ON [mt].[mtGUID] = [Tbl].[MatPtr] 
			INNER JOIN [vwGr] AS [gr]      
			ON [mt].[mtGroup] = [gr].[grGUID] '  
		SET @Sql = @Sql + '  
		WHERE   
			[Tbl].[Type] = 1 ' 
		EXEC( @Sql ) 
	END  
	
	IF (@CollectByMcBillType = 0)
		SELECT 
		[r].[BillType],
		CASE @LangDirection WHEN 0 THEN [bt].[Name] WHEN 1 THEN CASE [bt].[LatinName] WHEN '''' THEN [bt].[Name] ELSE [bt].[LatinName] END END AS btName,
		[Val],
		[Qty],
		[Bonus],
		[PrevBal],
		[CostStr],
		CASE [bt].[BillType] WHEN 4 THEN -1 ELSE [bt].[BillType] END AS [Sort]
		FROM @EndResult [r]
		INNER JOIN bt000 bt ON bt.GUID = [r].BillType
		Order By [Sort] ASC
	ELSE
	SELECT 
		[r].[BillType],
		[Val],
		[Qty],
		[Bonus],
		[PrevBal],
		[CostStr],
		CASE [r].[BillType] WHEN 4 THEN -1 ELSE [r].[BillType] END AS [Sort]
		FROM @EndResult [r]
		Order By [Sort] ASC

###########################################################################
#END