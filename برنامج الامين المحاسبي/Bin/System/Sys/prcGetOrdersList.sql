#########################################################################
CREATE PROCEDURE prcGetOrdersList
	@CondGuid [UNIQUEIDENTIFIER] = 0x00  
AS   
/*   
This procedure:   
	- returns Orders numbers according   
	  to a given CondGuid found in bu000   
	- depends on fnGetOrderConditionStr   
*/  	 
	SET NOCOUNT ON   
	   
	DECLARE   
		@HasCond [INT],   
		@Criteria [NVARCHAR](max),   
		@SQL [NVARCHAR](max),   
		@HaveCFldCondition	BIT ,-- to check existing Custom Fields , it must = 1   
		@HaveAddInof Bit -- to check existing Addition Info Of Orders , it must = 1   
	 
	SET @SQL = ' SELECT DISTINCT bu.[BuGuid] AS [Guid], bu.[BuSecurity] AS [Security] '  
	SET @SQL = @SQL + ' FROM [vwExtended_bi] bu ' 	 
  
	IF ISNULL(@CondGUID,0X00) <> 0X00   
	BEGIN   
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER 
		SET @CurrencyGUID = (SELECT TOP 1 [guid] FROM [my000] WHERE [CurrencyVal] = 1) 
		SET @Criteria = [dbo].[fnGetOrderConditionStr]( NULL,@CondGUID,@CurrencyGUID) 
   
		IF @Criteria <> ''   
		BEGIN   
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields   
			BEGIN   
				SET @HaveCFldCondition = 1  				
			END   
			IF (LEFT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Addition Info Of Orders   
			BEGIN   
				SET @HaveAddInof = 1   				
			END 
			if  @HaveCFldCondition = 1 or @HaveAddInof = 1
				SET @Criteria = REPLACE(@Criteria,'<<>>','')  
			SET @Criteria = '(' + @Criteria + ')'
		END 
	END   
	ELSE   
		SET @Criteria = ''   
-------------------------------------------------------------------------------------------------------  
-- Inserting Condition Of Custom Fields   
--------------------------------------------------------------------------------------------------------   
	IF @HaveCFldCondition > 0   
		Begin   
			Declare @CF_Table NVARCHAR(255)   
			SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'bu000') 	  
			SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON bu.BuGuid = ' + @CF_Table + '.Orginal_Guid '   
		End   
-------------------------------------------------------------------------------------------------------  
-- Inserting Condition Of Addition Info Of Orders
-------------------------------------------------------------------------------------------------------
	if  @HaveAddInof > 0
		SET @SQL = @SQL +' INNER JOIN ORADDINFO000 OrAddInfo ON bu.BuGuid = OrAddInfo.ParentGuid  '  
-------------------------------------------------------------------------------------------------------
	SET @SQL = @SQL + '   
		WHERE 1 = 1 '   
	IF @Criteria <> ''   
		SET @SQL = @SQL + ' AND (' + @Criteria + ')'   
	EXEC(@SQL) 
