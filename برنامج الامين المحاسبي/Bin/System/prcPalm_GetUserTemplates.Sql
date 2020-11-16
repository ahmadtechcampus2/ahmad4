#########################################################
CREATE PROCEDURE prcPalm_GetUserTemplates
	@PalmUserName [NVARCHAR](250) 
AS 
	SET NOCOUNT ON               
	DECLARE @ProfileGUID  [uniqueidentifier] 
	SELECT @ProfileGUID = [GUID] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName 
	 
	CREATE TABLE [#TemplateTbl](       
		[Type] [int],        
		[ID] [uniqueidentifier],       
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI,       
		[LatinName] [NVARCHAR](255)  COLLATE Arabic_CI_AI,       
		[bIsOutput] [int], 
		[DefPrice] [int],
		[bPrintReceipt] [int]
	)               
	 
	INSERT INTO  [#TemplateTbl] 
		SELECT 
			1 , 
			[bt].[btGUID] AS [ID], 
			[bt].[btName], 
			[bt].[btLatinName],    
			[bt].[btIsOutput], 
			[bt].[btDefPrice],
			[bt].[btPrintReceipt]
		FROM        
			[vwBt] AS [bt] INNER JOIN [vwPd] AS [pd] ON [bt].[btGUID] = [pd].[RefGUID]
		WHERE                
			[bt].[btType] =  1 AND 
			[pd].[RefType] = 1 AND	--Bill Types 
			[pd].[ProfileGUID] = @ProfileGUID 
	 
	 
	INSERT INTO  [#TemplateTbl]         
		SELECT       
			2,       
			[et].[etGUID] AS [ID],       
			[et].[etName],     
			[et].[etLatinName],    
			0, 
			0,
			0
		FROM        
			[vwEt] AS [et] INNER JOIN [vwPd] AS [pd] ON [et].[etGUID] = [pd].[RefGUID]
		WHERE                
			[pd].[RefType] = 2 AND				--Entry Types 
			[pd].[ProfileGUID] = @ProfileGUID	--This PAlm 
	INSERT INTO [PalmGUID] 
	SELECT DISTINCT 
		[tm].[ID]
	FROM 
		[#TemplateTbl] AS [tm] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [tm].[ID]
	WHERE 
		[pg].[GUID] IS NULL 

	SELECT  
		[Type], 
		pg.[Number] AS [ID], 
		[Name], 
		[LatinName], 
		[bIsOutput], 
		[DefPrice],
		[bPrintReceipt]
	 FROM  
		[#TemplateTbl] AS [tm]  
		INNER JOIN [PalmGUID] as [pg] ON [pg].[GUID] = [tm].[ID]
	ORDER BY [Type] ASC, [bIsOutput] DESC, [Name] ASC 

	SELECT TOP 1 * FROM [vwPl] WHERE [PalmUserName] = @PalmUserName 
	DROP TABLE [#TemplateTbl] 
#########################################################
#END