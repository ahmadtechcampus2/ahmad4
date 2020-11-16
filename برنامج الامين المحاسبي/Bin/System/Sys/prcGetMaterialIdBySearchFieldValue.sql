################################################################################
CREATE PROCEDURE prcGetMaterialIdBySearchFieldValue
	@searchFieldValue	NVARCHAR(256)
AS
	SET NOCOUNT ON
	
	SELECT Guid
	FROM vwExtendedSearchMaterials
	WHERE 	([Name] = @searchFieldValue)
			OR
			([LatinName] = @searchFieldValue)
			OR
			([Dim] = @searchFieldValue)
			OR
			([Origin] = @searchFieldValue)
			OR
			([Pos] = @searchFieldValue)
			OR
			([Company] = @searchFieldValue)
			OR
			([Color] = @searchFieldValue)
			OR
			([Provenance] = @searchFieldValue)
			OR
			([Quality] = @searchFieldValue)
			OR
			([Model] = @searchFieldValue)
			OR
			([GroupName] = @searchFieldValue)
	ORDER BY ABS(ISNULL([Qty], 0)) DESC
################################################################################
#END
