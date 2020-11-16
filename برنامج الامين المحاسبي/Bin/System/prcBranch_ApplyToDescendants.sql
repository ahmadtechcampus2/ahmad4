######################################################################
CREATE PROCEDURE prcBranch_ApplyToDescendants
	@parent [UNIQUEIDENTIFIER]
AS
/*
this proc
	- 
*/

	RETURN
/*

	SET NOCOUNT ON

	DECLARE
		@Type VARCHAR(50),
		@ListingFunctionName VARCHAR(128),
		@SQL VARCHAR(8000)

	-- get parent refType:
	SELECT
		@Type = Type,
		@ListingFunctionName =ListingFunctionName
	FROM
		brt
	WHERE
		Type = (SELECT TOP 1 RefType FROM bl000 WHERE RefGUID = @parent)

	IF @ListingFunctionName IS NULL
		RETURN

	SET @SQL = '
		DECLARE @t TABLE(GUID UNIQUEIDENTIFIER, refType INT)
		INSERT INTO @t SELECT GUID, ' + @Type + ' FROM ' + @ListingFunctionName + '(''' + CAST(@parent AS VARCHAR(128)) + ''')

		DELETE bl000 FROM bl000 AS b INNER JOIN @t AS t ON b.RefGUID = t.GUID
	
		INSERT INTO bl000 (BranchGUID, RefGUID, RefType)
				SELECT b.BranchGUID, t.GUID, t.refType
				FROM bl000 AS b CROSS JOIN @t t
				WHERE b.RefGUID = @parent'

	EXEC (@SQL)
*/

######################################################################
#END