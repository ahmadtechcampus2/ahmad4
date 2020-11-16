#########################################################################
CREATE FUNCTION fnGetSourcesType( @SrcGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS
	RETURN (
		SELECT [GUID], [Security] FROM [dbo].[fnGetBillsTypesList] ( @SrcGuid, NULL) 
		UNION ALL
		SELECT [GUID], [Security] FROM [dbo].[fnGetEntriesTypesList] ( @SrcGuid, NULL) 
		UNION ALL
		SELECT [GUID], [Security] FROM [dbo].[fnGetCollectNotesTypesList] ( @SrcGuid, NULL) 
		UNION ALL
		SELECT [GUID], [Security] FROM [dbo].[fnGetNotesTypesList] ( @SrcGuid, NULL) 
	)
############################################################################
#END