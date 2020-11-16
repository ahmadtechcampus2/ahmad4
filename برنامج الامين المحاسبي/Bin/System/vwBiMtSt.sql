#########################################################
CREATE VIEW vwBiMtSt
AS
	SELECT
		-- bi.biType,
		[bi].[biGUID],
		[bi].[biParent],
		[bi].[biNumber],
		[bi].[biMatPtr],
		[bi].[mtCode],
		[bi].[mtName],
		[bi].[mtLatinName],
		[bi].[mtUnitFact],
		[bi].[biQty],
		[bi].[biQty2],
		[bi].[biQty3],
		[bi].[biCalculatedQty2],
		[bi].[biCalculatedQty3],
		[bi].[biBonusQnt],
		[bi].[mtUnityName],
		[bi].[biUnity],
		[bi].[biPrice],
		[st].[stGUID],
		[st].[stNumber],
		[st].[stCode],
		[st].[stName],
		[bi].[biNotes],
		[bi].[biDiscount],
		[bi].[biBonusDisc],
		[bi].[biProfits],
		[bi].[biExpireDate],
		[bi].[biProductionDate],
		[bi].[biCostPtr],
		[bi].[biClassPtr],
		[bi].[biLength],
		[bi].[biWidth],
		[bi].[biHeight],
		[bi].[biCount]
	FROM
		[vwBiMt] AS [bi] INNER JOIN [vwSt] AS [st]
		ON [bi].[biStorePtr] = [St].[stGUID]

#########################################################
#END