################################################################################
CREATE VIEW vwExtendedSearchMaterials 
AS
 SELECT [MT].[Guid] [Guid], [MT].[Name] [Name], [MT].[LatinName] [LatinName], [MT].[Dim] [Dim], 
        [MT].[Origin] [Origin], [MT].[Pos] [Pos], [MT].[Company] [Company], [MT].[Color] [Color], 
        [MT].[Provenance] [Provenance], [MT].[Quality] [Quality], [MT].[Model] [Model], 
        [Gr].[Name] [GroupName], [MS].[StoreGuid] [StoreGuid], [MS].[Qty] [Qty]
 FROM MT000 MT
 INNER JOIN
      MS000 MS
 ON (MT.Guid = MS.MatGuid)
 INNER JOIN
      GR000 GR
 ON (MT.GroupGuid = Gr.Guid)
 WHERE MS.StoreGuid != 0x0 
################################################################################
CREATE VIEW vwExtendedSearchMaterialInfo 
AS
 SELECT MT.Number Number, MT.Name Name, MT.Code Code, MT.LatinName LatinName, MT.BarCode BarCode, 
        MT.CodedCode CodedCode, MT.Unity Unity, MT.Spec Spec, MT.Qty Qty, MT.High High, Mt.Low Low, 
        MT.Whole Whole, MT.Half Half, MT.Retail Retail, MT.EndUser EndUser, MT.Export Export, MT.Vendor Vendor, 
        MT.MaxPrice MaxPrice, MT.AvgPrice AvgPrice, MT.LastPrice LastPrice, MT.PriceType PriceType, 
        MT.SellType SellType, MT.BonusOne BonusOne, MT.CurrencyVal CurrencyVal, MT.UseFlag UseFlag, 
        MT.Origin Origin, MT.Company Company, MT.Type Type, MT.Security Security, MT.LastPriceDate LastPriceDate, 
        MT.Bonus Bonus, MT.Unit2 Unit2, MT.Unit2Fact Unit2Fact, MT.Unit3 Unit3, MT.Unit3Fact Unit3Fact, 
        MT.Flag Flag, MT.Pos Pos, MT.Dim Dim, MT.ExpireFlag ExpireFlag, MT.ProductionFlag ProductionFlag, 
        MT.Unit2FactFlag Unit2FactFlag, MT.Unit3FactFlag Unit3FactFlag, MT.BarCode2 BarCode2, 
        MT.BarCode3 BarCode3, MT.SNFlag SNFlag, MT.ForceInSN ForceInSN, MT.ForceOutSN ForceOutSN, MT.VAT VAT, 
        MT.Color Color, MT.Provenance Provenance, MT.Quality Quality, MT.Model Model, MT.Whole2 Whole2, 
        MT.Half2 Half2, MT.Retail2 Retail2, MT.EndUser2 EndUser2, MT.Export2 Export2, MT.Vendor2 Vendor2, 
        MT.MaxPrice2 MaxPrice2, MT.LastPrice2 LastPrice2, MT.Whole3 Whole3, MT.Half3 Half3, MT.Retail3 Retail3, 
        MT.EndUser3 EndUser3, MT.Export3 Export3, MT.Vendor3 Vendor3, MT.MaxPrice3 MaxPrice3, MT.LastPrice3 LastPrice3, 
        MT.GUID GUID, MT.GroupGUID GroupGUID, MT.PictureGUID PictureGUID, MT.CurrencyGUID CurrencyGUID, 
        MT.DefUnit DefUnit, GR.Name GroupName 
 FROM vcMt MT
       INNER JOIN
      Gr000 GR
       ON (MT.GroupGUID = GR.GUID) 
################################################################################
#END