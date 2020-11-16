##################################################################################
CREATE VIEW vtDistHi
AS 
	SELECT * FROM DistHi000
##################################################################################
CREATE VIEW vbDistHi
AS 
	SELECT * FROM vtDistHi
##################################################################################
CREATE VIEW vwDistHi
AS
	SELECT 
		Hi.[Number],
		Hi.[GUID],
		Hi.[Code],
		Hi.[Name],
		Hi.[LatinName] ,
		Hi.[TypeGUID],
		Hi.[Security],
		Hi.[ParentGuid],	
		ISNULL(p.Code, '')		AS ParentCode,
		ISNULL(p.Name, '')		AS ParentName,
		ISNULL(p.LatinName, '')		AS ParentLatinName,
		ISNULL(p.Code, '') + '-' + ISNULL(p.Name, '')	AS ParentCodeName
	FROM 
		vbDistHi AS Hi
		LEFT JOIN DistHi000 AS p ON p.Guid = Hi.ParentGuid 
##################################################################################
Create view vwDistHt
AS
	SELECT * FROM DistHt000
##################################################################################
CREATE VIEW vwDistTch
AS
	SELECT Number, Code, Name, GUID , 1 AS Security FROM DIstTch000
##################################################################################
CREATE VIEW vwDistCt
AS
	SELECT Number, Code, Name, GUID , 1 AS Security FROM DIstCt000
##################################################################################
CREATE VIEW vwDistCtd
AS 
	SELECT  
		Ct.Number		AS CtNumber,
		Ct.Guid			AS CtGuid,
		Ct.Code			AS CtCode,
		Ct.Name			AS CtName,
		Ct.LAtinName	AS CtLatinName,
		Ct.PossibilityItemDisc	AS CtPossibilityItemDisc,
		CtD.Number		AS Number,
		CtD.Number		AS CtDNumber,
		CtD.Guid		AS CtDGuid,
		CtD.DiscountGuid AS DiscGuid,
		D.Number		AS DiscNumber,
		D.Code			AS DiscCode,
		D.Name			AS DiscName,
		D.LatinName		AS DiscLatinName,
		D.GivingType	AS DiscGivingType,
		D.StartDate		AS DiscStartDate,
		D.EndDate		AS DiscEndDate,
		D.AccountGuid	AS DiscAccGuid,
		D.CalcType		AS DiscCalcType,
		D.OneTime 		AS DiscOneTime,
		D.ChangeVal		AS DiscChangeVal,
		D.[Percent]		AS DiscPercent,
		D.Value			AS DiscValue,
		D.CondValue		AS DiscCondValue,
		D.CondValueTo	AS DiscCondValueTo,
		D.MatGuid		AS DiscMatGuid,
		D.MatCondGuid   AS DiscMatCondGuid,
		D.GroupGuid		AS DiscGroupGuid,
		D.MatTemplateGuid	AS DiscMatTemplateGuid,
		D.Security		AS DiscSecurity,
		D.AroundType	AS AroundType

	FROM DistCt000	AS Ct
		INNER JOIN DistCtd000	AS CtD	ON Ct.Guid = CtD.ParentGuid
		INNER JOIN DistDisc000	AS D	ON D.Guid  = CtD.DiscountGuid
##################################################################################
CREATE VIEW vwDistDiscDistributor
AS
	SELECT 
		D.Number	AS DistNumber,
		D.Name 		AS DistName, 
		D.Guid 		AS DistGuid, 
		ISNULL(Di.Guid,0x00) AS DiscGuid, 
		ISNULL(DiDr.Value,0) AS Value
	FROM Distributor000 	AS D
		LEFT JOIN DistDiscDistributor000 	AS DiDr	ON D.Guid  = DiDr.DistGuid
		LEFT JOIN DistDisc000 			AS Di	ON Di.Guid = DiDr.ParentGuid
##################################################################################
CREATE VIEW vwTCH_CT
AS 
	SELECT 
		Number, 
		GUID, 
		Code, 
		Name, 
		LatinName, 
		1 AS Security
	FROM DisTTch000
	UNION ALL
	SELECT 
		Number, 
		GUID, 
		Code, 
		Name, 
		LatinName, 
		1 AS Security
	FROM DistCT000

