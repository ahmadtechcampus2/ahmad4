################################################################
CREATE PROCEDURE prcGetExpMatList
	@From		[NVARCHAR](255) = '',
	@TO			[NVARCHAR](255) ='',
	@MatType 	[INT] = -1,
	@CondGuid	[UNIQUEIDENTIFIER] = 0x00
AS
	SET NOCOUNT ON
	DECLARE @Sql [NVARCHAR](max)
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		0X0, 0X0 ,@MatType,@CondGuid,0
	
	SET  @Sql = ' SELECT mtAll.[GUID], mtAll.[GroupGuid] FROM mt000 AS mtAll INNER JOIN [#MatTbl] AS [mt2] ON [mt2].[MatGUID] = mtAll.[GUID] INNER JOIN (SELECT [mt].[GUID] AS GUID FROM [MT000] AS [mt] INNER JOIN [#MatTbl] AS [mt1] ON [mt].[GUID] = [mt1].[MatGUID] AND [mt].[Parent] = 0x00 '
	IF @From <> ''
		SET  @Sql = @Sql + ' WHERE [mt].[Code] >= '+'''' + @From +''''
	IF @TO	<> ''
 	BEGIN
		IF @From = ''
			SET  @Sql = @Sql + ' WHERE '
		ELSE
			SET  @Sql = @Sql + ' AND '
		SET  @Sql = @Sql + '  [mt].[Code] <= ' ++'''' + @To +''''
		
	END
	SET  @Sql = @Sql + ' ) AS matCode ON matCode.GUID = mtAll.GUID OR matCode.GUID = mtAll.Parent ORDER BY  [mtAll].[Number], [mtAll].[Guid]'

	EXEC (@SQL)
/*
PRCCONNECTIONS_ADD2 'ãÏíÑ'
EXEC prcGetExpMatList

*/
##############################################################################
#END 