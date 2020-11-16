#################################################################
CREATE PROC prcSaveMaterialPrices
	@date DATETIME
AS
BEGIN
	SET NOCOUNT ON

	INSERT INTO MaterialPriceHistory000 
		(MatGuid, Date, 
		Whole, Half, Retail, EndUser, Export, Vendor,
		Whole2, Half2, Retail2, EndUser2, Export2, Vendor2,
		Whole3, Half3, Retail3, EndUser3, Export3, Vendor3)
	SELECT
		GUID, @date, 
		Whole, Half, Retail, EndUser, Export, Vendor,
		Whole2, Half2, Retail2, EndUser2, Export2, Vendor2,
		Whole3, Half3, Retail3, EndUser3, Export3, Vendor3
	FROM mt000
END
#################################################################
CREATE PROC prcSavePFCMaterialPrices
	@date DATETIME
AS
BEGIN
	SET NOCOUNT ON

	DELETE MaterialPriceHistory000 WHERE Date = @date

	EXEC prcSaveMaterialPrices @date
END
#################################################################
CREATE PROC prcSavemanagementMaterialPrices
	@PFCGuid UNIQUEIDENTIFIER,
	@date DATETIME
AS
BEGIN
	SET NOCOUNT ON

	DELETE MaterialPriceHistory000 WHERE date = @date

	EXEC prcSaveMaterialPrices @date
end
#################################################################
CREATE PROC prcSyncPFCMaterial
       @date DATETIME,
	   @lastConsalidateDate DATETIME,
       @syncNewOnly BIT