##################################################################################
CREATE VIEW vwDistTrvi
AS
	SELECT	 
		[tr].[Number] 		AS [TrNumber], 
		[tr].[GUID] 		AS [TrgUID], 
		[tr].[DistributorGUID] 	AS [TrDistributorGUID], 
		[tr].[Date] 		AS [TrDate], 
		[tr].[VanGUID] 		AS [TrVanGUID], 
		[tr].[VisitReq] 	AS [TrVisitReq], 
		[tr].[State] 		AS [trState],
		[vi].[Number] 		AS [ViNumber], 
		[vi].[GUID] 		AS [ViGuid], 
		[vi].[CustomerGUID] AS [viCustomerGUID], 
		[vi].[StartTime] 	AS [ViStartTime], 
		[vi].[FinishTime] 	AS [ViFinishTime], 
		[vi].[State] 		AS [viState],
		[vi].[EntryStockOfCust]	AS [ViEntryStockOfCust], 
		[vi].[EntryVisibility] 	AS [EntryVisibility]
 
	FROM  
		[DistTr000] AS [Tr]  
		INNER JOIN [DistVi000] as [VI] 
		ON [Tr].[GUID] = [vi].[TripGUID] 
		
##################################################################################
CREATE View vwCuCe
AS 
	SELECT 
		[cu].*, 
		ISNULL([ce].[State], 0) AS ceState,
		ISNULL([ce].[Contract], '') AS ceContract,
		ISNULL([ce].[Contracted], 0) AS ceContracted,
		ISNULL([ce].[OrderInRoute], 0) AS ceOrderInRoute,
		ISNULL([ce].[ContractDate], '01-01-1980') AS ceContractDate,
		ISNULL([ce].[Notes], '') AS ceNotes,
		ISNULL([ce].[StoreGuid], 0x00) AS ceStoreGuid,
		ISNULL([ct].[GUID], 0x0) AS ctGUID,
		ISNULL([ct].[Code], '') AS ctCode,
		ISNULL([ct].[Name], '') AS ctName,
		ISNULL([ct].[LatinName], '') AS ctLatinName,
		ISNULL([tch].[GUID], 0x0) AS tchGUID,
		ISNULL([tch].[Code], '') AS tchCode,
		ISNULL([tch].[Name], '') AS tchName,
		ISNULL([tch].[LatinName], '') AS tchLatinName
	FROM 
		[vwCu] AS [cu]
		LEFT JOIN [DistCe000] AS [ce] ON [ce].[CustomerGUID] = [cu].[cuGUID] 
		LEFT JOIN [DistCT000] AS [ct] ON [ct].[GUID] = [ce].[CustomerTypeGUID] 
		LEFT JOIN [DistTch000] AS [tch] ON [tch].[GUID] = [ce].[TradeChannelGUID] 

##################################################################################
CREATE  VIEW vwDistPromotions
AS
	SELECT [Number], [Guid], [Code], [Name], [Security] FROM [DistPromotions000]

##################################################################################
CREATE  VIEW vwDistCuAc 
AS 
	SELECT 
		[cuGUID]	AS Guid, 
		[cuNumber], 
		[cuCustomerName], 
		[cuNationality], 
		[cuAddress], 
		[cuPhone1], 
		[cuPhone2], 
		[cuFAX], 
		[cuTELEX], 
		[cuNotes], 
		[cuUseFlag], 
		[cuPicture], 
		[cuAccount], 
		[cuCheckDate], 
		[cuSecurity]	AS Security, 
		[cuType], 
		[cuDiscRatio], 
		[cuDefPrice], 
		[cuState], 
		[cuArea], 
		[cuCity], 
		[cuStreet], 
		[acGUID], 
		[acNumber], 
		[acName], 
		[acCode], 
		[acCDate], 
		[acParent], 
		[acFinal], 
		[acNSons], 
		[acDebit], 
		[acCredit], 
		[acInitDebit], 
		[acInitCredit], 
		[acUseFlag], 
		[acMaxDebit], 
		[acNotes], 
		[acCurrencyVal], 
		[acCurrencyPtr], 
		[acWarn], 
		[acCheckDate], 
		[acSecurity], 
		[acDebitOrCredit], 
		[acType], 
		[acState], 
		[acNum1], 
		[acNum2], 
		[acBranchGUID] 
	FROM 
		[vwCu] AS [cu] INNER JOIN [vwAc] AS [ac] 
		ON [ac].[acGUID] = [cu].[cuAccount] 
