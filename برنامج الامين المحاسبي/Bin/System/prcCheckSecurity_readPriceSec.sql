#################################################
CREATE PROC prcCheckSecurity_readPriceSec
	@result [NVARCHAR](128) = '#result',
	@secViol [NVARCHAR](128) = '#secViol',
	@violTypeID [INT]
AS
	SET NOCOUNT ON 
	
	DECLARE
		@SQL [NVARCHAR](2000),
		@flds [NVARCHAR](2000)

	IF EXISTS(SELECT * FROM [#fields] WHERE [name] = 'security') AND EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'userReadPriceSecurityFieldName')
	BEGIN
		SET @flds = ''
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buTotal')		SET @flds = @flds + 'buTotal = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buTotalDisc')	SET @flds = @flds + 'buTotalDisc = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buTotalExtra')	SET @flds = @flds + 'buTotalExtra = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buItemsDisc')	SET @flds = @flds + 'buItemsDisc = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buBonusDisc')	SET @flds = @flds + 'buBonusDisc = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buFirstPay')	SET @flds = @flds + 'buFirstPay = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buProfits')		SET @flds = @flds + 'buProfits = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'buVAT')		SET @flds = @flds + 'buVAT = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biPrice')		SET @flds = @flds + 'biPrice = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biDiscount')	SET @flds = @flds + 'biDiscount = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biBonusDisc')	SET @flds = @flds + 'biBonusDisc = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biExtra')		SET @flds = @flds + 'biExtra = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biProfits')		SET @flds = @flds + 'biProfits = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'biVAT')		SET @flds = @flds + 'biVAT = 0,'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBuTotal')		SET @flds = @flds + 'FixedBuTotal = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBuTotalDisc')		SET @flds = @flds + 'FixedBuTotalDisc = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBuTotalExtra')		SET @flds = @flds + 'FixedBuTotalExtra = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedbuItemsDisc')		SET @flds = @flds + 'FixedbuItemsDisc = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedbuFirstPay')		SET @flds = @flds + 'FixedbuFirstPay = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiTotal')		SET @flds = @flds + 'FixedBiTotal = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiPrice')		SET @flds = @flds + 'FixedBiPrice = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedbiUnitPrice')		SET @flds = @flds + 'FixedbiUnitPrice = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedbiUnitDiscount')		SET @flds = @flds + 'FixedbiUnitDiscount = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedbiUnitExtra')		SET @flds = @flds + 'FixedbiUnitExtra = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiDiscount')		SET @flds = @flds + 'FixedBiDiscount = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiBonusDisc')		SET @flds = @flds + 'FixedBiBonusDisc = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiExtra')		SET @flds = @flds + 'FixedBiExtra = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiVAT')		SET @flds = @flds + 'FixedBiVAT = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBiProfits')		SET @flds = @flds + 'FixedBiProfits = 0'
		IF EXISTS(SELECT * FROM [#fields] WHERE [Name] = 'FixedBuVAT')		SET @flds = @flds + 'FixedBuVAT = 0'

		IF @flds <> ''
		BEGIN
			SET @SQL = '
				UPDATE '+ @result +' SET ' + LEFT(@flds, LEN(@flds) - 1) + ' WHERE [security] > [userReadPriceSecurityFieldName]
				INSERT INTO ' + @secViol + ' SELECT ' + CAST(@violTypeID AS [NVARCHAR](7)) + ', COUNT(*) FROM '+ @result +' WHERE [security] > [userReadPriceSecurityFieldName]'
			EXEC (@SQL)
		END
	END

#################################################
#END