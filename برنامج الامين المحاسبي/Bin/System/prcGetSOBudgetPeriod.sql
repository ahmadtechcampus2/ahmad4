#######################################################################################
CREATE PROCEDURE prcGetSOBudgetPeriod
	@SpecialOfferGuid UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT
		[GUID],
		Number,
		PeriodGuid,
		Budget,
		(SELECT SUM(discount) FROM bi000 WHERE SOGuid = sop.[GUID]) Applied
	FROM 
		SOPeriodBudgetItem000 sop
	WHERE 
		specialofferguid = @SpecialOfferGuid
	ORDER BY 
		Number
#######################################################################################
#END
