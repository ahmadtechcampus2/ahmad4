########################################
##
CREATE function fnDistGetNewAccNum()
RETURNS float
AS 
begin
	DECLARE @Number float
	SELECT @Number = ISNULL(Max(Number), 0) + 1 FROM AC000
	RETURN @Number
end
########################################
##
CREATE function fnDistGetNewCuNum()
RETURNS float
AS 
begin
	DECLARE @Number float
	SELECT @Number = ISNULL(Max(Number), 0) + 1 FROM Cu000
	RETURN @Number
end
########################################
##
CREATE function fnDistGetNewBillNum(@TypeGUID AS uniqueidentifier)
RETURNS float
AS 
begin
	DECLARE @Number float
	SELECT @Number = ISNULL(Max(Number), 0) + 1 FROM Bu000 WHERE TypeGUID = @TypeGUID
	RETURN @Number
end
########################################
##
CREATE PROCEDURE prcDist_GenEntry
		@TypeGUID		[uniqueidentifier],
		@CustGUID		[uniqueidentifier],
		@CostGUID		[uniqueidentifier],
		@Debit			[FLOAT],
		@Credit			[FLOAT],
		@Date			[DATETIME],
		@Notes			[NVARCHAR](250)
AS
	SET NOCOUNT ON
	DECLARE @CurrencyGUID [uniqueidentifier]
	DECLARE @CurrencyVal [FLOAT]
	DECLARE @DefAccGUID [uniqueidentifier]
	DECLARE @AccountGUID [uniqueidentifier]
	DECLARE @pyNewNumber [INT]
	DECLARE @ceNewNumber [INT]
	DECLARE @ErParentType [INT]
	DECLARE @Value [FLOAT]
	DECLARE @IsDebit [BIT]

	SELECT TOP 1 @CurrencyGUID = [GUID] FROM [MY000] WHERE [CurrencyVal] = 1
	SET @CurrencyVal = 1
	SELECT @DefAccGUID = [DefAccGUID] FROM [ET000] WHERE [GUID] = @TypeGUID
	SELECT @AccountGUID = [AccountGUID] FROM [CU000] WHERE [GUID] = @CustGUID
	SELECT @pyNewNumber = Max([Number]) + 1 FROM [PY000] WHERE [TypeGUID] = @TypeGUID
	SET @pyNewNumber = ISNULL(@pyNewNumber, 1)
	SELECT @ceNewNumber = Max([Number]) + 1 FROM [CE000]
	SET @ceNewNumber = ISNULL(@ceNewNumber, 1)
	SET @ErParentType = 4
	IF (@Debit > 0)
	BEGIN
		SET @Value = @Debit
		SET @IsDebit = 1
	END
	ELSE
	BEGIN
		SET @Value = @Credit
		SET @IsDebit = 0
	END
	
	DECLARE @PyGUID [uniqueidentifier]
	DECLARE @CeGUID [uniqueidentifier]
	SET @PyGUID = newID()
	SET @CeGUID = newID()
	--- py000
	INSERT INTO [PY000]	
	(
		[Number], 
		[Date], 
		[Notes], 
		[CurrencyVal], 
		[Skip], 
		[Security], 
		[Num1], 
		[Num2], 
		[GUID], 
		[TypeGUID], 
		[AccountGUID], 
		[CurrencyGUID], 
		[BranchGUID]
	)
	VALUES
	(
		@pyNewNumber,
		@Date,
		@Notes,
		@CurrencyVal,
		0,		-- Skip
		1,		-- Security
		0,		-- Num1
		0,		-- Num2
		@PyGUID,		
		@TypeGUID,
		@DefAccGUID,
		@CurrencyGUID,
		0x0
	)
	--ce000
	INSERT INTO	[CE000]
	(
		[Type], 
		[Number], 
		[Date], 
		[Debit], 
		[Credit], 
		[Notes], 
		[CurrencyVal], 
		[IsPosted], 
		[State], 
		[Security], 
		[Num1], 
		[Num2], 
		[Branch], 
		[GUID], 
		[CurrencyGUID], 
		[TypeGUID]
	)
	VALUES
	(
		1,	--Type
		@ceNewNumber,
		@Date,
		CASE WHEN @Debit > 0 THEN @Debit ELSE @Credit END,
		CASE WHEN @Debit > 0 THEN @Debit ELSE @Credit END,
		@Notes,		
		@CurrencyVal,
		0,	-- IsPosted
		0,	-- State
		1,	-- Security
		0,	-- Num1
		0,	-- Num2
		0x0,	-- Branch
		@CeGUID,
		@CurrencyGUID,
		@TypeGUID
	)
	-- en000
	INSERT INTO [EN000]
	(
		[Number], 
		[Date], 
		[Debit], 
		[Credit], 
		[Notes], 
		[CurrencyVal], 
		[Class], 
		[Num1], 
		[Num2], 
		[Vendor], 
		[SalesMan], 
		[GUID], 
		[ParentGUID], 
		[AccountGUID], 
		[CurrencyGUID], 
		[CostGUID], 
		[ContraAccGUID]
	)
	VALUES
	(
		0,	--Number
		@Date,
		CASE WHEN @IsDebit=1 THEN @Value ELSE 0.0 END,	
		CASE WHEN @IsDebit=0 THEN @Value ELSE 0.0 END,	
		@Notes,
		@CurrencyVal,
		0,	-- class
		0,	-- Num1
		0,	-- Num2
		0,	-- Vendor
		0,	-- SalesMan
		newID(),
		@CeGUID,
		@AccountGUID,
		@CurrencyGUID,
		@CostGUID,
		@DefAccGUID		
	)
	INSERT INTO [EN000]
	(
		[Number], 
		[Date], 
		[Debit], 
		[Credit], 
		[Notes], 
		[CurrencyVal], 
		[Class], 
		[Num1], 
		[Num2], 
		[Vendor], 
		[SalesMan], 
		[GUID], 
		[ParentGUID], 
		[AccountGUID], 
		[CurrencyGUID], 
		[CostGUID], 
		[ContraAccGUID]
	)
	VALUES
	(
		1,	--Number
		@Date,
		CASE WHEN @IsDebit=0 THEN @Value ELSE 0.0 END,	
		CASE WHEN @IsDebit=1 THEN @Value ELSE 0.0 END,	
		@Notes,
		@CurrencyVal,
		0,	-- class
		0,	-- Num1
		0,	-- Num2
		0,	-- Vendor
		0,	-- SalesMan
		newID(),
		@CeGUID,
		@DefAccGUID,		
		@CurrencyGUID,
		@CostGUID,
		@AccountGUID
	)
	-- er000
	INSERT INTO [ER000]
	(
		[GUID], 
		[EntryGUID], 
		[ParentGUID], 
		[ParentType], 
		[ParentNumber]
	)
	VALUES
	(
		newid(),
		@CeGUID,
		@PyGUID,
		@ErParentType,
		@pyNewNumber		
	)
	-- Post
	UPDATE [CE000]
	SET
		[IsPosted] = 1
	WHERE
		[GUID] = @CeGUID
