#########################################################
CREATE FUNCTION fnBranch_getBitMask(@bit TINYINT)
	RETURNS BIGINT
AS BEGIN
	DECLARE @result BIGINT

	IF @bit NOT BETWEEN 1 AND 63
		SET @result = 0

	ELSE BEGIN
		SELECT
			@result = 1,
			@bit = @bit - 1

		WHILE @bit > 0
		BEGIN
			SET @result = @result * 2
			SET @bit = @bit - 1
		END
	END

	RETURN @result

END

#########################################################
#END