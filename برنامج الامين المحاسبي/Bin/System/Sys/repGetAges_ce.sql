################################################################################
CREATE PROCEDURE repGetAges_ce
		@Account [UNIQUEIDENTIFIER],  
		@CostGuid [UNIQUEIDENTIFIER],  
		@UntilDate [DATETIME],  
		@DEBITCREDITFLAG	tinyint,  
		@Detailed [BIT],  
		@NumOfPeriods [INT],  
		@PeriodLength [INT],  
		@CurGUID [UNIQUEIDENTIFIER],  
		@CurVal [FLOAT],  
		@UserID [UNIQUEIDENTIFIER],    
		@CustOnly	[BIT] = 0,   
		@DetCost	BIT = 0,  
		@SrcGuid	UNIQUEIDENTIFIER = 0X00, 
		@CusTCondAcc [UNIQUEIDENTIFIER] =0X00,
		@Customer [UNIQUEIDENTIFIER] =0X00	 
AS   
	SET NOCOUNT ON   
	--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
	DECLARE   
		@c_ac CURSOR,  
		@dcType  tinyint,  
		@acGuid [UNIQUEIDENTIFIER], 
		@custGuid [UNIQUEIDENTIFIER],  
		@acSumOfOtherSide [FLOAT],  
		@CostPtr	UNIQUEIDENTIFIER  
	DECLARE    
		@c_en CURSOR,  
		@en_dcType  NVARCHAR(1), 
		@enDebitCredit [FLOAT],  
		@ceGuid [UNIQUEIDENTIFIER],  
		@enDate [DATETIME],  
		@Notes [NVARCHAR](1000), 
		@enNumber [INT],  
		@ceNumber [INT],@ID INT  
	-----------------------------------------------------------   
	DECLARE @AccTbl TABLE( [Guid] [UNIQUEIDENTIFIER])   
	INSERT INTO @AccTbl SELECT [GUID] FROM [dbo].[fnGetAccountsList]( @Account, DEFAULT)   
	IF @CustOnly > 0   
		DELETE @AccTbl WHERE [Guid] NOT IN (SELECT [AccountGuid] FROM [cu000])   
	DECLARE @STR NVARCHAR(1000),@HosGuid [UNIQUEIDENTIFIER],@UserGuid [UNIQUEIDENTIFIER] 
	SET @HosGuid = NEWID()  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()       
	-----------------------------------------------------------   
	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER])   
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGuid)    
	IF ISNULL( @CostGuid, 0x0) = 0x0     
		INSERT INTO @Cost_Tbl VALUES(0x0)    
	-----------------------------------------------------------  
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])      
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])      
	-----------------------------------------------------------   
	CREATE TABLE [#ACC] ([Guid] [UNIQUEIDENTIFIER], [acSecurity] INT)
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#t_Result](   
			dcType  TINYINT,  
			[Account] [UNIQUEIDENTIFIER],    
			[Value] [FLOAT],    
			[EntryNum] [UNIQUEIDENTIFIER],   
			[enNumber] [INT],   
			[ceNumber] [INT],   
			[Date] [DATETIME],    
			[Remaining] [FLOAT],    
			[Age] [INT],    
			[Notes] [NVARCHAR](1000) COLLATE ARABIC_CI_AI,  
			[ParentGuid] [UNIQUEIDENTIFIER] DEFAULT 0X00,   
			[ParentNum]	[INT] DEFAULT 0,   
			[ParentType]	[INT] DEFAULT 0,   
			[ParentTypeGUID] [UNIQUEIDENTIFIER] DEFAULT 0X00,   
			[CostGuid]			UNIQUEIDENTIFIER,
			[Customer]			UNIQUEIDENTIFIER

			)   

	------------------------------------------------------------------   
	CREATE TABLE [#TmpRes](    
		[ceGuid]		[UNIQUEIDENTIFIER],    
		[enGuid]		[UNIQUEIDENTIFIER],    
		[enNumber]		[INT],   
		[enAccount]		[UNIQUEIDENTIFIER],      
		[enDebit]		[FLOAT],     
		[enCredit] 		[FLOAT],    
		[enCurrencyPtr] [UNIQUEIDENTIFIER],    
		[enCurrencyVal] [FLOAT],    
		[enDate]		[DATETIME],    
		[ce_Security] 	[INT],     
		[acSecurit] 	[INT],   
		[ceNumber]		[INT],    
		[enNotes]		[NVARCHAR](max) COLLATE ARABIC_CI_AI,  
		[enCostPoint] [UNIQUEIDENTIFIER],
		[enCustomer]  [UNIQUEIDENTIFIER])    
	---------------------------------------------------------------------------------------------------------------  
	--#Tables for resources check security.
	DECLARE @Sec INT 
	SET @Sec = [dbo].[fnGetUserEntrySec_Browse]([dbo].[fnGetCurrentUserGUID](),0X00) 
	
	INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGuid      
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGuid      
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGuid   
	  
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]  
	IF [dbo].[fnObjectExists]( 'prcGetTransfersTypesList') <> 0	  
		INSERT INTO [#EntryTbl]	EXEC [prcGetTransfersTypesList] 	@SrcGuid  
	IF [dbo].[fnObjectExists]( 'vwTrnStatementTypes') <> 0  
	BEGIN		  
		SET @str = 'INSERT INTO [#EntryTbl]  
		SELECT  
					[IdType],  
					[dbo].[fnGetUserSec](''' + CAST(@UserGuid AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1) 
				FROM  
					[dbo].[RepSrcs] AS [r]   
					INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]  
				WHERE  
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + '''' 
		EXEC(@str)  
	END  
	IF [dbo].[fnObjectExists]( 'vwTrnExchangeTypes') <> 0  
	BEGIN		  
		SET @str = 'INSERT INTO [#EntryTbl]  
		SELECT  
					[IdType],  
					[dbo].[fnGetUserSec](''' + CAST(@UserGuid AS NVARCHAR(36)) + ''',0X2000F200, [IdType],1,1) 
				FROM  
					[dbo].[RepSrcs] AS [r]   
					INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]  
				WHERE  
					[IdTbl] = ''' + CAST(@SrcGuid AS NVARCHAR(36)) + '''' 
		EXEC(@str)  
	END 			  
					  
	IF EXISTS(SELECT * FROM [dbo].[RepSrcs] WHERE [IDSubType] = 303)  
		INSERT INTO [#EntryTbl] VALUES(@HosGuid,0)  
	---------------------------------------------------------------------------------------------------------------   
	INSERT INTO [#ACC] SELECT [c].[Guid],[Security] AS [acSecurity]  FROM @AccTbl AS [c] INNER JOIN [ac000] AS [AC] ON [ac].[Guid] = [c].[Guid]    
	-------------------------------------------------------------------------------------- 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])  
	IF (@CusTCondAcc <> 0X00) 
	BEGIN  
		INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] 0X00, @Account,@CusTCondAcc       
		DELETE ac FROM [#ACC] ac  
		LEFT JOIN  
		(SELECT [Accountguid] FROM cu000 cu INNER JOIN  [#Cust] c ON c.Number = cu.Guid) cc  
		ON [Accountguid] = ac.Guid WHERE [Accountguid] IS NULL 
	END 
	-------------------------------------------------------------------------------------- 
	INSERT INTO [#TmpRes]   
		SELECT   
			[ceGUID],   
			[enGuid],    
			[enNumber],   
			[enAccount],   
			[enDebit],    
			[enCredit],    
			[enCurrencyPtr],  
			[enCurrencyVal],  
			[enDate],    
			[ceSecurity],  
			[acSecurity],  
			[ceNumber],   
			[enNotes],  
			[enCostPoint],
			[enCustomerGUID]   
		FROM  
		(			  
			SELECT    
				[en].[ceGUID],   
				[en].[enGuid],    
				[en].[enNumber],   
				[en].[enAccount],    
				[en].[enDebit],    
				[en].[enCredit],    
				[en].[enCurrencyPtr],    
				[en].[enCurrencyVal],    
				[en].[enDate],    
				[en].[ceSecurity],    
				[ac].[acSecurity],    
				[en].[ceNumber],   
				[en].[enNotes],   
				CASE @DetCost WHEN 1 THEN [en].[enCostPoint] ELSE 0X00 END   [enCostPoint],  
				CASE WHEN [er].[ParentType] BETWEEN 300 AND 305 THEN @HosGuid  else [cetypeguid] end cetypeguid ,
				[en].[enCustomerGUID] 
			FROM    
				[vwCeEn] AS [en]    
				INNER JOIN   [#ACC] AS [ac] ON [en].[enAccount] = [ac].[Guid]   
				INNER JOIN @Cost_Tbl AS [Cost] ON [en].[enCostPoint] = [Cost].[GUID]  
				INNER JOIN [#EntryTbl] rv ON [en].cetypeguid = rv.[Type]     
				LEFT JOIN ER000 er ON er.entryGuid = [en].[ceGUID]
				LEFT JOIN BU000 bu ON er.ParentGUID = [bu].[GUID]   
				
			WHERE    
				[en].[enDate] <= @UntilDate    
				AND [en].[ceIsPosted] <> 0
				AND ([bu].PayType <> 0 OR [bu].PayType IS NULL)
				AND [en].[ceSecurity] <= ISNULL([rv].[Security],@Sec) ) A
				
		   
		IF EXISTS (SELECT * FROM [Ages000] a INNER JOIN [#TmpRes] b ON [a].[refGuid] = [enGuid] WHERE a.Type = 0)   
		BEGIN   
			UPDATE a SET [enDate] = '1/1/1980' FROM [#TmpRes] a INNER JOIN [Ages000] b ON b.[refGuid] = [enGuid]   
			INSERT INTO [#TmpRes]   
			SELECT    
				[ceGuid],		   
				b.Guid,		   
				[enNumber],		   
				[enAccount],		   
				CASE WHEN [enDebit] > 0 THEN b.Val	ELSE 0 END ,		   
				CASE WHEN  [enCredit] > 0 THEN b.Val ELSE 0	END ,		   
				[b].[CurrencyGuid],    
				[b].[CurrencyVal],    
				b.[Date],	   
				[ce_Security], 	   
				[acSecurit], 	   
				[ceNumber],		   
				[enNotes],   
				[enCostPoint],
				[enCustomer]		   
			FROM [#TmpRes] a INNER JOIN [Ages000] b ON b.[refGuid] = [enGuid]   
			WHERE [enDate] = '1/1/1980'   
			DELETE [#TmpRes] WHERE [enDate] = '1/1/1980'   
		END   
	-------------------------------------------------------   
	EXEC [prcCheckSecurity] @result = '#TmpRes'   
	  
	CREATE TABLE #AGE  
	(  
		DCTYPE TINYINT,  
		ID INT IDENTITY(1,1),  
		BALANCE FLOAT,  
		[enAccount] UNIQUEIDENTIFIER,  
		ceGuid UNIQUEIDENTIFIER,  
		enDate DATETIME,  
		enNotes NVARCHAR(max) COLLATE ARABIC_CI_AI,  
		enNumber INT,  
		ceNumber INT,  
		enCostPoint UNIQUEIDENTIFIER,
		enCustomer  UNIQUEIDENTIFIER
	) 
	DECLARE @Cur TABLE ([Date] SMALLDATETIME,[Val] FLOAT) 
	INSERT INTO @Cur  
	SELECT [Date],CurrencyVal FROM mh000 WHERE CurrencyGuid = @CurGUID  
	UNION ALL  
	SELECT '1/1/1980',CurrencyVal FROM my000 WHERE [Guid] = @CurGUID  
	IF (@DEBITCREDITFLAG &0x00001 ) > 0   
	BEGIN  
		INSERT INTO [#AGE]( DCTYPE, BALANCE, enAccount, ceGuid, enDate, enNotes, enNumber, ceNumber, enCostPoint, enCustomer)  
		SELECT    
				0,  
				[enDebit] * Factor BALANCE,   
				[en].[enAccount],    
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber],   
				[enCostPoint],
				[en].[enCustomer]  
			  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate] ORDER BY DATE DESC) END Factor FROM [#TmpRes] )AS [en]   
			WHERE    
				 [en].[enCredit] = 0  
			ORDER BY  
				[enDate],    
				[en].[enNumber],   
				[en].[ceNumber]   
	end  
	if  (@DEBITCREDITFLAG &  0x00002) > 0   
	BEGIN  
		INSERT INTO [#AGE]( DCTYPE, BALANCE, enAccount, ceGuid, enDate, enNotes, enNumber, ceNumber, enCostPoint, enCustomer)  
		SELECT    
				1,  
				[en].[enCredit] * Factor,   
				[en].[enAccount],    
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber],   
				[enCostPoint],
				[en].[enCustomer]   
			  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] )AS [en]   
			WHERE    
				 [en].[enDebit] = 0  
			ORDER BY  
				[enDate],    
				[en].[enNumber],   
				[en].[ceNumber]   
	  
	END  
	CREATE TABLE #CREDIT 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER,
		[enCustomer] UNIQUEIDENTIFIER, 
		[Val] float,Flag BIT 
	) 
	CREATE TABLE #SUMDEBITS 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER,
		[enCustomer] UNIQUEIDENTIFIER, 		 
		[Val] FLOAT 
	) 
	CREATE TABLE #DEBIT 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER,
		[enCustomer] UNIQUEIDENTIFIER, 
		[Val] float,Flag BIT 
	) 
	CREATE TABLE #SUMCREDTS 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER,
		[enCustomer] UNIQUEIDENTIFIER, 		 
		[Val] FLOAT 
	) 
	IF (@DEBITCREDITFLAG &  0x00001) > 0 	 
		INSERT INTO #CREDIT   
		SELECT    
				 [en].[enAccount],[enCostPoint],[en].[enCustomer], 
				SUM([en].[enCredit] * Factor ),0 
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] ) AS [en]  where [en].[enCredit] > 0 AND (@DEBITCREDITFLAG &  0x00001) > 0  
			GROUP BY    
				[en].[enAccount],[enCostPoint],[en].[enCustomer] 
			--HAVING  SUM([enCredit]-[enDebit]) > 0  
	IF  (@DEBITCREDITFLAG &  0x00002) > 0
	   
		INSERT INTO #DEBIT 
		SELECT    
				 [en].[enAccount],[enCostPoint],[en].[enCustomer],   
				SUM([en].[enDebit] * Factor ),0  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] ) AS [en]  where [en].[enDebit] > 0 AND (@DEBITCREDITFLAG &  0x00002) > 0  
			GROUP BY    
				[en].[enAccount],[enCostPoint],[en].[enCustomer] 
			--HAVING  SUM([enDebit] -[enCredit]) > 0  
	DECLARE @dd SMALLDATETIME 
	SELECT @dd = MIN([enDate]) FROM [#TmpRes] 
	SET @dd = DATEADD(mm,1,@dd) 
	WHILE (	@dd <= @UntilDate) 
	BEGIN 
		IF (@DEBITCREDITFLAG &  0x00001) > 0 	 
		BEGIN 
			INSERT INTO #SUMDEBITS  
			SELECT    
					 [en].[enAccount], [enCostPoint], [en].[enCustomer],   
					SUM(BALANCE)   
				FROM    
					[#Age] AS [en]  WHERE DCTYPE = 0 AND enDate <= @dd 
				GROUP BY    
					[en].[enAccount], [enCostPoint], [en].[enCustomer]
			
			UPDATE C SET val = c.val - d.val ,Flag = 1 
			FROM  #CREDIT c   
			INNER JOIN #SUMDEBITS d ON CAST(d.[enAccount] AS NVARCHAR(36)) + CAST(d.[enCostPoint] AS NVARCHAR(36)) + CAST(d.[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
			WHERE c.val >= d.val  
			DELETE tmp FROM  [#Age] tmp INNER JOIN #CREDIT c  ON CAST(tmp.[enAccount] AS NVARCHAR(36)) + CAST(tmp.[enCostPoint] AS NVARCHAR(36)) + CAST(tmp.[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
			WHERE DCTYPE = 0 AND enDate <= @dd AND c.Flag = 1 
			UPDATE #CREDIT SET Flag = 0 WHERE Flag = 1 
			TRUNCATE TABLE #SUMDEBITS 
		END 
		IF (@DEBITCREDITFLAG &  0x00002) > 0 	 
		BEGIN 
			INSERT INTO #SUMCREDTS  
			SELECT    
					 [en].[enAccount], [enCostPoint], [en].[enCustomer],
					SUM(BALANCE)   
				FROM    
					[#Age] AS [en]  WHERE DCTYPE = 1 AND enDate <= @dd 
				GROUP BY    
					[en].[enAccount], [enCostPoint], [en].[enCustomer] 
				UPDATE C SET val = c.val - d.val ,Flag = 1 
				FROM  #DEBIT c   
			INNER JOIN #SUMCREDTS d ON CAST(d.[enAccount] AS NVARCHAR(36)) + CAST(d.[enCostPoint] AS NVARCHAR(36)) + CAST(d.[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
			WHERE c.val >= d.val  
			DELETE tmp FROM  [#Age] tmp INNER JOIN #DEBIT c  ON CAST(tmp.[enAccount] AS NVARCHAR(36)) + CAST(tmp.[enCostPoint] AS NVARCHAR(36)) + CAST(tmp.[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
			WHERE DCTYPE = 1 AND enDate <= @dd AND c.Flag = 1 
			UPDATE #DEBIT SET Flag = 0 WHERE Flag = 1 
			TRUNCATE TABLE #SUMCREDTS 
		END 
		SET @dd = DATEADD(mm,1,@dd) 
	END	  
	DELETE #CREDIT WHERE Val <= 0 
	DELETE #DEBIT WHERE Val <= 0 
	SET @c_ac = CURSOR FAST_FORWARD FOR   
			SELECT    
				0, [en].[enAccount],[enCostPoint],   
			val,[en].[enCustomer] 	   
			FROM  #CREDIT AS [en]  WHERE   val > 0  
		union all  
		SELECT    
				1, [en].[enAccount],[enCostPoint],   
			val,[en].[enCustomer] 	   
			FROM  #DEBIT AS [en]  WHERE   val > 0  
	------------------------------------------------------------------   
	OPEN @c_ac FETCH NEXT FROM @c_ac INTO @dcType, @acGuid,@CostPtr, @acSumOfOtherSide, @custGuid   
	 		  
	WHILE @@FETCH_STATUS = 0   
	BEGIN  
	------------------------------------------------------------------ 
		-------------------------------------  
		Declare @Tmp FLOAT 
		SELECT @Tmp = ISNULL(SUM(BALANCE), 0) 
		FROM [#AGE] AS [en]   
		WHERE [en].[enAccount] = @acGuid 
		AND [en].[enCustomer] = @custGuid
		AND (@DetCost = 0 OR [enCostPoint] = @CostPtr)   
		AND [DCTYPE] =@dcType  
		IF (@Tmp < @acSumOfOtherSide) 
			GoTo FetchLabel; 
			------------------------------- 
		------------------------------------------------------------------   
		SET @c_en = CURSOR FAST_FORWARD FOR   
		SELECT  
				[dcType],[ID],   
				BALANCE,   
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber]
			FROM    
				[#AGE] AS [en]   
			WHERE    
				[en].[enAccount] = @acGuid AND (@DetCost = 0 OR [enCostPoint] = @CostPtr  )  and [DCTYPE] =  @dcType AND [en].[enCustomer] = @custGuid
		ORDER BY    
			[ID]  
	   
		------------------------------------------------------------------   
		OPEN @c_en FETCH NEXT FROM @c_en INTO @en_dcType, @ID,@enDebitCredit, @ceGuid,@enDate, @Notes, @enNumber ,@ceNumber   
		WHILE @@FETCH_STATUS = 0   
		BEGIN 
			IF @acSumOfOtherSide < @enDebitCredit   
			BEGIN   
				IF @acSumOfOtherSide > 0   
				BEGIN   
					SET @acSumOfOtherSide = @acSumOfOtherSide - @enDebitCredit   
					INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid], [Customer] )   
						VALUES (@en_dcType, @acGuid, @enDebitCredit, @ceGuid, @enNumber,@ceNumber, @enDate, -@acSumOfOtherSide, DATEDIFF(d, @enDate, @UntilDate), @Notes ,@CostPtr, @custGuid)   
				END   
				ELSE   
				BEGIN   
				INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid], [Customer])   
					SELECT [dcType], [enAccount] ,BALANCE,[ceGuid],[enNumber],[ceNumber],[enDate],BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[enCostPoint], [enCustomer]    
					FROM #AGE [en] WHERE   
						[en].[enAccount] = @acGuid
						AND [en].[enCustomer] = @custGuid   
						AND [ID] >= @ID  
						AND [enCostPoint] = @CostPtr  
						AND dcType =  @dcType  
					BREAK   
				END   
			END   
			ELSE   
				SET @acSumOfOtherSide = @acSumOfOtherSide - @enDebitCredit   
			FETCH NEXT FROM @c_en INTO @en_dcType, @ID, @enDebitCredit, @ceGuid,@enDate, @Notes, @enNumber ,@ceNumber   
		END  
		CLOSE @c_en
		DEALLOCATE @c_en
		 
FetchLabel:  
		FETCH NEXT FROM @c_ac INTO @dcType, @acGuid, @CostPtr, @acSumOfOtherSide, @custGuid   
	END   
	CLOSE @c_ac   
	DEALLOCATE @c_ac   
	---------------------------------------------------- 
	-- For #credit or debit val = 0 
	INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid], [Customer])
	SELECT 0,[en].[enAccount], BALANCE, [en].[ceGuid],[en].[enNumber],[en].[ceNumber],[en].[enDate], BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[en].[enCostPoint],[en].[enCustomer] 
	FROM    
		[#AGE] AS [en]  LEFT JOIN #CREDIT c  ON CAST([en].[enAccount] AS NVARCHAR(36)) + CAST([en].[enCostPoint] AS NVARCHAR(36)) + CAST([en].[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
	WHERE c.[enAccount] IS NULL AND (@DEBITCREDITFLAG &  0x00001) > 0 		AND [dcType] = 0
	INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid], [customer])
	SELECT 1,[en].[enAccount], BALANCE, [en].[ceGuid],[en].[enNumber],[en].[ceNumber],[en].[enDate], BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[en].[enCostPoint],[en].[enCustomer] 
	FROM    
		[#AGE] AS [en]  LEFT JOIN #Debit c  ON CAST([en].[enAccount] AS NVARCHAR(36)) + CAST([en].[enCostPoint] AS NVARCHAR(36)) + CAST([en].[enCustomer] AS NVARCHAR(36)) = CAST(c.[enAccount] AS NVARCHAR(36)) + CAST(c.[enCostPoint] AS NVARCHAR(36)) + CAST(c.[enCustomer] AS NVARCHAR(36))
	WHERE c.[enAccount] IS NULL AND (@DEBITCREDITFLAG &  0x00002) > 0 	and [dcType] = 1 
	---------------------------------------------------- 
	---------------------------------------------------- 
	DELETE #T_Result WHERE ABS([Remaining]) < [dbo].[fnGetZeroValuePrice]()
	---------------------------------------------------- 
	DECLARE    
		@DtlPeriodCounter [INT], 
		@DtlSQL AS [NVARCHAR](max)  
		SET @DtlPeriodCounter = 0 
		SET @DtlSQL = ''
		WHILE @DtlPeriodCounter < @NumOfPeriods  
		BEGIN   
			SET @DtlSQL = @DtlSQL +'ALTER TABLE [#t_Result] ADD [Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) + '] [FLOAT]'  
			SET @DtlPeriodCounter = @DtlPeriodCounter + 1 
		END 
		EXEC (@DtlSQL) 
	IF @Detailed = 0   
	BEGIN   
		UPDATE [#t_Result]
		SET Customer = CASE WHEN EXISTS (SELECT AccountGUID FROM cu000 WHERE AccountGUID = T.Account) THEN Customer ELSE 0x0 END   
		FROM [#t_Result] T
		DECLARE    
			@PeriodCounter [INT],    
			@PeriodStart [INT],    
			@PeriodEnd [INT],    
			@SumSQL [NVARCHAR](max)  
		SET @PeriodCounter = 0   
		CREATE TABLE [#t] ([DCTYPE] tinyint, [Account] [UNIQUEIDENTIFIER],[CuGuid] [UNIQUEIDENTIFIER], [CostGuid] [UNIQUEIDENTIFIER] )   
		SET @SumSQL = ''   
		DECLARE @SQL AS [NVARCHAR](max)  
		SET @SQL = 'ALTER TABLE [#t] ADD [Balance] [FLOAT]'    
		WHILE @PeriodCounter < @NumOfPeriods  
		BEGIN   
			SET @SQL = @SQL + ', [Period' + CAST(@PeriodCounter+1 AS [NVARCHAR](5)) + '] [FLOAT]'  
			SET @PeriodStart = @PeriodCounter * @PeriodLength   
			SET @PeriodEnd = @PeriodStart + @PeriodLength   
			 
			SET @SumSQL = @SumSQL +  ', ISNULL((SELECT SUM([Remaining]) FROM [#t_Result] [t_inner] WHERE ' 
			---------------------------------------------------------------- 
			SET @SumSQL = @SumSQL + ' [t_inner].[Account] = [t_outer].[Account] AND ' 
			SET @SumSQL = @SumSQL + ' [t_inner].[Customer] = [t_outer].[Customer] AND '
			IF @DetCost > 0 
			BEGIN 
				DECLARE @TEMP3 NVARCHAR(100)
				SET @TEMP3 = ' 0x00 ' 
				SET @TEMP3 = ' [t_outer].[CostGuid] ' 
				SET @SumSQL = @SumSQL +  ' [t_inner].[CostGuid] = ' + @TEMP3 + ' AND ' 
			END 
			 
			SET @SumSQL = @SumSQL + ' [t_inner].[DCTYPE] = [t_outer].[DCTYPE] AND ' 
			---------------------------------------------------------------- 
			IF @PeriodCounter = (@NumOfPeriods - 1) 
				SET @SumSQL = @SumSQL +  ' [t_inner].[Age] >' + CAST(@PeriodStart AS [NVARCHAR](5)) + '), 0)'  
			ELSE  IF @PeriodCounter = 0  
				SET @SumSQL = @SumSQL +	' ( [t_inner].[Age] = 0 OR ( [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5))  
						+ ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '))), 0)' 
			ELSE  
				SET @SumSQL = @SumSQL +  ' [t_inner].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '), 0)'
			----------------------------------------------------------------	 
			SET @PeriodCounter = @PeriodCounter + 1 
		END 
		EXEC (@SQL)  
		DECLARE @SqlInsert AS [NVARCHAR](max)
		Declare @TEMP1 NVARCHAR(50), @TEMP2 NVARCHAR(50)
		SET @TEMP1 = ' 0x00 ' 
		SET @TEMP2 = '  ' 

		SET @TEMP1 = ' [CostGuid] ' 
		SET @TEMP2 = ',[CostGuid] ' 

		SET @SqlInsert = '  
				INSERT INTO [#t]  
				SELECT [dctype], [Account], [Customer],' + @TEMP1 + ', Sum([Remaining]) ' + @SumSQL + '  
				FROM [#t_Result] [t_outer]  
				GROUP BY [dctype], [Account], [Customer]' + @TEMP2 
		EXEC( @SqlInsert)   
		IF @CustOnly = 0   
		BEGIN 
			SELECT [ac].[acCode] AS [AcCode], [ac].[acName] AS [AcName], [ac].[acLatinName] AS [AcLatinName], [tb].*,[cu].[CustomerName] AS [CuName],ISNULL(co.Code,'') coCode,ISNULL(co.Name,'') coName,ISNULL(co.LatinName,'') coLatinName    
			FROM [#t] AS [tb]
			INNER JOIN [vwac] AS [ac] ON [tb].[Account] = [ac].[acGuid]
			LEFT JOIN [co000] co ON  co.Guid = [tb].[CostGuid]
			LEFT JOIN [cu000] cu ON cu.GUID = tb.CuGuid
			WHERE
				tb.CuGuid = CASE WHEN ISNULL(@Customer, 0x0) <> 0x0 THEN @Customer ELSE ISNULL(tb.CuGuid, 0x0) END  
			ORDER BY
				[DCTYPE], [tb].[Account],[tb].[CostGuid]   
			
		END 
	 ELSE  
		BEGIN  
			DECLARE @StrSql1 NVARCHAR(1000) 
			SET @StrSql1 =  ' SELECT'  
			 
			SET @StrSql1 = @StrSql1 +  '[cu].[Guid] AS [cuGuid], [cu].[CustomerName] AS [CuName], ' 
			SET @StrSql1 = @StrSql1 + ' [tb].* '  
			IF @DetCost > 0   
				SET @StrSql1 = @StrSql1 + ',ISNULL(co.Code,'''') coCode,ISNULL(co.Name,'''') coName,ISNULL(co.LatinName,'''') coLatinName '   
  
			SET @StrSql1 = @StrSql1 +  ' FROM [#t] AS [tb] ' 
			SET @StrSql1 = @StrSql1 +'INNER JOIN [cu000] AS cu ON [cu].[Guid] = [tb].[CuGuid] ' 
			IF @DetCost > 0   
				SET @StrSql1 = @StrSql1 + ' LEFT JOIN [co000] co ON  co.Guid = [tb].[CostGuid] '    
			IF(ISNULL(@Customer, 0x0) <> 0x0)
				SET @StrSql1 = @StrSql1 +  'WHERE  tb.CuGuid =  ''' + convert( char(100), @Customer)+'''' 
			SET @StrSql1 = @StrSql1 +  
			' ORDER BY [DCTYPE]'
			  
			SET  @StrSql1 = @StrSql1 + ', [cu].[CustomerName]'

			IF @DetCost > 0  
				SET @StrSql1 = @StrSql1 + ', ISNULL(co.Code,'''')'  
			EXEC (@StrSql1) 
		END  
	END  
	ELSE  
	BEGIN   
		SET @DtlSQL = ''
		SET @DtlPeriodCounter = 0    
		WHILE @DtlPeriodCounter < @NumOfPeriods
		BEGIN   
			SET @DtlSQL = @DtlSQL + ' UPDATE [#t_Result] SET [Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) +']' + '= [#t_Result].[Remaining] WHERE ' 
			SET @PeriodStart = @DtlPeriodCounter * @PeriodLength   
			SET @PeriodEnd = @PeriodStart + @PeriodLength
			IF @DtlPeriodCounter = (@NumOfPeriods - 1) 
				SET @DtlSQL = @DtlSQL +  ' [#t_Result].[Age] >' + CAST(@PeriodStart AS [NVARCHAR](5))
			ELSE  IF @DtlPeriodCounter = 0  
				SET @DtlSQL = @DtlSQL +	' ([#t_Result].[Age] = 0 OR ([#t_Result].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5))  
						+ ' AND [#t_Result].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5)) + '))' 
			ELSE  
				SET @DtlSQL = @DtlSQL +  ' [#t_Result].[Age] > ' + CAST(@PeriodStart AS [NVARCHAR](5)) + ' AND [#t_Result].[Age] <= ' + CAST(@PeriodEnd AS [NVARCHAR](5))
			SET @DtlPeriodCounter = @DtlPeriodCounter + 1   
			EXEC (@DtlSQL)
		END 
				
		UPDATE [t] SET [ParentGuid] = [er].[ParentGuid],[ParentNum] = [bu].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [bu].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbbu] AS [bu] ON [bu].[Guid] = [er].[ParentGuid]   
		UPDATE [t] SET [ParentGuid] = [er].[ParentGuid],[ParentNum] = [py].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [py].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbpy] AS [py] ON [py].[Guid] = [er].[ParentGuid]   
		UPDATE [t] SET [ParentGuid] = [er].[ParentGuid],[ParentNum] = [ch].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [ch].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbch] AS [ch] ON [ch].[Guid] = [er].[ParentGuid]   
		
		IF @CustOnly = 0   
		BEGIN  
			DECLARE @S NVARCHAR(MAX);
			SET @S = 'SELECT ' 
			SET @S = @S + '[ac].[Code] AS [AcCode],  
			[ac].[Name] AS [AcName],  
			[ac].[LatinName] AS [AcLatinName], 
			[cu].[cuCustomerName] AS [CuName],' 

			 
			SET @S = @S + '[tb].[DCType], [tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID] 
							 , [tb].[CostGuid], [tb].[customer] AS [CuGUID], ISNULL(co.Code,'''') coCode, ISNULL(co.Name,'''') coName, ISNULL(co.LatinName, '''') coLatinName ' 
			SET @DtlPeriodCounter = 0
			WHILE @DtlPeriodCounter < @NumOfPeriods  
			BEGIN   
				SET @S = @S + ', ISNULL([Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) +'], 0) AS [Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) +']'
				SET @DtlPeriodCounter = @DtlPeriodCounter + 1 
			END 
			SET @S = @S + 'FROM [#t_Result] AS [tb] '	
							
			SET @S = @S + 'INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [tb].[Account] ' 
			
			SET @S = @S + 'LEFT JOIN [co000] AS [co] ON [co].[Guid] = [tb].[CostGuid]' 

			SET @S = @S + 'LEFT JOIN [vwcu] [cu] on [cu].[cuGUID] = [tb].[Customer]'
			IF(ISNULL(@Customer, 0x0) <> 0x0)
				SET @S = @S +  'WHERE  [tb].[Customer] =  ''' + convert( char(100), @Customer)+''''
	
			SET @S = @S + 'ORDER BY [DCTYPE], ' 

			SET @S = @S + '[tb].[Account], ' 

			SET @S = @S + '[tb].[CostGuid],' 
				 
			SET @S = @S + '[tb].[Date], [tb].[enNumber] ' 
			
			EXEC (@S) 	
		END 
		ELSE 
		BEGIN 
			DECLARE @StrSql2 NVARCHAR(max)  
			SET @StrSql2 =  ' SELECT  ' 

			SET @StrSql2 = @StrSql2 + '[cu].[Guid] AS [cuGuid],' 	
			SET @StrSql2 = @StrSql2 + '[tb].DCType,	[tb].[Account], [tb].[Customer], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID] ' 
			SET @StrSql2 = @StrSql2 + ', [tb].[CostGuid], [cu].[CustomerName] AS [CuName]' 
			SET @DtlPeriodCounter = 0    
			WHILE @DtlPeriodCounter < @NumOfPeriods  
			BEGIN   
				SET @StrSql2 = @StrSql2 + ', ISNULL([Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) +'], 0) [Period' + CAST(@DtlPeriodCounter+1 AS [NVARCHAR](5)) +']'
				SET @PeriodStart = @DtlPeriodCounter * @PeriodLength   
				SET @PeriodEnd = @PeriodStart + @PeriodLength
				SET @DtlPeriodCounter = @DtlPeriodCounter + 1 
			END
				IF @DetCost > 0
					SET @StrSql2 = @StrSql2 + ', ISNULL(co.Code,'''') coCode, ISNULL(co.Name,'''') coName, ISNULL(co.LatinName,'''') coLatinName '   
				 
				SET @StrSql2 = @StrSql2 +  ' FROM   [#t_Result] AS [tb] ' 
				SET @StrSql2 = @StrSql2 +  'INNER JOIN [cu000] AS cu ON [cu].[AccountGuid] = [tb].[Account] '   
			
				IF @DetCost > 0
					SET @StrSql2 = @StrSql2 + ' LEFT JOIN [co000] co ON  co.Guid = [tb].[CostGuid] '
				SET @StrSql2 = @StrSql2 + 'WHERE [cu].[Guid] = [tb].[Customer] '
				IF(ISNULL(@Customer, 0x0) <> 0x0)
					SET @S = @S +  'AND  [tb].[Customer] =  ''' + convert( char(100), @Customer)+''''     
				 
				SET @StrSql2 = @StrSql2 + ' ORDER BY [DCTYPE],' 
			 
				SET @StrSql2 = @StrSql2 + ' [cu].[CustomerName],' 
				 
				SET @StrSql2 = @StrSql2 + ' [tb].[Date], [tb].[enNumber] '   
			 
				IF @DetCost > 0
					SET @StrSql2 = @StrSql2 + ', ISNULL(co.Code,'''')' 

			END 
			EXEC (@StrSql2)  
		END
################################################################################
#END
