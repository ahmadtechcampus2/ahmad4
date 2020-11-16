################################################################
CREATE FUNCTION fnGetMatFldsStr(
	@Prefix 			[NVARCHAR](10),
	@ShowMtFldsFlag		[BIGINT]
)
RETURNS [NVARCHAR](3000)
BEGIN
--	print ' here'
	DECLARE @FldStr [NVARCHAR](3000)
	--DECLARE @Prefix NVARCHAR(10)
	--SET @Prefix = ' v_mt.'
	DECLARE @Comma [NVARCHAR](1)
	SET @Comma = ','

	SET @FldStr = ''
	
	DECLARE @AddComma [BIT]
	SET @AddComma = 0
	
	IF @ShowMtFldsFlag & 0x00000008 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtBarCode], '''')'
		SET @AddComma = 1
	END
	-- IF @ShowMtFldsFlag & 0x00000010 > 0
	--	SET @FldStr = @FldStr + @Prefix + 'r.mtQty'
	IF @ShowMtFldsFlag & 0x00000020 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([MtUnity], '''')'
		SET @AddComma = 1
	END
	--IF @ShowMtFldsFlag & 0x00000040 > 0
	--	SET @FldStr = @FldStr + @Prefix + 'r.APrice'
	--IF @ShowMtFldsFlag & 0x00000080 > 0 -- grandprice
	--	SET @FldStr = @FldStr + @Prefix + 'r.APrice'
	-- mtType must appear all the time
	--IF @ShowMtFldsFlag & 0x00000100 > 0
	--BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtType], 0)'
		SET @AddComma = 1
	--END
	IF @ShowMtFldsFlag & 0x00000200 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtSpec], '''')'
		SET @AddComma = 1
	END
	IF @ShowMtFldsFlag & 0x00000400 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtDim], '''')'
		SET @AddComma = 1
	END
	IF @ShowMtFldsFlag & 0x00000800 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtOrigin], '''')'
		SET @AddComma = 1
	END
	IF @ShowMtFldsFlag & 0x00001000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtPos],'''')'
		SET @AddComma = 1
	END
	IF @ShowMtFldsFlag & 0x00020000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtCompany], '''')'
		SET @AddComma = 1
	END
	/*	
	--IF @ShowMtFldsFlag & 0x00040000 > 0
	--BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'MtGroup'
		SET @AddComma = 1
	--END
	*/
	IF @ShowMtFldsFlag & 0x00080000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtColor], '''')'
		SET @AddComma = 1
	END

	IF @ShowMtFldsFlag & 0x00100000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtProvenance], '''')'
		SET @AddComma = 1
	END

	IF @ShowMtFldsFlag & 0x00200000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtQuality], '''')'
		SET @AddComma = 1
	END

	IF @ShowMtFldsFlag & 0x00400000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtModel], '''')'
		SET @AddComma = 1
	END

	IF @ShowMtFldsFlag & 0x00800000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtBarCode2], '''')'
		SET @AddComma = 1
	END

	IF @ShowMtFldsFlag & 0x01000000 > 0
	BEGIN
		IF @AddComma = 1
			SET @FldStr = @FldStr + @Comma
		SET @FldStr = @FldStr + @Prefix + 'ISNULL([mtBarCode3], '''')'
		SET @AddComma = 1
	END

	IF @AddComma = 1
		SET @FldStr = @FldStr + @Comma

--	print @FldStr
	RETURN @FldStr

END
/*
SELECT dbo.fnGetMatFldsStr('v_mt.', 242)
	@ShowMtFldsFlag		BIGINT)
exec prcGetMatFldsStr
	'v_mt.',	 --@Prefix 			NVARCHAR(10),
	242 		--@ShowMtFldsFlag		BIGINT

*/
##################################################
#END