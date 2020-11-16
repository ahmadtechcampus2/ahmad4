#########################################################
CREATE PROCEDURE PrcTotalSpecialOfferReport
	@FromDate DATETIME ='1-1-2016', -- First value in date range
	@ToDate DATETIME='12-12-2016', -- Last value in date range
	@showDetails BIT = 0, -- For each special offer type, show its details
	@typesBitwise INT=128 -- Represents one special offer type or more, For each special offer type there is number of a power of 2
AS
	SET NOCOUNT ON
	
	CREATE TABLE #Result(
		SOGuid				UNIQUEIDENTIFIER,
		OfferType			INT,
		IsTotalRecord		BIT,
		Quantity			FLOAT,
		QuantityDiscount	FLOAT,
		ExecutionCount		INT,
		SalesDiscount		FLOAT,
		QuantityGiven		FLOAT)

 	IF (@typesBitwise & POWER(2, 0) > 0)
 	BEGIN
 		INSERT INTO #Result
 		SELECT
 			so.GUID,
 			so.[Type],
 			0,
 			CASE WHEN @showDetails = 1 THEN soItems.Quantity ELSE 0 END,
 			CASE WHEN @showDetails = 1 THEN ISNULL((SELECT SUM(offerd.Quantity) FROM SOOfferedItems000 offerd WHERE offerd.SpecialOfferGUID = so.[GUID]), 0) ELSE 0 END,
 			SUM(CAST((bi.biQty / soItems.Quantity * [dbo].[fnGetMaterialUnitFact](bi.biMatPtr ,soItems.Unit)) AS INT)),
 			0,
 			0
 		FROM
 			SpecialOffers000 so
 			INNER JOIN SOItems000 soItems ON soItems.SpecialOfferGUID = so.[GUID]
			INNER JOIN vwbubi bi ON bi.biSoGUID = soItems.[GUID]
 		WHERE
 			(bi.[buDate] BETWEEN @FromDate AND @ToDate)
 			AND
 			(so.StartDate BETWEEN @FromDate AND @ToDate)
 			AND
 			so.[Type] = 0
 		GROUP BY
 			so.[Type],
 			so.[GUID],
 			soItems.Quantity
 	
 	UPDATE r
 		SET r.QuantityGiven = (SELECT SUM(bi.biQty) + SUM(bi.biBonusQnt) FROM vwbubi bi INNER JOIN SOOfferedItems000 soi ON bi.biSOGuid = soi.[GUID] WHERE soi.[SpecialOfferGuid] = r.SOGuid AND bi.[buDate] BETWEEN @FromDate AND @ToDate)
 	FROM
 		#Result r
 		
 	END
 	
 	IF (@typesBitwise & POWER(2, 1) > 0)
 	BEGIN
 		INSERT INTO #Result
 		SELECT
 			so.GUID,
 			so.[Type],
 			0,
 			CASE WHEN @showDetails = 1 THEN soItems.Quantity ELSE 0 END,
 			0,
 			SUM(CAST((bi.biQty / soItems.Quantity * [dbo].[fnGetMaterialUnitFact](bi.biMatPtr ,soItems.Unit)) AS INT)),
 			SUM(bi.biDiscount),
 			0
 		FROM
 			SpecialOffers000 so
 			INNER JOIN SOItems000 soItems ON soItems.SpecialOfferGUID = so.[GUID]
			INNER JOIN vwbubi bi ON bi.biSoGUID = soItems.[GUID]
 		WHERE
 			(bi.[buDate] BETWEEN @FromDate AND @ToDate)
 			AND
 			(so.StartDate BETWEEN @FromDate AND @ToDate)
 			AND
 			so.[Type] = 1
 		GROUP BY
 			so.[Type],
 			so.[GUID],
 			soItems.Quantity
 	END
	
	IF (@typesBitwise & POWER(2, 2) > 0)
	BEGIN
		INSERT INTO #Result
		SELECT
			so.GUID,
			2,
			0,
			CASE WHEN @showDetails = 1 THEN (SELECT SUM(soItems.Quantity) FROM SOItems000 soItems WHERE soItems.SpecialOfferGUID = so.[GUID]) ELSE 0 END,
			CASE WHEN @showDetails = 1 THEN (SELECT SUM(offerd.Quantity) FROM SOOfferedItems000 offerd WHERE offerd.SpecialOfferGUID = so.[GUID]) ELSE 0 END,
			0,
			SUM(bi.biDiscount),
			0
		FROM
			SpecialOffers000 so
			INNER JOIN SOItems000 soItems ON soItems.SpecialOfferGUID = so.[GUID]
			INNER JOIN vwbubi bi ON bi.biSoGUID = soItems.[GUID]
		WHERE
			bi.[buDate] BETWEEN @FromDate AND @ToDate
			AND
			so.[Type] = 2
		GROUP BY
			so.GUID
			
		UPDATE r
		SET
			r.SalesDiscount = r.SalesDiscount + soBi.DiscountTotal,
			r.QuantityGiven = soBi.GivenQty,
			r.ExecutionCount = 
				(	SELECT 
						SUM(bi.Qty / soItems.Quantity * [dbo].[fnGetMaterialUnitFact](bi.MatGUID ,soItems.Unit))
					FROM 
						SpecialOffers000 so
						INNER JOIN (SELECT TOP 1 GUID, SpecialOfferGUID, Quantity, Unit FROM SOItems000 WHERE SpecialOfferGUID = soBi.GUID) soItems ON soItems.SpecialOfferGUID = so.[GUID]
						INNER JOIN bi000 bi ON bi.SoGUID = soItems.[GUID]
						INNER JOIN bu000 bu ON bu.Guid = bi.ParentGuid
					WHERE
						bu.[Date] BETWEEN @FromDate AND @ToDate
						AND
						so.GUID = soBi.GUID
					GROUP BY
						so.GUID
				)
		FROM
			#Result r
			INNER JOIN 
			(
				SELECT
					so.GUID,
					SUM(bi.Discount) DiscountTotal,
					SUM(bi.Qty) + SUM(bi.BonusQnt) GivenQty
				FROM
					SpecialOffers000 so
					INNER JOIN SOOfferedItems000 sof ON sof.SpecialOfferGUID = so.GUID
					INNER JOIN bi000 bi ON bi.SOGUID = sof.GUID
					INNER JOIN bu000 bu ON bu.[GUID] = bi.ParentGUID
				WHERE
					bu.[Date] BETWEEN @FromDate AND @ToDate
					AND
					so.[Type] = 2
				GROUP BY
					so.GUID
			) soBi ON r.SoGuid = sobi.GUID
	END
	
	IF (@typesBitwise & POWER(2, 3) > 0)
	BEGIN
		INSERT INTO #Result
		SELECT
			so.GUID,
			3,
			0,
			CASE WHEN @showDetails = 1 THEN (SELECT SUM(soItems.Quantity) FROM SOItems000 soItems WHERE soItems.SpecialOfferGUID = so.[GUID]) ELSE 0 END,
			CASE WHEN @showDetails = 1 THEN (SELECT SUM(soItems.BonusQuantity) FROM SOItems000 soItems WHERE soItems.SpecialOfferGUID = so.[GUID]) ELSE 0 END,
			COUNT(DISTINCT bi.buGUID),
			SUM(bi.biDiscount),
			SUM(bi.biBonusQnt)
		FROM
			SpecialOffers000 so
			INNER JOIN SOItems000 soItems ON soItems.SpecialOfferGUID = so.[GUID]
			INNER JOIN ContractBillItems000 cob ON cob.ContractItemGUID = soItems.GUID
			INNER JOIN vwbubi bi ON bi.biGUID = cob.[BillItemGUID]
		WHERE
			bi.[buDate] BETWEEN @FromDate AND @ToDate
			AND
			so.[Type] = 3
			--(so.[Type] = 0 AND @typesBitwise & POWER(2, 0) > 0) OR (so.Type = 1 AND @typesBitwise & POWER(2, 1) > 0)
		GROUP BY
			so.GUID
	END

	IF (@typesBitwise & POWER(2, 4) > 0)
	BEGIN	
		INSERT INTO #Result
		SELECT
			so.GUID,
			4,
			0,
			0,
			0,
			COUNT(bi.[biGUID]),
			SUM(bi.biDiscount),
			0
		FROM
			SpecialOffers000 so
			INNER JOIN SOPeriodBudgetItem000 periodBudget ON periodBudget.SpecialOfferGUID = so.[GUID]
			INNER JOIN vwbubi bi ON bi.biSoGUID = periodBudget.[GUID]
		WHERE
			bi.[buDate] BETWEEN @FromDate AND @ToDate
			AND
			so.[Type] = 4
			--(so.[Type] = 0 AND @typesBitwise & POWER(2, 0) > 0) OR (so.Type = 1 AND @typesBitwise & POWER(2, 1) > 0)
		GROUP BY
			so.GUID	
	END
	
	IF @showDetails = 0
	BEGIN
		SELECT
		'' Name,
			OfferType,
			1 IsTotalRecord,
			0 Quantity,
			0 QuantityDiscount,
			SUM(ExecutionCount) ExecutionCount,
			SUM(SalesDiscount) SalesDiscount,
			SUM(QuantityGiven) QuantityGiven
 		FROM 
 			#Result 
 		GROUP BY 
 			OfferType
	END
	ELSE
	BEGIN
		INSERT INTO #Result
		SELECT
			0x0,
			r.OfferType,
			1,
			0,
			0,
			SUM(r.ExecutionCount),
			SUM(r.SalesDiscount),
			SUM(r.QuantityGiven)
 		FROM 
 			#Result r
 		GROUP BY 
 			r.OfferType
 			
 		SELECT
 			ISNULL(so.Code, '') Code,
 			ISNULL(so.Name, '') Name,
 			ISNULL(so.LatinName, '') LatinName,
 			r.*
 		FROM
 			#Result r
 			LEFT JOIN SpecialOffers000 so ON so.GUID = r.SOGuid
		WHERE	SoGuid=0x0 
 		ORDER BY
 			OfferType,
 			IsTotalRecord DESC

		SELECT
 			ISNULL(so.Code, '') Code,
 			ISNULL(so.Name, '') Name,
 			ISNULL(so.LatinName, '') LatinName,
 			r.*
 		FROM
 			#Result r
 			LEFT JOIN SpecialOffers000 so ON so.GUID = r.SOGuid
		WHERE	SoGuid<>0x0 
 		ORDER BY
 			OfferType,
 			IsTotalRecord DESC
 			
	END
#########################################################
#END

