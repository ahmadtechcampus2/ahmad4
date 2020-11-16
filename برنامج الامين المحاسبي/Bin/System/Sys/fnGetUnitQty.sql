######################################################################################
CREATE FUNCTION  fnGetUnitQty 
(
	@MatGUID AS [UNIQUEIDENTIFIER] ,
	@qty AS [FLOAT],
	@Type AS [INT]
)
RETURNS [FLOAT]
AS
BEGIN
DECLARE
	@firstUnit as [FLOAT],
	@secoundUnit as [FLOAT],
	@therdUnit as [FLOAT]
	
		IF @qty < 0
		SET @qty = 0
		set @therdUnit = (select Round( CASE mtUnit3Fact WHEN 0 THEN 0 ELSE @qty/mtUnit3Fact END ,0,1) from vwMt where mtGUID = @MatGUID)
		set @secoundUnit = (select Round( CASE mtUnit2Fact WHEN 0 THEN 0 ELSE (@qty-(@therdUnit*mtUnit3Fact))/mtUnit2Fact END ,0,1) from vwMt where mtGUID = @MatGUID )
		set @firstUnit = (select @qty-((@secoundUnit*mtUnit2Fact)+(@therdUnit*mtUnit3Fact)) from vwMt where mtGUID = @MatGUID )
	
	RETURN CASE @Type WHEN 1 THEN @firstUnit WHEN 2 THEN @secoundUnit WHEN 3 THEN @therdUnit END
END


######################################################################################
#END
