#########################################################
CREATE FUNCTION fnGetAvaQnt(@biGuid UNIQUEIDENTIFIER, @unity FLOAT, @distBillGuid UNIQUEIDENTIFIER=0X0)
RETURNS FLOAT
AS 
BEGIN
IF ISNULL(@biGuid, 0x0) = 0x0
	RETURN 0
DECLARE @OrgQnt FLOAT
DECLARE @RefundedQnt FLOAT
SELECT @OrgQnt = bi.[Qty]
/ (CASE @unity WHEN 1 THEN 1 WHEN 2 THEN mt.[Unit2Fact] WHEN 3 THEN mt.[Unit3Fact] END) FROM bi000 bi
INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID WHERE bi.[GUID] = @biGuid

SELECT @RefundedQnt = SUM(bi.[Qty]
/ (CASE @unity WHEN 1 THEN 1 WHEN 2 THEN mt.[Unit2Fact] WHEN 3 THEN mt.[Unit3Fact] END))
FROM bi000 bi 
INNER JOIN mt000 mt ON mt.[GUID] = bi.[MatGUID] 
WHERE bi.[RelatedTo] = @biGuid
AND (@distBillGuid = 0X0 OR(bi.ParentGUID != @distBillGuid))
RETURN (ISNULL(@OrgQnt, 0) - ISNULL(@RefundedQnt, 0))
END
#########################################################
CREATE FUNCTION fnGetAvaBns(@biGuid UNIQUEIDENTIFIER, @unity FLOAT, @distBillGuid UNIQUEIDENTIFIER=0X0)
RETURNS FLOAT
AS
BEGIN
DECLARE @OrgBns FLOAT
DECLARE @RefundedBns FLOAT
SELECT @OrgBns = bi.[BonusQnt] 
/ (CASE @unity WHEN 1 THEN 1 WHEN 2 THEN mt.[Unit2Fact] WHEN 3 THEN mt.[Unit3Fact] END) FROM bi000 bi
INNER JOIN mt000 mt ON mt.[GUID] = bi.MatGUID WHERE bi.[GUID] = @biGuid

