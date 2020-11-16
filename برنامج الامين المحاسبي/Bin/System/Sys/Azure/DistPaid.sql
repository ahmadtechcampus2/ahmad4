##############################################
CREATE PROCEDURE prcDistNetLoad 
      @DistGUID         UNIQUEIDENTIFIER OUTPUT, 
      @SalesManGUID     UNIQUEIDENTIFIER OUTPUT,
      @DistStore		UNIQUEIDENTIFIER,    
      @Date             DATETIME OUTPUT,           
      @PaidNumber       INT,                
      @Unit             INT,                
      @PriceType        INT, 
      @ViewLoadDetail   BIT = 1,
      @BranchGuid		UNIQUEIDENTIFIER = 0x0
AS 
	EXECUTE prcNotSupportedInAzureYet
	/*
    SET NOCOUNT ON 
    -- Test Paid Number 
    --DECLARE @DistStore UNIQUEIDENTIFIER  
    --SELECT @DistStore =  di.StoreGUID FROM Distributor000 di WHERE  di.GUID = @DistGUID 
    ----------------------------- ----------------------------------------------------------- 
    CREATE TABLE #bills(BillType INT, guid UNIQUEIDENTIFIER, number INT, serial INT IDENTITY(1,1)) 
    INSERT INTO #bills 
    SELECT  
            bt.Type, bu.guid, bu.number 
    FROM  
        bt000 bt  
        INNER JOIN bu000 bu on bt.GUID = bu.TypeGUID 
        INNER JOIN TT000 AS tt ON tt.OutTYpeGuid = bu.TypeGuid OR tt.InTypeGuid = bu.TypeGuid        
        LEFT JOIN br000 as br ON br.Guid = bu.branch
    WHERE  
        bu.StoreGUID = @distStore 
        AND bu.Date = @Date 
        AND bu.IsPosted = 1  
        AND (bu.branch = @BranchGuid OR @BranchGuid = 0x0)
    ORDER BY  
        bt.Type DESC , bu.Number 
       
    DECLARE @InventoryBillTypeGuid UNIQUEIDENTIFIER 
    SELECT  @InventoryBillTypeGuid = CAST(Value AS UNIQUEIDENTIFIER)  
									FROM op000  
									WHERE Name = 'DistCfg_NetLoad_InventoryBTGuid' 
	SET @InventoryBillTypeGuid = ISNULL(@InventoryBillTypeGuid, 0x00) 
             
    INSERT INTO #bills 
    SELECT bt.Type, bu.guid, bu.number 
    FROM   
        bt000 bt  
        INNER JOIN bu000 bu on bt.GUID = bu.TypeGUID 
        LEFT JOIN br000 AS br ON br.Guid = bu.branch 
    WHERE  
        bu.StoreGUID = @distStore 
        AND bu.Date = @Date 
        AND bt.guid = @InventoryBillTypeGuid 
        AND (bu.branch = @BranchGuid OR @BranchGuid = 0x0)
---------------------------------------------------------------------------------------------- 
-- «·Ã—œ «·”«»ﬁ
    SELECT   
        [biStorePtr]      AS StoreGuid,   
        [biMatPtr]        AS MatGuid,  
        [mtName]          AS MatName,   
        SUM([btIsInput]*([biQty] + [biBonusQnt])) - SUM([btIsOutput] * ([biQty] + [biBonusQnt]))  AS [Qty],  
        ISNULL( ( SUM([btIsInput]*([biQty] + [biBonusQnt])) - SUM([btIsOutput] * ([biQty] + [biBonusQnt])) )  /   
			CASE @Unit WHEN 1 THEN CASE mtUnit2Fact WHEN 0 THEN 1 ELSE mtUnit2Fact END         
                        WHEN 2 THEN CASE mtUnit3Fact WHEN 0 THEN 1 ELSE mtUnit3Fact END         
                        WHEN 3 THEN CASE mtDefUnitFact WHEN 0 THEN 1 ELSE mtDefUnitFact END        
                        ELSE 1         
            END, 0)  
        AS QtyUnit  
    INTO  
        #InvTable  
	FROM   
        [vwExtended_Bi] as vwBi
        LEFT JOIN br000 as br ON br.Guid = vwBi.buBranch
    WHERE  
        buDate < @Date 
        AND [buStorePtr] = @DistStore  
        AND BuIsPosted = 1 
        AND (vwbi.bubranch = @BranchGuid OR @BranchGuid = 0x0)
    GROUP BY  
        [biStorePtr], [biMatPtr], [mtName], mtUnit2Fact, mtUnit3Fact, mtDefUnitFact 
             
----------------------------------------------------------------------
    SELECT 
	bu.guid, bu.number, bu.BillType, bi.matguid, mt.mtname name, mt.mtGroup AS GroupGuid, mt.grName GrName,  
        Case @Unit WHEN  0 THEN mt.mtUnity 
                    WHEN  1  THEN Case mt.mtUnit2Fact WHEN 0 THEN mt.mtUnity ELSE mt.mtUnit2 END 
                    WHEN  2  THEN Case mt.mtUnit3Fact WHEN 0 THEN mt.mtUnity ELSE mt.mtUnit3 END 
                    WHEN  3 THEN  
                                CASE mt.mtDefUnit  
                                    WHEN 1 THEN mt.mtUnity 
                                    WHEN 2 THEN Case mt.mtUnit2FACT WHEN 0 THEN mt.mtUnity ELSE mt.mtUnit2 END 
                                    WHEN 3 THEN Case mt.mtUnit3Fact WHEN 0 THEN mt.mtUnity ELSE mt.mtUnit3 END 
                                END 
        END 
        As MatUnit,  
        isnull(bi.qty / CASE @Unit     
                                WHEN 1 THEN CASE ISNULL(MT.mtUnit2Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit2Fact   END        
                                WHEN 2 THEN CASE ISNULL(MT.mtUnit3Fact, 0)   WHEN 0 THEN 1 ELSE MT.mtUnit3Fact   END        
                                WHEN 3 THEN CASE ISNULL(MT.mtDefUnitFact, 0) WHEN 0 THEN 1 ELSE MT.mtDefUnitFact END       
                                ELSE 1        
                                END, 0) 
        AS Qty, 
        mt.Price AS UnitPrice,  
		bu.Serial 
    INTO #BillItems 
    FROM 
    bi000 as bi  
        FULL  OUTER JOIN  #bills AS BU ON bu.GUID = bi.ParentGUID 
        FULL  OUTER JOIN dbo.fnExtended_mt(@PriceType, 0, @Unit) AS mt ON mt.mtGuid = bi.MatGuid 
        FULL  OUTER JOIN  #InvTable it ON it.[MatGuid]  = mt.mtGuid
    ----------------------------------------------------------------------------------------- 
    DECLARE @in INT, @out INT, @i INT, @Inv INT 
    SET @i = 1 
    SELECT @in = COUNT(*) FROM #bills WHERE BillType = 4   -- 4 
    SELECT @out = COUNT(*) FROM #bills WHERE BillType = 3  --5
    SELECT @Inv = COUNT(*) FROM #bills WHERE BillType = 1  --5  
        
       
    IF (dbo.fnObjectExists('##NetLoadData') = 1) 
        DROP TABLE ##NetLoadData  
             
    DECLARE @sql NVARCHAR(4000) 
    SET @i = 1 
    SET @sql = 'SELECT d.MatGUID, d.Name, d.GroupGUID, d.GrName, d.UnitPrice, d.MatUnit, ' 
    WHILE (@i <= @in AND @ViewLoadDetail = 1) 
    BEGIN 
        SET @sql = @sql + ' SUM(CASE WHEN d.serial = ' + CAST(@i AS NVARCHAR(10))+' THEN ISNULL(d.qty,0) ELSE 0 END) AS Load' + CAST(@i AS NVARCHAR(10)) + ',' 
        SET @i = @i + 1 
    END 
    SET @sql = @sql + ' 
        ISNULL( SUM(CASE BillType WHEN 4 THEN d.Qty ELSE 0 END), 0) AS TotalLoad, 
        ISNULL( SUM(CASE BillType WHEN 3 THEN d.Qty ELSE 0 END), 0) AS TotalRemain, 
        ISNULL( SUM(CASE BillType WHEN 1 THEN d.Qty ELSE 0 END), 0) AS TotalInv, 
        CAST(0 AS FLOAT) AS TotalSalesQty, 
        CAST(0 AS FLOAT) AS TotalSalesValue, 
        2 AS LineType, 
        CAST(0 AS FLOAT) AS LastInventory
    ' 
    SET @sql = @sql + ' INTO ##NetLoadData FROM #BillItems d '  
    SET @sql = @sql + ' INNER JOIN ms000 ms on d.matguid = ms.matGuid where ms.storeguid  = '+ ''''+CAST(@DistStore AS NVARCHAR(50))+''''  
    SET @sql = @sql + ' GROUP BY d.MatGUID, d.Name, d.UnitPrice, d.MatUnit,  d.GroupGUID, d.GrName, ms.qty ' 
       
    EXEC (@sql)
    -- print @sql
    IF EXISTS(SELECT * FROM  #invTable )     
	UPDATE ##NetLoadData SET  
	LastInventory = ISNULL(inv.QtyUnit, 0),  
	TotalSalesQty = ISNULL(inv.QtyUnit, 0) + TotalLoad - TotalRemain - TotalInv,  
	TotalSalesValue = (ISNULL(inv.QtyUnit, 0) + TotalLoad - TotalRemain - TotalInv) * UnitPrice  
	FROM 
	##NetLoadData AS nl 
	FULL OUTER JOIN  #invTable AS inv ON inv.MatGuid = nl.MatGuid
	ELSE 
	UPDATE ##NetLoadData SET  
	LastInventory = 0, 
	TotalSalesQty =  TotalLoad - TotalRemain - TotalInv, 
	TotalSalesValue = (TotalLoad - TotalRemain - TotalInv) * UnitPrice 
	FROM 
	##NetLoadData AS nl
	FULL OUTER JOIN  #invTable AS inv ON inv.MatGuid = nl.MatGuid 
		
             
    DECLARE @NetLoadValue   FLOAT 
    SELECT @NetLoadValue = SUM(TotalSalesValue) FROM ##NetLoadData 
--------------------------------- 
-- Add Groups 
    SET @i = 1 
    SET @sql = 'INSERT INTO ##NetLoadData ' 
    SET @sql = @sql + ' SELECT GroupGUID, GrName, GroupGUID, GrName, CAST(0 AS FLOAT), '''', ' 
    WHILE (@i <= @in AND @ViewLoadDetail = 1) 
    BEGIN 
        SET @sql = @sql + ' SUM(Load' + CAST(@i AS NVARCHAR(10)) + '), ' 
        SET @i = @i + 1 
    END 
    SET @sql = @sql + ' SUM(TotalLoad), SUM(TotalRemain), SUM(TotalInv), SUM(TotalSalesQty), SUM(TotalSalesValue), 1 AS LineType,  ' 
    SET @sql = @sql + ' SUM (LastInventory)' 
    SET @sql = @sql + ' FROM ##NetLoadData GROUP BY GroupGUID, GrName' 
    EXEC (@sql)
    DELETE FROM  ##NetLoadData
    WHERE LastInventory = 0 AND TotalLoad = 0 AND TotalRemain = 0
    SELECT  
        ISNULL(@In, 0)			 AS NumOfLoads,     
        ISNULL(@Out, 0)			 AS NumOfRemain, 
        ISNULL(@NetLoadValue, 0) AS NetLoadValue,
        ISNULL(@Inv, 0)			 AS NumOfInv   
	*/
