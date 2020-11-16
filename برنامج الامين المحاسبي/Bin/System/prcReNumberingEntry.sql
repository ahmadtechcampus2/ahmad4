##########################################################
CREATE PROC prcReNumberingEntry
AS  
	SET NOCOUNT ON
	
	BEGIN Tran
	CREATE TABLE [#Ce]( [GUID] [UNIQUEIDENTIFIER], [NewNumber] [INT] IDENTITY (1,1) NOT NULL PRIMARY KEY)
	INSERT INTO [#Ce]([GUID]) SELECT [GUID] FROM [ce000] ORDER BY [Date]
	------------------------------------ 
	-- UPDATE CE
	------------------------------------ 
	EXEC prcDisableTriggers 'ce000'
	UPDATE [ce000] 
		SET [ce000].[Number] = [ce].[NewNumber]
	FROM  
		[#Ce] AS [ce] INNER JOIN [ce000]
		ON [ce].[GUID] = [ce000].[GUID]
	ALTER TABLE [ce000] ENABLE TRIGGER ALL 
	-------------------------------------------------------------------------------------------------- 
	COMMIT Tran 
##########################################################
#END