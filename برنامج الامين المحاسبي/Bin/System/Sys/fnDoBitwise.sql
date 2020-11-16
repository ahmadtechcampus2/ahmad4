##################################################################################
CREATE FUNCTION fnDoBitwise(@Mask INT, @Number INT) 
	RETURNS INT
AS BEGIN 
/* 
this function: 
	- Takes two numbers and make bitwise operation between them.
*/ 	
	RETURN (@Mask & POWER(2, @Number))
END
#########################################################
#END