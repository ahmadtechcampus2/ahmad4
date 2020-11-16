####################################
CREATE PROC prcPatient_genCloseDossierEntry
	@FileGuid				UNIQUEIDENTIFIER,
	@CurrencyGuid			UNIQUEIDENTIFIER,
	@CurrencyVal			FLOAT,
	@entryNum 				INT = 0,
	@SystemType				INT = 1 -- ST_HOSPITALS = 1, ST_HOTELS = 2
AS
	SET NOCOUNT ON 
	
	DECLARE
		@CostPtr 			UNIQUEIDENTIFIER,	--ÑÞã ãÑßÒ ÇáßáÝÉ
		@StartDate 			DATETIME,			--ÊÇÑíÎ  ÇáÏÎæá
		@EndDate 			DATETIME,			--ÊÇÑíÎ ÇáÎÑæÌ

		@PatientGUID 		UNIQUEIDENTIFIER,
		@PatientAccGUID		UNIQUEIDENTIFIER,
		@entryGUID 			UNIQUEIDENTIFIER,
		@branchGUID 		UNIQUEIDENTIFIER,
		@PatientTotalBal	FLOAT,
		@DossierCode		NVARCHAR(256),
		@Patient			NVARCHAR(256),
		@Security			INT,
		@DefaultPatientAccGuid UNIQUEIDENTIFIER,
		@IsBriefEntry		BIT;

	SET @DefaultPatientAccGuid = (SELECT Value FROM op000 WHERE Name = 'HosCfg_Employee_DefPatientAcc')
	SET @IsBriefEntry = ISNULL((SELECT CAST(Value AS BIT) FROM op000 WHERE Name = 'HosCfg_IsBriefEntry'),0)

	-- prepare new entry guid and number:
	SET @entryGUID = NEWID()

	SELECT @BranchGUID = Branch  from [hosPFile000] WHERE [Guid] = @FileGUID

	IF @entryNum = 0 OR EXISTS(SELECT * FROM vwCe WHERE ceNumber = @entryNum) 
		SET @entryNum = dbo.fnEntry_getNewNum( @BranchGUID)
	-- delete old entry: 
	EXEC prcPatient_DeleteEntry @FileGuid 
	-- prepare variables data:
	SELECT
			@PatientGUID = PatientGuid , 
			@PatientAccGUID = AccGuid, 	
			@CostPtr = CostGuid,
			@StartDate = dbo.HosGetJustDate(DateIn),
			@EndDate = DateAdd(day, 1 ,DateOut),
			@DossierCode = Code,
			@Patient = [Name],
			@Security = Security
	FROM 
		vwHosFile WHERE Guid = @FileGuid

	CREATE TABLE  #Result
	(
		RecType			INT,
		Id 				INT IDENTITY(1,1),
		CostSecurity	INT,
		AccSecurity		INT,
		AccGuid			UNIQUEIDENTIFIER,
		ceGuid 			UNIQUEIDENTIFIER,
		ceNumber 		INT,
		[Date]			DATETIME,
		Debit			FLOAT,
		Credit			FLOAT,
		Notes			NVARCHAR(255) COLLATE ARABIC_CI_AI,
		Security		INT,
		UserSecurity	INT
	)
	CREATE TABLE  #Result2
	(   
		RecType			INT,
		Id 				INT IDENTITY(1,1),
		CostSecurity	INT,
		AccSecurity		INT,
		AccGuid			UNIQUEIDENTIFIER,
		ceGuid 			UNIQUEIDENTIFIER,
		ceNumber 		INT,
		[Date]			DATETIME,
		Debit			FLOAT,
		Credit			FLOAT,
		Notes			NVARCHAR(255) COLLATE ARABIC_CI_AI,
		Security		INT,
		UserSecurity	INT
	)
	
	select 1
	--íÌÈ ÇÓÊÏÚÇÁ ÇáÅÌÑÇÁ ÈÚÏ ÅäÔÇÁ ÇáÌÏÇæá #Result, #Result2
	EXEC prcGetPatientBal @CostPtr, @StartDate, @EndDate, @CurrencyGuid, @CurrencyVal

	SELECT  * FROM #Result

	DECLARE @SumDebit FLOAT
	DECLARE @SumCredit FLOAT
	
	SELECT @SumDebit =  ISNULL(SUM(Debit), 0) FROM #Result WHERE AccGuid = @PatientAccGUID 
	SELECT @SumCredit = ISNULL(SUM(Credit), 0) FROM #Result WHERE AccGuid = @PatientAccGUID 
	
	SELECT @SumDebit AS SumDebit, @SumCredit AS SumCredit

	IF @SumDebit = 0 AND  @SumCredit = 0
	BEGIN
		RAISERROR('AmnE0511: Cant Generate entry there is no activities...', 16, 1)
		RETURN
	END

	SELECT @SumDebit AS SumDebit, @SumCredit AS SumCredit

	--IF (@SumDebit - 1) > dbo.fnGetZeroValue()
		SET @PatientTotalBal = @SumDebit - @SumCredit
	--ELSE
		--SET @PatientTotalBal = @SumDebit 
	
	if @PatientTotalBal < 0 
	BEGIN
		RAISERROR('AmnE0521: Cant Generate entry Patient is Credit...', 16, 1)
		RETURN
	END


	declare @Positive int
	if @PatientTotalBal > 0
		set @Positive = 1
	else
	BEGIN
	 	SET @Positive = 0
		SET @PatientTotalBal = @PatientTotalBal * -1
	END
