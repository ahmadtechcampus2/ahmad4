#############################3###########################
CREATE PROCEDURE PrcHosGetAnalysisMat
(
	@ParentGUID UNIQUEIDENTIFIER,	
	@GRIDTYPE INT	
)
AS
SET NOCOUNT ON 
IF ( @GRIDTYPE = 0 ) 
BEGIN
	SELECT * 
	FROM vwHosRadioGraphyMats 
	WHERE TYPE = 0  AND ParentGUID = @ParentGUID
END
ELSE
BEGIN
	IF EXISTS ( SELECT * FROM  HosRadioGraphyMats000 WHERE  ParentGUID = @ParentGUID )
	BEGIN 
		SELECT * 
		FROM vwHosRadioGraphyMats 
		WHERE TYPE = 1  AND ParentGUID = @ParentGUID
	END
	ELSE
	BEGIN
		SELECT * FROM vwHosRadioGraphyMats
		WHERE 
		ParentGUID IN 
		(
			SELECT 
				D.AnalysisGUID 
			FROM 
				HosToDoAnalysis000 D	
					INNER JOIN HosAnalysis000 C ON C.GUID = D.AnalysisGUID
			WHERE D.AnalysisOrderGUID = @ParentGUID
		)
	END
END

/*
exec [PrcHosGetAnalysisMat] '1c4586d5-ce3c-4c99-a2c4-e9812a9cee25', 1 
*/
############################################################
#END