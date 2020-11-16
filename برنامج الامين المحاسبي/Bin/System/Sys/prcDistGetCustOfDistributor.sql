########################################
## prcDistGetCustOfDistributor
CREATE PROCEDURE prcDistGetCustOfDistributor
		@PalmUserName NVARCHAR(250),
		@ExportStatement	INT = 0   -- 0 Don't Export Statement    1 Export Statemnet  
AS     
	SET NOCOUNT ON     
	     
	DECLARE @DistributorGUID 	Uniqueidentifier,  
			@CustomersAccGUID 	Uniqueidentifier, 
			@CostGUID 			Uniqueidentifier, 
			@SalesManGUID 		Uniqueidentifier, 
			@CustBalanceByJobCost	BIT, 
			@UseCustTarget		BIT, 
			@Route	 			INT,   
			@CustCondID 		INT, 
			@CustCondGuid		Uniqueidentifier, 
			@CustSortFld 		NVARCHAR(100), 
			@GLStartDate 		DateTime, 
			@GLEndDate 			DateTime 
	SELECT  
		@DistributorGUID 	= [GUID] ,  
		@SalesManGUID 		= [PrimSalesManGUID], 
		@CustomersAccGUID 	= [CustomersAccGUID],  
		@CustBalanceByJobCost 	= [CustBalanceByJobCost], 
		@CustCondID 		= [CustCondID], 
		@CustCondGuid		= [CustCondGuid],
		@CustSortFld 		= [CustSortFld], 
		@UseCustTarget 		= [UseCustTarget], 
		@GLStartDate		= [GLStartDate], 
		@GlEndDate			= [GlEndDate] 
	FROM  
		vwDistributor 
	WHERE  
		PalmUserName = @PalmUserName 

	SELECT @CostGUID = [CostGUID] FROM [vwDistSalesMan] WHERE [GUID] = @SalesManGUID 
	
	CREATE TABLE [#CustCond]([GUID] [uniqueidentifier], [Security] [INT])   
	INSERT INTO [#CustCond] EXEC [prcPalm_GetCustsList] @CustCondId , @CustCondGuid  

	SET @Route = dbo.fnDistGetRouteNumOfDate(GetDate())
	
	CREATE TABLE #CountryTbl 
		(           
			[ID] 	int identity(1,1),            
			[Name] 	NVARCHAR(255)  COLLATE Arabic_CI_AI           
		)                   
	CREATE TABLE #StreetTbl 
		(           
			[ID] int 	identity(1,1),            
			CountryID 	int,        
			[Name] 		NVARCHAR(255)  COLLATE Arabic_CI_AI,            
			CountryName 	NVARCHAR(255)  COLLATE Arabic_CI_AI           
		)                   
	CREATE TABLE #CustomerTbl 
		(           
			[ID] 			uniqueidentifier,     
			StreetID 		int ,            
			[Name] 			NVARCHAR(255)  COLLATE Arabic_CI_AI,            
			LatinName 		NVARCHAR(255)  COLLATE Arabic_CI_AI,            
			Balance 		float,            
			CountryName 		NVARCHAR(255)  COLLATE Arabic_CI_AI,           
			StreetName 		NVARCHAR(255)  COLLATE Arabic_CI_AI,           
			cuAccount 		uniqueidentifier,   
			InRoute			int,   
			TargetFromDate		datetime,   
			TargetToDate		datetime,   
			Target			float,   
			Realized		float,   
			Remnant			float,   
			LastVisit		datetime,   
			MaxDebit		float,   
			CustomerTypeGUID	uniqueidentifier,   
			TradeChannelGUID	uniqueidentifier,   
			PersonalName		NVARCHAR(250)  COLLATE Arabic_CI_AI,   
			Contract		NVARCHAR(250)  COLLATE Arabic_CI_AI, 
			Contracted		int, 
			AroundBalance		float 
		)  
	CREATE TABLE #CustomerRouteTbl ( GUID 	UNIQUEIDENTIFIER, RouteTime DateTime )  
	CREATE TABLE #CustomerCodeTbl 
	(    
		CustIndex 	INT,     
		CustCode 	NVARCHAR(255) COLLATE Arabic_CI_AI    
	)    
	 
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PalmCustTbl]') and OBJECTPROPERTY(id, N'IsUserTable') = 1) 
		DROP TABLE PalmCustTbl 
	CREATE TABLE PalmCustTbl 
	(    
		ID 			int,    
		StreetID 		int,    
		Name 			NVARCHAR(255) COLLATE Arabic_CI_AI,    
		LatinName 		NVARCHAR(255) COLLATE Arabic_CI_AI,    
		Balance 		NVARCHAR(255) COLLATE Arabic_CI_AI,    
		InRoute			int,   
		TargetFromDate		datetime,   
		TargetToDate		datetime,   
		Target			float,   
		Realized		float,   
		Remnant			float,   
		LastVisit		datetime,   
		MaxDebit		float,   
		CustomerType		int,   
		TradeChannel		int,   
		PersonalName		NVARCHAR(250)  COLLATE Arabic_CI_AI,   
		Contract		NVARCHAR(250)  COLLATE Arabic_CI_AI, 
		Contracted		int,   
		[Index] 		int IDENTITY(0, 1)    
	)    

	-----------------------------------  
	SET @CustomersAccGUID = ISNULL(@CustomersAccGUID, 0x00) 
	if (@CustomersAccGUID = 0x0) 
		INSERT INTO #CustomerTbl   
			(   
				[ID],   
				StreetID,   
				[Name],   
				LatinName,   
				Balance,   
				CountryName,   
				StreetName,   
				cuAccount,   
				InRoute,   
				TargetFromDate,   
				TargetToDate,   
				Target,   
				Realized,   
				Remnant,   
				LastVisit,   
				MaxDebit,   
				CustomerTypeGUID,   
				TradeChannelGUID,   
				PersonalName,   
				Contract,   
				Contracted, 
				AroundBalance 
			)   
			SELECT           
				cu.cuGUID,					-- cuac.cuGUID,     
				0,   
				cu.cuCustomerName,			-- cuac.cuCustomerName,   
				cu.cuLatinName,				-- ac.acLatinName,   
				ac.acDebit - ac.acCredit,   -- cuac.acDebit - cuac.acCredit,   
				cu.cuArea,   
				cu.cuStreet,   
				cu.cuAccount,   
				0,   
				'1-1-2000',   
				'1-1-2000',   
				0,   
				0,   
				0,   
				'1-1-2000',   
				ac.acMaxDebit,   
				ce.CustomerTypeGUID,   
				ce.TradeChannelGUID,   
				cu.cuPager,	-- '',   
				ce.Contract,   
				ce.Contracted, 
				0 
			FROM   
				DistCe000 AS ce   
				INNER JOIN DistDistributionLines000	AS [Dl]   ON Dl.CustGuid = Ce.CustomerGuid 
				-- INNER JOIN vwCuAc 		 	AS [cuac] On cuac.cuGUID = ce.CustomerGUID   
				INNER JOIN vwCu 		 	AS [cu]	ON cu.cuGUID = ce.CustomerGUID   
				INNER JOIN vwAc 		 	AS [ac] ON ac.acGUID = cu.cuAccount   
				INNER JOIN [#CustCond] 		AS [cn] ON [cn].[GUID] = [cu].[cuGUID] 
			WHERE   
				Dl.DistGUID = @DistributorGUID   
	else 
		INSERT INTO #CustomerTbl    
			(    
				[ID],    
				StreetID,    
				[Name],    
				LatinName,    
				Balance,    
				CountryName,    
				StreetName,    
				cuAccount,    
				InRoute,    
				TargetFromDate,    
				TargetToDate,    
				Target,    
				Realized,    
				Remnant,    
				LastVisit,    
				MaxDebit,    
				CustomerTypeGUID, 
				TradeChannelGUID,    
				PersonalName, 
				Contract, 
				Contracted, 
				AroundBalance 
			)    
			SELECT            
				cu.cuGUID,      
				0,    
				cu.cuCustomerName,    
				cu.cuLatinName,    
				ac.acDebit - ac.acCredit,    
				cu.cuArea,    
				cu.cuStreet,    
				cu.cuAccount,    
				0,    
				'1-1-2000',    
				'1-1-2000',    
				0,    
				0,    
				0,    
				'1-1-2000',    
				ac.acMaxDebit, 
				0x00, 
				0x00, 
				cu.cuPager, -- '',   
				'', 
				0, 
				0 
			FROM    
				(SELECT GUID FROM fnGetAccountsList(@CustomersAccGUID, 0) GROUP BY GUID) AS ce 
				-- INNER JOIN vwCuAc 		 	AS [cuac] On cuac.cuGUID = ce.GUID   
				INNER JOIN vwAc AS ac On ac.acGUID = ce.GUID 
				INNER JOIN vwCu AS [cu]	ON cu.cuAccount = ac.acGUID   
				INNER JOIN [#CustCond] AS [cn] ON [cn].[GUID] = [cu].[cuGUID] 

			UPDATE #CustomerTbl 
			SET 
				CustomerTypeGUID	= ce.CustomerTypeGUID, 
				TradeChannelGUID	= ce.TradeChannelGUID, 
				-- PersonalName		= '', 
				Contract		= ce.Contract, 
				Contracted		= ce.Contracted 
			FROM 
				#CustomerTbl AS cu 
				INNER JOIN DistCe000 AS ce ON ce.CustomerGUID = cu.ID 
			----------------------------------- 
			-- Calc Around Discount Balance
			CREATE TABLE #AroundBal (CustGUID uniqueidentifier, Balance float)  
			INSERT INTO #AroundBal  
			SELECT   
				pcu.ID, 
				Sum(di.diDiscount) - Sum(di.diExtra)  
			FROM  
				vwBu AS bu 
				INNER JOIN vwDi AS di ON di.diParent = bu.buGUID				 
				INNER JOIN (SELECT AccountGUID FROM DistDisc000 WHERE CalcType = 5) AS dis ON dis.AccountGUID = di.diAccount 
				INNER JOIN #CustomerTbl AS pcu ON pcu.ID = bu.buCustPTr 
			Group By 
				pcu.ID 
			UPDATE #CustomerTbl SET AroundBalance = a.Balance  
			FROM #AroundBal AS a, #CustomerTbl AS cu WHERE cu.ID = a.CustGUID  
			----------------------------------- 
			-- Calc Customer Balance
			-- @CustBalanceByJobCost = 1  «·√—’œ… ⁄·Ï „—ﬂ“ «·ﬂ·›…
			CREATE TABLE #CustBalance( [GUID] [uniqueidentifier], [Balance] [float]) 
			INSERT INTO #CustBalance 
				SELECT [cu].[ID] , Sum([en].[enDebit] - [en].[enCredit]) AS [Balance]  
				FROM  
					[vwCeEn] AS [en] 
					INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[cuAccount] = [enAccount]
				Where  
					[en].[ceIsPosted] <> 0 AND ([en].[enCostPoint] = @CostGUID OR @CustBalanceByJobCost = 0)
				GROUP BY 
					[cu].[ID] 
-- Select * From #CustBalance
			UPDATE #CustomerTbl SET [Balance] = ISNULL([cb].[Balance], 0) 
			FROM [#CustomerTbl] AS [cu] LEFT JOIN #CustBalance AS [cb] ON [cb].[GUID] = [cu].[ID] 

	----------------------------------- 
	-----------------------------------  
	INSERT INTO #CustomerRouteTbl EXEC prcDistGetRouteOfDistributor @DistributorGUID, @Route  
	UPDATE #CustomerTbl SET InRoute = 1 WHERE ID IN (SELECT GUID FROM #CustomerRouteTbl) 
	----------------------------------- 
	CREATE TABLE #CustLastVisit(GUID uniqueidentifier, LastVisit datetime) 
	INSERT INTO #CustLastVisit 
	SELECT 
		cu.ID, 
		-- ISNULL (Max(t.Date), '1-1-2000') 
		ISNULL (Max(v.StartTime), '1-1-2000') 
	FROM 
		DistVi000 AS v 
		-- INNER JOIN DistTr000 AS t ON t.GUID = v.TripGUID 
		INNER JOIN #CustomerTbl AS cu ON cu.ID = v.CustomerGUID 
	GROUP BY 
		cu.ID 
	 
	UPDATE #CustomerTbl SET LastVisit = lv.LastVisit 
	FROM 
		#CustomerTbl AS cu, #CustLastVisit AS lv 
	WHERE 
		lv.GUID = cu.ID 
	----------------------------------- 
	declare @CurMonthlyPeriod 	uniqueidentifier 
	declare @CurQuarterPeriod 	uniqueidentifier 
	declare @StartDate		datetime 
	declare @EndDate		datetime 
	declare @MonthStartDate 	DATETIME 
	declare @MonthEndDate 		DATETIME 
	SET @CurMonthlyPeriod = 0x0 
	SET @CurQuarterPeriod = 0x0 
	SELECT @CurMonthlyPeriod = ISNULL(CAST(Value AS uniqueidentifier), 0x0) FROM Op000 WHERE Name = 'DistCfg_Coverage_CurMonthlyPeriod' 
	SELECT @CurQuarterPeriod = ISNULL(CAST(Value AS uniqueidentifier), 0x0) FROM Op000 WHERE Name = 'DistCfg_Coverage_CurQuarterPeriod' 
	SELECT @StartDate = StartDate, @EndDate = EndDate FROM BDP000 WHERE GUID = @CurQuarterPeriod 
	SELECT @MonthStartDate = StartDate, @MonthEndDate = EndDate FROM BDP000 WHERE GUID = @CurMonthlyPeriod 
	 
	CREATE TABLE #Period ( GUID 	UNIQUEIDENTIFIER, StartDate DATETIME, EndDate DATETIME) 
	INSERT INTO #Period SELECT GUID, StartDate, EndDate FROM BDP000 WHERE ParentGUID = @CurQuarterPeriod 
------------------------------------------------------------------------------------------------------------ 
	CREATE TABLE #MatTemplates 
		( 
			Guid	UNIQUEIDENTIFIER, 
			Number	INT, 
			Name	NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			GroupGuid	UNIQUEIDENTIFIER 
		) 
	INSERT INTO #MatTemplates 
		SELECT DISTINCT 
			t.Guid, t.Number, t.Name, t.GroupGuid 
		FROM DistMatTemplates000 AS t 
			INNER JOIN DistDd000 AS Dd ON Dd.ObjectGuid = t.Guid  
		WHERE 	Dd.DistributorGuid  = @DistributorGUID	AND 
			Dd.ObjectType = 3 
		ORDER BY t.Number 
	CREATE TABLE #TemplatesDetail 
		( 
			TemplateGuid	UNIQUEIDENTIFIER, 
			GroupGuid	UNIQUEIDENTIFIER 
		) 
	DECLARE @CTemplates	CURSOR, 
		@TGuid	UNIQUEIDENTIFIER, 
		@GGuid	UNIQUEIDENTIFIER 
	SET @CTemplates = CURSOR FAST_FORWARD FOR 
		SELECT Guid, GroupGuid FROM #MatTemplates ORDER BY Number 
	OPEN @CTemplates FETCH FROM @CTemplates INTO @TGuid, @GGuid 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		INSERT INTO #TemplatesDetail 
			 SELECT @TGuid, Guid FROM fnGetGroupsList( @GGuid)  
		FETCH FROM @CTemplates INTO @TGuid, @GGuid 
	END 
	CLOSE @CTemplates DEALLOCATE @CTemplates 
--------------   Get Templates Target And Achived Values 
	CREATE TABLE #CustTemplates 
		( 
			CustGuid	UNIQUEIDENTIFIER, 
			MatTemplateNumber	INT,	 
			MatTemplateGuid	UNIQUEIDENTIFIER, 
			MatTemplateName	NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		) 
	CREATE TABLE #ClassTargets 
		( 
			Guid				UNIQUEIDENTIFIER, 
			PeriodGuid			UNIQUEIDENTIFIER, 
			CustClassGuid		UNIQUEIDENTIFIER, 
			CustClassName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			CustClassNumber		INT,	 
			MatTemplateGuid		UNIQUEIDENTIFIER, 
			MatTemplateName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			MatTemplateNumber	INT, 
			CurGuid				UNIQUEIDENTIFIER,	 
			CurVal				FLOAT, 
			TargetVal			FLOAT, 
			Flag				INT, 
			PeriodName			NVARCHAR(100) COLLATE ARABIC_CI_AI, 
			BranchGUID			UNIQUEIDENTIFIER,
			BranchName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
			BranchNumber		INT
		) 
	 
	CREATE TABLE #Bills 
		( 
			CustGuid	UNIQUEIDENTIFIER, 
			MatTemplateGuid	UNIQUEIDENTIFIER, 
			Totals		FLOAT, 
			Flag		INT 
		) 
	CREATE TABLE #CustClassTarget 
		( 
			PeriodGuid		UNIQUEIDENTIFIER, 
			CustGuid		UNIQUEIDENTIFIER, 
			CustName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			MatTemplateGuid		UNIQUEIDENTIFIER, 
			MatTemplateName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			MatTemplateNumber	INT, 
			CustClassGuid		UNIQUEIDENTIFIER, 
			CustClassName		NVARCHAR(255) COLLATE ARABIC_CI_AI, 
			TargetVal		FLOAT, 
			AchievedVal		FLOAT 
		) 
	CREATE TABLE #CustTarget 
		( 
			GUID 		UNIQUEIDENTIFIER,  
			Target 		FLOAT,  
			Realized 	FLOAT, 
			StartDate	DATETIME, 
			EndDate		DATETIME 
		)	 
	IF (@UseCustTarget = 1)     ----- Option From Distributor000 :   
	BEGIN 

		DECLARE	@CurGuid	UNIQUEIDENTIFIER, 
			@CurVal		FLOAT 
	 
		SELECT @CurVal = ISNULL(CurrencyVal, 1), @CurGuid = ISNULL(Guid, 0x00) FROM my000 WHERE Number = 1 
		INSERT INTO #CustTemplates 
		    	SELECT Cu.ID, t.Number, t.Guid, t.Name 
		 	FROM #CustomerTbl AS Cu CROSS JOIN #MatTemplates AS t	 
			ORDER By Cu.ID, t.Number 
		-- Get Target For Each Class  
		INSERT INTO #ClassTargets  
		Exec prcDistGetCustClassesTarget @CurMonthlyPeriod, 1, 1, 1  
		-- Get Achieved Value From Bills 
		 INSERT INTO #Bills 
			SELECT  
				Cu.Id, 
				Fn.TemplateGuid,  
				CASE bt.btIsOutput 	WHEN 1 THEN  (FixedBiTotal)  
							       ELSE -(FixedBiTotal)  
				END, 
				0 		 
			FROM  
				#CustomerTbl	AS Cu 
				INNER JOIN dbo.fnExtended_bi_Fixed( @CurGuid) 	AS bu ON bu.buCustPtr = Cu.ID 
				INNER JOIN vwBt 				AS bt ON bt.btGUID = bu.buType  
				INNER JOIN fnDistGetMatTemplates(0x00) 		AS fn ON Fn.MatGuid = bu.biMatPtr 
				INNER JOIN #MatTemplates 			AS mt ON mt.Guid = Fn.TemplateGuid 
			WHERE  
				bt.btType = 1	AND		 
				bu.buDate BETWEEN @MonthStartDate AND @MonthEndDate	 
		INSERT INTO #Bills 
			SELECT 
				CustGuid, MatTemplateGuid, SUM(Totals), 1 
			FROM #Bills  
			GROUP BY CustGuid, MatTemplateGuid 
		DELETE FROM #Bills WHERE Flag = 0 
		-- Get Detail Targets And Acheiveds For Each Cust  
		INSERT INTO #CustClassTarget 
			SELECT  
				-- Ct.PeriodGuid, 
				ISNULL(Ct.PeriodGuid, @CurMonthlyPeriod), 
				c.cuGuid, 
				c.cuCustomerName, 
				Cu.MatTemplateGuid, 
				Cu.MatTemplateName, 
				Cu.MatTemplateNumber, 
				ISNULL(Ct.CustClassGuid, 0x00),  
				ISNULL(Ct.CustClassName, ''), 
				ISNULL(Ct.TargetVal, 0) / ISNULL(@CurVal, 1), 
				-- ISNULL(bi.Totals, 0) 
				CASE ISNULL(Ct.PeriodGuid, @CurMonthlyPeriod)  
					WHEN @CurMonthlyPeriod THEN ISNULL(bi.Totals, 0) 
					ELSE (	SELECT SUM(-1 * buDirection * FixedBiTotal)  
						FROM dbo.fnExtended_bi_Fixed( @CurGuid) AS bu 
							INNER JOIN vwBt 			AS bt ON bt.btGUID = bu.buType  
							INNER JOIN fnDistGetMatTemplates(0x00) 	AS fn ON Fn.MatGuid = bu.biMatPtr 
						WHERE	bu.buCustPtr = c.cuGuid AND bt.btType = 1 AND 
							Fn.TemplateGuid = Cu.MatTemplateGuid	  AND	 
							bu.buDate BETWEEN pd.StartDate AND pd.EndDate 
					      ) 
				END 
			FROM	 
				#CustTemplates		AS cu 
				INNER JOIN vwCu		AS c  ON c.cuGuid = cu.CustGuid 
				LEFT  JOIN DistCc000   	AS Cc ON Cc.CustGuid = cu.CustGuid AND Cc.MatTemplateGuid = cu.MatTemplateGuid 
				LEFT JOIN #ClassTargets AS Ct ON Cc.MatTemplateGuid = Ct.MatTemplateGuid AND Cc.CustClassGuid = Ct.CustClassGuid 
				LEFT  JOIN #Bills	AS bi ON bi.CustGuid = cu.CustGuid AND bi.MatTemplateGuid = cu.MatTemplateGuid 	 
				INNER JOIN #Period	AS pd ON pd.Guid = ISNULL(Ct.PeriodGuid, @CurMonthlyPeriod) 
		--- Get Total Targets And Acheiveds For Each Cust  
		INSERT INTO #CustTarget 
		SELECT 
			ct.CustGUID, 
			Sum(TargetVal), 
			SUM(AchievedVal), 
			MIN(pd.StartDate), 
			MAX(pd.EndDate) 
		FROM  
			#CustClassTarget AS ct 
			INNER JOIN #Period AS pd ON pd.GUID = ct.PeriodGUID 
			INNER JOIN #CustomerTbl AS cu ON cu.ID = ct.CustGUID 
		GROUP BY ct.CustGUID --, pd.StartDate, pd.EndDate 
	 
		UPDATE #CustomerTbl SET  
			Target = ct.Target, 
			Realized = Ct.Realized, 
			TargetFromDate = ct.StartDate, 	-- @MonthStartDate, 
			TargetToDate = 	ct.EndDate	-- @MonthEndDate 
		FROM 
			#CustomerTbl AS cu, #CustTarget AS ct 
		WHERE 
			ct.GUID = cu.Id 
	 
		UPDATE #CustomerTbl 
		SET 
			Remnant = Target - Realized 

	END 
------------------------------------------------------------------------------------------------------------	 
---------------------------------------------------------------------- 
	INSERT INTO #CountryTbl 
	SELECT DISTINCT CountryName From #CustomerTbl 
---------------------------------------------------------------------- 
	INSERT INTO #StreetTbl 
	SELECT  DISTINCT 
		0,           
		StreetName,           
		CountryName           
	From           
		#CustomerTbl             
-------------------------------------------   Dist Disc Distributior 
	CREATE TABLE #DistDisc 
		( 
			[Number] 	[float] , 
			[GUID]  	uniqueidentifier , 
			[Code] 		[NVARCHAR] (100) COLLATE Arabic_CI_AI , 
			[Name] 		[NVARCHAR] (250) COLLATE Arabic_CI_AI , 
			[LatinName] 	[NVARCHAR] (250) COLLATE Arabic_CI_AI , 
			[GivingType] 	[int] , 
			[CalcType] 	[int] , 
			[Percent] 	[float] , 
			[Value] 	[float] , 
			[CondValue] 	[float] , 
			[AccountGUID] 	[uniqueidentifier] , 
			[StartDate] 	[datetime] , 
			[EndDate] 	[datetime] , 
			[MatGuid] 	[uniqueidentifier] , 
			[OneTime] 	[int] , 
			[ChangeVal] 	[int], 
			[Security] 	[int] , 
			[CondValueTo] 	[float] , 
			[GroupGuid] 		[uniqueidentifier] , 
			[MatTemplateGuid] 	[uniqueidentifier] 
		) 
	INSERT INTO #DistDisc 
		SELECT DISTINCT d.Number, d.Guid, d.Code, d.[Name], d.LatinName, d.GivingType, d.CalcType, d.[Percent], d.Value, d.CondValue, d.AccountGuid, d.StartDate, d.EndDate, d.MatGuid, d.OneTime, d.ChangeVal, d.Security, d.CondValueTo, d.GroupGuid, d.MatTemplateGuid 
		FROM DistDisc000	AS d 
			INNER JOIN DistDiscDistributor000 AS r ON r.ParentGuid = d.Guid 
		WHERE 	 
			r.DistGuid = @DistributorGuid AND r.Value = 1 
       
----- Return Result -----     
	--------- 1     
	SELECT * FROM #CountryTbl     
	--------- 2     
	SELECT           
		St.ID,       
		Co.ID AS CountryID,       
		St.Name       
	FROM            
		#StreetTbl AS St                    
		INNER JOIN #CountryTbl AS Co ON Co.Name = St.CountryName                   
	--------- 3               
	INSERT INTO PalmGUID     
		SELECT DISTINCT     
			cu.ID     
		FROM     
			#CustomerTbl AS cu LEFT JOIN PalmGUID AS pg ON pg.GUID = cu.ID     
		WHERE     
			pg.GUID IS NULL     
	------------------  
	INSERT INTO PalmGUID     
		SELECT DISTINCT     
			ct.GUID     
		FROM     
			DistCt000 AS ct LEFT JOIN PalmGUID AS pg ON pg.GUID = ct.GUID     
		WHERE     
			pg.GUID IS NULL     
	------------------  
	INSERT INTO PalmGUID  
		SELECT DISTINCT  
			tt.GUID  
		FROM  
			DistTch000 AS tt LEFT JOIN PalmGUID AS pg ON pg.GUID = tt.GUID  
		WHERE  
			pg.GUID IS NULL  
	------------------  
	INSERT INTO PalmGUID  
	SELECT DISTINCT  
			d.GUID  
		FROM  
			#DistDisc AS d LEFT JOIN PalmGUID AS pg ON pg.GUID = d.GUID  
		WHERE  
			pg.GUID IS NULL  
	------------------  
	------------------ ------------------ ------------------  
	INSERT INTO PalmGUID  
		SELECT DISTINCT  
			t.GUID  
		FROM #MatTemplates AS t LEFT JOIN PalmGUID AS pg ON pg.GUID = t.GUID  
		WHERE  
			pg.GUID IS NULL  
		-- ORDER BY t.Number 
	------------------  
	INSERT INTO PalmGUID  
		SELECT DISTINCT  
			t.GroupGUID  
		FROM #TemplatesDetail AS t LEFT JOIN PalmGUID AS pg ON pg.GUID = t.GroupGuid  
		WHERE  
			pg.GUID IS NULL  
	------------------ ------------------ ------------------  
	If (@CustSortFld = 'Name') 
	Begin 
		INSERT INTO PalmCustTbl   
			(   
				ID,   
				StreetID,   
				Name,   
				LatinName,   
				Balance,   
				InRoute,   
				TargetFromDate,   
				TargetToDate,   
				Target,   
				Realized,   
				Remnant,   
				LastVisit,   
				MaxDebit,   
				CustomerType,   
				TradeChannel,   
				PersonalName,   
				Contract,   
				Contracted				 
			)	   
		SELECT           
			pg.Number AS ID,           
			St.ID AS StreetID,           
			Cu.Name AS Name,     
			Cu.LatinName AS LatinName,     
			Cu.Balance AS Balance,   
			InRoute,   
			TargetFromDate,   
			TargetToDate,   
			Target,   
			Realized,   
			Remnant,   
			LastVisit,   
			MaxDebit,   
			pg1.Number AS CustomerType,   
			pg2.Number AS TradeChannel,   
			PersonalName,   
			Contract,   
			Contracted   
		From           
			#CustomerTbl AS Cu                   
			INNER JOIN #StreetTbl AS St ON Cu.StreetName = St.Name AND Cu.CountryName = St.CountryName     
			INNER JOIN PalmGUID AS pg ON pg.GUID = Cu.ID     
			INNER JOIN PalmGUID AS pg1 ON pg1.GUID = Cu.CustomerTypeGUID  
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = Cu.TradeChannelGUID  
			ORDER By StreetID, Name 
	 
	End 
	Else 
	Begin 
		INSERT INTO PalmCustTbl   
			(   
				ID,   
				StreetID,   
				Name,   
				LatinName,   
				Balance,   
				InRoute,   
				TargetFromDate,   
				TargetToDate,   
				Target,   
				Realized,   
				Remnant,   
				LastVisit,   
				MaxDebit,   
				CustomerType,   
				TradeChannel,   
				PersonalName,   
				Contract,   
				Contracted   
			)	   
		SELECT           
			pg.Number AS ID,           
			St.ID AS StreetID,           
			Cu.Name AS Name,     
			Cu.LatinName AS LatinName,     
			Cu.Balance AS Balance,   
			InRoute,   
			TargetFromDate,   
			TargetToDate,   
			Target,   
			Realized,   
			Remnant,   
			LastVisit,   
			cu.MaxDebit,   
			pg1.Number AS CustomerType,   
			pg2.Number AS TradeChannel,   
			PersonalName,   
			Contract,   
			Contracted   
		From           
			#CustomerTbl AS Cu                   
			INNER JOIN #StreetTbl AS St ON Cu.StreetName = St.Name AND Cu.CountryName = St.CountryName 
			INNER JOIN PalmGUID AS pg ON pg.GUID = Cu.ID 
			INNER JOIN PalmGUID AS pg1 ON pg1.GUID = Cu.CustomerTypeGUID  
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = Cu.TradeChannelGUID 
			INNER JOIN CU000 AS cu2 ON cu2.GUID = cu.ID 
			INNER JOIN AC000 AS ac ON ac.GUID = cu2.AccountGUID 
			ORDER By StreetID, ac.Code 
	end 
	INSERT INTO #CustomerCodeTbl     
		SELECT     
			r.[Index],     
			cu.BarCode     
		FROM     
			PalmCustTbl AS r    
			INNER JOIN PalmGUID AS pg ON pg.Number = r.ID    
			INNER JOIN Cu000 AS cu ON cu.GUID = pg.GUID    
		ORDER BY BarCode    
	---------------------------------  
	SELECT  
		ac.Name, ac.Code, 
		p.*,  
		c.Barcode, 
		c.Telex, 
		c.Phone1, 
		pcu.AroundBalance 
	FROM  
		PalmCustTbl AS p  
		INNER JOIN PalmGUID AS g ON g.Number = p.ID  
		INNER JOIN [CU000] AS c ON [c].[GUID] = [g].[GUID] 
		INNER JOIN [AC000] AS ac ON ac.GUID = c.AccountGUID 
		INNER JOIN #CustomerTbl AS pcu ON pcu.ID = c.GUID 
	ORDER BY  
		[p].[Index] ASC 
	---------------------------------  
	SELECT CustIndex AS [Index], CustCode AS Code FROM #CustomerCodeTbl    
	---------------------------------  
	SELECT [Index] FROM PalmCustTbl WHERE InRoute = 1 ORDER BY [Index] 
	---------------------------------	  
	SELECT  
		pg.Number,  
		ct.Name,  
		ct.LatinName, 
		ct.PossibilityItemDisc 
	FROM     
		DistCt000 AS ct    
		INNER JOIN PalmGUID AS pg ON pg.GUID = ct.GUID 
	---------------------------------  
	--Export Discount 
	CREATE TABLE #Discount 
	(		 
		Number 		int, 
		Name 		NVARCHAR(100)  COLLATE Arabic_CI_AI , 
		CalcType	int, 
		[Percent]	float, 
		Value		float, 
		CondValue	float, 
		CondValueTo	float, 
		MatID		int, 
		ChangeVal	int, 
		OneTime		int, 
		StartDate	datetime, 
		EndDate		datetime,
		MatTemplateID	INT 
	) 
	INSERT INTO #Discount 
		SELECT 
			pg1.Number,  
			d.Name,  
			d.CalcType, 
			d.[Percent], 
			d.Value, 
			d.CondValue, 
			d.CondValueTo, 
			pg2.Number AS MatID, 
			ChangeVal, 
			OneTime, 
			StartDate	datetime, 
			EndDate		datetime,
			pg3.Number	AS MatTemplateID 
		FROM     
			-- DistDisc000 AS d    
			#DistDisc	AS d 
			INNER JOIN PalmGUID AS pg1 ON pg1.GUID = d.GUID 
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = d.MatGUID 
			INNER JOIN PalmGUID AS pg3 ON pg3.GUID = d.MatTemplateGUID 
		WHERE 
			GivingType = 1 AND 
			GetDate() Between StartDate AND DATEADD ( day , 1, EndDate) 
	 
	SELECT * FROM #Discount	 -- ORDER BY Number 
	---------------------------------	 
	CREATE TABLE #matGroups(distGuid UNIQUEIDENTIFIER, mtGuid UNIQUEIDENTIFIER, grGuid UNIQUEIDENTIFIER) 
	DECLARE  
		@c		CURSOR,  
		@grGUID		[UNIQUEIDENTIFIER], 
		@dGUID		[UNIQUEIDENTIFIER]  
		 
	SET @c = CURSOR FAST_FORWARD FOR  
		SELECT Guid, GroupGuid FROM #DistDisc WHERE CalcType = 3 
	OPEN @c FETCH FROM @c INTO @dGuid, @grGUID 
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		INSERT INTO #matGroups SELECT @dGuid, mtGuid, mtGroup FROM fnGetMatsOfGroups (@GrGuid)  
		FETCH FROM @c INTO @dGUID, @grGuid  
	END -- @c loop  
	CLOSE @c DEALLOCATE @c  
	 
	CREATE TABLE #DiscountDetail (DiscId INT, MatId INT)  
	INSERT INTO #DiscountDetail 
		SELECT 
			pg1.Number,  
			pg2.Number AS MatID 
		FROM     
			#DistDisc	AS d 
			INNER JOIN PalmGUID AS pg1 ON pg1.GUID = d.GUID 
			INNER JOIN #matGroups AS mg ON mg.distGuid = d.Guid 
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = mg.MtGUID 
		WHERE 
			GivingType = 1 AND 
			GetDate() Between StartDate AND DATEADD ( day , 1, EndDate) AND 
			CalcTYpe = 3 AND 
			ISNULL(d.GroupGuid,0x00) <> 0x00 

	SELECT * FROM #DiscountDetail ORDER BY DiscId, MatId 

	---------------------------------	 
	--Export Ct Detail 
	SELECT	 
		pg1.Number AS CustomerTypeID, 
		pg2.Number AS DiscountID 
	FROM     
		DistCtd000 AS ctd    
		INNER JOIN PalmGUID AS pg1 ON pg1.GUID = ctd.ParentGUID 
		INNER JOIN PalmGUID AS pg2 ON pg2.GUID = ctd.DiscountGUID 
		INNER JOIN #DistDisc AS d ON d.GUID = ctd.DiscountGUID  
	WHERE 
		GivingType = 1 	 
	ORDER BY 
		-- pg1.Number, ctd.Number 
		pg1.Number, d.MatTemplateGuid DESC , ctd.Number 
	---------------------------------  
	SELECT  
		pg.Number,  
		ct.Name,  
		ct.LatinName  
	FROM     
		DistTch000 AS ct    
		INNER JOIN PalmGUID AS pg ON pg.GUID = ct.GUID 
	--------------------------------- 
	--- CustDisc -  For OneTimeDisc 
	SELECT 
		DISTINCT 
		pg1.Number	AS DiscId, 
		pg2.Number	AS CustId 
	FROM 
		#Discount AS d 
		INNER JOIN PalmGUID AS Pg1 on pg1.Number = d.Number 
		INNER JOIN #DistDisc AS cd ON cd.GUID = pg1.GUID AND cd.OneTime = 1 
		INNER JOIN DI000 AS di ON di.AccountGUID = cd.AccountGUID 
		INNER JOIN BU000 AS bu ON bu.GUID = di.ParentGUID AND bu.Date BETWEEN cd.StartDate AND DATEADD ( day , 1, cd.EndDate) 
		INNER JOIN PalmGUID AS Pg2 on pg2.GUID = bu.CustGUID 
		INNER JOIN PalmCustTbl AS pc on pc.ID = Pg2.Number AND pc.InRoute = 1 
	--------------------------------- 
------------------------------------------------------------------------------------ 
-------  DistMatTemplates 
	SELECT 
		pg.Number	AS MatTemplateID, 
		t.Name		AS MatTemplateName 
	FROM 
		#MatTemplates	AS t 
		INNER JOIN PalmGuid 	AS pg ON pg.Guid = t.Guid 
	ORDER BY pg.Number 
-------  DistMatTemplateDetail    === All Groups For Templates 
	SELECT 
		pg1.Number	AS MatTemplateID, 
		pg2.Number	AS GroupID 
	FROM 
		#TemplatesDetail	AS t 
		INNER JOIN PalmGuid 	AS pg1 ON pg1.Guid = t.TemplateGuid 
		INNER JOIN PalmGuid 	AS pg2 ON pg2.Guid = t.GroupGuid 
	ORDER BY pg1.Number, pg2.Number 
-------  CustClassesTargets 
	SELECT 
		pg1.Number	AS CustID, 
		pg2.Number	AS MatTemplateID, 
		Ct.CustClassName, 
		Ct.TargetVal, 
		Ct.AchievedVal, 
		(Ct.TargetVal - Ct.AchievedVal) AS RemnantVal, 
		pd.StartDate, 
		pd.EndDate 
	FROM  
		#CustClassTarget 	AS Ct 
		INNER JOIN PalmGuid	AS pg1 ON pg1.GUID = Ct.CustGuid 
		INNER JOIN PalmGuid	AS pg2 ON pg2.GUID = Ct.MatTemplateGuid 
		-- INNER JOIN vwPeriods 	AS pd  ON pd.Guid = Ct.PeriodGuid 
		INNER JOIN #Period 	AS pd  ON pd.Guid = Ct.PeriodGuid 
	ORDER BY pg1.Number, pg2.Number	  
------------------------------------------------------   
---------------------------    ’œÌ— ﬂ‘› Õ”«» «·“»Ê‰ 
	CREATE TABLE [#CustStatement](          
			[CustomerID] [uniqueidentifier], 
			[LineType] [INT], 
			[Debit] [Float],           
			[Credit] [Float],           
			[EntryDate] [DateTime], 
			[Note] [NVARCHAR](255) COLLATE ARABIC_CI_AI          
		 )               
	CREATE TABLE [#CustEntrySum](          
			[GUID] [uniqueidentifier], 
			[SumDebit] [Float],           
			[SumCredit] [Float],           
			[PrevBalance] [Float]         
		 )               
	---------------------------- 
	IF (@ExportStatement = 1)
	BEGIN 
		DECLARE	@PREVBALANCESTR		[NVARCHAR](100)         
		DECLARE	@FROMDATESTR		[NVARCHAR](100)         
		DECLARE	@TODATESTR			[NVARCHAR](100)         
		DECLARE	@EMPTYSTR			[NVARCHAR](100)         
		DECLARE	@SUMDEBITSTR		[NVARCHAR](100)         
		DECLARE	@SUMCREDITSTR		[NVARCHAR](100)         
		DECLARE	@BALANCESTR			[NVARCHAR](100)         
		SET	@PREVBALANCESTR = 'Previous'         
		SET	@FROMDATESTR = 'From Date'         
		SET	@TODATESTR = 'To Date'         
		SET	@EMPTYSTR = ' '         
		SET	@SUMDEBITSTR = 'Total Debit'         
		SET	@SUMCREDITSTR = 'Total Credit'         
		SET	@BALANCESTR = 'Total Balance'         
		------------------------------- 
		INSERT INTO          
			[#CustStatement] 
		SELECt          
			[cu].[ID], 
			100,         
			[enDebit], 
			[enCredit], 
			[enDate], 
			[enNotes] 
		FROm         
			[vwEN] AS [en]         
			INNER JOIN [#CustomerTbl] AS [cu]         
				ON [en].[enAccount] = [cu].[cuAccount] 
		WHERE         
			[enDate] Between @GLStartDate AND @GLEndDate 
		ORDER BY         
			[cu].[ID], 
			[en].[enDate] 
		---------------------------------------------------------         
		INSERT INTO          
			[#CustEntrySum]         
		SELECt          
			[cu].[ID],         
			Sum([en].[enDebit]) AS [SumDebit],         
			Sum([en].[enCredit]) AS [SumCredit],         
			0 AS PrevBalance         
		FROm         
			[vwEN] AS [en]         
			INNER JOIN [#CustomerTbl] AS [cu]         
				ON [en].[enAccount] = [cu].[cuAccount]         
		WHERE         
			[enDate] Between @GLStartDate AND @GLEndDate 
		GROUP BY         
			[cu].[ID]   
		---------------------------------------------------------         
		UPDATE 
			[#CustEntrySum] 
		SET 
			[PrevBalance] =  ISNULL([b].[Balaance], 0)         
		FROM         
		(         
			SELECT         
				SUM([en].[enDebit] - [en].[enCredit]) AS [Balaance], 
				[cu].[ID] AS [CuID] 
			FROm         
				[vwEN] AS [en]         
				INNER JOIN [#CustomerTbl] AS [cu]         
					ON [en].[enAccount] = [cu].[cuAccount] 
			WHERE         
				[enDate] < @GLStartDate 
			GROUP BY 
				[cu].[ID] 
		) AS [b]         
		WHERE 
			[GUID] = [b].[CuID] 
		--------------------------------------------------------         
		DECLARE 	@c_en CURSOR 
		DECLARE               
				@GUID [uniqueIdentifier],         
				@SumDebit [Float],           
				@SumCredit [Float],           
				@PrevBalance [Float]         
		SET @c_en = CURSOR FAST_FORWARD         
		FOR         
			SELECT [GUID], [SumDebit], [SumCredit],	[PrevBalance] FROM [#CustEntrySum] ORDER BY [GUID]         
		OPEN @c_en         
		FETCH NEXT FROM @c_en INTO @GUID, @SumDebit, @SumCredit, @PrevBalance         
		WHILE @@FETCH_STATUS = 0         
		BEGIN              
				---------- Insert BrevBalance         
				INSERT INTO [#CustStatement] VALUES (@GUID, 1, @PrevBalance, 0, @GLStartDate, @PREVBALANCESTR )			         
				---------- Insert FromDate         
				INSERT INTO [#CustStatement] VALUES (@GUID, 2, 0, 0, @GLStartDate, @FROMDATESTR)			         
				---------- Insert ToDate         
				INSERT INTO [#CustStatement] VALUES (@GUID, 3, 0, 0, @GLEndDate, @TODATESTR)         
				---------- Insert Empty Line         
				INSERT INTO [#CustStatement] VALUES (@GUID, 4, 0, 0, @GLEndDate, @EMPTYSTR )			         
				---------- Insert Empty Line         
				INSERT INTO [#CustStatement] VALUES (@GUID, 101, 0, 0, @GLEndDate, @EMPTYSTR )         
				---------- Insert SumDebit         
				INSERT INTO [#CustStatement] VALUES (@GUID, 102, @SumDebit, 0, @GLEndDate, @SUMDEBITSTR)         
				---------- Insert SumCredit         
				INSERT INTO [#CustStatement] VALUES (@GUID, 103, 0, @SumCredit, @GLEndDate, @SUMCREDITSTR)			         
				---------- Insert Balance         
				INSERT INTO [#CustStatement] VALUES (@GUID, 104, 0, @PrevBalance + @SumDebit - @SumCredit, @GLEndDate, @BALANCESTR  )			         
			         
			FETCH NEXT FROM @c_en INTO @GUID, @SumDebit, @SumCredit, @PrevBalance         
		END          
		 
		CLOSE @c_en
		DEALLOCATE @c_en

		INSERT INTO [PalmGUID] 
		SELECT DISTINCT  
			[st].[CustomerID] 
		FROM 
			[#CustStatement] AS [st] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [st].[CustomerID] 
		WHERE 
			[pg].[GUID] IS NULL 
		 
		SELECT          
			[pg].[Number] AS [CustomerID],    
			[LineType], 
			[Debit],         
			[Credit],         
			[EntryDate],         
			[Note]         
		FROM          
			[#CustStatement] AS [st]         
			INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[ID] = [st].[CustomerID] 
			INNER JOIN [PalmGUID] As [pg] on [pg].[GUID] = [st].[CustomerID] 
		ORDER By          
			[st].[CustomerID],          
			[st].[LineType],          
			[st].[EntryDate]         
	END  -- @Export Statement
------------------------------------------------------------------------------------- 
	DROP TABLE #CountryTbl                   
	DROP TABLE #StreetTbl                   
	DROP TABLE #CustomerTbl                   
	DROP TABLE #CustomerCodeTbl    
	DROP TABLE #Discount 
	DROP TABLE #DiscountDetail 
	DROP TABLE #matGroups 
	DROP TABLE #MatTemplates 
	DROP TABLE #TemplatesDetail 
	DROP TABLE #CustClassTarget 
	DROP TABLE #ClassTargets 
	DROP TABLE #Bills 
	DROP TABLE #CustTemplates 
	DROP TABLE #CustStatement 
	DROP TABLE #CustEntrySum 

/* 
prcConnections_Add2 '„œÌ—' 
EXEC prcDistGetCustOfDistributor 'Alpha' 
*/ 
########################################
#END
