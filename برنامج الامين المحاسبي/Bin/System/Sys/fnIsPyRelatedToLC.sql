#########################################################
CREATE FUNCTION fnIsPyRelatedToLC(@PyGUID UNIQUEIDENTIFIER)
	RETURNS BIT 
AS 
BEGIN 
	IF EXISTS( 
			SELECT 
				enLCGUID 
			FROM vwER_EntriesPays  py
			INNER JOIN vwEn en ON  en.enParent = py.erEntryGUID 
			INNER JOIN LC000 lc ON lc.GUID = en.enLCGUID
			WHERE lc.State = 0 AND py.erPayGUID = @PyGUID)
		RETURN 1
	RETURN 0
END 
#########################################################
#END