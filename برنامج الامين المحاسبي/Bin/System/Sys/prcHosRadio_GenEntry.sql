#########################################################
CREATE   PROC prcHosRadio_deleteAllEntry 
	@FROMDATE DATETIME = '', 
	@TODATE	DATETIME = '2100' 
	AS  
	Create Table #temp_En  
	(  
		 EntryGuid [uniqueidentifier]  
	)  
	Create Table #temp_Py  
	(  
		 PayGuid [uniqueidentifier]  
	)  
	-- for old ver	 
	insert into  
	#temp_Py  
		select PayGuid 
		from HosRadioGraphyOrder000  
		where (IsNull(payGuid , 0x0) <> 0x0)
		AND   (DATE BETWEEN @FROMDATE AND @TODATE)
	insert into  
	#temp_En  
		select e.EntryGuid 
		from HosRadioGraphyOrder000 r	 
		inner JOIN er000 e on r.PayGuid = e.parentGuid 
		where (IsNull(r.payGuid , 0x0) <>0x0) 
		AND   (DATE BETWEEN @FROMDATE AND @TODATE)
		      --AND (ISNull(r.EntryGuid, 0x0) = 0x0)		 
		 
	-- for new ver 
	insert into  
	#temp_En  
		select EntryGuid 
		from HosRadioGraphyOrder000 	 
		where IsNull(EntryGuid , 0x0) <>0x0 
		AND   (DATE BETWEEN @FROMDATE AND @TODATE)
	  
	update HosRadioGraphyOrder000  
	set entryguid = 0x0, payGuid = 0x0 
	 
	 EXEC prcDisableTriggers  'py000'
	 EXEC prcDisableTriggers  'ce000'
	 EXEC prcDisableTriggers  'en000'

	 
	delete from [py000]  
	where  	guid in (select [PayGuid] from #temp_Py)  
	delete from [ce000]  
	where  	guid in (select [entryGuid] from #temp_En)  
	 
	delete from [en000]  
	where ParentGuid in (select [entryGuid] from #temp_En)  
								  
	DELETE FROM ER000  
	WHERE 	entryGuid in(Select [entryGuid] from #temp_En) 
		  
	ALTER TABLE [py000] ENABLE TRIGGER ALL  
	ALTER TABLE [ce000] ENABLE TRIGGER ALL   
	ALTER TABLE [en000] ENABLE TRIGGER ALL 
	--exec prcReNumberingEntry  

################################################
CREATE  proc prcHosRadio_GenEntry 
	@RadioOrder UNIQUEIDENTIFIER,
	@entryNum		INT = 0	  
AS 
	SET NOCOUNT ON 
	Declare @entryGUID	UNIQUEIDENTIFIER    	
	set @entryGUID = NewID()
	DECLARE @DefCurBranch	UNIQUEIDENTIFIER   ,
			@DepitAcc UNIQUEIDENTIFIER,
			@FileGuid UNIQUEIDENTIFIER,
			@CostGuid UNIQUEIDENTIFIER,
			@CurrencyGuid UNIQUEIDENTIFIER,
			@CurrencyVal float,
			@payGuid UNIQUEIDENTIFIER,
			@Str nVarChar(100),
			@Name nVarChar(100),
			@oldEntryGuid UNIQUEIDENTIFIER,
			@oldPayGuid   UNIQUEIDENTIFIER
			
	Select @FileGuid = FileGuid from HosRadioGraphyOrder000 where Guid = @RadioOrder
	
	SELECT 
		@DefCurBranch = f.Branch 
	FROM hospfile000 as f
	WHERE 	F.GUID = @FileGuid

	
	IF (@DefCurBranch IS NULL )
		SET @DefCurBranch = 0X0
	
	if (@entryNum = 0)	
		SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)     

	/*if (@entryNum in (select number from ce000 ))
			SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch)*/
			
	select @oldEntryGuid = entryguid, @oldPayGuid = payguid
	From HosRadioGraphyOrder000
	where guid = @RadioOrder
	
	Select @FileGuid    = FileGuid from HosRadioGraphyOrder000 where Guid = @RadioOrder
	SELECT @Str = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN ' ØáÈ ÃÔÚÉ ' ELSE ' ØáÈ ÃÔÚÉ ' END    


	if (IsNull(@FileGuid, 0x0) = 0x0)
	  begin
		--select 	@depitAcc = Value from op000 where name = 'HosCfg_RG_ExternIncomAcc'
		declare @EType  UNIQUEIDENTIFIER
		select @EType = Value from op000 where name = 'HosCfg_RG_PayType'
		--select  @EAcc = DefAccGuid From et000 where guid = @EType
		select 	@depitAcc = DefAccGuid from et000 where guid = @EType
		
		select @Name =	pn.[Name] from HosRadioGraphyOrder000 r 
			INNER join hospatient000 as pat on pat.Guid = r.patientguid 
			INNER join hosperson000 as  pn on pn.Guid = pat.personGuid  
			where r.guid = @RadioOrder	
		select @CostGuid = 0x0
	  end
        else
	  begin
		select 	@depitAcc = AccGuid 
		from HosPFile000 
		where guid = @FileGuid
		select @Name = pn.[Name] from HosRadioGraphyOrder000 r 
			inner Join hospFile000 as p ON p.guid = r.fileGuid  			
			INNER join hospatient000 as pat on pat.Guid = p.patientguid 
			INNER join hosperson000 as  pn on pn.Guid = pat.personGuid  
		where r.guid = @RadioOrder	
		select @CostGuid = costGuid From hospFile000 where guid = @FileGuid
  	  end

	select @CurrencyGuid = IsNull(currencyGuid, 0x0) from HosRadioGraphyOrder000 where guid = @RadioOrder 
	if ( @CurrencyGuid = 0x0) 
		select @CurrencyGuid = Value from op000 where name = 'AmnCfg_DefaultCurrency'     

	SELECT @CurrencyVal = CurrencyVal from my000 where Guid = @CurrencyGuid
	--DECLARE @Cost float
	--select @cost 
	SELECT  
		ord.Guid,  
		dbo.GetJustDate(ord.[Date]) as [date], 
		sum(d.price - d.discount) AS cost,
		ord.notes, 
		ord.AccGUID AS CreditAcc, 
		ord.security

	into #temp	 	
	from 
	HosRadioGraphyOrder000 as ord  
	INNER JOIN HosRadioGraphyOrderDetail000 AS d on d.ParentGuid = ord.Guid
	where @RadioOrder = ord.guid
	group by 
		ord.Guid, ord.[Date], ord.NOTES,ord.AccGUID, ord.security
	Having(sum(d.price - d.discount) > 0)

	if (@FileGuid = 0x0)
	Begin
		Declare @Number INT
		Declare @EAcc  UNIQUEIDENTIFIER
		select  @EAcc = DefAccGuid From et000 where guid = @EType
		Set @payGuid = NEWID()
		SELECT @Number = ISNULL(Max(Number) + 1, 1) FROM Py000 where typeGUID = @EType
		--select * from py000
		insert INTO py000
			([Number],[Date],[Notes], [Guid], [typeGUID],[AccountGuid], 
			 [CurrencyGUID], [CurrencyVal], 
			 [Security], [BranchGuid]) 
			select	
				@Number,
				[date],
				@Name + ' ' +@Str + ' ' +  notes  ,  
				@payGuid,
				@EType,
				@EAcc,
				@CurrencyGuid,
				@CurrencyVal,
				security,
				@DefCurBranch
			from #temp 
		INSERT INTO [er000]  
		SELECT   
			newID(),  
			@entryGUID, 
			@payGuid, 
			4,  
			@Number 
 	END
 	ELSE
 	
 	INSERT INTO [er000]  
	SELECT   
		newID(),  
		@entryGUID, 
		@RadioOrder, 
		309,  
		@entryNum 
		
	INSERT INTO [ce000]  
	    	([typeGUID], [Type],  [Number], [Date], [Debit],  
		 [Credit], [Notes], [CurrencyVal], [IsPosted],  
		 [Security], [Branch],[GUID], [CurrencyGUID])    
	select 
		0x0,  
		1,  
		@entryNum,  
		[date], 
		cost, 
		cost, 
		@Name + ' ' +@Str + ' ' +  notes  ,  
		@CurrencyVal, 
		0, 
		security,  
		@DefCurBranch, 
		@entryGUID, 
		@CurrencyGuid  
	from #temp  
			 
	INSERT INTO [en000]   ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], 
		 [accountGUID], [CurrencyGUID], [CostGUID], [ContraAccGUID] ) 
	select   
		0,[date], Cost, 0, @Name + ' ' +@Str + ' ' +  notes  ,  
		@CurrencyVal,@entryGUID,@DepitAcc, @CurrencyGuid , @CostGuid,Creditacc  

	from #temp  

	INSERT INTO [en000] ([Number], [Date],  [Debit], [Credit],  
		 [Notes], [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
	SELECT    
		1, [Date], 0,Cost, @Name + ' ' + @Str + ' ' +  notes,  
		@CurrencyVal,@entryGUID,Creditacc, @CurrencyGuid,@CostGuid,@DepitAcc   

	from #temp  

/*
	INSERT INTO [en000] ([Number], [Date],  [Debit], [Credit],  
		 [Notes], [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
	SELECT    
		1, [Date], 0,Cost, @Name + ' ' + @Str + ' ' +  notes2  ,  
		@CurrencyVal,@entryGUID,Creditacc, @CurrencyGuid,@CostGuid,@DepitAcc   
	from #temp  */
	
	declare @sumdebit float
	select @sumdebit = sum(w.wages) 
	from HosRadioOrderWorker000 as w
	inner join #temp as t on t.guid = w.parentguid

	INSERT INTO [en000] ([Number], [Date],  [Debit], [Credit],  
		 [Notes], [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
	SELECT    
		2, [Date], @sumdebit,0,'' ,  
		@CurrencyVal,@entryGUID, Creditacc , @CurrencyGuid, 0x0, 0x0   
	from #temp as t
	
	INSERT INTO [en000] ([Number], [Date],  [Debit], [Credit],  
		 [Notes], [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
	SELECT    
		w.Number + 3, [Date], 0, W.wages, w.Notes  ,  
		@CurrencyVal,@entryGUID, e.AccGuid, @CurrencyGuid, 0x0, Creditacc   
	from #temp as t
	inner join HosRadioOrderWorker000 as w on  w.parentguid = t.guid
	inner join hosemployee000 as e on e.guid = w.WorkerGuid

	update HosRadioGraphyOrder000
	set EntryGuid = @entryGUID,
	PayGuid = IsNull(@payGuid ,0x0)
	where guid = @RadioOrder
	 
	UPDATE ce000
	SET IsPosted = 1
	WHERE GUID = @entryGUID

	select @entryGUID As EntryGuid, @payGuid as PayGuid
#######################################################
CREATE PROC prcRadio_ReGenEntry 
	@FROMDATE DATETIME = '', 
	@TODATE	DATETIME = '2100' 
AS  
	SET NOCOUNT ON  
	/*select  c1.Guid 
	into  #CENumbersRepeat 
	from ce000 as c1 INNER JOIN ce000 as c2 ON 	c1.number = c2.number 
	where  
	c1.guid <> c2.guid	 
	Create Table #numbers( GrapghGuid UNIQUEIDENTIFIER, CEnumber INT) 
	INSERT  #numbers 
	select  r.Guid, ce.Number	 
	from er000 as er 
	inner join ce000 as ce on  er.entryGuid = ce.guid 
	inner join HosRadioGraphyOrder000 as r on r.Guid = er.parentGuid  
	where r.entryGuid = ce.guid 
	AND CE.GUID NOT IN (select Guid from #CENumbersRepeat) 
	*/ 
	-- just for once 
	update 	HosRadioGraphyOrder000   
	set patientGuid = (select PatientGuid From hospfile000 Where Guid = FileGuid) 
	Where PatientGuid = 0x0 
	--AND (DATE BETWEEN @FROMDATE AND @TODATE)
	declare @AcDefaultGuid uniqueidentifier 
	select @AcDefaultGuid = value from op000 where [name] = 'HosCfg_File_RadioGraphyAcc' 
	update 	HosRadioGraphyOrder000   
	set AccGuid = @AcDefaultGuid 
	Where AccGuid = 0x0 
	--AND (DATE BETWEEN @FROMDATE AND @TODATE)
	 
	-- always 
	exec prcHosRadio_deleteAllEntry  @FROMDATE,@TODATE
	DECLARE  @RadioOrderGuid	UNIQUEIDENTIFIER 
	DECLARE  @CENumbr					INT 
	DECLARE C CURSOR FOR   
	SELECT   
		ord.Guid,ord.number 
		--IsNull(n.CENumber  , 0) 
	FROM  
	HosRadioGraphyOrder000 as ord
	WHERE ord.DATE BETWEEN @FROMDATE AND @TODATE
	ORDER BY number 
	--INNER JOIN HosRadioGraphyOrderDetail000 AS d on d.ParentGuid = ord.Guid 
	--left join #numbers as n on n.GrapghGuid = ord.guid  
	--group by ord.Guid, n.CENumber 
	--Having(sum(d.price - d.discount) > 0) 
	OPEN	C 
	FETCH NEXT FROM C 
	INTO   
		@RadioOrderGuid, 
		@CENumbr 
		 
		  
	WHILE (@@FETCH_STATUS = 0 )  
	BEGIN  
		  
		EXEC prcHosRadio_GenEntry	@RadioOrderGuid, 0 
		fetch next from C	  
		into   
		@RadioOrderGuid, 
		@CENumbr 
	End  
	CLOSE C 
	DEALLOCATE C    

#########################################################
#END

