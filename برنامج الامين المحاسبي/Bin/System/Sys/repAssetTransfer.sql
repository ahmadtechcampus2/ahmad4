############################################################################################
CREATE PROC repAssetTransfer 
	@NewDBName NVARCHAR(1000)
AS
SET NOCOUNT ON;

	IF SUBSTRING(@NewDBName, 1, 1) != '['
		SET @NewDBName = '[' + @NewDBName + ']'

	DECLARE @SQL AS NVARCHAR(max)
	SET @SQL =
	'UPDATE ADetail
	SET
		ADetail.AddedVal = Axxx.AddedVal,
		ADetail.DeductVal = Axxx.DeductVal,
		ADetail.MaintenVal = Axxx.MaintenVal,
		ADetail.DeprecationVal = Axxx.DeprecationVal,
		ADetail.DailyRental = Axxx.DailyRental,
		ADetail.ScrapValue	= Axxx.ScrapValue,
		ADetail.InVal		= Axxx.InVal
	FROM 
		' + @NewDBName + '..ad000 as ADetail INNER JOIN 
		(SELECT 
			ad.GUID AS AdGUID,
			ISNULL( AxAdded.AddedVal, 0)+ ad.AddedVal AS AddedVal,
			ISNULL( AxDeduct.DeductVal, 0)+ ad.DeductVal AS DeductVal,
			ISNULL( AxMainten.MaintenVal, 0)+ ad.MaintenVal  AS MaintenVal,
			ISNULL( DD.DeprecationVal, 0)+ ad.DeprecationVal AS DeprecationVal,
			ISNULL( ad.DailyRental, 0) AS DailyRental,
			ISNULL( ad.ScrapValue, 0) AS ScrapValue ,
			ISNULL( ad.InVal, 0) AS InVal
		FROM 
			Ad000 AS ad 
			LEFT JOIN ( SELECT SUM( CASE WHEN Type = 0 THEN Value ELSE 0 END) AS AddedVal, ADGUID FROM Ax000 GROUP BY ADGUID) AS AxAdded ON ad.GUID = AxAdded.ADGUID
			LEFT JOIN ( SELECT SUM( CASE WHEN Type = 1 THEN Value ELSE 0 END) AS DeductVal, ADGUID FROM Ax000 GROUP BY ADGUID) AS AxDeduct ON ad.GUID = AxDeduct.ADGUID
			LEFT JOIN ( SELECT SUM( CASE WHEN Type = 2 THEN Value ELSE 0 END) AS MaintenVal, ADGUID FROM Ax000 GROUP BY ADGUID) AS AxMainten ON ad.GUID = AxMainten.ADGUID
			LEFT JOIN ( SELECT SUM( Value) AS DeprecationVal, ADGUID FROM dd000 GROUP BY ADGUID)AS DD ON ad.GUID = DD.ADGUID
		) AS Axxx ON Axxx.AdGUID = ADetail.Guid'
	EXEC ( @SQL)
#########################################################################################
CREATE PROC prcAssetPossessionsTransfer
	@NewDBName NVARCHAR(1000) = ''

AS
IF(@NewDBName <> '')
	IF SUBSTRING(@NewDBName, 1, 1) != '['
		SET @NewDBName = '[' + @NewDBName + ']'

DECLARE @SQL NVARCHAR(MAX) = ' ';

SET @SQL += ';WITH Reciept AS(
	SELECT fi.AssetGuid, MAX(f.Number) AS Number FROM AssetPossessionsForm000 AS f
		INNER JOIN AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
		WHERE f.OperationType = 1
		GROUP BY fi.AssetGuid
		)
SELECT f.GUID, fi.AssetGuid ,MAX(f.Date) AS Date ,MAX(f.Number) AS Num INTO #tbl
	FROM AssetPossessionsForm000 AS f
	INNER JOIN AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
	WHERE f.OperationType = 2
	GROUP BY fi.AssetGuid, f.GUID
	HAVING MAX(f.Number) > ISNULL((SELECT Number from Reciept WHERE AssetGuid = fi.AssetGuid), 0) ';

