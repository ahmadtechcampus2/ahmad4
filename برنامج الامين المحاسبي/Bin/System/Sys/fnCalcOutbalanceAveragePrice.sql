###############################################
CREATE FUNCTION fnCalcOutbalanceAveragePrice(
      @StartDate DATE,
      @EndDate DATE,
      @MaterialGuid UNIQUEIDENTIFIER,
      @GroupGuid UNIQUEIDENTIFIER)
RETURNS @Result TABLE(MaterialGuid UNIQUEIDENTIFIER, Price FLOAT)
BEGIN

    DECLARE 
		@FPDate DATE,
		@CostBillType UNIQUEIDENTIFIER;

	SET @CostBillType = ISNULL((SELECT Guid FROM bt000 WHERE Type = 3 AND SortNum = 0 AND BillType = 4 AND Name = '≈œŒ«·  ﬂ·›…'), 0x0)
      
    SET @FPDate = [dbo].[fnDate_Amn2Sql]([dbo].[fnOption_get]('AmnCfg_FPDate', default));
                  
    WITH INV
    AS
    (
        SELECT
                biMatPtr,
                ISNULL(SUM((biQty + biBonusQnt) * btIsInput - (biQty + biBonusQnt) * btIsOutput), 0) AS Quantity,
                [dbo].fnGetOutbalanceAveragePrice(biMatPtr, DATEADD(DAY, -1, @StartDate)) AS Price
        FROM
                vwExtended_bi Bi
                JOIN fnGetMaterialsList(@GroupGuid) M ON Bi.biMatPtr = M.[GUID]
        WHERE
                @StartDate <> @FPDate AND buDate BETWEEN @FPDate AND DATEADD(DAY, -1, @StartDate)
                AND
                (@MaterialGuid = 0x0 OR @MaterialGuid = M.[GUID])
				AND
				Bi.buIsPosted= 1
        GROUP BY
                biMatPtr
    ),
	OAP AS
	(
		SELECT
			MT.[GUID],
			(
				ISNULL
				(
					SUM
					(
						(
							BI.biUnitPrice * (BI.biQty + BI.biBonusQnt) 
							- CASE WHEN BI.btDiscAffectCost = 1 THEN BI.biDiscount ELSE 0 END 
							+ CASE WHEN BI.btExtraAffectCost = 1 THEN BI.biExtra ELSE 0 END
						) 
						* (BI.btIsInput - BI.btIsOutput)
					), 0
				)
				+ ISNULL((I.Quantity * i.Price), 0)
			)
			/ 
			CASE 
				WHEN (ISNULL(SUM((BI.biQty + BI.biBonusQnt) * (BI.btIsInput - BI.btIsOutput)), 0) + ISNULL(I.Quantity, 0)) = 0 THEN 1 
				ELSE (ISNULL(SUM((BI.biQty + BI.biBonusQnt) * (BI.btIsInput - BI.btIsOutput)), 0) + ISNULL(I.Quantity, 0)) 
			END AS NewOAP
		FROM
			fnGetMaterialsList(@GroupGuid) MT
			JOIN mt000 M ON MT.[GUID] = M.[GUID]
			LEFT JOIN vwExtended_bi BI ON BI.biMatPtr = MT.[GUID] AND BI.btAffectCostPrice = 1 
				AND BI.buDate BETWEEN @StartDate AND @EndDate
				AND 
				(
					(
						EXISTS(SELECT * FROM vwExtended_bi WHERE btAffectCostPrice = 1 
							AND buDate BETWEEN @StartDate AND @EndDate AND buType <> @CostBillType)
						AND
						Bi.buType <> @CostBillType
					)
					OR
					(
						NOT EXISTS(SELECT * FROM vwExtended_bi WHERE btAffectCostPrice = 1 
							AND buDate BETWEEN @StartDate AND @EndDate AND buType <> @CostBillType)
						/*AND
						Bi.buType = @CostBillType*/
					)
				)
				
			LEFT JOIN INV I ON I.biMatPtr = M.[GUID]
			/*LEFT JOIN vwExtended_bi costBi ON costBi.biMatPtr = MT.[GUID] AND BI.btAffectCostPrice = 1 
						AND BI.buDate BETWEEN @StartDate AND @EndDate AND Bi.buType = @CostBillType 
						AND NOT EXISTS(SELECT * FROM vwExtended_bi BI WHERE btAffectCostPrice = 1 
						AND buDate BETWEEN @StartDate AND @EndDate AND buType <> @CostBillType)*/
		WHERE
			ISNULL(Bi.buIsPosted, 1) = 1
			
		GROUP BY 
			MT.[GUID],
			I.Quantity,
			I.Price
	)
    INSERT INTO @Result
    SELECT
	O.Guid,
	ISNULL(CASE ISNULL(O.NewOAP, 0) WHEN 0 THEN ISNULL(I.Price, [dbo].fnGetOutbalanceAveragePrice(O.Guid, DATEADD(DAY, -1, @StartDate))) ELSE O.NewOAP END, 0)
    FROM 
	OAP O
	LEFT JOIN INV I ON I.biMatPtr = O.[GUID]
	           
    RETURN
END
############################################### 
#END