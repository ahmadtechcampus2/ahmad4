#########################################
## repGetLakeRawMatList
##########################################
## Added by Raouf
###############################################
### «·ﬂ„Ì«  «·‰«ﬁ’… ›Ì ⁄„·Ì«  «· ’‰Ì⁄
CREATE  procedure repGetLakeRawMatList  
						@FormGUID uniqueidentifier, 
						@StoreGUID uniqueidentifier 
AS
SET NOCOUNT ON
DECLARE @Lang INT = dbo.fnConnections_GetLanguage();
CREATE TABLE #Result
(
	MatGUID UniqueIdentifier,
	MatName NVARCHAR(250) COLLATE ARABIC_CI_AI,
	MatCode NVARCHAR(250) COLLATE ARABIC_CI_AI,
	FormGUID UniqueIdentifier,
	miQty FLOAT,
	MatDefUnit NVARCHAR(150) COLLATE ARABIC_CI_AI,
	MatDefUnitFact FLOAT,
	MsMatQty FLOAT
)

INSERT INTO #Result
SELECT
	mi.miMatGUID,
	(CASE @Lang WHEN 0 THEN mi.mtName ELSE (CASE mi.mtLatinName WHEN N'' THEN mi.mtName ELSE mi.mtLatinName END) END ),
	mi.mtCode,
	mi.mnFormGUID,
	CASE mi.mtDefUnit
		WHEN 1 THEN ISNULL( mi.miQty, 0)
		WHEN 2 THEN ISNULL( mi.miQty, 0) / ISNULL( CASE mi.mtUnit2Fact WHEN 0 THEN 1 ELSE mi.mtUnit2Fact END,1) 
		WHEN 3 THEN ISNULL( mi.miQty, 0) / ISNULL( CASE mi.mtUnit3Fact WHEN 0 THEN 1 ELSE mi.mtUnit3Fact END,1) 
	END AS miQty,
	mi.mtDefUnitName,
	mi.mtDefUnitFact,
	(ms.msQty / mi.mtDefUnit) AS msQty
FROM
	vwMnMiMt AS mi LEFT JOIN vwMs AS ms ON ms.msStorePtr = @StoreGUID AND ms.msMatPtr = mi.miMatGUID
WHERE
	mi.mnType = 0 AND 
	--mi.miType = 1 AND // in order to enable adding Semi Manufacturing Mats
	mi.mnFormGUID = @FormGUID
SELECT * FROM #Result
######################################################################
#END
