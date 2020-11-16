#################################################################
CREATE PROC prcPDABilling_InitCust
		@PDAGUID uniqueidentifier  
AS       
	SET NOCOUNT ON       
	DECLARE @CustAccGUID 	uniqueidentifier,    
			@CostGUID 		uniqueidentifier,  
			@CustCondID 		INT,  
			@CustCondGuid	uniqueidentifier, 
			@CustSortFld		NVARCHAR(100), 
			@GLStartDate 		DateTime,   
			@GLEndDate 		DateTime   
	SELECT  
			@CustAccGUID 	= [CustAccGUID],  
			@CustCondID 	= [CustCondID], 
			@CustCondGuid	= [CustCondGuid],
			@CustSortFld 	= [CustSortFld], 
			@GLStartDate	= [GLStartDate],   
			@GlEndDate		= [GlEndDate],
			@CostGUID		= [CostGUID]   
	FROM  
		vwPl
	WHERE  
		[GUID] = @PDAGUID 

	------------------------------------------  
	CREATE TABLE [#CustCond]([GUID] [uniqueidentifier], [Security] [INT]) 
	INSERT INTO [#CustCond] EXEC [prcPalm_GetCustsList] @CustCondId, @CustCondGuid 
	------------------------------------------  
	CREATE TABLE #CustomerTbl(            
		[GUID] 			uniqueidentifier,  
		[Code] 			NVARCHAR(255) COLLATE Arabic_CI_AI,  
		[Name] 			NVARCHAR(255) COLLATE Arabic_CI_AI,  
		[Barcode] 		NVARCHAR(100) COLLATE Arabic_CI_AI,  
		[Balance] 		float,             
		[Area] 			NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[Street] 		NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[InRoute]		int,    
		[TargetFromDate]	datetime,    
		[TargetToDate]		datetime,    
		[Target]		float,    
		[Realized]		float,    
		[LastVisit]		datetime,    
		[MaxDebt]		float,    
		[CustomerTypeGUID]	uniqueidentifier,    
		[TradeChannelGUID]	uniqueidentifier,    
		[PersonalName]		NVARCHAR(250) COLLATE Arabic_CI_AI,    
		[Contract]		NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[Contracted]		int, 
		[RouteTime]		DATETIME, 
		[SortID]		INT DEFAULT (0),    
		[StoreGUID]		uniqueidentifier,  
		[Notes]			NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[AroundBalance]		float,   
		[AccGUID]		uniqueidentifier,  
		[LastBuDate]		DateTime,   
		[LastBuTotal]		FLOAT,   
		[LastBuFirstPay]		FLOAT,   
		[LastEnDate]		DateTime,   
		[LastEnTotal]		FLOAT,   
		[CustomerType]		NVARCHAR(250) COLLATE Arabic_CI_AI,  
		[TradeChannel]		NVARCHAR(250) COLLATE Arabic_CI_AI,
		[DefPrice]			INT,
		[Phone]				NVARCHAR(30) COLLATE Arabic_CI_AI, 
		[Mobile]			NVARCHAR(30) COLLATE Arabic_CI_AI
	)   
	------------------------------------------ 

	INSERT INTO #CustomerTbl    
		(    
			[GUID],  
			[Code],  
			[Name],  
			[Barcode],  
			[Balance],  
			[Area],  
			[Street],  
			[InRoute],  
			[TargetFromDate],  
			[TargetToDate],  
			[Target],  
			[Realized],  
			[LastVisit],  
			[MaxDebt],  
			[CustomerTypeGUID],  
			[TradeChannelGUID],  
			[PersonalName],  
			[Contract],  
			[Contracted], 
			[RouteTime], 
			[SortID], 
			[StoreGuid], 
			[Notes],  
			[AroundBalance],  
			[AccGUID], 
			[LastBuDate],   
			[LastBuTotal],   
			[LastBuFirstPay],   
			[LastEnDate],   
			[LastEnTotal],   
			[CustomerType],  
			[TradeChannel],
			[DefPrice],
			[Phone], 
			[Mobile]
		)    
		SELECT            
			[cu].[cuGUID],      
			[ac].[acCode], 
			[cu].[cuCustomerName],  
			[cu].[cuBarcode],  
			[ac].[acDebit] - [ac].[acCredit] AS Balance,         
			[cu].[cuArea],    
			[cu].[cuStreet],    
			0,    
			'1-1-2000',    
			'1-1-2000',    
			0,    
			0,    
			'1-1-2000',    
			[ac].[acMaxDebit],  
			CAST(0x00 AS UNIQUEIDENTIFIER) AS CustomerTypeGUID, 
			CAST(0x00 AS UNIQUEIDENTIFIER) AS TradeChannelGUID, 
			'',    
			'' AS Contract,   
			0 AS Contracted, 
			'1-1-1980' AS RouteTime, 
			0 AS SortID, 
			CAST(0x00 AS UNIQUEIDENTIFIER) AS StoreGUID,
			[cu].[cuNotes], 
			0	AS AroundBalance, 
			[ac].[acGUID], 
			'1-1-1980'	AS LastBuDate, 
			0			AS LastBuTotal, 
			0			AS LastBuFirstPay,  
			'1-1-1980'	AS LastEnDate, 
			0			AS LastEnTotal, 
			''			AS CustomerType, 
			''			AS TradeChannel,
			cuDefPrice,	
			CAST([cu].[cuPhone1] AS NVARCHAR(30)),
			CAST([cu].[cuMobile] AS NVARCHAR(30))
		FROM    
			[vwCu] AS [cu] 
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [cu].[cuAccount] 
			INNER JOIN [dbo].[fnGetCustsOfAcc](@CustAccGUID) AS [fn] ON [cu].[cuGUID] = [fn].[GUID]         
			INNER JOIN [#CustCond] 	AS [cn] ON [cn].[GUID] = [cu].[cuGUID]  
	------------------------------------------  
	-- „” Êœ⁄«  «·“»«∆‰ 
	UPDATE #CustomerTbl  
		SET 	[StoreGUID] = [st].[stGUID] 
	FROM  
		#CustomerTbl AS [cu]  
		INNER JOIN vwSt AS [st] ON [st].[stAccount] = [cu].[AccGuid] 
	WHERE  
		ISNULL(StoreGUID, 0x0) = 0x0 
	-----------------------------------  
	-- Õ”«» ¬Œ— “Ì«—…	 
	DECLARE @c_Lasts	CURSOR, 
		@CustGuid	UNIQUEIDENTIFIER, 
		@AccGuid	UNIQUEIDENTIFIER, 
		@LastViDate	[datetime],  
		@LastBuDate	[datetime],  
		@LastBuTotal	[FLOAT], 
		@LastBuFirstPay	[FLOAT], 
		@LastEnDate	[datetime],  
		@LastEnTotal	[FLOAT] 
	SET @c_Lasts = CURSOR FAST_FORWARD FOR SELECT [GUID], [AccGUID] FROM [#CustomerTbl]  
	OPEN @c_Lasts FETCH NEXT FROM @c_Lasts INTO @CustGUID, @AccGUID 
	WHILE @@FETCH_STATUS = 0           
	BEGIN    
		SET @LastViDate = '01-01-1980' 
		SET @LastBuDate = '01-01-1980' 
		SET @LastEnDate = '01-01-1980' 
		SET @LastBuTotal = 0 
		SET @LastBuFirstPay = 0 
		SET @LastEnTotal = 0 
		SELECT TOP 1 @LastBuDate = Date, @LastBuTotal = Total + TotalExtra - TotalDisc - ItemsDisc, @LastBuFirstPay = FirstPay -- ¬Œ— ›« Ê—… 
		FROM bu000 Where CustGuid = @CustGUID AND CostGUID = @CostGUID 
		ORDER By Date DESC  
		Select TOP 1 @LastEnDate = en.Date, @LastEnTotal = (en.Debit - en.Credit)-- ¬Œ— œ›⁄… 
		FROM  
			vwPyCe AS ce  
			INNER JOIN en000 AS en On en.ParentGUID = ce.ceGUID AND en.AccountGUID = @AccGUID  -- AND en.Debit <> 0 
		WHERE 
			en.CostGUID = @CostGUID 
		ORDER BY CeDate DESC 
		 
		SELECT @LastViDate = ISNULL(Max([StartTime]), '1-1-2000')  -- ¬Œ— “Ì«—… 
		FROM DistVi000 WHERE CustomerGuid = @CustGUID 
		UPDATE #CustomerTbl  
		SET 	LastVisit 	= @LastViDate, 
				LastBuDate 	= @LastBuDate, 
				LastBuTotal 	= @LastBuTotal, 
				LastBuFirstPay 	= @LastBuFirstPay, 
				LastEnDate 	= @LastEnDate, 
				LastEnTotal 	= @LastEnTotal 
		WHERE  
			Guid = @CustGUID 
		 
		FETCH NEXT FROM @c_Lasts INTO @CustGUID, @AccGUID 
	END 
	CLOSE @c_Lasts DEALLOCATE @c_Lasts 
	------------------------------------------  
	DELETE [DistDeviceCU000] WHERE [DistributorGUID] = @PDAGUID  
	------------------------------------------  
	--- CREATE INDEX [Devicecu000ndx11] ON [dbo].[DistDeviceCu000]([GUID]) ON [PRIMARY] 
	INSERT INTO DistDeviceCU000  
		(    
			[cuGUID],  
			[DistributorGUID],  
			[Name],  
			[Barcode],  
			[Balance],  
			[Area],  
			[Street],  
			[InRoute],  
			[OrderInRoute],  
			[TargetFromDate],  
			[TargetToDate],  
			[Target],  
			[Realized],  
			[LastVisit],  
			[MaxDebt],  
			[CustomerTypeGUID],  
			[TradeChannelGUID],  
			[PersonalName],  
			[ContractNum],  
			[Contracted], 
			[RouteTime], 
			[SortID], 
			[StoreGUID],  
			[Notes], 
			[AroundBalance], 
			[LastBuDate], 
			[LastBuTotal], 
			[LastBuFirstPay],  
			[LastEnDate], 
			[LastEnTotal], 
			[CustomerType], 
			[TradeChannel],
			[DefPrice], 
			[Phone],
			[Mobile]
		)	    
		SELECT            
			[cu].[GUID],   
			CAST (@PDAGUID AS NVARCHAR(100)),  
			[cu].[Name],  
			ISNULL([cu].[Barcode], ''),  
			[cu].[Balance],  
			[cu].[Area],  
			[cu].[Street],  
			[cu].[InRoute],  
			0, -- ISNULL([ce].[OrderInRoute], 0),  
			ISNULL([cu].[TargetFromDate], '1-1-2000'),  
			ISNULL([cu].[TargetToDate], '1-1-2000'),  
			[cu].[Target],  
			[cu].[Realized],  
			[cu].[LastVisit],  
			ISNULL([cu].[MaxDebt], 0),  
			[cu].[CustomerTypeGUID],   
			[cu].[TradeChannelGUID],  
			'',  
			[cu].[Contract],  
			[cu].[Contracted], 
			CAST(CAST(DatePart(Hour,RouteTime) AS [NVARCHAR](2)) + ':' + CAST(DatePart(Minute, RouteTime) AS [NVARCHAR](2)) AS [NVARCHAR](6)) AS RouteTime, 
			[cu].[SortID], 
			ISNULL([cu].[StoreGUID], 0x00), 
			[cu].[Notes], 
			[cu].[AroundBalance], 
			[LastBuDate], 
			[LastBuTotal], 
			[LastBuFirstPay],  
			[LastEnDate], 
			[LastEnTotal], 
			[CustomerType], 
			[TradeChannel],
			[DefPrice],
			[Phone],
			[Mobile] 
		From            
			#CustomerTbl AS cu  
---------------------------    ’œÌ— ﬂ‘› Õ”«» «·“»Ê‰   
	IF 1 = 1 	 
	BEGIN 
		CREATE TABLE [#CustStatement](            
				[CustGUID] 		[uniqueidentifier],   
				[LineType] 		[INT],   
				[Debit] 		[Float],             
				[Credit] 		[Float],             
				[EntryDate] 		[DateTime],   
				[Note] 			[NVARCHAR](255) COLLATE ARABIC_CI_AI 
			 )                 
		CREATE TABLE [#CustEntrySum](            
				[CustGUID] 		[uniqueidentifier],   
				[SumDebit] 		[Float],             
				[SumCredit]	 	[Float],             
				[PrevBalance] 		[Float]           
			 )                 
		DECLARE	@PREVBALANCESTR		[NVARCHAR](100)           
		-- DECLARE	@BALANCESTR		[NVARCHAR](100)           
		DECLARE	@SUMSTR			[NVARCHAR](100)           
		DECLARE	@BALANCETOTALSTR	[NVARCHAR](100)          
		SET	@PREVBALANCESTR = '«·—’Ìœ «·”«»ﬁ'   -- 0 
		-- SET	@BALANCESTR 	= '—’”œ «·Õ—ﬂ…'      -- 101 
		SET	@SUMSTR 	= '«·„Ã„Ê⁄'           -- 102 
		SET	@BALANCETOTALSTR = '„Ã„Ê⁄ «·—’Ìœ'     -- 104     
		-------------------------------   
		INSERT INTO            
			[#CustStatement]   
		SELECt            
			[cu].[GUID],   
			100,           
			[enDebit],   
			[enCredit],   
			[enDate],   
			[enNotes]   
		FROM 
			-- [vwEN] AS [en]           
			[vwCeEn] AS [en]  
			INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[AccGUID] = [en].[enAccount] 
		WHERE           
			[enDate] Between @GLStartDate AND @GLEndDate   
			AND  [en].[ceIsPosted] <> 0  
			AND ([en].[enCostPoint] = @CostGUID) 
		---------------------------------------------------------           
		INSERT INTO            
			[#CustEntrySum]           
		SELECt            
			[cu].[GUID],           
			Sum([en].[enDebit]) AS [SumDebit],           
			Sum([en].[enCredit]) AS [SumCredit],           
			0 AS PrevBalance           
		FROm           
			[vwCeEn] AS [en]  
			-- [vwEN] AS [en]           
			INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[AccGUID] = [en].[enAccount]  
		WHERE           
			[enDate] Between @GLStartDate AND @GLEndDate   
			AND  [en].[ceIsPosted] <> 0  
			AND ([en].[enCostPoint] = @CostGUID) 
		GROUP BY [cu].[GUID] 
		---------------------------------------------------------           
		UPDATE   
			[#CustEntrySum]   
		SET   
			[PrevBalance] =  ISNULL([b].[Balaance], 0)           
		FROM           
		(           
			SELECT           
				SUM([en].[enDebit] - [en].[enCredit]) AS [Balaance],   
				[cu].[Guid] AS [CuGUID]   
			FROM  
				-- [vwEN] AS [en]           
				[vwCeEn] AS [en]  
				INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[AccGUID] = [en].[enAccount] 
			WHERE           
				[enDate] < @GLStartDate   
				AND  [en].[ceIsPosted] <> 0  
				AND ([en].[enCostPoint] = @CostGUID) 
			GROUP BY   
				[cu].[GUID]   
		) AS [b]           
		WHERE   
			[CustGUID] = [b].[CuGUID]   
		--------------------------------------------------------           
		DECLARE 	@c_en CURSOR   
		DECLARE                 
				@SumDebit 	[Float],             
				@SumCredit 	[Float],             
				@PrevBalance 	[Float]           
		SET @c_en = CURSOR FAST_FORWARD           
		FOR           
			SELECT [CustGUID], [SumDebit], [SumCredit], [PrevBalance] FROM [#CustEntrySum] ORDER BY [CustGUID]           
		OPEN @c_en           
		FETCH NEXT FROM @c_en INTO @CustGUID, @SumDebit, @SumCredit, @PrevBalance           
		WHILE @@FETCH_STATUS = 0           
		BEGIN                
				---------- Insert BrevBalance     
				IF @PrevBalance >= 0      
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 1, @PrevBalance, 0, @GLStartDate, @PREVBALANCESTR )			           
				ELSE 
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 1, 0, @PrevBalance * -1, @GLStartDate, @PREVBALANCESTR )			           
				---------- Insert SumDebit AND SumCredit           
				IF @PrevBalance >= 0 
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 102, @SumDebit + @PrevBalance, @SumCredit, @GLEndDate, @SUMSTR)           
				ELSE 
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 102, @SumDebit, @SumCredit + @PrevBalance, @GLEndDate, @SUMSTR)           
				---------- Insert Balance          
				IF (@PrevBalance + @SumDebit - @SumCredit >= 0) 
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 104, @PrevBalance + @SumDebit - @SumCredit, 0, @GLEndDate, @BALANCETOTALSTR  )			          
				ELSE 
					INSERT INTO [#CustStatement] VALUES (@CustGUID, 104, 0, (@PrevBalance + @SumDebit - @SumCredit) * -1, @GLEndDate, @BALANCETOTALSTR  )			          
			           
			FETCH NEXT FROM @c_en INTO @CustGUID, @SumDebit, @SumCredit, @PrevBalance           
		END            
		CLOSE @c_en
		DEALLOCATE @c_en 
		DELETE FROM [DistDeviceStatement000] WHERE [DistributorGUID] = @PDAGUID 
		INSERT INTO [DistDeviceStatement000]  
			( 
				[GUID], 
				[DistributorGUID], 
				[CustGUID], 
				[Debit], 
				[Credit], 
				[Date], 
				[Notes], 
				[LineType]		 
			) 
		SELECT            
				newID(), 
				@PDAGUID, 
				[st].[CustGUID], 
				[Debit],           
				[Credit],           
				[EntryDate],           
				[Note], 
				[LineType]           
		FROM            
			[#CustStatement] AS [st]           
			INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[Guid] = [st].[CustGUID]   
		ORDER By            
			[st].[CustGUID], 
			[st].[LineType],            
			[st].[EntryDate]           
		DROP TABLE [#CustStatement] 
		DROP TABLE [#CustEntrySum] 
	END 
	DROP TABLE #CustomerTbl

/*
Exec prcDistInitCustStockOfDistributor 'BE916CF7-47BA-4A1A-80F2-1294F211CC5E'
Select * From DistCm000
*/

#################################################################
#END