###########################################################################
CREATE VIEW vwRestOrderTemp 
AS  
SELECT     Orders.Number, Orders.Guid, Orders.Type, Orders.State, Orders.CashierID, Orders.FinishCashierID, Orders.BranchID, Orders.Notes, Orders.Cashed, Orders.Discount, 
                      Orders.Added, Orders.Tax, Orders.SubTotal, Orders.CustomerID, Orders.DeferredAccountID, Orders.CurrencyID, Orders.IsPrinted, Orders.HostName, 
                      Orders.BillNumber, Orders.DepartmentID, Orders.GuestID, Orders.PaymentsPackageID, Orders.Opening, Orders.Preparing, Orders.Receipting, Orders.Closing, 
                      Orders.Version, ISNULL(Vendor.Name, '') AS VendorName, ISNULL(Vendor.LatinName, '') AS VendorLatinName, ISNULL(Depart.Name, '') AS DepartmentName, 
                      ISNULL(Depart.LatinName, '') AS DepartmentLatinName, ISNULL(br.Code, '') AS BranchCode, ISNULL(br.Name, '') AS BranchName, ISNULL(us.LoginName, '') 
                      AS UserName, ISNULL(cu.CustomerName, '') AS CustomerName, ISNULL(cu.Country, '') AS CustomerCountry, ISNULL(cu.City, '') AS CustomerCity, ISNULL(cu.Area, '') 
                      AS CustomerArea, ISNULL(cu.Street, '') AS CustomerStreet, ISNULL(cu.Address, '') AS CustomerAddress, ISNULL(cu.Phone1, '') AS CustomerPhone1, 
                      ISNULL(cu.Phone2, '') AS CustomerPhone2, ISNULL(cu.Mobile, '') AS CustomerMobile, Orders.PrintTimes, Orders.ExternalcustomerName, Orders.CustomerAddressID,
					  Orders.DeliveringTime, Orders.DeliveringFees, Orders.IsManualPrinted
FROM         dbo.RestOrderTemp000 AS Orders LEFT OUTER JOIN
                      dbo.RestVendor000 AS Vendor ON Orders.GuestID = Vendor.GUID LEFT OUTER JOIN
                      dbo.RestDepartment000 AS Depart ON Depart.GUID = Orders.DepartmentID LEFT OUTER JOIN
                      dbo.br000 AS br ON br.GUID = Orders.BranchID LEFT OUTER JOIN
                      dbo.us000 AS us ON us.GUID = Orders.CashierID LEFT OUTER JOIN
                      dbo.vexCu AS cu ON cu.GUID = Orders.CustomerID
###########################################################################
CREATE VIEW vwRestOrderItemsTemp
AS 
SELECT  
	[Items].[Number], 
	[Items].[Guid], 
	[MatID], 
	[Items].[Type], 
	[Mat].[Name] AS [MatName], 
	[Mat].[LatinName] AS [MatLatinName], 
	[Mat].[Code] AS [MatCode], 
	[Items].[Qty],   
	[Items].[Qty] * CASE [Items].[Unity] 	WHEN 1 THEN 1.0 
		WHEN 2 THEN [Unit2Fact] 
		WHEN 3 THEN [Unit3Fact] 
	END AS QtyByDefUnit, 
	[Items].[MatPrice], 
	[Items].[Price], 
	[Mat].[Whole] AS [WholePrice],
	[Mat].[Half] AS [HalfPrice],
	[Mat].[Retail] AS [RetailPrice],
	[Mat].[EndUser] AS [EndUserPrice],
	[Mat].[Export] AS [ExportPrice],
	[Mat].[Vendor] AS [VendorPrice],
	[Mat].[MaxPrice] AS [MaxPrice],
	[Mat].[AvgPrice] AS [AvgPrice],
	[Mat].[LastPrice] AS [LastPrice],
	[Mat].[Dim] AS [Dimension],
	[Mat].[Origin] AS [Origin],
	[Mat].[Pos] AS [Position],
	[Mat].[Company] AS [Company],
    [Mat].[Color] AS [Color], 
	[Mat].[Provenance] AS [Provenance], 
    [Mat].[Quality] AS [Quality],
    [Mat].[Model] AS [Model],
    [Mat].[Spec] AS [Specification],
    [Items].[PriceType], 
	[Items].[Unity], 
	CASE [Items].[Unity] 	WHEN 1 THEN [Mat].[Unity] 
		WHEN 2 THEN [Unit2] 
		WHEN 3 THEN [Unit3] 
	END AS [UnitName], 
	CASE [Items].[Unity] 	WHEN 1 THEN 1 
		WHEN 2 THEN [Unit2Fact] 
		WHEN 3 THEN [Unit3Fact] 
	END AS [UnitFactory],		 
	[Items].[State], 
	[Items].[Discount] AS [DiscountValue], 
	[Items].[Added] AS [AddedValue],	 
	[Items].[Price] * [Items].[Qty] AS [SubTotal], 
	[Items].[Price] * [Items].[Qty] AS [Total], 
	[ParentID], 
	[ItemParentID], 
	[Items].[PrinterID], 
	[Mat].[GroupGuid] AS [GroupID], 
	[Group].[Code] AS [GroupCode], 
	[Group].[Name] AS [GroupName], 
	[Items].[BillType], 
	[Items].[Note], 
	[Items].[SpecialOfferID], 
	[Items].[SpecialOfferIndex], 
	[Items].[OfferedItem], 
	[Items].[IsPrinted],
	[Items].[KitchenID],
	[Items].[Vat],
	[Items].[VatRatio],
	[Items].[ChangedQty]