AS
BEGIN
    CREATE TABLE #TargetMat (GUID UNIQUEIDENTIFIER)

    DECLARE @newMatCount INT = 0, @updatedMatCount INT = 0, @deletedMatCount INT = 0
	DECLARE @IncreaseBillTypeGUID UNIQUEIDENTIFIER, @DecreaseBillTypeGUID UNIQUEIDENTIFIER
              
	SET    @IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_IncreasePricesBillType'))
	SET    @DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_DecreasePricesBillType'))

	INSERT INTO #TargetMat
	SELECT DISTINCT mt.GUID
	FROM 
          PFCUpdatedMaterial000 mt 
          LEFT JOIN 
			(SELECT bi.MatGUID FROM bi000 bi 
				INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
            WHERE 
                bu.typeGuid NOT IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID)
				AND CAST(BU.Date AS DATE) > @lastConsalidateDate) bi 
          ON mt.GUID = bi.MatGUID
	WHERE 
	@syncNewOnly = 0 OR bi.MatGUID IS NULL

	------------------------------------------------------------------------------
	ALTER TABLE mt000 DISABLE TRIGGER ALL
	------------------------------------------------------------------------------
	
	UPDATE mt000 SET 
	       [Number] = updatedMat.Number
	       ,[Name] = updatedMat.Name
	       ,[Code] = updatedMat.Code
	       ,[LatinName] = updatedMat.LatinName
	       ,[BarCode] = updatedMat.BarCode
	       ,[CodedCode] = updatedMat.CodedCode
	       ,[Unity] = updatedMat.Unity
	       ,[Spec] = updatedMat.Spec
	       ,[Whole] = updatedMat.Whole
	      ,[Half] = updatedMat.Half
	       ,[Retail] = updatedMat.Retail
	       ,[EndUser] = updatedMat.EndUser
	       ,[Export] = updatedMat.Export
	       ,[Vendor] = updatedMat.Vendor
	       ,[PriceType] = updatedMat.PriceType
	       ,[SellType] = updatedMat.SellType
	       ,[BonusOne] = updatedMat.BonusOne
	       ,[CurrencyVal] = updatedMat.CurrencyVal
	       ,[UseFlag] = updatedMat.UseFlag
	       ,[Origin] = updatedMat.Origin
	       ,[Company] = updatedMat.Company
	       ,[Type] = updatedMat.Type
	       ,[Security] = updatedMat.Security
	       ,[Bonus] = updatedMat.Bonus
	       ,[Unit2] = updatedMat.Unit2
	       ,[Unit2Fact] = updatedMat.Unit2Fact
	       ,[Unit3] = updatedMat.Unit3
	       ,[Unit3Fact] = updatedMat.Unit3Fact
	       ,[Flag] = updatedMat.Flag
	       ,[Pos] = updatedMat.Pos
	       ,[Dim] = updatedMat.Dim
	       ,[ExpireFlag] = updatedMat.ExpireFlag
	       ,[ProductionFlag] = updatedMat.ProductionFlag
	       ,[Unit2FactFlag] = updatedMat.Unit2FactFlag
	       ,[Unit3FactFlag] = updatedMat.Unit3FactFlag
	       ,[BarCode2] = updatedMat.BarCode2
	       ,[BarCode3] = updatedMat.BarCode3
	       ,[SNFlag] = updatedMat.SNFlag
	       ,[ForceInSN] = updatedMat.ForceInSN
	       ,[ForceOutSN] = updatedMat.ForceOutSN
	       ,[VAT] = updatedMat.VAT
	       ,[Color] = updatedMat.Color
	       ,[Provenance] = updatedMat.Provenance
	       ,[Quality] = updatedMat.Quality
	       ,[Model] = updatedMat.Model
	       ,[Whole2] = updatedMat.Whole2
	       ,[Half2] = updatedMat.Half2
	       ,[Retail2] = updatedMat.Retail2
	       ,[EndUser2] = updatedMat.EndUser2
	       ,[Export2] = updatedMat.Export2
	       ,[Vendor2] = updatedMat.Vendor2
	       ,[Whole3] = updatedMat.Whole3
	       ,[Half3] = updatedMat.Half3
	       ,[Retail3] = updatedMat.Retail3
	       ,[EndUser3] = updatedMat.EndUser3
	       ,[Export3] = updatedMat.Export3
	       ,[Vendor3] = updatedMat.Vendor3
	       ,[GUID] = updatedMat.GUID
	       ,[GroupGUID] = updatedMat.GroupGUID
	       ,[PictureGUID] = updatedMat.PictureGUID
	       ,[CurrencyGUID] = updatedMat.CurrencyGUID
	       ,[DefUnit] = updatedMat.DefUnit
	       ,[bHide] = updatedMat.bHide
	       ,[branchMask] = updatedMat.branchMask
	       ,[OldGUID] = updatedMat.OldGUID
	       ,[NewGUID] = updatedMat.NewGUID
	       ,[Assemble] = updatedMat.Assemble
	       ,[CalPriceFromDetail] = updatedMat.CalPriceFromDetail
	       ,[ForceInExpire] = updatedMat.ForceInExpire
	       ,[ForceOutExpire] = updatedMat.ForceOutExpire
	       ,[CreateDate] = updatedMat.CreateDate
	       ,[IsIntegerQuantity] = updatedMat.IsIntegerQuantity
	       ,[ClassFlag] = updatedMat.ClassFlag
	       ,[ForceInClass] = updatedMat.ForceInClass
	       ,[ForceOutClass] = updatedMat.ForceOutClass
	       ,[DisableLastPrice] = updatedMat.DisableLastPrice
	       ,[LastPriceCurVal] = updatedMat.LastPriceCurVal
	       ,[PrevQty] = updatedMat.PrevQty
	       ,[FirstCostDate] = updatedMat.FirstCostDate
	       ,[HasSegments] = updatedMat.HasSegments
	       ,[Parent] = updatedMat.Parent
	       ,[IsCompositionUpdated] = updatedMat.IsCompositionUpdated
	       ,[InheritsParentSpecs] = updatedMat.InheritsParentSpecs
	       ,[CompositionName] = updatedMat.CompositionName
	       ,[CompositionLatinName] = updatedMat.CompositionLatinName
	       ,[IsCalcTaxForPUTaxCode] = updatedMat.IsCalcTaxForPUTaxCode
	FROM PFCUpdatedMaterial000 updatedMat 
	       INNER JOIN #TargetMat targetMat ON targetMat.Guid = updatedMat.Guid
	WHERE mt000.GUID = updatedMat.GUID
	
	SET @updatedMatCount = @@ROWCOUNT
	------------------------------------------------------------------------------------
	
	INSERT INTO mt000 
	       ([Number]
	 ,[Name]
	       ,[Code]
	       ,[LatinName]
	       ,[BarCode]
	       ,[CodedCode]
	       ,[Unity]
	       ,[Spec]
	       ,[Qty]
	       ,[High]
	       ,[Low]
	       ,[Whole]
	       ,[Half]
	       ,[Retail]
	       ,[EndUser]
	       ,[Export]
	       ,[Vendor]
	       ,[MaxPrice]
	       ,[AvgPrice]
	       ,[LastPrice]
	       ,[PriceType]
	       ,[SellType]
	       ,[BonusOne]
	       ,[CurrencyVal]
	       ,[UseFlag]
	       ,[Origin]
	       ,[Company]
	       ,[Type]
	       ,[Security]
	       ,[LastPriceDate]
	       ,[Bonus]
	       ,[Unit2]
	       ,[Unit2Fact]
	       ,[Unit3]
	       ,[Unit3Fact]
	       ,[Flag]
	       ,[Pos]
	       ,[Dim]
	       ,[ExpireFlag]
	       ,[ProductionFlag]
	       ,[Unit2FactFlag]
	       ,[Unit3FactFlag]
	       ,[BarCode2]
	       ,[BarCode3]
	       ,[SNFlag]
	       ,[ForceInSN]
	       ,[ForceOutSN]
	       ,[VAT]
	       ,[Color]
	       ,[Provenance]
	       ,[Quality]
	       ,[Model]
	       ,[Whole2]
	       ,[Half2]
	       ,[Retail2]
	       ,[EndUser2]
	       ,[Export2]
	       ,[Vendor2]
	       ,[MaxPrice2]
	       ,[LastPrice2]
	       ,[Whole3]
	       ,[Half3]
	       ,[Retail3]
	       ,[EndUser3]
	       ,[Export3]
	       ,[Vendor3]
	       ,[MaxPrice3]
	       ,[LastPrice3]
	       ,[GUID]
	       ,[GroupGUID]
	       ,[PictureGUID]
	       ,[CurrencyGUID]
	       ,[DefUnit]
	       ,[bHide]
	       ,[branchMask]
	       ,[OldGUID]
	       ,[NewGUID]
	       ,[Assemble]
	       ,[OrderLimit]
	       ,[CalPriceFromDetail]
	       ,[ForceInExpire]
	       ,[ForceOutExpire]
	       ,[CreateDate]
	       ,[IsIntegerQuantity]
	       ,[ClassFlag]
	       ,[ForceInClass]
	       ,[ForceOutClass]
	       ,[DisableLastPrice]
	       ,[LastPriceCurVal]
	       ,[PrevQty]
	       ,[FirstCostDate]
	       ,[HasSegments]
	       ,[Parent]
	       ,[IsCompositionUpdated]
	       ,[InheritsParentSpecs]
	       ,[CompositionName]
	       ,[CompositionLatinName]
	       ,[IsCalcTaxForPUTaxCode])
	SELECT 
	       updatedMat.[Number]
	       ,updatedMat.[Name]
	       ,updatedMat.[Code]
	       ,updatedMat.[LatinName]
	       ,updatedMat.[BarCode]
	       ,updatedMat.[CodedCode]
	       ,updatedMat.[Unity]
	       ,updatedMat.[Spec]
	       ,updatedMat.[Qty]
	       ,updatedMat.[High]
	       ,updatedMat.[Low]
	       ,updatedMat.[Whole]
	       ,updatedMat.[Half]
	       ,updatedMat.[Retail]
	       ,updatedMat.[EndUser]
	       ,updatedMat.[Export]
	       ,updatedMat.[Vendor]
	       ,updatedMat.[MaxPrice]
	       ,updatedMat.[AvgPrice]
	       ,updatedMat.[LastPrice]
	       ,updatedMat.[PriceType]
	       ,updatedMat.[SellType]
	       ,updatedMat.[BonusOne]
	       ,updatedMat.[CurrencyVal]
	       ,updatedMat.[UseFlag]
	       ,updatedMat.[Origin]
	       ,updatedMat.[Company]
	       ,updatedMat.[Type]
	       ,updatedMat.[Security]
	       ,updatedMat.[LastPriceDate]
	       ,updatedMat.[Bonus]
	       ,updatedMat.[Unit2]
	       ,updatedMat.[Unit2Fact]
	       ,updatedMat.[Unit3]
	       ,updatedMat.[Unit3Fact]
	       ,updatedMat.[Flag]
	       ,updatedMat.[Pos]
	       ,updatedMat.[Dim]
	       ,updatedMat.[ExpireFlag]
	       ,updatedMat.[ProductionFlag]
	       ,updatedMat.[Unit2FactFlag]
	       ,updatedMat.[Unit3FactFlag]
	       ,updatedMat.[BarCode2]
	       ,updatedMat.[BarCode3]
	       ,updatedMat.[SNFlag]
	       ,updatedMat.[ForceInSN]
	       ,updatedMat.[ForceOutSN]
	       ,updatedMat.[VAT]
	       ,updatedMat.[Color]
	       ,updatedMat.[Provenance]
	       ,updatedMat.[Quality]
	       ,updatedMat.[Model]
	       ,updatedMat.[Whole2]
	       ,updatedMat.[Half2]
	       ,updatedMat.[Retail2]
	       ,updatedMat.[EndUser2]
	       ,updatedMat.[Export2]
	       ,updatedMat.[Vendor2]
	       ,updatedMat.[MaxPrice2]
	       ,updatedMat.[LastPrice2]
	       ,updatedMat.[Whole3]
	       ,updatedMat.[Half3]
	       ,updatedMat.[Retail3]
	       ,updatedMat.[EndUser3]
	       ,updatedMat.[Export3]
	       ,updatedMat.[Vendor3]
	       ,updatedMat.[MaxPrice3]
	       ,updatedMat.[LastPrice3]
	       ,updatedMat.[GUID]
	       ,updatedMat.[GroupGUID]
	       ,updatedMat.[PictureGUID]
	       ,updatedMat.[CurrencyGUID]
	       ,updatedMat.[DefUnit]
	       ,updatedMat.[bHide]
	       ,updatedMat.[branchMask]
	       ,updatedMat.[OldGUID]
	       ,updatedMat.[NewGUID]
	       ,updatedMat.[Assemble]
	       ,updatedMat.[OrderLimit]
	       ,updatedMat.[CalPriceFromDetail]
	       ,updatedMat.[ForceInExpire]
	       ,updatedMat.[ForceOutExpire]
	       ,updatedMat.[CreateDate]
	       ,updatedMat.[IsIntegerQuantity]
	       ,updatedMat.[ClassFlag]
	       ,updatedMat.[ForceInClass]
	       ,updatedMat.[ForceOutClass]
	       ,updatedMat.[DisableLastPrice]
	       ,updatedMat.[LastPriceCurVal]
	       ,updatedMat.[PrevQty]
	       ,updatedMat.[FirstCostDate]
	       ,updatedMat.[HasSegments]
	       ,updatedMat.[Parent]
	       ,updatedMat.[IsCompositionUpdated]
	       ,updatedMat.[InheritsParentSpecs]
	       ,updatedMat.[CompositionName]
	       ,updatedMat.[CompositionLatinName]
	       ,updatedMat.[IsCalcTaxForPUTaxCode] 
	FROM PFCUpdatedMaterial000 updatedMat 
	       INNER JOIN #TargetMat targetMat ON targetMat.Guid = updatedMat.Guid
	       LEFT JOIN mt000 mt on mt.GUID = updatedMat.GUID
	WHERE mt.GUID IS NULL
	
	SET @newMatCount = @@ROWCOUNT
	
	------------------------------------------------------------------------------------
	ALTER TABLE [mt000] ENABLE TRIGGER ALL
	------------------------------------------------------------------------------------
	
	DELETE PFCSyncResult000 WHERE DATE = @date
	INSERT INTO PFCSyncResult000 
	       (Date, Type, NewMatCount, UpdatedMatCount) VALUES 
	       (@date, @syncNewOnly, @newMatCount, @updatedMatCount)
