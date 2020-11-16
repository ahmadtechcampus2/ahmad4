################################################################
CREATE PROCEDURE repSOAchievedContractCondDisc
      @FromDate AS [DATETIME], 
      @ToDate AS [DATETIME], 
      @AccountGuid AS [UNIQUEIDENTIFIER], 
      @Unit AS [INT], -- 0 for unit 1, 1 for unit 2, 2 for unit 3, 3 for default unit. 
	  @IsAchievedCustomers AS [BIT],
	  @IsNotAchievedCustomers AS [BIT]
AS
	 
      SET NOCOUNT ON
      --select * From #E      
      CREATE TABLE [#Result]( 
            [CustomerGuid]          [UNIQUEIDENTIFIER], 
            [CustomerName]          [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [ConditionType]         [INT], 
            [ConditionValue]        [FLOAT], 
            [ItemType]              [INT], 
            [ItemGuid]              [UNIQUEIDENTIFIER], 
            [ItemDescription]       [NVARCHAR](250) COLLATE ARABIC_CI_AI, 
            [AchievedQuatity]       [FLOAT], 
            [AchievedPrice]         [FLOAT], 
            [Unit]                  [INT],
            [DiscountRatio]         [FLOAT], 
            [CalculatedDiscount]    [FLOAT],
            [BranchGUID]			[UNIQUEIDENTIFIER],
            [BranchName]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[IsAchievedCustomers]	[BIT],
			[ContractStartDate]		[DATETIME],
			[ContractEndDate]		[DATETIME]) 
       
      CREATE TABLE #ApplicableBillItems( 
            [BillCustomerGUID]      [UNIQUEIDENTIFIER], 
            [BillGUID]              [UNIQUEIDENTIFIER], 
            [BillItemGUID]          [UNIQUEIDENTIFIER], 
            [BillItemTotalPrice]    [FLOAT], 
            [BillItemQuantity]      [FLOAT], 
            [BillItemUnit]          [TINYINT], 
            [SOGUID]                [UNIQUEIDENTIFIER], 
            [SOStartDate]           [DATETIME], 
            [SOCondItemGUID]        [UNIQUEIDENTIFIER], 
            [SOCondItemType]        [TINYINT], 
            [SOCondItemItemGUID]    [UNIQUEIDENTIFIER], 
            [IsOutput]              [BIT],
            [BranchGUID]			[UNIQUEIDENTIFIER])
       
      DECLARE @HasBranches	 BIT
      
      SET @HasBranches = 0
	  	
	  IF EXISTS(SELECT * FROM br000)
	  BEGIN
		SET @HasBranches = 1
	  END
      
      IF @HasBranches = 0
      BEGIN
			INSERT INTO #ApplicableBillItems EXEC prcSOContractCondCusts @FromDate, @ToDate, @AccountGuid
			--EXEC prcSOContractCondCusts @FromDate, @ToDate, @AccountGuid
			--return
      END
      ELSE
      BEGIN
			DECLARE 
				@BranchesCursor CURSOR,
				@BranchGUID UNIQUEIDENTIFIER
			
			SET @BranchesCursor = 
				CURSOR FAST_FORWARD FOR
					SELECT
						brGUID 
					FROM
						vwBr 
					WHERE 
						POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0
						
			OPEN @BranchesCursor
			FETCH NEXT FROM @BranchesCursor INTO @BranchGUID
			
			WHILE @@FETCH_STATUS = 0
			BEGIN
				INSERT INTO #ApplicableBillItems EXEC prcSOContractCondCusts @FromDate, @ToDate, @AccountGuid, 1, @BranchGUID
				FETCH NEXT FROM @BranchesCursor INTO @BranchGUID
			END
			CLOSE @BranchesCursor
			DEALLOCATE @BranchesCursor
			
			DELETE ab
			FROM
				#ApplicableBillItems ab
				LEFT JOIN (SELECT * FROM vwBr WHERE POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0) br ON ab.BranchGUID = br.[brGUID]
			WHERE
				br.[brGUID] IS NULL
      END

      UPDATE #ApplicableBillItems --*
      SET BillItemQuantity  = 
		  BillItemQuantity / 
				CASE @Unit  
					WHEN 1 THEN CASE ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) End
					WHEN 2 THEN CASE ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) End
					WHEN 3 THEN 
						CASE mt.DefUnit
							WHEN 2 THEN CASE ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) END
							WHEN 3 THEN CASE ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) END
							ELSE 1
						END
					ELSE 1
				END,
		   BillItemUnit = @unit
      FROM #ApplicableBillItems AS Abi
      INNER JOIN bi000 AS bi ON bi.Guid = Abi.BillItemGUID
      INNER JOIN mt000 AS mt ON mt.Guid = bi.MatGuid
