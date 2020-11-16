#########################################################
CREATE FUNCTION fnGetHostName() 
	RETURNS [NVARCHAR](128) 
AS BEGIN 
	RETURN Host_Name() 
END 
#########################################################
#END
