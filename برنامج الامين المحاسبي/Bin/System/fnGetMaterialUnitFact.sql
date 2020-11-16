#########################################################
CREATE FUNCTION fnGetMaterialUnitFact(
	@MaterialGUID UNIQUEIDENTIFIER,
	@UnitNumber INT) -- 1 for unit 1, 2 for unit 2, 3 for unit 3, 4 for default unit
	
RETURNS FLOAT
AS
BEGIN
	RETURN
		CASE @UnitNumber
			WHEN 1 THEN 1
			WHEN 2 THEN (SELECT mtUnit2Fact FROM vwmt WHERE mtGUID = @MaterialGUID)
			WHEN 3 THEN (SELECT mtUnit3Fact FROM vwmt WHERE mtGUID = @MaterialGUID)
			WHEN 4 THEN (SELECT mtDefUnitFact FROM vwmt WHERE mtGUID = @MaterialGUID)
			ELSE 1
		END
END
#########################################################
CREATE FUNCTION fnGetUnitName(@MatGuid UNIQUEIDENTIFIER, @UnitId INT)
	RETURNS NVARCHAR(250)
AS BEGIN
	RETURN 
		(SELECT TOP 1 
			CASE @UnitId
				WHEN 1 THEN mtUnity
				WHEN 2 THEN mtUnit2
				WHEN 3 THEN mtUnit3
				ELSE mtDefUnitName
			END
		FROM 
			vwMt 
		WHERE 
			mtGuid = @MatGuid);
END
#########################################################
#END 