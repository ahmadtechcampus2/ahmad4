################################################################################
CREATE  PROC prcDistCoverageUpdate
AS

SET NOCOUNT ON

SELECT 
		cu.accountguid AS songuid , dl.custguid , d.customersaccguid AS parentguid , dl.distguid INTO #oldCustDist
FROM 
		distdistributionlines000 AS dl 
		INNER join distributor000 AS d ON d.guid = dl.distguid INNER JOIN cu000 AS cu ON cu.guid = dl.custguid
WHERE 
		custguid in (SELECT dc.custguid FROM DistCoverageUpdate000 AS dc WHERE dl.custguid = dc.custguid)
		AND distguid NOT IN (SELECT dc.distguid FROM DistCoverageUpdate000 AS dc WHERE dl.custguid = dc.custguid)



-- remove the old dist customers from distribotion lines
DELETE  distdistributionlines000 
FROM	distdistributionlines000 AS dl
		INNER JOIN #oldCustDist AS o ON o.custguid = dl.custguid 
		AND o.distguid = dl.distguid

-- remove the old cust accounts from old dist account
DELETE ci000 FROM ci000 AS ci 
			 INNER JOIN #oldCustDist AS o ON o.parentguid = ci.parentguid
			 AND o.songuid = ci.songuid



SELECT 
		1 AS item /*= IDENTITY(INT)*/,dcu.distguid,customersaccguid AS parentguid,dcu.custguid , cu.accountguid as songuid 
INTO	
		#newCustDist 
FROM 
		DistCoverageUpdate000 AS dcu
		INNER JOIN distributor000 AS d on d.guid = dcu.distguid 
		INNER JOIN cu000 AS cu ON cu.guid = dcu.custguid
WHERE 
		NOT EXISTS (SELECT * FROM distdistributionlines000 AS dl WHERE  dl.custguid = dcu.custguid AND dl.distguid = dcu.distguid)

ALTER TABLE #newCustDist
ALTER COLUMN item INT NULL

UPDATE #newCustDist 
SET item = (SELECT MAX(item) FROM ci000 AS ci WHERE ci.parentguid = #newCustDist.parentguid)



INSERT INTO distdistributionlines000 
		(guid,distguid,custguid)
SELECT 
		NEWID(),distguid,custguid
FROM 
		#newCustDist

ALTER TABLE  ci000 
		disable TRIGGER trg_ci000_DistLines
		
INSERT INTO ci000 
		(item,parentguid,songuid)
SELECT  item , parentguid, songuid
FROM 	#newCustDist
		
ALTER TABLE  ci000 
		enable TRIGGER trg_ci000_DistLines

DELETE distcoverageupdate000

################################################################################
CREATE PROC prcDistGetCoverageUpdate
     @DistGuid  UNIQUEIDENTIFIER = 0x0,
     @AccGuid	UNIQUEIDENTIFIER = 0x0,
     @Country   UNIQUEIDENTIFIER = 0x0,
     @City      UNIQUEIDENTIFIER = 0x0,
	 @area      UNIQUEIDENTIFIER = 0x0,
     @street    nVarChar(256) = '',
     @Job       nVarChar(256) = '',
     @updated   int = 0
AS 
  SET NOCOUNT ON 
     CREATE TABLE #Cust      ( [GUID] UNIQUEIDENTIFIER, [Security] INT)       
     INSERT INTO #Cust EXEC prcGetDistGustsList @DistGuid, @AccGuid  
   
    SELECT  DISTINCT	 
	
		[cu].[GUID]						AS [CustomerGUID],  
		ISNULL([du].[distguid],0x00)  	AS [DistGUID], 
		ISNULL([d].[name],'')			AS [DistName],
		[ac].[GUID]						AS [AccGUID],  
		[ac].[Code]						AS [Code],   
		[cu].[CustomerName]				AS [Name],
		[Cu].[LatinName] 				As [CuLName],   
		[Cu].[AccountGUID] 				As [CuAccPtr],   
		[Cu].[Country]					AS Country,
		[Cu].[City]						AS City,
		[Cu].[Area] 					As [CustArea],   
		[Cu].[Street] 					As [CustStreet],  
		[Cu].[Job]						AS Job,
		[dbo].[fnDistGetDistsForCust](Cu.Guid) AS [CurrentDists]
		
	FROM   
		vexCu AS [cu]   
		INNER JOIN Ac000 AS [ac] ON [cu].[AccountGUID] = [ac].[GUID]   
		INNER JOIN #Cust  AS [c] ON [cu].[GUID] = [c].[GUID]   
		LEFT JOIN DistCoverageUpdate000 AS [du] ON [cu].[GUID] = [du].[CustGUID]
		LEFT JOIN Distributor000 AS [d] ON [d].[GUID] = [du].[DistGUID]
	WHERE 
		([Cu].[CountryGUID] = @Country OR @Country = 0x0) AND
		([Cu].[CityGUID] = @City OR @City = 0x0) AND
		([Cu].[AreaGUID] = @area OR @area = 0x0) AND
		([Cu].[Street] = @street OR @street = '') AND
		([Cu].[Job] = @Job OR @Job = '') AND
		((@updated = 0) OR ([du].[distguid] is not null AND @updated = 1))
	ORDER BY  
		Cu.CustomerName	 
/*
exec prcDistCoverUpdate 
*/

################################################################################
#END