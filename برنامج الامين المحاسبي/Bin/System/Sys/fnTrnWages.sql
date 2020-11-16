#########################################
CREATE FUNCTION fnTrnWages 
	( @Type AS INT) 
	RETURNS TABLE 
	AS 
		RETURN (SELECT * FROM TrnWages000 WHERE Type = @Type) 
#########################################
#END