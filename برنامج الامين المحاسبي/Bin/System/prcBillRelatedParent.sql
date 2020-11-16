#########################################################
CREATE FUNCTION fnGetBillParentOrder(
	@buGuid [UNIQUEIDENTIFIER])
RETURNS TABLE
AS
RETURN (
	SELECT TOP 1
		1					AS [BillParentType],				
		CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [bu].[btName] ELSE (CASE [bt].[LatinName] WHEN N'' THEN [bu].[btName] ELSE [bt].[LatinName] END) END AS [Name],
		[bu].[buNumber]		AS [Number],
		[ori].[POGUID]		AS [BillParentGuid], 
		[bu].[buType]		AS [BillParentTypeGuid],
		0x0					AS [OutBillTypeGuid]
	FROM 
		ori000 AS [ori] 
		INNER JOIN vwbu	AS [bu] ON [ori].[POGUID] = [bu].[buGUID] 
		INNER JOIN bt000		AS [bt]	 ON [bt].[GUID]    = [bu].[buType]
	WHERE 
		[ori].[BuGuid] = @buGuid AND @buGuid <> 0x0 AND [bu].[btType] IN (5, 6) 
)
#########################################################
CREATE FUNCTION fnGetBillParentAssemble(
	@buGuid [UNIQUEIDENTIFIER])
RETURNS TABLE
AS
RETURN(
	SELECT 2										AS [BillParentType],					
		   CASE dbo.fnConnections_GetLanguage() WHEN 0 THEN [abi].[Name] ELSE (CASE [abi].[LatinName] WHEN N'' THEN [abi].[Name] ELSE [abi].[LatinName] END) END AS [Name],
		   CONVERT(NVARCHAR(250),[bu].[Number])		AS [Number],
		   [ab].[InBillGUID]						AS [BillParentGuid],
		   [bu].[TypeGUID]							AS [BillParentTypeGuid],
		   [abi].[OutTypeGUID]						AS [OutBillTypeGuid]
	  FROM AssemBill000 AS [ab] 
		   INNER JOIN bu000 AS [bu] ON [ab].[InBillGUID] = [bu].[GUID]
		   INNER JOIN AssemBillType000 AS [abi] ON [abi].[InTypeGUID] = [bu].[TypeGUID]
	 WHERE [ab].[FinalBillGuid] = @buGuid AND @buGuid <> 0x0
)
#########################################################
CREATE FUNCTION fnGetBillParentManufacture(
	@buGuid [UNIQUEIDENTIFIER])
RETURNS TABLE
AS
RETURN(
	SELECT 3										AS [BillParentType],
		   ''										AS [Name],
		   CONVERT(NVARCHAR(250),[mn].[Number])		AS [Number],
		   [mb].[ManGUID]							AS [BillParentGuid],
		   0x0										AS [BillParentTypeGuid],
   		   0x0										AS [OutBillTypeGuid]
	  FROM MB000 AS [mb] 
		   INNER JOIN vcMn AS [mn] ON [mn].[GUID] = [mb].[ManGUID] 
	 WHERE [mb].[BillGUID] = @buGuid AND @buGuid <> 0x0
)
#########################################################
CREATE PROC prcGetBillParentData
	@buGuid [UNIQUEIDENTIFIER]
AS
BEGIN
	SET NOCOUNT ON;
	CREATE TABLE #Result(
		[BillParentType]	 INT,
		[Name]				 NVARCHAR(250),
		[Number]			 NVARCHAR(250),
		[BillParentGuid]	 UNIQUEIDENTIFIER,
		[BillParentTypeGuid] UNIQUEIDENTIFIER,
		[OutBillTypeGuid]	 UNIQUEIDENTIFIER
	)
	INSERT INTO #Result SELECT [BillParentType], [Name], [Number], [BillParentGuid], [BillParentTypeGuid], [OutBillTypeGuid] FROM [dbo].[fnGetBillParentOrder](@buGuid)
	IF NOT EXISTS (SELECT 1 FROM #Result)
	BEGIN
		INSERT INTO #Result SELECT [BillParentType], [Name], [Number], [BillParentGuid], [BillParentTypeGuid], [OutBillTypeGuid] FROM [dbo].[fnGetBillParentAssemble](@buGuid)
		IF NOT EXISTS (SELECT 1 FROM #Result)
		BEGIN
			INSERT INTO #Result SELECT [BillParentType], [Name], [Number], [BillParentGuid], [BillParentTypeGuid],[OutBillTypeGuid] FROM [dbo].[fnGetBillParentManufacture](@buGuid)
		END
	END
	SELECT [BillParentType], [Name], [Number], [BillParentGuid], [BillParentTypeGuid], [OutBillTypeGuid]
	  FROM #Result 
END
#########################################################
#END
