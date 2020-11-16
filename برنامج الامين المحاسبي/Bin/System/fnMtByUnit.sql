###########################################################################
CREATE Function fnMtByUnit(@UseUnit int)
RETURNS TABLE 
AS
	-- Return vwMt + unFields
	-- @UseUnit = 1 >> Unit1
	-- @UseUnit = 2 >> Unit2
	-- @UseUnit = 3 >> Unit3
	-- @UseUnit = 4 >> DefUnit
	--
	RETURN
	SELECT 
		mt.*,
			(CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN	CASE mt.mtUnit2Fact 
								WHEN 0 THEN 1
								ELSE 2
							END
				WHEN 3 THEN	CASE mt.mtUnit3Fact
								WHEN 0 THEN 1
								ELSE 3
							END
				WHEN 4 THEN	CASE mt.mtDefUnit
								WHEN 0 THEN 1
								ELSE 4
							END
			ELSE 1
			END) AS unUnit,
			-----------------------------------------------------
			(CASE @UseUnit
				WHEN 1 THEN mt.mtUnity 
				WHEN 2 THEN	CASE mt.mtUnit2Fact 
								WHEN 0 THEN mt.mtUnity
								ELSE mt.mtUnit2
							END
				WHEN 3 THEN	CASE mt.mtUnit3Fact
								WHEN 0 THEN mt.mtUnity
								ELSE mt.mtUnit3
							END
				WHEN 4 THEN	CASE mt.mtDefUnit
								WHEN 0 THEN mt.mtUnity
								ELSE mt.mtDefUnitName
							END
			ELSE mt.mtUnity
			END) AS unUnitName,
			-----------------------------------------------------
			(CASE @UseUnit
				WHEN 1 THEN 1
				WHEN 2 THEN	CASE mt.mtUnit2Fact 
								WHEN 0 THEN 1
								ELSE mt.mtUnit2Fact
							END
				WHEN 3 THEN	CASE mt.mtUnit3Fact
								WHEN 0 THEN 1
								ELSE mt.mtUnit3Fact
							END
				WHEN 4 THEN	CASE mt.mtDefUnitFact
								WHEN 0 THEN 1
								ELSE mt.mtDefUnitFact
							END
				ELSE 1 
			END) AS unUnitFact
			-----------------------------------------------------
	FROM
		vwMt AS mt
###########################################################################
#END