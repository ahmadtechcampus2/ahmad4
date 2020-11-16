#########################################################
CREATE VIEW vo_bill_Item
AS 
	SELECT 
		--=================================
		--	Materials
		--=================================
		-- أساسيات
		[mt].[Code] AS [Material_Code],						-- [المادة الرمز],
		[mt].[Name]	AS [Material_Name],						-- [المادة الاسم],
		[mt].[LatinName] AS [Material_LatinName],			-- [المادة الاسم اللاتيني],
		[mt].[Security] AS [Material_Security],				-- [المادة درجة السرية],
		[mt].[Type] AS [Material_Type],						-- [المادة النوع],
		[mt].[branchMask] AS [Material_BranchMask],			-- [المادة الفروع],
		-- رمز الباركود
		[mt].[BarCode] AS [Material_BarCode1],				-- [المادة رمز الباركود بالوحدة 1],
		[mt].[BarCode2] AS [Material_BarCode2],				-- [المادة رمز الباركود بالوحدة 2],
		[mt].[BarCode3] AS [Material_BarCode3],				-- [المادة رمز الباركود بالوحدة 3],
		-- الوحدات
		[mt].[Unity] AS [Material_Unit1Name],				-- [المادة اسم الوحدة 1],
		[mt].[Unit2] AS [Material_Unit2Name],				-- [المادة اسم الوحدة 2],
		[mt].[Unit3] AS [Material_Unit3Name],				-- [المادة اسم الوحدة 3],
		[mt].[Unit2Fact] AS [Material_Unit2Fact],			-- [المادة عامل تحويل الوحدة 2],
		[mt].[Unit3Fact] AS [Material_Unit3Fact],			-- [المادة عامل تحويل الوحدة 3],
		[mt].[DefUnit] AS [Material_DefUnit],				-- [المادة الوحدة الافتراضية], 	-- 1, 2, 3
		[mt].[Unit2FactFlag] AS [Material_Unit2FactFlag],	-- [المادة الوحدة 2 غير مترابطة],
		[mt].[Unit3FactFlag] AS [Material_Unit3FactFlag],	-- [المادة الوحدة 3 غير مترابطة],
		-- مواصفات المادة
		[mt].[Spec] AS [Material_Spec],						-- [المادة المواصفات],
		[mt].[Origin] AS [Material_Origin],					-- [المادة المصدر],
		[mt].[Company] AS [Material_Company],				-- [المادة الشركة المصنعة],
		[mt].[Color] AS [Material_Color],					-- [المادة اللون],
		[mt].[Provenance] AS [Material_Provenance],			-- [المادة بلد المنشأ],
		[mt].[Pos] AS [Material_Pos],						-- [المادة مكان التواجد],
		[mt].[Dim] AS [Material_Dim],						-- [المادة القياس],
		[mt].[Quality] AS [Material_Quality],				-- [المادة النوعية],
		[mt].[Model] AS [Material_Model],					-- [المادة الطراز],
		-- أسعار المادة
		[mt].[Whole] AS [Material_Price_Whole],				-- [المادة سعر الجملة بالوحدة 1],
		[mt].[Half] AS [Material_Price_Half],				-- [المادة سعر نصف الجملة بالوحدة 1],
		[mt].[Retail] AS [Material_Price_Retail],			-- [المادة سعر المفرق بالوحدة 1],
		[mt].[EndUser] AS [Material_Price_EndUser],			-- [المادة سعر المستهلك بالوحدة 1],
		[mt].[Export] AS [Material_Price_Export],			-- [المادة سعر التصدير بالوحدة 1],
		[mt].[Vendor] AS [Material_Price_Vendor],			-- [المادة سعر الموزع بالوحدة 1],
		[mt].[MaxPrice] AS [Material_Price_MaxPrice],		-- [المادة سعر الشراء الأعظمي بالوحدة 1],
		[mt].[AvgPrice] AS [Material_Price_AvgPrice],		-- [المادة سعر الشراء الوسطي بالوحدة 1],
		[mt].[LastPrice] AS [Material_Price_LastPrice],		-- [المادة آخر سعر شراء بالوحدة 1],
		[mt].[Whole2] AS [Material_Whole2],					-- [المادة سعر الجملة بالوحدة 2],
		[mt].[Half2] AS [Material_Half2],					-- [المادة سعر نصف الجملة بالوحدة 2],
		[mt].[Retail2] AS [Material_Retail2],				-- [المادة سعر المفرق بالوحدة 2],
		[mt].[EndUser2] AS [Material_EndUser2],				-- [المادة سعر المستهلك بالوحدة 2],
		[mt].[Export2] AS [Material_Export2],				-- [المادة سعر التصدير بالوحدة 2],
		[mt].[Vendor2] AS [Material_Vendor2],				-- [المادة سعر الموزع بالوحدة 2],
		[mt].[MaxPrice2] AS [Material_MaxPrice2],			-- [المادة سعر الشراء الأعظمي بالوحدة 2],
		[mt].[LastPrice2] AS [Material_LastPrice2],			-- [المادة آخر سعر شراء بالوحدة 2],
		[mt].[Whole3] AS [Material_Whole3],					-- [المادة سعر الجملة بالوحدة 3],
		[mt].[Half3] AS [Material_Half3],					-- [المادة سعر نصف الجملة بالوحدة 3],
		[mt].[Retail3] AS [Material_Retail3],				-- [المادة سعر المفرق بالوحدة 3],
		[mt].[EndUser3] AS [Material_EndUser3],				-- [المادة سعر المستهلك بالوحدة 3],
		[mt].[Export3] AS [Material_Export3],				-- [المادة سعر التصدير بالوحدة 3],
		[mt].[Vendor3] AS [Material_Vendor3],				-- [المادة سعر الموزع بالوحدة 3],
		[mt].[MaxPrice3] AS [Material_MaxPrice3],			-- [المادة سعر الشراء الأعظمي بالوحدة 3],
		[mt].[LastPrice3] AS [Material_LastPrice3],			-- [المادة آخر سعر شراء بالوحدة 3],
		[mt].[PriceType] AS [Material_PriceType],			-- [المادة سياسة التسعير],
		[mt].[VAT] AS [Material_VAT],						-- [المادة ضريبة القيمة المضافة],		-- نسبة 
		-- 15: حقيقي	-- 120: الأعظمي	-- 121: الوسطي	-- 122: آخر شراء	-- 128: افتراضي
		-- الهدايا
		[mt].[BonusOne] AS [Material_BonusOne],				-- [المادة كمية الهدية المستحقة لكل],
		[mt].[Bonus] AS [Material_Bonus],					-- [المادة الكيمة المستحقة للهدية],
		-- خيارات
		[mt].[ExpireFlag] AS [Material_ExpireFlag],			-- [المادة فرض تاريخ الصلاحية],
		[mt].[ProductionFlag] AS [Material_ProductionFlag],	-- [المادة فرض تاريخ الانتاج],
		[mt].[SNFlag] AS [Material_SNFlag],					-- [المادة فرض الأرقام التسلسلية],
		[mt].[ForceInSN] AS [Material_ForceInSN],			-- [المادة فرض الأرقام التسلسلية عند الإدخال],
		[mt].[ForceOutSN] AS [Material_ForceOutSN],			-- [المادة فرض الأرقام التسلسلية عند الإخراج],
		[mt].[Assemble] AS [Material_Assemble],				-- [المادة تجميعية],
		[mt].[bHide] AS [Material_Hide],					-- [المادة إخفاء في نافذة البحث],
		-- الحدود
		[mt].[High] AS [Material_High],						-- [المادة الحد الأعلى],
		[mt].[Low] AS [Material_Low],						-- [المادة الحد الأدنى],
		[mt].[OrderLimit] AS [Material_OrderLimit],			-- [المادة حد الطلب],
		-- معلومات ديناميكية
		[mt].[Qty] AS [Material_Qty],						-- [المادة الكمية],
		[mt].[UseFlag] AS [Material_UseFlag],				-- [المادة مستخدمة],
		[mt].[LastPriceDate] AS [Material_LastPriceDate],	-- [المادة تاريخ آخر شراء],
		-- غير مستخدمة
		[mt].[CodedCode] AS [Material_CodedCode],			-- غير مستخدم
		[mt].[Flag] AS [Material_Flag],						-- غير مستخدم
		--=================================
		-- Group
		--=================================
		[gr].[Code] AS [Group_Code],						-- [المجموعة الرمز],
		[gr].[Name] AS [Group_Name],						-- [المجموعة الاسم],
		[gr].[LatinName] AS [Group_LatinName],				-- [المجموعة الاسم اللاتيني],
		--=================================
		--	Bill item
		--=================================
		[bi].[ParentGUID] AS [BillItem_Parent],				-- [قلم الفاتورة مميز الفاتورة],
		[bi].[Number] AS [BillItem_Number],					-- [قلم الفاتورة الترتيب],
		[bi].[Qty] AS [BillItem_Qty1], 						-- [قلم الفاتورة الكمية بالوحدة 1],
		[bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) AS [BillItem_Qty2],	-- [قلم الفاتورة الكمية بالوحدة 2],
		[bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) AS [BillItem_Qty3],	-- [قلم الفاتورة الكمية بالوحدة 3],
		[bi].[Unity] AS [BillItem_Unity],					-- [قلم الفاتورة الوحدة المستخدمة],	-- 1, 2, 3
		(CASE [bi].[Unity]
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty2] WHEN 0 THEN 1 ELSE [bi].[Qty2] END) END) 
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty3] WHEN 0 THEN 1 ELSE [bi].[Qty3] END) END) 
				ELSE 1 
		END) AS [BillItem_UnitFact], 					-- [قلم الفاتورة عامل تحويل الوحدة المستخدمة],
		[bi].[Price] AS [BillItem_Price],				-- [قلم الفاتورة السعر الفردي للوحدة المستخدمة],
		[bi].[Price] / 
		(CASE [bi].[Unity] 
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty2] WHEN 0 THEN 1 ELSE [bi].[Qty2] END) END) 
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty3] WHEN 0 THEN 1 ELSE [bi].[Qty3] END) END) 
				ELSE 1 
		END) AS [BillItem_UnitPrice],					-- [قلم الفاتورة السعر الفردي للوحدة 1],	-- بدون حسميات أو إضافات
		[bi].[BonusQnt] AS [BillItem_BonusQnt], 		-- [قلم الفاتورة كمية الهدايا بالوحدة 1],
		[bi].[BonusQnt] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) AS [BillItem_BonusQnt2],	-- [قلم الفاتورة كمية الهدايا بالوحدة 2],
		[bi].[BonusQnt] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) AS [BillItem_BonusQnt3],	-- [قلم الفاتورة كمية الهدايا بالوحدة 3],
		[bi].[Discount] AS [BillItem_Discount],			-- [قلم الفاتورة حسم القلم],
		[bi].[BonusDisc] AS [BillItem_BonusDisc],		-- [قلم الفاتورة حسم الهدايا],
		[bi].[Extra] AS [BillItem_Extra],				-- [قلم الفاتورة إضافة القلم],
		[bi].[Notes] AS [BillItem_Notes],				-- [قلم الفاتورة البيان],
		[bi].[Profits] AS [BillItem_Profits],			-- [قلم الفاتورة نسبة الربح],
		[bi].[ClassPtr] AS [BillItem_Class],			-- [قلم الفاتورة الفئة],
		[bi].[ExpireDate] AS [BillItem_ExpireDate],		-- [قلم الفاتورة تاريخ الصلاحية],
		[bi].[ProductionDate] AS [BillItem_ProductionDate],	-- [قلم الفاتورة تاريخ الانتاج],	
		[bi].[Length] AS [BillItem_Length],				-- [قلم الفاتورة تاريخ الطول],	
		[bi].[Width] AS [BillItem_Width],				-- [قلم الفاتورة تاريخ العرض],	
		[bi].[Height] AS [BillItem_Height],				-- [قلم الفاتورة تاريخ الارتفاع],	
		[bi].[VAT] AS [BillItem_VAT],					-- [قلم الفاتورة الضريبة الإجمالية على القلم],	
		[bi].[VATRatio] AS [BillItem_VATRatio],			-- [قلم الفاتورة نسبة الضريبة],	
		[bi].[SOType] AS [BillItem_SOType],				-- [قلم الفاتورة نوع العرض الخاص],	-- 0: Master -- 1: Details
		--=================================
		-- Store int bill items 
		--=================================
		[st].[Name] AS [BillItem_StoreName],			-- [قلم الفاتورة اسم المستودع],
		[st].[LatinName] AS [BillItem_StoreLatinName],	-- [قلم الفاتورة الاسم اللاتيني للمستودع],
		[st].[Code] AS [BillItem_StoreCode],			-- [قلم الفاتورة رمز المستودع],
		--=================================
		-- Cost
		--=================================
		ISNULL( [co].[Name], '') AS [BillItem_CostName],			-- [قلم الفاتورة اسم مركز الكلفة],
		ISNULL( [co].[LatinName], '') AS [BillItem_CostLatinName],	-- [قلم الفاتورة الاسم اللاتيني لمركز الكلفة],
		ISNULL( [co].[Code], '') AS [BillItem_CostCode],			-- [قلم الفاتورة رمز مركز الكلفة],
		--=================================
		-- Spical offers
		--=================================
		ISNULL( [sm].[Notes], '') AS [SpicalOfferName],	-- [قلم الفاتورة اسم العرض الخاص المستخدم],
		--=================================
		-- Currency int bill items 
		--=================================
		[my].[Name] AS [BillItem_CurrencyName],				-- [قلم الفاتورة اسم العملة],
		[my].[Code] AS [BillItem_CurrencyCode],				-- [قلم الفاتورة رمز العملة],
		[my].[LatinName] AS [BillItem_CurrencyLatinName],	-- [قلم الفاتورة الاسم اللاتيني للعملة],
		[bi].[CurrencyVal] AS [BillItem_CurrencyVal],		-- [قلم الفاتورة تعادل العملة],
		
		(CASE [bi].[unity] 
			WHEN 2 THEN [bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
			WHEN 3 THEN [bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
			ELSE [bi].[Qty] END) AS [BillItem_CurrentQty],	-- الكمية بوحدة الحركة

		(CASE [bi].[unity] 
			WHEN 2 THEN [mt].[Unit2]
			WHEN 3 THEN [mt].[Unit3]
			ELSE [mt].[Unity] END) AS [BillItem_CurrentUnit]	-- وحدة الحركة
		
	FROM 
		[bi000] [bi]
		INNER JOIN [mt000] [mt] ON [bi].[MatGUID] = [mt].[GUID]
		INNER JOIN [gr000] [gr] ON [mt].[GroupGUID] = [gr].[GUID]
		INNER JOIN [st000] [st] ON [bi].[StoreGUID] = [st].[GUID]
		INNER JOIN [my000] [my] ON [bi].[CurrencyGUID] = [my].[GUID]
		LEFT JOIN [co000] [co] ON [bi].[CostGUID] = [co].[GUID]
		LEFT JOIN [sm000] [sm] ON [bi].[SOGuid] = [sm].[GUID]

#########################################################
CREATE VIEW vo_bill_Item_sn
AS 
	SELECT 
		--=================================
		--	Materials
		--=================================
		-- أساسيات
		[mt].[Code] AS [Material_Code],						-- [المادة الرمز],
		[mt].[Name]	AS [Material_Name],						-- [المادة الاسم],
		[mt].[LatinName] AS [Material_LatinName],			-- [المادة الاسم اللاتيني],
		[mt].[Security] AS [Material_Security],				-- [المادة درجة السرية],
		[mt].[Type] AS [Material_Type],						-- [المادة النوع],
		[mt].[branchMask] AS [Material_BranchMask],			-- [المادة الفروع],
		-- رمز الباركود
		[mt].[BarCode] AS [Material_BarCode1],				-- [المادة رمز الباركود بالوحدة 1],
		[mt].[BarCode2] AS [Material_BarCode2],				-- [المادة رمز الباركود بالوحدة 2],
		[mt].[BarCode3] AS [Material_BarCode3],				-- [المادة رمز الباركود بالوحدة 3],
		-- الوحدات
		[mt].[Unity] AS [Material_Unit1Name],				-- [المادة اسم الوحدة 1],
		[mt].[Unit2] AS [Material_Unit2Name],				-- [المادة اسم الوحدة 2],
		[mt].[Unit3] AS [Material_Unit3Name],				-- [المادة اسم الوحدة 3],
		[mt].[Unit2Fact] AS [Material_Unit2Fact],			-- [المادة عامل تحويل الوحدة 2],
		[mt].[Unit3Fact] AS [Material_Unit3Fact],			-- [المادة عامل تحويل الوحدة 3],
		[mt].[DefUnit] AS [Material_DefUnit],				-- [المادة الوحدة الافتراضية], 	-- 1, 2, 3
		[mt].[Unit2FactFlag] AS [Material_Unit2FactFlag],	-- [المادة الوحدة 2 غير مترابطة],
		[mt].[Unit3FactFlag] AS [Material_Unit3FactFlag],	-- [المادة الوحدة 3 غير مترابطة],
		-- مواصفات المادة
		[mt].[Spec] AS [Material_Spec],						-- [المادة المواصفات],
		[mt].[Origin] AS [Material_Origin],					-- [المادة المصدر],
		[mt].[Company] AS [Material_Company],				-- [المادة الشركة المصنعة],
		[mt].[Color] AS [Material_Color],					-- [المادة اللون],
		[mt].[Provenance] AS [Material_Provenance],			-- [المادة بلد المنشأ],
		[mt].[Pos] AS [Material_Pos],						-- [المادة مكان التواجد],
		[mt].[Dim] AS [Material_Dim],						-- [المادة القياس],
		[mt].[Quality] AS [Material_Quality],				-- [المادة النوعية],
		[mt].[Model] AS [Material_Model],					-- [المادة الطراز],
		-- أسعار المادة
		[mt].[Whole] AS [Material_Price_Whole],				-- [المادة سعر الجملة بالوحدة 1],
		[mt].[Half] AS [Material_Price_Half],				-- [المادة سعر نصف الجملة بالوحدة 1],
		[mt].[Retail] AS [Material_Price_Retail],			-- [المادة سعر المفرق بالوحدة 1],
		[mt].[EndUser] AS [Material_Price_EndUser],			-- [المادة سعر المستهلك بالوحدة 1],
		[mt].[Export] AS [Material_Price_Export],			-- [المادة سعر التصدير بالوحدة 1],
		[mt].[Vendor] AS [Material_Price_Vendor],			-- [المادة سعر الموزع بالوحدة 1],
		[mt].[MaxPrice] AS [Material_Price_MaxPrice],		-- [المادة سعر الشراء الأعظمي بالوحدة 1],
		[mt].[AvgPrice] AS [Material_Price_AvgPrice],		-- [المادة سعر الشراء الوسطي بالوحدة 1],
		[mt].[LastPrice] AS [Material_Price_LastPrice],		-- [المادة آخر سعر شراء بالوحدة 1],
		[mt].[Whole2] AS [Material_Whole2],					-- [المادة سعر الجملة بالوحدة 2],
		[mt].[Half2] AS [Material_Half2],					-- [المادة سعر نصف الجملة بالوحدة 2],
		[mt].[Retail2] AS [Material_Retail2],				-- [المادة سعر المفرق بالوحدة 2],
		[mt].[EndUser2] AS [Material_EndUser2],				-- [المادة سعر المستهلك بالوحدة 2],
		[mt].[Export2] AS [Material_Export2],				-- [المادة سعر التصدير بالوحدة 2],
		[mt].[Vendor2] AS [Material_Vendor2],				-- [المادة سعر الموزع بالوحدة 2],
		[mt].[MaxPrice2] AS [Material_MaxPrice2],			-- [المادة سعر الشراء الأعظمي بالوحدة 2],
		[mt].[LastPrice2] AS [Material_LastPrice2],			-- [المادة آخر سعر شراء بالوحدة 2],
		[mt].[Whole3] AS [Material_Whole3],					-- [المادة سعر الجملة بالوحدة 3],
		[mt].[Half3] AS [Material_Half3],					-- [المادة سعر نصف الجملة بالوحدة 3],
		[mt].[Retail3] AS [Material_Retail3],				-- [المادة سعر المفرق بالوحدة 3],
		[mt].[EndUser3] AS [Material_EndUser3],				-- [المادة سعر المستهلك بالوحدة 3],
		[mt].[Export3] AS [Material_Export3],				-- [المادة سعر التصدير بالوحدة 3],
		[mt].[Vendor3] AS [Material_Vendor3],				-- [المادة سعر الموزع بالوحدة 3],
		[mt].[MaxPrice3] AS [Material_MaxPrice3],			-- [المادة سعر الشراء الأعظمي بالوحدة 3],
		[mt].[LastPrice3] AS [Material_LastPrice3],			-- [المادة آخر سعر شراء بالوحدة 3],
		[mt].[PriceType] AS [Material_PriceType],			-- [المادة سياسة التسعير],
		[mt].[VAT] AS [Material_VAT],						-- [المادة ضريبة القيمة المضافة],		-- نسبة 
		-- 15: حقيقي	-- 120: الأعظمي	-- 121: الوسطي	-- 122: آخر شراء	-- 128: افتراضي
		-- الهدايا
		[mt].[BonusOne] AS [Material_BonusOne],				-- [المادة كمية الهدية المستحقة لكل],
		[mt].[Bonus] AS [Material_Bonus],					-- [المادة الكيمة المستحقة للهدية],
		-- خيارات
		[mt].[ExpireFlag] AS [Material_ExpireFlag],			-- [المادة فرض تاريخ الصلاحية],
		[mt].[ProductionFlag] AS [Material_ProductionFlag],	-- [المادة فرض تاريخ الانتاج],
		[mt].[SNFlag] AS [Material_SNFlag],					-- [المادة فرض الأرقام التسلسلية],
		[mt].[ForceInSN] AS [Material_ForceInSN],			-- [المادة فرض الأرقام التسلسلية عند الإدخال],
		[mt].[ForceOutSN] AS [Material_ForceOutSN],			-- [المادة فرض الأرقام التسلسلية عند الإخراج],
		[mt].[Assemble] AS [Material_Assemble],				-- [المادة تجميعية],
		[mt].[bHide] AS [Material_Hide],					-- [المادة إخفاء في نافذة البحث],
		-- الحدود
		[mt].[High] AS [Material_High],						-- [المادة الحد الأعلى],
		[mt].[Low] AS [Material_Low],						-- [المادة الحد الأدنى],
		[mt].[OrderLimit] AS [Material_OrderLimit],			-- [المادة حد الطلب],
		-- معلومات ديناميكية
		[mt].[Qty] AS [Material_Qty],						-- [المادة الكمية],
		[mt].[UseFlag] AS [Material_UseFlag],				-- [المادة مستخدمة],
		[mt].[LastPriceDate] AS [Material_LastPriceDate],	-- [المادة تاريخ آخر شراء],
		-- غير مستخدمة
		[mt].[CodedCode] AS [Material_CodedCode],			-- غير مستخدم
		[mt].[Flag] AS [Material_Flag],						-- غير مستخدم
		--=================================
		-- Group
		--=================================
		[gr].[Code] AS [Group_Code],						-- [المجموعة الرمز],
		[gr].[Name] AS [Group_Name],						-- [المجموعة الاسم],
		[gr].[LatinName] AS [Group_LatinName],				-- [المجموعة الاسم اللاتيني],
		--=================================
		--	Bill item
		--=================================
		[bi].[ParentGUID] AS [BillItem_Parent],				-- [قلم الفاتورة مميز الفاتورة],
		[bi].[Number] AS [BillItem_Number],					-- [قلم الفاتورة الترتيب],
		[bi].[Qty] AS [BillItem_Qty1], 						-- [قلم الفاتورة الكمية بالوحدة 1],
		[bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) AS [BillItem_Qty2],	-- [قلم الفاتورة الكمية بالوحدة 2],
		[bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) AS [BillItem_Qty3],	-- [قلم الفاتورة الكمية بالوحدة 3],
		[bi].[Unity] AS [BillItem_Unity],					-- [قلم الفاتورة الوحدة المستخدمة],	-- 1, 2, 3
		(CASE [bi].[Unity]
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty2] WHEN 0 THEN 1 ELSE [bi].[Qty2] END) END) 
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty3] WHEN 0 THEN 1 ELSE [bi].[Qty3] END) END) 
				ELSE 1 
		END) AS [BillItem_UnitFact], 					-- [قلم الفاتورة عامل تحويل الوحدة المستخدمة],
		[bi].[Price] AS [BillItem_Price],				-- [قلم الفاتورة السعر الفردي للوحدة المستخدمة],
		[bi].[Price] / 
		(CASE [bi].[Unity] 
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty2] WHEN 0 THEN 1 ELSE [bi].[Qty2] END) END) 
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE [bi].[Qty] / (CASE [bi].[Qty3] WHEN 0 THEN 1 ELSE [bi].[Qty3] END) END) 
				ELSE 1 
		END) AS [BillItem_UnitPrice],					-- [قلم الفاتورة السعر الفردي للوحدة 1],	-- بدون حسميات أو إضافات
		[bi].[BonusQnt] AS [BillItem_BonusQnt], 		-- [قلم الفاتورة كمية الهدايا بالوحدة 1],
		[bi].[BonusQnt] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) AS [BillItem_BonusQnt2],	-- [قلم الفاتورة كمية الهدايا بالوحدة 2],
		[bi].[BonusQnt] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) AS [BillItem_BonusQnt3],	-- [قلم الفاتورة كمية الهدايا بالوحدة 3],
		[bi].[Discount] AS [BillItem_Discount],			-- [قلم الفاتورة حسم القلم],
		[bi].[BonusDisc] AS [BillItem_BonusDisc],		-- [قلم الفاتورة حسم الهدايا],
		[bi].[Extra] AS [BillItem_Extra],				-- [قلم الفاتورة إضافة القلم],
		[bi].[Notes] AS [BillItem_Notes],				-- [قلم الفاتورة البيان],
		[bi].[Profits] AS [BillItem_Profits],			-- [قلم الفاتورة نسبة الربح],
		[bi].[ClassPtr] AS [BillItem_Class],			-- [قلم الفاتورة الفئة],
		[bi].[ExpireDate] AS [BillItem_ExpireDate],		-- [قلم الفاتورة تاريخ الصلاحية],
		[bi].[ProductionDate] AS [BillItem_ProductionDate],	-- [قلم الفاتورة تاريخ الانتاج],	
		[bi].[Length] AS [BillItem_Length],				-- [قلم الفاتورة تاريخ الطول],	
		[bi].[Width] AS [BillItem_Width],				-- [قلم الفاتورة تاريخ العرض],	
		[bi].[Height] AS [BillItem_Height],				-- [قلم الفاتورة تاريخ الارتفاع],	
		[bi].[VAT] AS [BillItem_VAT],					-- [قلم الفاتورة الضريبة الإجمالية على القلم],	
		[bi].[VATRatio] AS [BillItem_VATRatio],			-- [قلم الفاتورة نسبة الضريبة],	
		[bi].[SOType] AS [BillItem_SOType],				-- [قلم الفاتورة نوع العرض الخاص],	-- 0: Master -- 1: Details
		--=================================
		-- Store int bill items 
		--=================================
		[st].[Name] AS [BillItem_StoreName],			-- [قلم الفاتورة اسم المستودع],
		[st].[LatinName] AS [BillItem_StoreLatinName],	-- [قلم الفاتورة الاسم اللاتيني للمستودع],
		[st].[Code] AS [BillItem_StoreCode],			-- [قلم الفاتورة رمز المستودع],
		--=================================
		-- Cost
		--=================================
		ISNULL( [co].[Name], '') AS [BillItem_CostName],			-- [قلم الفاتورة اسم مركز الكلفة],
		ISNULL( [co].[LatinName], '') AS [BillItem_CostLatinName],	-- [قلم الفاتورة الاسم اللاتيني لمركز الكلفة],
		ISNULL( [co].[Code], '') AS [BillItem_CostCode],			-- [قلم الفاتورة رمز مركز الكلفة],
		--=================================
		-- Spical offers
		--=================================
		ISNULL( [sm].[Notes], '') AS [SpicalOfferName],	-- [قلم الفاتورة اسم العرض الخاص المستخدم],
		--=================================
		-- Currency int bill items 
		--=================================
		[my].[Name] AS [BillItem_CurrencyName],				-- [قلم الفاتورة اسم العملة],
		[my].[Code] AS [BillItem_CurrencyCode],				-- [قلم الفاتورة رمز العملة],
		[my].[LatinName] AS [BillItem_CurrencyLatinName],	-- [قلم الفاتورة الاسم اللاتيني للعملة],
		[bi].[CurrencyVal] AS [BillItem_CurrencyVal],		-- [قلم الفاتورة تعادل العملة],
		
		(CASE [bi].[unity] 
			WHEN 2 THEN [bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
			WHEN 3 THEN [bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
			ELSE [bi].[Qty] END) AS [BillItem_CurrentQty],	-- الكمية بوحدة الحركة

		(CASE [bi].[unity] 
			WHEN 2 THEN [mt].[Unit2]
			WHEN 3 THEN [mt].[Unit3]
			ELSE [mt].[Unity] END) AS [BillItem_CurrentUnit],	-- وحدة الحركة

		[snc].[SN] AS SN_SN,                                -- [الرقم التسلسلي]
		[snt].[Notes] AS SN_Notes                           -- [ملاحظات الرقم التسلسلي]

	FROM 
		[bi000] [bi]
		INNER JOIN [mt000] [mt] ON [bi].[MatGUID] = [mt].[GUID]
		INNER JOIN [gr000] [gr] ON [mt].[GroupGUID] = [gr].[GUID]
		INNER JOIN [st000] [st] ON [bi].[StoreGUID] = [st].[GUID]
		INNER JOIN [my000] [my] ON [bi].[CurrencyGUID] = [my].[GUID]
		LEFT JOIN [co000] [co] ON [bi].[CostGUID] = [co].[GUID]
		LEFT JOIN [sm000] [sm] ON [bi].[SOGuid] = [sm].[GUID]
		LEFT JOIN [snt000] [snt] ON [bi].[GUID] = [snt].[biGuid]
		LEFT JOIN [snc000] [snc] ON [snt].[ParentGuid] = [snc].[Guid]

#########################################################
#END
