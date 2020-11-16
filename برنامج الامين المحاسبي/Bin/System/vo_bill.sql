#########################################################
CREATE VIEW vo_bill
AS 
	SELECT 
		--=================================
		-- Bill
		--=================================
		[bu].[Guid] AS [Bill_Guid],								-- [الفاتورة المميز],
		[bu].[Number] AS [Bill_Number], 						-- [الفاتورة الرقم],
		[bu].[Date] AS [Bill_Date], 							-- [الفاتورة التاريخ],
		DATEPART( YEAR, [bu].[Date]) AS [Bill_FullYear],		-- [الفاتورة سنة كاملة]
		CAST( DATEPART( YY, [bu].[Date]) AS VARCHAR)+ 'Q' + CAST(DATEPART( QUARTER, [bu].[Date]) AS VARCHAR)AS [Bill_YearQuarter],	-- [الفاتورة التاريخ-ربعي سنوي],
		'Q' + CAST(DATEPART( QUARTER, [bu].[Date]) AS VARCHAR) AS [Bill_Quarter],													-- [التاريخ - الربع],
		DATEPART( mm, [bu].[Date]) AS Bill_Month,																					-- [التاريخ - شهر],
		SUBSTRING( CONVERT(VARCHAR, [bu].[Date], 120), 3, 2) + SUBSTRING( CONVERT(VARCHAR, [bu].[Date], 120), 6, 2) AS [Bill_MonthYear], -- [التاريخ - سنة شهر],
		[bu].[Notes] AS [Bill_Notes], 							-- [الفاتورة البيان],
		[bu].[PayType] AS [Bill_PayType], 						-- [الفاتورة كيفية الدفع],
		-- 0: نقداً 	-- 1: آجل	-- 2: شيكات
		[bu].[FirstPay] AS [Bill_FirstPay], 					-- [الفاتورة الدفعة الأولى],
		[bu].[Profits] AS [Bill_Profits], 						-- [الفاتورة نسبة الربح],
		[bu].[IsPosted] AS [Bill_IsPosted], 					-- [الفاتورة مرحلة],
		-- 0: غير مرحلة	-- 1: مرحلة
		[bu].[Security] AS [Bill_Security], 					-- [الفاتورة درجة السرية],
		[bu].[Vendor] AS [Bill_Vendor], 						-- [الفاتورة الموزع],
		[bu].[SalesManPtr] AS [Bill_SalesMan], 					-- [الفاتورة البائع],
		[bu].[VAT] AS [Bill_Vat],								-- [الفاتورة الضريبة المضافة],
		-- مزيد
		[bu].[TextFld1] AS [Bill_Fld1], 						-- [الفاتورة حقل 1],
		[bu].[TextFld2] AS [Bill_Fld2], 						-- [الفاتورة حقل 2],
		[bu].[TextFld3] AS [Bill_Fld3], 						-- [الفاتورة حقل 3],
		[bu].[TextFld4] AS [Bill_Fld4], 						-- [الفاتورة حقل 4],
		
		[bu].[CustAccGUID] AS [Bill_CustAccGUID],
		(CASE [bu].[CustAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[CustAccGUID]), '') END) AS Bill_CustAccountDesc, 							-- [الفاتورة اسم حساب الزبون],
		(CASE [bu].[CustAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetParentAccountName( [bu].[CustAccGUID]), '') END) AS Bill_CustParentAccountDesc, 				-- [الفاتورة اسم أب حساب الزبون],
		(CASE [bu].[CustAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetGrandAccountName( [bu].[CustAccGUID]), '') END) AS Bill_CustGrandAccountDesc, 					-- [الفاتورة اسم جد حساب الزبون],
		(CASE [bu].[MatAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[MatAccGUID]), '') END) AS Bill_MatAccountDesc, 								-- [الفاتورة اسم حساب المواد],
		(CASE [bu].[ItemsDiscAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[ItemsDiscAccGUID]), '') END) AS Bill_ItemsDiscountAccountDesc, 			-- [الفاتورة اسم حساب حسم الأقلام],
		(CASE [bu].[BonusDiscAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[BonusDiscAccGUID]), '') END) AS Bill_BonusDiscountAccountDesc, 			-- [الفاتورة اسم حساب حسم الهدايا],	
		(CASE [bu].[FPayAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[FPayAccGUID]), '') END) AS Bill_FirstPayAccountDesc, 						-- [الفاتورة اسم حساب الدفعة الأولى],	
		(CASE [bu].[ItemsExtraAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[ItemsExtraAccGUID]), '')  END) AS Bill_ItemsExtraAccountDesc, 			-- [الفاتورة اسم حساب إضافات الأقلام],	
		(CASE [bu].[CostAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[CostAccGUID]), '') END) AS Bill_CostAccountDesc, 							-- [الفاتورة اسم حساب التكلفة],
		(CASE [bu].[StockAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[StockAccGUID]), '') END) AS Bill_StockAccountDesc, 							-- [الفاتورة اسم حساب المخزون],
		(CASE [bu].[VATAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[VATAccGUID]), '') END) AS Bill_VatAccountDesc, 								-- [الفاتورة اسم حساب Vat],
		(CASE [bu].[BonusAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[BonusAccGUID]), '') END) AS Bill_BonusAccountDesc, 							-- [الفاتورة اسم حساب الهدايا],
		(CASE [bu].[BonusContraAccGUID] WHEN 0x0 THEN '' ELSE ISNULL( dbo.fnGetAccountName( [bu].[BonusContraAccGUID]), '') END) AS Bill_BonusContraAccountDesc, 		-- [الفاتورة اسم حساب مقابل الهدايا],
		[bu].[Total] AS [Bill_Total],												-- [الفاتورة الإجمالي],
		[bu].[Total] 
		- (CASE [bt].[VATSystem] WHEN 2 THEN [bu].[Vat] ELSE 0 END) AS [Bill_Total_With_TTC], -- [الفاتورة الإجمالي بوجود TTC],
		[bu].[Total] - [bu].[TotalDisc] + [bu].[TotalExtra] 
		+(CASE WHEN ([bt].[VATSystem] = 1 OR (SELECT [dbo].[fnOption_GetBit]('AmnCfg_EnableGCCTaxSystem', DEFAULT)) = 1) THEN [bu].[Vat] ELSE 0 END) AS [Bill_NetTotal],-- [الفاتورة الصافي],
		[bu].[TotalDisc] AS [Bill_TotalDisc],										-- [الفاتورة إجمالي الحسميات],
		[bu].[TotalExtra] AS [Bill_TotalExtra],										-- [الفاتورة إجمالي الإضافات],
		[bu].[ItemsDisc] AS [Bill_ItemsDisc],										-- [الفاتورة مجموع حسميات الأقلام],
		[bu].[BonusDisc] AS [Bill_BonusDisc],										-- [الفاتورة مجموع حسميات الهدايا],
		[bu].[ItemsExtra] AS [Bill_ItemsExtra],										-- [الفاتورة مجموع إضافات الأقلام],

		(CASE [bt].[bIsInput] WHEN 1 THEN 1 ELSE -1 END) *
		[bu].[Total] AS [Bill_Total_s],												-- [الفاتورة الإجمالي باعتبار الاشارة],

		(CASE [bt].[bIsInput] WHEN 1 THEN 1 ELSE -1 END) *	
		([bu].[Total] 
		- (CASE [bt].[VATSystem] WHEN 2 THEN [bu].[Vat] ELSE 0 END)) AS [Bill_Total_With_TTC_s], -- [الفاتورة الإجمالي بوجود TTC باعتبار الاشارة],

		(CASE [bt].[bIsInput] WHEN 1 THEN 1 ELSE -1 END) *	
		([bu].[Total] - [bu].[TotalDisc] + [bu].[TotalExtra] 
		+(CASE [bt].[VATSystem] WHEN 1 THEN [bu].[Vat] ELSE 0 END)) AS [Bill_NetTotal_s],-- [الفاتورة الصافي باعتيار الاشارة],
		--=================================
		-- Customer	
		--=================================
		ISNULL( [bu].[CustGUID], 0x0) AS [Bill_CustomerGUID],
		ISNULL( [cu].[CustomerName], '') AS [Bill_CustomerName],					-- [الفاتورة اسم الزبون من بطاقة الزبون],
		ISNULL( [cu].[CustomerName], '') AS [Cust_Name],
		ISNULL( [cu].[Country], '') AS [Cust_Country],
		ISNULL( [cu].[City], '') AS [Cust_City],
		ISNULL( [cu].[Area], '') AS [Cust_Area],
		ISNULL( [cu].[Job], '') AS [Cust_Job],
		ISNULL( [cu].[JobCategory], '') AS [Cust_JobCategory],
		ISNULL( [cu].[UserFld1], '') AS [Cust_UserFld1],
		ISNULL( [cu].[UserFld2], '') AS [Cust_UserFld2],
		ISNULL( [cu].[UserFld3], '') AS [Cust_UserFld3],
		ISNULL( [cu].[UserFld4], '') AS [Cust_UserFld4],
		ISNULL( [cu].[Notes], '') AS [Cust_Notes],
		--=================================
		-- Store
		--=================================
		[bu].[StoreGUID] AS [Bill_StoreGUID],
		[st].[Name] AS [Bill_StoreName],											-- [الفاتورة اسم المستودع],
		[st].[LatinName] AS [Bill_StoreLatinName],									-- [الفاتورة اسم المستودع اللاتيني],
		[st].[Code] AS [Bill_StoreCode],											-- [الفاتورة رمز المستودع],
		--=================================
		-- Cost
		--=================================
		ISNULL( [bu].[CostGUID], 0x0) AS [Bill_CostGUID],
		ISNULL( [co].[Name], '') AS [Bill_CostName],								-- [الفاتورة اسم مركز الكلفة],
		ISNULL( [co].[LatinName], '') AS [Bill_CostLatinName],						-- [الفاتورة اسم مركز الكلفة اللاتيني],
		ISNULL( [co].[Code], '') AS [Bill_CostCode],								-- [الفاتورة رمز مركز الكلفة],
		--=================================
		-- User
		--=================================
		ISNULL( [bu].[UserGUID], 0x0) AS [Bill_UserGUID],
		ISNUll( [us].[LoginName], '') AS [Bill_UserLoginName],						-- [الفاتورة اسم المستخدم الذي قام بإضافتها],
		ISNUll( [us].[bAdmin], 0) AS [Bill_UserIsAdmin],							-- [الفاتورة صلاحيات المستخدم],
		--=================================
		-- Check Type
		--=================================
		ISNULL( [nt].[Name], '') AS [Bill_CheckTypeName],							-- [الفاتورة اسم نمط الورقة المالية],
		ISNULL( [nt].[LatinName], '') AS [Bill_CheckTypeLatinName],					-- [الفاتورة الاسم اللاتيني لنمط الورقة المالية],
		ISNULL( [nt].[Abbrev], '') AS [Bill_CheckTypeAbbrev],						-- [الفاتورة اختصار نمط الورقة المالية],
		ISNULL( [nt].[LatinAbbrev], '') AS [Bill_CheckTypeLatinAbbrev],				-- [الفاتورة الاختصار اللاتيني لنمط الورقة المالية],
		--=================================
		-- Branch
		--=================================
		ISNULL( [bu].[Branch], 0x0) AS [Bill_BranchGUID],
		ISNULL( [br].[Code], '') AS [Bill_BranchCode],								-- [الفاتورة رمز الفرع],
		ISNULL( [br].[Name], '') AS [Bill_BranchName],								-- [الفاتورة اسم الفرع],
		ISNULL( [br].[LatinName], '') AS [Bill_BranchLatinName],					-- [الفاتورة الاسم اللاتيني الفرع],
		ISNULL( [br].[Prefix], '') AS [Bill_BranchPrefix],							-- [الفاتورة اختصار الفرع],
		--=================================
		-- Currency
		--=================================
		[bu].[CurrencyGUID] AS [Bill_CurrencyGUID],
		[my].[Name] AS [Bill_CurrencyName],											-- [الفاتورة اسم العملة],
		[my].[Code] AS [Bill_CurrencyCode],											-- [الفاتورة رمز العملة],
		[my].[LatinName] AS [Bill_CurrencyLatinName],								-- [الفاتورة اسم العملة اللاتيني],
		[bu].[CurrencyVal] AS [Bill_CurrencyVal],									-- [الفاتورة سعر التعادل],
		--=================================
		--	Bill type
		--=================================
		[bu].[TypeGUID] AS [Bill_TypeGUID],
		[bt].[Type] AS [BillType_Type], 											-- [نمط الفاتورة نوع],
		-- 1: عادي
		-- 2: قياسي
		[bt].[SortNum] AS [BillType_SortNum],										-- [نمط الفاتورة ترتيب],
		[bt].[BillGroup] AS [BillType_BillGroup],									-- 
		[bt].[BillType] AS  [BillType_BillType],									-- [نمط الفاتورة النمط],
		-- 0: شراء
		-- 1: مبيع
		-- 2: مرتجع شراء
		-- 3: مرتجع مبيع
		-- 4: إدخال
		-- 5: إخراج
		[bt].[Name] AS [BillType_Name], 											-- [نمط الفاتورة الاسم],
		[bt].[LatinName] AS [BillType_LatinName], 									-- [نمط الفاتورة الاسم اللاتيني],
		[bt].[Abbrev] AS [BillType_Abbrev], 										-- [نمط الفاتورة الاختصار],
		[bt].[LatinAbbrev] AS [BillType_LatinAbbrev], 								-- [نمط الفاتورة الاختصار اللاتيني],
		[bt].[DefPrice] AS [BillType_DefPrice], 									-- [نمط الفاتورة السعر الافتراضي],
		-- 1: بدون
		-- 2: تكلفة
		-- 4: الجملة
		-- 8: نصف الجملة
		-- 16: التصدير
		-- 32: الموزع
		-- 64: المفرق
		-- 128: المستهلك
		-- 512: آخر شراء
		-- 1024: آخر مبيع زبون
		-- 2048: سعر بطاقة الزبون
		[bt].[DefCostPrice] AS [BillType_DefCostPrice], 							-- [نمط الفاتورة سعر التكلفة],
		[bt].[bIsInput] AS [BillType_IsInput],										-- [نمط الفاتورة إدخال],
		-- 0: إخراج
		-- 1: إدخال
		[bt].[VATSystem] AS [BillType_VATSystem], 									-- [نمط الفاتورة نظام الـ VAT],
		-- 0: عادية
		-- 1: VAT
		-- 2: TTC
		[bt].[branchMask] AS [BillType_BranchMask]									-- [نمط الفاتورة الفروع],
	FROM 
		[bu000] AS [bu]
		INNER JOIN [bt000] [bt] ON [bu].[TypeGUID] = [bt].[GUID]
		INNER JOIN [st000] [st] ON [bu].[StoreGUID] = [st].[GUID]
		INNER JOIN [my000] [my] ON [bu].[CurrencyGUID] = [my].[GUID]
		LEFT JOIN [br000] [br] ON [bu].[Branch] = [br].[GUID]
		LEFT JOIN [vexCu] [cu] ON [bu].[CustGUID] = [cu].[GUID]
		LEFT JOIN [us000] [us] ON [bu].[UserGUID] = [us].[GUID]
		LEFT JOIN [nt000] [nt] ON [bu].[CheckTypeGUID] = [nt].[GUID]
		LEFT JOIN [co000] [co] ON [bu].[CostGUID] = [co].[GUID]

#########################################################
#END