END
###################################################################
CREATE PROC prcSyncPFCGroups
AS
BEGIN
	SET NOCOUNT ON

	-----------------------------------------------------------------------
	ALTER TABLE [gr000] DISABLE TRIGGER ALL
	-----------------------------------------------------------------------

	UPDATE gr000 SET
		[Number] = updatedGroup.Number
		,[Code] = updatedGroup.Code
		,[Name] = updatedGroup.Name
		,[Notes] = updatedGroup.Notes
		,[Security] = updatedGroup.Security
		,[GUID] = updatedGroup.GUID
		,[Type] = updatedGroup.Type
		,[VAT] = updatedGroup.VAT
		,[LatinName] = updatedGroup.LatinName
		,[ParentGUID] = updatedGroup.ParentGUID
		,[branchMask] = updatedGroup.branchMask
		,[Kind] = updatedGroup.Kind
	FROM 
		PFCUpdatedGroup000 updatedGroup 
	WHERE 
		gr000.GUID = updatedGroup.GUID
	-----------------------------------------------------------------------

	INSERT INTO gr000
		([Number]
		,[Code]
		,[Name]
		,[Notes]
		,[Security]
		,[GUID]
		,[Type]
		,[VAT]
		,[LatinName]
		,[ParentGUID]
		,[branchMask]
		,[Kind])
	SELECT
		updatedGroup.Number
		,updatedGroup.Code
		,updatedGroup.Name
		,updatedGroup.Notes
		,updatedGroup.Security
		,updatedGroup.GUID
		,updatedGroup.Type
		,updatedGroup.VAT
		,updatedGroup.LatinName
		,updatedGroup.ParentGUID
		,updatedGroup.branchMask
		,updatedGroup.Kind
	FROM PFCUpdatedGroup000 updatedGroup 
		LEFT JOIN gr000 gr on gr.GUID = updatedGroup.GUID
	WHERE 
		gr.GUID IS NULL
	
	-----------------------------------------------------------------------
	ALTER TABLE [gr000] ENABLE TRIGGER ALL
	-----------------------------------------------------------------------