-- soCondItemGuid
      SELECT
        CASE IsOutput 
			WHEN 1 THEN SUM([BillItemTotalPrice]) 
			WHEN 0 THEN SUM(-1 * [BillItemTotalPrice]) 
        END AS [AchievedPrice], 
        CASE IsOutput 
			WHEN 1 THEN SUM([BillItemQuantity]) 
			WHEN 0 THEN SUM(-1 * [BillItemQuantity]) 
        END AS [AchievedQuatity], 
        [BillCustomerGUID],
        [SOCondItemItemGUID],
        [BranchGUID]
      INTO 
        #AgregatedBillItems           
      FROM
		#ApplicableBillItems 
      GROUP BY
        [BillCustomerGUID], 
        [BranchGUID],
        [SOCondItemItemGUID], 
        [IsOutput]  
 
      SELECT
		SUM(CASE EN.Debit WHEN 0 THEN EN.Credit ELSE EN.Debit END) [CalculatedDiscount], 
		CAST(Class AS UNIQUEIDENTIFIER) Class,
		EN.ContraAccGUID,
		br.[brGUID]
      INTO
        #EntriesCalculatedDiscounts
      FROM
        SOContractPeriodEntries000 SOContraPerEn
        INNER JOIN ce000 CE ON CE.GUID = SOContraPerEn.EntryGUID
        INNER JOIN en000 EN ON EN.ParentGUID = CE.GUID
        LEFT JOIN (SELECT * FROM vwBr WHERE POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0) br ON br.brGUID = SOContraPerEn.BranchGUID
      WHERE
        CE.Date BETWEEN @FromDate AND @ToDate
        AND
        Class <> ''
        AND
		(@HasBranches = 0 OR (@HasBranches = 1 AND br.[brGUID] IS NOT NULL))
      GROUP BY
        EN.AccountGUID,
        EN.ContraAccGUID,
        EN.Class,
        br.[brGUID]

      INSERT INTO #Result 
      SELECT DISTINCT 
		api.BillCustomerGUID, 
		cu.CustomerName, 
		SOCondDisc.ConditionType, 
		--SOCondDisc.Value, --*
		CASE billItems.SOCondItemType
			 WHEN 0 THEN 
 				SOCondDisc.Value *  
  				CASE SoCondDisc.Unit 
  					WHEN 2 THEN ISNULL(mt.unit2fact, 1)
  					WHEN 3 THEN ISNULL(mt.unit3fact, 1)
  					ELSE 1
  				END
  				  / CASE @Unit 
  						WHEN 1 THEN CASE ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) End
   						WHEN 2 THEN CASE ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) End
 						WHEN 3 THEN 
  							CASE mt.DefUnit
  								WHEN 2 THEN CASE ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) End
  								WHEN 3 THEN CASE ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) End
 								ELSE 1
 							END
 						ELSE 1
 					END
			 ELSE SOCondDisc.Value
		END,
		billItems.SOCondItemType, 
		billItems.SOCondItemItemGUID, 
		CASE billItems.SOCondItemType  
			  WHEN 0 THEN  mt.Name
			  WHEN 1 THEN (SELECT [Name] FROM gr000 WHERE GUID = billItems.SOCondItemItemGUID) 
			  WHEN 2 THEN (SELECT [Name] FROM Cond000 WHERE GUID = billItems.SOCondItemItemGUID) 
		END, 
		api.AchievedQuatity,
		api.AchievedPrice, 
		CASE billItems.SOCondItemType
			WHEN 0 THEN
				CASE @Unit  
					WHEN 3 THEN ISNULL(mt.DefUnit, 1) 
					ELSE CASE @UNIT 
							WHEN 1 THEN CASE ISNULL(mt.unit2, '1') WHEN '1' THEN '1' ELSE '2' END
							WHEN 2 THEN CASE ISNULL(mt.unit3, '1') WHEN '1' THEN '1' ELSE '3' END
							ELSE '1'
						 END 
				End
			ELSE CASE billItems.SOCondItemType
					WHEN 3 THEN billItems.BillItemUnit
					ELSE billItems.BillItemUnit + 1
				 END
		END, --*
		SOCondDisc.DiscountRatio, 
		ISNULL(ecd.CalculatedDiscount, 0),
		br.GUID,
		br.Name,
		CASE
			WHEN ecd.CalculatedDiscount IS NULL THEN 0
			ELSE 1
		END,
		so.StartDate,
		so.EndDate
      FROM
        #AgregatedBillItems api 
        INNER JOIN #ApplicableBillItems billItems ON (billItems.BillCustomerGUID = api.BillCustomerGUID) AND (billItems.BranchGUID = api.BranchGUID) AND (billItems.SOCondItemItemGUID = api.SOCondItemItemGUID)
		INNER JOIN SpecialOffers000 so ON so.[GUID] = billItems.SOGuid
        INNER JOIN SOConditionalDiscounts000 SOCondDisc ON SOCondDisc.SpecialOfferGUID = billItems.SOGUID AND SOCondDisc.[GUID] = billItems.SOCondItemGUID --*
        INNER JOIN cu000 cu ON cu.GUID = api.BillCustomerGUID
		LEFT JOIN #EntriesCalculatedDiscounts ecd ON (SELECT [GUID] FROM cu000 WHERE ConditionalContraDiscAccGUID = ecd.ContraAccGUID) = api.BillCustomerGUID AND ((@HasBranches = 1 AND ecd.brGUID = api.BranchGUID) OR @HasBranches = 0) AND ecd.Class = billItems.SOCondItemGUID
        LEFT JOIN mt000 AS mt ON mt.GUID = billItems.SOCondItemItemGUID
        LEFT JOIN br000 br ON br.GUID = billItems.BranchGUID

	 IF @IsAchievedCustomers = 0
	 BEGIN
		DELETE FROM #Result WHERE  IsAchievedCustomers = 1
	 END

	 IF @IsNotAchievedCustomers = 0
	 BEGIN
		DELETE FROM #Result WHERE  IsAchievedCustomers = 0
	 END

     DECLARE @BranchesCount INT
     
     SET @BranchesCount = (SELECT COUNT(*) FROM vwBr WHERE POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0)
     
     SELECT 
	 	CustomerGuid,
	 	CustomerName,
	 	BranchGUID,
	 	BranchName,
	 	ConditionType,
	 	ConditionValue,
	 	ItemType,
	 	ItemGuid,
	 	ItemDescription,
	 	AchievedQuatity,
	 	AchievedPrice,
	 	Unit,
	 	DiscountRatio,
	 	SUM(CalculatedDiscount) AS CalculatedDiscount,
	 	@BranchesCount BranchesCount,
		(
			(
				CAST(
				DATEDIFF(DAY,
				CASE
					WHEN @FromDate >= ContractStartDate THEN @FromDate
					ELSE ContractStartDate
				END,
				CASE
					WHEN @ToDate <= ContractEndDate THEN @ToDate
					ELSE ContractEndDate
				END)
				AS FLOAT)
				/
				CAST(DATEDIFF(DAY, ContractStartDate, ContractEndDate) AS FLOAT)
			) * 100
		) AS ExpectedRatio
     FROM 
		#Result  
     GROUP BY 
		CustomerGuid,
		CustomerName,
		BranchGUID,
		BranchName,
		ConditionType,
		ConditionValue,
		ItemType,
		ItemGuid,
		ItemDescription,
		AchievedQuatity,
		AchievedPrice,
		Unit,
		DiscountRatio,
		ContractStartDate,
		ContractEndDate
/* 
EXECUTE [repSOAchievedContractCondDisc] '1/1/2011', '12/31/2011', 0x0, 0
*/

################################################################
#END	
