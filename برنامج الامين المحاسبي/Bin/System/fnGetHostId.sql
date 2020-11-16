#########################################################
CREATE FUNCTION fnGetHostId() 
	RETURNS [NVARCHAR](128) 
AS BEGIN 
	RETURN Host_Id() 
END
#########################################################
#END
