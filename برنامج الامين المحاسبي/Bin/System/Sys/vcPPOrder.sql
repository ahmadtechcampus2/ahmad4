##################################################################################
CREATE VIEW vcPPOrder
AS
	SELECT     
		PPO.Number, PPO.GUID, PPO.OrderNum, PPO.Supplier, PPO.Date, PPO.CurrencyGUID, PPO.CurrencyVal, 
		PPO.Notes, PPO.POGuid, PPO.TypeGUID, PPO.Security, PPO.Type, PPO.IsNotAvailableQuantity, 
		cu.CustomerName AS SupplierName, cu.LatinName AS SupplierLatinName, bt.LatinName AS OTLatinName, bt.Name AS OTName , bt.Abbrev AS OTAbbrev, bt.LatinAbbrev OTLatinAbbrev
	FROM         
		dbo.ppo000 AS PPO 
		INNER JOIN dbo.bt000 AS bt ON PPO.TypeGUID = bt.GUID 
		INNER JOIN dbo.cu000 AS cu ON PPO.Supplier = cu.GUID
##################################################################################
#END