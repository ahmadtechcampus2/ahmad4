############################################################
CREATE  PROCEDURE RepPatientGL
	@Account 	UNIQUEIDENTIFIER,	--—ﬁ„ «·Õ”«»  
	@CostGuid 	UNIQUEIDENTIFIER,	--—ﬁ„ „—ﬂ“ «·ﬂ·›…  
	@StartDate 	DATETIME,		-- «—ÌŒ «·»œ«Ì…  
	@EndDate 	DATETIME,-- «—ÌŒ «·‰Â«Ì…  
	@GroupByFile 		Int = 0,  
	@PatientGuid	UNIQUEIDENTIFIER = 0X0,	--«·„—Ì÷  
	@PatientDebitAccount UNIQUEIDENTIFIER = 0x0,
	@FileGuid UNIQUEIDENTIFIER = 0x0
AS  
	SET NOCOUNT ON 
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
	  
	CREATE TABLE #FinalResult  
	(  
		[CeGUID] 	[UNIQUEIDENTIFIER],  
		[CeNumber]	[INT],  
		[AccGUID] 	[UNIQUEIDENTIFIER],      
		[CostGuid] 	[UNIQUEIDENTIFIER],  
		[DATE] 		[DATETIME],  
		[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI,  
		[DEBIT]		[FLOAT],  
		[CREDIT]	[FLOAT],  
		[FileGuid] 	[UNIQUEIDENTIFIER],  
		[PatientName]	[NVARCHAR] (250) COLLATE Arabic_CI_AI,  
		[FILECODE]	[NVARCHAR] (250) COLLATE Arabic_CI_AI,  
		[DateIn]	[DateTime],  
		[DateOut]	[DateTime],  
		[ceParentGUID] [UNIQUEIDENTIFIER],       
		[ceRecType] [INT],       
		[ParentNumber] NVARCHAR(250),   
		[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,   
		[ObvaAccName][NVARCHAR](250) COLLATE ARABIC_CI_AI   
	)  
	INSERT INTO #Result1  
	EXEC prcHosGetEntries @Account, @CostGuid, @StartDate, @EndDate, @PatientGuid, @FileGuid  
	IF (@PatientDebitAccount = 0X0) 
		INSERT INTO #FinalResult  
		SELECT  
			r.[CeGUID],  
			r.[CeNumber],  
			r.[AccGUID],   
			r.[CostGuid],  
			r.[DATE],	  
			r.[EnNotes],  
			r.[DEBIT],  
			r.[CREDIT],  
			r.[FileGuid],  
			PF.[NAME] ,  
			PF.[CODE],   
			PF.[DateIn],  
			PF.[DateOut],  
			r.[ceParentGUID],  
			r.[ceRecType],  
			r.[ParentNumber],  
			r.[ParentName],  
			ISNULL(AC.acName, '')  
		FROM #Result1 AS r  
		INNER JOIN VwEn ON VwEn.enGuid = r.[enGuid]		  
		LEFT JOIN VWAC	AS AC ON AC.acGuid = VwEn.enContraAcc  
		INNER JOIN VwHosFile as PF ON PF.Guid = r.[FileGuid] 
		WHERE ((PF.PatientGuid = @PatientGuid) OR (@PatientGuid = 0x0))
			AND ((PF.Guid = @FileGuid) OR (@FileGuid = 0x0)) 
			
	ELSE  
		INSERT INTO #FinalResult  
		SELECT  
			r.[CeGUID],  
			r.[CeNumber],  
			r.[AccGUID],   
			r.[CostGuid],  
			r.[DATE],	  
			r.[EnNotes],  
			r.[DEBIT],  
			r.[CREDIT],  
			r.[FileGuid],  
			PF.[NAME] ,  
			PF.[CODE],   
			PF.[DateIn],  
			PF.[DateOut],  
			r.[ceParentGUID],  
			r.[ceRecType],  
			r.[ParentNumber],  
			r.[ParentName],  
			AC.acName  
		FROM #Result1 AS r  
		INNER JOIN VwEn ON VwEn.enGuid = r.[enGuid]		  
		INNER JOIN VWAC	AS AC ON AC.acGuid = VwEn.enContraAcc  
		INNER JOIN VwHosFile as PF ON PF.Guid = r.[FileGuid]  
		INNER JOIN hosPatientAccounts000 AS Pac on Pac.PatientGuid  = PF.PatientGuid  
			WHERE Pac.AccGuid = @PatientDebitAccount
			AND ((PF.PatientGuid = @PatientGuid) OR (@PatientGuid = 0x0))
			AND ((PF.Guid = @FileGuid) OR (@FileGuid = 0x0)) 	
	IF (@GroupByFile = 0)  
		SELECT * FROM 	#FinalResult  
		ORDER BY [DATE], CeNumber  
	ELSE  
		SELECT * FROM 	#FinalResult  
		ORDER BY [FileCode], [Date], CeNumber  
	/*	  
	IF (@SortBy = 2)  
			SELECT * FROM 	#RESULT  
			ORDER BY HosType, [Date], EntryNumber  
	IF (@SortBy = 3)  
			SELECT * FROM 	#RESULT  
			ORDER BY [FileCode], [HosType],[Date], EntryNumber  
	*/  

##########################################################
CREATE  PROCEDURE RepHosPatientFileGL
	@FileGUID	UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON

	CREATE TABLE #TEMP
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
	
	DECLARE @AccountGuid UNIQUEIDENTIFIER,
		@CostGuid UNIQUEIDENTIFIER
			 
	SELECT 
		@AccountGuid = AccGuid,
		@CostGuid = CostGuid
	FROM VWHOSFILE
	WHERE GUID = @FileGUID


	CREATE TABLE #FinalResult 
	( 
		[CeGUID] 	[UNIQUEIDENTIFIER], 
		[CeNumber]	[INT], 
		[DATE] 		[DATETIME], 
		[EnNotes] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI, 
		[DEBIT]		[FLOAT], 
		[CREDIT]	[FLOAT], 
		[ceParentGUID] [UNIQUEIDENTIFIER],      
		[ceRecType] [INT],      
		[ParentNumber] [NVARCHAR](250),  
		[ParentName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,  
		[ObvaAccName][NVARCHAR](250) COLLATE ARABIC_CI_AI  
	) 

	INSERT INTO #TEMP
	EXEC prcHosGetEntries @AccountGuid, @CostGuid, '', '2100', 0x0
	 
	INSERT INTO #FinalResult 
	SELECT 
		t.[CeGUID], 
		t.[CeNumber], 
		t.[DATE],	 
		t.[EnNotes], 
		t.[DEBIT], 
		t.[CREDIT], 
		t.[ceParentGUID], 
		t.[ceRecType], 
		t.[ParentNumber], 
		t.[ParentName], 
		ISNULL(AcContra.acName, '') 
	FROM #TEMP AS t
	INNER JOIN VwEn ON VwEn.enGuid = t.[enGuid]		 
	LEFT JOIN VWAC	AS AcContra ON AcContra.acGuid = VwEn.enContraAcc 
	WHERE  t.[FileGuid] = @FileGUID
			
	--INNER JOIN hosPatientAccounts000 AS Pac on Pac.PatientGuid  = PF.PatientGuid 
		--WHERE Pac.AccGuid = @PatientDebitAccount 
	SELECT * FROM 	#FinalResult 
	ORDER BY [DATE], CeNumber 
############################################################################
#END
