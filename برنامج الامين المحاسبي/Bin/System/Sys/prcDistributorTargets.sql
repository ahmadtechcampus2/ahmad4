################################################################################
CREATE PROCEDURE GetDistrbutionGroupTarget
	@ParentGroupGUID UNIQUEIDENTIFIER,
	@PeriodGUID UNIQUEIDENTIFIER,
	@level INT
AS
	SET NOCOUNT ON

	IF @level = 1
	BEGIN
		SELECT [t].*,t.Qty AS Qnty, t.Unit AS Unt, [mt].[mtCode], [mt].[mtUnity], [mt].[mtUnit2], [mt].[mtUnit3], mt.mtDefUnitName AS mtDefUnit, mt.mtUnit2Fact, mt.mtUnit3Fact,mt.mtDefUnitFact
		FROM vwDisGeneralTarget AS t 
		INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [t].[MatGuid]
		WHERE t.PeriodGuid = @PeriodGUID AND t.Qty > 0
		ORDER BY t.MatName , Qnty
	END
	ELSE
	BEGIN
		SELECT [t].*, dq.Qty AS Qnty, d.Unit AS Unt, [mt].[mtCode], [mt].[mtUnity], [mt].[mtUnit2], [mt].[mtUnit3], mt.mtDefUnitName AS mtDefUnit, mt.mtUnit2Fact, mt.mtUnit3Fact,mt.mtDefUnitFact
		FROM vwDisGeneralTarget AS t 
		INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [t].[MatGuid]
		INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd ON t.GUID = dd.MatGeneralTargetGUID
		INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq ON dd.Guid = dq.ParentGUID
		INNER JOIN DistTargetByGroupOrDistributor000 AS d ON d.Guid = dd.ParentGUID
		WHERE t.PeriodGuid = @PeriodGUID AND
		((dq.DistGroupGUID = @ParentGroupGUID AND dq.DistGroupGUID <> 0x) OR (dq.DistGUID = @ParentGroupGUID AND dq.DistGUID <> 0x))
		AND dq.Qty > 0
		ORDER BY t.MatName , Qnty
	END
########################################
CREATE PROCEDURE prcSaveDistTargetQty
	@ParentGUID UNIQUEIDENTIFIER,
	@DisGUID UNIQUEIDENTIFIER,
	@Qty FLOAT = 0,
	@Flag INT
AS
	SET NOCOUNT ON

	DECLARE
		@DisGroupGUID UNIQUEIDENTIFIER = 0x00,
		@DistributorGUID UNIQUEIDENTIFIER =0x00
	IF @Flag = 0
	BEGIN
		SET @DisGroupGUID = @DisGUID
	END
	ELSE
	BEGIN
		SET @DistributorGUID = @DisGUID
	END

	INSERT INTO DistTargetByGroupOrDistributorQty000
           ([GUID]
           ,[ParentGUID]
           ,[DistGroupGUID]
           ,[DistGUID]
           ,[Qty])
     VALUES
           (NEWID()
           ,@ParentGUID
           ,@DisGroupGUID
           ,@DistributorGUID
           ,@Qty)
########################################
CREATE PROCEDURE prcDeleteDistTarget
	@ParentGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DELETE FROM DistTargetByGroupOrDistributorQty000 WHERE ParentGUID IN (SELECT [GUID] FROM DistTargetByGroupOrDistributorDetails000 WHERE ParentGUID =@ParentGUID)
	DELETE FROM DistTargetByGroupOrDistributorDetails000 WHERE ParentGUID =@ParentGUID
	DELETE FROM DistTargetByGroupOrDistributor000 WHERE [GUID] =@ParentGUID
