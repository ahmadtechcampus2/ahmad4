##########################################################################
CREATE PROCEDURE prcAddIntFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128),
	@DefVal [NVARCHAR](12) = '0'
AS
	SET NOCOUNT ON
	
	DECLARE
		@Sql AS [NVARCHAR](500),
		@RetVal AS [INT]
		
	SET @Sql = '[INT] NOT NULL DEFAULT ' + ISNULL(@DefVal, '0')
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, @Sql
	IF (@RetVal = 0)
		RETURN 0

	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, '[INT]', 1

	RETURN @RetVal

##########################################################################
#END