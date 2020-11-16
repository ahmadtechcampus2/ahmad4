###########################################################################
CREATE PROCEDURE prcGeneralLedgerPerYear
	@Account [UNIQUEIDENTIFIER],
	@ContraAccount [UNIQUEIDENTIFIER] = 0x0,
	@CostCenter [UNIQUEIDENTIFIER]= 0x0,
	@CurGUID [UNIQUEIDENTIFIER]= 0x0,
	@StartDate [DATETIME] = '1990-01-01',	             
	@EndDate [DATETIME] = '2000-12-31',
	@Class [NVARCHAR](256) = '',
	@Contain [NVARCHAR](256) = '',	
	@NotContain [NVARCHAR](256) = '',
	@PostedOnly [BIT] = 1,
	@ReportSourceFlag [INT] = 63,
	@ReportSourceBillTypeFlag [INT] = 31,
	@UserID UNIQUEIDENTIFIER = 0x0,
	@Lang		[INT] = 0,--  0 arabic 1 latin
	@CustomerName [NVARCHAR](512) = '',
	@LocalDB BIT = 1,
	@Customer [UNIQUEIDENTIFIER] = 0x0
AS  
BEGIN
	SET NOCOUNT ON;
		
	--@ReportSourceBillTypeFlag
	--0 => 1		000001 -- شراء
	--1 => 2		000010 -- مبيع
	--2 => 4		000100 -- شراء مرتجع
	--3 => 8		001000 -- مرتجع مبيع
	--4 => 16	010000 -- ادخال
	--5 => 32	100000 -- اخراج
	--@ReportSourceFlag
	--1     000001 سند القيد
	--2     000010 الفواتير
	--4     000100 أنماط السندات
	--8     001000 أوراق مالية مقبوضة
	--16    010000 أوراق مالية مدفوعة
	--32    100000 مناقلات

	DECLARE 
		@BillParentType			AS INT,
		@EntriesParentType		AS INT,
		@EntryTypesParentType	AS INT,
		@ChequesInParentType	AS INT,
		@ChequesOutParentType	AS INT,
		@Transaction			AS INT,
		@CurrencyVal			AS FLOAT,
		@NoteContain			AS [NVARCHAR](1000) ,      
		@NoteDosentContain		AS [NVARCHAR](1000)  ,     
		@firstPeriodDate		AS DATE,
		@endPeriodDate			AS DATE,
		@SearchByCustomerName   AS BIT = 0
 
	SET @EntriesParentType = 1; 
	SET @BillParentType = 2; 
	SET @EntryTypesParentType = 4; 
	SET @ChequesInParentType = 8; 
	SET @ChequesOutParentType = 16;	
	SET @Transaction = 32;
	SET @NoteContain			= N'%'+ @Contain + '%'       
	SET @NoteDosentContain		= N'%'+ @NotContain + '%' 
	
	IF @CurGUID = 0x0  SET @CurGUID = [dbo].[fnGetDefaultCurr]();

	IF NOT EXISTS(select GUID from my000 where GUID = @CurGUID)
		BEGIN
			SET @CurGUID = [dbo].[fnGetDefaultCurr]();
		END

	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE GUID = @CurGUID
	IF (@CustomerName != '' AND @LocalDB = 0) SET @SearchByCustomerName = 1

	SELECT 
		EN.Date				AS EnDate,
		Ce.Number			AS CeNumber,
		Ce.GUID				AS CeGuid,
		CASE @Lang WHEN 0 THEN ET.Abbrev ELSE CASE ET.LatinAbbrev WHEN '' THEN ET.Abbrev ELSE ET.LatinAbbrev END END AS EntryTypeName,
		EN.Notes			AS EnNotes,
		EN.ContraAccGUID	AS EnContraAccount,
		EN.AccountGUID		AS EnAccount,
		EN.Class			AS EnClass,
		CAC.Name			AS EnContraAccName,
		CAC.LatinName		AS EnContraAccLatinName,
		CAC.Code			AS EnContraAccCode,
		CC.GUID				AS EnCostCenterGuid ,
		CC.Name				AS EnCostCenterName ,
		CC.LatinName		AS EnCostCenterLatinName ,
		CC.Code				AS EnCostCenterCode ,
		((EN.Debit - EN.Credit) / EN.CurrencyVal) AS EnOriginalCurrency ,
		ISNULL([dbo].[fnCurrency_Fix](EN.Debit, EN.CurrencyGuid , EN.CurrencyVal, @CurGUID, EN.Date), 0.0) AS EnCurrDebit,
		ISNULL([dbo].[fnCurrency_Fix](EN.Credit, EN.CurrencyGuid , EN.CurrencyVal, @CurGUID, EN.Date), 0.0) AS EnCurrCredit,
		EN.CurrencyVal AS EnCurrencyVal,
		MY.Code AS EnCurrencyCode,
		DB_NAME() AS DatabaseName,
		ISNULL(ER.ParentType, 1)	AS CeParentType,
		CASE @Lang WHEN 0 THEN BT.Abbrev ELSE CASE BT.LatinAbbrev WHEN '' THEN BT.Abbrev ELSE BT.LatinAbbrev END END AS BillTypeName,
		BT.BillType					AS BillType,
		ER.ParentGUID				AS ParentGuid,
		ER.ParentNumber				AS ParentNumber,
		CASE @Lang WHEN 0 THEN NT.Abbrev ELSE CASE NT.LatinAbbrev WHEN '' THEN NT.Abbrev ELSE NT.LatinAbbrev END END AS NoteTypeName,
		CASE @Lang WHEN 0 THEN BR.Name ELSE CASE BR.LatinName WHEN '' THEN BR.Name ELSE BR.LatinName END END AS BranchName,
		CE.IsPosted AS IsPosted,
		CE.TypeGUID AS CeTypeGuid,
		Ac.Security AS acSecurity,
		CC.Security AS coSecurity,
		CE.Security AS ceSecurity,
		ISNULL(EnTbl.Security, ISNULL(BuTbl.Security, NtTbl.Security)) AS UserSecurity,
		ISNULL(CE.Security, ISNULL(BU.Security, CH.Security)) AS Security,
		EN.CustomerGUID		AS EnCustomer,
		CU.cuCustomerName	AS EnCustomerName
	FROM 
		ce000  CE 			 
		INNER JOIN en000 EN	 ON CE.Guid = EN.ParentGuid
		LEFT  JOIN ac000 AC  ON AC.GUID = EN.AccountGUID
		LEFT  JOIN ac000 CAC ON CAC.GUID = EN.ContraAccGUID
		LEFT  JOIN et000 ET	 ON CE.TypeGUID = ET.Guid
		LEFT  JOIN er000 ER	 ON ER.EntryGUID = CE.GUID
		LEFT  JOIN bu000 BU	 ON BU.Guid = ER.ParentGUID
		LEFT  JOIN bt000 BT  ON BT.Guid = BU.TypeGUID
		LEFT  JOIN co000 CC  ON CC.GUID = EN.CostGUID
		LEFT  JOIN my000 MY  ON MY.GUID = EN.CurrencyGUID
		LEFT  JOIN ch000 CH  ON CH.GUID = ER.ParentGUID
		LEFT  JOIN nt000 NT  ON NT.GUID = CH.TypeGUID
		LEFT  JOIN br000 BR  ON BR.GUID = CE.Branch
		LEFT  JOIN [dbo].[fnGetEntriesTypesList](null, @UserID)  EnTbl ON EnTbl.GUID = ET.Guid
		LEFT  JOIN [dbo].[fnGetBillsTypesList](null, @UserID)  BuTbl ON BuTbl.Guid = BT.Guid
		LEFT  JOIN [dbo].[fnGetNotesTypesList](null, @UserID)  NtTbl ON NtTbl.Guid = NT.Guid
		LEFT  JOIN vwCu CU ON CU.cuGUID = EN.CustomerGUID
	WHERE 
		EN.AccountGuid = @Account
		AND ((@SearchByCustomerName != 1 AND en.CustomerGUID = CASE WHEN ISNULL(@Customer, 0x0) <> 0x0 THEN @Customer ELSE ISNULL(en.CustomerGUID, 0x0)END )
			OR (@SearchByCustomerName = 1 AND CU.cuCustomerName = @CustomerName))
		AND (@CostCenter = 0x0 OR @CostCenter = EN.CostGuid)
		AND (@ContraAccount = 0x0 OR @ContraAccount = EN.ContraAccGUID)
		AND (@Contain = '' OR EN.Notes Like @NoteContain)      
		AND (@NotContain = '' OR EN.Notes NOT Like @NoteDosentContain)      
		AND (@Class = '' OR EN.Class = @Class)   
		AND (CE.IsPosted = 1 OR @PostedOnly != 1)
		AND (
				(@ReportSourceFlag & @EntriesParentType != 0		AND ISNULL(ER.ParentType, 1) = 1) -- سندات القيد
			OR  (@ReportSourceFlag & @EntryTypesParentType != 0		AND ISNULL(ER.ParentType, 1) = 4) -- أنماط السندات
			OR  (@ReportSourceFlag & @ChequesInParentType != 0		AND (ISNULL(ER.ParentType, 1) = 5 OR ISNULL(ER.ParentType, 1) = 6 OR ISNULL(ER.ParentType, 1) = 8) AND CH.Dir = 1) -- اوراق مالية مقبوضة
			OR  (@ReportSourceFlag & @ChequesOutParentType != 0		AND (ISNULL(ER.ParentType, 1) = 5 OR ISNULL(ER.ParentType, 1) = 6 OR ISNULL(ER.ParentType, 1) = 8) AND CH.Dir = 2) -- اوراق مالية مدفوعة
			OR  (@ReportSourceFlag & @BillParentType != 0			AND 
									ISNULL(ER.ParentType, 1) = 2	AND 
									(POWER(2, BT.BillType)  & @ReportSourceBillTypeFlag != 0) AND
									BT.GUID IS NOT NULL		AND 
									BT.Type = 1	
								
				) -- الفواتير
			OR  ((@ReportSourceFlag & @Transaction != 0)	AND (BT.GUID IS NOT NULL) AND (BT.Type = 3 OR BT.Type = 4 OR ( BT.Type = 2 AND (BT.BillType = 4 OR BT.BillType = 5)) ))-- المناقلات
			)
