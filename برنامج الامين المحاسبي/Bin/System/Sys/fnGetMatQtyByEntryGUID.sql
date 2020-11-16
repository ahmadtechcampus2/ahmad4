##################################################################################
CREATE FUNCTION fnGetMatQtyByEntryGUID
(
	@ceGUID UNIQUEIDENTIFIER,
	@mtGUID UNIQUEIDENTIFIER
)
RETURNS FLOAT
AS
BEGIN
	DECLARE @ResultVar AS FLOAT

	IF (@ceGUID <> 0x0)
	BEGIN
		SELECT @ResultVar = vbi.biBillQty
		FROM 
			er000 er
			inner join vwExtended_bi vbi on er.ParentGUID = vbi.buGuid
		WHERE
			EntryGUID = @ceGUID
			AND
			vbi.biMatPtr = @mtGUID
	END
	ELSE
	BEGIN
		SET @ResultVar = 0
	END
	IF (@ResultVar IS NULL)
	BEGIN
		SET @ResultVar = 0
	END

	RETURN @ResultVar
END
##################################################################################
#END
