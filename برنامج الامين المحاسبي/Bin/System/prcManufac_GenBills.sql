#########################################################
CREATE PROC prcManufac_genEntry
	@bEntryOut [bit],    
	@bEntryIn [bit] ,    
	@bEntrySemiOut BIT,
	@EntryOutNum FLOAT,
	@EntryInNum FLOAT,
	@EntryOutSemiNum FLOAT,
	@OutBillGuid UNIQUEIDENTIFIER = 0x0,
	@InBillGuid UNIQUEIDENTIFIER = 0x0,
	@outSemiBillGuid UNIQUEIDENTIFIER = 0x0,
	@isSemiManedMatBillReq INT

AS

SET NOCOUNT ON 

IF (@bEntryOut = 1 OR @EntryOutNum <> 0)        
BEGIN 
	EXEC [prcBill_GenEntry] @OutBillGUID, @EntryOutNum 
END

IF (@bEntryIn = 1 OR @EntryInNum <> 0)        
BEGIN   
	EXEC [prcBill_GenEntry] @InBillGUID, @EntryInNum
END  
IF ((@bEntrySemiOut = 1 OR @EntryOutSemiNum <> 0) AND (@isSemiManedMatBillReq = 1)) 
BEGIN
	EXEC [prcBill_GenEntry]	@outSemiBillGuid, @EntryOutSemiNum
END 
#########################################################
CREATE PROC prcManufac_genBills
	@ManufacGUID [UNIQUEIDENTIFIER]
	,@ForMaintenance [INT]  = 0
	,@PriceType [INT] = 4         -- if 4 then Get PriceType From mn000           
	,@pEntryOutNum float = 0
	,@pEntryInNum float = 0
	,@isSemiManedMatBillReq [INT] = 0
	,@pEntrySemiNum float = 0
	,@InBillNumber INT = 0
	,@OutBillNumber INT = 0
	,@SemiBillNumber INT = 0   
	,@InBillGuid [UNIQUEIDENTIFIER] = 0x0
	,@OutBillGuid [UNIQUEIDENTIFIER] = 0x0
	,@outSemiBillGuid [UNIQUEIDENTIFIER] = 0x0 
	,@ShowPriceforMatService [BIT] = 0
	,@PriceformMatService    [INT] = 0  
	,@UseCostCenter          [INT] = 0
	,@GenEntry bit = 1 
	,@CreateUserGuid [UNIQUEIDENTIFIER] = 0x0
	,@CreateDate [DATETIME] = '1980-01-01'
	,@LastUpdateUserGuid [UNIQUEIDENTIFIER] = 0x0
	,@LastUpdateDate [DATETIME] = '1980-01-01'
AS          
/*         
Algorithm steps :            
          - deletes any old bill found for the given manufacturing guid         
          - generate bills for a given manufacturing guid           
          - insert into bu000 two bills one for in and other for out          
          - insert into bi (manufacturing mat) for bills taken from (mi join mn)         
          - insert into di addition cost if mn generate entry          
          - update bu totlaprice and bi price          
          - update mn unitprice and totalprice          
          - insert into misn serial numbers for matarials if matarial have been defined as serializable         
          - post bills          
          - generate entries for generated bills          
          - return generated bill's guid to the caller          
*/           
SET NOCOUNT ON           
DECLARE                     
	@InBillTypeGUID [UNIQUEIDENTIFIER],           
	@OutBillTypeGUID [UNIQUEIDENTIFIER],           
	@OutTotal [FLOAT],       
	@SemiOutTotal [FLOAT],          
	@OutTotalRaw [FLOAT],         
	@OutTotalSemiRaw [FLOAT] ,         
	@OutTotalExtra [FLOAT],       
	@OutTotalSemiExtra  [FLOAT],         
	@Flags [BIT],           
	@OutBillDate [DATETIME],           
	@ManufQty [FLOAT],
	@CurrencyGUID [UNIQUEIDENTIFIER],
	@CurrencyVal [FLOAT],
	@outSemiBillTypeGuid  [UNIQUEIDENTIFIER], 
	@isFineToGenerateBill [INT] ,       
	@isFineForRawMatBill [INT] ,      
	@GrGuid [UNIQUEIDENTIFIER]
	
DECLARE @EntryOutNum FLOAT
DECLARE @EntryOutSemiNum FLOAT
DECLARE @EntryInNum FLOAT
   
DECLARE @Lang INT 
SET @Lang = (SELECT [dbo].[fnConnections_GetLanguage]())
	
        
SET @EntryOutNum = 0          
SET @EntryInNum = 0          
SET @EntryOutSemiNum = 0
               
IF(ISNULL(@InBillGuid, 0x0) = 0x0)
	SET @InBillGuid = NEWID()
IF(ISNULL(@OutBillGuid, 0x0) = 0x0)
	SET @OutBillGuid = NEWID()
IF(ISNULL(@outSemiBillGuid, 0x0) = 0x0)
	SET @outSemiBillGuid = NEWID()
----------------------------------------------------------------------------------       
IF (@ForMaintenance <> 0)          
BEGIN          
	SELECT @EntryOutNum  = ce.Number          
	FROM CE000 AS ce           
	INNER JOIN ER000 AS er ON ce.GUID = er.EntryGUID           
	INNER JOIN BU000 AS bu ON bu.GUID = er.ParentGUID          
	INNER JOIN MB000 AS mb ON mb.BillGUID = bu.GUID AND mb.Type = 0          
	WHERE mb.ManGUID = @ManufacGUID          
	SELECT @EntryInNum  = ce.Number          
	FROM CE000 AS ce           
	INNER JOIN ER000 AS er ON ce.GUID = er.EntryGUID           
	INNER JOIN BU000 AS bu ON bu.GUID = er.ParentGUID          
	INNER JOIN MB000 AS mb ON mb.BillGUID = bu.GUID AND mb.Type = 1          
	WHERE mb.ManGUID = @ManufacGUID         
	SELECT @EntryOutSemiNum  = ce.Number          
	FROM CE000 AS ce           
	INNER JOIN ER000 AS er ON ce.GUID = er.EntryGUID           
	INNER JOIN BU000 AS bu ON bu.GUID = er.ParentGUID          
	INNER JOIN MB000 AS mb ON mb.BillGUID = bu.GUID AND mb.Type = 2          
	WHERE mb.ManGUID = @ManufacGUID         
END          
ELSE          
BEGIN          
	SET @EntryOutNum = @pEntryOutNum          
	SET @EntryInNum = @pEntryInNum         
	SET @EntryOutSemiNum = @pEntrySemiNum        
END      
-------------------------------------------------------------------------------------     
-- Õ–› ›« Ê—… «·≈œŒ«· Ê «·≈Œ—«Ã ·⁄„·Ì… «· ’‰Ì⁄         
-- delete old bills          
EXEC [prcManufac_DeleteBills] @ManufacGUID          
-------------------------------------------------------------------------------------     
-- declare variable to hold new bill guid and bring it's type from bt table          
SELECT           
	@OutBillTypeGUID = (SELECT [GUID] FROM [bt000] WHERE [Type] = 2 AND [SortNum] = 6),           
	@InBillTypeGUID = (SELECT [GUID] FROM [bt000] WHERE [Type] = 2 AND [SortNum] = 5)         
