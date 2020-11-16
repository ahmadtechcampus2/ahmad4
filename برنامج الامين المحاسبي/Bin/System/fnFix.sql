################################################################################
CREATE FUNCTION fnFix ( @v AS FLOAT, @ocptr AS uniqueidentifier,
		@ocval AS FLOAT, @ncptr AS uniqueidentifier, @ncval AS FLOAT)
	RETURNS FLOAT
AS
BEGIN
	DECLARE @Val FLOAT

	IF @ocptr = @ncptr
		SET @val = @v / (CASE @ocval WHEN 0.0 THEN 1.0 ELSE @ocval END)
	ELSE
		SET @val = @v / (CASE @ncval WHEN 0.0 THEN 1.0 ELSE @ncval END)

	RETURN @Val
END
######################################################
#END