##################################################################################
CREATE  VIEW vwDistPromotionsDetail
AS
	SELECT 
		Pr.Number	AS PrNumber,
		Pr.Guid		AS PrGuid,
		Pr.FDate	AS PrFDate,
		Pr.LDate	AS PrLDate,
		Pr.Name		AS PrName,
		Pr.CondQty	AS PrCondQty,
		Pr.FreeQty	AS PrFreeQty,
		Pr.Type		AS PrType,
		Pr.DiscType	AS PrDiscType,
		Pd.Number	AS PdNumber,
		Pd.Guid		AS PdGuid,
		Pd.Type		AS PdType,
		Pd.MatGuid	AS mtGuid,
		Pd.Qty		AS mtQty,
		mt.Name		AS mtName

	FROM DistPromotions000 AS Pr
	INNER JOIN DistPromotionsDetail000 	AS Pd ON Pr.Guid = Pd.ParentGuid
	INNER JOIN mt000					AS mt ON mt.Guid = Pd.MatGuid
##################################################################################
CREATE VIEW vwDistCustClasses
AS
	SELECT 
		Cc.Number	AS Number,
		Cc.Guid		AS Guid,
		Cc.CustGuid	AS CustGuid,
		Cu.CustomerName	AS CustName,
		t.Guid		AS MatTemplateGuid,
		t.Number	AS MatTemplateNumber,
		t.Name		AS MatTemplateName,
		t.GroupGuid	AS MatTemplateGroupGuid,
		ISNULL(c.Guid, 0x00)		AS CustClassGuid,
		ISNULL(c.Number, 0)		AS CustClassNumber,
		ISNULL(c.Name, '')		AS CustClassName
		
	FROM DistCC000 		AS Cc 
		INNER JOIN Cu000 		AS Cu ON Cu.Guid = Cc.CustGuid
		INNER JOIN DistMatTemplates000 	AS t ON T.Guid = Cc.MatTemplateGuid
		LEFT JOIN DistCustClasses000 	AS C ON C.Guid = Cc.CustClassGuid
##################################################################################
CREATE VIEW vtDistributor
AS 
	SELECT * FROM Distributor000
##################################################################################
CREATE VIEW vbDistributor
AS 
	SELECT * FROM vtDistributor
##################################################################################
CREATE VIEW vwDistributor
AS 
	SELECT * FROM vbDistributor
