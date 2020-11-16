#########################################################
CREATE PROC prcBranch_InstallBRTs
AS
	SET NOCOUNT ON
	-- don't delete the table, prcBranch_addBRT adds if necessary:
	EXEC [prcBranch_AddBRT] 'Account', 'ac000', 'fnGetAccountsTree', 0, '', 'الحسابات', 'Accounts'
	-- cu wont need to join branching, as it depends completely on ac
	EXEC [prcBranch_AddBRT] 'CostJob', 'co000', 'fnGetCostsTree', 0, '', 'مراكز الكلفة', 'Jobs Costing'
	EXEC [prcBranch_AddBRT] 'Material', 'mt000', 'fnGetMaterialsTree', 0, '', 'المواد و المحموعات', 'Materials'
	EXEC [prcBranch_AddBRT] 'Group', 'gr000', DEFAULT, 0, '', 'المجموعات', 'Groups'
	EXEC [prcBranch_AddBRT] 'Store', 'st000', 'fnGetStoresTree', 0, '', 'المستودعات', 'Stores'
	EXEC [prcBranch_AddBRT] 'ManForm', 'fm000', 'fnGetManufacturingFormsTree', 0, '', 'نماذج التصنيع', 'Manufacturing Forms'
	-- EXEC prcBranch_AddBRT 'as000'
	EXEC [prcBranch_AddBRT] 'BillTemplate', 'bt000', 'fnGetBillsTypesTree', 0, '', 'أنماط الفواتير', 'Bills Types'
	EXEC [prcBranch_AddBRT] 'EntryTemplate', 'et000', 'fnGetEntriesTypesTree', 0, '', 'أنماط السندات', 'Entries Types'
	EXEC [prcBranch_AddBRT] 'NoteTemplate', 'nt000', 'fnGetNotesTypesTree', 0, '', 'أنماط الأوراق المالية', 'Notes Types'
	EXEC [prcBranch_AddBRT] 'Currency', 'my000', 'fnGetCurrenciesTree', 0,'', 'العملات', 'Currencies'
	
	EXEC [prcBranch_AddBRT] 'TRNEXCHANGETYPES', 'TrnExchangeTypes000', 'fnGetExchangeTypesTree', 0, '', 'أنماط الصرافة',	'Exchange Types'

	
	
	EXEC [prcBranch_AddBRT] 'TRNSTATEMENTTYPES', 'TrnStatementTypes000', 'fnGetTrnStatementTypesTree', 0, '', 'أنماط الكشوفات الخارجية', 'TrnStatement Types'

	EXEC [prcBranch_AddBRT] 'Bill', 'bu000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'Entry', 'ce000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'Note', 'ch000', DEFAULT, 1, 'BranchGUID'
	EXEC [prcBranch_AddBRT] 'Payment', 'py000', DEFAULT, 1, 'BranchGUID'
	--EXEC [prcBranch_AddBRT] 'Order', 'or000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'Manufac', 'mn000', DEFAULT, 1, 'BranchGUID'
	--EXEC [prcBranch_AddBRT] 'PackingLists', 'km000', DEFAULT, 1, 'BranchGUID'
	--EXEC [prcBranch_DelBRT] 'PackingLists', 'km000', DEFAULT, 1, 'BranchGUID'

	-- EXEC prcBranch_AddBRT 'TRNSENDERRECEIVER', 'TrnSenderReceiver000', DEFAULT, 1, 'BranchGUID'
	-- EXEC prcBranch_AddBRT 'TRNOFFICE', 'TrnOffice000', DEFAULT, 1, 'BranchGUID'

	EXEC [prcBranch_AddBRT] 'TRNTRANSFERVOUCHER', 'TrnTransferVoucher000', DEFAULT, 0, ''
	EXEC [prcBranch_AddBRT] 'TrnDeposit', 'TrnDeposit000', DEFAULT, 1, 'BranchGUID'
	EXEC [prcBranch_AddBRT] 'TrnCloseCashier', 'TrnCloseCashier000', DEFAULT, 1, 'BranchGUID'
	EXEC [prcBranch_AddBRT] 'TrnBranch', 'TrnBranch000', DEFAULT, 1, 'AmnBranchGUID' 
	
	EXEC [prcBranch_AddBRT] 'TRNSTATEMENT', 'TrnStatement000', DEFAULT, 0, ''

	EXEC [prcBranch_AddBRT] 'File', 'HosPFile000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'ANALYSISORDER', 'HosAnalysisOrder000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'RADIOGRAPHYORDER', 'HosRadioGraphyOrder000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'Manufacturing Plan', 'MNPS000', DEFAULT, 1 , 'BranchGUID', 'خطة التصنيع','Plan Schedule'
	EXEC [prcBranch_AddBRT] 'DP', 'DP000', DEFAULT, 1 , 'BranchGUID', 'مذكرة اهتلاك','Deprecation Card'
	EXEC [prcBranch_AddBRT] 'AX', 'AX000', DEFAULT, 1 , 'BranchGUID', 'بطاقة اصول','Add/Mnt/Deduct Assets'
	EXEC [prcBranch_AddBRT] 'assetExclude', 'assetExclude000', DEFAULT, 1 , 'BranchGUID', 'اخراج اصل','asset Exclude card'
	EXEC [prcBranch_AddBRT] 'RecostMaterials', 'RecostMaterials000', DEFAULT, 1 , 'BranchGUID', 'بطاقة اصل فرعية','Materials Cost Card'
	EXEC [prcBranch_AddBRT] 'AD', 'AD000', DEFAULT, 1 , 'BrGuid', 'بطاقة اصل فرعية','AD'
	--------------- New For Distributions
	-- EXEC [prcBranch_AddBRT] 'Distribution', 'Distributor000', 'fnDistGetDistributionTree', 0 , '', 'التوزيع','Distribution' 

	-- EXEC [prcBranch_AddBRT] 'DistVan', 'DistVan000', DEFAULT, 0, '', 'سيارات التوزيع', 'Dist Van Cars' 
	-- EXEC [prcBranch_AddBRT] 'DisGeneralTarget', 'DisGeneralTarget000', DEFAULT, 1, 'BranchGUID' 
	-- EXEC [prcBranch_AddBRT] 'DistCustMatTarget', 'DistCustMatTarget000', DEFAULT, 1, 'BranchGUID' 
	-- EXEC [prcBranch_AddBRT] 'DistCustTarget', 'DistCustTarget000', DEFAULT, 1, 'BranchGUID' 
	-- EXEC [prcBranch_AddBRT] 'DistDistributorTarget', 'DistDistributorTarget000', DEFAULT, 1, 'BranchGUID' 
	-- EXEC [prcBranch_AddBRT] 'DistCustClassesTarget', 'DistCustClassesTarget000', DEFAULT, 1, 'BranchGUID' 
	-- EXEC [prcBranch_AddBRT] 'DisTChTarget', 'DisTChTarget000', DEFAULT, 1, 'BranchGUID' 
	EXEC [prcBranch_AddBRT] 'DistHi', 'DistHi000', DEFAULT, 0, '', 'مجموعات التوزيع', 'Dist Hierarchy' 
	EXEC [prcBranch_AddBRT] 'DistSalesMan', 'DistSalesMan000', DEFAULT, 0, '', 'المندوبين', 'Dist Sales Man' 
	EXEC [prcBranch_AddBRT] 'DistPromotions', 'DistPromotions000', DEFAULT, 0, '', 'العروض', 'Dist Promotions' 
	EXEC [prcBranch_AddBRT] 'DISTPAID', 'DistPaid000', DEFAULT, 1, 'BranchGUID'
	EXEC [prcBranch_AddBRT] 'Distribution', 'Distributor000', 'fnDistGetDistributionTree', 0 , '', 'التوزيع','Distribution' 
	--------------- 

	--------------- New For POS
	EXEC [prcBranch_AddBRT] 'DiscountTypes', 'DiscountTypes000', 'fnGetDiscountTypesTree', 0 , '', 'أنماط الحسميات','Discount Types'
	EXEC [prcBranch_AddBRT] 'DiscountCard', 'DiscountCard000', 'fnGetDiscountCardTree', 0 , '', 'بطاقات الحسم','Discount Card'
	EXEC [prcBranch_AddBRT] 'DiscountCardStatus', 'DiscountCardStatus000', 'fnGetDiscountCardStatusTree', 0 , '', 'حالات بطاقات الحسم','Discount Card Status'
	EXEC [prcBranch_AddBRT] 'DiscountTypesCard', 'DiscountTypesCard000', 'fnGetDiscountTypesCardTree', 0 , '', 'بطاقات أنماط الحسم','Discount Types Card'
	
	-- EXEC [prcBranch_AddBRT] 'SpecialOffer', 'sm000', 'fnGetSpecialOffersTree', 0 , '', 'بطاقات العروض الخاصة',  'Special Offer Card'	
	EXEC [prcBranch_AddBRT] 'POSSpecialOffer', 'SpecialOffer000', 'fnGetPOSSpecialOffersTree', 0 , '', 'عروض نقاط البيع',  'POS Special Offer Card'	
	EXEC [prcBranch_AddBRT] 'SpecialOffers', 'SpecialOffers000', DEFAULT, 0 , '', 'بطاقات العروض الخاصة',  'Special Offer Card'	
	EXEC [prcBranch_AddBRT] 'AssetEmployee', 'AssetEmployee000', DEFAULT, 1, 'BranchGuid'
	EXEC [prcBranch_AddBRT] 'AssetPossessions', 'AssetPossessionsForm000', DEFAULT, 1, 'Branch'
	EXEC [prcBranch_AddBRT] 'PackingList', 'PackingLists000', DEFAULT, 1
	EXEC [prcBranch_AddBRT] 'LC', 'LC000', DEFAULT, 1, 'BranchGUID'
	EXEC [prcBranch_AddBRT] 'LCMain', 'LCMain000', DEFAULT, 0, '', 'الاعتماد المستندي الرئيسي', 'LCMain'
	-- POSOrder000
	EXEC [prcBranch_AddBRT] 'POSOrder', 'POSOrder000', DEFAULT, 1, 'BranchID'
	--POSPayRecieveTable000 
	EXEC [prcBranch_AddBRT] 'POSPayRecieveTable', 'POSPayRecieveTable000', DEFAULT, 1, 'BranchGUID'

	-- re-optimize views:
	EXEC [prcBranch_Optimize]
	EXEC [prcBranch_Optimize_LeftTables]  

#########################################################
#END