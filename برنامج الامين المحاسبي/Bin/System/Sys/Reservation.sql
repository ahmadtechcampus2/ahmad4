########################################
CREATE PROC PrcHosGetPatientReservation( @PatientGuid  UNIQUEIDENTIFIER)
AS 
SET NOCOUNT ON 
	SELECT 
	*
	FROM vwhosReservationDetails
	WHERE PatientGuid = @PatientGuid AND STATE  = 0
###################################################################
CREATE  proc prcHos_ConfirmResrvation
	@ResGuid UNIQUEIDENTIFIER

AS 
SET NOCOUNT ON 
	DECLARE @FileGuid	UNIQUEIDENTIFIER,
		@SiteGuid		UNIQUEIDENTIFIER,
		@FROMDate		DATETIME,
		@ToDate			DATETIME,
		@PayGuid		UNIQUEIDENTIFIER,	
		@Pay			INT,
	 	@CurrencyGuid	UNIQUEIDENTIFIER,
		@CurrencyVal	INT, 
		@StayAcc		UNIQUEIDENTIFIER,
		@cost			FLOAT,
		@StayGuid		UNIQUEIDENTIFIER,
		@number			INT,
		@StayEntryGuid	UNIQUEIDENTIFIER

	SELECT 
		@FileGuid = FileGuid,
		@SiteGuid = SiteGuid,	
		@FROMDate = FROMDate,
		@ToDate = ToDate,
		@PayGuid = PayGuid,
		@Pay = Pay,
		@CurrencyGuid = CurrencyGuid,
		@CurrencyVal = CurrencyVal
	--INTO #temp
	FROM	HosReservationDetails000  WHERE Guid = @ResGuid
	
	
	UPDATE HosReservationDetails000 
	SET IsConfirm = 1
	WHERE Guid = @ResGuid
	
	UPDATE hospfile000 
		SET SiteGuid 	=  @SiteGuid,
		ClinicalTestSecurity = 1,
		MedConsSecurity = 1,
		DoctorFollowingSecurity = 1,
		NurseFollowingSecurity = 1,
		DateIn = @FROMDate, 
		DateOut  = @ToDate	
	WHERE Guid = @FileGuid

	SELECT @number = MAX(number) + 1 FROM HosStay000
	IF (@number IS NULL)
		SET @number = 1
	
	SELECT @StayAcc = Value FROM op000 WHERE [Name] = 'HosCfg_File_StayAcc'     	
	
	CREATE TABLE #t (cost FLOAT)
	INSERT INTO #t
	EXEC repGetSiteCost @SiteGuid, @FROMDate, @ToDate

	SELECT @cost = cost
	FROM #t 	
	
	IF EXISTS (SELECT * FROM HosStay000 WHERE FileGuid = @FileGuid)
	BEGIN
	
		DELETE FROM er000
		WHERE ParentGuid IN 
		(SELECT GUID FROM HosStay000 WHERE FileGUID = @FileGuid)
		
		DELETE FROM HosStay000
		WHERE FileGUID = @FileGuid
	END

	SET @StayGuid = NEWID()  
	INSERT INTO HosStay000 
			([Number],[Guid],[FileGuid],[StartDate],[EndDate],[Cost],--[OtherCost],
			 [DisCount], [Notes], [Security],[SiteGuid], [AccGuid], 
			 [CurrencyGUID], [CurrencyVal]
			)
	SELECT
		@number,
		@StayGuid,
		@FileGuid,
		@FROMDate,
		@ToDate,
		Cost,
		0, --discount
		'„Ê·œ… „‰ ÕÃ“',
		1,
		@SiteGuid,
		@StayAcc,
		@CurrencyGuid,
		@CurrencyVal
	FROM #t
	
	
	EXEC prcHosStay_GenEntry @StayGuid
###################################################################
CREATE  proc prcHosRes_GenEntry 
	@ResGuid UNIQUEIDENTIFIER
