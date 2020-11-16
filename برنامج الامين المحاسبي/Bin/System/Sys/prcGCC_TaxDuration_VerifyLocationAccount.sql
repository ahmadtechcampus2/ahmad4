################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyLocationAccount
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())

	-- FIRT RESULT --
	-- Verify location VAT account 
	SELECT 
		CL.VATAccGUID,
		AC.Code + ' - ' +
		CASE @Lang WHEN 0 THEN AC.Name 
				   ELSE CASE AC.LatinName WHEN '' THEN AC.Name 
										  ELSE AC.LatinName END END    AS Account
	FROM
		GCCCustLocations000 CL
		LEFT JOIN ac000 AC ON CL.[GUID] = AC.[GUID]
	WHERE 
		CL.VATAccGUID NOT IN (SELECT VATAccGUID FROM GCCTaxAccounts000)
		AND CL.VATAccGUID <> 0x0

	-- SECOND RESULT --
	-- Verify location Return account 
	SELECT 
		CL.ReturnAccGUID,
		AC.Code + ' - ' +
		CASE @Lang WHEN 0 THEN AC.Name 
				   ELSE CASE AC.LatinName WHEN '' THEN AC.Name 
										  ELSE AC.LatinName END END    AS Account
	FROM
		GCCCustLocations000 CL
		LEFT JOIN ac000 AC ON CL.[GUID] = AC.[GUID]
	WHERE 
		CL.ReturnAccGUID NOT IN (SELECT ReturnAccGUID FROM GCCTaxAccounts000)
		AND CL.ReturnAccGUID <> 0x0
##################################################################################
#END
