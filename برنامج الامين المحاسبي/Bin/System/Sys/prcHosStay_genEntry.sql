################################################
CREATE PROC prcHosStay_GenEntry
	@StayGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 
	DECLARE @OldEntry 	 UNIQUEIDENTIFIER, 
			@entryNum 	 [INT], 
			@DefCurBranch	 UNIQUEIDENTIFIER, 
			@DefCurrencyGuid UNIQUEIDENTIFIER,  
			@DefCurrencyVal INT 

	DECLARE @NoDate DATETIME = '2100-01-01 00:00:00.000';

	SELECT @DefCurBranch = f.Branch  
		FROM hospfile000 as f 
		INNER Join hosstay000 s on f.guid = s.fileguid 
		WHERE s.GUID = @StayGuid 
	IF (@DefCurBranch IS NULL ) 
		SET @DefCurBranch = 0X0 
	SELECT @OldEntry = EntryGuid  
		FROM HosStay000 
		WHERE GUID = @StayGuid 
	 
	IF (ISNULL(@OldEntry, 0X0) <> 0X0) 
	BEGIN 
		SELECT @entryNum = NUMBER FROM CE000 WHERE GUID = @OldEntry 
		DELETE FROM ER000 WHERE EntryGuid = @OldEntry  
		EXEC prcEntry_delete @OldEntry 
		IF EXISTS (SELECT * FROM CE000 WHERE NUMBER = @entryNum AND BRANCH = @DefCurBranch) 
			SET @entryNum = [dbo].[fnEntry_getNewNum](@DefCurBranch)  
	END 
	ELSE 
	BEGIN 
		SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch)  
	END 
	 
	 
	SELECT @DefCurrencyGuid = Value from op000 where name = 'AmnCfg_DefaultCurrency'      
	SELECT @DefCurrencyVal = CurrencyVal from my000 where Guid = @DefCurrencyGuid 
	 
	DECLARE @entryGUID	UNIQUEIDENTIFIER    
	SET @entryGUID = NEWID() 
	DECLARE @Str 	  NVARCHAR(100)    
	DECLARE @TheNotes NVARCHAR(100)  
	SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN ' in site ' ELSE ' ›Ì «·„Êﬁ⁄ ' END    
	SELECT @TheNotes  = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Stay'  ELSE ' ≈ﬁ«„… '  END  
	select  
		pn.[Name] AS PatientName,  
		t.[name]as [SiteName] , 
		IsNull(ty.[name],'') as [SiteTypename], 
		IsNull(s.notes, '') AS NOTES, 
		CASE dbo.GetJustDate(s.EndDate) WHEN @NoDate THEN  dbo.GetJustDate(s.StartDate) ELSE dbo.GetJustDate(s.EndDate) END AS [date], 
		(s.cost - s.discount) * (s.CurrencyVal/@DefCurrencyVal)  as cost, 
		p.accGuid as DebitAcc, 
		s.accGuid as CreditAcc, 
		p.CostGuid, 
		s.security, 
		s.CurrencyVal,  
		s.CurrencyGuid 
 	 
	into #temp	 
	from hospfile000 as p  
		INNER Join hosstay000 s on p.guid = s.fileguid 
		inner join hospatient000 as pat on pat.Guid = p.patientguid 
		inner join hosperson000 as pn on pn.Guid = pat.personGuid 
		INNER Join hossite000 as t on t.guid = s.siteguid  
		left Join HosSiteType000 as ty on ty.guid = t.typeguid  
	where @StayGuid = s.guid 
	 
	DECLARE @Cost FLOAT 
	SELECT @Cost = cost FROM #temp 
	IF (@Cost <= 0 ) 
	BEGIN 
			UPDATE hosstay000 
			SET entryguid = 0X0 
			WHERE guid = @stayGuid	 
			 
		RETURN 
	END 
	INSERT INTO [ce000]  
	    	([typeGUID], [Type],  [Number], [Date], [PostDate], [Debit],  
		 [Credit], [Notes], [CurrencyVal], [IsPosted],  
		 [Security], [Branch],[GUID], [CurrencyGUID])    
	select 
		0x0,  
		1,  
		@entryNum,  
		[date], 
		[date],
		cost, 
		cost, 
		@TheNotes + ' '+ PatientName + ' '+ @Str + ' ' + SiteName + ' ' + SiteTypename + ' ' + notes  ,  
		CurrencyVal, 
		0, 
		security,  
		@DefCurBranch, 
		@entryGUID, 
		CurrencyGuid  
	from #temp  
			 
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
	select   
		0,    
		[date],    
		Cost,    
		0,    
		@TheNotes + ' '+ PatientName + ' '+ @Str + ' ' + SiteName + ' ' + SiteTypename + ' ' + notes  ,  
		CurrencyVal,    
		@entryGUID,    
		DebitAcc,    
		CurrencyGuid , 
		CostGuid,    
		CreditAcc  
	from #temp  
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
			[Date],    
			0,      
			Cost,      
			@TheNotes + ' '+ PatientName + ' '+ @Str + ' ' + SiteName + ' ' + SiteTypename + ' ' + notes  ,  
			CurrencyVal,      
			@entryGUID,      
			Creditacc,    
			CurrencyGuid,      
			CostGuid,      
			DebitAcc   
	from #temp  
	update hosstay000 
	set entryguid = @entryGUID 
	where guid = @stayGuid	 
	declare @fileNum int
	SELECT @fileNum = f.Number FROM hospfile000 AS f inner join hosstay000 AS s ON s.FileGuid = f.Guid
	WHERE s.GUID = @stayGuid 
	INSERT INTO [er000]  
	SELECT   
		newID(),  
		@entryGUID, 
		@StayGuid, 
		303,  
		@fileNum  
		 
	UPDATE ce000 
	SET IsPosted = 1 
	WHERE GUID = @entryGUID



################################################
#END


