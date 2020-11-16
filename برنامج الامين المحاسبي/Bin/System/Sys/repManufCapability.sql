###########################################################
###ÅãßÇäíÇÊ ÇáÊÕäíÚ ÇáäÙÑíÉ
CREATE PROCEDURE repManufCapability
	@RawMaterialGUID	uniqueidentifier,
	@FormGUID			uniqueidentifier,
	@StoreGUID			uniqueidentifier
AS
	SET NOCOUNT ON
	declare @UserGUID UNIQUEIDENTIFIER
	SET @UserGUID		 = ISNULL(@userGUID, [dbo].[fnGetCurrentUserGUID]()) 
	SET @FormGUID		 = ISNULL(@FormGUID, 0x0)
	SET @RawMaterialGUID = ISNULL(@RawMaterialGUID, 0x0)
	SET @StoreGUID		 = ISNULL(@StoreGUID, 0x0)

	DECLARE @Lang INT = [dbo].[fnConnections_GetLanguage]();
	DECLARE @MaterialQty float
	IF (@StoreGUID = 0x0)
		SELECT @MaterialQty = mtQty FROM vwMt WHERE mtGUID = @RawMaterialGUID
	ELSE
		SELECT @MaterialQty = msQty	FROM vwMs WHERE msMatPtr = @RawMaterialGUID AND msStorePtr = @StoreGUID

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE #Result(
		GUID uniqueidentifier, 
		Code NVARCHAR(250) COLLATE ARABIC_CI_AI,
		Name NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MatGUID uniqueidentifier,
		MatCode NVARCHAR(250) COLLATE ARABIC_CI_AI,
		MatName NVARCHAR(250) COLLATE ARABIC_CI_AI, 
		RequireQty float,
		AvailableQty float,
		CapabilityQty Float,
		usersecurity int,
		security int
	)

	INSERT INTO #Result 
	SELECT 
		mnmimt.mnFormGUID				AS GUID,
		fm.fmCode 				     AS Code,
		CASE WHEN @Lang > 0 THEN CASE WHEN FM.fmLatinName = ''  THEN FM.fmName ELSE FM.fmLatinName END ELSE FM.fmName END AS Name,
		mnmimt.miMatGUID                   AS MatGuid,
		mnmimt.mtCode					AS MatName,
		CASE WHEN @Lang > 0 THEN CASE WHEN mnmimt.mtLatinName = ''  THEN mnmimt.mtName ELSE mnmimt.mtLatinName END ELSE mnmimt.mtName END AS MatName,
		miQty						    AS RequireQty,
		( 
			CASE WHEN @StoreGUID = 0x0 THEN (SELECT mtQty FROM vwMt WHERE mtGUID = mnmimt.miMatGUID)
			     ELSE (SELECT msQty FROM vwMs WHERE msMatPtr = mnmimt.miMatGUID AND msStorePtr = @StoreGUID) END
		) AvailableQty,
		0 CapabilityQty,
		dbo.fnGetUserFormSec(@UserGUID, 1)	AS UserSecurity,
		fm.fmSecurity					AS Security
	FROM
		vwMnMiMt AS mnmimt
		INNER JOIN vwfm AS fm ON fm.fmGUID = mnmimt.mnFormGUID
	WHERE
		mnmimt.mnType = 0 AND
		mnmimt.miType = 1 AND
		(mnmimt.miMatGUID = @RawMaterialGUID OR @RawMaterialGUID = 0x0) AND
		(fm.fmGUID = @FormGUID OR ISNULL(@FormGUID, 0x0) = 0x0)

	EXEC [prcCheckSecurity] @result = '#Result'

	UPDATE #Result
	SET CapabilityQty = CASE WHEN AvailableQty > 0 THEN (AvailableQty / RequireQty)
							 ELSE 0 END
	SELECT *
	FROM #Result
	ORDER BY CASE WHEN @FormGUID = 0x0 THEN Code
				  ELSE CapabilityQty END

	DROP TABLE #Result

	SELECT * FROM [#SecViol] 
###########################################################################
CREATE PROCEDURE repManufCapability_CheckForm
	@RawMaterialGUID	uniqueidentifier,
	@FormGUID			uniqueidentifier
AS
	SET NOCOUNT ON
	DECLARE @FromCount int
	SET @FormGUID = isnull(@FormGUID, 0x0)
	IF (@FormGUID = 0x0)
	BEGIN
		SELECT @FromCount = Count(*) FROM vwMnMiMt WHERE 
			miMatGUID = @RawMaterialGUID AND
			mnType = 0 AND
			miType = 1
	END
	ELSE
	BEGIN
		SELECT @FromCount = Count(*) FROM vwMnMiMt WHERE 
			miMatGUID = @RawMaterialGUID AND
			mnType = 0 AND
			miType = 1 AND
			mnFormGUID = @FormGUID		
	END
	SELECT @FromCount AS FormCount
###############################################################
CREATE PROC ASAccDelete 
AS
  Delete from man_ActualStdAcc000
###########################################################
#END