########################################
CREATE PROCEDURE prcGetSavedDistTargetQty
	@CurrGUID UNIQUEIDENTIFIER,
	@PeriodGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE @level INT,@ParentGroupGUID UNIQUEIDENTIFIER
	SET @level =(SELECT (CASE d.ParentDisGroupGUID WHEN 0x THEN 1 ELSE 0 END) FROM DistTargetByGroupOrDistributor000 d WHERE Guid = @CurrGUID)
	SET @ParentGroupGUID = (select ParentDisGroupGUID from DistTargetByGroupOrDistributor000 where Guid = @CurrGUID)
	;WITH vwtarget AS (
	SELECT D.GUID AS GU,d.Unit AS Unt,dd.* FROM DistTargetByGroupOrDistributorDetails000 AS dd 
	INNER JOIN DistTargetByGroupOrDistributor000 AS d ON d.Guid = dd.ParentGUID 
	WHERE d.Guid = @CurrGUID
	)
	SELECT vw.GU, [t].*, (CASE @level WHEN 1 THEN t.Qty WHEN 0 THEN (

	SELECT Qty FROM DistTargetByGroupOrDistributorQty000 AS sq WHERE sq.DistGroupGUID = @ParentGroupGUID AND sq.ParentGUID IN 
	(select Guid from DistTargetByGroupOrDistributorDetails000 AS sd where sd.MatGeneralTargetGUID = t.GUID and sd.ParentGUID IN 
	(select Guid from DistTargetByGroupOrDistributor000 AS s WHERE s.PeriodGuid = @PeriodGUID))
	
	) END) AS Qnty, vw.Guid AS ParentGUID, vw.Unt AS Unt, [mt].[mtCode], [mt].[mtUnity], [mt].[mtUnit2], [mt].[mtUnit3], mt.mtDefUnitName AS mtDefUnit, mt.mtUnit2Fact, mt.mtUnit3Fact,mt.mtDefUnitFact
	FROM vwDisGeneralTarget AS t 
	INNER JOIN [vwmt] AS [mt] ON [mt].[mtGuid] = [t].[MatGuid]
	LEFT JOIN vwtarget AS vw ON vw.MatGeneralTargetGUID = t.GUID
	WHERE
	t.PeriodGUID = @PeriodGUID
	AND ((t.Qty > 0 AND @level = 1) OR ((
	
	SELECT Qty FROM DistTargetByGroupOrDistributorQty000 AS sq WHERE sq.DistGroupGUID = @ParentGroupGUID AND sq.ParentGUID IN 
	(select Guid from DistTargetByGroupOrDistributorDetails000 AS sd where sd.MatGeneralTargetGUID = t.GUID and sd.ParentGUID IN 
	(select Guid from DistTargetByGroupOrDistributor000 AS s WHERE s.PeriodGuid = @PeriodGUID)
	)
	) > 0 AND @level = 0))
	ORDER BY t.MatName , Qnty
########################################
CREATE PROCEDURE prcUpdateDistributionTreeQty
@GroupGUID UNIQUEIDENTIFIER,
@ParentGUID UNIQUEIDENTIFIER,
@PeriodGUID UNIQUEIDENTIFIER,
@Flag INT = 0

AS
	SET NOCOUNT ON

DECLARE 
@MatGUID UNIQUEIDENTIFIER, @QtyGUID UNIQUEIDENTIFIER, @ParentGroupGUID UNIQUEIDENTIFIER, @MatGroupGUID UNIQUEIDENTIFIER, @level INT, @m_level INT = 0

IF @Flag = 0
	BEGIN
		SET @MatGUID = (SELECT MatGeneralTargetGUID FROM DistTargetByGroupOrDistributorDetails000 WHERE Guid = @ParentGUID)
	END
ELSE
	BEGIN
		SET @MatGUID = @ParentGUID
	END

;WITH tree (GUID, name, level) AS  
(
  SELECT GUID, name, 1 as level         
  FROM DistHi000
  WHERE GUID = @GroupGUID
  UNION ALL
  SELECT child.GUID, child.name, parent.level + 1         
  FROM DistHi000 as child
    JOIN tree as parent on parent.GUID = child.parentGUID
  UNION ALL
  SELECT child.GUID, child.name, parent.level + 1
  FROM Distributor000 as child
    JOIN tree as parent on parent.GUID = child.HierarchyGUID  
)
SELECT * INTO #Result FROM tree ORDER BY level
CREATE TABLE #EndResult (
		[GUID] UNIQUEIDENTIFIER,
		[Qty] FLOAT)
