#######################
CREATE PROC prcStatement_deleteEntry
	@StatementGUID UNIQUEIDENTIFIER
AS
/* 
this procedure: 
	- deletes a given notes' entries
	- entries are deleted from er
*/ 
	SET NOCOUNT ON
	exec [prcER_delete] @StatementGUID, 510
################################################################
CREATE PROC prcStatement_genEntry
	@StatemntGUID 			UNIQUEIDENTIFIER,
	@DebitAccGUID	 		UNIQUEIDENTIFIER,
	@CreditAccGUID			UNIQUEIDENTIFIER,
	@Note					[VARCHAR](256)  = '',
	@entryNum 				INT = 0
AS
/*
-- @branchGUID
-- ÇáÍÓÇÈ ÇáãÞÇÈá
-- ÇáÝÆÉ æãÑßÒ ÇáßáÝÉ
-- æÇáÍÓã æÇáÅÖÇÝÉ Ïæä ÓÄÇá ÈÏÑ 
-- ÞíÏ ÇáÅÑÌÇÚ ãÚ ãÚÇáÌÉ ÃÌæÑ ÇáÅÑÌÇÚ
*/
	SET NOCOUNT ON

	DECLARE	@StatementTypeGUID 	UNIQUEIDENTIFIER,
		@entryGUID		UNIQUEIDENTIFIER,
		@branchGUID 		UNIQUEIDENTIFIER 

	SELECT @StatementTypeGUID = TypeGUID FROM trnStatement000 WHERE GUID = @StatemntGUID

	SELECT @BranchGUID = br.AmnBranchGuid
		FROM TrnStatement000 as stm
		INNER JOIN trnBranch000 AS br on br.Guid = stm.Branch
		WHERE stm.GUID = @StatemntGUID
		--CAST(value AS uniqueidentifier) FROM OP000 WHERE Name Like 'TrnCfg_CurrentBranch'
	-- check:
	IF @@ROWCOUNT = 0
	BEGIN
		RAISERROR('AmnE0193: Transfer specified was not found ...', 16, 1)
		RETURN
	END

	DECLARE @WagesBranchGUID uniqueidentifier
	SELECT @WagesBranchGUID = WagesAccGUID FROM trnBranch000 WHERE AmnBranchGUID = @branchGUID
	/*
	SELECT 	@DebitAccGUID =  SourceAcc,
		 	@CreditAccGUID = DestAcc
		FROM TrnStatementTypes000
	WHERE Guid = @StatementTypeGUID
	*/


	-- ãä ÃÌá ÇáÊÚÏíá ÍÊì íÈÞì ÈäÝÓ ÇáÑÞã
	DECLARE @CalcedEntryNumber FLOAT
	SELECT @CalcedEntryNumber = ISNULL( Number, 0) FROM ce000 
			WHERE Guid = ( SELECT EntryGuid FROM er000 WHERE ParentGuid = @StatemntGUID)
	IF @CalcedEntryNumber > 0 
		SET @entryNum = @CalcedEntryNumber
	
	-- delete old entry: 
	EXEC prcStatement_deleteEntry @StatemntGUID

	-- prepare new entry guid and number:  
	SET @entryGUID = NEWID()  
	IF @entryNum = 0 OR EXISTS(SELECT * FROM vwCe WHERE ceNumber = @entryNum) 
		SET @entryNum = dbo.fnEntry_getNewNum(@BranchGUID) 
	
	DECLARE @DebitVal 	FLOAT,
		@CreditVal	FLOAT,
		@Cur1		UNIQUEIDENTIFIER,
		@CurVal1	FLOAT,
		@Cur2		UNIQUEIDENTIFIER,
		@CurVal2	FLOAT

	SELECT
			@DebitVal 	= TotalInCur2,
			@CreditVal 	= Total,
			@Cur1		= CurrencyGuid,
			@CurVal1	= CurrencyVal,
			@Cur2		= CurrencyGuid2,
			@CurVal2	= CurrencyVal2
	FROM TrnStatement000 WHERE Guid = @StatemntGUID

	Declare @BaseCurrency uniqueidentifier
	select @BaseCurrency = Guid From my000 
	where currencyVal = 1

	-- insert ce:  
	INSERT INTO ce000 (Type, Number, Date, Debit, Credit, Notes, CurrencyVal, IsPosted, Security, Branch, GUID, CurrencyGUID)    
		SELECT 
			1, @entryNum, Date, 
			@CreditVal,
			@CreditVal,
			--@Note + Code, CurrencyVal, 0, Security, Branch, @entryGUID, CurrencyGUID
			@Note + Code, 
			1,--CurrencyVal, 
			0,
			Security,
			@branchGUID, 
			@entryGUID, 
			@BaseCurrency
		FROM TrnStatement000
		WHERE GUID = @StatemntGUID

	DECLARE @ItemNum float
	SELECT @ItemNum = ISNUll(Count(*), 1) FROM TrnStatementItems000 WHERE ParentGUID = @StatemntGUID
	
	DECLARE @TotalInUnit1 float
	SELECT @TotalInUnit1 = Sum(Amount * CurrencyVal) / @CurVal1 FROM TrnStatementItems000 WHERE ParentGUID = @StatemntGUID
	-- insert en:

	DECLARE @BriefEntry INT 
	SELECT 	@BriefEntry = bBriefEntry 
	from	trnStatementTypes000
	where guid = @StatementTypeGUID

	declare @sdate datetime
	select @SDate = [date]
	From  TrnStatement000 where GUID = @StatemntGUID


	if (@BriefEntry = 1)
	BEGIN
		create table #Debit
		(id int identity (1,1), currencyval float, currencyGuid uniqueidentifier, Debit Float)

		insert into #Debit(currencyval, currencyGuid, Debit)  
		select 
			i.CurrencyVal,
			i.currencyGuid,
			--Sum((i.Amount + i.netWages) * i.CurrencyVal)				
			Sum(i.Amount * i.CurrencyVal)				
		FROM
		trnStatementItems000 AS i
		INNER JOIN TrnStatement000 AS s ON s.GUID = i.ParentGUID
		WHERE ParentGUID = @StatemntGUID
		Group by i.currencyGuid, i.CurrencyVal


		INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID,
				 accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			SELECT
				[id],--i.Number,
				@sdate,	--s.date,
				Debit,--(i.Amount + i.netWages) * i.CurrencyVal,	--Debit
				0,			--Credit
				'',			--Note
				CurrencyVal,
				@entryGUID,
				@DebitAccGUID,
				CurrencyGUID,
				0x0,
				0x0
			FROM 
				#Debit as t
			order by id

			declare @lastid int 
			select @lastid = max(id) + 1 From #Debit

			create table #Credit
			(id int identity (1,1), currencyval float, currencyGuid uniqueidentifier, Credit Float)

			insert into #Credit(currencyval, currencyGuid, Credit)  
			select 
				i.CurrencyVal2,
				i.CurrencyGUID2,
				Sum(i.Amount2 * i.CurrencyVal2)				
			from
			trnStatementItems000 AS i
			INNER JOIN TrnStatement000 AS s ON s.GUID = i.ParentGUID
			WHERE ParentGUID = @StatemntGUID
			Group by i.currencyGuid2, i.CurrencyVal2

			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID,
						accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			SELECT
				@lastid + id,
				@sdate,	
				0,
				credit,
				'',--Note
				CurrencyVal,
				@entryGUID,
				@CreditAccGUID,
				CurrencyGUID,
				0x0,--costGuid
				0x0 -- contrAcc h
			FROM 
				#Credit
			order by id

			Create Table #wages
			(id int identity (1,1), currencyval float, currencyGuid uniqueidentifier, Credit Float)

			insert into #wages(currencyval, currencyGuid, Credit)  
			select 
				i.CurrencyVal,
				i.CurrencyGUID,
				Sum(i.netWages * i.CurrencyVal)				
			from
			trnStatementItems000 AS i
			INNER JOIN TrnStatement000 AS s ON s.GUID = i.ParentGUID
			WHERE ParentGUID = @StatemntGUID
			Group by i.currencyGuid, i.CurrencyVal
			
			select @lastid = max(id) + 1 From #Credit
			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID,
						accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			SELECT
				@lastid + id,
				@sdate,	
				0,
				credit,
				'',--Note
				CurrencyVal,
				@entryGUID,
				@WagesBranchGUID,
				CurrencyGUID,
				0x0,--costGuid
				0x0 -- contrAcc h
			FROM 
				#wages
			order by id
	END
	ELSE
	BEGIN
		Declare @Number int,
			@EnNumber int,
			@Amount FLOAT,
			@NetWages FLOAT,
			@CurGuid1 uniqueidentifier,
			@CurrencyVal1 FLOAT,
			@Amount2 FLOAT,
			@CurGuid2 uniqueidentifier,
			@CurrencyVal2 FLOAT
			
		set @EnNumber = 1		 

		DECLARE itemcur CURSOR FORWARD_ONLY FOR
		SELECT 
			i.Number, i.Amount, i.netWages, i.CurrencyGuid,i.CurrencyVal,
			i.Amount2, i.CurrencyGuid2, i.CurrencyVal2
		FROM 
			trnStatementItems000 AS i
			INNER JOIN TrnStatement000 AS s ON s.GUID = i.ParentGUID
			WHERE ParentGUID = @StatemntGUID
			order by i.number
		
		OPEN itemcur 
		FETCH NEXT FROM itemcur INTO 
			@Number,
			@Amount,
			@NetWages,
			@CurGuid1,
			@CurrencyVal1,
			@Amount2,
			@CurGuid2,
			@CurrencyVal2
		WHILE @@FETCH_STATUS = 0 
		BEGIN  
			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			VALUES(
				@EnNumber,
				@SDate,
				(@Amount + @NetWages) * @CurrencyVal1,	--Debit
				0,			--Credit
				'',			--Note
				@CurrencyVal1, 
				@entryGUID,
				@DebitAccGUID,
				@CurGuid1,
				0x0,
				0x0
			)
			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			VALUES(
			
				@EnNumber + 1,
				@SDate,
				0,			--Debit
				@Amount2 * @CurrencyVal2,	--Credit
				'',			--Code
				@CurrencyVal2,--@CurrencyVal2,
				@entryGUID,
				@CreditAccGUID,
				@CurGuid2,--@CurGuid2,
				0x0,--costGuid
				0x0 -- contrAcc here ??
				)
			if (@NetWages <>0)
			BEGIN
			INSERT INTO en000 (Number, Date, Debit, Credit, Notes, CurrencyVal, ParentGUID, accountGUID, CurrencyGUID, CostGUID, ContraAccGUID)
			VALUES(
				@EnNumber + 2,
				@sDate,
				0,				--Debit
				@NetWages * @CurrencyVal1,	--Credit
				'',			--Code
				@CurrencyVal1,
				@entryGUID,
				@WagesBranchGUID,
				@CurGuid1,
				0x0,--costGuid
				0x0 -- contrAcc
				)
				set @EnNumber = @EnNumber + 3
			end
		 	else
				set @EnNumber = @EnNumber + 2



			FETCH NEXT FROM itemcur INTO 
				@Number,
				@Amount,
				@NetWages,
				@CurGuid1,
				@CurrencyVal1,
				@Amount2,
				@CurGuid2,
				@CurrencyVal2

		END

		CLOSE itemcur 
		DEALLOCATE itemcur
		
	END
	/*		
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
	*/
	-- post entry: 
	UPDATE ce000 SET IsPosted = 1 WHERE GUID = @entryGUID 

	-- link  
	INSERT INTO er000 (EntryGUID, ParentGUID, ParentType, ParentNumber)
			VALUES(@entryGUID, @StatemntGUID, 510, @entryNum) 
   
	-- return data about generated entry 
	SELECT @entryGUID AS EntryGuid, @entryNum as EntryNum
################################################################
#END