/*-- check:
	IF @@ROWCOUNT = 0
	BEGIN
		RAISERROR('AmnE0193: Transfer specified was not found ...', 16, 1)
		RETURN
	END
*/
	CREATE TABLE #Items
	(
		Number		INT IDENTITY(1,1),
		AccGuid		UNIQUEIDENTIFIER,
		NOTES		NVARCHAR(255) COLLATE ARABIC_CI_AI,
		Val			FLOAT
	)
	-- SELECT AccGuid, NOTES, Ratio,  @PatientTotalBal FROM hosPatientAccounts000  WHERE PatientGuid = @PatientGUID
-- 	SELECT *FROM hosPatientAccounts000  WHERE PatientGuid = @PatientGUID
	DECLARE @Not NVARCHAR(100), @language INT;
	SET @language = [dbo].[fnConnections_GetLanguage]();
	SELECT @Not = [dbo].[fnStrings_get]('HOSPITAL\CLOSEDOSSIERENTRY', @language) 
	SELECT @Not = @Not + ' ' + @DossierCode
	SELECT @Not = @Not + [dbo].[fnStrings_get]('HOSPITAL\PATIENT', @language) 
	SELECT @Not = @Not + @Patient

	;WITH PA AS
	(
		SELECT 
			AccGuid, 
			NOTES, 
			Ratio,
			SUM(Ratio) OVER(PARTITION BY PatientGuid) AS SumRatio
		FROM 
			hosPatientAccounts000 
		WHERE 
			(@SystemType = 2 AND PatientGuid = @PatientGUID) OR (@SystemType = 1 AND PatientGuid = @FileGuid)
	)
	INSERT INTO #Items(AccGuid, NOTES, Val) 
	SELECT 
		AccGuid, 
		NOTES, 
		(Ratio * @PatientTotalBal / 100) 
	FROM 
		PA 
	--UNION ALL
	--SELECT TOP 1
	--	@DefaultPatientAccGuid, 
	--	@Not, 
	--	((100 - SumRatio) * @PatientTotalBal / 100) 
	--FROM PA
	--WHERE SumRatio < 100

	select * from #Items
	
	DECLARE @Debit FLOAT
	DECLARE @MaxNum INT
	SELECT @MaxNum = MAX(Number) FROM #Items
	SET @MaxNum = @MaxNum + 1
	SELECT @MaxNum
	SELECT @Debit = SUM (Val) FROM #Items
	-- insert ce:  -- 

	
	
	declare @date  DateTime
	select @date = dbo.HosGetJustDate(GetDate())  	
	
	INSERT INTO ce000 (typeGUID, Type, Number, [Date], [PostDate], Debit, Credit, Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)
		SELECT 
			0x0, 1, @entryNum, @date, @date,  
			@Debit,
			@Debit,
			@Not, @CurrencyVal, 0,
			@Security,
			@BranchGUID, @entryGUID, @CurrencyGUID  
		--FROM hosPFile000 WHERE PatientGUID = @PatientGUID

	-- insert en:
	DECLARE @NullCost UNIQUEIDENTIFIER
	SET @NullCost = 0x0
	INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
		SELECT
		-- Item Number ÑÞã ÇáÞáã
			Number,
			@date,--@EndDate,
			case @Positive when 1 then Val else 0 end,  -- debit
			case @Positive when 1 then 0 else val end,  -- credit
			@Not,--NOTES,
			@CurrencyVal,
			@entryGUID,
			AccGuid,
			@CurrencyGUID,
			@CostPtr,
			0x0 -- contrAcc  here ??
		FROM #Items

	-- ØÑíÞÉ ÊæáíÏ ÇáÞíÏ (ãÎÊÕÑ,ÛíÑ ãÎÊÕÑ)
	IF @IsBriefEntry = 0
	BEGIN
	INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
	SELECT
	-- Item Number ÑÞã ÇáÞáã
		@MaxNum,			
		@date,--@EndDate,
		case @positive when 1 then 0 else Val end, 		-- debit
		case @positive when 1 then Val else 0 end,	-- credit
		@Not,
		@CurrencyVal,
		@entryGUID,
		@PatientAccGUID, 
		@CurrencyGUID,
		@CostPtr, --costGuid
		0x0 -- contrAcc here ??
		FROM #Items
	END
	ELSE
	BEGIN
	INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
		SELECT
		-- Item Number ÑÞã ÇáÞáã
			@MaxNum,			
			@date,--@EndDate,
			case @positive when 1 then 0 else @Debit end, 		-- debit
			case @positive when 1 then @Debit else 0 end,	-- credit
			@Not,
			@CurrencyVal,
			@entryGUID,
			@PatientAccGUID, 
			@CurrencyGUID,
			@CostPtr, --costGuid
			0x0 -- contrAcc here ??
	END

