################################################################################
create PROCEDURE prcGenerateAllocations
	@AllotmentGuidParam		UNIQUEIDENTIFIER,
	@GenrateTypeParam		INT,
	@dateParam				DATETIME,
	@RegenerateParam		INT,
	@FincanceYearStartParam DATETIME,
	@FincanceYearEndParam	DATETIME,
	@CeNoteParam			NVARCHAR(1000),
	@EnAcountNoteParam		NVARCHAR(1000),
	@EnCounterAcountNoteParam NVARCHAR(250),
	@EntryType				UNIQUEIDENTIFIER,
	@WesternUsed			INT,
	@PeriodStr				NVARCHAR(50),
	@Day					TINYINT = 1
AS
	SET NOCOUNT ON
	DECLARE @EmptyNote NVARCHAR(1000)
	SET @EmptyNote =  @EnAcountNoteParam
	
	-- حذف أسطر الجدول المرتبطة بسندات محذوفة
	Delete ae
	FROM
		AllocationEntries000 as ae
		Left Join ce000 as ce ON ce.Guid = ae.BondGuid
	WHERE 
		ce.Guid IS NULL
	
	DECLARE @CeNotes NVARCHAR(1000)
	SELECT @CeNotes =  Notes FROM Allotment000 WHERE GUID = @AllotmentGuidParam
	
	IF @GenrateTypeParam = 0 -- monthly
	BEGIN
		DECLARE
			@startDate	DATETIME,
			@endDate	DATETIME
		SET @startDate = CAST(MONTH(@dateParam) AS NVARCHAR) + '/1/' + CAST(YEAR(@dateParam) AS NVARCHAR)
		SET @endDate = DATEADD(DAY, -1, DATEADD(MONTH, 1, @startDate))
		-- انهاء الاجرائية في حال وجود سند قيد مولد مسبقا ولم يتم تحديد خيار إعادة توليد سندات القيد
		IF ((SELECT 
				COUNT(*)
			FROM
				Allocations000  al
				INNER JOIN AllocationEntries000 ae ON ae.AllocationGuid = al.Guid
			WHERE
				AllotmentGUID = @AllotmentGuidParam
				AND ae.Date BETWEEN @startDate AND @endDate
			)
			 > = 1  AND @RegenerateParam = 0)
		BEGIN
			RETURN 
		END 
		
		DECLARE
			@number		INT,
			@AlocNumber INT,
			@balance	FLOAT,
			@entryDate	DATETIME,
			@PyNumber	INT,
			@ceGuid		UNIQUEIDENTIFIER,
			@PyGuid		UNIQUEIDENTIFIER,
			@branchGuid UNIQUEIDENTIFIER,
			@currencyGuid UNIQUEIDENTIFIER
			
		SELECT 
			@balance = SUM(MonthPortion) 
		FROM 
			Allocations000 
		WHERE 
			AllotmentGUID = @AllotmentGuidParam 
			AND FromMonth <= @startDate 
			AND ToMonth >= @endDate
			
	
		SELECT @currencyGuid = myGUID FROM vwmy WHERE myNumber = 1
		SELECT @branchGuid	 = BranchGUID FROM Allotment000 WHERE GUID = @AllotmentGuidParam
		-- اختبار وجود قيد مولد مسبقا
		SET @ceGuid = (
			SELECT TOP 1
				BondGuid
			FROM
				AllocationEntries000 ae
				INNER JOIN Allocations000 aloc ON ae.AllocationGuid = aloc.GUID
				INNER JOIN Allotment000 al ON aloc.AllotmentGuid = al.GUID
			WHERE
				al.GUID = @AllotmentGuidParam
				AND aloc.FromMonth <= @startDate 
				AND aloc.ToMonth >= @endDate
				AND MONTH(ae.Date) = Month(@dateParam) 
				AND YEAR(ae.Date) = YEAR(@dateParam)
			)
			
		IF ISNULL(@ceGuid, 0x0) <> 0x0
		BEGIN
			DECLARE @ExistPyGuid UNIQUEIDENTIFIER					
	
			SELECT @ExistPyGuid = parentGuid FROM er000 WHERE EntryGUID = @ceGuid
			
			-- delete entry header
			UPDATE ce000 SET IsPosted = 0 WHERE GUID = @ceGuid
			SELECT @number = Number FROM ce000 WHERE GUID = @ceGuid
			DELETE FROM ce000 WHERE GUID = @ceGuid
			
			-- Delete Entry items - if exists - from en000, er000, py000 tables
			DELETE FROM en000 WHERE ParentGuid = @ceGuid
			DELETE FROM AllocationEntries000 WHERE BondGuid = @ceGuid
			IF ISNULL(@ExistPyGuid, 0x0) <> 0x0
			BEGIN				
				ALTER TABLE er000 DISABLE TRIGGER trg_er000_delete
				ALTER TABLE py000 DISABLE TRIGGER trg_py000_delete
		
				DELETE FROM py000 WHERE GUID = @ExistPyGuid-- AND ISNULL(@EntryType, 0x0) = 0x0
				DELETE FROM er000 WHERE ParentGUID = @ExistPyGuid-- and (@EntryType = 0x0 OR @EntryType is null))
		
				ALTER TABLE er000 ENABLE TRIGGER trg_er000_delete
				ALTER TABLE py000 ENABLE TRIGGER trg_py000_delete
			END
		END
		
