###########################################################
CREATE VIEW vdMtOrder1
AS
SELECT     mt.Number, mt.Name, mt.Code, mt.LatinName, mt.BarCode, mt.CodedCode, mt.Unity, mt.Spec, mt.Qty, mt.High, mt.Low, mt.Whole, mt.Half, mt.Retail, 
                      mt.EndUser, mt.Export, mt.Vendor, mt.MaxPrice, mt.AvgPrice, mt.LastPrice, mt.PriceType, mt.SellType, mt.BonusOne, mt.CurrencyVal, mt.UseFlag, 
                      mt.Origin, mt.Company, mt.Type, mt.Security, mt.LastPriceDate, mt.Bonus, mt.Unit2, mt.Unit2Fact, mt.Unit3, mt.Unit3Fact, mt.Flag, mt.Pos, mt.Dim, 
                      mt.ExpireFlag, mt.ProductionFlag, mt.Unit2FactFlag, mt.Unit3FactFlag, mt.BarCode2, mt.BarCode3, mt.SNFlag, mt.ForceInSN, mt.ForceOutSN, mt.VAT, 
                      mt.Color, mt.Provenance, mt.Quality, mt.Model, mt.Whole2, mt.Half2, mt.Retail2, mt.EndUser2, mt.Export2, mt.Vendor2, mt.MaxPrice2, mt.LastPrice2, 
                      mt.Whole3, mt.Half3, mt.Retail3, mt.EndUser3, mt.Export3, mt.Vendor3, mt.MaxPrice3, mt.LastPrice3, mt.GUID, mt.GroupGUID, mt.PictureGUID, 
                      mt.CurrencyGUID, mt.DefUnit, mt.bHide, mt.branchMask, mt.OldGUID, mt.NewGUID, mt.Assemble, mt.OrderLimit, mt.CalPriceFromDetail, 
                      mt.ForceInExpire, mt.ForceOutExpire, mt.CreateDate, mt.IsIntegerQuantity, mt.grCode, mt.grName, mt.grLatinName, fn.SellOrderRemainder, 
                      fn.PurchaseOrderRemainder, fn.StockAfterSatisfyingOrders, mt.CompositionName, mt.CompositionLatinName
FROM         dbo.vdMt AS mt INNER JOIN
                      dbo.fnGetOrdersRemainderAndStockQty('1/1/1980', '12/31/2079') AS fn ON mt.GUID = fn.mtGuid
###########################################################
CREATE VIEW vdMtOrder2
AS
SELECT     mt.Number, mt.Name, mt.Code, mt.LatinName, mt.BarCode, mt.CodedCode, mt.Unity, mt.Spec, mt.Qty, mt.High, mt.Low, mt.Whole, mt.Half, mt.Retail, 
                      mt.EndUser, mt.Export, mt.Vendor, mt.MaxPrice, mt.AvgPrice, mt.LastPrice, mt.PriceType, mt.SellType, mt.BonusOne, mt.CurrencyVal, mt.UseFlag, 
                      mt.Origin, mt.Company, mt.Type, mt.Security, mt.LastPriceDate, mt.Bonus, mt.Unit2, mt.Unit2Fact, mt.Unit3, mt.Unit3Fact, mt.Flag, mt.Pos, mt.Dim, 
                      mt.ExpireFlag, mt.ProductionFlag, mt.Unit2FactFlag, mt.Unit3FactFlag, mt.BarCode2, mt.BarCode3, mt.SNFlag, mt.ForceInSN, mt.ForceOutSN, mt.VAT, 
                      mt.Color, mt.Provenance, mt.Quality, mt.Model, mt.Whole2, mt.Half2, mt.Retail2, mt.EndUser2, mt.Export2, mt.Vendor2, mt.MaxPrice2, mt.LastPrice2, 
                      mt.Whole3, mt.Half3, mt.Retail3, mt.EndUser3, mt.Export3, mt.Vendor3, mt.MaxPrice3, mt.LastPrice3, mt.GUID, mt.GroupGUID, mt.PictureGUID, 
                      mt.CurrencyGUID, mt.DefUnit, mt.bHide, mt.branchMask, mt.OldGUID, mt.NewGUID, mt.Assemble, mt.OrderLimit, mt.CalPriceFromDetail, 
                      mt.ForceInExpire, mt.ForceOutExpire, mt.CreateDate, mt.IsIntegerQuantity, mt.grCode, mt.grName, mt.grLatinName, mt.Qty0, fn.SellOrderRemainder, 
                      fn.PurchaseOrderRemainder, fn.StockAfterSatisfyingOrders, mt.CompositionName, mt.CompositionLatinName
FROM         dbo.vdMt2 AS mt INNER JOIN
                      dbo.fnGetOrdersRemainderAndStockQty('1/1/1980', '12/31/2079') AS fn ON mt.GUID = fn.mtGuid
############################################################
#END