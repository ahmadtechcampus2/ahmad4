###########################################################################
CREATE TRIGGER trg_materialsSegmentsManagement000_delete 
	ON [MaterialsSegmentsManagement000] FOR DELETE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	
	
	IF EXISTS(SELECT * FROM GroupSegments000 [gs] INNER JOIN [deleted] AS [d] ON [gs].SegmentId = [d].SegmentId ) 
	BEGIN
	  RAISERROR ( 'AmnE0001: Can''t delete Segment(s), it''s being used in Group ...', 16, 1) ;
	END
	
	IF EXISTS(SELECT * FROM MaterialSegments000 [ms] INNER JOIN [deleted] AS [d] ON [ms].SegmentId = [d].SegmentId ) 
	BEGIN
	  RAISERROR ( 'AmnE0002: Can''t delete Segment(s), it''s being used in Materials ...', 16, 1) ;
	END
###########################################################################
#END