--------------------------------------------------------------------------------------------
		-- insert insert entry header into ce000
		ELSE 
		BEGIN 
		IF (@branchGuid = 0x0 )
			BEGIN
				SELECT @number =  ISNULL(MAX(Number), 0) + 1 FROM ce000 
				SELECT @AlocNumber =  ISNULL(MAX(Number), 0)  FROM Allotment000 
			END
		ELSE 
			BEGIN
				 SELECT @number =  ISNULL(MAX(Number), 0) + 1 FROM ce000  WHERE Branch = @branchGuid
				 SELECT @AlocNumber =  ISNULL(MAX(Number), 0)  FROM Allotment000 WHERE BranchGuid = @branchGuid
			END
		END
		SET @ceGuid = ISNULL(@ceGuid, NEWID())
		
		INSERT INTO ce000(Type, Number, Date, Debit, Credit, Notes, CurrencyVal, IsPosted,State, Security, Num1, Num2, Branch, GUID, CurrencyGUID, TypeGUID, IsPrinted, PostDate) VALUES(
			0 ,
			@number,
			@dateParam,
			@balance,
			@balance,
			@CeNotes,
			1, -- CurrencyVal
			0, -- IsPosted
			0, -- State
			1, -- Security
			0, -- Num1
			0, -- Num2
			@branchGuid,
			@ceGuid,
			@currencyGuid,
			@EntryType,
			0,
			@dateParam
		)