SET @SQL += 'DELETE FROM ' + @NewDBName + '..AssetStartDatePossessions000 WHERE IsTransfered = 1 ';
SET @SQL += 'DELETE FROM ' + @NewDBName + '..AssetPossessionsForm000 WHERE Guid IN (SELECT GUID FROM AssetPossessionsForm000) AND Guid NOT IN (SELECT GUID FROM #tbl) ';
SET @SQL += 'DELETE ai FROM ' + @NewDBName + '..AssetPossessionsFormItem000 AS ai
	WHERE NOT EXISTS (SELECT * FROM #tbl WHERE ai.ParentGuid = #tbl.GUID
	 AND ai.AssetGuid = #tbl.AssetGuid ) AND EXISTS (SELECT * FROM AssetPossessionsFormItem000 AS si
		WHERE ai.AssetGuid = si.AssetGuid AND ai.ParentGuid = si.ParentGuid) ';

DECLARE @BrunchId UNIQUEIDENTIFIER;
DECLARE @ParentId UNIQUEIDENTIFIER;
DECLARE @INumber INT = 1;

IF EXISTS (SELECT * FROM vwbr)
BEGIN
	DECLARE AssetStartDatePossessions_cursor CURSOR FOR   
	SELECT brGUID FROM vwbr

	OPEN AssetStartDatePossessions_cursor  
  
	FETCH NEXT FROM AssetStartDatePossessions_cursor   
	INTO @BrunchId
  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		SET @ParentId = NEWID()
		
		SET @SQL += 'INSERT INTO ' + @NewDBName + '..AssetStartDatePossessions000 VALUES(' + CAST(@INumber AS NVARCHAR(250)) + ', ''' + CAST(@ParentId AS NVARCHAR(250)) + ''', 1, 1) ';

		SET @INumber = @INumber + 1;

		SET @SQL += 'UPDATE ' + @NewDBName + '..AssetPossessionsForm000
			SET ParentGuid = ''' + CAST(@ParentId AS NVARCHAR(250)) + '''
		WHERE Branch = ''' + CAST(@BrunchId AS NVARCHAR(250)) + ''' 
		AND Guid IN (SELECT GUID FROM #tbl) ';

		FETCH NEXT FROM AssetStartDatePossessions_cursor   
		INTO @BrunchId

	END

	CLOSE AssetStartDatePossessions_cursor;  
	DEALLOCATE AssetStartDatePossessions_cursor;
END
ELSE
BEGIN
	SET @ParentId = NEWID()

	SET @SQL += 'INSERT INTO ' + @NewDBName + '..AssetStartDatePossessions000 VALUES(' + CAST(@INumber AS NVARCHAR(250)) + ', ''' + CAST(@ParentId AS NVARCHAR(250)) + ''', 1, 1) ';

	SET @SQL += 'UPDATE ' + @NewDBName + '..AssetPossessionsForm000
		SET ParentGuid = ''' + CAST(@ParentId AS NVARCHAR(250)) + ''' 
		WHERE Guid IN (SELECT GUID FROM #tbl) ';
END

EXEC(@SQL);

BEGIN TRY
	DROP TABLE #tbl
END TRY
BEGIN CATCH
END CATCH
#########################################################################################
CREATE PROC prcAssetPossessionsReNumTransferedCard
	@NewDBName NVARCHAR(1000)
AS
	IF SUBSTRING(@NewDBName, 1, 1) != '['
		SET @NewDBName = '[' + @NewDBName + ']'

	DECLARE @mxNum INT = (SELECT MAX(Number) FROM AssetPossessionsForm000)
		
	IF(@mxNum IS NOT NULL)
	BEGIN
		EXEC('IF(SELECT MIN(Number) FROM ' + @NewDBName + '..AssetPossessionsForm000
				WHERE ParentGuid NOT IN (SELECT GUID FROM ' + @NewDBName + '..AssetStartDatePossessions000 WHERE IsTransfered = 1)) < ' + @mxNum + '
						UPDATE ' + @NewDBName + '..AssetPossessionsForm000
							SET Number = Number + ' + @mxNum + '');
	END
#########################################################################################
CREATE PROC GetDeplecatedAsset
	@NewDBName NVARCHAR(1000)
AS
	SET NOCOUNT ON
	
	SET @NewDBName = '[' + @NewDBName + ']..';
DECLARE @SQL NVARCHAR(MAX) = ' ';
	
	SET @SQL += 'SELECT f.GUID, f.Employee, f.Date, f.OperationType, fi.AssetGuid, f.Number2  INTO #DeleverTbl 
			FROM '+ @NewDBName +'AssetPossessionsForm000 AS f
			INNER JOIN '+ @NewDBName +'AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
				WHERE f.OperationType = 2 AND f.GUID NOT IN (SELECT f.GUID FROM AssetPossessionsForm000) ';
	
	SET @SQL += 'INSERT INTO #DeleverTbl
	SELECT f.GUID, f.Employee, f.Date, f.OperationType, fi.AssetGuid, f.Number2
		FROM AssetPossessionsForm000 AS f
		INNER JOIN AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
			WHERE f.OperationType = 2 ';
	
	SET @SQL += 'SELECT f.GUID, f.Employee, f.Date, f.OperationType, fi.AssetGuid, f.Number2 INTO #ReciveTbl 
		FROM '+ @NewDBName +'AssetPossessionsForm000 AS f
		INNER JOIN '+ @NewDBName +'AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
			WHERE f.OperationType = 1 ';
	
	SET @SQL += 'INSERT INTO #ReciveTbl
	SELECT f.GUID, f.Employee, f.Date, f.OperationType, fi.AssetGuid, f.Number2 
		FROM AssetPossessionsForm000 AS f
		INNER JOIN AssetPossessionsFormItem000 AS fi ON f.GUID = fi.ParentGuid
			WHERE f.OperationType = 1 AND f.GUID NOT IN (SELECT f.GUID FROM AssetPossessionsForm000) ';
	
	SET @SQL += 'DECLARE @ReciveCount INT = (SELECT COUNT(*) FROM #ReciveTbl) ';
	
	SET @SQL += 'DECLARE @NewCount INT = (SELECT COUNT(*) FROM #DeleverTbl AS dt
			INNER JOIN #ReciveTbl AS rt 
			ON dt.AssetGuid = rt.AssetGuid AND dt.Date <= rt.Date AND dt.Employee = rt.Employee) '
	
	SET @SQL += 'IF @NewCount <> @ReciveCount
			SELECT r.*, mt.Name AS mt, e.Name, ad.SN FROM #ReciveTbl as r
				INNER JOIN ad000 AS ad ON r.AssetGuid = ad.GUID
				INNER JOIN as000 AS a ON a.GUID = ad.ParentGUID
				INNER JOIN mt000 AS mt ON mt.GUID = a.ParentGUID
				LEFT JOIN AssetEmployee000 AS e ON e.Guid = r.Employee
				WHERE r.GUID NOT IN (SELECT rt.GUID FROM #DeleverTbl AS dt
				INNER JOIN #ReciveTbl AS rt 
				ON dt.AssetGuid = rt.AssetGuid AND dt.Date <= rt.Date AND dt.Employee = rt.Employee) ';

	SET @SQL += ';WITH R AS (
				SELECT COUNT(*) AS Cnt,AssetGuid FROM #ReciveTbl
				GROUP BY AssetGuid
				),
				D AS (
				SELECT COUNT(*) AS Cnt,AssetGuid FROM #DeleverTbl
				GROUP BY AssetGuid
				),
				T AS (
				SELECT d.*, mt.Name AS mt, e.Name, ad.SN FROM #DeleverTbl AS d 
						INNER JOIN ad000 AS ad ON d.AssetGuid = ad.GUID
						INNER JOIN as000 AS a ON a.GUID = ad.ParentGUID
						INNER JOIN mt000 AS mt ON mt.GUID = a.ParentGUID
						LEFT JOIN AssetEmployee000 AS e ON e.Guid = d.Employee
				)
				SELECT * FROM T
				WHERE T.AssetGuid IN (SELECT  R.AssetGuid
				FROM R JOIN D ON R.AssetGuid = D.AssetGuid
					WHERE D.Cnt - R.Cnt > 0)
						ORDER BY Number2
					';
EXEC(@SQL);
#########################################################################################
#END