END
###########################################################################
CREATE PROCEDURE prcGeneralLedgerMultipleYears
	@Account [UNIQUEIDENTIFIER],
	@ContraAccount [UNIQUEIDENTIFIER] = 0x0,
	@CostCenter [UNIQUEIDENTIFIER]= 0x0,
	@CurGUID [UNIQUEIDENTIFIER] = 0x0,
	@StartDate [DATETIME] = '1990-01-01',	             
	@EndDate [DATETIME] = '2000-12-31',
	@Class [NVARCHAR](256) = '',
	@Contain [NVARCHAR](256) = '',	
	@NotContain [NVARCHAR](256) = '',
	@PostedOnly [BIT] = 1,
	@ReportSourceFlag [INT] = 63,
	@ReportSourceBillTypeFlag [INT] = 31,
	@GroupByEntry [INT] = 0,
	@DetailsByCostCenter [INT] = 0,
	@SearchBy [INT] = 1, --1 by_Guid, 2 by_Name 3 by_code,
	@AccountNameToSearch [NVARCHAR](512) = '',
	@AccountCodeToSearch [NVARCHAR](256) = '',
	@BalanceZeroOnFirstPeriod [BIT] = 0,
	@Customer [UNIQUEIDENTIFIER] = 0x0,
	@CustomerToSearch [NVARCHAR](512) = ''

