########################################
## prcDistInitCustOfDistributor
CREATE PROCEDURE prcDistInitCustOfDistributor
              @DistributorGUID UNIQUEIDENTIFIER 
AS      
	SET NOCOUNT ON      
	DECLARE @SalesManGUID          UNIQUEIDENTIFIER, 
		@CostGUID                  UNIQUEIDENTIFIER, 
		@CustCondGuid              UNIQUEIDENTIFIER, 
		@CustCondID                INT,  
		@CustBalanceByJobCost      INT,
		@CustSortFld               NVARCHAR(100),
		@GLStartDate               DATETIME,  
		@GLEndDate                 DATETIME,  
		@ShowTarget                BIT,
		@ExportCustInRouteOnly     BIT
	SELECT 
		@SalesManGUID              = [PrimSalesManGUID], 
		@CustBalanceByJobCost      = [CustBalanceByJobCost], 
		@CustCondGuid              = [CustCondGuid],
		@CustCondID				   = [CustCondID],
		@CustSortFld			   = [CustSortFld],
		@GLStartDate			   = [GLStartDate],  
		@GlEndDate                 = [GlEndDate],  
		@ShowTarget                = [UseCustTarget],
		@ExportCustInRouteOnly	   = [ExportCustInRouteOnly]
	FROM 
		  [vwDistributor] 
	WHERE 
		  [GUID] = @DistributorGUID
		  
	SELECT @CostGUID = [CostGUID] FROM [vwDistSalesMan] WHERE [GUID] = @SalesManGUID 
	------------------------------------------ 
	CREATE TABLE #CustOfDist( [GUID] UNIQUEIDENTIFIER, [Security] INT) 
	INSERT INTO #CustOfDist --EXEC [prcGetDistGustsList] @DistributorGUID
	SELECT DISTINCT 
		[cu].[cuGuid] AS Guid, 
		[cu].[cuSecurity] AS [Security]
	FROM 
		[vwCu] AS [Cu] 
		INNER JOIN [DistDistributionLines000] AS [Dl]  ON [Dl].[CustGuid] = [Cu].[cuGuid]
	WHERE
		(Dl.DistGUID = @DistributorGUID)
	------------------------------------------ 
	DECLARE @IsGCCEnabled BIT = (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT))
	DECLARE @CurrencyGuid UNIQUEIDENTIFIER = (SELECT GUID FROM my000 WHERE CurrencyVal = 1)
	------------------------------------------  
	CREATE TABLE [#CustCond]([GUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CustCond] EXEC [prcPalm_GetCustsList] @CustCondId, @CustCondGuid
	------------------------------------------ 
	-- حساب خط التغطية الحالي
	DECLARE @Route       INT
	SET @Route = dbo.fnDistGetRouteNumOfDate(GetDate())
	------------------------------------------ 
	CREATE TABLE #CustomerTbl(           
		[GUID]                  UNIQUEIDENTIFIER, 
		[Code]                  NVARCHAR(255) COLLATE Arabic_CI_AI, 
		[Name]                  NVARCHAR(255) COLLATE Arabic_CI_AI, 
		[LatinName]				NVARCHAR(255) COLLATE Arabic_CI_AI,
		[Barcode]				NVARCHAR(100) COLLATE Arabic_CI_AI, 
		[Balance]				FLOAT,            
		[InRoute]				INT,   
		[TargetFromDate]	    DATETIME,   
		[TargetToDate]			DATETIME,   
		[Target]				FLOAT,   
		[Realized]				FLOAT,   
		[LastVisit]				DATETIME,   
		[MaxDebt]				FLOAT,   
		[CustomerTypeGUID]		UNIQUEIDENTIFIER,   
		[TradeChannelGUID]		UNIQUEIDENTIFIER,   
		[PersonalName]          NVARCHAR(250) COLLATE Arabic_CI_AI,   
		[Contract]              NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[Contracted]			INT,
		[RouteTime]             DATETIME,
		[SortID]                INT DEFAULT (0),   
		[StoreGUID]             UNIQUEIDENTIFIER, 
		[Notes]                 NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[AroundBalance]         FLOAT,  
		[AccGUID]               UNIQUEIDENTIFIER, 
		[LastBuDate]			DATETIME,  
		[LastBuTotal]			FLOAT,  
		[LastBuFirstPay]		FLOAT,  
		[LastEnDate]			DATETIME,  
		[LastEnTotal]			FLOAT,  
		[CustomerType]          NVARCHAR(250) COLLATE Arabic_CI_AI, 
		[TradeChannel]          NVARCHAR(250) COLLATE Arabic_CI_AI,
		[DefPrice]              INT DEFAULT (0),   
		[Phone]                 NVARCHAR(30) COLLATE Arabic_CI_AI, 
		[Mobile]                NVARCHAR(30) COLLATE Arabic_CI_AI,
		[Promotions]			NVARCHAR(200),
		[Discounts]             NVARCHAR(100) ,
		[Routes]                NVARCHAR(20),
		[PayTypeTerm]           INT,
		[PayTermsDays]          INT,
		[HasBillsMustBePaid]	BIT,
		[AccountGUID]			UNIQUEIDENTIFIER,
		TaxCode					INT,
		pager					NVARCHAR(250),
		Phone2					NVARCHAR(250),
		TaxNumber				NVARCHAR(200),
		LocationName			NVARCHAR(200),
		LocationLatinName		NVARCHAR(200),
		CustomerDuePayments		FLOAT,
		[DefaultAddressGUID]    UNIQUEIDENTIFIER
	)  
	------------------------------------------
	DECLARE @CurrenctDate DATE
	SET @CurrenctDate = dbo.fnGetDateFromTime(GETDATE());

	;WITH Payments AS 
	(
	   (SELECT CustGUID, ISNULL(SUM(ISNULL(DUE, 0)), 0) DUE FROM
       (SELECT 
                       bu.CustGUID,
					   SUM(bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0)) DUE
              FROM
                       bu000 bu
                       INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID
                       INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]
                       --LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID]
                       --INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
                       --INNER JOIN en000 en ON en.parentguid = ce.GUID
                       LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID, ParentDebitGuid FROM bp000 GROUP BY DebtGUID,ParentDebitGuid) bp ON bp.DebtGUID = bu.GUID OR bp.ParentDebitGuid = bu.GUID
                       --INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
                       --INNER JOIN cu000 cu ON ac.GUID = cu.AccountGUID
              WHERE 
                       EXISTS(SELECT 1 FROM #CustOfDist WHERE GUID = bu.CustGUID)
                       AND bt.bIsOutput > 0 
                       AND bu.PayType = 1 
                       AND bu.IsPosted > 0
                       AND bu.Total + bu.TotalExtra - bu.TotalDisc  + (CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END) - ISNULL(bp.Val,0) > 0.9
                       AND CAST(pt.DueDate AS DATE) < @CurrenctDate
					   AND bu.CustGUID <> 0x0
			 GROUP BY bu.CustGUID
              UNION ALL 
              SELECT 
                       cu.GUID AS CustGUID,
					   SUM(en.Debit - ISNULL(bp.Val,0)) DUE
              FROM 
                       ce000 AS ce
                       INNER JOIN pt000 pt ON pt.RefGUID = ce.[Guid]
                       LEFT JOIN er000 er ON er.ParentGUID = ce.[Guid]
                       INNER JOIN ce000 ce1 ON ce1.[Guid] = entryGuid
                       INNER JOIN en000 en ON en.parentguid = ce1.GUID
                       LEFT JOIN (SELECT SUM(Val) AS Val, DebtGUID FROM bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID
                       --INNER JOIN ac000 ac ON ac.GUID = en.AccountGUID
                       INNER JOIN cu000 cu ON en.AccountGUID = cu.AccountGUID
              WHERE
			  EXISTS(SELECT 1 FROM #CustOfDist WHERE GUID = cu.GUID)
			   AND en.Debit - ISNULL(bp.Val,0) > 0.9
               AND  CAST(pt.DueDate AS DATE) < @CurrenctDate
			   GROUP BY  cu.GUID) D GROUP BY CustGUID)
			   
	)
	INSERT INTO #CustomerTbl (   
		 [GUID], 
		 [Code], 
		 [Name], 
		 [LatinName],
		 [Barcode], 
		 [Balance], 
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
		 [Mobile],
		 [Promotions],
		 [Discounts],
		 [Routes],
		 [PayTypeTerm],
		 [PayTermsDays],
		 [HasBillsMustBePaid],
		 [AccountGUID],
		 TaxCode,
		 pager,
		 Phone2,
		 TaxNumber,
		 LocationName,
		 LocationLatinName,
		 CustomerDuePayments,
		[DefaultAddressGUID]
	)   
	SELECT           
		[cu].[cuGUID],     
        [ac].[acCode],
        [cu].[cuCustomerName], 
        [cu].[cuLatinName],
        [cu].[cuBarcode], 
        [dbo].[fnAccCust_getBalance]([ac].[acGUID], @CurrencyGuid ,'1/1/1980', NULL, 0x0, [cu].[cuGUID]), -- dbo.[fnAccount_getBalance] ([acGuid], 0x0, '1/1/1980', null),   
        0,
		'1-1-2000',   
		'1-1-2000',   
		0,   
		0,   
		'1-1-2000',   
		[ac].[acMaxDebit], 
		[cu].[ctGUID],
		[cu].[tchGUID],
		[cu].[cuHead],
		[cu].[ceContract],  
		[cu].[ceContracted],
		'1-1-1980',
		0,
		[cu].[ceStoreGuid], -- ISNULL([StoreGuid], 0x00),         
		[cu].[cuNotes],
		0,
		[ac].[acGUID],
		'1-1-1980',
		0,
		0, 
		'1-1-1980',
		0,
		[cu].[ctName],
		[cu].[tchName],
		-- [cu].[cuDefPrice],
		CASE [cu].[cuDefPrice]  WHEN 4   THEN 1        -- Whole Price              الجملة  
								WHEN 8   THEN 2        -- Half Price         نصف الجملة  
								WHEN 16  THEN 4        -- Export Price         التصدير    
								WHEN 32  THEN 3        -- Vendor Price         الموزع    
								WHEN 64  THEN 5        -- Retail Price         المفرق  
								WHEN 128 THEN 6        -- EndUser Price  المستهلك  
								ELSE 1
		END AS cuDefPrice,                                     
		CAST([cu].[cuPhone1] AS NVARCHAR(20)),
		CAST([cu].[cuMobile] AS NVARCHAR(20)),
		'0',  
		'0',
		'0,0,0,0',
		ISNULL(pt.Term, -1) AS PayTypeTerm,
		ISNULL(pt.Days, -1) AS PayTermsDays,
		CASE WHEN Due.CustGUID IS NULL THEN 0 ELSE 1 END,--dbo.fnIsCustomerHasDuePayments([cu].[cuGUID]),
		[cu].cuAccount,
		(CASE @IsGCCEnabled WHEN 0 THEN (CASE [cu].cuExemptFromTax WHEN 1 THEN 4
		ELSE 0 END)
		ELSE ISNULL(GCC.TaxCode, 0) 
		END),
		[cu].cuPager,
		[cu].cuPhone2,
		ISNULL(GCC.TaxNumber, N''),
		ISNULL(GCCLocations.Name, N''),
		ISNULL(GCCLocations.LatinName, N''),
		ISNULL(Due.DUE, 0),--dbo.fnGetCustomerDuePayments([cu].[cuGUID])			
		ISNULL([cu].cuDefaultAddressGUID, 0x0)
	FROM   
		#CustOfDist AS [c] 
		INNER JOIN [vwCuCe] AS [cu] ON [cu].[cuGUID] = [c].[GUID]   
		INNER JOIN [vwAc]    AS [ac] ON [ac].[acGUID] = [cu].[cuAccount]   
		INNER JOIN [#CustCond]     AS [cn] ON [cn].[GUID] = [cu].[cuGUID] 
		LEFT  JOIN pt000 pt ON [cu].cuGUID = pt.RefGUID  AND pt.Type = 2 AND pt.Term = 2 -- أيام استحقاق الزبائن
		LEFT JOIN GCCCustomerTax000 GCC ON GCC.CustGUID = CU.cuGUID AND GCC.TaxType = 1
		LEFT JOIN GCCCustLocations000 GCCLocations ON GCCLocations.GUID = CU.GCCLocationGUID
		LEFT JOIN Payments AS Due ON Due.CustGUID = [c].[GUID] 
	
	------------------------------------------ 
	-- إحضار زبائن خط التغطية الحالي
	CREATE TABLE #CustomerRouteTbl
	( 
		  [GUID]        [UNIQUEIDENTIFIER], 
		  [RouteTime]   [DATETIME],  
		  [SortID]      [INT] IDENTITY(1,1)
	)  
	IF @CustSortFld = 'RouteTime'     
	BEGIN
		  INSERT INTO #CustomerRouteTbl ( [Guid] , [RouteTime])
				 SELECT [CustomerGuid], [RouteTime] 
				 FROM fnDistGetRouteOfDistributor(@DistributorGUID, @Route) ORDER BY [RouteTime]
	END
	ELSE
	BEGIN
		  INSERT INTO #CustomerRouteTbl ( [Guid], [RouteTime])
				 SELECT [fn].[CustomerGuid] , [fn].[RouteTime]
				 FROM fnDistGetRouteOfDistributor(@DistributorGUID, @Route) AS [fn]
				 INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[Guid] = [fn].[CustomerGuid]
				 ORDER BY 
					   CASE @CustSortFld WHEN 'Code' THEN [cu].[Code] ELSE [cu].[Name] END
	END
	UPDATE #CustomerTbl 
		  SET    [InRoute] = 1,
				 [RouteTime] = [ru].[RouteTime],
				 [SortID]    = [ru].[SortID] 
	FROM 
		  #CustomerTbl AS [cu] 
		  INNER JOIN #CustomerRouteTbl AS [ru] ON [ru].[Guid] = [cu].[Guid]
	UPDATE #CustomerTbl
		  SET [Routes] = Cast(dl.Route1 as NVARCHAR(2))+','+Cast(dl.Route2 as NVARCHAR(2))+','+Cast(dl.Route3 as NVARCHAR(2))+','+Cast(dl.Route4 as NVARCHAR(2))
	FROM  
		  #CustomerTbl AS cu
	INNER JOIN DistDistributionLines000 AS dl ON dl.[CustGuid] = cu.[Guid] AND dl.DistGuid = @DistributorGuid    
	----------------------------------- 
	-- حساب رصيد حسم التقريب 
	CREATE TABLE #AroundBal ( [CustGUID] [UNIQUEIDENTIFIER], [AcoundBalance] [FLOAT])  
	INSERT INTO #AroundBal  
	SELECT   
		  [cu].[GUID], 
		  --(Sum([di].[diDiscount]) - Sum([di].[diExtra]))
		  CAST(Sum([di].[diDiscount]) - Sum([di].[diExtra]) AS INT) % 5		  
	FROM  
		  [#CustomerTbl]             AS [cu]              
		  INNER JOIN [vwBu]    AS [bu]   ON [cu].[Guid] = [bu].[buCustPtr] 
		  INNER JOIN [vwDi]    AS [di]   ON [di].[diParent] = [bu].[buGUID]                         
		  INNER JOIN [DistDisc000]AS [disc] ON [disc].[AccountGUID] = [di].[diAccount] AND [CalcType] = 5
	Group By 
		  [cu].[Guid] 
		  
	UPDATE #CustomerTbl 
		  SET [AroundBalance] = [a].[AcoundBalance]  
		  FROM #AroundBal AS [a] INNER JOIN #CustomerTbl AS [cu] ON [cu].[GUID] = [a].[CustGUID]  
	----------------------------------- 
	---- حساب رصيد الزبون
	---- @CustBalanceByJobCost = 1  الأرصدة على مركز الكلفة
	--CREATE TABLE #CustBalance( [GUID] [UNIQUEIDENTIFIER], [Balance] [FLOAT]) 
	--INSERT INTO #CustBalance 
	--SELECT [cu].[GUID] , Sum([en].[enDebit] - [en].[enCredit]) AS [Balance]  
	--FROM  
	--	  [vwCeEn] AS [en] 
	--	  INNER JOIN [#CustomerTbl] AS [cu] ON [cu].[GUID] = [enCustomerGUID]
	--WHERE  
	--	  [en].[ceIsPosted] <> 0 AND ([en].[enCostPoint] = @CostGUID OR @CustBalanceByJobCost = 0)
	--GROUP BY 
	--	  [cu].[GUID] 
	--UPDATE #CustomerTbl SET [Balance] = [cb].[Balance] 
	--FROM 
	--	  #CustBalance AS [cb], #CustomerTbl AS [cu] 
	--WHERE 
	--	  [cb].[GUID] = [cu].[GUID] 
	----------------------------------- 
	-- حساب أهداف الزبائن 
	IF @ShowTarget = 1 
	BEGIN
		  UPDATE #CustomerTbl
		  SET
				 Target = tr.TotalCustTarget, 
				 TargetFromDate = pd.StartDate, 
				 TargetToDate = pd.EndDate 
		  FROM 
				 #CustomerTbl AS cu
				 INNER JOIN DistCustTarget000 AS tr ON tr.CustGuid = cu.Guid
				 INNER JOIN BDP000  AS pd ON pd.Guid = tr.PeriodGuid
		  WHERE 
				 PeriodGuid = (       SELECT TOP 1 GUID FROM BDP000 WHERE Getdate() Between StartDate AND EndDate ORDER BY CAST(EndDate - StartDate AS INT) )
	END                  
	----------------------------------- 
	-- حساب آخر زيارة       
	DECLARE @c_Lasts CURSOR,
		@CustGuid            UNIQUEIDENTIFIER,
		@AccGuid             UNIQUEIDENTIFIER,
		@LastViDate          [DATETIME], 
		@LastBuDate          [DATETIME], 
		@LastBuTotal  [FLOAT],
		@LastBuFirstPay      [FLOAT],
		@LastEnDate          [DATETIME], 
		@LastEnTotal  [FLOAT],
		@StartDate           [DATETIME],
		@EndDate             [DATETIME],
		@Realized            [FLOAT]
		
	SET @c_Lasts = CURSOR FAST_FORWARD FOR SELECT [GUID], [AccGUID], [TargetFromDate], [TargetToDate]  FROM [#CustomerTbl] WHERE InRoute = 1
	OPEN @c_Lasts FETCH NEXT FROM @c_Lasts INTO @CustGUID, @AccGUID, @StartDate, @EndDate
	WHILE @@FETCH_STATUS = 0          
	BEGIN   
		SET @LastViDate = '01-01-1980'
		SET @LastBuDate = '01-01-1980'
		SET @LastEnDate = '01-01-1980'
		SET @LastBuTotal = 0
		SET @LastBuFirstPay = 0
		SET @LastEnTotal = 0
		SET @Realized = 0
		
		SELECT 
			TOP 1 @LastBuDate = Date, @LastBuTotal = Total + TotalExtra - TotalDisc - ItemsDisc, @LastBuFirstPay = FirstPay -- آخر فاتورة
		FROM 
			bu000 
		WHERE 
			CustGuid = @CustGUID 
			AND (CostGUID = @CostGUID OR @CustBalanceByJobCost = 0)
		ORDER By 
			[Date] DESC 
			
		Select 
			TOP 1 @LastEnDate = en.Date, @LastEnTotal = (en.Debit - en.Credit)-- آخر دفعة
		FROM 
			vwPyCe AS ce 
			INNER JOIN en000 AS en ON en.ParentGUID = ce.ceGUID AND en.AccountGUID = @AccGUID  -- AND en.Debit <> 0
		WHERE
			(en.CostGUID = @CostGUID OR @CustBalanceByJobCost = 0)
		ORDER BY 
			CeDate DESC
		SELECT @LastViDate = ISNULL(Max([StartTime]), '01-01-1980')  -- آخر زيارة
		FROM DistVi000 WHERE CustomerGuid = @CustGUID
		--- Calc Realized Value For Each Cust
		IF @ShowTarget = 1 
		BEGIN
			SELECT
				@Realized = ISNULL(SUM(Total + TotalExtra - TotalDisc - ItemsDisc), 0)
			FROM 
				bu000
			WHERE 
				[Date] BETWEEN @StartDate AND @EndDate 
				AND CustGuid = @CustGuid 
				AND CostGUID = @CostGUID 
		END
	      
		UPDATE #CustomerTbl 
			SET LastVisit = @LastViDate,
			LastBuDate = @LastBuDate,
			LastBuTotal = @LastBuTotal,
			LastBuFirstPay = @LastBuFirstPay,
			LastEnDate = @LastEnDate,
			LastEnTotal = @LastEnTotal,
			Realized = @Realized
		WHERE 
			Guid = @CustGUID
	      
		  FETCH NEXT FROM @c_Lasts INTO @CustGUID, @AccGUID, @StartDate, @EndDate
	END
	CLOSE @c_Lasts DEALLOCATE @c_Lasts
	------------------------------------------ 
	DELETE [DistDeviceCU000] WHERE [DistributorGUID] = @DistributorGUID 
	------------------------------------------ 
	INSERT INTO DistDeviceCU000 (   
		[cuGUID], 
		[DistributorGUID], 
		[Name], 
		[LatinName],
		[Barcode], 
		[Balance], 
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
		[Mobile],
		[Promotions],
		[Discounts],
		[Routes],
		[PayTypeTerm],
		[PayTermsDays],
		[HasBillsMustBePaid],
		[AccountGuid],
		TaxCode,
		pager,
		Phone2,
		TaxNumber,
		LocationName,
		LocationLatinName,
		CustomerDuePayments,
		DefaultAddressGUID
	)         
	SELECT           
		[cu].[GUID],  
		CAST (@DistributorGUID AS NVARCHAR(100)), 
		[cu].[Name], 
		[cu].[LatinName], 
		ISNULL([cu].[Barcode], ''), 
		[cu].[Balance], 
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
		[cu].[PersonalName],      
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
		[Mobile],
		[Promotions],
		[Discounts],
		[Routes],
		[PayTypeTerm],
		[PayTermsDays],
		[HasBillsMustBePaid],
		[AccountGUID],
		TaxCode,
		pager,
		Phone2,
		TaxNumber,
		LocationName,
		LocationLatinName,
		CustomerDuePayments,
		DefaultAddressGUID
	FROM           
		#CustomerTbl AS cu 
	WHERE 
		InRoute = 1 OR @ExportCustInRouteOnly = 0              
		
	DROP TABLE #CustomerTbl                   
	DROP TABLE #CustomerRouteTbl    
########################################
## prcDistInitCustomerAddresses
CREATE PROCEDURE prcDistInitCustomerAddresses
            @DistributorGUID UNIQUEIDENTIFIER 
AS      
	SET NOCOUNT ON      
	CREATE TABLE #CustAddressTbl
	(   
		[Number]				INT,
		[GUID]                  UNIQUEIDENTIFIER, 
		[Name]                  NVARCHAR(255) COLLATE Arabic_CI_AI, 
		[LatinName]				NVARCHAR(255) COLLATE Arabic_CI_AI,
		[CustomerGUID]			UNIQUEIDENTIFIER,   
		[AreaGUID]				UNIQUEIDENTIFIER,   
		[Street]				NVARCHAR(255) COLLATE Arabic_CI_AI,
		[BuildingNumber]		NVARCHAR(255) COLLATE Arabic_CI_AI,
		[FloorNumber]			NVARCHAR(255) COLLATE Arabic_CI_AI,
		[MoreDetails]			NVARCHAR(255) COLLATE Arabic_CI_AI,
		[POBox]					NVARCHAR(255) COLLATE Arabic_CI_AI,
		[ZipCode]				NVARCHAR(255) COLLATE Arabic_CI_AI,
		[GPSX]					FLOAT,
		[GPSY]					FLOAT,
		[AddressGUID]           UNIQUEIDENTIFIER, 
	)  
	------------------------------------------
	INSERT INTO #CustAddressTbl 
	SELECT
		[ca].[Number],
		NEWID(),
		[ca].[Name],
		[ca].[LatinName],
		[ca].[CustomerGUID],
		[ca].[AreaGUID],
		[ca].[Street],
		[ca].[BulidingNumber],
		[ca].[FloorNumber],
		[ca].[MoreDetails],
		[ca].[POBox],
		[ca].[ZipCode],
		[ca].[GPSX],
		[ca].[GPSY],
		[ca].[GUID]
	FROM 
		distdevicecu000 cu 
		INNER JOIN CustAddress000 ca on [cu].[CuGUID] = [ca].[CustomerGUID]
	WHERE 
		cu.DistributorGUID = @DistributorGUID
	------------------------------------------ 
	DELETE [DistDeviceCustAddress000] WHERE [DistributorGUID] = @DistributorGUID
	DELETE [DistDeviceCustAddressWorkingDays000] WHERE [DistributorGUID] = @DistributorGUID
	DELETE [DistDeviceAddressCountry000]
	DELETE [DistDeviceAddressCity000]
	DELETE [DistDeviceAddressArea000]
	------------------------------------------
	INSERT INTO DistDeviceCustAddress000  (Number, GUID,Name, LatinName, CustomerGUID,
											AreaGUID, Street, BulidingNumber, FloorNumber, MoreDetails,
											POBox, ZipCode, GPSX, GPSY,DistributorGUID, State, AddressGUID)   
    SELECT
        [Number],               
        [GUID],        
        [Name],                 
        [LatinName],               
        [CustomerGUID],           
        [AreaGUID],               
        [Street],               
        [BuildingNumber],       
        [FloorNumber],           
        [MoreDetails],           
        [POBox],                   
        [ZipCode],               
        [GPSX],                   
        [GPSY],                           
        @DistributorGUID,
        0,
		[AddressGUID]
      
    FROM          
        #CustAddressTbl
	------------------------------------------
	INSERT INTO DistDeviceCustAddressWorkingDays000 (GUID, AddressGUID, WorkDays, MorningStart, MorningEnd, 
													 NightStart, NightEnd, DistributorGUID, State, AmenWorkingAddressGUID)          
	SELECT 
		NEWID(),
		[wd].[AddressGUID],
		WorkDays,
		MorningStart,
		MorningEnd,
		NightStart,
		NightEnd,
		@DistributorGUID,
		0,
		[wd].[GUID]
	FROM #CustAddressTbl ca
	INNER JOIN CustAddressWorkingDays000 wd on [ca].[AddressGUID] = [wd].[AddressGUID] 
	DROP TABLE #CustAddressTbl   
	--------------------------
	INSERT INTO DistDeviceAddressCountry000 (GUID, Code, Name, LatinName, State)
	SELECT 
		GUID,
		Code, 
		Name, 
		LatinName,
		0
	FROM 
		AddressCountry000   
	--------------------------
	INSERT INTO DistDeviceAddressCity000 (GUID, Code, Name, LatinName, ParentGUID, State)
	SELECT
		GUID,
		Code, 
		Name, 
		LatinName, 
		ParentGUID,
		0
	FROM 
		AddressCity000   
	--------------------------
	INSERT INTO DistDeviceAddressArea000 (GUID, Code, Name, LatinName, ParentGUID, State)
	SELECT  
		GUID,
		Code, 
		Name, 
		LatinName, 
		ParentGUID,
		0
	FROM 
		AddressArea000   
########################################
## prcDistInitCustStockOfDistributor
CREATE PROC prcDistInitCustStockOfDistributor
	@DistGuid	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	--------------------------------------------------
	DELETE DistDeviceCm000 WHERE DistributorGuid = @DistGuid

	DECLARE @UseStockOfCust				BIT,
			@ExportAllCustDetailFlag	BIT
	SELECT @UseStockOfCust = UseStockOfCust, @ExportAllCustDetailFlag = ExportAllCustDetailFlag FROM Distributor000 Where Guid = @DistGuid
	IF @UseStockOfCust = 0
		RETURN 

	CREATE TABLE #CustLastDate(CustGUID uniqueidentifier, LastVisit datetime) 
	INSERT INTO #CustLastDate (CustGuid, LastVisit)
	SELECT 
		[CustomerGUID], 
		Max([Date]) 
	FROM 
		DistCm000 AS cm 
	GROUP BY 
		CustomerGUID 

	--------------------------------------------------
	INSERT INTO DistDeviceCm000(
		DistributorGuid,
		CustGuid,
		MatGuid,
		LastDate,
		NewDate,
		LastQty,
		NewQty,
		Unity,
		VisitGuid
	)
	SELECT 
		@DistGuid,
		cu.cuGuid,
		mt.mtGuid,
		ld.LastVisit,
		'01-01-1980',
		(cm.Qty+cm.Target),
		0,
		1,
		0x00
	FROM 
		DistCm000 AS cm
		INNER  JOIN #CustLastDate   AS ld ON ld.CustGuid = cm.CustomerGuid AND ld.LastVisit = cm.Date
		INNER JOIN DistDeviceCu000 AS cu ON cu.cuGuid = cm.CustomerGuid AND cu.DistributorGuid = @DistGuid
		INNER JOIN DistDeviceMt000 AS mt ON mt.mtGuid = cm.MatGuid AND mt.DistributorGuid = @DistGuid
	WHERE 
		cu.InRoute = 1 OR @ExportAllCustDetailFlag = 0	-- تصدير تفاصيل كل الزبائن
	--------------------------------------------------
-- Select * From DistDeviceCm000 Where DistributorGuid = @DistGuid

/*
Exec prcDistInitCustStockOfDistributor 'BE916CF7-47BA-4A1A-80F2-1294F211CC5E'
Select * From DistCm000
*/
########################################
## prcDistInitOffersOfDistributor
CREATE PROC prcDistInitOffersCondOfDistributor
	@DistGUID uniqueidentifier
AS   
	SET NOCOUNT ON
	
	DECLARE @C					CURSOR,
			@ProGuid			UNIQUEIDENTIFIER,
			@CustCondGuid		UNIQUEIDENTIFIER,
			@MatCondGuid		UNIQUEIDENTIFIER,
			@CustAccGuid		UNIQUEIDENTIFIER,
			@GroupGuid			UNIQUEIDENTIFIER,
			@Number				INT
			
	CREATE TABLE #Cond ( [Guid] UNIQUEIDENTIFIER, [Security] INT)
	-------------------------------------------------
	SELECT @CustAccGuid = CustomersAccGuid, @GroupGuid = MatGroupGuid FROM Distributor000 WHERE Guid = @DistGuid
	-------------------------------------------------
	--- Check Promotions Conditions			
	SET @C = CURSOR FAST_FORWARD FOR 
	SELECT P1.ProGuid, P2.CustCondGuid, P2.MatCondGuid, P2.Number 
	FROM 
		DistDevicePro000 AS P1 
		INNER JOIN DistPromotions000 AS P2 ON P1.ProGuid = P2.Guid 
	WHERE 
		P1.DistributorGuid = @DistGuid 
	ORDER By 
		P2.Number
	OPEN @C FETCH FROM @C INTO @ProGuid, @CustCondGuid, @MatCondGuid, @Number
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--- Cust Cond
		DELETE #Cond		
		INSERT INTO #Cond EXEC [prcGetCustsList] 0x0, @CustAccGuid, @CustCondGUID 
		--IF EXISTS (SELECT * FROM #Cond)
		--BEGIN
		--	UPDATE DistDeviceCu000
		--	SET Promotions = CAST( 
		--			CASE Promotions 
		--			WHEN '0' THEN CONVERT(NVARCHAR(10), @Number)
		--			ELSE 
		--			(
		--				CASE 
		--					WHEN NOT CHARINDEX(CONVERT(NVARCHAR(10), @Number), Promotions) > 0  THEN Promotions + ',' + CONVERT(NVARCHAR(10), @Number)
		--					Else Promotions
		--				END
		--			)
		--			END  
		--		 AS NVARCHAR(2000)) 
		--	FROM 
		--		DistDeviceCu000 AS cu
		--		INNER JOIN #Cond AS cd ON cd.Guid = cu.cuGuid
		--		INNER JOIN DistDeviceCtd000 as ct ON ct.ObjectGuid = @ProGuid AND ParentGuid = cu.CustomerTypeGuid AND cu.DistributorGuid = ct.DistributorGuid
		--	WHERE 
		--		cu.DistributorGuid = @DistGuid	
		--END
		
		--- Mat Cond
		DELETE #Cond		
		INSERT INTO #Cond EXEC [prcGetMatsList] 0x0, @GroupGuid, -1, @MatCondGUID 
		--IF EXISTS (SELECT * FROM #Cond)
		--BEGIN
		--	UPDATE DistDeviceMt000
		--	SET Promotions = CAST( 
		--						CASE Promotions 
		--						WHEN '0' THEN CONVERT(NVARCHAR(10), @Number)
		--						ELSE 
		--						(
		--							CASE 
		--								WHEN NOT CHARINDEX(CONVERT(NVARCHAR(10), @Number), Promotions) > 0 THEN Promotions + ',' + CONVERT(NVARCHAR(10), @Number)
		--								Else Promotions
		--							END
		--						)
		--						END  
		--					 AS NVARCHAR(2000)) 
		--	FROM 
		--		DistDeviceMt000 AS mt
		--		INNER JOIN #Cond AS md ON md.Guid = mt.mtGuid
		--	WHERE 
		--		mt.DistributorGuid = @DistGuid	
		--END
		
		
		FETCH FROM @C INTO @ProGuid, @CustCondGuid, @MatCondGuid, @Number
	END
	CLOSE @C DEALLOCATE @C
	-------------------------------------------------
	--- Check Discounts Conditions			
	SET @C = CURSOR FAST_FORWARD FOR 
	SELECT di.Guid, di.CustCondGuid, di.MatCondGuid, di.Number FROM DistDisc000 AS di INNER JOIN DistDiscDistributor000 AS ds ON ds.ParentGuid = di.Guid AND ds.DistGuid = @distGuid AND ds.Value = 1 ORDER BY di.Number
	OPEN @C FETCH FROM @C INTO @ProGuid, @CustCondGuid, @MatCondGuid, @Number
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--- Cust Cond
		DELETE #Cond		
		INSERT INTO #Cond EXEC [prcGetCustsList] 0x0, @CustAccGuid, @CustCondGUID 
		IF EXISTS (SELECT * FROM #Cond)
		BEGIN
			UPDATE DistDeviceCu000
			SET Discounts = CAST( 
								CASE Discounts 
								WHEN '0' THEN CONVERT(NVARCHAR(10), @Number)
								ELSE 
								(
									CASE 
										WHEN NOT CHARINDEX(CONVERT(NVARCHAR(10), @Number), Discounts) > 0 THEN Discounts + ',' + CONVERT(NVARCHAR(10), @Number)
										Else Discounts
									END
								)
								END  
							 AS NVARCHAR(2000)) 
			FROM 
				DistDeviceCu000 AS cu
				INNER JOIN #Cond AS cd ON cd.Guid = cu.cuGuid
				-- INNER JOIN DistDeviceCtd000 as ct ON ct.ObjectGuid = @ProGuid AND ParentGuid = cu.CustomerTypeGuid AND cu.DistributorGuid = ct.DistributorGuid
			WHERE 
				cu.DistributorGuid = @DistGuid	
		END
		
		--- Mat Cond
		DELETE #Cond		
		INSERT INTO #Cond EXEC [prcGetMatsList] 0x0, @GroupGuid, -1, @MatCondGUID 
		IF EXISTS (SELECT * FROM #Cond)
		BEGIN
			UPDATE DistDeviceMt000
			SET Discounts = CAST( 
								CASE Discounts 
								WHEN '0' THEN CONVERT(NVARCHAR(10), @Number)
								ELSE 
								(
									CASE 
										WHEN NOT CHARINDEX(CONVERT(NVARCHAR(10), @Number), Discounts) > 0 THEN Discounts + ',' + CONVERT(NVARCHAR(10), @Number)
										Else Discounts
									END
								)
								END  
							 AS NVARCHAR(2000)) 
			FROM 
				DistDeviceMt000 AS mt
				INNER JOIN #Cond AS md ON md.Guid = mt.mtGuid
			WHERE 
				mt.DistributorGuid = @DistGuid	
		END
		
		FETCH FROM @C INTO @ProGuid, @CustCondGuid, @MatCondGuid, @Number
	END
	CLOSE @C DEALLOCATE @C
	-------------------------------------------------
	DROP TABLE #Cond
	-------------------------------------------------
/* 
prcDistInitOffersCondOfDistributor  '06826D4F-E81B-4DF0-AC22-438A09F68C93'
Select Promotions, Discounts, * From DistDeviceCu000 Where DistributorGuid = '06826D4F-E81B-4DF0-AC22-438A09F68C93' ORder By Name
Select Promotions, Discounts, * From DistDeviceMt000 Where DistributorGuid = '06826D4F-E81B-4DF0-AC22-438A09F68C93' ORder By Name
Select * From Distributor000
*/
########################################
## prcDistInitCustStatementOfDistributor
CREATE PROCEDURE prcDistInitCustStatementOfDistributor
		@DistributorGUID uniqueidentifier 
AS      
SET NOCOUNT ON      
	DECLARE @SalesManGUID			uniqueidentifier, 
			@CostGUID 				uniqueidentifier, 
			@DistCustAccGUID		uniqueidentifier,
			@GLStartDate 			DateTime,  
			@GLEndDate 				DateTime,
			@GLLastDayes			INT,
			@GLExportFlag			BIT,
			@GLDetailed				BIT,
			@GLInRouteCusts			INT,
			@CustBalByJobCost		BIT
	SELECT 
			@SalesManGUID 		= [PrimSalesManGUID], 
			@GlLastDayes		= [ExportCustAccDays],
			@GlEndDate			= CASE [ExportCustAccDays] WHEN 0 THEN [GlEndDate] ELSE GETDATE() END,
			@GLStartDate		= CASE [ExportCustAccDays]WHEN 0 THEN [GlStartDate] ELSE GETDATE() - [ExportCustAccDays] END,
			@GLDetailed			= [ExportDetailedCustAcc],
			@GLExportFlag		= [ExportCustAcc],
			@GLInRouteCusts		= CASE [ExportAllCustDetailFlag] WHEN 1 THEN 0 ELSE 1 END,
			@CustBalByJobCost	= [CustBalanceByJobCost],
			@DistCustAccGUID	= [CustomersAccGUID]
	FROM 
		[Distributor000] 
	WHERE 
		[GUID] = @DistributorGUID
		
	SELECT @CostGUID = [CostGUID] FROM [vwDistSalesMan] WHERE [GUID] = @SalesManGUID 
	
	DELETE FROM DistDeviceStatement000 WHERE DistributorGuid = @DistributorGuid
	
	IF @GLExportFlag = 0
		RETURN
	
	-----------------------------------------------------------------
	DECLARE @defCurrencyGUID UNIQUEIDENTIFIER
	SELECT @defCurrencyGUID = Value FROM op000 WHERE Name like 'AmnCfg_DefaultCurrency'
	-----------------------------------------------------------------
	CREATE TABLE #TempGL (
		Guid		UNIQUEIDENTIFIER,
		CustGuid	UNIQUEIDENTIFIER,
		Date		DATETIME,
		Debit		FLOAT,
		Credit		FLOAT,
		Notes		NVARCHAR(MAX),
		Qty			FLOAT,
		Unit		NVARCHAR(100),
		Price		FLOAT,
		LineType	INT,		-- 100 LastBalance -- 110 Entries -- 200 Bill Header  -- 201 Bill Mats -- 202 Bill Discounts -- 203 Bill Items Discount And Extra -- 204 BillTotals -- 300 Payments	-- 400 Totals -- 500 Current Balance -- 600 Cheques
		ItemNumber	NVARCHAR(255),
		Bonus_Qty			FLOAT DEFAULT 0
	)	
	-- Add LastBalance
	INSERT INTO #TempGL ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		newId(),
		[cu].[Guid],
		'01-01-1980',
		[dbo].[fnCurrency_fix](SUM([en].[enDebit] - [en].[enCredit]), en.enCurrencyPtr, en.enCurrencyVal, @defCurrencyGUID, en.enDate) AS [LastBalance],   
		0,
		'الرصيد السابق',
		0,
		'',
		0,
		100,
		'0'
	FROM  
		[vwCeEn] AS [en]  
		INNER JOIN cu000 As cu ON cu.AccountGuid = [en].[enAccount] 
		INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = cu.Guid AND DistributorGuid = @DistributorGUID 
		--AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
	WHERE           
		[enDate] < @GLStartDate   
		AND ([en].[enCostPoint] = @CostGUID OR @CustBalByJobCost = 0)
	GROUP BY   
		[cu].[GUID], en.enCurrencyPtr, en.enCurrencyVal, en.enDate
	Update #TempGl SET Credit = -1 * Debit, Debit = 0 WHERE Debit < 0 AND LineType = 100
	
	-- Add Entries
      INSERT INTO #TempGL  ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
      SELECT 
            newid(),
            cu.Guid,
            ce.Date,
			[dbo].[fnCurrency_fix]([en].Debit, en.CurrencyGUID, en.CurrencyVal, @defCurrencyGUID, en.Date),
			[dbo].[fnCurrency_fix]([en].Credit, en.CurrencyGUID, en.CurrencyVal, @defCurrencyGUID, en.Date),
            en.Notes,
            0,
            '',
            0,
            110,
            '0'
      FROM 
            ce000 AS ce
            INNER JOIN En000 AS en ON en.ParentGuid = ce.Guid
            INNER JOIN cu000 As cu On cu.AccountGuid = en.AccountGuid
            INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = cu.Guid AND DistributorGuid = @DistributorGUID 
			-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
            LEFT JOIN Er000 AS er ON er.EntryGuid = ce.Guid
      WHERE 
            ce.Date BETWEEN @GLStartDate AND @GLEndDate
            AND (en.CostGuid = @CostGuid OR @CustBalByJobCost = 0)
            AND er.Guid IS NULL
            
	-- Add Bills Headers	
	INSERT INTO #TempGL ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		bu.Guid,
		bu.CustGuid,
		bu.Date,
		CASE bt.bIsOutput WHEN 1 THEN [dbo].[fnCurrency_fix]((bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc), bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)
		ELSE 0 --				  ELSE CASE bu.PayType WHEN 0 THEN (bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc) ELSE bu.FirstPay END
		END,
		CASE bt.bIsOutput WHEN 0 THEN [dbo].[fnCurrency_fix]((bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc) , bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)
		ELSE 0 --				  ELSE CASE bu.PayType WHEN 0 THEN (bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc) ELSE bu.FirstPay END
		END,
		CASE bu.PayType WHEN 0 THEN 'نقداً' ELSE bu.Notes END,
		0,
		'',
		0,
		200,
		bu.Number
	FROM 
		bu000 AS bu
		INNER JOIN bt000 AS bt ON bt.Guid = bu.TypeGuid
		INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = bu.CustGuid AND DistributorGuid = @DistributorGUID 
		-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
	WHERE 
		bu.Date BETWEEN @GLStartDate AND @GLEndDate
		AND (bu.CostGuid = @CostGuid OR @CustBalByJobCost = 0)
		AND bt.Type = 1 AND bt.bNoEntry = 0
	IF @GLDetailed = 1
	BEGIN
		-- Add Bills Mats
		INSERT INTO #TempGL( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber,Bonus_Qty)
		SELECT 
			newid(),
			bu.CustGuid,
			bu.Date,
			0,
			0,
			mt.Name,
			CASE bi.Unity WHEN 2 THEN bi.Qty / mt.Unit2Fact WHEN 3 THEN bi.Qty / mt.Unit3Fact ELSE bi.Qty END, 
			CASE bi.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 ELSE mt.Unity END,
			[dbo].[fnCurrency_fix](bi.Price, bi.CurrencyGUID, bi.CurrencyVal, @defCurrencyGUID, bu.Date),
			201,
			bu.Number,
			bi.BonusQnt 
		
		FROM
			bu000 AS bu
			INNER JOIN bi000 AS bi ON bu.Guid = bi.ParentGuid
			INNER JOIN mt000 AS mt ON mt.Guid = bi.MatGuid
			INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = bu.CustGuid AND DistributorGuid = @DistributorGUID 
			-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
		WHERE 
			bu.Guid IN (Select DISTINCT Guid FROM #TempGL)
			
		-- Add Bills Discounts
		INSERT INTO #TempGL( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
		SELECT 
			newid(),
			bu.CustGuid,
			bu.Date,
			0,
			0,
			ac.Name,
			0, 
			'', 
			CASE di.Discount 
				WHEN 0 THEN [dbo].[fnCurrency_fix](Extra, bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)
				ELSE -1 * [dbo].[fnCurrency_fix](di.Discount, di.CurrencyGUID, di.CurrencyVal, @defCurrencyGUID, bu.Date)
			END,
			202,
			bu.Number	
		FROM
			bu000 AS bu
			INNER JOIN di000 AS di ON bu.Guid = di.ParentGuid		
			INNER JOIN ac000 AS ac ON ac.Guid = di.AccountGuid
			INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = bu.CustGuid AND DistributorGuid = @DistributorGUID 
			-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
		WHERE 
			bu.Guid IN (Select DISTINCT Guid FROM #TempGL)
			
		-- Add Bills Items Discounts 
		INSERT INTO #TempGL( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
		SELECT 
			newid(),
			bu.CustGuid,
			bu.Date,
			0,
			0,
			'حسم الأقلام',
			0, 
			'',
			[dbo].[fnCurrency_fix](bu.ItemsDisc, bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date),
			203,
			bu.Number
		FROM
			bu000 AS bu
			INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = bu.CustGuid AND DistributorGuid = @DistributorGUID 
			-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
		WHERE 
			bu.Guid IN (Select DISTINCT Guid FROM #TempGL) AND bu.ItemsDisc <> 0
			
	END
	-- Add Bills Totals
	INSERT INTO #TempGL ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		newid(),
		bu.CustGuid,
		bu.Date,
		CASE bt.bIsOutput WHEN 1 THEN 0
						  ELSE CASE bu.PayType 
									WHEN 0 THEN [dbo].[fnCurrency_fix]((bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc), bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)   
									ELSE [dbo].[fnCurrency_fix](bu.FirstPay , bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date) 
								END
		END,
		CASE bt.bIsOutput WHEN 0 THEN 0
						  ELSE CASE bu.PayType 
									WHEN 0 THEN [dbo].[fnCurrency_fix]((bu.Total + bu.TotalExtra + bu.Vat - bu.TotalDisc - bu.ItemsDisc) , bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)
									
									ELSE [dbo].[fnCurrency_fix](bu.FirstPay , bu.CurrencyGUID, bu.CurrencyVal, @defCurrencyGUID, bu.Date)
								END
		END,
		CASE bu.PayType WHEN 0 THEN 'قيمة الفاتورة' ELSE 'الدفعة الأولى' END, 
		0,
		'',
		0,
		204,
		bu.Number
	FROM 
		bu000 AS bu
		INNER JOIN bt000 AS bt ON bt.Guid = bu.TypeGuid
		INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = bu.CustGuid AND DistributorGuid = @DistributorGUID 
		-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
	WHERE 
		bu.Date BETWEEN @GLStartDate AND @GLEndDate
		AND ( bu.CostGuid = @CostGuid OR @CustBalByJobCost = 0)
		AND bt.Type = 1 AND bt.bNoEntry = 0
		AND (bu.PayType = 0 OR (bu.PayType = 1 AND bu.FirstPay <> 0))
	-- Add Payments		
	INSERT INTO #TempGL  ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		newid(),
		cu.Guid,
		py.Date,
		[dbo].[fnCurrency_fix](en.Debit , en.CurrencyGUID, en.CurrencyVal, @defCurrencyGUID, en.Date),
		[dbo].[fnCurrency_fix](en.Credit , en.CurrencyGUID, en.CurrencyVal, @defCurrencyGUID, en.Date),
		en.Notes,
		0,
		'',
		0,
		300,
		'0'
	FROM 
		Py000	AS py	
		INNER JOIN Er000 AS er ON er.ParentGuid = py.Guid
		INNER JOIN En000 AS en ON en.ParentGuid = er.EntryGuid
		INNER JOIN cu000 As cu On cu.AccountGuid = en.AccountGuid
		INNER JOIN DistDeviceCu000 AS [dd] ON [dd].[cuGUID] = cu.Guid AND DistributorGuid = @DistributorGUID 
		-- AND (InRoute = @GLInRouteCusts OR @GLInRouteCusts = 0)
	WHERE 
		py.Date BETWEEN @GLStartDate AND @GLEndDate
		AND (en.CostGuid = @CostGuid OR @CustBalByJobCost = 0)
	-- Add Totals 
	INSERT INTO #TempGL  ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		newid(),
		CustGuid,
		'01-01-2020',
		SUM(Debit),
		SUM(Credit),
		'المجموع',
		0,
		'',
		0,
		400,
		'0'
	FROM 
		#TempGL
	GROUP By 
		CustGuid
		
	-- Add Current Balance
	INSERT INTO #TempGL  ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		newid(),
		CustGuid,
		'01-01-2020',
		Debit- Credit,
		0,
		'الرصيد الحالي',
		0,
		'',
		0,
		500,
		'0'
	FROM 
		#TempGL
	WHERE 
		LineType = 400	-- From Total Balance
	UPDATE #TempGl SET Credit = -1 * Debit, Debit = 0 WHERE Debit < 0
	-- Add Cheque
	INSERT INTO #TempGL ( Guid, CustGuid, Date, Debit, Credit, Notes, Qty, Unit, Price, LineType, ItemNumber)
	SELECT 
		NEWID(),
		cu.GUID,
		ch.Date,
		CASE     
			WHEN ch.Dir = 2 THEN [dbo].[fnCurrency_fix](ch.Val , ch.CurrencyGUID, ch.CurrencyVal, @defCurrencyGUID, ch.Date)
				ELSE 0
			END,
		CASE     
			WHEN ch.Dir = 1 THEN [dbo].[fnCurrency_fix](ch.Val , ch.CurrencyGUID, ch.CurrencyVal, @defCurrencyGUID, ch.Date)
				ELSE 0
			END,
		ch.Notes, 
		0,
		'',
		0,
		600,
		ch.Num
	FROM 
		ch000 AS ch
		INNER JOIN cu000 AS cu ON ch.AccountGUID = cu.AccountGUID
		INNER JOIN DistDeviceCu000 AS dd ON dd.cuGUID = cu.GUID
	WHERE 
		ch.Date BETWEEN @GLStartDate AND @GLEndDate
		 AND dd.DistributorGuid = @DistributorGUID 
		AND ( ch.Cost1GUID = @CostGuid OR @CustBalByJobCost = 0)
			
	-----------------------------------------------------
	-- Insert new data
	INSERT INTO [DistDeviceStatement000] 
	(
		[GUID],
		[DistributorGUID],
		[CustGUID],
		[Debit],
		[Credit],
		[Date],
		[Notes],
		[LineType],
		[Qty],
		[Unit],
		[Price],
		[ItemNumber],
		[BonusQty]
	)
	SELECT
		t.Guid,
		@DistributorGuid,
		CustGuid,
		Debit,
		Credit,
		Date,
		t.Notes,
		LineType,
		Qty,
		Unit,
		Price,
		ItemNumber,
		Bonus_Qty
	FROM #TempGL AS t
####################################################################################################################
CREATE FUNCTION fnGetCustomerMatSalesAvg (
	@PeriodGUID		UNIQUEIDENTIFIER,
	@DistributorGUID UNIQUEIDENTIFIER
)
RETURNS @Result TABLE
( 
	MatGUID UNIQUEIDENTIFIER,
	CustGUID UNIQUEIDENTIFIER,
	SalesAvgQty	 FLOAT
)  
AS
BEGIN
	DECLARE @PeriodStartDate DATETIME,  
	 		@StartDate 		 DATETIME,  
			@EndDate 		 DATETIME,  
			@CurrencyGUID 	 UNIQUEIDENTIFIER,  
			@brEnabled		 INT, 
			@BranchMask		 BIGINT,
			@CostGuid		 UNIQUEIDENTIFIER,
			@BranchGuid		 UNIQUEIDENTIFIER
	SELECT 
		@CostGuid = sm.CostGuid,
		@BranchMask = d.BranchMask
	FROM 
		Distributor000 AS d
		JOIN DistSalesMan000 AS sm ON sm.GUID = d.PrimSalesmanGUID
	WHERE 
		d.GUID = @DistributorGUID
	
	SELECT 
		@BranchGuid = ISNULL(Guid, 0x0) 
		FROM br000 
	WHERE 
		[dbo].[fnPowerOf2]([Number] - 1) = @BranchMask
	
	IF (@BranchGuid IS NULL)
		SET @BranchGuid = 0x0
			
	SELECT @PeriodStartDate = StartDate FROM vwPeriods WHERE GUID = @PeriodGUID  
	SELECT @EndDate   = DATEADD(day, -1, @PeriodStartDate)  
	SELECT @StartDate = DATEADD(month, -6, @EndDate)  
	SELECT @CurrencyGUID = GUID From my000 WHERE Number = 1  
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')  
	DECLARE @MatTbl	TABLE (GUID UNIQUEIDENTIFIER)    
	DECLARE @CustTbl TABLE (GUID UNIQUEIDENTIFIER, TradeChannelGUID UNIQUEIDENTIFIER, CustomerTypeGUID UNIQUEIDENTIFIER, DistGUID UNIQUEIDENTIFIER)    
	 
	INSERT INTO @CustTbl     
	SELECT DISTINCT    
		cu.cuGUID,    
		ISNULL(ce.TradeChannelGUID, 0x0),    
		ISNULL(ce.CustomerTypeGUID, 0x0),    
		0x00    
	FROM     
		vwCu AS cu 
		INNER JOIN vwac AS ac ON ac.acGuid = cu.cuAccount 
		LEFT JOIN DistCe000 AS ce ON cu.cuGUID = ce.CustomerGUID     
	WHERE     
		ISNULL(ce.State, 0) <> 1 
		AND ((acBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1))
			
	INSERT INTO @MatTbl     
	SELECT     
		mt.mtGUID    
	FROM     
		vwMt AS mt    
	Where	(brBranchMask & @BranchMask <> 0 AND @brEnabled = 1) OR 
			(@brEnabled <> 1) 
	DECLARE @CustMatMonthSales TABLE (CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, [Month] INT, SalesQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	DECLARE @PeriodsTbl TABLE (GUID UNIQUEIDENTIFIER, StartDate DATETIME, EndDate DATETIME)  
	  
	INSERT INTO @PeriodsTbl  
		SELECT  
			p.Guid,  
			p.StartDate,  
			p.EndDate  
		FROM vwperiods AS p  
		WHERE p.Guid = @PeriodGUID
		
	IF EXISTS (SELECT TOP 1 * FROM @PeriodsTbl)
	BEGIN
		DELETE FROM @CustMatMonthSales
		DECLARE @C CURSOR,  
			@CPeriodGuid	UNIQUEIDENTIFIER,  
			@CStartDate		DATETIME,  
			@CEndDate		DATETIME  
	SET @C = CURSOR FAST_FORWARD FOR SELECT Guid, StartDate, EndDate FROM @PeriodsTbl  
	OPEN @C FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
	WHILE @@FETCH_STATUS = 0    
		BEGIN     
			INSERT INTO @CustMatMonthSales    
				SELECT    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					Sum( CASE bi.btBillType WHEN 1 THEN bi.biQty WHEN 3 THEN bi.biQty * -1 ELSE 0 END),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END    
				FROM    
					vwExtended_bi AS bi    
					INNER JOIN @CustTbl AS cu ON cu.GUID = bi.buCustPtr    
					INNER JOIN @MatTbl AS mt ON mt.GUID = bi.biMatPtr    
				WHERE    
					bi.buDate BETWEEN @CStartDate AND @CEndDate	AND    
					bi.btType = 1 AND (bi.btBillType = 1 OR bi.btBillType = 3) AND     
					(bi.buBranch = @BranchGuid OR @BranchGuid = 0x0) AND
					bi.buCostPtr = @CostGuid
				GROUP BY    
					bi.buCustPtr,    
					bi.biMatPtr,    
					DatePart(Month, bi.buDate),    
					CASE @brEnabled WHEN 1 THEN bi.buBranch ELSE 0x0 END  
			FETCH FROM @C INTO @CPeriodGuid, @CStartDate, @CEndDate    
		END	    
	CLOSE @C DEALLOCATE @C    
	END
--------  
	DECLARE @CustMatSales TABLE ( CustGUID UNIQUEIDENTIFIER, MatGUID UNIQUEIDENTIFIER, MonthCount INT, SalesQty FLOAT, MatSalesAvgQty float, StaticMatSalesAvgQty float, MatTargetQty float, TradeChannelTarget FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO @CustMatSales    
	SELECT    
		CustGUID,    
		MatGUID,    
		Count([Month]),    
		Sum(SalesQty),    
		0,    
		0,    
		0,    
		0,    
		BranchGuid    
	FROM    
		@CustMatMonthSales    
	GROUP BY    
		CustGUID,    
		MatGUID,    
		BranchGuid    
	------------------------------   
	INSERT INTO @CustMatSales    
		SELECT    
			0x0,    
			mt.Guid,   
			1,    
			0,	   
			0,    
			0,    
			0,    
			0,    
			@BranchGuid   
		FROM   
			@MatTbl AS mt   
			INNER JOIN mt000 AS mt2 ON mt.Guid = mt2.Guid   
		WHERE	
			mt.Guid NOT IN (SELECT MatGuid FROM @CustMatSales)   
	
	DECLARE @MatSales TABLE (MatGUID UNIQUEIDENTIFIER, CustGUID UNIQUEIDENTIFIER,SalesAvgQty FLOAT, BranchGUID UNIQUEIDENTIFIER)    
	INSERT INTO @MatSales   
	SELECT   
		MatGUID,   
		CustGUID,
		Sum(SalesQty / MonthCount),   
		BranchGuid   
	FROM   
		@CustMatSales   
	GROUP BY   
		MatGUID,CustGUID, BranchGuid   
		
	DECLARE @PeriodsMask INT,
			@C2 CURSOR
	SET @PeriodsMask = 0
	SET @C2 = CURSOR FAST_FORWARD FOR SELECT Guid FROM @PeriodsTbl
	
	OPEN @C2 FETCH FROM @C2 INTO @CPeriodGuid
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @PeriodsMask = @PeriodsMask + [dbo].[fnPowerOf2]([Number] - 1) FROM vwPeriods WHERE Guid = @CPeriodGuid
			FETCH FROM @C2 INTO @CPeriodGuid
		END
    CLOSE @C2 
	DEALLOCATE @C2
	
	INSERT INTO @Result
		SELECT    
			s.[MatGUID],   
			s.[CustGUID],
			s.[SalesAvgQty] AS SalesAvgQty
		FROM   
			@MatSales AS s   
			INNER JOIN fnMtByUnit(1) AS mt ON mt.mtGUID = s.MatGUID
		WHERE CustGUID <> 0x0
		ORDER BY LEN(mt.[mtCode]), mt.[mtCode]   
	
	RETURN
END
####################################################################################################################
#END