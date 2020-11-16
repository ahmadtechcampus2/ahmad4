#########################################################
CREATE PROCEDURE prcPalm_GetUserCosts
	@PalmUserName [NVARCHAR](250)
AS
	SET NOCOUNT ON

	DECLARE @CostGUID [uniqueidentifier]
	DECLARE @ExportCostsFlag [bit]
	SELECT @CostGUID = [CostGUID], @ExportCostsFlag = [ExportCostsFlag] FROM [vwPl] WHERE [PalmUserName] = @PalmUserName

	CREATE TABLE [#CostTbl](      
		[Parent] [uniqueidentifier],
		[GUID] [uniqueidentifier],
		[Name] [NVARCHAR](255)  COLLATE Arabic_CI_AI
	)      
	if (@ExportCostsFlag = 1)
		if (@CostGUID <> 0x0)
		BEGIN
			INSERT INTO [#CostTbl]
				SELECT
					[co].[coParent],
					[co].[coGUID],
					[co].[coName]
				FROM [vwCo] AS [co] INNER JOIN [dbo].[fnGetCostsList](@CostGUID) AS [fn] ON [fn].[GUID] = [co].[coGUID]
		END
		ELSE
		BEGIN
			INSERT INTO [#CostTbl]
				SELECT
					[coParent],       
					[coGUID],     
					[coName]      
				FROM [vwCo] AS [Co]
		END
	------------------------------------------
	INSERT INTO [PalmGUID]
	SELECT DISTINCT
		[co].[GUID]
	FROM
		[#CostTbl] AS [co] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [co].[GUID]
	WHERE
		[pg].[GUID] IS NULL
	------------------------------------------		
	INSERT INTO [PalmGUID]
	SELECT DISTINCT
		[co].[Parent]
	FROM
		[#CostTbl] AS [co] LEFT JOIN [PalmGUID] AS [pg] ON [pg].[GUID] = [co].[Parent]
	WHERE
		[pg].[GUID] IS NULL
	------------------------------------------		
	SELECT 
		[pg1].[Number] AS [Parent],
		[pg2].[Number] AS [ID],
		[co].[Name] AS [Name]
	FROM
		[#CostTbl] AS [co] 
		INNER JOIN [PalmGUID] AS [pg1] ON [pg1].[GUID] = [co].[Parent]
		INNER JOIN [PalmGUID] AS [pg2] ON [pg2].[GUID] = [co].[GUID]		
	ORDER BY
		[Name]

	DROP TABLE [#CostTbl]
	
#########################################################
#END