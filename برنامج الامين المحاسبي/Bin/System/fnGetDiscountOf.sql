
CREATE FUNCTION fnGetDiscountOf(@Total AS [FLOAT], @Ratio AS [FLOAT])
RETURNS [FLOAT]
AS 
BEGIN
	IF @Ratio = 0.0
		RETURN 0
	IF @Ratio > 100
		SET @Ratio = 100

	DECLARE @d  [FLOAT]
	DECLARE @DivideDisc  [INT]
	 SELECT @DivideDisc = [opValue] FROM [vwOp] WHERE [opName] = 'AmnCfg_DivideDiscount'

	IF @DivideDisc  > 0 
	BEGIN
		SET @d = @Total / (100.0 + @Ratio) * 100
		RETURN  @Total - @d
	END

	RETURN @Total * @Ratio / 100.0
END


/*

DECLARE @Disc Float
SET @Disc =  dbo.fnGetDiscountOf(5000, 10)
print @Disc

*/