-----------------------------------------------------------------------------------------------
		-- get Allocations000 items into @alocCursor
		-- get Allocations000 items into @alocCursor
		DECLARE
			@alocCursor		CURSOR,
			@alocGuid		UNIQUEIDENTIFIER,
			@accGUID		UNIQUEIDENTIFIER,
			@counterAcc		UNIQUEIDENTIFIER,
			@custGUID		UNIQUEIDENTIFIER,
			@contraCust	UNIQUEIDENTIFIER,
			@monthPortion	FLOAT,
			@CostCreditGuid	UNIQUEIDENTIFIER,
			@CostDebitGuid	UNIQUEIDENTIFIER,
			@CuurGuid	UNIQUEIDENTIFIER,
			@Cuurval        FLOAT,
			@ParentGuid UNIQUEIDENTIFIER
			
		SET @alocCursor = CURSOR FAST_FORWARD FOR
			SELECT
				aloc.GUID,
				AccountGuid,
				CounterAccountGuid,
				ISNULL(CustomerGuid,0x0),
				ISNULL(ContraCustomerGuid,0x0),
				MonthPortion,
				aloc.CostDebitGuid,
				aloc.CostCreditGuid,
				ISNULL(v.myGuid, @currencyGuid),
                dbo.fnGetCurVal(ISNULL(v.myGuid, @currencyGuid), @startDate),
				aloc.AllotmentGUID
				 
			FROM
				Allocations000 aloc
				INNER JOIN Allotment000 alm ON alm.GUID = aloc.AllotmentGUID
				LEFT JOIN vwmy  v on v.myGUID = aloc.CurrencyGuid
			WHERE
				aloc.FromMonth <= @startDate 
				AND aloc.ToMonth >= @endDate
				AND alm.GUID = @AllotmentGuidParam
				AND
				( 
					@RegenerateParam = 1 
					OR 
					@RegenerateParam = 0 
					AND NOT EXISTS(SELECT * FROM AllocationEntries000 WHERE aloc.GUID = AllocationGuid AND [Date] BETWEEN @startDate AND @endDate)
				)
				 
		OPEN @alocCursor
		FETCH NEXT FROM @alocCursor INTO @alocGuid, @accGUID, @counterAcc, @custGUID, @contraCust, @monthPortion, @CostCreditGuid, @CostDebitGuid, @CuurGuid, @Cuurval,@ParentGuid
																			   
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @EnAcountNoteParam = (SELECT CASE aloc.Note WHEN N'' THEN @EmptyNote ELSE aloc.Note END 
				FROM
					Allocations000 aloc
					INNER JOIN Allotment000 alm ON alm.GUID = aloc.AllotmentGUID
				WHERE
						aloc.FromMonth <= @startDate 
					AND 
						aloc.ToMonth >= @endDate
					AND 
						alm.GUID = @AllotmentGuidParam
					AND @alocGuid = aloc.GUID and aloc.AccountGuid = @accGUID and aloc.CounterAccountGuid = @counterAcc)
			SET @EnCounterAcountNoteParam  = @EnAcountNoteParam
			
			IF (@CuurGuid = 0x0)
			BEGIN 
				SET @CuurGuid = @currencyGuid
				SET @Cuurval =  1
			END 
			
			EXEC prcAddAllocationEntry @alocGuid, @ceGuid, @accGUID, @counterAcc,@custGUID,@contraCust, @monthPortion, @dateParam, @branchGuid, @Cuurval, @CuurGuid,
			 @EnAcountNoteParam, @EnCounterAcountNoteParam, @WesternUsed,@CostCreditGuid,@CostDebitGuid,@PeriodStr
			UPDATE Allocations000 
			SET EntryGenrated = 1 
			WHERE GUID = @alocGuid
			
			FETCH NEXT FROM @alocCursor INTO @alocGuid, @accGUID, @counterAcc, @custGUID, @contraCust, @monthPortion, @CostCreditGuid, @CostDebitGuid, @CuurGuid, @Cuurval,@ParentGuid
		END
		CLOSE @alocCursor
		DEALLOCATE @alocCursor
		
		INSERT INTO er000(GUID, EntryGUID, ParentGUID, ParentType,ParentNumber)
		VALUES(NEWID(), @ceGuid, @AllotmentGuidParam, 1000, @AlocNumber);
		-- في حال توليد سند قيد من أحد أنماط السندات
		-- link entry head -en000- with py000, er000 tables
		IF ISNULL(@EntryType, 0x0) <> 0x0
		BEGIN
			DECLARE @DefaultEntryAccount UNIQUEIDENTIFIER
			
			SELECT @DefaultEntryAccount = DefAccGUID FROM et000 WHERE GUID = @EntryType
			SELECT @currencyGuid		= myGUID FROM vwmy WHERE myNumber = 1
			SELECT @PyNumber			= ISNULL(MAX(Number), 0) + 1 FROM py000 WHERE TypeGUID = @EntryType
			SET @PyGuid = NEWID()
			
			INSERT INTO py000(Number, Date, Notes, currencyval, skip, Security, GUID, TypeGuid, AccountGUID, CurrencyGUID,BranchGuid)
			VALUES(@PyNumber, @dateParam, @CeNotes, 1, 0, 1, @PyGuid, @EntryType,@DefaultEntryAccount, @CurrencyGuid, @BranchGuid)
			INSERT INTO er000(GUID, EntryGUID, ParentGUID, ParentType,ParentNumber)
			VALUES(NEWID(), @ceGuid, @PyGuid, 4, @PyNumber)
		END
		EXEC prcDisableTriggers 'ce000'
		UPDATE ce000 
		SET 
			IsPosted = 1,
			TypeGUID = @EntryType
		WHERE 
			GUID = @ceGuid
		EXEC prcEnableTriggers 'ce000'
	
---------------------------------------------------------------------------------------------
	SELECT 1 AS Result -- تم توليد السند بنجاح
	END
	ELSE -- سنوي
	BEGIN
		DECLARE
			@fromMonth	DATETIME,
			@toMonth	DATETIME
		SELECT 
			@fromMonth  = CASE WHEN @FincanceYearStartParam > MIN(FromMonth) THEN @FincanceYearStartParam ELSE MIN(FromMonth) END,
			@toMonth	= CASE WHEN @FincanceYearEndParam	< MAX(toMonth)	THEN @FincanceYearEndParam	  ELSE MAX(toMonth) END 
		FROM 
			Allocations000 
		WHERE 
			AllotmentGuid = @AllotmentGuidParam
		
		SET @toMonth = EOMONTH( @toMonth )
		WHILE @fromMonth <= @toMonth
		BEGIN		
			DECLARE @fromMonthD INT = DATEPART(D,@fromMonth)
			IF( @Day > @fromMonthD )
			BEGIN
				DECLARE @endOfMonth INT = DATEPART(D,EOMONTH( @fromMonth ))
				SET @fromMonth = DATEADD(D, IIF( @Day < @endOfMonth , @Day , @endOfMonth) - @fromMonthD, @fromMonth) 
			END	
			ELSE
				SET @fromMonth = DATEADD(D, @Day - @fromMonthD, @fromMonth)  
			EXEC prcGenerateAllocations @AllotmentGuidParam, 0, @fromMonth, @RegenerateParam, '', '', @CeNotes, @EnAcountNoteParam, @EnCounterAcountNoteParam,@EntryType , @WesternUsed, @PeriodStr
			SET @fromMonth = DATEADD(MONTH, 1, @fromMonth) 
		END  
	END



################################################################################
#END
