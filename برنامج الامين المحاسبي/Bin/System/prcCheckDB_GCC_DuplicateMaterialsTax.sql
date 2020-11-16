###############################################################################
CREATE PROC prcCheckDB_GCC_DuplicateMaterialsTax
	@Correct [INT] = 0
AS 
	SET NOCOUNT ON

	DECLARE @IsGCCSystemEnabled INT 
	SET @IsGCCSystemEnabled = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0')
	IF @IsGCCSystemEnabled = 0
		RETURN 

	IF EXISTS (SELECT * FROM GCCMaterialTax000 GROUP BY MatGUID, TaxType, TaxCode HAVING COUNT(*) > 1)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2]) 
			SELECT DISTINCT 0x1120, mt.GUID, mt.Code, mt.Name
			FROM 
				GCCMaterialTax000 t 
				INNER JOIN mt000 mt ON mt.GUID = t.MatGUID
			GROUP BY mt.GUID, t.TaxType, t.TaxCode, mt.Code, mt.Name HAVING COUNT(*) > 1	

		IF @Correct <> 0
		BEGIN 
			;WITH y AS 
			(
				SELECT rn = ROW_NUMBER() OVER (PARTITION BY MatGUID, TaxType, TaxCode ORDER BY GUID)
				FROM 
					GCCMaterialTax000 s 
			)
			DELETE y WHERE rn > 1;
		END
	END
###########################################################################
#END
