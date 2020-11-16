#################################################################
CREATE PROC prcPDABilling_GenBill	
	@PDAGuid	uniqueidentifier        
AS      
	SET NOCOUNT ON   

	DECLARE	@CurrencyGUID 	uniqueidentifier,       
			@CurrencyVal	float,
			@CostGUID		uniqueidentifier,       
			@DefCashAccGUID uniqueidentifier,       
			@CustAccGUID	uniqueidentifier,       
			@BranchGUID		uniqueidentifier,
			@BranchMask		INT         
	SELECT @CurrencyGUID = [GUID], @CurrencyVal = [CurrencyVal] FROM My000 WHERE [Number] = 1        
	SELECT     
		@CostGuid		= [CostGUID],
		@DefCashAccGUID = [AccountGUID], 
		@CustAccGUID	= [CustAccGUID],
		@BranchMask		= [BranchMask]
	FROM Pl000 WHERE [GUID] = @PDAGuid
	
	SELECT @BranchGuid = ISNULL(Guid, 0x0) FROM br000 WHERE [dbo].[fnPowerOf2]([Number] - 1) = @BranchMask
	IF ISNULL(@BranchGuid, 0x00) = 0x00
		SELECT @BranchGuid = [Guid] FROM br000 Where [Number] = 1 
		
	SET @BranchGuid = ISNULL(@BranchGuid, 0x0)  
	-------------- BU ---------------------        
	SELECT TOP 0 * INTO #PalmBu000 FROM Bu000  
	        
	INSERT INTO #PalmBu000        
	(        
		[Number],         
		[Cust_Name],         
		[Date],         
		[CurrencyVal],         
		[Notes],         
		[Total],         
		[PayType],         
		[TotalDisc],         
		[TotalExtra],         
		[ItemsDisc],         
		[BonusDisc],         
		[FirstPay],         
		[Profits],         
		[IsPosted],         
		[Security],         
		[Vendor],         
		[SalesManPtr],         
		[Branch],         
		[VAT],         
		[GUID],         
		[TypeGUID],         
		[CustGUID],         
		[CurrencyGUID],         
		[StoreGUID],         
		[CustAccGUID],         
		[MatAccGUID],         
		[ItemsDiscAccGUID],         
		[BonusDiscAccGUID],         
		[FPayAccGUID],         
		[CostGUID],         
		[UserGUID],         
		[CheckTypeGUID],         
		[TextFld1],         
		[TextFld2],         
		[TextFld3],         
		[TextFld4],         
		[RecState],        
		[ItemsExtra],        
		[ItemsExtraAccGUID],    
		[CostAccGUID],    
		[StockAccGUID],    
		[VATAccGUID],    
		[BonusAccGUID],    
		[BonusContraAccGUID],  
		[IsPrinted],
		[IsGeneratedByPocket],
		[TotalDiscountPercent],
        	[TotalExtraPercent]    
	)        
	SELECT        
		dbo.fnDistGetNewBillNum([TypeGUID]) + pbu.Number - 1	AS Number,        
		[cu].[CustomerName]		AS Cust_Name,   
		[Date]				AS Date,        
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyVal	ELSE pbu.CurVal END	AS CurrencyVal,  -- @CurrencyVal AS CurrencyVal	        
		CAST( ISNULL([pbu].[Notes], '')			AS NVARCHAR(255)),        
		[pbu].[Total]			AS Total,        
		[pbu].[PayType]			AS PayType,        
		[pbu].[TotalDisc]		AS TotalDisc,        
		[pbu].[TotalExtra]		AS TotalExtra,        
		[pbu].[TotalItemDisc]	AS ItemDisc,        
		0					AS BonusDisc,        
		[FirstPay]			AS FirstPay,        
		0					AS Profits,        
		0					AS IsPosted,        
		1					AS Security,        
		0					AS Vindor,        
		0					AS SalesManPtr,        
		@BranchGUID			AS Branch, -- 0x0					AS Branch,        
		pbu.VAT,						--0	AS Vat,        
		[pbu].[GUID]		AS GUID,        
		[pbu].[TypeGUID]	AS TypeGUID,        
		[pbu].[CustomerGUID]AS CustGUID,        
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyGUID ELSE (Select TOP 1 Guid From my000 WHERE Number = pbu.CurNumber) END AS CurrencyGuid,  -- @CurrencyGUID		AS CurrencyGUID,        
		[pbu].[StoreGUID]		AS StoreGUID,   
		case [pbu].[PayType] when 1 then (SELECT TOP 1 [AccountGUID] FROM CU000 WHERE [GUID] = [pbu].[CustomerGUID]) when 0 then @DefCashAccGUID end AS CustAccGUID,        
		0x0 AS MatAccGUID,  
		(SELECT TOP 1 [DefDiscAccGUID] FROM Bt000 WHERE [GUID] = TypeGUID)	AS ItemDiscAccGUID,        
		(SELECT TOP 1 [DefDiscAccGUID] FROM Bt000 WHERE [GUID] = TypeGUID)	AS BonusDiscAccGUID,        
		@DefCashAccGUID		AS DefCashAccGUID,       
		@CostGUID			AS CostGUID,   
		0x0					AS UserGUID,        
		0x0					AS CheckTypeGUID,        
		''					AS TextFld1,		        
		''					AS TextFld2,        
		''					AS TextFld3,        
		''					AS TextFld4,        
		0					AS RecState,        
		0					AS ItemsExtra,        
		0x0					AS ItemsExtraAccGUID,    
		0x0,    
		0x0,    
		0x0,    
		0x0,    
		0x0,  
		0,
		1,
		0,
		0    
	FROM        
		DistDeviceBu000 AS [pbu]        
		INNER JOIN Cu000 AS [cu] ON [cu].[GUID] = [pbu].[CustomerGUID]      
	WHERE        
		[pbu].[DistributorGUID] = @PDAGuid AND   
		[pbu].[Deleted] = 0 AND 
		pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet  

	CREATE TABLE #BillNum ([TypeGUID] uniqueidentifier, [NewNum] float)  
	INSERT INTO #BillNum SELECT [p].[TypeGUID], ISNULL(Max([bu].[Number]), 0) FROM BU000 AS bu RIGHT JOIN #PalmBu000 AS p ON [p].[TypeGUID] = [bu].[TypeGUID] GROUP BY [p].[TypeGUID]  
