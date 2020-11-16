###############################################################################
CREATE PROC prcCheckDB_GCC_DuplicateSettings
	@Correct INT = 0
AS 
	SET NOCOUNT ON

	DECLARE @IsGCCSystemEnabled INT 
	SET @IsGCCSystemEnabled = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0')
	IF @IsGCCSystemEnabled = 0
		RETURN 
	
	-- GCC Tax Settings 
	IF ((SELECT COUNT(*) FROM GCCTaxSettings000) = 0)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1100, 0x0)
	END

	IF ((SELECT COUNT(*) FROM GCCTaxSettings000) > 1)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1101, 0x0)

		IF @Correct <> 0
		BEGIN 
			;WITH y AS 
			(
				SELECT rn = ROW_NUMBER() OVER (ORDER BY s.SubscriptionDate)
				FROM 
					GCCTaxSettings000 s 
			)
			DELETE y WHERE rn > 1;
		END
	END

	-- GCC Tax Types 
	IF ((SELECT COUNT(*) FROM GCCTaxTypes000) = 0)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1102, 0x0)
	END

	IF EXISTS (SELECT Type, COUNT(*) cnt FROM GCCTaxTypes000 GROUP BY [Type] HAVING COUNT(*) > 1)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1103, 0x0)

		IF @Correct <> 0
		BEGIN 
			;WITH y AS 
			(
				SELECT rn = ROW_NUMBER() OVER (PARTITION BY s.Type ORDER BY s.Number)
				FROM 
					GCCTaxTypes000 s 
			)
			DELETE y WHERE rn > 1;
		END
	END

	-- GCC Tax Codings 
	IF ((SELECT COUNT(*) FROM GCCTaxCoding000) = 0)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1104, 0x0)
	END

	IF EXISTS (SELECT Code, COUNT(*) cnt FROM GCCTaxCoding000 GROUP BY [Code] HAVING COUNT(*) > 1)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1105, 0x0)

		IF @Correct <> 0
		BEGIN 
			;WITH y AS 
			(
				SELECT rn = ROW_NUMBER() OVER (PARTITION BY s.Code ORDER BY s.Number)
				FROM 
					GCCTaxCoding000 s 
			)
			DELETE y WHERE rn > 1;
		END
	END

	-- GCC Tax locations 
	IF ((SELECT COUNT(*) FROM GCCCustLocations000) = 0)
	BEGIN 
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1]) 
			VALUES (0x1106, 0x0)
	END

###########################################################################
#END
