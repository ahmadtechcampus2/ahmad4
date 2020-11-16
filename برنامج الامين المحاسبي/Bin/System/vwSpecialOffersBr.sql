#########################################################
CREATE VIEW vwSpecialOffersBr
AS
SELECT     so.GUID soGuid, 
           so.Number soNumber,
		   so.Code soCode, 
		   so.Name soName, 
		   so.LatinName soLatinName, 
		   so.Type soType, 
		   so.StartDate soStartDate, 
		   so.EndDate soEndDate, 
		   so.AccountGUID soAccountGUID, 
		   so.CostGUID soCostGUID, 
		   so.IsAllBillTypes soIsAllBillTypes, 
		   so.CustCondGUID soCustCondGUID, 
		   so.IsActive soIsActive, 
		   so.Class soClass, 
		   so.[Group] soGroup, 
		   so.ItemsCondition soItemsCondition, 
           so.OfferedItemsCondition soOfferedItemsCondition, 
		   so.Quantity soQuantity, 
		   so.Unit soUnit, 
		   so.ItemsAccount soItemsAccount, 
		   so.ItemsDiscountAccount soItemsDiscountAccount, 
		   so.OfferedItemsAccount soOfferedItemsAccount, 
		   so.OfferedItemsDiscountAccount soOfferedItemsDiscountAccount, 
		   so.BranchMask soBranchMask, 
           so.IsApplicableToCombine soIsApplicableToCombine,
		   vwbr.*
FROM       dbo.SpecialOffers000 so inner join vwbr ON (POWER(2, vwbr.brNumber-1) &  so.BranchMask) >0
#########################################################
#END