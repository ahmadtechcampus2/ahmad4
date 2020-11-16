######################################################### 
CREATE PROC prcBill_delete
	@GUID [UNIQUEIDENTIFIER]
AS
/*
this procedure:
	- is responsible for deleting a bill
	- unposts before deleting
	- depends on triggers to do related cleaning
*/
	SET NOCOUNT ON
	-- unpost first:
	UPDATE [bu000] SET [IsPosted] = 0 FROM [bu000] WHERE [GUID] = @GUID

	-- delete bill:
	DELETE [bu000] WHERE [GUID] = @GUID
#########################################################
CREATE PROCEDURE prcGetBudgetbyBill
	@BillGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	DECLARE @AccountGuid UNIQUEIDENTIFIER,
			@CostGuid UNIQUEIDENTIFIER,
			@CostGuid2 UNIQUEIDENTIFIER,
			@buDir	TINYINT,
			@buTotal	FLOAT,
			@Budget		FLOAT,
			@CNT		TINYINT
			
	SELECT @AccountGuid = buCustAcc ,@CostGuid = buCostPtr,@buTotal = (buTotal - buTotalDisc + buTotalExtra + buVAT ) * -1 * btDirection FROM vwbu WHERE buGUID = @BillGuid AND buPayType > 0
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
	
	IF EXISTS(SELECT
			*
			FROM #BUGET budg
			LEFT JOIN
			(	
			SELECT  SUM(a.Debit - a.Credit) + @buTotal Bal,CAST (acc AS NVARCHAR(36)) + CAST (cost AS NVARCHAR(36)) AccCst
			FROM en000 a INNER JOIN ce000 c on c.[GUID] =  a.ParentGUID 
			INNER JOIN #Account ON acc = a.AccountGUID
			INNER JOIN #Costs ON cost = a.CostGuid
			WHERE C.IsPosted > 0
			GROUP BY acc,cost) B ON budg.AccCst = b.AccCst
			WHERE (Budget > 0 AND  Budget < (ISNULL(B.Bal,0) + @buTotal)) OR (Budget < 0 AND  Budget > (ISNULL(B.Bal,0) + @buTotal)))
		SELECT 1 AS res
#########################################################
CREATE PROCEDURE prcCheckBillLessMinPrice
	@User UNIQUEIDENTIFIER,
	@Bill UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	DECLARE @Price INT,@Date SMALLDATETIME
	SET @Price =  ( SELECT [dbo].[fnGetMinPrice]( @Bill, @User))
	IF @Price = 1 
		RETURN
	DECLARE @bi TABLE(MatGuid UNIQUEIDENTIFIER,Number INT,Unity TINYINT ,price FLOAT)
	INSERT INTO @bi SELECT MatGuid,Number,Unity,price FROM bi000 WHERE ParentGUID = @Bill 
	SELECT @Date = [Date] FROM bu000 WHERE GUID = @Bill
	SELECT Code,Name
	FROM 
	(
		SELECT bi.MatGuid,bi.Number FROM @bi bi INNER JOIN [dbo].[fnExtended_mt](@Price, 121, 0) m  on m.mtGUID = bi.MatGuid WHERE Unity = 1 AND bi.Price < m.[Price]
		UNION ALL
		SELECT bi.MatGuid,bi.Number FROM @bi bi INNER JOIN [dbo].[fnExtended_mt](@Price, 121, 1) m  on m.mtGUID = bi.MatGuid WHERE Unity = 2 AND bi.Price < m.[Price]
		UNION ALL
		SELECT bi.MatGuid,bi.Number FROM @bi bi INNER JOIN [dbo].[fnExtended_mt](@Price, 121, 2) m  on m.mtGUID = bi.MatGuid WHERE Unity = 3 AND bi.Price < m.[Price]
	 
	)a INNER JOIN mt000 mt ON mt.[Guid] = MatGuid
#########################################################
CREATE PROCEDURE prcCheckAccountBudgetExceed
	@AccountGuid UNIQUEIDENTIFIER,  
	@CostGuid    UNIQUEIDENTIFIER,  	
	@CurrGuid    UNIQUEIDENTIFIER,  
	@GrandTotal  FLOAT,  
	@BillType    INT