########################################
CREATE PROC prcDist_GenerateEntrys
		@TripGUID uniqueidentifier = 0x0
AS

	DECLARE @DistributorGUID uniqueidentifier
	SELECT @DistributorGUID = DistributorGUID FROM DistTr000 WHERE GUID = @TripGUID

	DECLARE @CashAccGUID uniqueidentifier
	DECLARE @CurrencyGUID uniqueidentifier
	DECLARE @CurrencyVal float
	DECLARE @FirstCeNumber float
	DECLARE @FirstPyNumber float
	DECLARE @CostGUID uniqueidentifier

	SELECT @FirstCeNumber = ISNULL(Max(Number) + 1, 1) FROM CE000
	SELECT @FirstPyNumber = ISNULL(Max(Number) + 1, 1) FROM Py000
	SELECT @CurrencyGUID = GUID FROM MY000 WHERE Number = 1
	SELECT @CurrencyVal = CurrencyVal FROM MY000 WHERE Number = 1
	DECLARE @SalesManGUID uniqueidentifier
	SELECT @SalesManGUID = PrimSalesManGUID FROM Distributor000 WHERE GUID = @DistributorGUID
	SELECT @CostGUID = CostGUID FROM DistSalesMan000 WHERE GUID = @SalesManGUID
	SET @CostGUID = ISNULL(@CostGUID, 0x00)
	SELECT @CashAccGUID = AccountGUID FROM Distributor000 WHERE GUID = @DistributorGUID 
	SET @CashAccGUID = ISNULL(@CashAccGUID, 0x00)

	DECLARE @ErParentType int
	SET @ErParentType = 4 

	-------------------------------------
	CREATE TABLE #Payment(
		Number int,
		TypeGUID uniqueidentifier,    
		CustGUID uniqueidentifier,    
		Debit float,    
		Credit float,    
		[Date] Datetime,    
		Notes NVARCHAR(250) COLLATE ARABIC_CI_AI   
	)   
	INSERT INTO #Payment   
	SELECT
		en.Number,
		pg1.GUID,   
		pg2.GUID,   
		en.Debit,   
		en.Credit,   
		CAST([en].[Date] AS DateTime),   
		en.Notes   
	FROM   
		PalmEN AS en   
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = en.Type   
		INNER JOIN PalmGUID AS pg2 ON pg2.Number = en.Account   
	WHERE   
		TripGUID = @TripGUID AND
		Flag = 0
		
	-------------------------------------

	CREATE Table #Header(Number int IDENTITY(0,1), [GUID] [uniqueidentifier], [TypeGUID] [uniqueidentifier], [Date] [datetime], Debit float, Credit Float)
	INSERT INTO #Header
	SELECT
		newid(),
		TypeGUID,
		[Date],
		sum(Debit),
		sum(Credit)
	FROM
		#Payment
	GROUP BY
		TypeGUID,
		[Date]
	
	CREATE TABLE #Detail(
			Number float,
			Date datetime,
			Debit float,
			Credit float,
			Notes NVARCHAR(250) COLLATE ARABIC_CI_AI,
			CurrencyVal float,
			class int,
			Num1 float,
			Num2 float,
			Vendor int,
			SalesMan int,
			GUID uniqueidentifier,
			ParentGUID uniqueidentifier,
			AccountGUID uniqueidentifier,
			CurrencyGUID uniqueidentifier,
			CostGUID uniqueidentifier,
			ContraAccGUID uniqueidentifier
	)
	INSERT INTO #Detail
	SELECT
		d.Number,
		h.Date,
		d.Debit,
		d.Credit,
		d.Notes,
		@CurrencyVal,
		0,
		0,
		0,
		0,
		0,
		NEWID(),--d.GUID,
		h.GUID,
		ISNULL((SELECT TOP 1 AccountGUID FROM CU000 WHERE GUID = d.CustGUID), 0x00),
		@CurrencyGUID,
		@CostGUID, --d.CostGUID,
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END
	FROM
		#Header AS h
		INNER JOIN #Payment AS d ON d.TypeGUID = h.TypeGUID AND h.Date = d.Date
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID
		--INNER JOIN CU000 AS cu ON cu.GUID = d.CustGUID

	INSERT INTO CE000 (
		Type, Number, Date, Debit, Credit, Notes, CurrencyVal, IsPosted, State, Security, Num1, Num2, Branch, GUID, CurrencyGuid, TypeGuid, IsPrinted 
	)
	SELECT
		1 AS Type,
		(Number + @FirstCeNumber) AS CeNumber,
		Date,
		CASE Debit WHEN 0 THEN Credit ELSE DEBIT END AS Debit,
		CASE Debit WHEN 0 THEN Credit ELSE DEBIT END AS Credit,
		'',
		@CurrencyVal,
		0 AS IsPosted,
		0 AS State,
		1 AS Security,
		0 AS Num1,
		0 AS Num2,
		0x0 AS Branch,
		GUID,
		@CurrencyGUID,
		TypeGUID,
		0
	FROM
		#Header

	INSERT INTO Py000(
		Number, DAte, Notes, CurrencyVal, Skip, Security, Num1, Num2, GUID, TypeGUID, AccountGUID, CurrencyGUID, BranchGUID 
	) 
	SELECT
		(h.Number + @FirstPyNumber) AS PyNumber,
		h.Date,
		'',
		@CurrencyVal,
		0 AS [Skip],
		1 AS Security,
		0 AS Num1,
		0 AS Num2,
		h.GUID,
		h.TypeGUID,
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END,
		@CurrencyGUID,
		0x0 AS Branch
	FROM
		#Header AS h
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID

	INSERT INTO EN000( 
		Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGuid, CostGUID, ContraAccGUID
	) 
	SELECT * FROM #Detail

	INSERT INTO EN000( 
		Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGuid, CostGUID, ContraAccGUID
	) 
	SELECT
		0,
		h.Date,
		h.Credit,
		h.Debit,
		'',
		@CurrencyVal,
		0,
		0,
		0,
		0,
		0,
		NEWID(),--d.GUID,
		h.GUID,
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END,
		@CurrencyGUID,
		@CostGUID,
		0x00
	FROM
		#Header AS h
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID

	INSERT INTO [ER000] 
	( 
		[GUID],  
		[EntryGUID],  
		[ParentGUID],  
		[ParentType],  
		[ParentNumber] 
	)
	SELECT
		newid(),
		GUID,
		GUID,
		@ErParentType,
		Number + @FirstPyNumber
	FROM
		#Header

	---- post Entries
	UPDATE [CE000]
	SET
		[IsPosted] = 1
	FROM
		#Header AS h INNER JOIN CE000 AS ce ON ce.GUID = h.GUID
