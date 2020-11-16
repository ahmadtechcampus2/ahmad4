#########################################################
CREATE   proc PrcGetBtTree  @LANG [INT] = 0
AS
SET NOCOUNT ON
CREATE TABLE [#T]
(
	[GUID] [UNIQUEIDENTIFIER],
	[Name] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
	[MenuName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
	[type] [int],
	[Billtype] [int],
	[Level] [int]
)
INSERT INTO [#T]
	SELECT CAST (0x0 AS [UNIQUEIDENTIFIER]) [Guid], 
				 '' [Name],
				 CASE @LANG WHEN 0 THEN   [MenuName] ELSE [MenuLatinName] END [MenuName],
				 [type], 
 				 [BillType],
				 1
  FROM [bt000]
	WHERE  ( ISNULL([MenuName],'') <> '') OR (ISNULL([MenuLatinName],'')<>'' )
SELECT * FROM  [#T]
UNION 
SELECT [Guid], 
			 [Name],
			 CASE @LANG WHEN 0 THEN  [MenuName] ELSE  [MenuLatinName] END [MenuName],
			 [Type], 
			 [BillType],
			 Case ISNULL([MenuName] + [MenuLatinName],'') WHEN '' Then 1 else 2 END [Level]
FROM [Bt000]
order by [BillType], [MenuName] DESC
DROP TABLE [#T]
#########################################################
#END