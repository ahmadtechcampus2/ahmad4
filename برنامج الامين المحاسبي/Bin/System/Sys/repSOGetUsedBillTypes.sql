################################################################################
## 
CREATE PROC repSOGetUsedBillTypes
	@smGUID [UNIQUEIDENTIFIER]
AS 
SET NOCOUNT ON

SELECT 
	DISTINCT [bu].[buType]
FROM 
	[bi000] [bi] INNER JOIN [vwbu] [bu] ON [bi].[ParentGUID] = [bu].[buGuid] 
WHERE 
	[soGuid] = @smGuid
##########################################################################
CREATE PROC prcIsSOConditionalContractUsed
	@SpecialOfferGUID	UNIQUEIDENTIFIER
AS
	
	DECLARE @maxDate DATETIME
	
	SELECT @maxDate = 
		MAX(sp.ToDate)
	FROM
		SOContractPeriodEntries000 sp
		INNER JOIN ce000 ce ON sp.EntryGuid = ce.[GUID]
		INNER JOIN en000 en ON en.parentGuid = ce.[GUID]
		INNER JOIN SOConditionalDiscounts000 cd ON CAST(cd.[GUID] AS NVARCHAR(64))= en.Class
	WHERE
		cd.SpecialOfferGUID = @SpecialOfferGUID
	
	IF (@maxDate IS NOT NULL)
	BEGIN
		SELECT @maxDate AS MaxFromDate
	END
###################################################################################
#END