##################################################################################
CREATE VIEW  vwDistDistributor
AS
	SELECT 
		d.[Number],
		d.[GUID],
		d.[Code],
		d.[Name],
		d.[LatinName] ,
		d.[HierarchyGUID],
		ISNULL(Hi.Code, '')		AS HierarchyCode,
		ISNULL(Hi.Name, '')		AS HierarchyName,
		ISNULL(Hi.LatinName, '')	AS HierarchyLatinName,
		ISNULL(Hi.Code, '') + '-' + ISNULL(Hi.Name, '')	AS HierarchyCodeName,
		d.[Security],
		d.[VanGUID] ,
		ISNULL(Vn.Code, '')		AS VanCode,
		ISNULL(Vn.Name, '')		AS VanName,
		ISNULL(Vn.LatinName, '')	AS VanLatinName,
		ISNULL(Vn.Code, '') + '-' + ISNULL(Vn.Name, '')	AS VanCodeName,
		d.[StoreGUID] ,
		ISNULL(st.Code, '')		AS StoreCode,
		ISNULL(st.Name, '')		AS StoreName,
		ISNULL(st.Code, '') + '-' + ISNULL(st.Name, '') 	AS StoreCodeName,
		d.[PalmUserName] ,
		d.[MatGroupGUID] ,
		d.[CustAccGUID] ,
		d.[AccountGUID] ,
		d.[ExportStoreGUID] ,
		d.[ExportCostGUID] ,
		d.[MatSortFld] ,
		d.[CustSortFld],
		d.[GLStartDate],
		d.[GLEndDate] ,
		d.[GLStartDateFlag] ,
		d.[ExportAccFlag] ,
		d.[ExportStoreFlag] ,
		d.[ExportCostsFlag] ,
		d.[MatCondId] ,
		d.[MatCondGuid],
		d.[CustCondId],
		d.[CustCondGuid],
		d.[ExportSerialNumFlag] ,
		d.[ExportEmptyMaterialFlag] ,
		d.[License] ,
		d.[PrimSalesmanGUID] ,
		ISNULL(sm1.Code, '')	AS PrimSalesManCode,
		ISNULL(sm1.Name, '')	AS PrimSalesManName,
		ISNULL(sm1.LatinName, '')	AS PrimSalesManLatinName,
		ISNULL(sm1.Code, '') + '-' + ISNULL(sm1.Name, '') AS PrimSalesManCodeName,
		d.[AssisSalesmanGUID] ,
		ISNULL(sm2.Code, '')	AS AssisSalesManCode,
		ISNULL(sm2.Name, '')	AS AssisSalesManName,
		ISNULL(sm2.LatinName, '')	AS AssisSalesManLatinName,
		ISNULL(sm2.Code, '') + '-' + ISNULL(sm2.Name, '') AS AssisSalesManCodeName,
		ISNULL(co1.Guid, 0x00)	AS PrimCostGUID,
		ISNULL(co1.Code, '')	AS PrimCostCode,
		ISNULL(co1.Name, '')	AS PrimCostName,
		ISNULL(co1.LatinName, '')	AS PrimCostLatinName,
		ISNULL(co1.Code, '') + '-' + ISNULL(co1.Name, '') AS PrimCostCodeName,
		ISNULL(co2.Guid, 0x00) 	AS AssisCostGUID,
		ISNULL(co2.Code, '')	AS AssisCostCode,
		ISNULL(co2.Name, '')	AS AssisCostName,
		ISNULL(co2.LatinName, '')	AS AssisCostLatinName,
		ISNULL(co2.Code, '') + '-' + ISNULL(co2.Name, '') AS AssisCostCodeName,
		d.[DriverAccGUID],
		ISNULL(acd.Code, '')		AS DriveAccCode,
		ISNULL(acd.Name, '')		AS DriveAccName,
		ISNULL(acd.LatinName, '')		AS DriveAccLatinName,
		ISNULL(acd.Code, '') + '-' + ISNULL(acd.Name, '')	AS DriveAccCodeName,
		d.[TypeGuid],
		d.[CurrSaleMan],
		d.[VisitPerDay],
		d.[ItemDiscType],
		d.[CustomersAccGUID],
		ISNULL(acc.Code, '')		AS CustomersAccCode,
		ISNULL(acc.Name, '')		AS CustomersAccName,
		ISNULL(acc.LatinName, '')		AS CustomersAccLatinName,
		ISNULL(acc.Code, '') + '-' + ISNULL(acc.Name, '')	AS CustomersAccCodeName,
		d.[AutoPostBill] ,
		d.[AutoGenBillEntry] ,
		d.[AccessByBarcode],
		d.[UseStockOfCust] ,
		d.[UseShelfShare] ,
		d.[UseActivity] ,
		d.[NoOvertakeMaxDebit] ,
		d.[CustBalanceByJobCost] ,
		d.[UseCustTarget] ,
		d.[OutNegative] ,
		d.[CanChangePrice] ,
		d.[ShowCustInfo] ,
		d.[ShowTodayRoute] ,
		d.[UseCustLastPrice] ,
		d.[ExportAllCustDetailFlag] ,
		d.[CustBarcodeHasValidate] ,
		d.[DefaultPayType] ,
		d.[DistributorPassword] ,
		d.[SupervisorPassword] 
	FROM 
		vwDistributor AS D 
		LEFT JOIN DistHi000 	AS Hi ON Hi.Guid = D.HierarchyGUID	
		LEFT JOIN DistVan000	AS Vn ON Vn.Guid = D.VanGuid
		LEFT JOIN St000		AS St ON St.Guid = D.StoreGuid
		LEFT JOIN DistSalesMan000	AS sm1 ON sm1.Guid = d.PrimSalesmanGUID
		LEFT JOIN Co000 		AS Co1 ON Co1.Guid = sm1.CostGuid
		LEFT JOIN DistSalesMan000	AS sm2 ON sm2.Guid = d.AssisSalesmanGUID
		LEFT JOIN Co000 		AS Co2 ON Co2.Guid = sm2.CostGuid
		LEFT JOIN ac000 		AS AcD ON acD.Guid  = d.DriverAccGuid 
		LEFT JOIN ac000 		AS AcC ON acC.Guid  = d.CustomersAccGuid 
