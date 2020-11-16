#########################################################
CREATE PROCEDURE prcPalm_GetUserStores
		@PalmUserName [NVARCHAR](250)			
AS
	SET NOCOUNT ON              	
	
	DECLARE @StoreGUID [uniqueidentifier]
	DECLARE @ExportStoreFlag [bit]
	SELECT @StoreGUID = [StoreGUID], @ExportStoreFlag = [ExportStoreFlag] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName	
	
	CREATE TABLE [#StoreTbl](      
		[Parent] [uniqueidentifier],
		[GUID] [uniqueidentifier],
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI
	)      
	if (@ExportStoreFlag = 1)
		if (@StoreGUID <> 0x0)
		BEGIN
			INSERT INTO [#StoreTbl]
				SELECT
					[st].[stParent],       
					[st].[stGUID],     
					[st].[stName]      
				FROM [vwSt] AS [st] INNER JOIN [dbo].[fnGetStoresList](@StoreGUID) AS [fn] ON [fn].[GUID] = [st].[stGUID]
		END
		ELSE
		BEGIN
			INSERT INTO [#StoreTbl]
				SELECT
					[stParent],       
					[stGUID],     
					[stName]      
				FROM [vwSt] AS [st]
		END
	------------------------------------------		
	INSERT INTO [PalmGUID]
	SELECT DISTINCT
		[st].[GUID]
	FROM
		[#StoreTbl] AS [st] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [st].[GUID]
	WHERE
		[pg].[GUID] IS NULL
	------------------------------------------		
	INSERT INTO [PalmGUID]
	SELECT DISTINCT
		[st].[Parent]
	FROM
		[#StoreTbl] AS [st] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [st].[Parent]
	WHERE
		[pg].[GUID] IS NULL
	------------------------------------------		
	SELECT 
		[pg1].[Number] AS [Parent],
		[pg2].[Number] AS [ID],
		[st].[Name] AS [Name]
	FROM
		[#StoreTbl] AS [st] 
		INNER JOIN [PalmGUID] AS [pg1] ON [pg1].[GUID] = [st].[Parent]
		INNER JOIN [PalmGUID] AS [pg2] ON [pg2].[GUID] = [st].[GUID]		
	ORDER BY
		[Name]
	------------------------------------------
	DROP TABLE [#StoreTbl]
#########################################################
#END