FROM [RestOrderItemTemp000] [Items] 
  LEFT JOIN [Mt000] AS [Mat] ON [Items].[MatID] = [Mat].[Guid] 
  LEFT JOIN [Gr000] AS [Group] ON [Mat].[GroupGuid] = [Group].[Guid] 
  LEFT JOIN [Bt000] AS [BillType] ON [Items].[BillType] = [BillType].[Guid]
###########################################################################
CREATE VIEW vwRestAllOrders
AS 
SELECT * FROM RestOrder000
UNION ALL 
SELECT * FROM RestOrderTemp000
###########################################################################
CREATE VIEW vwRestAllOrdersItems
AS 
SELECT * FROM RestOrderItem000
UNION ALL 
SELECT * FROM RestOrderItemTemp000
###########################################################################
CREATE VIEW vwRestOrder
AS  
SELECT     Orders.Number, Orders.Guid, Orders.Type, Orders.State, Orders.CashierID, Orders.FinishCashierID, Orders.BranchID, Orders.Notes, Orders.Cashed, Orders.Discount, 
                      Orders.Added, Orders.Tax, Orders.SubTotal, Orders.CustomerID, Orders.DeferredAccountID, Orders.CurrencyID, Orders.IsPrinted, Orders.HostName, 
                      Orders.BillNumber, Orders.DepartmentID, Orders.GuestID, Orders.PaymentsPackageID, Orders.Opening, Orders.Preparing, Orders.Receipting, Orders.Closing, 
                      Orders.Version, ISNULL(Vendor.Name, '') AS VendorName, ISNULL(Vendor.LatinName, '') AS VendorLatinName, ISNULL(Depart.Name, '') AS DepartmentName, 
                      ISNULL(Depart.LatinName, '') AS DepartmentLatinName, ISNULL(br.Code, '') AS BranchCode, ISNULL(br.Name, '') AS BranchName, ISNULL(us.LoginName, '') 
                      AS UserName, ISNULL(cu.CustomerName, '') AS CustomerName, ISNULL(cu.Country, '') AS CustomerCountry, ISNULL(cu.City, '') AS CustomerCity, ISNULL(cu.Area, '') 
                      AS CustomerArea, ISNULL(cu.Street, '') AS CustomerStreet, ISNULL(cu.Address, '') AS CustomerAddress, ISNULL(cu.Phone1, '') AS CustomerPhone1, 
                      ISNULL(cu.Phone2, '') AS CustomerPhone2, ISNULL(cu.Mobile, '') AS CustomerMobile, Orders.PrintTimes, Orders.ExternalcustomerName, Orders.CustomerAddressID,
					  Orders.DeliveringTime, Orders.DeliveringFees, Orders.IsManualPrinted
