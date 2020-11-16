#########################################################
CREATE PROCEDURE prcCheckDB_bu_IsPosted
	@Correct [INT] = 0
AS

	-- Posted without entries while bill type auto-generates entry:
	IF @Correct <> 1
	begin
		INSERT INTO [ErrorLog]([Type], [g1]) 
		SELECT 
			0x30E, 
			[bu].[GUID]
		FROM 
			(SELECT [bill].* FROM [bu000] AS [bill] INNER JOIN [bt000] AS [bt] on [bill].[TypeGUID] = [bt].[GUID] WHERE [bt].[bAutoEntry] <> 0) [Bu] 
			LEFT JOIN [vwEr_EntriesBills] [er] on [bu].[GUID] = [er].[erBillGUID]
			left JOIN [ce000] [ce] on [er].[erEntryGuid] = [ce].[Guid] 	
		WHERE 
			[bu].[IsPosted] <> 0 AND [bu].[Total] <> 0 
			AND ( [er].[erBillGUID] IS NULL OR [ce].[GUID] IS NULL)
	end
#########################################################
#END