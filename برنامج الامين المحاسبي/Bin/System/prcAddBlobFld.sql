##########################################################################
CREATE PROCEDURE prcAddBlobFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	SET NOCOUNT ON
	
	DECLARE
		@Sql AS [NVARCHAR](500),
		@RetVal AS [INT]
		
	SET @Sql = '[NTEXT] DEFAULT NULL'
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, @Sql
	RETURN @RetVal

##########################################################################
#END