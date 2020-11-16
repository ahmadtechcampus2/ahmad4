##############################################
CREATE PROC HosUpdate_FileDateout
		@Fileguid uniqueidentifier 
AS
	SET NOCOUNT ON 
	DECLARE @DateOut DATETIME 
	DECLARE @DateIn DATETIME 
	SELECT @DateOut = ISNULL( MAX(endDate), GETDATE() ) FROM hosStay000 WHERE FileGuid = @FileGUID 
	SELECT @DateIn = ISNULL(  MIN(StartDate), GETDATE() ) FROM hosStay000 WHERE FileGuid = @FileGUID 
	UPDATE HosPFile000 SET  Dateout = @DateOut, DateIn = @DateIn WHERE Guid = @FileGUID 
##############################################	
CREATE  PROC prcHosStay_ReGenEntry
	@FROMDATE DATETIME = '',
	@TODATE	DATETIME = '2100'
AS
	set nocount on
		
	select  c1.Guid
	into  #CENumbersRepeat
	from ce000 as c1 INNER JOIN ce000 as c2 ON 	c1.number = c2.number
	where c1.guid <> c2.guid 
	AND c1.[DATE] BETWEEN @FROMDATE AND @TODATE
	AND c2.[DATE] BETWEEN @FROMDATE AND @TODATE

	Create Table #numbers( StayGuid UNIQUEIDENTIFIER, CEnumber INT)

	INSERT  #numbers
	select  Stay.Guid, ce.Number	
	from er000 as er
	inner join ce000 as ce on  er.entryGuid = ce.guid
	inner join hosStay000 as Stay on Stay.Guid = er.parentGuid 
	where Stay.entryGuid = ce.guid
	AND CE.GUID NOT IN (select Guid from #CENumbersRepeat)
	AND Stay.[STARTDATE] BETWEEN @FROMDATE AND @TODATE


	DELETE FROM ER000
	WHERE EntryGuid in (select EntryGuid From hosstay000 WHERE STARTDATE BETWEEN @FROMDATE AND @TODATE)	

	/*
	update hosstay000
	set endDate = '2100'
	where endDate ='1899-12-30 00:00:00.000'
	*/

	DECLARE @CostGuid 	UNIQUEIDENTIFIER,
			@DefCurGuid	UNIQUEIDENTIFIER,
			@DefCurBranch	UNIQUEIDENTIFIER,
			@DefCurVal	FLOAT,
			@entryGUID	UNIQUEIDENTIFIER,
			@AccGUID	UNIQUEIDENTIFIER,
			@entryNum [INT]
	
	SELECT @DefCurGuid =  Value from op000 where name = 'AmnCfg_DefaultCurrency'    
	SELECT @DefCurVal = CurrencyVal from my000 where Guid = @DefCurGuid   
	SET @DefCurBranch = ISNULL([dbo].[fnBranch_getDefaultGuid](), 0x0)

		
	DECLARE @Str 	  NVARCHAR(100)   
	DECLARE @TheNotes NVARCHAR(100) 
	SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN ' in site ' ELSE ' Ýí ÇáãæÞÚ ' END   
	SELECT @TheNotes  = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Stay'  ELSE ' ÅÞÇãÉ '  END   	

	--SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)    

	DECLARE 
		@StayGuid	UNIQUEIDENTIFIER,   
		@FileGuid	UNIQUEIDENTIFIER ,  
		@CreditGuid	UNIQUEIDENTIFIER ,  
		@DATE		DATETIME,
		@Cost		float,
		@DisCount	float,
		@CurrencyGuid	UNIQUEIDENTIFIER  ,
		@CurrencyVal	float,
		@PatientName	NVARCHAR (255),
		@SiteName		NVARCHAR (255),
		@SiteTypeName	NVARCHAR (255),
		@notes			NVARCHAR (255),
		@notes2			NVARCHAR (255),
		@sec			int,
		@Branch			UNIQUEIDENTIFIER
	DECLARE s CURSOR FOR 
	SELECT 
		s.Guid, 
		FileGuid,
		IsNull(	CEnumber, [dbo].[fnEntry_getNewNum](@DefCurBranch)) As CEnumber,
		dbo.GetJustDate(s.StartDate),
		cost,
		disCount,
		CurrencyGuid,
		CurrencyVal,
		pn.[Name],
		t.[name]as [SiteName],
		IsNull(ty.[name],'') as [SiteTypename],
		IsNull(s.notes, '') AS NOTES,
		p.accGuid ,
		p.CostGuid,
		s.AccGUID ,
		s.security,
		p.branch
	FROM
	HosStay000 as s 
	INNER Join HosPFile000 as p on s.FileGuid = p.guid 
	inner join hospatient000 as pat on pat.Guid = p.patientguid
	inner join hosperson000 as pn on pn.Guid = pat.personGuid
	INNER Join hossite000 as t on t.guid = s.siteguid 
	left Join HosSiteType000 as ty on ty.guid = t.typeguid 
	left join #numbers as num on num.stayGuid = S.guid
	WHERE (S.COST - S. DISCOUNT > 0)
		AND s.StartDate BETWEEN @FROMDATE AND @TODATE

	OPEN	s
	FETCH NEXT FROM s
	INTO 
		@StayGuid,	
		@FileGuid,
		@entryNum,
		@DATE,
		@Cost,
		@DisCount,
		@CurrencyGuid,
		@CurrencyVal,
		@PatientName,
		@SiteName,
		@SiteTypeName,
		@notes,
		@AccGUID,
		@CostGuid,
		@CreditGuid,
		@sec,
		@Branch
		
	WHILE (@@FETCH_STATUS = 0 )
	BEGIN
		--select @entryNum
		if (@entryNum in (select number from ce000 ))
			SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)    
		set @Cost = (@Cost - @Discount) * (@CurrencyVal/@DefCurVal)
		
		set @notes2 = @TheNotes +  @PatientName + ' '  + @TheNotes + ' ' + @SiteName + ' ' + @SiteTypeName+ ' ' + @notes 
		SET @entryGUID = NEWID() 
		
				
		if (IsNull(@CurrencyGuid,0x0) = 0x0) 
		begin
			set @CurrencyGuid = @DefCurGuid
			set @CurrencyVal = @DefCurVal
		end

		update   HosStay000
			set  entryGuid = @entryGUID,
			CurrencyGuid = 	@CurrencyGuid,
			CurrencyVal = @CurrencyVal
		where guid = @StayGuid


		INSERT INTO [ce000] 
		    	([typeGUID], [Type],  [Number], [Date], [Debit], 
			 [Credit], [Notes], [CurrencyVal], [IsPosted], 
			 [Security], [Branch],[GUID], [CurrencyGUID])   
		SELECT  
			0x0, 
			1, 
			@entryNum, 
			@Date, 
			@Cost, 
			@Cost,
			@notes2, 
			@CurrencyVal,
			0,
			@sec, 
			@Branch,
			@entryGUID,
			@CurrencyGuid 
			
	   
		INSERT INTO [en000] 
		([Number], [Date], [Debit], [Credit], [Notes], 
		 [CurrencyVal], [ParentGUID], [accountGUID], 
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])   
		select  
			0,   
			@Date,   
			@Cost,   
			0,   
			@notes2,--@ItemNotes + F.[Name] + @Str + St.[Name]+ '  '+ S.Notes,   
			@CurrencyVal,   
			@entryGUID,   
			@AccGUID,   
			@CurrencyGuid,   
			@CostGuid,   
			@CreditGuid 

		INSERT INTO [en000]
		([Number], [Date], [Debit], [Credit], [Notes],
		 [CurrencyVal], [ParentGUID], [accountGUID], 
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])   
		SELECT   
			1,     
			@Date,   
			0,     
			@Cost,     
			@notes2,--@ItemNotes + F.[Name]+ @Str + St.[Name]+ '  '+ S.Notes,     
			@CurrencyVal,     
			@entryGUID,     
			@CreditGuid,   
			@CurrencyGuid,     
			@CostGuid,     
			@AccGUID   
		
		INSERT INTO [er000] 
		SELECT  
			newID(), 
			@entryGUID,
			@StayGuid,
			303, 
			@entryNum
			
		UPDATE ce000
		SET IsPosted = 1
		WHERE GUID = @entryGUID

		--SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)    
		FETCH NEXT FROM s	
		INTO 
			@StayGuid,	
			@FileGuid,
			@entryNum,
			@DATE,
			@Cost,
			@DisCount,
			@CurrencyGuid,
			@CurrencyVal,
			@PatientName,
			@SiteName,
			@SiteTypeName,
			@notes,
			@AccGUID,
			@CostGuid,
			@CreditGuid,
			@sec,
			@Branch
	End
	CLOSE s
	DEALLOCATE s  
##############################################	
#END

