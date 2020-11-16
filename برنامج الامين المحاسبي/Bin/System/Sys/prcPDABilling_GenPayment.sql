#################################################################
CREATE PROC prcPDABilling_GenPayment
		@PDAGuid uniqueidentifier = 0x0 
AS 
	SET NOCOUNT ON 
	DECLARE @CashAccGUID	uniqueidentifier, 
			--@CurrencyGUID	uniqueidentifier, 
			--@CurrencyVal	float, 
			@FirstCeNumber	float,
			@CostGUID		uniqueidentifier, 
			@BranchGUID 	UNIQUEIDENTIFIER,
			@ErParentType int 
	SELECT @FirstCeNumber = ISNULL(Max(Number) + 1, 1) FROM CE000 
	--SELECT @CurrencyGUID = GUID, @CurrencyVal = CurrencyVal  FROM MY000 WHERE Number = 1 
	SELECT @CostGuid = [CostGuid], @CashAccGUID	= [AccountGUID] FROM pl000 WHERE GUID = @PDAGuid
	SELECT @BranchGuid = ISNULL(Guid, 0x0) FROM br000 WHERE Number = 1 -- [dbo].[fnPowerOf2]([Number] - 1) = @BranchMask 
	SET @ErParentType = 4  
	IF NOT EXISTS (SELECT * FROM DistDeviceEn000 WHERE DistributorGuid = @PDAGuid)
		return
	CREATE Table #Header(
		Number int IDENTITY(0,1), 
		[GUID] [uniqueidentifier], 
		[TypeGUID] [uniqueidentifier], 
		[Date] [datetime], 
		Debit float, 
		Credit Float,
		CurrencyGuid uniqueidentifier,
		CurrencyVal Float) 
	INSERT INTO #Header 
	SELECT 
		newid(), 
		TypeGUID, 
		[Date], 
		sum(Debit) * CurrencyVal,
		sum(Credit) * CurrencyVal,
		CurrencyGuid,
		CurrencyVal
	FROM 
		DistDeviceEn000
	WHERE 
		DistributorGuid = @PDAGuid
		AND IsSync = 0 AND Deleted = 0
	GROUP BY 
		TypeGUID, 
		[Date],
		CurrencyGuid,
		CurrencyVal
	 
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
		ISNULL(d.Notes, ''), 
		h.CurrencyVal,
		0, 
		0, 
		0, 
		0, 
		0, 
		d.Guid,   -- NEWID(),--d.GUID, 
		h.GUID, 
		ISNULL((SELECT TOP 1 AccountGUID FROM CU000 WHERE GUID = d.CustomerGUID), 0x00), 
		h.CurrencyGUID,
		@CostGUID, --d.CostGUID, 
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END 
	FROM 
		#Header AS h 
		INNER JOIN DistDeviceEn000 AS d ON d.TypeGUID = h.TypeGUID AND h.Date = d.Date 
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID 
	WHERE 
		d.DistributorGuid = @PDAGuid
		AND IsSync = 0 AND Deleted = 0
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
		CurrencyVal, 
		0 AS IsPosted, 
		0 AS State, 
		1 AS Security, 
		0 AS Num1, 
		0 AS Num2, 
		@BranchGUID AS Branch, -- 0x0 AS Branch, 
		GUID, 
		CurrencyGUID,
		TypeGUID,
		0 
	FROM 
		#Header 
	INSERT INTO Py000(
		Number, 
		Date, 
		Notes, 
		CurrencyVal, 
		Skip, 
		Security, 
		Num1, 
		Num2, 
		GUID, 
		TypeGUID, 
		AccountGUID, 
		CurrencyGUID, 
		BranchGUID 
	) 
	SELECT 
		(h.Number + (SELECT ISNULL(Max(Number) + 1, 1) FROM Py000 WHERE TypeGUID = h.TypeGUID)) AS PyNumber, 
		h.Date, 
		'', 
		h.CurrencyVal,
		0 AS [Skip], 
		1 AS Security, 
		0 AS Num1, 
		0 AS Num2, 
		h.GUID, 
		h.TypeGUID, 
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END, 
		h.CurrencyGUID,
		@BranchGUID AS Branch --0x0 AS Branch 
	FROM 
		#Header AS h 
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID 
	
	INSERT INTO EN000 
	(
		Number, 
		Date, 
		Debit,
		Credit, 
		Notes, 
		CurrencyVal, 
		class, 
		Num1, 
		Num2, 
		Vendor, 
		SalesMan, 
		GUID,
		ParentGUID,
		AccountGUID,
		CurrencyGUID,
		CostGUID,
		ContraAccGUID
	)
	SELECT  
	*	
	FROM 
		#Detail 
	
	--SELECT * FROM EN000
	--SELECT * FROM #Detail 
	--return 
	
	INSERT INTO EN000( 
		Number, 
		Date, 
		Debit, 
		Credit, 
		Notes, 
		CurrencyVal, 
		Class, 
		Num1, 
		Num2, 
		Vendor, 
		SalesMan, 
		GUID, 
		ParentGUID, 
		AccountGUID, 
		CurrencyGuid, 
		CostGUID, 
		ContraAccGUID
	) 
	SELECT 
		0, 
		h.Date, 
		h.Credit, 
		h.Debit, 
		'', 
		h.CurrencyVal,
		0, 
		0, 
		0, 
		0, 
		0, 
		NEWID(),--d.GUID, 
		h.GUID, 
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END, 
		h.CurrencyGUID,
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
		Number-- + @FirstPyNumber 
	FROM 
		#Header 
	UPDATE [ER000]  
		SET ParentNumber = py.Number 
	FROM 
		ER000 AS er 
		INNER JOIN PY000 AS py ON py.GUID = er.ParentGUID 
	----------		
	DELETE DistDeviceEn000 WHERE DistributorGUID = @PDAGuid 
	---- post Entries 
	ALTER TABLE ac000 DISABLE TRIGGER trg_ac000_CheckConstraints 
	UPDATE [CE000] 
	SET 
		[IsPosted] = 1 
	FROM 
		#Header AS h INNER JOIN CE000 AS ce ON ce.GUID = h.GUID 
	ALTER TABLE ac000 ENABLE TRIGGER trg_ac000_CheckConstraints
		

/*
EXEC prcPDABilling_GenPayment 'BE799ADD-6C32-4F01-A94D-0C43DEF1828E'
*/
#################################################################
CREATE PROC prcPDABilling_GenAll
AS       
	SET NOCOUNT ON    

	DECLARE @UserName NVARCHAR(100) 
	SELECT TOP 1 @UserName = LoginName From us000 Where bAdmin = 1  
	EXEC prcConnections_add2 @UserName 

	DECLARE @PDAGuid	UNIQUEIDENTIFIER,
			@C			CURSOR

	SET @C = CURSOR FAST_FORWARD FOR  SELECT Guid FROM Pl000 WHERE LastSyncOperation = 0
	OPEN @C FETCH NEXT FROM @C INTO @PDAGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- PRINT(@PDAGuid)
		EXEC prcPDABilling_GenVisits @PDAGuid
		EXEC prcPDABilling_GenBill @PDAGuid
		EXEC prcPDABilling_GenPayment @PDAGuid
		FETCH NEXT FROM @C INTO @PDAGuid
	END
	CLOSE @C DEALLOCATE @C
#################################################################
#END