END
###################################################################
CREATE PROC prcGenerateMatPricDiffBills
       @toDate DATETIME,
	   @lastConsalidateDate DATETIME,
       @IncreaseNotes NVARCHAR(500),
       @DecreaseNotes NVARCHAR(500),
       @QtyNotes NVARCHAR(100),
       @FromNotes NVARCHAR(100),
       @ToNotes NVARCHAR(100)
AS
BEGIN
       SET NOCOUNT ON 

       DECLARE @fromDate DATETIME = (SELECT MAX([date]) FROM MaterialPriceHistory000 WHERE [date] < @toDate)

       IF(@fromDate IS NULL)
              RETURN

       DECLARE @centerPrice INT = dbo.fnOption_GetInt('PFC_CenterPriceBox', '0')
       
       DECLARE @PriceDiff TABLE
       (
              FMatGuid UNIQUEIDENTIFIER,
              TMatGuid UNIQUEIDENTIFIER,
              FPrice FLOAT,
              TPrice FLOAT,
              Diff FLOAT
       )
       
       INSERT INTO @PriceDiff
       SELECT FD.MatGuid, TD.MatGuid,
              CASE @centerPrice 
                     WHEN 4 THEN FD.Whole 
                     WHEN 8 THEN FD.Half        
                     WHEN 16 THEN FD.Export     
                     WHEN 32 THEN FD.Vendor     
                     WHEN 64 THEN FD.Retail     
                     WHEN 128 THEN FD.EndUser   
              END,
              CASE @centerPrice 
                     WHEN 4 THEN TD.Whole
                     WHEN 8 THEN TD.Half
                     WHEN 16 THEN TD.Export
                     WHEN 32 THEN TD.Vendor
                     WHEN 64 THEN TD.Retail
                     WHEN 128 THEN TD.EndUser
              END,
              CASE @centerPrice 
                     WHEN 4 THEN TD.Whole - FD.Whole    
                     WHEN 8 THEN TD.Half        - FD.Half            
                     WHEN 16 THEN TD.Export     - FD.Export   
                     WHEN 32 THEN TD.Vendor     - FD.Vendor   
                     WHEN 64 THEN TD.Retail     - FD.Retail   
                     WHEN 128 THEN TD.EndUser- FD.EndUser     
              END
       FROM 
              MaterialPriceHistory000 FD INNER JOIN
              MaterialPriceHistory000 TD on FD.MatGuid = TD.MatGuid
       WHERE 
              FD.[Date] = @fromDate AND TD.[Date] = @toDate
       ----------------------------------------------------------------------
  
       DECLARE @MatQty TABLE
       (
              MatGuid UNIQUEIDENTIFIER,
              Unity NVARCHAR(255),
              Qty FLOAT
       )

       INSERT INTO @MatQty
       SELECT 
              BI.biMatPtr,
              Unity,
              SUM((BI.biQty + BI.biBonusQnt) * BI.buDirection)
       FROM 
              vwBuBi BI INNER JOIN mt000 mt on bi.biMatPtr = mt.GUID
       WHERE
              BI.buIsPosted = 1
              AND (CAST(BI.buDate AS DATE) <= @lastConsalidateDate)
       GROUP BY
              BI.biMatPtr,
              Unity
       --------------------------------------------------------------------------------

       DECLARE
              @IncreaseBillGUID UNIQUEIDENTIFIER,
              @IncreaseBillTypeGUID UNIQUEIDENTIFIER,
              @DecreaseBillGUID UNIQUEIDENTIFIER,
              @DecreaseBillTypeGUID UNIQUEIDENTIFIER,
              @DefCurrency UNIQUEIDENTIFIER,
              @DefStoreGuid UNIQUEIDENTIFIER,
              @IncNumber INT,
              @DecNumber INT,
              @TotalIncrease FLOAT,
              @TotalDecrease FLOAT

       --------------------------------------------------------------------
       
       SET    @IncreaseBillGUID = NEWID()
       SET    @DecreaseBillGUID = NEWID()
       SET    @IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_IncreasePricesBillType'))
       SET    @DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_DecreasePricesBillType'))

       DELETE bu000 WHERE CAST([Date] AS DATE) = @toDate AND TypeGUID IN (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID)

       SET @IncNumber = (SELECT MAX(Number) FROM bu000 WHERE TypeGUID = @IncreaseBillTypeGUID)
       SET @DecNumber = (SELECT MAX(Number) FROM bu000 WHERE TypeGUID = @DecreaseBillTypeGUID)
       SET @DefCurrency = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='AmnCfg_DefaultCurrency'))
       SET @DefStoreGuid = (SELECT DefStoreGUID FROM bt000 WHERE GUID = @IncreaseBillTypeGUID)

       IF NOT EXISTS (SELECT * FROM @PriceDiff)
              RETURN

       SET @TotalIncrease = (SELECT ISNULL(SUM(Diff * Qty), 0) FROM @PriceDiff DIFF INNER JOIN @MatQty MQ ON DIFF.TMatGuid = MQ.MatGuid WHERE Diff > 0)
       SET @TotalDecrease = (SELECT ISNULL(SUM(ABS(Diff * Qty)), 0) FROM @PriceDiff DIFF INNER JOIN @MatQty MQ ON DIFF.TMatGuid = MQ.MatGuid WHERE Diff < 0)

       IF(ISNULL(@TotalIncrease, 0) <> 0)
       BEGIN
              INSERT INTO bu000(
                     Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, Profits, 
                     IsPosted, Security, Vendor, SalesManPtr, Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, CustAccGUID, 
                     MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID)
              SELECT
                     ISNULL(@IncNumber, 0) + 1,
                     '',
                     @toDate,
                     1,
                     @IncreaseNotes,
                     0,
                     0, -- payType
                     0, -- totalDisc
                     0,
                     0, -- itemsDisc
                     0, -- bonusDisc
                     0, -- firstPay
                     0, -- profits
                     0, -- isPosted
                     1,
                     0, -- vendor
                     0, -- salesManPtr
                     0x0,
                     0, -- vat
                     @IncreaseBillGUID,
                     @IncreaseBillTypeGUID,
                     0x0, -- CustGUID
                     @DefCurrency,
                     @DefStoreGuid,       
                     DefCashAccGUID,
                     DefBillAccGUID,
                     0x0, -- ItemsDiscAccGUID
                     0x0, -- bonusDiscAccGUID
                     0x0, -- FPayAccGUID
                     0x0,
                     0x0, -- userGUID
                     0x0 -- CheckTypeGUID
              FROM bt000
              WHERE GUID = @IncreaseBillTypeGUID

              INSERT INTO bi000(
                     Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, Notes, Profits, 
                     Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height, VAT, VATRatio, 
                     ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID)
              SELECT
                     0,
                     Qty,
                     0, -- order
                     0, -- order qnt
                     1,
                     Diff,
                     0, -- bonusQnt
                     0, -- discount
                     0, -- bonusDisc
                     0, -- extra
                     1,
                     '(' + @IncreaseNotes + ' ' + @QtyNotes + ' ' + CAST(Qty AS nvarchar(10)) + ' ' + Unity + ' ' 
                           + @FromNotes + ' ' + CAST(FPrice as nvarchar(10)) + ' ' + @ToNotes + ' ' + CAST(TPrice as nvarchar(10)) + ')',
                     0, -- profits,
                     0, -- num1
                     0, -- num2
                     0,
                     0,
                     '',
                     '1980-01-01',
                     '1980-01-01',
                     '',
                     '',
                     '',
                     0,
                     0,
                     @IncreaseBillGUID,
                     TMatGuid,
                     @DefCurrency,
                     @DefStoreGuid,
                     0x0
              FROM @PriceDiff diff 
                     INNER JOIN @MatQty mt ON diff.TMatGuid = mt.MatGuid
              WHERE Qty * Diff > 0

              EXEC prcBill_GenEntry @IncreaseBillGUID
       END

       IF(ISNULL(@TotalDecrease, 0) <> 0)
       BEGIN
              INSERT INTO bu000(
                     Number, Cust_Name, Date, CurrencyVal, Notes, Total, PayType, TotalDisc, TotalExtra, ItemsDisc, BonusDisc, FirstPay, Profits, 
                     IsPosted, Security, Vendor, SalesManPtr, Branch, VAT, GUID, TypeGUID, CustGUID, CurrencyGUID, StoreGUID, CustAccGUID, 
                     MatAccGUID, ItemsDiscAccGUID, BonusDiscAccGUID, FPayAccGUID, CostGUID, UserGUID, CheckTypeGUID)
              SELECT
                     isnull(@DecNumber, 0) + 1,
                     '',
                     @toDate,
                     1,
                     @DecreaseNotes,
                     0,
                     0, -- payType
                     0, -- totalDisc
                     0,
                     0, -- itemsDisc
                     0, -- bonusDisc
                     0, -- firstPay
                     0, -- profits
                     0, -- isPosted
                     1,
                     0, -- vendor
                     0, -- salesManPtr
                     0x0,
                     0, -- vat
                     @DecreaseBillGUID,
                     @DecreaseBillTypeGUID,
                     0x0, -- CustGUID
                     @DefCurrency,
                     @DefStoreGuid,       
                     DefCashAccGUID,
                     DefBillAccGUID,
                     0x0, -- ItemsDiscAccGUID
                     0x0, -- bonusDiscAccGUID
                     0x0, -- FPayAccGUID
                     0x0,
                     0x0, -- userGUID
                     0x0 -- CheckTypeGUID
              FROM bt000
              WHERE GUID = @DecreaseBillTypeGUID

              INSERT INTO bi000(
                     Number, Qty, [Order], OrderQnt, Unity, Price, BonusQnt, Discount, BonusDisc, Extra, CurrencyVal, Notes, Profits, 
                     Num1, Num2, Qty2, Qty3, ClassPtr, ExpireDate, ProductionDate, Length, Width, Height, VAT, VATRatio, 
                     ParentGUID, MatGUID, CurrencyGUID, StoreGUID, CostGUID)
              SELECT
                     0,
                     Qty,
                     0, -- order
                     0, -- order qnt
                     1,
                     abs(Diff),
                     0, -- bonusQnt
                     0, -- discount
                     0, -- bonusDisc
                     0, -- extra
                     1,
                     '(' + @DecreaseNotes + ' ' + @QtyNotes + ' ' + CAST(Qty AS nvarchar(10)) + ' ' + Unity + ' ' 
                           + @FromNotes + ' ' + CAST(FPrice as nvarchar(10)) + ' ' + @ToNotes + ' ' + CAST(TPrice as nvarchar(10)) + ')',
                     0, -- profits,
                     0, -- num1
                     0, -- num2
                     0,
                     0,
                     '',
                     '1980-01-01',
                     '1980-01-01',
                     '',
                     '',
                     '',
                     0,
                     0,
                     @DecreaseBillGUID,
                     TMatGuid,
                     @DefCurrency,
                     @DefStoreGuid,
                     0x0
              FROM @PriceDiff diff 
                     INNER JOIN @MatQty mt ON diff.TMatGuid = mt.MatGuid
              WHERE Qty * Diff < 0

              EXEC prcBill_GenEntry @DecreaseBillGUID
       END
