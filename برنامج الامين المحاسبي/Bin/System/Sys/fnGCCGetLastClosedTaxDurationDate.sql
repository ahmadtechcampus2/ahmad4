#########################################################
CREATE FUNCTION fnGCCGetLastClosedTaxDurationDate()
	RETURNS TABLE 
AS 
	RETURN
		(SELECT MAX(EndDate) AS EndDate FROM GCCTaxDurations000 WHERE State = 1)
#########################################################
CREATE FUNCTION fnGCC_CanModifySubscriptionDate()
	RETURNS BIT
AS BEGIN
	DECLARE @CanModify BIT = 1
	IF EXISTS(SELECT TOP 1 * FROM GCCTaxSettings000 WHERE IsTransfered = 1)
		SET @CanModify = 0
	ELSE BEGIN 
		IF EXISTS(SELECT TOP 1 * FROM bu000 bu INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID WHERE bu.Isposted = 0 AND ISNULL(bi.TaxCode, 0) != 0)
			SET @CanModify = 0
		IF (@CanModify = 1) AND EXISTS(
			SELECT TOP 1 * FROM en000 
			WHERE 
				ISNULL(Type, 0) IN (202 /*SR in GCC*/, 401, 402, 403, 404, 405, 406, 407))
			SET @CanModify = 0
	END

	RETURN @CanModify
END
#########################################################
CREATE FUNCTION fnGCC_CanModifyPaymentsSubscriptionDate()
	RETURNS BIT
AS BEGIN
	DECLARE @CanModify BIT = 1
	IF EXISTS(
		SELECT 
			TOP 1 * 
		FROM 
			en000 en 
			INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
			INNER JOIN er000 er ON ce.GUID = er.EntryGUID
			INNER JOIN py000 py ON py.GUID = er.ParentGUID
			INNER JOIN et000 et ON et.GUID = py.TypeGUID 
		WHERE 
			ISNULL(en.Type, 0) IN (202 /*SR in GCC*/, 401, 402, 403, 404, 405, 406, 407))
		SET @CanModify = 0

	RETURN @CanModify
END
#########################################################
#END