########################################
######## prc_DistPostTrip
CREATE PROC prc_DistPostTrip
	@TripGUID	uniqueidentifier        
AS      
	
	SET NOCOUNT ON  
	DECLARE @CurrencyGUID uniqueidentifier       
	DECLARE @CurrencyVal float        
	SELECT @CurrencyGUID = GUID, @CurrencyVal = CurrencyVal FROM My000 WHERE Number = 1        
	DECLARE @DistributorGUID	uniqueidentifier       
	DECLARE @StoreGUID	uniqueidentifier       
	DECLARE @CostGUID	uniqueidentifier       
	DECLARE @SalesManGUID	uniqueidentifier       
	DECLARE @DefCashAccGUID uniqueidentifier       
	DECLARE @CustAccGUID	uniqueidentifier       
	DECLARE @TripDate datetime      
	DECLARE @CurDate datetime      
	SET @CurDate = getDate()      
	DECLARE @CurDateStr AS NVARCHAR(100)      
	SET @CurDateStr = CAST(datepart(year, @CurDate) AS NVARCHAR(10)) + '-' + CAST(datepart(month, @CurDate) AS NVARCHAR(10)) + '-' + CAST(datepart(day, @CurDate) AS NVARCHAR(10)) + '-' + CAST(datepart(hour, @CurDate) AS NVARCHAR(10)) + '-' + CAST(datepart(minute, @CurDate) AS NVARCHAR(10)) + '-' + CAST(datepart(second, @CurDate) AS NVARCHAR(10))      
	--PRINT @CurDateStr      
	SELECT @DistributorGUID = DistributorGUID, @TripDate = date FROM DistTr000 WHERE GUID = @TripGUID       
	SELECT        
		@StoreGUID = StoreGUID,        
		@SalesManGUID = PrimSalesManGUID,       
		@CustAccGUID = CustAccGUID       
	FROM        
		Distributor000 WHERE GUID = @DistributorGUID       
	       
	SELECT @CostGUID = CostGUID, @DefCashAccGUID = AccGUID FROM DIstSalesMan000 WHERE GUID = @SalesManGUID       
	DECLARE @StrDate NVARCHAR(100)      
	SET @StrDate = CAST(DatePart(month, @TripDate) AS NVARCHAR(10)) + '-' + CAST(DatePart(day, @TripDate) AS NVARCHAR(10)) + '-' + CAST(DatePart(Year, @TripDate) AS NVARCHAR(10))      
	SET @TripDate = CAST(@StrDate AS Datetime)      
	-------------- CU ---------------------       
	IF EXISTS (SELECT * FROM PalmCU WHERE TripGUID = @TripGUID)       
	BEGIN     
		----------------------------------------------------     
		UPDATE PalmCU SET Barcode = ''     
		FROM    
			PalmCU AS pcu    
			INNER JOIN CU000 AS cu ON cu.Barcode = pcu.Barcode    
		WHERE    
			TripGUID = @TripGUID    
		----------------------------------------------------     
		UPDATE PalmCU      
		SET      
			GUID = pg.GUID      
		FROM      
			PalmCU AS pcu      
			INNER JOIN PalmGUID AS pg ON pg.Number = pcu.Number      
		WHERE     
			pcu.Flag & 0x0001 = 0 AND     
			pcu.Flag & 0x0002 <> 0     
		----------------------------------------------------     
		UPDATE PalmCU SET AccGUID = NewID(), ParentGUID = @CustAccGUID WHERE TripGUID = @TripGUID       
		----------------------------------------------------     
		INSERT INTO AC000       
		(       
			Number, Name, Code, CDate, NSons, Debit, Credit, InitDebit, InitCredit, UseFlag, MaxDebit, Notes, CurrencyVal, Warn, CheckDate, Security, DebitOrCredit, Type, State, Num1, Num2, LatinName, GUID, ParentGUID, FinalGUID, CurrencyGUID, BranchGUID, branchMask       
		)       
		SELECT       
			dbo.fnDistGetNewAccNum() 	AS Number,       
			pcu.CustomerName + @CurDateStr			AS Name,       
			pcu.CustomerName + @CurDateStr			AS Code,       
			ac.CDate,        
			0							AS NSons,        
			ac.Debit,        
			ac.Credit,        
			ac.InitDebit,        
			ac.InitCredit,        
			ac.UseFlag,        
			ac.MaxDebit,        
			ac.Notes,        
			ac.CurrencyVal,        
			ac.Warn,        
			ac.CheckDate,        
			ac.Security,        
			ac.DebitOrCredit,        
			ac.Type,        
			ac.State,        
			ac.Num1,        
			ac.Num2,        
			ac.LatinName,        
			pcu.AccGUID					AS GUID,       
			pcu.ParentGUID				AS ParentGUID,       
			ac.FinalGUID,        
			ac.CurrencyGUID,        
			ac.BranchGUID,        
			ac.branchMask		       
		FROM       
			PalmCu AS pcu       
			INNER JOIN Ac000 AS ac ON ac.GUID = pcu.ParentGUID       
		WHERE        
			TripGUID = @TripGUID  AND     
			pcu.Flag & 0x0001 <> 0     
		----------------------------------------------------     
		INSERT INTO CU000(GUID, Number, CustomerName, Phone1,Barcode, AccountGUID)       
		SELECT       
			pcu.GUID,       
			dbo.fnDistGetNewCuNum() 	AS Number,       
			pcu.CustomerName,       
			pcu.Phone,      
			ISNULL(pcu.Barcode, ''),      
			pcu.AccGUID       
		FROM       
			PalmCU AS pcu       
		WHERE        
			TripGUID = @TripGUID  AND     
			pcu.Flag & 0x0001 <> 0     
		----------------------------------------------------    
		DECLARE @CuGUID uniqueidentifier    
		DECLARE @CuBarcode NVARCHAR(100)    
		    
		DECLARE c CURSOR FOR     
		SELECT GUID , Barcode    
		FROM PalmCU    
			WHERE        
				TripGUID = @TripGUID  AND     
				Flag & 0x0002 <> 1     
		OPEN c    
		FETCH NEXT FROM c INTO @CuGUID, @CuBarcode    
		    
		WHILE @@FETCH_STATUS = 0    
		BEGIN    
			IF EXISTS (SELECT GUID FROM CU000 WHERE Barcode = @CuBarcode)    
				UPDATE CU000 SET Barcode = '' WHERE Barcode = @CuBarcode  
			UPDATE CU000 SET Barcode = @CuBarcode WHERE GUID = @CuGUID    
			FETCH NEXT FROM c INTO @CuGUID, @CuBarcode    
		END    
		    
		CLOSE c    
		DEALLOCATE c    
		--UPDATE CU000      
		--SET     
		--	BarCode = pcu.BarCode     
		--FROM     
		--	CU000 AS cu INNER JOIN PalmCu AS pcu ON pcu.GUID = cu.GUID     
		--WHERE        
		--	pcu.TripGUID = @TripGUID  AND     
		--	pcu.Flag & 0x0002 <> 1     
		----------------------------------------------------    
		-- INSERT INTO DistCe000(GUID, CustomerGUID, DistributorGUID)     
		INSERT INTO DistCe000(GUID, CustomerGUID)     
		SELECT     
			newid(),     
			pcu.GUID     
			-- ISNULL(pcu.Barcode, ''),     
			-- @DistributorGUID     
		FROM     
			PalmCU AS pcu	       
		WHERE        
			TripGUID = @TripGUID  AND     
			pcu.Flag & 0x0001 <> 0     
		INSERT INTO DistDistributionLines000 (Guid, CustGuid, DistGuid)  
		SELECT     
			newid(),     
			pcu.GUID,     
			@DistributorGUID     
		FROM     
			PalmCU AS pcu	       
		WHERE        
			TripGUID = @TripGUID  AND     
			pcu.Flag & 0x0001 <> 0     
		----------------------------------------------------     
		INSERT INTO PalmGUID            
		SELECT DISTINCT            
			cu.GUID            
		FROM            
			PalmCU AS cu       
			LEFT JOIN PalmGUID AS pg ON cu.GUID = pg.GUID      
		WHERE            
			TripGUID = @TripGUID AND      
			pg.GUID IS NULL       
		----------------------------------------------------     
		UPDATE PalmBu SET CustPtr = pg.Number       
		FROM       
			PalmGUID AS pg, PalmCU AS cu, PalmBu AS bu       
		WHERE       
			pg.GUID = cu.GUID AND cu.Number = bu.CustPtr       
		UPDATE PalmVisit SET CustId = pg.Number       
		FROM       
			PalmGUID AS pg, PalmCU AS cu, PalmVisit AS vi       
		WHERE       
			pg.GUID = cu.GUID AND cu.Number = vi.CustId       
		----------------------------------------------------     
	END       
	-------------- BU ---------------------        
	CREATE TABLE #BillsNumber   ( Guid UNIQUEIDENTIFIER, Type INT DEFAULT (0), Number INT IDENTITY(0, 1) )  
	INSERT INTO  #BillsNumber   (Guid, Type) SELECT Guid, Type FROM PalmBu Order By Type, Number  