-- SELECT * FROM #PalmBu000  
-- SELECT * FROM #BillNum  
	DECLARE	@cGUID		uniqueidentifier,  
			@cTypeGUID	uniqueidentifier,  
			@cNewNum	float  
	DECLARE c CURSOR FOR SELECT [GUID], [TypeGUID] FROM #PalmBu000 ORDER BY [Number]  
	OPEN c  
		FETCH NEXT FROM c INTO @cGUID , @cTypeGUID  
		WHILE @@FETCH_STATUS = 0  
		BEGIN  
			UPDATE #BillNum SET [NewNum] = [NewNum] + 1 WHERE [TypeGUID] = @cTypeGUID  
			SELECT @cNewNum = [NewNum] FROM #BillNum WHERE [TypeGUID] = @cTypeGUID  
			-- PRINT @cNewNum  
			UPDATE #PalmBu000 SET [Number] = @cNewNum WHERE [GUID] = @cGUID  
			FETCH NEXT FROM c INTO @cGUID , @cTypeGUID  
		END  
	CLOSE c  
	DEALLOCATE c  
	DROP TABLE #BillNum  
	-------------- BI ---------------------        
	SELECT TOP 0 * INTO #PalmBi000 FROM Bi000        
	        
	INSERT INTO #PalmBi000        
	(        
		[Number],         
		[Qty],         
		[Order],         
		[OrderQnt],         
		[Unity],         
		[Price],         
		[BonusQnt],         
		[Discount],         
		[BonusDisc],         
		[Extra],         
		[CurrencyVal],         
		[Notes],         
		[Profits],         
		[Num1],         
		[Num2],         
		[Qty2],         
		[Qty3],         
		[ClassPtr],         
		[ExpireDate],         
		[ProductionDate],         
		[Length],         
		[Width],         
		[Height],         
		[GUID],         
		[VAT],         
		[VATRatio],         
		[ParentGUID],         
		[MatGUID],         
		[CurrencyGUID],         
		[StoreGUID],         
		[CostGUID],         
		[SOType],         
		[SOGuid],
		[Count],
		[SOGroup],
		[TotalDiscountPercent],
        	[TotalExtraPercent]        
	)        
	SELECT        
		[pbi].[Number],				 
		[pbi].[Qty],				 
		0,						 
		0,						 
		[pbi].[Unity],				 
		[pbi].[Price],				 
		[pbi].[BonusQty],			 
		[pbi].[Discount],			 
		0,						 
		0,						 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyVal	ELSE pbu.CurVal END	AS CurrencyVal,  -- @CurrencyVal AS CurrencyVal	        
		'',						 
		0,						 
		0,						 
		0,						 
		0,						 
		0,						 
		'', -- 0,						 
		'1-1-1980',				 
		'1-1-1980',				 
		0,						 
		0,						 
		0,						 
		[pbi].[GUID],				 
		[pbi].[Vat],	--0,	VAT						 
		[mt].[VAT],		--0,	VATRatio 
		[ParentGUID],				 
		[MatGUID],				 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyGUID ELSE (Select TOP 1 Guid From my000 WHERE Number = pbu.CurNumber) END AS CurrencyGuid,  -- @CurrencyGUID		AS CurrencyGUID,        
		[pbu].[StoreGUID], 		 
		@CostGUID,			 
		0,					 
		0x0,
		0,
		0,
		0,
		0
	FROM        
		DistDeviceBi000 AS [pbi]   
		INNER JOIN DistDeviceBu000 AS [pbu] ON [pbu].[GUID] = [pbi].[ParentGUID]   
		INNER JOIN mt000 AS [mt] ON [mt].[Guid] = [pbi].[MatGuid]
	WHERE   
		[pbu].[DistributorGUID] = @PDAGuid AND   
		[pbu].[Deleted] = 0   AND 
		pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet 
	-------------- DI ---------------------        
	SELECT TOP 0 * INTO #PalmDi000 FROM Di000        
	-- Add Discounts  
	INSERT INTO #PalmDi000         
	(         
		[Number],          
		[Discount],          
		[Extra],          
		[CurrencyVal],          
		[Notes],          
		[Flag],          
		[GUID],          
		[ClassPtr],          
		[ParentGUID],          
		[AccountGUID],          
		[CurrencyGUID],          
		[CostGUID],          
		[ContraAccGUID]         
	)         
	SELECT	         
		0,			 
		[pbu].[TotalDisc] - [pbu].[TotalItemDisc],		 
		0,					 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyVal	ELSE pbu.CurVal END	AS CurrencyVal,  -- @CurrencyVal AS CurrencyVal	        
		'Õ”„Ì« ',			 
		0,					 
		newId(),		 
		'', -- 0,					 
		pbu.GUID,			 
		bt.DefDiscAccGuid,	 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyGUID ELSE (Select TOP 1 Guid From my000 WHERE Number = pbu.CurNumber) END AS CurrencyGuid,  -- @CurrencyGUID		AS CurrencyGUID,        
		@CostGUID,			 
		0x0					 
	FROM         
		DistDeviceBu000 AS pbu   
		INNER JOIN bt000 AS bt On pbu.TypeGuid = bt.Guid  
	WHERE   
		[pbu].[DistributorGUID] = @PDAGuid AND   
		[pbu].[Deleted] = 0 		AND  
		[pbu].[TotalDisc] - [pbu].[TotalItemDisc] <> 0  AND 
		pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet 
	-- Add Extra  
	INSERT INTO #PalmDi000         
	(         
		[Number],          
		[Discount],          
		[Extra],          
		[CurrencyVal],          
		[Notes],          
		[Flag],          
		[GUID],          
		[ClassPtr],          
		[ParentGUID],          
		[AccountGUID],          
		[CurrencyGUID],          
		[CostGUID],          
		[ContraAccGUID]         
	)         
	SELECT	         
		0,			 
		0,					 
		pbu.[TotalExtra],		 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyVal	ELSE pbu.CurVal END	AS CurrencyVal,  -- @CurrencyVal AS CurrencyVal	        
		'≈÷«›« ',			 
		0,					 
		newId(),		 
		'', -- 0,					 
		[pbu].[GUID],			 
		[bt].[DefExtraAccGuid],	 
		CASE ISNULL(pbu.CurNumber, 0) WHEN 0 THEN @CurrencyGUID ELSE (Select TOP 1 Guid From my000 WHERE Number = pbu.CurNumber) END AS CurrencyGuid,  -- @CurrencyGUID		AS CurrencyGUID,        
		@CostGUID,			 
		0x0					 
	FROM         
		DistDeviceBu000 AS [pbu]   
		INNER JOIN bt000 AS [bt] On [pbu].[TypeGuid] = [bt].[Guid]  
	WHERE   
		[pbu].[DistributorGUID] = @PDAGuid AND   
		[pbu].[Deleted] = 0 		AND  
		[pbu].[TotalExtra] <> 0  AND 
		pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet 
	-------------- INSERT BILLS ---------------------        
	INSERT INTO BU000    
	(    
		Number,         
		Cust_Name,         
		Date,         
		CurrencyVal,         
		Notes,         
		Total,         
		PayType,         
		TotalDisc,         
		TotalExtra,         
		ItemsDisc,         
		BonusDisc,         
		FirstPay,         
		Profits,         
		IsPosted,         
		Security,         
		Vendor,         
		SalesManPtr,         
		Branch,         
		VAT,         
		GUID,         
		TypeGUID,         
		CustGUID,         
		CurrencyGUID,         
		StoreGUID,         
		CustAccGUID,         
		MatAccGUID,         
		ItemsDiscAccGUID,         
		BonusDiscAccGUID,         
		FPayAccGUID,         
		CostGUID,         
		UserGUID,         
		CheckTypeGUID,         
		TextFld1,         
		TextFld2,         
		TextFld3,         
		TextFld4,         
		RecState,        
		ItemsExtra,        
		ItemsExtraAccGUID,    
		[CostAccGUID],    
		[StockAccGUID],    
		[VATAccGUID],    
		[BonusAccGUID],    
		[BonusContraAccGUID],  
		[IsPrinted], 
		[IsGeneratedByPocket]      
	)    
 	SELECT    
		Number,         
		Cust_Name,         
		Date,         
		CurrencyVal,         
		Notes,         
		Total,         
		PayType,         
		TotalDisc,         
		TotalExtra,         
		ItemsDisc,         
		BonusDisc,         
		FirstPay,         
		Profits,         
		IsPosted,         
		Security,         
		Vendor,         
		SalesManPtr,         
		Branch,         
		VAT,         
		GUID,         
		TypeGUID,         
		CustGUID,         
		CurrencyGUID,         
		StoreGUID,         
		CustAccGUID,         
		MatAccGUID,         
		ItemsDiscAccGUID,         
		BonusDiscAccGUID,         
		FPayAccGUID,         
		CostGUID,         
		UserGUID,         
		CheckTypeGUID,         
		TextFld1,         
		TextFld2,         
		TextFld3,         
		TextFld4,         
		RecState,        
		ItemsExtra,        
		ItemsExtraAccGUID,    
		[CostAccGUID],    
		[StockAccGUID],    
		[VATAccGUID],    
		[BonusAccGUID],    
		[BonusContraAccGUID],  
		[IsPrinted], 
		[IsGeneratedByPocket]      
	FROM #PalmBu000     
	INSERT INTO Bi000     
	(    
		Number,         
		Qty,         
		[Order],         
		OrderQnt,         
		Unity,         
		Price,         
		BonusQnt,         
		Discount,         
		BonusDisc,         
		Extra,         
		CurrencyVal,         
		Notes,         
		Profits,         
		Num1,         
		Num2,         
		Qty2,         
		Qty3,         
		ClassPtr,         
		[ExpireDate],         
		ProductionDate,         
		Length,         
		Width,         
		Height,         
		GUID,         
		VAT,         
		VATRatio,         
		ParentGUID,         
		MatGUID,         
		CurrencyGUID,         
		StoreGUID,         
		CostGUID,         
		SOType,         
		SOGuid,
		[Count],
		SoGroup  
	)    
	SELECT    
		Number,         
		Qty,         
		[Order],         
		OrderQnt,         
		Unity,         
		Price,         
		BonusQnt,         
		Discount,         
		BonusDisc,         
		Extra,         
		CurrencyVal,         
		Notes,         
		Profits,         
		Num1,         
		Num2,         
		Qty2,         
		Qty3,         
		ClassPtr,         
		[ExpireDate],         
		ProductionDate,         
		Length,         
		Width,         
		Height,         
		GUID,         
		VAT,         
		VATRatio,         
		ParentGUID,         
		MatGUID,         
		CurrencyGUID,         
		StoreGUID,         
		CostGUID,         
		SOType,         
		SOGuid,
		[Count],
		SOGroup        
	FROM #PalmBi000     
	INSERT INTO Di000   
	(   
		Number, Discount, Extra, CurrencyVal, Notes, Flag, GUID, ClassPtr, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID   
	)   
	SELECT   
		Number, Discount, Extra, CurrencyVal, Notes, Flag, GUID, ClassPtr, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID   
	FROM #PalmDi000   
	------------- SN --------------------------------  
	--- Add New SN To SNC000
	INSERT INTO Snc000( SN, MAtGUID, Qty)	
	SELECT DISTINCT
		-- newId(),
		sn.sn,
		bi.MatGuid,
		1
	FROM  
		DistDeviceSN000 AS sn 
		INNER JOIN DistDeviceBi000 AS bi ON bi.Guid = sn.OutGuid OR bi.Guid = sn.InGuid 
		LEFT JOIN Snc000 AS snc ON snc.Sn = sn.sn
	WHERE  
		sn.DistributorGuid = @PDAGuid AND
		snc.Guid IS NULL
		
	--- Update SNT000
	INSERT INTO snt000( item, biGuid, stGuid, ParentGuid, Notes, buGuid) 
	SELECT DISTINCT
		-- newId(),
		sn.item,
		bi.Guid,
		sn.Notes,
		snc.Guid, -- sn.Guid,
		'',
		bi.ParentGuid
	FROM 
		DistDeviceSN000 AS sn
		INNER JOIN DistDeviceBi000 AS bi ON bi.Guid = sn.OutGuid OR bi.Guid = sn.InGuid
		INNER JOIN Snc000 AS snc ON snc.Sn = sn.sn -- snc.Guid = sn.Guid
	WHERE 
		sn.DistributorGuid = @PDAGuid
	
	--------------- TS ---------------------------------------  
	INSERT INTO TS000  
		(  
			Guid,  
			OutBillGuid,  
			InBillGuid			  
		)  
	SELECT  
		Guid,  
		OutBillGuid,  
		InBillGuid  
	FROM   
		DistDeviceTs000   
	WHERE   
		DistributorGuid = @PDAGuid
	  
	DROP TABLE #PalmBu000        
	DROP TABLE #PalmBi000       
	DROP TABLE #PalmDi000       
	  
	DELETE DistDeviceBi000 WHERE ParentGUID IN (SELECT GUID FROM DistDeviceBu000 WHERE DistributorGUID = @PDAGuid)
	DELETE DistDeviceBu000 WHERE DistributorGUID = @PDAGuid 
	DELETE DistDeviceTs000 WHERE DistributorGUID = @PDAGuid 
	-- DELETE DistDeviceSN000 WHERE DistributorGUID = @PDAGuid
	
/* 
Exec prcPDABilling_GenBill	'BE799ADD-6C32-4F01-A94D-0C43DEF1828E'

Select * from Pl000
*/ 
#################################################################
#END