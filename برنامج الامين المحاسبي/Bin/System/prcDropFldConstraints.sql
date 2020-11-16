#########################################################
CREATE PROCEDURE prcDropFldConstraints
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	DECLARE @DF AS [NVARCHAR](128)
	DECLARE @c CURSOR
	DECLARE @SQL NVARCHAR(250)
	
	SET @SQL = 'prcDropFldConstraints: ' + @Table + '.' + @Column
	EXECUTE [prcLog] @SQL

	-- remove the Full Brackets if any:
	SET @Column = REPLACE(REPLACE(@Column, ']', ''), '[', '')

	-- Dropping defaults and constraints
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			CONST.name 
		FROM 
			[sys].[objects] AS OBJ INNER JOIN [sys].[columns] COL ON COL.[object_id] = OBJ.[object_id]
			INNER JOIN [sys].[default_constraints] AS CONST ON CONST.[parent_column_id] = COL.[column_id] AND CONST.[parent_object_id] = OBJ.[object_id]
		WHERE 
			OBJ.[object_id] = object_id(@Table) AND COL.[name] = @Column

	OPEN @c FETCH FROM @c INTO @DF

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC ('ALTER TABLE ' + @Table + ' DROP CONSTRAINT ' + @DF)
		FETCH FROM @c INTO @DF
	END

	-- Dropping indexes
	SET @c = CURSOR FAST_FORWARD FOR 
		SELECT 
			[name] 
		FROM 
			[sys].[indexes] AS i INNER JOIN [sys].[index_columns] AS k ON i.object_id = k.object_id AND i.[index_id] = k.[index_id]
		WHERE 
			OBJECT_ID( @Table) = i.[object_id] AND 
			COL_NAME( k.[object_id], k.[column_id]) = @Column AND
			[name] NOT LIKE '_WA_Sys%'

	OPEN @c FETCH FROM @c INTO @DF

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC ('DROP INDEX [dbo].[' + @Table + '].[' + @DF + ']')
		FETCH FROM @c INTO @DF
	END

	CLOSE @c DEALLOCATE @c

#########################################################
#END