END
##########################################################################################
CREATE PROC prcGetMatPricDiffBalance
	@date DATETIME
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @DecreaseBillTypeGUID UNIQUEIDENTIFIER, @IncreaseBillTypeGUID UNIQUEIDENTIFIER

	SET	@IncreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_IncreasePricesBillType'))
	SET	@DecreaseBillTypeGUID = dbo.FnStrToGuid((SELECT [Value] FROM op000 WHERE [Name] ='PFC_DecreasePricesBillType'))

	SELECT 
		bu.date, en.AccountGUID, en.ContraAccGUID, en.Debit - en.Credit Balance, en.Notes
	FROM 
		en000 en 
		INNER JOIN er000 er ON en.ParentGUID = er.EntryGUID
		INNER JOIN bu000 bu ON bu.GUID = er.ParentGUID
	WHERE bu.Date = @date and bu.TypeGUID in (@IncreaseBillTypeGUID, @DecreaseBillTypeGUID)
END
###################################################################
CREATE PROC prcDeletePricesDiffEntry
	@PFCGuid UNIQUEIDENTIFIER,
	@date DATETIME
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @entryGuid uniqueidentifier = (SELECT EntryGuid FROM PFCMaterialUpdateHistory000 WHERE PFCGuid = @PFCGuid AND Date = @date)

	UPDATE ce SET IsPosted = 0
	FROM ce000 ce inner join PFCMaterialUpdateHistory000 h on ce.GUID = h.EntryGuid
	WHERE PFCGuid = @PFCGuid AND CAST(h.Date AS DATE) = @date

	DELETE ce 
	FROM ce000 ce inner join PFCMaterialUpdateHistory000 h on ce.GUID = h.EntryGuid
	WHERE PFCGuid = @PFCGuid AND CAST(h.Date AS DATE) = @date

	DELETE PFCMaterialUpdateHistory000 WHERE PFCGuid = @PFCGuid AND DATE = @date
END
###################################################################
#END