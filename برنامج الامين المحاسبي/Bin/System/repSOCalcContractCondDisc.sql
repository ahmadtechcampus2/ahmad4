#########################################
CREATE PROCEDURE repSOCalcContractCondDisc
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@AccountGuid		UNIQUEIDENTIFIER = 0x0,
	@Unit				int  = 1, -- 2: unit2, 3: unit3, 4: DefaultUnit, else unit1.
	@ShowPeriodsDetails bit = 1  -- 0: hide periods details, 1: show periods details.
AS
	SET NOCOUNT ON
	SET @FromDate =  DATEADD(DAY, 0, DATEDIFF(DAY, 0, @FromDate))
	SET @ToDate =  DATEADD(DAY, 0, DATEDIFF(DAY, 0, @ToDate))
	--select * from #e
	CREATE TABLE #AppBillItems
	(
		FromDate			DateTime,
		ToDate				DateTime,
		BillCustomerGUID	UNIQUEIDENTIFIER,
		BillGUID			UNIQUEIDENTIFIER,
		BillItemGUID		UNIQUEIDENTIFIER,
		BillItemTotalPrice	FLOAT,
		BillItemQuantity	FLOAT,
		BillItemUnit		TINYINT,
		SOGUID				UNIQUEIDENTIFIER,
		SOStartDate			DATETIME,
		SOCondItemGUID		UNIQUEIDENTIFIER,
		SOCondItemType		TINYINT,
		SOCondItemItemGUID	UNIQUEIDENTIFIER,
		IsOutput			BIT,
		BranchGUID			UNIQUEIDENTIFIER)
	
	DECLARE @PeriodLength	 INT,
			@FirstDayOfMonth DATETIME,
			@LastDayOfMonth	 DATETIME,
			@HasBranches	 BIT
	
	SET @HasBranches = 0
	
	IF EXISTS(SELECT * FROM br000)
	BEGIN
		SET @HasBranches = 1
	END
	
	SELECT  @PeriodLength = DATEDIFF(mm, @FromDate, @ToDate) + 1,
			@FirstDayOfMonth = DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, @FromDate), 0)) + 1,
			@LastDayOfMonth  = DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, @FromDate)+1, 0))
	
	IF @FirstDayOfMonth < @FromDate
		SET @FirstDayOfMonth = @FromDate
	
	WHILE @PeriodLength > 0 
	BEGIN
		IF @LastDayOfMonth > @ToDate
			SET @LastDayOfMonth = @ToDate
		
		SET @FirstDayOfMonth =  DATEADD(DAY, 0, DATEDIFF(DAY, 0, @FirstDayOfMonth)) 
		SET @LastDayOfMonth =  DATEADD(DAY, 0, DATEDIFF(DAY, 0, @LastDayOfMonth)) 
		
		INSERT INTO #AppBillItems(BillCustomerGUID, BillGUID, BillItemGUID, BillItemTotalPrice, BillItemQuantity, BillItemUnit, SOGUID, SOStartDate, SOCondItemGUID, SOCondItemType, SOCondItemItemGUID, IsOutput, BranchGUID) 
		EXEC prcSOContractCondCusts @FirstDayOfMonth, @LastDayOfMonth, @AccountGuid
		
		IF @HasBranches = 1
		BEGIN
			DELETE ab
			FROM
				#AppBillItems ab
				LEFT JOIN (SELECT * FROM vwBr WHERE POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0) br ON ab.BranchGUID = br.[brGUID]
			WHERE
				br.[brGUID] IS NULL
		END
		
		UPDATE 
			#AppBillItems
		SET 
			FromDate = @FirstDayOfMonth,
			ToDate	= @LastDayOfMonth
		WHERE 
			FromDate IS NULL
			AND ToDate IS NULL
			
		SELECT	@PeriodLength	 = @PeriodLength - 1,
				@FromDate		 = DATEADD(mm, 1, @FromDate),
				@FirstDayOfMonth = DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, @FromDate), 0)) + 1,
				@LastDayOfMonth  = DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, @FromDate)+1, 0))
	END
	
	UPDATE 	#AppBillItems
			SET BillItemQuantity  = BillItemQuantity 
									/ case @Unit  
										When 1 then case ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) End
										When 2 then case ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) End
										when 3 then case mt.DefUnit
														WHEN 2 THEN CASE ISNULL(mt.unit2fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit2fact, 1) End
														WHEN 3 THEN CASE ISNULL(mt.unit3fact, 1) WHEN 0 THEN 1 ELSE ISNULL(mt.unit3fact, 1) End
														else 1
													End
										Else 1
								   End,
			BillItemUnit = @unit
	From #AppBillItems as Abi
	INNER JOIN bi000 as bi ON bi.Guid = abi.BillItemGUID
	INNER JOIN mt000 as mt ON mt.Guid = bi.MatGuid

	SELECT  Fromdate, 
			Todate, 
			billCustomerGuid, 	
			SUM(BillItemTotalPrice * CASE IsOutPut WHEN 1 THEN 1 ELSE -1 END) AS BillItemsTotalPrice,
			SUM(BillItemQuantity * CASE IsOutPut WHEN 1 THEN 1 ELSE -1 END) AS BillItemsQuantity,
			BillItemUnit,
			SoGuid,
			SoStartDate,
			SoCondItemGuid,
			SoCondItemType,
			SoCondItemItemGuid,
			BranchGUID
	INTO #AppBi
	From #AppBillItems
	GROUP BY FromDate, ToDate, BillCustomerGuid, BillItemUnit, SoGuid,
			 SoStartDate, SoCondItemGuid, SoCondItemType, SoCondItemItemGuid, BranchGUID
	-------------------------------------------------
	-- Result
	CREATE TABLE #PreResult
	(
		CustomerGuid	UNIQUEIDENTIFIER,
		CustomerName	NVARCHAR(250),
		FromDate		DATETIME DEFAULT '3000-01-01',
		ToDate			DATETIME DEFAULT '3000-01-01',
		ItemType		INT, -- 0: material, 1: group, 2: product condition.
		ItemGuid		UNIQUEIDENTIFIER, -- material, group or condition GUID
		ItemDescription NVARCHAR(250) COLLATE ARABIC_CI_AI, -- the name of the material, group or condition
		Quantity		FLOAT, -- Net quantity (after implementing the gifts).
		Unit			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		QuantityPrice	FLOAT,
		DiscountRatio	FLOAT, -- The discount ratio specified in the contract special offer.
		CalcedDiscount	FLOAT, -- The total discount calculated that found in the generated entry of the monthly state.
		RealDiscount	FLOAT, -- The real total discount which is recalculated when the report is called.
		soGuid			UNIQUEIDENTIFIER,
		class			UNIQUEIDENTIFIER, -- conditional Disc Guid
		ContraAccGuid	UNIQUEIDENTIFIER,
		Total			FLOAT, -- The net total value after implementing the discounts and additions. 
		BranchGUID		UNIQUEIDENTIFIER,
		BranchName		NVARCHAR(250),
		LineType		BIT -- 1: GroupLine, 2:not groupLine
	)
	
	SELECT TOP 0 
		CustomerGuid, 
		CustomerName, 
		FromDate, 
		ToDate, 
		ItemType, 
		ItemGuid, 
		ItemDescription, 
		Quantity, 
		Unit, 
		QuantityPrice, 
		DiscountRatio, 
		CalcedDiscount, 
		RealDiscount, 
		Total, 
		BranchGUID,
		BranchName,
		LineType
	INTO 
		#Result 
	FROM 
		#PreResult

	INSERT INTO 
		#PreResult
	SELECT DISTINCT
		Abi.BillCustomerGUID,
		cu.CustomerName,
		Abi.FromDate,
		Abi.ToDate,
		SOCondItemType, -- item type
		Abi.SOCondItemItemGUID, -- itemGuid
		CASE SOCondItemType
			WHEN 0 THEN mt.Name
			WHEN 1 THEN gr.Name 
			ELSE cond.Name 
		END, -- itemDisc
		Abi.BillItemsQuantity, -- Quantity
		CASE SOCondItemType 
			WHEN 0 THEN CASE @Unit  
							WHEN 1 THEN CASE(ISNULL(mt.unit2, '')) WHEN '' THEN mt.Unity ELSE mt.Unit2 End 
							WHEN 2 THEN CASE(ISNULL(mt.unit3, '')) WHEN '' THEN mt.Unity ELSE mt.Unit3 End
							WHEN 3 THEN 
									CASE DefUnit 
										WHEN 2 THEN CASE(ISNULL(mt.unit2, '')) WHEN '' THEN mt.Unity ELSE mt.Unit2 END
										WHEN 3 THEN CASE(ISNULL(mt.unit3, '')) WHEN '' THEN mt.Unity ELSE mt.Unit3 END
										ELSE ISNULL(mt.Unity, '')
									END
							ELSE ISNULL(mt.Unity, '')
						END
			ELSE ''
		END, -- unit Name
		Abi.BillItemsTotalPrice, -- TotalPrice
		SoCd.DiscountRatio, -- discountRatio
		SoCd.DiscountRatio/100 * Abi.BillItemsTotalPrice, -- calced Discount
		0, -- RealDiscount
		Abi.soGuid,
		SoCd.Guid,
		cu.ConditionalContraDiscAccGUID,
		Abi.BillItemsTotalPrice, -- Total
		br.[GUID],
		br.Name,
		0 -- linetype
	FROM 
		#AppBi AS Abi
		INNER JOIN SOConditionalDiscounts000 AS SoCd ON SoCd.SpecialOfferGuid = Abi.SoGuid
		INNER JOIn cu000 as cu ON cu.Guid = Abi.BillCustomerGUID
		LEFT JOIN br000 br ON abi.BranchGUID = br.[GUID]
		LEFT JOIN mt000 as mt ON mt.Guid = Abi.SOCondItemItemGUID AND mt.Guid = SoCd.ItemGUID
		LEFT JOIN gr000 as gr ON gr.Guid = Abi.SOCondItemItemGUID AND gr.Guid = SoCd.ItemGUID
		LEFT JOIN cond000 as cond ON cond.Guid = Abi.SOCondItemItemGUID AND cond.Guid = SoCd.ItemGUID


	DELETE FROM #PreResult WHERE ItemDescription IS NULL

	DECLARE  
		 @Cursor		CURSOR,
		 @cuGuid		UNIQUEIDENTIFIER,
		 @ContraAccGuid UNIQUEIDENTIFIER,
		 @Sdate			DATETIME,
		 @Edate			DATETIME,
		 @RealDisc		FLOAT,
		 @Class			UNIQUEIDENTIFIER
		
		SET @Cursor = 
			CURSOR FAST_FORWARD 
				FOR
				SELECT
					CustomerGuid,
					FromDate,
					ToDate,
					SUM(RealDisc),
					ContraAccGuid,
					Class 
				From(
					SELECT DISTINCT 
						pr.CustomerGuid CustomerGuid, 
						pr.FromDate FromDate, 
						pr.ToDate ToDate, 
						en.Debit RealDisc, 
						en.ContraAccGUID ContraAccGUID, 
						CAST(CASE ISNULL(en.Class, '') WHEN '' THEN '00000000-0000-0000-0000-000000000000' ELSE en.class END AS UNIQUEIDENTIFIER) Class,
						en.AccountGuid
					 FROM
						#PreResult AS pr
						INNER JOIN SOConditionalDiscounts000 AS SoCd ON SoCd.SpecialOfferGuid = pr.SoGuid
						INNER JOIn cu000 as cu ON cu.Guid = pr.CustomerGuid
						INNER JOIN en000 as en ON SoCd.Guid = CAST(CASE ISNULL(en.Class, '') WHEN '' THEN '00000000-0000-0000-0000-000000000000' ELSE en.class END AS UNIQUEIDENTIFIER) 
							AND en.ContraAccGuid = cu.ConditionalContraDiscAccGUID
						LEFT JOIN br000 br ON br.[GUID] = pr.BranchGUID
					WHERE 
						en.Date BETWEEN pr.FromDate AND pr.ToDate
					--GROUP BY 
					--	pr.CustomerGuid, en.ContraAccGuid, en.Debit, en.AccountGUID, pr.FromDate, pr.ToDate, CAST(CASE ISNULL(en.Class, '') WHEN '' THEN '00000000-0000-0000-0000-000000000000' ELSE en.class END AS UNIQUEIDENTIFIER) 		 
					) as t
				GROUP BY
					CustomerGuid,
					FromDate,
					ToDate,
					ContraAccGuid,
					Class
					
					
					--SELECT DISTINCT 
					--	pr.CustomerGuid CustomerGuid, 
					--	pr.FromDate FromDate, 
					--	pr.ToDate ToDate, 
					--	en.Debit RealDisc, 
					--	en.Date,
					--	en.ContraAccGUID ContraAccGUID, 
					--	CAST(CASE ISNULL(en.Class, '') WHEN '' THEN '00000000-0000-0000-0000-000000000000' ELSE en.class END AS UNIQUEIDENTIFIER) Class,
					--	en.AccountGuid
					-- FROM
					--	#PreResult AS pr
					--	INNER JOIN SOConditionalDiscounts000 AS SoCd ON SoCd.SpecialOfferGuid = pr.SoGuid
					--	INNER JOIn cu000 as cu ON cu.Guid = pr.CustomerGuid
					--	INNER JOIN en000 as en ON SoCd.Guid = CAST(CASE ISNULL(en.Class, '') WHEN '' THEN '00000000-0000-0000-0000-000000000000' ELSE en.class END AS UNIQUEIDENTIFIER) 
					--		AND en.ContraAccGuid = cu.ConditionalContraDiscAccGUID
					--	LEFT JOIN br000 br ON br.[GUID] = pr.BranchGUID
					----WHERE 
					----	en.Date BETWEEN pr.FromDate AND pr.ToDate
					
		OPEN @Cursor 
		FETCH NEXT FROM @Cursor INTO @CuGuid, @SDate, @EDate, @RealDisc, @ContraAccGuid, @Class
		WHILE @@FETCH_STATUS = 0 
			BEGIN
				UPDATE #PreResult
				SET RealDiscount = @RealDisc
				WHERE CustomerGuid = @CuGuid AND FromDate = @SDate AND ToDate = @EDate AND ContraAccGuid = @ContraAccGuid And Class = @Class
				
				FETCH NEXT FROM @Cursor INTO @CuGuid, @SDate, @EDate, @RealDisc, @ContraAccGuid, @Class
			END 
		CLOSE @Cursor 
		DEALLOCATE @Cursor
		
	---------------------------------------------
	-- RESULT
	IF @ShowPeriodsDetails = 1 
		INSERT INTO 
			#Result
		SELECT
			customerGuid,
			CustomerName,
			FromDate,
			ToDate,
			ItemType,
			ItemGuid,
			ItemDescription,
			Quantity,
			Unit,
			QuantityPrice,
			DiscountRatio,
			RealDiscount,
			CalcedDiscount,
			Total,
			BranchGUID,
			BranchName,
			0
		FROM 
			#PreResult
			
	INSERT INTO #Result(CustomerGuid, CustomerName, ItemType, ItemGuid, ItemDescription, Quantity, Unit, QuantityPrice, DiscountRatio, CalcedDiscount, RealDiscount, Total, BranchGUID, BranchName, lineType)
	SELECT 
		CustomerGuid,
		CustomerName,
		ItemType,
		ItemGuid,
		ItemDescription,
		SUM(Quantity) AS Quantity,
		Unit,
		SUM(QuantityPrice) AS QuantityPrice,
		DiscountRatio,
		SUM(RealDiscount) AS RealDiscount,
		SUM(CalcedDiscount) AS CalcedDiscount,
		SUM(Total) AS Total,
		BranchGUID,
		'',
		1
	FROM #PreResult
	GROUP BY
		customerGuid,
		CustomerName,
		ItemType,
		ItemGuid,
		ItemDescription,
		Unit,
		DiscountRatio,
		BranchGUID,
		BranchName,
		LineType

	SELECT 
		r.CustomerGuid,
		cu.CustomerName,	
		CASE WHEN FromDate IS NULL THEN '3000-01-01' ELSE Fromdate END AS Fromdate,
		CASE WHEN ToDate IS NULL THEN '3000-01-01' ELSE ToDate END AS Todate,
		ItemType,		
		ItemGuid,		
		ItemDescription, 
		Quantity,		
		Unit,			
		QuantityPrice,	
		DiscountRatio,	
		CalcedDiscount,	
		RealDiscount,	
		Total,
		BranchGUID,
		BranchName,
		LineType			
	From 
		#Result AS r
		INNER JOIN cu000 AS cu ON cu.Guid = r.CustomerGuid
	ORDER BY 
		cu.CustomerName,
		CASE @HasBranches
			WHEN 1 THEN BranchGUID 
		END desc, 
		CASE @HasBranches
			WHEN 1 THEN BranchName 
		END desc,
		FromDate, 
		ToDate, 
		ItemDescription
	
	SELECT DISTINCT 
		ItemDescription, itemGuid 
	FROM 
		#Result
	ORDER BY
		ItemDescription		
		
	SELECT COUNT(*) AS BranchCount FROM vwBr WHERE POWER(2, brNumber - 1) & dbo.fnBranch_getCurrentUserReadMask_scalar(1) > 0
	
	SELECT COUNT(DISTINCT CustomerName) AS CustomersCnt FROM #Result
/*
EXECUTE [repSOCalcContractCondDisc] '1/1/2011', '10/30/2011', 0X0, 2, 1
*/
##########################################################################
#END