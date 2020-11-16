###############################################################################
CREATE FUNCTION fnGetMatVCoord1( @VCoord1Index [INT]) 
	RETURNS @Result TABLE( [VCoord1] [NVARCHAR](250) COLLATE ARABIC_CI_AI)
AS
BEGIN 
	INSERT INTO @Result
	SELECT DISTINCT 
		(CASE @VCoord1Index 
			WHEN 1 THEN [mtDim]
			WHEN 2 THEN [mtOrigin]
			WHEN 3 THEN [mtPos]
			WHEN 4 THEN [mtCompany]
			WHEN 5 THEN [mtColor]
			WHEN 6 THEN [mtProvenance]
			WHEN 7 THEN [mtQuality]
			WHEN 8 THEN [mtModel] 
		END) AS [VCoord1]
	FROM 
		[vwmt]

	ORDER BY 
		(CASE @VCoord1Index 
			WHEN 1 THEN [mtDim]
			WHEN 2 THEN [mtOrigin]
			WHEN 3 THEN [mtPos]
			WHEN 4 THEN [mtCompany]
			WHEN 5 THEN [mtColor]
			WHEN 6 THEN [mtProvenance]
			WHEN 7 THEN [mtQuality]
			WHEN 8 THEN [mtModel] 
		END)
		
	DELETE @Result WHERE [VCoord1] = ''
	RETURN
END 
###############################################################################
#End
