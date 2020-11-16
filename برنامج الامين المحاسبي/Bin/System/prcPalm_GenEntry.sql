#########################################################
CREATE PROCEDURE prcPalm_GenEntry
		@TypeGUID		[uniqueidentifier],
		@CustGUID		[uniqueidentifier],
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
		0x0,
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
		0x0,
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

#########################################################
CREATE   PROC prcPalm_InsertPalmEntry
		@TypeGUID			[uniqueidentifier], 
		@Number				[int],
		@CustGUID			[uniqueidentifier], 
		@Debit				[FLOAT], 
		@Credit				[FLOAT], 
		@Date				[DATETIME], 
		@Notes				[NVARCHAR](250) 
AS
	INSERT INTO PalmEntry(GUID, TypeGUID, Number, CustGUID, Date, Debit, Credit, CostGUID, Notes)
	SELECT
		NEWID(), @TypeGUID, @Number, @CustGUID, @Date, @Debit, @Credit, 0x0, @Notes
#########################################################
CREATE PROC prcPalm_GenerateEntrys
		@DistributorGUID uniqueidentifier = 0x0
AS
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
	SELECT @CostGUID = CostGUID FROM Pl000 WHERE GUID = @DistributorGUID 
	SET @CostGUID = ISNULL(@CostGUID, 0x00)
	SELECT @CashAccGUID = AccountGUID FROM Pl000 WHERE GUID = @DistributorGUID 
	SET @CashAccGUID = ISNULL(@CashAccGUID, 0x00)

	DECLARE @ErParentType int
	SET @ErParentType = 4 

	CREATE Table #Header(Number int IDENTITY(0,1), [GUID] [uniqueidentifier], [TypeGUID] [uniqueidentifier], [Date] [datetime], Debit float, Credit Float)
	INSERT INTO #Header
	SELECT
		newid(),
		TypeGUID,
		[Date],
		sum(Debit),
		sum(Credit)
	FROM
		PalmEntry
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
		INNER JOIN PalmEntry AS d ON d.TypeGUID = h.TypeGUID AND h.Date = d.Date
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID
		--INNER JOIN CU000 AS cu ON cu.GUID = d.CustGUID

	INSERT INTO CE000
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
		TypeGUID
	FROM
		#Header

	INSERT INTO Py000
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

	INSERT INTO EN000 SELECT * FROM #Detail

	INSERT INTO EN000
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
#########################################################
#END