######################################################################################################
CREATE PROCEDURE repMaturityBill 
	@StartDate          [DateTime],
	@EndDate            [DateTime],
	@Acc                [UNIQUEIDENTIFIER],
	@Cust               [UNIQUEIDENTIFIER],
	@Src                [UNIQUEIDENTIFIER],
	@Type               [INT],
	-- 0=Maturity Bill, 1=Not Maturity Bill, 2= All Bill  
	@UseDate            [INT],
	-- 0=Use Bill Date, 1=Use Maturity Date,   
	@CurrencyPtr        [UNIQUEIDENTIFIER],
	@CurrencyVal        [FLOAT],
	--@SortBy             [INT],
	@PaidBill           [INT],
	@PartiallyPaid      [INT],
	@BillNoPaid         [INT],
	--@CollectFld         [INT],
	--@TotalByCust        [INT],
	@CostGuid           [UNIQUEIDENTIFIER] = 0x0,
	@BillshaveNoDueDate [BIT] = 0,
	@CustCondGuid       [UNIQUEIDENTIFIER] = 0x0,
	@Lang               [BIT] = 0,
	@ShowFlag           [INT] = 0,
	@BillCond           [UNIQUEIDENTIFIER] = 0x0,
	@VeiwCFlds          [NVARCHAR](max) = '', -- New Parameter to check veiwing of Custom Fields
	@InOut				[INT] , 
	@ShowFromFirstBill	[BIT] = 0 ,
	@ShowMaturityWithDaysLess [BIT] = 0 , 
	@MaturityNumDays	[INT] = 0