##################################################################################
CREATE VIEW vtDistPromotions
AS 
	SELECT * FROM DistPromotions000
##################################################################################
CREATE VIEW vbDistPromotions
AS 
	SELECT * FROM vtDistPromotions
##################################################################################
CREATE VIEW vtDistSalesMan
AS 
	SELECT * FROM DistSalesMan000
##################################################################################
CREATE VIEW vbDistSalesMan
AS 
	SELECT * FROM vtDistSalesMan
##################################################################################
CREATE VIEW  vwDistSalesMan
AS
	SELECT 
		sm.[Number],
		sm.[GUID],
		sm.[Code],
		sm.[Name],
		sm.[LatinName] ,
		sm.[TypeGUID],
		sm.[Security],
		sm.[CostGuid],	
		ISNULL(co.Code, '')		AS CostCode,
		ISNULL(co.Name, '')		AS CostName,
		ISNULL(co.LatinName, '')	AS CostLatinName,
		ISNULL(co.Code, '') + '-' + ISNULL(co.Name, '')	AS CostCodeName,
		sm.[AccGuid],	
		ISNULL(ac.Code, '')		AS AccCode,
		ISNULL(ac.Name, '')		AS AccName,
		ISNULL(ac.LatinName, '')	AS AccLatinName,
		ISNULL(ac.Code, '') + '-' + ISNULL(ac.Name, '')	AS AccCodeName
	FROM 
		vbDistSalesMan AS Sm
		LEFT JOIN Co000 AS Co ON Co.Guid = sm.CostGuid
		LEFT JOIN Ac000 AS Ac ON Ac.Guid = sm.AccGuid
##################################################################################
CREATE VIEW vtDistVan
AS 
	SELECT * FROM DistVan000
##################################################################################
CREATE VIEW vbDistVan
AS 
	SELECT * FROM vtDistVan
##################################################################################
CREATE VIEW vwDistVan
AS 
	SELECT * FROM vbDistVan
##################################################################################
CREATE VIEW vwDistMatTemplates
AS
	SELECT
		mt.Number,
		mt.Guid,
		mt.Name,
		mt.GroupGuid,
		gr.Name	AS groupName,
		1 AS Security,
		gr.Name AS Code 
	FROM 
		DistMatTemplates000 AS mt
		INNER JOIN gr000 AS gr ON gr.Guid = mt.GroupGuid
##################################################################################
CREATE VIEW vwPeriods 
 AS 
	select * from bdp000 
##################################################################################
CREATE VIEW vwDistOrders
AS
	SELECT * FROM DistOrders000
##################################################################################
CREATE VIEW vwDistDetOrder
AS 
SELECT  m.code, m.name, dod.number , dod.guid , dod.parentguid , dod.matguid, dod.qty ,  dod.unity ,
 CASE dod.unity WHEN 1 THEN
	CASE do.pricetype 
		WHEN  0x4   THEN whole
		WHEN  0x8   THEN half
		WHEN  0x10  THEN export
		WHEN  0x20  THEN vendor
		WHEN  0x40  THEN retail
		WHEN  0x80  THEN enduser
      End
      WHEN 2 THEN
	CASE do.pricetype 
		WHEN  0x4   THEN whole2
		WHEN  0x8   THEN half2
		WHEN  0x10  THEN export2
		WHEN  0x20  THEN vendor2
		WHEN  0x40  THEN retail2
		WHEN  0x80  THEN enduser2
	 End
      WHEN 3 THEN 
	CASE do.pricetype 
		WHEN  0x4   THEN whole3
		WHEN  0x8   THEN half3
		WHEN  0x10  THEN export3
		WHEN  0x20  THEN vendor3
		WHEN  0x40  THEN retail3
		WHEN  0x80  THEN enduser3
         End
    END AS mtprice ,
  CASE dod.unity WHEN 1 THEN m.unity
		 WHEN 2 THEN unit2
		 WHEN 3 THEN unit3
    END AS unitname , 
  CASE dod.unity WHEN 1 THEN 1
		 WHEN 2 THEN unit2fact
		 WHEN 3 THEN unit3fact
    END AS unitfact , do.pricetype