AS 
BEGIN
  
	CREATE TABLE #MasterResult
	(
		DatabaseName NVARCHAR(256),
		FirstPeriodDate DATE,
		EndPeriodDate DATE,
		AccountGuid UNIQUEIDENTIFIER,
		AccountName NVARCHAR(256),
		AccountCode NVARCHAR(256),
		IsLocalDb	[BIT]
	)
	CREATE TABLE #Result
	(
		EnDate Date,
		CeNumber INT,
		CeGuid UNIQUEIDENTIFIER,
		EntryTypeName NVARCHAR(256),
		EnNotes NVARCHAR(1000),
		EnContraAccount UNIQUEIDENTIFIER,
		EnAccount UNIQUEIDENTIFIER,
		EnClass NVARCHAR(256),
		EnContraAccName NVARCHAR(256),
		EnContraAccLatinName NVARCHAR(256),
		EnContraAccCode NVARCHAR(256),
		EnCostCenterGuid UNIQUEIDENTIFIER,
		EnCostCenterName NVARCHAR(256),
		EnCostCenterLatinName NVARCHAR(256),
		EnCostCenterCode NVARCHAR(256),
		EnOriginalCurrency FLOAT,
		EnCurrDebit FLOAT,
		EnCurrCredit FLOAT,
		EnCurrencyVal FLOAT,
		EnCurrencyCode NVARCHAR(256),
		DatabaseName NVARCHAR(256),
		CeParentType INT,
		BillTypeName NVARCHAR(256),
		BillType INT,
		ParentGuid UNIQUEIDENTIFIER,
		ParentNumber INT,
		NoteTypeName NVARCHAR(1000),
		BranchName NVARCHAR(256),
		IsPosted INT,
		CeTypeGuid UNIQUEIDENTIFIER,
		acSecurity INT, 
		coSecurity INT, 
		ceSecurity INT,
		UserSecurity INT,
		Security INT,
		EnCustomer UNIQUEIDENTIFIER,
		EnCustomerName NVARCHAR(500)	
	)
	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 

	DECLARE @FirstPeriodDateForFirstDatabase DATE,
		@currentDbName NVARCHAR(128),
		@currentFirstPeriodDate DATE,
		@currentEndPeriodDate DATE,
		@firstLoop BIT,
		@Statement NVARCHAR(MAX),
		@Name  NVARCHAR(256),
		@Code NVARCHAR(256),
		@Query NVARCHAR(300),
		@UserId UNIQUEIDENTIFIER,
		@ParmDefinition NVARCHAR(300),
		@AccountGuid UNIQUEIDENTIFIER,
		@CustomerGuid UNIQUEIDENTIFIER,
		@CustomerName  NVARCHAR(500),
		@Lang [INT]

	EXEC @Lang = [dbo].fnConnections_GetLanguage;	 
	SET @ParmDefinition = N'@NameOut  NVARCHAR(256) OUTPUT, @CodeOut NVARCHAR(256) OUTPUT'
	SET @firstLoop = 1;
	SET @AccountGuid = @Account;
	SET @CustomerGuid = @Customer;
											  
	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate) ORDER BY FirstPeriod
	OPEN AllDatabases;	    
	
	FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
			   
	   IF @SearchBy = 2 -- search by name
	   BEGIN
		   SET @AccountGuid = 0x0;
		   SET @Query = 'SELECT @GuidOut = GUID FROM  [' + @currentDbName + '].[dbo].[ac000] WHERE Name = ''' + @AccountNameToSearch + '''';
		   EXEC sp_executesql @Query, N' @GuidOut UNIQUEIDENTIFIER OUTPUT', @GuidOut = @AccountGuid OUTPUT;
	   END
	   ELSE IF @SearchBy = 3 -- search by code
	   BEGIN
			SET @AccountGuid = 0x0;
			SET @Query = 'SELECT @GuidOut = GUID FROM  [' + @currentDbName  + '].[dbo].[ac000] WHERE Code = '''+ @AccountCodeToSearch +''''
			EXEC sp_executesql @Query, N' @GuidOut UNIQUEIDENTIFIER OUTPUT', @GuidOut = @AccountGuid OUTPUT;
	   END
	
	   SET @Name = ''; SET @Code = '';
	   SET @Query = 'SELECT @NameOut = Name, @CodeOut = Code FROM  [' + @currentDbName +'].[dbo].[ac000] WHERE GUID = ''' + CONVERT(NVARCHAR(38), @AccountGuid) + '''';
	   
	   EXEC sp_executesql @Query, @ParmDefinition, @NameOut = @Name OUTPUT, @CodeOut=@Code OUTPUT;
	   
	   INSERT INTO #MasterResult
	   VALUES (@currentDbName, CASE @firstLoop WHEN 1 THEN @StartDate ELSE @currentFirstPeriodDate END, 
			   @currentEndPeriodDate, 
			   CASE @currentDbName WHEN  DB_NAME() THEN @AccountGuid ELSE 0x0 END ,
			   @Name, 
			   @Code, 
			   CASE @currentDbName WHEN  DB_NAME() THEN 1 ELSE 0 END);

	   IF @firstLoop = 1
	   BEGIN
			SET @FirstPeriodDateForFirstDatabase = @currentFirstPeriodDate;
			SET @firstLoop = 0;
	   END

	   IF @currentDbName = DB_NAME()
	   BEGIN
			SELECT @UserId = [dbo].[fnGetCurrentUserGUID]()
	   END
	   ELSE
	   BEGIN 
		   SET @Query = 'SELECT TOP 1 @UserIdOut=GUID  FROM [' + @currentDbName + N'].[dbo].us000 WHERE bAdmin = 1'
		   EXEC sp_executesql @Query, N' @UserIdOut UNIQUEIDENTIFIER OUTPUT', @UserIdOut = @UserId OUTPUT;   
	   END
	   	   
	   SET @Statement =  N'INSERT INTO #Result EXEC [' + @currentDbName + '].[dbo].[prcGeneralLedgerPerYear] ' +
			''''+ CONVERT(NVARCHAR(38), @AccountGuid) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @ContraAccount) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @CostCenter) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @CurGUID) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @StartDate) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @EndDate) + ''',' +
			''''+ @Class + ''',' +
			''''+ @Contain + ''',' +
			''''+ @NotContain + ''',' +
			''''+ CONVERT(NVARCHAR(10), @PostedOnly) + ''',' +
			''''+ CONVERT(NVARCHAR(10), @ReportSourceFlag) + ''',' +
			''''+ CONVERT(NVARCHAR(10), @ReportSourceBillTypeFlag) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @UserId) + ''',' +
			''''+ CONVERT(NVARCHAR(10), @Lang) + ''',' +
			''''+ CONVERT(NVARCHAR(512), @CustomerToSearch) + ''',' +
			''''+ CONVERT(NVARCHAR(10), CASE @currentDbName WHEN  DB_NAME() THEN 1 ELSE 0 END) + ''',' +
			''''+ CONVERT(NVARCHAR(38), @CustomerGuid)  + '''' 
	   EXEC sp_executesql @Statement;
	   
	   FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	END;
	CLOSE AllDatabases;
	DEALLOCATE AllDatabases;

	EXEC prcCheckSecurity

	--set the end period date of the last database to be the EndDate from report parameters
	UPDATE #MasterResult
	SET EndPeriodDate = @EndDate
	WHERE DatabaseName = @currentDbName

	--calculate previous balance
	SELECT SUM(R.EnCurrDebit) - SUM(R.EnCurrCredit) AS PrevBalance
	FROM #Result R
	WHERE R.EnDate >= @FirstPeriodDateForFirstDatabase AND R.EnDate < @StartDate
	GROUP BY R.EnAccount
	
	DELETE #Result
	WHERE  
	EnDate < @StartDate OR EnDate > @EndDate
		
	SELECT * FROM #MasterResult
	ORDER BY FirstPeriodDate
	IF @GroupByEntry = 1
	BEGIN
		SELECT ISNULL(R.EntryTypeName, ISNULL(R.BillTypeName, ISNULL(R.NoteTypeName, ''))) + ' : ' + CONVERT(NVARCHAR(10), R.ParentNumber) Document,
				R.EnDate,
				R.CeNumber, 
				R.CeGuid,
				R.EntryTypeName,
				'' AS EnNotes ,
				0x0 AS EnContraAccount,
				0x0 AS EnAccount,
				'' AS EnClass,
				'' AS EnContraAccName,
				'' AS EnContraAccLatinName,
				'' AS EnContraAccCode,
				CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterGuid		ELSE  0x0 END AS EnCostCenterGuid,                                                              
				CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterName		ELSE  ''  END AS EnCostCenterName ,
				CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterLatinName	ELSE  ''  END AS EnCostCenterLatinName,
				CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterCode		ELSE  ''  END AS EnCostCenterCode,
				0 AS EnOriginalCurrency,
				SUM(R.EnCurrDebit) EnCurrDebit,
				SUM(R.EnCurrCredit) EnCurrCredit, 
				0 AS EnCurrencyVal,
				'' AS EncurrencyCode,
				R.DatabaseName,
				R.CeParentType, 
				R.BillTypeName,
				R.BillType,
				R.ParentGuid,
				R.ParentNumber,
				R.NoteTypeName,
				R.BranchName,
				R.IsPosted,
				0x0 AS CeTypeGuid,
				R.EnCustomer,
				R.EnCustomerName
		FROM #Result R
		GROUP BY 
		R.DatabaseName, 
		R.CeGuid, 
		R.CeNumber, 
		R.EnDate, 
		R.EntryTypeName, 
		R.BillTypeName,
		R.NoteTypeName,
		R.CeParentType, 
		R.BillTypeName, 
		R.BillType,
		R.ParentGuid,
		R.ParentNumber,
		R.BranchName,
		R.IsPosted,
		R.EnCustomer,
		R.EnCustomerName,
		CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterGuid		ELSE  0x0 END,
		CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterName		ELSE  ''  END,
		CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterLatinName	ELSE  ''  END,
		CASE @DetailsByCostCenter WHEN 1 THEN R.EnCostCenterCode		ELSE  ''  END,
		EnNotes,
		EnAccount,
		EnClass,
		EnContraAccName,
		EnContraAccLatinName,
		EnContraAccCode,
		EnContraAccount,
		EnOriginalCurrency,
		EnCurrencyVal,
		EncurrencyCode,
		CeTypeGuid
		ORDER BY R.EnDate
	END
	ELSE
	BEGIN
		SELECT ISNULL(R.EntryTypeName, ISNULL(R.BillTypeName, ISNULL(R.NoteTypeName, ''))) + ' : ' + CONVERT(NVARCHAR(10), R.ParentNumber) Document, R.* 
		FROM #Result R
		ORDER BY R.EnCustomerName,R.EnDate
	END

	SELECT * FROM #SecViol
