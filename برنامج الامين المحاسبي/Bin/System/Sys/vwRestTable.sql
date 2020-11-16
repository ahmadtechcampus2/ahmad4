###########################################################################
CREATE VIEW vwRestTable
AS
SELECT [rt].[Number]
      ,[rt].[GUID]
      ,[rt].[Code]
      ,[rt].[Cover]
      ,[rt].[DepartmentID]
      ,[rt].[Security]
      ,[rt].[BranchMask]
      ,ISNULL([rd].[Code], '') AS [DepartmentCode]
      ,ISNULL([rd].[Name], '') AS [DepartmentName]
      ,ISNULL([rd].[LatinName], '') AS [DepartmentLatinName]
FROM [RestTable000] [rt] 
	LEFT JOIN [RestDepartment000] [rd] ON [rd].GUID=[rt].[DepartmentID]
###########################################################################
CREATE VIEW vwRestTable_Extended
AS
	SELECT 
		rt.*, 
		CASE 
			WHEN r.[TableID] IS NULL THEN 1
			ELSE 0
		END AS [IsAvailable],
		ISNULL(r.OrderGUID, 0x0) AS OrderGUID
	FROM 
		vwRestTable rt
		LEFT JOIN (SELECT [rott].[TableID], [rot].GUID AS [OrderGUID] FROM 
			[RestOrderTableTemp000] [rott] 
			INNER JOIN [RestOrderTemp000] [rot] ON [rot].GUID = [rott].[ParentID]) r ON rt.GUID = r.[TableID]
###########################################################################
CREATE VIEW vdRestTable
AS
	SELECT 
		rt.*, 
		CASE 
			WHEN r.[TableID] IS NULL THEN 1
			ELSE 0
		END AS [IsAvailable],
		ISNULL(r.OrderGUID, 0x0) AS OrderGUID,
		ISNULL(r.OrderNumber, 0) AS OrderNumber,
		ISNULL(r.OrderPersonsCount, 0) AS OrderPersonsCount,
		ISNULL(r.GuestCode, '') AS GuestCode,
		ISNULL(r.GuestName, '') AS GuestName,
		ISNULL(r.GuestLatinName, '') AS GuestLatinName,
		ISNULL(r.OrderOpeningTime, GetDate()) AS OrderOpeningTime,
		CASE 
			WHEN r.OrderOpeningTime IS NULL THEN 0 
			WHEN r.OrderOpeningTime = '1980-1-1' THEN 0 
			ELSE DATEDIFF(mi, r.OrderOpeningTime, GETDATE()) 
		END AS OpeningTimePeriod,
		CASE 
			WHEN r.LastAdditionDate IS NULL THEN 0 
			WHEN r.LastAdditionDate = '1980-1-1' THEN 0 
			ELSE DATEDIFF(mi, r.LastAdditionDate, GETDATE()) 
		END AS LastAdditionPeriod,
		ISNULL(OrderState, 0) AS OrderState
	FROM 
		vwRestTable rt
		LEFT JOIN (SELECT [rott].[TableID], [rot].[GUID] AS OrderGUID, 
			[rot].[Number] AS OrderNumber, [rott].[Cover] AS OrderPersonsCount,
			ISNULL(Vn.Code, '') AS GuestCode, ISNULL(Vn.Name, '') AS GuestName, ISNULL(Vn.LatinName, '') AS GuestLatinName,
			ISNULL(rot.Opening, GetDate()) AS OrderOpeningTime,
			rot.LastAdditionDate AS LastAdditionDate,
			[rot].[State] AS OrderState
			FROM 
				[RestOrderTableTemp000] [rott] 
				INNER JOIN [RestOrderTemp000] [rot] ON [rot].GUID = [rott].[ParentID]
				LEFT JOIN [RestVendor000] [Vn] ON [Vn].[GUID] = [rot].[GuestID]) r ON rt.GUID = r.[TableID]
###########################################################################
CREATE VIEW vwRestFreeTablesCard
AS
SELECT *
FROM vwRestTable WHERE [GUID] NOT IN (SELECT [rott].[TableID] FROM 
		[RestOrderTableTemp000] [rott]
		INNER JOIN [RestOrderTemp000] [rot] ON [rot].GUID=[rott].[ParentID])
###########################################################################
CREATE VIEW vwRestTablesOrders	
AS
SELECT temp.*
	,ve.DepartmentID
	,ve.DepartmentCode 
	,ve.DepartmentName
	,ve.DepartmentLatinName
FROM [RestOrderTableTemp000] temp
		INNER JOIN vwRestTable ve ON ve.GUID=temp.TableID
###########################################################################
#END