AS   
	SET NOCOUNT ON
	
	DECLARE @AllEntriesBal FLOAT
	DECLARE @BillsWithNoEntriesBal FLOAT
	DECLARE @AccBalance FLOAT
    DECLARE @NewBalance FLOAT 
    DECLARE @AccBudget FLOAT
    
	--///////////////////////////////////
	-- ÝÍÕ ÇáãæÇÒäÉ Ýí ÈØÇÞÉ ÇáÍÓÇÈ
	--///////////////////////////////////
	
	-------------------------------
	-- ÇáÓäÏÇÊ ÇáãÑÍáÉ æÛíÑ ÇáãÑÍáÉ
	SELECT @AllEntriesBal = ISNULL(SUM(CASE ISNULL(@CurrGuid, 0x0)
	                              WHEN 0x0 THEN ([e].[debit] - [e].[credit])
	                              ELSE [dbo].[fnCurrency_fix]([e].[debit] - [e].[credit], [e].[currencyGuid], [e].[currencyVal], @CurrGuid, [e].[date])
	                           END)
	                           , 0
	                           )
	FROM 
	    [en000] [e] 
	    inner join [ce000] [c] ON [e].[parentGuid] = [c].[guid] 
	    inner join [fnGetAccountsList](@AccountGuid, 0) [f] ON [e].[accountGuid] = [f].[guid] 
	-------------------------------
	
	-------------------------------
	-- ÇáÝæÇÊíÑ ÇáÊí áã íæáÏ áåÇ ÞíÏ æäãØåÇ íæáÏ ÞíÏ
	SELECT @BillsWithNoEntriesBal = ISNULL(SUM(dbo.fnCurrency_Fix(CASE bt.bIsOutput 
	                                                            WHEN 1 THEN (bu.Total+bu.TotalExtra-bu.TotalDisc+bu.VAT)
	                                                            ELSE -(bu.Total+bu.TotalExtra-bu.TotalDisc+bu.VAT)
	                                                        END,
	                                                        bu.CurrencyGuid,
	                                                        bu.CurrencyVal,
	                                                        @CurrGuid,
	                                                        bu.Date
	                                                        ) 
	                                            ), 0
	                                       )
    FROM 
        bt000 bt
        INNER JOIN bu000 bu ON bt.Guid = bu.TypeGuid
    WHERE
        bt.bNoEntry = 0 
        AND bt.bAutoEntry = 0
        AND bu.CustAccGuid = @AccountGuid
	
	SET @AccBalance = @AllEntriesBal + @BillsWithNoEntriesBal  
       
    SET @NewBalance = @AccBalance + CASE @BillType WHEN 1 THEN @GrandTotal WHEN 2 THEN -@GrandTotal ELSE 0 END	  
    
    SELECT @AccBudget = (CASE @BillType   
                             WHEN 1 THEN (CASE ac.Warn WHEN 1 THEN dbo.fnCurrency_Fix(ac.MaxDebit, ac.CurrencyGUID, ac.CurrencyVal, @CurrGuid, NULL) ELSE 0 END)  
                             WHEN 2 THEN (CASE ac.Warn WHEN 2 THEN -dbo.fnCurrency_Fix(ac.MaxDebit, ac.CurrencyGUID, ac.CurrencyVal, @CurrGuid, NULL) ELSE 0 END)                               
                         END)  
    FROM ac000 ac 
    WHERE Guid = @AccountGuid
    
    IF ((@AccBudget > 0 AND @AccBudget < @NewBalance) OR (@AccBudget < 0 AND @AccBudget > @NewBalance))
    BEGIN
		SELECT 1 AS test, @AccBalance AS AccBalance, @AccBudget AS AccBudget, @NewBalance AS NewBalance
		,CASE ac.Warn WHEN 0 THEN 0 ELSE 1 END AS Warn
			FROM ac000 ac 		 
			WHERE Guid = @AccountGuid
		RETURN
	END
	
	--///////////////////////////////////
	-- ÝÍÕ ÇáãæÇÒäÉ Ýí ÈØÇÞÉ ãæÇÒäÉ
	--///////////////////////////////////
    IF @CostGuid IS NOT NULL
    BEGIN
	    -------------------------------
	    -- ÇáÓäÏÇÊ ÇáãÑÍáÉ æÛíÑ ÇáãÑÍáÉ
	    SELECT @AllEntriesBal = ISNULL(SUM(CASE ISNULL(@CurrGuid, 0x0)
	                                  WHEN 0x0 THEN ([e].[debit] - [e].[credit])
	                                  ELSE [dbo].[fnCurrency_fix]([e].[debit] - [e].[credit], [e].[currencyGuid], [e].[currencyVal], @CurrGuid, [e].[date])
	                               END)
	                               , 0
	                               )
	    FROM 
	        [en000] [e] 
	        inner join [ce000] [c] ON [e].[parentGuid] = [c].[guid]
	    WHERE 
	        e.AccountGuid = @AccountGuid
	        AND e.CostGuid = @CostGuid
	    -------------------------------
    	
	    -------------------------------
	    -- ÇáÝæÇÊíÑ ÇáÊí áã íæáÏ áåÇ ÞíÏ æäãØåÇ íæáÏ ÞíÏ
	    SELECT @BillsWithNoEntriesBal = ISNULL(SUM(dbo.fnCurrency_Fix(CASE bt.bIsOutput 
	                                                                WHEN 1 THEN (bu.Total+bu.TotalExtra-bu.TotalDisc+bu.VAT)
	                                                                ELSE -(bu.Total+bu.TotalExtra-bu.TotalDisc+bu.VAT)
	                                                            END,
	                                                            bu.CurrencyGuid,
	                                                            bu.CurrencyVal,
	                                                            @CurrGuid,
	                                                            bu.Date
	                                                            ) 
	                                                ), 0
	                                           )
        FROM 
            bt000 bt
            INNER JOIN bu000 bu ON bt.Guid = bu.TypeGuid
        WHERE
            bt.bNoEntry = 0 
            AND bt.bAutoEntry = 0
            AND bu.CustAccGuid = @AccountGuid
            AND bu.CostGuid = @CostGuid
    	
	    SET @AccBalance = @AllEntriesBal + @BillsWithNoEntriesBal  
           
        SET @NewBalance = @AccBalance + CASE @BillType WHEN 1 THEN @GrandTotal WHEN 2 THEN -@GrandTotal ELSE 0 END	  
        
        SELECT 
	        @AccBudget = (abd.debit - abd.Credit)
	    FROM 
	        [ab000] ab 
	        INNER JOIN [abd000] abd on abd.Parentguid =  ab.[GUID]    
	    WHERE 
	        abd.CostGuid = @CostGuid
	        AND ab.AccGuid = @AccountGuid
    	    
	    IF @AccBudget IS NULL  
		    RETURN
    	 
	    IF ((@AccBudget > 0 AND @AccBudget < @NewBalance) OR (@AccBudget < 0 AND @AccBudget > @NewBalance))
        BEGIN
		    SELECT 2 AS test, @AccBalance AS AccBalance, @AccBudget AS AccBudget, @NewBalance AS NewBalance
			,CASE ac.Warn WHEN 0 THEN 0 ELSE 1 END AS Warn
				FROM ac000 ac 		 
				WHERE Guid = @AccountGuid
		    RETURN
	    END
    END    