SELECT        
	@outSemiBillTypeGuid = CAST((SELECT [VALUE]	FROM op000 WHERE [NAME] = 'man_semiconduct_outbilltype') AS UNIQUEIDENTIFIER)
SELECT           
	@Flags = ISNULL([Flags], 0),           
	@OutBillDate = [OutDate],           
	@ManufQty = [Qty],           
	@PriceType = CASE @PriceType WHEN 4 THEN [PriceType] ELSE @PriceType END,           
	@CurrencyGUID = CurrencyGUID,           
	@CurrencyVal = CurrencyVal           
FROM [mn000] 
WHERE [GUID] = @ManufacGUID           
DECLARE @buNumber FLOAT 
		, @Branch UNIQUEIDENTIFIER         
SELECT @buNumber = Number , @Branch = BranchGuid          
FROM mn000          
WHERE guid = @ManufacGUID    
SELECT @buNumber = CASE @InBillNumber WHEN 0 THEN  ([dbo].[fnBill_getNewNum] (@InBillTypeGUID , @Branch ))  ELSE @InBillNumber END  
----------------------------------------------------------------------------------     
SELECT @GrGuid = CAST((SELECT [VALUE] FROM op000 WHERE [NAME] ='man_semiconductGroup')AS UNIQUEIDENTIFIER)         
SELECT @isFineToGenerateBill =        
(       
	SELECT COUNT(*) 
	FROM [mi000] AS [mi]
		INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]           
		INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]           
		WHERE [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 1         
			AND [mt].[groupGuid] IN (SELECT * FROM fnGetGroupsList(@GrGuid))      
)       
SELECT @isFineForRawMatBill =        
(       
	SELECT COUNT(*) 
		FROM [mi000] AS [mi]            
		INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]           
		INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]           
	WHERE [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 1         
		AND [mt].[groupGuid] NOT IN (SELECT * FROM fnGetGroupsList(@GrGuid))      
)      
----------------------------------------------------------------------------------
if EXISTS(  SELECT cu.AccountGUID
	from cu000 cu
	INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
	INNER JOIN(
		SELECT OutTempAccGUID FROM mn000
		WHERE GUID = @ManufacGUID) mn on mn.OutTempAccGUID = cu.AccountGUID
	WHERE ac.CustomersCount > 1)
		BEGIN
		DECLARE @AccoutnGUID UNIQUEIDENTIFIER;
		SELECT  @AccoutnGUID = cu.AccountGUID
		FROM cu000 cu
		INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
		INNER JOIN(
			SELECT OutTempAccGUID FROM mn000
			WHERE GUID = @ManufacGUID) mn on mn.OutTempAccGUID = cu.AccountGUID
		WHERE ac.CustomersCount > 1
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0052: [' + CAST(@AccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
		RETURN 
		END 
--------------------------------- ›« Ê—… «·«œŒ«· ---------------------------------       
INSERT INTO [bu000](           
		[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits],            
		[IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],            
		[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID],
		[CreateUserGUID], [CreateDate], [LastUpdateUserGUID], [LastUpdateDate])           
		SELECT           
			@buNumber,         
			'',           
			[InDate],           
			@CurrencyVal, --[CurrencyVal],
			[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+': '+ CONVERT(nvarchar(MAX), MN.[Number])+' -'+
			[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+': '+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+' -'+
			[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+': '+CONVERT(nvarchar(MAX), MN.Qty ),
			0, -- total of input bu: will be calculated later           
			1, -- payType           5
			0, -- totalDisc           
			0, -- totalExtra           
			0, -- itemsDisc           
			0, -- bonusDisc           
			0, -- firstPay           
			0, -- profits           
			0, -- isPosted           
			[Security],           
			0, -- vendor           
			0, -- salesManPtr           
			@Branch,             
			0, -- vat           
			@InBillGUID,           
			@InBillTypeGUID,           
			ISNULL(
					(SELECT [GUID] 
					FROM [cu000] 
					WHERE [AccountGUID] = [InTempAccGUID])
			, 0x0), -- CustGUID           
			@CurrencyGUID,                --[CurrencyGUID],           
			[InStoreGUID],                     
			[InTempAccGUID],           
			[InAccountGUID],           
			0x0, -- ItemsDiscAccGUID           
			0x0, -- bonusDiscAccGUID           
			0x0, -- FPayAccGUID           
			CASE @UseCostCenter WHEN 1 THEN StepCost ELSE  [InCostGUID] END,--[InCostGUID],           
			[dbo].[fnGetCurrentUserGUID](), -- userGUID           
			0x0, -- CheckTypeGUID  
			@CreateUserGuid,
			@CreateDate,
			@LastUpdateUserGuid,
			@LastUpdateDate         
		FROM [mn000]    mn       
		WHERE [GUID] = @ManufacGUID           
-- insert bi           
INSERT INTO [bi000](           
		[Number], [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits],            
		[Num1], [Num2], [Qty2], [Qty3], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],            
		[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [CostGUID], ClassPtr)           
		-- input bill items ( taken from mi000 joim mn000)          
		SELECT           
			[mi].[Number],           
			[mi].[Qty],           
			0, -- order           
			0, -- order qnt           
			[mi].[Unity],           
			0, -- Price: will be updated later           
			0, -- bonusQnt           
			0, -- discount           
			0, -- bonusDisc           
			0, -- extra           
			[mi].[CurrencyVal], 
			CASE 
				WHEN ISNULL([mi].[Notes], N'') = N'' THEN
					[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+' :'+ CONVERT(nvarchar(MAX), MN.[Number])+'-'+
					[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+' :'+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+'-'+
					[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+' :'+CONVERT(nvarchar(MAX), MN.Qty )
				ELSE [mi].[Notes] 
			END,
			0, -- profits,           
			0, -- num1           
			0, -- num2           
			[mi].[Qty2],           
			[mi].[Qty3],           
			--[mi].[class],           -- ClassPtr           
			[mi].[ExpireDate],           
			[mi].[ProductionDate],           
			[mi].[Length],           
			[mi].[Width],           
			[mi].[Height],           
			0,           
			0,           
			@InBillGUID,           
			[mi].[MatGUID],           
			@CurrencyGUID,           
			CASE [mi].[StoreGUID] 
				WHEN 0x0 THEN [mn].[inStoreGUID] 
				ELSE [mi].[StoreGUID] 
			END,
			CASE @UseCostCenter WHEN 1 THEN [mn].StepCost ELSE  [mi].[CostGUID] END,--[mi].[CostGUID],   
			CASE mt.ClassFlag WHEN 0 THEN '' ELSE 	     
				CASE [mi].[Class]
					WHEN '' THEN [mn].[LOT]
					ELSE [mi].[Class]
	  			END
			END
		FROM [mi000] [mi]           
		INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]   
		inner join mt000 mt on mt.guid = mi.matguid             
		WHERE   [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 0           
INSERT INTO [mb000]([Type], [ManGUID], [BillGUID])           
	SELECT 1, @ManufacGUID, @InBillGUID
---------------------------------------------------------------------------------       
      
------------------------------- ›« Ê—… «Œ—«Ã  -----------------------------------       
SELECT @buNumber = CASE @OutBillNumber 
						WHEN 0 THEN  ([dbo].[fnBill_getNewNum] (@OutBillTypeGUID , @Branch ))  
						ELSE @OutBillNumber 
				   END  
INSERT INTO [bu000](           
		[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits],            
		[IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],            
		[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID],
		[CreateUserGUID], [CreateDate], [LastUpdateUserGUID], [LastUpdateDate])           
		SELECT           
			@buNumber,           
			'',          
			[OutDate],           
			@CurrencyVal,--[CurrencyVal], 
			[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+': '+ CONVERT(nvarchar(MAX), MN.[Number])+' -'+
			[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+': '+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+' -'+
			[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+': '+CONVERT(nvarchar(MAX), MN.Qty ),
			--[Notes],           
			0, -- total of output bu: will be calculated later           
			1, -- payType           
			0, -- totalDisc           
			0, -- @Flags * @OutTotalExtra --- totalExtra           
			0, -- itemsDisc           
			0, -- bonusDisc           
			0, -- firstPay           
			0, -- profits           
			0, -- isPosted           
			[Security],           
			0, -- vendor           
			0, -- salesManPtr           
			@Branch,           
			0, -- vat           
			@OutBillGUID,           
			@OutBillTypeGUID,           
			ISNULL(
					(SELECT [GUID] 
					FROM [cu000] 
					WHERE [AccountGUID] = [OutTempAccGUID])
			, 0x0), -- CustGUID           
			@CurrencyGUID,                --[CurrencyGUID],           
			[OutStoreGUID],                  
			[OutTempAccGUID],           
			[OutAccountGUID],           
			0x0, -- ItemsDiscAccGUID           
			0x0, -- bonusDiscAccGUID           
			0x0, -- FPayAccGUID           
			CASE @UseCostCenter WHEN 1 THEN StepCost ELSE OutCostGUID END,           
			[dbo].[fnGetCurrentUserGUID](), -- userGUID           
			0x0, -- CheckTypeGUID
			@CreateUserGuid,
			@CreateDate, 
			@LastUpdateUserGuid,
			@LastUpdateDate          
		FROM [mn000] mn        
		WHERE [GUID] = @ManufacGUID
		
INSERT INTO [bi000](           
		[Number], [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits],            
		[Num1], [Num2], [Qty2], [Qty3], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],            
		[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [CostGUID], ClassPtr)             
		SELECT           
			[mi].[Number],           
			[mi].[Qty],           
			0, -- order           
			0, -- order qnt           
			[mi].[Unity],           
			CASE @ShowPriceforMatService WHEN 0 THEN 
                            (CASE @PriceType 
				WHEN 3 THEN [mi].[Price]
                                ELSE  
								 [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
																									WHEN 3 THEN [mt].[unit3Fact] 
																									ELSE 1 
                                                                                                          END
																										  )   
																							  END) 
                           WHEN 1 THEN
                                  CASE mt.Type
                                         WHEN 0 THEN (CASE @PriceType 
														WHEN 3 THEN [mi].[Price]
														ELSE  [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
                                                                                                                             WHEN 3 THEN [mt].[unit3Fact]  
                                                                                                                             ELSE 1  
                                                                                                          END
																										  )   
                                                END) 
										 WHEN 1  THEN
										  CASE @PriceformMatService 
												WHEN 0 THEN mt.Export
												WHEN 1 THEN mt.Whole
												WHEN 2 THEN mt.EndUser                 
												WHEN 3 THEN mt.Retail
												WHEN 4 THEN mt.Vendor
												WHEN 5 THEN mt.LastPrice    
												WHEN 6 THEN mt.Half                                                                                                                                              
										   END    
                                  END       
                END
			, 
			0, -- bonusQnt           
			0, -- discount           
			0, -- bonusDisc           
			0, -- extra           
			@CurrencyVal,
			CASE 
				WHEN ISNULL([mi].[Notes], N'') = N'' THEN
					[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+' :'+ CONVERT(nvarchar(MAX), MN.[Number])+'-'+
					[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+' :'+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+'-'+
					[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+' :'+CONVERT(nvarchar(MAX), MN.Qty )
				ELSE [mi].[Notes] 
			END,
			0, -- profits,           
			0, -- num1           
			0, -- num2           
			[mi].[Qty2],           
			[mi].[Qty3],           
			--[mi].[class],                     -- Class           
			[mi].[ExpireDate],           
			[mi].[ProductionDate],           
			[mi].[Length],           
			[mi].[Width],           
			[mi].[Height],           
			0,           
			0,           
			@OutBillGUID,           
			[mi].[MatGUID],           
			@CurrencyGUID,                --[mi].[CurrencyGUID],           
			CASE [mi].[StoreGUID] 
				WHEN 0x0 THEN [mn].[outStoreGUID] 
				ELSE [mi].[StoreGUID] 
			END,           
			CASE @UseCostCenter WHEN 1 THEN [mn].StepCost ELSE  [mi].[CostGUID] END,                  
		  [mi].[Class]
		FROM [mi000] AS [mi]            
		INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]           
		INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]           
		WHERE [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 1         
			AND [mt].[groupGuid] NOT IN (SELECT * FROM fnGetGroupsList(@GrGuid))     
	
IF( NOT((@isSemiManedMatBillReq = 1) AND (@isFineToGenerateBill >= 1)) )
BEGIN
	INSERT INTO [bi000](           
			[Number], [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits],            
			[Num1], [Num2], [Qty2], [Qty3], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],            
			[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [CostGUID], ClassPtr)             
			SELECT           
				[mi].[Number],           
				[mi].[Qty],           
				0, -- order           
				0, -- order qnt           
				[mi].[Unity],           
				CASE @ShowPriceforMatService WHEN 0 THEN 
                            (CASE @PriceType 
					WHEN 3 THEN [mi].[Price]
                                ELSE  
								 [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
																										WHEN 3 THEN [mt].[unit3Fact] 
																										ELSE 1 
                                                                                                          END
																										  )   
																								  END) 
                           WHEN 1 THEN
                                  CASE mt.Type
                                         WHEN 0 THEN (CASE @PriceType 
					WHEN 3 THEN [mi].[Price] / [mi].[CurrencyVal] 
														ELSE  [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
																										WHEN 3 THEN [mt].[unit3Fact] 
																										ELSE 1 
                                                                                                          END
																										  )   
																								  END) 
										 WHEN 1  THEN
										  CASE @PriceformMatService 
												WHEN 0 THEN mt.Export
												WHEN 1 THEN mt.Whole
												WHEN 2 THEN mt.EndUser                 
												WHEN 3 THEN mt.Retail
												WHEN 4 THEN mt.Vendor
												WHEN 5 THEN mt.LastPrice    
												WHEN 6 THEN mt.Half                                                                                                                                              
										   END    
                                  END       
				END,           
				0, -- bonusQnt           
				0, -- discount           
				0, -- bonusDisc           
				0, -- extra           
				@CurrencyVal,
				CASE 
					WHEN ISNULL([mi].[Notes], N'') = N'' THEN
						[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+' :'+ CONVERT(nvarchar(MAX), MN.[Number])+'-'+
						[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+' :'+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+'-'+
						[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+' :'+CONVERT(nvarchar(MAX), MN.Qty )
					ELSE [mi].[Notes] 
				END,
				0, -- profits,           
				0, -- num1           
				0, -- num2           
				[mi].[Qty2],           
				[mi].[Qty3],           
				--[mi].[class],                     -- Class           
				[mi].[ExpireDate],           
				[mi].[ProductionDate],           
				[mi].[Length],           
				[mi].[Width],           
				[mi].[Height],           
				0,           
				0,           
				@OutBillGUID,           
				[mi].[MatGUID],           
				@CurrencyGUID,                --[mi].[CurrencyGUID],           
				CASE [mi].[StoreGUID] 
					WHEN 0x0 THEN [mn].[outStoreGUID] 
					ELSE [mi].[StoreGUID] 
				END,           
				 CASE @UseCostCenter WHEN 1 THEN [mn].StepCost ELSE  [mi].[CostGUID] END,	--[mi].[CostGUID],        
		    [mi].[Class]
			FROM [mi000] AS [mi]            
			INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]           
			INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]           
			WHERE [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 1         
				AND [mt].[groupGuid]  IN (SELECT * FROM fnGetGroupsList(@GrGuid))
END
------------------------------------›« Ê—… «Œ—«Ã «·„Ê«œ ‰’› «·„’‰⁄…------------------------------------------     
IF ((@isSemiManedMatBillReq = 1) AND (@isFineToGenerateBill >= 1))       
BEGIN    
	SELECT @buNumber = CASE @SemiBillNumber 
							WHEN 0 THEN  ([dbo].[fnBill_getNewNum] (@outSemiBillTypeGuid , @Branch ))
							ELSE @SemiBillNumber 
					   END
	INSERT INTO [bu000](           
			[Number], [Cust_Name], [Date], [CurrencyVal], [Notes], [Total], [PayType], [TotalDisc], [TotalExtra], [ItemsDisc], [BonusDisc], [FirstPay], [Profits],            
			[IsPosted], [Security], [Vendor], [SalesManPtr], [Branch], [VAT], [GUID], [TypeGUID], [CustGUID], [CurrencyGUID], [StoreGUID], [CustAccGUID],            
			[MatAccGUID], [ItemsDiscAccGUID], [BonusDiscAccGUID], [FPayAccGUID], [CostGUID], [UserGUID], [CheckTypeGUID],
			[CreateUserGUID], [CreateDate], [LastUpdateUserGUID], [LastUpdateDate])              
			--insert input bill         
			SELECT           
				@buNumber,           
				'',          
				[OutDate],           
				@CurrencyVal,--[CurrencyVal], 
			[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+': '+ CONVERT(nvarchar(MAX), MN.[Number])+' -'+
			[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+': '+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+' -'+
			[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+': '+CONVERT(nvarchar(MAX), MN.Qty ),
			          
				--[Notes],           
				0, -- total of output bu: will be calculated later           
				1, -- payType           
				0, -- totalDisc           
				0, -- @Flags * @OutTotalExtra --- totalExtra           
				0, -- itemsDisc           
				0, -- bonusDisc           
				0, -- firstPay           
				0, -- profits           
				0, -- isPosted           
				[Security],           
				0, -- vendor           
				0, -- salesManPtr           
				@Branch,           
				0, -- vat           
				@outSemiBillGuid,           
				@outSemiBillTypeGuid,           
				ISNULL((SELECT [GUID] 
						FROM [cu000] 
						WHERE [AccountGUID] = [OutTempAccGUID])
				, 0x0), -- CustGUID           
				@CurrencyGUID,                --[CurrencyGUID],           
				[OutStoreGUID],                  
		    [OutTempAccGUID],           
				[OutAccountGUID],           
				0x0, -- ItemsDiscAccGUID           
				0x0, -- bonusDiscAccGUID           
				0x0, -- FPayAccGUID           
				CASE @UseCostCenter WHEN 1 THEN StepCost ELSE  OutCostGUID END,--OutCostGUID,           
				[dbo].[fnGetCurrentUserGUID](), -- userGUID           
				0x0, -- CheckTypeGUID   
				@CreateUserGuid,
				@CreateDate,
				@LastUpdateUserGuid,
				@LastUpdateDate         
			FROM [mn000] AS MN      
			WHERE [GUID] = @ManufacGUID      
	INSERT INTO [bi000](           
			[Number], [Qty], [Order], [OrderQnt], [Unity], [Price], [BonusQnt], [Discount], [BonusDisc], [Extra], [CurrencyVal], [Notes], [Profits],            
			[Num1], [Num2], [Qty2], [Qty3], [ExpireDate], [ProductionDate], [Length], [Width], [Height], [VAT], [VATRatio],            
			[ParentGUID], [MatGUID], [CurrencyGUID], [StoreGUID], [CostGUID], ClassPtr)             
			SELECT           
				[mi].[Number],           
				[mi].[Qty],           
				0, -- order           
				0, -- order qnt           
				[mi].[Unity],           
				CASE @ShowPriceforMatService WHEN 0 THEN 
                            (CASE @PriceType 
                                WHEN 3 THEN [mi].[Price] / [mi].[CurrencyVal] 
                                ELSE  
								 [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
                                                                                                                             WHEN 3 THEN [mt].[unit3Fact]  
                                                                                                                             ELSE 1  
                                                                                                          END
																										  )   
                                                END) 
                           WHEN 1 THEN
                                  CASE mt.Type
                                         WHEN 0 THEN (CASE @PriceType 
					WHEN 3 THEN [mi].[Price]/ [mi].[CurrencyVal] 
														ELSE  [dbo].[fnMaterial_GetPrice]([mi].[MatGUID], @PriceType, @OutBillDate) * (CASE [mi].[unity]  WHEN 2 THEN [mt].[unit2Fact]  
																										WHEN 3 THEN [mt].[unit3Fact] 
																										ELSE 1 
                                                                                                          END
																										  )   
																								   END) 
										 WHEN 1  THEN
										  CASE @PriceformMatService 
												WHEN 0 THEN mt.Export
												WHEN 1 THEN mt.Whole
												WHEN 2 THEN mt.EndUser                 
												WHEN 3 THEN mt.Retail
												WHEN 4 THEN mt.Vendor
												WHEN 5 THEN mt.LastPrice    
												WHEN 6 THEN mt.Half                                                                                                                                              
										   END    
                                  END       
				END,
				0, -- bonusQnt           
				0, -- discount           
				0, -- bonusDisc           
				0, -- extra           
				@CurrencyVal, 
			    --[mi].[CurrencyVal],           
				CASE 
					WHEN ISNULL([mi].[Notes], N'') = N'' THEN
						[dbo].[fnStrings_get]('COSTREPS\NUMBER', @lang)+' :'+ CONVERT(nvarchar(MAX), MN.[Number])+'-'+
						[dbo].[fnStrings_get]('COSTREPS\FORM', @lang)+' :'+(select fm.Name from fm000  fm where fm.GUID=MN.FormGUID)+'-'+
						[dbo].[fnStrings_get]('COSTREPS\QTY', @lang)+' :'+CONVERT(nvarchar(MAX), MN.Qty )
					ELSE [mi].[Notes] 
				END,
				0, -- profits,           
				0, -- num1           
				0, -- num2           
				[mi].[Qty2],           
				[mi].[Qty3],           
				--[mi].[class],                     -- Class           
				[mi].[ExpireDate],           
				[mi].[ProductionDate],           
				[mi].[Length],           
				[mi].[Width],           
				[mi].[Height],           
				0,           
				0,           
				@outSemiBillGuid,           
				[mi].[MatGUID],           
				@CurrencyGUID,                --[mi].[CurrencyGUID],           
				CASE [mi].[StoreGUID] 
					WHEN 0x0 THEN [mn].[outStoreGUID] 
					ELSE [mi].[StoreGUID] 
				END,
				CASE @UseCostCenter WHEN 1 THEN [mn].StepCost ELSE  [mi].[CostGUID] END,--[mi].[CostGUID],        
		    [mi].[Class]
				FROM            
				[mi000] AS [mi]            
				INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]           
				INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]           
				WHERE [mi].[ParentGUID] = @ManufacGUID AND [mi].[type] = 1         
					AND [mt].[groupGuid] IN (SELECT * FROM fnGetGroupsList(@GrGuid))     
END                  
               
--------------------------------------------------------------------------------------      
INSERT INTO [mb000]([Type], [ManGUID], [BillGUID])           
	SELECT 2, @ManufacGUID, @outSemiBillGuid           
	UNION ALL           
	SELECT 0,@ManufacGUID, @OutBillGUID       
IF(@isFineToGenerateBill = 0)       
	DELETE FROM [mb000] WHERE billGuid = @outSemiBillGuid                        
----------------------------------------------------------------------------------------------       
-- return outBillGuid and inBillGuid to the caller          
-- SELECT @OutBillGUID AS [OutBillGUID], @InBillGUID AS [InBillGUID]        
----------------------------------------------------------------------------------------------        
-- insert serial numbers(in misn000) for input bill material, if any:        
INSERT INTO [snc000] ([SN],[MatGUID],[Qty])           
	SELECT   
		[sn].[SN],            
		[bi].[MatGUID],           
		0   
	FROM [mi000] AS [mi] INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number] INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
    WHERE [mi].[ParentGUID] = @manufacGUID 
		AND [mi].[type] = 0 
		AND [bi].[ParentGUID] = @InBillGUID           
		AND [sn].[SN] NOT IN (SELECT SN FROM Snc000)
INSERT INTO [snt000] ([Item], [biGUID], [stGUID], [ParentGUID], [Notes], [buGuid])   
	SELECT    
		[sn].[Number],   
		[bi].[GUID],   
		[bi].[StoreGUID],   
		[snc].guid,         
		--[mn000].Number,         
		'',   
		[bi].[ParentGUID]   
	FROM [mi000] AS [mi] 
	INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number]    
    INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
    INNER JOIN [snc000] AS [snc] ON [snc].MatGUID = [bi].[MatGUID] AND [snc].SN = [sn].[SN]
    WHERE [mi].[ParentGUID] = @manufacGUID 
		AND [mi].[type] = 0 
		AND [bi].[ParentGUID] = @InBillGUID           
-------------------------------------------------------------------------------------     
INSERT INTO [snc000] ([SN],[MatGUID],[Qty])   
	SELECT            
		[sn].[SN],            
		[bi].[MatGUID],           
		1        
	FROM [mi000] AS [mi]           
	INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number]            
	INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
    WHERE [mi].[ParentGUID] = @manufacGUID 
		AND [mi].[type] = 1 
		AND [bi].[ParentGUID] = @OutBillGUID           
		AND [sn].[SN] NOT IN (SELECT SN FROM Snc000)
INSERT INTO [snc000] ([SN],[MatGUID],[Qty])   
	SELECT            
		[sn].[SN],            
		[bi].[MatGUID],           
		1        
	FROM [mi000] AS [mi]           
	INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number]            
	INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
    WHERE [mi].[ParentGUID] = @manufacGUID 
		AND [mi].[type] = 1 
		AND [bi].[ParentGUID] = @outSemiBillGuid           
		AND [sn].[SN] NOT IN (SELECT SN FROM Snc000)
INSERT INTO [snt000] ([Item], [biGUID], [stGUID], [ParentGUID], [Notes], [buGuid])   
	SELECT   
		[sn].[Number],   
		[bi].[GUID],   
		[bi].[StoreGUID],   
		[snc].guid,         
		'',   
		[bi].[ParentGUID]   
	FROM [mi000] AS [mi]           
	INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number]            
	INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
	INNER JOIN [snc000] AS [snc] ON  [snc].MatGUID = [bi].[MatGUID] AND [snc].SN = [sn].[SN]   
    WHERE [mi].[ParentGUID] = @manufacGUID 
		AND [mi].[type] = 1 
		AND ([bi].[ParentGUID] = @OutBillGUID  or bi.ParentGUID=@outSemiBillGuid  )          
-------------------------------------------------------------------------------------     
IF (@isSemiManedMatBillReq = 1 AND @isFineToGenerateBill >0)       
BEGIN       
	INSERT INTO [sn000] ([Item], [SN], [InGuid], [OutGUID], [Notes], [MatGUID])           
		SELECT            
			[sn].[Number],            
			[sn].[SN],            
			0x0,           
			[bi].[GUID],           
			[sn].[Notes],            
			[bi].[MatGUID]           
		FROM [mi000] AS [mi]           
		INNER JOIN [bi000] AS [bi] ON [mi].[Number] = [bi].[Number]            
		INNER JOIN [misn000] AS [sn] ON [mi].[GUID] = [sn].[miGUID]           
		WHERE [mi].[ParentGUID] = @manufacGUID 
			AND [mi].[type] = 1 
			AND [bi].[ParentGUID] = @outSemiBillGuid          
	SELECT @OutTotalSemiRaw = ISNULL(
									(SELECT SUM([biPrice] * [biBillQty]) 
									FROM [vwBiMt] 
									WHERE [vwBiMt].[biParent] = @outSemiBillGuid)
							  ,0)
END       
-------------------------------------------------------------------------------------       
SELECT @outTotalRaw = ISNULL(
							  (SELECT SUM([biPrice] * [biBillQty]) 
							  FROM [vwBiMt] 
							  WHERE [vwBiMt].[biParent] = @OutBillGUID)
					  ,0)
DECLARE @SemiTotal float = ISNULL(
							  (SELECT SUM([biPrice] * [biBillQty]) 
							  FROM [vwBiMt] 
							  WHERE [vwBiMt].[biParent] = @outSemiBillGuid)
					  ,0)
--                 --≈œŒ«· «·≈÷«›«  ›Ì ÃœÊ· «·≈÷«›«  Ê «·Õ”„Ì«  ›Ì Õ«· ﬂ«‰  ⁄„·Ì… «· ’‰Ì⁄          
--  Ê·œ ﬁÌœ »«· ﬂ«·Ì› «·≈÷«›Ì…         
IF( @Flags = 1 )       
BEGIN    
	IF EXISTS( SELECT TOP 1 cu.AccountGUID
					FROM cu000 cu
					INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
					INNER JOIN(
						SELECT AccountGUID FROM mx000
						WHERE ParentGUID = @ManufacGUID) mn on mn.AccountGUID = cu.AccountGUID
					WHERE ac.CustomersCount > 1)
	BEGIN
		DECLARE @DiscAccoutnGUID UNIQUEIDENTIFIER;
		SELECT TOP 1  @DiscAccoutnGUID = cu.AccountGUID
		FROM cu000 cu
		INNER JOIN vwAcCu ac on ac.GUID = cu.AccountGUID
		INNER JOIN(
			SELECT AccountGUID FROM mx000
			WHERE ParentGUID = @ManufacGUID) mn on mn.AccountGUID = cu.AccountGUID
		WHERE ac.CustomersCount > 1
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
		SELECT 1, 0, 'AmnE0052: [' + CAST(@DiscAccoutnGUID AS NVARCHAR(36)) +'] Account Have Multi customer',0x0
	RETURN 
	END 

INSERT INTO [di000](           
		[Number], [Discount], [Extra], [CurrencyVal], [Notes], [Flag], [ClassPtr],            
		[ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])           
	SELECT           
		MX.[Number],  
		0,
		MX.Extra,       
		MX.[CurrencyVal],           
		MX.[Notes],           
		MX.[Flag],           
		MX.[Class],           
		@OutBillGUID,           
		MX.[AccountGUID],           
		MX.[CurrencyGUID],           
		MX.[CostGUID],           
		MX.[ContraAccGUID],   
		ISNULL(CU.GUID, 0x0)          
	FROM [mx000] AS MX        
	LEFT JOIN cu000 AS CU ON CU.AccountGUID = MX.AccountGUID
	WHERE MX.[ParentGUID] = @ManufacGUID  AND MX.TYPE = 1   
	
	INSERT INTO [di000](           
		[Number], [Discount], [Extra], [CurrencyVal], [Notes], [Flag], [ClassPtr],            
		[ParentGUID], [AccountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID], [CustomerGUID])           
	SELECT           
		MX.[Number],  
		0,
		MX.Extra,       
		MX.[CurrencyVal],           
		MX.[Notes],           
		MX.[Flag],           
		MX.[Class],           
		@OutBillGUID,           
		MX.[AccountGUID],           
		MX.[CurrencyGUID],           
		MX.[CostGUID],           
		MX.[ContraAccGUID],
		ISNULL(CU.GUID, 0x0)           
	FROM [mx000] AS MX
	LEFT JOIN cu000 AS CU ON CU.AccountGUID = MX.AccountGUID          
	WHERE MX.[ParentGUID] = @ManufacGUID   AND MX.TYPE = 0        
END       
-----------------------------------------------------------------------------       
          -- calculate bill totals        
SET @OutTotal =0       
SET @SemiOutTotal = 0       
SET @OutTotalExtra = 0       
SET @OutTotalSemiExtra = 0       
-------------------------------------------------------     
SELECT @OutTotalExtra = ISNULL((SELECT SUM(Extra) 
								FROM [mx000] 
								WHERE [ParentGUID] = @ManufacGUID), 0)
								
SET @OutTotal = @outTotalExtra + @outTotalRaw
DECLARE @TotalDisc [float]
DECLARE @TotalExtra [float]
SELECT @TotalDisc = ISNULL( SUM( Discount ) , 0) 
FROM di000 
WHERE ParentGuid = @OutBillGUID 
SELECT @TotalExtra = ISNULL( SUM( Extra ), 0)  
FROM di000 
WHERE ParentGuid = @OutBillGUID 
-----------------------------------------------------------     
IF (@isSemiManedMatBillReq = 1 AND @isFineToGenerateBill > 0)       
BEGIN       
	SELECT @OutTotalSemiExtra = ISNULL((SELECT SUM( CASE [Extra] 
														WHEN 0 THEN [Discount] * @OutTotalSemiRaw /100 
														ELSE [Extra]*[currencyVal] 
													END) 
										FROM [mx000] 
										WHERE [ParentGUID] = @ManufacGUID), 
								0)       
	SET @SemiOutTotal = @OutTotalSemiRaw--+@OutTotalSemiExtra       
END        
---------------------------------------------------------------------     
-- update input bills total and extra          
UPDATE [bu000] SET
	[TotalExtra] = 0,           
	[Total] = (@OutTotal + @SemiOutTotal)
WHERE   [GUID] = @InBillGUID           
-- update output bills  total and extra
UPDATE [bu000] SET
	[TotalDisc] = @TotalDisc,
	[TotalExtra] = @TotalExtra,
	[Total] = @OutTotalRaw
WHERE [GUID] = @OutBillGUID
--update semi output bills and extra
UPDATE [bu000] SET
	[TotalExtra] = 0 ,--@Flags * @OutTotalSemiExtra,
	[Total] = @SemiOutTotal-- - @OutTotalSemiExtra
WHERE [GUID]= @outSemiBillGuid
----------------------------------------------------------------------      
          -- ReCalc UnitPrice & Total Price
UPDATE [mi]
SET [mi].[Price] = [bi].[Price]
FROM [mi000] [mi]
INNER JOIN [bi000] bi
	ON [mi].[MatGuid] = [bi].[MatGuid]
WHERE [mi].[ParentGUID] = @ManufacGUID
AND ([bi].[ParentGuid] = @OutBillGUID
OR [bi].[ParentGuid] = @outSemiBillGuid)
----------------------------------------------------------------------  
          -- ReCalc UnitPrice & Total Price
UPDATE [MN000] SET           
	[TotalPrice] = @OutTotal - (CASE @Flags 
									WHEN 1 THEN 0 
									ELSE @OutTotalExtra 
								END)        
WHERE [GUID] = @ManufacGUID        
                              
UPDATE [MN000] SET           
	[UnitPrice] = [TotalPrice] / [Qty]
WHERE [GUID] = @ManufacGUID
---------------------------------------------------------------------- 
          -- update input bi price :           
-- Exclude linked Raw Mat with Ready Mat 
DECLARE @ExcludedLinkedMatVal FLOAT
SET @ExcludedLinkedMatVal = ISNULL((SELECT
	SUM([Price] * [Qty])
FROM [mi000] mi
WHERE [ParentGUID] = @ManufacGUID
AND [mi].[Type] = 1
AND [mi].[ReadyMatGuid] <> 0x0)
, 0)
-- Exclude linked Cost with Ready Mat 
DECLARE @ExcludedLinkedCostVal FLOAT
SET @ExcludedLinkedCostVal = ISNULL((SELECT
	SUM(Extra / (CASE WHEN [CurrencyVal] <> 0 THEN [CurrencyVal] ELSE 1 END))
FROM [mx000] [mx]
WHERE [mx].[ParentGUID] = @ManufacGUID
AND [ReadyMatGuid] <> 0x0)
, 0)

UPDATE [bi000]
SET [Price] =
((@OutTotal + @SemiOutTotal - @ExcludedLinkedMatVal - @ExcludedLinkedCostVal) * ([mi].[Percentage] / 100))
    /([mi].[Qty] / (CASE [mi].[unity] 
						WHEN 2 THEN [mt].[unit2Fact] 
						WHEN 3 THEN [mt].[unit3Fact] 
						ELSE 1 
					END)
) + ISNULL(IncludedLinkedMatVal / ([mi].[Qty]/(CASE [mi].[unity] 
						WHEN 2 THEN [mt].[unit2Fact] 
						WHEN 3 THEN [mt].[unit3Fact] 
						ELSE 1 
					END)), 0) 
+ ISNULL(IncludedLinkedCostVal / ([mi].[Qty]/(CASE [mi].[unity] 
						WHEN 2 THEN [mt].[unit2Fact] 
						WHEN 3 THEN [mt].[unit3Fact] 
						ELSE 1 
					END)), 0)
FROM [bi000] AS [bi] 
INNER JOIN [mi000] AS [mi] ON [bi].[MatGUID] = [mi].[MatGUID] 
INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]           
LEFT JOIN -- Include linked Raw Mat with Ready Mat 
(SELECT
	[ReadyMatGuid],
	SUM([Price] * [Qty]) IncludedLinkedMatVal
FROM [mi000] [mi]
WHERE [mi].[ParentGUID] = @ManufacGUID
AND [mi].[ReadyMatGuid] <> 0x0
GROUP BY ReadyMatGuid) r
	ON [mi].[MatGuid] = [r].[ReadyMatGuid]
LEFT JOIN -- Include linked Cost with Ready Mat 
(SELECT
	ReadyMatGuid,
	SUM(Extra / (CASE WHEN [CurrencyVal] <> 0 THEN [CurrencyVal] ELSE 1 END)) IncludedLinkedCostVal
FROM [mx000] mx
WHERE [mx].[ParentGUID] = @ManufacGUID
AND [mx].[ReadyMatGuid] <> 0x0
GROUP BY ReadyMatGuid) r2
	ON [mi].[MatGuid] = [r2].[ReadyMatGuid]
WHERE [bi].[ParentGUID] = @InBillGUID 
	AND [mi].[ParentGUID] = @ManufacGUID
	AND mi.Type = 0
---------------------------------------------------------------------------------------            
-- update ReadyMat from input bill 
UPDATE [mi]
SET [mi].[Price] = [bi].[Price]
FROM [mi000] [mi]
INNER JOIN [bi000] bi
	ON [mi].[MatGuid] = [bi].[MatGuid]
WHERE [mi].[ParentGUID] = @ManufacGUID
AND [bi].[ParentGuid] = @InBillGUID
----------------------------------------------------------------------               
-- post bills:                     
DECLARE @bPostSemiOut[bit]       
DECLARE @bEntryOut [bit]           
DECLARE @bEntryIn [bit]        
DECLARE @bEntrySemiOut [bit],
@bpostout BIT,
@bPostIn BIT      
DECLARE @isAutoPosted [BIT]
IF (@isSemiManedMatBillReq = 1 AND @isFineToGenerateBill > 0)       
BEGIN       
	SELECT @bPostSemiOut = [bAutoPost], @bEntrySemiOut = [bAutoEntry] 
	FROM [Bt000] 
	WHERE [GUID] = @outSemiBillTypeGuid           
SELECT
	@bPostOut = [bAutoPost],
	@bEntryOut = [bAutoEntry]
FROM [Bt000]
WHERE [GUID] = @OutBillTypeGUID
SELECT
	@bPostIn = [bAutoPost],
	@bEntryIn = [bAutoEntry]
FROM [Bt000]
WHERE [GUID] = @InBillTypeGUID
END       
 SET @bEntryOut	= ( SELECT  bt.bAutoEntry 
					FROM bt000 bt 
					WHERE bt.GUId = @OutBillTypeGUID )
	
 SET @bEntryIn = ( SELECT  bt.bAutoEntry
				   FROM bt000 bt 
				   WHERE bt.GUId = @InBillTypeGUID )
----------------------------------------------------------------------------------------------------------------------------------------------------       
-- return outBillGuid and inBillGuid and.........  to the caller          
SELECT @OutBillGUID AS [OutBillGUID], @InBillGUID AS [InBillGUID], @outSemiBillGuid AS outSemiBillGuid, @bEntryOut AS bEntryOut, @bEntryIn AS bEntryIn, @bEntrySemiOut AS bEntrySemiOut
	 , @EntryOutNum AS EntryOutNum, @EntryInNum AS EntryInNum, @EntryOutSemiNum AS EntryOutSemiNum, @isSemiManedMatBillReq AS  isSemiManedMatBillReq
-----------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @isAdmin INT
SELECT @isAdmin = bAdmin FROM us000 WHERE Guid = [dbo].[fnGetCurrentUserGUID]()
SELECT
	421 AS ErrorNo
FROM bi000 Bi
WHERE @isAdmin = 0
		AND bi.ParentGuid IN( @OutBillGUID, @InBillGUID)
		AND 
		(
			[bi].[Price] * [bi].[CurrencyVal]
		) < (
		SELECT CASE( SELECT [dbo].[fnGetMinPrice]( @outSemiBillTypeGuid, [dbo].[fnGetCurrentUserGUID]()))
							WHEN 2 THEN Whole
							WHEN 4 THEN Whole
							WHEN 8 THEN Half
							WHEN 16 THEN Export
							WHEN 32 THEN Vendor 
							WHEN 64 THEN Retail 
							WHEN 128 THEN EndUser 
					   END
				FROM Mt000 
				WHERE Guid = [Bi].MatGuid
			)
-- —ÕÌ· «·›Ê« Ì— Õ”» ≈⁄œ«œ Â« ›Ì ≈‰„«ÿ «·›Ê« Ì—                
IF (@isSemiManedMatBillReq = 1 AND @bPostSemiOut = 1 AND @isFineToGenerateBill > 0)        
BEGIN       
	UPDATE [BU000] SET [IsPosted] = 1 WHERE [GUID] = @outSemiBillGuid        
END 
     
SELECT @isAutoPosted = bAutoPost FROM BT000 WHERE GUID = @InBillTypeGUID
UPDATE BU000 
SET Isposted = ISNULL(@isAutoPosted, 0)
WHERE [GUID] = @InBillGUID	
SELECT @isAutoPosted = bAutoPost FROM BT000 WHERE GUID = @OutBillTypeGUID
UPDATE BU000 
SET Isposted = ISNULL(@isAutoPosted, 0)
WHERE [GUID] = @OutBillGUID	
-- Ê·Ìœ ﬁÌÊœ ··›Ê« Ì—  
IF (@GenEntry = 1)
BEGIN
	IF (@bEntryOut = 1 OR @EntryOutNum <> 0)        
	BEGIN 
		EXEC [prcBill_GenEntry] @OutBillGUID, @EntryOutNum 
	END
	IF (@bEntryIn = 1 OR @EntryInNum <> 0)        
	BEGIN   
		EXEC [prcBill_GenEntry] @InBillGUID, @EntryInNum
	END  
	IF ((@bEntrySemiOut = 1 OR @EntryOutSemiNum <> 0) AND (@isSemiManedMatBillReq = 1)) 
	BEGIN
		EXEC [prcBill_GenEntry]	@outSemiBillGuid, @EntryOutSemiNum
	END 
END 
#########################################################
CREATE PROC PRCManuf_GetBillGuid 
	@inBillGuid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON

	SELECT CreateUserGUID, CreateDate
	FROM BU000 
	WHERE GUID = @inBillGuid
END
#########################################################
CREATE PROC prcManuf_GetEntryNumOfBill
	@ManufacGUID UNIQUEIDENTIFIER,
	@Type INT
AS
		SELECT ce.Number AS number
		FROM 
			CE000 AS ce 
			INNER JOIN ER000 AS er ON ce.GUID = er.EntryGUID 
			INNER JOIN BU000 AS bu ON bu.GUID = er.ParentGUID
			INNER JOIN MB000 AS mb ON mb.BillGUID = bu.GUID AND mb.Type = @Type
		WHERE
			mb.ManGUID = @ManufacGUID
###########################################################
CREATE PROC prcExpectedQty  
( 
      @GrpGuid UNIQUEIDENTIFIER = NULL, 
      @CostGuid UNIQUEIDENTIFIER = 0x0 , 
      @SrcTypesguid UNIQUEIDENTIFIER =  NULL, 
      @FromDate DATETIME = '1-1-1980'      , 
      @ToDate DATETIME   = '1-1-2070'       
) 
AS  
SELECT 
		 q1.matGuid AS MatGuid 
		,q1.matcode AS MatCode 
		,q1.matname AS MatName 
		,q1.matlatinname AS MatLatinName 
  	,SUM(CASE q1.billtype WHEN 2 THEN q1.Qty ELSE 0 END) AS StdOutput
	  ,SUM(CASE q1.billtype WHEN 1 THEN q1.Qty ELSE 0 END) AS ActOutput
		
FROM  
( 
     SELECT DISTINCT mt.Guid AS MatGuid 
                   , mt.Code  AS MatCODE 
                   , mt.NAME AS MatName 
				   , mt.LatinName AS MatLatinName 
				   , bi.qty AS Qty 
				   , billTypes.[type] AS billtype 
				   , mn.Guid AS Guid
              
            FROM 
			bt000 billTypes  
            INNER JOIN bu000 bu ON bu.[TypeGUID]   = billTypes.[GUID]  
            INNER JOIN bi000 bi ON bi.[ParentGUID] = bu.[GUID] 
            INNER JOIN (SELECT Guid FROM dbo.fnGetCostsList(@CostGuid)) co ON co.Guid = bu.CostGuid
            INNER JOIN (SELECT bu.costguid AS Guid FROM co000 co,bu000 bu  
						WHERE co.guid = bu.costGuid OR bu.costguid = 0x0 
						GROUP BY bu.costguid ) co1 ON co1.[GUID] = co.[Guid] 
            INNER JOIN mt000 mt                                         ON mt.[GUID]  = bi.[MatGUID] 
            INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID]  = mt.[GroupGUID] 
            INNER JOIN [RepSrcs] rs ON rs.[idType] = bu.[TypeGUID] 
			INNER JOIN mb000 mb  ON mb.[BILLGUID] = bu.[GUID]  
			INNER JOIN mn000 mn  ON mn.[GUID] = mb.[MANGUID] 
			INNER JOIN mi000 mi  ON mi.[MATGUID] = bi.[MATGUID] 
           WHERE  
				bu.[Date] >= @FromDate 
				AND bu.[Date] <= @ToDate  
				AND [rs].IdTbl = @SrcTypesguid 
				AND mi.[type] = 1 
) q1 
GROUP BY matguid, matcode, matName, matlatinName  
ORDER BY matCode
#########################################################
CREATE PROCEDURE prcGetActualQtys  
      @GrpGuid UNIQUEIDENTIFIER = 0x0, 
      @CostGuid UNIQUEIDENTIFIER = 0x0 , 
      @SrcTypesguid UNIQUEIDENTIFIER = 0x0, 
      @FromDate DATETIME = '1-1-1980'      , 
      @ToDate DATETIME   = '1-1-2070',       
	  @matGuid UNIQUEIDENTIFIER	=0x0 
AS  
SELECT  
		 q1.matGuid AS MatGuid 
		,q1.billtype 
	    , SUM(CASE q1.billtype WHEN 1 THEN q1.Qty ELSE 0 END) AS ActOutput 
FROM  
( 
      SELECT DISTINCT  mt.Guid AS MatGuid 
                   , mt.Code  AS MatCODE 
                   , mt.NAME AS MatName 
				   , mt.LatinName AS MatLatinName 
				   , bi.qty AS Qty 
				   , billTypes.[type] AS billtype 
				   , bu.Guid
              
            FROM bt000 billTypes 
            INNER JOIN bu000 bu                                         ON bu.[TypeGUID]   = billTypes.[GUID] 
            INNER JOIN bi000 bi                                         ON bi.[ParentGUID] = bu.[GUID] 
            INNER JOIN (SELECT Guid FROM dbo.fnGetCostsList(@CostGuid)) co ON co.Guid = bu.CostGuid
            INNER JOIN (SELECT bu.costguid AS Guid FROM co000 co,bu000 bu  
						WHERE co.guid = bu.costGuid OR bu.costguid = 0x0
						GROUP BY bu.costguid ) co1 ON co1.[GUID] = co.[Guid] 
            INNER JOIN mt000 mt                                         ON mt.[GUID]  = bi.[MatGUID] 
            INNER JOIN dbo.fnGetGroupsList (@GrpGuid)  gr ON gr.[GUID]  = mt.[GroupGUID] 
            INNER JOIN [RepSrcs] rs ON rs.[idType] = bu.[TypeGUID] 
           WHERE  
				bu.[Date] >= @FromDate 
				AND bu.[Date] <= @ToDate  
				AND [rs].IdTbl = @SrcTypesguid 
			 
) q1 
GROUP BY matguid, matcode, matName, matlatinName ,billtype 
HAVING matguid = @matGuid AND billtype = 1	 	
#########################################################
CREATE PROCEDURE prcGetManRawMatStatus  @ManGuid [UNIQUEIDENTIFIER]
AS
DECLARE @ManRawMatCount [INT] 
SET @ManRawMatCount = 0	
SELECT @ManRawMatCount  = 
        (
		SELECT COUNT(*) FROM     
			[mi000] AS [mi]     
			INNER JOIN [mt000] [mt] ON [mi].[MatGUID] = [mt].[GUID]    
			INNER JOIN [mn000] [mn] ON [mi].[ParentGUID] = [mn].[GUID]    
		WHERE [mi].[ParentGUID] = @ManGuid AND [mi].[type] = 1  
		AND [mt].[groupGuid] <> CAST((SELECT [VALUE] FROM op000 WHERE [NAME] = 'man_semiconductGroup')	AS UNIQUEIDENTIFIER)  
		)
SELECT @ManRawMatCount AS [ManRawMatCount]
#########################################################
CREATE PROCEDURE prcGetSemiManedMats @MatGuid [UNIQUEIDENTIFIER] = 0x0
AS 
DECLARE @b UNIQUEIDENTIFIER
SET @b = (SELECT [VALUE] FROM op000 WHERE [NAME] = 'man_semiconductGroup')
SELECT mt.Guid FROM mt000 AS mt
INNER JOIN dbo.fnGetGroupsList (@b)
            gr ON gr.[GUID]  = mt.[GroupGUID]
WHERE mt.Guid = @MatGuid
#########################################################	
CREATE function  fnGetFormMatPrice
(
    @FormGuid UNIQUEIDENTIFIER ,
	 @MatGuid UNIQUEIDENTIFIER
	
)
RETURNS FLOAT
AS
BEGIN 
DECLARE @Result FLOAT 
SELECT
      @Result =  [mi].Price 		
	FROM 
		FM000 fm INNER JOIN MN000 mn ON mn.FormGUID = fm.Guid 
				 INNER JOIN MI000 mi ON mi.ParentGuid = mn.Guid  
				 INNER JOIN mt000 mt ON mi.MatGuid = mt.Guid 			 
	 
	WHERE		
		 fm.Guid = @FormGuid
		AND 
		mi.MatGuid = @MatGuid
		AND 
		  mn.Type = 0
	
RETURN  @Result 
   END
#########################################################
#END
