##################################################################
CREATE FUNCTION fnGetDirection(@InOutMode [INT], @buDirection [INT])
	RETURNS [INT]
AS BEGIN
/*
this function is used to convert bu direction to support
user defined directions, following these rules:
	@InOutMode = 0 ->	INPUT +, OUTPUT +
	@InOutMode = 1 ->	INPUT +, OUTPUT -	(which defaults to buDirection)
	@InOutMode = 2 ->	INPUT -, OUTPUT +	(which defaults to -buDirection)
*/

	RETURN
		CASE @InOutMode
			WHEN 1 THEN @buDirection
			WHEN 2 THEN -@buDirection
			ELSE 1
		END
END
###################################################
#END