-- Select * from #BillsNumber  
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmBu000]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)	        
		DROP TABLE PalmBu000        
	SELECT TOP 0 * INTO PalmBU000 FROM BU000        
	        
	INSERT INTO PalmBu000        
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
		[IsPrinted]  
	)        
	SELECT        
		-- dbo.fnDistGetNewBillNum(pg1.GUID) + pbu.Number - 1	AS Number,        
		dbo.fnDistGetNewBillNum(pg1.GUID) + b.Number   
			- (SELECT ISNULL((Max(Number))+1,0) FROM #BillsNumber WHERE Type = b.Type - 1)	AS Number,        
		cu.CustomerName		AS Cust_Name,        
		--@TripDate			AS Date,        
		CAST([pbu].[Date] AS DateTime)	AS Date,        
		@CurrencyVal		AS CurrencyVal,        
		pbu.Notes			AS Notes,        
		pbu.Total			AS Total,        
		pbu.PayType			AS PayType,        
		pbu.TotalDisc		AS TotalDisc,        
		pbu.TotalExtra		AS TotalExtra,        
		pbu.TotalItemDisc	AS ItemDisc,        
		0					AS BonusDisc,        
		FirstPay			AS FirstPay,        
		0					AS Profits,        
		0					AS IsPosted,        
		1					AS Security,        
		0					AS Vindor,        
		0					AS SalesManPtr,        
		0x0					AS Branch,        
		0					AS Vat,        
		pbu.GUID			AS GUID,        
		pg1.GUID			AS TypeGUID,        
		pg2.GUID			AS CustGUID,        
		@CurrencyGUID		AS CurrencyGUID,        
		@StoreGUID			AS StoreGUID, 		-- pg3.GUID       
		case pbu.PayType when 1 then (SELECT TOP 1 AccountGUID FROM CU000 WHERE GUID = pg2.GUID) when 0 then @DefCashAccGUID end AS CustAccGUID,        
		0x00, --(SELECT TOP 1 DefBillAccGUID FROM Bt000 WHERE GUID = pg1.GUID)	AS MatAccGUID,        
		0x00, --(SELECT TOP 1 DefDiscAccGUID FROM Bt000 WHERE GUID = pg1.GUID)	AS ItemDiscAccGUID,        
		0x00, --(SELECT TOP 1 DefBonusAccGUID FROM Bt000 WHERE GUID = pg1.GUID)	AS BonusDiscAccGUID,        
		--(SELECT TOP 1 DefCashAccGUID FROM Bt000 WHERE GUID = pg1.GUID)	AS FPayAccGUID,        
		@DefCashAccGUID		AS DefCashAccGUID,       
		@CostGUID			AS CostGUID, 		--pg4.GUID       
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
		0
	FROM        
		PalmBu AS pbu        
		INNER JOIN #BillsNumber AS b ON b.Guid = pbu.Guid  
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = pbu.Type        
		INNER JOIN PalmGUID AS pg2 ON pg2.Number = pbu.CustPtr        
		INNER JOIN DistTr000 AS tr ON tr.GUID = pbu.TripGUID      
		INNER JOIN Cu000 AS cu ON cu.GUID = pg2.GUID      
	WHERE        
		pbu.TripGUID = @TripGUID  AND      
		pbu.Flag = 0  
	  
	-- INSERT INTO DistVd000 SELECT newID(), VisitGUID, 3, GUID, 1 	FROM PalmBu	  
	
	INSERT INTO DistVd000 ( Guid, VistGuid, Type, ObjectGuid, Flag) 
		SELECT newID(), pv.GUID, 3, pbu.GUID, 1  
	FROM   
		PalmBu AS pbu  
		INNER JOIN PalmVisit AS pv ON pv.Number = pbu.VisitIndex  
	WHERE  
		pbu.TripGUID = @TripGUID AND pv.TripGUID = @TripGUID  
	
	-------------- BI ---------------------        
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmBi000]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)	        
		DROP TABLE PalmBi000        
	SELECT TOP 0 * INTO PalmBi000 FROM Bi000        
	        
	INSERT INTO PalmBi000        
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
		[count]	        
	)        
	SELECT        
		pbi.Number,				--Number,         
		pbi.Qty,				--Qty,         
		0,						--Order,         
		0,						--OrderQnt,         
		pbi.Unity,				--Unity,         
		pbi.Price,				--Price,         
		pbi.BonusQnt,			--BonusQnt,         
		pbi.Discount,			--Discount,         
		0,						--BonusDisc,         
		0,						--Extra,         
		@CurrencyVal,			--CurrencyVal,         
		pbi.Notes,				--Notes,         
		0,						--Profits,         
		0,						--Num1,         
		0,						--Num2,         
		0,						--Qty2,         
		0,						--Qty3,         
		'',						--ClassPtr,         
		'1-1-1980',				--ExpireDate,         
		'1-1-1980',				--ProductionDate,         
		0,						--Length,         
		0,						--Width,         
		0,						--Height,         
		pbi.GUID,				--GUID,         
		0,						--VAT,         
		0,						--VATRatio,         
		pbu.GUID,				--ParentGUID,         
		pg1.GUID,				--MatGUID,         
		@CurrencyGUID,			--CurrencyGUID,         
		@StoreGUID,				--StoreGUID,  		-- pg2.GUID       
		@CostGUID,				--CostGUID,  		-- pg3.GUID       
		0,						--SOType,         
		0x0,					--SOGuid	        
		0
	FROM        
		PalmBi AS pbi        
		INNER JOIN PalmBU AS pbu ON pbu.Number = pbi.Parent AND pbu.TripGUID = @TripGUID        
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = pbi.MatPtr        
		--INNER JOIN PalmGUID AS pg2 ON pg2.Number = pbi.StorePtr        
		--INNER JOIN PalmGUID AS pg3 ON pg3.Number = pbi.CostPtr        
	WHERE        
		pbi.TripGUID = @TripGUID AND pbu.Flag = 0     
	-------------- DI ---------------------        
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmDi000]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)	        
		DROP TABLE PalmDi000        
	SELECT TOP 0 * INTO PalmDi000 FROM Di000        
	        
	INSERT INTO PalmDi000        
	(        
		Number,         
		Discount,         
		Extra,         
		CurrencyVal,         
		Notes,         
		Flag,         
		GUID,         
		ClassPtr,         
		ParentGUID,         
		AccountGUID,         
		CurrencyGUID,         
		CostGUID,         
		ContraAccGUID        
	)        
	SELECT	        
		pdi.Number,			--Number,         
		pdi.Value,			--Discount,         
		0,					--Extra,         
		@CurrencyVal,		--CurrencyVal,         
		pdi.Notes,			--Notes,         
		0,					--Flag,         
		pdi.GUID,			--GUID,         
		'',					--ClassPtr,         
		pbu.GUID,			--ParentGUID,         
		Disc.AccountGUID,	--AccountGUID,         
		@CurrencyGUID,		--CurrencyGUID,         
		@CostGUID,			--CostGUID,         
		0x0					--ContraAccGUID        
	FROM        
		PalmDi AS pdi        
		INNER JOIN PalmBU AS pbu ON pbu.Number = pdi.Parent AND pbu.TripGUID = @TripGUID        
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = pdi.DiscountPtr        
		INNER JOIN DistDisc000 AS Disc ON Disc.GUID = pg1.GUID        
	WHERE        
		pdi.TripGUID = @TripGUID AND pbu.Flag = 0     
	-------- Extra -----------  
	INSERT INTO PalmDi000        
	(        
		Number,         
		Discount,         
		Extra,         
		CurrencyVal,         
		Notes,         
		Flag,         
		GUID,         
		ClassPtr,         
		ParentGUID,         
		AccountGUID,         
		CurrencyGUID,         
		CostGUID,         
		ContraAccGUID        
	)        
	SELECT	        
		0,					--Number,         
		0,					--Discount,         
		pbu.TotalExtra,		--Extra,         
		@CurrencyVal,		--CurrencyVal,         
		'',					--Notes,         
		0,					--Flag,         
		NewID(),			--GUID,         
		'',					--ClassPtr,         
		pbu.GUID,			--ParentGUID,         
		--(SELECT TOP 1 DefExtraAccGUID FROM Bt000 WHERE GUID = pg1.GUID)	AS AccountGUID,      --AccountGUID,  
		bt.DefExtraAccGUID,  
		@CurrencyGUID,		--CurrencyGUID,         
		@CostGUID,			--CostGUID,         
		0x0					--ContraAccGUID        
	FROM        
		PalmBu000 AS pbu        
		--INNER JOIN PalmGUID AS pg1 ON pg1.Number = pbu.Type  
		INNER JOIN BT000 AS bt ON bt.GUID = pbu.TypeGUID  
	WHERE        
		pbu.TotalExtra > 0  
	UPDATE PalmDI000 SET Extra = -1 * Discount, Discount = 0 WHERE Discount < 0  
	-------------- DistVI ---------------------        
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmVi000]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)	        
		DROP TABLE PalmVi000        
	SELECT TOP 0 * INTO PalmVi000 FROM DistVi000        
	        
	INSERT INTO PalmVi000        
	(        
		Number,         
		GUID,         
		TripGUID,         
		CustomerGUID,         
		StartTime,         
		FinishTime,         
		State,   
		EntryStockOfCust,   
		EntryVisibility,
		UseCustBarcode   
	)        
	SELECT	        
		pvi.Number,		--Number,         
		pvi.GUID,		--GUID,         
		pvi.TripGUID,	--TripGUID,         
		pg1.GUID,		--CustomerGUID,         
		pvi.VisitDate + ' ' + pvi.InTime,		--StartTime, 
		'1-1-2000 ' + pvi.OutTime,		--FinishTime, 
		-- CASE ISNULL(pbu.GUID, 0x0) WHEN 0x0 THEN 0 ELSE 1 END, --State 
		-- (SELECT TOP 1 CASE ISNULL(GUID, 0x0) WHEN 0x0 THEN 0 ELSE 1 END FROM Palmbu WHERE CustPtr = pvi.CustId AND TripGUID = @TripGUID), 
		ISNULL( (SELECT TOP 1 CASE ISNULL(GUID, 0x0) WHEN 0x0 THEN 0 ELSE 1 END FROM PalmBu WHERE CustPtr = pvi.CustId AND TripGUID = @TripGUID), 0), 
		EntryStockOfCust, 
		EntryVisibility,
		0	 
	FROM        
		PalmVisit AS pvi        
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = pvi.CustId   
		-- LEFT JOIN PalmBU AS pbu ON pbu.VisitIndex = pvi.Number AND pbu.TripGUID = @TripGUID 
	WHERE        
		pvi.TripGUID = @TripGUID        
	--SELECT * FROM PalmVisit   
	--SELECT * FROM PalmVi000   
	------------------------------------        
	-------------- DistVD ---------------------        
	CREATE TABLE #lookupTbl(GUID uniqueidentifier, ID int , Type int, Number int , Name NVARCHAR(255) COLLATE Arabic_CI_AI, Used int, Flag int)   
	INSERT INTO #lookupTbl EXEC prcDistGetLookupFlages   
	INSERT INTO DistVd000 ( Guid, VistGuid, Type, ObjectGuid, Flag)   
	SELECT   
		NEWID()		AS GUID,   
		vi.GUID		AS VistGUID,   
		1			AS Type,   
		lk.GUID		AS ObjectGUID,   
		1			AS Flag   
	FROM   
		PalmVisit AS vi   
		Cross join #lookupTbl AS lk   
	WHERE   
		lk.Flag	& ActivityFlag <> 0 AND   
		vi.TripGUID = @TripGUID        
	INSERT INTO DistVd000 ( Guid, VistGuid, Type, ObjectGuid, Flag)    
	SELECT   
		NEWID()		AS GUID,   
		vi.GUID		AS VistGUID,   
		0			AS Type,   
		lk.GUID		AS ObjectGUID,   
		1			AS Flag   
	FROM   
		PalmVisit AS vi   
		Cross join #lookupTbl AS lk   
	WHERE   
		lk.Flag	& UnBuyFlag <> 0 AND   
		vi.TripGUID = @TripGUID        
	   
	-------------- DistCm ---------------------        
	CREATE TABLE #Cm (CustGUID uniqueidentifier, MatGUID uniqueidentifier, Qty float, Type int, VisitDate DateTime)  
	INSERT INTO #Cm  
		SELECT bu.CustGUID, bi.MatGUID, bi.Qty, 1, bu.Date  
	FROM   
		PalmBi000 AS bi   
		INNER JOIN PalmBu000 AS bu ON bi.ParentGUID = bu.GUID      
		--INNER JOIN PalmVisit AS pvi ON pvi.GUID = bu.VisitGUID  
	-- /*
	INSERT INTO #Cm      
	SELECT      
		pg1.GUID,      
		pg2.GUID,      
		CurStock,      
		2,  
		pvi.VisitDate  
	FROM      
		PalmCm AS cm      
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = cm.CustPtr        
		INNER JOIN PalmGUID AS pg2 ON pg2.Number = cm.MatPtr        
		INNER JOIN PalmVisit AS pvi ON pvi.Number = cm.VisitIndex  
	WHERE        
		cm.TripGUID = @TripGUID  
	-- */
	INSERT INTO DistCm000        
	(        
		Number,         
		GUID,         
		Type,         
		CustomerGUID,         
		MatGUID,         
		[Date],         
		Qty,         
		Target        
	)        
	SELECT        
		0,			--Number,         
		NewID(),	--GUID,         
		0,			--Type,         
		CustGUID,	--CustomerGUID,         
		MatGUID,	--MatGUID,         
		VisitDate,--@TripDate,	--[Date],         
		Sum(CASE Type WHEN 2 THEN Qty ELSE 0 END),			--Qty + SalesQty        
		Sum(CASE Type WHEN 1 THEN Qty ELSE 0 END)			--Target        
	FROM        
		#Cm AS cm  
	GROUP BY      
		CustGUID,      
		MatGUID,  
		VisitDate  
	-------------- DistCg ---------------------        
	INSERT INTO DistCg000        
	(        
		Number,         
		GUID,         
		CustomerGUID,         
		GroupGUID,         
		[Date],         
		Visibility         
	)        
	SELECT        
		0,			-- Number,         
		cg.GUID,		-- GUID,         
		pg1.GUID,		-- CustomerGUID,         
		pg2.GUID,		-- GroupGUID,         
		@TripDate,		-- [Date],         
		cg.Visibility		-- Visibility,        
	FROM        
		PalmCg AS cg        
		INNER JOIN PalmGUID AS pg1 ON pg1.Number = cg.CustPtr        
		INNER JOIN PalmGUID AS pg2 ON pg2.Number = cg.GroupPtr        
		INNER JOIN DistTr000 AS tr ON tr.GUID = cg.TripGUID        
	WHERE        
		cg.TripGUID = @TripGUID AND   
		Visibility <> 0   
   
	-------------- SET Trip Posted ---------------------        
	UPDATE DistTr000 SET State = 2 WHERE DistributorGUID = @DistributorGUID AND State = 1       
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
		[IsPrinted]    
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
		0    
	FROM PalmBu000     
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
		[Count]        
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
		[Count]        
	FROM PalmBi000     
	INSERT INTO Di000 SELECT * FROM PalmDi000	        
	INSERT INTO DistVI000 SELECT * FROM PalmVi000   
	-----------------   New  ⁄œÌ·  «—ÌŒ «·—Õ·… ·»√Œ–  «—ÌŒ «·“Ì«—…	--------------------  
	--UPDATE DistTr000 SET [Date] = vi.StartTime FROM DistVi000 AS Vi INNER JOIN DistTr000 AS Tr ON Tr.Guid = Vi.TripGuid  
	------------------------------------------------------------------------------------  
	SELECT * FROM PalmVi000  
	------- Gen Payment      
	EXEC prcDist_GenerateEntrys @TripGUID   
	-- End Generate Payment	      
	DROP TABLE PalmBu000        
	DROP TABLE PalmBi000        
	DROP TABLE PalmDi000   
	DROP TABLE PalmVi000   
	DROP TABLE PalmVisit  
	DROP TABLE PalmCm  
	DROP TABLE PalmBu  
	DROP TABLE PalmBI  
	DROP TABLE PalmEN  
	DROP TABLE #BillsNumber  

/*
Exec prc_DistPostTrip 'A7C9FD14-6029-4A6E-8566-C1C33197FD41' 
Select * from DistTR000 Order By Date Desc
*/
########################################
##    prc_DistPostBillTrip
CREATE PROC prc_DistPostBillTrip
	@TripGUID	uniqueidentifier    
AS  

DECLARE @DistributorGUID uniqueidentifier
DECLARE @AutoPostBill bit

SELECT @DistributorGUID = DistributorGUID FROM DistTR000 WHERE GUID = @TripGUID
SELECT @AutoPostBill = AutoPostBill FROM Distributor000 WHERE GUID = @DistributorGUID

IF (@AutoPostBill = 1)
begin
	UPDATE BU000 SET ISPosted = 1 
	FROM
		BU000 AS bu
		INNER JOIN PalmBu AS pbu ON bu.GUID = pbu.GUID
		INNER JOIN Bt000 AS bt ON bu.TypeGUID = bt.GUID
	WHERE    
		pbu.TripGUID = @TripGUID  AND  
		pbu.Flag = 0  AND
		bt.bNoPost = 0 AND
		bt.bAutoPost = 1
end
#############################
#END