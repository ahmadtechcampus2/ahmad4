###############################################################################
CREATE PROC prcCheckDB_GCC_DuplicateCustomersTax
	@Correct [INT] = 0
AS 
	SET NOCOUNT ON

	DECLARE @IsGCCSystemEnabled INT 
	SET @IsGCCSystemEnabled = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0')
	IF @IsGCCSystemEnabled = 0
		RETURN 

	IF EXISTS (SELECT * FROM GCCCustomerTax000 GROUP BY CustGUID, TaxType, TaxCode HAVING COUNT(*) > 1)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1], [c1]) 
			SELECT DISTINCT 
				0x1130, cu.GUID, cu.CustomerName 
			FROM 
				GCCCustomerTax000 t
				INNER JOIN cu000 cu ON cu.GUID = t.CustGUID
			GROUP BY cu.GUID, t.TaxType, t.TaxCode, cu.CustomerName HAVING COUNT(*) > 1	

		IF @Correct <> 0
		BEGIN 
			;WITH y AS 
			(
				SELECT rn = ROW_NUMBER() OVER (PARTITION BY CustGUID, TaxType, TaxCode ORDER BY GUID)
				FROM 
					GCCCustomerTax000 s 
			)
			DELETE y WHERE rn > 1;
		END
	END
###########################################################################
#END
