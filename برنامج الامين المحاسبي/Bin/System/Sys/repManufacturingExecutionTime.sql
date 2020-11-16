###############################################################################
CREATE PROCEDURE repManufacturingExecutionTime
	@FormGuid		[UNIQUEIDENTIFIER] = 0x0,
	@FromDate   	[DATETIME] = '2009-1-1',
	@ToDate     	[DATETIME] = '2009-10-31',
	@IsDetailed       [BIT] = 1
AS

	SET NOCOUNT ON 
	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	IF(@IsDetailed = 1)
	BEGIN
		SELECT MN.GUID MNGuid, MN.Number MNNumber, MN.Date, FM.Code + ' - ' + CASE WHEN @Lang > 0 THEN CASE WHEN FM.LatinName = ''  THEN FM.Name ELSE FM.LatinName END ELSE FM.Name END Name, MN.Qty, (FM.StandardTime) StandardSingleTime, FM.StandardTime * MN.Qty StandardTotalTime, MN.ProductionTime ActualTime, (MN.ProductionTime - (FM.StandardTime * MN.Qty)) TotalDiff, MN.ProductionTime / NULLIF(MN.Qty, 0) SingleActualAvg, (MN.ProductionTime - (FM.StandardTime * MN.Qty)) / NULLIF(MN.Qty, 0) SingleAvg
			FROM MN000 MN -- actual
			INNER JOIN MN000 MN1 ON MN.FormGuid = MN1.FormGuid -- standard
			INNER JOIN FM000 FM ON MN.FormGuid = FM.Guid
			WHERE ( @FormGuid = 0x0 OR FM.Guid = @FormGuid)
				  AND MN.Type = 1
				  AND MN1.Type = 0
				  AND MN.Date >= @FromDate
				  AND MN.Date <= @ToDate
			ORDER BY Date, Code
	END
	ELSE
	BEGIN
			SELECT  '' Date, FM.Code + ' - ' + CASE WHEN @Lang > 0 THEN CASE WHEN FM.LatinName = ''  THEN FM.Name ELSE FM.LatinName END ELSE FM.Name END Name, SUM(MN.Qty) Qty, (FM.StandardTime) StandardSingleTime, SUM(MN.Qty) * Avg(MN.Qty) * (FM.StandardTime / Avg(MN.Qty)) StandardTotalTime, SUM(MN.ProductionTime) ActualTime, (SUM(MN.ProductionTime) - SUM(MN.Qty) * Avg(MN.Qty) * (FM.StandardTime / Avg(MN.Qty))) TotalDiff, SUM(MN.ProductionTime) / SUM(MN.Qty) SingleActualAvg, (SUM(MN.ProductionTime) - SUM(MN.Qty) * Avg(MN.Qty) * (FM.StandardTime / Avg(MN.Qty))) / SUM(MN.Qty) SingleAvg
			FROM MN000 MN -- actual
			INNER JOIN MN000 MN1 ON MN.FormGuid = MN1.FormGuid -- standard
			INNER JOIN FM000 FM ON MN.FormGuid = FM.Guid
			WHERE ( @FormGuid = 0x0 OR FM.Guid = @FormGuid)
				  AND MN.Type = 1
				  AND MN1.Type = 0
				  AND MN.Date >= @FromDate
				  AND MN.Date <= @ToDate
			GROUP BY CASE WHEN @Lang > 0 THEN CASE WHEN FM.LatinName = ''  THEN FM.Name ELSE FM.LatinName END ELSE FM.Name END , FM.StandardTime, FM.Code
			ORDER BY Name
	END
################################################################################
#END