/* 
EXECUTE  [prcDistNetLoad] '00000000-0000-0000-0000-000000000000', 'f70e3718-a614-42c6-9c6d-061f26f1841d', '1/19/2011', 2, 3, 128 
*/  
##############################################
CREATE PROCEDURE repDistNetLoad 
	@DistGUID		UNIQUEIDENTIFIER,
	@SalesManGUID	UNIQUEIDENTIFIER,
	@Date			DATETIME,
	@PaidNumber		INT,
	@Unit			INT,
	@PriceType		INT,
	@ViewLoadDetail	BIT = 1, 
	@BranchGuid		UNIQUEIDENTIFIER = 0x0
AS
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON
	DECLARE @StoreGuid UNIQUEIDENTIFIER 
	IF @paidNumber <> 0
    BEGIN
		SELECT @DistGUID = DistGuid, 
			   @Date = Date, 
			   @StoreGuid = SalesManStoreGUID 
		From DistPaid000 
		WHERE Number = @PaidNumber 
			  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
        
        IF IsNull(@DistGUID, 0x0) = 0x0 
			RETURN
    END
    ELSE
    BEGIN
        IF ISNULL(@SalesManGUID, 0x0) <> 0x00 
        BEGIN
              SELECT DISTINCT @DistGUID = d.GUID, 
							  @StoreGuid = d.StoreGUID 
              From Distributor000 d 
              INNER JOIN DistSalesman000 sm ON d.PrimSalesmanGUID = @SalesManGUID
              IF IsNull(@DistGUID, 0x0) = 0x0 
			  RETURN
		END
        ELSE IF ISNULL(@DistGUID, 0x0) <> 0x00 
              SELECT @SalesManGUID = PrimSalesManGuid, 
					 @StoreGuid = StoreGUID 
              FROM Distributor000 
              where Guid = @DistGUID
        
        SELECT @PaidNumber = Number 
        FROM DistPaid000 
        WHERE DistGuid = @DistGuid 
			  AND Date = @Date
			  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
	END 
    
	CREATE TABLE #NetLoadValues( NumOfLoads INT, NumOfRemain INT, NetLoadValue FLOAT, NumOfInv INT)
	INSERT INTO #NetLoadValues Exec prcDistNetLoad @DistGuid OUTPUT, @SalesManGUID OUTPUT, @StoreGuid, @Date OUTPUT, @PaidNumber, @Unit, @PriceType, @ViewLoadDetail
	 
	DECLARE @NetLoadValue FLOAT, 
			@NumOfLoads INT, 
			@NumOfRemain INT, 
			@NumOfInv INT
	
	SELECT @NetLoadValue = NetLoadValue, 
		   @NumOfLoads = NumOfLoads, 
		   @NumOfRemain = NumOfRemain, 
		   @NumOfInv =  NumOfInv
	FROM #NetLoadValues
	
	IF @NumOfLoads = 0 AND @NumOfRemain = 0 AND @NumOfInv = 0 AND @NetLoadValue = 0
		RETURN
	---------------------------------------------------------------------------------------------
	------ Add To DistPaid Values
	IF @paidNumber = 0
		SELECT @PaidNumber = Number 
		FROM DistPaid000 
		WHERE DistGuid = @DistGuid 
			  AND Date = @Date
			  AND (BranchGuid = @BranchGuid Or @BranchGuid = 0x0)
		
	IF ISNULL(@PaidNumber, 0) = 0
	BEGIN
		SELECT @PaidNumber = ISNULL(Max(Number), 0) + 1 
		FROM DistPaid000
		where BranchGuid = @BranchGuid OR @BranchGuid = 0x0
		
		INSERT INTO DistPaid000( 
			Number, Guid, DistGuid, Date, NetLoadValue, BonusValue, DiscountValue, DebtsGranted, DebtsCollected, AccPaidGuid, EntryGuid, Security, SalesManGuid, SalesManStoreGuid, BranchGuid
		)
		VALUES(
			@PaidNumber, newId(), @DistGuid, @Date, ISNULL(@NetLoadValue, 0), 0, 0, 0, 0, 0x00, 0x00, 1, @SalesManGUID, @StoreGuid, @BranchGuid
		) 
	END
	ELSE
	BEGIN
		UPDATE DistPaid000 
		SET NetLoadValue = ISNULL(@NetLoadValue, 0) 
		WHERE Number = @PaidNumber  
		AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
	END
	---------------------------------------------------------------------------------------------
	DECLARE @DistName		NVARCHAR(255), 
			@SalesManName	NVARCHAR(255),
			@StoreName		NVARCHAR(255),
			@CostGuid		UNIQUEIDENTIFIER		 
	SELECT  
		@DistName = dr.Name, 
		@SalesManName = sm.Name, 
		@CostGuid = sm.CostGUID,
		@StoreName = st.name
	FROM
		Distributor000 AS dr
		INNER JOIN DistSalesman000 AS sm ON sm.GUID = dr.PrimSalesmanGUID INNER JOIN st000 st ON  st.GUID = @StoreGuid 
		WHERE dr.GUID = @DistGUID
	-----------------------------------------------------------------------------------------------------		
	---- Results
	SELECT 
		@NumOfLoads		AS NumOfLoads, 
		@NumOfRemain	AS NumOfRemain, 
		@PaidNumber		AS PaidNumber,
		@DistName		AS DistName,
		@SalesManName	AS SalesManName,
		@Date           AS DATE,
		@StoreGuid		AS StoreGuid,
		@CostGuid       AS CostGuid,
		@StoreName		AS StoreName
		
	SELECT * FROM ##NetLoadData  
	ORDER BY GrName, LineType, Name 
	*/
	
