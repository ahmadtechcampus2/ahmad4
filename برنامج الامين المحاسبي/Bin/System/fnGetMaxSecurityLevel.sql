##########################################################################################
CREATE FUNCTION fnGetMaxSecurityLevel()
	RETURNS [INT]
AS BEGIN
	RETURN 3
END
###########################################################################
CREATE FUNCTION fnGetMinSecurityLevel()
	RETURNS [INT]
AS BEGIN
	RETURN -2
END
##########################################################################################
#END