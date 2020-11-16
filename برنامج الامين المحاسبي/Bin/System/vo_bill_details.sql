#########################################################		
CREATE FUNCTION fnGetDueDate(@Term [INT], @Day [INT], @BillDate [DATETIME])
	RETURNS [DATETIME]
AS
BEGIN
	DECLARE @DayOfWeek [INT]
	IF @Term = 2
		RETURN DATEADD(DAY, @Day, @BillDate)
	ELSE IF @Term = 3
		RETURN CAST((CAST(MONTH(@BillDate) AS NVARCHAR(2)) + '/' + CAST(@Day AS NVARCHAR(2)) + '/' + CAST(YEAR(@BillDate) AS NVARCHAR(4))) AS [DATETIME])
	ELSE IF @Term = 4
		RETURN DATEADD(MONTH, 1, CAST((CAST(MONTH(@BillDate) AS NVARCHAR(2)) + '/' + CAST(@Day AS NVARCHAR(2)) + '/' + CAST(YEAR(@BillDate) AS NVARCHAR(4))) AS [DATETIME]))
	ELSE IF @Term = 5
	BEGIN
		SET @DayOfWeek = DATEPART(dw, @BillDate) + 1
		IF @DayOfWeek = 8
			SET @DayOfWeek  = 1
		RETURN DATEADD(DAY, @Day - @DayOfWeek, @BillDate)
	END
	ELSE IF @Term = 6
	BEGIN
		SET @DayOfWeek = DATEPART(dw, @BillDate) + 1
		IF @DayOfWeek = 8
			SET @DayOfWeek  = 1
		RETURN DATEADD(DAY, (@Day - @DayOfWeek) + 7, @BillDate)
	END
	ELSE IF @Term = 7
		RETURN DATEADD(DAY, -DATEPART(DAY, @BillDate), DATEADD(MONTH, 1, @BillDate))
	ELSE IF @Term = 8
		RETURN DATEADD(MONTH, 1, DATEADD(DAY, -DATEPART(DAY, @BillDate), DATEADD(MONTH, 1, @BillDate)))
	RETURN '1/1/1980'