END
###########################################################################
CREATE FUNCTION FnGetReportDataSources(@StartDate [DATE],	 @EndDate [DATE])
RETURNS @result 
	TABLE (
		[DatabaseName] [nvarchar](150) NOT NULL,
		[FirstPeriod] [date] NOT NULL,
		[EndPeriod] [date] NOT NULL
	)  
BEGIN
	INSERT INTO @result
	SELECT RDS.DatabaseName, RDS.FirstPeriod, RDS.EndPeriod 
	FROM 
		ReportDataSources000 RDS inner join  master.sys.databases DB 
		ON RDS.DatabaseName = DB.name COLLATE ARABIC_CI_AI
	WHERE 
		(RDS.FirstPeriod <= @EndDate) and (RDS.EndPeriod >= @StartDate)
	
	RETURN 
END
###########################################################################
CREATE FUNCTION fnGetOtherReportDataSources(@StartDate [DATE], @EndDate [DATE])
RETURNS @result 
	TABLE (
		[DatabaseName] [nvarchar](150) NOT NULL,
		[FirstPeriod] [date] NOT NULL,
		[EndPeriod] [date] NOT NULL
	)  
BEGIN
	INSERT INTO @result
	SELECT RDS.DatabaseName, RDS.FirstPeriod, RDS.EndPeriod 
	FROM 
		ReportDataSources000 RDS
	WHERE 
		(RDS.FirstPeriod <= @EndDate) AND (RDS.EndPeriod >= @StartDate) AND	(DB_NAME() != RDS.DatabaseName)
	
	RETURN 