FROM         dbo.RestOrder000 AS Orders LEFT OUTER JOIN
                      dbo.RestVendor000 AS Vendor ON Orders.GuestID = Vendor.GUID LEFT OUTER JOIN
                      dbo.RestDepartment000 AS Depart ON Depart.GUID = Orders.DepartmentID LEFT OUTER JOIN
                      dbo.br000 AS br ON br.GUID = Orders.BranchID LEFT OUTER JOIN
                      dbo.us000 AS us ON us.GUID = Orders.CashierID LEFT OUTER JOIN
                      dbo.vexCu AS cu ON cu.GUID = Orders.CustomerID
###########################################################################
CREATE VIEW vwRestOrderItems
AS 
SELECT  
	[Items].[Number], 
	[Items].[Guid], 
	[MatID], 
	[Items].[Type], 
	[Mat].[Name] AS [MatName], 
	[Mat].[LatinName] AS [MatLatinName], 
	[Mat].[Code] AS [MatCode], 
	[Items].[Qty],   
	[Items].[Qty] * CASE [Items].[Unity] 	WHEN 1 THEN 1.0 
		WHEN 2 THEN [Unit2Fact] 
		WHEN 3 THEN [Unit3Fact] 
	END AS QtyByDefUnit, 
	[Items].[MatPrice], 
	[Items].[Price], 
	[Mat].[Whole] AS [WholePrice],
	[Mat].[Half] AS [HalfPrice],
	[Mat].[Retail] AS [RetailPrice],
	[Mat].[EndUser] AS [EndUserPrice],
	[Mat].[Export] AS [ExportPrice],
	[Mat].[Vendor] AS [VendorPrice],
	[Mat].[MaxPrice] AS [MaxPrice],
	[Mat].[AvgPrice] AS [AvgPrice],
	[Mat].[LastPrice] AS [LastPrice],
	[Mat].[Dim] AS [Dimension],
	[Mat].[Origin] AS [Origin],
	[Mat].[Pos] AS [Position],
	[Mat].[Company] AS [Company],
    [Mat].[Color] AS [Color], 
	[Mat].[Provenance] AS [Provenance], 
    [Mat].[Quality] AS [Quality],
    [Mat].[Model] AS [Model],
    [Mat].[Spec] AS [Specification],
    [Items].[PriceType], 
	[Items].[Unity], 
	CASE [Items].[Unity] 	WHEN 1 THEN [Mat].[Unity] 
		WHEN 2 THEN [Unit2] 
		WHEN 3 THEN [Unit3] 
	END AS [UnitName], 
	CASE [Items].[Unity] 	WHEN 1 THEN 1 
		WHEN 2 THEN [Unit2Fact] 
		WHEN 3 THEN [Unit3Fact] 
	END AS [UnitFactory],		 
	[Items].[State], 
	[Items].[Discount] AS [DiscountValue], 
	[Items].[Added] AS [AddedValue],	 
	[Items].[Price] * [Items].[Qty] AS [SubTotal], 
	[Items].[Price] * [Items].[Qty] AS [Total], 
	[ParentID], 
	[ItemParentID], 
	[Items].[PrinterID], 
	[Mat].[GroupGuid] AS [GroupID], 
	[Group].[Code] AS [GroupCode], 
	[Group].[Name] AS [GroupName], 
	[Items].[BillType], 
	[Items].[Note], 
	[Items].[SpecialOfferID], 
	[Items].[SpecialOfferIndex], 
	[Items].[OfferedItem], 
	[Items].[IsPrinted],
	[Items].[KitchenID],
	[Items].[Vat],
	[Items].[VatRatio],
	[Items].[ChangedQty]
FROM [RestOrderItem000] [Items] 
  LEFT JOIN [Mt000] AS [Mat] ON [Items].[MatID] = [Mat].[Guid] 
  LEFT JOIN [Gr000] AS [Group] ON [Mat].[GroupGuid] = [Group].[Guid] 
  LEFT JOIN [Bt000] AS [BillType] ON [Items].[BillType] = [BillType].[Guid]
###########################################################################
#END