END
#########################################################
CREATE VIEW vo_bill_details
AS 
	SELECT 
		[b].*,
		[bi].*,
		([bi].[BillItem_UnitPrice] * [bi].[BillItem_Qty1]) AS [BillItem_TotalPrice],
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * [bi].[BillItem_Qty1] AS [BillItem_Qty_s], -- By first unity
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * [bi].[BillItem_UnitPrice] AS [BillItem_UnitPrice_s],
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * ([bi].[BillItem_UnitPrice] * [bi].[BillItem_Qty1]) AS [BillItem_TotalPrice_s],
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END)) AS [BillItem_UnitDiscount],
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]), 0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END)) AS [BillItem_UnitExtra],
		[bi].[BillItem_Qty1] * ((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END)) AS [BillItem_TotalDiscount],
		[bi].[BillItem_Qty1] * ((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END)) AS [BillItem_TotalExtra],

		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		AS [BillItem_NetUnitPrice],

		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) *
		(
			[bi].[BillItem_UnitPrice] 
			-
			((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
			+
			((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		) AS [BillItem_NetUnitPrice_s],
		

		[bi].[BillItem_Qty1] * (
		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_GUID]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		) AS [BillItem_NetTotalPrice],

		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * 
		( 
		[bi].[BillItem_Qty1] * (
		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		)) AS [BillItem_NetTotalPrice_s], 
		
		(CASE [bi].[BillItem_Discount] 
			WHEN 0 THEN 0
			ELSE (CASE [bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] * 100) / ([bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice]) END)
			END) AS [BillItem_DiscRatio],		-- نسبة حسم القلم

		(CASE [bi].[BillItem_Extra] 
			WHEN 0 THEN 0
			ELSE (CASE [bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] * 100) / ([bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice]) END)
			END) AS [BillItem_ExtraRatio],		-- نسبة إضافة القلم
			
		(CASE [b].[BillType_VATSystem]
			WHEN 2 THEN [bi].[BillItem_Price] * (1 + ([bi].[Material_VAT] / 100))
			ELSE [bi].[BillItem_Price]
			END) AS [BillItem_Price_TTC],									-- السعر بدون احتساب الضريبة

		(CASE [b].[BillType_VATSystem]
			WHEN 2 THEN [bi].[BillItem_Price] * (1 + ([bi].[Material_VAT] / 100))
			ELSE [bi].[BillItem_Price]
			END) *  [BillItem_CurrentQty] AS [BillItem_TotalPrice_TTC],		-- السعر بدون احتساب الضريبة
		[ac].[Code] AS [Bill_Customer_Account_Code], 
		[ac].[Name] AS [Bill_Customer_Account_Name] 
	FROM 
		[vo_bill] AS [b]
		INNER JOIN [vo_bill_Item] [bi] ON [b].[Bill_Guid] = [bi].[BillItem_Parent]
		LEFT JOIN [ac000] [ac] ON [b].[Bill_CustAccGuid] = [ac].[Guid] 

#########################################################
CREATE VIEW vo_bill_details_extended
AS 
	SELECT 
		[bd].*,
		
		(CASE ISNULL( [pt].[Term], -1) 
			WHEN -1 THEN [bd].[Bill_Date]
			ELSE [dbo].[fnGetDueDate]([pt].[Term], [pt].[Days],[bd].[Bill_Date]) 
			END) AS [Bill_DueDate],
			
		(SELECT SUM([BillItem_Price] * [BillItem_CurrentQty]) FROM [vo_bill_details] WHERE [billitem_parent] = [bd].[bill_guid]) AS [Bill_Total_TTC],
		
		(SELECT SUM([BillItem_Price] * [BillItem_CurrentQty]) FROM [vo_bill_details] WHERE [billitem_parent] = [bd].[bill_guid]) + [Bill_Vat] - [Bill_TotalDisc] + [Bill_TotalExtra]  AS [Bill_NetTotal_TTC]
		
	FROM 
		[vo_bill_details] [bd]
		LEFT JOIN [pt000] [pt] ON [pt].[RefGUID] = [bd].[Bill_Guid]
#########################################################
CREATE VIEW vo_bill_dtails_extended
AS 
	SELECT * FROM vo_bill_details_extended
#########################################################
CREATE VIEW vo_bill_details_sn
AS 
	SELECT 
		[b].*,
		[bi].*,
		([bi].[BillItem_UnitPrice] * [bi].[BillItem_Qty1]) AS [BillItem_TotalPrice],
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * [bi].[BillItem_Qty1] AS [BillItem_Qty_s], -- By first unity
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * [bi].[BillItem_UnitPrice] AS [BillItem_UnitPrice_s],
		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * ([bi].[BillItem_UnitPrice] * [bi].[BillItem_Qty1]) AS [BillItem_TotalPrice_s],
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END)) AS [BillItem_UnitDiscount],
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]), 0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END)) AS [BillItem_UnitExtra],
		[bi].[BillItem_Qty1] * ((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END)) AS [BillItem_TotalDiscount],
		[bi].[BillItem_Qty1] * ((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END)) AS [BillItem_TotalExtra],

		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		AS [BillItem_NetUnitPrice],

		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) *
		(
			[bi].[BillItem_UnitPrice] 
			-
			((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
			+
			((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		) AS [BillItem_NetUnitPrice_s],
		

		[bi].[BillItem_Qty1] * (
		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_GUID]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		) AS [BillItem_NetTotalPrice],

		(CASE [b].[BillType_IsInput] WHEN 1 THEN 1 ELSE -1 END) * 
		( 
		[bi].[BillItem_Qty1] * (
		[bi].[BillItem_UnitPrice] 
		-
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE [bi].[BillItem_Discount] / [bi].[BillItem_Qty1] END) + [bi].[BillItem_BonusDisc] ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Discount]) FROM [di000] WHERE [ParentGuid] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END) + (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_BonusDisc] / [bi].[BillItem_Qty1]) END))		
		+
		((CASE [b].[Bill_Total] WHEN 0 THEN (CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0  ELSE [bi].[BillItem_Extra] / [bi].[BillItem_Qty1] END) ELSE ((CASE [bi].[BillItem_Qty1] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] / [bi].[BillItem_Qty1]) END) + (ISNULL((SELECT Sum([Extra]) FROM [di000] WHERE [ParentGUID] = [b].[Bill_Guid]),0) * [bi].[BillItem_Price] / CASE [bi].[BillItem_UnitFact] WHEN 0 THEN 1 ELSE [bi].[BillItem_UnitFact] END) / [b].[Bill_Total]) END))
		)) AS [BillItem_NetTotalPrice_s], 
		
		(CASE [bi].[BillItem_Discount] 
			WHEN 0 THEN 0
			ELSE (CASE [bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Discount] * 100) / ([bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice]) END)
			END) AS [BillItem_DiscRatio],		-- نسبة حسم القلم

		(CASE [bi].[BillItem_Extra] 
			WHEN 0 THEN 0
			ELSE (CASE [bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice] WHEN 0 THEN 0 ELSE ([bi].[BillItem_Extra] * 100) / ([bi].[BillItem_Qty1] * [bi].[BillItem_UnitPrice]) END)
			END) AS [BillItem_ExtraRatio],		-- نسبة إضافة القلم
			
		(CASE [b].[BillType_VATSystem]
			WHEN 2 THEN [bi].[BillItem_Price] * (1 + ([bi].[Material_VAT] / 100))
			ELSE [bi].[BillItem_Price]
			END) AS [BillItem_Price_TTC],									-- السعر بدون احتساب الضريبة

		(CASE [b].[BillType_VATSystem]
			WHEN 2 THEN [bi].[BillItem_Price] * (1 + ([bi].[Material_VAT] / 100))
			ELSE [bi].[BillItem_Price]
			END) *  [BillItem_CurrentQty] AS [BillItem_TotalPrice_TTC],		-- السعر بدون احتساب الضريبة
		[ac].[Code] AS [Bill_Customer_Account_Code], 
		[ac].[Name] AS [Bill_Customer_Account_Name] 
	FROM 
		[vo_bill] AS [b]
		INNER JOIN [vo_bill_Item_sn] [bi] ON [b].[Bill_Guid] = [bi].[BillItem_Parent]
		LEFT JOIN [ac000] [ac] ON [b].[Bill_CustAccGuid] = [ac].[Guid] 

#########################################################
CREATE VIEW vo_bill_details_sn_extended
AS 
	SELECT 
		[bd].*,
		
		(CASE ISNULL( [pt].[Term], -1) 
			WHEN -1 THEN [bd].[Bill_Date]
			ELSE [dbo].[fnGetDueDate]([pt].[Term], [pt].[Days],[bd].[Bill_Date]) 
			END) AS [Bill_DueDate],
			
		(SELECT SUM([BillItem_Price] * [BillItem_CurrentQty]) FROM [vo_bill_details] WHERE [billitem_parent] = [bd].[bill_guid]) AS [Bill_Total_TTC],
		
		(SELECT SUM([BillItem_Price] * [BillItem_CurrentQty]) FROM [vo_bill_details] WHERE [billitem_parent] = [bd].[bill_guid]) + [Bill_Vat] - [Bill_TotalDisc] + [Bill_TotalExtra]  AS [Bill_NetTotal_TTC]
		
	FROM 
		[vo_bill_details_sn] [bd]
		LEFT JOIN [pt000] [pt] ON [pt].[RefGUID] = [bd].[Bill_Guid]
#########################################################
#END

