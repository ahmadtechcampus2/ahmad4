################################################################################
CREATE PROC prcGetTabelsSchema 
AS
	SET NOCOUNT ON

	SELECT DISTINCT T.type AS ObjectType, C.Name, C.user_type_id, C.Column_Id AS ID, 
		C.max_length AS Size, C.Precision, C.Scale, ISNULL(C.Collation_Name,'') as Collation, 
		C.Is_nullable AS IsNullable, C.Is_RowGuidcol AS IsRowGuid, C.Is_Computed AS IsComputed, 
		C.Is_Identity AS IsIdentity, ISNULL(TT.Name, T.Name) AS TableName, T.object_id AS TableId, 
		S1.name AS TableOwner, OBJECTPROPERTY(T.OBJECT_ID, 'TableHasClustIndex') AS HasClusteredIndex
	FROM sys.columns C
		INNER JOIN sys.objects T ON T.object_id = C.object_id
		INNER JOIN sys.types TY ON TY.user_type_id = C.user_type_id
		LEFT JOIN sys.table_types TT ON TT.type_table_object_id = C.object_id
		LEFT JOIN sys.tables TTT ON TTT.object_id = C.object_id
		LEFT JOIN sys.schemas S1 ON (S1.schema_id = TTT.schema_id and T.type = 'U') OR (S1.schema_id = TT.schema_id and T.type = 'TT')
		LEFT JOIN sys.computed_columns CC ON CC.column_id = C.column_Id AND C.object_id = CC.object_id
		LEFT JOIN sys.default_constraints DC ON DC.parent_object_id = T.object_id AND parent_column_id = C.Column_Id
	WHERE T.type IN ('U','TT')
	ORDER BY ISNULL(TT.Name,T.Name),T.object_id,C.column_id
################################################################################
CREATE PROC prcGetTabelsIndexes
AS
	SET NOCOUNT ON

	SELECT t.name tableName, c.name ColumnName, c.is_nullable IsNullable, idx.index_id indexId, ic.column_id columnId,
		idx.is_primary_key IsPrimary, idx.type, idx.name, is_included_column isIncluded, 
		count(idx.index_id) over (partition by idx.name) ColumnsCount 
	FROM sys.objects T
		INNER JOIN sys.columns c on c.object_id = t.object_id
		INNER JOIN sys.index_columns IC ON IC.object_id = T.object_id AND IC.column_Id = C.column_Id
		INNER JOIN sys.indexes IDX ON IDX.object_id = T.object_id AND IDX.index_id = IC.index_id 
	WHERE T.type IN ('U', 'TT')
	ORDER BY t.object_id, idx.index_id
################################################################################
CREATE PROC prcGetDisabledTriggers
AS
	SET NOCOUNT ON

	SELECT t.name tableName, tr.name triggerName
	FROM sys.triggers tr INNER JOIN sys.objects t on t.object_id = tr.parent_id 
	WHERE is_disabled = 1 AND T.type IN ('U', 'TT')
################################################################################
#END