##########################################################################
CREATE PROCEDURE prcAddGUIDFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	SET NOCOUNT ON
	
	DECLARE @RetVal AS [INT]
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, '[UNIQUEIDENTIFIER] NOT NULL DEFAULT 0x0'
	IF (@RetVal = 0)
		RETURN 0

	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, 'UNIQUEIDENTIFIER', 1

	RETURN @RetVal

##########################################################################
#END