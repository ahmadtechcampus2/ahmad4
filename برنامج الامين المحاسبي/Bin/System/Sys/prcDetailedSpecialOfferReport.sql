###############################################################################
CREATE PROC PrcDetailedSpecialOfferReport
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@ShowDetails		BIT,
	@TypesBitwise		INT,
	@AccountGuid		UNIQUEIDENTIFIER,
	@OfferGuid			UNIQUEIDENTIFIER,
	@CustomerCondition	UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	CREATE TABLE #Accounts(Guid UNIQUEIDENTIFIER, Security INT, Level INT)
	INSERT INTO #Accounts EXEC prcGetAccountsList @AccountGuid

	CREATE TABLE #Custs (Guid UNIQUEIDENTIFIER, Security INT)
	INSERT INTO #Custs EXEC [prcGetCustsList] 0x0, @AccountGuid, @CustomerCondition
	IF ISNULL(@CustomerCondition, 0x0) = 0x0
		INSERT INTO #Custs VALUES(0x0, 1)
	-- result1
	CREATE TABLE #Result(
	 CustomerGuid	UNIQUEIDENTIFIER,
	 CustomerName	NVARCHAR(255) COLLATE ARABIC_CI_AI,
	 CustomerLatinName NVARCHAR(255),
	 BillGuid		UNIQUEIDENTIFIER,
	 BillNumber		INT,
	 BillSum		FLOAT,
	 OfferName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
	 OfferCode		NVARCHAR(255),
	 OfferLatinName NVARCHAR(255),
	 SOGuid			UniqueIdentifier,
	 ExecutionCount INT,
	 SalesDiscount	FLOAT,
	 QuantityGiven	FLOAT)
	
	-- Offer SpecialOffers
	IF (@typesBitwise & 1 > 0) 
	BEGIN
		INSERT INTO #Result
 		SELECT 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			CASE WHEN @ShowDetails = 1 THEN so.Name ELSE '' END,
			CASE WHEN @ShowDetails = 1 THEN so.Code ELSE '' END,
			CASE WHEN @ShowDetails = 1 THEN so.LatinName ELSE '' END,
			so.Guid,
			SUM(CAST((bubi.biQty / SOItems.Quantity * [dbo].[fnGetMaterialUnitFact](bubi.biMatPtr ,SOItems.Unit)) AS INT)),
			0,
			0
		FROM 
			SpecialOffers000 AS so
            INNER JOIN SOItems000 AS SOItems ON SoItems.SpecialOfferGuid = so.Guid
            INNER JOIN vwbubi as bubi ON bubi.biSoGuid = soItems.Guid
            INNER JOIN #Custs as cu ON cu.Guid = bubi.buCustPtr
            LEFT JOIN cu000 as cust ON cust.Guid = cu.Guid
            INNER JOIN #Accounts AS ac ON ac.Guid = bubi.buCustAcc
		WHERE 
			bubi.buDate BETWEEN @FromDate AND @ToDate 
			AND 
			(SO.Guid = @OfferGuid OR @OfferGuid = 0x0)
			AND
			so.[Type] = 0
			AND
			so.IsActive = 1
		GROUP BY 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			so.Name,
			so.Code,
			so.LatinName,
			so.Guid

		UPDATE r
 			SET r.QuantityGiven = 
				(SELECT SUM(bi.biQty) + SUM(bi.biBonusQnt) 
					FROM 
						vwbubi bi 
						INNER JOIN SOOfferedItems000 soi ON bi.biSOGuid = soi.[GUID] 
					WHERE 
						bi.buCustPtr = r.CustomerGuid
						AND
						soi.[SpecialOfferGuid] = r.SOGuid 
						AND 
						bi.[buDate] BETWEEN @FromDate AND @ToDate)
 		FROM
 			#Result r
	END

	-- SpecialOffers Sales
	IF (@typesBitwise & 2 > 0) 
	BEGIN
		INSERT INTO #Result
 		SELECT 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			CASE WHEN @ShowDetails = 1 THEN so.Name ELSE '' END,
			CASE WHEN @ShowDetails = 1 THEN so.Code ELSE '' END,
			CASE WHEN @ShowDetails = 1 THEN so.LatinName ELSE '' END,
			so.Guid,
			SUM(CAST((bubi.biQty / SOItems.Quantity * [dbo].[fnGetMaterialUnitFact](bubi.biMatPtr ,SOItems.Unit)) AS INT)),
			SUM(bubi.biDiscount),
			0
		FROM 
			SpecialOffers000 AS so
            INNER JOIN SOItems000 AS SOItems ON SoItems.SpecialOfferGuid = so.Guid
            INNER JOIN vwbubi as bubi ON bubi.biSoGuid = soItems.Guid
            INNER JOIN #Custs as cu ON cu.Guid = bubi.buCustPtr
            LEFT JOIN cu000 as cust ON cust.Guid = cu.Guid
            INNER JOIN #Accounts AS ac ON ac.Guid = bubi.buCustAcc
		WHERE 
			bubi.buDate BETWEEN @FromDate AND @ToDate 
			AND 
			(SO.Guid = @OfferGuid OR @OfferGuid = 0x0)
			AND 
			so.[Type] = 1
			AND 
			so.IsActive = 1
		GROUP BY 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			so.Name,
			so.Code,
			so.LatinName,
			so.Guid
	END

	-- MultiItems
	IF @TypesBitwise & 4 > 0 
	BEGIN
		INSERT INTO #Result
 		SELECT 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			so.Name,
			so.Code,
			so.LatinName,
			so.Guid,
			0,
			SUM(bubi.biDiscount),
			SUM(bubi.biBonusQnt)
		FROM 
			SpecialOffers000 AS so
			INNER JOIN SOItems000 AS SOItems ON SoItems.SpecialOfferGuid = so.Guid
			INNER JOIN vwbubi as bubi ON bubi.biSoGuid = soItems.Guid
			INNER JOIN #Custs as cu ON cu.Guid = bubi.buCustPtr
			LEFT JOIN cu000 as cust ON cust.Guid = cu.Guid
			INNER JOIN #Accounts AS ac ON ac.Guid = bubi.buCustAcc
		WHERE 
			bubi.buDate BETWEEN @FromDate AND @ToDate
			AND (SO.Guid = @OfferGuid OR @OfferGuid = 0x0)
			AND SO.Type = 2
			AND so.IsActive = 1
		GROUP BY 
			cust.Guid,
			cust.CustomerName,
			cust.LatinName,
			bubi.buGuid,
			bubi.buNumber,
			bubi.butotal,
			so.Name,
			so.Code,
			so.LatinName,
			so.Guid

		UPDATE 
			#Result
		SET 
			ExecutionCount = t.ExcecCnt
		FROM 
			#Result AS res	
			INNER JOIN 	(
				SELECT bubi.buGuid AS buGuid, so.Guid AS soGuid, SUM(bubi.biQty / items.Quantity) / COUNT(DISTINCT Items.Number) AS ExcecCnt
				FROM 
					SpecialOffers000 AS so
					INNER JOIN soItems000 AS items ON items.SpecialOfferGuid = so.GUID
					INNER JOIN vwbubi AS bubi ON bubi.biSoGuid = items.Guid
				WHERE 
					so.type = 2
					AND so.IsActive = 1
					AND bubi.buDate BETWEEN @FromDate AND @ToDate
				GROUP BY bubi.buGuid, so.Guid
			)AS t ON t.buGuid = res.BillGuid AND t.soGuid = res.SoGuid

		UPDATE 
			#Result
		SET 
			QuantityGiven = t.QuantityGiven,
			SalesDiscount = res.SalesDiscount + t.SalesDiscount
		FROM 
			#Result AS res	
			INNER JOIN 	(
				SELECT bubi.buGuid, so.GUID AS soGuid, SUM(bubi.biQty+bubi.bibonusQnt) QuantityGiven, SUM(biDiscount) AS SalesDiscount
				FROM 		
					SpecialOffers000 AS so
					INNER JOIN soOfferedItems000 AS offered ON offered.SpecialOfferGuid = so.Guid
					INNER JOIN vwbubi AS bubi ON bubi.biSoGuid = offered.Guid
				WHERE 
					so.Type = 2
					AND so.IsActive = 1
					AND bubi.buDate BETWEEN @FromDate AND @ToDate
				GROUP by
					bubi.buGuid, 
					so.GUID 
			)AS t ON t.buGuid = res.BillGuid AND t.soGuid = res.SoGuid
	END
	
	IF (@typesBitwise & POWER(2, 3)) > 0
	BEGIN
		INSERT INTO #Result
 			SELECT 
				cust.Guid,	
				cust.CustomerName,
				cust.LatinName,
				bubi.buGuid,
				bubi.buNumber,
				bubi.butotal,
				so.Name,
				so.Code,
				so.LatinName,
				so.Guid,
				count(DISTINCT bubi.buGuid),
				Sum(bubi.biDiscount),
				sum(bubi.biBonusQnt)
			FROM
				SpecialOffers000 AS so
				INNER JOIN SOItems000 AS SOItems ON SoItems.SpecialOfferGuid = So.Guid
				INNER JOIN ContractBillItems000 AS cob ON cob.ContractItemGUID = soItems.GUID
				INNER JOIN vwbubi as bubi ON bubi.biGuid = cob.BillItemGUID
				INNER JOIN #Custs AS cu ON cu.Guid = bubi.buCustPtr
				LEFT JOIN cu000 as cust ON cust.Guid = cu.Guid
				INNER JOIN #Accounts AS ac ON ac.Guid = bubi.buCustAcc
			WHERE 
				@TypesBitwise & POWER(2, so.Type) > 0
				AND SO.Type = 3
				AND  bubi.buDate BETWEEN @FromDate AND @ToDate
				AND SO.Guid = @OfferGuid OR @OfferGuid = 0x0
				AND so.IsActive = 1
			GROUP BY
				cust.Guid,
				cust.CustomerName,
				cust.LatinName,
				bubi.buGuid,
				bubi.buNumber,
				bubi.butotal,
				so.Name,
				so.Code,
				so.LatinName,
				so.Guid
	END

	IF (@typesBitwise & POWER(2, 4)) > 0
	BEGIN
		INSERT INTO #Result
 			SELECT
				cust.Guid,
				cust.CustomerName,
				cust.LatinName,
				bubi.buGuid,
				bubi.buNumber,
				bubi.butotal,
				so.Name,
				so.Code,
				so.LatinName,
				so.Guid,
				COUNT(bubi.buGuid),
				SUM(bubi.biDiscount),
				SUM(bubi.biBonusQnt)
			FROM 
				vwbubi as bubi 
				INNER JOIN SOPeriodBudgetItem000 AS PBudget ON PBudget.Guid = bubi.biSoGuid
				INNER JOIN SpecialOffers000 AS so ON so.Guid = PBudget.SpecialOfferGuid
				INNER JOIN #Custs AS cu ON bubi.buCustPtr = cu.Guid
                LEFT JOIN cu000 as cust ON cust.Guid = cu.Guid
				INNER JOIN #Accounts AS ac ON ac.Guid = bubi.buCustAcc
			WHERE 
				SO.Type = 4
				AND bubi.buDate BETWEEN @FromDate AND @ToDate
				AND (SO.Guid = @OfferGuid OR @OfferGuid = 0x0)
				AND so.IsActive = 1
			GROUP BY
				cust.Guid,
				cust.CustomerName,
				cust.LatinName,
				bubi.buGuid,
				bubi.buNumber,
				bubi.butotal,
				so.Name,
				so.Code,
				so.LatinName,
				so.Guid
	END

	IF @ShowDetails = 1
	BEGIN
		SELECT 
			CustomerGuid,CustomerName, CustomerLatinName, BillGuid,BillNumber, BillSum, OfferName, OfferCode, OfferLatinName, ExecutionCount, SalesDiscount, QuantityGiven
		FROM 
			#Result
		ORDER BY 
			CustomerName, CustomerLatinName, BillNumber, OfferName
	END
	ELSE
	BEGIN
		SELECT
			CustomerGuid, 
			CustomerName,
			CustomerLatinName,
			BillGuid,
			BillNumber,
			BillSum AS BillSum,
			Sum(ExecutionCount) AS ExecutionCount,
			Sum(SalesDiscount) SalesDiscount,
			QuantityGiven QuantityGiven
		INTO 
			#FinalResult
		FROM
			#Result
		GROUP BY 
			CustomerGuid,
			CustomerName, 
			CustomerLatinName, 
			BillNumber,
			BillGuid, 
			BillSum, 
			QuantityGiven
			
		SELECT
			CustomerGuid,
			CustomerName,
			CustomerLatinName, 
			0x0 BillGuid,
			0 AS BillNumber,
			(select SUM(bSum) from (select Distinct BillNumber, BillSum as bSum from #FinalResult as sub where ISNULL(sub.CustomerGuid, 0x0) = ISNULL(final.CustomerGuid, 0x0) ) as t) AS BillSum,
			'' AS OfferName,
			'' AS OfferCode,
			'' AS OfferLatinName,
			Sum(ExecutionCount) ExecutionCount,
			Sum(SalesDiscount) SalesDiscount,
			SUM(QuantityGiven) QuantityGiven
		FROM
			#FinalResult AS final
		GROUP BY
			CustomerGuid, 
			CustomerName, 
			CustomerLatinName
		ORDER BY 
			CustomerName,
			CustomerLatinName
END
###############################################################################################
#END