##################################
CREATE PROC prcCalcMatStoreQty
	@MatGUID 		[UNIQUEIDENTIFIER], 
	@StoreGUID 		[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON 

SELECT
	[biStorePtr],
	[BuIsPosted],
	[mtDefUnitFact],
	--SUM((  biQty ) / CASE [mtUnit2Fact]	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) AS Qty2,
	--SUM(( biQty ) / CASE [mtUnit3Fact]	WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) AS Qty3,
	-- SUM( btIsOutput * biQty ) - ( SUM( btIsInput  * biQty ))/CASE [mtUnit2Fact]	WHEN 0 THEN 1 ELSE [mtUnit2Fact] END ,
	((SUM([btIsInput]*[biQty] ) - SUM([btIsOutput]*[biQty]) )/ (CASE [mtDefUnitFact] 	WHEN 0 THEN 1 ELSE [mtDefUnitFact] END ))AS [DefQty]--,
	--SUM( biQty ) AS Qty1
FROM
	[vwExtended_Bi]
WHERE
	[biMatPtr] = @MatGUID
	AND [biStorePtr] = @StoreGUID
GROUP BY
	[biStorePtr]
	,[buIsPosted]
	,[mtDefUnitFact]

/*

select * from st000

Exec prcCalcMatStoreQty
'7641B68D-5917-48E4-8A02-81C4D0EA1B5C' ,--	@MatGUID 		[UNIQUEIDENTIFIER], 
'FF7176F0-E717-43AB-B80E-95C50CE0E687' --	@StoreGUID 		[UNIQUEIDENTIFIER]

EXEC prcCalcMatStoreQty 'd4eff03a-5541-4c22-8cde-573d281b8040', '8A272AF1-697B-4559-B74C-C3BCA82A107C' 

*/
###########################
#END