-- select * FROM ch000  
	-- populate distibutive accounts:
	WHILE EXISTS(SELECT * FROM en000 e INNER JOIN ac000 a ON e.accountGuid = a.guid WHERE e.parentGuid = @entryGUID and a.type = 8)
	BEGIN
		-- mark distributives:
		update en000 set number = - e.number from en000 e inner join ac000 a on e.accountGuid = a.guid where e.parentGuid = @entryGuid and a.type = 8

		-- insert distributives detailes:
		insert into en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			select
				- e.number, -- this is called unmarking.
				e.date,
				e.debit * c.num2 / 100,
				e.credit * c.num2 / 100,
				e.notes,
				e.currencyVal,
				e.parentGUID,
				c.sonGuid,--e.accountGUID,
				e.currencyGUID,
				e.costGUID,
				e.contraAccGUID
			from en000 e inner join ac000 a on e.accountGuid = a.guid inner join ci000 c on a.guid = c.parentGuid
			where e.parentGuid = @entryGuid and a.type = 8

		-- delete the marked distributives:
		delete en000 where parentGuid = @entryGuid and number < 0
		-- continue looping untill no distributive accounts are found
	END
	-- post entry: 
	UPDATE ce000 SET IsPosted = 1 WHERE GUID = @entryGUID 

	-- link  
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)
			VALUES(@entryGUID, @FileGuid, 302, @entryNum) 
   
-- 		@FileGuid
	-- return data about generated entry 
	SELECT @entryGUID, @entryNum 
####################################
CREATE PROC CheckDossierBalance
	@StartDate 	DATETIME,		--ÊÇÑíÎ ÇáÈÏÇíÉ  
	@EndDate 	DATETIME,--ÊÇÑíÎ ÇáäåÇíÉ  
	@FileGuid UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON 
	DECLARE
	@Account 	UNIQUEIDENTIFIER,	--ÑÞã ÇáÍÓÇÈ  
	@CostGuid 	UNIQUEIDENTIFIER,	--ÑÞã ãÑßÒ ÇáßáÝÉ  
	@PatientGuid	UNIQUEIDENTIFIER = 0X0	--ÇáãÑíÖ  

	SELECT @Account = AccGuid, @CostGuid = CostGuid, @PatientGuid = PatientGuid FROM vwHosFile

	CREATE TABLE #Result1  
		(  
			[CeGUID] 	[UNIQUEIDENTIFIER],  
			[enGUID] 	[UNIQUEIDENTIFIER],   
			[CeNumber]	[INT],  
			[EnNumber]	[INT],  
			[AccGUID] 	[UNIQUEIDENTIFIER],      
			[CostGuid] 	[UNIQUEIDENTIFIER],  
			[DATE] 		[DATETIME],  
			[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI,  
			[DEBIT]		[FLOAT],  
			[CREDIT]	[FLOAT],  
			[FileGuid] 	[UNIQUEIDENTIFIER],  
			[ceParentGUID] [UNIQUEIDENTIFIER],       
			[ceRecType] [INT],       
			[ParentNumber] [NVARCHAR](250),   
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,   
			[ceTypeGuid] [UNIQUEIDENTIFIER],  
			[ceSecurity] [INT],      
			[accSecurity] [INT]  
		)

	INSERT INTO #Result1  
	EXEC prcHosGetEntries @Account, @CostGuid, @StartDate, @EndDate, @PatientGuid, @FileGuid  
	SELECT SUM(DEBIT) AS DEBIT, SUM(CREDIT) AS CREDIT FROM #Result1
####################################
#END