#########################################################
CREATE PROCEDURE prcCheckIfAccExceededBalance
	@BillValue FLOAT,
	@AccountGuid UNIQUEIDENTIFIER,
	@IsInput BIT
AS
	SET NOCOUNT ON 
	
		IF EXISTS(SELECT * FROM ac000 WHERE Guid = @AccountGuid AND Warn > 0)
		BEGIN
			DECLARE @oldDebit FLOAT, @oldCredit FLOAT, @newDebit FLOAT, @newCredit FLOAT;

			SET @oldDebit = 0;
			SET @oldCredit = 0;

			SELECT
				@oldDebit = SUM(en.Debit),
				@oldCredit = SUM(en.Credit)
			FROM 
				ce000 ce
				INNER JOIN en000 en ON ce.Guid = en.ParentGuid
			WHERE 
				ce.IsPosted = 0
				AND 
				AccountGuid = @AccountGuid
			GROUP BY 
				en.AccountGUID;

			IF @IsInput = 1
				SET @oldCredit = ISNULL(@oldCredit, 0) + @BillValue;
			ELSE
				SET @oldDebit = ISNULL(@oldDebit, 0) + @BillValue;

			IF EXISTS(SELECT * FROM ac000 ac WHERE Guid = @AccountGuid AND CASE [ac].[Warn] 
							WHEN 1 THEN ISNULL((([ac].[Debit]+@oldDebit) - ([ac].[Credit]+@oldCredit)), 0) 
							ELSE ISNULL((([ac].[Credit]+@oldCredit) - ([ac].[Debit]+@oldDebit)), 0) 
						END > MaxDebit)
				BEGIN
					INSERT INTO [ErrorLog] ([level], [type], [c1], [g1])
						SELECT 2, 0, 
						'AmnW0055: ' 
						+ CAST(ISNULL(@AccountGuid, 0x0) AS NVARCHAR(36)) 
						+ ' Account exceeded its Max Balance: [' + CAST(MaxDebit AS NVARCHAR)
							+ '] by: [' 
						+ CAST((   (CASE [ac].[Warn] 
							WHEN 1 THEN ISNULL((([ac].[Debit]+@oldDebit) - ([ac].[Credit]+@oldCredit)), 0) 
							ELSE ISNULL((([ac].[Credit]+@oldCredit) - ([ac].[Debit]+@oldDebit)), 0) 
						END)
							- [MaxDebit]) AS NVARCHAR) + ']',0x0 guid FROM ac000 ac WHERE ac.Guid = @AccountGuid
				END
		END
