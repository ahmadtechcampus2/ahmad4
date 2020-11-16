##############################################
CREATE  proc prcHosOp_deleteAllEntry
	@FROMDATE DATETIME = '', 
	@TODATE	DATETIME = '2100'
AS 
	SET NOCOUNT ON  
	EXEC prcDisableTriggers 'ce000'
	EXEC prcDisableTriggers 'en000'
	delete from [ce000] 
	where guid in (select [entryGuid] from hosgeneraltest000 WHERE DATE BETWEEN @FROMDATE AND @TODATE) 
	 
	delete from [en000] 
	where ParentGuid in (select [entryGuid] from hosgeneraltest000 WHERE DATE BETWEEN @FROMDATE AND @TODATE ) 
								 
	DELETE FROM ER000 where 
	entryguid in (select [entryGuid] from hosgeneraltest000 WHERE DATE BETWEEN @FROMDATE AND @TODATE) 
	 
	update hosgeneraltest000 
	set entryguid = 0x0 
	WHERE DATE BETWEEN @FROMDATE AND @TODATE
		 
	ALTER TABLE [ce000] ENABLE TRIGGER ALL  
	ALTER TABLE [en000] ENABLE TRIGGER ALL  

##############################################	
CREATE PROC prcHosOp_GenEntry
	@OpTestGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON  
	DECLARE @entryNum 	[INT], 
			@DefCurBranch	UNIQUEIDENTIFIER,  
			@DefCurrencyGuid UNIQUEIDENTIFIER,  
			@entryGuid	UNIQUEIDENTIFIER,
			@DefCurrencyVal int   
	 
	SELECT @DefCurBranch = f.Branch  
	FROM hospfile000 as f 
	INNER JOIN hosgeneraltest000 AS t on t.FileGuid = F.Guid 
	WHERE t.GUID = @OpTestGuid 
	 
	IF (@DefCurBranch IS NULL ) 
		SET @DefCurBranch = 0X0 
	 
	 
	SELECT @DefCurrencyGuid = Value from op000 where name = 'AmnCfg_DefaultCurrency'      
	SELECT @DefCurrencyVal = CurrencyVal from my000 where Guid = @DefCurrencyGuid 
	SET @entryNum = 0
	SELECT @entryGuid = EntryGuid FROM er000 WHERE parentGuid = @OpTestGuid AND ParentType = 300
	SELECT @entryNum = ISNULL(Number, 0) FROM ce000 WHERE Guid = @entryGuid
	DELETE er000 WHERE EntryGuid = @entryGuid AND ParentGuid = @OpTestGuid AND ParentType = 300
	 
	IF (@entryNum = 0)
	BEGIN
	SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)     
	END
	   
	SET @entryGUID = NEWID() 
	DECLARE @TheNotes NVARCHAR(100)  
	SELECT @TheNotes  = '' 
	 
	SELECT  
		pn.[Name] AS PatientName,  
		Op.[name]as [OpName] , 
		IsNull(t.notes, '') AS NOTES, 
		dbo.HosGetJustDate(t.[date]) as [date] , 
		(t.cost - t.discount) * (t.CurrencyVal/@DefCurrencyVal) as cost, 
		p.accGuid as PatientAcc, --DebitAcc, 
		t.accGuid as OpAcc,      --CreditAcc, 
		p.CostGuid, 
		t.security, 
		t.CurrencyVal,  
		t.CurrencyGuid, 
		t.WorkerGuid, 
		t.WorkerFee * (t.CurrencyVal/@DefCurrencyVal) as WorkerFee 
	 INTO #temp	 
	 FROM 	hospfile000 as p  
		INNER JOIN hosgeneraltest000 AS t on t.FileGuid = p.Guid 
		INNER join hospatient000 as pat on pat.Guid = p.patientguid 
		INNER join hosperson000 as pn on pn.Guid = pat.personGuid 
		INNER Join hosGeneralOperation000 as op on t.OperationGuid = Op.Guid 
	WHERE 	t.guid = @OpTestGuid 
	 
	INSERT INTO [ce000]  
	    	([typeGUID], [Type],  [Number], [Date], [PostDate], [Debit],  
		 [Credit], [Notes], [CurrencyVal], [IsPosted],  
		 [Security], [Branch],[GUID], [CurrencyGUID])    
	SELECT 
		0x0,  
		1,  
		@entryNum,  
		[date], 
		[date],
		cost, 
		cost, 
		@TheNotes + ' '+ OpName + ' ' +PatientName + ' ' + notes  ,  
		CurrencyVal, 
		0, 
		security,  
		@DefCurBranch, 
		@entryGUID, 
		CurrencyGuid  
	FROM #temp  
			 
	INSERT INTO [en000] 
		 ([Number], [Date],  [Debit],  [Credit],  [Notes],  
		 [CurrencyVal],  [ParentGUID],	 [accountGUID], 
		 [CurrencyGUID], [CostGUID], [ContraAccGUID] ) 
	SELECT   
		0,    
		[date],    
		Cost,    
		0,    
		@TheNotes + ' ' +OpName + ' ' +PatientName + ' ' + notes  ,  
		CurrencyVal,    
		@entryGUID,    
		PatientAcc,--DebitAcc,    
		CurrencyGuid , 
		CostGuid,    
		OpAcc--CreditAcc  
	FROM #temp  
	INSERT INTO [en000] 
		([Number], [Date], [Debit], [Credit],  
		 [Notes], [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
	SELECT    
		1,      
		[Date],    
		0,      
		Cost,      
		@TheNotes + ' '+ OpName + ' ' +PatientName + ' ' + notes  ,  
		CurrencyVal,      
		@entryGUID,      
		OpAcc,--Creditacc,    
		CurrencyGuid,      
		CostGuid,      
		PatientAcc--DebitAcc   
	FROM #temp  
	Declare @WorkerGuid UNIQUEIDENTIFIER 
	SELECT @WorkerGuid =  WorkerGuid From #temp  
	if (@WorkerGuid <> 0x0) 
	BEGIN 
		--IsNull(e.accGuid, 0x0) as WorkerAcc , 
		--IsNull(t.WorkerFee , 0) as WorkerFee 
	Declare @doc NVARCHAR(100) 
	select @doc = p.[name] 
		   FROM	hosEmployee000 as e  
		   INNER join hosperson000 as p on p.Guid = e.personGuid 
		   where @WorkerGuid = e.Guid  
	Declare @DocAcc UNIQUEIDENTIFIER 
	SELECT @DocAcc =  e.[AccGuid] 
		      FROM 	hosEmployee000 as e  
		      where @WorkerGuid = e.Guid  
	Declare @doc2 NVARCHAR(100) 
	SELECT @doc2 = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Doctor' + @doc  ELSE ' «·ÿ»Ì» ' + @doc  END   	 		 
		 
		INSERT INTO [en000] 
			 ([Number], [Date],  [Debit],  [Credit],  [Notes],  
			 [CurrencyVal],  [ParentGUID],	 [accountGUID], 
			 [CurrencyGUID], [CostGUID], [ContraAccGUID] ) 
		SELECT   
			2,    
			[date],    
			WorkerFee,    
			0,    
			@TheNotes + ' ' +OpName + ' ' + @doc + ' ' + notes  ,  
			CurrencyVal,    
			@entryGUID,    
			OpAcc, 
			CurrencyGuid , 
			0x0,    
			@DocAcc  
		FROM #temp  
		INSERT INTO [en000] 
			([Number],  [Date],  [Debit],  [Credit],  
			 [Notes],[CurrencyVal], [ParentGUID], [accountGUID],  
			 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
		SELECT    
			3,      
			[Date],    
			0,      
			WorkerFee,      
			@TheNotes + ' ' +OpName + ' ' + @doc + ' ' + notes  ,  
			CurrencyVal,      
			@entryGUID,      
			@DocAcc,    
			CurrencyGuid,      
			0x0,      
			OpAcc   
		FROM #temp  
	END 
	 
	update hosgeneraltest000 
	set entryguid = @entryGUID 
	where guid = @OpTestGuid	 
	declare @fileNum int
	SELECT @fileNum = f.Number FROM hospfile000 AS f inner join hosgeneraltest000 AS s ON s.FileGuid = f.Guid
	WHERE s.GUID = @OpTestGuid   
	INSERT INTO [er000]  
	SELECT   
		newID(),  
		@entryGUID, 
		@OpTestGuid, 
		300,  
		@fileNum  
	UPDATE ce000 
	SET IsPosted = 1 
	WHERE GUID = @entryGUID
##############################################	
CREATE  PROC prcHosOpTest_ReGenEntry
	@FROMDATE DATETIME = '', 
	@TODATE	DATETIME = '2100'
AS 
	SET NOCOUNT ON  
	select  c1.Guid 
	into  #CENumbersRepeat 
	from ce000 as c1 INNER JOIN ce000 as c2 ON 	c1.number = c2.number 
	where  
	c1.guid <> c2.guid	
	AND c1.[DATE] BETWEEN @FROMDATE AND @TODATE 
	AND c2.[DATE] BETWEEN @FROMDATE AND @TODATE  
	Create Table #numbers( GeneralOpGuid UNIQUEIDENTIFIER, CEnumber INT) 
	 
	INSERT  #numbers 
	select  g.Guid, ce.Number	 
	from er000 as er 
	inner join ce000 as ce on  er.entryGuid = ce.guid 
	inner join hosgeneraltest000 as g on g.Guid = er.parentGuid  
	where g.entryGuid = ce.guid 
	AND CE.GUID NOT IN (select Guid from #CENumbersRepeat) 
	AND g.[DATE] BETWEEN @FROMDATE AND @TODATE
	exec prcHosOp_deleteAllEntry @FROMDATE, @TODATE
	DECLARE @CostGuid 	UNIQUEIDENTIFIER, 
			@DefCurGuid	UNIQUEIDENTIFIER, 
			@DefCurVal	FLOAT, 
			@entryGUID	UNIQUEIDENTIFIER, 
			@AccGUID	UNIQUEIDENTIFIER, 
			@entryNum [INT], 
			@Branch		UNIQUEIDENTIFIER 
	 
	SELECT @DefCurGuid =  Value from op000 where name = 'AmnCfg_DefaultCurrency'     
	SELECT @DefCurVal = CurrencyVal from my000 where Guid = @DefCurGuid    
	DECLARE @TheNotes NVARCHAR(100)  
	SELECT @TheNotes  = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'General Operation'  ELSE ' «·⁄„· «·⁄«„ '  END   	 
	--SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) --(@BranchGUID)     
	DECLARE  
		@PatientName	NVARCHAR (255), 
		@WrName	NVARCHAR (255), 
		@OpName	NVARCHAR (255), 
		@TestGuid	UNIQUEIDENTIFIER,    
		@FileGuid	UNIQUEIDENTIFIER ,   
		@OpAccGuid	UNIQUEIDENTIFIER ,   
		@WrAcc		UNIQUEIDENTIFIER ,   
		@DATE		DATETIME, 
		@Cost		float, 
		@DisCount	float, 
		@fee	float, 
		@CurrencyGuid	UNIQUEIDENTIFIER  , 
		@CurrencyVal	float, 
		@notes	NVARCHAR (255), 
		@notes2	NVARCHAR (255), 
		@sec	int 
	DECLARE s CURSOR FOR  
	SELECT 
		T.Guid, 
		p.Guid, 
		IsNull(	CEnumber, [dbo].[fnEntry_getNewNum](P.Branch)) As CEnumber, 
		dbo.HosGetJustDate(t.[date]) as [date], 
		(t.cost - t.discount) * (t.CurrencyVal/@DefCurVal) as cost, 
		t.CurrencyGuid	, 
		t.CurrencyVal,  
		p.accGuid as AccGuid,--as DebitAcc, 
		t.accGuid as OpAcc,--CreditAcc, 
		p.CostGuid, 
		Pn.[Name] as PnName, 
		IsNull(e.[Name],' ') as WrName, 
		@TheNotes + ' '+ Op.[name] + ' ' + t.notes AS NOTES , 
		isNull(e.AccGUID,0x0) as workerAcc, 
		--t.WorkerFee, 
		t.WorkerFee * (t.CurrencyVal/@DefCurVal) as WorkerFee, 
		t.security, 
		P.Branch 
		 
	FROM 	hospfile000 as p  
		INNER JOIN hosgeneraltest000 AS t on t.FileGuid = p.Guid 
		inner join hospatient000 as pat on pat.Guid = p.patientguid 
		inner join hosperson000 as pn on pn.Guid = pat.personGuid 
		INNER Join hosGeneralOperation000 as op on t.OperationGuid = Op.Guid 
		left  join vwHosEmployee as e on e.guid = t.workerguid 
		left join #numbers as num on num.GeneralOpGuid = t.guid 
		 
	WHERE 	(t.cost - t.discount > 0) 
		AND t.Date BETWEEN @FROMDATE AND @TODATE 
	OPEN	s
	FETCH NEXT FROM s 
	INTO  
		@TestGuid,	 
		@FileGuid, 
		@entryNum, 
		@DATE, 
		@Cost, 
		@CurrencyGuid, 
		@CurrencyVal, 
		@AccGUID, 
		@OpAccGuid, 
		@CostGuid, 
		@PatientName, 
		@WrName, 
		@notes, 
		@WrAcc, 
		@fee, 
		@sec, 
		@Branch 
		 
	WHILE (@@FETCH_STATUS = 0 ) 
	BEGIN 
		 
		SET @entryGUID = NEWID()  
		 
	/*if (@entryNum in (select number from ce000 )) 
			SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch)*/ 
		if (IsNull(@CurrencyGuid,0x0) = 0x0)  
		begin 
			set @CurrencyGuid = @DefCurGuid 
			set @CurrencyVal = @DefCurVal 
		end 
		update  hosgeneraltest000 
			set  	entryGuid = @entryGUID, 
				CurrencyGuid = 	@CurrencyGuid, 
				CurrencyVal = @CurrencyVal 
		where guid = @TestGuid 
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
			@notes ,  
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
			@notes + ' ' + @PatientName,--@ItemNotes + F.[Name] + @Str + St.[Name]+ '  '+ S.Notes,    
			@CurrencyVal,    
			@entryGUID,    
			@AccGUID,    
			@CurrencyGuid,    
			@CostGuid,    
			@OpAccGuid  
		INSERT INTO [en000] 
		([Number], [Date], [Debit], [Credit], [Notes], 
		 [CurrencyVal], [ParentGUID], [accountGUID],  
		 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
		SELECT    
			1,      
			@Date,    
			0,      
			@Cost,      
			@notes + ' ' + @PatientName,--@ItemNotes + F.[Name]+ @Str + St.[Name]+ '  '+ S.Notes,      
			@CurrencyVal,      
			@entryGUID,      
			@OpAccGuid,    
			@CurrencyGuid,      
			@CostGuid,      
			@AccGUID    
		 
		if (@WrAcc <> 0x0) 
		BEGIN 
			INSERT INTO [en000] 
				 ([Number], [Date],  [Debit],  [Credit],  [Notes],  
				 [CurrencyVal],  [ParentGUID],	 [accountGUID], 
				 [CurrencyGUID], [CostGUID], [ContraAccGUID] ) 
			SELECT   
				2,    
				@Date,    
				@fee,    
				0,    
				@notes + ' ' + @WrName, 
				@CurrencyVal,    
				@entryGUID,    
				@OpAccGuid, 
				@CurrencyGuid , 
				0x0,    
				@WrAcc  
			INSERT INTO [en000] 
				([Number],  [Date],  [Debit],  [Credit],  
				 [Notes],[CurrencyVal], [ParentGUID], [accountGUID],  
				 [CurrencyGUID], [CostGUID], [ContraAccGUID])    
			SELECT    
				3,      
				@Date,    
				0,      
				@fee,      
				@notes + ' ' + @WrName, 
				@CurrencyVal,      
				@entryGUID,      
				@WrAcc,    
				@CurrencyGuid,      
				0x0,      
				@OpAccGuid   
		END 
		INSERT INTO [er000]  
		SELECT   
			newID(),  
			@entryGUID, 
			@TestGuid, 
			300,  
			@entryNum 
		UPDATE ce000 
		SET IsPosted = 1 
		WHERE GUID = @entryGUID 
		 
		--SET @entryNum =  [dbo].[fnEntry_getNewNum](@DefCurBranch) 
		fetch next from s	 
		into  
		@TestGuid,	 
		@FileGuid, 
		@entryNum, 
		@DATE, 
		@Cost, 
		@CurrencyGuid, 
		@CurrencyVal, 
		@AccGUID, 
		@OpAccGuid, 
		@CostGuid, 
		@PatientName, 
		@WrName, 
		@notes, 
		@WrAcc, 
		@fee, 
		@sec, 
		@Branch 
	End 
	CLOSE s 
	DEALLOCATE s  	
##############################################	
#END
