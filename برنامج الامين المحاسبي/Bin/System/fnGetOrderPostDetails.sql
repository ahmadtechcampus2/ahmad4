#########################################################
CREATE FUNCTION fnGetOrderPostDetails
(
	@OrderGuid UNIQUEIDENTIFIER = 0x0
) 
RETURNS @Result TABLE ([BtType]				INT ,
					   [OrderNumber]		INT,
					   [OrderBiNumber]		INT,
					   [OrderGuid]			UNIQUEIDENTIFIER,
					   [OrderCostGuid]		UNIQUEIDENTIFIER,
					   [OrderCustGuid]		UNIQUEIDENTIFIER,
					   [OrderBiGuid]		UNIQUEIDENTIFIER,
					   [MatGuid]			UNIQUEIDENTIFIER,
					   [OrderDate]			DATETIME,
					   [BtAbbrev]			NVARCHAR(500),
					   [BtLatinAbbrev]		NVARCHAR(500),
					   [UnitName]			NVARCHAR(500),
					   [MatName]			NVARCHAR(500),
					   [MatLatinName]		NVARCHAR(500),
					   [ItemQty]			FLOAT,
					   [ItemPrice]			FLOAT,
					   [ItemTotalPrice]		FLOAT,
					   [NetItemTotalPrice]	FLOAT,
					   [Required]			FLOAT,
					   [Achieved]			FLOAT,
					   [RequiredBonus]		FLOAT,
					   [AchievedBonus]		FLOAT )
AS 
BEGIN
	DECLARE @CurrencyVal [FLOAT] = (SELECT my.CurrencyVal FROM op000 AS op INNER JOIN my000 AS my ON my.GUID = op.Value WHERE op.Name = 'AmnCfg_DefaultCurrency')
	INSERT INTO @Result
		SELECT
			bi.[btType] AS [BtType],
			bi.[buNumber] AS [OrderNumber],			
			bi.[biNumber] AS [OrderBiNumber],
			bi.[buGUID] AS [OrderGuid],
			bi.[buCostPtr] AS [OrderCostGuid],
			bi.[buCustPtr] AS [OrderCustGuid],
			bi.[biGuid] AS [OrderBiGuid],
			bi.[biMatPtr] AS [MatGuid],
			bi.[buDate] AS [OrderDate],
			bi.[btAbbrev] AS [BtAbbrev],
			bi.[btLatinAbbrev] AS [BtLatinAbbrev],
			bi.[mtUnityName] AS [UnitName],
			bi.[mtName] AS [MatName],
			bi.[mtLatinName] AS [MatLatinName],
			(bi.[biQty] / bi.[mtUnitFact]) AS [ItemQty],
			(bi.[biUnitPrice] * bi.[mtUnitFact]) / @CurrencyVal AS [ItemPrice],
			(bi.[biQty] * bi.[biUnitPrice]) / @CurrencyVal AS [ItemTotalPrice],
			((bi.[biUnitPrice] * bi.[biQty]) - bi.[biDiscount] - bi.[biTotalDiscountPercent] + bi.[biExtra] + bi.[biTotalExtraPercent] + bi.[biVAT]) / @CurrencyVal AS [NetItemTotalPrice],
			bi.[biBillQty] AS [Required],
			SUM(CASE WHEN ori.oribuGuid <> 0x0 AND oit.QtyStageCompleted <> 0 AND ori.oriQty > 0 THEN ori.oriQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END) ELSE 0 END) AS [Achieved],
			bi.[biBillBonusQnt] AS [RequiredBonus],
			SUM(CASE WHEN ori.oribuGuid <> 0x0 AND ori.oriBonusPostedQty > 0 THEN ori.oriBonusPostedQty / (CASE WHEN bi.mtUnitFact <> 0 THEN bi.mtUnitFact ELSE 1 END) ELSE 0 END) AS [AchievedBonus]
		FROM
			vwExtended_bi bi
			INNER JOIN mt000 mt ON bi.biMatPtr = mt.GUID
			INNER JOIN vwORI ori ON bi.biGUID = ori.oriPOIGUID
			INNER JOIN oit000 oit ON ori.oriTypeGuid = oit.[Guid]
		WHERE
			bi.buGUID = (CASE WHEN @OrderGuid = 0x0 THEN bi.buGUID ELSE @OrderGuid END)
		GROUP BY
			bi.btType,
			bi.buNumber,
			bi.biNumber,
			bi.buGUID,
			bi.buCostPtr,
			bi.buCustPtr,
			bi.biGuid,
			bi.biMatPtr,
			bi.buDate,
			bi.btAbbrev,
			bi.btLatinAbbrev,
			bi.mtUnityName,
			bi.mtName,
			bi.mtLatinName,
			bi.biQty,
			bi.biUnitPrice,
			bi.biDiscount,
			bi.biTotalDiscountPercent,
			bi.biExtra,
			bi.biTotalExtraPercent,
			bi.biVAT,
			bi.biBillQty, 
			bi.biBillBonusQnt,
			bi.[mtUnitFact]
	RETURN
END
#########################################################
#END 