FROM distordersdetails000 AS dod 
INNER JOIN distorders000  AS do ON do.guid = dod.parentguid
INNER JOIN mt000		  AS m ON m.guid = dod.matguid
##################################################################################
CREATE VIEW vtDistEnSummary
AS
	SELECT
		ce.Guid AS Guid,
		d.Guid AS DistGuid,
		ce.Date,
		CAST(py.Number AS NCHAR) AS Number,
		et.Name AS Type,
		et.LatinName AS LatinType
	FROM en000 AS en
	INNER JOIN ce000 AS ce ON en.ParentGuid = ce.Guid
	INNER JOIN et000 AS et ON ce.TypeGuid = et.Guid
	INNER JOIN er000 AS er ON er.EntryGuid = ce.Guid
	INNER JOIN py000 AS py ON py.Guid = er.ParentGuid
	INNER JOIN Distsalesman000 AS ds ON ds.CostGuid = en.CostGuid
	INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid
##################################################################################
CREATE VIEW vwDistEnSummary
AS
	SELECT DISTINCT 
		en.Guid,
		vten.Guid AS CeGuid, 
		vten.DistGuid, 
		cu.Guid AS CustGuid, 
		vten.Date, 
		vten.Number, 
		vten.Type, 
		vten.LatinType 
	FROM en000 AS en 
	INNER JOIN vtDistEnSummary AS vten ON en.ParentGuid = vten.Guid 
	INNER JOIN cu000 AS cu ON en.AccountGuid = cu.AccountGuid
##################################################################################
CREATE VIEW vwDistBuSummary
AS
SELECT
		bu.Guid, 
		d.Guid AS DistGuid, 
		bu.CustGuid, 
		bu.Date, 
		CAST(bu.Number AS NCHAR) AS Number, 
		bt.Name AS Type, 
		bt.LatinName AS LatinType 
	FROM bu000 AS bu 
	INNER JOIN bt000 AS bt ON bu.TypeGuid = bt.Guid 
	INNER JOIN Distsalesman000 AS ds ON ds.CostGuid = bu.CostGuid 
	INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid
##################################################################################
CREATE VIEW vwDistLookup
AS
	SELECT
		CAST(Number AS NVARCHAR(10)) AS Number,
		Guid,
		Name,
		Used,
		Type
	FROM DistLookup000
##################################################################################
CREATE VIEW vwDistSearchStructCustClasses
AS
	-- This view is used in TCustClassStruct
	SELECT
		CAST(Number AS NVARCHAR(10)) AS Number,
		Guid,
		Name
	FROM DistCustClasses000
##################################################################################
CREATE VIEW vtDistPaid
AS 
	SELECT dp.*, st.Name AS StoreName, py.GUID  AS flag 
	FROM DistPaid000 AS dp
	INNER JOIN Distributor000 AS Dist On Dist.guid = dp.DistGuid
	INNER JOIN st000 AS st ON st.Guid = Dist.StoreGuid
	LEFT JOIN  py000 py ON py.GUID  = dp.EntryGuid
##################################################################################
CREATE VIEW vbDistPaid
AS 
	SELECT * FROM vtDistPaid
##################################################################################
CREATE VIEW vwDistPaid 
AS  
      SELECT * FROM vbDistPaid
GO
##################################################################################
CREATE view vwDistQuestAnswers
AS
	SELECT
		q.Guid		AS QuestGuid,
		q.StartDate AS StartDate,
		q.EndDate	AS EndDate,
		q.name		AS QuestName, 		
		qu.Guid		AS QuestionGuid,
		qu.Text		AS QuestionText,
		qu.Type		AS Type, 
		qa.Guid		AS AnswerGuid,
		qa.CustGuid AS CustGuid,
		qa.Answer	AS Answer,	
		qa.VisitGuid AS VisitGuid 
	FROM
		DistQuestionnaire000 AS q
		INNER JOIN DistQuestQuestion000 AS qu ON q.Guid = qu.ParentGuid
		INNER JOIN DistQuestAnswers000  AS qa ON qu.Guid = qa.QuestGuid 
################################################################################
#END