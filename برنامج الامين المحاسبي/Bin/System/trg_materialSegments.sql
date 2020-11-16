###########################################################################
CREATE TRIGGER trg_MaterialSegmentElements000_DELETE
ON MaterialSegmentElements000 FOR DELETE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS ( 
				SELECT * FROM MaterialElements000 me
				JOIN SegmentElements000 se on me.ElementId = se.Id
				JOIN mt000 mt ON mt.GUID = me.MaterialId
				JOIN MaterialSegments000 ms ON mt.Parent = ms.MaterialId AND se.SegmentId = ms.SegmentId
				JOIN deleted mse ON ms.Id = mse.MaterialSegmentId AND mse.ElementId = me.ElementId
			  )
	BEGIN
		INSERT INTO ErrorLog ([level], [Type], c1)
		VALUES (1, 0,  'AmnE0074')
	END

	
###########################################################################

CREATE TRIGGER trg_MaterialSegments000_DELETE
ON MaterialSegments000 FOR DELETE
NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	IF EXISTS ( 
				SELECT * FROM MaterialElements000 me
				JOIN SegmentElements000 se on me.ElementId = se.Id
				JOIN mt000 mt ON mt.GUID = me.MaterialId
				JOIN deleted ms ON mt.Parent = ms.MaterialId AND se.SegmentId = ms.SegmentId
				JOIN MaterialSegmentElements000 mse ON ms.Id = mse.MaterialSegmentId AND mse.ElementId = me.ElementId
			  )
	BEGIN
		INSERT INTO ErrorLog ([level], [Type], c1)
		VALUES (1, 0,  'AmnE0075')
	END

###########################################################################
#END