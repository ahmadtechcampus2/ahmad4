##########################################################################
CREATE PROCEDURE prcAddROWGUIDCOLFld
	@Table [NVARCHAR](128)
AS
	SET NOCOUNT ON
	
	DECLARE @RetVal AS [INT]
	EXECUTE @RetVal = [prcAddFld] @Table, 'GUID', '[UNIQUEIDENTIFIER] ROWGUIDCOL NOT NULL DEFAULT (NEWID())'
	RETURN @RetVal

##########################################################################
#END