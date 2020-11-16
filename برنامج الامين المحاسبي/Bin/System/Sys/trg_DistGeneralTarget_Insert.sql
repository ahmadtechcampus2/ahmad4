#########################################################
CREATE TRIGGER trg_DistGeneralTarget_Insert
	ON DisGeneralTarget000	AFTER INSERT
	NOT FOR REPLICATION
AS
IF EXISTS (SELECT *
           FROM DistTargetByGroupOrDistributor000 AS d
		   INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd
		   ON d.Guid = dd.ParentGUID
           INNER JOIN inserted AS i 
           ON dd.MatGeneralTargetGUID = i.GUID
           WHERE i.PeriodGUID = d.PeriodGuid
          )
	BEGIN
		DECLARE 
		@GroupGUID UNIQUEIDENTIFIER, @ParentGUID UNIQUEIDENTIFIER, @PeriodGUID UNIQUEIDENTIFIER,
		@OldTotal FLOAT, @NewTotal FLOAT,@SubQty FLOAT
		SET @ParentGUID = (SELECT GUID FROM inserted)
		SET @PeriodGUID = (SELECT PeriodGUID FROM inserted)
		SET @OldTotal = (SELECT SUM(dq.Qty) FROM DistTargetByGroupOrDistributor000 AS d
							INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd
							ON  d.Guid = dd.ParentGUID
							INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq
							ON dd.Guid = dq.ParentGUID
							WHERE dq.DistGroupGUID IN(SELECT GUID FROM DistHi000 WHERE ParentGUID = 0x)
							 AND d.PeriodGuid = @PeriodGUID AND dd.MatGeneralTargetGUID = (SELECT GUID FROM inserted))
		SET @NewTotal = (SELECT Qty FROM inserted)
		DECLARE @GroupCursor CURSOR
		SET @GroupCursor =
			CURSOR FOR SELECT GUID FROM DistHi000 WHERE ParentGUID = 0x
		OPEN @GroupCursor
			FETCH NEXT FROM @GroupCursor
			INTO @GroupGUID
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SubQty = (SELECT dq.Qty FROM DistTargetByGroupOrDistributor000 AS d
							INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd
							 ON  d.Guid = dd.ParentGUID
							INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq
							 ON dd.Guid = dq.ParentGUID
							WHERE dq.DistGroupGUID = @GroupGUID
							 AND d.PeriodGuid = @PeriodGUID 
							 AND dd.MatGeneralTargetGUID = (SELECT GUID FROM inserted))

					IF @OldTotal > 0 AND @SubQty > 0
							BEGIN
							UPDATE DistTargetByGroupOrDistributorQty000
								SET Qty = ((((100 / @OldTotal) * @SubQty) * @NewTotal) / 100)
								WHERE GUID = (
								SELECT dq.GUID FROM DistTargetByGroupOrDistributor000 AS d
								INNER JOIN DistTargetByGroupOrDistributorDetails000 AS dd
									ON  d.Guid = dd.ParentGUID
								INNER JOIN DistTargetByGroupOrDistributorQty000 AS dq
									ON dd.Guid = dq.ParentGUID
								WHERE dq.DistGroupGUID = @GroupGUID
									AND d.PeriodGuid = @PeriodGUID 
									AND dd.MatGeneralTargetGUID = (SELECT GUID FROM inserted))
							END

					EXEC prcUpdateDistributionTreeQty @GroupGUID, @ParentGUID, @PeriodGUID, 1
			FETCH NEXT FROM @GroupCursor 
					INTO @GroupGUID
				END
		CLOSE @GroupCursor
		DEALLOCATE @GroupCursor
	END
#########################################################
#END