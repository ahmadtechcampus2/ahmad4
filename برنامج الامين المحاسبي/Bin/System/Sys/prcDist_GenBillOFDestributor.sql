#####################################################
CREATE PROC prcDist_GenBillOFDestributor
	@DistributorGUID	uniqueidentifier    
AS     
			SET NOCOUNT ON   

		DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
		
		DECLARE --@CurrencyGUID 	UNIQUEIDENTIFIER,  
				--@CurrencyVal	FLOAT,  
				@CostGUID		UNIQUEIDENTIFIER,        
				@SalesManGUID	UNIQUEIDENTIFIER,        
				@DefCashAccGUID UNIQUEIDENTIFIER,        
				@CustAccGUID	UNIQUEIDENTIFIER,        
				@StoreGUID		UNIQUEIDENTIFIER,        
				@BranchGUID		UNIQUEIDENTIFIER,        
				@BranchMask		INT ,  
				@DistCode		NVARCHAR(100)  
		--SELECT @CurrencyGUID = GUID, @CurrencyVal = CurrencyVal FROM My000 WHERE Number = 1         
		SELECT         
			@SalesManGUID = PrimSalesManGUID,        
			@CustAccGUID = CustAccGUID,        
			@BranchMask  = BranchMask,   
			@StoreGuid = StoreGuid,  
			@DistCode = Code,
			@BranchGuid = ISNULL(UploadBranch,0x0)
		FROM         
			Distributor000 WHERE GUID = @DistributorGUID        
			        
		SELECT 
			@BranchGuid = ISNULL(Guid, 0x0) 
			FROM br000 
		WHERE 
			[dbo].[fnPowerOf2]([Number] - 1) = @BranchMask
		
		IF (@BranchGuid IS NULL)
			SET @BranchGuid = 0x0
			
		SELECT @CostGUID = CostGUID, @DefCashAccGUID = AccGUID FROM DistSalesMan000 WHERE GUID = @SalesManGUID        
		--------------------------------------- 
		DECLARE @StopDate			DATETIME ,
				@BillStopDate		DATETIME ,
				@ISBillStopDate		INT, 
				@OrderStopDate		DATETIME ,
				@ISOrderStopDate	INT ,
				@EPDate				DATETIME

		SELECT @StopDate		= dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_StopDate' 
		SELECT @BillStopDate	= dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_BillStopDate' 
		SELECT @ISBillStopDate	= CAST(Value AS INT) FROM op000 WHERE Name = 'AmnCfg_IsBillStoped'  
		SELECT @OrderStopDate	= dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_OrderStopDate' 
		SELECT @ISOrderStopDate = CAST(Value AS INT) FROM op000 WHERE Name = 'AmnCfg_IsOrderStoped'  
		SELECT @EPDate			= dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_EPDate'  

		IF EXISTS(SELECT * FROM DistDeviceBu000 
				  WHERE Date < @StopDate 
					AND Date < @EPDate 
					AND DistributorGUID = @DistributorGUID)
		BEGIN
			RAISERROR(N'AmnE004 : Fixed Date Of Operations OR End Date Of Period > Date of Bills', 16, 1)
			RETURN
		END

		--  «—ÌŒ  À»Ì  «·ÿ·»Ì« 		
		IF (EXISTS (SELECT  * FROM DistDeviceBu000 bu INNER JOIN bt000  bt ON bt.GUID = bu.TypeGUID
					WHERE 
						(DistributorGUID = @DistributorGUID AND bt.Type = 5 OR bt.Type = 6) AND bu.Date < @OrderStopDate 
					AND ((bu.Date < bt.StopDate AND bt.IsStopDate = 1) OR bt.IsStopDate = 0))
					AND @ISOrderStopDate = 1)
		BEGIN
			RAISERROR(N'AmnE003 : Fixed Date Of Orders > Date of order', 16, 1)
			RETURN
		END

		--  «—ÌŒ  À»Ì  «·›Ê« Ì—
		IF (EXISTS (SELECT * FROM DistDeviceBu000 bu INNER JOIN bt000  bt ON bt.GUID = bu.TypeGUID
					WHERE 
						(DistributorGUID = @DistributorGUID AND bt.Type <> 5 OR bt.Type <> 6) AND bu.Date < @BillStopDate
					AND ((bu.Date < bt.StopDate AND bt.IsStopDate = 1) OR bt.IsStopDate = 0)) 
					AND @ISBillStopDate = 1)
		BEGIN
			RAISERROR(N'AmnE002 : Fixed Date Of Bills > Date of Bills', 16, 1) 
			RETURN
		END 
		-------------- BU ---------------------         
		CREATE TABLE #PalmBu000(
			[Number] [int],
			[Cust_Name] [nvarchar](250),
			[Date] [datetime],
			[Notes] [nvarchar](1000),
			[Total] [float],
			[PayType] [int],
			[TotalDisc] [float],
			[TotalExtra] [float],
			[ItemsDisc] [float],
			[BonusDisc] [float],
			[FirstPay] [float],
			[Profits] [float],
			[IsPosted] [int],
			[Security] [int],
			[Vendor] [bigint],
			[SalesManPtr] [bigint],
			[Branch] [uniqueidentifier],
			[VAT] [float],
			[GUID] [uniqueidentifier],
			[TypeGUID] [uniqueidentifier],
			[CustGUID] [uniqueidentifier],
			[StoreGUID] [uniqueidentifier],
			[CustAccGUID] [uniqueidentifier],
			[MatAccGUID] [uniqueidentifier],
			[ItemsDiscAccGUID] [uniqueidentifier],
			[BonusDiscAccGUID] [uniqueidentifier],
			[FPayAccGUID] [uniqueidentifier],
			[CostGUID] [uniqueidentifier],
			[UserGUID] [uniqueidentifier],
			[CheckTypeGUID] [uniqueidentifier],
			[TextFld1] [nvarchar](100),
			[TextFld2] [nvarchar](100),
			[TextFld3] [nvarchar](100),
			[TextFld4] [nvarchar](100),
			[RecState] [int],
			[ItemsExtra] [float],
			[ItemsExtraAccGUID] [uniqueidentifier],
			[CostAccGUID] [uniqueidentifier],
			[StockAccGUID] [uniqueidentifier],
			[VATAccGUID] [uniqueidentifier],
			[BonusAccGUID] [uniqueidentifier],
			[BonusContraAccGUID] [uniqueidentifier],
			[IsPrinted] [bit],
			[IsGeneratedByPocket] [bit],
			[TotalSalesTax] [float],
			[TotalExciseTax] [float],
			[RefundedBillGUID] [uniqueidentifier],
			[IsTaxPayedByAgent] [float],
			[LCGUID] [uniqueidentifier],
			[LCType] [int],
			[ReversChargeReturn] [uniqueidentifier],
			[ReturendBillNumber] [int],
			[ReturendBillDate] [datetime],
			[CustomerAddressGUID] [uniqueidentifier],
			[CurrencyGUID] [uniqueidentifier],
			[CurrencyValue] [float]
		)    
		 
		INSERT INTO #PalmBu000         
		(         
			Number,          
			Cust_Name,          
			Date,          
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
			[IsGeneratedByPocket],
			[TotalSalesTax],
			TotalExciseTax,
			RefundedBillGuid,
			IsTaxPayedByAgent,
			LCGUID,
			LCType,
			ReversChargeReturn,
			ReturendBillNumber,
			ReturendBillDate,
			CustomerAddressGUID,
			[CurrencyGUID],
			[CurrencyValue]
		)
		SELECT         
			dbo.fnDistGetNewBillNum(TypeGUID) + pbu.Number - 1	AS Number,         
			ISNULL(cu.CustomerName, '')		AS Cust_Name,    
			-- [Date]							AS [Date],        
			-- Test StopDate 
			 [Date], 
			-- CAST(ISNULL(pbu.Notes, '') + ' - Bill:'+ CAST(pbu.Number AS NVARCHAR(10))	AS NVARCHAR(255)),         
			CAST( '#' + @DistCode + '-' + CAST(pbu.Number AS NVARCHAR(10)) + '# ' + ISNULL(pbu.Notes, '') AS NVARCHAR(255)), 
			pbu.Total			AS Total,         
			pbu.PayType			AS PayType,         
			pbu.TotalDisc		AS TotalDisc,         
			pbu.TotalExtra		AS TotalExtra,         
			pbu.TotalItemDisc	AS ItemDisc,         
			0					AS BonusDisc,         
			(CASE PayType WHEN 0 THEN 0 ELSE FirstPay END) AS FirstPay,    
			0					AS Profits,         
			0					AS IsPosted,         
			1					AS Security,         
			0					AS Vindor,         
			0					AS SalesManPtr,         
			@BranchGUID			AS Branch,   
			pbu.VAT				AS Vat,         
			pbu.GUID			AS GUID,         
			pbu.TypeGUID		AS TypeGUID,         
			pbu.CustomerGUID	AS CustGUID,         
			pbu.StoreGUID		AS StoreGUID,    
			CASE pbu.PayType 
				WHEN 0 THEN @DefCashAccGUID 
				ELSE (SELECT TOP 1 AccountGUID FROM CU000 WHERE GUID = pbu.CustomerGUID) 			
			END AS CustAccGUID,         
			0x0		AS MatAccGUID,   
			0x0		AS ItemDiscAccGUID,		-- Set Acc From Mat Accounts -- (SELECT TOP 1 DefDiscAccGUID FROM Bt000 WHERE GUID = TypeGUID)	AS ItemDiscAccGUID,         
			0x0		AS BonusDiscAccGUID,	-- Set AccFrom Mat Accounts --(SELECT TOP 1 DefDiscAccGUID FROM Bt000 WHERE GUID = TypeGUID)	AS BonusDiscAccGUID,         
			(CASE PayType WHEN 0 THEN 0x0 ELSE @DefCashAccGUID END),  -- @DefCashAccGUID		AS DefCashAccGUID,        
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
			1, -- [IsGeneratedByPocket] 
			0,
			0,
			0x0,
			0,
			0x0,
			0,
			0x0,
			0,
			'1-1-1980',
			CustomerAddressGUID,
			[pbu].[CurrencyGUID],
			[pbu].[CurrencyValue]
		FROM         
			DistDeviceBu000 AS pbu         
			LEFT JOIN Cu000 AS cu ON cu.GUID = pbu.CustomerGUID       
		WHERE         
			pbu.DistributorGUID = @DistributorGUID AND    
			pbu.Deleted = 0 AND  
			pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet  
		CREATE TABLE #BillNum (TypeGUID uniqueidentifier, NewNum float)   
		INSERT INTO #BillNum   
			SELECT p.TypeGUID, ISNULL(Max(bu.Number), 0)   
			FROM #PalmBu000 AS p   
			LEFT JOIN BU000 AS bu ON p.TypeGUID = bu.TypeGUID AND bu.Branch = @BranchGuid  
			GROUP BY p.TypeGUID   
		  
		DECLARE @cGUID uniqueidentifier   
		DECLARE @cTypeGUID uniqueidentifier   
		DECLARE @cNewNum float   
		DECLARE c CURSOR FOR SELECT GUID, TypeGUID FROM #PalmBu000 ORDER BY Number   
		OPEN c   
			FETCH NEXT FROM c INTO @cGUID , @cTypeGUID   
			WHILE @@FETCH_STATUS = 0   
			BEGIN   
				UPDATE #BillNum SET NewNum = NewNum + 1 WHERE TypeGUID = @cTypeGUID   
				SELECT @cNewNum = NewNum FROM #BillNum WHERE TypeGUID = @cTypeGUID   
				-- PRINT @cNewNum   
				UPDATE #PalmBu000 SET Number = @cNewNum WHERE GUID = @cGUID   
				FETCH NEXT FROM c INTO @cGUID , @cTypeGUID   
			END   
		CLOSE c   
		DEALLOCATE c
		DROP TABLE #BillNum  	
		
		-------------- BI ---------------------         
		CREATE TABLE #PalmBi000(
			[Number] [int],
			[Qty] [float],
			[Order] [float],
			[OrderQnt] [float],
			[Unity] [float],
			[Price] [float],
			[BonusQnt] [float],
			[Discount] [float],
			[BonusDisc] [float],
			[Extra] [float],
			[Notes] [nvarchar](1000),
			[Profits] [float],
			[Num1] [float],
			[Num2] [float],
			[Qty2] [float],
			[Qty3] [float],
			[ClassPtr] [nvarchar](250),
			[ExpireDate] [datetime],
			[ProductionDate] [datetime],
			[Length] [float],
			[Width] [float],
			[Height] [float],
			[GUID] [uniqueidentifier],
			[VAT] [float],
			[VATRatio] [float],
			[ParentGUID] [uniqueidentifier],
			[MatGUID] [uniqueidentifier],
			[StoreGUID] [uniqueidentifier],
			[CostGUID] [uniqueidentifier],
			[SOType] [int],
			[SOGuid] [uniqueidentifier],
			[Count] [float],
			[SOGroup] [int],
			[TotalDiscountPercent] [float],
			[TotalExtraPercent] [float],
			[MatCurVal] [float],
			[TaxCode] [int],
			[ExciseTaxVal] [float],
			[PurchaseVal] [float],
			[ReversChargeVal] [float],
			[ExciseTaxPercent] [float],
			[ExciseTaxCode] [int],
			[LCDisc] [float],
			[LCExtra] [float],
			[CurrencyGUID] [uniqueidentifier],
			[CurrencyValue] [float]
		)        
		         
		INSERT INTO #PalmBi000         
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
			StoreGUID,          
			CostGUID,          
			SOType,          
			SOGuid,  
			[Count],  
			SOGroup,
			[TotalDiscountPercent],
			[TotalExtraPercent],
			[MatCurVal],
			TaxCode,
			ExciseTaxVal,
			PurchaseVal,
			ReversChargeVal,
			ExciseTaxPercent,
			ExciseTaxCode,
			LCDisc,
			LCExtra,
			CurrencyGUID,
			CurrencyValue
		)         
		SELECT         
			pbi.Number,				  
			pbi.Qty,				  
			0,						  
			0,						  
			pbi.Unity,				  
			pbi.Price,				  
			pbi.BonusQty,			  
			pbi.Discount,			  
			0,						  
			0,						  
			pbi.Notes, 				  
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
			pbi.GUID,				  
			pbi.VAT,						  
			pbi.VATRatio,						  
			ParentGUID,				  
			pbi.MatGUID,				  
			pbu.StoreGUID, 		  
			@CostGUID,			  
			0,			-- ISNULL(pbi.ProType, 0),  
			0x00,		-- (SELECT TOP 1 ProGuid From DistDevicePro000 AS pro WHERE pro.ProNumber = pbi.ProNumber AND pro.DistributorGuid = @DistributorGUID), -- ISNULL(pro.ProGuid, 0x0),	-- SOGuid				  
			0,  
			0,
			pbi.TotalDiscountPercent,
			pbi.TotalExtraPercent,
			0,
			CASE @IsGCCEnabled WHEN 0 THEN 0 ELSE (SELECT dbo.fnGCCGetBillItemTaxCode(gccmat.taxcode, gcccust.taxcode, pbu.TypeGuid, 0, 1, 0, 0)) END,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			[pbi].[CurrencyGUID],
			[pbi].[CurrencyValue]
		FROM         
			DistDeviceBi000 AS pbi    
			INNER JOIN DistDeviceBu000 AS pbu ON pbu.GUID = pbi.ParentGUID    
			LEFT JOIN GccMaterialTax000 gccmat on gccmat.matguid = pbi.matguid and gccmat.TaxType = 1
			LEFT JOIN GCCCustomerTax000 gcccust on gcccust.custguid = pbu.CustomerGUID and gcccust.TaxType = 1
		WHERE    
			pbu.DistributorGUID = @DistributorGUID AND   
			pbu.Deleted = 0  AND  
			pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet  
		---------------«· √ﬂœ „‰ Ê’· «·€Ìœ »ﬁÌ„… ’ÕÌÕ…---------------
		IF EXISTS(SELECT MatGUID FROM #PalmBi000 WHERE MatGUID = 0x0)
		BEGIN
			RAISERROR ('MatGUID is empty', 16, 1)
			RETURN
		END
		-------------- DI ---------------------         
		CREATE TABLE #PalmDi000(
			[Number] [int],
			[Discount] [float],
			[Extra] [float],
			[CurrencyValue] [float],
			[Notes] [nvarchar](250),
			[Flag] [int],
			[GUID] [uniqueidentifier],
			[ClassPtr] [nvarchar](250),
			[ParentGUID] [uniqueidentifier],
			[AccountGUID] [uniqueidentifier],
			[CurrencyGUID] [uniqueidentifier],
			[CostGUID] [uniqueidentifier],
			[ContraAccGUID] [uniqueidentifier],
			[IsGeneratedByPayTerms] [bit]
		)       
		-- Add Discounts   
		INSERT INTO #PalmDi000          
		(          
			Number,           
			Discount,           
			Extra,           
			CurrencyValue,           
			Notes,           
			Flag,           
			GUID,           
			ClassPtr,           
			ParentGUID,           
			AccountGUID,           
			CurrencyGUID,           
			CostGUID,           
			ContraAccGUID,
			IsGeneratedByPayTerms
		)          
		SELECT	          
			pdi.Number,			  
			pdi.Value,			  
			0,					  
			pbu.CurrencyValue,		  
			ISNULL(pdi.Notes, ''),			   
			0,					  
			pdi.GUID,			  
			'', -- 0,					  
			pbu.GUID,			  
			Disc.AccountGUID,	  
			pbu.CurrencyGUID,	  
			@CostGUID,			  
			0x0,
			0					      
		FROM          
			DistDeviceDi000 AS pdi    
			INNER JOIN DistDeviceBu000 AS pbu ON pbu.GUID = pdi.ParentGUID    
			INNER JOIN DistDisc000 AS Disc ON Disc.GUID = pdi.DiscountGUID    
		WHERE    
			pbu.DistributorGUID = @DistributorGUID AND    
			pbu.Deleted = 0  AND  
			pbu.IsSync = 0		-- IsSync = 1 For Bills Sended To Internet  
		-- Extra Updates   
		UPDATE #PalmDI000 SET Extra = -1 * Discount, Discount = 0 WHERE Discount < 0    
		-- Add Extra   
		INSERT INTO #PalmDi000          
		(          
			Number,           
			Discount,           
			Extra,           
			CurrencyValue,           
			Notes,           
			Flag,           
			GUID,           
			ClassPtr,           
			ParentGUID,           
			AccountGUID,           
			CurrencyGUID,           
			CostGUID,           
			ContraAccGUID,
			IsGeneratedByPayTerms          
		)          
		SELECT	          
			0,			  
			0,					  
			pbu.TotalExtra,		  
			pbu.CurrencyValue,	  
			'≈÷«›« ',			  
			0,					  
			newId(),		  
			'', -- 0,					  
			pbu.GUID,			  
			bt.DefExtraAccGuid,	  
			pbu.CurrencyGUID,		  
			@CostGUID,			  
			0x0,
			0					  
		FROM          
			DistDeviceBu000 AS pbu    
			INNER JOIN bt000 AS bt On pbu.TypeGuid = bt.Guid   
		WHERE    
			pbu.DistributorGUID = @DistributorGUID AND    
			pbu.Deleted = 0 		AND   
			pbu.TotalExtra <> 0		AND  
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
			[IsGeneratedByPocket],
			[TotalSalesTax],
			[CustomerAddressGUID]
		)     
 		SELECT     
			bu.Number,          
			bu.Cust_Name,          
			bu.Date,          
			bu.CurrencyValue,          
			bu.Notes,          
			bu.Total,          
			bu.PayType,          
			bu.TotalDisc,          
			bu.TotalExtra,          
			bu.ItemsDisc,          
			bu.BonusDisc,          
			bu.FirstPay,          
			bu.Profits,          
			bu.IsPosted,          
			bu.Security,          
			bu.Vendor,          
			bu.SalesManPtr,          
			bu.Branch,          
			bu.VAT,          
			bu.GUID,          
			bu.TypeGUID,          
			bu.CustGUID,          
			bu.CurrencyGUID,          
			bu.StoreGUID,          
			bu.CustAccGUID,          
			bu.MatAccGUID,          
			bu.ItemsDiscAccGUID,          
			bu.BonusDiscAccGUID,          
			bu.FPayAccGUID,          
			bu.CostGUID,          
			bu.UserGUID,          
			ISNULL(ch.[TypeGUID],0x0),
			bu.TextFld1,          
			bu.TextFld2,          
			bu.TextFld3,          
			bu.TextFld4,          
			bu.RecState,         
			bu.ItemsExtra,         
			bu.ItemsExtraAccGUID,     
			bu.[CostAccGUID],     
			bu.[StockAccGUID],     
			bu.[VATAccGUID],     
			bu.[BonusAccGUID],     
			bu.[BonusContraAccGUID],   
			bu.[IsPrinted], 
			bu.[IsGeneratedByPocket],
			bu.[TotalSalesTax],
			bu.[CustomerAddressGUID]
		FROM #PalmBu000 AS bu
		LEFT JOIN ch000 AS ch ON bu.GUID = ch.ParentGUID
		--------------------Update Last Number And Return last Number On Distributor--------------------------------
		UPDATE Distributor000 SET LastSalesNumber = NEW.LastSalesNumber			
		FROM 
			(SELECT
			 ISNULL((SELECT MAX(Number) FROM DistDeviceBu000 BU INNER JOIN bt000 BT ON BU.TypeGuid = BT.GUID WHERE DistributorGUID = @DistributorGUID AND bIsOutput = 1), 0) LastSalesNumber
			) NEW
		WHERE ResetDaily = 2 AND GUID = @DistributorGUID AND NEW.LastSalesNumber > Distributor000.LastSalesNumber
		
		UPDATE Distributor000 SET LastReturnNumber = NEW.LastReturnNumber			
		FROM 
			(SELECT
			 ISNULL((SELECT MAX(Number) FROM DistDeviceBu000 BU INNER JOIN bt000 BT ON BU.TypeGuid = BT.GUID WHERE DistributorGUID = @DistributorGUID AND bIsInput = 1), 0) LastReturnNumber
			) NEW
		WHERE ResetDaily = 2 AND GUID = @DistributorGUID AND NEW.LastReturnNumber > Distributor000.LastReturnNumber
		-------------- INSERT BILL ITEM ---------------------     
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
			TotalDiscountPercent,
			TotalExtraPercent,
			MatCurVal,
			TaxCode         
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
			CurrencyValue,          
			ISNULL(Notes, ''),          
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
			ISNULL(SOGuid, 0x00),  
			[Count],
			TotalDiscountPercent,
			TotalExtraPercent,
			MatCurVal, 
			TaxCode        
		FROM #PalmBi000   
		   
		INSERT INTO Di000    
		(    
			Number, Discount, Extra, CurrencyVal, Notes, Flag, GUID, ClassPtr, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID    
		)    
		SELECT    
			Number, Discount, Extra, CurrencyValue, Notes, Flag, GUID, ClassPtr, ParentGUID, AccountGUID, CurrencyGUID, CostGUID, ContraAccGUID    
		FROM #PalmDi000    
		--------------------------------------------------------------   
		------------- SN --------------------------------   
		--- Add New SN To SNC000  
		INSERT INTO Snc000( GUID, SN, MAtGUID, Qty)	  
		SELECT   
			newId(),  
			sn.sn,  
			bi.MatGuid,  
			1  
		FROM    
			DistDeviceSN000 AS sn   
			INNER JOIN DistDeviceBi000 AS bi ON bi.Guid = sn.OutGuid OR bi.Guid = sn.InGuid   
			LEFT JOIN Snc000 AS snc ON snc.Sn = sn.sn  
		WHERE    
			sn.DistributorGuid = @DistributorGuid AND  
			snc.Guid IS NULL  
			  
		--- Update SNT000  
		INSERT INTO snt000( Guid, item, biGuid, stGuid, ParentGuid, Notes, buGuid)   
		SELECT   
			newId(),  
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
			sn.DistributorGuid = @DistributorGuid  
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
			DistributorGuid = @DistributorGUID   
		   
		--------------------------------------------------------------------   
		--------------- CM CustStock ---------------------------------------   
		INSERT INTO DistCm000(  
			Number,  
			Guid,  
			Type,  
			CustomerGuid,  
			MatGuid,  
			Date,  
			Qty,	  
			Target,  
			VisitGuid,
			Unity
		)  
		SELECT   
			0,  
			cm.Guid,	  
			0,  
			cm.CustGuid,  
			cm.MatGuid,  
			cm.NewDate,  
			cm.NewQty * (CASE cm.unity WHEN 2 THEN unit2Fact WHEN 3 THEN Unit3Fact ELSE 1 END),  
			0,  
			cm.VisitGuid,
			cm.Unity
		FROM   
			DistDeviceCm000 AS cm  
			INNER JOIN mt000 AS mt ON mt.Guid = cm.MatGuid   
		WHERE   
			DistributorGuid = @DistributorGuid AND VisitGuid <> 0x00  
		UPDATE DistCm000  
			SET Target = bi.Qty  
		FROM   
			DistCm000 AS cm  
			INNER JOIN DistDeviceCm000 AS dm ON dm.Guid = cm.Guid  
			INNER JOIN ( SELECT bu.CustomerGuid , bi.MatGuid, SUM(CASE bt.bIsOutput WHEN 1 THEN bi.Qty ELSE bi.Qty*-1 END) AS Qty    
						 FROM	DistDeviceBt000 AS bt INNER JOIN DistDeviceBu000 AS bu ON bt.Guid = bu.TypeGuid   
								INNER JOIN DistDeviceBi000 AS bi ON bi.ParentGuid = bu.Guid   
						 WHERE bu.StoreGuid =  @StoreGuid  
						 GROUP BY bu.CustomerGuid, bi.MatGuid  
						)	AS bi ON bi.CustomerGuid = dm.CustGuid AND bi.MatGuid = dm.MatGuid  
		--------------------------------------------------------------------  
		--------------- Bill Duty - Pay Terms ---------------------------------------   
		DECLARE @buGUID			UNIQUEIDENTIFIER
		DECLARE @buTypeGUID		UNIQUEIDENTIFIER
		DECLARE @buCustAccGUID	UNIQUEIDENTIFIER
		DECLARE @buCustGUID		UNIQUEIDENTIFIER
		DECLARE @buCurrencyGUID UNIQUEIDENTIFIER
		DECLARE @buCurrencyVal	FLOAT
		DECLARE @buDate			DATETIME
		DECLARE @buTotal		FLOAT
		DECLARE @buTotalExtra	FLOAT
		DECLARE @buItemsExtra	FLOAT
		DECLARE @buVAT			FLOAT
		DECLARE @buTotalDisc	FLOAT
		DECLARE @buItemsDisc	FLOAT
		
		DECLARE cc CURSOR FOR 
		SELECT 
			GUID, 
			TypeGUID, 
			CustGUID,
			CustAccGUID,
			CurrencyGUID,
			CurrencyValue,
			[Date],
			Total,
			TotalExtra,
			ItemsExtra,
			VAT,
			TotalDisc,
			ItemsDisc 
		FROM 
			#PalmBu000  
		
		OPEN cc   
			FETCH NEXT FROM cc INTO 
				@buGUID, 
				@buTypeGUID, 
				@buCustGUID,
				@buCustAccGUID,
				@buCurrencyGUID,
				@buCurrencyVal,
				@buDate, 
				@buTotal,
				@buTotalExtra,
				@buItemsExtra,
				@buVAT,
				@buTotalDisc,
				@buItemsDisc 
				
			WHILE @@FETCH_STATUS = 0   
			BEGIN   
				DECLARE @net FLOAT
				SET @net = @buTotal + @buTotalExtra + @buItemsExtra + @buVAT - @buTotalDisc - @buItemsDisc
				
				DECLARE @days INT
				SET @days = 0
				
				-- Customer
				SELECT @days = ISNULL([Days], 0) FROM pt000 WHERE [Type] = 2 AND Term = 2 AND RefGUID = @buCustGUID
				
				-- Bill Type
				IF (@days = 0) 		
					SELECT @days = ISNULL([Days], 0) FROM pt000 WHERE [Type] = 1 AND Term = 2 AND RefGUID = @buTypeGuid
				
				DECLARE @dueDate DATETIME
				SET @dueDate = DATEADD(day, @days, @buDate)
				--SELECT DATEADD(day, 6, '2016-12-27 00:00:00.000')
				
				DECLARE @isOutput BIT
				DECLARE @debit FLOAT
				DECLARE @credit FLOAT
				SELECT @isOutput = ISNULL(bIsOutput, 1) FROM bt000 WHERE GUID = @buTypeGUID
				
				IF (@isOutput = 1)
				BEGIN
					SET @debit = @net
					SET @credit = 0
				END
				ELSE
				BEGIN
					SET @debit = 0
					SET @credit = @net
				END
				-------------------------
				INSERT INTO pt000
					   ([GUID]
					   ,[Type]
					   ,[RefGUID]
					   ,[Term]
					   ,[Days]
					   ,[Disable]
					   ,[CalcOptions]
					   ,[CustAcc]
					   ,[Debit]
					   ,[Credit]
					   ,[CurrencyGUID]
					   ,[CurrencyVal]
					   ,[DueDate]
					   ,[IsTransfered]
					   ,[TypeGuid]
					   ,[OriginDate])
				 VALUES
					   (NEWID()
					   ,3 -- Bill
					   ,@buGUID
					   ,2 -- Duty for numer of days
					   ,@days
					   ,0
					   ,0
					   ,@buCustAccGUID 
					   ,@debit
					   ,@credit
					   ,@buCurrencyGUID
					   ,@buCurrencyVal
					   ,@dueDate
					   ,0
					   ,0x0
					   ,'1980-01-01 00:00:00.000')			
				
				FETCH NEXT FROM cc INTO 
					@buGUID, 
					@buTypeGUID, 
					@buCustGUID,
					@buCustAccGUID,
					@buCurrencyGUID,
					@buCurrencyVal,
					@buDate, 
					@buTotal,
					@buTotalExtra,
					@buItemsExtra,
					@buVAT,
					@buTotalDisc,
					@buItemsDisc 
			END   
		CLOSE cc   
		DEALLOCATE cc
		---------- Update Promotion Budgets   
		Update DistPromotionsBudget000   
		SET RealPromQty = pb.ProQty   
		From    
			DistPromotionsBudget000 AS dg   
			INNER JOIN DistDeviceProBudget000 AS pb ON pb.ProGuid = dg.ParentGuid AND pb.DistributorGuid = dg.DistributorGuid AND pb.DistributorGuid = @DistributorGuid   
		--------------------------------------------------------------------  
		---------- Gen Transfer For DistributorOrder  
		DECLARE		@OrderBuGuid		UNIQUEIDENTIFIER  
		 
		SELECT @OrderBuGuid = Guid FROM DistDeviceBu000   
		WHERE DistributorGuid = @DistributorGuid AND IsOrder = 1 And Deleted = 0  
		 
		IF ISNULL(@OrderBuGuid, 0x00) <> 0x00   
			EXEC prcDistGenOrderTransfer @DistributorGUID, @OrderBuGuid  
		--------------------------------------------------------------------  
		--- Update LastBuNumber  
		UPDATE Distributor000 SET LastBuNumber = ISNULL((SELECT MAX(Number) FROM DistDeviceBu000 WHERE DistributorGuid = @DistributorGuid), LastBuNumber) 
		WHERE Guid = @DistributorGuid 
		-------------------------------------------------------------------- 
		--- Generate Orders System Info 
		CREATE TABLE #DistOrderBu000(Guid UNIQUEIDENTIFIER, TypeGuid UNIQUEIDENTIFIER, DistributorGuid UNIQUEIDENTIFIER) 
			
		INSERT INTO #DistOrderBu000 
		SELECT 
			bu.Guid
			,bu.TypeGUID
			,DistributorGUID
		FROM 
			DistDeviceBu000 bu 
			INNER JOIN bt000  bt ON bt.GUID = bu.TypeGUID
		WHERE 
			DistributorGUID = @DistributorGUID
			AND bt.Type = 5 OR bt.Type = 6

		IF EXISTS (SELECT GUID FROM #DistOrderBu000)
		BEGIN
			EXEC prcDistGenerateOrdersInfo @DistributorGUID
		END
		--------------------------------------------------------------------  
		DROP TABLE #PalmBu000         
		DROP TABLE #PalmBi000         
		DROP TABLE #PalmDi000  
		DROP TABLE #DistOrderBu000   
		---------------------------------- Fix Expiry Date	     
		CREATE TABLE #PDABillGuids(GUID UNIQUEIDENTIFIER, DistributorGUID UNIQUEIDENTIFIER)    
		INSERT INTO  #PDABillGuids SELECT Guid, @DistributorGUID From DistDeviceBu000 WHERE DistributorGUID = @DistributorGUID     
		DECLARE @CheckExpireDatePalm BIT   
		 
		SELECT @CheckExpireDatePalm = ISNULL(op000.[Value],0) FROM op000 WHERE Name = 'DistCfg_CHECK_MAT_VALIDITY' 
		 
		IF (@CheckExpireDatePalm = 1)
			EXEC prcCheckExpireDatePalm
		------------------------------------ End Fix Expiry Date    
		DELETE DistDeviceDi000 WHERE ParentGUID IN (SELECT GUID FROM DistDeviceBu000 WHERE DistributorGUID = @DistributorGUID)
		DELETE DistDeviceBi000 WHERE ParentGUID IN (SELECT GUID FROM DistDeviceBu000 WHERE DistributorGUID = @DistributorGUID)
		DELETE DistDeviceBu000 WHERE DistributorGUID = @DistributorGUID
		DELETE DistDeviceTs000 WHERE DistributorGUID = @DistributorGUID
		DELETE DistDeviceCm000 WHERE DistributorGUID = @DistributorGUID
		DELETE DistDeviceSN000 WHERE DistributorGUID = @DistributorGUID    
		------------------------------------------------------------    
	
##################################################### 
CREATE PROC prcDist_PostBillOFDestributor 
	@BillGUID uniqueidentifier,
	@DistributorGUID uniqueidentifier
AS 
	SET NOCOUNT ON

	DECLARE @UserName NVARCHAR(100)
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1 

	EXEC prcConnections_add2 @UserName

	DECLARE	@DistAutoPost		BIT,
		@DistAutoGenEntry 	BIT,
		@btNoEntry 			BIT,
		@btNoPost		 	BIT

	SELECT 	 
		@btNoEntry = bNoEntry,
		@btNoPost  = bNoPost
	FROM 
		bu000 AS bu
		INNER JOIN bt000 AS bt ON bt.Guid = bu.TypeGUID
	WHERE 
		bu.Guid = @billGUID

	SELECT 
		@DistAutoPost = AutoPostBill, 
		@DistAutoGenEntry = AutoGenBillEntry 
	FROM 
		Distributor000 
	WHERE 
		GUID = @DistributorGUID 

	IF (@DistAutoPost <> 0 AND @btNoPost <> 1)  
	BEGIN 
		EXEC prcDisableTriggers 'mt000'
		EXEC prcDisableTriggers 'MS000'
		ALTER TABLE bu000 DISABLE TRIGGER  trg_bu000_CheckConstraintsExpireDate
		
		UPDATE BU000 
		SET Isposted = 1 
		WHERE GUID = @BillGUID 
		
		ALTER TABLE mt000 ENABLE TRIGGER ALL
		ALTER TABLE MS000 ENABLE TRIGGER ALL
		ALTER TABLE bu000 ENABLE TRIGGER  trg_bu000_CheckConstraintsExpireDate
	END 
	
	IF (@DistAutoGenEntry <> 0 AND @btNoEntry <> 1) 
	BEGIN
		EXEC prcDisableTriggers 'ce000'
		
		EXEC prcBill_genEntry @BillGUID 
		
		ALTER TABLE ce000 ENABLE TRIGGER All
	END	
##################################################### 
CREATE PROCEDURE prcCheckExpireDatePalm
AS 
      SET NOCOUNT ON  
      -------------------------------------------- Posting Bills
      DECLARE @cc CURSOR
      DECLARE @Bill_Guid UNIQUEIDENTIFIER, @DistributorGUID UNIQUEIDENTIFIER
      
      SET @cc = CURSOR FAST_FORWARD FOR 
      SELECT [GUID], [DistributorGUID] FROM #PDABillGuids
      
      OPEN @cc 
      FETCH NEXT FROM @cc INTO @Bill_Guid, @DistributorGUID
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
		EXEC prcDist_PostBillOFDestributor @Bill_Guid, @DistributorGUID
		
		FETCH NEXT FROM @cc INTO @Bill_Guid, @DistributorGUID
      END
      
      CLOSE @cc
      DEALLOCATE @cc
      ---------------------------------------------------------------
      DECLARE @MatStore TABLE ( [MatGUID] [UNIQUEIDENTIFIER], [StoreGuid] [UNIQUEIDENTIFIER])  
      SELECT  bi.[MatGUID],bi.StoreGuid,bi.GUID  
      INTO #bi
      FROM bi000 bi 
      INNER JOIN  #PDABillGuids b ON bi.ParentGuid = b.Guid
      INNER JOIN mt000 mt ON mt.GUID = bi.[MatGUID]
      WHERE mt.ExpireFlag > 0 AND bi.ExpireDate = '1/1/1980'
      IF (@@ROWCOUNT = 0)
      RETURN

      CREATE INDEX KLSAFJKL ON #bi(Guid)
      INSERT INTO @MatStore
            SELECT DISTINCT MatGUID,StoreGuid FROM #bi
      CREATE TABLE #InResult 
      (
            MatGUID UNIQUEIDENTIFIER,
            StoreGuid UNIQUEIDENTIFIER,
            [buDate] DateTime,
            [ExpireDate] DateTime,
            Qty               FLOAT,
            Dir               INT
      )
      
      CREATE TABLE #OutResule
      (
            Id                      INT IDENTITY(1,1),
            Id2                     FLOAT,
            GUID              UNIQUEIDENTIFIER,
            Number                  INT,
            buGuid                  UNIQUEIDENTIFIER,
            MatGUID                 UNIQUEIDENTIFIER,
            StoreGuid         UNIQUEIDENTIFIER,
            qty                     FLOAT,
            Bonus             FLOAT,
            buDate                  DATETIME,
            [expireDate]      DATETIME,
            unity             TINYINT,
            Price             FLOAT,
            discrate          FLOAT,
            bonusdiscrate           FLOAT,
            extrarate         FLOAT,
            FLAG BIT          DEFAULT 0,
		Cost 		UNIQUEIDENTIFIER
      )
      ---------------------------
      INSERT INTO #InResult (MatGUID,     StoreGuid,[ExpireDate],qty )
      SELECT biMatPtr,biStorePtr,biExpireDate,SUM((biQty + biBonusQnt) * buDirection) from vwBuBi 
      INNER JOIN (SELECT DISTINCT MatGUID FROM @MatStore) mt ON mt.[MatGUID] = biMatPtr
      INNER JOIN (SELECT DISTINCT StoreGuid FROM @MatStore) st ON StoreGuid = biStorePtr
      WHERE buDirection = 1 OR (buDirection = -1 AND (biExpireDate > '1/1/1980' OR buGUID NOT IN( SELECT GUID FROM #PDABillGuids))
      )
      GROUP BY biMatPtr,biStorePtr,biExpireDate,[buDate],buDirection
--SELECT * FROM #InResult
      --------------------------------------------------------
      INSERT INTO #OutResule(Guid,Number,buGuid,MatGUID,StoreGuid,qty,Bonus,[expireDate],unity,Price,discrate,bonusdiscrate,extrarate,Cost)
      SELECT biGUID,biNumber,buGUID,biMatPtr,biStorePtr,biQty,bibonusQnt,biExpireDate ,biunity,biPrice,CASE biPrice WHEN 0 THEN 0 ELSE  CASE biQty WHEN 0 THEN 0 ELSE biDiscount/(biPrice * biQty) END END, CASE WHEN biQty = 0 OR biPrice = 0 THEN 0 ELSE  biBonusDisc /(biPrice * biQty) END ,
      CASE  WHEN  biQty = 0 OR biPrice = 0 THEN 0 ELSE  biBonusDisc /(biPrice * biQty) END,biCostptr      
   
      FROM vwBuBi bu INNER JOIN #bi bi ON       bi.GUID = biGuid
      WHERE  btDirection = -1 AND biExpireDate = '1/1/1980' ORDER BY biMatPtr,buDate,buSortFlag,buNumber,BInUMBER
      
      
      
  
      UPDATE #OutResule SET Id2 = CAST ([id] AS FLOAT)
      --ALTER TABLE #OutResule DROP COLUMN ID

-------------------------------------------------------------------
      
      DECLARE @c CURSOR,@MatPtr UNIQUEIDENTIFIER,@StoreGuid UNIQUEIDENTIFIER,@biQty FLOAT,@ExpireDate DATETIME,@Qty FLOAT,@ID FLOAT
      ,@Qty2 FLOAT,@CurrMatPtr UNIQUEIDENTIFIER,@CurrStoreGuid UNIQUEIDENTIFIER,@Bonus FLOAT
      
      SET @c = CURSOR FAST_FORWARD FOR 
      SELECT MatGUID,   StoreGuid,[ExpireDate],SUM(qty) FROM #InResult 
      GROUP BY MatGUID,StoreGuid,[ExpireDate] 
      HAVING SUM(qty) > 0 ORDER BY MatGUID,     StoreGuid,[ExpireDate] 
      SET @CurrMatPtr = 0X00
      SET @CurrStoreGuid = 0X00
      OPEN @c FETCH NEXT FROM @c INTO @MatPtr,  @StoreGuid,@ExpireDate,@biQty
      WHILE @@FETCH_STATUS = 0
      BEGIN
    
            IF ((@CurrStoreGuid =@StoreGuid) AND (@CurrMatPtr = @MatPtr))
                  GOTO LL
            SET @Qty = @biQty
            WHILE @Qty > 0
            BEGIN
           
                  SET @ID = NULL
                  SELECT @Qty2 = qty ,@ID = Id2,@Bonus = Bonus FROM #OutResule 
                  WHERE Id2 = (SELECT MIN(ID2) FROM #OutResule  WHERE [ExpireDate] = '1/1/1980' AND MatGUID = @MatPtr AND StoreGuid = @StoreGuid AND FLAG = 0)
   
                  IF (@ID IS NULL)
                  BEGIN
                        SET @CurrStoreGuid = @StoreGuid
                        SET @CurrMatPtr = @MatPtr
                        GOTO LL
                  END
                  IF ((@Qty2 + @Bonus) <= @Qty)
                  BEGIN
                        UPDATE #OutResule SET [ExpireDate] = @ExpireDate WHERE Id2 = @ID
                        SET @Qty = @Qty - (@Qty2 + @Bonus)
                  END
                  ELSE
                  BEGIN
               
                        UPDATE #OutResule SET qty = 
                        CASE WHEN (@Qty2 < @Qty)  THEN  @Qty2
                        ELSE
                         @Qty END ,
                         bonus =  CASE 
                         WHEN (@Qty2 < @Qty) THEN (@Qty - @Qty2) 
                          ELSE 0 END 
                         
                         ,[expireDate]  = @ExpireDate,FLAG = 1 
                        
                       WHERE Id2 = @ID
                        IF   (@Qty2 < @Qty)
                        begin
                              
                              set @Bonus = @Bonus - (@Qty -@Qty2 )
                              SET @Qty2 = 0
                       
                         end
                        ELSE
                        begin
                              SET @Qty2 = @Qty2 - @Qty
                        end

                        INSERT INTO #OutResule(Id2,GUID,Number,buGuid,MatGUID,StoreGuid,qty,[expireDate],Bonus,unity,discrate,bonusdiscrate,extrarate,Price,Cost,FLAG)                  
                        SELECT @ID + 0.000001
                        ,NEWID(),Number,buGuid,MatGUID,StoreGuid,@Qty2 ,'1/1/1980',@Bonus,unity,discrate,bonusdiscrate,extrarate,Price,Cost,0
                        FROM #OutResule WHERE ID2 = @ID and (@Qty2 > 0 or @Bonus > 0)
                        SET @Qty = 0
                        
                  END
            END
      
            LL: FETCH NEXT FROM @c INTO @MatPtr ,@StoreGuid,@ExpireDate ,@biQty  
      END
      CLOSE @c
      DEALLOCATE @c
      create table #bb(id int identity(1,1),G UNIQUEIDENTIFIER,CurrencyGUID UNIQUEIDENTIFIER ,CurrencyVal float)
	  --select *  FROM #OutResule
	  
	  
      BEGIN TRAN      
      EXEC prcDisableTriggers 'bi000'
      UPDATE bi SET 
      Qty = CASE [out].FLAG WHEN 0 THEN bi.Qty ELSE [out].qty END,
      BonusQnt = CASE [out].FLAG WHEN 0 THEN bi.BonusQnt ELSE [out].bonus END,
      Discount = CASE [out].FLAG WHEN 0 THEN bi.Discount ELSE [out].discrate *[out].Price *[out].qty   END,
      BonusDisc = CASE [out].FLAG WHEN 0 THEN bi.BonusDisc ELSE [out].bonusdiscrate *[out].Price *[out].qty   END,
      bi.Extra  = CASE [out].FLAG WHEN 0 THEN bi.Extra ELSE [out].extrarate *[out].Price *[out].qty   END,
      [ExpireDate] =  [out].[ExpireDate] FROM  bi000 bi INNER JOIN #OutResule [out] ON [out].GUID = bi.GUID 
            
      INSERT INTO bi000 (GUID,Number,Qty,ParentGUID,BonusQnt,Price,Discount,BonusDisc,Extra,[ExpireDate],MATGUID,STOREGUID,unity,CostGuid)
      SELECT [out].[GUID],[out].[Number] + id, [out].qty,[out].buGuid,[out].bonus,[out].Price,[out].discrate *[out].Price *[out].qty,
      [out].bonusdiscrate *[out].Price *[out].qty, [out].extrarate *[out].Price *[out].qty  ,[out].[ExpireDate],[out].MatGUID,[out].STOREGUID,[out].unity,Cost
      FROM #OutResule [out] LEFT JOIN bi000 bi ON [out].GUID = bi.GUID WHERE bi.GUID IS NULL
      Insert #bb(G,CurrencyGUID,CurrencyVal) select bi.guid , bu.CurrencyGUID ,bu.CurrencyVal 
      FROM bi000 bi
	  INNER JOIN #OutResule O ON O.GUID = BI.GUID
	  INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID  
	  Order by bi.matguid,bi.ExpireDate,bi.number desc
      
      UPDATE bi SET number = id, CurrencyGUID = b.CurrencyGUID, CurrencyVal = b.CurrencyVal 
      FROM bi000 bi
	  INNER JOIN #bb b on g = bi.GUID 
	  ----- tras
	  Select DISTINCT outbillGuid,InbillGuid,bu.StoreGuid 
	  INTO #e from ts000 ts 
	  INNER JOIN #OutResule b ON b.buGuid = ts.outbillGuid
	  INNER JOIN bu000 bu ON bu.Guid = InbillGuid
 
	  IF Exists(select * FROM #e)
	  BEGIN
			DELETE BI FROM bi000 bi INNER JOIN #e e ON e.InbillGuid = bi.ParentGuid INNER JOIN mt000 mt ON mt.Guid = bi.MatGuid WHERE mt.ExpireFlag > 0
            
			INSERT INTO bi000 (GUID,Number,Qty,ParentGUID,BonusQnt,Price,Discount,BonusDisc,Extra,[ExpireDate],MATGUID,STOREGUID,unity,CostGuid)
			SELECT 
				NEWID(),bi.Number,bi.Qty,InbillGuid,bi.BonusQnt,bi.Price,bi.Discount,bi.BonusDisc,Extra,[ExpireDate],MATGUID,e.STOREGUID,BI.unity,CostGuid
			FROM 
				bi000 bi 
				INNER JOIN #e e ON e.outbillGuid = bi.ParentGuid 
				INNER JOIN mt000 mt ON mt.Guid = bi.MatGuid WHERE mt.ExpireFlag > 0
	END
	  -----------	 
      ALTER TABLE bi000 ENABLE  TRIGGER ALL
 
      DELETE #PDABillGuids

      DELETE #bi
      DELETE #bb 
      DELETE #InResult 
      DELETE #OutResule

      COMMIT 
###########################################################################
#END