END
###########################################################################
CREATE PROC prcCheckAccountDifferences
	@Account [UNIQUEIDENTIFIER],
	@StartDate [DATETIME],
	@EndDate [DATETIME] 
AS 
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #Result
	(
		DatabaseName NVARCHAR(256),
		FirstPeriodDate DATE,
		EndPeriodDate DATE,
		AccountName NVARCHAR(256),
		AccountCode NVARCHAR(256)
	)
	DECLARE @currentDbName NVARCHAR(128);
	DECLARE @currentFirstPeriodDate DATE;
	DECLARE @currentEndPeriodDate DATE;
	DECLARE @Name  NVARCHAR(256)
	DECLARE @Code NVARCHAR(256)
	DECLARE @Query NVARCHAR(300)
	DECLARE @ParmDefinition NVARCHAR(300)
	SET @ParmDefinition = N'@NameOut  NVARCHAR(256) OUTPUT, @CodeOut NVARCHAR(256) OUTPUT'
	DECLARE AllDatabases CURSOR FOR				 
	SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM FnGetReportDataSources(@StartDate, @EndDate)
	OPEN AllDatabases;	    
	
	FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		
	   SET @Name = ''; SET @Code = '';
	   SET @Query = 'SELECT @NameOut = Name, @CodeOut = Code FROM  ['+ @currentDbName +'].[dbo].[ac000] WHERE GUID = '''+ CONVERT(NVARCHAR(38), @Account) +'''';
	   EXEC sp_executesql @Query, @ParmDefinition, @NameOut = @Name OUTPUT, @CodeOut=@Code OUTPUT;
	   INSERT INTO #Result
	   VALUES(@currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate, @Name, @Code)
	   
	   
	   FETCH NEXT FROM AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
	END;
	CLOSE AllDatabases;
	DEALLOCATE AllDatabases;

	SELECT @Name = Name FROM ac000 WHERE GUID = @Account
	SELECT @Code = Code FROM ac000 WHERE GUID = @Account
	SET @currentFirstPeriodDate = GETDATE();
	SET @currentEndPeriodDate = GETDATE();

	INSERT INTO #Result
	VALUES(DB_NAME(), @currentFirstPeriodDate, @currentEndPeriodDate, @Name, @Code)


	SELECT DISTINCT AccountName, AccountCode FROM #Result
END
###########################################################################
#END
