##########################################################
CREATE PROCEDURE prcGetTableDefaultValueConstraints

	@TableID BIGINT

AS

SET NOCOUNT ON

SELECT dv.object_id, dv.name, c.ColumnName, dv.definition
FROM #stringColumns c
INNER JOIN sys.default_constraints dv ON c.ColumnID = dv.parent_column_id AND dv.parent_object_id = @TableID
WHERE dv.Type = 'D'
#########################################################
#END