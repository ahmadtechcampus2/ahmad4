#########################################################
CREATE VIEW vwExtended_bi_cost
AS
     SELECT  *,
		(([biPrice] * [biBillQty]) - [biProfits] - (([biQty] + [biBillBonusQnt]) * [biUnitDiscount] * [btDiscAffectProfit]) + (([biQty] + [biBillBonusQnt]) * [biUnitExtra] * [btExtraAffectProfit]))as cost,
		CASE [biBillQty] + [biBillBonusQnt] WHEN 0 THEN 0 ELSE (([biPrice] * [biBillQty]) - [biProfits] - (([biQty] + [biBillBonusQnt]) * [biUnitDiscount] * [btDiscAffectProfit]) + (([biQty] + [biBillBonusQnt]) * [biUnitExtra] * [btExtraAffectProfit])) / ([biBillQty] + [biBillBonusQnt]) END as [unitCost]

	FROM  
		[vwExtended_bi]

#########################################################