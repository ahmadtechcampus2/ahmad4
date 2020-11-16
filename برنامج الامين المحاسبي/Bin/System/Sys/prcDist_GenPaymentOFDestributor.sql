##########################################################
CREATE PROC prcDist_GenPaymentOFDestributor
		@DistributorGUID uniqueidentifier = 0x0
AS
	SET NOCOUNT ON  
	
	DECLARE	@CashAccGUID	UNIQUEIDENTIFIER,
			@FirstCeNumber	FLOAT,
			@SalesManGUID	UNIQUEIDENTIFIER,
			@CostGUID		UNIQUEIDENTIFIER,
			@BranchGUID 	UNIQUEIDENTIFIER,
			@BranchMask 	INT,
			@DistCode		NVARCHAR(100)
			
	SELECT @FirstCeNumber = ISNULL(Max(Number) + 1, 1) FROM CE000
	
	SELECT 
		@SalesManGUID = PrimSalesManGUID,	
		@BranchMask	= BranchMask,
		@DistCode = Code
	FROM 
		Distributor000 
	WHERE 
		GUID = @DistributorGUID
	SELECT @CostGUID = CostGUID, @CashAccGUID = AccGUID FROM DistSalesMan000 WHERE GUID = @SalesManGUID    
	
	SELECT 
		@BranchGuid = ISNULL(Guid, 0x0) 
		FROM br000 
	WHERE 
		[dbo].[fnPowerOf2]([Number] - 1) = @BranchMask
	
	IF (@BranchGuid IS NULL)
	SET @BranchGuid = 0x0

	/*DECLARE @CurrencyVal FLOAT

	Select @CurrencyVal = CurrencyVal  FROM my000 Where Guid = '4D44F0D0-CD6D-41B6-A717-C373BE4D0E2B'

	IF EXISTS (Select CurrencyVal FROM mh000 Where CurrencyGuid = '4D44F0D0-CD6D-41B6-A717-C373BE4D0E2B')
	BEGIN
		Select @CurrencyVal = CurrencyVal FROM mh000 Where CurrencyGuid = '4D44F0D0-CD6D-41B6-A717-C373BE4D0E2B'
	END*/
		
	SET @CostGUID = ISNULL(@CostGUID, 0x00)
	SET @CashAccGUID = ISNULL(@CashAccGUID, 0x00)

	DECLARE @postDate DATE
	SET @postDate = GetDate()
	
	DECLARE @StopDate		DATETIME ,
			@EPDate			DATETIME
	SELECT @StopDate = dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_StopDate'
	SELECT @EPDate	 = dbo.[fnDate_Amn2Sql](Value) FROM op000 WHERE Name = 'AmnCfg_EPDate'   

	IF EXISTS(SELECT * FROM DistDeviceEn000 en
				INNER JOIN et000 AS et ON et.Guid = en.TypeGuid
			WHERE DistributorGuid = @DistributorGUID 
			AND	(en.Date < @StopDate AND en.Date < @EPDate)
			AND ((et.IsStopDate = 1 AND en.Date < et.StopDate) OR et.IsStopDate = 0))
	BEGIN
		RAISERROR(N'AmnE004 : Fixed Date Of Operations > Date of Entry', 16, 1)
		RETURN
	END

	DECLARE @ErParentType int
	SET @ErParentType = 4 
	
	CREATE TABLE #Header(
		Number			INT IDENTITY(0,1), 
		[GUID]			UNIQUEIDENTIFIER, 
		[TypeGUID]		UNIQUEIDENTIFIER,
		[Date]			DATETIME, 
		Debit			FLOAT, 
		Credit			FLOAT, 
		CurrencyGuid	UNIQUEIDENTIFIER,
		CurrencyVal		FLOAT,
		Notes			NVARCHAR(2000)
	)
	
	INSERT INTO #Header
	SELECT
		newid(),
		TypeGUID,
		[Date],
		sum(Debit) * CurrencyVal,
		sum(Credit) * CurrencyVal,
		CurrencyGuid,
		CurrencyVal,
		--''
		@DistCode + '# ' + REPLACE(CONVERT(NVARCHAR, [Date], 103), '/', '-') + '#'		
	FROM
		DistDeviceEn000 
	WHERE 
		DistributorGuid = @DistributorGUID
		AND IsSync = 0 AND Deleted = 0
	GROUP BY
		@DistCode + '# ' + REPLACE(CONVERT(NVARCHAR, [Date], 103), '/', '-') + '#',
		TypeGUID,
		Date,
		CurrencyGuid,
		CurrencyVal
	
	CREATE TABLE #Detail(
			Number			FLOAT,
			Date			DATETIME,
			Debit			FLOAT,
			Credit			FLOAT,
			Notes			NVARCHAR(250) COLLATE ARABIC_CI_AI,
			CurrencyVal		FLOAT,
			class			INT,
			Num1			FLOAT,
			Num2			FLOAT,
			Vendor			INT,
			SalesMan		INT,
			GUID			UNIQUEIDENTIFIER,
			ParentGUID		UNIQUEIDENTIFIER,
			AccountGUID		UNIQUEIDENTIFIER,
			CustomerGUID	UNIQUEIDENTIFIER,
			CurrencyGUID	UNIQUEIDENTIFIER,
			CostGUID		UNIQUEIDENTIFIER,
			ContraAccGUID	UNIQUEIDENTIFIER
	)

	INSERT INTO #Detail
	SELECT
		d.Number,
		h.Date,
		d.Debit * h.CurrencyVal,
		d.Credit * h.CurrencyVal,
		CAST( '#' + CAST(d.Number AS NVARCHAR(10)) + '# ' + ISNULL(d.Notes, '') AS NVARCHAR(255)),
		h.CurrencyVal,
		0,
		0,
		0,
		0,
		0,
		d.GUID,
		h.GUID,
		ISNULL((SELECT TOP 1 AccountGUID FROM CU000 WHERE GUID = d.CustomerGUID), d.CustomerGUID),
		d.CustomerGUID,
		h.CurrencyGUID,
		@CostGUID, --d.CostGUID,
		CASE @CashAccGUID WHEN 0x0 THEN et.DefAccGUID ELSE @CashAccGUID END
	FROM
		#Header AS h
		INNER JOIN DistDeviceEn000 AS d ON d.TypeGUID = h.TypeGUID AND dbo.GetJustDate(h.Date) = dbo.GetJustDate(d.Date)
		INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID
	WHERE 
		d.DistributorGuid = @DistributorGUID
		AND d.IsSync = 0 AND Deleted = 0
	---------------------Õ· Œÿ√ «—”«· ”‰œ €Ì— ﬂ«„·---------
	IF NOt EXists (SELECT * FROM #Header)
	BEGIN
	RAISERROR ('#Header is empty', 16, 1)
	RETURN
	END
	IF NOt EXists (SELECT * FROM #Detail)
	BEGIN
	RAISERROR ('#Detail is empty', 16, 1)
	RETURN
	END
-------------------------------------------
	INSERT INTO CE000(
		Type, Number, Date, PostDate, Debit, Credit, Notes, CurrencyVal, IsPosted, State, Security, Num1, Num2, Branch, GUID, CurrencyGuid, TypeGuid
	)
	SELECT
		1 AS Type,
		(Number + @FirstCeNumber) AS CeNumber,
		Date,
		@postDate,
		CASE Debit WHEN 0 THEN Credit ELSE DEBIT END AS Debit,
		CASE Debit WHEN 0 THEN Credit ELSE DEBIT END AS Credit,
		Notes,
		CurrencyVal,
		0 AS IsPosted,
		0 AS State,
		1 AS Security,
		0 AS Num1,
		0 AS Num2,
		@BranchGUID AS Branch, -- 0x0 AS Branch,
		GUID,
		CurrencyGUID,
		TypeGUID
	FROM
		#Header
	
	INSERT INTO Py000(
		Number, Date, Notes, CurrencyVal, Skip, Security, Num1, Num2, GUID, TypeGUID, AccountGUID, CurrencyGUID, BranchGUID
	)
	SELECT
		(h.Number + (SELECT ISNULL(Max(Number) + 1, 1) FROM Py000 WHERE TypeGUID = h.TypeGUID)) AS PyNumber,
		h.Date,
		h.Notes,
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
	
	INSERT INTO EN000 (Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID,CustomerGUID, CurrencyGuid, CostGUID, ContraAccGUID) 
	SELECT * FROM #Detail 

	-------------------------------------------------------------------------------------
	DECLARE @bDetailed bit
	DECLARE @HeaderGuid uniqueidentifier
	DECLARE @HeaderTypeGUID uniqueidentifier	
	DECLARE @cur CURSOR
	
	SET @cur = CURSOR FAST_FORWARD FOR  
		SELECT 
			h.[GUID],
			h.[TypeGUID]
		FROM 
			#Header AS h 
			INNER JOIN ET000 AS et ON et.GUID = h.TypeGUID
	OPEN @cur 
	FETCH NEXT FROM @cur INTO @HeaderGuid, @HeaderTypeGUID
	
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		SELECT @bDetailed = [bDetailed] FROM [ET000] WHERE [Guid] = @HeaderTypeGUID
		
		IF (@bDetailed = 1)
		BEGIN
			-- ﬁÌœ ·ﬂ· ﬁ·„
			INSERT INTO EN000(Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGuid, CostGUID, ContraAccGUID)
			SELECT
				d.[Number],
				h.[Date],
				d.[Credit],
				d.[Debit],
				d.[Notes],
				h.CurrencyVal,
				0,
				0,
				0,
				0,
				0,
				NEWID(),
				h.[GUID],
				CASE @CashAccGUID WHEN 0x0 THEN et.[DefAccGUID] ELSE @CashAccGUID END,
				h.CurrencyGUID,
				@CostGUID,
				0x00
			FROM
				#Header AS h
				INNER JOIN #Detail d ON h.Guid = d.[ParentGuid]
				INNER JOIN [ET000] AS et ON et.GUID = h.[TypeGUID]
			WHERE
				h.[GUID] = @HeaderGuid
		END
		ELSE
		BEGIN
			INSERT INTO EN000(Number, Date, Debit, Credit, Notes, CurrencyVal, Class, Num1, Num2, Vendor, SalesMan, GUID, ParentGUID, AccountGUID, CurrencyGuid, CostGUID, ContraAccGUID)
			SELECT 
				0,
				h.[Date],
				h.[Credit],
				h.[Debit],
				h.[Notes],
				h.CurrencyVal,
				0,
				0,
				0,
				0,
				0,
				NEWID(),
				h.[GUID],
				CASE @CashAccGUID WHEN 0x0 THEN et.[DefAccGUID] ELSE @CashAccGUID END,
				h.CurrencyGUID,
				@CostGUID,
				0x00
			FROM
				#Header AS h
				INNER JOIN [ET000] AS et ON et.[GUID] = h.[TypeGUID]
			WHERE
				h.[GUID] = @HeaderGuid
		END
		
		FETCH NEXT FROM @cur INTO @HeaderGuid, @HeaderTypeGUID
	END
	
	CLOSE @cur 
	
	DEALLOCATE @cur
	-----------------------------------------------------------------------------------------------------------
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
		INNER JOIN #Header AS H ON H.GUID = Er.EntryGuid AND H.Guid = Er.ParentGUID
		
	--------------------------------------------------------------------
	/*UPDATE
		ce
	SET 
		ce.Notes = ce.Notes + ' ' + d.Notes
	FROM 
		CE000 ce
		INNER JOIN DistDeviceEn000 d ON ce.*/


	--- Update LastEnNumber
	UPDATE Distributor000 SET LastEnNumber = ISNULL( (SELECT MAX(Number) FROM DistDeviceEn000 WHERE DistributorGuid = @DistributorGuid), LastEnNumber)
	WHERE Guid = @DistributorGuid
	-------------
	DELETE DistDeviceEn000 WHERE DistributorGUID = @DistributorGUID
	---- post Entries
	ALTER TABLE ac000 DISABLE TRIGGER trg_ac000_CheckConstraints
	
	UPDATE [CE000]
	SET
		[IsPosted] = 1
	FROM
		#Header AS h INNER JOIN CE000 AS ce ON ce.GUID = h.GUID
	ALTER TABLE ac000 ENABLE TRIGGER trg_ac000_CheckConstraints

-- EXEC prcDist_GenPaymentOFDestributor 0x00
########################################
CREATE PROCEDURE prcDistUpdateChequeCust
		@CustGUID uniqueidentifier,@chequGUID uniqueidentifier
AS        
	SET NOCOUNT ON         
	-----------------------------------------------------------------------
	update ch000  set CustomerGuid = @CustGUID
	where GUID = @chequGUID
#######################################################
#END

