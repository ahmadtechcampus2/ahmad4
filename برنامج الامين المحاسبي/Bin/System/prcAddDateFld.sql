##########################################################################
CREATE PROCEDURE prcAddDateFld
	@Table [NVARCHAR](128),
	@Column [NVARCHAR](128)
AS
	SET NOCOUNT ON
	
	DECLARE @RetVal AS [INT]
	EXECUTE @RetVal = [prcAddFld] @Table, @Column, '[DATETIME] NOT NULL DEFAULT ''1/1/1980'''
	IF (@RetVal = 0)
		RETURN 0

	EXECUTE @RetVal = [prcAlterFld] @Table, @Column, '[DATETIME]', 1

	RETURN @RetVal
 
##########################################################################
#END