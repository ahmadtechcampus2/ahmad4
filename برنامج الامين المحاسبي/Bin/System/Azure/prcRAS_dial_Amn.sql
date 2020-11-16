###############################
CREATE procedure prcRAS_dial_Amn
	@entry nvarchar(255) = '',
	@showDlg bit = 0,
	@dlgCaption nvarchar(128) = ''
as
	EXECUTE prcNotSupportedInAzure
##############################
#END 