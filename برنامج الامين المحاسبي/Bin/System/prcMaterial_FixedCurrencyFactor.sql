#########################################################
CREATE PROCEDURE prcMaterial_FixedCurrencyFactor
	@mtGuid UNIQUEIDENTIFIER,
	@date DATETIME
AS 
	SET NOCOUNT ON 

	DECLARE 
		@cv FLOAT,
		@cg UNIQUEIDENTIFIER 

	SELECT 
		@cg = [CurrencyGUID] 
	FROM 
		[mt000]
	WHERE 
		[GUID] = @mtGuid		

	SET @cv = (SELECT TOP 1 [CurrencyVal] FROM [mh000] WHERE [CurrencyGUID] = @cg AND [Date] <= @date ORDER BY [Date] DESC)

	IF @cv IS NULL
		SET @cv = (SELECT [CurrencyVal] FROM [my000] WHERE [GUID] = @cg)
	
	SELECT 
		[CurrencyVal] / (CASE ISNULL( @cv, 0) WHEN 0 THEN [CurrencyVal] ELSE @cv END) AS [Val] 
	FROM 
		[mt000]
	WHERE 
		[GUID] = @mtGuid
#########################################################
#END
