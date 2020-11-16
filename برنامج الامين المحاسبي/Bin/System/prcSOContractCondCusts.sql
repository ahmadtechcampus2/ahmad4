#########################################################
CREATE PROCEDURE prcSOContractCondCusts
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@AccountGuid	UNIQUEIDENTIFIER = 0x0,
	@IsFirstUnit	BIT = 1,
	@BranchGUID		UNIQUEIDENTIFIER = 0x0
AS
	SET NOCOUNT ON
	
	DECLARE
		@SOTypeContract TINYINT
		
	SET @SOTypeContract = 3
		
	CREATE TABLE #SOConditionalDiscounts(
		SpecialOfferGUID		UNIQUEIDENTIFIER,
		AccountGuid				UNIQUEIDENTIFIER,
		CostGuid				UNIQUEIDENTIFIER,
		CustomerConditionGUID	UNIQUEIDENTIFIER,
		StartDate				DATETIME,
		EndDate					DATETIME,
		IsAllBillTypes			BIT)
		
	CREATE TABLE #SOBill(
		BillGUID		UNIQUEIDENTIFIER,
		BillAccGUID		UNIQUEIDENTIFIER,
		BillCustGUID	UNIQUEIDENTIFIER,
		BillTotal		FLOAT,
		BillTotalExtra	Float,
		BillTotalDisc	FLOAT,
		BillItemExtra	FLOAT,
		BillItemDIsc	FLOAT,
		SoGUID			UNIQUEIDENTIFIER,
		SoStartDate		DATETIME,
		SoCustCondGUID	UNIQUEIDENTIFIER,
		SOAccGUID		UNIQUEIDENTIFIER,
		IsOutput		BIT,
		BillBranch		UNIQUEIDENTIFIER,
		BillDate		DATETIME)
		
	INSERT INTO #SOConditionalDiscounts	
	SELECT 
		GUID,
		AccountGUID,
		CostGUID,
		CustCondGUID,
		StartDate,
		EndDate,
		IsAllBillTypes
	FROM
		SpecialOffers000 AS so
	WHERE
		EXISTS(SELECT * FROM SOConditionalDiscounts000 WHERE SpecialOfferGUID = so.[GUID])
		AND
		[Type] = @SOTypeContract
		AND
		IsActive = 1
		AND
		((StartDate Between @FromDate AND @ToDate) OR (@FromDate Between StartDate AND EndDate))
		AND
		((EndDate Between @FromDate AND @ToDate) OR (@ToDate Between StartDate AND EndDate))
		
	DECLARE
		@custCondSOCursor CURSOR,
		@BillGUID UNIQUEIDENTIFIER,
		@BillAccGUID UNIQUEIDENTIFIER,
		@BillCustGUID UNIQUEIDENTIFIER,
		@BillTotal		FLOAT,
		@BillTotalExtra	Float,
		@BillTotalDisc	FLOAT,
		@BillItemsExtra	FLOAT,
		@BillItemsDisc	FLOAT,
		@SoGUID	UNIQUEIDENTIFIER,
		@SoStartDate	DATETIME,
		@SOCustomerConditionGUID UNIQUEIDENTIFIER,
		@CustomerGUID UNIQUEIDENTIFIER,
		@SOAccGUID UNIQUEIDENTIFIER,
		@IsOutput BIT,
		@SoCostGUID UNIQUEIDENTIFIER,
		@BuCostGUID UNIQUEIDENTIFIER,
		@BillBranchGUID UNIQUEIDENTIFIER,
		@BillDate DATETIME
		
	SET @custCondSOCursor =  
		CURSOR FAST_FORWARD FOR 
		SELECT 
			bu.[GUID], 
			bu.CustAccGUID, 
			bu.CustGUID, 
			bu.Total, 
			bu.TotalExtra, 
			bu.TotalDisc, 
			bu.ItemsExtra, 
			bu.ItemsDisc, 
			soCond.SpecialOfferGUID, 
			soCond.StartDate, 
			soCond.CustomerConditionGUID, 
			socond.AccountGuid, 
			bu.bIsoutput, 
			socond.CostGuid SOCostGuid, 
			bu.CostGuid buCostGuid, 
			bu.Branch, 
			bu.[Date] 
		FROM 
			(SELECT 
				bu.[GUID], 
				bu.CustAccGUID, 
				bu.CustGUID, 
				bu.Total, 
				bu.TotalExtra, bu.TotalDisc, bu.ItemsExtra, bu.ItemsDisc, 
				bu.TypeGUID, bt.bIsoutput, bu.CostGuid, bu.[Date], 
				bu.Branch 
			FROM 
				bu000 bu 
				INNER JOIN bt000 bt ON bu.TypeGUID = bt.[GUID] 
			WHERE 
				bu.[Date] BETWEEN @FromDate AND @ToDate 
				AND (bt.BillType = 1 OR bt.BillType = 3) 
				AND (@BranchGUID = 0x0 OR bu.Branch = @BranchGUID)
				AND (@AccountGuid = 0x0 OR (@AccountGuid <> 0x0 AND EXISTS(SELECT [GUID] FROM [dbo].[fnGetAccountsList](@AccountGuid, DEFAULT) WHERE [GUID] = bu.CustAccGUID)))
			) bu, 
			#SOConditionalDiscounts soCond 
		WHERE
			bu.[Date] BETWEEN soCond.StartDate AND soCond.EndDate 
			AND 
			soCond.IsAllBillTypes = 1 OR (EXISTS(SELECT * FROM SOBillTypes000 soB WHERE bu.TypeGUID = soB.BillTypeGUID)) 
			
	OPEN @custCondSOCursor
	FETCH FROM @custCondSOCursor INTO @BillGUID, @BillAccGUID, @BillCustGUID, @BillTotal, @BillTotalExtra, @BillTotalDisc, @BillItemsExtra, @BillItemsDisc, @SoGUID, @SoStartDate, @SOCustomerConditionGUID, @SOAccGUID, @IsOutput, @SoCostGUID, @BuCostGUID, @BillBranchGUID, @BillDate
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @IsFound BIT
		
		SET @IsFound = 0
		IF (@SoCostGUID = 0x0 OR (EXISTS(SELECT [GUID] FROM fnGetCostsList(@SoCostGUID) WHERE [GUID] = @BuCostGUID)))
		BEGIN
			IF @SOCustomerConditionGUID = 0x0 AND @SOAccGUID = 0x0
			BEGIN
				SET @IsFound = 1
			END
			ELSE
			BEGIN
				IF @SOCustomerConditionGUID <> 0x0
				BEGIN
					EXEC @IsFound = prcIsCustCondVerified @SOCustomerConditionGUID, @BillCustGUID
				END
				IF @IsFound = 0 AND @SOAccGUID <> 0x0
				BEGIN
					IF EXISTS(SELECT [GUID] FROM [dbo].[fnGetCustsOfAcc](@SOAccGUID) WHERE [GUID] = @BillCustGUID)
					BEGIN
						SET @IsFound = 1
					END
				END
			END
			IF @IsFound = 1
			BEGIN
				INSERT INTO #SOBill VALUES(@BillGUID, @BillAccGUID, @BillCustGUID, @BillTotal, @BillTotalExtra, @BillTotalDisc, @BillItemsExtra, @BillItemsDisc, @SoGUID, @SoStartDate, @SOCustomerConditionGUID, @SOAccGUID, @IsOutput, @BillBranchGUID, @BillDate)
			END
		END
		
		FETCH FROM @custCondSOCursor INTO @BillGUID, @BillAccGUID, @BillCustGUID, @BillTotal, @BillTotalExtra, @BillTotalDisc, @BillItemsExtra, @BillItemsDisc, @SoGUID, @SoStartDate, @SOCustomerConditionGUID, @SOAccGUID, @IsOutput, @SoCostGUID, @BuCostGUID, @BillBranchGUID, @BillDate
	END
	CLOSE @custCondSOCursor
	DEALLOCATE @custCondSOCursor
	
	DELETE SO 
	FROM 
		#SOBill so
		INNER JOIN #SOConditionalDiscounts soCond ON so.SoGUID = soCond.SpecialOfferGUID
	WHERE 
		so.BillDate NOT BETWEEN soCond.StartDate AND soCond.EndDate
		
	CREATE TABLE #ApplicableBillItems(
		BillCustomerGUID UNIQUEIDENTIFIER,
		BillGUID UNIQUEIDENTIFIER,
		BillItemGUID UNIQUEIDENTIFIER,
		BillItemTotalPrice FLOAT,
		BillItemQuantity FLOAT,
		BillItemUnit TINYINT,
		SOGUID UNIQUEIDENTIFIER,
		SOStartDate DATETIME,
		SOCondItemGUID UNIQUEIDENTIFIER,
		SOCondItemType TINYINT,
		SOCondItemItemGUID UNIQUEIDENTIFIER,
		IsOutput BIT,
		BillBranch UNIQUEIDENTIFIER)
		
	INSERT INTO #ApplicableBillItems
	SELECT
		sob.BillCustGUID,
		bi.ParentGUID,
		bi.[GUID],
		(
				((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END) - bi.Discount + bi.Extra)
				+ ((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END)* (sob.BillTotalExtra - sob.BillItemExtra)/ sob.BillTotal)
				- ((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END)*(sob.BillTotalDisc - sob.BillItemDIsc)/ sob.BillTotal)
		), -- NEt Price
		CASE @IsFirstUnit
			WHEN 1 THEN bi.Qty
			ELSE CASE socond.Unit WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact WHEN 4 THEN bi.Qty / mt.mtDefUnitFact ELSE bi.Qty END
		END,-- Net Quantiy
		bi.Unity,
		sob.SoGUID,
		sob.SoStartDate,
		socond.[GUID],
		socond.ItemType,
		socond.ItemGUID,
		sob.IsOutput,
		sob.BillBranch
	FROM
		bi000 bi
		INNER JOIN #SOBill sob ON sob.BillGUID = bi.ParentGUID
		INNER JOIN SOConditionalDiscounts000 soCond ON socond.SpecialOfferGUID = sob.SoGUID
		LEFT JOIN vwMt mt ON bi.MatGUID = mt.[mtGUID]
	WHERE
		(soCond.ItemType = 0 OR soCond.ItemType = 1)
		AND
		(
		(soCond.ItemType = 0 AND ((soCond.ItemGUID = bi.MatGUID) OR (soCond.ItemGUID = mt.mtParent)))
		OR
		(soCond.ItemType = 1 AND 
				(
					(soCond.ItemGUID in (SELECT vwMt.mtGroup FROM vwMt WHERE vwMt.mtGUID = bi.MatGUID))
						or 
					(soCond.ItemGUID in (SELECT groupguid FROM gri000 WHERE MatGUID = bi.MatGUID))
				)
				
)
		)
		AND
		NOT EXISTS(SELECT BillItemGUID FROM #ApplicableBillItems WHERE BillItemGUID = bi.[GUID])
		AND
		bi.Price <> 0
		AND
		bi.SOType <> 2
		
	DECLARE 
		@ItemsCursor CURSOR,
		@BillCustomerGUID UNIQUEIDENTIFIER,
		@BillItemGUID UNIQUEIDENTIFIER,
		@BillMatGUID UNIQUEIDENTIFIER,
		@BillItemTotalPrice FLOAT,
		@BillItemQuantity FLOAT,
		@BillItemUnit TINYINT,
		@SOCondItemGUID UNIQUEIDENTIFIER,
		@SOCondItemItemType TINYINT,
		@SOCondItemItemGUID UNIQUEIDENTIFIER,
		@BillBranch	UNIQUEIDENTIFIER
		
	SET @ItemsCursor = CURSOR FAST_FORWARD FOR
		SELECT
			sob.BillCustGUID,
			bi.ParentGUID,
			bi.[GUID],
			(
				((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END) - bi.Discount + bi.Extra)
				+ ((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END)* (sob.BillTotalExtra - sob.BillItemExtra)/ sob.BillTotal)
				- ((bi.Price * CASE bi.Unity WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact ELSE bi.Qty END)*(sob.BillTotalDisc - sob.BillItemDIsc)/ sob.BillTotal)
			), -- NEt Price
			CASE @IsFirstUnit
				WHEN 1 THEN bi.Qty
				ELSE CASE socond.Unit WHEN 2 THEN bi.Qty / mt.mtUnit2Fact WHEN 3 THEN bi.Qty / mt.mtUnit3Fact WHEN 4 THEN bi.Qty / mt.mtDefUnitFact ELSE bi.Qty END
			END,-- Net Quantiy
			bi.Unity,
			bi.MatGuid,
			sob.SoGUID,
			sob.SoStartDate,
			socond.[GUID],
			socond.ItemType,
			socond.ItemGUID,
			sob.IsOutput,
			sob.BillBranch
		FROM
			bi000 bi
			INNER JOIN vwMt mt ON bi.MatGUID = mt.[mtGUID]
			INNER JOIN #SOBill sob ON sob.BillGUID = bi.ParentGUID
			INNER JOIN SOConditionalDiscounts000 soCond ON socond.SpecialOfferGUID = sob.SoGUID
		WHERE
			soCond.ItemType = 2
			
	OPEN @ItemsCursor
	FETCH FROM @ItemsCursor INTO @BillCustomerGUID, @BillGUID, @BillItemGUID, @BillItemTotalPrice ,@BillItemQuantity ,@BillItemUnit ,@BillMatGUID, @SoGUID, @SoStartDate, @SOCondItemGUID, @SOCondItemItemType, @SOCondItemItemGUID, @IsOutput, @BillBranch
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC @IsFound = prcIsMatCondVerified @SOCondItemItemGUID, @BillMatGUID
		IF @IsFound = 1
		BEGIN 
			INSERT INTO #ApplicableBillItems
			VALUES(@BillCustomerGUID, @BillGUID, @BillItemGUID, @BillItemTotalPrice, @BillItemQuantity, @BillItemUnit ,@SoGUID, @SoStartDate, @SOCondItemGUID, @SOCondItemItemType, @SOCondItemItemGUID, @IsOutput, @BillBranch)
		END
		FETCH FROM @ItemsCursor INTO @BillCustomerGUID, @BillGUID, @BillItemGUID, @BillItemTotalPrice ,@BillItemQuantity ,@BillItemUnit ,@BillMatGUID, @SoGUID, @SoStartDate, @SOCondItemGUID, @SOCondItemItemType, @SOCondItemItemGUID, @IsOutput, @BillBranch
	END
	CLOSE @ItemsCursor
	DEALLOCATE @ItemsCursor
			
	SELECT * FROM #ApplicableBillItems
#########################################################
#END
