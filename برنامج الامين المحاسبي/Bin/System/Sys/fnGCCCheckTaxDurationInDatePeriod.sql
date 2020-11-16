#########################################################
CREATE FUNCTION fnGCCCheckTaxDurationInDatePeriod(@FPDate DATE, @EPDate DATE)
	RETURNS INT
BEGIN
	DECLARE @SubscriptionDate DATE 
	SET @SubscriptionDate = ISNULL((SELECT TOP 1 SubscriptionDate FROM GCCTaxSettings000), @FPDate)

	IF @FPDate < @SubscriptionDate
		SET @FPDate = @SubscriptionDate

	IF (EXISTS (SELECT [GUID] FROM GCCTaxDurations000 WHERE 
			(IsTransfered = 0) AND 
			(StartDate NOT BETWEEN @FPDate AND @EPDate)))
	BEGIN
	     RETURN 0;
	END
	RETURN 1 ;
END
#########################################################
#END