/*
EXECUTE  [repDistNetLoad] '2c741ade-fd7c-4fac-9c3f-de4ff2c4c09b', '00000000-0000-0000-0000-000000000000', '3/20/2011', 0, 3, 128select * from distpaid000
*/
########################################
CREATE PROCEDURE prcDistFinalPaid
	@PaidNumber				INT,   
    @PaidOption				INT,			-- 1 Values    2 Qty 
    @StoreGuid				UNIQUEIDENTIFIER,
    @ViewFinalPaidDetail	BIT = 1,		-- 1 View Details  -- 0 View FinalPaidState 
    @FinalPaidState			BIT OUTPUT, 		-- 1 No Differences Can Close Paid   
    @BranchGuid				UNIQUEIDENTIFIER = 0x0
AS  
	EXECUTE prcNotSupportedInAzureYet
	/*
	SET NOCOUNT ON  
    DECLARE @DistGUID	    UNIQUEIDENTIFIER,     
            @Date           DATETIME,    
            @DistName		NVARCHAR(255),   
            @SalesManName	NVARCHAR(255),  
            @CostGUID       UNIQUEIDENTIFIER,  
            @Unit           INT,
            @CompareGiftsAndDiscSum BIT,
            @DistAccGuid UNIQUEIDENTIFIER
                    
    SELECT  
		@DistGUID = DistGuid,  
		@Date = Date, 
        @DistName = dr.Name,  
        @SalesManName = sm.Name,  
        @CostGUID = sm.CostGUID,
        @DistAccGuid = sm.AccGuid 
    FROM  
          Distributor000 AS dr  
          INNER JOIN DistSalesman000 AS sm ON sm.GUID = dr.PrimSalesmanGUID   
          INNER JOIN DistPaid000 AS dp ON dp.DistGuid = dr.Guid 
    WHERE  
          dp.Number = @PaidNumber
          AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
          
    SELECT @CompareGiftsAndDiscSum = ISNULL(value, 0) FROM op000 
									 WHERE Name = 'DistCfg_FinalPaid_SumDiscountsAndGiftsCompare'
    IF @DistGuid IS NULL 
    BEGIN
		SET @FinalPaidState = 0 
		RETURN     
	END	
    ----------------------------- Bills ---------------------------------------------- 
    CREATE TABLE #FpBills(BillType INT,Type INT, guid UNIQUEIDENTIFIER)  
    INSERT INTO #FpBills  
    SELECT   
          bt.BillType, bt.Type, bu.guid-- , bu.number  
    FROM   
          bt000 bt   
          INNER JOIN bu000 bu ON bt.GUID = bu.TypeGUID  
    WHERE   
          bu.Date = @Date   
          AND bu.CostGUID = @CostGUID   
          AND bt.Type = 1 
          AND bu.IsPosted = 1 
    ORDER BY   
          bt.Type DESC, bu.Number  
           
    DECLARE @CalcDifference		FLOAT	-- 0 No Difference & Can Close Paid 
    ---------------------------------------------------------------------------------------  
    -- VALUES --  
    IF @PaidOption = 1    
    BEGIN  
		CREATE TABLE #Results1( 
			NetLoadValue	FLOAT,  
			BonusValue		FLOAT,  
			DiscountValue	FLOAT,  
			DebtsGranted	FLOAT,  
			DebtsCollected	FLOAT,  
			PaidValue		FLOAT,  
			LineType		INT	-- 1 FastPaid  2 Bills 
		)  
       ----- From Fast Paid  
		DECLARE @FastPaidValue	FLOAT
		SELECT 
			@FastPaidValue = ce.Debit
		FROM 
			DistPaid000 AS dp
			INNER JOIN er000 AS er ON er.ParentGuid = dp.EntryGuid
			INNER JOIN ce000 AS ce ON ce.Guid = er.EntryGuid
		Where dp.Number = @PaidNumber
			  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
       
        INSERT INTO #Results1  
        SELECT   
			NetLoadValue, BonusValue, DiscountValue, DebtsGranted, DebtsCollected,  
			-- ﬁÌ„… «·œ›⁄… ›Ì «·”œ«œ «·”—Ì⁄ „‰ «·œ›⁄… «·„ Ê·œ… Ê·Ì”  „‰ „Ã„Ê⁄ «·ﬁÌ„
			-- Ê–·ﬂ ·· √ﬂœ „‰  Ê·Ìœ œ›⁄… «·’‰œÊﬁ ›Ì «·”œ«œ «·”—Ì⁄ ﬁ»· ﬁ›· «·”œ«œ
			-- NetLoadValue - BonusValue - DiscountValue - DebtsGranted + DebtsCollected,  
			ISNULL(@FastPaidValue, 0),	
			1    -- LineType = 1 For FastPaid  
        FROM  
			DistPaid000  
        WHERE  
			Number = @PaidNumber
			AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)  
        
        ---- FROM BILLS & ENTRIES  
        DECLARE @DebtsCollected FLOAT  
        SELECT @DebtsCollected = SUM([en].[enCredit] - [en].[enDebit])  
        FROM     
              [vwCeEn] AS [en]     
              LEFT JOIN er000 AS er ON er.EntryGuid = en.ceGuid AND er.ParentType = 2  
              INNER JOIN DistSalesMan000 as sm ON sm.CostGuid = @CostGuid
        WHERE              
              er.Guid IS NULL AND  
              enDate = @Date  
              AND [en].[enCostPoint] = @CostGUID  
              AND sm.AccGuid IN (en.enContraAcc) 
         
        ---- „—ﬂ“ «·ﬂ·›… ÌŒ’ ﬂ·« «·Õ”«»Ì‰
		DECLARE @IsCostForBothAcc BIT
		SELECT @IsCostForBothAcc = CostForBothAcc FROM et000 
									WHERE Guid = (SELECT TypeGuid FROM py000 
													WHERE  AccountGuid = @DistAccGuid
													AND Date = @Date
													AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
												  )
		IF @IsCostForBothAcc = 1	   
			SELECT @DebtsCollected = @DebtsCollected - SUM([en].[enCredit] - [en].[enDebit])
			FROM     
				  [vwCeEn] AS [en]     
				  LEFT JOIN er000 AS er ON er.EntryGuid = en.ceGuid AND er.ParentType = 2
				  INNER JOIN DistSalesMan000 as sm ON sm.CostGuid = @CostGUID
			WHERE              
				  er.Guid IS NULL AND  
				  enDate = @Date
				  AND [en].[enCostPoint] = @CostGUID
				  AND sm.AccGuid IN (en.enContraAcc)
				  AND EN.enDebit <> 0
				             
        DECLARE @NetLoadValue FLOAT, @DiscountValue FLOAT, @DebtsGranted FLOAT  
        SELECT   
            @NetLoadValue = SUM (CASE fb.BillType WHEN 1 THEN bu.Total
                                                  WHEN 3  THEN -bu.Total
                                END),
            @DiscountValue = SUM(bu.TotalDisc),  
            @DebtsGranted = SUM(CASE bu.PayType WHEN 0 THEN 0  
												WHEN 1 THEN 
															CASE fb.BillType WHEN 1 THEN(bu.Total + bu.TotalExtra -bu.TotalDisc)- bu.FirstPay  
															                 WHEN 3 THEN -((bu.Total + bu.TotalExtra -bu.TotalDisc)- bu.FirstPay)
														    END
															  
                              END)  
        FROM  
			#FpBills Fb  
			INNER JOIN bu000 bu ON fb.guid = bu.GUID  
              
        INSERT INTO #Results1  
        SELECT  
            ISNULL(@NetLoadValue, 0)+ ISNULL(SUM(bubi.biBonusQnt * bubi.biPrice), 0),--------------  
            ISNULL(SUM(bubi.biBonusQnt * bubi.biPrice), 0),  
            ISNULL(@DiscountValue, 0),  
            ISNULL(@DebtsGranted, 0),  
            ISNULL(@DebtsCollected,0),   
            0,  
            2    -- LineType = 2 For Bills       
        FROM   
			vwbubi bubi   
        WHERE   
			buDate = @Date AND   
            buCostPtr = @CostGUID AND  
            btType = 1  
                    
        UPDATE #Results1   
        SET   
			PaidValue = NetLoadValue - BonusValue - DiscountValue - DebtsGranted + DebtsCollected  
        WHERE   
            LineType = 2  
                 
		IF @ViewFinalPaidDetail = 1 
	        SELECT * FROM #Results1  
					 
		IF @CompareGiftsAndDiscSum = 1	 
			SELECT  
				@CalcDifference =  
					SUM(CASE LineType WHEN 1 THEN NetLoadValue		ELSE NetLoadValue *-1	END) +  
					SUM(CASE LineType WHEN 1 THEN BonusValue		ELSE BonusValue *-1		END) +  
					SUM(CASE LineType WHEN 1 THEN DiscountValue		ELSE DiscountValue *-1	END) +  
					SUM(CASE LineType WHEN 1 THEN DebtsGranted		ELSE DebtsGranted *-1	END) +  
					SUM(CASE LineType WHEN 1 THEN DebtsCollected	ELSE DebtsCollected *-1	END) +	 
					SUM(CASE LineType WHEN 1 THEN PaidValue			ELSE PaidValue *-1		END) 
			FROM  
				#Results1
		ELSE
			BEGIN
				DECLARE @NetLoadVal		FLOAT, 
						@BonusVal		FLOAT, 
						@DiscountVal		FLOAT, 
						@GrantedDebts	FLOAT, 
						@CollectedDebts FLOAT, 
						@PaidVal		FLOAT
				
				
				SELECT  @NetLoadVal	= SUM(CASE LineType WHEN 1 THEN NetLoadValue	ELSE NetLoadValue *-1	END),
					    @BonusVal		= SUM(CASE LineType WHEN 1 THEN BonusValue		ELSE BonusValue *-1		END),
						@DiscountVal	= SUM(CASE LineType WHEN 1 THEN DiscountValue	ELSE DiscountValue *-1	END),
						@GrantedDebts	= SUM(CASE LineType WHEN 1 THEN DebtsGranted	ELSE DebtsGranted * -1	END),
						@CollectedDebts = SUM(CASE LineType WHEN 1 THEN DebtsCollected	ELSE DebtsCollected *-1	END),
						@PaidVal		= SUM(CASE LineType WHEN 1 THEN PaidValue		ELSE PaidValue * -1		END) 
				FROM #Results1
				
				IF  @NetLoadVal <> 0 OR @BonusVal <> 0 OR @DiscountVal <> 0 OR @GrantedDebts <> 0 OR @CollectedDebts <> 0 OR @PaidVal <> 0
					SET @CalcDifference =  1
				ELSE	
					SET @CalcDifference =  0
			END	 
			 
		EXEC prcDropTable '#Results1'          
		
		DECLARE @r INT
		SELECT @r = ISNULL(value, 0) FROM op000 WHERE name = 'AmnCfg_PricePrec'
		SET @r = ISNULL(@r, 0)
		SET @CalcDifference = ROUND(@CalcDifference, @r, 1)
	END     
    ---------------------------------------------------------------------------------------  
    --QTY--  
    ELSE  
    BEGIN   
		CREATE TABLE #Results2(  
			mtGuid		UNIQUEIDENTIFIER,  
			mtName		NVARCHAR(255) COLLATE Arabic_CI_AI,  
			grGuid		UNIQUEIDENTIFIER,  
			grName		NVARCHAR(255) COLLATE Arabic_CI_AI,  
			BillsQty	FLOAT,  
			NetLoadQty	FLOAT, 
			LineType	INT	-- 1 Group 2 Mats 
		)  
		--------------------------------------------- Qty From Bills  
        --------------- Mats Qty From Bills 
        INSERT INTO #Results2 
        SELECT   
              mt.mtGUID, mt.mtName, mt.grGUID, mt.grName, SUM(( biQty * btDirection * -1) + ISNULL(bubi.biBonusQnt,0 )) AS BillsQty, 0, 2  
        FROM --------------------------------  
			vwbubi	AS bubi   
			INNER JOIN vwMtGr AS mt ON bubi.biMatPtr = mt.mtGUID   
            INNER JOIN #FpBills AS bill ON bill.guid = bubi.buGUID  
        GROUP BY   
			mt.grGUID,mt.grName,mt.mtGUID ,mt.mtName   
        ORDER BY   
            mt.mtGUID, mt.mtName, mt.grGUID, mt.grName   
        -------------- Groups Qty  
        INSERT INTO #Results2  
        SELECT    
			mt.grGUID , mt.grName, mt.grGUID , mt.grName, SUM(rs.BillsQty) AS BillsQty, 0, 1  
        FROM   
			#Results2 AS   rs   
			INNER JOIN vwMtGr AS mt ON rs.mtGUID = mt.mtGUID   
        GROUP BY    
			mt.grGUID, mt.grName    
         
		--------------------------------------------- Qty From NetLoadReport  
		CREATE TABLE #NetLoad( 
			mtGuid			UNIQUEIDENTIFIER,  
			mtName			NVARCHAR(255) COLLATE Arabic_CI_AI,  
			grGuid			UNIQUEIDENTIFIER,  
			grName			NVARCHAR(255) COLLATE Arabic_CI_AI,  
			UnitPrice		FLOAt,  
			MatUnit			NVARCHAR(100) COLLATE Arabic_CI_AI, 
			TotalLoad		FLOAT, 
			TotalRemain		FLOAT, 
			TotalSalesQty	FLOAT, 
			TotalSalesValue	FLOAT, 
			LineType		INT, 
			LastInventory	FLOAT
		) 

		CREATE TABLE #NetLoadValues(NumOfLoads INT, NumOfRemain INT, NetLoadVlaue FLOAT, NumOfInv INT) 
		INSERT INTO #NetLoadValues EXEC prcDistNetLoad @DistGuid, 0x00, @StoreGuid, @Date, @PaidNumber, 0, 128, 0, @BranchGuid  
		
		INSERT INTO #NetLoad 
		SELECT MatGuid, Name, GroupGuid, GrName, UnitPrice, MatUnit, TotalLoad, TotalRemain, TotalSalesQty, TotalSalesValue, LineType, LastInventory 
		FROM ##NetLoadData  
		
		UPDATE #Results2 SET  
			NetLoadQty = nl.TotalSalesQty 
		FROM  
			#Results2 AS rs  
			INNER JOIN #NetLoad AS nl ON nl.mtGuid = rs.mtGuid  
		INSERT INTO #Results2 
		SELECT  
			nl.mtGuid, nl.mtName, nl.grGuid, nl.grName, 0, nl.TotalSalesQty, nl.LineType  
		FROM  
			#NetLoad AS nl  
			LEFT JOIN #Results2 AS rs ON nl.mtGuid = rs.mtGuid  
		WHERE  
			rs.mtGuid IS NULL	 
			 
		IF @ViewFinalPaidDetail = 1 
	        SELECT mtGuid, mtName, BillsQty, NetLoadQty, LineType FROM #Results2 ORDER BY grName, LineType, mtName 
		SELECT  
			@CalcDifference = SUM(ABS(BillsQty - NetLoadQty)) 
		FROM  
			#Results2 
         
        EXEC prcDropTable '#Results2'          
    END  
    EXEC prcDropTable '#FpBills'  
       
	IF @CalcDifference = 0 -- No Difference  
		SET @FinalPaidState = 1		-- Can Close Paid 
	ELSE 	 
		SET @FinalPaidState = 0		-- Can't Close Paid 
	*/