DECLARE targetCursor CURSOR FOR 
	SELECT dq.GUID, d.ParentDisGroupGUID, dd.Guid, r.level FROM DistTargetByGroupOrDistributor000 AS d INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd ON d.Guid = dd.ParentGUID 
	INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq ON dd.Guid = dq.ParentGUID INNER JOIN 
	#Result AS r ON ((r.GUID = dq.DistGroupGUID AND dq.DistGroupGUID <> 0x )OR (r.GUID = dq.DistGUID AND dq.DistGUID <> 0x))
	WHERE dd.MatGeneralTargetGUID = @MatGUID AND level != (SELECT MIN(level) FROM #Result)
	AND d.PeriodGuid = @PeriodGUID AND dq.Qty != 0
	ORDER BY level
OPEN targetCursor
FETCH NEXT FROM targetCursor 
	INTO @QtyGUID, @ParentGroupGUID, @MatGroupGUID, @level
		WHILE @@FETCH_STATUS = 0
			BEGIN
			
			IF (@level != @m_level AND @m_level != 0)
			BEGIN 
			UPDATE Q
			   SET Qty = E.Qty
				FROM DistTargetByGroupOrDistributorQty000 AS Q
					 INNER JOIN #EndResult AS E
							ON Q.GUID = E.GUID
			SET @m_level = @level
			DELETE FROM #EndResult
			END
			ELSE
			BEGIN
			IF @m_level = 0
				SET @m_level = @level
			END

			;WITH C AS
			(
				SELECT
					(SELECT SUM(sq.Qty) FROM DistTargetByGroupOrDistributorQty000 sq WHERE sq.ParentGUID = @MatGroupGUID) AS OldTotal,
					(SELECT sq.Qty FROM DistTargetByGroupOrDistributorQty000 sq WHERE sq.GUID = @QtyGUID) AS SubQty,
					(SELECT dq.Qty
						FROM DistTargetByGroupOrDistributor000 AS d
							INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd ON d.Guid=dd.ParentGUID
							INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq ON dd.Guid=dq.ParentGUID
						WHERE dd.MatGeneralTargetGUID = @MatGUID AND dq.DistGroupGUID = @ParentGroupGUID
					) AS NewTotal
			)
			INSERT INTO #EndResult VALUES (@QtyGUID,(SELECT (C.SubQty * C.NewTotal / C.OldTotal) FROM C))

				FETCH NEXT FROM targetCursor 
					INTO @QtyGUID, @ParentGroupGUID, @MatGroupGUID, @level
			END
CLOSE targetCursor
DEALLOCATE targetCursor;
DROP Table [#Result]
 UPDATE Q
	SET Qty = E.Qty
	FROM DistTargetByGroupOrDistributorQty000 AS Q
			INNER JOIN #EndResult AS E
				ON Q.GUID = E.GUID
DROP Table [#EndResult]
########################################
CREATE PROCEDURE prcDeleteDistGroupTargetTree
	@GroupGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

;WITH Tree (GUID, name, level) AS  
(
  SELECT GUID, name, 1 as level         
  FROM DistHi000
  WHERE ParentGUID = @GroupGUID
  UNION ALL
  SELECT child.GUID, child.name, parent.level + 1         
  FROM DistHi000 as child
    JOIN tree as parent on parent.GUID = child.parentGUID
  UNION ALL
  SELECT child.GUID, child.name, parent.level + 1
  FROM Distributor000 as child
    JOIN tree as parent on parent.GUID = child.HierarchyGUID  
)
SELECT  T.GUID AS GroupGuid,T.name INTO #Result FROM Tree AS T
ORDER BY level
IF EXISTS (SELECT * FROM #Result)
BEGIN
DELETE FROM DistTargetByGroupOrDistributor000 WHERE [GUID] IN (SELECT ParentGUID FROM DistTargetByGroupOrDistributorDetails000 WHERE Guid IN 
(SELECT ParentGUID FROM DistTargetByGroupOrDistributorQty000 AS dq INNER JOIN #Result AS r ON r.GroupGuid = dq.DistGroupGUID OR r.GroupGuid = dq.DistGUID))
DELETE FROM DistTargetByGroupOrDistributorDetails000 WHERE Guid IN 
(SELECT ParentGUID FROM DistTargetByGroupOrDistributorQty000 AS dq INNER JOIN #Result AS r ON r.GroupGuid = dq.DistGroupGUID OR r.GroupGuid = dq.DistGUID)
DELETE FROM DistTargetByGroupOrDistributorQty000 WHERE DistGroupGUID IN (SELECT GroupGuid FROM #Result) OR DistGUID IN (SELECT GroupGuid FROM #Result)
END
DROP Table [#Result]
########################################
CREATE PROCEDURE prcDeleteDistUnitTargetTree
	@GroupGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
DELETE FROM DistTargetByGroupOrDistributorQty000 WHERE ParentGUID IN (SELECT GUID FROM DistTargetByGroupOrDistributorDetails000 WHERE ParentGUID IN (SELECT GUID FROM DistTargetByGroupOrDistributor000 WHERE ParentDisGroupGUID = @GroupGUID))
DELETE FROM DistTargetByGroupOrDistributorDetails000 WHERE ParentGUID IN (SELECT GUID FROM DistTargetByGroupOrDistributor000 WHERE ParentDisGroupGUID = @GroupGUID)
DELETE FROM DistTargetByGroupOrDistributor000 WHERE ParentDisGroupGUID = @GroupGUID
################################################################################
#END
