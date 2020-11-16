#########################################################
CREATE VIEW vwExtended_biCu 
AS 
	SELECT  
		[bi].*, 
		(CASE [bi].[buCustPtr] WHEN 0x0 THEN [bi].[buCustAcc] ELSE [cu].[cuAccount] END) AS [buResolvedCustAcc],
		(CASE WHEN [bi].[buCustPtr] IS NULL OR [bi].[buCustPtr] = 0x0 THEN [bi].[buCust_Name] ELSE [cu].[cuCustomerName] END) AS [cuCustomerName],
		(CASE WHEN [bi].[buCustPtr] IS NULL OR [bi].[buCustPtr] = 0x0 THEN [bi].[buCust_Name] ELSE [cu].[cuLatinName] END) AS [cuLatinName]
	FROM 
		[vwExtended_bi] AS [bi] LEFT JOIN [vwCu] as [cu]
		ON [bi].[buCustPtr] = [cu].[cuGUID]
#########################################################
#END