/*  
DECLARE @B BIT 
Exec prcDistFinalPaid 1, 1, 1, @B OUTPUT 
SELECT @B 
*/  
########################################
CREATE PROCEDURE repDistFinalPaid
	@PaidNumber				INT,  
    @PaidOption				INT, 	-- 1 Values    2 Qty
    @BranchGuid		UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 
	DECLARE @FinalPaidState		BIT,		-- 1 Can Close Paid    -- 0 Can't Close Paid 
			@StoreGuid UNIQUEIDENTIFIER
	
	SELECT @StoreGuid =  SalesManStoreGuid From DistPaid000
					WHERE Number = @PaidNumber 
						  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
						  
	EXEC prcDistFinalPaid @PaidNumber, @PaidOption, @StoreGuid, 1, @FinalPaidState, @BranchGuid 
	---------- Bring CalcHeader Data For The Report 
	SELECT dp.Number AS DistPaidNumber, 
		   sm.Name AS SalesManName,
		   st.GUID As StoreGuid,
		   sm.CostGUID AS CostGuid, 
		   st.Name AS StoreName, 
		   dist.Name AS DistName, 
		   dp.Date AS Date 
	FROM DistSalesMan000 AS sm 
		INNER JOIN Distributor000 AS dist ON dist.PrimSalesManGuid = sm.Guid 
		INNER JOIN DistPaid000 AS dp ON dp.distGuid = dist.Guid And dp.SalesManGuid = sm.Guid 
		INNER JOIN st000 AS st ON st.Guid = dp.SalesManStoreGuid
	WHERE dp.Number = @PaidNumber 
		  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
