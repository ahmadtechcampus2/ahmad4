################################################################################
CREATE PROCEDURE prcGetDistGustsListForChannel
	@DistGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@AccGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@CustGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@HiGuid		[UNIQUEIDENTIFIER] = 0x00
AS

	SET NOCOUNT ON

	DECLARE @ZeroGuid	UNIQUEIDENTIFIER
	SET @ZeroGuid	= '00000000-0000-0000-0000-000000000000' 

	CREATE TABLE #CustsOfAcc([GUID] UNIQUEIDENTIFIER) 
	INSERT INTO #CustsOfAcc
	SELECT * FROM [dbo].[fnGetCustsOfAcc](@AccGUID)
	
	CREATE TABLE #HierarchyList([GUID] UNIQUEIDENTIFIER) 
	INSERT INTO #HierarchyList
	SELECT GUID FROM fnGetHierarchyList(@HiGuid, 0)
	
	SELECT DISTINCT 
		[cu].[cuGuid] AS Guid, 
		[cu].[cuSecurity] AS [Security]
	FROM 
		[vwCu] AS [Cu] 
		INNER JOIN #CustsOfAcc AS [fCu] ON [Cu].[cuGuid] = [fCu].[Guid] 
		INNER JOIN vwDistributor AS [D]   ON [D].[Guid] = @DistGUID 
	WHERE
		(cu.cuGuid = @CustGuid OR @CustGuid = @ZeroGuid) 
	AND	(D.Guid = @DistGuid OR @DistGuid = @ZeroGuid) 
	AND	(d.CustomersAccGUID = @AccGUID OR @AccGUID = @ZeroGuid)
	AND (D.HierarchyGuid IN (SELECT Guid FROM #HierarchyList) OR @HiGuid = @ZeroGuid)		

################################################################################
CREATE PROC repDistCustInfo
	@AccGuid 		UNIQUEIDENTIFIER = 0x0, 
	@DistGuid		UNIQUEIDENTIFIER = 0x0 
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Cust      ( [GUID] UNIQUEIDENTIFIER, [Security] INT)      

	IF(@AccGuid = 0x00)
		SET @AccGuid = (SELECT CustomersAccGUID FROM Distributor000 WHERE GUID = @DistGuid)

	INSERT INTO #Cust EXEC prcGetDistGustsListForChannel @DistGuid, @AccGuid 

	SELECT  DISTINCT	
		ISNULL([ce].[Guid],0x00) 		AS [Guid],	
		[cu].[cuGUID]				AS [CustomerGUID],  
		[ac].[GUID]				AS [AccGUID], 
		[ac].[Code]				AS [Code],  
		[cu].[cuCustomerName]			AS [Name],  
		ISNULL([tch].[Guid], 0x00)		AS [TradeChannelGuid],  
		ISNULL([ct].[Guid], 0x00)		AS [CustomerTypeGuid],  
		ISNULL([tch].[Name], '')		AS [TradeChannelName],  
		ISNULL([ct].[Name], '')			AS [CustomerTypeName],  
		ISNULL([ce].[State], 0)			AS [State],  
		ISNULL([Ce].[Contract], '')		AS [Contract], 
		[ce].[ContractDate] 			AS [ContractDate], 
		ISNULL([Ce].[Contracted],1)		AS [Contracted],
		[Cu].[cuNumber] 			As [cuNumber],  
		[Cu].[cuCustomerName] 			As [CuName],  
		[Cu].[cuLatinName] 			As [CuLName],  
		[Cu].[cuAccount] 			As [CuAccPtr],  
		[Cu].[cuArea] 				As [CustArea],  
		[Cu].[cuStreet] 			As [CustStreet],  
		-- [parentAc].[acName]			AS [ParentAccName],
		[dbo].[fnDistGetDistsForCust] (Cu.cuGuid)	AS [AllDistNames],
		[Ce].[Notes]				AS [Notes],
		ISNULL([st].[Guid], 0x00)		AS StoreGuid,
		ISNULL([st].[Name], '')		AS StoreName
	FROM  
		[vwCu] AS [cu]  
		INNER JOIN Ac000 	 AS ac 	ON cu.cuAccount = ac.GUID  
		INNER JOIN #Cust 	 AS c 	ON cu.[cuGUID] = c.GUID  
		LEFT JOIN DistCe000  AS ce 	ON cu.cuGUID = ce.CustomerGUID  
		LEFT JOIN DISTTCH000 AS tch ON tch.GUID = ce.TradeChannelGUID  
		LEFT JOIN DISTCT000  AS ct 	ON ct.GUID = ce.CustomerTypeGUID  
		LEFT JOIN st000		 AS st	ON st.Guid = ce.StoreGuid
	ORDER BY 
		Cu.CuCustomerName	

DROP TABLE #Cust 

/*
Exec prcConnections_Add2 '„œÌ—'
EXEC repDistCustInfo Null, '21D82EAC-9B52-4B52-9782-DDCF2F2B1E35'
*/
################################################################################
#END