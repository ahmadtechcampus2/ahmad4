#########################################################
CREATE PROCEDURE prcDropFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	SET NOCOUNT ON 

	DECLARE @Sql AS [NVARCHAR](500)
	SET @Sql = 'prcDropFld: ' + @Table + '.' + @Column
	EXECUTE [prcLog] @Sql

	IF [dbo].[fnObjectExists](@Table + '.' + @Column) <> 0 AND [dbo].[fnTblExists](@Table) <> 0
	BEGIN

		EXECUTE [prcDropFldIndex] @Table, @Column
		EXECUTE [prcDropFldConstraints] @Table, @Column

		SET @Sql = 'ALTER TABLE ' + @Table + ' DROP COLUMN ' + @Column
		EXECUTE (@Sql)
	END

#########################################################
#END