AS
    SET NOCOUNT ON

    DECLARE @Sql      NVARCHAR(4000),
            @Criteria NVARCHAR(4000),
            @CF_Table NVARCHAR(255) -- For Custom Field
    SET @Criteria = ''
    SET @Sql = ''
    SET @CF_Table = ''

    -------Bill Resource ---------------------------------------------------------------------- 
    CREATE TABLE [#Src]
      (
         [Type]       [UNIQUEIDENTIFIER],
         [Sec]        [INT],
         [ReadPrice]  [INT],
         [UnPostedSec][INT]
      )

    INSERT INTO [#Src]
    EXEC [prcGetBillsTypesList2]
      @Src

    -------Accounts List----------------------------------------------------------------------- 
    CREATE TABLE [#Cust_Tbl]
      (
         [GUID]     [UNIQUEIDENTIFIER],
         [Security] [INT]
      )

    INSERT INTO [#Cust_Tbl]
    EXEC [prcGetCustsList]
      @Cust,
      @Acc,
      @CustCondGuid

    SELECT [customerName] [cuCustomerName],
           [LatinName]    [cuLatinName],
           [accountGUID],
           c.*
    INTO   [#Cust_Tbl2]
    FROM   [cu000] cu
           INNER JOIN [#Cust_Tbl] C
                   ON c.[Guid] = [cu].[Guid]

    -------------------------------------------------------------------------------------------- 
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] [UNIQUEIDENTIFIER],
         [Security] [INT]
      )

    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostGUID

    SELECT [CostGUID],
           a.[Security],
           co.Code + '-' + CASE @Lang WHEN 0 THEN [Name] ELSE CASE ISNULL([LatinName],'')
           WHEN
           '' THEN
           [Name] ELSE [LatinName] END END AS [coName]
    INTO   [#CostTbl2]
    FROM   [#CostTbl] A
           INNER JOIN [Co000] co
                   ON co.Guid = [CostGUID]

    IF ( @CostGUID = 0x0 )
      INSERT INTO [#CostTbl2]
      VALUES     (0x0,
                  0,
                  CONVERT(VARCHAR(250), '')) 

    --------------------------------------------------------------------------------------------  
    CREATE TABLE [#SecViol]
      (
         [Type] [INT],
         [Cnt]  [INT]
      )

    -------------------------------------------------------------------------------------------- 
    CREATE TABLE [#Result]
      (
         [BillGuid]     [UNIQUEIDENTIFIER],
         [BillNum]      [INT],
         [BillDate]     [DateTime],
         [CustGuid]     [UNIQUEIDENTIFIER],
         [CustName]     [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [CustLName]    [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [BillTotal]    [FLOAT],
         [MaturityDate] [DateTime],
         [DebtVal]      [FLOAT] DEFAULT 0,
         [CustSecurity] [INT],
         [Security]     [INT],
         [UserSecurity] [INT],
         [Type]         [INT],
         [CostGuid]     [UNIQUEIDENTIFIER],
         [CostCodeName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [BranchName]   [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [brGuid]       [UNIQUEIDENTIFIER],
         [Dir]          [INT],
         bHasTTC        [BIT],
         [Vendor]       [FLOAT],
         [SalesMan]     [FLOAT],
         CurrGuid       [UNIQUEIDENTIFIER],
         CurVal         [FLOAT],
		 PaymentGuid	[UNIQUEIDENTIFIER],
		 PaymentNumber	[INT] , 
		 TypeGUID [UNIQUEIDENTIFIER] DEFAULT 0x0 , 
		 [State]	[TINYINT]
      )

    CREATE TABLE [#EndResult]
      (
         [BillGuid]        [UNIQUEIDENTIFIER],
		 [BillType]		   [UNIQUEIDENTIFIER],
         [BillNum]         [INT],
         [BillDate]        [DateTime],
         [CustGuid]        [UNIQUEIDENTIFIER],
         [CustName]        [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [CustLName]       [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [MaturityNumDays] [INT],
         [BillTotal]       [FLOAT],
         [MaturityDate]    [DateTime],
         [DebtVal]         [FLOAT] DEFAULT 0,
         [Type]            [INT],
         [CostGuid]        [UNIQUEIDENTIFIER],
         [CostCodeName]    [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [BranchName]      [NVARCHAR](255) COLLATE ARABIC_CI_AI,
         [brGuid]          [UNIQUEIDENTIFIER],
         [Dir]             [INT],
         [Vendor]          [FLOAT],
         [SalesMan]        [FLOAT],
         [CurrGuid]        [UNIQUEIDENTIFIER],
         [CurVal]          [FLOAT],
		 PaymentNumber		[INT],
		 [State]	[TINYINT]
      )

    SET DATEFIRST 5

    DECLARE @FirstPeriod [DATETIME]

    SET @FirstPeriod = [dbo].[fnDate_Amn2Sql](
                       [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
    SET @Sql = 'INSERT INTO [#Result] '

    IF @BillCond = 0x0
     BEGIN
         SET @Sql = @Sql + 'SELECT   
				[ptRefGuid],  
				CAST(ptTransferedInfo AS XML).value(''/Number[1]'',''INT''), 
                CAST(ptTransferedInfo AS XML).value(''/Date[1]'',''DATE''),   
				[cu].[GUID] AS [CustGuid],  
				[cu].[cuCustomerName] AS [CustName],  
				[cu].[cuLatinName] AS [CustLName],
				CAST(ptTransferedInfo AS XML).value(''/Total[1]'',''FLOAT'') AS [Total]  , 
				[ptDueDate], 
				CAST(ptTransferedInfo AS XML).value(''/Total[1]'',''FLOAT'') - 
				( CASE [ptDebit] WHEN 0 THEN [ptCredit] ELSE [ptDebit] END ) + ISNULL(bp.Val,0),
				[cu].[Security], 
				0,			 
				0,
				1,
				[CostGUID],
				[coName],
				CONVERT(VARCHAR(250), ''''),
				[ceBranch],
				CASE [ptDebit]
					WHEN 0 THEN 1 
					ELSE -1 
				END, 
				0,
				0,
				0,
				0x0,
				0,
				0x0,
				0 , 
				[ptTypeGUID] ,
				1
			FROM 
				[vwPt] AS [pt]   	 
				INNER JOIN [#Cust_Tbl2] AS [cu] ON [accountguid] = [pt].[ptCustAcc] 
				INNER JOIN [#Src] AS [Src] ON [pt].[ptTypeGuid] = [Src].[Type]  
				INNER JOIN [vwCeEn] [ce] ON ce.ceGuid = ptRefGuid 
				INNER JOIN [#CostTbl2] [co] ON [enCostPoint] = [CostGUID] 
				LEFT JOIN (
				SELECT  DebtGUID ,  SUM(Val) AS Val FROM 
					(
						SELECT DebtGUID , Val FROM bp000 bp 
						UNION ALL 
						SELECT PayGUID , Val  FROM bp000 bp 
					) t
					GROUP BY DebtGUID
				) bp ON bp.DebtGUID = enGUID
			WHERE
				[ptTransfered] = 1 
				AND [enAccount] = [pt].[PTCustAcc] 
				AND [cu].[GUID]= [ce].[enCustomerGUID]'
		IF @UseDate = 1
		BEGIN 
			SET @Sql = @Sql + 'AND  CAST(ptTransferedInfo AS XML).value(''/Date[1]'',''DATE'') '
			IF @ShowFromFirstBill = 0		 
                 SET @Sql = @Sql +  ' BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)
			ELSE 
				SET @Sql = @Sql + ' <= ' + [dbo].[fnDateString](@EndDate)
		END

		IF  @ShowMaturityWithDaysLess = 0
		BEGIN 
			IF @Type = 1
				SET @Sql = @Sql + ' AND [ptDueDate] > ' + [dbo].[fnDateString](@EndDate)
			ELSE IF @Type = 0
			BEGIN
				IF @ShowFromFirstBill = 0
					SET @Sql = @Sql + 'AND  [ptDueDate] BETWEEN '
                  + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)
				ELSE
					SET @Sql = @Sql + ' AND [ptDueDate] <= ' + [dbo].[fnDateString](@EndDate) 
			END 
			ELSE IF @Type = 2  AND @ShowFromFirstBill = 0
			BEGIN  
				SET @Sql = @Sql + ' AND [ptDueDate] >= ' + [dbo].[fnDateString](@StartDate)
			END
		END 
		ELSE 
		BEGIN 
			SET @Sql = @Sql + ' AND  DATEDIFF(D, ' + + [dbo].[fnDateString](@EndDate) + ', [ptDueDate]) <= ' + CAST(@MaturityNumDays AS NVARCHAR(6)) 
		END
		
        SET @Sql = @Sql + ' UNION ALL '
     END

    SET @Sql = @Sql + ' SELECT
			[fnEx].[buGUID] AS [BillGuid],  
			[fnEx].[buNumber] AS [BillNum],  
			[fnEx].[buDate] AS [BillDate],  
			[fnEx].[buCustPtr] AS [CustGuid],  
			[cu].[cuCustomerName] AS [CustName],  
			[cu].[cuLatinName] AS [CustLName], 
			ISNULL(orp.UpdatedValue , (
				[fnEx].[FixedBuTotal] - [fnEx].[FixedbuItemsDisc] + 
				(	
					(- [fnEx].[BuBonusDisc]+ ' + CASE @BillCond WHEN 0x0
               THEN
               '[fnEx].[buItemExtra]' ELSE '[fnEx].[buItemsExtra]' END
               +
') * FixedCurrencyFactor
				) + [fnEx].[FixedBuVat] + 
			ISNULL(
				(SELECT SUM(
					(di.Extra * [dbo].[fnCurrency_fix](1, di.CurrencyGUID, di.CurrencyVal, '''
           + Cast(@CurrencyPtr AS NVARCHAR(36))
           +
''', bu.Date))
					-
					(di.Discount * [dbo].[fnCurrency_fix](1, di.CurrencyGUID, di.CurrencyVal, '''
           + Cast(@CurrencyPtr AS NVARCHAR(36))
           + ''', bu.Date))
				)
				FROM di000 di join bu000 bu on bu.GUID = di.ParentGUID
				WHERE di.parentGUID = [buGUID] AND (di.[ContraAccGuid] = 0x0 OR di.[ContraAccGuid] = [cu].[accountguid]))
				, 0)
			)) AS [BillTotal],
			ISNULL(orp.DueDate, ISNULL([ptDueDate], [fnEx].[buDate])), 
			0 AS [DebtVal],
			[cu].[Security],
			[fnEx].[buSecurity],
			CASE
				[fnEx].[buIsPosted] 
				WHEN 1 THEN [Src].[Sec] 
				ELSE [Src].[UnPostedSec] 
			END,
			0,
			[CostGUID],
			[coName],
			CONVERT(VARCHAR(250),''''),
			[buBranch],
			[btDirection], 
			CASE
				btVatSystem 
				WHEN 2 THEN 1 
				ELSE 0 
			END,
			[buVendor],
			[buSalesmanptr],
			[buCurrencyPtr],
			[buCurrencyVal],
			ISNULL(orp.PaymentGUID, 0x0),
			ISNULL(orp.PaymentNumber, 0),
			[buType],
			0
		FROM '

    IF @BillCond = 0x0
      SET @Sql = @Sql + '[dbo].[fnBu_Fixed]'
    ELSE
      SET @Sql = @Sql + 'fn_bubi_Fixed'

    SET @Sql = @Sql + '( '''
               + Cast(@CurrencyPtr AS NVARCHAR(36))
               +
    ''') AS [fnEx]  
			INNER JOIN [#Cust_Tbl2] AS [cu] ON [fnEx].[buCustPtr] = [cu].[GUID]  
			INNER JOIN [#CostTbl2] [co] ON [buCostPtr] = [CostGUID] 
			INNER JOIN [#Src] AS [Src] ON [fnEx].[buType] = [Src].[Type]  
			LEFT JOIN [vwOrderPayments] AS [orp] ON [orp].[BillGUID] = [fnEx].[buGUID]
			LEFT JOIN [vwPt] AS [pt] ON [fnEx].[buGUID] = [pt].[ptRefGUID]'

    -------------------------------------------------------------------------------------------------------
    -- to check existing Custom Filed and extracting Condition Criteria
    -------------------------------------------------------------------------------------------------------
    DECLARE @HaveCFldCondition INT

    SET @HaveCFldCondition = 0

    IF @BillCond <> 0x0
      BEGIN
          SET @Criteria = [dbo].[fnGetBillConditionStr](NULL, @BillCond,
                          @CurrencyPtr)

          IF @Criteria <> ''
            BEGIN
                IF ( RIGHT(@Criteria, 4) = '<<>>' )
                  -- <<>> to Aknowledge Existing Custom Fields 
                  BEGIN
                      SET @HaveCFldCondition = 1
                      SET @Criteria = Replace(@Criteria, '<<>>', '')
                  END

                SET @Criteria = '(' + @Criteria + ')'
            END
      END

    -------------------------------------------------------------------------------------------------------
    -- Inserting Condition Of Custom Fields 
    -------------------------------------------------------------------------------------------------------- 
    IF @HaveCFldCondition = 1
        OR @VeiwCFlds <> ''
      SET @CF_Table = (SELECT CFGroup_Table
                       FROM   CFMapping000
                       WHERE  Orginal_Table = 'bu000')

    IF @HaveCFldCondition = 1
      SET @Sql = @Sql + ' INNER JOIN ' + @CF_Table
                 + ' ON [fnEx].[buGUID] = ' + @CF_Table
                 + '.Orginal_Guid '

    -------------------------------------------------------------------------------------------------------
    SET @Sql = @Sql + 'WHERE [bupayType] = 1 '

	IF @UseDate = 1
		IF @ShowFromFirstBill = 0
			SET @Sql = @Sql + 'AND  [fnEx].[buDate] BETWEEN  '
				+ [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate)
		ELSE 
			SET @Sql = @Sql + 'AND  [fnEx].[buDate] < ' + [dbo].[fnDateString](@EndDate) 


		IF  @ShowMaturityWithDaysLess = 0
		BEGIN 
			IF @Type = 1
				SET @Sql = @Sql + ' AND ISNULL([ptDueDate],[fnEx].[buDate]) > ' + [dbo].[fnDateString](@EndDate)
			ELSE IF @Type = 0
			BEGIN
				IF @ShowFromFirstBill = 1
					SET @Sql = @Sql + ' AND  ISNULL([ptDueDate],[fnEx].[buDate]) BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) 
				ELSE
					SET @Sql = @Sql + ' AND ISNULL([ptDueDate],[fnEx].[buDate]) <= ' + [dbo].[fnDateString](@EndDate) 
			END	
			ELSE IF @Type = 2  AND @ShowFromFirstBill = 0
			BEGIN  
				SET @Sql = @Sql + ' AND ISNULL([ptDueDate],[fnEx].[buDate]) >= ' + [dbo].[fnDateString](@StartDate)
			END		
		END 
		ELSE 
		BEGIN 
			SET @Sql = @Sql + ' AND  DATEDIFF(D,' + [dbo].[fnDateString](@EndDate) + ' , ISNULL([ptDueDate],[fnEx].[buDate])) <= ' + CAST(@MaturityNumDays AS NVARCHAR(6))
		END

    IF @BillshaveNoDueDate <> 1
      SET @Sql = @Sql + ' AND ptGuid IS NOT NULL'

    IF @Criteria <> ''
      SET @Criteria = ' AND (' + @Criteria + ')'

    SET @Sql = @Sql + @Criteria

    EXEC (@Sql)

    UPDATE b
    SET    [BillTotal] = [BillTotal] - V
    FROM   [#Result] [b]
           INNER JOIN (SELECT Sum(( Discount + BonusDisc ) * VATRatio / 100) V,
                              parentGUID
                       FROM   bi000
                       GROUP  BY parentGUID) Q
                   ON Q.parentGUID = [BillGuid]
    WHERE  bHasTTC = 1

    DELETE [#Result]
    WHERE  [BillTotal] < dbo.fnGetZeroValuePrice()

    -------------------------------------------------------------------------------	 
    EXEC [prcCheckSecurity]

    IF ( @ShowFlag & 0X00002 ) > 0
      UPDATE [r]
      SET    [BranchName] = b.[Name]
      FROM   [#Result] [r]
             INNER JOIN [Br000] b
                     ON b.[Guid] = [brGuid]

    ------------------------------------------------------------------------------- 
    UPDATE [Res]
    SET    [DebtVal] = ISNULL([BillDebt].[DebtVal], Res.[DebtVal])
    FROM   (SELECT	[r].[BillGUID] AS [BillGUID],
					ISNULL([r].[PaymentGUID], 0x0) AS [PaymentGUID], 
					Sum([BpDebt].[FixedBpVal]) AS [DebtVal]
            FROM	[#Result] [r]
					LEFT JOIN vwOrderPayments orp ON orp.BillGuid = r.BillGuid AND orp.[PaymentGUID] = r.[PaymentGUID]
					LEFT JOIN [dbo].[fnBp_Fixed](@CurrencyPtr, @CurrencyVal) AS [BpDebt] ON 
						ISNULL(orp.PaymentGUID, [r].[BillGUID]) = [BpDebt].[BpDebtGUID]
                        OR 
						ISNULL(orp.PaymentGUID, [r].[BillGUID]) = [BpDebt].[BpPayGUID]
            GROUP  BY [r].[BillGUID], [r].[PaymentGUID]) AS [BillDebt]
           INNER JOIN [#Result] AS [Res]
                   ON [Res].[BillGUID] = [BillDebt].[BillGUID] AND [Res].[PaymentGUID] = [BillDebt].[PaymentGUID]

    SELECT DISTINCT r.BillGuid AS BillGuid
    INTO   #Bills
    FROM   [#Result] r
           INNER JOIN [ori000] ori
                   ON ori.BuGuid = r.BillGuid
           INNER JOIN [oit000] oit
                   ON oit.[GUID] = ori.TypeGUID
           INNER JOIN vwOrderPayments orp
                   ON orp.BillGuid = ori.POGUID
           INNER JOIN bp000 bp
                   ON bp.DebtGUID = orp.PaymentGuid
                       OR bp.PayGUID = orp.PaymentGuid
	WHERE ori.Qty > 0 AND oit.QtyStageCompleted = 1

    IF EXISTS(SELECT *
              FROM   #Bills)
      BEGIN
          UPDATE r
          SET    [DebtVal] = dbo.fnBillOfOrder_GetPaiedValue(r.BillGuid)
          FROM   [#Result] r
                 INNER JOIN #Bills bills
                         ON bills.BillGuid = r.BillGuid
      END

    -------------------------------------------------------------------------------- 
    INSERT INTO [#EndResult]
                ([BillGuid],
				 [BillType],
                 [BillNum],
                 [BillDate],
                 [CustGuid],
                 [CustName],
                 [CustLName],
                 [BillTotal],
                 [MaturityDate],
                 [DebtVal],
                 [Type],
                 [CostGuid],
                 [CostCodeName],
                 [BranchName],
                 [brGuid],
                 [Dir],
                 [Vendor],
                 [SalesMan],
                 [CurrGuid],
                 [CurVal],
				 [PaymentNumber],
				 [State])
    SELECT [Res].[BillGuid],
		   [Res].[TypeGUID],
           [Res].[BillNum],
           [Res].[BillDate],
           [Res].[CustGuid],
           [Res].[CustName],
           [Res].[CustLName],
           [Res].[BillTotal],
           [Res].[MaturityDate],
           [Res].[DebtVal],
           [Res].[Type],
           [Res].[CostGuid],
           [Res].[CostCodeName],
           [Res].[BranchName],
           [Res].[brGuid],
           CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [Res].[Dir] WHEN 2 THEN (-[Res].[Dir]) END DIR,
           [Res].[Vendor],
           [Res].[Salesman],
           [Res].CurrGuid,
           [Res].CurVal,
		   0,
		   [Res].[State]
    FROM   [#Result] AS [Res] LEFT JOIN bu000 bu ON [Res].[BillGuid] = bu.[GUID]
    WHERE 
		(@PaidBill = 1 AND CAST(([Res].[BillTotal] - ISNULL( [Res].[DebtVal],0)) AS MONEY) = 0) 
		OR (@PartiallyPaid = 1 AND [Res].[DebtVal] <> 0 AND (CAST([Res].[BillTotal] AS MONEY) - CAST(ISNULL( [Res].[DebtVal],0) AS MONEY) ) > 0)
		OR (@BillNoPaid = 1 AND [Res].[DebtVal] = 0) 
    GROUP  BY [Res].[BillGuid],
              [Res].[BillNum],
              [Res].[BillDate],
              [Res].[CustGuid],
              [Res].[CustName],
              [Res].[CustLName],
              [Res].[BillTotal],
              [Res].[MaturityDate],
              [Res].[DebtVal],
              [Res].[Type],
              [Res].[CostGuid],
              [Res].[CostCodeName],
              [Res].[BranchName],
              [Res].[brGuid],
              [Res].[Dir],
              [Res].[Vendor],
              [Res].[Salesman],
              [Res].CurrGuid,
              [Res].CurVal,
			  [Res].PaymentGUID,
			  [Res].[PaymentNumber],
			  [Res].[TypeGUID],
			  [Res].[State]
    UPDATE e
    SET    MaturityNumDays = days
    FROM   pt000 pt
           INNER JOIN #EndResult e
                   ON e.CustGUID = pt.RefGUID

	UPDATE #EndResult
	SET [BillGuid] = 0x0 
	WHERE [State] = 1


                SET @Sql = @Sql + '  SELECT bt.Abbrev , ERes.*'

                ------------------------------------------------------------------------------------------------------- 
                -- Checked if there are Custom Fields to View  	 
                ------------------------------------------------------------------------------------------------------- 
                IF @VeiwCFlds <> ''
                  SET @Sql = @Sql + @VeiwCFlds

                IF ( ( @ShowFlag & 0X00010 ) > 0 )
                  SET @Sql = @Sql + ',ISNULL(m.Code, CONVERT(VARCHAR(250), '''')) myCode'

                ------------------------------------------------------------------------------------------------------
                SET @Sql = @Sql + ' FROM  [#EndResult] ERes LEFT JOIN bt000 bt ON ERes.BillType = bt.GUID'

                ------------------------------------------------------------------------------------------------------- 
                -- Custom Fields to View  	 
                -------------------------------------------------------------------------------------------------------- 
                IF @VeiwCFlds <> ''
                  SET @Sql = @Sql + ' LEFT JOIN ' + @CF_Table
                             + ' ON [ERes].[BillGuid] = ' + @CF_Table
                             + '.Orginal_Guid '

                IF ( ( @ShowFlag & 0X00010 ) > 0 )
                  SET @Sql = @Sql
                             + ' LEFT JOIN [my000] m ON m.Guid = CurrGuid'

                -------------------------------------------------------------------------------------------------------   
                SET @Sql = @Sql
                           +
                ' ORDER BY  [BillNum]'


    EXEC (@Sql) 
######################################################################################################
#END