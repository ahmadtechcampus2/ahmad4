################################################################################
## 
CREATE PROCEDURE repGetAssList
	@Lang		INT = 0,					-- Language	(0=Arabic; 1=English)
	@Group		UNIQUEIDENTIFIER = NULL
AS
	CREATE TABLE #SecViol (Type INT, Cnt INT)
	CREATE TABLE #Result(
			Guid		UNIQUEIDENTIFIER,
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
			Number		FLOAT,
			AssSecurity INT
		   	)
	
	INSERT INTO #Result 
	SELECT 
			ass.asGuid, 
			ass.asCode, 
			CASE WHEN (@Lang = 1)AND(ass.asLatinName <> '') THEN  ass.asLatinName ELSE ass.asName END AS asName,
			ass.asNumber,
			ass.asSecurity
	FROM
			vwas as ass
	WHERE 
			(@Group IS NULL) OR (ass.asParent = @Group)
	
	EXEC prcCheckSecurity
	SELECT * FROM #Result
	SELECT * FROM #SecViol
###################################################################################
#END