#########################################################################
CREATE PROCEDURE prcGetBudgetbyOrder
	@BillGuid UNIQUEIDENTIFIER = 0x0,
	@GrandTotal FLOAT = 0,
	@AccGuid UNIQUEIDENTIFIER = 0x0,
	@CoGuid UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 
	
	DECLARE @AccountGuid UNIQUEIDENTIFIER, 
			@CostGuid UNIQUEIDENTIFIER, 
			@CostGuid2 UNIQUEIDENTIFIER, 
			@buDir	TINYINT, 
			@buTotal	FLOAT, 
			@Budget		FLOAT, 
			@CNT		TINYINT 
	
	IF (ISNULL(@BillGuid, 0x0) <> 0x0)		 
		SELECT @AccountGuid = buCustAcc ,@CostGuid = buCostPtr FROM vwbu WHERE buGUID = @BillGuid AND buPayType > 0 
	ELSE
	BEGIN
		SET @AccountGuid = @AccGuid
		SET @CostGuid = @CoGuid
	END
	
	SET @buTotal = @GrandTotal	
	SET @CostGuid2 = @CostGuid 
	CREATE TABLE #Cost(G UNIQUEIDENTIFIER,[Level] TINYINT) 
	CREATE TABLE #Acc(G UNIQUEIDENTIFIER,[Level] TINYINT) 
	INSERT #Acc VALUES(@AccountGuid ,0) 
	SET @CNT = 0 
	WHILE @AccountGuid > 0X00 
		BEGIN 
			SELECT @AccountGuid = ParentGuid FROM AC000 WHERE [GUID] = @AccountGuid 
			 
			IF @AccountGuid <> 0X00 
				INSERT INTO #Acc VALUES (@AccountGuid,@CNT) 
			SET @CNT = @CNT + 1 
		END 
	SET @CNT = 0 
	INSERT INTO #Cost VALUES (@CostGuid,0) 
	IF @CostGuid <> 0X00 
	BEGIN 
		WHILE @CostGuid <> 0X00 
		BEGIN 
			SELECT @CostGuid = ParentGuid FROM co000 WHERE [GUID] = @CostGuid 
			 
			IF @CostGuid <> 0X00 
				INSERT INTO #Cost VALUES (@CostGuid,@cnt) 
			SET @CNT = @CNT + 1 
		END 
	END 
	 
	SELECT (abd.debit - abd.Credit) Budget, ac.G accGuid, co.G CostGuid,CAST (ac.G AS NVARCHAR(36)) + CAST (co.G AS NVARCHAR(36)) AccCst 
	INTO #BUGET 
	FROM [ab000] a INNER JOIN [abd000] abd on abd.Parentguid =  A.[GUID]   
	INNER JOIN #Cost co ON co.G = abd.CostGuid 
	INNER JOIN #Acc AC ON ac.G = a.AccGuid 
	IF  @@ROWCOUNT IS NULL 
		RETURN 
	DELETE ac FROM #Acc ac LEFT JOIN #BUGET b ON G = accGuid WHERE accGuid IS NULL 
	DELETE co FROM #Cost co LEFT JOIN #BUGET b ON G = CostGuid WHERE CostGuid IS NULL 
	CREATE TABLE #Account(Acc UNIQUEIDENTIFIER,Parent UNIQUEIDENTIFIER)  
	CREATE TABLE #Costs(cost UNIQUEIDENTIFIER,Parent UNIQUEIDENTIFIER)	 
	SET @CNT = 0 
	DECLARE @MAXCNT TINYINT 
	SELECT @MAXCNT = MAX([Level]) FROM #Acc 
	WHILE @CNT <= @MAXCNT 
	BEGIN 
		SELECT top 1  @AccountGuid = G ,@CNT = [Level] FROM #Acc WHERE [Level] >=  @CNT 
		INSERT INTO #Account SELECT [Guid],@AccountGuid FROM [dbo].[fnGetAccountsList](@AccountGuid,DEFAULT) 
		SET @CNT = @CNT + 1 
	END 
	 
	IF @CostGuid2 <> 0X00 
	BEGIN 
		SET @CNT = 0 
		SELECT @MAXCNT = MAX([Level]) FROM #Cost 
		WHILE @CNT <= @MAXCNT 
		BEGIN 
			SELECT top 1  @CostGuid = G ,@CNT = [Level] FROM #Cost WHERE [Level] >=  @CNT 
			INSERT INTO #Costs SELECT [Guid],@CostGuid FROM [dbo].[fnGetCostsList](@CostGuid) 
			SET @CNT = @CNT + 1 
		END 
	END 
	ELSE  
		INSERT INTO #Costs SELECT 0X00,0X00 
	 
	
	IF EXISTS(SELECT * 
				FROM #BUGET budg 
				LEFT JOIN 
				(	 
				SELECT  SUM(a.Debit - a.Credit) + @buTotal Bal, CAST (acc AS NVARCHAR(36)) + CAST (cost AS NVARCHAR(36)) AccCst 
				FROM en000 a INNER JOIN ce000 c on c.[GUID] =  a.ParentGUID  
				INNER JOIN #Account ON acc = a.AccountGUID 
				INNER JOIN #Costs ON cost = a.CostGuid 
				WHERE C.IsPosted > 0
				GROUP BY acc,cost) B ON budg.AccCst = b.AccCst 
				WHERE (Budget > 0 AND  Budget < (ISNULL(B.Bal,0) + @buTotal)) OR (Budget < 0 AND  Budget > (ISNULL(B.Bal,0) + @buTotal))
			)
	BEGIN
			DECLARE @budgetval FLOAT
			SET @budgetval = (SELECT ABS(abd.debit - abd.Credit)
							  FROM [ab000] a INNER JOIN [abd000] abd on abd.Parentguid =  A.[GUID]
							  WHERE a.AccGuid = @AccountGuid AND abd.CostGuid = @CostGuid)
			
			DECLARE @balval FLOAT
			SET @balval = (SELECT dbo.fnAccount_getBalance(@AccountGuid, 0x0, '1/1/1980', NULL, @CostGuid))
			
			SELECT @balval + @GrandTotal as bal, @budgetval as budget
	END
#########################################################################
#END