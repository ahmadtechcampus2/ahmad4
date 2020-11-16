####################################################################################
CREATE FUNCTION NSFnMatMonitoringInfo(@ObjectGuid UNIQUEIDENTIFIER , @messageGuid UNIQUEIDENTIFIER)
RETURNS @MaterialInfo TABLE 
(
		MatName			NVARCHAR(255),
		MatCode			NVARCHAR(255),
		MatLName		NVARCHAR(255),
		HighQty			FLOAT,
		LowQty			FLOAT,
		OrderLimit		FLOAT,
		LastPrice		FLOAT,
		MatCurrency		NVARCHAR(255),
		Unit1Name		NVARCHAR(255),
		QtyUnit1		FLOAT,
		Unit2Name		NVARCHAR(255),
		QtyUnit2		FLOAT,
		Unit3Name		NVARCHAR(255),
		QtyUnit3		FLOAT,
		UnitDefName		NVARCHAR(255),
		QtyUnitDef		FLOAT	
)
AS 
	BEGIN
		INSERT INTO @MaterialInfo
		SELECT 
			MT.Name, 
			MT.Code, 
			MT.LatinName,
			MT.High,
			MT.Low,
			MT.OrderLimit,
			MT.LastPrice,
			MY.Name,
			MT.Unity,
			MT.Qty,
			MT.Unit2,
			MT.Qty/(CASE WHEN MT.Unit2Fact  = 0 THEN 1 
						 WHEN MT.Unit2Fact != 0 THEN MT.Unit2Fact END) AS QtyUnit2,
			MT.Unit3,
			MT.Qty/(CASE WHEN MT.Unit3Fact  = 0 THEN 1 
						 WHEN MT.Unit3Fact != 0 THEN MT.Unit3Fact END) AS QtyUnit3,
			(CASE MT.DefUnit WHEN 1 THEN MT.Unity
							 WHEN 2 THEN MT.Unit2
							 WHEN 3 THEN MT.Unit3 END),
			(CASE MT.DefUnit WHEN 1 THEN MT.Qty
							 WHEN 2 THEN MT.Qty/(CASE WHEN MT.Unit2Fact  = 0  THEN 1
													  WHEN MT.Unit2Fact != 0  THEN MT.Unit2Fact END)
							 WHEN 3 THEN MT.Qty/(CASE WHEN MT.Unit3Fact  = 0  THEN 1
													  WHEN MT.Unit3Fact != 0  THEN MT.Unit3Fact END) END)
		FROM mt000 MT INNER JOIN my000 MY ON MT.CurrencyGUID = MY.[GUID]
		WHERE MT.[GUID] = @ObjectGuid
		RETURN
	END
################################################################################
CREATE FUNCTION NSFnMatExpireDateInfo(@ObjectGuid UNIQUEIDENTIFIER , @messageGuid UNIQUEIDENTIFIER)
RETURNS @MaterialInfo TABLE 
(
	[ExpireDate] [DATE],        
	[Remaining] [FLOAT]
)
AS 
	BEGIN
		DECLARE @eventConditonGuid UNIQUEIDENTIFIER = (SELECT EventConditionGuid FROM NSMessage000 WHERE Guid = @messageGuid)
		DECLARE @beforeDays INT =  (SELECT DC.BeforeDays from NSScheduleEventCondition000 DC where DC.EventConditionGuid = @eventConditonGuid)

		INSERT INTO @MaterialInfo
		SELECT 
			[ExpireDate], 
			SUM([Remaining])
			
		FROM fnGetMatsExpireDateInfo (@beforeDays , NULL)
		WHERE [MatPtr] = @ObjectGuid
		GROUP BY [ExpireDate]
		RETURN
	END
################################################################################
#END
