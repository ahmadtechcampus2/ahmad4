#########################################################
CREATE VIEW vwSCCustomerinfo 
AS
SELECT      ISNULL(obr.GUID, 0x0) AS OfferedBranchGuid, 
			ISNULL(status.Guid, 0x0) AS statusGuid, 
			ISNULL(cu.GUID, 0x0) AS customerGuid, 
			ISNULL(Cardtype.Guid, 0x0) AS cardtypeGuid, 
            ISNULL(card.Code, '') AS code, 
			ISNULL(cu.FirstName, cuSup.CustomerName) AS name, 
			ISNULL(cu.LatinFirstName, '')  AS latinName, 
			ISNULL(cu.NationalIdentityNumber, '') AS identityNumber, 
			ISNULL(cu.BestTime, '') AS BestTime, 
			ISNULL(cu.Residence, '') AS Residence, 
            ISNULL(cu.Address, '') AS Address, 
			ISNULL(cu.City, '') AS City, 
			ISNULL(cu.Email, '') AS Email, 
			ISNULL(cu.PostalAddress, '') AS box, 
			ISNULL(dbr.Name, '')  AS dealtWithBranch, 
			ISNULL(cu.FormReceiptDate, '') AS FormReceiptDate, 
			ISNULL(obr.Name, '') AS OfferedBranch, 
			ISNULL(cu.FormSubmitDate, '') AS FormSubmitDate, 
            ISNULL(cuSup.Phone1, '')  AS telephone1,
			ISNULL(cuSup.Phone2, '') AS telephone2, 
			ISNULL(cu.Profession, '') AS Profession, 
			ISNULL(cu.subscriptionCode, '') AS subscriptionCode, 
			ISNULL(cu.BirthDate, '') AS BirthDate, 
			ISNULL(cu.FormReceiptDate, '')  AS firstAffiliationDate, 
            ISNULL(card.StartDate, '1-1-1980') AS validityStartDate, 
			ISNULL(card.EndDate, '1-1-1980') AS validityEndDate, 
			ISNULL(Cardtype.Name, '') AS discountCardType, 
            ISNULL(card.ID, 0) AS cardNumber, 
			ISNULL(card.TotalBuy, '') AS purchaseBalance, 
			ISNULL(cu.PostalAddress, '') AS PostalAddress, 
			ISNULL(cu.Note, '') AS Note
FROM         dbo.SCCustomers000 AS cu RIGHT JOIN
             dbo.cu000 AS cuSup ON cuSup.GUID = cu.CustomerSupplier LEFT OUTER JOIN
             dbo.br000 AS obr ON cu.OfferedBransh = obr.GUID LEFT OUTER JOIN
             dbo.br000 AS dbr ON cu.DealtWithBranch = dbr.GUID LEFT OUTER JOIN
             dbo.DiscountCard000 AS card ON cuSup.GUID = card.CustomerGuid LEFT OUTER JOIN
             dbo.DiscountCardStatus000 AS status ON status.Guid = card.State LEFT OUTER JOIN
             dbo.DiscountTypesCard000 AS Cardtype ON Cardtype.Guid = card.Type
#########################################################
#END