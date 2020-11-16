################################################################################
CREATE VIEW vwPOSSDSegmentsElemnts
AS
	/*******************************************************************************************************
	Company : Syriansoft
	View : vwPOSSDSegmentsElemnts
	Purpose: list all the segments and segments detail by join both tables based on FK
	How to Call: SELECT * FROM vwPOSSDSegmentsElemnts
	Create By: Hanadi Salka													Created On: 06 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT
		s.Id			AS SGuid,
		s.Number		AS SDisplayOrder,
		s.Name			AS SName,
		s.LatinName		AS SLatinName,
		se.Id			AS SEGuid,
		se.Number		AS SEDisplayOrder,
		se.Code			AS SECode,
		se.Name			AS SEName,
		se.LatinName	AS SELatinName

	FROM Segments000	AS s INNER JOIN SegmentElements000 AS se ON (se.SegmentId = s.Id);
################################################################################
#END
