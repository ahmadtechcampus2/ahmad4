##########################################################################
CREATE PROCEDURE prcAddFloatFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128),
	@DefVal [FLOAT] = 0
AS
	SET NOCOUNT ON
	
	DECLARE
		@Sql AS [NVARCHAR](1000),
		@RetVal AS [INT]
		
	SET @Sql = '[FLOAT] NOT NULL DEFAULT ' + CAST( ISNULL(@DefVal, N'0') AS [NVARCHAR])
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, @Sql
	IF (@RetVal = 0)
		RETURN 0

	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, '[FLOAT]', 1

	RETURN @RetVal
 
##########################################################################
#END