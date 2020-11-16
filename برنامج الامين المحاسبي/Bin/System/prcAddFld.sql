##########################################################################
CREATE PROCEDURE prcAddFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128),
	@Type [NVARCHAR](128)
AS
	SET NOCOUNT ON
	
	DECLARE @Sql AS [NVARCHAR](500)
	SET @Sql =  'prcAddFld: ' + @table + '.' + @column + ' (' + @type + ')'
	EXEC [prcLog] @Sql

	-- assure that the table exists, and the column doesn't:
	IF [dbo].[fnObjectExists](@Table + '.' + @Column) <> 0 OR [dbo].[fnTblExists](@Table) = 0
	BEGIN
		EXEC [prcLog] '-Field Already Exists'
		RETURN 0
	END

	SET @Sql = 'ALTER TABLE [' + @Table + '] ADD [' + @Column + '] ' + @Type
	EXECUTE( @Sql)
	EXEC [prcLog] '-Field Added'
	RETURN 1

##########################################################################
#END