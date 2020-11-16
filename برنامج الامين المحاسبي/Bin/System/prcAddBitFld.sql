##########################################################################
CREATE PROCEDURE prcAddBitFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128),
	@DefVal [INT] = 0
AS
	SET NOCOUNT ON
	
	DECLARE
		@Sql AS [NVARCHAR](500),
		@RetVal AS [INT]
		
	SET @Sql = '[BIT] NOT NULL DEFAULT ' + CAST( ISNULL(@DefVal, N'0') AS [NVARCHAR])
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, @Sql
	IF (@RetVal = 0)
		RETURN 0

	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, '[BIT]', 1

	RETURN @RetVal

##########################################################################
#END