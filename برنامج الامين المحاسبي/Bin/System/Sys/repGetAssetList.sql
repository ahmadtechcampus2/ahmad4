#############################################################################
CREATE PROCEDURE repGetAssetList 
	@mtGuid	UNIQUEIDENTIFIER = NULL
AS  
	SET NOCOUNT ON
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result( 
			Guid		UNIQUEIDENTIFIER, 
			GroupGuid 	UNIQUEIDENTIFIER, 
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Number		FLOAT, 
			MatSecurity INT  
		   	)  
	  
	INSERT INTO #Result
	SELECT   
			ad.adGuid, 
			ad.adGuid, 
			mt.mtCode AS adCode,   
			ad.adSn AS adName, 
			ad.Number AS adNumber, 
			mt.mtSecurity AS adSecurity 
	FROM  
			vwAd as ad INNER JOIN vwAs AS ass 
			ON adAssGuid = ass.asGuid 
			INNER JOIN vwMt AS mt
			ON mt.mtGUID = ass.asParentGUID
	WHERE 
			(@mtGuid IS NULL) OR ( mt.mtGUID = @mtGuid) 
	  
	EXEC prcCheckSecurity  
	SELECT * FROM #Result  
	SELECT * FROM #SecViol
######################################################################################
#END