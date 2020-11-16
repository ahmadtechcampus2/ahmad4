###########################################################################
CREATE FUNCTION fnGetAcDescList(@GUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT * FROM [fnGetAccountsList](@GUID, DEFAULT))

###########################################################################
CREATE FUNCTION fnGetAccountsListByFinal( @AccGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI)  
AS 
BEGIN 
	IF((SELECT COUNT(*) FROM ac000 WHERE GUID = @AccGUID AND TYPE = 2) > 0)
	BEGIN
		DECLARE @Level INT SET @Level = 0
		INSERT INTO @Result SELECT GUID, @Level, '' 
		FROM ac000
		WHERE FinalGUID = @AccGUID AND ISNULL(ParentGUID, 0x0) = 0x0
		
		DECLARE @RowCount INT SET @RowCount = 10
		WHILE @RowCount > 0
		BEGIN
			INSERT INTO @Result (GUID, Level, Path)
			SELECT AC.GUID, @Level + 1, '' 
			FROM @Result FAC INNER JOIN ac000 AC ON AC.ParentGUID = FAC.GUID 
			WHERE FAC.Level = @Level

			SET @RowCount = @@ROWCOUNT
			SET @Level = @Level + 1
		END
	END
	ELSE
		INSERT INTO @Result SELECT * FROM [fnGetAccountsList](@AccGUID, DEFAULT) 
	RETURN
END
###########################################################################
#END