SELECT @RefundedBns = SUM(bi.[BonusQnt] * 
(CASE bi.[Unity] WHEN 1 THEN 1 WHEN 2 THEN mt.[Unit2Fact] WHEN 3 THEN mt.[Unit3Fact] END) 
/ (CASE @unity WHEN 1 THEN 1 WHEN 2 THEN mt.[Unit2Fact] WHEN 3 THEN mt.[Unit3Fact] END))
FROM bi000 bi 
INNER JOIN mt000 mt ON mt.[GUID] = bi.[MatGUID] 
WHERE bi.[RelatedTo] = @biGuid
AND (@distBillGuid = 0X0 OR(bi.ParentGUID != @distBillGuid))
RETURN (ISNULL(@OrgBns, 0) - ISNULL(@RefundedBns, 0))
END
#########################################################
CREATE FUNCTION fnGetBillItems(@BillGuid UNIQUEIDENTIFIER, /*@GroupGuid UNIQUEIDENTIFIER, */@AllowSORefund bit)
RETURNS TABLE
AS
RETURN (
SELECT 
		bi.ItemNumber AS [Number], 
		CONVERT(NVARCHAR(MAX), bi.MatPtr) AS MatPtr, 
		bi.MatCode AS [Code],
		bi.MatName AS [Name],
		bi.LatinName,
		bi.UnityName, 
		/*CONVERT(NVARCHAR(MAX), dbo.fnGetAvaQnt(bi.[GUID], bi.Unity, 0x0))*/'0' AS Qty,
		CONVERT(NVARCHAR(MAX), bi.Price) AS Price,
		bi.ClassPtr, 
		CASE WHEN CONVERT(VARCHAR(10),bi.[ExpireDate], 120) = '1980-01-01' THEN '' 
			ELSE CONVERT(VARCHAR(10),bi.[ExpireDate], 120) END AS [ExpireDate], 
		bi.StoreNumber,
		bi.StoreName,
		bi.CostPtr,
		co.Name AS CostName,
		bi.StoreLatinName,
		bi.[GUID],
		(SELECT STUFF((
		SELECT ',' + BarCode
		FROM MatExBarcode000
		WHERE MatGuid = bi.MatPtr AND MatUnit = bi.Unity
		FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '')) AS BarCode
	FROM vwBillItems bi
	INNER JOIN mt000 mt on mt.[GUID] = bi.MatPtr
	LEFT OUTER JOIN co000 co ON bi.CostPtr = co.GUID
	WHERE bi.BillNumber = @BillGuid 
	--AND (@GroupGuid = 0x0 OR(mt.GroupGUID = @GroupGuid)) 
	AND (@AllowSORefund = 1 OR(bi.SOGUID = 0x0))
	)
#########################################################
CREATE FUNCTION fnGetBillBranches(@TypeGuid	UNIQUEIDENTIFIER, @BillNo INT, @AllowCrossBranches BIT)
RETURNS TABLE
AS
RETURN(
	SELECT [Bill_Guid] AS [GUID], 
		[Bill_Date], 
		[Bill_CustomerName], 
		[Bill_StoreName], 
		[Bill_CostName], 
		[Bill_BranchName] 
	FROM [dbo].[vo_bill] vo
	WHERE [Bill_TypeGUID] = @TypeGuid AND [Bill_Number] = @BillNo
	AND (@AllowCrossBranches = 1 OR(vo.Bill_Guid IN(SELECT buGUID FROM vwBu)))
)
#########################################################
CREATE PROC GetRefundedBills(@OrgBillGuid UNIQUEIDENTIFIER)
AS
SELECT br.RelatedBillGuid, 
	br.RefundFromBillDB,
	bu.BillType_Abbrev + ': ' + CAST(bu.Bill_Number AS VARCHAR) AS Bill_Number,
	bu.Bill_Date, 
	bu.Bill_NetTotal, 
	bu.Bill_StoreName, 
	bu.Bill_CostName, 
	bu.Bill_BranchGUID,
	bu.Bill_BranchName,
	bu.Bill_NetTotal
FROM BillRelations000 br
INNER JOIN vo_bill bu on bu.Bill_Guid = br.RelatedBillGuid
WHERE br.BillGuid = @OrgBillGuid
AND br.IsRefundFromBill = 1
ORDER BY bu.Bill_Number DESC
#########################################################
CREATE PROC GetRefundedBillItems(@RefundGuid UNIQUEIDENTIFIER)
AS
SELECT 
	bi.matNumber,
	bi.[MatName],
	bi.[UnityName],
	bi.Unity,
	bi.[Qty],
	bi.RelatedTo
FROM vwBillItems bi 
WHERE bi.BillNumber = @RefundGuid
ORDER BY bi.ItemNumber DESC
#########################################################
CREATE FUNCTION fnGetRefundsFromBillValue(@OrgBillGuid	UNIQUEIDENTIFIER)
RETURNS FLOAT
AS
BEGIN
	RETURN(
		SELECT
			ISNULL(SUM(vo.Bill_NetTotal), 0)
		FROM vo_bill vo
		INNER JOIN BillRelations000 br ON br.RelatedBillGuid = vo.Bill_Guid
		WHERE br.BillGuid = @OrgBillGuid AND br.IsRefundFromBill = 1)
END
#########################################################
CREATE PROC GetBillAndRefundsValues(@OrgBillGuid	UNIQUEIDENTIFIER)
AS
SELECT 
	ISNULL(Bill_NetTotal, 0) AS Bill_NetTotal--, dbo.fnGetRefundsFromBillValue(@OrgBillGuid) AS Refunds_NetTotal
	FROM vo_bill vo
WHERE Bill_Guid = @OrgBillGuid
#########################################################
CREATE PROC GetMatInfoTable(@RelatedTo UNIQUEIDENTIFIER, @Unity FLOAT)
AS
----------- ßãíÉ ÇáãÇÏÉ
SELECT Qty, [dbo].fnGetAvaQnt(@RelatedTo, @Unity, 0x0) AS RfndQty FROM bi000
WHERE [GUID] = @RelatedTo

----------- ßãíÉ ÇáåÏÇíÇ
SELECT BonusQnt, [dbo].fnGetAvaBns(@RelatedTo, @Unity, 0x0) AS RfndBns FROM bi000
WHERE [GUID] = @RelatedTo

----------- ÞíãÉ ÇáãÇÏÉ
DECLARE @RefundedValue FLOAT
SELECT @RefundedValue = SUM(([Qty] * [Price]) / CurrencyVal) FROM bi000
WHERE RelatedTo = @RelatedTo

SELECT ([Qty] * [Price]) / CurrencyVal AS OrgValue, @RefundedValue as RfndValue FROM bi000
WHERE [GUID] = @RelatedTo

----------- ÞíãÉ ÍÓã ÇáÞáã
DECLARE @RefundedDisc FLOAT
SELECT @RefundedDisc = SUM([Discount] / CurrencyVal) FROM bi000
WHERE RelatedTo = @RelatedTo

SELECT [Discount] / CurrencyVal AS [Discount], @RefundedDisc AS RfndDisc FROM bi000
WHERE [GUID] = @RelatedTo

----------- äÓÈÉ ÍÓã ÇáÞáã
SELECT ISNULL([TotalDiscountPercent], 0) AS TotalDiscountPercent, (@RefundedDisc / (Qty * Price)) AS RfndDiscRatio FROM bi000
WHERE [GUID] = @RelatedTo

----------- ÞíãÉ ÇÖÇÝÇÊ ÇáÞáã
DECLARE @RefundedExtra FLOAT
SELECT @RefundedExtra = SUM([Extra] / CurrencyVal) FROM bi000
WHERE RelatedTo = @RelatedTo

SELECT [Extra] / CurrencyVal AS Extra, @RefundedExtra AS RfndExtra FROM bi000
WHERE [GUID] = @RelatedTo

----------- äÓÈÉ ÇÖÇÝÇÊ ÇáÞáã
SELECT ISNULL([TotalExtraPercent], 0) AS TotalExtraPercent, (@RefundedExtra / (Qty * Price)) AS RfndExtraRatio FROM bi000
WHERE [GUID] = @RelatedTo

----------- ÍÕÉ ÇáÞáã ãä ÇáÍÓã ÇáÇÌãÇáì
DECLARE @OrgDisc FLOAT
SELECT @OrgDisc = TotalDisc / CurrencyVal FROM bu000
WHERE [GUID] IN(SELECT ParentGUID FROM bi000 WHERE [GUID] = @RelatedTo)

SELECT CASE WHEN @OrgDisc = 0 THEN 0 
	ELSE (([Discount] / CurrencyVal) / @OrgDisc) END AS DiscShare, 
	CASE WHEN @OrgDisc = 0 THEN 0
	ELSE (@RefundedDisc / @OrgDisc) END AS RfndDiscShare 
FROM bi000 WHERE [GUID] = @RelatedTo

----------- ÍÕÉ ÇáÞáã ãä ÇáÇÖÇÝÇÊ ÇáÇÌãÇáíÉ 
DECLARE @OrgExtra FLOAT
SELECT @OrgExtra = TotalExtra / CurrencyVal FROM bu000
WHERE [GUID]  IN(SELECT ParentGUID FROM bi000 WHERE [GUID] = @RelatedTo)

SELECT CASE WHEN @OrgExtra = 0 THEN 0
	ELSE (([Extra] / CurrencyVal) / @OrgExtra) END AS ExtShare,
	CASE WHEN @OrgExtra = 0 THEN 0
	ELSE (@RefundedExtra / @OrgExtra) END AS RfndExtShare	
FROM bi000 WHERE [GUID] = @RelatedTo
#########################################################
CREATE FUNCTION fnRefundFromBillSN(@orgBiGuid UNIQUEIDENTIFIER, @refBiGuid UNIQUEIDENTIFIER, @OutReFund BIT) 
	RETURNS TABLE 
AS 
RETURN(  
	SELECT  
			[s].[Guid],
			[s].[SN],
			[s].[Item]
	FROM  
		[vcSNs] s 
	WHERE (s.biGuid = @orgBiGuid AND @OutReFund != 1 AND s.Qty > 0)
			OR(s.biGuid = @orgBiGuid AND @OutReFund = 1 AND s.Qty = 0)
			OR(s.biGuid = @refBiGuid)
	)
#########################################################
#END
