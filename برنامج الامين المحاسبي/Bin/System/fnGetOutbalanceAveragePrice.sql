###########################################################################
CREATE FUNCTION fnGetOutbalanceAveragePrice(@MaterialGUID [UNIQUEIDENTIFIER], @BillDate AS [DATE])
	RETURNS [FLOAT]
AS
BEGIN
	RETURN 
	(
		SELECT Price
		FROM oap000
		WHERE MaterialGuid = @MaterialGUID AND @BillDate BETWEEN StartDate AND EndDate
	);
END
###########################################################################
CREATE FUNCTION fnGetOutbalanceAveragePriceByUnit(@MaterialGUID [UNIQUEIDENTIFIER], @BillDate AS [DATE], @Unit INT)
	RETURNS [FLOAT]
AS
BEGIN
	RETURN 
	(
		ISNULL((SELECT 
			oap.Price * (CASE @Unit 
							WHEN 2 THEN (CASE ISNULL([mt].[Unit2Fact], 0) WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
							WHEN 3 THEN (CASE ISNULL([mt].[Unit3Fact], 0) WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
							WHEN 4 THEN (CASE [mt].[DefUnit] 
											WHEN 2 THEN (CASE ISNULL([mt].[Unit2Fact], 0) WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
											WHEN 3 THEN (CASE ISNULL([mt].[Unit3Fact], 0) WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
											ELSE 1
										END)
							ELSE 1 END)
		FROM 
			oap000 oap 
			INNER JOIN mt000 mt ON mt.GUID = oap.MaterialGuid
		WHERE oap.MaterialGuid = @MaterialGUID AND @BillDate BETWEEN oap.StartDate AND oap.EndDate), 0)
	);
END
###########################################################################
#END 