AS 
SET NOCOUNT ON 
	DECLARE @entryGUID			UNIQUEIDENTIFIER,
			@payGuid  			UNIQUEIDENTIFIER,  
			@EntryNum 			INT,
			@NUMBER				INT,
			@EType 				UNIQUEIDENTIFIER,
			@DefCurBranch		UNIQUEIDENTIFIER, 
			@DefCurrencyGuid	UNIQUEIDENTIFIER, 
			@DefCurrencyVal		INT,
			@DepitAcc			UNIQUEIDENTIFIER,
			@CurrencyGuid		UNIQUEIDENTIFIER,
			@CurrencyVal		FLOAT,
			@Str				NVARCHAR(100)
	
	SELECT @DefCurBranch =  Value FROM op000 WHERE [Name] = 'TrnCfg_CurrentBranch'    
	IF (@DefCurBranch IS NULL )
		SET @DefCurBranch = 0X0
		
	SELECT @DefCurrencyGuid = Value FROM op000 WHERE [Name] = 'AmnCfg_DefaultCurrency'     
	SELECT @DefCurrencyVal = CurrencyVal FROM my000 WHERE Guid = @DefCurrencyGuid
	
	SET @entryGUID = NEWID()
	SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)     
	SET @payGuid = NEWID()
	SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN ' ÿ·» ÕÃ“ ' ELSE ' ÿ·» ÕÃ“ ' END    
	SELECT @EType = Value FROM op000 WHERE [Name] = 'HosCfg_Reservation_PayType'
	SELECT @Number = ISNULL(MAX(Number) + 1, 1) FROM Py000  WHERE typeGUID = @EType
	SELECT 	@depitAcc = DefAccGuid FROM et000 WHERE guid = @EType
	
		
	SELECT @CurrencyGuid = Value FROM op000 WHERE [Name] = 'AmnCfg_DefaultCurrency'     
	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE Guid = @CurrencyGuid

	SELECT  
		res.FileGuid,
		dbo.HosGetJustDate(GetDate())  AS CurrentDate,
		(res.Pay - res.Discount)  * (res.CurrencyVal/@DefCurrencyVal)  AS cost,
		res.notes, 
		p.AccGUID AS CreditAcc,
		p.CostGuid AS CostGuid,
		pn.[Name]
		--security
	INTO #temp	 	
	FROM 
	HosReservationDetails000 AS res  
	INNER JOIN HosPfile000 AS p ON res.FileGuid = p.Guid   
	INNER JOIN hospatient000 AS pat ON pat.Guid = p.patientguid 
	INNER JOIN hosperson000 AS  pn ON pn.Guid = pat.personGuid  
	WHERE res.guid = @ResGuid
	
	INSERT INTO py000
			([Number],[Date],[Notes], [Guid], [typeGUID],[AccountGuid], 
			 [CurrencyGUID], [CurrencyVal], 
			 [Security], [BranchGuid]) 
		SELECT	
			@Number,
			[CurrentDate],
			[Name] + ' ' +@Str + ' ' +  notes  ,  
			@payGuid,
			@EType,
			@depitAcc,
			@CurrencyGuid,
			@CurrencyVal,
			0,--security,
			@DefCurBranch
		FROM #temp 
	
	INSERT INTO [er000]  
		SELECT   
		NEWID(),  
		@entryGUID, 
		@payGuid, 
		4,  
		@Number 
 	
 		
	INSERT INTO [ce000]  
	    	([typeGUID], [Type],  [Number], [Date], [Debit],  
		 [Credit], [Notes], [CurrencyVal], [IsPosted],  
		 [Security], [Branch],[GUID], [CurrencyGUID])    
	SELECT 
		0x0,  
		1,  
		@entryNum,  
		[Currentdate], 
		cost, 
		cost, 
		[Name] + ' ' +@Str + ' ' +  notes  ,  
		@CurrencyVal, 
		0, 
		0,--security,  
		@DefCurBranch, 
		@entryGUID, 
		@CurrencyGuid  
	FROM #temp  
			 
INSERT INTO [en000]  
	 
		 ([Number],  
		 [Date],  
		 [Debit],  
		 [Credit],  
		 [Notes],  
		 [CurrencyVal],  
		 [ParentGUID], 
		 [accountGUID], 
		 [CurrencyGUID], [CostGUID], [ContraAccGUID] ) 
	SELECT   
		0,    
		[CurrentDate],    
		Cost,    
		0,    
		[Name] + ' ' +@Str + ' ' +  notes  ,  
		@CurrencyVal,    
		@entryGUID,    
		@DepitAcc,    
		@CurrencyGuid , 
		CostGuid,    
		Creditacc  
	FROM #temp  
	INSERT INTO [en000] 
		([Number],  
		 [Date],  
		 [Debit],  
		 [Credit],  
		 [Notes], 
		 [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
		SELECT    
		1,      
		[CurrentDate],    
		0,      
		Cost,      
		[Name] + ' ' + @Str + ' ' +  notes  ,  
		@CurrencyVal,      
		@entryGUID,      
		Creditacc,    
		@CurrencyGuid,      
		CostGuid,      
		@DepitAcc   
	FROM #temp  
	
	UPDATE HosReservationDetails000
	SET PayGuid = @payGuid
	WHERE guid = @ResGUID
###################################################################
#END
 