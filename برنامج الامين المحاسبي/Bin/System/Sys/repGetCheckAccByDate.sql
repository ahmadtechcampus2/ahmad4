##########################################################################
CREATE PROC repGetCheckAccByDate
	@AccGuid [UNIQUEIDENTIFIER],
	@CostGuid [UNIQUEIDENTIFIER] = 0x0,
	@date [DATETIME],
	@CustGuid [UNIQUEIDENTIFIER] 
AS 
	SET NOCOUNT ON;  

	CREATE TABLE [#CustTbl] ([GUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO  [#CustTbl] EXEC [dbo].[prcGetCustsList] @CustGUID, @AccGUID, 0x0
	IF @CustGUID = 0x0
		INSERT INTO  [#CustTbl] SELECT 0x0, 0 

	IF @CostGuid = 0X0 
		SELECT  
			[checkac].[guid]
		FROM  
			[CHECKACC000] [checkac]
			INNER JOIN [dbo].[fnGetAccountsList]( @AccGUID, DEFAULT) [fn] ON [fn].[GUID] = [checkac].[accGuid]
			INNER JOIN [#CustTbl] [cu] ON [cu].[GUID] = [checkac].[CustGUID]
			LEFT JOIN [vwco] [co] ON [co].[coGuid] = [checkac].[CostGuid]
		WHERE
			[CheckedToDate] = @date AND [checkac].[CostGUID] = 0x0 
	ELSE 
		SELECT  
			[checkac].[guid]
		FROM  
			[CHECKACC000] [checkac]
			INNER JOIN [dbo].[fnGetAccountsList]( @AccGUID, DEFAULT) [fn] ON [fn].[GUID] = [checkac].[accGuid]
			INNER JOIN [#CustTbl] [cu] ON [cu].[GUID] = [checkac].[CustGUID]
		WHERE
			[CheckedToDate] = @date AND [checkac].[CostGUID] = @CostGuid
			
###############################################################################
#END
