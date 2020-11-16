#########################################################
CREATE TRIGGER trg_ce000_CheckConstraints
	ON [ce000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION

AS 
/* 
This trigger checks: 
	- not to insert posted records.							(AMNE0040)
	- not to delete posted records.							(AMNE0041)
	- not to have unbalanced posted records.					(AMNE0042)
	- unbalanced CostJobs, if options in db states this.			(AMNW0043)
	- posting pre checkdates.								(AMNW0044)
	- unknown account in entries.							(AMNE0045)
	- unknown contraAccount in entries.						(AMNE0046)
	- unknown costJob in entries.								(AMNE0047)
	- unknown currency in entries.							(AMNE0048)
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 

	DECLARE @GUID [NVARCHAR](128)-- not uniqueidentifier, to help in typecasting 
	
	-- study a case when inserting posted records: 
	IF NOT EXISTS(SELECT * FROM [deleted])
		insert into ErrorLog ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0001: Can''t insert posted entries', [guid]
			from [inserted]
			where [IsPosted] = 1

	-- study a case when deleting posted records: 
	IF NOT EXISTS(SELECT * FROM [inserted]) 
		insert into ErrorLog ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0001: Can''t delete posted entries', [guid]
			from [deleted] where [IsPosted] = 1


	DECLARE @User INT
	SET @User = [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 0X1024, 0x00, 1, 0)
	-- study a case when posting/unposting to accounts pre CheckDates:
	IF EXISTS(SELECT * FROM [deleted]) AND UPDATE([IsPosted]) AND ( @User > 0)-- and exists in [inserted] (but no need for this check)
		INSERT INTO [ErrorLog]( [level], [type], [c1], [g1])
		SELECT 2, 0, 'AmnW0044: ' + CAST( [e].accountGuid AS [NVARCHAR](128)) + ' Posting to account(s) before CheckDate(s)', [e].[parentGuid]
		FROM [inserted] [c] INNER JOIN [en000] [e] ON [c].[guid] = [e].[parentGUID] INNER JOIN ( SELECT [AccGUID] AS [Guid],MAX([CheckedToDate]) AS [checkDate] FROM [dbo].[CheckAcc000] AS [Ac]  GROUP BY [AccGUID]) [a] ON [e].[accountGUID] = [a].[guid]
		WHERE [e].[date] < [a].[checkDate] AND [IsPosted] = 1
			
	-- data integrity check:
	declare @t table(
		[guid] [uniqueidentifier],
		[accountGuid] [uniqueidentifier],
		[contraAccGuid] [uniqueidentifier],
		[costGuid] [uniqueidentifier],
		[currencyGuid] [uniqueidentifier])
	IF ( @User <= 0)
			insert into ErrorLog ([level], [type], [c1], [g1])
			SELECT 1, 0,  'AmnE0151: you don''t have a permit to update before mach acc data[' + ac.Code + '-' + ac.Name + ']' ,Accguid
			FROM [CheckAcc000] A INNER JOIN EN000 B on a.Accguid = b.AccountGuid
			INNER JOIN (SELECT GUID FROM INSERTED WHERE IsPosted = 1 UNION ALL SELECT GUID FROM DELETED WHERE IsPosted = 1) v on v.Guid = b.parentguid
			INNER JOIN ac000 ac ON ac.Guid = b.AccountGuid
			GROUP BY Accguid,B.[Date],ac.Code, ac.Name
			HAVING MAX(Checkedtodate) > B.[Date]

--«” »œ«· „—«ﬂ“ «·ﬂ› «·€Ì— „ÊÃÊœ… »„—«ﬂ“ «·ﬂ› «·«› —«÷Ì… 
	IF  EXISTS(SELECT * FROM [inserted])
	Begin
		EXEC prcDisableTriggers	'en000'
			UPDATE en000 
				SET  CostGUID = AC.CostGUID
					FROM en000 EN
						INNER JOIN ac000 AC ON  EN.AccountGUID =  AC.Guid  
					WHERE AC.ForceCostCenter = 1
					and EN.CostGUID = 0x0
					and AC.CostGUID <> 0x
					and EN.[parentGuid] in (select guid from inserted)
		EXEC prcEnableTriggers	'en000'
	End
	insert into @t select [e].[parentGuid], [e].[accountGuid], [e].[contraAccGuid], [e].[costGuid], [e].[currencyGuid] from [en000] [e] inner join [inserted] [i] on [e].[parentGuid] = [i].[guid]

						---- ibrahim.elsayed ------
			declare @costcenteguid  uniqueidentifier = 0x0 ;
			declare @WhereForceCostCenter int = 0 ; 
			--· ÕœÌœ ﬁ·„ «·Õ”«» «·–Ï ·„ ÌÕœœ „—ﬂ“ ﬂ·›Â ›Ï Õ«·… ›—÷ ⁄·ÌÂ „—ﬂ“ ﬂ·›Â
		set @costcenteguid =
			(
			
		 		select top 1 ac.Guid
				from @t t inner join ac000 ac 
				on t.[accountGuid] = ac.Guid
				inner join ce000 on t.GUID = ce000.Guid
				left join er000 on t.GUID = er000.EntryGUID
				left join py000 on er000.ParentGUID = py000.Guid
				left join et000 on ce000.[TypeGUID] = et000.Guid
				where ((et000.ForceCostCenter = 1 AND et000.CostForBothAcc = 1 AND py000.AccountGUID = t.accountGuid) or (et000.ForceCostCenter = 1 AND py000.AccountGUID <> t.accountGuid)) and t.CostGuid = 0x00 --
			)
			--	   0x0  ÕœÌœ «Ì‰ ›—÷ ⁄·ÌÂ „—ﬂ“ «·ﬂ·›… ÌÕœœ ⁄‰ ÿ—Ìﬁ „⁄—› ‰Ê⁄ «·ﬁÌœ ·Ê
			--      ’»Õ „‰  ‰Ê⁄ ”‰œ ﬁÌœ  «Ï «‰Â „‰ »ÿ«ﬁ… «·Õ”«» €Ì— –«·ﬂ „‰ Œ’«∆’ «·«‰„«ÿ ··”‰œ«  «·—«∆Ì”Â  
		     
		set @WhereForceCostCenter =
		(
			select top 1 et.[ForceCostCenter]
	    	from @t t inner join ce000 ce
	    	on t.[GUID] = ce.[Guid]
	    	inner join et000 et 
	    	on et.[Guid] = ce.[TypeGUID]
	    	where t.[accountGuid] = @costcenteguid
		)
			
			IF(@costcenteguid <> 0x0)
				begin 
					 if(@WhereForceCostCenter = 1)
						begin
							 insert into ErrorLog ([level], [type], [c1], [g1]) 
							 select 1, 0, 'AmnE0050: '+cast(@costcenteguid as NVARCHAR(250))+' no cost center ', @costcenteguid
						end
					 else
						begin
							insert into ErrorLog ([level], [type], [c1], [g1]) 
							select 1, 0, 'AmnE0049: '+cast(@costcenteguid as NVARCHAR(250))+' no cost center ', @costcenteguid
						end
				end
			------------------ibrahim-------------------------------
		


	insert into ErrorLog ([level], [type], [c1], [g1])
		-- check accountGuid:
		select 1, 0, 'AmnE0045: found unknown account in entry item', [t].[guid]
		from @t [t] left join [ac000] [x] on [t].[accountGuid] = [x].[guid]
		where [x].[guid] is null

		-- check contraAccGuid:
	insert into ErrorLog ([level], [type], [c1], [g1])
		select 1, 0, 'AmnE0046: found unknown contra account in entry item', [t].[guid]
		from @t [t] left join [ac000] [x] on [t].[contraAccGuid] = [x].[guid]
		where [t].[contraAccGuid] != 0x0 and [x].[guid] is null
	
	
			

	-- check costGuid:
	insert into ErrorLog ([level], [type], [c1], [g1])
		select 1, 0, 'AmnE0047: found unknown costJob in entry item', [t].[guid]
		from @t [t] left join [co000] [x] on [t].[costGuid] = [x].[guid]
 		where [t].[costGuid] != 0x0 and [x].[guid] is null

		-- check currencyGuid:
	insert into ErrorLog ([level], [type], [c1], [g1])
		select 1, 0, 'AmnE0048: found currency in entry item', [t].[guid]
		from @t [t] left join [my000] [x] on [t].[currencyGuid] = [x].[guid]
		where [t].[currencyGuid] != 0x0 and [x].[guid] is null
		
#########################################################
CREATE TRIGGER trg_ce000_post
	ON [ce000] FOR UPDATE
	NOT FOR REPLICATION

AS 
/* 
This trigger: 
	- handles the changes in IsPosted field 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	DECLARE @t TABLE([GUID] [UNIQUEIDENTIFIER], [MainAcc] [UNIQUEIDENTIFIER]) 
	DECLARE  
		@c 			CURSOR,  
		@GUID		[UNIQUEIDENTIFIER], 
		@OldPost	[INT],  
		@NewPost	[INT],
		@cnt INT,
		@Level INT,
		@OldPostDate [DateTime]
	DECLARE @ErrorLog TABLE([Type] [int] NULL, 
	[i1] [int] NULL DEFAULT (0), 
	[c1] [NVARCHAR](255) COLLATE Arabic_CI_AI NULL DEFAULT (''), 
	[c2] [NVARCHAR](255) COLLATE Arabic_CI_AI NULL DEFAULT (''), 
	[f1] [float] NULL DEFAULT (0), 
	[f2] [float] NULL DEFAULT (0), 
	[g1] [uniqueidentifier] NULL DEFAULT (null), 
	[g2] [uniqueidentifier] NULL DEFAULT (null), 
	[level] [int] NOT NULL DEFAULT (0), 
	[spid] [int] NOT NULL DEFAULT (@@spid) 
	) 
	DECLARE @bgu TABLE([account] [UNIQUEIDENTIFIER], Cost [UNIQUEIDENTIFIER], [Branch] [UNIQUEIDENTIFIER], Bal FLOAT, StartDate DATETIME, QFLAG VARCHAR(MAX), [debitBal] FLOAT, PeriodGuid UNIQUEIDENTIFIER)
	DECLARE @en TABLE (AccountGUID [UNIQUEIDENTIFIER],Debit FLOAT,Credit FLOAT,ParentGUID [UNIQUEIDENTIFIER], CostGUID [UNIQUEIDENTIFIER] ,Cost [UNIQUEIDENTIFIER],[Date] DATETIME)
    DECLARE @qq TABLE(AccountGuid [UNIQUEIDENTIFIER], Costguid [UNIQUEIDENTIFIER], BAL FLOAT, StartDate DATETIME
				,Branch [UNIQUEIDENTIFIER], ParentGuid [UNIQUEIDENTIFIER], acLevel INT, coLevel INT, QFLAG NVARCHAR(100)) 
	DECLARE @Budjet TABLE(AccountGuid [UNIQUEIDENTIFIER], Costguid [UNIQUEIDENTIFIER], StartDate DATETIME, bal FLOAT, bug FLOAT)
	
	declare @zero FLOAT 
		set @zero = dbo.fnGetZeroValuePrice()  
	IF UPDATE(IsPosted) 
	BEGIN 
		 
		SET @c = CURSOR FAST_FORWARD FOR 
			SELECT [i].[GUID], [d].[IsPosted], [d].[PostDate], [i].[IsPosted] 
			FROM [inserted] AS [i] INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID] 
		OPEN @c FETCH FROM @c INTO @GUID, @OldPost, @OldPostDate, @NewPost 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			IF @OldPost <> @NewPost -- posting state changed 
			BEGIN 
				IF @OldPost = 0 
				BEGIN 
					EXECUTE [prcEntry_Post] @GUID, 1 
					EXECUTE [prcEntry_AssignContraAcc] @GUID = @GUID 
					IF(@OldPostDate = '1980-1-1')
						UPDATE Ce000 Set PostDate = GetDate() WHERE Guid = @GUID
				END ELSE 
					EXECUTE [prcEntry_Post] @GUID, -1 
			END 
			FETCH FROM @c INTO @GUID, @OldPost, @OldPostDate, @NewPost 
		END -- @c loop 
		CLOSE @c DEALLOCATE @c 
		 
		-- For check budget 
		IF  EXISTS ( SELECT * FROM OP000 WHERE NAME = 'AmnCfg_CheckBudgetBal' AND Value = '1')  
		BEGIN  
			DECLARE @ce TABLE( 
				[account] UNIQUEIDENTIFIER, 
				Cost UNIQUEIDENTIFIER, 
				[Branch] UNIQUEIDENTIFIER, 
				ParentGuid UNIQUEIDENTIFIER, 
				[Level] TINYINT, 
				coLevel TINYINT
			) 
			INSERT INTO @ce  
			SELECT  DISTINCT en.AccountGuid AS [account],[en].[CostGuid] AS Cost,[i].[Branch],ac.ParentGuid, 0 AS [Level] ,0 as coLevel 
			 
				FROM [inserted] AS [i] --INNER JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]   
				INNER JOIN en000 en ON en.ParentGuid = i.Guid  
				INNER JOIN ac000 ac ON ac.Guid = en.accountGuid  
				WHERE [i].[IsPosted] > 0  
			SET @cnt = @@RowCount  
			IF (@cnt > 0) 
			BEGIN 
			 
			DECLARE @bdp TABLE(Guid UNIQUEIDENTIFIER,StartDate DATETIME,EndDate DATETIME) 
			IF EXISTS(SELECT periodGuid from abd000 where PeriodGuid <> 0x00) 
				INSERT INTO @bdp 
					SELECT Guid,StartDate,EndDate FROM bdp000 WHERE GUID NOT IN (SELECT ParentGUID FROM pd000)  
				SET @Level = 0  
				WHILE @cnt > 0  
				BEGIN  
					INSERT INTO @ce  
						SELECT  c.ParentGuid ,Cost,[Branch],ac.ParentGuid,@Level + 1,0  
						FROM @ce c INNER JOIN ac000 ac ON ac.Guid = c.ParentGuid  
						WHERE [Level] = @Level  
						GROUP BY c.ParentGuid,Cost,[Branch],ac.ParentGuid  
						SET @cnt = @@rowCount  
						SET @Level = @Level + 1  
						 
				END  
				SET @Level = 0 
				set @cnt = 1 
				WHILE @cnt > 0  
				BEGIN  
					INSERT INTO @ce  
						SELECT [account],co.ParentGuid,[Branch],0X00,[Level],@Level + 1 
						FROM @ce c INNER JOIN co000 co ON co.Guid = c.Cost  
						WHERE [COLevel] = @Level AND  co.ParentGuid <> 0x00 
						GROUP BY  [account],co.ParentGuid,[Branch],[Level] 
						SET @cnt = @@rowCount  
						SET @Level = @Level + 1  
				END  
				DECLARE @ce2 TABLE( 
					[account] UNIQUEIDENTIFIER, 
					Cost UNIQUEIDENTIFIER, 
					[Branch] UNIQUEIDENTIFIER, 
					PRIMARY KEY CLUSTERED  
					( 
						[account],Cost ASC 
					) 
					) 
				INSERT INTO @ce2 ([account],[Cost],[Branch]) SELECT [account],[Cost],[Branch] FROM @ce 
				group by [account],[Cost],[Branch] 
		 
				--CREATE INDEX dfsdafsdafkjkl on #ce([account],[Cost])  
				INSERT INTO @bgu  
				SELECT 
					[account],
					Cost,
					[Branch],
					Bal,
					StartDate,
					CAST([account] AS NVARCHAR(36)) + CAST(Cost AS NVARCHAR(36)) QFLAG,
					[debitBal],
					PeriodGuid 
				FROM (  
						SELECT   [account],Cost,[Branch],StartDate,Bal,[debitBal] ,PeriodGuid
						FROM  
						(  
							SELECT  [account],ce.Cost,ce.[Branch],abd.Branch abdBranch,ab.Guid,abd.CostGuid,abd.Debit - abd.Credit Bal ,ISNULL(	StartDate,'1/1/1980') StartDate,CASE WHEN abd.Debit > 0 THEN 1 ELSE 0 END [debitBal] ,abd.PeriodGuid
							FROM @ce2 ce INNER JOIN ab000 ab ON AB.AccGuid = [account] 
							INNER JOIN abd000  abd ON abd.ParentGUID = ab.[GUID] 
							LEFT  JOIN (SELECT * FROM  @bdp WHERE Guid <> 0X00) bdp ON bdp.Guid = periodGuid  
						  ) q   
						WHERE Cost =  CostGuid AND (abdBranch = 0x00 OR Branch = abdBranch)  
					) q2   
				 
				

	INSERT INTO @en select AccountGUID,
	[dbo].[fnCurrency_fix](en.Debit, en.CurrencyGUID, [en].[CurrencyVal], AC2.CurrencyGUID, en.Date) ,
	[dbo].[fnCurrency_fix](en.Credit, en.CurrencyGUID, [en].[CurrencyVal], AC2.CurrencyGUID, en.Date),
	en.ParentGUID,en.CostGUID,Cost,[Date]
	 from en000 en 
	 JOIN ac000 AC2 ON en.AccountGUID = AC2.GUID
	 INNER JOIN(select DISTINCT account FROM @ce2) AC ON en.AccountGUID = account 
	 INNER JOIN(select DISTINCT Cost FROM @ce2) Co ON en.CostGUID = Cost
	 --
	DELETE @en WHERE CostGUID<>Cost
				INSERT INTO @qq SELECT AccountGuid,en.Costguid,Sum(en.Debit) - SUM (en.Credit) AS BAL  
				, StartDate 
				,Branch,v.ParentGuid,0 as acLevel ,0 coLevel 
				,CAST(AccountGuid AS NVARCHAR(36)) + CAST(en.Costguid AS NVARCHAR(36))   QFLAG  
				
					 FROM ( 
							SELECT  
								AccountGuid,Costguid,SUM(Debit)Debit ,SUM(Credit) Credit,Branch,StartDate 
								FROM 
								( 
									SELECT en1.AccountGuid,en1.Costguid,en1.Debit Debit ,en1.Credit Credit,ce.Branch, 
									 ISNULL((SELECT MAX(StartDate) FROM @bdp WHERE en1.Date BETWEEN StartDate AND EndDate ),'1/1/1980') --Khaleds
									 StartDate   
												  
									 FROM  @en en1  INNER JOIN ce000 ce ON ce.Guid =en1.ParentGuid 
									 WHERE  ce.Isposted > 0) ee 
									 GROUP BY  
					  					AccountGuid,Costguid,Branch,StartDate 
								) en   
						INNER JOIN ac000 v ON v.Guid = en.AccountGuid  
					GROUP BY AccountGuid,en.Costguid,Branch,v.ParentGuid,StartDate 
				SET @Level = 0 
				SET @cnt = 1  
				WHILE	@cnt > 0  
				BEGIN 
					INSERT INTO @qq(AccountGuid,Costguid,BAL,Branch,ParentGuid,StartDate,QFLAG,coLevel,acLevel ) 
					SELECT a.AccountGuid,co.Parentguid,SUM(BAL),a.Branch,a.ParentGuid,a.StartDate,CAST( a.AccountGuid AS NVARCHAR(36)) + CAST(co.Parentguid AS NVARCHAR(36)),@Level + 1,acLevel  
					FROM @qq a INNER JOIN CO000 co ON co.GUID = Costguid 
					WHERE coLevel = @Level AND co.Parentguid <> 0x00 
					GROUP BY  
					a.AccountGuid,co.Parentguid,a.Branch,a.ParentGuid,a.StartDate,CAST( a.AccountGuid AS NVARCHAR(36)) + CAST(co.Parentguid AS NVARCHAR(36)),acLevel 
					SET @cnt = @@ROWCOUNT 	 
					SET @Level = @Level + 1 			 
				END 
				INSERT INTO @qq (AccountGuid,Costguid,BAL, StartDate,Branch,QFLAG,coLevel,acLevel)  
				SELECT  AccountGuid,Costguid,SUM(BAL), StartDate,Branch,QFLAG,-1,-1 
				FROM @qq 
				GROUP BY AccountGuid,Costguid, StartDate,Branch,QFLAG 
					 
				DELETE @qq WHERE coLevel <> -1 
		 
				INSERT INTO @Budjet SELECT DISTINCT AccountGuid,a.Costguid ,A.StartDate,a.Bal bal,b.Bal bug    
				FROM   
					@qq a INNER JOIN @bgu b ON b.QFLAG = a.QFLAG  
					WHERE  (b.Branch = 0x00 OR [a].[Branch] = [b].[Branch])  
					AND ((([debitBal] = 1) AND (a.Bal - b.Bal) > [dbo].[fnGetZeroValuePrice]()) OR (([debitBal] = 0) AND ((b.Bal) - (a.Bal)) > [dbo].[fnGetZeroValuePrice]()))  --KhaledS
					AND ((A.StartDate = b.StartDate AND b.PeriodGuid <> 0x) OR b.PeriodGuid = 0x)
				IF (@@RowCOunt > 0)  
				BEGIN  
						INSERT INTO @ErrorLog ([level], [type], [c1], [g1])
							SELECT  2, 0, 'AmnW00300: ' + cast(AccountGuid as NVARCHAR(128)) + '  ['+ cast(CostGuid as NVARCHAR(128)) + '] Account and Job Cost have exceeded the budjet bal['    
							+ CAST (bal AS NVARCHAR(20)) + '] BUG[' + CAST (bug AS NVARCHAR(20)) +']' ,AccountGuid   
						FROM  @Budjet   
				END  
				INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) SELECT [level], [type], [c1], [g1] FROM @ErrorLog 
			END  
	END 
	-- study a case when having unbalanced costJob:  
		INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
			select  2, 0, N'AmnW0043: ' + cast([e].costGuid as [NVARCHAR](128)) + N' costJob found unbalaced in ce000', [e].[parentGuid] 
			from [en000] [e] inner join [inserted] [c] ON [e].[parentGUID] = [c].[guid]  
			where [c].[isPosted] = 1 and [e].[costGUID] <> 0x0  
			group by [e].[parentGuid], [e].[costGUID] 
			having abs(sum([e].[debit]) - sum([e].[credit])) > [dbo].[fnGetZeroValuePrice]() 
	INSERT into ErrorLog ([level], [type], [c1], [g1]) 
		select 1, 0, N'AmnE0042: Can''t insert unbalanced posted records in ce000' + CAST(Number AS NVARCHAR(10)), [guid] 
		from [inserted] 
		where [isPosted] = 1 and abs([debit] - [credit]) > @zero 
	 
	-- study a case when having unbalanced posted records:  

	INSERT INTO [ErrorLog]( [level], [type], [c1], [g1]) 
	SELECT 1, 0, 'AmnE0049: '+ cast([en].[AccountGUID] as NVARCHAR(250))'+ found no costJob in entry item', [en].[AccountGUID]  
	FROM [en000] [en] 
	INNER JOIN  [INSERTED] [i] ON [i].[Guid] = [en].[ParentGuid]  
	INNER JOIN ac000 AS ac On ac.GUID = en.AccountGUID
	WHERE [en].[CostGuid] = 0x00 
		AND (ac.ForceCostCenter = 1 AND ac.CostGuid = 0x0) 
	 
	INSERT INTO [ErrorLog]( [level], [type], [c1], [g1]) 
	SELECT 2, 0, 'AmnW0077: found no costJob in entry item', [en].[guid] 
	FROM [en000] [en] INNER JOIN  [INSERTED] [i] ON [i].[Guid] = [en].[ParentGuid]  
	WHERE [en].[CostGuid] = 0x00 AND [i].[IsPosted] = 1 
END 
#########################################################
CREATE TRIGGER trg_ce000_delete
	ON [ce000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- deletes related records: en
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	DELETE [en000] FROM [en000] INNER JOIN [deleted] ON [en000].[ParentGUID] = [deleted].[GUID]
	DELETE py FROM py000 AS py JOIN er000 AS er ON er.ParentGUID = py.GUID JOIN deleted AS CE ON CE.GUID = er.EntryGUID
	DELETE [er000] FROM [er000] INNER JOIN [deleted] ON [er000].[EntryGUID] = [deleted].[GUID]
	DELETE au FROM Audit000 au INNER JOIN [deleted] ON au.AuditRelGuid = deleted.GUID

###########################################################################
CREATE TRIGGER trg_ce000_post_NotificationSystem
	ON [ce000] FOR UPDATE
	NOT FOR REPLICATION

AS 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 	

	IF NOT EXISTS(SELECT * FROM NSAccountCondition000)
		RETURN

	IF UPDATE(IsPosted)
	BEGIN

	DECLARE @ceGUID UNIQUEIDENTIFIER
	DECLARE @enGUID UNIQUEIDENTIFIER
	DECLARE @InsertedEntry CURSOR
	DECLARE @InsertedEntryItem CURSOR

	SET @InsertedEntry = CURSOR FAST_FORWARD FOR
	SELECT 
		[GUID] 
	FROM 
		[inserted]
	WHERE
		IsPosted > 0
	OPEN @InsertedEntry;	
		FETCH NEXT FROM @InsertedEntry INTO @ceGUID;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN
		-----------------------------------------------------------

			SET @InsertedEntryItem = CURSOR FAST_FORWARD FOR
			SELECT 
				[GUID] 
			FROM 
				en000
			WHERE
				ParentGUID = @ceGUID
			OPEN @InsertedEntryItem;	
			FETCH NEXT FROM @InsertedEntryItem INTO @enGUID;
			WHILE (@@FETCH_STATUS = 0)
			BEGIN
				
				EXEC NSPrcObjectEvent @EnGuid,  9, 0

			FETCH NEXT FROM @InsertedEntryItem INTO @enGUID;
			END
			CLOSE      @InsertedEntryItem;
			DEALLOCATE @InsertedEntryItem;

		-----------------------------------------------------------
		FETCH NEXT FROM @InsertedEntry INTO @ceGUID;
		END
		CLOSE      @InsertedEntry;
		DEALLOCATE @InsertedEntry;

	END
###########################################################################
CREATE TRIGGER trg_ce000_insert
	ON [dbo].[ce000] FOR INSERT
	NOT FOR REPLICATION

AS  
	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  

	IF EXISTS (SELECT * FROM inserted WHERE ISNULL(CreateUserGUID, 0x0) = 0x0)
	BEGIN 
		UPDATE ce 
		SET 
			CreateUserGUID = [dbo].[fnGetCurrentUserGUID](),
			CreateDate = GETDATE()
		FROM 
			ce000 ce 
			INNER JOIN inserted i ON ce.GUID = i.GUID 
		WHERE 
			ISNULL(i.CreateUserGUID, 0x0) = 0x0
	END 
###########################################################################
#END