/* 
Exec repDistFinalPaid 1, 1
*/ 
##############################################
CREATE PROC prcDistFastPaid
   @PaidGuid        UNIQUEIDENTIFIER, 
   @AccPaidGuid		UNIQUEIDENTIFIER, 
   @NetLoadValue    FLOAT, 
   @BonusValue      FLOAT, 
   @DiscountValue   FLOAT, 
   @DebtsGranted    FLOAT, 
   @DebtsCollected	FLOAT,
   @TotalPayment    FLOAT, 
   @Security		INT, 
   @GenerateEntry	BIT, 
   @BranchGuid		UNIQUEIDENTIFIER = 0x0 
AS 
	SET NOCOUNT ON 
	DECLARE @PyTypeGuid	  UNIQUEIDENTIFIER, 
			@opTypeGuid	  UNIQUEIDENTIFIER 
	 
	SELECT @opTypeGuid = CAST(value AS UNIQUEIDENTIFIER) FROM op000 
			WHERE Name = 'DistCfg_FastPaid_EntryTypeGuid' 
	 
	SELECT  @PyTypeGuid = CASE ISNULL(@opTypeGuid, 0x0)  
							WHEN 0x0 THEN ( 
											SELECT  TOP 1 guid  FROM et000  
											WHERE FldDebit = 0 and FldCredit = 1  
											ORDER BY sortNum 
										  ) 
							ELSE @opTypeGuid 
						  END 
	--------------------------------------------- 
	-- Update DistPaid Table	 
	UPDATE DistPaid000  
	SET 
	   AccPaidGuid		= @AccPaidGuid, 
	   NetLoadValue		= @NetLoadValue, 
	   BonusValue		= @BonusValue, 
	   DiscountValue	= @DiscountValue, 
	   DebtsGranted		= @DebtsGranted, 
	   DebtsCollected   = @DebtsCollected, 
	   Security			= @Security, 
	   EntryTypeGuid	= @PyTypeGuid 
	 WHERE  
		Guid = @PaidGuid 
	-------------------------------------------------------------------------
	-------------------- if total = 0 delete previous entry------------------ 
	IF (@TotalPayment = 0.0)
	BEGIN
		DECLARE @PyEnGuid	UNIQUEIDENTIFIER,
				@EnGuid		UNIQUEIDENTIFIER
		SELECT @PyEnGuid = EntryGuid FROM DistPaid000 dp WHERE dp.Guid = @PaidGuid 
		SELECT @EnGuid = EntryGuid FROM er000 WHERE ParentGuid = @PyEnGuid
		IF ((ISNULL(@PyEnGuid, 0x00) <> 0x00) and (ISNULL(@EnGuid, 0x00) <> 0x00)) 
			BEGIN 
				UPDATE ce000 SET IsPosted = 0 WHERE GUID = @EnGuid 
				DELETE FROM ce000 WHERE GUID = @EnGuid 
				DELETE FROM er000 WHERE EntryGuid = @EnGuid AND ParentGuid = @PyEnGuid 
				DELETE FROM py000 WHERE GUID = @PyEnGuid 
				UPDATE DistPaid000 set EntryGuid = 0X00,EntryNumber = 0 WHERE Guid = @PaidGuid
			End
	END 
	-------------------------------------------------------------------------
	-- Gen Entry 
	IF(@GenerateEntry = 1)and (@TotalPayment <> 0.0) 
	BEGIN 
		DECLARE @EntryGuid		UNIQUEIDENTIFIER, 
				@PyGuid			UNIQUEIDENTIFIER, 
				@CurrencyGuid	UNIQUEIDENTIFIER, 
				@DistAccGuid	UNIQUEIDENTIFIER, 
				@CostGuid		UNIQUEIDENTIFIER, 
				@EntryNumber	INT, 
				@CurrencyVal	INT, 
				@PaidNumber		INT, 
				@PyNumber		INT, 
				@Notes			NVARCHAR(30), 
				@Date			DATETIME, 
				@TotalPaid		FLOAT 
		SELECT 
			@PyGuid		 = dp.EntryGuid,  
			@pyNumber	 = dp.EntryNumber,  
			@DistAccGuid = sm.AccGuid,  
			@CostGuid	 = sm.CostGuid, 
			@PaidNumber	 = dp.Number,   
			@Date		 = dp.Date, 
			@TotalPaid	 = NetLoadValue - BonusValue - DiscountValue - DebtsGranted + DebtsCollected 
		FROM  
			Distributor000 AS ds 
			INNER JOIN 	DistSalesMan000 AS sm ON sm.Guid = ds.PrimSalesmanGUID 
			INNER JOIN DistPaid000 AS dp ON dp.DistGuid = ds.Guid 
		WHERE  
			dp.Guid = @PaidGuid 
		 
		SELECT @EntryGuid = EntryGuid from er000 where ParentGuid = @PyGuid 
		SELECT @CurrencyGuid = CAST(value AS UNIQUEIDENTIFIER) FROM op000 WHERE Name = 'AmnCfg_DefaultCurrency' 
		 
		IF ISNULL(@CurrencyGuid, 0x00) <> 0x00 
			SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE GUID = @CurrencyGuid 
		ELSE 
			SELECT  
				@CurrencyGuid = Guid,  
				@CurrencyVal = CurrencyVal  
			FROM my000 WHERE Number = 1 
			 
		IF ((ISNULL(@PyGuid, 0x00) <> 0x00) and (ISNULL(@EntryGuid, 0x00) <> 0x00)) 
		BEGIN 
			UPDATE ce000 SET IsPosted = 0 WHERE GUID = @EntryGuid 
			SELECT @EntryNumber = number FROM ce000 WHERE GUID = @EntryGuid 
			  
			DELETE FROM ce000 WHERE GUID = @EntryGuid 
			DELETE FROM er000 WHERE EntryGuid = @EntryGuid AND ParentGuid = @PyGuid 
			DELETE FROM py000 WHERE GUID = @PyGuid 
		End 
		 
		ELSE IF(ISNULL(@EntryGuid,0x00) = 0x00) 
		BEGIN 
			SET @EntryGuid = NEWID() 
			SET @PyGuid	   = NEWID() 
			SELECT @EntryNumber = ISNULL(MAX(number), 0) + 1 FROM ce000	WHERE Branch = @BranchGuid 
			SELECT @PyNumber    = ISNULL(MAX(number), 0) + 1 FROM py000 WHERE BranchGuid = @BranchGuid 
			 
			UPDATE DistPaid000 SET  
				EntryGuid	= @PyGuid,  
				EntryNumber = @PyNumber  
			WHERE GUID = @paidGuid 
		END 
		
		SET @Notes = '«·”œ«œ «·”—Ì⁄ ' + CAST(@PaidNumber AS NVARCHAR(20)) 
		
		Declare 
			@IsCostForBothAcc BIT,
			@PostDate	  DATE
		
		SELECT 
			@IsCostForBothAcc = CostForBothAcc,
			@PostDate		  = CASE bAutoPost WHEN 1 THEN GETDATE() ELSE '1905-06-02' END
		FROM 
			et000 
		WHERE 
			Guid = @PyTypeGuid 
			 
		INSERT INTO ce000 (type, number, date, debit, credit, notes, guid, security, branch, currencyGuid, currencyval, isposted, PostDate) 
			VALUES (1, @EntryNumber, @Date, @TotalPaid, @TotalPaid, @Notes, @EntryGuid, 1, @BranchGuid, @CurrencyGuid, 1, 0, @PostDate) 
		 
		INSERT INTO en000(Number, Date, Debit, Credit, Notes, GUID, currencyval, ParentGUID, AccountGUID, CurrencyGUID, CostGuid, ContraAccGUID) 
		VALUES(2, @Date, @TotalPaid, 0, @Notes, NEWID(), @currencyVal, @EntryGuid, @AccPaidGuid, @CurrencyGuid, CASE @IsCostForBothAcc WHEN 1 THEN @CostGuid ELSE 0x0 END, @DistAccGuid ) 
		 
		INSERT INTO en000(Number, Date, Debit, Credit, Notes, GUID, currencyval, ParentGUID, AccountGUID, CurrencyGUID, CostGuid, ContraAccGUID) 
			VALUES(1, @Date, 0, @TotalPaid, @Notes, NEWID(), @currencyVal, @EntryGuid, @DistAccGuid, @CurrencyGuid, @CostGuid, @AccPaidGuid) 
		 
		UPDATE ce000 SET IsPosted = 1 WHERE GUID = @EntryGuid  
										   AND 1 = (select bAutoPost from et000 where Guid = @PyTypeGuid)  
		 
		INSERT INTO py000(Number, Date, Notes, currencyval, skip, Security, GUID, TypeGuid, AccountGUID, CurrencyGUID,BranchGuid) 
		VALUES(@PyNumber, @Date, @Notes, @currencyVal, 0, 1, @PyGuid, @PyTypeGuid, @AccPaidGuid, @CurrencyGuid, @BranchGuid)		 
		 
		INSERT INTO er000(GUID, EntryGUID, ParentGUID, ParentType,ParentNumber) 
		VALUES(NEWID(), @EntryGuid, @PyGuid, 4, @PyNumber)
					 
	END 
	--------------------------------------------- 
	-- Return Value 
	SELECT EntryGuid , ISNULL(EntryNumber, 0) AS EntryNumber FROM DistPaid000 where Guid = @PaidGuid
