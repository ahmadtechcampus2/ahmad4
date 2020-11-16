################################################
CREATE PROC prcHosPatientRep
			@Account uniqueidentifier, 
			@CostGuid uniqueidentifier,
			@ResponsiblePerson uniqueidentifier,
			@FromDate DateTime = '',  
			@ToDate DateTime = '2100', 
			@PatientDebitAccount uniqueidentifier = 0x0, 
			@SortBy INT = 0 -- patientName, FileCode, DateTin,   
AS  
	SET NOCOUNT ON  
		 
	CREATE TABLE #FinalResult  
	( 
		FileGuid uniqueidentifier, 
		PatientName NVARCHAR(250) COLLATE Arabic_CI_AI, 
		FileCode  NVARCHAR(250) COLLATE Arabic_CI_AI, 
		ResPrsName  NVARCHAR(250) COLLATE Arabic_CI_AI, 
		Account  uniqueidentifier, 
		CostGuid uniqueidentifier, 
		CostName  NVARCHAR(250) COLLATE Arabic_CI_AI, 
		DateIn DateTime, 
		DateOut DateTime, 
		Stay FLOAT DEFAULT 0, 
		GeneralTest FLOAT  DEFAULT 0, 
		Cosule FLOAT DEFAULT 0, 
		ConsumedMaster FLOAT DEFAULT 0, 
		RadioGraphy FLOAT DEFAULT 0, 
		SurgeryRoom FLOAT DEFAULT 0, 
		SurgeryWorkers FLOAT DEFAULT 0, 
		SurgeryPatientCons FLOAT DEFAULT 0, 
		SurgeryCons FLOAT DEFAULT 0, 
		OhtersDebit FLOAT DEFAULT 0, 
		SumCredit FLOAT DEFAULT 0, 
		PatientDebitAccount uniqueidentifier  DEFAULT 0x0, 
		PatientDebitPercent FLOAT DEFAULT 0 
	) 
	CREATE TABLE #temp 
	(		[CeGUID] 	[UNIQUEIDENTIFIER], 
			[enGUID] 	[UNIQUEIDENTIFIER],  
			[CeNumber]	[INT], 
			[EnNumber]	[INT], 
			[AccGUID] 	[UNIQUEIDENTIFIER],     
			[CostGuid] 	[UNIQUEIDENTIFIER], 
			[DATE] 		[DATETIME], 
			[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI, 
			[DEBIT]		[FLOAT], 
			[CREDIT]	[FLOAT], 
			--[ParentGuid] 	[UNIQUEIDENTIFIER], 
			[FileGuid] 	[UNIQUEIDENTIFIER], 
			[ceParentGUID] [UNIQUEIDENTIFIER],      
			[ceRecType] [INT],      
			[ParentNumber] [NVARCHAR](250),  
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ceTypeGuid] [UNIQUEIDENTIFIER], 
			--[HosType]	[INT], 
			[ceSecurity] [INT],     
			[accSecurity] [INT] 
	) 
	INSERT INTO #temp 
	EXEC prcHosGetEntries @Account, @CostGuid, @FromDate, @ToDate
	

	CREATE TABLE #TBL  
	( 
		FILEGUID uniqueidentifier, 
		RecType int, 
		SumDebit float,	 
		SumCredit float 
	) 
	CREATE INDEX ind1 ON #TBL(FileGuid) 
	CREATE INDEX ind2 ON #FinalResult(FileGuid) 
	INSERT INTO #TBL 
	SELECT  
		FileGuid, 
		ceRecType, 
		Sum(Debit), 
		Sum(Credit)  
	FROM #temp  
	GROUP BY FileGuid, ceRecType 
		 
	IF (@PatientDebitAccount = 0x0) 
		INSERT INTO #FinalResult 
			(FileGuid, PatientName, FileCode,  
			Account, CostGuid, CostName, DateIn, DateOut) 
		SELECT  
			Distinct(res.FileGuid), 
			f.[Name], 
			f.Code, 
			f.AccGuid, 
			f.CostGuid, 
			co.coCode + '-' + co.coName, 
			f.DateIn, 
			f.DateOut 
		FROM vwhosfile AS f 
		INNER JOIN #TBL AS res on res.FileGuid = f.Guid 
		INNER JOIN VwCo AS co on co.CoGuid = f.CostGuid 
	ELSE 
		INSERT INTO #FinalResult 
			(FileGuid, PatientName, FileCode,  
			Account, CostGuid, CostName, DateIn, DateOut, PatientDebitPercent) 
		SELECT  
			Distinct(res.FileGuid), 
			f.[Name], 
			f.Code, 
			f.AccGuid, 
			f.CostGuid, 
			co.coCode + '-' + co.coName, 
			f.DateIn, 
			f.DateOut, 
			ac.ratio 
		FROM vwhosfile AS f 
		INNER JOIN hosPatientAccounts000 AS ac on ac.PatientGuid  = f.PatientGuid 
		INNER JOIN #TBL AS res on res.FileGuid = f.Guid 
		INNER JOIN VwCo AS co on co.CoGuid = f.CostGuid 
		WHERE ac.AccGuid = @PatientDebitAccount 
	
	UPDATE 	#FinalResult 
		SET STAY = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 303 
	UPDATE 	#FinalResult 
		SET GeneralTest = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 300 
	UPDATE 	#FinalResult 
		SET Cosule = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 301 
	UPDATE 	#FinalResult 
		SET ConsumedMaster = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 312 
	UPDATE 	#FinalResult 
		SET RadioGraphy = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 309 
	UPDATE 	#FinalResult 
		SET SurgeryRoom = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 304 
	UPDATE 	#FinalResult 
		SET SurgeryWorkers = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 202 
	UPDATE 	#FinalResult 
		SET SurgeryCons = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 310 
	UPDATE 	#FinalResult 
		SET SurgeryPatientCons = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 311 
	
	UPDATE #FinalResult
		SET ResPrsName = p.name FROM HosPerson000 AS p
				 INNER JOIN HosEmployee000 AS emp 
					ON emp.PersonGUID = p.GUID
				 INNER JOIN HosPFile000 AS f 
					ON f.DoctorGUID = emp.GUID
				 INNER JOIN #FinalResult AS rs
					ON f.GUID = rs.FileGUID
	DECLARE @ResponsiblePersonName NVARCHAR(50)
	
	SELECT @ResponsiblePersonName = p.name 
	FROM HosPerson000 AS p
		INNER JOIN HosEmployee000 AS emp 
			ON emp.PersonGUID = p.GUID
		INNER JOIN HosPFile000 AS f 
			ON f.DoctorGUID = emp.GUID
	WHERE f.DoctorGUID = @ResponsiblePerson
	
	IF (@ResponsiblePersonName IS NOT NULL) 
		DELETE FROM #FinalResult
		WHERE ISNULL(ResPrsName , '') NOT LIKE @ResponsiblePersonName
	ELSE
		IF (@ResponsiblePerson <> 0X0)
			DELETE FROM #FinalResult
		
	CREATE TABLE #OtherDebitTable 
	( 
		FILEGUID uniqueidentifier, 
		SumDebit float 
	) 
	INSERT INTO #OtherDebitTable 
	SELECT  
		FileGuid, 
		Sum(Debit) 
	FROM #temp  
	WHERE ceRecType NOT IN (303, 300, 301, 312, 309, 304, 202, 310, 311) 
	GROUP BY FileGuid	 
	CREATE TABLE #CreditTable 
	( 
		FILEGUID uniqueidentifier, 
		SumCredit float 
	) 
	INSERT INTO #CreditTable 
	SELECT  
		FileGuid, 
		Sum(Credit) 
	FROM #temp 
	GROUP BY FileGuid	 
	UPDATE 	#FinalResult 
		SET OhtersDebit = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #OtherDebitTable as r on r.FileGuid = f.FileGuid 
	UPDATE 	#FinalResult 
		SET SumCredit = IsNull(r.SumCredit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #CreditTable as r on r.FileGuid = f.FileGuid 
	
	IF (@SortBy = 0) 
		SELECT * FROM #FinalResult 
		order by PatientName 
	ELSE 
	IF (@SortBy = 1) 
		SELECT * FROM #FinalResult 
		order by FileCode 
	ELSE 
	IF (@SortBy = 2) 
		SELECT * FROM #FinalResult 
		order by DateIn 
	ELSE 
	IF (@SortBy = 3) 
		SELECT * FROM #FinalResult 
		order by (Stay + GeneralTest + Cosule + ConsumedMaster + RadioGraphy + SurgeryRoom +  
				SurgeryWorkers + SurgeryPatientCons + SurgeryCons + OhtersDebit) DESC 
	ELSE 
	IF (@SortBy = 4) 
		SELECT * FROM #FinalResult 
		order by (Stay + GeneralTest + Cosule + ConsumedMaster + RadioGraphy + SurgeryRoom +  
				SurgeryWorkers + SurgeryPatientCons + SurgeryCons + OhtersDebit - SumCredit) DESC 
##########################################################################################
CREATE PROC prcHosHtPatientRep
			@Account uniqueidentifier, 
			@CostGuid uniqueidentifier, 
			@ResponsiblePerson uniqueidentifier, 
			@FromDate DateTime = '',  
			@ToDate DateTime = '2100', 
			@GuestDebitAccount uniqueidentifier = 0x0, 
			@SortBy INT = 0 -- patientName, FileCode, DateTin,   
AS  
	SET NOCOUNT ON  
		 
	CREATE TABLE #FinalResult  
	( 
		FileGuid uniqueidentifier, 
		GuestName NVARCHAR(250)  COLLATE Arabic_CI_AI, 
		FileCode  NVARCHAR(250) COLLATE Arabic_CI_AI,
		EmpName NVARCHAR(250) COLLATE Arabic_CI_AI, 
		Account  uniqueidentifier, 
		CostGuid uniqueidentifier, 
		CostName  NVARCHAR(250) COLLATE Arabic_CI_AI, 
		DateIn DateTime, 
		DateOut DateTime, 
		Stay FLOAT DEFAULT 0, 
		GeneralTest FLOAT DEFAULT 0, 
		ConsumedMaster FLOAT DEFAULT 0, 
		OhtersDebit FLOAT DEFAULT 0, 
		SumCredit FLOAT DEFAULT 0, 
		GuestDebitAccount uniqueidentifier DEFAULT 0x0, 
		GuestDebitPercent FLOAT DEFAULT 0  
	) 
	CREATE TABLE #temp 
	(		[CeGUID] 	[UNIQUEIDENTIFIER], 
			[enGUID] 	[UNIQUEIDENTIFIER],  
			[CeNumber]	[INT], 
			[EnNumber]	[INT], 
			[AccGUID] 	[UNIQUEIDENTIFIER],     
			[CostGuid] 	[UNIQUEIDENTIFIER], 
			[DATE] 		[DATETIME], 
			[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI, 
			[DEBIT]		[FLOAT], 
			[CREDIT]	[FLOAT], 
			--[ParentGuid] 	[UNIQUEIDENTIFIER], 
			[FileGuid] 	[UNIQUEIDENTIFIER], 
			[ceParentGUID] [UNIQUEIDENTIFIER],      
			[ceRecType] [INT],      
			[ParentNumber] [NVARCHAR](250),  
			[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ceTypeGuid] [UNIQUEIDENTIFIER], 
			--[HosType]	[INT], 
			[ceSecurity] [INT],     
			[accSecurity] [INT] 
	) 
	INSERT INTO #temp 
	EXEC prcHosGetEntries @Account, @CostGuid, @FromDate, @ToDate 
	CREATE TABLE #TBL  
	( 
		FILEGUID uniqueidentifier, 
		RecType int, 
		SumDebit float 
	) 
	CREATE INDEX ind1 ON #TBL(FileGuid) 
	CREATE INDEX ind2 ON #FinalResult(FileGuid) 
	INSERT INTO #TBL 
	SELECT  
		FileGuid, 
		ceRecType, 
		Sum(Debit) 
	FROM #temp  
	GROUP BY FileGuid, ceRecType 
	IF (@GuestDebitAccount = 0x0) 
		INSERT INTO #FinalResult 
			(FileGuid, GuestName, FileCode,  
			Account, CostGuid, CostName, DateIn, DateOut) 
		SELECT  
			Distinct(res.FileGuid), 
			f.[Name], 
			f.Code, 
			f.AccGuid, 
			f.CostGuid, 
			co.coCode + '-' + co.coName, 
			f.DateIn, 
			f.DateOut 
		FROM vwhosfile AS f 
		INNER JOIN #TBL AS res on res.FileGuid = f.Guid 
		INNER JOIN VwCo AS co on co.CoGuid = f.CostGuid 
	ELSE 
		INSERT INTO #FinalResult 
			(FileGuid, GuestName, FileCode,  
			Account, CostGuid, CostName, DateIn, DateOut, GuestDebitPercent) 
		SELECT  
			Distinct(res.FileGuid), 
			f.[Name], 
			f.Code, 
			f.AccGuid, 
			f.CostGuid, 
			co.coCode + '-' + co.coName, 
			f.DateIn, 
			f.DateOut, 
			ac.ratio 
		FROM vwhosfile AS f 
		INNER JOIN hosPatientAccounts000 AS ac on ac.PatientGuid  = f.PatientGuid 
		INNER JOIN #TBL AS res on res.FileGuid = f.Guid 
		INNER JOIN VwCo AS co on co.CoGuid = f.CostGuid 
		WHERE ac.AccGuid = @GuestDebitAccount 
	UPDATE 	#FinalResult 
		SET STAY = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 303 
	UPDATE 	#FinalResult 
		SET GeneralTest = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 300 
	UPDATE 	#FinalResult 
		SET ConsumedMaster = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #TBL as r on r.FileGuid = f.FileGuid 
	WHERE RecType = 312 

	UPDATE #FinalResult
		SET EmpName = p.name FROM HosPerson000 AS p
				INNER JOIN HosEmployee000 AS emp 
					ON emp.PersonGUID = p.GUID
				INNER JOIN HosPFile000 AS f 
					ON f.DoctorGUID = emp.GUID
				INNER JOIN #FinalResult AS rs
					ON f.GUID = rs.FileGUID
	DECLARE @ResponsiblePersonName NVARCHAR(50)
	
	SELECT @ResponsiblePersonName = p.name 
	FROM HosPerson000 AS p
		INNER JOIN HosEmployee000 AS emp 
			ON emp.PersonGUID = p.GUID
		INNER JOIN HosPFile000 AS f 
			ON f.DoctorGUID = emp.GUID
	WHERE f.DoctorGUID = @ResponsiblePerson
	
	IF (@ResponsiblePersonName IS NOT NULL) 
		DELETE FROM #FinalResult
		WHERE ISNULL(EmpName , '') NOT LIKE @ResponsiblePersonName
	ELSE
		IF (@ResponsiblePerson <> 0X0)
			DELETE FROM #FinalResult

	CREATE TABLE #OtherDebitTable 
	( 
		FILEGUID uniqueidentifier, 
		SumDebit float 
	) 
	INSERT INTO #OtherDebitTable 
	SELECT  
		FileGuid, 
		Sum(Debit) 
	FROM #temp 
	WHERE ceRecType NOT IN (300, 303, 312)			 
	GROUP BY FileGuid	 
	CREATE TABLE #CreditTable 
	( 
		FILEGUID uniqueidentifier, 
		SumCredit float 
	) 
	INSERT INTO #CreditTable 
	SELECT  
		FileGuid, 
		Sum(Credit) 
	FROM #temp 
	GROUP BY FileGuid	 
	UPDATE 	#FinalResult 
		SET OhtersDebit = IsNull(r.SumDebit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #OtherDebitTable as r on r.FileGuid = f.FileGuid 
	UPDATE 	#FinalResult 
		SET SumCredit = IsNull(r.SumCredit, 0) 
		FROM #FinalResult as f  
		INNER JOIN #CreditTable as r on r.FileGuid = f.FileGuid 
	IF (@SortBy = 0) 
		SELECT * FROM #FinalResult 
		order by GuestName 
	ELSE 
	IF (@SortBy = 1) 
		SELECT * FROM #FinalResult 
		order by FileCode 
	ELSE 
	IF (@SortBy = 2) 
		SELECT * FROM #FinalResult 
		order by DateIn 
	ELSE 
	IF (@SortBy = 3) 
		SELECT * FROM #FinalResult 
		order by (Stay + GeneralTest + ConsumedMaster + OhtersDebit) DESC 
	ELSE 
	IF (@SortBy = 4) 
		SELECT * FROM #FinalResult 
		order by (Stay + GeneralTest + ConsumedMaster + OhtersDebit - SumCredit) DESC 
##########################################################################################
#END
