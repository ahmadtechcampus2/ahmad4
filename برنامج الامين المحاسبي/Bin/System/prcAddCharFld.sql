##########################################################################
CREATE PROCEDURE prcAddCharFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128),
	@Size [INTEGER],
	@DefVal [NVARCHAR](MAX) = ''
AS
	SET NOCOUNT ON
	
	DECLARE
		@Type AS [NVARCHAR](100),
		@RetVal AS [INT]
		
	SET @Type = '[NVARCHAR]( ' + CAST(@Size AS [NVARCHAR]) + ') COLLATE ARABIC_CI_AI NOT NULL DEFAULT ''' + ISNULL(@DefVal, '') + ''''
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, @Type
	IF (@RetVal = 0)
		RETURN 0

	SET @Type = '[NVARCHAR]( ' + CAST(@Size AS [NVARCHAR]) + ') '
	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, @Type, 1

	RETURN @RetVal

##########################################################################
#END