##############################################
CREATE PROC prcDistClosePaid
	@PaidNumber		INT,
	@PaidState	bit = 1,	--1 for close and 0 for reopen.
	@BranchGuid UNIQUEIDENTIFIER = 0x0
AS
/*
Result ClosePaidState
	0	Can't close paid has differeances
	1	Close/ReOpen Paid Done Successfully
	2	Old PaidState = New PaidState
	3	Paid Number Not Exists
*/
	SET NOCOUNT ON 
	DECLARE @StateValue		BIT, 
			@StateQty		BIT, 
			@ClosePaidState	BIT, 
			@StoreGuid		UNIQUEIDENTIFIER,
			@PaidGuid		UNIQUEIDENTIFIER,
			@Security		INT 
			
	SELECT 
			@PaidGuid = Guid,	
			@StoreGuid =  SalesManStoreGuid,
			@ClosePaidState = ClosePaidState
	From DistPaid000 
	WHERE Number = @PaidNumber
		  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
	
	IF ISNULL(@PaidGuid, 0x00) = 0x00
	BEGIN
		SELECT 3 AS ClosePaidState  
		RETURN
	END	
		
	SET @Security = 0
	IF @PaidState = 1 -- close Paid
	BEGIN			 
		IF ISNULL(@ClosePaidState, 0) = 0 
		BEGIN 
			Exec prcDistFinalPaid @PaidNumber, 1, @StoreGuid, 0, @StateValue OUTPUT, @BranchGuid
			Exec prcDistFinalPaid @PaidNumber, 2, @StoreGuid, 0, @StateQty OUTPUT, @BranchGuid
			IF (@StateValue = 0 OR @StateQty = 0) -- Can Close Paid 
			BEGIN
				SELECT 0 AS ClosePaidState  
				RETURN
			END
		END
		ELSE 
		BEGIN
			SELECT 2 AS ClosePaidState  
			RETURN
		END
		SET @Security = 3
	END	
	ELSE		-- ReOpen Paid 
	BEGIN
		IF ISNULL(@ClosePaidState, 0) = 0
		BEGIN
			SELECT 2 AS ClosePaidState  
			RETURN
		END
		SET @Security = 1
	END	
	
	BEGIN TRAN 
	 
	DECLARE @DistGUID	    UNIQUEIDENTIFIER,     
			@CostGUID       UNIQUEIDENTIFIER,  
			@Date           DATETIME 
	 
	SELECT   
		@DistGuid = DistGuid,  
		@CostGUID = sm.CostGUID,  
		@StoreGUID = dp.SalesManStoreGUID,  
		@Date = Date  
	FROM  
		Distributor000 AS dr  
		INNER JOIN DistSalesman000 AS sm ON sm.GUID = dr.PrimSalesmanGUID   
		INNER JOIN DistPaid000 AS dp ON dp.DistGuid = dr.Guid 
	WHERE  
		dp.Number = @PaidNumber
		AND (dp.BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
 
	----------------- Close/ReOpen Paid 
	--- Close/ReOpen Paid For Bills 
	UPDATE bu000 
	SET Security = @Security, 
		TextFld1 = @PaidNumber 
	WHERE CostGuid = @CostGuid 
		  AND Date = @Date 
	--- Close/ReOpen Paid For Transfers
	SELECT bu1.GUID 
	INTO #BILLGUID 
	FROM  
		bu000 AS bu1 
		INNER JOIN ts000 AS ts ON ts.OutBillGuid = bu1.Guid OR ts.InBillGuid = bu1.Guid 
	WHERE  
		bu1.StoreGuid = @StoreGuid
		AND bu1.Date = @Date 
	 
	SELECT ts.InBillGUID INTO #BILLGUID1 
	FROM ts000 AS ts 
	INNER JOIN #BILLGUID AS bg ON ts.OutBillGUID = bg.GUID 
	 
	INSERT INTO #BILLGUID1 
	SELECT ts.OutBillGUID 
	FROM ts000 ts 
	INNER JOIN #BILLGUID bg on ts.InBillGUID = bg.GUID 
	 
	INSERT INTO #BILLGUID1	 
	SELECT * FROM #BILLGUID 
	 
	UPDATE bu000 
	SET Security = @Security, 
		TextFld1 = @PaidNumber 
	WHERE GUID in(SELECT * FROM #BILLGUID1)  
	 
	--- Close/ReOpen Paid For Entries 
	UPDATE Ce000 SET Security = @Security   
	FROM  
		ce000 AS ce 
		INNER JOIN en000 AS en ON en.ParentGuid = ce.Guid 
		LEFT JOIN er000 AS er ON er.EntryGuid = ce.Guid 
	WHERE	 
		en.CostGuid = @CostGuid AND en.Date = @Date  
		AND (ce.TypeGuid = 0x00 OR ISNULL(er.ParentType, 2) in(2,4,6,8)) 
		 
	-- close/ReOpen Paid for py000 
	UPDATE py000 SET Security = @Security
	FROM 
		py000 py 
		INNER JOIN er000 er ON py.GUID = er.ParentGUID 
		INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID 
		INNER JOIN en000 en ON en.ParentGUID = ce.GUID 
	WHERE  
 		en.CostGuid = @CostGuid AND en.Date = @Date 
		AND  ISNULL(er.ParentType, 2) IN(2,4,6,8) 
		 
	UPDATE DistPaid000 
	SET ClosePaidState = @PaidState, 
		Security = @Security 
	WHERE Number = @PaidNumber
		  AND (BranchGuid = @BranchGuid OR @BranchGuid = 0x0)
	
	SELECT 1 AS ClosePaidState -- Close/ReOpen Paid Done
	COMMIT 
/*
EXEC prcDistClosePaid 1212, 1, 0x00
*/
##############################################
CREATE PROCEDURE prcDistCustsReceived
		@TotalPaid		FLOAT,
		@Notes			NVARCHAR(50),
		@currencyGuid	UNIQUEIDENTIFIER,
		@currencyVal	FLOAT,
		@paidnumber		INT,
		@BranchGuid		UNIQUEIDENTIFIER = 0x0
AS
      SET NOCOUNT ON
      DECLARE
          @Date             DATETIME,
          @SalesManAccGuid  UNIQUEIDENTIFIER,
          @EntryGuid        UNIQUEIDENTIFIER,
          @PyNumber         INT,           
          @PyGuid           UNIQUEIDENTIFIER,
          @opTypeGuid       UNIQUEIDENTIFIER, -- RecieveEntry TypeGuid in op000
          @PyTypeGuid       UNIQUEIDENTIFIER, 
          @EntryNumber      INT 

      SELECT @opTypeGuid = CAST(value AS UNIQUEIDENTIFIER) 
      FROM op000
      WHERE Name = 'DistCfg_CustomersReceived_EntryTypeGuid'
      
      SELECT  @PyTypeGuid = CASE ISNULL(@opTypeGuid, 0x0) 
                                WHEN 0x0 
                                THEN (
                                       SELECT  TOP 1 guid  FROM et000 
                                       WHERE FldDebit = 0 and FldCredit = 1 
                                       ORDER BY sortNum
                                      )
                                ELSE @opTypeGuid
                             END
      
      SELECT @EntryGuid = guid 
      FROM ce000 
      WHERE  Notes LIKE  '%#' + CAST (@paidnumber AS NVARCHAR (6)) + '#%'
			 And (Branch = @BranchGuid or @BranchGuid = 0x0)
			 
      SELECT
            @Date = dp.Date,
            @SalesManAccGuid =  sm.AccGUID  
      FROM DistPaid000 AS dp 
           INNER JOIN Distributor000 AS d ON d.GUID = dp.DistGUID
           INNER JOIN DistSalesman000 AS sm ON sm.GUID = d.PrimSalesmanGUID
      WHERE dp.Number = @paidnumber
			AND (dp.BranchGuid = @BranchGuid or @BranchGuid = 0x0)
      

      IF ISNULL(@EntryGuid, 0x0) = 0x0
      BEGIN 
            SELECT @EntryNumber = ISNULL(MAX(Number), 0) + 1 
            FROM ce000 
            WHERE (Branch = @BranchGuid OR @BranchGuid = 0x0)
            
            SELECT @PyNumber = ISNULL(MAX(Number), 0) + 1 
            FROM py000 
            WHERE TypeGuid = @PyTypeGuid
				  AND (BranchGuid = @BranchGuid or @BranchGuid = 0x0)
            
            SET @EntryGuid = NEWID()
            SET @PyGuid = NEWID()
                        
            INSERT INTO ce000 (type, number, date, debit, credit, notes, guid, security, branch, currencyGuid, currencyval, isposted, TypeGuid)
                   VALUES (1, @EntryNumber, @Date, @TotalPaid, @TotalPaid, @Notes, @EntryGuid, 1, @BranchGuid, @currencyGuid, @currencyVal, 0, @PyTypeGuid)
       
            INSERT INTO py000(Number, Date, Notes, currencyval, skip, Security, GUID, TypeGuid, AccountGUID, CurrencyGUID,BranchGuid)
                  VALUES(@PyNumber, @Date, @Notes , @currencyVal, 0, 1, @PyGuid,@PyTypeGuid, @SalesManAccGuid, @currencyGuid, @BranchGuid)         
                        
            INSERT INTO er000(GUID, EntryGUID, ParentGUID, ParentType, ParentNumber)
                  VALUES(NEWID(), @EntryGuid, @PyGuid, 4, @PyNumber)  
      END
      ELSE 
      BEGIN
          UPDATE 
			ce000 
          SET 
			date		 = @Date ,
            debit		 = @TotalPaid ,
            credit		 = @TotalPaid,
            notes		 =  @Notes,
            currencyGuid = @currencyGuid ,
            currencyval	 = @currencyVal,
            IsPosted	 = 0
		  WHERE 
			ce000.GUID = @EntryGuid
            
          SELECT @PyGuid = GUID, 
				 @PyNumber = number
          FROM  py000 
          WHERE Notes LIKE  '%#' + CAST (@paidnumber AS NVARCHAR (6)) + '#%'
				AND (BranchGuid = @BranchGuid or @BranchGuid = 0x0)
             
          UPDATE py000 
          SET date  = @Date ,
              notes =  @Notes,
              currencyGuid = @currencyGuid ,
              currencyval  = @currencyVal
          WHERE GUID = @PyGuid
                        
            DELETE FROM en000 WHERE ParentGUID = @EntryGuid
      END   
      SELECT @EntryGuid as EntryGuid, @PyGuid AS PyGuid, @PyTypeGuid As PyTypeGuid, @PyNumber AS PyNumber
##############################################	
CREATE PROCEDURE prcDistCustsReceivedDetails
		@enCustAccGuid  UNIQUEIDENTIFIER,
		@enNotes		NVARCHAR(50),
		@number			INT,
		@enValue		FLOAT,
		@EntryGuid		UNIQUEIDENTIFIER,
		@currencyGuid	UNIQUEIDENTIFIER,
		@currencyVal	FLOAT,
		@paidnumber		INT,
		@BranchGuid		UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON
	DECLARE	@SalesManAccGuid  UNIQUEIDENTIFIER,
			@SalesManCostGuid UNIQUEIDENTIFIER,
			@Date DATETIME,
			@IsCostForBothAcc BIT
			
	SELECT 
		@SalesManAccGuid  = sm.AccGUID,
		@SalesManCostGuid = sm.CostGUID,
		@Date = dp.Date
	FROM 
		DistPaid000 AS dp 
		INNER JOIN Distributor000 AS d ON d.GUID = dp.DistGUID
		INNER JOIN DistSalesman000 AS sm ON sm.GUID = d.PrimSalesmanGUID
	WHERE 
		dp.Number = @PaidNumber	
		And (dp.BranchGuid = @BranchGuid or @BranchGuid = 0x0)

	SELECT @IsCostForBothAcc = CostForBothAcc FROM et000 
							   WHERE Guid = (SELECT TypeGuid FROM ce000 WHERE Guid = @EntryGuid)
				
	INSERT INTO en000(Number, Date, Debit, Credit, Notes, GUID, currencyval, ParentGUID, AccountGUID, CurrencyGUID, CostGuid, ContraAccGUID)
		VALUES(@number * 2-1, @Date, @enValue, 0, @enNotes, NEWID(), @currencyVal, @EntryGuid, @SalesManAccGuid, @currencyGuid, CASE @IsCostForBothAcc WHEN 1 THEN @SalesManCostGuid ELSE 0x0 END, @enCustAccGuid)
	            
	INSERT INTO en000(Number, Date, Debit, Credit,   Notes,    GUID,    currencyval,  ParentGUID, AccountGUID,    CurrencyGUID,   CostGuid,        ContraAccGUID)
	   VALUES(@number * 2, @Date, 0, @enValue, @enNotes, NEWID(), @currencyVal, @EntryGuid, @enCustAccGuid, @currencyGuid, @SalesManCostGuid, @SalesManAccGuid)
	   
##############################################
CREATE PROCEDURE RepDistPaidState
	@StartDate			DATETIME		 = '1980-01-01',
	@EndDate			DATETIME		 = '1980-01-01',
	@HierarchyGuid			UNIQUEIDENTIFIER = 0x0,
	@DistributorGuid		UNIQUEIDENTIFIER = 0x0,
	@SalesmanGuid	UNIQUEIDENTIFIER = 0x0,
	@State		INT = 3 -- 0:NotClosed, 1:Closed, 2:All
AS 
	SET NOCOUNT ON 
	CREATE TABLE #Dists(DistGuid UNIQUEIDENTIFIER, SecLevel INT)	
	INSERT INTO  #Dists EXEC GetDistributionsList @DistributorGuid, @HierarchyGuid 

	SELECT dp.Guid AS PaidGuid,
		   dp.Number AS PaidNumber, 
		   Date AS PaidDate, 
		   ClosePaidState, 
		   hi.Guid AS HiGuid,
		   hi.Name AS HiName,
		   dp.DistGuid, 
		   d.Name AS DistName,
		   dp.salesManGuid, 
		   sm.Name AS salesManName,
		   NetLoadValue, 
		   BonusValue, 
		   DiscountValue,  
		   DebtsGranted,
		   DebtsCollected, 
		   NetLoadValue + DebtsCollected - (BonusValue + DiscountValue + DebtsGranted) AS Total,
		   dp.BranchGuid AS BranchGuid,
		   ISNULL(br.Name, '') AS BranchName
	FROM DistPaid000 AS dp
		INNER JOIN #Dists AS dl ON dl.DistGuid = dp.DistGuid
		INNER JOIN Distributor000 AS d ON d.Guid = dp.DistGuid
		INNER JOIN distsalesMan000 AS sm ON sm.Guid = d.PrimSalesManGuid
		INNER JOIN DistHi000 AS hi ON hi.Guid = d.HierarchyGUID
		LEFT JOIN br000 AS br ON br.Guid = dp.BranchGuid
	WHERE 
		Date BETWEEN @StartDate AND @EndDate
		AND  (dp.DistGuid = @DistributorGuid OR @DistributorGuid = 0x0)
		AND  (dp.SalesManGuid = @SalesmanGuid OR @SalesmanGuid = 0x0)
		AND  dp.ClosePaidState = CASE @State 
								   WHEN 0 THEN 0
								   WHEN 1 THEN 1
								   ELSE ClosePaidState
								 END				 
	ORDER BY HiName, DistName, SalesManName, ClosePaidState DESC,  PaidNumber
###########################################
#END
