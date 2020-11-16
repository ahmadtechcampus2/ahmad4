######################################################################
CREATE PROC repGetAssetDetailsList @AssGUID UNIQUEIDENTIFIER 
AS  
	CREATE TABLE #Result( GUID UNIQUEIDENTIFIER, 
			Name NVARCHAR(255) COLLATE ARABIC_CI_AI)
	INSERT INTO #Result
		SELECT
			adGUID,
			adSN
		FROM  
			vwAD 
		WHERE  
			adAssGuid = @AssGUID 


	SELECT * FROM #Result
########################################################################
#END