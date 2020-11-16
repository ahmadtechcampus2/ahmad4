#############################################################################
CREATE FUNCTION JocFnGetMaterialFactorial (@MaterialGuid UNIQUEIDENTIFIER, @Unit INT)
RETURNS FLOAT
AS
BEGIN
	DECLARE @Factorial FLOAT
	SET @Factorial = 1

	SELECT @Factorial =	(
							CASE WHEN @Unit = 2 THEN Unit2Fact 
								 WHEN @Unit = 3 THEN Unit3Fact
							ELSE 1 END
						) 
						FROM mt000 mt WHERE mt.[GUID] = @MaterialGuid 
	RETURN @Factorial
END
#############################################################################

CREATE FUNCTION JOCfngetMaterialUnitFactor(@MaterialGuid UNIQUEIDENTIFIER, @UNIT FLOAT)
RETURNS FLOAT
BEGIN
	RETURN 
	(SELECT CASE WHEN @UNIT = 2 AND mt.Unit2Fact != 0 THEN mt.Unit2Fact WHEN @UNIT = 3 AND mt.Unit3Fact != 0 THEN mt.Unit3Fact ELSE 1 END FROM mt000 mt WHERE mt.[GUID] = @MaterialGuid)
END
#############################################################################
CREATE FUNCTION JocFnGetActualProductionQty (@JobOrder UNIQUEIDENTIFIER, @Unit INT)
RETURNS TABLE
AS
RETURN(
		SELECT  ISNULL(SUM(bi.Qty), 0) / dbo.JOCfngetMaterialUnitFactor(bi.MatGUID, @Unit) As Qty
		FROM bi000 bi 
		INNER JOIN bu000 bu on bi.ParentGUID = bu.[GUID]
		INNER JOIN JobOrder000 JobOrder ON bu.CustAccGUID = JobOrder.Account
		INNER JOIN Manufactory000 factory ON factory.[Guid] = JobOrder.ManufactoryGUID
		WHERE JobOrder.[Guid] = @JobOrder
		AND bu.TypeGUID = factory.FinishedGoodsBillType
		GROUP BY bi.MatGUID
	)
#############################################################################
CREATE FUNCTION fnGetMaxJOCostProcessLevel()
RETURNS int
as 
Begin
Declare @MaxRank int
SELECT @MaxRank = ISNULL(MAX(bom.CostRank),0)  from JOCJobOrderOperatingBOM000 bom

return @MaxRank
End
#############################################################################
CREATE FUNCTION JOCfnGetBOMActualCostRank(@BomGuid uniqueidentifier)
RETURNS TABLE
AS
RETURN  SELECT ISNULL( MAX(CostRank),0) CostRank from JOCJobOrderOperatingBOM000 where BOMGuid = @BomGuid 


#############################################################################
CREATE FUNCTION JOCfnGetBOMAbnormalAccounts()
RETURNS TABLE
RETURN(

	with cte(accGuid)
	as
	(
		select mohAccounts.GUID from Manufactory000 m 
		cross apply fnGetAccountsList(MOHAcc, 0) mohAccounts
		union all
		select indirectAccounts.GUID from Manufactory000 m 
		cross apply fnGetAccountsList(MOHIndirectAcc, 0) indirectAccounts
		union all 
		select inprocess.GUID from Manufactory000 m 
		cross apply fnGetAccountsList(InProcessAcc, 0) inprocess
	)select * from vwExtended_AC where GUID NOT IN (select accguid from cte)	
)

#############################################################################
CREATE FUNCTION JOCfnGetBOMRawMaterialsWithCosts(@BOMGUID UNIQUEIDENTIFIER)
RETURNS TABLE
RETURN 
(
	SELECT * FROM JOCOperatingBOMRawMaterials000 materials
	WHERE materials.OperatingBOMGuid = @BOMGUID
)
#############################################################################
CREATE FUNCTION fnJOCCheckDatePeriodValid ( @FPDate DATETIME,  @EPDate DATETIME	)
RETURNS INT
BEGIN

	SET @FPDate = ( DATEADD(DAY, -DATEPART(DAY, @FPDate) + 1, @FPDate))
	SET @EPDate = ( DATEADD(DAY, -DATEPART(DAY, @EPDate) + 1, @EPDate))
	
	IF (EXISTS (SELECT [ProductionLine] FROM plcosts000 WHERE StartPeriodDate NOT between @FPDate AND @EPDate))
	BEGIN
	     RETURN 0 ;
	END
	RETURN 1 ;
END
#############################################################################