#########################################################
CREATE PROCEDURE prcGetBillsOfMat
	@BillType int
AS
	SET NOCOUNT ON 
	select mt.mtGUID
	from vwMt mt 
	inner JOIN vwbubi AS b  ON b.biMatPtr = mt.mtGUID and b.buGUID = b.biParent
	inner JOIN vwbt	  AS bt ON bt.btGUID = b.buType   and b.btBillType=@BillType
		
#########################################################
CREATE PROCEDURE prcDeleteOldAssets
	@BillGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON 
	DELETE ad FROM ad000 ad LEFT JOIN snt000 snt on ad.SnGuid = snt.ParentGUID
    WHERE  ad.BillGUID = @BillGuid AND snt.buGUID IS NULL
		
#########################################################
CREATE PROCEDURE prcDeleteRestOrderLinks
	@billId UNIQUEIDENTIFIER
AS    
SET NOCOUNT ON

DELETE rest FROM  RestOrder000 rest
	INNER JOIN BillRel000 rel ON rest.Guid = rel.ParentGUID
	WHERE rel.BillGUID = @billId

#########################################################
CREATE PROCEDURE prcCheckBillSN
(
	@BillGuid UNIQUEIDENTIFIER
)
AS
	SET NOCOUNT ON;
	
	 DECLARE @BillMaterials AS TABLE
	 (
		MatGUID UNIQUEIDENTIFIER,
		SNGUID UNIQUEIDENTIFIER,
		stGuid UNIQUEIDENTIFIER
	 )

	-- current bill materials with serial numbers if the current bill is input
	INSERT INTO @BillMaterials
		SELECT DISTINCT mt.mtGUID, sn.snGuid, sn.biStorePtr
		FROM vwMt mt 
			INNER JOIN vwbubi			AS b  ON b.biMatPtr = mt.mtGUID AND b.buGUID = b.biParent
			INNER JOIN vwbt				AS bt ON bt.btGUID = b.buType
			INNER JOIN vwExtended_SN	AS sn ON sn.buGUID = b.buGUID AND sn.biGUID = b.biGUID AND sn.biMatPtr = b.biMatPtr
		WHERE 
			b.buGUID = @BillGuid AND mt.mtForceInSN = 1 AND mt.mtForceOutSN = 1 AND bt.btIsInput = 1

	DECLARE @OutSNMaterials INT

	SELECT @OutSNMaterials = COUNT(mt.MatGUID)
	FROM @BillMaterials mt 
		INNER JOIN vwExtended_SN AS sn ON sn.biMatPtr = mt.MatGUID AND sn.snGuid = mt.SNGUID AND mt.stGuid = sn.biStorePtr
		INNER JOIN vwbt			 AS bt ON bt.btGUID = sn.buType
	WHERE bt.btIsOutput = 1

	-- returns materials' Serial numbers count that exsist in out bills
	SELECT @OutSNMaterials AS OutSNMaterialsCount

#########################################################
#END
