#########################################################
CREATE PROC prcSegmentation_Composition_Enable 
	@IncludeCompositionInMatName INT = 2 
AS  
	DECLARE
		@sqlCommand NVARCHAR(max);
		
	SET @IncludeCompositionInMatName = CASE @IncludeCompositionInMatName WHEN 2 THEN (SELECT CAST(Value AS INT) FROM op000 WHERE name = 'AmnCfg_IncludeCompositionInMatName') ELSE @IncludeCompositionInMatName END ;
	IF @IncludeCompositionInMatName = 1
	BEGIN
	DECLARE @excluded_columns TABLE (name SYSNAME)
	DECLARE @table_name SYSNAME
	DECLARE @columns NVARCHAR(MAX)

	SET @table_name = 'MT000'

	-- Excluded columns
	INSERT INTO @excluded_columns VALUES ('Number')
	INSERT INTO @excluded_columns VALUES ('Name')
	INSERT INTO @excluded_columns VALUES ('Code')
	INSERT INTO @excluded_columns VALUES ('LatinName')

	SET @columns = ''
		SELECT @columns = @columns + ', ' + QUOTENAME(name)
		FROM sys.columns
		WHERE object_id = OBJECT_ID(@table_name)
		AND name NOT IN(select name from @excluded_columns)

	SET @columns = RIGHT(@columns, LEN(@columns) - 2)
	SET @sqlCommand ='
			ALTER view vsmt
			AS
				SELECT Number,
				Name + CASE WHEN PARENT != 0X0 THEN + ''('' + CompositionName + '')''
					ELSE  '''' END AS Name, 
					Code,
				LatinName + CASE WHEN PARENT != 0X0 THEN CASE WHEN (CompositionLatinName = '''' OR CompositionLatinName = ''-'' ) THEN '''' ELSE + ''('' + CompositionLatinName + '')'' END 
					ELSE  '''' END AS LatinName , ' + @columns + ' FROM vbmt' ;
			END
		ELSE
		BEGIN
			SET @sqlCommand ='ALTER VIEW vsmt AS SELECT * FROM vbmt'
		END
	EXEC (@sqlCommand)
#########################################################
#END