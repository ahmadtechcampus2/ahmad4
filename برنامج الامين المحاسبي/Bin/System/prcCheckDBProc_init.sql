######################################################### 
create proc prcCheckDBProc_init
as
	

	-- truncate table CheckDBProc

	-- root:
	-- exec prcCheckDBProc_add N'0000', N'', N'', N'check database', N''

	-- accounts
	exec [prcCheckDBProc_add] N'0100', N'الحسابات',N'', N'Accounts', N'check database accounts'
	exec [prcCheckDBProc_add] N'0101', N'علاقات الحساب الرئيسي والفرعي',N'', N'Sub and Main Account Relationships', N'', N'prcCheckDB_ac_Links', 0
	exec [prcCheckDBProc_add] N'0102', N'مكونات الحسابات التجميعية و التوزيعية',N'', N'Collective and Ditributive Components', N'', N'prcCheckDB_ac_ci', 0
	exec [prcCheckDBProc_add] N'0103', N'صحة أنماط الحسابات',N'', N'Valid account types', N'', N'prcCheckDB_ac_Types', 0
	exec [prcCheckDBProc_add] N'0104', N'استخدام الحساب',N'', N'Usability', N'', N'prcCheckDB_ac_UseFlag', 0
	exec [prcCheckDBProc_add] N'0105', N'عدد الحسابات الفرعية',N'', N'Number of Sons', N'', N'prcCheckDB_ac_NSons', 0
	exec [prcCheckDBProc_add] N'0106', N'صحة فرع الحساب الأب بفرع الحساب الأبن',N'', N'Valid Accounts Branches Links', N'', N'prcCheckDB_ac_br_Links', 0
	exec [prcCheckDBProc_add] N'0107', N'صحة حقول بطاقات الحسابات',N'', N'Valid Accounts Fields', N'', N'prcCheckDB_ac_Fields', 0
	
	-- branches:
	exec [prcCheckDBProc_add] N'0200', N'الأفرع',N'', N'Branches', N'check database Branches'
	exec [prcCheckDBProc_add] N'0201', N'التحقق من صحة حقول الأفرع',N'', N'Valid Branches in Branch Related Tables', N'', N'prcCheckDB_br', 0
	
	-- groups:
	exec [prcCheckDBProc_add] N'0300', N'مجموعات المواد',N'', N'Materials Groups', N'check database Materials Groups'
	exec [prcCheckDBProc_add] N'0301', N'علاقات المجموعة الرئيسية والفرعية',N'', N'Sub and Main Group Relationships', N'', N'prcCheckDB_gr_Links', 0
	exec [prcCheckDBProc_add] N'0302', N'الوحدات في بطاقات المواد',N'', N'Valid Units', N'', N'prcCheckDB_mt_Units', 0
	exec [prcCheckDBProc_add] N'0303', N'صحة حقول بطاقات المواد',N'', N'Valid Materials Fields', N'', N'prcCheckDB_mt_Fields', 0
	exec [prcCheckDBProc_add] N'0304', N'تكرار الرمز في بطاقات المواد',N'', N'Materials Code Repeated', N'', N'prcCheckDB_mt_RepeatedCode', 0

	-- stores:
	exec [prcCheckDBProc_add] N'0400', N'المستودعات',N'', N'Stores', N'check database Stores'
	exec [prcCheckDBProc_add] N'0401', N'علاقات المستودع الرئيسي والفرعي',N'', N'Sub and Main Warehouse Relationships', N'', N'prcCheckDB_st_Links', 0

	-- bills
	exec [prcCheckDBProc_add] N'0500', N'الفواتير',N'', N'Bills', N'check database bills'
	exec [prcCheckDBProc_add] N'0501', N'أنماط الفواتير',N'', N'Bills Templates Defaults', N'', N'prcCheckDB_bt_Defaults', 0
	exec [prcCheckDBProc_add] N'0502', N'زبائن صحيحة',N'', N'Valid Customers', N'', N'prcCheckDB_bu_Custs', 0
	exec [prcCheckDBProc_add] N'0503', N'أخطاء كميات المواد في الفواتير',N'', N'Quantity Error In Bill Items', N'', N'prcCheckDB_bi_QtyMinus', 0
	exec [prcCheckDBProc_add] N'0504', N'مجاميع الفواتير',N'', N'Bills Sums', N'', N'prcCheckDB_bu_Sums', 0
	exec [prcCheckDBProc_add] N'0505', N'فواتير بلا سندات',N'', N'Bills without Entries', N'', N'prcCheckDB_bu_IsPosted', 0
	exec [prcCheckDBProc_add] N'0506', N'فواتير بلا أقلام',N'', N'Bills Without Items', N'', N'prcCheckDB_bu_NoBi', 0
	exec [prcCheckDBProc_add] N'0507', N'أقلام بلا فواتير',N'', N'Items without Bills', N'', N'prcCheckDB_bi_NoBu', 0
	exec [prcCheckDBProc_add] N'0508', N'القيم الخالية في الفواتير',N'', N'Nulls in Bills', N'', N'prcCheckDB_bu_Nulls', 0
	exec [prcCheckDBProc_add] N'0509', N'القيم الخالية في أقلام الفواتير',N'', N'Nulls in Bills items', N'', N'prcCheckDB_bi_Nulls', 0
	exec [prcCheckDBProc_add] N'0510', N'مستودعات الفواتير',N'', N'Valid Bills Stores', N'', N'prcCheckDB_bu_Stores', 0
	exec [prcCheckDBProc_add] N'0511', N'مستودعات أقلام الفواتير',N'', N'Valid Bills Item Stores', N'', N'prcCheckDB_bi_Stores', 0
	exec [prcCheckDBProc_add] N'0512', N'مواد الفواتير',N'', N'Valid Bills Items Materials', N'', N'prcCheckDB_bi_Mats', 0
	exec [prcCheckDBProc_add] N'0513', N'الوحدات المستخدمة',N'', N'Valid Bills Items Units', N'', N'prcCheckDB_bi_Units', 0
	exec [prcCheckDBProc_add] N'0514', N'عملات الفواتير',N'', N'Valid Bills Currencies and Currencies Values', N'', N'prcCheckDB_bu_Currencies', 0
	exec [prcCheckDBProc_add] N'0515', N'عملات أقلام الفواتير',N'', N'Valid Bills Items Currencies and Currency Values', N'', N'prcCheckDB_bi_Currencies', 0
	exec [prcCheckDBProc_add] N'0516', N'حسابات المواد والمجموعات والمستخدمين',N'','Materials, groups and user Accounts', N'', N'prcCheckDB_mt_Acc', 0
	exec [prcCheckDBProc_add] N'0517', N'فحص ارتباط إحدى فاتورتي المناقلة',N'','Missing Transfer Bill Check',N'','prcCheckDB_Missing_Transfer_Bill', 0
	exec [prcCheckDBProc_add] N'0518', N'ارتباط دفعات الفواتير',N'', N'Valid related bill payments', N'', N'prcCheckDB_bu_bp', 0
	exec [prcCheckDBProc_add] N'0519', N'التحقق من انماط الفواتير',N'', N'Check billing patterns', N'', N'prcFixSortNumColIssue', 0
	
	-- entries
	exec [prcCheckDBProc_add] N'0600', N'السندات',N'', N'Entries', N'check database Entries'
	exec [prcCheckDBProc_add] N'0601', N'أنماط السندات',N'', N'Entries Templates Defaults', N'', N'prcCheckDB_et_Defaults', 0
	exec [prcCheckDBProc_add] N'0602', N'الأنماط المحدد في السندات',N'', N'Valid Entries Types', N'', N'prcCheckDB_ce_typeGuid', 0
	exec [prcCheckDBProc_add] N'0603', N'صحة مؤشر ترحيل السند',N'', N'Valid Posting Flag', N'', N'prcCheckDB_ce_IsPosted', 0
	exec [prcCheckDBProc_add] N'0604', N'عملات السندات',N'', N'Valid Currencies and Currencies Values', N'', N'prcCheckDB_ce_Currencies', 0
	exec [prcCheckDBProc_add] N'0605', N'عملات أقلام السندات',N'', N'Valid Entries Items Currencies and Currencies Values', N'', N'prcCheckDB_en_Currencies', 0
	exec [prcCheckDBProc_add] N'0606', N'مجاميع السندات',N'', N'Entries Sums', N'', N'prcCheckDB_ce_Sums', 0
	exec [prcCheckDBProc_add] N'0607', N'حسابات السندات',N'', N'Valid Entries Items Accounts', N'', N'prcCheckDB_en_Accounts', 0
	exec [prcCheckDBProc_add] N'0608', N'مراكز الكلفة في السندات',N'', N'Valid Entries Items Cost Center', N'', N'prcCheckDB_en_CostCenter', 0
	
	exec [prcCheckDBProc_add] N'0609', N'سندات بلا أقلام',N'', N'Enties without Items', N'', N'prcCheckDB_ce_NoEn', 0
	exec [prcCheckDBProc_add] N'0610', N'أقلام سندات بلا سندات',N'', N'Entries Items without Entries', N'', N'prcCheckDB_en_NoCe', 0
	exec [prcCheckDBProc_add] N'0611', N'قيم خالية في السندات',N'', N'Nulls in Entries', N'', N'prcCheckDB_ce_Nulls', 0
	exec [prcCheckDBProc_add] N'0612', N'روابط السندات',N'', N'Valid Entries Relations', N'', N'prcCheckDB_er', 0
	exec [prcCheckDBProc_add] N'0613', N'تكرار أرقام السندات',N'', N'Duplicate Numbers', N'', N'prcCheckDB_py_duplicateNumbers', 0
	exec [prcCheckDBProc_add] N'0614', N'تعيين الحساب المقابل',N'', N'ContraAccount Assignment', N'', N'prcEntry_assignContraAcc', 0
	exec [prcCheckDBProc_add] N'0615', N'سندات أفرع تضم حسابات أفرع مختلفة',N'', N'Deferant between Account Branch and ce Branch', N'', N'prcCheckDB_ce_br_ac', 0
	exec [prcCheckDBProc_add] N'0616', N'الزبائن في أقلام السندات',N'', N'Valid Entries Items Customers', N'', N'prcCheckDB_en_Customers', 0

	-- notes:
	exec [prcCheckDBProc_add] N'0700', N'الأوراق المالية',N'', N'Notes', N'check database Notes'
	exec [prcCheckDBProc_add] N'0701', N'أنماط الأوراق المالية',N'', N'Notes Templates Defaults', N'', N'prcCheckDB_nt_Defaults', 0
	exec [prcCheckDBProc_add] N'0701', N'حسابات الأوراق',N'', N'Notes Accounts', N'', N'prcCheckDB_ch_Accounts', 0

	-- currencies:
	exec [prcCheckDBProc_add] N'0800', N'العملات',N'', N'Currencies', N'check database Currencies'
	exec [prcCheckDBProc_add] N'0801', N'فحص بطاقات العملات',N'', N'Currencies Cards', N'', N'prcCheckDB_my', 0

	-- Assets:
	exec [prcCheckDBProc_add] N'0900', N'الأصول الثابتة',N'', N'Assets', N'check database Assets'
	exec [prcCheckDBProc_add] N'0901', N'أصول فرعية غير مرتبطة برقم تسلسلي',N'', N'Valid Links between Asset Detail and serial Number', N'', N'prcCheckDB_as_ad', 0

	-- Tables Fields:
	exec [prcCheckDBProc_add] N'1000', N'بيانات الحقول',N'', N'data Fields', N'check database Fields'
	exec [prcCheckDBProc_add] N'1001', N'فحص القيم الافتراضية',N'', N'Defaults Values', N'', N'prcCheckDB_Flds_DefaultValue', 0
	exec [prcCheckDBProc_add] N'1002', N'فحص القيم الخالية',N'', N'Null Values', N'', N'prcCheckDB_Flds_NullValue', 0
	
	-- GCC check:
	exec [prcCheckDBProc_add] N'1100', N'نظام ضرائب الخليج',N'', N'GCC Tax System', N'check GCC Tax System settings', N'', 1 /*GCC*/
	exec [prcCheckDBProc_add] N'1101', N'تكرار إعدادات الضرائب',N'', N'Duplicate GCC Settings', N'', N'prcCheckDB_GCC_DuplicateSettings', 1
	exec [prcCheckDBProc_add] N'1102', N'تكرار الضرائب في بطاقات المواد',N'', N'Duplicate GCC Materials Tax', N'', N'prcCheckDB_GCC_DuplicateMaterialsTax', 1
	exec [prcCheckDBProc_add] N'1103', N'تكرار الضرائب في بطاقات الزبائن',N'', N'Duplicate GCC Customers Tax', N'', N'prcCheckDB_GCC_DuplicateCustomersTax', 1

#########################################################
#end
