################################################################################
## repDist_GetCustomerExtendedInfo
CREATE PROC repDist_GetCustomerExtendedInfo
	@AccountGUID 		UNIQUEIDENTIFIER = 0x0, 
	@DistributorGuid	UNIQUEIDENTIFIER = 0x0, 
	@State 			INT = -1, 
	@Contracted 		INT = -1, 
	@SortType 		INT = 0,
	@CustsCT		[UNIQUEIDENTIFIER], 
	@CustsTCH		[UNIQUEIDENTIFIER] 
AS 
	SET NOCOUNT ON 

	SET @AccountGuid = ISNULL(@AccountGuid,0x00)
	SET @DistributorGuid = ISNULL(@DistributorGuid, 0x00)

	CREATE TABLE #Cust      ( [GUID] 	[UNIQUEIDENTIFIER], [Security] 		[INT])      
	INSERT INTO #Cust EXEC prcGetDistGustsList @DistributorGuid, @AccountGUID 

	SELECT  
		ISNULL([ce].[Guid],0x00) 		AS [Guid],	
		[cu].[cuGUID]				AS [CustomerGUID],  
		[ac].[GUID]				AS [AccGUID], 
		[ac].[Code]				AS [Code],  
		[cu].[cuCustomerName]			AS [Name],  
		ISNULL([tch].[Guid], 0x00)		AS [TradeChannelGuid],  
		ISNULL([ct].[Guid], 0x00)		AS [CustomerTypeGuid],  
		ISNULL([tch].[Name], '')		AS [TradeChannelName],  
		ISNULL([ct].[Name], '')			AS [CustomerTypeName],  
		ISNULL([d].[Name], '')			AS [DistributorName],  
		ISNULL([ce].[State], 1)			AS [State],  
		ISNULL([Ce].[Contract], '')		AS [Contract], 
		ISNULL ([ce].[ContractDate], '1/1/1980')AS [ContractDate], 
		ISNULL([Dl].[Route1], 0)		AS [Route1],  
		ISNULL([Dl].[Route2], 0)		AS [Route2],  
		ISNULL([Dl].[Route3], 0)		AS [Route3],  
		ISNULL([Dl].[Route4], 0)		AS [Route4],  
		ISNULL([Ce].[Contracted],1)		AS [Contracted],
		[Cu].[cuNumber] 			As [cuNumber],  
		[Cu].[cuCustomerName] 			As [CuName],  
		[Cu].[cuLatinName] 			As [CuLName],  
		[Cu].[cuAddress] 			As [CuAddress],  
		[Cu].[cuNationality] 			As [CuNationality],  
		[Cu].[cuDiscRatio] 			As [CuDiscRatio],  
		[Cu].[cuPhone1] 			As [CuPhone1],  
		[Cu].[cuPhone2] 			As [CuPhone2],  
		[Cu].[cuFAX] 				As [CuFax],  
		[Cu].[cuTelex] 				As [CuTelex],  
		[Cu].[cuNotes] 				As [CuNotes],  
		[Cu].[cuAccount] 			As [CuAccPtr],  
		[Cu].[cuPrefix] 			As [CustPrefix],  
		[Cu].[cuLatinName] 			As [CustLatinName],  
		[Cu].[cuSuffix] 			As [CustSuffix],  
		[Cu].[cuMobile] 			As [CustMobile],  
		[Cu].[cuPager] 				As [CustPager],  
		[Cu].[cuEmail] 				As [CustEmail],  
		[Cu].[cuHomePage] 			As [CustHomePage],  
		[Cu].[cuCountry] 			As [CustCountry],  
		[Cu].[cuCity] 				As [CustCity],  
		[Cu].[cuArea] 				As [CustArea],  
		[Cu].[cuStreet] 			As [CustStreet],  
		[Cu].[cuZipCode] 			As [CustZipCode],  
		[Cu].[cuPOBox] 				As [CustPOBox],  
		[Cu].[cuCertificate] 			As [CustCertificate],  
		[Cu].[cuJob] 				As [CustJob],  
		[Cu].[cuJobCategory] 			As [CustJobCategory],  
		[Cu].[cuUserFld1] 			As [CustUserFld1],  
		[Cu].[cuUserFld2] 			As [CustUserFld2],  
		[Cu].[cuUserFld3] 			As [CustUserFld3],  
		[Cu].[cuUserFld4] 			As [CustUserFld4],  
		[Cu].[cuDateOfBirth] 			As [CustDateOfBirth], 
		[Cu].[cuGender] 			As [CustGender], 
		[Cu].[cuHobbies] 			As [CustHobbies], 
		[Cu].[cuBarcode] 			As [CustBarcode], 
		[parentAc].[acName]			AS [ParentAccName],
		-- [Cd].[AllDistNames]			AS [AllDistNames] ,
		[dbo].[fnDistGetDistsForCust] (Cu.cuGuid)	AS [AllDistNames],		
		[Ce].[Notes]					AS [Notes]
	FROM  
		[vwCu] AS [cu]  
		INNER JOIN Ac000 			AS ac 		ON cu.cuAccount = ac.GUID  
		INNER JOIN #Cust 			AS c 		ON [cu].[cuGUID] = c.GUID  
		INNER JOIN vwAC 			AS parentAc 	ON parentAc.acGUID = ac.ParentGUID 
		INNER JOIN DistCe000 			AS ce 		ON cu.cuGUID = ce.CustomerGUID  
		LEFT  JOIN DISTTCH000 			AS tch 		ON tch.GUID = ce.TradeChannelGUID  
		LEFT  JOIN DISTCT000 			AS ct 		ON ct.GUID = ce.CustomerTypeGUID  
		LEFT  JOIN DistDistributionLines000     AS Dl		ON Dl.CustGuid = ce.CustomerGuid 
		LEFT  JOIN vwDistributor 		AS d 		ON d.GUID = Dl.DistGuid  
		INNER JOIN RepSrcs			AS rCT 		ON rCT.IdType = [ce].[CustomerTypeGuid] AND rCT.idTbl = @CustsCT
		INNER JOIN RepSrcs			AS rTCH 	ON rTCH.IdType = [ce].[TradeChannelGuid] AND rTCH.idTbl = @CustsTCH
	WHERE  
		((d.Guid = @DistributorGuid AND dl.DistGUID = @DistributorGuid) OR (@DistributorGuid= 0x0)) AND 
		((@Contracted = -1) OR (ISNULL([ce].[Contracted], 1) = @Contracted)) AND  
		((@State = -1)      OR (ISNULL([ce].[State], 1) = @State)) 
	ORDER BY  
		( CASE @SortType 
			WHEN 0 THEN [d].[Name] 
			WHEN 1 THEN [tch].[Name] 
			WHEN 2 THEN [ct].[Name] 
			WHEN 3 THEN CAST ( [Dl].[Route1]	 AS NVARCHAR(10)) 
			WHEN 4 THEN [Cu].[cuCustomerName] 
			WHEN 5 THEN CAST ( [Ce].[ContractDate]	 AS NVARCHAR(10)) 
			WHEN 6 THEN [Cu].[cuPrefix] 
			WHEN 7 THEN [Cu].[cuLatinName] 
			WHEN 8 THEN [Cu].[cuSuffix] 
			WHEN 9 THEN [Cu].[cuNationality] 
			WHEN 10 THEN [Cu].[cuPhone1] 
			WHEN 11 THEN [Cu].[cuPhone2] 
			WHEN 12 THEN [Cu].[cuFAX] 
			WHEN 13 THEN [Cu].[cuTelex] 
			WHEN 14 THEN [Cu].[cuMobile] 
			WHEN 15 THEN [Cu].[cuCountry] 
			WHEN 16 THEN [Cu].[cuCity] 
			WHEN 17 THEN [Cu].[cuArea] 
			WHEN 18 THEN [Cu].[cuStreet] 
			WHEN 19 THEN [Cu].[cuBarcode] 
			WHEN 20 THEN [parentAc].[acName] 
		  END) 

DROP TABLE #Cust 

/*
Exec prcConnections_Add2 '„œÌ—'
EXEC [dbo].[repDist_GetCustomerExtendedInfo] Null, Null, -1, -1, 4
*/
################################################################################
#END