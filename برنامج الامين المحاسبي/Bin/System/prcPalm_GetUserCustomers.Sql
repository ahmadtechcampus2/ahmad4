#########################################################
CREATE PROCEDURE prcPalm_GetUserCustomers
		@PalmUserName [NVARCHAR](250)  
AS  
	SET NOCOUNT ON  
	  
	DECLARE @CustAccGUID [uniqueidentifier]  
	DECLARE @CustCondID [INT] 
	DECLARE @CustSortFld [NVARCHAR](250)  
	SELECT @CustAccGUID = [CustAccGUID], @CustCondID = [CustCondID], @CustSortFld = [CustSortFld] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName  
		  
	CREATE TABLE [#CountryTbl](        
		[ID] [int] identity(1,1),         
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI        
	)                
	CREATE TABLE [#StreetTbl](        
		[ID] [int] identity(1,1),         
		[CountryID] [int],     
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI,         
		[CountryName] [NVARCHAR](255)  COLLATE Arabic_CI_AI        
	)                
	CREATE TABLE [#CustomerTbl]( 
		[ID] [uniqueidentifier],  
		[StreetID] [int],         
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI,         
		[Code] [NVARCHAR](100)  COLLATE Arabic_CI_AI,         
		[LatinName] [NVARCHAR](255)  COLLATE Arabic_CI_AI,         
		[Balance] [float],         
		[CountryName] [NVARCHAR](255)  COLLATE Arabic_CI_AI,        
		[StreetName] [NVARCHAR](255)  COLLATE Arabic_CI_AI,        
		[cuAccount] [uniqueidentifier]  
	) 
	CREATE TABLE [#CustomerCodeTbl]( 
		[CustIndex] [int],  
		[CustCode] [NVARCHAR](255) COLLATE Arabic_CI_AI 
	) 
	CREATE TABLE [#CustResultTbl]( 
		[ID] [int], 
		[StreetID] [int], 
		[Name] [NVARCHAR](255) COLLATE Arabic_CI_AI, 
		[Code] [NVARCHAR](100) COLLATE Arabic_CI_AI, 
		[LatinName] [NVARCHAR](255) COLLATE Arabic_CI_AI, 
		[Balance] [NVARCHAR](255) COLLATE Arabic_CI_AI, 
		[Index] [int] IDENTITY(0, 1) 
	) 
	CREATE TABLE [#CustCond]([GUID] [uniqueidentifier], [Security] [INT])  
	INSERT INTO [#CustCond] EXEC [prcPalm_GetCustsList] @CustCondId  
	if(@CustAccGUID = 0x0)                
	begin
		INSERT INTO [#CustomerTbl]          
			SELECT        
				[accu].[cuGUID],  
				0,        
				[cu].[cuCustomerName],        
				[accu].[acCode],        
				[cu].[cuLatinName],     
				[accu].[acDebit] - [accu].[acCredit],        
				[cu].[cuArea],        
				[cu].[cuStreet],        
				[cu].[cuAccount]         
			FROM        
				[vwCuAc]  as [accu]     
				INNER JOIN [vwCu] As [cu]     
					ON [accu].[cuGUID] = [cu].[cuGUID]     
				INNER JOIN [#CustCond] AS [cn] ON [cn].[GUID] = [cu].[cuGUID]  
	end
	else                
	begin
		INSERT INTO [#CustomerTbl]                
			SELECT        
				[accu].[cuGUID],        
				0,        
				[cu].[cuCustomerName],        
				[accu].[acCode],        
				[cu].[cuLatinName],     
				[accu].[acDebit] - [accu].[acCredit],        
				[cu].[cuArea],        
				[cu].[cuStreet],        
				[cu].[cuAccount]         
			FROM        
				[vwCuAc]  as [accu]     
				INNER JOIN [vwCu] As [cu]     
					ON [accu].[cuGUID] = [cu].[cuGUID]     
				INNER JOIN [dbo].[fnGetCustsOfAcc](@CustAccGUID) AS [f]      
					ON [accu].[cuGUID] = [f].[GUID]        
				INNER JOIN [#CustCond] AS [cn] ON [cn].[GUID] = [cu].[cuGUID]  
	--SELECT * FROM #CustomerTbl                
	end
	-----------------------------------                
	INSERT INTO [#CountryTbl]                
	SELECT DISTINCT [CountryName] From [#CustomerTbl] ORDER BY [CountryName]
	-----------------------------------                
	INSERT INTO [#StreetTbl]                
	SELECT  DISTINCT        
		0,        
		[StreetName],
		[CountryName]
	From        
		[#CustomerTbl] ORDER BY [StreetName]
----- Return Result -----  
--------- 1  
SELECT * FROM [#CountryTbl] 
--------- 2  
SELECT        
	[St].[ID],    
	[Co].[ID] AS [CountryID],    
	[St].[Name]    
FROM         
	[#StreetTbl] AS [St]                 
	INNER JOIN [#CountryTbl] AS [Co] ON [Co].[Name] = [St].[CountryName]                
--------- 3            
	INSERT INTO [PalmGUID]  
	SELECT DISTINCT  
		[cu].[ID]  
	FROM  
		[#CustomerTbl] AS [cu] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [cu].[ID]  
	WHERE  
		[pg].[GUID] IS NULL  
if (ISNULL(@CustSortFld, '') <> '')  
begin  
	DECLARE @Str AS [NVARCHAR](2024)    
	SET @Str =  
				'INSERT INTO [#CustResultTbl] SELECT        
					[pg].[Number] AS [ID],        
					[St].[ID] AS [StreetID],        
					[Cu].[Name] AS [Name],  
					[Cu].[Code] AS [Code],  
					[Cu].[LatinName] AS [LatinName],  
					[Cu].[Balance] AS [Balance]  
				From        
					[#CustomerTbl] AS [Cu]                
					INNER JOIN [#StreetTbl] AS [St] ON [Cu].[StreetName] = [St].[Name] AND [Cu].[CountryName] = [St].[CountryName]  
					INNER JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [Cu].[ID]  
					ORDER By [StreetID],'  
	SET @Str = @Str + 'cu.[' + @CustSortFld  + ']'
	EXECUTE (@Str) 	    
end  
else  
	INSERT INTO [#CustResultTbl] SELECT        
		[pg].[Number] AS [ID],        
		[St].[ID] AS [StreetID],        
		[Cu].[Name] AS [Name],        
		[Cu].[Code] AS [Code],        
		[Cu].[LatinName] AS [LatinName],  
		[Cu].[Balance] AS [Balance]  
	From        
		[#CustomerTbl] AS [Cu]                
		INNER JOIN [#StreetTbl] AS [St] ON [Cu].[StreetName] = [St].[Name] AND [Cu].[CountryName] = [St].[CountryName]  
		INNER JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [Cu].[ID]  
	ORDER BY  
		[StreetID]  
INSERT INTO [#CustomerCodeTbl]  
SELECT  
	[r].[Index],  
	[r].[Code]  
FROM  
	[#CustResultTbl] AS [r] 
ORDER BY [r].[Code] 
SELECT * FROM [#CustResultTbl] ORDER BY [Index] 
SELECT [CustIndex] AS [Index], [CustCode] AS [Code] FROM [#CustomerCodeTbl] ORDER BY [CustCode] 
	  
drop table [#CountryTbl]                
drop table [#StreetTbl]                
drop table [#CustomerTbl]                
drop table [#CustResultTbl]                
drop table [#CustomerCodeTbl] 
drop table [#CustCond] 
#########################################################
#END
