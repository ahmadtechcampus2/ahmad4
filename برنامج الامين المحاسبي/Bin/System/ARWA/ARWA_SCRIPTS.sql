#########################################################
CREATE FUNCTION ARWA.fnIszero (@Number  FLOAT, @NumberOut FLOAT)		 
	RETURNS [FLOAT] 
AS BEGIN 
	RETURN (CASE WHEN @Number = 0 THEN  @NumberOut ELSE @Number END)
END 
#########################################################
CREATE FUNCTION ARWA.fnGetFirstDate()
	RETURNS DATETIME
AS
BEGIN
RETURN (
	SELECT 
		TOP 1 ISNULL(CAST(value AS DATETIME), GETDATE()) AS 'First Date' 
	FROM 
		op000 
	WHERE 
		[name] = 'AmnCfg_FPDate')		
		
END
#########################################################
CREATE FUNCTION ARWA.fnGetBranchMask (@UserGUID AS [UNIQUEIDENTIFIER])
	RETURNS [BIGINT] 
AS BEGIN 
	RETURN (ISNULL((SELECT TOP 1 [branchMask] FROM [connections] WHERE [UserGUID] = @UserGUID AND [HostID] = 'WebSite'), -1)) 
END 
#########################################################
CREATE FUNCTION ARWA.fnParseRepSources (@Source [VARCHAR](8000)) 
	RETURNS @Result TABLE([Guid] VARCHAR(100), [Type] VARCHAR(100))  
AS BEGIN  
/* 
This function: 
	- Converts a coma delemited string Consists of report source GUIDs and Types into a table with two fields 
*/ 
	DECLARE  
		@ComaPos [INT], 
		@StartShift [INT], 
		@LenSource [INT],
		@Guid	VARCHAR(100),
		@Type	VARCHAR(100)
	
	SELECT 
		@LenSource = LEN(@Source), 
		@StartShift = 1 
	IF RIGHT(@Source, 1) <> ',' 
		SET @Source = @Source + ',' 
	WHILE @StartShift <= @LenSource 
	BEGIN 
		SET @ComaPos = CHARINDEX(',', @Source, @StartShift) 
		SET @Guid = LTRIM(RTRIM(SUBSTRING(@Source, @StartShift, @ComaPos - @StartShift)))
		SET @StartShift = @ComaPos + 1
		SET @ComaPos = CHARINDEX(',', @Source, @StartShift) 
		SET @Type = LTRIM(RTRIM(SUBSTRING(@Source, @StartShift, @ComaPos - @StartShift)))
		INSERT INTO @Result VALUES (@Guid, @Type) 
		SET @StartShift = @ComaPos + 1 
	END
	
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetUsers()
RETURNS TABLE 
	RETURN(
	SELECT	
			[Guid],
			[LoginName] AS [Name],
			[Number] AS [Code],
			[LoginName]	AS [LatinName]
	FROM Us000
)
#########################################################
CREATE FUNCTION [ARWA].[fnGetTrnStatementTypes](@UserGuid [UNIQUEIDENTIFIER]) 
      RETURNS TABLE 
AS 
RETURN
(     
SELECT * FROM [TrnStatementTypes000] 
WHERE ([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
OR [dbo].[fnIsAdmin](@UserGUID) = 1
)
#########################################################
CREATE FUNCTION ARWA.fnGetTrnExchangeTypes(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS TABLE 
AS 
/*
This function return TrnExchangeTypes that are in UserBranchMask 
*/
RETURN
(	
SELECT * FROM [TrnExchangeTypes000] 
WHERE ([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
OR [dbo].[fnIsAdmin](@UserGUID) = 1
)
#########################################################
CREATE FUNCTION ARWA.fnGetStores(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI
						) 
AS
BEGIN
	DECLARE @StoreSecBrowse INT
	SELECT @StoreSecBrowse = dbo.fnGetUserStoreSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		CASE @Lang WHEN 'ar' THEN [Name] 
			ELSE
			CASE LatinName WHEN '' THEN [Name] ELSE LatinName END
		END,
		Code
	FROM st000
	WHERE [branchMask] & @BranchMask <> 0 AND [Security] <= @StoreSecBrowse
	
	RETURN
END			
#########################################################
CREATE FUNCTION ARWA.fnGetStores2(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT)
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[LatinName] VARCHAR(250) COLLATE ARABIC_CI_AI
						) 
AS
BEGIN
	DECLARE @StoreSecBrowse INT
	SELECT @StoreSecBrowse = dbo.fnGetUserStoreSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		Name,
		Code,
		LatinName
	FROM st000
	WHERE [branchMask] & @BranchMask <> 0 AND [Security] <= @StoreSecBrowse
	
	RETURN
END	
#########################################################
CREATE FUNCTION ARWA.fnGetRepSources(
	@UserGuid [UNIQUEIDENTIFIER], 
	@IncludeManualEntry BIT = 1, 
	@IncludeEntries BIT = 1,
	@IncludeBills BIT = 1,
	@IncludeTrnStatements BIT = 1,
	@IncludeTrnExchange BIT = 1,
	@IncludeNotePapers BIT = 1) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Name] VARCHAR(250), [LatinName] VARCHAR(250), [Type] [INT])
AS 
/*
This function return SrcsTypes that are in UserBranchMask 
*/
BEGIN
	INSERT INTO @Result
		-- ManualEntry 
		SELECT 0x0  [GUID],'”‰œ ﬁÌœ' [Name], 'Journal Entry' [LatinName], 1 WHERE @IncludeManualEntry = 1
		UNION
		--Entries Types
		SELECT [GUID], [Name], [LatinName], 1 FROM [ET000] 
		WHERE 
		(@IncludeManualEntry = 1) AND 
		(([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
		OR [dbo].[fnIsAdmin](@UserGUID) = 1)
		UNION
		--Bills Types
		SELECT [GUID], [Name], [LatinName], 2 FROM [BT000] 
		WHERE 
		(@IncludeBills = 1) AND 
		(([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
		OR [dbo].[fnIsAdmin](@UserGUID) = 1)
		UNION
		--TrnStatements Types
		SELECT [GUID], [Name], [LatinName], 3 FROM [TrnStatementTypes000] 
		WHERE 
		(@IncludeTrnStatements = 1) AND 
		(([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
		OR [dbo].[fnIsAdmin](@UserGUID) = 1)
		UNION
		--TrnExchange Types
		SELECT [GUID], [Name], [LatinName], 4 FROM [TrnExchangeTypes000] 
		WHERE 
		(@IncludeTrnExchange = 1) AND 
		(([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
		OR [dbo].[fnIsAdmin](@UserGUID) = 1)
		UNION
		--NotePapers Types
		SELECT [GUID], [Name], [LatinName], 5 FROM [nt000] 
		WHERE 
		(@IncludeNotePapers = 1) AND 
		(([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
		OR [dbo].[fnIsAdmin](@UserGUID) = 1)
		
	RETURN
END
#########################################################
CREATE FUNCTION ARWA.fnGetNotePapersTypes(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS TABLE 
AS 
/*
This function return NotePapersTypes that are in UserBranchMask 
*/
RETURN
(	
SELECT * FROM [nt000] 
WHERE ([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
OR [dbo].[fnIsAdmin](@UserGUID) = 1
)
#########################################################
CREATE FUNCTION ARWA.fnGetAllAccounts(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Type] INT
						) 
AS
BEGIN
	DECLARE @AccountSecBrowse INT
	SELECT @AccountSecBrowse = dbo.fnGetUserAccountSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		ac.[Guid],
		CASE @Lang WHEN 'ar' THEN ac.[Name] 
			ELSE
			CASE ac.LatinName WHEN '' THEN ac.[Name] ELSE ac.LatinName END
		END AS [Name],
		ac.Code,
		ac.[Type] 
	FROM ac000 AS ac
	WHERE [ac].[branchMask] & @BranchMask <> 0 AND ac.[Security] <= @AccountSecBrowse
	
	RETURN
END	
#########################################################
CREATE FUNCTION ARWA.fnGetNormalAccounts(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS TABLE 
AS
RETURN
	(
		SELECT * FROM fnGetAllAccounts(@UserGuid, @BranchMask, @Lang)
		WHERE [Type] IN (1, 4, 8)
	)
#########################################################
CREATE FUNCTION ARWA.fnGetMatGroups(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI 
						) 
AS
BEGIN
	DECLARE @GroupSecBrowse INT
	SELECT @GroupSecBrowse = dbo.fnGetUserGroupSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		CASE @Lang WHEN 'ar' THEN [Name] 
			ELSE
			CASE LatinName WHEN '' THEN [Name] ELSE LatinName END
		END,
		Code
	FROM gr000
	WHERE [branchMask] & @BranchMask <> 0 AND [Security] <= @GroupSecBrowse
	
	RETURN
END	
#########################################################
CREATE FUNCTION ARWA.fnGetMaterialsTree()  
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], [ParentGUID] [UNIQUEIDENTIFIER], [Code] [VARCHAR](255) COLLATE ARABIC_CI_AI, [Name] [VARCHAR](255) COLLATE ARABIC_CI_AI, [LatinName] [VARCHAR](255) COLLATE ARABIC_CI_AI,[tableName] [VARCHAR](255) COLLATE ARABIC_CI_AI, [SortNum] [INT], [IconID] [INT], [Path] [VARCHAR](8000) COLLATE ARABIC_CI_AI, [Level] [INT]) 
BEGIN 
/*   
icons ids   
	21. materials and groups root.   
	22. group.  
	23. material  
	  
*/  DECLARE @ParenTGrp UNIQUEIDENTIFIER 
	declare  @Grp Table ( 
		[Guid] UNIQUEIDENTIFIER, 
		[Level] SMALLINT, 
		[Path] VARCHAR(5000) 
	) 
	INSERT INTO @Grp([Guid],[Level],[Path]) 
	SELECT [Guid],[Level],[Path] from [dbo].[fnGetGroupsOfGroupSorted]( 0x00, 1) 
	 
	SELECT @ParenTGrp = [GUID]  
	FROM [brt]   
		WHERE [tableName] = 'mt000'  
	INSERT INTO @Result SELECT * FROM  
	(  
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'mt000' AS [tableName], 4 AS [SortNum], 21 AS [IconID] , '0.' AS [Path], 0 AS [Level]  
		 
		FROM [brt]   
		WHERE [tableName] = 'mt000'  
		UNION ALL  
		SELECT    
			[g].[GUID],    
			CASE [g].[ParentGUID] WHEN 0x0 THEN @ParenTGrp ELSE [g].[ParentGUID] END,   
			[g].[Code],   
			[g].[Name],   
			[g].[LatinName],   
			'gr000',  
			0, -- sortNum   
			22, -- iconID   
			[fn].[Path] AS [Path],  
			(fn.[Level]+1) AS [Level] 
		FROM   
			[gr000] AS [g]   
			INNER JOIN @Grp AS [fn] ON [g].[Guid] = [fn].[Guid]  
		UNION ALL  
		SELECT    
			[m].[GUID],    
			CASE [m].[groupGUID] WHEN 0x0 THEN @ParenTGrp ELSE [m].[groupGUID] END,   
			[m].[Code],   
			[m].[Name],  
			[m].[LatinName],  
			'mt000',  
			0, -- sortNum   
			23, -- iconID  
			[fn].[Path] + '0.1' AS [Path],  
			([fn].[Level]+2) AS [Level] 
		FROM [mt000] AS [m]   
		INNER JOIN @Grp AS [fn] ON [m].[groupGUID] = [fn].[Guid] 
		) AS [r]  
		ORDER BY [Path], [Level] 
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetMaterials(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Type] INT
						) 
AS
BEGIN
	DECLARE @MaterialSecBrowse INT
	SELECT @MaterialSecBrowse = dbo.fnGetUserMaterialSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		CASE @Lang WHEN 'ar' THEN [Name] 
			ELSE
			CASE LatinName WHEN '' THEN [Name] ELSE LatinName END
		END,
		Code,
		[Type] 
	FROM mt000 
	WHERE[branchMask] & @BranchMask <> 0 AND [Security] <= @MaterialSecBrowse
	
	RETURN
END	
#########################################################
CREATE FUNCTION ARWA.fnGetGroups(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Code] VARCHAR(250), [Name] VARCHAR(250), [LatinName] VARCHAR(250))
AS BEGIN 
/* 
Hierarichal Security List: 
	select function return a selection close to : select guid from gr000, with the exception that 
	the security value of each records is dependant on security value of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
	
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)		
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE ([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue [BIT]
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [BranchMask], 0 FROM [Gr000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0
	BEGIN
		INSERT INTO @SonsBuf
			SELECT [gr].[GUID], CASE WHEN [fb].[security] > [gr].[Security] THEN [fb].[security] ELSE [gr].[Security] END, [gr].[BranchMask]
			FROM [Gr000] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[ParentGUID] = [fb].[GUID] 
			WHERE [fb].[OK] = 0
		SET @Continue = @@ROWCOUNT
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf
		DELETE FROM @SonsBuf
	END
	
	IF (@IsAdmin = 1)
		INSERT INTO @Result SELECT [GR].[GUID], [GR].[Code], [GR].[Name], [GR].[LatinName] FROM @FatherBuf f INNER JOIN [GR000] GR ON [f].[GUID] = [GR].[GUID]
	ELSE
		INSERT INTO @Result SELECT [GR].[GUID], [GR].[Code], [GR].[Name], [GR].[LatinName] FROM @FatherBuf f INNER JOIN [GR000] GR ON [f].[GUID] = [GR].[GUID]
		WHERE ([GR].[Security] <= @UserSecurity)
		AND (([GR].[branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetAccounts(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Code] VARCHAR(250), [Name] VARCHAR(250), [LatinName] VARCHAR(250))
AS BEGIN 
/* 
Hierarichal Security List:
	select function return a selection close to : select guid from ac000, with the exception that 
	the security value of each records is dependant on security of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].fnGetUserAccountSec_Browse(@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue [BIT] 
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [BranchMask], 0 FROM [Ac000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0  
	BEGIN  
		INSERT INTO @SonsBuf  
			SELECT [ac].[GUID], CASE WHEN [fb].[security] > [ac].[Security] THEN [fb].[security] ELSE [ac].[Security] END, [ac].[BranchMask] 
			FROM [Ac000] AS [ac] INNER JOIN @FatherBuf AS [fb] ON [ac].[ParentGUID] = [fb].[GUID]  
			WHERE [fb].[OK] = 0  
		SET @Continue = @@ROWCOUNT  
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0  
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf  
		DELETE FROM @SonsBuf  
	END  
	
	IF (@IsAdmin = 1)
		INSERT INTO @Result SELECT [AC].[GUID], [AC].[Code], [AC].[Name], [AC].[LatinName] FROM @FatherBuf f INNER JOIN [AC000] AC ON [f].[GUID] = [AC].[GUID]
	ELSE
		INSERT INTO @Result
			SELECT [AC].[GUID], [AC].[Code], [AC].[Name], [AC].[LatinName] FROM @FatherBuf f INNER JOIN [AC000] AC ON [f].[GUID] = [AC].[GUID]
			WHERE ([f].[Security] <= @UserSecurity)
			  AND (([f].[branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
			
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetFinalAccounts(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS TABLE 
AS
RETURN
	(
		SELECT * FROM fnGetAllAccounts(@UserGuid, @BranchMask, @Lang)
		WHERE [Type] = 2
	)
#########################################################
CREATE FUNCTION ARWA.fnGetEntriesTypes(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS TABLE 
AS 
/*
This function return EntriesTypes that are in UserBranchMask 
*/
RETURN
(	
SELECT 0x0  [GUID],
	   null [SortNum],
	   null [EntryGroup],
	   null [EntryType],
	   '”‰œ ﬁÌœ' [Name], 'Journal Entry' [LatinName], '”‰œ ﬁÌœ' [Abbrev], 'Journal Entry' [LatinAbbrev],
	   null [DbTerm],
	   null [CrTerm],
	   null [Color1],
	   null [Color2],
	   null [bAcceptCostAcc],
	   null [bAutoPost],
	   null [bDetailed],
	   null [FldAccName],
	   null [FldDebit],
	   null [FldCredit],
	   null [FldNotes],
	   null [FldCurName],
	   null [FldCurVal],
	   null [FldStat],
	   null [FldCostPtr],
	   null [FldDate],
	   null [FldVendor],
	   null [FldSalesMan],
	   null [FldAccParent],
	   null [FldAccFinal],
	   null [FldAccCredit],
	   null [FldAccDebit],
	   null [FldAccBalance],
	   null [FldContraAcc],
	   null [DefAccGUID],
	   null [branchMask],
	   null [FldCurEqu],
	   null [ShowDiscGrid],
	   null [CostForBothAcc],
	   null [MenuName],
	   null [MenuLatinName],
	   null [DefCurrency],
	   null [FixedAccount],
	   null [FixedCurrency] 

UNION

SELECT * FROM [ET000] 
WHERE ([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
OR [dbo].[fnIsAdmin](@UserGUID) = 1
)
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedStores(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
/* 
Hierarichal Security List: 
	select function return a selection close to : select guid st000, with the exception that 
	the security value of each records is dependant on security value of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
	
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)		
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].[fnGetUserStoreSec_Browse](@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE ([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue BIT 
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [branchMask], 0 FROM [St000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0  
	BEGIN  
		INSERT INTO @SonsBuf  
			SELECT [st].[GUID], CASE WHEN [fb].[security] > [st].[Security] THEN [fb].[security] ELSE [st].[Security] END, [st].[BranchMask]
			FROM [St000] AS [st] INNER JOIN @FatherBuf AS [fb] ON [st].[ParentGUID] = [fb].[GUID]  
			WHERE [fb].[OK] = 0  
		SET @Continue = @@ROWCOUNT  
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0  
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf  
		DELETE FROM @SonsBuf  
	END  
	INSERT INTO @Result
		SELECT [GUID], 1 FROM @FatherBuf
		WHERE ([Security] > @UserSecurity AND @IsAdmin = 0)
		  AND (([branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)		
		
	INSERT INTO @Result
		SELECT [GUID], 0 FROM @FatherBuf
		WHERE [branchMask] & @UserBranchMask = 0 AND @brEnabled = 1
		
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedGroups(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
/* 
Hierarichal Security List: 
	select function return a selection close to : select guid from gr000, with the exception that 
	the security value of each records is dependant on security value of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
	
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)		
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE ([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue [BIT]
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [BranchMask], 0 FROM [Gr000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0
	BEGIN
		INSERT INTO @SonsBuf
			SELECT [gr].[GUID], CASE WHEN [fb].[security] > [gr].[Security] THEN [fb].[security] ELSE [gr].[Security] END, [gr].[BranchMask]
			FROM [Gr000] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[ParentGUID] = [fb].[GUID] 
			WHERE [fb].[OK] = 0
		SET @Continue = @@ROWCOUNT
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf
		DELETE FROM @SonsBuf
	END
	INSERT INTO @Result
		SELECT [GUID], 1 FROM @FatherBuf
		WHERE ([Security] > @UserSecurity AND @IsAdmin = 0)
		  AND (([branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	INSERT INTO @Result
		SELECT [GUID], 0 FROM @FatherBuf
		WHERE [branchMask] & @UserBranchMask = 0 AND @brEnabled = 1
	
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedMaterials(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 

	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
	
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].[fnGetUserMaterialSec_Browse](@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @GrpList TABLE([GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @GrpList SELECT [GUID] FROM [fnGetDeniedGroups](@UserGuid) 
	
	INSERT INTO @Result
		SELECT [mt].[GUID], 1
		FROM Mt000 AS [mt]
		INNER JOIN @GrpList AS [gr] ON [gr].[GUID] = [mt].[GroupGuid]
		WHERE ([mt].[Security] > @UserSecurity AND @IsAdmin = 0)
		  AND (([mt].[BranchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	INSERT INTO @Result
		SELECT [mt].[GUID], 0
		FROM Mt000 AS [mt]
		INNER JOIN @GrpList AS [gr] ON [gr].[GUID] = [mt].[GroupGuid]
		WHERE [mt].[BranchMask] & @UserBranchMask = 0 AND @brEnabled = 1
			
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedCentries(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 


	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	INSERT INTO @Result
		SELECT [ce].[GUID], 1
		FROM Ce000 AS [ce]
		LEFT JOIN Br000 AS [br] ON [br].[GUID] = [ce].[Branch]
		INNER JOIN [dbo].[fnGetUserEntriesSec](@UserGuid) AS [ets] ON [ce].[TypeGuid] = [ets].[GUID]
		WHERE ([ce].[Security] > [ets].[BrowseSec] AND @IsAdmin = 0)
		  AND ((power(2, [BR].Number - 1) & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	INSERT INTO @Result
		SELECT [ce].[GUID], 0
		FROM Ce000 AS [ce]
		INNER JOIN Br000 AS [br] ON [br].[GUID] = [ce].[Branch]
		LEFT JOIN ET000 AS [et] ON [ce].[TypeGUID] = [et].[GUID]
		WHERE (power(2, [BR].Number - 1) & @UserBranchMask = 0 OR [et].[BranchMask] & @UserBranchMask = 0) AND @brEnabled = 1 
			
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedEntries(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
	
	INSERT INTO @Result
		SELECT [en].[GUID], [fnCe].[IsSecViol]
		FROM en000 AS [en]
		INNER JOIN [fnGetDeniedCentries](@UserGuid) AS [fnCe] ON [en].[ParentGUID] = [fnCe].[GUID]

	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedCustomers(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
 
	DECLARE	@IsAdmin [INT],
			@UserSecurity [INT]	
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @UserSecurity = [dbo].[fnGetUserCustomerSec_Browse](@UserGuid)
	
	INSERT INTO @Result
		SELECT [GUID], 1
		FROM Cu000
		WHERE [Security] > @UserSecurity AND @IsAdmin = 0
		
	RETURN 
END
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedCosts(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
/* 
Hierarichal Security List: 
	select function return a selection close to : select guid from co000, with the exception that 
	the security value of each records is dependant on security value of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
	
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].[fnGetUserCostSec_Browse](@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue [BIT] 
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [BranchMask], 0 FROM [Co000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0  
	BEGIN  
		INSERT INTO @SonsBuf  
			SELECT [co].[GUID], CASE WHEN [fb].[security] > [co].[Security] THEN [fb].[security] ELSE [co].[Security] END, [co].[BranchMask] 
			FROM [Co000] AS [co] INNER JOIN @FatherBuf AS [fb] ON [co].[ParentGUID] = [fb].[GUID] 
			WHERE [fb].[OK] = 0  
		SET @Continue = @@ROWCOUNT  
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0  
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf  
		DELETE FROM @SonsBuf  
	END  
	INSERT INTO @Result
		SELECT [GUID], 1 FROM @FatherBuf
		WHERE ([Security] > @UserSecurity AND @IsAdmin = 0)
		  AND (([branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	INSERT INTO @Result
		SELECT [GUID], 0 FROM @FatherBuf
		WHERE [branchMask] & @UserBranchMask = 0 AND @brEnabled = 1
			
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedBills(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 

	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	INSERT INTO @Result
		SELECT [bu].[GUID], 1
		FROM Bu000 AS [bu]
		LEFT JOIN Br000 AS [br] ON [br].[GUID] = [bu].[Branch]
		INNER JOIN Bt000 AS [bt] ON [bu].[TypeGuid] = [bt].[Guid]
		INNER JOIN [dbo].[fnGetUserBillsSec](@UserGuid) AS [bts] ON [bt].[Guid] = [bts].[Guid]
		WHERE ([bu].[Security] > [bts].[BrowseSec] AND @IsAdmin = 0)
		  AND ((power(2, [br].[Number] - 1) & @UserBranchMask <> 0 AND [bt].[BranchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
		
	INSERT INTO @Result
		SELECT [bu].[GUID], 0
		FROM Bu000 AS [bu]
		INNER JOIN Br000 AS [br] ON [br].[GUID] = [bu].[Branch]
		INNER JOIN Bt000 AS [bt] ON [bu].[TypeGuid] = [bt].[Guid]
		WHERE ((power(2, [br].[Number] - 1) & @UserBranchMask = 0 OR [bt].[BranchMask] & @UserBranchMask = 0) AND @brEnabled = 1)
			
	RETURN 
END
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedBillItems(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT]) 
AS BEGIN 
	
	INSERT INTO @Result
		SELECT [bi].[GUID], [fnBu].[IsSecViol]
		FROM Bi000 AS [bi]
		INNER JOIN [fnGetDeniedBills](@UserGuid) AS [fnBu] ON [bi].ParentGUID = [fnBu].[GUID]
		
	RETURN 
END
#########################################################
CREATE FUNCTION ARWA.fnGetDeniedAccounts(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [IsSecViol] [BIT])
AS BEGIN 
/* 
Hierarichal Security List:
	select function return a selection close to : select guid from ac000, with the exception that 
	the security value of each records is dependant on security of parent record. 
	following a rule where a sons' security value is always greater or equal to its parent security value 
*/ 
	DECLARE @IsAdmin [INT],
			@brEnabled [INT],
			@UserSecurity [INT],
			@UserBranchMask [BIGINT]
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SET @UserSecurity = [dbo].fnGetUserAccountSec_Browse(@UserGuid)
	SET @UserBranchMask = [ARWA].[fnGetBranchMask](@UserGuid)
	
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT], [OK] [BIT]) 
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [security] [INT], [branchMask] [BIGINT]) 
	DECLARE @Continue [BIT] 
  
	INSERT INTO @FatherBuf SELECT [GUID], [Security], [BranchMask], 0 FROM [Ac000] WHERE ISNULL([ParentGUID], 0x0) = 0x0 
	SET @Continue = @@ROWCOUNT 
  
	WHILE @Continue <> 0  
	BEGIN  
		INSERT INTO @SonsBuf  
			SELECT [ac].[GUID], CASE WHEN [fb].[security] > [ac].[Security] THEN [fb].[security] ELSE [ac].[Security] END, [ac].[BranchMask] 
			FROM [Ac000] AS [ac] INNER JOIN @FatherBuf AS [fb] ON [ac].[ParentGUID] = [fb].[GUID]  
			WHERE [fb].[OK] = 0  
		SET @Continue = @@ROWCOUNT  
		UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0  
		INSERT INTO @FatherBuf SELECT [GUID], [security], [branchMask], 0 FROM @SonsBuf  
		DELETE FROM @SonsBuf  
	END  
	INSERT INTO @Result
		SELECT [GUID], 1 FROM @FatherBuf
		WHERE ([Security] > @UserSecurity AND @IsAdmin = 0)
		  AND (([branchMask] & @UserBranchMask <> 0 AND @brEnabled = 1) OR @brEnabled = 0)
			
	INSERT INTO @Result
		SELECT [GUID], 0 FROM @FatherBuf
		WHERE [branchMask] & @UserBranchMask = 0 AND @brEnabled = 1
		
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetCustomers(@UserGuid [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Code] VARCHAR(250), [Name] VARCHAR(250), [LatinName] VARCHAR(250))
AS BEGIN 
 
	DECLARE	@IsAdmin [INT],
			@UserSecurity [INT]	
			
	SET @IsAdmin = [dbo].[fnIsAdmin](@UserGUID)
	SET @UserSecurity = [dbo].[fnGetUserCustomerSec_Browse](@UserGuid)
	
	IF (@IsAdmin = 1)
		INSERT INTO @Result SELECT [GUID], [Number] AS [Code], [CustomerName] AS [Name], [LatinName] FROM [CU000] CU
	ELSE
		INSERT INTO @Result SELECT [GUID], [Number] AS [Code], [CustomerName] AS [Name], [LatinName] FROM [CU000] CU
		WHERE [Security] <= @UserSecurity
		
	RETURN 
END 
#########################################################
CREATE FUNCTION ARWA.fnGetCurrencies(@BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS TABLE 
AS
RETURN
	(
		SELECT 
			[Guid],
			CASE @Lang WHEN 'ar' THEN [Name] 
				ELSE
				CASE LatinName WHEN '' THEN [Name] ELSE LatinName END
			END AS [Name],
			Code
		FROM my000
		WHERE [branchMask] & @BranchMask <> 0
	)
#########################################################
CREATE FUNCTION ARWA.fnGetCosts_2(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT)
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[LatinName] VARCHAR(250) COLLATE ARABIC_CI_AI
						) 
AS
BEGIN
	DECLARE @CostSecBrowse INT
	SELECT @CostSecBrowse = dbo.fnGetUserCostSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		Name,
		Code,
		LatinName
	FROM co000
	WHERE [branchMask] & @BranchMask <> 0 AND [Security] <= @CostSecBrowse
	
	RETURN
END			
#########################################################
CREATE FUNCTION ARWA.fnGetCosts(@UserGuid UNIQUEIDENTIFIER, @BranchMask BIGINT, @Lang VARCHAR(100))
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI
						) 
AS
BEGIN
	DECLARE @CostSecBrowse INT
	SELECT @CostSecBrowse = dbo.fnGetUserCostSec_Browse(@UserGuid)
	INSERT INTO @Result
	SELECT 
		[Guid],
		CASE @Lang WHEN 'ar' THEN [Name] 
			ELSE
			CASE LatinName WHEN '' THEN [Name] ELSE LatinName END
		END AS [Name],
		Code
	FROM co000
	WHERE [branchMask] & @BranchMask <> 0 AND [Security] <= @CostSecBrowse
	
	RETURN
END			
#########################################################
CREATE FUNCTION ARWA.fnGetBranches(@UserGuid UNIQUEIDENTIFIER)
RETURNS @Result TABLE ([Guid] UNIQUEIDENTIFIER, 
						[Name] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[Code] VARCHAR(250) COLLATE ARABIC_CI_AI, 
						[LatinName] VARCHAR(250) COLLATE ARABIC_CI_AI
						) 
AS
BEGIN
	
	INSERT INTO @Result
	SELECT  Guid, Name, Code, LatinName
	FROM 
	BR000 
	WHERE 
	GUID IN 
	(
		  SELECT SUBID 
		  FROM UIX 
		  WHERE ReportID = 268562432 AND Permission = 1 and UserGUID = [Guid]
	) 
	
	RETURN
END			
#########################################################
CREATE FUNCTION ARWA.fnGetBillsTypes(@UserGuid [UNIQUEIDENTIFIER]) 
	RETURNS TABLE 
AS 
/*
This function return BillsTypes that are in UserBranchMask 
*/
RETURN
(	
SELECT * FROM [BT000] 
WHERE ([dbo].[fnIsAdmin](@UserGUID) = 0 AND ([ARWA].[fnGetBranchMask](@UserGuid) & [branchMask] <> 0 OR [dbo].[fnOption_get]('EnableBranches', '0') = 0))
OR [dbo].[fnIsAdmin](@UserGUID) = 1
)
#########################################################
CREATE FUNCTION ARWA.fnExtended_En_Src( @SourcesTypes	VARCHAR(Max))     
	RETURNS TABLE  
		 /*  
			TYPE = 1 -> ENTRY    
			TYPE = 2 -> Bill    
			TYPE = 4 -> Pay    
			TYPE = 5 -> Check    
			TYPE = 6 -> CheckCol    
		*/    
AS     
	RETURN (  
		SELECT     
			[en].[ceGUID],     
			[en].[ceType],     
			[en].[ceNumber],     
			[en].[ceDate],     
			[en].[ceDebit],     
			[en].[ceCredit],     
			[en].[ceNotes],     
			[en].[ceCurrencyVal],     
			[en].[ceCurrencyPtr],     
			[en].[ceIsPosted],     
			[en].[ceState],     
			[en].[ceSecurity],     
			4 AS [UserSecurity],  
			[en].[ceBranch],     
			[en].[enGUID],     
			[en].[enNumber],     
			[en].[enAccount],     
			[en].[enDate],     
			[en].[enDebit],     
			[en].[enCredit],     
			[en].[enNotes],     
			[en].[enCurrencyPtr],     
			[en].[enCurrencyVal],     
			[en].[enCostPoint],     
			[en].[enClass],     
			[en].[enNum1],     
			[en].[enNum2],     
			[en].[enVendor],     
			[en].[enSalesMan],     
			[en].[enContraAcc],    
			[en].[acNumber],     
			[en].[acName],     
			[en].[acLatinName],    
			[en].[acCode],     
			[en].[acParent],     
			[en].[acFinal],     
			[en].[acSecurity],     
			[en].[acNSons],     
			[en].[acType],     
			[en].[acMaxDebit],     
			[en].[acWarn],     
			[en].[acNotes],     
			[en].[acUseFlag],     
			[en].[acCurrencyPtr],     
			[en].[acCurrencyVal],     
			[en].[acDebitOrCredit],    
			[en].[acGUID], 
			ISNULL([er].[erParentType],0) [erParentType], 
			ISNULL( [er].[erParentGuid], 0x0) AS [ParentGUID], 
			[en].[ceTypeGUID] AS [ParentTypeGUID], 
			ISNULL( [er].[erParentType], 0x0) AS [ceRecType],  
			ISNULL( [er].[erParentNumber], 0x0) AS [ceParentNumber],  
			ISNULL( [bt].[btName], ISNULL( [et].[etName], ISNULL( [nt].[ntName], ''))) AS [ceTypeName],  
			ISNULL( [bt].[btLatinName], ISNULL( [et].[etLatinName], ISNULL( [nt].[ntLatinName], ''))) AS [ceTypeLatinName],  
			ISNULL( [bt].[btAbbrev], ISNULL( [et].[etAbbrev], ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''))) AS [ceTypeAbbrev],  
			ISNULL( [bt].[btLatinAbbrev], ISNULL( [et].[etLatinAbbrev], ISNULL( CASE [nt].[ntLatinAbbrev] WHEN '' THEN [nt].[ntLatinName] ELSE [nt].[ntLatinAbbrev] END, ''))) AS [ceTypeLatinAbbrev]  
		FROM 	 
			[vwExtended_en] AS [en]    
			INNER JOIN (select distinct [guid] from [fnParseRepSources] (@SourcesTypes)) AS [t]       
			ON ISNULL( [en].[ceTypeGUID], 0x0) = [t].[GUID]  
			LEFT JOIN [vwEr] AS [er] ON [en].[ceGuid] = [er].[erEntryGuid]  
			LEFT JOIN [vwBt] AS [bt] ON [en].[ceTypeGUID] = [bt].[btGuid] 
			LEFT JOIN [vwEt] AS [et] ON [en].[ceTypeGUID] = [et].[etGuid] 
			LEFT JOIN [vwNt] AS [nt] ON [en].[ceTypeGUID] = [nt].[ntGuid] 
	) 				
#########################################################
CREATE FUNCTION ARWA.fnExtended_En_Fixed_Src( @SourcesTypes	VARCHAR(MAX), @CurGUID [UNIQUEIDENTIFIER] = 0x0) 
	RETURNS TABLE 
AS   
	RETURN (  
			SELECT  
				*, 
				[dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @CurGUID, [enDate]) AS [FixedEnDebit],   
				[dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal],  @CurGUID, [enDate]) AS [FixedEnCredit] 
			FROM 
				[fnExtended_En_Src]( @SourcesTypes)) 
#########################################################
CREATE PROCEDURE ARWA.PrcWriteReportUserPreferences
	@UserGuid			UNIQUEIDENTIFIER,
	@ReportName			NVARCHAR(100),
	@Customization      VARCHAR(MAX)
AS
/*
This Stored Procedure is used to Write report-Customizations for specific user @UserGuid
*/
	IF EXISTS (SELECT * FROM [ReportCustomization] WHERE UserGuid = @UserGuid AND ReportName = @ReportName)
		UPDATE [ReportCustomization] SET Customization = @Customization WHERE UserGuid = @UserGuid AND ReportName = @ReportName
	ELSE
		INSERT INTO [ReportCustomization]
		VALUES 
			(@UserGuid, @ReportName, @Customization)
#########################################################
CREATE PROCEDURE ARWA.PrcWriteReportOptions
	@UserGuid	UNIQUEIDENTIFIER,
	@ReportName  NVARCHAR(100),
	@Options     VARCHAR(MAX)
AS
/*
This Stored Procedure is used to Write report-Options for specific user @UserGuid
*/
	IF EXISTS (SELECT * FROM [ReportOptions] WHERE UserGuid = @UserGuid AND ReportName = @ReportName)
		UPDATE [ReportOptions] SET Options = @Options WHERE UserGuid = @UserGuid AND ReportName = @ReportName
	ELSE
		INSERT INTO [ReportOptions] 
		VALUES 
			(@UserGuid, @ReportName, @Options)
#########################################################
CREATE PROCEDURE ARWA.prcTrialBalanceHdr
	@AccountGUID 			[UNIQUEIDENTIFIER],		-- Account Guid
	@CurrencyGUID 			[UNIQUEIDENTIFIER],		-- Currency Guid
	@Lang					VARCHAR(10) = 'ar'		-- Resultset Language (determined by the system)
AS
	--------------------------
	SELECT
		(SELECT TOP 1 CASE @Lang WHEN 'ar' THEN Code + '-' + Name ELSE Code + '-' + LatinName END FROM ac000 WHERE GUID = @AccountGUID OR @AccountGUID = 0x0) AS acName,
		(SELECT TOP 1 Code FROM my000 WHERE GUID = @CurrencyGuid OR @CurrencyGuid = 0x0) AS currCode
/*
EXEC [prcTrialBalanceHdr] '4B09D808-2DE5-4167-AAE8-CD300A2FE8EB', '7F85974C-6EEC-48D9-A9F2-E12A34D7B060','en'
*/
#########################################################
CREATE PROCEDURE ARWA.prcSetSessionConnections
      @USREGUID UNIQUEIDENTIFIER,
      @Branchmask BIGINT =0
AS 
      --SET NOCOUNT ON
      DELETE  Connections  WHERE spid = @@spid
      INSERT INTO Connections(SPID,UserGUID,BranchMask,HostName,login_time,HostId ) SELECT  @@spid,@USREGUID,@Branchmask,'WebSite',GETDATE(),'WebSite'  
#########################################################
CREATE PROCEDURE ARWA.prcRemoveConnection
	@UserGuid	[UNIQUEIDENTIFIER]
AS
	DELETE FROM [Connections] WHERE UserGUID = @UserGuid AND HostId = 'WebSite' AND HostName = 'WebSite'
#########################################################
CREATE PROCEDURE ARWA.PrcReadReportUserPreferences
	@UserGuid	 UNIQUEIDENTIFIER,
	@ReportName  NVARCHAR(100)
AS
/*
This Stored Procedure is used to Read report-Customizations for specific user @UserGuid
*/
	SELECT [Customization] 
	FROM  [ReportCustomization] 
	WHERE [UserGuid] = @UserGuid
	AND   [ReportName] = @ReportName
#########################################################
CREATE PROCEDURE ARWA.PrcReadReportOptions
	@UserGuid	 UNIQUEIDENTIFIER,
	@ReportName  NVARCHAR(100)
AS
/*
This Stored Procedure is used to Read report-Options for specific user @UserGuid
*/
	SELECT [Options] 
	FROM  [ReportOptions] 
	WHERE [UserGuid] = @UserGuid
	AND   [ReportName] = @ReportName
#########################################################
CREATE PROCEDURE ARWA.prcAddConnection
	@UserGuid	[UNIQUEIDENTIFIER],
	@BranchMask	[BIGINT] = -1
AS
	DECLARE @UserNumber [int]
	select @UserNumber = [Number] from [us000] where [GUID] = @UserGuid
	INSERT INTO [Connections]
	SELECT
		ISNULL(MAX(SPID), 1) + 1,
		GETDATE(),
		@UserGuid,
		0,
		0,
		GETDATE(),
		@BranchMask,
		@UserNumber,
		'WebSite',
		'WebSite'
	FROM Connections
#########################################################
CREATE PROCEDURE ARWA.prcConnectionsAdd
      @UserGUID UNIQUEIDENTIFIER,
      @BranchMask BIGINT = -1
AS 
      SET NOCOUNT ON
      
      DELETE 
            Connections 
      WHERE 
            spid = @@SPID

      INSERT INTO Connections(
        SPID, 
        UserGUID,
        BranchMask,
        login_time,
        HostName,
        HostId) 
      SELECT  
        @@SPID,
        @UserGUID,
        @BranchMask,
        GETDATE(),
        'WebSite',
        'WebSite'
#########################################################
CREATE PROCEDURE ARWA.prcLogingUser
	@UserName	VARCHAR(250),
	@Password	VARCHAR(250),
	@BranchMask	[BIGINT] = -1
AS
/*
This procedure is used to verify user credentials
On fail: Return UserGuid = 0x0 & SuccessFlag = 0
On success: 1- Register the user permissions in the table 'UIX' 
			2- Add the user connection to the table 'Connections'
			3- Return the UserGuid & SuccessFlag = 1
*/
	DECLARE @UserGuid [UNIQUEIDENTIFIER]
	SET @UserGuid = 0x0
	
	-- Validate User Credentials
	SELECT @UserGuid = [GUID] FROM [us000] WHERE [LoginName] = @UserName AND [Password] = @Password
	
	IF @UserGuid = 0x0
	BEGIN
		SELECT CAST(0 AS BIT) AS SuccessFlag
		RETURN
	END
	
	-- Fill the UIX table with the user permissions
	EXEC [dbo].[prcUser_RebuildSecurityTable] @UserGuid

	-- Add the user to the Connections table
	EXEC [prcRemoveConnection] @UserGuid
	EXEC [prcAddConnection] @UserGuid, @BranchMask

	-- return the the userguid and success flag = 1
	SELECT CAST(1 AS BIT) AS SuccessFlag
	FROM [us000] WHERE [GUID] = @UserGuid
#########################################################
CREATE PROCEDURE ARWA.prcInventoryChecklistHdr
	@GroupGUID 				[UNIQUEIDENTIFIER],		-- Group Guid
	@MatGUID 				[UNIQUEIDENTIFIER],		-- Material Guid
	@CostGUID 				[UNIQUEIDENTIFIER],		-- Cost Guid
	@CurrencyGUID 			[UNIQUEIDENTIFIER],		-- Currency Guid
	@Lang					VARCHAR(10) = 'ar'	-- Resultset Language (determined by the system)
AS
	--------------------------
	SELECT
		(SELECT TOP 1 CASE @Lang WHEN 'ar' THEN Code + '-' + Name ELSE Code + '-' + LatinName END FROM gr000 WHERE GUID = @GroupGuid OR @GroupGuid = 0x0) AS grName,
		(SELECT TOP 1 CASE @Lang WHEN 'ar' THEN Code + '-' + Name ELSE Code + '-' + LatinName END FROM mt000 WHERE GUID = @MatGuid OR @MatGuid = 0x0) AS mtName,
		(SELECT TOP 1 CASE @Lang WHEN 'ar' THEN Code + '-' + Name ELSE Code + '-' + LatinName END FROM co000 WHERE GUID = @CostGuid OR @CostGuid = 0x0) AS coName,
		(SELECT TOP 1 Code FROM my000 WHERE GUID = @CurrencyGUID OR @CurrencyGUID = 0x0) AS currCode
/*
EXEC [prcInventoryChecklistHdr] 'C88F2DD2-98BA-49AE-AE4B-92D70110073F', '00000000-0000-0000-0000-000000000000', '8F5AF12D-0791-4987-9DB6-79B85C798A89', '47d90150-4405-4bfc-9f9d-910d3853431c', 'ar'
*/
#########################################################
CREATE PROCEDURE ARWA.prcInitialize_Environment
	@UserGUID UNIQUEIDENTIFIER,
	@ProcedureName VARCHAR(250),
	@BranchMask BIGINT = -1
AS 
      SET NOCOUNT ON 
      
      -- EXEC [prcStartLog] @UserGUID, @ProcedureName
      EXEC [prcConnectionsAdd] @UserGUID, @BranchMask
#########################################################
CREATE PROCEDURE ARWA.prcGetUserInfo
	@UserName	VARCHAR(250)
AS
	SELECT [GUID] AS UserGuid, CAST(bAdmin AS BIT) AS IsAdmin
	FROM [us000] WHERE [LoginName] = @UserName

#########################################################
CREATE PROCEDURE ARWA.prcGetFinalAcc
	@StartDate 		DATETIME,   
	@EndDate 		DATETIME,      
	@CurPtr			UNIQUEIDENTIFIER,      
	@CurVal			FLOAT,     
	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	 
	@StGUID			UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	 
	@Final			UNIQUEIDENTIFIER,     
	@DetailSubStores		INT,	 -- 1 show details 0 no details  for Stores  
	@PriceType				INT,	  
	@PricePolicy			INT,       
	@ShowDetails			INT,  -- 1= show Accounts Tree for the specific FinalAcc, 0 = show only balance for the specific FinalAcc      
	@ShowPosted				INT, 
	@ShowUnPosted			INT, 
	@RateType				INT = 0, 
	@accLevel					INT = 1, 
	@havePriceBySN			BIT = 0 
AS     
	--- 1 posted, 0 unposted -1 both        
	DECLARE @PostedType AS  INT 
	DECLARE @TypeAccGuid1  [UNIQUEIDENTIFIER]  
	DECLARE @TypeAccGuid2  [UNIQUEIDENTIFIER]  
	DECLARE @Level INT, @MaxLevel INT    
	DECLARE @FinalType	BIT  
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 0) )		          
		SET @PostedType = 1       
	IF( (@ShowPosted = 0) AND (@ShowUnPosted = 1))          
		SET @PostedType = 0       
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 1))          
		SET @PostedType = -1       
	SET NOCOUNT ON	  
	DECLARE  
		@UserGUID [UNIQUEIDENTIFIER], 
		@UserSec  [INT], 
		@AccSec	  [INT], 
		@RecCnt	  [INT]     
	IF @RateType = 1 
		SELECT TOP 1 @CurPtr = [Guid] FROM [my000] WHERE CurrencyVal = 1 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()     
	-- User Security on entries     
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)     
	-- User Security on Browse Account 
	SET @AccSec = dbo.fnGetUserAccountSec_Browse(@UserGUID)     
	 
	-- Security Table ------------------------------------------------------------     
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)    
	 
	--================================================================= 
	--  AccList Sorted     
	--================================================================= 
	CREATE TABLE [#AccountsList]     
	(     
		[guid]		[UNIQUEIDENTIFIER],      
		[level]		[INT],     
		[path]		[VARCHAR](5000) COLLATE ARABIC_CI_AI     
	)    
	--====================================================================  
	CREATE TABLE [#FinalResult] 
	(        
		[acGUID]			[UNIQUEIDENTIFIER],     
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acFinal]			[UNIQUEIDENTIFIER],     
		[acParent]			[UNIQUEIDENTIFIER],     
		[DebitOrCredit]		[BIT]	DEFAULT 0,  -- IsDebit   
		[acCurPtr]			[UNIQUEIDENTIFIER],     
		[acCurVal]			[FLOAT] DEFAULT 0, 	     
		[Debit] 			[FLOAT] DEFAULT 0,      
		[Credit] 			[FLOAT] DEFAULT 0,      
		[CurDebit] 			[FLOAT] DEFAULT 0,      
		[CurCredit] 		[FLOAT] DEFAULT 0,     
		[Level]				[INT]	DEFAULT 0,     
		[Path] 				[VARCHAR](5000) COLLATE ARABIC_CI_AI,    
		[RecType] 			[INT] DEFAULT 0, -- 0 Acc, 1 ParentAcc, 2 FinalAcc     
		[fn_AcLevel]		[INT],	-- OrderID for The FinalAcc 
		[FLAG]				[INT], 
		[IsFinalAccount]	[BIT] DEFAULT 0,
		--[Id]				[INT]
		FinalAccountIdentity [INT]
	)      
	 
	CREATE TABLE [#EResult] 
	(        
		[acGUID]		[UNIQUEIDENTIFIER],     
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acFinal]			[UNIQUEIDENTIFIER],     
		[acParent]			[UNIQUEIDENTIFIER],     
		[DebitOrCredit]		[INT]	DEFAULT 0,     
		[acCurPtr]			[UNIQUEIDENTIFIER],     
		[acCurVal]			[FLOAT] DEFAULT 0, 	     
		[Debit] 			[FLOAT] DEFAULT 0,      
		[Credit] 			[FLOAT] DEFAULT 0,      
		[CurDebit] 			[FLOAT] DEFAULT 0,      
		[CurCredit] 		[FLOAT] DEFAULT 0,     
		[Level]				[INT]	DEFAULT 0,     
		[Path] 				[VARCHAR](5000) COLLATE ARABIC_CI_AI,    
		[RecType] 			[INT] DEFAULT 0,	-- = 0 Acc  =1 ParentAcc = 2 FinalAcc     
		[Security]			[INT],     
		[AccSecurity]		[INT],     
		[UserSecurity] 		[INT], 
		[fn_AcLevel]		[INT],		-- OrderID for The FinalAcc 
		[Flag]				[INT], 
		[DFlag]				[INT], 
		[ID]				[INT] 
	) 
	--================================================================= 
	CREATE TABLE #FinalAccTbl 
	(  
		[ID]				[INT] IDENTITY(1,1), 
		[AcGuid]			[UNIQUEIDENTIFIER],  
		[AcCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,  
		[AcCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,  
		[AcFinal]			[UNIQUEIDENTIFIER],  
		[AcParent]			[UNIQUEIDENTIFIER],  
		[DebitOrCredit]	[INT],  
		[AcCurPtr] 		[UNIQUEIDENTIFIER],  
		[AcCurVal]		[FLOAT],  
		[AccSecurity]	[INT],  
		[Level]			[INT]	  
	)       
	--================================================================== 
	-- ·« Ì„ﬂ‰ «” Œœ«„ prcgetAccountslist     
	-- ·√‰Â ·« Ì√Œ– «·›—“     
	INSERT INTO #AccountsList     
	SELECT     
		[guid],     
		[level],     
		[path]     
	FROM      
		[fnGetAccountsList]( null, 1) 
	 
	--================================================================= 
	--====================== Calc Acc Goods =========================== 
	--================================================================= 
	DECLARE @ShowUnLinked INT, @UseUnit INT, @DetailsStores	INT  
	DECLARE @MatGUID UNIQUEIDENTIFIER, @GroupPtr  UNIQUEIDENTIFIER, @SrcTypes UNIQUEIDENTIFIER  
	DECLARE @MatType INT 
	DECLARE @FirstPeriodStGUID UNIQUEIDENTIFIER  
	 
	SET @MatGUID = 0x0 
	SET @GroupPtr = 0x0 
	SET @SrcTypes = 0x0 
	SET @MatType = 0 
	SET @ShowUnLinked = 0  
	SET @UseUnit = 0  
	SET @DetailsStores = 1  
	 
	-- Creating temporary tables  ----------------------------------------------------------  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#MatTbl2]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl]([StoreGUID] UNIQUEIDENTIFIER, [Security] INT)   
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)   
	 
	--Filling temporary tables   
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] @MatGUID, @GroupPtr,257  
	 
	IF  @havePriceBySN > 0 
	BEGIN 
		INSERT INTO [#MatTbl2] SELECT *  from [#MatTbl] 
		DELETE [#MatTbl] FROM [#MatTbl] mt INNER JOIN mt000 m ON m.Guid = mt.[MatGUID] WHERE  m.SnFlag > 0 
		 
	END 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypes 
	IF (@DetailSubStores = 1) 
		INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] @StGUID 
	ELSE 
		INSERT INTO [#StoreTbl] SELECT [stGuid],[stSecurity] FROM vwSt WHERE ISNULL(@StGUID,0X00) = 0X00 OR  [stGuid] = @StGUID 
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] @CostGUID   
	 
	--Get Qtys  
	CREATE TABLE [#t_Qtys]  
	(  
		[MatGUID] 	[UNIQUEIDENTIFIER],  
		[Qnt] 		[FLOAT],  
		[Qnt2] 		[FLOAT],  
		[Qnt3] 		[FLOAT],  
		[StoreGUID]	[UNIQUEIDENTIFIER]  
	)  
	 
	CREATE TABLE #t_AccGoods   
	(   
		[acGUID]			[UNIQUEIDENTIFIER],   
		[acQty]				[FLOAT], 
		[acPrice]			[FLOAT],	 
		[StoreGUID]			[UNIQUEIDENTIFIER], 
		[AccType]			[INT]		-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—…	   
	)   
	 
	CREATE TABLE [#t_Goods]   
	(   
		[acGUID]			[UNIQUEIDENTIFIER],   
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,   
		[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,   
		[acFinal]			[UNIQUEIDENTIFIER],   
		[acParent]			[UNIQUEIDENTIFIER],   
		[acCurPtr]			[UNIQUEIDENTIFIER],   
		[acCurVal]			[FLOAT],   
		[Balance]			[FLOAT], 
		[AccType]			[INT],-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—… 
		[acSecurity]		[INT]			   
	)   
	 
	CREATE TABLE [#MatAccount]   
	( 
		[MatGUID]	UNIQUEIDENTIFIER,	   
		[MatAccGUID] UNIQUEIDENTIFIER, 
		[AccType]		INT 
	) 
	CREATE TABLE [#T_RESULT] 
	( 
		[acGUID] UNIQUEIDENTIFIER, 
		[Flag] INT DEFAULT 0 
	) 
	CREATE TABLE [#t_Prices]  
	(  
		[MatGUID] 	[UNIQUEIDENTIFIER],  
		[Price] 	[FLOAT]  
	)  
	CREATE TABLE #PricesQtys  
	(  
		[MatGUID]	[UNIQUEIDENTIFIER],  
		[Price]		[FLOAT],  
		[Qnt]		[FLOAT],  
		[StoreGUID]	[UNIQUEIDENTIFIER] 
	)  
	-- First Period 
	DECLARE @DelPrice [BIT],@FBDate	DATETIME,@StDate DATETIME 
	INSERT INTO [#FinalAccTbl] ([AcGuid],[AcCodeName],[AcCodeLatinName],[AcFinal],[AcParent],[DebitOrCredit],[AcCurPtr],[AcCurVal],[AccSecurity],[Level]) 
		SELECT  
			[acGUID],  
			[acCode] + '-'+ [acName],  
			[acCode] + '-'+ [acLatinName],  
			[acFinal],	  
			[acParent],  
			[acDebitOrCredit],  	  
			[acCurrencyPtr],    
			[acCurrencyVal],  
			[acSecurity],  
			[Level]  
		FROM  
			[fnGetAccountsList]( @Final,1) AS [al] INNER JOIN [vwAc]  
			ON [al].[GUID] = [acGUID]  
		ORDER BY [path]  
	--======================================================================== 
	 
	SELECT @FBDate = dbo.fnDate_Amn2Sql(value) FROM op000 WHERE NAME = 'AmnCfg_FPDate' 
	IF (@FBDate < @StartDate) 
	BEGIN 
		IF NOT EXISTS( SELECT * FROM BT000 where TYPE = 2 AND SORTNUM = 2) 
			SET @FinalType = 0 
		ELSE 
		BEGIN 
			INSERT INTO #MatAccount([MatAccGUID]) SELECT DefBillAccGUID FROM BT000 where TYPE = 2 AND SORTNUM = 2 AND DefBillAccGUID <> 0x00 
			INSERT INTO #MatAccount([MatAccGUID]) 
				SELECT [MatAccGUID] 	FROM [ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
						WHERE  	[ma].[Type] = 1  AND [btSortNum] = 2 AND [btType] = 2 AND  [MatAccGUID] <> 0X00 
			 
			IF NOT EXISTS( SELECT * FROM #MatAccount A inner join ac000 b on b.guid = [MatAccGUID] WHERE finalGuid = @Final )-- INNER JOIN [#FinalAccTbl] F ON f.acGuid = b.finalGuid) 
				SET @FinalType = 1 
			ELSE 
				SET @FinalType = 0 
			TRUNCATE TABLE #MatAccount 
		END  
	END  
	ELSE  
		SET  @FinalType = 0 
	SET @DelPrice = 1 
	DECLARE		@FPStDate DATETIME 
	SET @FPStDate = @StartDate 
	IF @FinalType = 1 
	BEGIN 
		SET @FPStDate = '1/1/1980' 
		SET @StDate = DATEADD(day,-1,@StartDate) 
		EXEC [prcGetQnt]  
			'1/1/1980',@StDate, 
			@MatGUID, @GroupPtr,  
			@StGUID, @CostGUID,  
			@MatType, @DetailsStores,  
			@SrcTypes, @ShowUnLinked  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
			EXEC [prcGetLastPrice] '1/1/1980',@StDate, @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
			EXEC [prcGetMaxPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
			EXEC [prcGetAvgPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
			EXEC [prcGetLastPrice] '1/1/1980',@StDate , @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType,	@CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
		ELSE IF @PriceType = 2 AND @PricePolicy = 125 
			EXEC [prcGetFirstInFirstOutPrise] '1/1/1980',@StDate,@CurPtr	 
		ELSE 
		BEGIN  
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurPtr, @CurVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3 
			SET @DelPrice = 0 
		END  
		INSERT INTO [#PricesQtys] 
		SELECT  
			[q].[MatGUID],  
			ISNULL([p].[Price],0),  
			ISNULL([q].[Qnt],0),  
			[q].[StoreGUID]  
		FROM  
			[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID]  
		IF  @havePriceBySN > 0 
		BEGIN 
			INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price])  
				EXEC repMatSNBSheet @CurPtr, 0x00, '1/1/1980',@StDate 
		END 
		INSERT INTO #MatAccount		   		 
			SELECT					   		 
				[ObjGUID],			    
				[MatAccGUID], 
				0 
			FROM      
				[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
			WHERE   
				[ma].[Type] = 1    
				AND [btSortNum] = 1		-- »÷«⁄… √Ê· „œ… 
				AND [btType] = 2 
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 1  
		INSERT INTO #t_AccGoods 
		SELECT   
			ISNULL([mAcc].[MatAccGUID], @TypeAccGuid2), 
			[Pq].[Qnt], 
			[Pq].[Price], 
			0X00, 
			-1	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄«  
		FROM 
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc]  
			ON [Pq].[MatGUID] = [mAcc].[MatGUID]  
		INSERT INTO [#t_Goods]   
		SELECT  
			ISNULL([tg].[acGUID],0x0), 
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
			ISNULL([acFinal],0x0), 
			ISNULL([acParent],0x0), 
			ISNULL([acCurrencyPtr],0x0), 
			ISNULL([acCurrencyVal], 1)l, 
			SUM(ISNULL(acQty * acPrice, 0)), 
			0, 
			[acSecurity] 
		FROM  
			[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID] 
		GROUP BY 
			ISNULL([tg].[acGUID],0x00), 
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
			ISNULL([acFinal],0x00), 
			[acParent], 
			[acCurrencyPtr], 
			[acCurrencyVal], 
			[acSecurity] 
		INSERT INTO #MatAccount([MatAccGUID]) SELECT @TypeAccGuid2 
		 
	------------------------------------------------------ 
		Exec [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods] 
		--»÷«⁄… √Ê· «·„œ… 
		INSERT INTO #EResult     
		SELECT       
			[t].[acGUID],     
			[t].[AcCodeName],     
			[t].[AcCodeLatinName],     
			[t].[acFinal],     
			[t].[acParent], 
			0,  
			[t].[acCurPtr],      
			[t].[acCurVal],       
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END,  
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END,  
			0,0, 
			[al].[level] + 1,     
			[al].[path],     
			0,     
			1,      
			1,      
			@UserSec, 
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			CASE WHEN ([t].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END, 
			[f].[Id] 
		FROM     
			[#t_Goods] AS [t] 
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal] 
	 
		IF @DelPrice > 0  
			TRUNCATE TABLE 	[#t_Prices]  
		TRUNCATE TABLE  [#t_Qtys] 
		TRUNCATE TABLE  [#PricesQtys] 
		TRUNCATE TABLE #t_AccGoods 
		TRUNCATE TABLE [#t_Goods] 
	END	 
	 
	EXEC [prcGetQnt]  
	@FPStDate,@EndDate, 
	@MatGUID, @GroupPtr,  
	@StGUID, @CostGUID,  
	@MatType, @DetailsStores,  
	@SrcTypes, @ShowUnLinked  
	 
	--8 Get last Prices  
	 
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
		EXEC [prcGetLastPrice] @FPStDate,@EndDate, @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
		EXEC [prcGetMaxPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
		EXEC [prcGetAvgPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
		EXEC [prcGetLastPrice] @FPStDate , @EndDate , @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType,	@CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
	ELSE IF @PriceType = 2 AND @PricePolicy = 125 
		EXEC [prcGetFirstInFirstOutPrise] @FPStDate , @EndDate,@CurPtr	 
	ELSE  
	BEGIN 
		IF @FinalType = 0 
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurPtr, @CurVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3  
	END 
	 
	---- Get Qtys And Prices  
	 
	 
	-- you must use left join cause if details stores you have more than one record for each mat  
	INSERT INTO [#PricesQtys] 
	SELECT  
		[q].[MatGUID],  
		ISNULL([p].[Price],0),  
		ISNULL([q].[Qnt],0),  
		[q].[StoreGUID]  
	FROM  
		[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID]  
	IF  @havePriceBySN > 0 
	BEGIN 
		INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price])   
			EXEC repMatSNBSheet @CurPtr, 0x00, @FPStDate , @EndDate 
	END 
	 
	-- Add MatAccount in ma  
	-------------------------------------------------- 
	-- »÷«⁄… ¬Œ— „œ… («·„Ì“«‰Ì…) 
	-------------------------------------------------- 
	INSERT INTO #MatAccount 
		SELECT  
			[ObjGUID], 
			[MatAccGUID], 
			1 
		FROM      
			[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
		WHERE   
			[ma].[Type] = 1    
			AND [btSortNum] = 2		-- »÷«⁄… ¬Œ— „œ… 
			AND [btType] = 2 
	 
	-------------------------------------------------- 
	 -- »÷«⁄… ¬Œ— «·„œ… («·„ «Ã—…) 
	-------------------------------------------------- 
	INSERT INTO [#MatAccount] 
		SELECT  
			[ObjGUID], 
			[DiscAccGUID], 
			2		 
		FROM      
			[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
		WHERE   
			[ma].[Type] = 1   		-- Material Only 
			AND [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ… 
			AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ… 
	 
	INSERT INTO #t_AccGoods 
		SELECT   
			ISNULL([mAcc].[MatAccGUID], 0x0), 
			[Pq].[Qnt], 
			CASE ISNULL([AccType], 1) WHEN 1 THEN [Pq].[Price] 
			WHEN 2 THEN [Pq].[Price] * -1 END, 
			ISNULL([Pq].[StoreGUID], 0x0), 
			ISNULL([AccType], 0)	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄«  
		FROM 
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc]  
			ON [Pq].[MatGUID] = [mAcc].[MatGUID]  
	 
	 
	-- ”Ì „  ﬂ—«— ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… «·€Ì— „ÊÃÊœ… ›Ì Õ”«»«  «·„Ê«œ „‰ √Ã· «·„ «Ã—…  
	INSERT INTO [#t_AccGoods] 
		SELECT   
			[acGUID],   
			[acQty], 
			[acPrice],	 
			[StoreGUID], 
			-1 
		FROM  
			[#t_AccGoods] ac 
		WHERE [ac].[AccType] = 0 
	 
		 
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„ «Ã—… 
	IF (@DetailSubStores = 0 )-- AND (@StGUID <> 0X0) 
	BEGIN 
		UPDATE [t] 
		SET   
			[AcGUID] = ISNULL([st].[AccountGuid],0x00), 
			[acPrice] = -1 * [acPrice] 
		FROM  [#t_AccGoods] AS [t] INNER JOIN [st000] AS [st] ON [st].[Guid] = [t].[StoreGUID] 
		WHERE    
				[t].[AcGUID] = 0x00 AND [t].[AccType] = -1 AND ISNULL([st].[AccountGuid],0x00) <> 0x00 
		 
		 
	END  
	SELECT @TypeAccGuid1 = [bt].[btDefDiscAcc]  FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2  
	UPDATE [#t_AccGoods] 
		SET   
			[AcGUID] = @TypeAccGuid1,   
			 
			[acPrice] = -1 * [acPrice] 
		WHERE    
			[#t_AccGoods].[AcGUID] = 0x0 AND [#t_AccGoods].[AccType] = -1 
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2  
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„Ì“«‰Ì… 
		UPDATE [#t_AccGoods] 
		SET   
			[AcGUID] =  @TypeAccGuid2 
			 
		WHERE    
			[#t_AccGoods].[AcGUID] = 0x0 
	--================================================================= 
	--========================= END Calc AccGoods ===================== 
	--================================================================= 
	INSERT INTO [#t_Goods]   
	SELECT  
		ISNULL([tg].[acGUID],0x0), 
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
		ISNULL([acFinal],0x0), 
		ISNULL([acParent],0x0), 
		ISNULL([acCurrencyPtr],0x0), 
		ISNULL([acCurrencyVal], 1)l, 
		SUM(ISNULL(acQty * acPrice, 0)), 
		0, 
		[acSecurity] 
	FROM  
		[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID] 
	GROUP BY 
		[tg].[acGUID], 
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
		[acFinal], 
		[acParent], 
		[acCurrencyPtr], 
		[acCurrencyVal], 
		[acSecurity] 
	------------------------------------------------------ 
	Exec [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods] 
	--================================================================= 
	--Get List of sorted final Accounts 
	 
	 
	 
	CREATE CLUSTERED INDEX [find] ON [#FinalAccTbl]([acGUID]) 
	--======================================================================== 
	Exec [prcCheckSecurity] @UserGUID, 0, 0, [#FinalAccTbl]	 
	-- ÌÕÊÌ ‘Ã—… Õ”«»«  „— »…   «»⁄… ·Õ”«» ›—⁄Ì ÌŒ „ »«·Õ”«» «·Œ «„Ì «·„Õœœ     
	-- sotrted AccList contains parentAcc & SubAccount for a specific final Acc      
	 
	DECLARE @MinLevel INT 
	SELECT 	@MinLevel = MIN([level]) FROM   [#AccountsList] 
	if 	@MinLevel > 0 
		UPDATE [#AccountsList] SET [level] = [level] - @MinLevel 
	SELECT       
			[al].[GUID],		     
			[ac].[acCode] + '-' + [ac].[acName] AS [acCodeName],     
			[ac].[acCode] + '-' + [ac].[acLatinName] AS [acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			[al].[level] AS [acLevel],     
			[al].[path],     
			[ac].[acSecurity],     
			[f].[Level] AS fLevel,   -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
			[f].[Id] 
		INTO 	[#AccountsTree] 
		FROM 
			[#AccountsList] AS [al]   
			INNER JOIN [vwAc] AS [ac] ON [al].[GUID] = [ac].[acGUID] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [ac].[acFinal] 
	 
	CREATE CLUSTERED INDEX InAccTree ON [#AccountsTree]([GUID]) 
	--================================================================ 
	SELECT  
		[ce].[ceSecurity], 
		[acCodeName], 
		[acCodeLatinName],  
		[en].[AccountGuid],  
		[en].[Date] AS EnDate,  
		[en].[Debit] AS [EnDebit],  
		[en].[Credit]AS [EnCredit],  
		[en].[CurrencyGuid],  
		[en].[CurrencyVal], 
		[al].[acFinal],     
		[al].[acParent],  
		[al].[acDebitOrCredit],     
		[al].[acCurrencyPtr],     
		[al].[acCurrencyVal], 	     
		[al].[acLevel],     
		[al].[path],     
		[al].[fLevel], 
		[al].[acSecurity],  
		[dbo].[fnCurrency_fix](1, [en].[CurrencyGuid], [en].[CurrencyVal], @CurPtr, [en].[Date]) AS [CurFact], 
		CASE [al].[acCurrencyPtr]      
				WHEN @CurPtr THEN 0      
				ELSE       
					CASE [en].[CurrencyGuid]       
						WHEN [al].[acCurrencyPtr] THEN [en].[Debit] / [en].[CurrencyVal]    	         
						ELSE 0       
					END         
		END AS [DebitCurAcc],      
		CASE [al].[acCurrencyPtr]      
			WHEN @CurPtr THEN 0     
			ELSE     
				CASE [en].[CurrencyGuid]       
					WHEN [al].[acCurrencyPtr]   THEN [en].[Credit] / [en].[CurrencyVal]      
					ELSE 0     
				END        
		END AS [CreditCurAcc], 
		CASE WHEN ([acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END AS [DFlag], 
		[ID]     
	INTO #RES2 
	FROM  
		[vwce] as [ce]  
		INNER JOIN [en000] AS en ON en.ParentGuid = ce.ceGuid 
		INNER JOIN [#AccountsTree] AS [al] ON [al].[GUID] = [en].[AccountGuid] 
	WHERE      
			[En].[Date] BETWEEN @StartDate AND @EndDate      
			AND ( (@CostGUID = 0x0) OR ([en].[CostGuid] IN (SELECT CostGUID FROM #CostTbl) ) )     			 
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND ceIsPosted = 1)        
				OR (@PostedType = 0 AND [ceIsPosted] = 0) )   
	--================================================================ 
	INSERT INTO [#EResult]     
		SELECT       
			[AccountGuid],     
			[acCodeName],     
			[acCodeLatinName],     
			[acfinal],     
			[acParent],  
			[acDebitOrCredit],     
			[acCurrencyPtr],      
			[acCurrencyVal],       
			SUM([EnDebit]*[CurFact]),     
			SUM([EnCredit]*[CurFact]),     
			SUM([DebitCurAcc]),      
			SUM([CreditCurAcc]),      
			[aclevel] + 1,     
			[path],     
			0,     
			[ceSecurity],      
			[acSecurity],      
			@UserSec, 
			[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			[DFlag], 
			[ID]  
		FROM     
			[#Res2] 
		GROUP BY  
			[AccountGuid],     
			[acCodeName],     
			[acCodeLatinName],     
			[acfinal],     
			[acParent],  
			[acDebitOrCredit],     
			[acCurrencyPtr],      
			[acCurrencyVal],       
			[aclevel],     
			[path],     
			[ceSecurity],      
			[acSecurity],      
			[fLevel], 
			[DFlag], 
			[ID]    
	--------------------------------------------------------------- 
	-- ≈÷«›… »÷«⁄… ¬Œ— «·„œ… 
	--------------------------------------------------------------- 
	INSERT INTO #EResult     
		SELECT       
			[t].[acGUID],     
			[t].[AcCodeName],     
			[t].[AcCodeLatinName],     
			[t].[acFinal],     
			[t].[acParent], 
			0,  
			[t].[acCurPtr],      
			[t].[acCurVal],       
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END,  
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END,  
			0,0, 
			[al].[level] + 1,     
			[al].[path],     
			0,     
			1,      
			1,      
			@UserSec, 
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			CASE WHEN ([t].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END, 
			[f].[Id] 
		FROM     
			[#t_Goods] AS [t] 
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal] 
	 
	--======================================================================= 
			 
	INSERT INTO [#FinalResult]		 
	SELECT 
		[AcGuid], 
		[acCodeName], 
		[acCodeLatinName], 
		0x0, 
		[acParent], 
		[DebitOrCredit], 
		[AcCurPtr], 
		[AcCurVal], 
		0,0,0,0,		  
		0, 0, 2, 
		[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
		0, 
		1, -- IsFinalAccount
		[id] 
	FROM [#FinalAccTbl] 
	WHERE  
		[AcGuid] <> @Final 
	SELECT @MaxLevel = MAX([Level]) FROM [#EResult] WHERE [DFlag] =1 
	--Balnced Account 
	INSERT INTO [#T_RESULT] 
	SELECT [acGUID],CASE WHEN ABS(ISNULL(SUM([Debit]),0)- ISNULL(SUM(Credit),0))> dbo.fnGetZeroValuePrice() THEN 1 ELSE 0 END  
	FROM  [#EResult] 
	WHERE [DFlag] =1 
	GROUP BY [acGUID] 
	 
	UPDATE [#EResult] SET [Flag] = [t].[Flag] 
	FROM [#EResult] AS [r] INNER JOIN [#T_Result] AS [t] ON [r].[acGUID] =[t].[acGUID] 
	WHERE [r].[DFlag] =1  
	 
	SET @Level = @MaxLevel  
	------------------------------------------------------------ 
	Exec [prcCheckSecurity] @Result = '#EResult' 
	------------------------------------------------------------ 
	WHILE @Level >= 0 
	BEGIN  
		INSERT INTO [#EResult]      
		SELECT       
			[r].[acParent],		     
			[ac].[acCodeName],     
			[ac].[acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			SUM(IsNULL([Debit],0)),      
			SUM(IsNULL([Credit],0)),      
			SUM(IsNULL([CurDebit],0)),      
			SUM(IsNULL([CurCredit],0)),     
			[ac].[aclevel] + 1,     
			[ac].[path],     
			1,     
			1,	-- ’·«ÕÌ… «·”‰œ«      
			[ac].[acSecurity],     
			@UserSec, 
			[ac].[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
			SUM([Flag]), 
			CASE WHEN ([ac].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END, 
			[ac].[id] 
		FROM 
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] = [ac].[acFinal]  
		WHERE  
			[r].[Level] = @Level AND [r].[DFlag] = 1   
		GROUP BY 
			[r].[acParent], 
			[ac].[acCodeName],     
			[ac].[acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			[ac].[aclevel],     
			[ac].[path],      
			[ac].[acSecurity], 
			[ac].[fLevel], 
			[ac].[id]  
		 
		UPDATE [r] 
			SET [Level] = @Level - 1,[acParent] = [ac].[acParent] 
		FROM 
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] <> [ac].[acFinal] 
		WHERE  
			[r].[Level] = @Level AND [r].[DFlag] = 1  
			  
		SET @Level = @Level - 1    
	END	 
	------------------------------------------------------------ 
	UPDATE [#EResult] SET [Level] = 1,[acParent] = 0X00 WHERE [acParent] <> 0X00 AND [acParent] NOT IN (SELECT  [GUID] FROM [#AccountsTree]) 
	SELECT @MaxLevel = ISNULL(MAX([ac].[Level]),0) 
	FROM 
			[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1 
		WHERE  
			[r].[DFlag] = 1    
	SET @Level = 0 
	IF @MaxLevel > 0 
	BEGIN 
		WHILE @Level <= @MaxLevel 
		BEGIN  
			UPDATE [r] 
				SET [Level] = [ac].[Level] + 1 
			FROM 
				[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1 
			WHERE  
				[ac].[Level] = @Level AND [r].[DFlag] = 1    
			SET @Level = @Level + 1    
		END	 
	END 
	------------------------------------------------------------ 
	INSERT INTO [#FinalResult] 
	SELECT     
		[acGUID],    
		[acCodeName],    
		[acCodeLatinName],    
		[acFinal],    
		[acParent],  
		[DebitOrCredit],     
		[acCurPtr],     
		[acCurVal],     
		SUM( ISNULL([Debit],0) ),    
		SUM( ISNULL([Credit],0) ),    
		SUM( ISNULL([CurDebit],0) ),     
		SUM( ISNULL([CurCredit],0) ),    
		[Level] - 1 ,    
		[Path], 
		[RecType], 
		[fn_AcLevel]  , 
		SUM([Flag]),
		0, 
		[id]   
	FROM      
		[#EResult]  
		WHERE [DFlag] = 1 AND [Level] <= @accLevel 
	GROUP BY      
		[acGUID],  
		[acCodeName],  
		[acCodeLatinName],  
		[acFinal],  
		[acParent],  
		[DebitOrCredit],  
		[acCurPtr],  
		[acCurVal],  
		[Level],  
		[Path], 
		[RecType],    
		[fn_AcLevel], 
		[id] 
	 
	INSERT INTO [#FinalResult] 
	SELECT 
		[f].[AcGuid], 
		[f].[acCodeName], 
		[f].[acCodeLatinName], 
		0x0, 
		[f].[acParent], 
		[f].[DebitOrCredit], 
		[f].[AcCurPtr], 
		[f].[AcCurVal], 
		SUM( ISNULL([Debit],0) ),    
		SUM( ISNULL([Credit],0) ),    
		SUM( ISNULL([CurDebit],0) ),     
		SUM( ISNULL([CurCredit],0) ),    
		0, 0,  
		1, 
		[fn_AcLevel] , 
		SUM([FLAG]), 
		0,
		[f].[id]    
	FROM      
		[#EResult] AS [r]  INNER JOIN [#FinalAccTbl] AS [f] ON [r].[acFinal] = [f].[AcGuid] 
	WHERE ABS(ISNULL([Debit],0) - ISNULL([Credit],0))> 0 AND [r].[DFlag] = 0 
	GROUP BY  
		[f].[AcGuid], 
		[f].[acCodeName], 
		[f].[acCodeLatinName], 
		[f].[acParent], 
		[f].[DebitOrCredit], 
		[f].[AcCurPtr], 
		[f].[AcCurVal], 
		[fn_AcLevel], 
		[f].[id]       
	 
	IF @RateType = 1 
	BEGIN 
		IF @CurVal = 0 
			SET @CurVal = 1 
		UPDATE	[#FinalResult]  
			SET [Debit] = [Debit] / @CurVal,[Credit] = [Credit] / @CurVal 
	END 


	UPDATE #finalResult	SET
		DebitOrCredit = ac.IsDebit
	FROM #finalResult AS f
	INNER JOIN (SELECT	fChild.acGUID AS AccountGuid,
						CASE WHEN fParent.Balance >= 0 THEN 1 ELSE 0 END AS IsDebit
					FROM 
						(SELECT acCodeName, acGuid, Debit - Credit AS Balance 
							FROM #finalResult 
							WHERE [Level] = 0 AND acParent = 0x0
							--fn_Aclevel = 0 
						)	
						AS fParent 
						CROSS APPLY fnGetAccountsList(fParent.acGUID, 1) AS Child
						INNER JOIN #finalResult AS fChild ON fChild.acGUID = Child.[GUID]
				) AS ac ON ac.AccountGuid = f.acGUID
	
	SELECT * FROM #FinalResult
	
	SELECT
		--d.acGUID,
		--ISNULL(d.number, 9999999) AS DNumber,
		--d.FinalAccountIdentity,
		--d.Debit,
		--d.Credit,
		--ISNULL(d.[Path],'9999') AS DebitPath,
		--c.acGUID,
		--c.Credit,
		--c.Credit,
		--c.[Level],
		--ISNULL(c.[Path],'9999') AS CreditPath,
		--ISNULL(c.number, 9999999) AS CNumber,
		--c.FinalAccountIdentity
		--ISNULL(d.number, 9999999) AS DNumber,
		
		ISNULL(d.acCodeName, '') AS DebitAccountCodeName,
		ISNULL(d.Debit - d.Credit, 0) AS DebitAccountBalance,
		ISNULL(d.[Level], 999) AS DebitAccountLevel,
		ISNULL(c.acCodeName, '') AS CreditAccountCodeName,
		ISNULL(c.Credit - C.Debit, 0) AS CreditAccountBalance,
		ISNULL(c.[Level], 999) AS CreditAccountLevel,
		CASE WHEN ISNULL(d.IsFinalAccount, 0) = 1 OR ISNULL(c.IsFinalAccount, 0) = 1
			THEN 1 ELSE 0 END AS IsFinalAccountRecord
		
	FROM	
		(SELECT *, ROW_NUMBER() OVER(PARTITION BY FinalAccountIdentity, IsFinalAccount, DebitOrCredit ORDER BY FinalAccountIdentity, fn_AcLevel, [Path]) AS number  FROM #finalResult 
			WHERE DebitOrCredit = 1
			--ORDER BY [PATH]
			) AS d
		
		FULL JOIN 
		
		(SELECT *, ROW_NUMBER() OVER(PARTITION BY FinalAccountIdentity, IsFinalAccount, DebitOrCredit ORDER BY FinalAccountIdentity, fn_AcLevel, [Path]) AS number FROM #finalResult 
			WHERE DebitOrCredit = 0
			--ORDER BY [PATH]
			) AS c 
			ON c.acFinal = d.acFinal AND d.acGUID <> c.acGUID AND d.number = c.number
			
	ORDER BY ISNULL(d.FinalAccountIdentity,ISNULL(c.FinalAccountIdentity,9999)), ISNULL(d.number,ISNULL(c.Number,99999)), ISNULL(d.[Path], ISNULL(c.[Path], '99999'))
	
	--SELECT
	--	d.acGUID,
	--	d.acCodeName,
	--	d.Debit,
	--	d.Credit,
	--	d.debit - d.credit
	--FROM	
	--	 #Result as d
		 
		 
	--SELECT
	--	d.acFinal,
	--	d.Debit,
	--	d.Credit,
	--	ROW_NUMBER() OVER(ORDER BY d.acfinal) as f,  
	--	SUM(d.debit - d.credit) OVER(PARTITION BY d.acFinal) AS 'Total'
 
	--FROM	
	--	 #Result as d
		 
	 

		--select name, code, ROW_NUMBER() over(order by name) as number
--from ac000

			
	----------------------------------------------------------------------  
	--SELECT * FROM [#SecViol]     
	----------------------------------------------------------------------  
	--SELECT 	Count(*) As [AccNull] FROM [vwbt]  
	--WHERE   
	--	[btType] = 2  
	--	AND [btSortNum] = 2    
	--	AND ( (ISNULL([btDefDiscAcc], 0x0) = 0x0) OR ( ISNULL([btDefBillAcc], 0x0) = 0x0) )  

#########################################################
CREATE PROCEDURE ARWA.prcGetDefaultCurrency
	@lang varchar(2)
AS 
	SELECT 
		GUID, 
		(CASE @lang
			WHEN 'ar' THEN Name
			ELSE LatinName
		END) Name 
	FROM 
		my000 
	WHERE 
		GUID = (SELECT TOP 1 value FROM op000 WHERE [Name] = 'AmnCfg_DefaultCurrency')
#########################################################
CREATE PROCEDURE ARWA.prcFinilize_Environment
	@ProcedureName VARCHAR(250)
AS 
      SET NOCOUNT ON 
      
      -- EXEC [prcEndLog] @ProcedureName
      DELETE Connections WHERE spid = @@SPID
#########################################################
CREATE PROCEDURE ARWA.prcGeneralLedger
	-- Report Filters
	@AccountGUID							[UNIQUEIDENTIFIER] = '4B09D808-2DE5-4167-AAE8-CD300A2FE8EB',			-- Account   
	@JobCostGUID							[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000',			-- Cost Job   
	@FromLastConsolidationDate				[BIT]              = 0, 												-- From Last Check Date   
	@StartDate								[DATETIME]         = '1/1/2009 0:0:0.0',								-- StartDate
	@EndDate								[DATETIME]         = '12/14/2010 23:59:35.21',							-- @EndDate
	@CurrencyGUID							[UNIQUEIDENTIFIER] = '0177fdf3-d3bb-4655-a8c9-9f373472715a',		    -- @CurrencyGUID  
	@Class									[VARCHAR](256)     = '',												-- Class      
	@ShowUnposted							[BIT]              =  1,  												-- ShowUnPosted
	@Level									[INT]              =  0,  												-- Level For Account      
	@NotesContain							[VARCHAR](256)     = '',												-- The Note Of Entry contain ...      
	@NotesNotContain						[VARCHAR](256)     = '',												-- The Note Of Entry Not contain ...      
	@ShowPreviousBalance					[BIT]              = 1,													-- Show PrvBalance
	@ContraAccount							[UNIQUEIDENTIFIER] = 0x0,												-- Fillter Entry with Obverse Account       
	@MergeAccountItemsInEntry				[BIT] = 0,																-- 0: let the entry , 1: merge the entry for same Account      
	@ShowEntrySource						[BIT] = 0,																-- ≈ŸÂ«— √’· «·”‰œ  
	@ItemChecked							[INT] = 2,																-- ≈ŸÂ«— «·„œﬁﬁ / €Ì— «·„œﬁﬁ : 0, 1, 2   
	@ShowEmptyBalances						[BIT] = 1,																-- ≈ŸÂ«— «·Õ”«»«  «·›«—€…  
	@MergeNotePapersEntries					[BIT] = 0	,															-- œ„Ã ”‰œ«  «·√Ê—«ﬁ «·„«·Ì… –«  ‰›” «·—ﬁ„  
	@ShowBranch								[BIT] = 0 ,																-- ShowBranch 
	@ShowContraAccount						[BIT] = 0,																-- ShowContraAcc
	@SelectedUserGUID						UNIQUEIDENTIFIER = 0X00,												-- Filter Result By @SelectedUserGUID
	@ShowUser								BIT = 0,  
	-----------------Report Sources-----------------------
	@SourcesTypes							VARCHAR(MAX) = '00000000-0000-0000-0000-000000000000, 1',			   -- SourcesTypes
	------------------------------------------------------
	@ShowEntryNumber						[BIT] = 0,															   --Show Entry Number
	@ShowOriginalCurrency					[BIT] = 0,                                                             --Show Original Currency
	@ShowJobCost       						[BIT] = 0,                                                             --Show Cost Point
	@ResetBalanceInPeriodStart				[BIT] = 0,															   --Reset Balance in Starting Period
	@ProcessContainInPreviousBalance		[BIT] = 0,															   --„⁄«·Ã… «·»Ì«‰ ›Ì «·—’Ìœ «·”«»ﬁ
	@ShowNotes  							[BIT] = 0,															   --Show note for entry and centry
	@ShowExchangeRateVariationsInCost  		[BIT] = 0,												   --≈ŸÂ«— ›—Êﬁ«  √”⁄«— «·’—› »«·ﬂ·›…
	@ShowFinalBalance						[BIT] = 0, 	     													   --≈ŸÂ«— «·—’Ìœ «·‰Â«∆Ì
	@ShowSumCheckedEntries					[BIT] = 0, 	     													   --≈ŸÂ«— „Ã„Ê⁄ «·√ﬁ·«„ «·„œﬁﬁ…
	@EachAccountInSeparatePage				[BIT] = 0,															   --ﬂ· Õ”«» ⁄·Ï Ê—ﬁ…
	@Lang									VARCHAR(100) = 'ar',												   --0 Arabic, 1 Latin
	@ShowClass								[BIT] = 0,															   --≈ŸÂ«— «·›∆…
	@UserGUID								[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',		   --Guid Of Logining User
	@ShowBalanceAsText						[BIT] = 0,															   --≈ŸÂ«—  ›ﬁÌÿ «·—’Ìœ
	@BranchMask								BIGINT = -1															   -- BranchMask				
AS        

	--prcInitialize_Environment
	EXEC [prcInitialize_Environment] @UserGUID, '[prcGeneralLedger]', @BranchMask
	
	
	SET NOCOUNT ON   
	-------------------TEST IF IsSingl Account-------------------
	Declare @IsSingl [INT], @NSons [INT], @AccType [INT]
	SET @NSons   = (SELECT [NSons] FROM [AC000] WHERE [GUID] = @AccountGUID)
	SET @AccType = (SELECT [Type] FROM [AC000] WHERE [GUID] = @AccountGUID)
	IF NOT(@NSons>0 OR @AccType = 4/*Composite*/)
		SET @IsSingl = 1
	ELSE
		SET @IsSingl = 0
	
	-------------------Prepare @PrevBalance---------------------
	-- 0 Without PrvBalance OR by ResetBalInStartPeriod - 1 PrvBalance Without CheckContain - 2 PrvBalance With CheckContain      
	DECLARE @PrevBalance [INT]
	IF (@ShowPreviousBalance = 0 OR @ResetBalanceInPeriodStart = 1)
		SET @PrevBalance = 0
	ELSE IF (@ShowPreviousBalance = 1)
		SET @PrevBalance = CAST(@ShowPreviousBalance AS INT) + @ProcessContainInPreviousBalance
		
	------------------Prepare @CurVal----------------------------
	DECLARE @CurVal [FLOAT]
	SET @CurVal = (Select Top 1 IsNull(mh.CurrencyVal, my.CurrencyVal) 
				   From my000 my 
				   LEFT join mh000 mh on my.[Guid] = mh.[CurrencyGUID] 
				   WHERE my.[GUID] = @CurrencyGUID Order By mh.Date Desc)
	--SELECT @CurVal 
	-------------------------------------------------------------

	DECLARE @strContain AS [VARCHAR]( 1000)       
	DECLARE @strNotContain AS [VARCHAR]( 1000)       
	SET @strContain = '%'+ @NotesContain + '%'       
	SET @strNotContain = '%'+ @NotesNotContain + '%'       
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#BILLENTRY]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT ) 
	CREATE TABLE [#Bill]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT) 

	DECLARE @S VARCHAR(1000) 
	SET @s = ' SELECT buGuid, buSecurity FROM vwbu' 

	INSERT INTO [#BILL] EXEC (@s) 
	INSERT INTO [#BILLENTRY] SELECT ce.GUID , ce.SECURITY FROM CE000 ce INNER JOIN ER000 er ON Ce.GUID = er.ENTRYGUID WHERE PARENTTYPE = 2 AND PARENTGUID IN (SELECT GUID FROM [#BILL]) 
	------------------------------------------------------------------ 
	------------------------------------------      
	CREATE TABLE #Account_Tbl  ( [GUID] [UNIQUEIDENTIFIER], [Level] [INT] , CheckDate [DATETIME], [Path] [VARCHAR](4000) COLLATE ARABIC_CI_AI,acCode [VARCHAR](250) COLLATE ARABIC_CI_AI,[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI, [acSecurity] INT)      
	IF( @IsSingl <> 1)  
		INSERT INTO #Account_Tbl SELECT [fn].[GUID], [fn].[Level], '1-1-1980', [fn].[Path],[Code],[Name],[LatinName],[Security] FROM [dbo].[fnGetAccountsList]( @AccountGUID, 1) AS [Fn] INNER JOIN [ac000] AS [ac] ON [Fn].[GUID] = [ac].[GUID]  
	ELSE  
		INSERT INTO #Account_Tbl SELECT [acGUID], 0, '1-1-1980', '',[acCode],[acName],[acLatinName], [acSecurity]  FROM [vwAc] WHERE [acGUID] = @AccountGUID  
	IF( @FromLastConsolidationDate = 1)  
		UPDATE Acc SET CheckDate = ch.CheckedToDate  
		FROM   
			#Account_Tbl Acc  
			INNER JOIN (   
				SELECT AccGUID, MAX( CheckedToDate) CheckedToDate   
				FROM checkAcc000   
				WHERE CheckedToDate < @EndDate GROUP BY AccGUID) ch  
			ON Acc.Guid = ch.AccGUID  
	CREATE CLUSTERED INDEX  Account_TblIND ON #Account_Tbl(Guid)  
	CREATE TABLE #AccObverse_Tbl  ( [GUID] [UNIQUEIDENTIFIER],  
					[acCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acSecurity] [INT])   
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	IF( ISNULL( @ContraAccount, 0x0) = 0x0)   
	BEGIN  
		INSERT INTO #AccObverse_Tbl  
			SELECT   
				[GUID], [Code], [Name], [LatinName], [Security]   
			FROM [ac000]   
			union all   
			select   
				0x00, '', '', '', 0  
			IF @ShowContraAccount = 0  
				UPDATE #AccObverse_Tbl SET  [acCode] = '', [acName] = '', [acLatinName] = '', [acSecurity]  = 0  
			  
	END  
	ELSE   
		INSERT INTO #AccObverse_Tbl   
			SELECT   
				[fn].[GUID], [ac].[Code], [ac].[Name], [ac].[LatinName], [ac].[Security]  
			FROM   
				[ac000] as [ac] INNER JOIN [dbo].[fnGetAccountsList]( @ContraAccount, 0) AS [Fn]   
				ON [ac].[GUID] = [fn].[GUID]  
	CREATE CLUSTERED INDEX  AccObverse_TblIND ON #AccObverse_Tbl(Guid)  
	------------------------------------------   
	CREATE TABLE #Cost_Tbl ( [GUID] [UNIQUEIDENTIFIER], [SEC] INT )   
	--INSERT INTO #Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @JobCostGUID)    
	INSERT INTO #Cost_Tbl  EXEC [prcGetCostsList] @JobCostGUID
	IF ISNULL( @JobCostGUID, 0x0) = 0x0     
		--INSERT INTO #Cost_Tbl VALUES(0x00)    
		INSERT INTO #Cost_Tbl VALUES(0x00, 0)    
	--------------------------------------------------------------------------------------  
	--Source   
	--DECLARE  @UserId [UNIQUEIDENTIFIER],@HosGuid [UNIQUEIDENTIFIER]  
	--SET @UserId = [dbo].[fnGetCurrentUserGUID]()  
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
	--INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID--@UserID 
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] = 5
			
	
	--INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
									
	--INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] =  1
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]    

	
	--New way For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 3
	
	--New way For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 4
	

	------------------------------------------------------------------------------------------------------------------------   
	--  1 - Get the balance of Accounts     
	--  2 - Get the Previos balance of Accounts (option)      
	------------------------------------------------------------------------------------------------------------------------      
	-- STEP 1    
	 
	CREATE TABLE [#Result] (      
			[CeGUID] [UNIQUEIDENTIFIER],      
			[enGUID] [UNIQUEIDENTIFIER],   
			[CeNumber] [FLOAT],      
			[ceDate] [DATETIME],      
			[enNumber] [FLOAT],      
			[AccGUID] [UNIQUEIDENTIFIER],      
			[acCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[enDebit]	[FLOAT],      
			[enCredit] [FLOAT],      
			[enFixDebit] [FLOAT],      
			[enFixCredit] [FLOAT],      
			[enCurPtr] [UNIQUEIDENTIFIER],      
			[enCurVal] [FLOAT] DEFAULT 0,      
			--ObverseGUID [UNIQUEIDENTIFIER],      
			[ObvacCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ObvacName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ObvacLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[CostGUID] [UNIQUEIDENTIFIER],      
			[enNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
			[ceNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,         
			[ceParentGUID] [UNIQUEIDENTIFIER],       
			[ceRecType] [INT],       
			[Path] [VARCHAR](4000),      
			[Type] [INT],      
			[PrevBalance] [FLOAT],
			[coSecurity] [INT],      
			[ceSecurity] [INT],      
			[accSecurity] [INT],    
			--AccSecurity [INT],  
			[ParentNumber] [INT],   
			[ParentName] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
			[IsCheck]  [INT] DEFAULT 0,  
			[ceTypeGuid] [UNIQUEIDENTIFIER],  
			[NtNumber] [VARCHAR](250) COLLATE ARABIC_CI_AI, -- Note Number  
			[NtFlg] INT,  
			[Class] [VARCHAR](250) COLLATE ARABIC_CI_AI,									-- Consolidate Notes?   
			[Branch] [UNIQUEIDENTIFIER],  
			[UserName] VARCHAR(100) COLLATE ARABIC_CI_AI,  
			[Posted] BIT DEFAULT 1, 
			[CeParentType]	INT 
			)     
	---------------------------------------------------------------------------------------------  
	INSERT INTO [#Result]      
		SELECT      
			[ceGUID],       
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x00 ELSE [enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [enNumber] END,   
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName],  
			SUM( [enDebit]),      
			SUM( [enCredit]),      
			SUM( [FixedEnDebit]),      
			SUM( [FixedEnCredit]),      
			[enCurrencyPtr],      
			[enCurrencyVal],      
			[AcObv].[acCode],  
			[AcObv].[acName],  
			[AcObv].[acLatinName],  
			[enCostPoint],  
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			0x0,		--ParentGUID,    
			0,		--ceRecType,    
			[AC].[Path],      
			1, 		-- 0 Main Account 1 Sub Account      
			0,
			[Cost].[SEC],      
			[ceSecurity],      
			[ac].[acSecurity],    
			--AcObv.acSecurity,  
			0,		--ceParentNumber,   
			'',		--ceTypeAbbrev,   
			0, 		-- isCheck   
			[ceTypeGuid],  
			'', 		-- NtNumber  
			0,  
			[enclass],  
			[ceBranch],'',ceIsPosted ,er.ParentType 
		FROM     
			([dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE]  --Select * From [dbo].[fnSecCostsInBranches] ('D1F944DD-2DD0-4D38-BE3E-C40C2C3C5576')
			INNER JOIN #Account_Tbl AS [AC] ON [CE].[enAccount] = [AC].[GUID])      
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]  
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON  [CE].[enContraAcc] = [AcObv].[GUID]  
			LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid    
		WHERE      
			( ( @FromLastConsolidationDate = 0 AND [CE].[enDate] BETWEEN @StartDate AND @EndDate)      
			  OR ( @FromLastConsolidationDate = 1 AND [CE].[enDate] BETWEEN DATEADD(dd,1,[AC].[CheckDate]) AND @EndDate) )      
			AND ( @Class = '' OR [enClass] = @Class)      
			AND ( @ShowUnposted = 1 OR [ceIsPosted] = 1)      
			AND ( @NotesContain = '' or [enNotes] Like @strContain or [ceNotes] Like @strContain)      
			AND ( @NotesNotContain = '' or ( [enNotes] NOT Like @strNotContain and [ceNotes] NOT Like @strNotContain))      
			AND ((src.[Type] IS NOT NULL) OR er.ParentType = 303)  
		GROUP BY     
			[ceGUID],       
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x00 ELSE [enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [enNumber] END,  
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName],  
			[enCurrencyPtr],      
			[enCurrencyVal],      
			--enContraAcc,      
			[AcObv].[acCode],  
			[AcObv].[acName],  
			[AcObv].[acLatinName],  
			[enCostPoint],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			[AC].[Path],
			[Cost].[SEC],      
			[ceSecurity],      
			[ac].[acSecurity],    
			--AcObv.acSecurity,  
			[ceTypeGuid],  
			[enclass],  
			[ceBranch],ceIsPosted,er.ParentType 
			
	IF( @MergeNotePapersEntries = 1)  
	BEGIN  
		-- Set flag for entries to merged  
		UPDATE [Res] SET   
			[NtNumber] = [ch].[chNum],  
			[enNotes] = [ch].[chNotes],			  
			[NtFlg] = 1  
		FROM  
			[#Result] AS [Res]  
			INNER JOIN [vwEr] AS [er]   
			ON [Res].[ceGuid] = [er].[erEntryGuid]    
			INNER JOIN [vwch] AS [ch]  
			ON [ch].[chGuid] = [er].[erParentGuid]  
		-- insert merged entry  
		INSERT INTO [#Result]  
		SELECT  
			0x0, --[CE].[ceGUID],       
			0x0, --CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			0, --[CE].[ceNumber],       
			[Res].[ceDate],  
			0, --CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [CE].[enNumber] END,   
			[Res].[AccGuid],      
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName],  
			SUM( [Res].[enDebit]),      
			SUM( [Res].[enCredit]),      
			SUM( [Res].[enFixDebit]),      
			SUM( [Res].[enFixCredit]),      
			[Res].[enCurPtr],  
			[Res].[enCurVal],      
			--enContraAcc,      
			'', --[AcObv].[acCode],  
			'', --[AcObv].[acName],  
			'', --[AcObv].[acLatinName],  
			[Res].[CostGUID],  
			[Res].[NtNumber] + (case [dbo].[fnConnections_GetLanguage]() when 0 then ' («·»Ì«‰: ' else ' (Note: '  end) +   
				max( [Res].[enNotes]) + ')', --CASE WHEN @MergeAccountItemsInEntry = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,  
			'',  
			0x0,		--ParentGUID,    
			[RES].[ceRecType],--ceRecType,    
			[Res].[Path],  
			1, 		-- 0 Main Account 1 Sub Account      
			0,
			[Res].[coSecurity],   
			[Res].[ceSecurity],  
			[Res].[accSecurity],  
			--AcObv.acSecurity,  
			0,		--ceParentNumber,   
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),	--ceTypeAbbrev,   
			0, 		-- isCheck   
			--0x0 		-- UserCheckGuid   
			[Res].[ceTypeGuid],  
			'',  
			0,  
			[Res].[class],  
			[Res].[Branch],[UserName],[Posted] ,0 
		FROM     
			[#Result] AS [Res]  
			INNER JOIN [vwNt] AS [nt]  
			ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
		WHERE      
			[Res].[NtFlg] = 1  
		GROUP BY     
			--[CE].[ceGUID],       
			--CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			--[CE].[ceNumber],       
			[Res].[ceDate],      
			--CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [CE].[enNumber] END,  
			[Res].[AccGuid],  
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName],  
			[Res].[enCurPtr],  
			[Res].[enCurVal],  
			--enContraAcc,      
			--[AcObv].[acCode],  
			--[AcObv].[acName],  
			--[AcObv].[acLatinName],  
			[Res].[CostGUID],      
			[Res].[NtNumber],--CASE WHEN @MergeAccountItemsInEntry = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,      
			--ParentGUID,    
			--ceRecType,    
			[Res].[Path],  
			[RES].[ceRecType],
			[Res].[coSecurity],  
			[Res].[ceSecurity],      
			[Res].[accSecurity],    
			--AcObv.acSecurity,  
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),  
			[Res].[ceTypeGuid],  
			[Res].[class],  
			[Res].[Branch],[UserName],[Posted]  
		--///////////////////////////////////////////////////////  
		-----------------------------------  
		-- delete flaged entries  
		DELETE FROM #Result WHERE [NtFlg] = 1  
	END  
	IF (@SelectedUserGUID <> 0X00)  
	BEGIN  
		DELETE r FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid LEFT JOIN   
			(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime and u.Guid = @SelectedUserGUID) v ON v.[RecGuid] = isnull(er.parentguid,r.[CeGUID]) where v.[RecGuid] IS NULL  
	END  
	IF( @ShowEntrySource = 1) 
	BEGIN   
			UPDATE [#Result] SET   
				[ceParentGUID] = [er].[erParentGuid],    
				[ceRecType] = [er].[erParentType],    
				[ParentNumber] = [er].[erParentNumber]  
			FROM  
				[#Result] AS [Res]   
				INNER JOIN [vwEr] AS [er]   
				ON [Res].[ceGuid] = [er].[erEntryGuid]    
			IF( @ShowEntrySource = 1) 
			BEGIN 
			------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [bt].[btAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwBt] AS [bt]   
				ON [Res].[ceTypeGUID] = [bt].[btGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [et].[etAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwEt] AS [et]   
				ON [Res].[ceTypeGUID] = [et].[etGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET  
				[ParentName] = ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, '')  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwNt] AS [nt]  
				ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
			-------------------------------------------  
			------------------------ For Exchange System By Muhammad Qujah  ----------  
			UPDATE [#Result] SET   
				[ParentName] = [et].[Abbrev]  
			FROM  
				TrnExchange000 as ex   
				INNER JOIN TrnExchangeTypes000 AS [et]  
					ON [ex].[TypeGuid] = [et].[Guid]  
			where ceRecType = 507  
			END 
			------------------------ For Exchange System By Muhammad Qujah  ---------  
	END 

	-------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserGUID     
	
	DECLARE @IsFullResult [INT]
	SET @IsFullResult = 0
	----Filter Result by Security
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 )
	
	--SET @NumOfSecViolated = @@ROWCOUNT
	
	----Filter Result by Branches
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID))
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID))
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
	-------------------------------------------------------------------------------------    
	--IF( @ShowIsCheck = 1) Always Update isCheck because No CheckedField in result
	--BEGIN   
		--DECLARE @UserGUID [UNIQUEIDENTIFIER]   
		--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
		
		DECLARE @CheckForUsers INT
		SET @CheckForUsers = (SELECT CAST(VALUE AS INT) From OP000 WHERE NAME LIKE 'AmnCfg_CheckEntryForUsers')  
		
		UPDATE [Res]  
		SET    
			[isCheck] = 1   
			--UserCheckGuid = RCH.UserGuid   
		FROM    
			[#Result] AS [Res] INNER JOIN [RCH000] As [RCH]   
			ON [Res].[enGuid] = [RCH].[ObjGUID]  
		WHERE    
			(@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGUID/*@UserGUID*/)
			/*@rid  = [RCH].[Type]  
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGUID)) */ 
		IF( @ItemChecked <> 2)  
		BEGIN    
			IF( @ItemChecked = 1)   
				DELETE FROM [#Result] WHERE [isCheck] <> 1   
			ELSE   
				DELETE FROM [#Result] WHERE [isCheck] = 1   
			   
		END   
	--END   
	-------------------------------------------------------------------------------   
	DECLARE @BalanceTbl TABLE(      
				[AccGUID] [UNIQUEIDENTIFIER],      
				[AccParent] [UNIQUEIDENTIFIER],      
				[FixDebit] [FLOAT],      
				[FixCredit] [FLOAT],      
				[PrevBalance] [FLOAT],     
				[Lv] [INT] DEFAULT 0     
				)     
	-- create initial balance for the result table  
	INSERT INTO @BalanceTbl     
		SELECT     
			[AC].[GUID],      
			[acParent],     
			SUM( ISNULL([Res].[enFixDebit],0)),     
			SUM( ISNULL([Res].[enFixCredit],0)),     
			0 AS [PrevBal],     
			0 AS [Lv]     
		FROM     
			#Account_Tbl AS [AC] INNER JOIN [vwAc]  
			ON [vwAc].[acGUID] = [AC].[GUID]     
			LEFT JOIN [#Result] AS [Res]      
			ON [AC].[GUID] = [Res].[AccGUID]     
		GROUP BY     
			[AC].[GUID],      
			[acParent]     
	-- STEP 2 THE PREVIOS BALANCE      
	-- calc previous balances for result and accounts not in result and   
	-- has only a previous balance  
	IF @PrevBalance	> 0      
	BEGIN      
		CREATE TABLE [#Prev_B_Res] ( [AccGUID] [UNIQUEIDENTIFIER],   
						[enDebit]	[FLOAT],   
						[enCredit] [FLOAT],
						[coSecurity] [INT],   
						[ceSecurity] [INT],   
						[acSecurity] [INT],  
						[ceGuid]	UNIQUEIDENTIFIER)   
		INSERT INTO [#Prev_B_Res]   
		SELECT      
			[CE].[enAccount] AS [Account],     
			[CE].[FixedEnDebit] AS [Debit],      
			[CE].[FixedEnCredit] AS [Credit],   
			[Cost].[SEC],
			[CE].[ceSecurity],   
			[Acc].[acSecurity] ,[ceGuid]  
		FROM      
			[dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE]      
			INNER JOIN #Account_Tbl AS [Acc] On [Acc].[Guid] = [CE].[enAccount]     
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]         
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON ISNULL( [CE].[enContraAcc], 0x0) = [AcObv].[GUID]   
			LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid    
		WHERE      
			( ( @FromLastConsolidationDate = 0 AND [CE].[enDate] < @StartDate)    
			OR ( @FromLastConsolidationDate = 1 AND [CE].[enDate] <= DATEADD(mi,1439,[Acc].[CheckDate])) )   
			AND ( @Class = '' OR [CE].[enClass] = @Class)     
			AND ( @ShowUnposted = 1 OR [CE].[ceIsPosted] = 1)      
			AND ( @PrevBalance = 1 OR       
					( @PrevBalance = 2      
					AND ( @NotesContain = '' or [CE].[enNotes] Like @strContain or [CE].[ceNotes] Like @strContain)      
					AND ( @NotesNotContain = '' or ( [CE].[enNotes] NOT Like @strNotContain and [CE].[ceNotes] NOT Like @strNotContain))  
					)  
			)  
			AND (([Type] IS NOT NULL) OR er.ParentType = 303)  
			
		IF (@ShowEmptyBalances = 0)  
			 DELETE a FROM [#Prev_B_Res] a LEFT JOIN (SELECT [AccGUID] FROM  [#result] GROUP BY [AccGUID] ) r ON r.[AccGUID] = a.[AccGUID] WHERE r.[AccGUID] IS NULL  
		IF (@SelectedUserGUID <> 0X00)  
		BEGIN  
			DELETE r FROM [#Prev_B_Res] r   
			LEFT JOIN er000 er on r.ceguid = er.entryguid LEFT JOIN    
				(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
					(  
					select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
					ON a.[RecGuid] = b.[RecGuid]   
					INNER JOIN us000 u ON [USerGuid] = u.Guid  
					WHERE a.logTime = b.logTime ) v ON v.[RecGuid] = ISNULL(er.ParentGuid,r.[CeGUID]) WHERE v.[RecGuid] IS NULL  
		END  
		--------------------------------------------------   
		EXEC [prcCheckSecurity] @UserGUID, DEFAULT, DEFAULT, '#Prev_B_Res', DEFAULT    
		
		----Filter Result by Branches And Security
		--DELETE [#Prev_B_Res] 
		--FROM [#Prev_B_Res] AS [r]
		--INNER JOIN [dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE] ON [CE].[ceGUID] = [r].[ceGuid]     
		--INNER JOIN #Account_Tbl AS [Acc] On [Acc].[Guid] = [CE].[enAccount]     
		--INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID] 
		--WHERE
		----Filter Accounts
		--[Acc].[Guid] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID))
		--OR
		----Filter Costs
		--[Cost].[GUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts](@UserGUID))
		--OR
		----Filter Ce
		--[r].[ceGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
		--------------------------------------------------   

		-- insert into result previous balance records  
		DECLARE @Prev_Balance TABLE ( [AccGUID] [UNIQUEIDENTIFIER],    
						[enDebit]	[FLOAT],   
						[enCredit]	[FLOAT])      
			    
			INSERT INTO @Prev_Balance    
			SELECT      
				[AccGUID] AS [Account],     
				SUM( [enDebit]) AS [Debit],      
				SUM( [enCredit]) AS [Credit]     
			FROM      
				[#Prev_B_Res]   
			GROUP BY       
				[AccGUID]    
					    
		-----------------------------------------------------------------      
		-- update the current balance by adding the previous balance  
		UPDATE [Balanc]     
			SET [PrevBalance] = ( [PrevBal].[enDebit] - [PrevBal].[enCredit])      
		FROM      
			@BalanceTbl AS [Balanc]   
			INNER JOIN @Prev_Balance AS [PrevBal]       
			ON [Balanc].[AccGUID] = [PrevBal].[AccGUID]     
	END  
---------------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------------- 
     
	-------------------------------------------------------------------------------------------      
	-- C O L L E C T  B A L A N C E   O F  A C C O U N T S     
	-------------------------------------------------------------------------     
	IF( @IsSingl <> 1) -- is this a general account (has sons)  
	BEGIN  
		-- calc balance by adding balances of sons (and previous balance)  
		DECLARE @Continue [INT], @Lv [INT]     
		SET @Continue = 1     
		SET @Lv = 0     
		WHILE @Continue <> 0   
		BEGIN     
			SET @Lv = @Lv + 1     
			INSERT INTO @BalanceTbl  
				SELECT     
					[Bal].[AccParent],      
					[acParent],     
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),     
					@Lv     
				FROM     
					@BalanceTbl AS [Bal]     
					INNER JOIN #Account_Tbl AS [AC]      
					ON [AC].[GUID] = [Bal].[AccParent]     
					INNER JOIN [vwAc]     
					ON [vwAc].[acGUID] = [AC].[GUID]     
				WHERE     
					[Lv] = @Lv - 1     
				GROUP BY     
					[Bal].[AccParent],     
					[acParent]     
			SET @Continue = @@ROWCOUNT      
		END	   
		IF EXISTS(SELECT * from ac000 WHERE GUID = @AccountGUID AND Type = 4)  
		BEGIN  
			INSERT INTO @BalanceTbl  
				SELECT @AccountGUID,0X00,  
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),  
					-1  
					FROM     
					@BalanceTbl AS [Bal]    INNER JOIN ci000 CI ON ci.SonGUID = [Bal].[AccGUID]  
							WHERE ci.ParentGUID =   @AccountGUID   
					  
					  
		END    
	END  
	-------------------------------------------------------------------------     
	-- now the final result  
	INSERT INTO [#Result] (      
					[AccGUID],      
					[acCode],  
					[acName],  
					[acLatinName],  
					[Path],      
					[enDebit],     
					[enCredit],     
					[enFixDebit],     
					[enFixCredit],     
					[PrevBalance],     
					[Type],
					[coSecurity],            
					[ceSecurity],      
					[accSecurity])     
				SELECT     
					[AC].[GUID],      
					[AC].[acCode],  
					[AC].[acName],  
					[AC].[acLatinName],  
					[AC].[Path],      
					0,     
					0,     
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),     
					0,
					0, -- 23-3-2010     
					0, -- 0 it suggest hi security for entry       
					[acSecurity]     
				FROM     
					#Account_Tbl AS [AC]     
					INNER JOIN @BalanceTbl AS [Bal]     
					ON [AC].[GUID] = [Bal].[AccGUID]  
				GROUP BY     
					[AC].[GUID],      
					[acCode],  
					[acName],  
					[acLatinName],  
					[AC].[Path],      
					[acSecurity]     
				HAVING   
				(  
					 (@ShowEmptyBalances = 1) OR  
					 ( (@ShowEmptyBalances = 0) AND   
					   ( (SUM( [Bal].[FixDebit])>0 OR SUM( [Bal].[FixCredit])>0) OR ( @PrevBalance = 1 AND SUM( [Bal].[PrevBalance]) > 0)  
					    )  
					  )  
				)  
	--------------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserGUID    
	
	----Filter Result by Security
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 )
	
	--SET @NumOfSecViolated = @NumOfSecViolated + @@ROWCOUNT
	
	----Filter Result by Branches
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID))
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts](@UserGUID))
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
	-------------------------------------------------------------------------------------------  
	IF @ShowUser > 0  
	BEGIN  
		UPDATE r SET UserName = ISNULL([LoginName],'') FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid  
		LEFT JOIN    
			(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime ) v ON v.[RecGuid] =isnull( er.parentguid,r.[CeGUID] )  
	END  
	--------------------------------------------------------------------------------------------      
	CREATE TABLE #Res (     
		[Number] [INT] IDENTITY,
		[AccGuid] [UNIQUEIDENTIFIER],      
		[AccCode] [VARCHAR](200) COLLATE ARABIC_CI_AI,    
		[AccName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[AccLName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceGuid] [UNIQUEIDENTIFIER],      
		[enGuid] [UNIQUEIDENTIFIER] DEFAULT 0x0,      
		[ceNumber] [INT],      
		[ceDate] [DATETIME],   
		[enNumber] [INT],   
		[Debit] [FLOAT],      
		[Credit] [FLOAT], 
		[SubBalance] [FLOAT],     
		[curDebit] [FLOAT],      
		[curCredit] [FLOAT],      
		[CurGuid] [UNIQUEIDENTIFIER],      
		[CurVal] [FLOAT],      
		--ObverseGUID [UNIQUEIDENTIFIER],      
		[CostGUID] [UNIQUEIDENTIFIER],   
		[enNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseLName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceParentGUID] [UNIQUEIDENTIFIER],      
		[RepType] [INT],      
		[AccType] [INT],	-- 0 Main Account 1 Sub Account      
		[PrevBalance] [FLOAT],     
		[PATH] [VARCHAR](4000),    
		[ParentNumber] [INT],   
		[ParentName] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
		[Level] [INT],   
		[IsCheck] [INT],  
		[Class] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[BranchGuid] [UNIQUEIDENTIFIER],  
		[Branch] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[LatinBranch] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[UserName] [VARCHAR](100) COLLATE ARABIC_CI_AI	,[Posted] BIT)   
		--UserCheckGuid [UNIQUEIDENTIFIER] DEFAULT 0x0)   
		  
	-- delete any account not to be displayed  
	INSERT INTO #Res  
	(
		[AccGuid] ,      
		[AccCode] ,    
		[AccName] ,    
		[AccLName] ,    
		[ceGuid] ,      
		[enGuid] ,      
		[ceNumber] ,      
		[ceDate] ,   
		[enNumber] ,   
		[Debit] ,      
		[Credit] ,   
		[SubBalance],   
		[curDebit] ,      
		[curCredit] ,      
		[CurGuid] ,      
		[CurVal] ,      
		      
		[CostGUID] ,   
		[enNotes] ,    
		[ceNotes] ,    
		[ObverseCode] ,    
		[ObverseName] ,    
		[ObverseLName] ,    
		[ceParentGUID] ,      
		[RepType] ,      
		[AccType] ,	-- 0 Main Account 1 Sub Account      
		[PrevBalance] ,     
		[PATH] ,    
		[ParentNumber] ,   
		[ParentName],   
		[Level] ,   
		[IsCheck],  
		[Class],  
		[BranchGuid],  
		[Branch],  
		[LatinBranch] ,  
		[UserName] ,[Posted]
	)    
	SELECT       
		[RES].[AccGuid] AS [AccGuid],      
		[RES].[acCode] AS [AccCode],      
		[RES].[acName] AS [AccName],      
		[RES].[acLatinName] AS [AccLName],      
		[RES].[ceGuid] AS [ceGuid],      
		[RES].[enGuid] AS [enGuid],   
		[RES].[ceNumber] AS [ceNumber],      
		[RES].[ceDate] AS [ceDate],      
		[RES].[enNumber] AS [enNumber],   
		[RES].[enFixDebit]  AS [Debit],      
		[RES].[enFixCredit] AS [Credit], 
		[RES].[enFixDebit] - [RES].[enFixCredit] AS [SubBalance],     
		[RES].[enDebit] AS [curDebit],      
		[RES].[enCredit] AS [curCredit],      
		[RES].[enCurPtr] AS [CurGuid],      
		[RES].[enCurVal] AS [CurVal],      
		ISNULL( [RES].[CostGUID], 0x0) AS [CostGUID],   
		[RES].[enNotes] AS [enNotes],  
		[RES].[ceNotes],      
		ISNULL( [ObvacCode], '') AS [ObverseCode],   
		ISNULL( [ObvacName], '') AS [ObverseName],   
		ISNULL( [ObvacLatinName], '') AS [ObverseLName],       
		[RES].[ceParentGUID] AS [ceParentGUID],      
		[RES].[ceRecType] AS [RepType],      
		[RES].[Type] AS [AccType],	-- 0 Main Account 1 Sub Account      
		ISNULL( [RES].[PrevBalance], 0) AS [PrevBalance],     
		[RES].[Path],    
		[RES].[ParentNumber],   
		[RES].[ParentName],   
		CASE WHEN [RES].[ceGuid] IS NULL THEN [Level] ELSE [Level] + 1 END,   
		[IsCheck] ,  
		[Class],[Branch],'','',[UserName],[Posted]  
		--UserCheckGuid   
	FROM      
		[#Result] AS [RES] INNER JOIN #Account_Tbl AS [AC] ON [RES].[AccGUID] = [AC].[GUID]      
	WHERE    
		[RES].[Type] = 0 OR [RES].[enDebit] <> 0 OR [RES].[enCredit] <> 0 OR [RES].[PrevBalance] <> 0   
		ORDER BY [RES].[Path], [RES].[Type], dbo.fnGetDateFromTime([RES].[ceDate]) , [RES].[ceNumber], [RES].[enNumber]  
	-- End Result   
	-- return the final result  
	IF (@ShowBranch > 0)  
		UPDATE	[r] SET	[Branch] = br.[Name],[LatinBranch] = br.[LatinName]  
		FROM #Res [r] INNER JOIN [br000] br ON 	br.Guid = [BranchGuid]  
		
----------------------------------Prepare Subbalance-----------------------------
UPDATE MainRes SET MainRes.[SubBalance] = MainRes.[SubBalance] + (SELECT ISNULL(SUM(PartRes.[SubBalance]), 0) FROM #RES PartRes WHERE PartRes.Number<MainRes.Number AND PartRes.AccGUID = MainRes.AccGUID AND PartRes.AccType <> 0) + (SELECT [PrevBalance] FROM #RES ParentPrevBal WHERE ParentPrevBal.AccGUID = MainRes.AccGUID AND ParentPrevBal.AccType = 0)
FROM #RES MainRes WHERE MainRes.AccType <>0
---------------------------------------------------------------------------------
	IF Exists(Select * From #SecViol)
		SET @IsFullResult = 0
	ELSE
		SET @IsFullResult = 1
	
	DECLARE @SQL NVARCHAR (4000) 
	SET @SQL = 'SELECT #Res.[Number],  
		[AccGuid],  
		[AccCode],  
		[AccName],  
		[AccLName],  
		ISNULL( [ceGuid], 0x0) AS [ceGuid],  
		ISNULL( [enGuid], 0x0) AS [enGuid],  
		ISNULL( [ceNumber], 0) AS [ceNumber],  
		ISNULL( [ceDate],'''+ CAST (GetDate() AS VARCHAR(50))+''') AS [ceDate],  
		--ISNULL( enNumber,0) AS enNumber,  
		ISNULL( #Res.[Debit], 0) AS [Debit],  
		ISNULL( #Res.[Credit], 0) AS [Credit],
		ISNULL( #Res.[SubBalance], 0) AS [SubBalance],
		ISNULL( [curDebit], 0) AS [curDebit],  
		ISNULL( [curCredit], 0) AS [curCredit],  
		ISNULL( [CurGuid], 0x0) AS [CurGuid],  
		ISNULL( [CurVal], 0) AS [CurVal],
		ISNULL( [EvlCur].[Code], '''')			AS [EvlCurCode],
		ISNULL( [EvlCur].[Name], '''')			AS [EvlCurName],    
		ISNULL( [EvlCur].[LatinName], '''')		AS [EvlCurLatinName],
		ISNULL( [EvlCur].[PartName], '''')		AS [EvlCurPartName], 
		ISNULL( [EvlCur].[LatinPartName], '''') AS [EvlCurLatinPartName],        
		--@AccountGUID AS ObverseGUID,  
		ISNULL( [CostGUID], 0x0) AS [CostGUID],  
		ISNULL( [enNotes], '''') AS [enNotes],  
		--ISNULL( [ceNotes], '''') AS [ceNotes],  
		ISNULL( [ObverseCode], '''') AS [ObverseCode],  
		ISNULL( [ObverseName], '''') AS [ObverseName],  
		ISNULL( [ObverseLName], '''') AS [ObverseLName],  
		ISNULL( [ceParentGUID], 0x0) AS [ceParentGUID],  
		ISNULL( [RepType], 0) AS [RepType],  
		ISNULL( [AccType], 0) AS [AccType],  
		ISNULL( [PrevBalance], 0) AS [PrevBalance],  
		ISNULL( [ParentNumber], 0) AS [ParentNumber],  
		ISNULL( [ParentName], '''') AS [ParentName],  
		ISNULL( [IsCheck], 0) AS [IsCheck], ' 
	
	SET @SQL = @SQL + ' ISNULL( enNumber,0) AS enNumber, ' 
	SET @SQL = @SQL + '(CASE WHEN curDebit>0 THEN ' + '''[ ''' + ' + enCurr.CODE + ' + ''' ''' + ' + CAST(CurVal AS VARCHAR(100)) + ' + ''']''' + '+ CAST(curDebit/ISNULL(CurVal,1) AS VARCHAR(100)) ' + ' ELSE (CASE WHEN curCredit>0 THEN ' + '''[ ''' + ' + enCurr.CODE + ' + ''' ''' + ' + CAST(CurVal AS VARCHAR(100)) + ' + ''']''' + '+ CAST(curCredit/ISNULL(CurVal,1) AS VARCHAR(100)) ' +' ELSE ' +''' '''+ ' END) END) As OriginalCurrency, ' 	
	SET @SQL = @SQL + ' ISNULL(Cost.Name, '''') As CostName, ' 
	SET @SQL = @SQL + ' ISNULL( [ceNotes], '''') AS [ceNotes], '
				   

	--DebitExchangeVariations
	SET @SQL = @SQL + '(CASE WHEN #Res.CurGUID = ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' 
	SET @SQL = @SQL +      ' THEN #Res.Debit * (#Res.CurVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      ' ELSE ' 
	SET @SQL = @SQL + 		'(CASE WHEN #Res.CurGUID <> ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' + ' AND #Res.CurGUID <> 0x0'
	SET @SQL = @SQL +      		' THEN #Res.Debit * (EvlCur.CurrencyVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      		' ELSE 0.0 END) END) AS DebitExchangeVariations, ' 
	
	--CreditExchangeVariations
	SET @SQL = @SQL + '(CASE WHEN #Res.CurGUID = ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' 
	SET @SQL = @SQL +      ' THEN #Res.Credit * (#Res.CurVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      ' ELSE '
	SET @SQL = @SQL + 		'(CASE WHEN #Res.CurGUID <> ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' + ' AND #Res.CurGUID <> 0x0'
	SET @SQL = @SQL +      		' THEN #Res.Credit * (EvlCur.CurrencyVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      		' ELSE 0.0 END) END) AS CreditExchangeVariations, ' 
	SET @SQL = @SQL + '(CASE WHEN #Res.[RepType] > 1 THEN ' 
	SET @SQL = @SQL + '#Res.[ParentName] + ' + ''': ''' + ' + CAST(#Res.[ParentNumber] AS VARCHAR(100))' + 'ELSE ' + '''''' +'END)AS OriginalCe,' 	 	
	SET @SQL = @SQL + 'ISNULL([Branch],'''') AS [BrName], '
	SET @SQL = @SQL + 'ISNULL([LatinBranch],'''') AS [BrLatinName], '
	
	SET @SQL = @SQL + '(CASE WHEN (#Res.[ObverseName]  <> '''' AND UPPER(SUBSTRING( ''' + @Lang + '''' + ', 1, 2))  = ''AR'') THEN #Res.[ObverseName] +' + '''-''' + ' + #Res.[ObverseCode] ELSE ' 
	SET @SQL = @SQL + '(CASE WHEN (#Res.[ObverseLName] <> '''' AND UPPER(SUBSTRING( ''' + @Lang + '''' + ', 1, 2))  = ''EN'') THEN #Res.[ObverseCode] +' + '''-''' + ' + #Res.[ObverseLName] ELSE '''' END) END) AS ContraAcc, '
	SET @SQL = @SQL + '[UserName], '
		
	SET @SQL = @SQL + 'ISNULL([Class],'''') AS [Class], ' 
		
	SET @SQL = @SQL + ' [Posted], ''' + CAST(@IsFullResult AS VARCHAR(100)) + '''' + ' AS NumOfSecViolated'
		  
	SET @SQL = @SQL + ' FROM  #Res LEFT JOIN MY000 enCurr ON #Res.CurGuid = enCurr.GUID '
	SET @SQL = @SQL + 	     ' LEFT JOIN MY000 EvlCur ON EvlCur.GUID = ' + '''' + CAST(@CurrencyGUID AS Varchar(1000)) + ''''
	SET @SQL = @SQL + 	     ' LEFT JOIN co000 Cost ON #Res.CostGUID = Cost.GUID ' 
	SET @SQL = @SQL + ' WHERE ( ' 
	SET @SQL = @SQL + CAST (@Level AS VARCHAR(4)) 
	SET @SQL = @SQL + ' = 0 OR [Level] < ' 
	SET @SQL = @SQL + CAST( @Level AS VARCHAR (4)) 
	SET @SQL = @SQL +' ) ORDER BY [Path], [AccType], dbo.fnGetDateFromTime([ceDate]) , [ceNumber], [enNumber] ' 
	EXEC (@SQL) 

	--prcFinalize_Environment 
	EXEC [prcFinilize_Environment] '[prcGeneralLedger]'
#########################################################
CREATE PROCEDURE ARWA.prcGetUserReportsPermissions
	@UserGuid	[UNIQUEIDENTIFIER]
AS
	select [r1].[ReportID]
	from [uix] AS [r1]
	INNER JOIN [ARWAReports] AS [r2] ON [r1].[ReportId] = [r2].[ReportId]
	where [r1].[UserGUID] = @UserGuid AND [r1].[PermType] = 0 AND [r1].[Permission] = 1
#########################################################
CREATE PROCEDURE ARWA.repYearlyTrialBalance
	@AccountGUID 			UNIQUEIDENTIFIER,
	@AccountDescription		VARCHAR(250),
	@StartDate 				DATETIME,
	@EndDate 				DATETIME,
	@CurrencyGUID 			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@CumulativeBalance		BIT,
	@ShowDebit				BIT,
	@ShowCredit				BIT,
	@ShowBalance			BIT,
	@ShowEmptyPeriods		BIT,
	@Lang					VARCHAR(100) = 'ar',
	@UserGUID				UNIQUEIDENTIFIER = 0x0,
	@BranchMask				BIGINT = -1
AS
	--  ﬁ—Ì— „Ì“«‰ «·„—«Ã⁄… «·”‰ÊÌ
	SET NOCOUNT ON

	EXEC [prcInitialize_Environment] @UserGUID, 'repYearlyTrialBalance', @BranchMask
	
	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT)
	
	CREATE TABLE [#Result](  
		[ceGUID]		UNIQUEIDENTIFIER,
		[ceSecurity]	INT,
		[acGUID]		UNIQUEIDENTIFIER,
		[enDate]		DATETIME,
		[FixedEnDebit]	FLOAT,
		[FixedEnCredit]	FLOAT,
		[acSecurity]	INT,
		[PrevDebit]		FLOAT,
		[PrevCredit]	FLOAT,
		[FromDate]		DATETIME,
		[ToDate]		DATETIME)
	
	INSERT INTO [#Result]
	SELECT  
		[ceGUID], 
		[ceSecurity],
		[acGUID],  
		[enDate],  
		CASE 
			WHEN [enDate] < @StartDate THEN 0
			ELSE  [dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGUID, [enDate]) 
		END,
		CASE 
			WHEN [enDate] < @StartDate THEN 0
			ELSE  [dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal],  @CurrencyGUID, [enDate])
		END,
		[acSecurity], 
		CASE 
			WHEN [enDate] < @StartDate THEN [dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @CurrencyGUID, [enDate]) 
			ELSE 0
		END,
		CASE 
			WHEN [enDate] < @StartDate THEN [dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal],  @CurrencyGUID, [enDate])
			ELSE 0
		END,
		[enDate],
		[enDate]
	FROM 
		[vwExtended_en] AS [en]
		INNER JOIN [dbo].[fnGetAccountsList](@AccountGUID, DEFAULT) AS [ac] ON [ac].[GUID] = en.[AcGUID]
	WHERE
		([ACNSons] = 0) AND ([AcType] = 1) AND ([ceIsPosted] = 1) AND ([enDate] <= @EndDate)

	DECLARE @SecBalPrice [INT]  
	SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGuid]()) 
	IF @SecBalPrice > 0 
		UPDATE [#Result] SET [ceSecurity] = 0 WHERE [AcSecurity] <= @SecBalPrice 
	DECLARE @NumOfSecViolated BIT = 0
	
	EXEC [prcCheckSecurity] 
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
	
	SELECT 
		[acGUID] AS [AccountGUID],
		SUM([PrevDebit]) AS [SumPrevDebit], 
		SUM([PrevCredit]) AS [SumPrevCredit]
	INTO 
		[#PrevBalances]
	FROM 
		[#Result]
	WHERE
		[enDate] < @StartDate
	GROUP BY
		[acGUID]
	IF @ShowEmptyPeriods = 1
	BEGIN 
		Create TABLE [#Periods](
			[fromDate]		DATETIME,
			[ToDate]		DATETIME,
			[AccGuid]		UNIQUEIDENTIFIER)
			
		DECLARE @LoopCondition BIT = 0
		DECLARE @Date1 DATETIME
		DECLARE @Date2 DATETIME
		
		SET @Date1 = @StartDate

		WHILE (@LoopCondition <> 1) AND (@EndDate > @StartDate)
		BEGIN
			IF @Date1 > @StartDate 
			BEGIN
				IF DAY(@Date1) > 1
					SET @Date1 = DATEADD(DAY, (-1 * DAY(@Date1)) + 1, @Date1)
				SET @Date2 = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @Date1))
			END
			ELSE
				SET @Date2 = DATEADD(DAY, (-1 * DAY(@Date1)) + 1, DATEADD(SECOND, -1, DATEADD(MONTH, 1, @Date1)))

			IF @Date2 > @EndDate
				SET @Date2 = DATEADD(SECOND, -1, DATEADD(DAY, 1, @EndDate))
			
			INSERT INTO [#Periods] VALUES (@Date1, @Date2, 0x0)
			SET @Date1 = DATEADD(MONTH, 1, @Date1)

			--set breaking rules
			IF (YEAR(@Date1) > YEAR(@EndDate)) OR (YEAR(@Date1) = YEAR(@EndDate) AND MONTH(@Date1) > MONTH(@EndDate))
				SET @LoopCondition = 1
		END
		
		INSERT INTO [#Result]
		SELECT
			0x0,
			0,
			[Rslt].[acGUID],  
			[Du].[fromDate],
			0,
			0,
			0,
			0,
			0,
			[Du].[fromDate],
			[Du].[toDate]
		FROM
			[#Periods] AS Du
			LEFT OUTER JOIN (SELECT DISTINCT [acGUID] FROM #Result) AS Rslt 
			ON Du.AccGuid <> Rslt.acGUID
	END	

	SELECT
		[res].[acGUID] AS [AccountGUID],
		[ac].[acCode] AS [AccountCode],
		CASE @Lang
			WHEN 'ar' THEN [ac].[acName]
			ELSE [ac].[acLatinName]
		END AS [AccountName],
		[res].[enDate] AS [Date],
		[res].[FixedEnDebit] AS [Debit],
		[res].[FixedEnCredit] AS [Credit],
		MONTH([res].[FromDate]) AS [MONTH],
		YEAR([res].[FromDate]) AS [YEAR],
		ISNULL([pb].[SumPrevDebit], 0) AS [PreviousSumDebit],
		ISNULL([pb].[SumPrevCredit], 0) AS [PreviousSumCredit],
		[res].[FromDate] AS [FromDate],
		[res].[ToDate] AS [ToDate],
		@NumOfSecViolated AS [NumOfSecViolated]
	FROM 
		[#Result] [res]
		INNER JOIN [vwAc] [ac] ON [ac].[acGUID] = [res].[acGUID] 
		LEFT JOIN [#PrevBalances] [pb] ON [pb].[AccountGUID] = [res].[acGUID]
	WHERE 
		[res].[enDate] >= @StartDate
	ORDER BY 
		[YEAR], 
		[MONTH]
		
	EXEC [prcFinilize_Environment] 'repYearlyTrialBalance'
#########################################################
CREATE PROCEDURE ARWA.repYearlyMaterialsTrialBalance
	@StartDate 				DATETIME,
	@EndDate				DATETIME,
	@ProductGUID			UNIQUEIDENTIFIER,
	@ProductDescription		VARCHAR(250),
	@GroupGUID 				UNIQUEIDENTIFIER,
	@GroupDescription		VARCHAR(250),
	@StoreGUID				UNIQUEIDENTIFIER,
	@StoreDescription		VARCHAR(250),
	@JobCostGUID 			UNIQUEIDENTIFIER,
	@JobCostDescription		VARCHAR(250),
	@SourcesTypes			VARCHAR(MAX),
	@CurrencyGUID 			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@PricePolicy 			INT,
	@ShowServiceProduct		BIT,
	@ShowStockProduct		BIT,
	@ShowAssetsProduct		BIT,
	@ShowQuantityNonUnit	BIT,
	@ShowProductCode		BIT,
	@ShowProductName		BIT,
	@ShowQuantity			BIT,
	@ShowValue				BIT,
	@ShowEmptyPeriods		BIT,
	@UseUnit 				INT,
	@WithDetails			BIT = 1,
	@ShowGroups				BIT = 0,
	@CumulativeBalance		BIT = 0,
	@ProductsConditions		VARCHAR(MAX) = '',
	@Lang					VARCHAR(100) = 'ar', 
	@UserGUID				UNIQUEIDENTIFIER = 0X0,
	@BranchMask				BIGINT = -1
AS 
	SET NOCOUNT ON
	
	IF [dbo].[fnGetUserMaterialSec_Balance](@UserGUID) <= 0 
		RETURN
	
	EXEC [prcInitialize_Environment] @UserGUID, 'repYearlyMaterialsTrialBalance', @BranchMask
	
	DECLARE @Types TABLE(
		[GUID]	VARCHAR(100), 
		[Type]	VARCHAR(100))
		
	CREATE TABLE [#SecViol](
		[Type]	INT,
		[Cnt]	INT) 
		
	CREATE TABLE [#MatTbl](
		[MatGUID]	UNIQUEIDENTIFIER,
		[mtSecurity]	INT,
		[GroupGUID]		UNIQUEIDENTIFIER) 
		
	CREATE TABLE [#BillsTypesTbl](
		[TypeGuid]				UNIQUEIDENTIFIER,
		[UserSecurity]			INT,
		[UserReadPriceSecurity] INT)
		 
	CREATE TABLE [#StoreTbl](
		[StoreGUID]		UNIQUEIDENTIFIER,
		[Security]		INT)
		
	CREATE TABLE [#CostTbl](
		[CostGUID]		UNIQUEIDENTIFIER,
		[Security]		INT)
	
	INSERT INTO @Types SELECT * FROM [fnParseRepSources](@SourcesTypes)
	
	DECLARE @MaterialType INT = -1
	
	IF @ShowStockProduct = 1 AND @ShowServiceProduct = 0 AND @ShowAssetsProduct = 0
		SET @MaterialType = 0
	ELSE
		IF @ShowStockProduct = 0 AND @ShowServiceProduct = 1 AND @ShowAssetsProduct = 0
			SET @MaterialType = 1
		ELSE
		IF @ShowStockProduct = 0 AND @ShowServiceProduct = 0 AND @ShowAssetsProduct = 1
			SET @MaterialType = 2
		ELSE
			IF @ShowStockProduct = 1 AND @ShowServiceProduct = 1 AND @ShowAssetsProduct = 0
				SET @MaterialType = 256
			ELSE
				IF @ShowStockProduct = 1 AND @ShowServiceProduct = 0 AND @ShowAssetsProduct = 1
					SET @MaterialType = 257
				ELSE
					IF @ShowStockProduct = 0 AND @ShowServiceProduct = 1 AND @ShowAssetsProduct = 1
						SET @MaterialType = 258
		
	INSERT INTO [#MatTbl]([MatGUID], [mtSecurity]) EXEC [prcGetMatsList] @ProductGUID, @GroupGUID, @MaterialType, 0x0, @ProductsConditions
	
	INSERT INTO [#BillsTypesTbl]
	SELECT
		[bt].btGUID, 
		[dbo].[fnGetUserBillSec_Browse](@UserGUID, [bt].btGUID), 
		[dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [bt].btGUID) 
	FROM 
		[vwBt] [bt]
		INNER JOIN @Types t ON t.[GUID] = CAST([bt].btGUID AS VARCHAR(100))
	
	INSERT INTO [#StoreTbl] EXEC [prcGetStoresList] @StoreGUID
	
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	
	UPDATE mt 
	SET GroupGUID = (SELECT [mtGroup] FROM vwMt WHERE vwMt.mtGUID = mt.MatGUID)
	FROM #MatTbl mt
			
	IF [dbo].[fnIsAdmin](ISNULL(@UserGUID, 0x0)) = 0
	BEGIN
		DELETE [mt]
		FROM 
			[#MatTbl] [mt]
			INNER JOIN fnGroup_HSecList() AS [f] ON [mt].GroupGUID = [f].[GUID]
		WHERE 
			[f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
			OR [mt].[mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid)
		
		IF @@ROWCOUNT > 0
			INSERT INTO [#SecViol] VALUES(7, 0)
	END
	
	DECLARE @mtCnt INT

	SELECT @mtCnt = COUNT(*) FROM [#MatTbl]
	DECLARE @T_Result TABLE(
		[btType]		INT DEFAULT 11,		
		[btTypeGUID]	UNIQUEIDENTIFIER,
		[MaterialGUID]	UNIQUEIDENTIFIER,
		[GroupGUID]		UNIQUEIDENTIFIER,
		[biStoreGUID]	UNIQUEIDENTIFIER,
		[buDirection]	INT, 
		[biQty]			FLOAT,
		[biQty2]		FLOAT,
		[biQty3]		FLOAT,
		[FixedBiPrice]	FLOAT DEFAULT 0,
		[TotalPrice]	FLOAT,
		[MatSecurity]	INT,
		[Security]		INT, 
		[UserSecurity]	INT,
		[mtUnitFact]	FLOAT DEFAULT 0,
		[GrpPtr]		UNIQUEIDENTIFIER,
		[Flag]			INT,
		[UnitName]		VARCHAR(256) COLLATE ARABIC_CI_AI,
		[Unit2Name]		VARCHAR(256) COLLATE ARABIC_CI_AI,
		[Unit3Name]		VARCHAR(256) COLLATE ARABIC_CI_AI,
		[Date]			DATETIME,
		[Path]			VARCHAR(1000),
		[Root]			INT DEFAULT 0,
		[Level]			INT DEFAULT 0)

	IF (ISNULL(@JobCostGUID, 0x0) = 0x0) 
		INSERT INTO [#CostTbl] VALUES (0x0, 0)
	
	INSERT INTO @T_Result
	SELECT 
		[bu].[btBillType],
		[bu].[buType],
		[bu].[biMaterialGUID],
		[bu].[biGroupGUID],
		[bu].[biStorePtr],
		[bu].[buDirection],
		[Qty],
		[bu].[biCalculatedQty2],
		[bu].[biCalculatedQty3],
		[bu].[FixedbiTotal],
		0,
		[bu].[mtSecurity],
		[bu].[buSecurity],
		[bu].[UserSecurity],
		[mtUnitFact],
		[bu].[mtGroup],
		0,
		[mtUint],
		[bu].[mtUnit2],
		[bu].[mtUnit3],
		[bu].[buDate],
		'',
		0,
		0	
	FROM 
		(SELECT 
			[bi].[btBillType],
			[bi].[buType],
			[mt].[MatGUID] AS [biMaterialGUID],
			[mt].[GroupGUID] AS [biGroupGUID],
			[bi].[biStorePtr],
			[buDirection],
			SUM(CASE @UseUnit 
				WHEN 0 THEN ([bi].[biQty] + [bi].[biBonusQnt])
				WHEN 1 THEN ([bi].[biQty] + [bi].[biBonusQnt]) / CASE [bi].[mtunit2Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit2Fact] END 
				WHEN 2 THEN ([bi].[biQty] + [bi].[biBonusQnt]) / CASE [bi].[mtunit3Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit3Fact] END  
				ELSE ([bi].[biQty] + [bi].[biBonusQnt]) / [bi].[mtDefUnitFact]
			END) AS [Qty],
			SUM([bi].[biCalculatedQty2]) AS [biCalculatedQty2],
			SUM([bi].[biCalculatedQty3]) AS [biCalculatedQty3] ,
			
			SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN  [bi].[FixedbiTotal] ELSE 0 END) AS [FixedbiTotal],
			[mt].[mtSecurity] AS [mtSecurity],
			[bi].[buSecurity],
			[bt].[UserSecurity],
			[bi].[mtGroup],
			CASE @UseUnit
				WHEN 0 THEN [bi].[mtUnity]
				WHEN 1 THEN [bi].[mtUnit2]
				WHEN 2 THEN [bi].[mtUnit3]
				ELSE 
					CASE [bi].[mtDefUnit]
						WHEN 1 THEN [bi].[mtUnity]
						WHEN 2 THEN [bi].[mtUnit2]
						ELSE [bi].[mtUnit3]
					END
			END AS [mtUint],
			[bi].[mtUnit2],
			[bi].[mtUnit3],
			[buDate],
			[bi].[biCostPtr],
			SUM(CASE @UseUnit 
				WHEN 0 THEN 1
				WHEN 1 THEN  CASE [bi].[mtunit2Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit2Fact] END 
				WHEN 2 THEN CASE [bi].[mtunit3Fact] WHEN 0 THEN 1 ELSE [bi].[mtunit3Fact] END  
				ELSE [bi].[mtDefUnitFact]
			END)
			 AS [mtUnitFact]
		FROM 
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
			INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
		WHERE 
			([buDate] BETWEEN @StartDate AND @EndDate )
				AND [buIsPosted] = 1 
		GROUP BY
			[bi].[btBillType],
			[bi].[buType],
			[mt].[MatGUID],
			[mt].[GroupGUID],
			[bi].[biStorePtr],
			[mt].[mtSecurity],
			[bi].[buSecurity],
			[bt].[UserSecurity],
			[bi].[mtGroup],
			[bi].[mtUnity],
			[bi].[mtUnit2],
			[bi].[mtUnit3],
			[bi].[buDate],
			[bi].[biCostPtr],
			[buDirection],
			[bi].[mtunit2Fact],
			[bi].[mtunit3Fact],
			[bi].[mtDefUnitFact],
			[bi].[mtDefUnit]) AS [bu]
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bu].[biStorePtr]
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bu].[biCostPtr]
		
	EXEC [prcCheckSecurity] @result = '#T_Result', @UserGUID = @UserGUID
	
	DECLARE @NumOfSecViolated BIT
	SET @NumOfSecViolated = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
	
	CREATE TABLE [#t_Prices](
		[mtNumber] 	UNIQUEIDENTIFIER,
		[APrice] 	FLOAT)

	IF @MaterialType > 100
		SET @MaterialType = -1

	DECLARE 
		@mtGuid UNIQUEIDENTIFIER,
		@SourceGuid UNIQUEIDENTIFIER,
		@CurrencyVal FLOAT,
		@c CURSOR
		
	DECLARE @Periods TABLE (
			[fromDate]		DATETIME,
			[ToDate]		DATETIME,
			[MaterialGUID]	UNIQUEIDENTIFIER)
			
		DECLARE @LoopCondition BIT = 0,
		@Date1 DATETIME,
		@Date2 DATETIME,
		@PStartDate DATETIME,
		@PEndDate DATETIME
		
		SET @Date1 = @StartDate

		WHILE (@LoopCondition <> 1) AND (@EndDate > @StartDate)
		BEGIN
			IF @Date1 > @StartDate 
			BEGIN
				IF DAY(@Date1) > 1
					SET @Date1 = DATEADD(DAY, (-1 * DAY(@Date1)) + 1, @Date1)
				SET @Date2 = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @Date1))
			END
			ELSE
				SET @Date2 = DATEADD(DAY, (-1 * DAY(@Date1)) + 1, DATEADD(SECOND, -1, DATEADD(MONTH, 1, @Date1)))

			IF @Date2 > @EndDate
				SET @Date2 = DATEADD(SECOND, -1, DATEADD(DAY, 1, @EndDate))
			
			INSERT INTO @Periods VALUES (@Date1, @Date2, 0x0)
			SET @Date1 = DATEADD(MONTH, 1, @Date1)

			--set breaking rules
			IF (YEAR(@Date1) > YEAR(@EndDate)) OR (YEAR(@Date1) = YEAR(@EndDate) AND MONTH(@Date1) > MONTH(@EndDate))
				SET @LoopCondition = 1
		END
	
	SELECT @CurrencyVal = [dbo].[fnGetCurVal](@CurrencyGUID, GETDATE())
		
	SET @SourceGuid = NEWID()
	
	SET @c = CURSOR FAST_FORWARD FOR  
			SELECT DISTINCT fromDate ,toDate FROM @Periods
	OPEN @c
	FETCH FROM @c INTO @PStartDate,@PEndDate
	WHILE @@FETCH_STATUS = 0
	BEGIN
		TRUNCATE TABLE [#t_Prices]
		IF @PricePolicy = 121
			EXEC [prcGetAvgPrice]	'1/1/1980', @PEndDate, 0x0, @GroupGUID, @StoreGUID, @JobCostGUID, @MaterialType, @CurrencyGUID, 1, @SourceGuid, 0, 0
		ELSE IF @PricePolicy = 122 
			EXEC [prcGetLastPrice]	'1/1/1980', @PEndDate, 0x0, @GroupGUID, @StoreGUID, @JobCostGUID, @MaterialType, @CurrencyGUID,  @SourceGuid, 0, 0
		ELSE
			EXEC [prcGetMaxPrice]	'1/1/1980', @PEndDate, 0x0, @GroupGUID, @StoreGUID, @JobCostGUID, @MaterialType, @CurrencyGUID, @CurrencyVal, @SourceGuid, 0, 0
			
		INSERT INTO @T_Result(
			[MaterialGUID],
			[GroupGUID],
			[biQty],
			[biQty2],
			[biQty3] ,
			[TotalPrice],
			[Flag],
			[GrpPtr],
			[UnitName],
			[Unit2Name],
			[Unit3Name],
			[buDirection],
			[Date])
		SELECT 
			[MaterialGUID],
			[GroupGUID],
			SUM ([biQty] * [buDirection]),
			SUM([biQty2] * [buDirection]),	
			SUM([biQty3] * [buDirection]),
			SUM (ISNULL([APrice],0) * [biQty] *  [buDirection]),
			1,
			[r].[GrpPtr],
			[r].[UnitName],
			[r].[Unit2Name],
			[r].[Unit3Name],
			-3,
			[Date]
			FROM @T_Result AS [r] LEFT JOIN [#t_Prices] AS [t] ON  [mtNumber] = [r].[MaterialGUID]
				WHERE 
					((@CumulativeBalance = 0 AND [Date] BETWEEN @PStartDate AND @PEndDate) OR (@CumulativeBalance = 1 AND [Date] <= @PEndDate))
					AND [Flag] = 0
					AND [buDirection] != -3
			GROUP BY 
				[r].[MaterialGUID],
				[r].[GroupGUID],
				[r].[GrpPtr],
				[r].[UnitName],
				[r].[Unit2Name],
				[r].[Unit3Name],
				[r].[Date]
						
	FETCH NEXT FROM @c   INTO @PStartDate,@PEndDate 
	END 
	CLOSE @c 
	DEALLOCATE @c
	
	CREATE TABLE [#FinalResult](
		[BillType]				INT,
		[BillTypeGUID]			UNIQUEIDENTIFIER,
		[BillTypeName]			VARCHAR(250) COLLATE ARABIC_CI_AI,
		[BillTypeAbbrev]		VARCHAR(250) COLLATE ARABIC_CI_AI,
		[MaterialGUID]			UNIQUEIDENTIFIER,
		[MaterialName]			VARCHAR(250) COLLATE ARABIC_CI_AI,
		[MaterialCode]			VARCHAR(250) COLLATE ARABIC_CI_AI,
		[GroupGUID]				UNIQUEIDENTIFIER,
		[GroupName]				VARCHAR(250) COLLATE ARABIC_CI_AI,
		[GroupCode]				VARCHAR(250) COLLATE ARABIC_CI_AI,
		[GroupLevel]			INT,
		[GroupPath]				VARCHAR(8000),
		[buDirection]			VARCHAR(100),
		[Date]					DATETIME,
		[Month]					TINYINT,
		[Year]					INT,
		[QuantityInput]			FLOAT,
		[QuantityInput2]		FLOAT,
		[QuantityInput3]		FLOAT,
		[QuantityOutput]		FLOAT,
		[QuantityOutput2]		FLOAT,
		[QuantityOutput3]		FLOAT,
		[PriceInput]			FLOAT,
		[PriceOutput]			FLOAT,
		[TotalPrice]			FLOAT,
		[UnitName]				VARCHAR(250) COLLATE ARABIC_CI_AI,
		[Unit2Name]				VARCHAR(250) COLLATE ARABIC_CI_AI,
		[Unit3Name]				VARCHAR(250) COLLATE ARABIC_CI_AI)

	IF @ShowEmptyPeriods = 1
	BEGIN
		INSERT INTO @T_Result(
			[MaterialGUID],
			[GroupGUID],
			[Date])
			SELECT 
				Rslt.[MaterialGUID],
				Rslt.[GroupGUID],
				Pr.[FromDate]
			FROM
			@Periods AS Pr
			LEFT OUTER JOIN (SELECT DISTINCT [MaterialGUID], [GroupGUID] FROM @T_Result) AS Rslt 
			ON Pr.[MaterialGUID] <> Rslt.[MaterialGUID]
	END
				
	INSERT INTO #FinalResult
	SELECT
		ISNULL([bt].[btType], 0),
		ISNULL([res].[btTypeGUID], 0x0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [bt].btName
			ELSE CASE [bt].btLatinName
					WHEN '' THEN [bt].btName
					ELSE [bt].btLatinName
				END
		END, ''),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [bt].btAbbrev
			ELSE CASE [bt].btLatinAbbrev
					WHEN '' THEN [bt].btAbbrev
					ELSE [bt].btLatinAbbrev
				END
		END, ''),
		ISNULL([res].[MaterialGUID], 0x0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [mtGr].[MtName]
			ELSE CASE [mtGr].[MtLatinName]
					WHEN '' THEN [mtGr].[MtName]
					ELSE [mtGr].[MtLatinName]
				END
		END, ''),
		ISNULL([mtGr].[MtCode], ''),
		ISNULL([mtGr].grGUID, 0x0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [mtGr].grName
			ELSE CASE [mtGr].grLatinName
					WHEN '' THEN [mtGr].grName
					ELSE [mtGr].grLatinName
				END
		END, ''),
		ISNULL([mtGr].grCode, ''),
		ISNULL([fn].[Level], 0),
		ISNULL([fn].[Path], ''),
		ISNULL(CASE [res].[buDirection]
			WHEN 1 THEN 'input'
			WHEN -1 THEN 'output'
			WHEN -3 THEN 'result'
		END, ''),
		ISNULL([res].[Date], '1/1/1980'),
		ISNULL(MONTH([res].[Date]), 0),
		ISNULL(YEAR([res].[Date]), 0),
		ISNULL(CASE [res].[buDirection]
			WHEN 1 THEN [biQty]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN 1 THEN [biQty2]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN 1 THEN [biQty3]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN -1 THEN [biQty]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN -1 THEN [biQty2]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN -1 THEN [biQty3]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN 1 THEN [FixedBiPrice]
			ELSE 0
		END, 0),
		ISNULL(CASE [res].[buDirection]
			WHEN -1 THEN [FixedBiPrice]
			ELSE 0
		END, 0),
		ISNULL([res].TotalPrice, 0),
		ISNULL([res].[UnitName], ''),
		ISNULL([res].[Unit2Name], ''),
		ISNULL([res].[Unit3Name], '')
	FROM
		@T_Result [res]
		LEFT JOIN [vwMtGr] [mtGr] ON [mtGr].mtGUID = [res].[MaterialGUID]
		LEFT JOIN [fnGetGroupsOfGroupSorted](@GroupGUID, DEFAULT) [fn] ON [fn].[GUID] = [mtGr].[mtGroup]
		LEFt JOIN [vwBt] [bt] ON [bt].[btGUID] = [res].[btTypeGUID]
		
	SELECT 
		*,
		@NumOfSecViolated AS  NumOfSecViolated
	FROM 
		#FinalResult
				
	EXEC [prcFinilize_Environment] 'repYearlyMaterialsTrialBalance'

	/*

	ALTER PROCEDURE ARWA.repYearlyMaterialsTrialBalance
	@StartDate 				DATETIME,
	@EndDate				DATETIME,
	@ProductGUID			UNIQUEIDENTIFIER,
	@ProductDescription		VARCHAR(250),
	@GroupGUID 				UNIQUEIDENTIFIER,
	@GroupDescription		VARCHAR(250),
	@StoreGUID				UNIQUEIDENTIFIER,
	@StoreDescription		VARCHAR(250),
	@JobCostGUID 			UNIQUEIDENTIFIER,
	@JobCostDescription		VARCHAR(250),
	@SourcesTypes			VARCHAR(MAX),
	@CurrencyGUID 			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@PricePolicy 			INT,
	@ShowServiceProduct		BIT,
	@ShowStockProduct		BIT,
	@ShowAssetsProduct		BIT,
	@ShowQuantityNonUnit	BIT,
	@ShowProductCode		BIT,
	@ShowProductName		BIT,
	@ShowQuantity			BIT,
	@ShowValue				BIT,
	@ShowEmptyPeriods		BIT,
	@UseUnit 				INT,
	@WithDetails			BIT = 1,
	@ShowGroups				BIT = 0,
	@CumulativeBalance		BIT = 0,
	@ProductsConditionGUID	UNIQUEIDENTIFIER = 0x0,
	@ProductsCondition		VARCHAR(MAX),
	@Lang					VARCHAR(100) = 'ar', 
	@UserGUID				UNIQUEIDENTIFIER = 0X0,
	@BranchMask				BIGINT = -1
AS 
	SET NOCOUNT ON
	
				
	SELECT
		0 as [BillType]			,
		0x0  as [BillTypeGUID]	,	
		'' as [BillTypeName]	,	
		'' as [BillTypeAbbrev]	,
		0x0 as [MaterialGUID]	,	
		'' as [MaterialName]	,	
		'' as [MaterialCode]	,	
		0x0 as [GroupGUID]		,	
		'' as [GroupName]		,	
		'' as [GroupCode]		,	
		0 as [GroupLevel]		,
		'' as [GroupPath]		,	
		0 as [buDirection]		,
		getdate() as [Date]		,		
		0 as [Month]			,	
		0 as [Year]				,
		0.0 as [QuantityInput]	,	
		0.0 as [QuantityInput2]	,
		0.0 as [QuantityInput3]	,
		0.0 as [QuantityOutput]	,
		0.0 as [QuantityOutput2],	
		0.0 as [QuantityOutput3],	
		0.0 as [PriceInput]		,
		0.0 as [PriceOutput]	,	
		0.0 as [TotalPrice]		,
		'' as [UnitName]		,	
		'' as [Unit2Name]		,	
		'' as [Unit3Name]		,
		0 AS NumOfSecViolated

	*/
#########################################################
CREATE PROCEDURE ARWA.repTrialBalance
	-- Report Filters
	@AccountGUID 					[UNIQUEIDENTIFIER] = 0X0,
	@MaxLevel 						[INT] = 32000,				-- show this level
	@JobCostGUID					[UNIQUEIDENTIFIER] = 0x0,
	@StartDate 						[DATETIME] = '1/1/2009 0:0:0.0',
	@EndDate 						[DATETIME] = '12/14/2010 23:59:35.21',
	@Class							[VARCHAR](250) = '',
	@CurrencyGUID					[UNIQUEIDENTIFIER] = '0177fdf3-d3bb-4655-a8c9-9f373472715a',
	@ValType						[INT] = 0,			--‰Ê⁄ «· ⁄«œ·
	@SelectedMonth					[INT] = 0,		--Monthly Trial
	@FirstEntryNumber 				[INT] = 0,
	@LastEntryNumber 				[INT] = 1000000000,
	@SourcesTypes					[VARCHAR](MAX) = '00000000-0000-0000-0000-000000000000, 1',
	-- Report Options
	@ShowDetailedAccount 			[BIT] = 1,
	@ShowMainAccount				[BIT] = 0,
	@ShowBalancedAccount 			[BIT] = 0,
	@ShowEmptyAccount 				[BIT] = 0,
	@AllEntries						[BIT] = 0,
	@ShowLastPay					[BIT] = 0,
	@ShowLastDebit					[BIT] = 0,
	@ShowLastCredit					[BIT] = 0,
	@ShowPostedEntries				[BIT] = 1,
	@ShowUnpostedEntries			[BIT] = 0,
	@ShowPreviousBalance			[BIT] = 0,			--Show Prev Balance
	@DontShowCustomursAccounts		[BIT] = 0,
	@UseFilterCurrency				[BIT] = 0,			--Check: «· ’›Ì… ⁄·Ï ⁄„·… »ÿ«ﬁ… «·Õ”«»
	@FilterCurrency					[UNIQUEIDENTIFIER] = 0x0,
	-- Fields Dispaly Options
	@ShowAccountCode				[BIT] = 0,
	@ShowCurrencyAccount			[BIT] = 0,
	@ShowClass						[BIT] = 0,
	-- Other options (No user interaction reqired)
	@UserGUID						[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',
	@Lang							[VARCHAR](10) = 'ar',
	@BranchMask						BIGINT = -1															   -- BranchMask				
	
	/*Deleted Parameters
	@PostedVal 		[INT] = -1 ,-- 1 posted or 0 unposted -1 all posted & unposted   
	@UserSec 			[INT],
	@CurVal 			[FLOAT],   
	@AccType 			[INT],   
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0,   Not Used
	*/
AS   
/*   
this procedure:   
	- ...   
	- ignores ceSecurity if user has readBalance privilage.   
	- algorithm:   
		1. Fill the result from descendings   
		2.   
		3. update parents balances:   
*/   

	--prcInitialize_Environment
	EXEC [prcInitialize_Environment] @UserGUID, '[repTrialBalance]', @BranchMask
	
	
	SET NOCOUNT ON   
	
	-------------------------------------------------
	-- Variables decleration
	DECLARE @Admin [INT],
			@CNT [INT],
			@Sql NVARCHAR(4000),
			@RES NVARCHAR(4000),
			@CostCnt [INT],
			@AllCost [BIT],
			@HospitalPermission [BIT] 

	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@UserGUID,0x00))
	SET @Sql= ''
	SET @RES =''
	SET @HospitalPermission = 1
	
	-------------------------------------------------
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])    
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] smallint)   
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] smallint, [ReadPriceSecurity] smallint)       
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] smallint)       

	-- the #result will hold the un-grouped data before summation, its necessary for security checking:   
	CREATE TABLE [#Result]
	(    
		[enAccount]			[UNIQUEIDENTIFIER],   
		[ceGuid]			[UNIQUEIDENTIFIER],    
		[FixedEnDebit]		[FLOAT],    
		[FixedEnCredit]		[FLOAT],    
		[enDate]			[DATETIME],    
		[ceNumber]			[INT],    
		[AcSecurity]		smallint,    
		[ceSecurity]		smallint,   
		[CurrAccBal]		[FLOAT],   
		[classptr]			[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''   
	)   
	 
	-- Create #prevBalances table to hold accounts previouse balances   
	DECLARE @PrevBalances TABLE
	(    
		[GUID] 				[UNIQUEIDENTIFIER],    
		[PrevDebit]			[FLOAT],    
		[PrevCredit]		[FLOAT],   
		[PrevCurrAccBal]	[FLOAT],   
		[classptr]			[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''
	)
			
	-- The repors' final result table   
	CREATE TABLE [#EndResult] 
	(    
		[ID]				INT IDENTITY(1,1),   
		[GUID]				[UNIQUEIDENTIFIER],    
		[Code]				[VARCHAR](256) COLLATE ARABIC_CI_AI,    
		[Name]				[VARCHAR](256) COLLATE ARABIC_CI_AI,    
		[LatinName]			[VARCHAR](256) COLLATE ARABIC_CI_AI,    
		[ParentGUID]		[UNIQUEIDENTIFIER],    
		[Type]				[INT],    
		[NSons]				[INT],    
		[Level]				[INT] DEFAULT 0,    
		[PrevDebit]			[FLOAT] DEFAULT 0,    
		[PrevCredit]		[FLOAT] DEFAULT 0,    
		[PrevBalDebit]		[FLOAT] DEFAULT 0,    
		[PrevBalCredit]		[FLOAT] DEFAULT 0,    
						
		[TotalDebit]		[FLOAT] DEFAULT 0,    
		[TotalCredit]		[FLOAT] DEFAULT 0,    
		[BalDebit]			[FLOAT] DEFAULT 0,    
		[BalCredit]			[FLOAT] DEFAULT 0,    
		[EndBalDebit]		[FLOAT] DEFAULT 0,    
		[EndBalCredit]		[FLOAT] DEFAULT 0,   
		[haveBalance]		[INT], -- null indicates empty account while 0 indicates balanced account, and 1 not balanced   
		[Status]			[INT] ,   
		[acSecurity]		[smallint],   
		[LastDebit]			[FLOAT] DEFAULT 0,   
		[LastDebitDate]		SMALLDATETIME  DEFAULT '1/1/1980',   
		[LastCredit]		[FLOAT] DEFAULT 0,   
		[LastCreditDate]	SMALLDATETIME  DEFAULT '1/1/1980',   
		[LastPay]			[FLOAT] DEFAULT 0,   
		[LastPayDate]		SMALLDATETIME DEFAULT '1/1/1980',   
		[acCurrGuid]		[UNIQUEIDENTIFIER],   
		[CurrAccBal]		[FLOAT] DEFAULT 0,   
		[PrevCurrAccBal]	[FLOAT] DEFAULT 0,   
		[CurCode]			[VARCHAR](256) COLLATE ARABIC_CI_AI,   
		[classptr]			[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		[Path]				[VARCHAR](4000) COLLATE ARABIC_CI_AI
	)
	
	-- accounts balances table:   
	DECLARE @Balances TABLE
	(   
		[GUID] 			[UNIQUEIDENTIFIER],    
		[TotalDebit]	[FLOAT],    
		[TotalCredit]	[FLOAT],   
		[CurrAccBal]    [FLOAT],   
		[classptr]		[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''
	)    
	
	-- declare variables:   
	DECLARE   
		@Level		[INT],   
		@ZeroValue	[FLOAT],   
		@MinLevel	[INTEGER],   
		@str		[VARCHAR](8000),
		@HosGuid	[UNIQUEIDENTIFIER]
		
	---------------------------------Preparing ----------------------------
	--Prepare @PrevStartDate, @PrevEndDate	
	DECLARE @PrevStartDate	[DATETIME],
			@PrevEndDate	[DATETIME],
			@OpeningDate	[DATETIME]
		
	SET @PrevStartDate = '1-1-1980'
	SET @PrevEndDate = '1-1-1980'	
	SET @OpeningDate = (SELECT CAST(Value AS DATETIME) FROM op000 WHERE Name LIKE 'AmnCfg_FPDate')
	
	IF (@ShowPreviousBalance = 1)--No Monyhly Balance
	BEGIN
		IF(@StartDate = @OpeningDate)
			SET @PrevStartDate = (SELECT DATEADD(day, -1, @OpeningDate))
		ELSE
			SET @PrevStartDate = @OpeningDate
		SET @PrevEndDate = (SELECT DATEADD(day, -1, @StartDate))	
	END
	ELSE IF (@SelectedMonth > 0)
	BEGIN
		SET @PrevStartDate = (SELECT DATEADD(MONTH, @SelectedMonth -1, @OpeningDate))
		SET @PrevStartDate = (SELECT DATEADD(DAY, 1, DATEADD(DAY, -DAY(@PrevStartDate), @PrevStartDate))) -- Set to the first day of the month
		
		SET @PrevEndDate = (SELECT DATEADD(DAY, -1, DATEADD(MONTH, 1, @PrevStartDate)))
	END
	
	--Prepare @AccType
	DECLARE @AccType [INT]
	IF (@AccountGUID = 0x0)
		SET @AccType = -1
	ELSE
		SET @AccType = (SELECT [Type] FROM [ac000] WHERE [GUID] = @AccountGUID)
		
	--Prepare @PostedVal
	--At Least one of (@ShowPostedEntries , @ShowUnpostedEntries) must be 1
	DECLARE @PostedVal [INT]
	IF (@ShowPostedEntries = 1 AND @ShowUnpostedEntries = 1)
		SET @PostedVal = -1		--All Entries
	ELSE IF (@ShowPostedEntries = 1 AND @ShowUnpostedEntries = 0)
		SET @PostedVal =  1		--Posted Entries
	ELSE IF (@ShowPostedEntries = 0 AND @ShowUnpostedEntries = 1)
		SET @PostedVal =  0		--Unposted Entries
		
	--Prepare @Curval
	DECLARE @CurVal [FLOAT]
	SET @CurVal = (Select Top 1 IsNull(mh.CurrencyVal, my.CurrencyVal) 
				   From my000 my 
				   LEFT join mh000 mh on my.[Guid] = mh.[CurrencyGUID] 
				   WHERE my.[GUID] = @CurrencyGUID Order By mh.Date Desc)
	
	-----------------------------------------------------------------------
	-- init    	
	SET @HosGuid = NEWID()   
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]()
	
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	SET @CostCnt = @@ROWCOUNT 
	IF ((SELECT COUNT(*) FROM co000) = @CostCnt) 
		SET @AllCost = 1 
	ELSE 
		SET @AllCost = 0 
	
	-----------------------------------------------------------------------
	-- Prepare the report sources tables
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
	
    INSERT INTO @Types
    SELECT * FROM [fnParseRepSources](@SourcesTypes)
    
    INSERT INTO [#EntryTbl]
	SELECT
		CAST([GUID] AS [UNIQUEIDENTIFIER]),
		[dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types
	WHERE [TYPE] = 1
	
	
	INSERT INTO [#EntryTbl]
	SELECT
		CAST([GUID] AS [UNIQUEIDENTIFIER]),
		[dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types
	WHERE [TYPE] = 2
	
	--For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT
		CAST([GUID] AS [UNIQUEIDENTIFIER]),
		[dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1)
	FROM @Types
	WHERE [TYPE] = 3
	
	--For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT
		CAST([GUID] AS [UNIQUEIDENTIFIER]),
		[dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM @Types
	WHERE [TYPE] = 4
	
	INSERT INTO [#EntryTbl]
	SELECT
		CAST([GUID] AS [UNIQUEIDENTIFIER]),
		[dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types
	WHERE [TYPE] = 5
				    
	INSERT INTO [#EntryTbl] VALUES(@HosGuid,0)   
	
	IF ISNULL(@JobCostGUID,0X00) = 0X00   
		INSERT INTO  [#CostTbl] VALUES (0X00,0)
	
	IF (@UseFilterCurrency=0)
		SET @FilterCurrency=0X00
	-----------------------------------------------------------------------	
	-- 1st. step: Fill the result from descendings:   
	INSERT INTO [#EndResult]    ([GUID], [Code], [Name], [LatinName], [ParentGUID], [Type], [NSons], [Level],[acSecurity],[acCurrGuid], [Path])   
		SELECT    
			[ac].[GUID],    
			[ac].[Code],    
			[ac].[Name],    
			[ac].[LatinName],    
			[ac].[ParentGuid],    
			[ac].[Type],    
			[ac].[NSons],    
			[dl].[Level],   
			[ac].[Security],   
			[ac].[CurrencyGuid],
			[al].[Path]
			
		FROM    
			[dbo].[fnGetAcDescList](@AccountGUID) AS [dl]
			INNER JOIN [ac000] AS [ac] ON [dl].[GUID] = [ac].[GUID]   
			INNER JOIN [dbo].[fnGetAccountsList](@AccountGUID, 1) AS [al] ON [dl].[GUID] = [al].[Guid]
		WHERE (@FilterCurrency = 0X00) OR( [CurrencyGuid] = @FilterCurrency) OR (NSONS >0 )   
		
	IF @ShowCurrencyAccount > 0   
		UPDATE [e]  SET [CurCode] = [myCode] FROM  [#EndResult]     AS [e] INNER JOIN [vwmy] AS [my] ON [my].[myGuid] = [acCurrGuid]   
	-- Calc Current Balance:  
	 
	IF @AccountGUID IN (SELECT [GUID] FROM [AC000] WHERE [TYPE] = 4)   
	BEGIN   
		UPDATE [#EndResult]     SET [LEVEL] = [LEVEL] - 1    
		SET @Cnt = 2   
		WHILE @Cnt > 0   
		BEGIN   
			UPDATE [#EndResult]     SET [LEVEL] = [LEVEL] - 1 WHERE Guid IN (SELECT SonGuid FROM  ci000 A INNER JOIN [#EndResult]     b ON b.Guid = a.ParentGuid WHERE b.Level = 1)   
			SET @CNT = @@RowCount   
		END   
		DELETE  [#EndResult]     WHERE [Type] = 4   
		SELECT GUID,MIN([LEVEL]) [Level] INTO #V FROM [#EndResult]     GROUP BY GUID HAVING COUNT(*) > 1   
		DELETE r FROM [#EndResult]     r INNER JOIN  #V V ON r.Guid = v.Guid AND  r.[Level] = v.[Level]   
		   
		UPDATE [#EndResult]     SET [ParentGUID] = 0X00 WHERE [LEVEL] = 0   
	END    
	SET @Sql='CREATE TABLE  #EndResult2       (    
		 
		[GUID]			[UNIQUEIDENTIFIER],    
		 
		 
		[Level]			[INT] ,    
		[acSecurity]	smallint,   
		[acCurrGuid]	[UNIQUEIDENTIFIER],   
		[CurCode]		[VARCHAR](256) COLLATE ARABIC_CI_AI,   
		[classptr]		[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''''   
		    
		)   
	INSERT INTO #EndResult2 SELECT [GUID] ,  [Level],[acSecurity],[acCurrGuid],[CurCode],[classptr]  FROM [#EndResult]  WHERE NSons = 0  ORDER BY  [GUID] 
	' + CHAR(13) 
	--CREATE INDEX SDwwFSDA ON   [#EntryTbl]([Type]) 
	SET @Sql= @Sql + 'DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT)' 
	SET @Sql = @Sql +' INSERT INTO @Curr SELECT DATE,CurrencyVal FROM mh000 WHERE CURRENCYGuid = '''+ CAST ( @CurrencyGUID AS  NVARCHAR(36) ) +''' UNION ALL SELECT  ''1/1/1980'',CurrencyVal FROM MY000 WHERE Guid = ''' +  CAST ( @CurrencyGUID AS  NVARCHAR(36) ) +'''' + NCHAR(13) 
	SET @Sql = @Sql + 'DECLARE @Result2 TABLE (    
		[enAccount]			[UNIQUEIDENTIFIER],    
		[ceGuid]			[UNIQUEIDENTIFIER],    
		[FixedEnDebit]		[FLOAT],    
		[FixedEnCredit]		[FLOAT],    
		[enDate]			[DATETIME],    
		[ceNumber]			[INT],    
		[AcSecurity]		SMALLINT,    
		[ceSecurity]		SMALLINT,   
		[TypeGuid]			[UNIQUEIDENTIFIER],   
		[CurrAccBal]		[FLOAT],   
		[classptr]		[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT ''''	)  ' + NCHAR(13) 
	 
	SET @Sql= @Sql +'INSERT INTO @Result2   
			SELECT [en].[AccountGUID], '  
			--IF @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0  
				SET @Sql = @Sql + '[ce].[ceGuid],'  
			--ELSE  
			--	SET @Sql = @Sql + '0X00 ,'   
			IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
				SET @Sql = @Sql + 'SUM('   
			IF(@ValType=0)  
				SET @Sql = @Sql+'[en].[Debit] * FACTOR '  
			ELSE  
				SET @Sql = @Sql+'[en].[Debit]/'+CAST(@CurVal AS NVARCHAR(36))  
			IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
				SET @Sql = @Sql + ')'  
			SET @Sql =@Sql + ','  
			IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
				SET @Sql = @Sql + 'SUM('   
			IF(@ValType=0)  
				SET @Sql = @Sql+' [en].[Credit] * FACTOR'  
			ELSE  
				SET @Sql = @Sql+'[en].[Credit]/'+CAST(@CurVal AS NVARCHAR(36))  
			IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
				SET @Sql = @Sql + ')'  
			SET @Sql =@Sql + ','  
			SET @Sql = @Sql +'CASE WHEN [en].[Date] >= '+[dbo].[fnDateString](@StartDate)+' THEN '+[dbo].[fnDateString](@StartDate)+'  ELSE '+ [dbo].[fnDateString](@PrevStartDate) +' END  DATE'  
			SET @Sql = @Sql + ',0,    
					  [AcSecurity],    
					  [ceSecurity], '  
		IF(@HospitalPermission=1)   
		BEGIN  
			SET @Sql=@Sql+'(CASE ISNULL([ceTypeGuid],0X00)    
					WHEN 0X00 THEN CASE ISNULL([er].[ParentGuid],0x00)    
					WHEN 0X00 THEN 0X00    
					ELSE CASE    
						WHEN [er].[ParentType] BETWEEN 300 AND 305 THEN CAST ('''+ CAST(@HosGuid AS NVARCHAR (36))+'''AS UNIQUEIDENTIFIER)   
						ELSE 0X00    
					END    
					END   
					ELSE [ceTypeGuid]  
					END)[ceTypeGuid] ,'  
		END  
		ELSE  
			SET @Sql=@Sql+'[ceTypeGuid] [ceTypeGuid],'  
		IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
			SET  @Sql=@Sql+'SUM('  
		IF (@ShowCurrencyAccount = 0)  
			SET @Sql = @Sql+'0'  
		ELSE  
			SET @Sql = @Sql + '[dbo].[fnCurrency_fix]([en].[Debit] - [en].[Credit], [en].[CurrencyGUID], [en].[CurrencyVal], [ac].[acCurrGuid], [en].[Date])'  
		IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
			SET  @Sql=@Sql+')'  
		IF(@ShowClass = 0)  
			SET @Sql = @Sql +','''' AS CLASS '  
		ELSE  
			SET @Sql= @Sql + ',en.class  CLASS '   
		SET @Sql = @Sql + 'FROM    
				 [vwCe] AS [ce] INNER JOIN ' 
		SET @Sql = @Sql  + '(SELECT *,1 / CASE WHEN [CurrencyGUID] ='''+ CAST ( @CurrencyGUID AS  NVARCHAR(36) ) +''' THEN [CurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE DATE <=  e.date  ORDER BY DATE DESC) END FACTOR FROM [en000] e)' 
		SET @Sql = @Sql  + 'AS [en] ON [en].[ParentGuid] = [ceGuid] '  
		IF(@HospitalPermission=1)  
		BEGIN  
			SET @Sql=@Sql+'LEFT JOIN [er000] AS [er] ON [er].[EntryGUID] = [ceGuid]   
				  INNER JOIN #EndResult2 AS [ac] ON [ac].[Guid] = [en].[AccountGUID]   
				   ' 
			IF @AllCost = 0  
				SET @Sql=@Sql+ 'INNER JOIN [#CostTbl] AS [co] ON [En].[CostGUID] = [co].[CostGUID]' 
		END	  
		ELSE  
		BEGIN 
			SET @Sql = @Sql + 'INNER JOIN #EndResult2 AS [ac] ON [ac].[Guid] = [en].[AccountGUID]   
				              INNER JOIN [#EntryTbl] AS [t]  ON [ceTypeGuid] = [t].[Type]' 
			IF @AllCost = 0  
				SET @Sql=@Sql+ 'INNER JOIN [#CostTbl] AS [co] ON [En].[CostGUID] = [co].[CostGUID]' 
		END			          
					          
	SET @Sql = @Sql +	 ' WHERE ([en].[Date] BETWEEN ' + [dbo].[fnDateString](@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) +' OR [en].[Date] BETWEEN '+[dbo].[fnDateString](@PrevStartDate)+' AND'+[dbo].[fnDateString]( @PrevEndDate)+')    
				  AND ((' + CAST (@PostedVal AS NVARCHAR (2))+' = -1) OR ( [ceIsPosted] ='+ CAST( @PostedVal AS NVARCHAR (2))+'))   
				  AND (([ceNumber] BETWEEN '+ CAST(@FirstEntryNumber AS NVARCHAR (10))+ ' AND ' +CAST( @LastEntryNumber AS NVARCHAR(10))+ ' AND '+CAST( @AllEntries AS NVARCHAR (10))+' = 0 )  OR ' ++CAST( @AllEntries AS NVARCHAR (10))+' = 1)   
				  AND (''' + CAST (@Class AS NVARCHAR (100))+''' = '''' or [en].[class] like ''%'+CAST( @Class AS NVARCHAR(100))+'%'')'  
	IF NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0)  
			 SET @Sql = @Sql + ' GROUP BY   
			  [en].[AccountGUID], [ce].[ceGuid],   
			  CASE WHEN [en].[Date] >= '+[dbo].[fnDateString](@StartDate)+' THEN '+[dbo].[fnDateString](@StartDate)+'  ELSE '+ [dbo].[fnDateString](@PrevStartDate) +' END,  
		 	  [AcSecurity],    
		          [ceSecurity],   
		 	  ceTypeGuid,  
			  CLASS'	  
	IF (NOT( @ShowLastDebit> 0 OR @ShowLastCredit > 0 OR @ShowLastPay > 0) AND (@HospitalPermission=1) )	  
		SET @Sql = @Sql + ',[er].[ParentGuid] ,[er].[ParentType] '  
	SET @Sql = @Sql + NCHAR(13)  
	--EXEC sp_executesql @Sql	  
	SET @RES = @Sql + 'INSERT INTO [#Result]([enAccount],[ceGuid],[FixedEnDebit], [FixedEnCredit], [enDate], [ceNumber], [AcSecurity], [ceSecurity],[CurrAccBal],[classptr])   
					SELECT    
						[enAccount],    
						[ceGuid],   
						[FixedEnDebit],    
						[FixedEnCredit],    
						[enDate],    
						[ceNumber],    
						[AcSecurity],    
						[ceSecurity],   
						[CurrAccBal],   
						[classptr]   
					FROM    
						@Result2 AS [f]'  
				IF(@HospitalPermission=1)    
		 
					SET @RES = @RES+'INNER JOIN [#EntryTbl] AS [t]  ON [f].[TypeGuid] = [t].[Type]'    
	EXEC sp_executesql @RES	    
	-- if the use has readBalance privilage, ignore ceSecurity by suppressing ceSecurity to 0:   
	  
	DECLARE @SecBalPrice [INT]    
	IF @Admin = 0   
	BEGIN   
		SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGuid]())   
		--IF @SecBalPrice > 0   
		--	UPDATE [#Result] SET [ceSecurity] = -10 WHERE [AcSecurity] <= @SecBalPrice   
		
		--Filter by Security
		DECLARE @NumOfSecViolated [INT]
		SET @NumOfSecViolated = 0
		DELETE FROM [#Result]
		WHERE
		--Filter Accounts
		[enAccount] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID) WHERE [IsSecViol] = 1 )
		OR
		--Filter Ce
		(@SecBalPrice = 0 AND [CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 ))
		
		SET @NumOfSecViolated = @@ROWCOUNT
		--print @NumOfSecViolated
		--SET @NumOfSecViolated = 0
		--Filter by Branches
		DELETE FROM [#Result]
		WHERE
		--Filter Accounts
		[enAccount] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID) WHERE [IsSecViol] = 0)
		OR
		--Filter Ce
		[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 0)
		--SET @NumOfSecViolated = @@ROWCOUNT
		--print @NumOfSecViolated
	END   
	-- check #result security:   
	--EXEC [prcCheckSecurity]   
	-- insert balances from #result:   
	INSERT INTO @Balances   
		SELECT    
			[enAccount],   
			SUM([FixedEnDebit]),   
			SUM([FixedEnCredit]),   
			SUM([CurrAccBal]),[classptr]	   
		FROM    
			[#Result]   
		WHERE    
			[enDate] BETWEEN @StartDate AND @EndDate   
			   
		GROUP BY    
			[enAccount],[classptr]   
	-- Calc Prev Balances:   
	  
	INSERT INTO @PrevBalances    
		SELECT    
			[enAccount],   
			SUM([FixedEnDebit]),   
			SUM([FixedEnCredit]),   
			SUM([CurrAccBal]),[classptr]   
		FROM   
			[#Result]   
		WHERE    
			[enDate] BETWEEN @PrevStartDate AND @PrevEndDate   
		GROUP BY    
			[enAccount],[classptr]   
	-- update #EndResult with Balances   
	UPDATE [#EndResult]     SET   
			[TotalDebit]	= ISNULL([b].[TotalDebit], 0),   
			[TotalCredit]	= ISNULL([b].[TotalCredit], 0),   
			[CurrAccBal]  = ISNULL([b].[CurrAccBal], 0)   
		FROM    
			[#EndResult]     AS [e] INNER JOIN @Balances [b]   
			ON [e].[GUID] = [b].[GUID] WHERE [b].[classptr] = ''   
			
	IF @ShowClass = 1   
		INSERT INTO [#EndResult]     ([GUID],[TotalDebit],[TotalCredit],[CurrAccBal],[Code],		   
			[Name],[LatinName],[ParentGUID],[Type],[NSons],[Level],[classptr], [Path])		   
		SELECT    
			[e].[GUID], 
			ISNULL([b].[TotalDebit], 0),   
			ISNULL([b].[TotalCredit], 0),   
			ISNULL([b].[CurrAccBal], 0),   
			[Code],		   
			[Name],[LatinName],[ParentGUID],[Type],[NSons],[e].[Level],[b].[classptr], [al].[Path]  
		FROM    
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID]
			INNER JOIN [dbo].[fnGetAccountsList](@AccountGUID, 1) AS [al] ON [e].[GUID] = [al].[Guid]
		WHERE [b].[classptr] <> ''   
		   
		   
	-- update #EndResult with PrevBalances:   
	UPDATE [#EndResult]     SET   
			[PrevDebit]	= ISNULL([b].[PrevDebit], 0),   
			[PrevCredit]= ISNULL([b].[PrevCredit], 0),   
			[PrevCurrAccBal] = ISNULL([b].[PrevCurrAccBal], 0)   
		FROM    
			[#EndResult]     AS [e] INNER JOIN @PrevBalances [b]   
			ON [e].[GUID] = [b].[GUID]  
	  
	IF @ShowLastDebit > 0   
		UPDATE [e]    
		SET [LastDebit] = ISNULL((SELECT TOP 1 [FixedEnDebit] FROM [#Result] WHERE [enAccount] = [GUID] AND [FixedEnDebit] > 0 ORDER BY [enDate] DESC,[ceNumber] DESC),0),   
		[LastDebitDate] = ISNULL((SELECT TOP 1 [enDate] FROM [#Result] WHERE [enAccount] = [GUID] AND [FixedEnDebit] > 0 ORDER BY [enDate] DESC),'1/1/1980')	     
		FROM  [#EndResult]     AS [e]   
	IF @ShowLastCredit > 0   
		UPDATE [e]    
		SET [LastCredit] = ISNULL((SELECT TOP 1 [FixedEnCredit] FROM [#Result] WHERE [enAccount] = [GUID] AND [FixedEnCredit] > 0 ORDER BY [enDate] DESC,[ceNumber] DESC),0),   
		[LastCreditDate] = ISNULL((SELECT TOP 1 [enDate] FROM [#Result] WHERE [enAccount] = [GUID] AND [FixedEnCredit] > 0 ORDER BY [enDate] DESC),'1/1/1980')	  	    
		FROM  [#EndResult]     AS [e]   
	IF @ShowLastPay > 0   
		UPDATE [e]    
		SET [LastPay] = ISNULL((SELECT TOP 1 [FixedEnCredit] FROM [#Result] AS  [en] INNER JOIN [Er000] AS [er] ON [en].[ceGuid] = [er].[EntryGuid] INNER JOIN [vwPy] AS [py] ON [er].[ParentGuid] = [py].[pyGuid] WHERE [enAccount] = [e].[GUID] AND [FixedEnCredit] > 0 ORDER BY [enDate] DESC,[ceNumber] DESC),0),   
		[LastPayDate] = ISNULL((SELECT TOP 1 [enDate] FROM [#Result] AS  [en] INNER JOIN [Er000] AS [er] ON [en].[ceGuid] = [er].[EntryGuid] INNER JOIN [vwPy] AS [py] ON [er].[ParentGuid] = [py].[pyGuid] WHERE [enAccount] = [e].[GUID] AND [FixedEnCredit] > 0 ORDER BY [enDate] DESC),'1/1/1980')	  	    
		FROM  [#EndResult]     AS [e]   
	UPDATE [#EndResult]     SET   
		[BalDebit] = CASE WHEN [TotalDebit] - [TotalCredit] < 0 THEN 0 ELSE [TotalDebit] - [TotalCredit] END,   
		[BalCredit] = CASE WHEN [TotalDebit] - [TotalCredit] < 0 THEN [TotalCredit] - [TotalDebit] ELSE 0 END,   
		[PrevBalDebit] = CASE WHEN [PrevDebit] - [PrevCredit] < 0 THEN 0 ELSE [PrevDebit] - [PrevCredit] END,   
		[PrevBalCredit] = CASE WHEN [PrevDebit] - [PrevCredit] < 0 THEN [PrevCredit] - [PrevDebit] ELSE 0 END,   
		[haveBalance] = CASE WHEN ABS(([TotalDebit] + [PrevDebit]) - ([TotalCredit] + [PrevCredit])) < @ZeroValue AND ([TotalDebit] + [PrevDebit]) + ([TotalCredit] + [PrevCredit]) > @ZeroValue THEN 0  WHEN ABS(([TotalDebit] + [PrevDebit]) - ([TotalCredit] + [PrevCredit])) > @ZeroValue AND ([TotalDebit] + [PrevDebit]) + ([TotalCredit] + [PrevCredit]) > @ZeroValue THEN 1  ELSE NULL END   
	-- 3rd. step: update parents balances:   
	   
	IF @Admin = 0   
	BEGIN   
		   
		DELETE [#EndResult]     WHERE  [acSecurity] > [dbo].[fnGetUserAccountSec_Browse](@UserGUID)   
		SET @Level = @@RowCount   
		IF EXISTS(SELECT * FROM [#SecViol] WHERE [Type] = 5)   
			INSERT INTO [#SecViol] VALUES(@Level,5)   
		IF @ShowMainAccount = 1   
		BEGIN   
			WHILE @Level > 0   
			BEGIN   
				UPDATE [r] SET [Level] = [r].[Level] - 1, [ParentGUID] = [ac].[ParentGUID]   
				FROM [#EndResult]     AS [r]    
				INNER JOIN  [ac000] AS [ac] ON [r].[ParentGUID] = [ac].[Guid]    
				LEFT JOIN  [#EndResult]     AS [r1] ON [r1].[GUID] = [ac].[Guid]    
				WHERE ISNULL([r].[ParentGUID],0X00) <> @AccountGUID AND [r].[GUID] <> @AccountGUID    
				AND [r].[Level] <> ( ISNULL([r1].[Level],-2) + 1)    
				SET @Level = @@RowCount   
			END   
		END   
		   
	END   
	  

	IF @ShowMainAccount > 0   
	BEGIN   
		SET @Level = (SELECT MAX([Level]) FROM [#EndResult]    )   
		WHILE @Level >= 0    
		BEGIN    
			UPDATE [#EndResult]     SET    
					[PrevDebit]		= ISNULL([SumPrevDebit], 0),   
					[PrevCredit]	= ISNULL([SumPrevCredit], 0),   
					[TotalDebit]	= ISNULL([SumTotalDebit], 0),   
					[TotalCredit]	= ISNULL([SumTotalCredit], 0),   
					[BalDebit]		= ISNULL([SumBalDebit], 0),   
					[BalCredit]		= ISNULL([SumBalCredit], 0),   
					[PrevBalDebit]	= ISNULL([SumPrevBalDebit], 0),   
					[PrevBalCredit]	= ISNULL([SumPrevBalCredit], 0),   
					[haveBalance]	= [sumHaveBalance]   
				FROM    
					[#EndResult]     AS [Father] INNER JOIN (    
						SELECT   
							[ParentGUID],   
							SUM([PrevDebit]) AS [SumPrevDebit],   
							SUM([PrevCredit]) AS [SumPrevCredit],    
							SUM([TotalDebit]) AS [SumTotalDebit],   
							SUM([TotalCredit]) AS [SumTotalCredit],   
							SUM([BalDebit]) AS [SumBalDebit],   
							SUM([BalCredit]) AS [SumBalCredit],    
							SUM([PrevBalDebit]) AS [SumPrevBalDebit],    
							SUM([PrevBalCredit]) AS [SumPrevBalCredit],   
							SUM([haveBalance])AS [sumHaveBalance]   
						FROM   
							[#EndResult]        
						WHERE    
							[Level] = @Level AND [haveBalance] IS NOT NULL   
						GROUP BY   
							[ParentGUID]   
						) AS [Sons] -- sum sons   
					ON [Father].[GUID] = [Sons].[ParentGUID]   
			SET @Level = @Level - 1   
		END   
	END   
	--    
	IF @ShowEmptyAccount = 0 --dont view acc that bal is 0 And it has'nt move   
		DELETE FROM [#EndResult]     WHERE [haveBalance] IS NULL   
	   
	IF @ShowBalancedAccount = 0	--AND @ShowEmptyAccount = 0   
		DELETE FROM [#EndResult]     WHERE [haveBalance] = 0   
	   
	IF @AccType = 4 AND @ShowDetailedAccount = 0   
		DELETE [#EndResult]     FROM [#EndResult]     AS [r] INNER JOIN [ci000] AS [c] ON [r].[GUID] = [c].[SonGUID]   
		WHERE [r].[Nsons] = 0 AND [c].[ParentGUID] = @AccountGUID AND ISNULL([c].[SonGUID], 0x0) = 0x0   
	ELSE IF @ShowDetailedAccount = 0   
			DELETE FROM [#EndResult]     WHERE [Nsons] = 0    
	-- get Min Level if Min > 1 then Update levels to level - 1   
	SET @MinLevel = ISNULL((SELECT MIN([Level]) FROM [#EndResult]    ), 0)   
	IF @MinLevel > 1   
		UPDATE [#EndResult]     SET [Level] = [Level] - 1    
	-- maxLevel   
	IF (@MaxLevel <> 0)
		SET @MaxLevel = @MaxLevel + ISNULL((SELECT DISTINCT [Level] FROM [#EndResult]     WHERE [GUID] = @AccountGUID), 0)   
	IF @DontShowCustomursAccounts = 1 AND @ShowMainAccount = 0   
		UPDATE [er] SET [NSons] = 0 FROM [#EndResult]     AS [er] INNER JOIN [ac000] AS [ac] ON [ac].[ParentGuid] = [er].[GUID] INNER JOIN  [cu000] AS [cu] ON  [CU].[AccountGuid] = [AC].[Guid]   
	IF EXISTS(SELECT [GUID] FROM [#EndResult]     GROUP BY [GUID] HAVING COUNT(*) > 1)   
	BEGIN   
		 DELETE  e FROM [#EndResult]     e INNER JOIN (SELECT [GUID],classptr,MIN(ID) ID FROM [#EndResult]     GROUP BY [GUID],classptr HAVING COUNT(*) > 1) v ON v.[GUID] = e.[GUID] WHERE v.[ID] <> e.[ID]   
	END   
	-- 5th. step: return main result set:   
	
	SELECT   
			[e].[GUID] 								AS [acNumber],    
			[e].[Code] 								AS [acCode],    
			[e].[Name] 								AS [acName],    
			[e].[LatinName] 						AS [acLatinName],    
			[e].[ParentGUID] 						AS [acParent],    
			[e].[Type] 								AS [acType],    
			[e].[NSons] 							AS [acNSons],    
			[e].[Level],    
			[e].[PrevDebit] 						AS [enPrevDebit],    
			[e].[PrevCredit] 						AS [enPrevCredit],    
			[e].[TotalDebit] 						AS [enTotalDebit],    
			[e].[TotalCredit] 						AS [enTotalCredit],   
			[e].[BalDebit] 							AS [enBalDebit],   
			[e].[BalCredit] 						AS [enBalCredit],    
			[e].[PrevBalDebit] 						AS [enPrevBalDebit],    
			[e].[PrevBalCredit] 					AS [enPrevBalCredit],    
			([e].[PrevBalDebit] + [e].[BalDebit]) 	AS [enEndBalDebit],    
			([e].[PrevBalCredit] + [e].[BalCredit]) AS [enEndBalCredit],    
			[e].[Status] ,   
			ISNULL ([Cu].[Guid],0x00) AS [CuGuid],   
			[LastDebit],   
			[LastDebitDate],   
			[LastCredit],   
			[LastCreditDate],   
			[LastPay],   
			[LastPayDate],[CurrAccBal],[PrevCurrAccBal],[CurCode],[acCurrGuid],   
			[ClassPtr],
			[haveBalance],
			(CASE WHEN ISNULL(@NumOfSecViolated, 0) > 0 Then 0 Else 1 END) As IsFullResult
		FROM    
			[#EndResult]     AS [e] LEFT JOIN [CU000] AS [CU] ON [CU].[AccountGuid] = [e].[Guid]   
		WHERE   
			([Level] < @MaxLevel OR @MaxLevel = 0)   
			AND (@ShowMainAccount = 1 OR  [NSons] = 0)   
			AND (@DontShowCustomursAccounts = 0  OR ISNULL ([Cu].[Guid],0x00) = 0X00)   
		ORDER BY   
			[Path]
			
			
	--prcFinalize_Environment 
	EXEC [prcFinilize_Environment] '[repTrialBalance]'
#########################################################
CREATE PROCEDURE ARWA.repSerialNumbersActivity
	-----------------Report Filters-----------------------
	@SerialNumberName 	[VARCHAR] (256)    = '', 
	@StartDate 			[DateTime]         = '1/1/2009 0:0:0.0', 
	@EndDate 			[DateTime]         = '1/1/2021 0:0:0.0', 
	@ShowPosted			[BIT]			   = 1,
	@ShowUnPosted		[BIT]              = 1,
	@NotesContain 		[VARCHAR] (256)	   = '', 
	@NotesNotContain	[VARCHAR] (256)	   = '',
	@CurrencyGUID 		[UNIQUEIDENTIFIER] = '0177fdf3-d3bb-4655-a8c9-9f373472715a' , 
	@ProductGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000' , 
	@GroupGUID 			[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000' , 
	@StoreGUID 			[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000' , 
	@CustomerGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@AccountGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@ProductCondition	AS VARCHAR(MAX)	   = '', 
	@JobCostGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000',
	@Lang				VARCHAR(100)	   = 'ar',		--0 Arabic, 1 Latin
	@UserGUID			[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	--Guid Of Logining User
	@BranchMask			[BIGINT]		   = -1,

	-----------------Report Sources-----------------------
	@SourcesTypes		VARCHAR(MAX)		= 'A7D1E04E-102F-4DAF-9792-1267DEB3591C,2,8C6A693B-5F7D-4570-917D-2E7941E195B3,2,CE2BC877-C6E1-4B9A-81F2-369147FEFD98,2,2FFBB4C2-8472-4333-9CF4-6342A1030682,2,FB256FE0-1883-4357-AD9F-8C28170D7460,2,70CC59C9-3EC5-4D5E-BB99-92DE3508EB06,2,D4F4933E-805E-47F7-9CD7-B25E7A78D4DA,2,8E899D39-FB88-46B5-BD08-B7D512DC4BA0,2,39ECA4D6-F63A-4FC3-B7EA-C6652BEF2142,2,55D1F1FC-68EB-47D3-BD5B-CECAF4A5F2D4,2,A4FAD32E-4FCA-4B09-816A-D488B36B633A,2,8B40BBD2-BEEB-454E-B080-D61A9A907DC2,2,484A7EEC-F3D8-4FAE-A90A-D8B9B0507337,2,011569AA-CB37-41C6-96A5-FC5700D5EA8F,2,34408B95-A1B8-481E-AFC0-FC8602555998,2,09F01BF2-69EB-4237-9DEE-0BC8332942FC,5,34401010-3A12-4F23-9509-1B7F6C6BAF82,5,164A5F82-A40A-41CB-AE17-15B57BD5BCFD,1,EA69BA80-662D-4FA4-90EE-4D2E1988A8EA,1,D36366BA-4079-4602-BE4A-7F4ADB2F4E5A,1,3DF31F7C-2CC4-464E-869B-B74FEAA4B301,1,426E158F-AEC7-4BE9-9492-C3E684D333BA,1,00000000-0000-0000-0000-000000000000,1',
	-----------------Materials Options----------------------------------
	@ShowProductGroup          [BIT] = 1   --Show [mtCompany]			«·„Ã„Ê⁄…
	/*
		This Report Requires Packaging [buFormatedNumber] OR [buLatinFormatedNumber] 
		Please Take A Look At Al-Ameen 8.0
	*/
AS 
	SET NOCOUNT ON 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	Exec [prcSetSessionConnections] @UserGuid,@BranchMask
	
	DECLARE @CurrencyVal FLOAT
	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE GUID = @CurrencyGuid
	
	IF @NotesContain IS NULL 
		SET @NotesContain = '' 
	IF @NotesNotContain IS NULL 
		SET @NotesNotContain = '' 
	IF @SerialNumberName IS NULL 
		SET @SerialNumberName = '' 
	
	-------Bill Resource ---------------------------------------------------------      
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTypesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnPostedSec] [INT], [ReadPriceSecurity] [INT])       
    INSERT INTO [#BillTypesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	-- Material 
	CREATE TABLE [#MatTbl]( MatGuid [UNIQUEIDENTIFIER] , [mtSecurity] [INT]) 
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@ProductGuid, @GroupGuid,-1, 0x0, @ProductCondition 
	-- Store
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGuid 
	SELECT [StoreGuid], [s].[Security],[Name] AS [stName], [LatinName] AS [stLatinName] INTO [#StoreTbl2] FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[Guid] = [StoreGuid] 
	
	-- Cost Center
	CREATE TABLE [#CostTbl]( [JobCostGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@JobCostGUID 
	IF @JobCostGUID = 0X00 
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
		
	-- Customer
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 		@CustomerGUID, @AccountGUID 
	SELECT [CustGuid] , [c].[Security],[CustomerName] AS [buCust_Name], [LatinName] AS [buCust_LatinName] INTO [#CustTbl2] FROM [#CustTbl] AS [c] INNER JOIN [cu000] AS [cu] ON [cu].[Guid] = [c].[CustGuid] 
	
	
	IF ((@CustomerGUID = 0X00) AND ( @AccountGUID = 0X00)) 
		INSERT INTO [#CustTbl2] VALUES(0X00, 0, '', '')
	
	-- Sn Table
	CREATE TABLE [#SNGuidsTbl]( [Guid] [UNIQUEIDENTIFIER],[ParentGuid] [UNIQUEIDENTIFIER]) 
	INSERT INTO [#SNGuidsTbl]( [Guid],[ParentGuid]) SELECT DISTINCT [biGUID],[ParentGuid] From [snt000] [t] INNER JOIN [snc000] [s] ON [s].[Guid] = [t].[ParentGuid] WHERE @SerialNumberName = '' OR [SN] = @SerialNumberName

	
	CREATE TABLE [#Res] ( 
			[biGuid]				[UNIQUEIDENTIFIER]  
	) 
	CREATE TABLE [#Result] 
	( 
		[buType]				[UNIQUEIDENTIFIER] , 
		[buNumber]				[UNIQUEIDENTIFIER] , 
		[buFormatedNumber]		[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buLatinFormatedNumber]	[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buNum]					[INT],  
		[biNum]					[INT], 
		[BuSortFlag]			[INT], 
		[biGuid]				[UNIQUEIDENTIFIER] , 
		[biMatPtr]				[UNIQUEIDENTIFIER] , 
		[buIsPosted]			[INT], 
		[biNotes]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[biPrice]				[FLOAT], 
		[buDisc]				[FLOAT], 
		[buExtra]				[FLOAT], 
		[biQty]					[FLOAT], 
		[biCurrencyPtr]			[UNIQUEIDENTIFIER] , 
		[biCurrencyVal]			[FLOAT], 
		[buDate]				[DateTime] , 
		[buNotes]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buVendor]				[INT], 
		[buSalesManPtr]			[INT], 
		[biStorePtr]			[UNIQUEIDENTIFIER] , 
		[buCust_Name]			[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buCust_LatinName]		[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[stName]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[stLatinName]			[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[Security]				[INT], 
		[UserSecurity] 			[INT], 
		[UserReadPriceSecurity]	[INT], 
		[grName]				[VARCHAR] (256) COLLATE ARABIC_CI_AI ,
		[grLatinName]			[VARCHAR] (256) COLLATE ARABIC_CI_AI ,
		FullResult				[INT]
	) 
	INSERT INTO [#Result] 
	SELECT 
		[bubi].[buType], 
		[bubi].[buGUID], 
		[bubi].[buFormatedNumber],
		[bubi].[buLatinFormatedNumber],
		[bubi].[buNumber], 
		[bubi].[biNumber], 
		[bubi].[BuSortFlag], 
		[bubi].[biGuid], 
		[bubi].[biMatPtr], 
		[bubi].[buIsPosted], 
		[bubi].[biNotes], 
		[dbo].[fnCurrency_fix](([bubi].[biPrice] * [bubi].[biQty]/([bubi].[biQty]+[bubi].[bibonusQnt])), [bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID,[bubi].[buDate]),  
		CASE buTotal WHEN 0 THEN 0 ELSE [dbo].[fnCurrency_fix](  
		([buTotalDisc] - [buItemsDisc] - buBonusDisc) * (([bubi].[biPrice]* [bubi].[biQty]/([bubi].[biQty]+[bubi].[bibonusQnt]) / BuTotal) + ( BuItemsDisc / ([bubi].[biQty] + [bubi].[biBonusQnt]))), [bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID, [bubi].[buDate]) END, 
		CASE buTotal WHEN 0 THEN 0 ELSE [dbo].[fnCurrency_fix](  
		([buTotalExtra] - [buItemsExtra]) *  ([bubi].[biPrice]* [bubi].[biQty]/([bubi].[biQty]+[bubi].[bibonusQnt]) / BuTotal)   
		+ ( BuItemsDisc / ([bubi].[biQty] + [bubi].[biBonusQnt])), [bubi].[biCurrencyPtr], [bubi].[biCurrencyVal], @CurrencyGUID, [bubi].[buDate]) END, 
		[bubi].[biQty], 
		[bubi].[biCurrencyPtr], 
		[bubi].[biCurrencyVal], 
		[bubi].[buDate], 
		[bubi].[buNotes], 
		[bubi].[buVendor], 
		[bubi].[buSalesManPtr], 
		[bubi].[biStorePtr], 
		[cu].[buCust_Name], 
		[cu].[buCust_LatinName],
		[st].[stName], 
		[st].[stLatinName],
		[bubi].[BuSecurity], 
		CASE [BuIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSec] END, 
		[bt].[ReadPriceSecurity], 
		'',
		'',
		1
	FROM 
		[vwbubi] AS [buBi]
		INNER JOIN [#BillTypesTbl] AS [bt] ON [bubi].[buType] = [bt].[Type] 
		INNER JOIN [#MatTbl] AS [mtTbl] ON [bubi].[biMatPtr] = [mtTbl].[MatGuid] 
		INNER JOIN (SELECT DISTINCT [guid] FROM [#SNGuidsTbl]) AS [g] ON [bubi].[biGuid] = [g].[guid] 
		INNER JOIN [#CustTbl2] AS [cu] ON [buBi].[BuCustPtr] = [cu].[CustGUID] 
		INNER JOIN  [#StoreTbl2] AS [st] ON  [st].[StoreGUID] = [BiStorePtr] 
		INNER JOIN  [#CostTbl] AS [co] ON [co].[JobCostGUID] = [buBi].[biCostPtr] 
	WHERE 
		([bubi].[buDate] BETWEEN @StartDate AND @EndDate) 
		AND( (@ShowPosted = 1 AND [BuIsPosted] = 1 ) OR (@ShowUnPosted = 1 AND [BuIsPosted] = 0)) 
		AND( (@NotesContain = '') OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [BiNotes] LIKE '%' + @NotesContain + '%')) 
		AND( (@NotesNotContain ='') OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
	
	EXEC [prcCheckSecurity] 

	IF Exists(Select * from #SecViol)
		Update #Result SET FullResult = 0
	
	CREATE CLUSTERED INDEX SNID ON #result([buDate],[buNum],[biNum],[BuSortFlag]) 

	IF (@ShowProductGroup = 1) 
		UPDATE [r] SET [grName] = [gr].[grName],  [grLatinName] = [gr].[grLatinName]
		FROM [#Result] AS [r] INNER JOIN 
		(  
			SELECT [mt].[Guid],[grName] AS [grName], [grLatinName] AS [grLatinName]
			FROM [mt000] AS [mt] 
			INNER JOIN [vwGr] AS [gr1] ON [mt].[GroupGuid] = [gr1].[grGuid] 
		) AS [gr] ON  [biMatPtr] = [gr].[guid] 
	-- return first result set 
	SELECT 
		[SNC].SN,
		[r].[buType], 
		[r].[buNumber], 
		--CASE WHEN [SNT].[Item] = 0 AND [r].[BiNum] = 0 THEN [r].[buFormatedNumber] ELSE '' END [buFormatedNumber],
		--CASE WHEN [SNT].[Item] = 0 AND [r].[BiNum] = 0 THEN [r].[buLatinFormatedNumber] ELSE '' END [buLatinFormatedNumber],		
		[r].[buFormatedNumber],
		[r].[buLatinFormatedNumber],
		[r].[buNum], 
		[r].[BuSortFlag], 
		[r].[biGuid], 
		[r].[buIsPosted], 
		[r].[biNotes], 
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[biPrice] ELSE 0 END AS [biPrice], 
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN 1 ELSE 0 END * [buDisc]  AS [buDisc], 
		CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN 1 ELSE 0 END * [buExtra] AS [buExtra], 
		[r].[biQty],	 
		[r].[biCurrencyPtr], 
		[r].[biCurrencyVal], 
		[r].[buDate], 
		[r].[buNotes], 
		[r].[buVendor], 
		[r].[buSalesManPtr], 
		[r].[buCust_Name], 
		[r].[buCust_LatinName], 
		[r].[biMatPtr] AS [MatPtr], 
		[mt].[mtName], 
		[mt].[mtLatinName],
		[mt].[MtCode], 
		[mt].[MtLatinName], 
		[mt].[MtDefUnitFact], 
		[mt].[mtDefUnitName], 
		[mt].[mtBarCode], 
		[mt].[mtSpec], 
		[mt].[mtDim], 
		[mt].[mtOrigin], 
		[mt].[mtPos], 
		[mt].[mtCompany], 
		[mt].[mtColor], 
		[mt].[mtProvenance], 
		[mt].[mtQuality], 
		[mt].[mtModel], 
		[mt].[mtType], 
		[r].[grName], 
		[r].[grLatinName], 
		[r].[stName], 
		[r].[stLatinName], 
		[mt].[mtBarCode2], 
		[mt].[mtBarCode3],
		CASE WHEN [SNT].[Item] = 0 AND [r].[BiNum] = 0 THEN 1 ELSE 0 END [IsHeader],
		[r].[FullResult]
	 FROM 
		[#Result] AS [r]  
		INNER JOIN [vwmt] AS [mt] ON [r].[biMatPtr] = [mt].[mtGUID] 
		INNER JOIN #SNGuidsTbl SN ON  [SN].[Guid] = [r].[biGuid]
		INNER JOIN [SNC000] AS [SNC]  ON  [SNC].[Guid] = [SN].[ParentGuid]  
		INNER JOIN snt000 Snt ON Snt.biGUID = [r].[biGuid] AND Snt.ParentGUID = SNC.GUID
	 ORDER BY 
		[r].[BuDate], 
		[r].[BuSortFlag], 
		[r].[BuNum], 
		[r].[BiNum],
		[SNT].[Item]
		
	DELETE [Connections] WHERE SPID = @@SPID
#########################################################
CREATE PROCEDURE ARWA.repMatSN
	-----------------Report Filters-----------------------
	@MaterialGUID 		[UNIQUEIDENTIFIER] = '272EA1A7-C9BC-4320-9DC8-C2CC4C348377' , 
	@GroupGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000' , 
	@StoreGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000' ,  --0 all stores so don't check store or list of stores 
	@MaterialCondition	VARCHAR(max) ='', 
	@JobCostGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@StartDate		DATETIME = '1/1/1980', 
	@EndDate		DATETIME = '1/1/2070', 
	@Lang					VARCHAR(100) = 'ar',		--0 Arabic, 1 Latin
	@UserGuid			[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	--Guid Of Logining User
	@Branchmask			[BIGINT]		   = -1,
	-----------------Report Sources-----------------------
	@SourcesTypes	VARCHAR(MAX) = 'A4FAD32E-4FCA-4B09-816A-D488B36B633A,2,FB256FE0-1883-4357-AD9F-8C28170D7460,2',--'6F519B68-820C-4A7C-BBDA-567A7932DB9D,2,7B11AFD4-7CD7-42F9-B09A-D15739C15411,2',
	------------------------------------------------------
	@ShowCustomer   [BIT] = 0,                  --Show [buCust_Name] OR [buCust_LatinName]	«·“»Ê‰
	@ShowStore      [BIT] = 0,                  --Show [StName] OR [StLatinName]			«·„” Êœ⁄
	@ShowPrice      [BIT] = 0				    --Show [biPrice]							«·”⁄—
AS  
	SET NOCOUNT ON
	Exec [prcSetSessionConnections] @UserGuid,@Branchmask
	DECLARE @CNT INT 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER] , [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [JobCostGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MaterialGUID, @GroupGuid,-1 ,0x0,@MaterialCondition 
	--INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @Src--'ALL' 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGuid 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@JobCostGUID 
	 
	 -------Bill Resource ---------------------------------------------------------      
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTypesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnPostedSec] [INT], [ReadPriceSecurity] [INT])       
    INSERT INTO [#BillTypesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	 ------------------------------------------------------------------------------      
	IF @JobCostGUID = 0X00 
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
	CREATE TABLE [#Result] 
	( 
		[Id]						[INT] IDENTITY(1,1), 
		[MatPtr]					[UNIQUEIDENTIFIER] , 
		[MtName]					[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[MtLatinName]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[biStorePtr]				[UNIQUEIDENTIFIER] , 
		[stName]					[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[stLatinName]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buNumber]					[UNIQUEIDENTIFIER] , 
		[biPrice]					[FLOAT], 
		[Security]					[INT], 
		[UserSecurity] 				[INT], 
		[UserReadPriceSecurity]		[INT], 
		[BillNumber]				[FLOAT], 
		[buDate]					[DATETIME], 
		[buFormatedNumber]			[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buLatinFormatedNumber]		[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buType]					[UNIQUEIDENTIFIER], 
		[buBranch]					[UNIQUEIDENTIFIER], 
		[buCust_Name]				[VARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[buCustPtr]					[UNIQUEIDENTIFIER], 
		[biCostPtr]					[UNIQUEIDENTIFIER], 
		[MatSecurity] 				[INT], 
		[biGuid]					[UNIQUEIDENTIFIER], 
		[buDirection]				[INT],
		FullResult					[INT]
	) 
	SELECT [StoreGuid], [s].[Security],[st].[Name] [stName], [st].[LatinName] [stLatinName] INTO [#StoreTbl2] FROM [#StoreTbl] AS [s] INNER JOIN  [st000] AS [st] ON  [st].[Guid] = 	[StoreGuid] 
	SELECT [MatGuid]  , [m].[mtSecurity],[mt].[Name] AS [MtName], [mt].[LatinName] AS [MtLatinName] INTO [#MatTbl2] FROM [#MatTbl] AS [m] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [MatGuid] WHERE [mt].[snFlag] = 1 
	 
	INSERT INTO [#Result] 
	( 
		[MatPtr],[MtName],[MtLatinName],[biStorePtr],[stName],[stLatinName],[buNumber],				 
		[biPrice],[Security],[UserSecurity],			 
		[UserReadPriceSecurity],[BillNumber],			 
		[buDate],[buFormatedNumber],[buLatinFormatedNumber],[buType],[buBranch],[buCust_Name],
		[buCustPtr],[biCostPtr],[MatSecurity],[biGuid],[buDirection], FullResult			 
	) 
	SELECT  
		[mtTbl].[MatGuid], 
		[mtTbl].[MtName], 
		[mtTbl].[MtLatinName],
		[bu].[biStorePtr], 
		[st].[stName], 
		[st].[stLatinName],
		[bu].[buGUID], 
		CASE WHEN [ReadPriceSecurity] >= [bu].[BuSecurity] THEN  
		([bu].[biPrice] * [biQty] + CASE [BUTOTAL] WHEN 0 THEN 0  
			ELSE ((([buTotalExtra] - [buItemsExtra]) - ([buTotalDisc] - [buItemsDisc] - buBonusDisc )* ( [biQty]*biprice/buTotal) ) +(biExtra - biBonusDisc - biDiscount)) END) / ([biBonusQnt] + [biQty]) 
			  ELSE 0 END, 
		[buSecurity], 
		[bt].[Security], 
		[bt].[ReadPriceSecurity], 
		[buNumber], 
		[buDate], 
		[buFormatedNumber],
		[buLatinFormatedNumber],
		[buType], 
		[buBranch], 
		[buCust_Name],
		[buCustPtr], 
		[biCostPtr], 
		[mtTbl].[mtSecurity],
		[biGuid],[buDirection],
		1
	FROM 
		--[SN000] AS [sn]  
		[vwBUbi] AS [bu] --ON [bu].[biGUID] = [sn].[InGuid] 
		INNER JOIN [#BillTypesTbl] AS [bt] ON [bu].[buType] = [bt].[Type] 
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bu].[biMatPtr] = [mtTbl].[MatGuid] 
		INNER JOIN [#StoreTbl2] AS [st] ON [st].[StoreGuid] = [bu].[biStorePtr] 
		INNER JOIN  [#CostTbl] AS [co] ON [co].[JobCostGUID] = [bu].[biCostPtr] 
	WHERE 
			[bu].[buIsPosted] != 0 AND 
			[buDate] BETWEEN @StartDate	AND @EndDate	 
		  
	ORDER BY 
		[MatGuid],[buDate],[buSortFlag],[buNumber] 
	---check sec 
	CREATE CLUSTERED INDEX SERIN ON #RESULT(ID,[biGuid]) 
	EXEC [prcCheckSecurity] 
	IF Exists(Select * from #SecViol)
		Update #Result SET FullResult = 0
	SELECT  MAX(CASE [buDirection] WHEN 1 THEN [Id] ELSE 0 END) AS ID ,SUM([buDirection]) AS cnt ,[sn].[ParentGuid]  
	INTO [#sn] 
	FROM [snt000] AS [sn] INNER JOIN [#Result] [r] ON [sn].[biGuid] = [r].[biGuid] GROUP BY [sn].[ParentGuid],[stGuid] HAVING SUM(buDirection) > 0 
	CREATE TABLE [#Isn2] 
	( 
		[SNID] [INT] IDENTITY(1,1), 
		[id] [INT],  
		[cnt] [INT],  
		[Guid] UNIQUEIDENTIFIER, 
		[SN] VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Length]	[INT] 
	) 
	CREATE TABLE [#Isn] 
	( 
		[SNID] [INT] , 
		[id] [INT],  
		[cnt] [INT],  
		[Guid] UNIQUEIDENTIFIER, 
		[SN] VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Length]	[INT] 
	) 
	 
	INSERT INTO [#Isn2] ([Guid],[id],[cnt],[SN],[Length]) SELECT   Guid,[ID] ,[cnt],[SN],LEN([SN])  FROM [#sn] INNER JOIN [snC000] ON [Guid] = [ParentGuid] ORDER BY SN 
	INSERT INTO  #Isn SELECT *  FROM [#Isn2] 
	IF EXISTS(SELECT * FROM [#Isn] WHERE [cnt] > 1) 
	BEGIN 
		SET @CNT = 1  
		WHILE (@CNT > 0) 
		BEGIN 
			INSERT INTO [#Isn] SELECT  SNID,MAX([R].[Id]),1,[I].[Guid]  ,[sn].[SN],[Length]  FROM [vcSNs] AS [sn]  
			INNER JOIN [#Result] [R] ON [sn].[biGuid] = [R].[biGuid]  
			INNER JOIN [#Isn] I ON [sn].[Guid] = [I].[Guid]   
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM [#Isn]) AND  [cnt] > 1 
			GROUP BY [sn].[SN],[SNID],[Length],[I].[Guid] 
			UPDATE [#Isn] SET [cnt] = [cnt] - 1 WHERE [cnt] > 1 
			SET @CNT = @@ROWCOUNT 
			 
		END 
	END 
	--- Return first Result Set -- needed data 
	SELECT 
		[SN].[SN], 
		[r].[MatPtr], 
		[r].[MtName], 
		[r].[MtLatinName], 
		[r].[biStorePtr], 
		[r].[StName], 
		[r].[StLatinName], 
		[r].[buType], 
		[r].[buNumber], 
		[r].[buCust_Name], 
		ISNULL([Cu].[LatinName], '') buCust_LatinName,
		[r].[buDate], 
		[r].[buFormatedNumber],
		[r].[buLatinFormatedNumber],
		[r].[biPrice], 
		[r].[BillNumber], 
		[r].[buBranch], 
		[r].[biCostPtr],
		[r].FullResult
	FROM 
		[#Result] AS [r] INNER JOIN [#ISN] AS [SN] ON [sn].[Id] = [r].[Id] 
		LEFT JOIN [Cu000] Cu ON Cu.GUID = [r].[buCustPtr]
	ORDER BY 
		[r].[ID], 
		[Length], 
		[SNID] 
	DELETE [Connections] WHERE SPID = @@SPID
#########################################################
CREATE PROCEDURE ARWA.repMaterialsByCustomers
	@StartDate						DATETIME,
	@EndDate						DATETIME,
	@SourcesTypes					VARCHAR(MAX),
	@AccountGUID					UNIQUEIDENTIFIER,
	@AccountDescription				VARCHAR(250),
	@GroupGUID						UNIQUEIDENTIFIER,
	@GroupDescription				VARCHAR(250),
	@StoreGUID						UNIQUEIDENTIFIER,
	@StoreDescription				VARCHAR(250),
	@UseUnit						INT,
	@IsIncludeSubStores				BIT,
	@JobCostGUID					UNIQUEIDENTIFIER,
	@JobCostDescription				VARCHAR(250),
	@IsBonusAddedToQty				BIT,
	@IsDiscountAddedToValue			BIT,
   	@InOut							INT,
	@CurrencyGUID					UNIQUEIDENTIFIER,
	@CurrencyDescription			VARCHAR(250),
	@AccountLevel					INT,
	@ProductLevel					INT,
	@CustomerGrouping				VARCHAR(128),
	@ProductGroupingField1			VARCHAR(128),
	@ProductGroupingField2			VARCHAR(128),
	@ProductGroupingField3			VARCHAR(128),
	@ShowUnit						BIT,
	@ShowPosted						BIT,
	@ShowUnposted					BIT,
	@ShowQuantity					BIT,
	@ShowGroups						BIT,
	@ShowProducts					BIT,	
	@ShowBonus						BIT,
	@ShowValues						BIT,
	--------------------------------
	-- Show Customer Fields
	--------------------------------
	@ShowCustomerNumber				BIT,
	@ShowCustomerLatinName			BIT,
	@ShowCustomerPrefix				BIT,
	@ShowCustomerSuffix				BIT,
	@ShowCustomerNationality		BIT,
	@ShowCustomerPhone1				BIT,
	@ShowCustomerPhone2				BIT,
	@ShowCustomerFax				BIT,
	@ShowCustomerTelex				BIT,
	@ShowCustomerMobile				BIT,
	@ShowCustomerPager				BIT,
	@ShowCustomerNotes				BIT,
	@ShowCustomerEmail				BIT,
	@ShowCustomerWebSite			BIT,
	@ShowCustomerDiscountPercentage	BIT,
	@ShowCustomerCountry			BIT,
	@ShowCustomerCity				BIT,
	@ShowCustomerRegion				BIT,
	@ShowCustomerStreet				BIT,
	@ShowCustomerAddress			BIT,
	@ShowCustomerZIPCode			BIT,
	@ShowCustomerPOBox				BIT,
	@ShowCustomerCertificate		BIT,
	@ShowCustomerJob				BIT,
	@ShowCustomerJobNature			BIT,
	@ShowCustomerField1				BIT,
	@ShowCustomerField2				BIT,
	@ShowCustomerField3				BIT,
	@ShowCustomerField4				BIT,
	@ShowCustomerDateOfBirth		BIT,
	@ShowCustomerGender				BIT,
	@ShowCustomerHobbies			BIT,
	-----------------------------------
	@Class							VARCHAR(256),
	@ProductConditions				VARCHAR(MAX) = '',
	@CustomerConditions				VARCHAR(MAX) = '',
	@Lang							VARCHAR(100) = 'ar', 
	@UserGUID						UNIQUEIDENTIFIER = 0X0,
	@BranchMask						BIGINT = -1
AS
	--  ﬁ—Ì— Õ—ﬂ… «·„Ê«œ Õ”» «·“»«∆‰
	SET NOCOUNT ON 

	EXEC [prcInitialize_Environment] @UserGUID, 'repMaterialsByCustomers', @BranchMask
	
	DECLARE @aSort INT
	
	CREATE TABLE [#SecViol](
		[Type] INT,
		[Cnt] INT)  
	CREATE TABLE [#Cust](
		[GUID]	UNIQUEIDENTIFIER,
		[Sec]	INT)

	INSERT INTO [#Cust] EXEC [prcGetCustsList] NULL, @AccountGUID, 0x0, @CustomerConditions
	 
	DECLARE @Types TABLE(
		[GUID]	VARCHAR(100), 
		[Type]	VARCHAR(100))

    INSERT INTO @Types SELECT * FROM [fnParseRepSources](@SourcesTypes)

	CREATE TABLE #Accounts(
		[GUID]			UNIQUEIDENTIFIER,
		[ParentGUID]	UNIQUEIDENTIFIER, 
		[CustomerGUID]	UNIQUEIDENTIFIER,
		[Level]			INT,
		[Path]			VARCHAR(8000),
		[acSecurity]	INT,
		[Code]			VARCHAR(256) COLLATE ARABIC_CI_AI,
		[Name]			VARCHAR(256) COLLATE ARABIC_CI_AI,
		[LatinName]		VARCHAR(256) COLLATE ARABIC_CI_AI,
		[NSons]			INT)
		
	INSERT INTO [#Accounts] 
	SELECT   
		[fn].[GUID],
		[ac].[acParent],
		ISNULL(cu.CustomerGUID, 0x0),
		[fn].[Level],
		[fn].[Path],
		[ac].[acSecurity],
		[ac].[acCode],
		[ac].[acName],
		[ac].[acLatinName],
		[ac].[acNSons]
	FROM   
		[dbo].[fnGetAccountsList](@AccountGUID, DEFAULT) AS [fn]
		INNER JOIN [vwac] AS [ac] ON [ac].[acGUID] = [fn].[GUID]
		LEFT JOIN 
			(SELECT  
				[cu2].[cuGUID] AS [CustomerGUID],
				[cu2].[cuAccount] AS [AccountGUID]
			FROM  
				[vwcu] AS [cu2]  
				INNER JOIN [#Cust] AS [cust] ON [cust].[GUID] = [cu2].[cuGUID]) cu ON cu.AccountGUID = [ac].[acGUID]
	WHERE	 
		[ac].[acType] = 1 
			 
	IF @CustomerConditions = ''
		DELETE [#Accounts] 
		WHERE [CustomerGUID] = 0x0 AND NSons = 0
		
	IF EXISTS(SELECT [GUID] FROM [AC000] WHERE [Type] = 4 AND [GUID] = @AccountGUID)
	BEGIN
		UPDATE [#Accounts] 
		SET [Level] = [Level] - 1 
		
		DELETE acc
		FROM #Accounts acc
		WHERE 
			[Path] = (SELECT MIN([Path]) 
						FROM #Accounts acc2 
						GROUP BY [GUID] 
						HAVING 
							COUNT(*) > 1 
							AND acc2.[GUID] = acc.[GUID])
	END 
	-----------------------------------
	-----------------------------------
	CREATE TABLE [#Materials](
		[GUID]			UNIQUEIDENTIFIER, 
		[mtSecurity]	INT)

	INSERT INTO [#Materials] EXEC [prcGetMatsList] NULL, @GroupGUID, -1, 0x0, @ProductConditions

	DECLARE @Groups TABLE(
		[GUID]	UNIQUEIDENTIFIER, 
		[Level]	INT,
		[Path]	VARCHAR(5000))
		
	INSERT INTO @Groups
	SELECT 
		[GUID],
		[Level],
		[Path]
	FROM
		[dbo].[fnGetGroupsOfGroupSorted](@GroupGUID, 0)
	-----------------------------------
	-----------------------------------
	DECLARE @Stores TABLE([GUID] UNIQUEIDENTIFIER)
	
	IF (@IsIncludeSubStores <> 0 OR ISNULL(@StoreGUID, 0x0) = 0x0) 
		INSERT INTO @Stores SELECT [GUID] FROM [fnGetStoresList](@StoreGUID) 
	ELSE 
		INSERT INTO @Stores SELECT @StoreGUID 

	DECLARE @Costs TABLE([GUID] UNIQUEIDENTIFIER)
	
	INSERT INTO @Costs SELECT [GUID] FROM [fnGetCostsList](@JobCostGUID) 
	IF @JobCostGUID = 0x0  
		INSERT INTO @Costs VALUES(0x0)
	-----------------------------------
	-----------------------------------
	CREATE TABLE [#Result](	
		[AccountGUID]		UNIQUEIDENTIFIER, 
		[MaterialGUID]		UNIQUEIDENTIFIER, 
		[GroupGUID]			UNIQUEIDENTIFIER, 
		[Quantity]			FLOAT,
		[Bonus]				FLOAT,
		[VAL]				FLOAT,
		[mtSecurity]		INT, 
		[AccSecurity]		INT, 
		[Security]			INT, 
		[UserSecurity]		INT)

	INSERT INTO [#Result]
	SELECT
		[ac].[GUID],
		[B].[biMatPtr], 
		[B].[mtGroup], 
		[B].Qty, 
		[B].Bonus, 
		[B].[Val], 
		[B].[mtSecurity], 
		ISNULL([acSecurity], 0), 
		[B].[buSecurity], 
		ASec 
	FROM 
		(SELECT 
			CASE [Bill].[BuCustPtr] 
				WHEN 0x0 THEN [Bill].[BuCustAcc] 
				ELSE [cu].[cuAccount]
			END AS cuAcc, 
			[Bill].[biMatPtr], 
			[Bill].[mtGroup], 
			SUM(CASE @UseUnit 
				WHEN 0 THEN ([biQty] + [biBonusQnt] * @IsBonusAddedToQty) * @ShowQuantity 
				WHEN 1 THEN ([biQty2] + [biBonusQnt] * @IsBonusAddedToQty/CASE WHEN [Bill].[mtUnit2Fact] = 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END) * @ShowQuantity 
				WHEN 2 THEN ([biQty3] + [biBonusQnt] * @IsBonusAddedToQty/CASE WHEN [Bill].[mtUnit3Fact] = 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END) * @ShowQuantity 
				WHEN 3 THEN ([biQty] + [biBonusQnt] * @IsBonusAddedToQty) * @ShowQuantity/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END 
				END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END) as Qty, 
			SUM([biBonusQnt] * @ShowBonus  
				* CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				/ CASE @UseUnit 
					WHEN 0 THEN 1 
					WHEN 1 THEN CASE WHEN [Bill].[mtUnit2Fact] = 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END 
					WHEN 2 THEN CASE WHEN [Bill].[mtUnit3Fact] = 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END   
					ELSE CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END  
				END) AS Bonus, 
			SUM(@ShowValues * CASE @IsDiscountAddedToValue  
					WHEN 0 THEN [biBillQty] * CASE WHEN [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [Src].[GUID]) >= [BuSecurity] THEN  [FixedBiPrice] ELSE 0 END  
						ELSE  
							CASE WHEN [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [Src].[GUID]) >= [BuSecurity] THEN [FixedbiTotal] ELSE 0 END 
						END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection])  
					END) [Val], 
			[Bill].[mtSecurity], 
			 
			[Bill].[buSecurity], 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [dbo].[fnGetUserBillSec_Browse](@UserGUID, [Src].[GUID]) ELSE [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGUID, [Src].[GUID]) END AS ASec 
		FROM 
			( [dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [bill] 
			INNER JOIN @Types AS [Src] ON [Bill].[buType] = [Src].[GUID]			
			INNER JOIN [#Materials] AS [mt] ON [Bill].[biMatPtr] = [mt].[GUID]  
			INNER JOIN @Costs AS [Co] ON [Bill].[BiCostPtr] = [Co].[GUID]  
			INNER JOIN @Stores AS [St] ON [Bill].[BiStorePtr] = [St].[GUID]  
			LEFT JOIN [vwcu] AS [cu] ON [cu].[cuGUID] = [Bill].[BuCustPtr]) 
		WHERE 
			[Bill].[buDate] between @StartDate AND @EndDate
			AND (@Class = '' OR @Class = [Bill].[biClassPtr])
			AND (((@ShowPosted = 1) AND ([Bill].[buIsPosted] = 1)) OR ((@ShowUnposted = 1) AND ([Bill].[buIsPosted] = 0)))
		GROUP BY 
			CASE [Bill].[BuCustPtr] WHEN 0x0 THEN [Bill].[BuCustAcc] ELSE [cu].cuAccount END, 
			[Bill].[biMatPtr], 
			[Bill].[mtGroup], 
			[Bill].[mtSecurity], 
			[Bill].[buSecurity], 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [dbo].[fnGetUserBillSec_Browse](@UserGUID, [Src].[GUID]) ELSE [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGUID, [Src].[GUID]) END) as [B] 
		RIGHT JOIN #Accounts AS ac ON cuAcc = ac.[GUID]
	-----------------------------------
	-----------------------------------
	
	EXEC [prcCheckSecurity] @UserGUID = @UserGUID
	
	DECLARE @NumOfSecViolated BIT = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
		
	-----------------------------------
	-----------------------------------
	CREATE TABLE #ResultTbl(  
		[AccountGUID]		UNIQUEIDENTIFIER,
		[AccountParentGUID]	UNIQUEIDENTIFIER,
		[AccountLevel]		INT,
		[MaterialGUID]		UNIQUEIDENTIFIER,
		[CustomerGUID]		UNIQUEIDENTIFIER,  
		[GroupGUID]			UNIQUEIDENTIFIER,
		[GroupLevel]		INT,  
		[Quantity]			FLOAT,  
		[Bonus]				FLOAT,  
		[Val]				FLOAT)
	-----------------------------------
	-----------------------------------
	INSERT INTO #ResultTbl
	SELECT
		[res].[AccountGUID],
		[ac].[ParentGUID],
		[ac].[Level],
		[res].[MaterialGUID],
		[ac].CustomerGUID,
		[res].[GroupGUID],
		[gr].[Level],
		SUM([res].[Quantity]),
		SUM([res].[Bonus]),
		SUM([res].[VAL])
	FROM  
		[#Result] AS [res]  
		INNER JOIN @Groups [gr] ON [gr].[GUID] = [res].[GroupGUID] 
		INNER JOIN #Accounts [ac] ON [ac].[GUID] = [res].[AccountGUID] 
	GROUP BY  
		[res].[AccountGUID],
		[res].[MaterialGUID],  
		[ac].[CustomerGUID],
		[res].[GroupGUID],
		[ac].[Level],
		[gr].[Level],
		[ac].[ParentGUID]

		
	INSERT INTO #ResultTbl(
		AccountGUID,
		Quantity,
		Bonus,	
		Val)
		SELECT 
			res.AccountParentGUID,
			SUM(res.Quantity),
			SUM(res.Bonus),
			SUM(res.Val)
		FROM
			#ResultTbl res
			INNER JOIN ac000 ac ON ac.GUID = res.AccountGUID
		WHERE
			res.AccountParentGUID <> 0x0
		GROUP BY
			res.AccountParentGUID
	-----------------------------------
	-----------------------------------
	SELECT 
		ISNULL([mt].[mtGUID], 0x0) AS [MaterialGUID],
		ISNULL([mt].[mtCode], '') AS [MaterialCode],
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [mt].[mtName]
			ELSE CASE [mt].[mtLatinName]
					WHEN '' THEN [mt].[mtName]
					ELSE [mt].[mtLatinName]
				END
		END, '') AS [MaterialName],
		ISNULL([mt].[mtLatinName], '') AS [MaterialLatinName], --for grouping options
		ISNULL([mt].[mtDim], '') AS [mtDim],							-- 1
		ISNULL([mt].[mtPos], '') AS [mtPos],							-- 2
		ISNULL([mt].[mtOrigin], '') AS [mtOrigin],						-- 3
		ISNULL([mt].[mtCompany], '') AS [mtCompany],					-- 4
		ISNULL([mt].[mtColor], '') AS [mtColor],						-- 5
		ISNULL([mt].[mtModel], '') AS [mtModel],						-- 6
		ISNULL([mt].[mtQuality], '') AS [mtQuality],					-- 7
		ISNULL([mt].[mtProvenance], '') AS [mtProvenance],				-- 8
		-- [mt].[mtName],						-- 9
		-- [mt].[mtLatinName],					-- 10
		-- [mt].[mtGroupGUID],					-- 11
		ISNULL(CASE @UseUnit
			WHEN 0 THEN [Mt].[mtUnity] 
			WHEN 1 THEN [Mt].[mtUnit2] 
			WHEN 2 THEN [Mt].[mtUnit3] 
			WHEN 3 THEN [Mt].[mtDefUnitName]
		END, '') AS [MaterialUnit],

		ISNULL([gr].[grGUID], 0x0) AS [GroupGUID],
		ISNULL([gr].[grCode], '') AS [GroupCode],
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [gr].[grName]
			ELSE CASE [gr].[grLatinName]
					WHEN '' THEN [gr].[grName]
					ELSE [gr].[grLatinName]
				END
		END, '') AS [GroupName],
		
		ISNULL([ac].[acGUID], 0x0) AS [AccountGUID],
		ISNULL([ac].[acCode], '') AS [AccountCode],
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [ac].[acName]
			ELSE CASE [ac].[acLatinName]
					WHEN '' THEN [ac].[acName]
					ELSE [ac].[acLatinName]
				END
		END, '') AS [AccountName],
		
		ISNULL([acParent].[acGUID], 0x0) AS [AccountParentGUID],
		ISNULL([acParent].[acCode], '') AS [AccountParentCode],
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [acParent].[acName]
			ELSE CASE [acParent].[acLatinName]
					WHEN '' THEN [acParent].[acName]
					ELSE [acParent].[acLatinName]
				END
		END, '') AS [AccountParentName],
		
		ISNULL([Cu].[cuGUID], 0x0) AS [CustomerGUID],
		ISNULL([Cu].[cuNumber], 0) AS [CustomerNum],
		ISNULL([Cu].[cuCustomerName], '') AS [CustomerName],
		ISNULL([Cu].[cuLatinName], '') AS [CustomerLatinName],
		ISNULL([Cu].[cuNationality], '') AS [CustomerNationality],
		ISNULL([Cu].[cuAddress], '') AS [CustomerAddress],
		ISNULL([Cu].[cuPhone1], '') AS [CustomerPhone1],
		ISNULL([Cu].[cuPhone2], '') AS [CustomerPhone2],
		ISNULL([Cu].[cuFax], '') AS [CustomerFax],
		ISNULL([Cu].[cuTelex], '') AS [CustomerTelex],
		ISNULL([Cu].[cuNotes], '') AS [CustomerNotes],
		ISNULL([Cu].[cuDiscRatio],0) AS [CustomerDiscRatio],
		ISNULL([Cu].[cuPrefix], '') AS [CustomerPrefix],
		ISNULL([Cu].[cuSuffix], '') AS [CustomerSuffix],
		ISNULL([Cu].[cuMobile], '') AS [CustomerMobile],
		ISNULL([Cu].[cuPager], '') AS [CustomerPager],
		ISNULL([Cu].[cuEmail], '') AS [CustomerEmail],
		ISNULL([Cu].[cuHomePage], '') AS [CustomerHomePage],
		ISNULL([Cu].[cuCountry], '') AS [CustomerCountry],
		ISNULL([Cu].[cuCity], '') AS [CustomerCity],
		ISNULL([Cu].[cuArea], '') AS [CustomerArea],
		ISNULL([Cu].[cuStreet], '') AS [CustomerStreet],
		ISNULL([Cu].[cuZipCode], '') AS [CustomerZipCode],
		ISNULL([Cu].[cuPOBox], '') AS [CustomerPOBox],
		ISNULL([Cu].[cuCertificate], '') AS [CustomerCertificate],
		ISNULL([Cu].[cuJob], '') AS [CustomerJob],
		ISNULL([Cu].[cuJobCategory], '') AS [CustomerJobCategory],
		ISNULL([Cu].[cuUserFld1], '') AS [CustomerUserFld1],
		ISNULL([Cu].[cuUserFld2], '') AS [CustomerUserFld2],
		ISNULL([Cu].[cuUserFld3], '') AS [CustomerUserFld3],
		ISNULL([Cu].[cuUserFld4], '') AS [CustomerUserFld4],
		ISNULL([Cu].[cuDateOfBirth], '') AS [CustomerDateOfBirth],
		ISNULL([Cu].[cuGender], '') AS [CustomerGender],
		ISNULL([Cu].[cuHobbies], '') AS [CustomerHobbies],

		ISNULL(res.[Quantity], 0) AS Quantity,
		ISNULL(res.[Bonus], 0) AS Bonus,
		ISNULL(res.[Val], 0) AS Val,
		@NumOfSecViolated AS PartialResult
	FROM 
		#ResultTbl res
		LEFT JOIN vwmt [mt] ON [mt].[mtGUID] = res.MaterialGUID
		LEFT JOIN vwgr [gr] ON [gr].[grGUID] = res.GroupGUID 
		LEFT JOIN vwac [ac] ON [ac].[acGUID] = res.AccountGUID
		LEFT JOIN vwac [acParent] ON [acParent].[acGUID] = res.AccountParentGUID
		LEFT JOIN vwcu [cu] ON [cu].[cuGUID] = res.CustomerGUID
	WHERE
		(@AccountLevel = 0 OR res.AccountLevel < @AccountLevel)
		AND ((@ProductLevel = 0) OR (res.GroupLevel + 1 <  @ProductLevel))

	EXEC [prcFinilize_Environment] 'repMaterialsByCustomers'
#########################################################
CREATE PROCEDURE ARWA.repMaterialMove
	@ProductGUID 				UNIQUEIDENTIFIER,
	@ProductDescription			VARCHAR(250),
	@GroupGUID					UNIQUEIDENTIFIER,
	@GroupDescription			VARCHAR(250),
	@StartDate 					DATETIME,
	@EndDate 					DATETIME,
	@CustomersConditions		VARCHAR(MAX) = '',
	@ProductConditions			VARCHAR(MAX) = '',
	@StoreGUID 					UNIQUEIDENTIFIER,
	@StoreDescription			VARCHAR(250),
	@JobCostGUID 				UNIQUEIDENTIFIER,
	@JobCostDescription			VARCHAR(250),
	@SelectedUserGUID			UNIQUEIDENTIFIER = 0x0,
	@CurrencyGUID				UNIQUEIDENTIFIER = 0x0,
	@CurrencyDescription		VARCHAR(250),
	@IsExtended					BIT,
	@ShowPosted					BIT,
	@ShowUnposted				BIT,
	@ShowNotes					BIT,
	@ShowBillRowNotes			BIT,
	@ShowStore					BIT,
	@ShowVendor					BIT,
	@ShowSalesMan				BIT,
	@ShowCustomer				BIT,
	@ShowTotalPrice				BIT,
	@ShowBonus					BIT,
	@ShowJobCost				BIT,
	@ShowRowDiscountRate		BIT,
	@ShowRowDiscountValue		BIT,
	@ShowBonusDiscount			BIT,
	@ShowRowExtraRate			BIT,
	@ShowRowExtraValue			BIT,
	@ShowWidthAndHeight			BIT,
	@ShowLength					BIT,
	@ShowCount					BIT,
	@ShowExpireDate				BIT,
	@ShowProductionDate			BIT,
	@ShowClass					BIT,
	@ShowPartialTotal			BIT,
	@ShowBranch					BIT,
	@ShowEachProductOnPage		BIT,
	@ShowUnLinkedUnits			BIT,
	-----Material Fields-----
	@ShowProductBarcode			BIT,
	@ShowProductType			BIT,
	@ShowProductSpecification	BIT,
	@ShowProductSize			BIT,
	@ShowProductSource			BIT,
	@ShowProductLocation		BIT,
	@ShowProductCompany			BIT,
	@ShowProductColor			BIT,
	@ShowProductProvenance		BIT,
	@ShowProductQuality			BIT,
	@ShowProductGroup			BIT,
	@ShowProductModel			BIT,
	-------------------------
	@NotesContain 				VARCHAR(256),
	@NotesNotContain 			VARCHAR(256),
	@ProductGroup1				VARCHAR(256),
	@ProductGroup2				VARCHAR(256),
	@ProductGroup3				VARCHAR(256),
	@UseUnit					INT = 0,
	@Class						VARCHAR(256) = '',
	@PriceType					INT = 2,
	@PricePolicy				INT = 121,
	@SourcesTypes				VARCHAR(MAX),
	@Lang						VARCHAR(100) = 'ar',
	@UserGUID					UNIQUEIDENTIFIER = 0X0,
	@BranchMask					BIGINT =	-1
AS
	SET NOCOUNT ON
	
	EXEC [prcInitialize_Environment] @UserGUID, 'repMaterialMove', @BranchMask

	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT)
	CREATE TABLE [#BillsTypesTbl]([TypeGuid] UNIQUEIDENTIFIER, [UserSecurity] INT, [UserReadPriceSecurity] INT, [UnPostedSecurity] INT)
	CREATE TABLE [#StoreTbl]([StoreGuid] UNIQUEIDENTIFIER, [Security] INT)
	CREATE TABLE [#CostTbl]([CostGuid] UNIQUEIDENTIFIER, [Security] INT, [Name] VARCHAR(256) COLLATE ARABIC_CI_AI)
	CREATE TABLE [#CustTbl]([CustGuid] UNIQUEIDENTIFIER, [Security] INT)
	CREATE TABLE [#MatTbl]([MatGUID] UNIQUEIDENTIFIER, [mtSecurity] INT)
	
	DECLARE @Types TABLE(
		[GUID]	VARCHAR(100),
		[Type]	VARCHAR(100))

    INSERT INTO @Types SELECT * FROM [fnParseRepSources](@SourcesTypes)
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] @ProductGUID, @GroupGUID, -1, 0x0, @ProductConditions
	INSERT INTO [#StoreTbl] EXEC [prcGetStoresList] @StoreGUID
	INSERT INTO [#CostTbl]([CostGuid], [Security]) EXEC [prcGetCostsList] @JobCostGUID
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] NULL, NULL, 0x0, @CustomersConditions
	IF (@CustomersConditions = '')
		INSERT INTO [#CustTbl] VALUES(0x0, 0)
		
	INSERT INTO [#BillsTypesTbl]
	SELECT
		[bt].btGUID,
		[dbo].[fnGetUserBillSec_Browse](@UserGUID, [bt].btGUID),
		[dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [bt].btGUID),
		[dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGUID, [bt].btGUID)
	FROM
		[vwBt] [bt]
		INNER JOIN @Types t ON t.[GUID] = CAST([bt].btGUID AS VARCHAR(100))
		
	IF (ISNULL(@JobCostGUID, 0x0) = 0x0)
		INSERT INTO [#CostTbl] VALUES (0x0, 0, '')
	
	IF @NotesContain IS NULL
		SET @NotesContain = ''
	IF @NotesNotContain IS NULL
		SET @NotesNotContain = ''
		
	DECLARE @PostedValue INT = -1
	IF @ShowPosted = 1 AND @ShowUnposted = 0
		SET @PostedValue = 1
	IF @ShowPosted = 0 AND @ShowUnposted = 1
		SET @PostedValue = 0
		
	DECLARE @CanShowProfits BIT=0
	SELECT @CanShowProfits=Count(typ.GUID) FROM bt000 AS bt
		INNER JOIN @Types AS typ ON typ.GUID=bt.GUID
	WHERE bt.Type=2 AND bt.SortNum=2 --»÷«⁄… ¬Œ— «·„œ…
	
	CREATE TABLE #QTYS(
		[Qty]		FLOAT,
		[Bonus]		FLOAT,
		[Price]		FLOAT,
		[MatGUID]	UNIQUEIDENTIFIER,
		[stGUID]	UNIQUEIDENTIFIER)
		
	CREATE TABLE [#EndResult]( 
		[ID]					INT IDENTITY(1,1),
		[MaterialGUID]			UNIQUEIDENTIFIER DEFAULT 0x0,
		[MaterialCode]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialName]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[GroupGUID]				UNIQUEIDENTIFIER DEFAULT 0x0,
		[GroupCode]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[GroupName]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[BillType]				INT DEFAULT -1,
		[BillTypeGUID]			UNIQUEIDENTIFIER DEFAULT 0x0,
		[BillGUID]				UNIQUEIDENTIFIER DEFAULT 0x0,
		[BillIsPosted]			INT DEFAULT -1,
		[BillCostGUID]			UNIQUEIDENTIFIER DEFAULT 0x0,
		[Security]				INT DEFAULT 1,
		[buDate]				DATETIME DEFAULT '1/1/1980',
		[buNotes]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[buVendor]				INT DEFAULT 0,
		[buSalesMan]			INT DEFAULT 0,
		[CustomerName]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[buTotal]				FLOAT DEFAULT 0,
		[buTotalDisc]			FLOAT DEFAULT 0,
		[buTotalExtra]			FLOAT DEFAULT 0,
		[buItemsDisc]			FLOAT DEFAULT 0,
		[buBonusDisc]			FLOAT DEFAULT 0,
		[buDirection]			INT  DEFAULT 0,
		[biGuid]				UNIQUEIDENTIFIER DEFAULT 0x0,
		[biStoreGUID]			UNIQUEIDENTIFIER DEFAULT 0x0,
		[biNotes]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[biPrice]				FLOAT DEFAULT 0,
		[biUnitPrice]			FLOAT DEFAULT 0,
		[MaxPrice]				FLOAT DEFAULT 0,
		[MinPrice]				FLOAT DEFAULT 0,
		[BalancePrice]			FLOAT DEFAULT 0,
		[biBillQty]				FLOAT DEFAULT 0,
		[biBillBonusQnt]		FLOAT DEFAULT 0,
		[biQty]					FLOAT DEFAULT 0,
		[biCalculatedQty2]		FLOAT DEFAULT 0,
		[biCalculatedQty3]		FLOAT DEFAULT 0,
		[BalanceQty]			FLOAT DEFAULT 0,
		[BalanceQty2]			FLOAT DEFAULT 0,
		[BalanceQty3]			FLOAT DEFAULT 0,
		[biBonusQnt]			FLOAT DEFAULT 0,
		[biUnity]				INT DEFAULT -1,
		[biDiscount]			FLOAT DEFAULT 0,
		[biDiscountRate]		FLOAT DEFAULT 0,
		[biBonusDisc]			FLOAT DEFAULT 0,
		[biExtra]				FLOAT DEFAULT 0,
		[biExtraRate]			FLOAT DEFAULT 0,
		[biProfits]				FLOAT DEFAULT 0,
		[MtUnit]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MtUnit2]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MtUnit3]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[UserSecurity]			INT DEFAULT 1,
		[UserReadPriceSecurity]	INT DEFAULT 1,
		[MtSecurity]			INT DEFAULT 1,
		[buFormatedNumber]		VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[CostCode]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[CostName]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[ExpireDate]			DATETIME DEFAULT '1/1/1980',
		[ProductionDate]		DATETIME DEFAULT '1/1/1980',
		[Length]				FLOAT DEFAULT 0,
		[Width]					FLOAT DEFAULT 0,
		[Height]				FLOAT DEFAULT 0,
		[Count]					FLOAT DEFAULT 0,
		[Class]					VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialBarCode]		VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialType]			INT DEFAULT -1,
		[MaterialSpecification]	VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialDim]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialOrigin]		VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialPos]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialCompany]		VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialColor]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialProvenance]	VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialQuality]		VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[MaterialModel]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[Fact]					FLOAT DEFAULT 0,
		[stName]				VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[BranchGUID]			UNIQUEIDENTIFIER DEFAULT 0x0,
		[BranchName]			VARCHAR(256) COLLATE ARABIC_CI_AI DEFAULT '',
		[biVat]					FLOAT DEFAULT 0,
		[btAffectCostPrice]		BIT DEFAULT 0,
		[btExtraAffectCost]		BIT DEFAULT 0,
		[btExtraAffectProfit]	BIT DEFAULT 0,
		[btDiscAffectCost]		BIT DEFAULT 0,
		[btDiscAffectProfit]	BIT DEFAULT 0,
		[btIsInput]				BIT DEFAULT 0,
		[btIsOutput]			BIT DEFAULT 0,
		[TotalItemPrice]		FLOAT DEFAULT 0,
		[TotalDisc]				FLOAT DEFAULT 0,
		[TotalExtra]			FLOAT DEFAULT 0,
		[biNoUnitQty]			FLOAT DEFAULT 0,
		[CanShowProfits]		BIT DEFAULT 0)

	DECLARE @DivideDiscount BIT
	SELECT @DivideDiscount =  Value from op000 WHERE Name = 'AmnCfg_DivideDiscount' AND OwnerGUID = @UserGUID
	
	INSERT INTO [#EndResult]
	SELECT
		ISNULL([r].biMatPtr, 0x0),
		ISNULL(mtGr.mtCode, ''),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN mtGr.mtName
			ELSE CASE mtGr.mtLatinName
					WHEN '' THEN mtGr.mtName
					ELSE mtGr.mtLatinName
				END
		END, '')
		,
		ISNULL(mtGr.grGUID, 0x0),
		ISNULL(mtGr.grCode, ''),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN mtGr.grName
			ELSE CASE mtGr.grLatinName
					WHEN '' THEN mtGr.grName
					ELSE mtGr.grLatinName
				END
		END, '')
		,
		ISNULL([r].btBillType, -1),
		ISNULL([r].[buType], 0x0),
		ISNULL([r].[buGUID], 0x0),
		[r].[buIsPosted],
		ISNULL([r].[buCostPtr], 0x0),
		[r].[buSecurity],
		ISNULL([r].[buDate], '1/1/1980'),
		ISNULL([r].[buNotes], ''),
		ISNULL([r].[buVendor], 0),
		ISNULL([r].[buSalesManPtr], 0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN cu.cuCustomerName
			ELSE CASE cu.cuLatinName
					WHEN '' THEN cu.cuCustomerName
					ELSE cu.cuLatinName
				END
		END, ''),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotal] ELSE 0 END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalDisc] ELSE 0 END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buTotalExtra] - [r].[buItemsExtra] ELSE 0 END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buItemsDisc] ELSE 0 END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[buBonusDisc] ELSE 0 END, 0),
		[r].buDirection,
		ISNULL([r].biGUID, 0x0),
		ISNULL([r].[biStorePtr], 0x0),
		ISNULL([r].[biNotes], ''),
		ISNULL(CASE 
			WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END) * (CASE @UseUnit WHEN 0 THEN 1 WHEN 1 THEN [r].mtUnit2Fact WHEN 2 THEN [r].mtUnit3Fact WHEN 3 THEN [r].mtDefUnitFact END) - ( ( CASE [r].[biPrice] WHEN 0 THEN 1 ELSE [r].[biPrice] END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END) * (CASE @UseUnit WHEN 0 THEN 1 WHEN 1 THEN [r].mtUnit2Fact WHEN 2 THEN [r].mtUnit3Fact WHEN 3 THEN [r].mtDefUnitFact END) * ((CASE @DivideDiscount WHEN 0 THEN ((biDiscount / (( ( CASE [r].[biPrice] WHEN 0 THEN 1 ELSE [r].[biPrice] END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [r].[biUnity]  WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END)) * biQty)) * 100) ELSE (biDiscount * 100) / (((CASE biPrice WHEN 0 THEN 1 ELSE biPrice END)* [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [r].[biUnity]  WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END))  - biDiscount) END) / 100))
			ELSE 0 
		END, 0),
		ISNULL(CASE
			WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END)
		END, 0),
		0,
		0,
		0,
		ISNULL([r].[biBillQty], 0),
		ISNULL([r].[biBillBonusQnt], 0),
		ISNULL([r].[biQty] / (CASE @UseUnit WHEN 0 THEN 1 WHEN 1 THEN [r].mtUnit2Fact WHEN 2 THEN [r].mtUnit3Fact WHEN 3 THEN [r].mtDefUnitFact END), 0),
		ISNULL([r].[biCalculatedQty2], 0),
		ISNULL([r].[biCalculatedQty3], 0),
		0,
		0,
		0,
		ISNULL(([r].[biBonusQnt] / (CASE [r].biUnity WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END)), 0),
		ISNULL([r].[biUnity], 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biDiscount]  ELSE 0 END, 0),
		ISNULL(CASE @DivideDiscount
			WHEN 0 THEN ((biDiscount / (( (CASE biPrice WHEN 0 THEN 1 ELSE biPrice END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [r].[biUnity]  WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END)) * biQty)) * 100)
			ELSE (biDiscount * 100) / (( (CASE biPrice WHEN 0 THEN 1 ELSE biPrice END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [r].[biUnity]  WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END))  - biDiscount)
		END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biBonusDisc] ELSE 0 END, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biExtra] ELSE 0 END, 0),
		ISNULL(([r].[biExtra] / (( (CASE biPrice WHEN 0 THEN 1 ELSE biPrice END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [r].[biUnity]  WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END)) * biQty)) * 100, 0),
		ISNULL(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biProfits] ELSE 0 END, 0),
		ISNULL([r].MtUnity, ''),
		ISNULL([r].[MtUnit2], ''),
		ISNULL([r].[MtUnit3], ''),
		CASE [r].[buIsPosted]
			WHEN 1 THEN [UserSecurity]
			ELSE [UnPostedSecurity]
		END,
		[bt].[UserReadPriceSecurity],
		[r].[mtsecurity],
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [r].[buFormatedNumber]
			ELSE CASE [r].[buLatinFormatedNumber]
					WHEN '' THEN [r].[buFormatedNumber]
					ELSE [r].[buLatinFormatedNumber]
				END								
		END, ''),
		ISNULL([vwCo].coCode, ''),
		ISNULL(CASE @Lang 
			WHEN 'ar' THEN [vwCo].coName
			ELSE CASE [vwCo].coLatinName
					WHEN '' THEN [vwCo].coName
					ELSE [vwCo].coLatinName
				END
		END, ''),
		ISNULL([r].[biExpireDate], '1/1/1980'),
		ISNULL([r].[biProductionDate], '1/1/1980'),
		ISNULL([r].[biLength], 0),
		ISNULL([r].[biWidth], 0),
		ISNULL([r].[biHeight], 0),
		ISNULL([r].[biCount], 0),
		ISNULL([r].[biClassPtr], ''),
		ISNULL(mtGr.[mtBarCode], ''),
		ISNULL(mtGr.[mtType], -1),
		ISNULL(mtGr.[mtSpec], ''),
		ISNULL(mtGr.[mtDim], ''),
		ISNULL(mtGr.[mtOrigin], ''),
		ISNULL(mtGr.[mtPos], ''),
		ISNULL(mtGr.[mtCompany], ''),
		ISNULL(mtGr.[mtColor], ''),
		ISNULL(mtGr.[mtProvenance], ''),
		ISNULL(mtGr.[mtQuality], ''),
		ISNULL(mtGr.[mtModel], ''),
		ISNULL([dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [buDate]), 0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [vwst].[stName]
			ELSE CASE [vwst].[stLatinName]
					WHEN '' THEN [vwst].[stName]
					ELSE [vwst].[stLatinName]
				END								
		END, ''),
		ISNULL([r].[buBranch], 0x0),
		ISNULL(CASE @Lang
			WHEN 'ar' THEN [br].[brName]
			ELSE CASE [br].[brLatinName]
					WHEN '' THEN [br].[brName]
					ELSE [br].[brLatinName]
				END
		END, ''),
		CASE btVATSystem
			WHEN 2 THEN biVat
			ELSE 0
		END,	
		btAffectCostPrice,
		btExtraAffectCost,
		btExtraAffectProfit,
		btDiscAffectCost,
		btDiscAffectProfit,
		btIsInput,
		btIsOutput,
		ISNULL([r].[biPrice] * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END) * [r].biQty, 0),
		ISNULL(CASE WHEN [r].buTotal * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) <> 0 THEN ([r].buItemsDisc + ([r].buTotalDisc - ([r].buItemsDisc + [r].buBonusDisc))) * ( (CASE biPrice WHEN 0 THEN 1 ELSE biPrice END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END) * [r].biQty) / (CASE [r].buTotal WHEN 0 THEN 1 ELSE [r].buTotal END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) ELSE [r].buTotalDisc - ([r].buItemsDisc + [r].buBonusDisc) END, 0),
		ISNULL(
			CASE 
				WHEN ([r].buTotal * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate])) <> 0
					THEN ([r].biExtra + [r].buTotalExtra) * ([r].[biPrice] * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) / (CASE [biUnity] WHEN 2 THEN [r].mtUnit2Fact WHEN 3 THEN [r].mtUnit3Fact ELSE 1 END) * [r].biQty) / CASE ( (CASE [r].buTotal  WHEN 0 THEN 1 ELSE [r].buTotal END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate])) WHEN 0 THEN 1 ELSE (CASE [r].buTotal  WHEN 0 THEN 1 ELSE [r].buTotal END) * [dbo].[fnCurrency_fix](1, [r].[biCurrencyPtr], [r].[biCurrencyVal], @CurrencyGUID, [r].[buDate]) END 
					ELSE [r].buTotalExtra
				END,
			 0),
		ISNULL([r].biQty, 0),
		@CanShowProfits
	FROM
		((([dbo].[vwExtended_bi] AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid])
		INNER JOIN [#MatTbl] AS [mt]ON [mt].[MatGUID] = [r].[biMatPtr])
		INNER JOIN [vwmtgr] AS mtGr ON mtGr.mtGUID = mt.MatGUID
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [BiCostPtr])
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [BiStorePtr]
		INNER JOIN [vwst] ON vwSt.stGUID = st.StoreGuid
		LEFT JOIN [#CustTbl] AS [c] ON [c].[CustGuid] = [r].[buCustPtr]
		LEFT JOIN [vwcu] AS [cu] ON [cu].cuGUID = c.CustGuid
		LEFT JOIN [vwCo] ON [vwCo].coGUID = [co].[CostGUID]
		LEFT JOIN [vwBr] [br] ON [br].[brGuid] = [r].[buBranch]
	WHERE
		[budate] BETWEEN @StartDate AND @EndDate
		AND( (@PostedValue = -1) OR ([BuIsPosted] = @PostedValue))
		AND (@ProductGUID = 0x0 OR [BiMatPtr] = @ProductGUID)
		AND ((@NotesContain = '') OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ([BiNotes] LIKE '%' + @NotesContain + '%'))
		AND ((@NotesNotContain = '') OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([BiNotes] NOT LIKE '%'+ @NotesNotContain + '%')))
		AND (@Class = '' OR @Class = [biClassPtr])
		AND (@SelectedUserGUID = 0x0 OR @SelectedUserGUID = [buUserGUID])
		
	DECLARE @CurrencyVal FLOAT
	SELECT @CurrencyVal = [dbo].[fnGetCurVal](@CurrencyGUID, GETDATE())
	
	DECLARE @Type UNIQUEIDENTIFIER, @SortNum INT
	SELECT @Type = t.[GUID], @SortNum = bt.SortNum
	FROM
		@Types [t]
		INNER JOIN [bt000] bt ON t.[GUID] = bt.[GUID]
		AND bt.[Type] = 2
		AND [SortNum] = 2
	IF @Type IS NOT NULL
	BEGIN
		EXEC prcCalcEPBill @StartDate, @EndDate, @CurrencyGUID, @JobCostGUID, @StoreGuid, @PriceType, @PricePolicy, @PostedValue, @CurrencyVal, @UseUnit
	
		INSERT INTO [#EndResult](
			[MaterialGUID],
			[MaterialCode],
			[MaterialName],
			[BillTypeGUID],
			[Security],
			[buDate],
			[biPrice],
			[biUnitPrice],
			[biProfits])
		SELECT
			[MatGUID],
			Code,
			CASE @Lang
				WHEN 'ar' THEN Name
				ELSE CASE LatinName
						WHEN '' THEN Name
						ELSE LatinName
					END
			END,
			@Type,
			0,
			@EndDate,
			SUM([Price] * (a.qty + a.[Bonus])),
			SUM([Price] * (a.qty + a.[Bonus])),
			0
		FROM
			#QTYS a
			INNER JOIN mt000 b on b.Guid = a.[MatGUID]
		WHERE
			@ProductGUID = 0x0 OR a.MatGUID = @ProductGUID
			GROUP BY
				[MatGUID],
				Code,
				CASE @Lang
				WHEN 'ar' THEN Name
				ELSE CASE LatinName
						WHEN '' THEN Name
						ELSE LatinName
					END
			END
	END
	
	EXEC [prcCheckSecurity] @Result = '#EndResult', @UserGUID = @UserGUID
	
	DECLARE @NumOfSecViolated BIT = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
	
	UPDATE res
	SET res.MaxPrice = res2.MaxPrice,
		res.MinPrice = res2.MinPrice
	FROM 
		#EndResult res
		INNER JOIN (SELECT MaterialGUID, MAX(biPrice) AS MaxPrice, MIN(biPrice) AS MinPrice FROM #EndResult WHERE btIsInput = 1 GROUP BY MaterialGUID) AS res2 ON res.MaterialGUID = res2.MaterialGUID
	WHERE res.btIsInput = 1
	
	UPDATE res
			SET 
			res.biProfits = (CASE WHEN BillTypeGUID = @Type THEN biUnitPrice ELSE (CASE btIsInput WHEN 1 THEN -1 ELSE 1 END * (biUnitPrice * biQty)) END),
			res.biPrice = (res.TotalItemPrice - (CASE WHEN res.btDiscAffectCost = 1 OR res.btDiscAffectProfit = 1 THEN res.TotalDisc ELSE 0 END) + (CASE WHEN res.btExtraAffectCost = 1 OR res.btExtraAffectProfit = 1 THEN res.TotalExtra ELSE 0 END)) / CASE res.biNoUnitQty WHEN 0 THEN 1 ELSE res.biNoUnitQty END
		FROM 
			#EndResult res

	DECLARE cu	CURSOR FOR SELECT [ID], [MaterialGUID], [biPrice], [biQty], [biCalculatedQty2],	[biCalculatedQty3], [biBonusQnt], [biExtra], [biDiscount], [btAffectCostPrice], [btExtraAffectCost], [btDiscAffectCost], [btIsInput], [btIsOutput] FROM [#EndResult] ORDER BY [MaterialCode], [MaterialName], [buDate], [ID]
	
	DECLARE 
			@ID INT,
			@MatGUID UNIQUEIDENTIFIER,
			@Price FLOAT,
			@Quantity FLOAT,
			@Quantity2 FLOAT,
			@Quantity3 FLOAT,
			@BonusQty FLOAT,
			@Extra FLOAT,
			@Disc FLOAT,
			@bAffectCostPrice BIT,
			@bExtraAffectCost BIT,
			@bDiscAffectCost BIT,
			@bIsInput BIT,
			@bIsOutput BIT,
			@RunningQnt FLOAT,
			@RunningQnt2 FLOAT,
			@RunningQnt3 FLOAT,
			@Avg		FLOAT,
			@PrevMatGUID UNIQUEIDENTIFIER = 0x0
			
	OPEN cu
	
	FETCH NEXT FROM cu INTO @ID, @MatGUID, @Price, @Quantity, @Quantity2, @Quantity3, @BonusQty, @Extra, @Disc, @bAffectCostPrice, @bExtraAffectCost, @bDiscAffectCost, @bIsInput, @bIsOutput
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
			IF @PrevMatGUID <> @MatGUID
			BEGIN
				SET @Avg = 0
				SET @RunningQnt = 0
				SET @RunningQnt2 = 0
				SET @RunningQnt3 = 0
			END
		SET @PrevMatGUID = @MatGUID
		DECLARE @q FLOAT,
				@q2 FLOAT,
				@q3 FLOAT,
				@TotalQty FLOAT = @Quantity + @BonusQty
		IF @bIsInput = 1
		BEGIN
			SET @q = @RunningQnt + @Quantity + @BonusQty
			SET @q2 = @RunningQnt2 + @Quantity2 + @BonusQty
			SET @q3 = @RunningQnt3 + @Quantity3 + @BonusQty
		END
		ELSE
		BEGIN
			SET @q = @RunningQnt - @Quantity - @BonusQty
			SET @q2 = @RunningQnt2 - @Quantity2 - @BonusQty
			SET @q3 = @RunningQnt3 - @Quantity3 - @BonusQty
		END
		IF @bAffectCostPrice = 1
		BEGIN 
			IF @bIsOutput = 0
			BEGIN
				SET @Avg =
						CASE
							WHEN @Quantity > 0 THEN
								CASE
									WHEN @q <= 0 AND @RunningQnt < 0 THEN (@Price * @Quantity) / @TotalQty
									ELSE									
										CASE
											WHEN @Avg > 0 THEN
												CASE 
													WHEN ((@Avg * @RunningQnt) + (@Quantity * @Price)) > 0 THEN ((@Avg * @RunningQnt) + (@Quantity * @Price)) / @q
													ELSE @Price
												END
											ELSE @Price
										END
								END
							WHEN @Quantity = 0 THEN 
								CASE 
									WHEN @q <= 0 AND @RunningQnt < 0 AND @TotalQty > 0 THEN CASE WHEN (((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @TotalQty) < 0 THEN 0 ELSE ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @TotalQty END
									ELSE
										CASE 
											WHEN @Avg > 0 THEN 
												CASE 
													WHEN (((@Avg * @RunningQnt) + ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc))) / @q) < 0 THEN 0
													ELSE ((@Avg * @RunningQnt) + ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc))) / @q
												END
											ELSE CASE 
													WHEN (((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @q) < 0 THEN 0
													ELSE ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @q
												END
									END
								END
							ELSE @Avg
						END
			END
			ELSE
			BEGIN
				SET @Avg =
						CASE
							WHEN @Quantity > 0 THEN
								CASE
									WHEN @q <= 0 AND @RunningQnt < 0 THEN ( (CASE @Price WHEN 0 THEN 1 ELSE @Price END) * @Quantity) / ( CASE @TotalQty WHEN 0 THEN 1 ELSE @TotalQty END)
									ELSE									
										CASE
											WHEN @Avg > 0 THEN
												CASE 
													WHEN ((@Avg * @RunningQnt) + (@Quantity * @Price)) > 0 THEN ((@Avg * @RunningQnt) - (@Quantity * @Price)) / (CASE @q WHEN 0 THEN 1 ELSE @q END)
													ELSE @Price
												END
											ELSE @Price
										END
								END
							WHEN @Quantity = 0 THEN 
								CASE 
									WHEN @q <= 0 AND @RunningQnt < 0 AND @TotalQty > 0 THEN ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @TotalQty
									ELSE
										CASE 
											WHEN @Avg > 0 THEN 
												CASE 
													WHEN (((@Avg * @RunningQnt) - ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc))) / @q) < 0 THEN 0
													ELSE ((@Avg * @RunningQnt) + ((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc))) / @q
												END
											ELSE 
												((@bExtraAffectCost * @Extra) - (@bDiscAffectCost * @Disc)) / @q
									END
								END
							ELSE @Avg
						END
			END
		END
		SET @RunningQnt = @q
		SET @RunningQnt2 = @q2
		SET @RunningQnt3 = @q3
		UPDATE #EndResult
		SET BalanceQty = @q,
			BalanceQty2 = @q2,
			BalanceQty3 = @q3,
			BalancePrice = @Avg
		WHERE ID = @ID
	FETCH NEXT FROM cu INTO @ID, @MatGUID, @Price, @Quantity, @Quantity2, @Quantity3, @BonusQty, @Extra, @Disc, @bAffectCostPrice, @bExtraAffectCost, @bDiscAffectCost, @bIsInput, @bIsOutput
	END
		
	CLOSE cu
	DEALLOCATE cu
		
	SELECT *, @NumOfSecViolated AS NumOfSecViolated FROM #EndResult ORDER BY [MaterialCode], [MaterialName], [buDate], [ID]

	EXEC [prcFinilize_Environment] 'repMaterialMove'
#########################################################
CREATE PROCEDURE ARWA.repJournal
	@StartNumber 					[INT] = 1,													--„‰ ﬁÌœ
	@EndNumber 						[INT] = 1,													--≈·Ï ﬁÌœ
	@StartDate 						[DATETIME]= '1/1/2009',												
	@EndDate 						[DATETIME]= '11/30/2010',         
	@CurrencyGUID					[UNIQUEIDENTIFIER] = '0177FDF3-D3BB-4655-A8C9-9F373472715A',       
	@SortType 						[INT] = 1,													--0 Date,	1 Number,	2 BranchName
	@ShowPosted						[INT] = 1,													--ﬁ—«¡… «·ﬁÌÊœ «·„—Õ·…
	@ShowUnposted 					[INT] = 1,													--ﬁ—«¡… «·ﬁÌÊœ €Ì— «·„—Õ·…
	@SourcesTypes 					VARCHAR(8000) = '00000000-0000-0000-0000-000000000000, 1',/*[UNIQUEIDENTIFIER],*/					--„’«œ— «· ﬁ—Ì—										
	@ShowAccountCode				[BIT] = 1,													--Show Account Code
	@AmountCondition				VARCHAR(Max) = '',										--Amount Condition
	--@OperationMode				[INT],													--0 without, 1 Less than, 2 Greater than ,3 Equal, 4 Between,5 Less Or Equal,6 Greater Or Equal
	--@OperationType				[INT],													--0 OPeration for Debit, 1 OPeration for Credit, 2 OPeration for both Debit and Credit
	--@Val1							[FLOAT],												--«·ﬁÌ„…1 ÷„‰ ‘—Êÿ «·„»·€
	--@Val2							[FLOAT],												--«·ﬁÌ„…2 ÷„‰ ‘—Êÿ «·„»·€
	@NotesContain 					[VARCHAR](256) = '',											-- NULL or Contain Text   
	@NotesNotContain				[VARCHAR](256) = '',											-- NULL or Not Contain   
	@JobCostGUID					[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000',										--›· —… Õ”» „—ﬂ“ «·ﬂ·›…
	@ShowContraAccount				[INT] = 0,												--≈ŸÂ«— «·Õ”«» «·„ﬁ«»·
	@ShowaccountCurrencyCode		[INT] = 0,												--«·⁄„·… «·√’·Ì…
	@ShowFromTo						[INT] = 0,												-- ﬁ⁄Ì· „‰ ﬁÌœ ≈·Ï ﬁÌœ
	@ShowEqual						[INT] = 0,												--Show The Equivalent Amount «·„ﬂ«›∆ ÷„‰ ÕﬁÊ· «·„” ‰œ
	@ShowMainAccount				[INT] = 0,												--Show Main Account
	@EntryUserGUID					[UNIQUEIDENTIFIER] = 0X00,								--›· —… Õ”» «·„” Œœ„
	@ShowMainCurrencyInEntry		[BIT] =0,												--Show Currency «·⁄„·… ÷„‰ ÕﬁÊ· «·„” ‰œ
	@ShowUser						[BIT] = 0,												--Show User
	@CollectOperationsByPeriod		[BIT] = 1,												--Show operations during the period
	@SortDebitThenCredit			[BIT] = 0,												--Sort Debit Then Credit
	@UserGUID						[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',										--Logining User
	@ShowEntriesDetail				[BIT] = 1,												--≈ŸÂ«—  ›«’Ì· «·”‰œ« 
	@ShowSummationEntries			[BIT] = 1,												--≈ŸÂ«— „Ã„Ê⁄ «·ﬁÌœ
	@AggregateEntryAccounts			[BIT] = 0,												-- Ã„Ì⁄ «·Õ”«»«  «·„ ﬂ——… ··”‰œ
	@ShowDebit						[BIT] = 1,												--Show Debit
	@ShowCredit						[BIT] = 1,												--Show Credit
	@ShowNote						[BIT] = 1,												--≈ŸÂ«— »Ì«‰ «·”‰œ
	@ShowCurrencyValue				[BIT] = 0,												--≈ŸÂ«—  ⁄«œ· «·⁄„·…
	@ShowJobCost					[BIT] = 0,												--≈ŸÂ«— „—ﬂ“ «·ﬂ·›…
	@ShowClass						[BIT] = 0,												--≈ŸÂ«— «·›∆…
	@ShowBranch						[BIT] = 0,												--≈ŸÂ«— «·›—⁄
	@Lang							[VARCHAR](10) = 'ar',									--«··€…
	@BranchMask						BIGINT = -1
AS     
	SET NOCOUNT ON 
	--Session-Connection
	EXEC [prcSetSessionConnections] @UserGUID, @BranchMask
	-------------------Prepare @Finalsorting-----------------------------
	DECLARE @Finalsorting AS [INT]
	IF (@SortDebitThenCredit = 0)
		SET @Finalsorting = @SortType
	ELSE
		SET @Finalsorting = @SortType + 3
	---------------------------------------------------------------------
	--- 1 posted, 0 unposted -1 both       
	DECLARE @PostedType AS  [INT]      
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 0) )		         
		SET @PostedType = 1      
	IF( (@ShowPosted = 0) AND (@ShowUnposted = 1))         
		SET @PostedType = 0      
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 1))         
		SET @PostedType = -1      
	DECLARE /*@UserGUID [UNIQUEIDENTIFIER],*/ @UserSec [INT] 
	--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()   
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)   
	IF @ShowaccountCurrencyCode > 0 
		SET @ShowMainCurrencyInEntry = 1 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#SecViol]( [Type] [INT],[Cnt] [INT])      
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@JobCostGUID  
	 
	SELECT [CostGuid],[Code] AS [CoCode],[Name] AS [CoName],[c].[Security] INTO [#Cost] FROM [#CostTbl] AS [c] INNER JOIN [co000] AS [co] ON [co].[Guid] = [CostGuid] 
	IF ISNULL(@JobCostGUID,0X00) = 0X00 
		INSERT INTO [#Cost] VALUES (0X00,'','',0)  
	CREATE TABLE [#Result] 
	(      
		[CeDate]			[DATETIME],   		   
		[CeGuid]			[UNIQUEIDENTIFIER],   
		[CeNumber]			[INT],      
		[CeNotes]			[VARCHAR](256) COLLATE ARABIC_CI_AI,		      
		[EnNumber]			[INT],		   
		[EnCurName]			[VARCHAR](256) COLLATE ARABIC_CI_AI,      
		[EnCurVal]			[FLOAT],      
		[EnClass]			[VARCHAR](256) COLLATE ARABIC_CI_AI,      
		[EnCostName]		[VARCHAR](256) COLLATE ARABIC_CI_AI,  
		[EnContraGuid]		[UNIQUEIDENTIFIER],      
		[EnDeBIT]			[FLOAT],      
		[EnCredit]			[FLOAT],      
		[EnAccount]			[UNIQUEIDENTIFIER],   
		[AccName]			[VARCHAR](512) COLLATE ARABIC_CI_AI,      
		[AccLatinName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,      
		[EnNotes]			[VARCHAR](256) COLLATE ARABIC_CI_AI,      
		[acCurrencyPtr]		[UNIQUEIDENTIFIER],  
		[CurCardDeBIT]		[FLOAT],      
		[CurCardCredit]		[FLOAT], 		   
		[Security]	   		[INT],   
		[ParentGUID] 		[UNIQUEIDENTIFIER],    
		[ParentType] 		[INT],   
		[ParentTypeNum] 	[INT],   
		[UserSecurity]		[INT],  
		[EnAccSecurity]		[INT], 
		[ceBranch]			[UNIQUEIDENTIFIER], 
		[ceBranchName]		[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[EnCurrencyEquivilant]			[FLOAT], 
		[acParentGuid]		[UNIQUEIDENTIFIER],  
		[EnNumer2]			[INT], 
		[Branched]			[INT], 
		[DebitinCurr]		[FLOAT], 
		[CrerditinCurr]		[FLOAT], 
		[Flag] [bit], 
		[IsDebit] [bit] 
	)  
	CREATE TABLE #Us 
	( 
		[RecGuid] UNIQUEIDENTIFIER, 
		[UserName] [VARCHAR](256) COLLATE ARABIC_CI_AI 
	)  
	IF @ShowUser = 1 
		INSERT INTO #Us 
		SELECT a.[RecGuid],[LoginName] FROM lg000 a join 
		( 
		select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b 
		ON a.[RecGuid] = b.[RecGuid]  
		INNER JOIN us000 u ON [USerGuid] = u.Guid 
		WHERE a.logTime = b.logTime  
	--Fill Result   
	INSERT INTO [#Result] 
		SELECT         
			[ceDate],         
			[ceGuid],   
			[ceNumber],         
			[ceNotes],      
			[EnNumber],   
			[my].[Code]  AS [CurName],   
			[EnCurrencyVal],      
			[EnClass],      
			CASE [EnCostPoint]       
				WHEN 0x0 THEN '' ELSE [coCode] +'-'+ [coName] 
			END, -- cost name 
			[enContraAcc],   
			 
			[FixedEnDeBIT],         
			[FixedEnCredit],        
			[enAccount],         
			CASE @ShowAccountCode WHEN 0 THEN [r].[acName]     
					ELSE [r].[acCode] +'-'+ [r].[acName] END,         
			CASE @ShowAccountCode WHEN 0 THEN [r].[acLatinName]     
					ELSE [r].[acCode] +'-'+ [r].[acLatinName] END,         
			[enNotes],   [acCurrencyPtr] ,  
			--MyCode AS AcCurCode,      
			[enDebit],  
			[EnCredit], 		   
			[ceSecurity],   
			[r].[ParentGUID],   
			[erparenttype],   
			[ceParentNumber],  
			@UserSec,  
			[r].[acSecurity],  
			[ceBranch], 
			ISNULL([br].[Name], ''), 
			CASE @ShowEqual WHEN 0 THEN 0 ELSE [EnDeBIT] - [EnCredit] 	END,[acParent], 0 ,1, 
			CASE @ShowMainCurrencyInEntry WHEN 0 THEN 0 ELSE [enDebit]/[enCurrencyVal] END, 
			CASE @ShowMainCurrencyInEntry WHEN 0 THEN 0 ELSE [EnCredit]/[enCurrencyVal] END,0,case when [endebit] > 0 then 1 else 0 end 
		FROM         
			((([fnExtended_En_Fixed_Src] (@SourcesTypes, @CurrencyGUID) AS [r]   
			INNER JOIN [My000] AS [MY] ON	[MY].[GUID] = [EnCurrencyPtr]) 
			INNER JOIN [#Cost] AS [co] ON   [EnCostPoint] =  [CostGuid])  
			LEFT JOIN  [Br000] AS [br] ON   [br].[GUID] = [CeBranch]) 
		WHERE         
			(@ShowFromTo = 0 OR [ceNumber] BETWEEN @StartNumber AND @EndNumber )      
			AND [ceDate] BETWEEN @StartDate AND @EndDate      
			AND( (ISNULL(@NotesContain, '') = '')	OR ([CeNotes] LIKE '%'+ @NotesContain + '%') OR ( [EnNotes] LIKE '%' + @NotesContain + '%'))   
			AND( (ISNULL(@NotesNotContain, '') ='')	OR (([CeNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([EnNotes] NOT LIKE '%'+ @NotesNotContain + '%')))	    
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND [ceIsPosted] = 1)       
				OR (@PostedType = 0 AND [ceIsPosted] = 0) ) 

	--Filter by amount condition
	DECLARE @FilterStr VARCHAR(Max)
	IF (@AmountCondition <> '')
		BEGIN
			SET @FilterStr = 'Delete From #Result WHERE NOT ( ' + @AmountCondition + ')'
			EXEC (@FilterStr)
		END

	--End Fill Result
	IF (@CollectOperationsByPeriod > 0) 
	BEGIN 
	 
		INSERT INTO #Result 
		( 
				[EnDeBIT],		 
				[EnCredit],		 
				[EnAccount],		 
				[AccName],		 
				[AccLatinName], 
				[acCurrencyPtr], 
				[UserSecurity], 
				[DebitinCurr], 
				[CrerditinCurr], 
				 
				[Flag] ,[isdebit],[EnCurName] 
		) 
		SELECT 
				SUM([EnDeBIT]),		 
				SUM([EnCredit]), 
				[EnAccount],		 
				[AccName],		 
				[AccLatinName], 
				[acCurrencyPtr], 
				[UserSecurity]	, 
				SUM([DebitinCurr]),	 
				SUM([CrerditinCurr]), 
				1, 
				[isdebit],[EnCurName] 
		FROM 
				#RESULT  
		WHERE 
				[Flag] = 0 
		GROUP BY 
				 
				[AccName],		 
				[AccLatinName], 
				[EnAccount],	 
				[acCurrencyPtr], 
				[UserSecurity]	, 
				[Flag] ,[isdebit],[EnCurName] 
		DELETE #RESULT  WHERE [Flag] = 0 
	END 
	 
	IF (@EntryUserGUID <> 0X00 ) 
				DELETE r FROM #Result r LEFT JOIN (SELECT [EntryGuid]FROM [ER000] AS [er] INNER JOIN [LG000] AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid] WHERE [lg].[USerGuid] = @EntryUserGUID UNION ALL SELECT [RecGuid] FROM [LG000] WHERE [USerGuid] = @EntryUserGUID AND [RecGuid] <> 0X00 ) Q ON q.[EntryGuid] = [r].[ceGuid]  WHERE q.[EntryGuid] IS NULL 
	IF @ShowMainAccount > 0 
	BEGIN 
		INSERT INTO [#Result]( [CeDate],[CeGuid],[CeNumber],[CeNotes],[EnNumber]	,		   
			[EnCurName],[EnCurVal],			 
			[EnClass],[EnCostName],[EnContraGuid],		 
			[EnDeBIT],[EnCredit],[EnAccount],			 
			[AccName],[AccLatinName],[EnNotes],[acCurrencyPtr],		 
			[CurCardDeBIT],[CurCardCredit],[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	 
			[UserSecurity],	[EnAccSecurity],[ceBranch],			 
			[ceBranchName],[EnCurrencyEquivilant],[EnNumer2],			 
			[Branched]	 
		)  
		SELECT [CeDate],[CeGuid],[CeNumber],[CeNotes],0,'',1,'',[EnCostName],0X00, 
			SUM([EnDeBIT]),SUM([EnCredit]),[ac].[acGuid],         
			CASE @ShowAccountCode WHEN 0 THEN [ac].[acName]     
					ELSE [ac].[acCode] +'-'+ [ac].[acName] END,         
			CASE @ShowAccountCode WHEN 0 THEN [ac].[acLatinName]     
					ELSE [ac].[acCode] +'-'+ [ac].[acLatinName] END,'',[ac].[acCurrencyPtr], 
			0,  0,  
				[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	 
				[UserSecurity],	[ac].[AcSecurity],[ceBranch],			 
				[ceBranchName],Sum([EnCurrencyEquivilant]),Min([EnNumber]),[Branched] 
			FROM [#Result] AS [r] INNER JOIN [vwac] AS [ac] ON [ac].[acGuid] = [r].[acParentGuid] 
			GROUP BY [CeDate],[CeGuid],[CeNumber],[CeNotes],[EnCostName],[ac].[acGuid],[ac].[acCode],[ac].[acName],[ac].[acLatinName],[ac].[acCurrencyPtr], 
				[Security],[ParentGUID],[ParentType],[ParentTypeNum], 	 
				[UserSecurity],	[ac].[AcSecurity],[ceBranch],			 
				[ceBranchName],[Branched],[FLAG] 
			UPDATE [r] SET [EnNumer2] = [rr].[EnNumer2] FROM  [#Result] AS [r] INNER JOIN [#Result] AS [rr] ON [rr].[EnAccount] = [r].[acParentGuid] AND [rr].[CeGuid] = [r].[CeGuid] 
			   
	END  
	
	Exec [prcCheckSecurity] @UserGUID   
	
	DECLARE @IsFullResult [BIT]
	IF (EXISTS(SELECT * FROM #SecViol))
		SET @IsFullResult = 0
	ELSE
		SET @IsFullResult = 1 
	
	--Filter Result by Security  Old Strategy
	--DECLARE @NumOfSecViolated [INT]
	--SET @NumOfSecViolated = 0
	
	--DELETE FROM [#Result]
	--WHERE [CeGUID] IN (SELECT [GUID] FROM [dbo].[fnARWAGetDeniedCentries] (@UserGuid) WHERE [IsSecViol] = 1 )
	--SET @NumOfSecViolated = @@ROWCOUNT
	--DECLARE @IsFullResult [BIT]
	--IF (@NumOfSecViolated = 0)
	--	SET @IsFullResult = 1
	--ELSE
	--	SET @IsFullResult = 0
	
	----Filter Result by Branches
	--DELETE FROM [#Result]
	--WHERE [CeGUID] IN (SELECT [GUID] FROM [dbo].[fnARWAGetDeniedCentries] (@UserGuid))
	
	DECLARE @SqlString AS [VARCHAR](7000)    
	--SELECT * FROM #Result 
	SET @SqlString = 'SELECT [CeDate],[CeGuid],[CeNumber], [CeNotes],[EnNumber],[EnCurName],[EnCurVal],[EnClass],[EnCostName],[EnContraGuid], 
			[EnDeBIT],[EnCredit],[EnAccount],[AccName],[AccLatinName],[EnNotes],[r].[acCurrencyPtr],[CurCardDeBIT],[CurCardCredit], 		   
			[r].[ParentGUID],[r].[ParentType],[ParentTypeNum],[ceBranchName],[EnAccSecurity], [CeBranch], [EnNumer2], r.[Branched] '   
	IF @ShowEqual > 0 
		SET @SqlString = @SqlString + ',[EnCurrencyEquivilant]' 
	IF (@ShowContraAccount   = 1)  
		SET @SqlString = @SqlString + ',ISNULL( [ac].[acCode] +'+''''+ '-' +'''' +' + [ac].[acName] , '+'''' +'''' +' ) AS [EnContraAcc],ISNULL( [ac].[acCode] +'+''''+ '-' +'''' +' + [ac].[acLatinName] , '+'''' +'''' +' ) AS [EnContraLatinAcc] ' 
	--IF (@ShowaccountCurrencyCode = 1) 
	--	SET @SqlString = @SqlString + ',[myCode] [AcCurCode]' 
	/*IF @ShowMainAccount > 0 
		SET @SqlString = @SqlString + ',r.[Branched]' Get Branched always to #Res*/
	IF @ShowMainCurrencyInEntry > 0 
		SET @SqlString = @SqlString + ',[DebitinCurr],[CrerditinCurr]	' 
	IF @ShowUser = 1 
		SET @SqlString = @SqlString + ',ISNULL([UserName],'''') AS [UserName]' 
	SET @SqlString = @SqlString + ', /*0 AS IsHeader,*/ (CASE WHEN MainAC.nSons <> 0 THEN 1 ELSE 0 END) AS IsMainAcc'
	SET @SqlString = @SqlString + char(13)+ 'INTO #Res FROM [#Result] AS [r]' 
	SET @SqlString = @SqlString + ' INNER JOIN AC000 MainAc ON r.EnAccount = MainAc.GUID '
	IF (@ShowContraAccount   = 1)  
		SET @SqlString = @SqlString + 'LEFT JOIN [vwAc] AS [ac] ON [ac].[acGUID] = [EnContraGuid]' 
	IF @ShowUser = 1 
		SET @SqlString = @SqlString + 'LEFT JOIN (SELECT [EntryGuid],[UserName]FROM [ER000] AS [er] INNER JOIN #Us AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid] 
			UNION ALL  
			SELECT [RecGuid],[UserName] FROM #Us WHERE  [RecGuid] <> 0X00) Q ON q.EntryGuid =[CeGuid] ' + CHAR(13) 
	--	SET @SqlString = @SqlString + ' INNER JOIN [vwMy] ON [myGUID] = [r].[acCurrencyPtr]' 
	IF (@CollectOperationsByPeriod > 0) 
		SET @SqlString = @SqlString + ' ORDER BY [AccName]' 
	ELSE 
	BEGIN 
		IF( /*@SortType*/@Finalsorting <= 0 ) 
			SET @SqlString = @SqlString + ' ORDER BY  [ceBranch], [ceDate], [ceNumber], [ParentTypeNum] '         
		IF( /*@SortType*/@Finalsorting = 1 )        
			SET @SqlString = @SqlString + ' ORDER BY  [ceBranch], [ceNumber], [ParentTypeNum], [enNumber], [ceDate] '         
		IF( /*@SortType*/@Finalsorting = /*2*/3)         
			SET @SqlString = @SqlString + ' ORDER BY [ceBranch], [ceDate], [ceNumber], [ParentTypeNum], [enDeBIT] DESC, [EnCredit] DESC '         
		IF( /*@SortType*/@Finalsorting = /*3*/4)         
			SET @SqlString = @SqlString + ' ORDER BY [ceBranch], [ceNumber], [ParentTypeNum], [ceDate], [enDeBIT] DESC, [EnCredit] DESC '         
		 
		IF( /*@SortType*/@Finalsorting  <= 0 ) 
			SET @SqlString = @SqlString + ',[enNumber]'   
		IF( /*@SortType*/@Finalsorting = /*4*/2 ) 
			SET @SqlString = @SqlString + ' ORDER BY  [ceBranchName],[ceBranch], [ceDate], [ceNumber], [ParentTypeNum] '   
		IF( /*@SortType*/@Finalsorting = 5 ) 
			SET @SqlString = @SqlString + ' ORDER BY  [ceBranchName],[ceBranch], [ceDate], [enDeBIT] DESC, [EnCredit] DESC, [ParentTypeNum] '   
		IF @ShowMainAccount > 0 
			SET @SqlString = @SqlString + ', [IsMainAcc] ' 
	END 
	--SET @SqlString = @SqlString + ' SELECT * FROM #Res '
	
	----„Ã«„Ì⁄ «·ﬁÌÊœ
	--SET @SqlString = @SqlString + ' SELECT CeGuid, CeDate, CeNumber, CeNotes, 
	--							    Sum(EnDebit) EnDebit, Sum(EnCredit) EnCredit,
	--							    ParentGUID, ParentType, ParentTypeNum, CeBranch, CeBranchName
	--							    INTO #CeHeaders
	--							    FROM #Res 
	--							    GROUP by CeGuid, CeDate, CeNumber, CeNotes, ParentGUID, ParentType, ParentTypeNum, CeBranch, CeBranchName '
	----«·‰ ÌÃ… ﬂ«„·… „Ã„Ê⁄ «·ﬁÌœ „⁄  ›«’Ì· «·”‰œ« 							  	 
	----Õ–› «· ›«’Ì·
	--IF (@ShowEntriesDetail = 0)
	--	SET @SqlString = @SqlString + ' DELETE #Res '
	
	----„Ã„Ê⁄ «·ﬁÌœ
	--IF (@ShowSummationEntries = 1)
	--	SET @SqlString = @SqlString + ' INSERT INTO #Res (CeGuid, CeDate, CeNumber, CeNotes, EnNumber,
	--												 EnDebit, EnCredit, ParentGUID, ParentType, ParentTypeNum, CeBranchName, IsHeader, IsMainAcc)
								  
	--									SELECT CeGuid, CeDate, CeNumber, CeNotes, -1,
	--									EnDebit, EnCredit,
	--									ParentGUID, ParentType, ParentTypeNum, CeBranchName, 1, 1
	--									FROM #CeHeaders '
    ----------------------------------------------------------------------------------------------------------------------
	----------------------------------------F I N A L    R E S U L T------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------
	-- Ã„Ì⁄ «·Õ”«»«  «·„ ﬂ——… ··”‰œ
	if (@AggregateEntryAccounts = 1)
	BEGIN
		SET @SqlString = @SqlString + ' SELECT res.CeDate, res.CeGuid, res.CeNumber, res.CeNotes, res.EnAccount, res.AccName, res.AccLatinName, res.AcCurrencyPtr, 
									    Sum(res.EnDebit) EnDebit, Sum(res.EnCredit) EnCredit,
									    res.ParentGUID, res.ParentType, res.ParentTypeNum, res.CeBranch, res.CeBranchName, /*IsHeader,*/ IsMainAcc, ' + CAST(@IsFullResult AS VARCHAR(1)) + ' AS IsFullResult '
		SET @SqlString = @SqlString + ' FROM #Res res
									    GROUP by res.CeGuid, res.EnAccount,
									    res.CeDate, res.CeNumber, res.CeNotes, res.AccName, res.AccLatinName, res.AcCurrencyPtr, res.ParentGUID, res.ParentType, res.ParentTypeNum, res.CeBranch, res.CeBranchName, /*IsHeader,*/ IsMainAcc '
	END
	ELSE
		SET @SqlString = @SqlString + ' SELECT *, ' + CAST(@IsFullResult AS VARCHAR(1)) + ' AS IsFullResult FROM #Res '
	
	
	EXECUTE(@SqlString)         
	SET NOCOUNT OFF   
#########################################################
CREATE PROCEDURE ARWA.repInventoryChecklist
	-- Report Filters
	@ProductGUID 					[UNIQUEIDENTIFIER] = 0x0,													-- Material Guid
	@GroupGUID 						[UNIQUEIDENTIFIER] = 0x0,													-- Group Guid
	@GroupLevel						[INT] = 0,																	-- Group Level
	@StoreGUID 						[UNIQUEIDENTIFIER] = 0x0,													-- Store Guid
	@StoreLevel						[INT] = 0,																	-- Store Level
	@JobCostGUID 					[UNIQUEIDENTIFIER] = 0x0,													-- Cost Group
	@Class							VARCHAR(255)       = '',													-- Bill Class
	@StartDate 						[DATETIME]         = '1-1-2009',											-- Start Date
	@EndDate 						[DATETIME]         = '12-31-2010',											-- End Date
	@CurrencyGUID 					[UNIQUEIDENTIFIER] = '0177FDF3-D3BB-4655-A8C9-9F373472715A',				-- Currency Guid
	@PriceType 						[INT]			   = 2,																		-- Price Type
	@PricePolicy 					[INT]			   = 120,																		-- Price Policy
	@UseUnit 						[INT]			   = 3,																		-- Use Unit
	@SortType 						[INT] 			   = 0,													-- Material Sort Type
	-- Report Options
	@CompareQuantity				[BIT] 			   = 1,													-- Compare Materials Quantity
	@ShowEmpty 						[BIT] 			   = 1,													-- Show empty materials
	@ShowBalancedProduct			[BIT] 			   = 1,													-- Show balanced materials
	@DetailsStores 					[BIT] 		   	   = 1,													-- Show detaild stores and add the store name field to the resultset
	@ShowGroups 					[BIT] 			   = 0,													-- Show Groups Details
	@ProductType 					[INT] 			   = -1,													-- Material Type to be displayed
	@DetailedCostPrice				[BIT] 			   = 1,													-- Detailed cost price according to stores
	-- Fields Dispaly Options
	@ShowProductCode				[BIT] 		       = 1,													-- Show material code field
	@ShowProductName				[BIT] 			   = 1,													-- Show material name field
	@ShowProductLatinName			[BIT] 			   = 1,													-- Show material latin name field
	--@ShowProductFieldsFlag			[BIGINT]           = 33431551,											-- Flag used to pass the material fields to be display
	@ShowProductQuantity			[BIT] 			   = 1,													-- Show material quantity
	@ShowProductPrice				[BIT] 			   = 1,													-- Show Material price field And the total field
	@ShowProductUnitFactor			[BIT] 			   = 1,													-- Show Material unit conversion factor field
	@ShowProductGroupCode			[BIT] 			   = 1,													-- Show group code field
	@ShowProductGroup				[BIT] 			   = 1,													-- Show group name field
	@ShowProductBarcode				[BIT] 			   = 1,													
	@ShowProductUnit2BarCode		[BIT] 			   = 1,														
	@ShowProductUnit3BarCode        [BIT]			   = 1,
	@ShowProductUnit				[BIT]			   = 1,
	@ShowProductType				[BIT]              = 1,
	@ShowProductSpecification       [BIT]              = 1,
	@ShowProductSize                [BIT]              = 1,
	@ShowProductSource              [BIT]              = 1,
	@ShowProductLocation            [BIT]              = 1,
	@ShowProductCompany             [BIT]              = 1,
	@ShowProductColor               [BIT]              = 1,
	@ShowProductProvenance          [BIT]              = 1,
	@ShowProductQuality				[BIT]              = 1,
	@ShowProductModel				[BIT]              = 1,
	
	@ClassDetails					[BIT] 			   = 1,													-- Show class detail
	@ShowStoreCode					[BIT] 			   = 1,													-- Show store code if @DetailsStores = 1
	@ShowUnLinked 					[BIT] 			   = 1,													-- Show Qty2, Qty3, Unity2, Unity 3
	-- Footer Display Options
	@ShowUnitDetailsTotal			[BIT] 			   = 1,													-- Show the total for all of the unit quantity when @UseUnit = 5
	-- Other options (No user interaction reqired)
	@UserGUID						[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	            -- The current loged in user (determined by the system)
	@Lang							VARCHAR(10) = 'ar',														    -- Resultset Language (determined by the system)
	@BranchMask						BigInt = -1,
	@ProductConditions				VARCHAR(MAX) = ''
	
	
	/*(New variable with the same name was created to replace these parameters)
	@CurrencyVal 			[FLOAT],			-- Currency Value
	@SrcTypesguid			[UNIQUEIDENTIFIER],	-- DELETED (Always passed with value = 0x0)
	@CalcPrices 			[INT] = 1,			-- DELETED (Always passed with value = 1)
	@MatCondGuid			[UNIQUEIDENTIFIER]  -- DELETED (Not supported)
	@VeiwCFlds				VARCHAR (8000),		-- DELETED (Not supported)
	*/
	
	
	
	
AS 

	--prcInitialize_Environment
	EXEC [prcInitialize_Environment] @UserGUID, '[repInventoryChecklist]', @BranchMask
	
	
	SET NOCOUNT ON 
	
	--Session-Connection
	EXEC [prcSetSessionConnections] @UserGUID, @BranchMask
	
	-------------------------------------------------
	-- Replacment variables for the deleted parameters
	DECLARE @SrcTypesguid	[UNIQUEIDENTIFIER],
			@CurrencyVal	[FLOAT],
			@CalcPrices		[INT],
			@VeiwCFlds		VARCHAR (8000)
			
	SET @SrcTypesguid = '00000000-0000-0000-0000-000000000000'
	SET @CalcPrices = 1
	SET @VeiwCFlds = ''
	
	SET @CurrencyVal = (Select Top 1 IsNull(mh.CurrencyVal, my.CurrencyVal) 
				   From my000 my 
				   LEFT join mh000 mh on my.[Guid] = mh.[CurrencyGUID] 
				   WHERE my.[GUID] = @CurrencyGUID Order By mh.Date Desc)
				   
	-------------------------------------------------
	-- Variables decleration
	DECLARE @IsArabic	[INT],
			@UnitType	[INT],
			@Zero		[FLOAT],
			@IsFullResult [INT]
			
	IF @Lang LIKE 'ar%'
		SET @IsArabic = 1
	ELSE
		SET @IsArabic = 0
		
	IF @UseUnit = 4
		SET @UseUnit = 5
	SET @UnitType = CASE @UseUnit WHEN 5 THEN 0 ELSE @UseUnit END 	
	SET @Zero = dbo.fnGetZeroValue()
	
	-------------------------------------------------
	-- Creating temporary tables 
	CREATE TABLE [#MatTbl] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#StoreTbl] ([StoreGUID] [UNIQUEIDENTIFIER], [stSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER]) 
	CREATE TABLE [#CostTbl] ([CostGUID] [UNIQUEIDENTIFIER], [coSecurity] [INT]) 
	CREATE TABLE [#t_Prices2] 
	( 
		[mtNumber]	[UNIQUEIDENTIFIER], 
		[APrice]	[FLOAT], 
		[stNumber]	[UNIQUEIDENTIFIER] 
	) 
	CREATE TABLE [#t_Prices] 
	( 
		[mtNumber]	[UNIQUEIDENTIFIER], 
		[APrice]	[FLOAT] 
	)
	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	-------------------------------------------------
	--Filling temporary tables 
	INSERT INTO [#MatTbl] ([MatGUID], [mtSecurity]) EXEC [prcGetMatsList] @ProductGUID, @GroupGUID, @ProductType, 0x0, @ProductConditions	
	INSERT INTO [#StoreTbl] EXEC [prcGetStoresList] @StoreGUID 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	INSERT INTO [#CostTbl] SELECT 0x0, 0
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypesguid, @UserGUID
	
	-------------------------------------------------
	-- Create the primary ResultSet
	CREATE TABLE [#SResult] 
	( 
		[biGuid]		[UNIQUEIDENTIFIER],
		[matGUID]		[UNIQUEIDENTIFIER],
		[biQty]			[FLOAT], 
		[biQty2]		[FLOAT], 
		[biQty3]		[FLOAT],
		[coGuid]		[UNIQUEIDENTIFIER],
		[stGUID]		[UNIQUEIDENTIFIER], 
		[biClassPtr]	[VARCHAR](255) COLLATE Arabic_CI_AI, 
		[APrice]		[FLOAT], 
		[bMove]			[TINYINT]
	) 
	
	-------------------------------------------------
	-- Fill the primary ResultSet, and handling the security and branches issues using the required security functions in the join statement
	IF( EXISTS( SELECT * FROM [vwbu] WHERE [buDate] < @StartDate OR [buDate]> @EndDate) 
		   OR @JobCostGUID <> 0X00  OR @ClassDetails = 1 OR ([dbo].[fnConnections_getBranchMask]() <> dbo.fnGetUserBranchMask()) 
		   OR @ShowUnLinked = 1 OR @Class <> ''
		   OR EXISTS(SELECT * FROM op000 WHERE name like 'AmncfgMultiFiles' and value = '1'))  -- we must calc sum(qty2), Sum(Qty3) from bi, bu 
	BEGIN 
	   INSERT INTO [#SResult] 
		SELECT 
			[r].[biGUID],
			[r].[biMatPtr], 
			(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection])  / (CASE @UnitType WHEN 0 THEN 1 ELSE CASE @UnitType WHEN 1 THEN (CASE WHEN [mt].[Unit2Fact] <> 0 THEN [mt].[Unit2Fact] ELSE 1 END) ELSE CASE @UnitType WHEN 2 THEN (CASE WHEN [mt].[Unit3Fact] <> 0 THEN [mt].[Unit3Fact] ELSE 1 END) ELSE CASE @UnitType WHEN 3 THEN 
							CASE [mt].[DefUnit] WHEN 2 THEN (CASE WHEN [mt].[Unit2Fact] <> 0 THEN [mt].[Unit2Fact] ELSE 1 END) ELSE CASE [mt].[DefUnit] WHEN 3 THEN (CASE WHEN [mt].[Unit3Fact] <> 0 THEN [mt].[Unit3Fact] ELSE 1 END) ELSE 1 END END
						END END END END), 
			[r].[biQty2]* [r].[buDirection], 
			[r].[biQty3]* [r].[buDirection], 
			[r].[biCostPtr],
			CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END, 
			CASE @ClassDetails WHEN 1 THEN [biClassPtr] ELSE '' END,
			0, 
			1
		FROM 
			[vwbubi] AS [r] 
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid] 
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID] 
			INNER JOIN mt000 AS [mt] ON [mt].[GUID] = [mtTbl].[MatGUID]
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]
			INNER JOIN [#CostTbl] AS [co] ON co.CostGUID = [r].[biCostPtr]
		WHERE 
			[budate] BETWEEN @StartDate AND @EndDate 
			AND [buIsPosted] > 0 
			AND (@Class = '' OR @Class =[biClassPtr])

		IF @ShowUnLinked = 1 AND @UseUnit <> 5 
			UPDATE [bi] SET  
				[biQty2] = (CASE [mt].[Unit2FactFlag] WHEN 0 THEN CASE [mt].[Unit2Fact] WHEN 0 THEN 0 ELSE (([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]) /  [mt].[Unit2Fact] END ELSE [bi].[biQty2] END), 
				[biQty3] = (CASE [mt].[Unit3FactFlag] WHEN 0 THEN CASE [mt].[Unit3Fact] WHEN 0 THEN 0 ELSE (([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]) /  [mt].[Unit3Fact] END ELSE [bi].[biQty3] END) 
			FROM [#SResult] AS [bi]
			INNER JOIN [vwbubi] AS [r] ON [bi].[biGuid] = [r].[biGUID]
			INNER JOIN [mt000] AS [mt]  ON  [mt].[Guid] = [bi].[matGUID] 
	END 
	
	ELSE 
	BEGIN 
	INSERT INTO [#SResult] 
	SELECT 
		0x0,
		[mtTbl].[MatGUID],
		msQty, 
		0, 
		0,
		0, 
		0x0,
		CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [msStorePtr] END, 
		'',
		0, 
		1 
	FROM 
		[#MatTbl] AS [mtTbl]  
		INNER JOIN [vwms] AS [ms] ON [msMatPtr] = [mtTbl].[MatGUID] 
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [msStorePtr] 
	END 
	
	IF (@ShowEmpty = 1 )
	INSERT INTO [#SResult] 
	SELECT
		0x0,
		[mtTbl].[MatGUID],
		0,
		0,
		0,
		0x00,
		0X00,
		'',
		0,
		0
	FROM [#MatTbl] AS [mtTbl]
	WHERE [mtTbl].[MatGUID] NOT IN (SELECT [matGUID] FROM [#SResult]) 
	
	IF @ShowBalancedProduct = 0
		DELETE [#SResult] WHERE ABS([biQty]) < @Zero AND [bMove] = 1

	--Security filtering :
	EXEC [prcCheckSecurity] @UserGUID, DEFAULT, DEFAULT, '#SResult', DEFAULT    
	IF Exists(Select * From #SecViol)
		SET @IsFullResult = 0
	ELSE
		SET @IsFullResult = 1
	/*
	-------------------------------------------------
	-- Delete the rows that violate any of the security constrains 
	-- A security function is used for every key element in the resultset that have a security level
	DELETE FROM #SResult
	WHERE
		[biGuid] IN (SELECT Guid FROM [fnGetDeniedBillItems](@UserGUID) WHERE [IsSecViol] = 1) OR
		[MatGuid] IN (SELECT Guid FROM [fnGetDeniedMaterials](@UserGUID) WHERE [IsSecViol] = 1) OR
		[coGuid] IN (SELECT Guid FROM [fnGetDeniedCosts](@UserGUID) WHERE [IsSecViol] = 1) OR
		[stGuid] IN (SELECT Guid FROM [fnGetDeniedStores](@UserGUID) WHERE [IsSecViol] = 1)
	
	-- Get the count of security violation
	SET @SecViolCount = @@ROWCOUNT

	-- Delete the rows that not related to the current registered branch mask
	DELETE FROM #SResult
	WHERE
		([biGuid] IN (SELECT Guid FROM [fnGetDeniedBillItems](@UserGUID))) OR
		([MatGuid] IN (SELECT Guid FROM [fnGetDeniedMaterials](@UserGUID))) OR
		([coGuid] IN (SELECT Guid FROM [fnGetDeniedCosts](@UserGUID))) OR
		([stGuid] IN (SELECT Guid FROM [fnGetDeniedStores](@UserGUID)))

	-------------------------------------------------
	*/
	CREATE TABLE [#R] 
	( 
		[StoreGUID]		[UNIQUEIDENTIFIER], 
		[mtNumber]		[UNIQUEIDENTIFIER], 
		[mtQty]			[FLOAT], 
		[Qnt2]			[FLOAT], 
		[Qnt3]			[FLOAT], 
		[APrice]		[FLOAT], 
		[stLevel]		[INT], 
		[ClassPtr]		[VARCHAR](255) COLLATE ARABIC_CI_AI, 
		[id]			[INT] DEFAULT 0, 
		[mtUnitFact]	[FLOAT] DEFAULT 1, 
		[MtGroup]		[UNIQUEIDENTIFIER], 
		[RecType]		[VARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL, 
		[grLevel]		[INT], 
		[Move]			[INT]
	)
		
	IF @ShowProductPrice > 0 
	BEGIN 
	IF @ProductType >= 3 
		SET @ProductType = -1
		
	IF @PriceType = 2
	BEGIN
		IF @PricePolicy = 120 -- Max Price
		BEGIN
			EXEC [prcGetMaxPrice]	@StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID,
									@ProductType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0 
		END
		
		ELSE IF @PricePolicy = 121 -- Average Price
		BEGIN
			IF @DetailedCostPrice = 0 -- NO STORE DETAILS
			BEGIN
				EXEC [prcGetAvgPrice]	@StartDate, @EndDate, @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID,
										@ProductType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,  @ShowUnLinked, 0 
			END						
			ELSE
			BEGIN
				EXEC [prcGetAvgPrice_WithDetailStore]	@StartDate, @EndDate, @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID,
														@ProductType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0 
			END
		END	
		
		ELSE IF @PricePolicy = 122 -- LastPrice
		BEGIN
			EXEC [prcGetLastPrice]	@StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID,
									@ProductType, @CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0
		END
		
		ELSE IF @PricePolicy = 124 -- LastPrice with extra and discount
		BEGIN
			EXEC [prcGetLastPrice]	@StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID,
									@ProductType, @CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0, 1
		END
		
		ELSE IF @PricePolicy = 125 -- FIFO
		BEGIN
			EXEC [prcGetFirstInFirstOutPrise] @StartDate , @EndDate,@CurrencyGUID 
		END
		
		ELSE IF @PricePolicy = 130 
		BEGIN
			INSERT INTO [#t_Prices]
			SELECT
				[r].[biMatPtr],SUM([FixedBiTotal])/ (CASE WHEN SUM([biQty] + [biBonusQnt]) <> 0 THEN SUM([biQty] + [biBonusQnt]) ELSE 1 END)--SUM([biQty] + [biBonusQnt])
			FROM
				[fnExtended_bi_Fixed](@CurrencyGUID) AS [r] 
				INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid] 
				INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID] 
				INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]
				INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [r].[BiCostPtr]
			WHERE 
				[budate] BETWEEN @StartDate AND @EndDate AND [BtBillType] = 0 
				AND [buIsPosted] > 0
			GROUP BY [r].[biMatPtr]
		END
	END 
	
	ELSE IF @PriceType = -1
	BEGIN 
		INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl] 
	END

	ELSE 
	BEGIN
		EXEC [prcGetMtPrice] @ProductGUID, @GroupGUID, @ProductType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UnitType 
	END 

	IF (@DetailedCostPrice = 1 AND @PricePolicy = 121) 
		UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices2] AS [p] ON [stNumber]= [stGUID] AND [mtNumber] = [matGUID] 
	ELSE 
		UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices] AS [p] ON [mtNumber] = [matGUID] 
	END 

	INSERT INTO [#R]
	(
		[StoreGUID],
		[mtNumber],
		[mtQty],
		[Qnt2],
		[Qnt3],
		[APrice],
		[stLevel],
		[ClassPtr],
		[id],
		[Move]
	)
	SELECT
		[stGUID],
		[matGUID],
		SUM([biQty]),
		SUM([biQty2]),
		SUM([biQty3]),
		ISNULL([APrice],0),
		0,
		[biClassPtr],
		0,
		MAX([bMove]) 
	FROM [#SResult] AS [r]
	GROUP BY [r].[matGUID], [r].[stGUID], [r].[APrice], [r].[biClassPtr]

	IF @ShowBalancedProduct = 0
		DELETE [#R] WHERE ABS([mtQty])< @Zero AND [Move] > 0

	DECLARE @Level [INT] 
	IF (@StoreLevel > 0) 
	BEGIN 
	CREATE TABLE [#TStore] 
	( 
		[Id]			[INT] IDENTITY(1,1), 
		[Guid]			[UNIQUEIDENTIFIER], 
		[Level]			[INT], 
		[StCode]		[VARCHAR](255) COLLATE ARABIC_CI_AI, 
		[StName]		[VARCHAR](255) COLLATE ARABIC_CI_AI 
	) 
	
	INSERT INTO [#TStore]
	(
		[Guid],
		[Level],
		[StCode],
		[StName]
	) 
	SELECT [f].[Guid],
		[Level] + 1,
		[Code],
		ISNULL(CASE @IsArabic WHEN 1 THEN [Name] ELSE [LatinName] END, [Name])
	FROM [fnGetStoresListTree](@StoreGUID, 0) AS [f]
	INNER JOIN [st000] AS [st] ON [st].[GUID] = [f].[Guid]
	ORDER BY [Path] 
	
	SET @Level = (SELECT MAX([LEVEL]) FROM [#TStore])  
	
	UPDATE [r]
		SET [stLevel] = [Level],[Id] = [st].[Id]
	FROM [#R] AS [r]
	INNER JOIN [#TStore] AS [st] ON [StoreGUID] = [Guid] 
	
	WHILE (@Level > 1) 
	BEGIN 
	INSERT INTO [#R]
	(
		[StoreGUID],
		[mtNumber],
		[mtQty],
		[Qnt2],
		[Qnt3],
		[APrice],
		[stLevel],
		[ClassPtr],
		[id]
	)          
	SELECT
		[t].[Guid],
		[mtNumber],
		SUM([mtQty]),
		SUM([Qnt2]),
		SUM([Qnt3]),
		ISNULL([APrice],0),
		[t].[Level],
		[ClassPtr],
		[t].[id] 
	FROM  [#R] AS [r]
	INNER JOIN [st000] AS [st] ON [st].[Guid] = [r].[StoreGUID]
	INNER JOIN [#TStore] AS [T] ON [t].[Guid] = [st].[ParentGuid] 
	WHERE [r].[stLevel] = @Level 
	GROUP BY  
		[t].[Guid],
		[mtNumber],
		ISNULL([APrice],0),
		[t].[Level],
		[ClassPtr],
		[t].[id]
		   
	IF (@StoreLevel = @Level) 
		DELETE [#R] WHERE [stLevel] > @StoreLevel 
		
	SET @Level = @Level - 1 
	END 
	IF (@StoreLevel = 1) 
		DELETE [#R] WHERE [stLevel] > @StoreLevel 
		SELECT
			[StoreGUID],
			[mtNumber],
			[mtQty],
			[Qnt2],
			[Qnt3],
			[APrice],
			[stLevel],
			[ClassPtr],
			[id]
		INTO [#R2] FROM [#R] 
		
		TRUNCATE TABLE [#R] 
		
		INSERT INTO #R
		(
			[StoreGUID],
			[mtNumber],
			[mtQty],
			[Qnt2],
			[Qnt3],
			[APrice],
			[stLevel],
			[ClassPtr],
			[id]
		)          
		SELECT
			[StoreGUID],
			[mtNumber],
			SUM([mtQty]),
			SUM([Qnt2]),
			SUM([Qnt3]),
			[APrice],
			[stLevel],
			[ClassPtr],
			[id]
		FROM [#R2] 
		GROUP BY
			[StoreGUID],
			[mtNumber],
			[APrice],
			[stLevel],
			[ClassPtr],
			[id]
	END  
	
	CREATE TABLE [#MainRes3] 
		( 
			[StoreGUID]		[UNIQUEIDENTIFIER], 
			[mtNumber]		[UNIQUEIDENTIFIER], 
			[mtQty]			[FLOAT], 
			[Qnt2]			[FLOAT], 
			[Qnt3]			[FLOAT], 
			[APrice]		[FLOAT], 
			[stLevel]		[INT], 
			[ClassPtr]		[VARCHAR](255) COLLATE ARABIC_CI_AI, 
			[id]			[INT] DEFAULT 0, 
			[MtGroup]		[UNIQUEIDENTIFIER], 
			[RecType]		[VARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL, 
			[grLevel]		[INT], 
			[mtUnitFact]	[FLOAT]
		)
	
	-- Show Groups 

	IF @ShowGroups <> 0 
	BEGIN 
		SELECT
			[f].[Guid],
			[f].[Level],
			[Name] AS [grName],
			[LatinName] AS [grLatinName],
			[Code] AS [grCode],
			[ParentGuid]
		INTO [#grp]
		FROM [dbo].[fnGetGroupsListByLevel](@GroupGUID,0) AS [f]
		INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid] 

		SELECT @Level = MAX([Level]) FROM [#grp] 
		UPDATE [r] 
		SET  
			[MtGroup] = [GroupGuid], 
			[RecType] = 'm', 
			[grLevel] = [Level], 
			[mtUnitFact] =	CASE @UseUnit WHEN 0 THEN 1 
								WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
								WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END 
							ELSE 
							CASE [DefUnit] 
								WHEN 1 THEN 1 
								WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END 
								ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
							END 
						END
		FROM [#R] AS [r]  
		INNER JOIN [mt000] AS [mt] ON [mtNumber] = [mt].[Guid]  
		INNER JOIN [#grp] AS [gr] ON  [gr].[Guid] = [GroupGuid] 

		INSERT INTO [#R]
		(
			[StoreGUID],
			[mtNumber],
			[mtQty],
			[Qnt2],
			[Qnt3],
			[APrice],
			[stLevel],
			[ClassPtr],
			[id],
			[MtGroup],
			[RecType],
			[grLevel]
		) 
		SELECT
			0x00,
			[gr].[Guid],
			SUM([mtQty]/[mtUnitFact]),
			SUM([Qnt2]),
			SUM([Qnt3]),
			SUM([APrice] * [mtQty]),
			[stLevel],
			'',
			[id],
			[gr].[ParentGuid],
			'g',
			[gr].[Level]
		FROM [#R] AS [r]
		INNER JOIN [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup] 
		WHERE [stLevel] < = 1
		GROUP BY
			[gr].[Guid],
			[stLevel],
			[id],
			[gr].[ParentGuid],
			[gr].[Level]

		WHILE (@Level > 1) 
		BEGIN 
			INSERT INTO [#R]
			(
				[StoreGUID],
				[mtNumber],
				[mtQty],
				[Qnt2],
				[Qnt3],
				[APrice],
				[stLevel],
				[ClassPtr],
				[id],
				[MtGroup],
				[RecType],
				[grLevel]
			)
			SELECT
				0x00,
				[gr].[Guid],
				SUM([mtQty]),
				SUM([Qnt2]),
				SUM([Qnt3]),
				SUM([APrice]),
				[stLevel],
				'',
				[id],
				[gr].[ParentGuid],
				'g',
				[gr].[Level]
			FROM [#R] AS [r]
			INNER JOIN [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup] 
			WHERE [r].[grLevel] = @Level AND [RecType] = 'g'  
			GROUP BY
				[gr].[Guid],
				[stLevel],
				[id],
				[gr].[ParentGuid],
				[gr].[Level]
				
			SET @Level = @Level - 1 
		END 

		INSERT INTO [#MainRes3] 
		SELECT
			[r].[StoreGUID],
			[r].[mtNumber],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR((CAST(SUM([r].[mtQty]) AS INT) % CAST([mt].[mtUnit3Fact] AS INT)) % CAST([mt].[mtUnit2Fact] AS INT)) END END ELSE SUM([r].[mtQty]) END AS [mtQty],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR((CAST(SUM([r].[mtQty]) AS INT) % CAST([mt].[mtUnit3Fact] AS INT)) / (CASE WHEN [mt].[mtUnit2Fact] <> 0 THEN [mt].[mtUnit2Fact] ELSE 1 END)/*[mt].[mtUnit2Fact]*/) END END ELSE SUM([r].[Qnt2]) END AS [Qnt2],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR(SUM([r].[mtQty]) / (CASE WHEN [mt].[mtUnit3Fact] <> 0 THEN [mt].[mtUnit3Fact] ELSE 1 END)/*[mt].[mtUnit3Fact]*/) END ELSE SUM([r].[Qnt3]) END AS [Qnt3],
			SUM([r].[APrice]) AS [APrice],
			[r].[stLevel],
			[r].[ClassPtr],
			[r].[id],
			[r].[MtGroup],
			[r].[RecType],
			[r].[grLevel],
			[r].[mtUnitFact]
		FROM [#r] AS [r]
		LEFT JOIN vwMt AS [mt] ON [mt].[mtGUID] = [r].[mtNumber]
		GROUP BY
			[r].[StoreGUID],
			[r].[mtNumber],
			[r].[stLevel],
			[r].[ClassPtr],
			[r].[id],
			[r].[MtGroup],
			[r].[RecType],
			[r].[grLevel],
			[r].[mtUnitFact],
			[mt].[mtUnit2Fact],
			[mt].[mtUnit3Fact]
		HAVING COUNT(*) > 1 
		UNION ALL 
		SELECT
			[r].[StoreGUID],
			[r].[mtNumber],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR((CAST(SUM([r].[mtQty]) AS INT) % CAST([mt].[mtUnit3Fact] AS INT)) % CAST([mt].[mtUnit2Fact] AS INT)) END END ELSE SUM([r].[mtQty]) END AS [mtQty],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR((CAST(SUM([r].[mtQty]) AS INT) % CAST([mt].[mtUnit3Fact] AS INT)) / (CASE WHEN [mt].[mtUnit2Fact] <> 0 THEN [mt].[mtUnit2Fact] ELSE 1 END)/*[mt].[mtUnit2Fact]*/) END END ELSE SUM([r].[Qnt2]) END AS [Qnt2],
			CASE @UseUnit WHEN 5 THEN CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE FLOOR(SUM([r].[mtQty]) / (CASE WHEN [mt].[mtUnit3Fact] <> 0 THEN [mt].[mtUnit3Fact] ELSE 1 END)/*[mt].[mtUnit3Fact]*/) END ELSE SUM([r].[Qnt3]) END AS [Qnt3],
			SUM([r].[APrice]),
			[r].[stLevel],
			[r].[ClassPtr],
			[r].[id],
			[r].[MtGroup],
			[r].[RecType],
			[r].[grLevel],
			[r].[mtUnitFact]
		FROM [#r] AS [r]
		LEFT JOIN vwMt AS [mt] ON [mt].[mtGUID] = [r].[mtNumber] 
		GROUP BY
			[r].[StoreGUID],
			[r].[mtNumber],
			[r].[stLevel],
			[r].[ClassPtr],
			[r].[id],
			[r].[MtGroup],
			[r].[RecType],
			[r].[grLevel],
			[r].[mtUnitFact],
			[mt].[mtUnit2Fact],
			[mt].[mtUnit3Fact]
		HAVING COUNT(*) = 1  
	END 

	UPDATE [#MainRes3] SET
		[mtQty] = [r2].[mtQty],
		[Qnt2] = [r2].[Qnt2],
		[Qnt3] = [r2].[Qnt3]
	FROM [#MainRes3] AS r1
	INNER JOIN(	SELECT
					MtGroup,
					SUM([mtQty]) AS mtQty,
					SUM([Qnt2]) AS Qnt2,
					SUM([Qnt3]) AS Qnt3
				FROM [#MainRes3]
				WHERE RecType = 'm'
				GROUP BY MtGroup) AS r2 ON r2.MtGroup = r1.mtNumber
	WHERE RecType = 'g'
		
	
	IF @GroupGUID = 0x0
	BEGIN
		DECLARE @MaxGrpLevel INT
		SELECT @MaxGrpLevel = [grLevel] FROM [#MainRes3]
		DELETE FROM [#MainRes3]
		WHERE RecType = 'g' AND grLevel < @MaxGrpLevel
	END
	ELSE
	BEGIN
		DELETE FROM [#MainRes3]
		WHERE (RecType = 'g' AND grLevel > @GroupLevel AND @GroupLevel <> 0)
	END

	--select * from #MainRes3	
	-- Fill #MatGrp table with the names of materials and groups according to @lang value 0: Arabic, other:Latin
	CREATE TABLE #MatGrp (mtGuid [UNIQUEIDENTIFIER], mtCode VARCHAR(250), mtName VARCHAR(250) COLLATE Arabic_CI_AI)
	INSERT INTO #MatGrp
	SELECT
		mt.mtGuid AS mtGuid,
		mt.mtCode AS mtCode,
		ISNULL(CASE @IsArabic WHEN 1 THEN mt.mtName ELSE mt.mtLatinName END, mt.mtName) AS mtName
	FROM vwMt AS mt
	UNION ALL
	SELECT
		gr.grGUID AS mtGuid,
		gr.grCode AS mtCode,
		ISNULL(CASE @IsArabic WHEN 1 THEN gr.grName ELSE gr.grLatinName END, gr.grName) AS mtName
	FROM vwGr AS gr
	
	-- Fill #stList table with the names of materials and groups according to @IsArabic value 1: Arabic, other:Latin
	CREATE TABLE #stList (stGuid [UNIQUEIDENTIFIER], stCode VARCHAR(250), stName VARCHAR(250) COLLATE ARABIC_CI_AI)
	INSERT INTO #stList
	SELECT
		[st].[stGuid] AS stGuid,
		[st].[stCode] AS stCode,
		ISNULL(CASE @IsArabic WHEN 1 THEN [st].[stName] ELSE [st].[stLatinName] END, [st].[stName]) AS [stName]
	FROM vwSt AS st
	
	--- return result sets 
	--The following IF-Statement is not used because showing just-groups, just-materials or groups-with-materials will be done in RDL  
	/*IF (@ShowGroups = 2) 
		   DELETE [#MainRes3] WHERE [RecType] = 'm'*/
		   
	DECLARE @FldStr [VARCHAR](3000),
			@SqlStr [VARCHAR](4000),
			@Str [VARCHAR](3000)

	SET @FldStr = ''
	SET @Str = '[r].[StoreGUID] AS [StorePtr], [r].[mtNumber]'
	SET @Str = @Str + ' ,[r].[mtQty] AS [Qnt]'
	SET @Str = @Str + ' ,[Qnt2], [Qnt3], [v_mt].[MtUnit2], [v_mt].[MtUnit3]'
	SET @Str = @Str + ' ,[r].[APrice] AS [mtPrice], [r].[APrice] * [r].[mtQty] AS [APrice]'
	SET @Str = @Str + ' ,ISNULL(CASE ' + CAST(@IsArabic AS VARCHAR(1)) + ' WHEN 1 THEN [v_mt].[grName] ELSE [v_mt].[grLatinName] END, [v_mt].[grName]) AS [grName]'
	SET @Str = @Str + ' ,ISNULL([v_mt].[grCode],' + '''' + '''' +') AS [grCode]'
	SET @Str = @Str + ' ,[v_mt].[mtDefUnitFact]'
	
	IF @SHOWGROUPS > 0 
	BEGIN
		IF @ShowProductUnitFactor = 1
			SET @Str = @Str + ' ,[mtUnitFact]'
	END 
	ELSE
	BEGIN
		IF @UseUnit = 0 
			SET @Str = @Str + ' ,CASE [mtUnitFact] WHEN 0 THEN 1 ELSE [mtUnitFact] END AS [mtUnitFact]' 
		IF @UseUnit = 1  
			SET @Str = @Str + ' ,CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS [mtUnitFact]' 
		IF @UseUnit = 2  
			SET @Str = @Str + ' ,CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS [mtUnitFact]' 
		IF @UseUnit = 3  
			SET @Str = @Str + ' ,[mtDefUnitFact] AS [mtUnitFact]' 
	END

	DECLARE @Prefix [VARCHAR](10) 
	SET @Prefix = ' v_mt.' 
	
	
	SELECT @FldStr = [dbo].[fnGetMatFldsStr]( @Prefix, '33431551') 

	SET @Str = @Str + ',' + @FldStr  
	SET @Str = @Str + ' [v_mt].[mtUnit2Fact], [v_mt].[mtUnit3Fact], ISNULL([v_mt].[mtDefUnitName],'+''''+''''+') AS [mtDefUnitName]'

	IF @ShowGroups > 0
	BEGIN
		SET @Str = @Str + ' ,[mt].[mtCode]'
		SET @Str = @Str + ' ,[mt].[mtName]'
		SET @Str = @Str + ' ,[r].[MtGroup] '
	END
	
	ELSE
	BEGIN
		SET @Str = @Str + ' ,[mt].[mtCode]'
		SET @Str = @Str + ' ,[mt].[mtName]'
		SET @Str = @Str + ' ,[v_mt].[MtGroup]'  
	END

	-------------------------- 
	SET @Str = @Str + ' ,CAST(0x0 AS [UNIQUEIDENTIFIER]) AS [GroupParent]'  
	IF @ShowGroups > 0  
	BEGIN  
		SET @Str = @Str + ' ,[RecType]'  
		SET @Str = @Str + '	,[r].[grLevel]'
	END
	ELSE
	BEGIN
		SET @Str = @Str + ' ,''m'' AS [RecType]'
		SET @Str = @Str + '	,0 AS [grLevel]'
	END

	--IF (@StoreLevel > 1) AND @DetailsStores = 1
	SET @Str = @Str + ' ,ISNULL([StLevel], 0) AS [STLevel]'

	--IF @DetailsStores = 1
	SET @Str = @Str + ' ,ISNULL([st].[StCode], '''') AS stCode'
	SET @Str = @Str + ' ,ISNULL([st].[StName], '''') AS stName'
		 
	SET @Str = @Str + ' ,[ClassPtr]'
			
	SET @Str = @Str + ' ,[tree].[path] ,' + CAST(@IsFullResult AS VARCHAR(250)) + ' AS IsFullResult '

	SET @SqlStr = 'SELECT ' + @Str

	------------------------------------------------------------------------------------------------------  
	SET @SqlStr = @SqlStr + ' FROM'
	
	IF @ShowGroups > 0 
		   SET @SqlStr = @SqlStr + ' [#MainRes3] AS [r] LEFT ' 
	ELSE 
		   SET @SqlStr = @SqlStr + ' [#R] AS [r] INNER '
		   
	SET @SqlStr = @SqlStr + ' JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID]'
	SET @SqlStr = @SqlStr + ' INNER JOIN [fnGetMaterialsTree]() [tree] on [tree].[guid] = [r].[mtNumber]'
	SET @SqlStr = @SqlStr + ' INNER JOIN [#MatGrp] AS [mt] ON [r].[mtNumber] = [mt].[mtGuid]'
	SET @SqlStr = @SqlStr + ' LEFT JOIN [#stList] AS [st] ON [r].[StoreGUID] = [st].[stGuid]'
	--Returning just materials, because grouping will be done in RDL
	SET @SqlStr = @SqlStr + ' WHERE [r].[RecType] = ''m'' ' 
	-------------------------------------------------------------------------------------------------------  
	SET @SqlStr = @SqlStr + ' ORDER BY [tree].[path],'
	
	IF @SortType = 3 AND @DetailsStores = 1 AND @StoreLevel <= 1 
		SET @SqlStr = @SqlStr + ' [StName], [StCode]'
		   
	ELSE IF @SortType = 3 AND @DetailsStores = 1 AND @StoreLevel > 1 
		SET @SqlStr = @SqlStr + ' [St1].[Path]'  
		
	ELSE IF @SortType = 2  
	BEGIN
		IF @ShowGroups = 0
			SET @SqlStr = @SqlStr + ' [v_mt].[mtName]'
		ELSE
			SET @SqlStr = @SqlStr + ' [mt].[mtName]'
	END
	
	ELSE IF @SortType = 1  
	BEGIN
		IF @ShowGroups = 0
			SET @SqlStr = @SqlStr + ' [v_mt].[mtCode]' 
		ELSE
			SET @SqlStr = @SqlStr + ' [mt].[mtCode]'   
	END
	
	ELSE IF  @SortType = 0 -- By Mat Input  
		SET @SqlStr = @SqlStr + ' [v_mt].[mtNumber]'
		
	ELSE IF  @SortType = 4 -- By Mat Latin Name  
		SET @SqlStr = @SqlStr + ' [v_mt].[mtLatinName]'
		
	ELSE IF  @SortType = 5 -- By Mat Type  
		SET @SqlStr = @SqlStr + ' [v_mt].[mtType]'
		
	ELSE IF  @SortType = 6 -- By Mat Specification   
		SET @SqlStr = @SqlStr + ' [v_mt].[mtSpec]'
		
	ELSE IF  @SortType = 7 -- By Mat Color  
		SET @SqlStr = @SqlStr + ' [v_mt].[mtColor]'
		
	ELSE IF  @SortType = 8 -- By Mat Orign 
		SET @SqlStr = @SqlStr + ' [v_mt].[mtOrigin]'
		
	ELSE IF  @SortType = 9 -- By Mat Magerment 
		SET @SqlStr = @SqlStr + ' [v_mt].[mtDim]'
		
	ELSE IF @SortType = 10-- By Mat COMPANY 
		SET @SqlStr = @SqlStr + ' [v_mt].[mtCompany]'
		
	ELSE IF @SortType = 11-- By Mat Pos 
		SET @SqlStr = @SqlStr + ' [v_mt].[mtPos]'
		
	ELSE  -- By Mat BARCOD 
		SET @SqlStr = @SqlStr + ' [v_mt].[mtBarCode]' 

	IF @SortType <> 3 AND @DetailsStores = 1 AND @StoreLevel > 1 
		SET @SqlStr = @SqlStr + ' ,[id]'
		
	IF (@ClassDetails > 0) 
		SET @SqlStr = @SqlStr + ' ,[ClassPtr]'
		
	EXECUTE (@SqlStr)	
	
	--prcFinalize_Environment 
	EXEC [prcFinilize_Environment] '[repInventoryChecklist]'
	
/*
prcConnections_add2 '„œÌ—'
EXEC [repInventoryChecklist] '00000000-0000-0000-0000-000000000000', '1B42470F-4196-404A-BC27-D811C837C684', 0, '00000000-0000-0000-0000-000000000000', 0, '00000000-0000-0000-0000-000000000000', '', '1/1/2009 0:0:0.0', '3/7/2010 23:59:28.29', '47d90150-4405-4bfc-9f9d-910d3853431c', 1.000000, 128, 120, 3, 0, 1, 1, 1, 1, 1, -1, 0, 1, 1, 1, 33431551, 1, 1, 1, 1, 1, 1, 1, 1, 1, 'A9C27E67-B55A-4C62-9C30-376FC420352C', 'ar'
*/
#########################################################
CREATE PROCEDURE ARWA.repHorizontalInventory
	@StartDate 				DATETIME,
	@EndDate 				DATETIME,
	@ProductGUID 			UNIQUEIDENTIFIER,
	@ProductDescription		VARCHAR(250),
	@GroupGUID 				UNIQUEIDENTIFIER,
	@GroupDescription		VARCHAR(250),
	@StoreGUID 				UNIQUEIDENTIFIER = 0x0,
	@StoreDescription		VARCHAR(250),
	@JobCostGUID 			UNIQUEIDENTIFIER,
	@JobCostDescription		VARCHAR(250),
	@SourcesTypes			VARCHAR(MAX),
    @StoreLevel				INT = 0,
    @PriceType 				INT,
	@PricePolicy 			INT,
	@CurrencyGUID 			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@ShowEmptyProducts 		BIT,
	@ShowBalancedProducts	BIT,
	@ShowGroups 			BIT,
	@ShowPrice				BIT,
	@ShowEmptyStore			BIT,
	@ShowStockProduct		BIT,
	@ShowServiceProduct		BIT,
	@UseUnit				INT = 1,
	@ProductConditions		VARCHAR(MAX) = '',
	@GroupLevel				INT = 0,
	@Lang					VARCHAR(100) = 'ar',
	@UserGUID				UNIQUEIDENTIFIER,
	@BranchMask				BIGINT = -1
AS  
	--«·Ã—œ «·√›ﬁÌ
	SET NOCOUNT ON
	
	EXEC [prcInitialize_Environment] @UserGUID, 'repHorizontalInventory',@BranchMask
	
	DECLARE @Types TABLE(
		[GUID]	VARCHAR(100), 
		[Type]	VARCHAR(100))

	CREATE TABLE [#SecViol](
		[Type] INT, 
		[Cnt] INT)
		
	CREATE TABLE [#MatTbl](
		[MatGUID] UNIQUEIDENTIFIER,
		[mtSecurity] INT)
		
	CREATE TABLE [#StoreTbl](
		[StoreGUID] UNIQUEIDENTIFIER,
		[Security] INT)
		
	CREATE TABLE [#BillsTypesTbl](
		[TypeGuid] UNIQUEIDENTIFIER,
		[UserSecurity] INT,
		[UserReadPriceSecurity] INT)
		
	CREATE TABLE [#CostTbl](
		[CostGUID] UNIQUEIDENTIFIER,
		[Security] INT)
	DECLARE @MaterialType INT = -1
	
	IF @ShowStockProduct = 1 AND @ShowServiceProduct = 0
		SET @MaterialType = 0
	ELSE
		IF @ShowStockProduct = 0 AND @ShowServiceProduct = 1
			SET @MaterialType = 1
		ELSE
			IF @ShowStockProduct = 1 AND @ShowServiceProduct = 1 
				SET @MaterialType = 256
				
	DECLARE @CurrencyVal FLOAT
	SELECT @CurrencyVal = [dbo].[fnGetCurVal](@CurrencyGUID, GETDATE())
	
	INSERT INTO @Types SELECT * FROM [fnParseRepSources](@SourcesTypes)
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@ProductGUID, @GroupGUID, @MaterialType, 0x0, @ProductConditions
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@JobCostGUID
	INSERT INTO [#BillsTypesTbl]
	SELECT
		[bt].btGUID, 
		[dbo].[fnGetUserBillSec_Browse](@UserGUID, [bt].btGUID), 
		[dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, [bt].btGUID) 
	FROM 
		[vwBt] [bt]
		INNER JOIN @Types t ON t.[GUID] = CAST([bt].btGUID AS VARCHAR(100))
		
	CREATE CLUSTERED INDEX [hrnvInd] ON [#MatTbl]([MatGUID])
	CREATE CLUSTERED INDEX [hrnvInd] ON [#StoreTbl]([StoreGUID])
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) > 0
		UPDATE [#billsTypesTbl] SET [userSecurity] = [dbo].[fnGetMaxSecurityLevel]()
	
	IF [dbo].[fnIsAdmin](ISNULL(@UserGUID, 0x0)) = 0
	BEGIN
		SELECT [Guid] INTO [#GR] FROM [fnGetGroupsList](@GroupGUID)
		
		DELETE [r]
		FROM
			[#GR] AS [r]
			INNER JOIN fnGroup_HSecList() AS [f] ON [r].[GUID] = [f].[GUID]
		WHERE
			[f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
			
		DELETE [m] 
		FROM 
			[#MatTbl] AS [m]
			INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid]
		WHERE 
			[mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid)
			OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr])
		IF @@ROWCOUNT > 0
			INSERT INTO [#SecViol] values(7, @@ROWCOUNT)
	END
	
	CREATE TABLE [#MainResult]( 
		[MaterialGUID]			UNIQUEIDENTIFIER, 
		[Quantity]				FLOAT DEFAULT 0, 
		[Price]					FLOAT DEFAULT 0, 
		[MaterialUnity]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialUnit2]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialUnit3]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialDefUnitFact]	FLOAT,
		[MaterialName]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialLatinName]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialCode]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialUnit2Fact]		FLOAT, 
		[MaterialUnit3Fact]		FLOAT, 
		[MaterialBarCode]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialSpec]			VARCHAR(1000) COLLATE ARABIC_CI_AI, 
		[MaterialDim]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialOrigin]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialPos]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialCompany]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialColor]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialProvenance]	VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialQuality]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialModel]			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialBarCode2]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialBarCode3]		VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[MaterialType]			INT, 
		[MaterialDefUnitName]	VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[GroupGUID]				UNIQUEIDENTIFIER,
		[GroupCode]				VARCHAR(255) COLLATE ARABIC_CI_AI,
		[GroupName]				VARCHAR(255) COLLATE ARABIC_CI_AI,
		[GroupLevel]			INT,
		[StoreGUID]				UNIQUEIDENTIFIER,
		[StoreCode]				VARCHAR(255) COLLATE ARABIC_CI_AI,
		[StoreName]				VARCHAR(255) COLLATE ARABIC_CI_AI,
		[StoreLevel]			INT,
		[StoreSecurity]			INT)
		
	CREATE TABLE [#t_Prices]( 
		[mtNumber] 	UNIQUEIDENTIFIER, 
		[APrice] 	FLOAT)
		
	DECLARE @SourceGUID	UNIQUEIDENTIFIER
	SET	 @SourceGUID  = NEWID()
		
	IF (@ShowPrice = 1)
	BEGIN 
		IF @PricePolicy = -1
			SELECT @PricePolicy = Value FROM op000 WHERE Name = 'AmnCfg_DefaultPrice'
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
		BEGIN 
			EXEC [prcGetLastPrice] @StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID, -1,	@CurrencyGUID, @SourceGUID, 0, 0 
		END 
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
		BEGIN 
			EXEC [prcGetMaxPrice] @StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID, -1,	@CurrencyGUID, @CurrencyVal, @SourceGUID, 0, 0 
		END 
		ELSE IF @PriceType = 2 AND @PricePolicy = 121  -- COST And AvgPrice NO STORE DETAILS 
		BEGIN 
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID, -1, @CurrencyGUID, @CurrencyVal, @SourceGUID,	0, 0 
		END 
		ELSE IF @PriceType = -1 
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl] 
		 
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
		BEGIN 
			EXEC [prcGetLastPrice] @StartDate , @EndDate , @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID, -1,	@CurrencyGUID, @SourceGUID, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
		END 
		ELSE IF @PriceType = 2 AND @PricePolicy = 125 
			EXEC [prcGetFirstInFirstOutPrise] @StartDate , @EndDate,@CurrencyGUID	 
		ELSE 
		BEGIN 
			EXEC [prcGetMtPrice] @ProductGUID,	@GroupGUID, -1, @CurrencyGUID, @CurrencyVal, @SourceGUID, @PriceType, @PricePolicy, 0, @UseUnit 
		END 
	END 
	
	CREATE TABLE [#t_Qtys](
		[mtNumber] 	UNIQUEIDENTIFIER,  
		[Qnt] 		FLOAT,  
		[Qnt2] 		FLOAT,  
		[Qnt3] 		FLOAT,  
		[StorePtr]	UNIQUEIDENTIFIER)
	  
	IF @MaterialType >= 3 
		SET @MaterialType = -1 
	EXEC [prcGetQnt] @StartDate, @EndDate, @ProductGUID, @GroupGUID, @StoreGUID, @JobCostGUID, @MaterialType, 1, @SourceGUID, 0
	 
	CREATE TABLE [#t_QtysWithEmpty](
		[mtNumber] 	UNIQUEIDENTIFIER,  
		[Qnt] 		FLOAT,
		[Qnt2] 		FLOAT,
		[Qnt3] 		FLOAT,
		[StorePtr]	UNIQUEIDENTIFIER)
		
	IF @ShowEmptyProducts = 0  
		INSERT INTO [#t_QtysWithEmpty] SELECT * FROM [#t_Qtys] WHERE @ShowBalancedProducts = 1 OR ABS([Qnt])> [dbo].[fnGetZeroValueQTY]() 
	ELSE
		INSERT INTO [#t_QtysWithEmpty]
			SELECT
				[mt].[MatGUID],
				ISNULL([q].[Qnt], 0),
				ISNULL([q].[Qnt2],0),
				ISNULL([q].[Qnt3],0),
				ISNULL([q].[StorePtr], 0x0)
			FROM  
				[#MatTbl] AS [mt] LEFT JOIN [#t_Qtys] AS [q] ON [mt].[MatGUID] = [q].[mtNumber]  
			WHERE @ShowBalancedProducts = 1  OR ABS([q].[Qnt]) > 0
	
	INSERT INTO [#MainResult]
		SELECT
			[q].[mtNumber],
			[q].[Qnt],
			ISNULL([p].[APrice],0),
			[mtUnity],
			[mtUnit2],
			[mtUnit3],
			CASE [mtDefUnit] 
				WHEN 2 THEN [mtUnit2Fact] 
				WHEN 3 THEN [mtUnit3Fact] 
			ELSE 1 END,
			CASE @Lang
				WHEN 'ar' THEN [mtName]
				ELSE CASE [mtLatinName]
						WHEN '' THEN [mtName]
						ELSE [mtLatinName]
					END
			END,
			[mtLatinName],
			[mtCode],
			[mtUnit2Fact],
			[mtUnit3Fact],
			[mtBarCode],
			[mtSpec],
			[mtDim],
			[mtOrigin],
			[mtPos],
			[mtCompany],
			[mtColor],
			[mtProvenance],
			[mtQuality],
			[mtModel],
			[mtBarCode2],
			[mtBarCode3],
			[mtType],
			CASE [mtDefUnit] 
				WHEN 2 THEN [mtUnit2] 
				WHEN 3 THEN [mtUnit3] 
				ELSE [mtUnity] 
			END,
			[mtGroup],
			[grCode],
			CASE @Lang
				WHEN 'ar' THEN [grName]
				ELSE CASE grLatinName
						WHEN '' THEN [grName]
						ELSE grLatinName
					END
			END,
			[Grfn].[Level],
			st.stGUID,
			st.stCode,
			CASE @Lang
				WHEN 'ar' THEN st.stName
				ELSE CASE [st].stLatinName
						WHEN '' THEN st.stName
						ELSE [st].stLatinName
					END
			END,
			st.[Level],
			st.[Security]
		FROM
			[#t_QtysWithEmpty] AS [q]
			INNER JOIN [vwMtGr] AS [mt] ON [mt].[mtGuid] = [q].[mtNumber]
			INNER JOIN [dbo].[fnGetGroupsListByLevel](@GroupGUID, @GroupLevel) AS [Grfn] ON [Grfn].[GUID] = [mt].[grGUID]
			INNER JOIN (SELECT [st].[stGUID], [st].[stCode], [st].[stName], [st].stLatinName, [stTbl].[Security], [stFn].[Level] 
						FROM vwSt st 
						INNER JOIN [dbo].[fnGetStoresListByLevel](@StoreGUID, @StoreLevel) AS [Stfn] ON [Stfn].[GUID] = [st].[stGUID] INNER JOIN #StoreTbl stTbl ON stTbl.StoreGUID = Stfn.[GUID]) [st] ON st.stGUID = [q].[StorePtr]
			LEFT JOIN [#t_Prices] AS [p] ON [p].[mtNumber] = [mt].[mtGuid]
			
	EXEC [prcCheckSecurity] @UserGUID = @UserGUID
	
	DECLARE @NumOfSecViolated BIT
	SET @NumOfSecViolated = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
	
	SELECT *,@NumOfSecViolated AS NumOfSecViolated  FROM #MainResult
	
	EXEC [prcFinilize_Environment] 'repHorizontalInventory'
#########################################################
CREATE PROCEDURE ARWA.repGetAges_ce
		@AccountGUID						[UNIQUEIDENTIFIER],							--«·Õ”«»
		@JobCostGUID						[UNIQUEIDENTIFIER],							--„—ﬂ“ «·ﬂ·›…
		@UntilDate							[DATETIME],									--Õ Ï  «—ÌŒ
		@DebitCreditFlag					tinyint,									-- 1 Debit, 2 Credit, 3 Debit and Credit
		@IsDetailed							[BIT],										--⁄—÷  ﬁ—Ì—  ›’Ì·Ì
		@NumOfPeriods						[INT],										--⁄œœ «·› —« 
		@PeriodLength						[INT],										--ÿÊ· «·› —…
		@CurrencyGUID						[UNIQUEIDENTIFIER],							--«·⁄„·…
		@UserGUID							[UNIQUEIDENTIFIER],							--«·„” Œœ„
		@ShowParent							[BIT] = 0,									--⁄—÷ √’· «·”‰œ
		@ShowCustomersOnly					[BIT] = 0,									--⁄—÷ «·“»«∆‰ ›ﬁÿ
		--@VeiwCFlds						VARCHAR (MAX) = '', 					-- check veiwing of Custom Fields  
		@HandlingCost						BIT = 0,									--„⁄«·Ã… „—ﬂ“ «·ﬂ·›…
		@SourcesTypes						VARCHAR(MAX),								--„’«œ— «· ﬁ—Ì—							
		@GroupingByCost						bit = 0,									-- Ã„»⁄ Õ”» „—ﬂ“ «·ﬂ·›…
		@HideCosts							BIT = 0,									--≈Œ›«¡ „—«ﬂ“ «·ﬂ·›
		@CustomersCondition					VARCHAR (MAX) = '',							--‘—Êÿ «·“»«∆‰
		@BranchMask							BigInt,										--›—Ê⁄ «„” Œœ„
		@Lang								VarChar(10) = 'ar',							--«··€…				
		@ShowNotes							BIT = 0,									--≈ŸÂ«— «·»Ì«‰																
		---------------------------≈ŸÂ«— ÕﬁÊ· «·“»Ê‰-----------------------------------------
		@ShowCustomerNumber					BIT = 0,									--≈ŸÂ«— —ﬁ„ «·»ÿ«ﬁ…																
		@ShowCustomerPrefix					BIT = 0,									--≈ŸÂ«— «··ﬁ»																
		@ShowCustomerLatinName				BIT = 0,									--≈ŸÂ«— «·«”„ «··« Ì‰Ì																
		@ShowCustomerSuffix					BIT = 0,									--≈ŸÂ«— «··«Õﬁ…																
		@ShowCustomerNationality			BIT = 0,									--≈ŸÂ«— «·Ã‰”Ì…																
		@ShowCustomerPhone1					BIT = 0,									--≈ŸÂ«— «·Â« ›1																
		@ShowCustomerPhone2					BIT = 0,									--≈ŸÂ«— «·Â« ›2																
		@ShowCustomerFax					BIT = 0,									--≈ŸÂ«— «·›«ﬂ”																
		@ShowCustomerTelex					BIT = 0,									--≈ŸÂ«— «· ·ﬂ”																
		@ShowCustomerMobile					BIT = 0,									--≈ŸÂ«— «·„Ê»«Ì·																
		@ShowCustomerPager					BIT = 0,									--≈ŸÂ«— «·‰œ«¡																
		@ShowCustomerNotes					BIT = 0,									--≈ŸÂ«— «·„·«ÕŸ« 																
		@ShowCustomerEmail					BIT = 0,									--≈ŸÂ«— «·»—Ìœ «·«ﬂ —Ê‰Ì																
		@ShowCustomerWebSite				BIT = 0,									--≈ŸÂ«— „Êﬁ⁄ «·«‰ —‰ 																
		@ShowCustomerDiscountPercentage		BIT = 0,									--≈ŸÂ«— ‰”»… «·Õ”„																
		@ShowCustomerCountry				BIT = 0,									--≈ŸÂ«— «·œÊ·…																
		@ShowCustomerCity					BIT = 0,									--≈ŸÂ«— «·„œÌ‰…																
		@ShowCustomerRegion					BIT = 0,									--≈ŸÂ«— «·„‰ÿﬁ…																
		@ShowCustomerStreet					BIT = 0,									--≈ŸÂ«— «·‘«—⁄																
		@ShowCustomerAddress				BIT = 0,									--≈ŸÂ«— «·⁄‰Ê«‰ « ›’Ì·Ì																
		@ShowCustomerZIPCode				BIT = 0,									--≈ŸÂ«— «·—„“ «·»—ÌœÌ																
		@ShowCustomerPOBox					BIT = 0,									--≈ŸÂ«— ’‰œÊﬁ «·»—Ìœ																
		@ShowCustomerCertificate			BIT = 0,									--≈ŸÂ«— «·‘Â«œ« 																
		@ShowCustomerJob					BIT = 0,									--≈ŸÂ«— «·⁄„·																
		@ShowCustomerJobNature				BIT = 0,									--≈ŸÂ«— ‰Ê⁄ «·⁄„·																
		@ShowCustomerField1					BIT = 0,									--≈ŸÂ«— «·Õﬁ·1																
		@ShowCustomerField2					BIT = 0,									--≈ŸÂ«— «·Õﬁ·2																
		@ShowCustomerField3					BIT = 0,									--≈ŸÂ«— «·Õﬁ·3																
		@ShowCustomerField4					BIT = 0,									--≈ŸÂ«— «·Õﬁ·4																
		@ShowCustomerDateOfBirth			BIT = 0,									--≈ŸÂ«—  «—ÌŒ «· Ê·œ																
		@ShowCustomerGender					BIT = 0,									--≈ŸÂ«— «·Ã‰”																
		@ShowCustomerHobbies				BIT = 0 									--≈ŸÂ«— «·ÂÊ«Ì« 																
		
AS   
	SET NOCOUNT ON   
	
	--Session-Connection
	EXEC [prcSetSessionConnections] @UserGUID, @BranchMask
	
	
	--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
	DECLARE   
		@c_ac CURSOR,  
		@dcType  tinyint,  
		@acGuid [UNIQUEIDENTIFIER],  
		@acSumOfOtherSide [FLOAT],  
		@CostPtr	UNIQUEIDENTIFIER  
	DECLARE    
		@c_en CURSOR,  
		@en_dcType  VARCHAR(1),  
		@enDebitCredit [FLOAT],  
		@ceGuid [UNIQUEIDENTIFIER],  
		@enDate [DATETIME],  
		@Notes [VARCHAR](1000),  
		@enNumber [INT],  
		@ceNumber [INT],@ID INT  
	-----------------------------------------------------------   
	DECLARE @AccTbl TABLE( [Guid] [UNIQUEIDENTIFIER])   
	INSERT INTO @AccTbl SELECT [GUID] FROM [dbo].[fnGetAccountsList]( @AccountGUID, DEFAULT)   
	IF @ShowCustomersOnly > 0   
		DELETE @AccTbl WHERE [Guid] NOT IN (SELECT [AccountGuid] FROM [cu000])   
	DECLARE @STR VARCHAR(1000),@HosGuid [UNIQUEIDENTIFIER]--,@UserGUID [UNIQUEIDENTIFIER]  
	SET @HosGuid = NEWID()  
	--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()       
	-----------------------------------------------------------   
	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER])   
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @JobCostGUID)    
	IF ISNULL( @JobCostGUID, 0x0) = 0x0     
		INSERT INTO @Cost_Tbl VALUES(0x0)    
	-----------------------------------------------------------  
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])      
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])      
	-----------------------------------------------------------   
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#t_Result](   
			[SerialNumber] INT IDENTITY,
			dcType  TINYINT,  
			[Account] [UNIQUEIDENTIFIER],    
			[Value] [FLOAT],    
			[EntryNum] [UNIQUEIDENTIFIER],   
			[enNumber] [INT],   
			[ceNumber] [INT],   
			[Date] [DATETIME],    
			[Remaining] [FLOAT],    
			[Age] [INT],    
			[Notes] [VARCHAR](1000) COLLATE ARABIC_CI_AI,   
			[ParentGuid] [UNIQUEIDENTIFIER] DEFAULT 0X00,   
			[ParentNum]	[INT] DEFAULT 0,   
			[ParentType]	[INT] DEFAULT 0,   
			[ParentTypeGUID] [UNIQUEIDENTIFIER] DEFAULT 0X00,   
			[CostGuid]			UNIQUEIDENTIFIER,
			[ParentTypeName]	Varchar(50) COLLATE ARABIC_CI_AI DEFAULT ''   
			)   
	   
	------------------------------------------------------------------   
	CREATE TABLE [#TmpRes](    
		[ceGuid]		[UNIQUEIDENTIFIER],    
		[enGuid]		[UNIQUEIDENTIFIER],    
		[enNumber]		[INT],   
		[enAccount]		[UNIQUEIDENTIFIER],      
		[enDebit]		[FLOAT],     
		[enCredit] 		[FLOAT],    
		[enCurrencyPtr] [UNIQUEIDENTIFIER],    
		[enCurrencyVal] [FLOAT],    
		[enDate]		[DATETIME],    
		[ceSecurity] 	[INT],     
		[acSecurit] 	[INT],   
		[ceNumber]		[INT],    
		[enNotes]		[VARCHAR](255) COLLATE ARABIC_CI_AI,   
		[enCostPoint] [UNIQUEIDENTIFIER])    
	--------------------------------------------------------------------------------------  
	--S o u r c e                      „’«œ— «· ﬁ—Ì—   
	--------------------------------------------------------------------------------------
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
	--INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID--@UserID 
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] = 5
			
	--INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl] 
									
	--INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] =  1
	
	
	--New way For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 3
	
	--New way For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 4
	  
	---------------------------------------------------------------------------------------------------------------   
	SELECT [c].[Guid],[Security] AS [acSecurity] INTO [#ACC] FROM @AccTbl AS [c] INNER JOIN [ac000] AS [AC] ON [ac].[Guid] = [c].[Guid]    
	-------------------------------------------------------------------------------------- 
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT])  
	IF (@CustomersCondition <> '') 
	BEGIN  
		INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] 0X00, @AccountGUID,0x00, @CustomersCondition       
		DELETE ac FROM [#ACC] ac  
		LEFT JOIN  
		(SELECT [Accountguid] FROM cu000 cu INNER JOIN  [#Cust] c ON c.Number = cu.Guid) cc  
		ON [Accountguid] = ac.Guid WHERE [Accountguid] IS NULL 
	END 
	-------------------------------------------------------------------------------------- 
	INSERT INTO [#TmpRes]   
		SELECT   
			[ceGUID],   
			[enGuid],    
			[enNumber],   
			[enAccount],   
			[enDebit],    
			[enCredit],    
			[enCurrencyPtr],  
			[enCurrencyVal],  
			[enDate],    
			[ceSecurity],  
			[acSecurity],  
			[ceNumber],   
			[enNotes],  
			[enCostPoint]   
		FROM  
		(			  
			SELECT    
				[en].[ceGUID],   
				[en].[enGuid],    
				[en].[enNumber],   
				[en].[enAccount],    
				[en].[enDebit],    
				[en].[enCredit],    
				[en].[enCurrencyPtr],    
				[en].[enCurrencyVal],    
				[en].[enDate],    
				[en].[ceSecurity],    
				[ac].[acSecurity],    
				[en].[ceNumber],   
				[en].[enNotes],   
				CASE @HandlingCost WHEN 1 THEN [en].[enCostPoint] ELSE 0X00 END   [enCostPoint],  
				CASE WHEN [er].[ParentType] BETWEEN 300 AND 305 THEN @HosGuid  else [cetypeguid] end cetypeguid  
			FROM    
				[vwCeEn] AS [en]    
				INNER JOIN   [#ACC] AS [ac] ON [en].[enAccount] = [ac].[Guid]   
				INNER JOIN @Cost_Tbl AS [Cost] ON [en].[enCostPoint] = [Cost].[GUID]  
				LEFT JOIN ER000 er ON er.entryGuid = [en].[ceGUID]  
			WHERE    
				[en].[enDate] <= @UntilDate    
				AND [en].[ceIsPosted] <> 0 ) A   
			INNER JOIN [#EntryTbl] rv ON a.cetypeguid = rv.[Type]   
		   
		IF EXISTS (SELECT * FROM [Ages000] a INNER JOIN [#TmpRes] b ON [a].[refGuid] = [enGuid] WHERE a.Type = 0)   
		BEGIN   
			UPDATE a SET [enDate] = '1/1/1980' FROM [#TmpRes] a INNER JOIN [Ages000] b ON b.[refGuid] = [enGuid]   
			INSERT INTO [#TmpRes]   
			SELECT    
				[ceGuid],		   
				b.Guid,		   
				[enNumber],		   
				[enAccount],		   
				CASE WHEN [enDebit] > 0 THEN b.Val	ELSE 0 END ,		   
				CASE WHEN  [enCredit] > 0 THEN b.Val ELSE 0	END ,		   
				[b].[CurrencyGuid],    
				[b].[CurrencyVal],    
				b.[Date],	   
				[ceSecurity], 	   
				[acSecurit], 	   
				[ceNumber],		   
				[enNotes],   
				[enCostPoint]		   
			FROM [#TmpRes] a INNER JOIN [Ages000] b ON b.[refGuid] = [enGuid]   
			WHERE [enDate] = '1/1/1980'   
			DELETE [#TmpRes] WHERE [enDate] = '1/1/1980'   
		END   
	-------------------------------------------------------   
	EXEC [prcCheckSecurity] @result = '#TmpRes'   
	  
	CREATE TABLE #AGE  
	(  
		DCTYPE TINYINT,  
		ID INT IDENTITY(1,1),  
		BALANCE FLOAT,  
		[enAccount] UNIQUEIDENTIFIER,  
		ceGuid UNIQUEIDENTIFIER,  
		enDate DATETIME,  
		enNotes VARCHAR(255) COLLATE ARABIC_CI_AI,   
		enNumber INT,  
		ceNumber INT,  
		enCostPoint UNIQUEIDENTIFIER  
	) 
	DECLARE @Cur TABLE ([Date] SMALLDATETIME,[Val] FLOAT) 
	INSERT INTO @Cur  
	SELECT [Date],CurrencyVal FROM mh000 WHERE CurrencyGuid = @CurrencyGUID  
	UNION ALL  
	SELECT '1/1/1980',CurrencyVal FROM my000 WHERE [Guid] = @CurrencyGUID  
	IF (@DebitCreditFlag &0x00001 ) > 0   
	BEGIN  
		INSERT INTO [#AGE]( DCTYPE, BALANCE,enAccount,ceGuid,enDate,enNotes,enNumber,ceNumber,enCostPoint)  
		SELECT    
				0,  
				[enDebit] * Factor BALANCE,   
				[en].[enAccount],    
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber],   
				[enCostPoint]   
			  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurrencyGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate] ORDER BY DATE DESC) END Factor FROM [#TmpRes] )AS [en]   
			WHERE    
				 [en].[enCredit] = 0  
			ORDER BY  
				[enDate],    
				[en].[enNumber],   
				[en].[ceNumber]   
	end  
	if  (@DebitCreditFlag &  0x00002) > 0   
	BEGIN  
		INSERT INTO [#AGE]( DCTYPE, BALANCE,enAccount,ceGuid,enDate,enNotes,enNumber,ceNumber,enCostPoint)  
		SELECT    
				1,  
				[en].[enCredit] * Factor,   
				[en].[enAccount],    
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber],   
				[enCostPoint]   
			  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurrencyGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] )AS [en]   
			WHERE    
				 [en].[enDebit] = 0  
			ORDER BY  
				[enDate],    
				[en].[enNumber],   
				[en].[ceNumber]   
	  
	END  
	CREATE TABLE #CREDIT 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER, 
		[Val] float,Flag BIT 
	) 
	CREATE TABLE #SUMDEBITS 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER, 
		[Val] FLOAT 
	) 
	CREATE TABLE #DEBIT 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER, 
		[Val] float,Flag BIT 
	) 
	CREATE TABLE #SUMCREDTS 
	( 
		[enAccount] UNIQUEIDENTIFIER, 
		[enCostPoint] UNIQUEIDENTIFIER, 
		[Val] FLOAT 
	) 
	IF (@DebitCreditFlag &  0x00001) > 0 	 
		INSERT INTO #CREDIT   
		SELECT    
				 [en].[enAccount],[enCostPoint],   
				SUM([en].[enCredit] * Factor ),0  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurrencyGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] ) AS [en]  where [en].[enCredit] > 0 AND (@DebitCreditFlag &  0x00001) > 0  
			GROUP BY    
				[en].[enAccount],[enCostPoint] 
			--HAVING  SUM([enCredit]-[enDebit]) > 0  
	IF  (@DebitCreditFlag &  0x00002) > 0  
		INSERT INTO #DEBIT 
		SELECT    
				 [en].[enAccount],[enCostPoint],   
				SUM([en].[enDebit] * Factor ),0  
			FROM    
				(SELECT *, 1/ CASE WHEN [enCurrencyPtr]= @CurrencyGUID THEN [enCurrencyVal] ELSE (SELECT TOP 1 [Val] FROM @Cur WHERE [DATE] <= [enDate]  ORDER BY DATE DESC) END Factor FROM [#TmpRes] ) AS [en]  where [en].[enDebit] > 0 AND (@DebitCreditFlag &  0x00002) > 0  
			GROUP BY    
				[en].[enAccount],[enCostPoint] 
			--HAVING  SUM([enDebit] -[enCredit]) > 0  
	DECLARE @dd SMALLDATETIME 
	SELECT @dd = MIN([enDate]) FROM [#TmpRes] 
	SET @dd = DATEADD(mm,1,@dd) 
	WHILE (	@dd <= @UntilDate) 
	BEGIN 
		IF (@DebitCreditFlag &  0x00001) > 0 	 
		BEGIN 
			INSERT INTO #SUMDEBITS  
			SELECT    
					 [en].[enAccount],[enCostPoint],   
					SUM(BALANCE)   
				FROM    
					[#Age] AS [en]  WHERE DCTYPE = 0 AND enDate <= @dd 
				GROUP BY    
					[en].[enAccount], [enCostPoint] 
			UPDATE C SET val = c.val - d.val ,Flag = 1 
			FROM  #CREDIT c   
			INNER JOIN #SUMDEBITS d ON CAST(d.[enAccount] AS VARCHAR(36)) + CAST(d.[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
			WHERE c.val >= d.val  
			DELETE tmp FROM  [#Age] tmp INNER JOIN #CREDIT c  ON CAST(tmp.[enAccount] AS VARCHAR(36)) + CAST(tmp.[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
			WHERE DCTYPE = 0 AND enDate <= @dd AND c.Flag = 1 
			UPDATE #CREDIT SET Flag = 0 WHERE Flag = 1 
			TRUNCATE TABLE #SUMDEBITS 
		END 
		IF (@DebitCreditFlag &  0x00002) > 0 	 
		BEGIN 
			INSERT INTO #SUMCREDTS  
			SELECT    
					 [en].[enAccount],[enCostPoint],   
					SUM(BALANCE)   
				FROM    
					[#Age] AS [en]  WHERE DCTYPE = 1 AND enDate <= @dd 
				GROUP BY    
					[en].[enAccount], [enCostPoint] 
				UPDATE C SET val = c.val - d.val ,Flag = 1 
				FROM  #DEBIT c   
			INNER JOIN #SUMCREDTS d ON CAST(d.[enAccount] AS VARCHAR(36)) + CAST(d.[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
			WHERE c.val >= d.val  
			DELETE tmp FROM  [#Age] tmp INNER JOIN #DEBIT c  ON CAST(tmp.[enAccount] AS VARCHAR(36)) + CAST(tmp.[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
			WHERE DCTYPE = 1 AND enDate <= @dd AND c.Flag = 1 
			UPDATE #DEBIT SET Flag = 0 WHERE Flag = 1 
			TRUNCATE TABLE #SUMCREDTS 
		END 
		SET @dd = DATEADD(mm,1,@dd) 
	END	  
	DELETE #CREDIT WHERE Val <= 0 
	DELETE #DEBIT WHERE Val <= 0 
	SET @c_ac = CURSOR FAST_FORWARD FOR   
			SELECT    
				0, [en].[enAccount],[enCostPoint],   
			val 	   
			FROM  #CREDIT AS [en]  WHERE   val > 0  
		union all  
		SELECT    
				1, [en].[enAccount],[enCostPoint],   
			val 	   
			FROM  #DEBIT AS [en]  WHERE   val > 0  
	------------------------------------------------------------------   
	OPEN @c_ac FETCH NEXT FROM @c_ac INTO @dcType, @acGuid,@CostPtr, @acSumOfOtherSide   
	 		  
	WHILE @@FETCH_STATUS = 0   
	BEGIN  
	------------------------------------------------------------------ 
		-------------------------------------  
		Declare @Tmp FLOAT 
		SELECT @Tmp = ISNULL(SUM(BALANCE), 0) 
		FROM [#AGE] AS [en]   
		WHERE [en].[enAccount] = @acGuid  
		AND (@HandlingCost = 0 OR [enCostPoint] = @CostPtr  )   
		AND [DCTYPE] =@dcType  
		IF (@Tmp < @acSumOfOtherSide) 
			GoTo FetchLabel; 
			------------------------------- 
		------------------------------------------------------------------   
		SET @c_en = CURSOR FAST_FORWARD FOR   
		SELECT  
				[dcType],[ID],   
				BALANCE,   
				[en].[ceGuid],    
				[en].[enDate],    
				[en].[enNotes],   
				[en].[enNumber],   
				[en].[ceNumber]   
			FROM    
				[#AGE] AS [en]   
			WHERE    
				[en].[enAccount] = @acGuid AND (@HandlingCost = 0 OR [enCostPoint] = @CostPtr  )  and [DCTYPE] =  @dcType  
		ORDER BY    
			[ID]  
	   
		------------------------------------------------------------------   
		OPEN @c_en FETCH NEXT FROM @c_en INTO @en_dcType, @ID,@enDebitCredit, @ceGuid,@enDate, @Notes, @enNumber ,@ceNumber   
		WHILE @@FETCH_STATUS = 0   
		BEGIN 
			IF @acSumOfOtherSide < @enDebitCredit   
			BEGIN   
				IF @acSumOfOtherSide > 0   
				BEGIN   
					SET @acSumOfOtherSide = @acSumOfOtherSide - @enDebitCredit   
					INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid])   
						VALUES (@en_dcType, @acGuid, @enDebitCredit, @ceGuid, @enNumber,@ceNumber, @enDate, -@acSumOfOtherSide, DATEDIFF(d, @enDate, @UntilDate), @Notes ,@CostPtr)   
				END   
				ELSE   
				BEGIN   
				INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid])   
					SELECT [dcType], [enAccount] ,BALANCE,[ceGuid],[enNumber],[ceNumber],[enDate],BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[enCostPoint]    
					FROM #AGE [en] WHERE   
						[en].[enAccount] = @acGuid   
						AND [ID] >= @ID  
						AND [enCostPoint] = @CostPtr  
						and dcType =  @dcType  
					BREAK   
				END   
			END   
			ELSE   
				SET @acSumOfOtherSide = @acSumOfOtherSide - @enDebitCredit   
			FETCH NEXT FROM @c_en INTO @en_dcType, @ID, @enDebitCredit, @ceGuid,@enDate, @Notes, @enNumber ,@ceNumber   
		END  
		CLOSE @c_en 
		DEALLOCATE @c_en
		 
FetchLabel:  
		FETCH NEXT FROM @c_ac INTO @dcType, @acGuid, @CostPtr, @acSumOfOtherSide   
	END   
	CLOSE @c_ac   
	DEALLOCATE @c_ac   
	---------------------------------------------------- 
	-- For #credit or debit val = 0 
	INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid])   
	SELECT 0,[en].[enAccount], BALANCE, [en].[ceGuid],[en].[enNumber],[en].[ceNumber],[en].[enDate], BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[en].[enCostPoint] 
	FROM    
		[#AGE] AS [en]  LEFT JOIN #CREDIT c  ON CAST([en].[enAccount] AS VARCHAR(36)) + CAST([en].[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
	WHERE c.[enAccount] IS NULL AND (@DebitCreditFlag &  0x00001) > 0 		and [dcType] = 0 
	INSERT INTO [#t_Result] ([dcType], [Account] ,[Value], [EntryNum], [enNumber], [ceNumber], [Date], [Remaining], [Age], [Notes], [CostGuid])   
	SELECT 1,[en].[enAccount], BALANCE, [en].[ceGuid],[en].[enNumber],[en].[ceNumber],[en].[enDate], BALANCE,DATEDIFF(d, [enDate], @UntilDate),[enNotes],[en].[enCostPoint] 
	FROM    
		[#AGE] AS [en]  LEFT JOIN #Debit c  ON CAST([en].[enAccount] AS VARCHAR(36)) + CAST([en].[enCostPoint] AS VARCHAR(36)) = CAST(c.[enAccount] AS VARCHAR(36)) + CAST(c.[enCostPoint] AS VARCHAR(36)) 
	WHERE c.[enAccount] IS NULL AND (@DebitCreditFlag &  0x00002) > 0 	and [dcType] = 1 
	---------------------------------------------------- 
	IF @GroupingByCost > 0 
		UPDATE #T_Result SET [Account] = 0x00 
	---------------------------------------------------- 
	--Test if full result
	DECLARE @IsFullResult [BIT]
	IF (EXISTS(SELECT * FROM #SecViol))
		SET @IsFullResult = 0
	ELSE
		SET @IsFullResult = 1 
	--
	IF @IsDetailed = 0   
	BEGIN   
		DECLARE    
			@PeriodCounter [INT],    
			@PeriodStart [INT],    
			@PeriodEnd [INT],    
			@SumSQL [VARCHAR](8000)   
		SET @PeriodCounter = 0   
		CREATE TABLE [#t] ([DCTYPE] tinyint, [Account] [UNIQUEIDENTIFIER],[CostGuid] UNIQUEIDENTIFIER)   
		SET @SumSQL = ''   
		DECLARE @SQL AS [VARCHAR](8000)   
		
		SET @SQL = 'ALTER TABLE [#t] ADD [Balance] [FLOAT]'    
		WHILE @PeriodCounter < @NumOfPeriods  
		BEGIN   
			SET @SQL = @SQL + ', [Period' + CAST(@PeriodCounter+1 AS [VARCHAR](5)) + '] [FLOAT]'   
			SET @PeriodStart = @PeriodCounter * @PeriodLength   
			SET @PeriodEnd = @PeriodStart + @PeriodLength   
			 
			SET @SumSQL = @SumSQL +  ', ISNULL((SELECT SUM([Remaining]) FROM [#t_Result] [t_inner] WHERE ' 
			---------------------------------------------------------------- 
			IF @GroupingByCost = 0 
				SET @SumSQL = @SumSQL + ' [t_inner].[Account] = [t_outer].[Account] AND ' 
			IF @HandlingCost > 0 
			BEGIN 
				DECLARE @TEMP3 VARCHAR(100) 
				SET @TEMP3 = ' 0x00 ' 
				IF @HideCosts = 0 
					SET @TEMP3 = ' [t_outer].[CostGuid] ' 
				SET @SumSQL = @SumSQL +  ' [t_inner].[CostGuid] = ' + @TEMP3 + ' AND ' 
			END 
			 
			SET @SumSQL = @SumSQL + ' [t_inner].[DCTYPE] = [t_outer].[DCTYPE] AND ' 
			---------------------------------------------------------------- 
			IF @PeriodCounter = (@NumOfPeriods - 1) 
				SET @SumSQL = @SumSQL +  ' [t_inner].[Age] >' + CAST(@PeriodStart AS [VARCHAR](5)) + '), 0)'   
			ELSE  IF @PeriodCounter = 0  
				SET @SumSQL = @SumSQL +	' ( [t_inner].[Age] = 0 OR ( [t_inner].[Age] > ' + CAST(@PeriodStart AS [VARCHAR](5))   
						+ ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [VARCHAR](5)) + '))), 0)'  
			ELSE  
				SET @SumSQL = @SumSQL +  ' [t_inner].[Age] > ' + CAST(@PeriodStart AS [VARCHAR](5)) + ' AND [t_inner].[Age] <= ' + CAST(@PeriodEnd AS [VARCHAR](5)) + '), 0)' 
			----------------------------------------------------------------	 
			SET @PeriodCounter = @PeriodCounter + 1 
		END  
		EXEC (@SQL)  
		DECLARE @SqlInsert AS [VARCHAR](8000) 
		Declare @TEMP1 VARCHAR(50), @TEMP2 VARCHAR(50) 
		SET @TEMP1 = ' 0x00 ' 
		SET @TEMP2 = '  ' 
		IF @HideCosts = 0 
		BEGIN 
			SET @TEMP1 = ' [CostGuid] ' 
			SET @TEMP2 = ',[CostGuid] ' 
		END 
		SET @SqlInsert = '  
				INSERT INTO [#t]  
				SELECT [dctype], [Account], ' + @TEMP1 + ', Sum([Remaining]) ' + @SumSQL + '  
				FROM [#t_Result] [t_outer]  
				GROUP BY [dctype], [Account]' + @TEMP2 
	  
		EXEC( @SqlInsert)   
		---
		--Preparing result-set for CrossTab
		SELECT[DCTYPE] , [Account] ,[CostGuid], 0 AS DebitAmount, 0 AS PeriodNum INTO #FinalTbl FROM #t 
		Delete #FinalTbl
		--CREATE TABLE [#FinalTbl] ([SerialNumber] [INT] IDENTITY, [DCTYPE] tinyint, [Account] [UNIQUEIDENTIFIER],[CostGuid] UNIQUEIDENTIFIER, DebitAmount FLOAT, PeriodNum INT)   
		DECLARE @FinalStr VARCHAR(8000)
		SET @PeriodCounter = 0
		WHILE @PeriodCounter < @NumOfPeriods  
		BEGIN   
			SET @FinalStr = 'INSERT INTO #FinalTbl SELECT [DCTYPE] , [Account] ,[CostGuid], [Period' + CAST(@PeriodCounter+1 AS [VARCHAR](5)) + '], ' + CAST(@PeriodCounter+1 AS [VARCHAR](5)) +  ' FROM #t'
			EXEC (@FinalStr)	 
			SET @PeriodCounter = @PeriodCounter + 1 
		END
		--Select * From #FinalTbl ORDER BY [DCTYPE], [Account], [CostGuid], [PeriodNum]  
		---
		IF @ShowCustomersOnly = 0   
		BEGIN 
			IF @GroupingByCost = 0  
				BEGIN
					SELECT 0 AS Balance, '' As CustomerName, ((CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN [ac].[acName] ELSE [ac].[acLatinName] END) + '-' + [ac].[acCode]) AS AccountName, [tb].*, ((CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN ISNULL(co.Name + '-','') ELSE ISNULL(co.LatinName + '-','') END) + ISNULL(co.Code,'')) AS CostName,
					[ac].[acCode] As [AccountCode], [ac].[acName] As [AccountArabicName], [ac].[acLatinName] As [AccountLatinName], 
					'' As [CostCode], '' As [CostArabicName], '' As [CostLatinName], @IsFullResult AS IsFullResult   
					--INTO #Test
					FROM #FinalTbl AS [tb] INNER JOIN [vwac] AS [ac] ON [tb].[Account] = [ac].[acGuid] LEFT JOIN [co000] co ON  co.Guid = [CostGuid]   
					ORDER BY [DCTYPE], [tb].[Account],[CostGuid], [PeriodNum]  
					--IF EXISTS (Select Period From #Test)
					--	Print(1)
				END
			ELSE  
				SELECT 0 AS Balance, '' As CustomerName, '' AS AccountName, [tb].*, ((CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN ISNULL(co.Name + '-','') ELSE ISNULL(co.LatinName + '-','') END) + ISNULL(co.Code,'')) AS CostName, 
				'' As [AccountCode], '' As [AccountArabicName], '' As [AccountLatinName], 
				IsNull([co].[Code], '') As [CostCode], IsNull([co].[Name], '') As [CostArabicName], IsNull([co].[LatinName], '') As [CostLatinName], @IsFullResult AS IsFullResult     
				FROM #FinalTbl AS [tb] LEFT JOIN [co000] co ON  co.Guid = [CostGuid]  
				ORDER BY [DCTYPE], [CostGuid], [PeriodNum]  
		END 
		ELSE  
		BEGIN  
			DECLARE @StrSql1 VARCHAR(8000)  
			SET @StrSql1 =  ' SELECT 0 AS Balance, '''' AS AccountName, [ac].[Code] As [AccountCode], [ac].[Name] As [AccountArabicName], [ac].[LatinName] As [AccountLatinName], '  
			 
			IF @GroupingByCost = 0 
			BEGIN  
				SET @StrSql1 = @StrSql1 +  '[cu].[Guid] AS [cuGuid],[cu].[CustomerName],[cu].[Nationality],[cu].[Address],[cu].[Phone1],[cu].[Phone2],[cu].[FAX],  
					[cu].[Number],[cu].[TELEX],[cu].[Notes] AS [CustomerNotes],[cu].[LatinName],[cu].[HomePage],[cu].[Prefix],[cu].[Suffix],[cu].[Area],[cu].[City],   
					[cu].[Street],[cu].[POBox],[cu].[ZipCode],[cu].[Mobile],[cu].[Pager],[cu].[Hoppies],[cu].[DiscRatio],   
					[cu].[Gender],[cu].[EMail],[cu].[Certificate],[cu].[DateOfBirth],[cu].[Job],[cu].[JobCategory],[cu].[Country],   
					[cu].[UserFld1],[cu].[UserFld2],[cu].[UserFld3],[cu].[UserFld4]   
					,' 
			END 
			SET @StrSql1 = @StrSql1 + ' [tb].* '  
			IF @HandlingCost > 0   
				BEGIN
				SET @StrSql1 = @StrSql1 + ', ((CASE WHEN UPPER(SUBSTRING(''' + @Lang + ''', 1, 2)) = ''AR'' THEN ISNULL(co.Name + ''-'','''') ELSE ISNULL(co.LatinName + ''-'','''') END) + ISNULL(co.Code,'''')) AS CostName '
				SET @StrSql1 = @StrSql1 + ',ISNULL(co.Code,'''') [CostCode], ISNULL(co.Name,'''') [CostArabicName], ISNULL(co.LatinName,'''') [CostLatinName] '   
				END
			ELSE
				SET @StrSql1 = @StrSql1 + ', '''' AS CostName, '''' As [CostCode], '''' As [CostArabicName], '''' As [CostLatinName] '
			-------------------------------------------------------------------------------------------------------   
			-- Checked if there are Custom Fields to View  	   
			-------------------------------------------------------------------------------------------------------   
			--IF @VeiwCFlds <> ''	    
			--	SET @StrSql1 = @StrSql1 + @VeiwCFlds  
			-------------------------------------------------------------------------------------------------------   
			--Is Full Result
			SET @StrSql1 = @StrSql1 + ', '
			SET @StrSql1 = @StrSql1 + CAST(@IsFullResult AS VARCHAR(1))
			SET @StrSql1 = @StrSql1 + ' AS IsFullResult '
			
			SET @StrSql1 = @StrSql1 +  ' FROM [#FinalTbl] AS [tb] Inner Join [Ac000] AS [Ac] ON [tb].[Account] = [Ac].[GUID] ' 
			IF @GroupingByCost = 0 
				SET @StrSql1 = @StrSql1 +'INNER JOIN [cu000] AS cu ON [cu].[AccountGuid] = [tb].[Account] '   
			IF @HandlingCost > 0   
				SET @StrSql1 = @StrSql1 + ' LEFT JOIN [co000] co ON  co.Guid = [CostGuid] '   
			-------------------------------------------------------------------------------------------------------   
			-- Custom Fields to View  	   
			--------------------------------------------------------------------------------------------------------   
			--IF @VeiwCFlds <> ''	   
			--BEGIN   
			--	Declare @CF_Table1 VARCHAR(255)   
			--	SET @CF_Table1 = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000')  -- Mapping Table   
			--	SET @StrSql1 = @StrSql1 + ' LEFT JOIN ' + @CF_Table1 + ' ON [cu].[Guid] = ' + @CF_Table1 + '.Orginal_Guid ' 	   
			--END   
			-------------------------------------------------------------------------------------------------------    
			SET @StrSql1 = @StrSql1 +  
			' ORDER BY [DCTYPE], [cu].[CustomerName] '  
			IF @HandlingCost > 0  
				SET @StrSql1 = @StrSql1 + ', ISNULL(co.Code,'''')'  
			SET @StrSql1 = @StrSql1 + ', [PeriodNum] '
			--Print (@StrSql1)
			EXEC (@StrSql1) 
		END  
	END  
	ELSE  
	BEGIN  
		IF (@ShowParent = 1)   
		BEGIN   
			UPDATE [t] SET [ParentTypeName] = (CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN [bt].[Name] ELSE [bt].[LatinName] END), [ParentGuid] = [er].[ParentGuid],[ParentNum] = [bu].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [bu].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbbu] AS [bu] ON [bu].[Guid] = [er].[ParentGuid] INNER JOIN [vbBt] AS [bt] ON [bt].[GUID] = [bu].[TypeGUID] 
			UPDATE [t] SET [ParentTypeName] = (CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN [et].[Name] ELSE [et].[LatinName] END), [ParentGuid] = [er].[ParentGuid],[ParentNum] = [py].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [py].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbpy] AS [py] ON [py].[Guid] = [er].[ParentGuid] INNER JOIN [vbEt] AS [et] ON [et].[GUID] = [py].[TypeGUID]   
			UPDATE [t] SET [ParentTypeName] = (CASE WHEN UPPER(SUBSTRING(@Lang, 1, 2)) = 'AR' THEN [nt].[Name] ELSE [nt].[LatinName] END), [ParentGuid] = [er].[ParentGuid],[ParentNum] = [ch].[Number],[ParentType] = [er].[ParentType],[ParentTypeGUID] = [ch].[TypeGUID]   FROM  [#t_Result] AS [t] INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] = [EntryNum] INNER JOIN [vbch] AS [ch] ON [ch].[Guid] = [er].[ParentGuid] INNER JOIN [vbNt] AS [nt] ON [nt].[GUID] = [ch].[TypeGUID]     
		END   
		IF @ShowCustomersOnly = 0   
		BEGIN  
			DECLARE @S VARCHAR(8000); 
			SET @S = 'SELECT [tb].[SerialNumber], '''' As CustomerName, 0 AS [Balance], ' 
			
			IF @GroupingByCost = 0 
				BEGIN
				SET @S = @S + '((CASE WHEN UPPER(SUBSTRING(''' + @Lang + ''', 1, 2)) = ''AR'' THEN [ac].[Name] ELSE [ac].[LatinName] END) + ''-'' + [ac].[Code]) AS AccountName, '
				SET @S = @S + '[ac].[Code] AS [AccountCode],  
				[ac].[Name] AS [AccountArabicName],  
				[ac].[LatinName] AS [AccountLatinName],  ' 
				END
			ELSE
				SET @S = @S + ' '''' AS AccountName, '''' AS AccountCode, '''' AS AccountArabicName, '''' AS AccountLatinName, '
			
			IF @HideCosts = 0 
				BEGIN
					SET @S = @S + '[tb].[DCType], [tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID], (CASE WHEN [tb].[ParentTypeGUID] <> 0x0 THEN [tb].[ParentTypeName] + '':'' + CAST([tb].[ParentNum] AS VARCHAR(10)) ELSE '''' END) AS ParentTypeName, 
								   [tb].[CostGuid], '
					
					SET @S = @S + ' ISNULL(co.Code,'''') [CostCode], ISNULL(co.Name,'''') [CostArabicName], ISNULL(co.LatinName, '''') [CostLatinName], ' 
					SET @S = @S + ' ((CASE WHEN UPPER(SUBSTRING(''' + @Lang + ''', 1, 2)) = ''AR'' THEN ISNULL(co.Name + ''-'', '''') ELSE ISNULL(co.LatinName + ''-'', '''') END) + ISNULL(co.Code,'''')) AS CostName '
				END
			ELSE
				BEGIN 
					SET @S = @S + ' [tb].[DCType], [tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID], (CASE WHEN [tb].[ParentTypeGUID] <> 0x0 THEN [tb].[ParentTypeName] + '':'' + CAST([tb].[ParentNum] AS VARCHAR(10)) ELSE '''' END) AS ParentTypeName, '''' AS CostName ' 
					SET @S = @S + ', '''' [CostCode], '''' [CostArabicName], '''' [CostLatinName] ' 
				END
			--Is Full Result
			SET @S = @S + ', '
			SET @S = @S + CAST(@IsFullResult AS VARCHAR(1))
			SET @S = @S + ' AS IsFullResult '
			
			SET @S = @S + ' FROM [#t_Result] AS [tb] '
			
			IF @GroupingByCost = 0 
				SET @S = @S + 'INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [tb].[Account] ' 
			IF @HideCosts = 0 
				SET @S = @S + 'LEFT  JOIN [co000] AS [co] ON [co].[Guid] = [tb].[CostGuid]' 
				 
			IF @HideCosts > 0 
			BEGIN 
				SET @S = @S + ' GROUP BY [tb].[DCType], [tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID], (CASE WHEN [tb].[ParentTypeGUID] <> 0x0 THEN [tb].[ParentTypeName] + '':'' + CAST([tb].[ParentNum] AS VARCHAR(10)) ELSE '''' END) ' 
				IF @GroupingByCost = 0 
					SET @S = @S + ', [ac].[Code], [ac].[Name], [ac].[LatinName] ' 
			END 
				 
			SET @S = @S + 'ORDER BY [DCTYPE], ' 
			IF @GroupingByCost = 0 
				SET @S = @S + '[tb].[Account], ' 
			IF @HideCosts = 0 
				SET @S = @S + '[tb].[CostGuid],' 
				 
			SET @S = @S + '[tb].[Date], [tb].[enNumber] ' 
				 	 
			EXEC (@S) 
		END 
		ELSE 
		BEGIN 
			DECLARE @StrSql2 VARCHAR(8000)   
			SET @StrSql2 =  ' SELECT [tb].[SerialNumber], '''' AS AccountName, 0 AS [Balance], [ac].[Code] As [AccountCode], [ac].[Name] As [AccountArabicName], [ac].[LatinName] As [AccountLatinName], ' 
			IF @GroupingByCost = 0 
				SET @StrSql2 = @StrSql2 + '[cu].[Guid] AS [cuGuid],[cu].[CustomerName],[cu].[Nationality],[cu].[Address],[cu].[Phone1],[cu].[Phone2],[cu].[FAX],   
				[cu].[Number],[cu].[TELEX],[cu].[Notes] AS [CustomerNotes],[cu].[LatinName],[cu].[HomePage],[cu].[Prefix],[cu].[Suffix],[cu].[Area],[cu].[City],   
				[cu].[Street],[cu].[POBox],[cu].[ZipCode],[cu].[Mobile],[cu].[Pager],[cu].[Hoppies],[cu].[DiscRatio],   
				[cu].[Gender],[cu].[EMail],[cu].[Certificate],[cu].[DateOfBirth],[cu].[Job],[cu].[JobCategory],   
				[cu].[UserFld1],[cu].[UserFld2],[cu].[UserFld3],[cu].[UserFld4],[cu].[Country],' 
			SET @StrSql2 = @StrSql2 + '[tb].DCType,	[tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID], (CASE WHEN [tb].[ParentTypeGUID] <> 0x0 THEN [tb].[ParentTypeName] + '':'' + CAST([tb].[ParentNum] AS VARCHAR(10)) ELSE '''' END) AS ParentTypeName ' 
			IF @HideCosts = 0 
				SET @StrSql2 = @StrSql2 + ', [tb].[CostGuid] ' 
			-------------------------------------------------------------------------------------------------------   
			-- Checked if there are Custom Fields to View  	   
			-------------------------------------------------------------------------------------------------------   
			--IF @VeiwCFlds <> ''	    
			--	SET @StrSql2 = @StrSql2 + @VeiwCFlds    
			-------------------------------------------------------------------------------------------------------   
			IF @HandlingCost > 0 AND @HideCosts = 0 
				BEGIN
					SET @StrSql2 = @StrSql2 + ', ((CASE WHEN UPPER(SUBSTRING(''' + @Lang + ''', 1, 2)) = ''AR'' THEN ISNULL(co.Name + ''-'', '''') ELSE ISNULL(co.LatinName + ''-'', '''') END) + ISNULL(co.Code,'''')) AS CostName '
					SET @StrSql2 = @StrSql2 + ', ISNULL(co.Code,'''') [CostCode], ISNULL(co.Name,'''') [CostArabicName], ISNULL(co.LatinName,'''') [CostLatinName] '   
				END
			ELSE 
				SET @StrSql2 = @StrSql2 + ', '''' AS CostName, '''' [CostCode], '''' [CostArabicName], '''' [CostLatinName]  '
			
			--Is Full Result
			SET @StrSql2 = @StrSql2 + ', '
			SET @StrSql2 = @StrSql2 + CAST(@IsFullResult AS VARCHAR(1))
			SET @StrSql2 = @StrSql2 + ' AS IsFullResult '
				 
			SET @StrSql2 = @StrSql2 +  ' FROM   [#t_Result] AS [tb] Inner Join [Ac000] AS [Ac] ON [tb].[Account] = [AC].[GUID]' 
			IF @GroupingByCost = 0 
				SET @StrSql2 = @StrSql2 +  'INNER JOIN [cu000] AS cu ON [cu].[AccountGuid] = [tb].[Account] '   
			IF @HandlingCost > 0 AND @HideCosts = 0 
				SET @StrSql2 = @StrSql2 + ' LEFT JOIN [co000] co ON  co.Guid = [CostGuid] '   
			-------------------------------------------------------------------------------------------------------   
			-- Custom Fields to View  	   
			--------------------------------------------------------------------------------------------------------   
			--IF @VeiwCFlds <> ''	AND @GroupingByCost = 0  
			--BEGIN   
			--	Declare @CF_Table2 VARCHAR(255)   
			--	SET @CF_Table2 = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000')  -- Mapping Table   
			--	SET @StrSql2 = @StrSql2 + ' LEFT JOIN ' + @CF_Table2 + ' ON [cu].[Guid] = ' + @CF_Table2 + '.Orginal_Guid ' 	   
			--END   
			-------------------------------------------------------------------------------------------------------    
			IF @HideCosts > 0 
			BEGIN 
				SET @StrSql2 = @StrSql2 + ' GROUP BY [tb].[DCType], [tb].[Account], [tb].[Value], [tb].[EntryNum], [tb].[enNumber], [tb].[ceNumber], [tb].[Date], [tb].[Remaining], [tb].[Age], [tb].[Notes], [tb].[ParentGuid], [tb].[ParentNum], [tb].[ParentType], [tb].[ParentTypeGUID], (CASE WHEN [tb].[ParentTypeGUID] <> 0x0 THEN [tb].[ParentTypeName] + '':'' + CAST([tb].[ParentNum] AS VARCHAR(10)) ELSE '''' END) ' 
				Set @StrSql2 = @StrSql2 + ', [ac].[Code], [ac].[Name], [ac].[LatinName] '
				IF @GroupingByCost = 0 
					SET @StrSql2 = @StrSql2 + ', [cu].[Guid],[cu].[CustomerName],[cu].[Nationality],[cu].[Address],[cu].[Phone1],[cu].[Phone2],[cu].[FAX],   
					[cu].[Number],[cu].[TELEX],[cu].[Notes],[cu].[LatinName],[cu].[HomePage],[cu].[Prefix],[cu].[Suffix],[cu].[Area],[cu].[City],   
					[cu].[Street],[cu].[POBox],[cu].[ZipCode],[cu].[Mobile],[cu].[Pager],[cu].[Hoppies],[cu].[DiscRatio],   
					[cu].[Gender],[cu].[EMail],[cu].[Certificate],[cu].[DateOfBirth],[cu].[Job],[cu].[JobCategory],   
					[cu].[UserFld1],[cu].[UserFld2],[cu].[UserFld3],[cu].[UserFld4],[cu].[Country]' 
			END 
				 
			SET @StrSql2 = @StrSql2 + ' ORDER BY [DCTYPE],' 
			 
			IF @GroupingByCost = 0  
				SET @StrSql2 = @StrSql2 + ' [cu].[CustomerName],' 
				 
			SET @StrSql2 = @StrSql2 + ' [tb].[Date], [tb].[enNumber] '   
			 
			IF @HandlingCost > 0 AND @HideCosts = 0 
				SET @StrSql2 = @StrSql2 + ', ISNULL(co.Code,'''')'   
			
			EXEC (@StrSql2)  
		END  
	END 
	
	
	
	
	/*
	ALTER PROCEDURE [RepGetAges_ce]
		@AccountGUID						[UNIQUEIDENTIFIER] = 0x0,							--«·Õ”«»
		@JobCostGUID						[UNIQUEIDENTIFIER] = 0x0,							--„—ﬂ“ «·ﬂ·›…
		@UntilDate							[DATETIME] = '1-1-2010',									--Õ Ï  «—ÌŒ
		@DebitCreditFlag					tinyint = 0,									-- 1 Debit, 2 Credit, 3 Debit and Credit
		@IsDetailed							[BIT] = 0,										--⁄—÷  ﬁ—Ì—  ›’Ì·Ì
		@NumOfPeriods						[INT] = 0,										--⁄œœ «·› —« 
		@PeriodLength						[INT] = 0,										--ÿÊ· «·› —…
		@CurrencyGUID						[UNIQUEIDENTIFIER] = 0x0,							--«·⁄„·…
		@UserGUID							[UNIQUEIDENTIFIER] = 0x0,							--«·„” Œœ„
		@ShowParent							[BIT] = 0,									--⁄—÷ √’· «·”‰œ
		@ShowCustomersOnly					[BIT] = 0,									--⁄—÷ «·“»«∆‰ ›ﬁÿ
		--@VeiwCFlds						VARCHAR (MAX) = '', 						-- check veiwing of Custom Fields  
		@HandlingCost						BIT = 0,									--„⁄«·Ã… „—ﬂ“ «·ﬂ·›…
		@SourcesTypes						VARCHAR(MAX) = '',								--„’«œ— «· ﬁ—Ì—							
		@GroupingByCost						bit = 0,									-- Ã„»⁄ Õ”» „—ﬂ“ «·ﬂ·›…
		@HideCosts							BIT = 0,									--≈Œ›«¡ „—«ﬂ“ «·ﬂ·›
		@CustomersCondition					VARCHAR (MAX) = '',							--‘—Êÿ «·“»«∆‰
		@BranchMask							BigInt = -1,										--›—Ê⁄ «„” Œœ„
		@Lang								VarChar(10) = 'ar',							--«··€…				
		@ShowNotes							BIT = 0,									--≈ŸÂ«— «·»Ì«‰																
		---------------------------≈ŸÂ«— ÕﬁÊ· «·“»Ê‰-----------------------------------------
		@ShowCustomerNumber					BIT = 0,									--≈ŸÂ«— —ﬁ„ «·»ÿ«ﬁ…																
		@ShowCustomerPrefix					BIT = 0,									--≈ŸÂ«— «··ﬁ»																
		@ShowCustomerLatinName				BIT = 0,									--≈ŸÂ«— «·«”„ «··« Ì‰Ì																
		@ShowCustomerSuffix					BIT = 0,									--≈ŸÂ«— «··«Õﬁ…																
		@ShowCustomerNationality			BIT = 0,									--≈ŸÂ«— «·Ã‰”Ì…																
		@ShowCustomerPhone1					BIT = 0,									--≈ŸÂ«— «·Â« ›1																
		@ShowCustomerPhone2					BIT = 0,									--≈ŸÂ«— «·Â« ›2																
		@ShowCustomerFax					BIT = 0,									--≈ŸÂ«— «·›«ﬂ”																
		@ShowCustomerTelex					BIT = 0,									--≈ŸÂ«— «· ·ﬂ”																
		@ShowCustomerMobile					BIT = 0,									--≈ŸÂ«— «·„Ê»«Ì·																
		@ShowCustomerPager					BIT = 0,									--≈ŸÂ«— «·‰œ«¡																
		@ShowCustomerNotes					BIT = 0,									--≈ŸÂ«— «·„·«ÕŸ« 																
		@ShowCustomerEmail					BIT = 0,									--≈ŸÂ«— «·»—Ìœ «·«ﬂ —Ê‰Ì																
		@ShowCustomerWebSite				BIT = 0,									--≈ŸÂ«— „Êﬁ⁄ «·«‰ —‰ 																
		@ShowCustomerDiscountPercentage		BIT = 0,									--≈ŸÂ«— ‰”»… «·Õ”„																
		@ShowCustomerCountry				BIT = 0,									--≈ŸÂ«— «·œÊ·…																
		@ShowCustomerCity					BIT = 0,									--≈ŸÂ«— «·„œÌ‰…																
		@ShowCustomerRegion					BIT = 0,									--≈ŸÂ«— «·„‰ÿﬁ…																
		@ShowCustomerStreet					BIT = 0,									--≈ŸÂ«— «·‘«—⁄																
		@ShowCustomerAddress				BIT = 0,									--≈ŸÂ«— «·⁄‰Ê«‰ « ›’Ì·Ì																
		@ShowCustomerZIPCode				BIT = 0,									--≈ŸÂ«— «·—„“ «·»—ÌœÌ																
		@ShowCustomerPOBox					BIT = 0,									--≈ŸÂ«— ’‰œÊﬁ «·»—Ìœ																
		@ShowCustomerCertificate			BIT = 0,									--≈ŸÂ«— «·‘Â«œ« 																
		@ShowCustomerJob					BIT = 0,									--≈ŸÂ«— «·⁄„·																
		@ShowCustomerJobNature				BIT = 0,									--≈ŸÂ«— ‰Ê⁄ «·⁄„·																
		@ShowCustomerField1					BIT = 0,									--≈ŸÂ«— «·Õﬁ·1																
		@ShowCustomerField2					BIT = 0,									--≈ŸÂ«— «·Õﬁ·2																
		@ShowCustomerField3					BIT = 0,									--≈ŸÂ«— «·Õﬁ·3																
		@ShowCustomerField4					BIT = 0,									--≈ŸÂ«— «·Õﬁ·4																
		@ShowCustomerDateOfBirth			BIT = 0,									--≈ŸÂ«—  «—ÌŒ «· Ê·œ																
		@ShowCustomerGender					BIT = 0,									--≈ŸÂ«— «·Ã‰”																
		@ShowCustomerHobbies				BIT = 0 	
		
AS   
	  SELECT
			'' AS [AccountName],   
			'' AS [CustomerName],
			'' AS [Nationality],
			'' AS [Address],
			'' AS [Phone1],
			'' AS [Phone2],
			'' AS [FAX],   
			'' AS [CardNumber],
			'' AS [TELEX],
			'' AS [CustomerNotes],
			'' AS [LatinName],
			'' AS [HomePage],
			'' AS [Prefix],
			'' AS [Suffix],
			'' AS [Area],
			'' AS [City],   
			'' AS [Street],
			'' AS [POBox],
			'' AS [ZipCode],
			'' AS [Mobile],
			'' AS [Pager],
			'' AS [Hobbies],
			'' AS [DiscRatio],   
			'' AS [Gender],
			'' AS [EMail],
			'' AS [Certificate],
			'' AS [DateOfBirth],
			'' AS [Job],
			'' AS [JobCategory],   
			'' AS [UserFld1],
			'' AS [UserFld2],
			'' AS [UserFld3],
			'' AS [UserFld4],
			'' AS [Country], 
			'' AS [Value], 
			'' AS [Date], 
			'' AS [Remaining], 
			'' AS [Age], 
			'' AS [Notes], 
			'' AS [ParentGuid], 
			'' AS [ParentNum], 
			'' AS [ParentType], 
			'' AS [ParentTypeGUID], 
			'' AS [ParentTypeName], 
			'' AS [CostGuid],  
			'' AS [coCode], 
			'' AS [coName], 
			'' AS [coLatinName], 
			'' AS [CostName],    
			1  AS [IsFullResult],
			0  As [Balance],
			0  As [DebitAmount],
			0  As [PeriodNum],
			0  As [Period1],
			0  As [Period2],
			0  As [Period3],
			0  As [Period4],
			0  As [Period5],
			0  As [Period6],
			0  As [Period7],
			0  As [Period8],
			0  As [Period9],
			0  As [Period10],
			'' As [CoGuid],
			0  AS [DCType],
			'' AS [AccountCode],  
			'' AS [AccountArabicName],  
			'' AS [AccountLatinName],
			'' AS [CostCode],  
			'' AS [CostArabicName],  
			'' AS [CostLatinName],
			0  AS [SerialNumber]    
	*/ 
#########################################################
CREATE PROCEDURE ARWA.repGeneralLedger
	-- Report Filters
	@AccountGUID							[UNIQUEIDENTIFIER] = '4B09D808-2DE5-4167-AAE8-CD300A2FE8EB',			-- Account   
	@JobCostGUID							[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000',			-- Cost Job   
	@FromLastConsolidationDate				[BIT]              = 0, 												-- From Last Check Date   
	@StartDate								[DATETIME]         = '1/1/2009 0:0:0.0',								-- StartDate
	@EndDate								[DATETIME]         = '12/14/2010 23:59:35.21',							-- @EndDate
	@CurrencyGUID							[UNIQUEIDENTIFIER] = '0177fdf3-d3bb-4655-a8c9-9f373472715a',		    -- @CurrencyGUID  
	@Class									[VARCHAR](256)     = '',												-- Class      
	@ShowUnposted							[BIT]              =  1,  												-- ShowUnPosted
	@Level									[INT]              =  0,  												-- Level For Account      
	@NotesContain							[VARCHAR](256)     = '',												-- The Note Of Entry contain ...      
	@NotesNotContain						[VARCHAR](256)     = '',												-- The Note Of Entry Not contain ...      
	@ShowPreviousBalance					[BIT]              = 1,													-- Show PrvBalance
	@ContraAccount							[UNIQUEIDENTIFIER] = 0x0,												-- Fillter Entry with Obverse Account       
	@MergeAccountItemsInEntry				[BIT] = 0,																-- 0: let the entry , 1: merge the entry for same Account      
	@ShowEntrySource						[BIT] = 0,																-- ≈ŸÂ«— √’· «·”‰œ  
	@ItemChecked							[INT] = 2,																-- ≈ŸÂ«— «·„œﬁﬁ / €Ì— «·„œﬁﬁ : 0, 1, 2   
	@ShowEmptyBalances						[BIT] = 1,																-- ≈ŸÂ«— «·Õ”«»«  «·›«—€…  
	@MergeNotePapersEntries					[BIT] = 0	,															-- œ„Ã ”‰œ«  «·√Ê—«ﬁ «·„«·Ì… –«  ‰›” «·—ﬁ„  
	@ShowBranch								[BIT] = 0 ,																-- ShowBranch 
	@ShowContraAccount						[BIT] = 0,																-- ShowContraAcc
	@SelectedUserGUID						UNIQUEIDENTIFIER = 0X00,												-- Filter Result By @SelectedUserGUID
	@ShowUser								BIT = 0,  
	-----------------Report Sources-----------------------
	@SourcesTypes							VARCHAR(MAX) = '00000000-0000-0000-0000-000000000000, 1',			   -- SourcesTypes
	------------------------------------------------------
	@ShowEntryNumber						[BIT] = 0,															   --Show Entry Number
	@ShowOriginalCurrency					[BIT] = 0,                                                             --Show Original Currency
	@ShowJobCost       						[BIT] = 0,                                                             --Show Cost Point
	@ResetBalanceInPeriodStart				[BIT] = 0,															   --Reset Balance in Starting Period
	@ProcessContainInPreviousBalance		[BIT] = 0,															   --„⁄«·Ã… «·»Ì«‰ ›Ì «·—’Ìœ «·”«»ﬁ
	@ShowNotes  							[BIT] = 0,															   --Show note for entry and centry
	@ShowExchangeRateVariationsInCost  		[BIT] = 0,												   --≈ŸÂ«— ›—Êﬁ«  √”⁄«— «·’—› »«·ﬂ·›…
	@ShowFinalBalance						[BIT] = 0, 	     													   --≈ŸÂ«— «·—’Ìœ «·‰Â«∆Ì
	@ShowSumCheckedEntries					[BIT] = 0, 	     													   --≈ŸÂ«— „Ã„Ê⁄ «·√ﬁ·«„ «·„œﬁﬁ…
	@EachAccountInSeparatePage				[BIT] = 0,															   --ﬂ· Õ”«» ⁄·Ï Ê—ﬁ…
	@Lang									VARCHAR(100) = 'ar',												   --0 Arabic, 1 Latin
	@ShowClass								[BIT] = 0,															   --≈ŸÂ«— «·›∆…
	@UserGUID								[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',		   --Guid Of Logining User
	@ShowBalanceAsText						[BIT] = 0,															   --≈ŸÂ«—  ›ﬁÌÿ «·—’Ìœ
	@BranchMask								BIGINT = -1,
	@EntryConditions						VARCHAR(MAX)='',
	@BillConditions							VARCHAR(MAX)=''
AS        

	--prcInitialize_Environment
	EXEC [prcInitialize_Environment] @UserGUID, '[repGeneralLedger]', @BranchMask
	
	
	SET NOCOUNT ON   
	-------------------TEST IF IsSingl Account-------------------
	Declare @IsSingl [INT], @NSons [INT], @AccType [INT]
	SET @NSons   = (SELECT [NSons] FROM [AC000] WHERE [GUID] = @AccountGUID)
	SET @AccType = (SELECT [Type] FROM [AC000] WHERE [GUID] = @AccountGUID)
	IF NOT(@NSons>0 OR @AccType = 4/*Composite*/)
		SET @IsSingl = 1
	ELSE
		SET @IsSingl = 0
	
	-------------------Prepare @PrevBalance---------------------
	-- 0 Without PrvBalance OR by ResetBalInStartPeriod - 1 PrvBalance Without CheckContain - 2 PrvBalance With CheckContain      
	DECLARE @PrevBalance [INT]
	IF (@ShowPreviousBalance = 0 OR @ResetBalanceInPeriodStart = 1)
		SET @PrevBalance = 0
	ELSE IF (@ShowPreviousBalance = 1)
		SET @PrevBalance = CAST(@ShowPreviousBalance AS INT) + @ProcessContainInPreviousBalance
		
	------------------Prepare @CurVal----------------------------
	DECLARE @CurVal [FLOAT]
	SET @CurVal = (Select Top 1 IsNull(mh.CurrencyVal, my.CurrencyVal) 
				   From my000 my 
				   LEFT join mh000 mh on my.[Guid] = mh.[CurrencyGUID] 
				   WHERE my.[GUID] = @CurrencyGUID Order By mh.Date Desc)
	--SELECT @CurVal 
	-------------------------------------------------------------

	DECLARE @strContain AS [VARCHAR]( 1000)       
	DECLARE @strNotContain AS [VARCHAR]( 1000)       
	SET @strContain = '%'+ @NotesContain + '%'       
	SET @strNotContain = '%'+ @NotesNotContain + '%'       
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#BILLENTRY]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT ) 
	CREATE TABLE [#Bill]  ([GUID] UNIQUEIDENTIFIER ,[SEC] INT) 

	DECLARE @S VARCHAR(1000) 
	SET @s = ' SELECT buGuid, buSecurity FROM vwbu' 

	INSERT INTO [#BILL] EXEC (@s) 
	INSERT INTO [#BILLENTRY] SELECT ce.GUID , ce.SECURITY FROM CE000 ce INNER JOIN ER000 er ON Ce.GUID = er.ENTRYGUID WHERE PARENTTYPE = 2 AND PARENTGUID IN (SELECT GUID FROM [#BILL]) 
	------------------------------------------------------------------ 
	------------------------------------------      
	CREATE TABLE #Account_Tbl  ( [GUID] [UNIQUEIDENTIFIER], [Level] [INT] , CheckDate [DATETIME], [Path] [VARCHAR](4000) COLLATE ARABIC_CI_AI,acCode [VARCHAR](250) COLLATE ARABIC_CI_AI,[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI, [acSecurity] INT)      
	IF( @IsSingl <> 1)  
		INSERT INTO #Account_Tbl SELECT [fn].[GUID], [fn].[Level], '1-1-1980', [fn].[Path],[Code],[Name],[LatinName],[Security] FROM [dbo].[fnGetAccountsList]( @AccountGUID, 1) AS [Fn] INNER JOIN [ac000] AS [ac] ON [Fn].[GUID] = [ac].[GUID]  
	ELSE  
		INSERT INTO #Account_Tbl SELECT [acGUID], 0, '1-1-1980', '',[acCode],[acName],[acLatinName], [acSecurity]  FROM [vwAc] WHERE [acGUID] = @AccountGUID  
	IF( @FromLastConsolidationDate = 1)  
		UPDATE Acc SET CheckDate = ch.CheckedToDate  
		FROM   
			#Account_Tbl Acc  
			INNER JOIN (   
				SELECT AccGUID, MAX( CheckedToDate) CheckedToDate   
				FROM checkAcc000   
				WHERE CheckedToDate < @EndDate GROUP BY AccGUID) ch  
			ON Acc.Guid = ch.AccGUID  
	CREATE CLUSTERED INDEX  Account_TblIND ON #Account_Tbl(Guid)  
	CREATE TABLE #AccObverse_Tbl  ( [GUID] [UNIQUEIDENTIFIER],  
					[acCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
					[acSecurity] [INT])   
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	IF( ISNULL( @ContraAccount, 0x0) = 0x0)   
	BEGIN  
		INSERT INTO #AccObverse_Tbl  
			SELECT   
				[GUID], [Code], [Name], [LatinName], [Security]   
			FROM [ac000]   
			union all   
			select   
				0x00, '', '', '', 0  
			IF @ShowContraAccount = 0  
				UPDATE #AccObverse_Tbl SET  [acCode] = '', [acName] = '', [acLatinName] = '', [acSecurity]  = 0  
			  
	END  
	ELSE   
		INSERT INTO #AccObverse_Tbl   
			SELECT   
				[fn].[GUID], [ac].[Code], [ac].[Name], [ac].[LatinName], [ac].[Security]  
			FROM   
				[ac000] as [ac] INNER JOIN [dbo].[fnGetAccountsList]( @ContraAccount, 0) AS [Fn]   
				ON [ac].[GUID] = [fn].[GUID]  
	CREATE CLUSTERED INDEX  AccObverse_TblIND ON #AccObverse_Tbl(Guid)  
	------------------------------------------   
	CREATE TABLE #Cost_Tbl ( [GUID] [UNIQUEIDENTIFIER], [SEC] INT )   
	--INSERT INTO #Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @JobCostGUID)    
	INSERT INTO #Cost_Tbl  EXEC [prcGetCostsList] @JobCostGUID
	IF ISNULL( @JobCostGUID, 0x0) = 0x0     
		--INSERT INTO #Cost_Tbl VALUES(0x00)    
		INSERT INTO #Cost_Tbl VALUES(0x00, 0)    
	--------------------------------------------------------------------------------------  
	--Source   
	--DECLARE  @UserId [UNIQUEIDENTIFIER],@HosGuid [UNIQUEIDENTIFIER]  
	--SET @UserId = [dbo].[fnGetCurrentUserGUID]()  
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
	--INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserGUID--@UserID 
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] = 5
			
	
	--INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
									
	--INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserGUID--@UserID        
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] =  1
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]    

	
	--New way For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 3
	
	--New way For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 4
	

	------------------------------------------------------------------------------------------------------------------------   
	--  1 - Get the balance of Accounts     
	--  2 - Get the Previos balance of Accounts (option)      
	------------------------------------------------------------------------------------------------------------------------      
	-- STEP 1    
	 
	CREATE TABLE [#Result] (      
			[CeGUID] [UNIQUEIDENTIFIER],      
			[enGUID] [UNIQUEIDENTIFIER],   
			[CeNumber] [FLOAT],      
			[ceDate] [DATETIME],      
			[enNumber] [FLOAT],      
			[AccGUID] [UNIQUEIDENTIFIER],      
			[acCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[acName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[acLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[enDebit]	[FLOAT],      
			[enCredit] [FLOAT],      
			[enFixDebit] [FLOAT],      
			[enFixCredit] [FLOAT],      
			[enCurPtr] [UNIQUEIDENTIFIER],      
			[enCurVal] [FLOAT] DEFAULT 0,      
			--ObverseGUID [UNIQUEIDENTIFIER],      
			[ObvacCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ObvacName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[ObvacLatinName] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
			[CostGUID] [UNIQUEIDENTIFIER],      
			[enNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
			[ceNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,         
			[ceParentGUID] [UNIQUEIDENTIFIER],       
			[ceRecType] [INT],       
			[Path] [VARCHAR](4000),      
			[Type] [INT],      
			[PrevBalance] [FLOAT],
			[coSecurity] [INT],      
			[ceSecurity] [INT],      
			[accSecurity] [INT],    
			--AccSecurity [INT],  
			[ParentNumber] [INT],   
			[ParentName] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
			[IsCheck]  [INT] DEFAULT 0,  
			[ceTypeGuid] [UNIQUEIDENTIFIER],  
			[NtNumber] [VARCHAR](250) COLLATE ARABIC_CI_AI, -- Note Number  
			[NtFlg] INT,  
			[Class] [VARCHAR](250) COLLATE ARABIC_CI_AI,									-- Consolidate Notes?   
			[Branch] [UNIQUEIDENTIFIER],  
			[UserName] VARCHAR(100) COLLATE ARABIC_CI_AI,  
			[Posted] BIT DEFAULT 1, 
			[CeParentType]	INT 
			)     
	---------------------------------------------------------------------------------------------  
	INSERT INTO [#Result]      
		SELECT      
			[ceGUID],       
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x00 ELSE [enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [enNumber] END,   
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName],  
			SUM( [enDebit]),      
			SUM( [enCredit]),      
			SUM( [FixedEnDebit]),      
			SUM( [FixedEnCredit]),      
			[enCurrencyPtr],      
			[enCurrencyVal],      
			[AcObv].[acCode],  
			[AcObv].[acName],  
			[AcObv].[acLatinName],  
			[enCostPoint],  
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			0x0,		--ParentGUID,    
			0,		--ceRecType,    
			[AC].[Path],      
			1, 		-- 0 Main Account 1 Sub Account      
			0,
			[Cost].[SEC],      
			[ceSecurity],      
			[ac].[acSecurity],    
			--AcObv.acSecurity,  
			0,		--ceParentNumber,   
			'',		--ceTypeAbbrev,   
			0, 		-- isCheck   
			[ceTypeGuid],  
			'', 		-- NtNumber  
			0,  
			[enclass],  
			[ceBranch],'',ceIsPosted ,er.ParentType 
		FROM     
			([dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE]  --Select * From [dbo].[fnSecCostsInBranches] ('D1F944DD-2DD0-4D38-BE3E-C40C2C3C5576')
			INNER JOIN #Account_Tbl AS [AC] ON [CE].[enAccount] = [AC].[GUID])      
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]  
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON  [CE].[enContraAcc] = [AcObv].[GUID]  
			LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid    
		WHERE      
			( ( @FromLastConsolidationDate = 0 AND [CE].[enDate] BETWEEN @StartDate AND @EndDate)      
			  OR ( @FromLastConsolidationDate = 1 AND [CE].[enDate] BETWEEN DATEADD(dd,1,[AC].[CheckDate]) AND @EndDate) )      
			AND ( @Class = '' OR [enClass] = @Class)      
			AND ( @ShowUnposted = 1 OR [ceIsPosted] = 1)      
			AND ( @NotesContain = '' or [enNotes] Like @strContain or [ceNotes] Like @strContain)      
			AND ( @NotesNotContain = '' or ( [enNotes] NOT Like @strNotContain and [ceNotes] NOT Like @strNotContain))      
			AND ((src.[Type] IS NOT NULL) OR er.ParentType = 303)  
		GROUP BY     
			[ceGUID],       
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x00 ELSE [enGUID] END,   
			[ceNumber],       
			[enDate],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [enNumber] END,  
			[enAccount],      
			[ac].[acCode],  
			[ac].[acName],  
			[ac].[acLatinName],  
			[enCurrencyPtr],      
			[enCurrencyVal],      
			--enContraAcc,      
			[AcObv].[acCode],  
			[AcObv].[acName],  
			[AcObv].[acLatinName],  
			[enCostPoint],      
			CASE WHEN @MergeAccountItemsInEntry = 1 THEN [ceNotes] ELSE [enNotes] END,  
			[ceNotes],      
			[AC].[Path],
			[Cost].[SEC],      
			[ceSecurity],      
			[ac].[acSecurity],    
			--AcObv.acSecurity,  
			[ceTypeGuid],  
			[enclass],  
			[ceBranch],ceIsPosted,er.ParentType 
			
	IF( @MergeNotePapersEntries = 1)  
	BEGIN  
		-- Set flag for entries to merged  
		UPDATE [Res] SET   
			[NtNumber] = [ch].[chNum],  
			[enNotes] = [ch].[chNotes],			  
			[NtFlg] = 1  
		FROM  
			[#Result] AS [Res]  
			INNER JOIN [vwEr] AS [er]   
			ON [Res].[ceGuid] = [er].[erEntryGuid]    
			INNER JOIN [vwch] AS [ch]  
			ON [ch].[chGuid] = [er].[erParentGuid]  
		-- insert merged entry  
		INSERT INTO [#Result]  
		SELECT  
			0x0, --[CE].[ceGUID],       
			0x0, --CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			0, --[CE].[ceNumber],       
			[Res].[ceDate],  
			0, --CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [CE].[enNumber] END,   
			[Res].[AccGuid],      
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName],  
			SUM( [Res].[enDebit]),      
			SUM( [Res].[enCredit]),      
			SUM( [Res].[enFixDebit]),      
			SUM( [Res].[enFixCredit]),      
			[Res].[enCurPtr],  
			[Res].[enCurVal],      
			--enContraAcc,      
			'', --[AcObv].[acCode],  
			'', --[AcObv].[acName],  
			'', --[AcObv].[acLatinName],  
			[Res].[CostGUID],  
			[Res].[NtNumber] + (case [dbo].[fnConnections_GetLanguage]() when 0 then ' («·»Ì«‰: ' else ' (Note: '  end) +   
				max( [Res].[enNotes]) + ')', --CASE WHEN @MergeAccountItemsInEntry = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,  
			'',  
			0x0,		--ParentGUID,    
			[RES].[ceRecType],--ceRecType,    
			[Res].[Path],  
			1, 		-- 0 Main Account 1 Sub Account      
			0,
			[Res].[coSecurity],   
			[Res].[ceSecurity],  
			[Res].[accSecurity],  
			--AcObv.acSecurity,  
			0,		--ceParentNumber,   
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),	--ceTypeAbbrev,   
			0, 		-- isCheck   
			--0x0 		-- UserCheckGuid   
			[Res].[ceTypeGuid],  
			'',  
			0,  
			[Res].[class],  
			[Res].[Branch],[UserName],[Posted] ,0 
		FROM     
			[#Result] AS [Res]  
			INNER JOIN [vwNt] AS [nt]  
			ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
		WHERE      
			[Res].[NtFlg] = 1  
		GROUP BY     
			--[CE].[ceGUID],       
			--CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0x0 ELSE [CE].[enGUID] END,   
			--[CE].[ceNumber],       
			[Res].[ceDate],      
			--CASE WHEN @MergeAccountItemsInEntry = 1 THEN 0 ELSE [CE].[enNumber] END,  
			[Res].[AccGuid],  
			[Res].[acCode],  
			[Res].[acName],  
			[Res].[acLatinName],  
			[Res].[enCurPtr],  
			[Res].[enCurVal],  
			--enContraAcc,      
			--[AcObv].[acCode],  
			--[AcObv].[acName],  
			--[AcObv].[acLatinName],  
			[Res].[CostGUID],      
			[Res].[NtNumber],--CASE WHEN @MergeAccountItemsInEntry = 1 THEN [CE].[ceNotes] ELSE [CE].[enNotes] END,      
			--ParentGUID,    
			--ceRecType,    
			[Res].[Path],  
			[RES].[ceRecType],
			[Res].[coSecurity],  
			[Res].[ceSecurity],      
			[Res].[accSecurity],    
			--AcObv.acSecurity,  
			ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, ''),  
			[Res].[ceTypeGuid],  
			[Res].[class],  
			[Res].[Branch],[UserName],[Posted]  
		--///////////////////////////////////////////////////////  
		-----------------------------------  
		-- delete flaged entries  
		DELETE FROM #Result WHERE [NtFlg] = 1  
	END  
	IF (@SelectedUserGUID <> 0X00)  
	BEGIN  
		DELETE r FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid LEFT JOIN   
			(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime and u.Guid = @SelectedUserGUID) v ON v.[RecGuid] = isnull(er.parentguid,r.[CeGUID]) where v.[RecGuid] IS NULL  
	END  
	IF( @ShowEntrySource = 1) 
	BEGIN   
			UPDATE [#Result] SET   
				[ceParentGUID] = [er].[erParentGuid],    
				[ceRecType] = [er].[erParentType],    
				[ParentNumber] = [er].[erParentNumber]  
			FROM  
				[#Result] AS [Res]   
				INNER JOIN [vwEr] AS [er]   
				ON [Res].[ceGuid] = [er].[erEntryGuid]    
			IF( @ShowEntrySource = 1) 
			BEGIN 
			------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [bt].[btAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwBt] AS [bt]   
				ON [Res].[ceTypeGUID] = [bt].[btGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [et].[etAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwEt] AS [et]   
				ON [Res].[ceTypeGUID] = [et].[etGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET  
				[ParentName] = ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, '')  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwNt] AS [nt]  
				ON [Res].[ceTypeGUID] = [nt].[ntGuid]  
			-------------------------------------------  
			------------------------ For Exchange System By Muhammad Qujah  ----------  
			UPDATE [#Result] SET   
				[ParentName] = [et].[Abbrev]  
			FROM  
				TrnExchange000 as ex   
				INNER JOIN TrnExchangeTypes000 AS [et]  
					ON [ex].[TypeGuid] = [et].[Guid]  
			where ceRecType = 507  
			END 
			------------------------ For Exchange System By Muhammad Qujah  ---------  
	END 

	-------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserGUID     
	
	DECLARE @IsFullResult [INT]
	SET @IsFullResult = 0
	----Filter Result by Security
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 )
	
	--SET @NumOfSecViolated = @@ROWCOUNT
	
	----Filter Result by Branches
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID))
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID))
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
	-------------------------------------------------------------------------------------    
	--IF( @ShowIsCheck = 1) Always Update isCheck because No CheckedField in result
	--BEGIN   
		--DECLARE @UserGUID [UNIQUEIDENTIFIER]   
		--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
		
		DECLARE @CheckForUsers INT
		SET @CheckForUsers = (SELECT CAST(VALUE AS INT) From OP000 WHERE NAME LIKE 'AmnCfg_CheckEntryForUsers')  
		
		UPDATE [Res]  
		SET    
			[isCheck] = 1   
			--UserCheckGuid = RCH.UserGuid   
		FROM    
			[#Result] AS [Res] INNER JOIN [RCH000] As [RCH]   
			ON [Res].[enGuid] = [RCH].[ObjGUID]  
		WHERE    
			(@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGUID/*@UserGUID*/)
			/*@rid  = [RCH].[Type]  
			AND( (@CheckForUsers = 1) OR ([RCH].[UserGuid] = @UserGUID)) */ 
		IF( @ItemChecked <> 2)  
		BEGIN    
			IF( @ItemChecked = 1)   
				DELETE FROM [#Result] WHERE [isCheck] <> 1   
			ELSE   
				DELETE FROM [#Result] WHERE [isCheck] = 1   
			   
		END   
	--END   
	-------------------------------------------------------------------------------   
	DECLARE @BalanceTbl TABLE(      
				[AccGUID] [UNIQUEIDENTIFIER],      
				[AccParent] [UNIQUEIDENTIFIER],      
				[FixDebit] [FLOAT],      
				[FixCredit] [FLOAT],      
				[PrevBalance] [FLOAT],     
				[Lv] [INT] DEFAULT 0     
				)     
	-- create initial balance for the result table  
	INSERT INTO @BalanceTbl     
		SELECT     
			[AC].[GUID],      
			[acParent],     
			SUM( ISNULL([Res].[enFixDebit],0)),     
			SUM( ISNULL([Res].[enFixCredit],0)),     
			0 AS [PrevBal],     
			0 AS [Lv]     
		FROM     
			#Account_Tbl AS [AC] INNER JOIN [vwAc]  
			ON [vwAc].[acGUID] = [AC].[GUID]     
			LEFT JOIN [#Result] AS [Res]      
			ON [AC].[GUID] = [Res].[AccGUID]     
		GROUP BY     
			[AC].[GUID],      
			[acParent]     
	-- STEP 2 THE PREVIOS BALANCE      
	-- calc previous balances for result and accounts not in result and   
	-- has only a previous balance  
	IF @PrevBalance	> 0      
	BEGIN      
		CREATE TABLE [#Prev_B_Res] ( [AccGUID] [UNIQUEIDENTIFIER],   
						[enDebit]	[FLOAT],   
						[enCredit] [FLOAT],
						[coSecurity] [INT],   
						[ceSecurity] [INT],   
						[acSecurity] [INT],  
						[ceGuid]	UNIQUEIDENTIFIER)   
		INSERT INTO [#Prev_B_Res]   
		SELECT      
			[CE].[enAccount] AS [Account],     
			[CE].[FixedEnDebit] AS [Debit],      
			[CE].[FixedEnCredit] AS [Credit],   
			[Cost].[SEC],
			[CE].[ceSecurity],   
			[Acc].[acSecurity] ,[ceGuid]  
		FROM      
			[dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE]      
			INNER JOIN #Account_Tbl AS [Acc] On [Acc].[Guid] = [CE].[enAccount]     
			INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID]         
			INNER JOIN #AccObverse_Tbl AS [AcObv] ON ISNULL( [CE].[enContraAcc], 0x0) = [AcObv].[GUID]   
			LEFT JOIN [#EntryTbl] src ON ceTypeGuid = src.[Type]  
			LEFT JOIN ER000 er ON er.EntryGuid = ceGuid    
		WHERE      
			( ( @FromLastConsolidationDate = 0 AND [CE].[enDate] < @StartDate)    
			OR ( @FromLastConsolidationDate = 1 AND [CE].[enDate] <= DATEADD(mi,1439,[Acc].[CheckDate])) )   
			AND ( @Class = '' OR [CE].[enClass] = @Class)     
			AND ( @ShowUnposted = 1 OR [CE].[ceIsPosted] = 1)      
			AND ( @PrevBalance = 1 OR       
					( @PrevBalance = 2      
					AND ( @NotesContain = '' or [CE].[enNotes] Like @strContain or [CE].[ceNotes] Like @strContain)      
					AND ( @NotesNotContain = '' or ( [CE].[enNotes] NOT Like @strNotContain and [CE].[ceNotes] NOT Like @strNotContain))  
					)  
			)  
			AND (([Type] IS NOT NULL) OR er.ParentType = 303)  
			
		IF (@ShowEmptyBalances = 0)  
			 DELETE a FROM [#Prev_B_Res] a LEFT JOIN (SELECT [AccGUID] FROM  [#result] GROUP BY [AccGUID] ) r ON r.[AccGUID] = a.[AccGUID] WHERE r.[AccGUID] IS NULL  
		IF (@SelectedUserGUID <> 0X00)  
		BEGIN  
			DELETE r FROM [#Prev_B_Res] r   
			LEFT JOIN er000 er on r.ceguid = er.entryguid LEFT JOIN    
				(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
					(  
					select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
					ON a.[RecGuid] = b.[RecGuid]   
					INNER JOIN us000 u ON [USerGuid] = u.Guid  
					WHERE a.logTime = b.logTime ) v ON v.[RecGuid] = ISNULL(er.ParentGuid,r.[CeGUID]) WHERE v.[RecGuid] IS NULL  
		END  
		--------------------------------------------------   
		EXEC [prcCheckSecurity] @UserGUID, DEFAULT, DEFAULT, '#Prev_B_Res', DEFAULT    
		
		----Filter Result by Branches And Security
		--DELETE [#Prev_B_Res] 
		--FROM [#Prev_B_Res] AS [r]
		--INNER JOIN [dbo].[fnceen_Fixed]( @CurrencyGUID) AS [CE] ON [CE].[ceGUID] = [r].[ceGuid]     
		--INNER JOIN #Account_Tbl AS [Acc] On [Acc].[Guid] = [CE].[enAccount]     
		--INNER JOIN #Cost_Tbl AS [Cost] ON [CE].[enCostPoint] = [Cost].[GUID] 
		--WHERE
		----Filter Accounts
		--[Acc].[Guid] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID))
		--OR
		----Filter Costs
		--[Cost].[GUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts](@UserGUID))
		--OR
		----Filter Ce
		--[r].[ceGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
		--------------------------------------------------   

		-- insert into result previous balance records  
		DECLARE @Prev_Balance TABLE ( [AccGUID] [UNIQUEIDENTIFIER],    
						[enDebit]	[FLOAT],   
						[enCredit]	[FLOAT])      
			    
			INSERT INTO @Prev_Balance    
			SELECT      
				[AccGUID] AS [Account],     
				SUM( [enDebit]) AS [Debit],      
				SUM( [enCredit]) AS [Credit]     
			FROM      
				[#Prev_B_Res]   
			GROUP BY       
				[AccGUID]    
					    
		-----------------------------------------------------------------      
		-- update the current balance by adding the previous balance  
		UPDATE [Balanc]     
			SET [PrevBalance] = ( [PrevBal].[enDebit] - [PrevBal].[enCredit])      
		FROM      
			@BalanceTbl AS [Balanc]   
			INNER JOIN @Prev_Balance AS [PrevBal]       
			ON [Balanc].[AccGUID] = [PrevBal].[AccGUID]     
	END  
---------------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------------- 
     
	-------------------------------------------------------------------------------------------      
	-- C O L L E C T  B A L A N C E   O F  A C C O U N T S     
	-------------------------------------------------------------------------     
	IF( @IsSingl <> 1) -- is this a general account (has sons)  
	BEGIN  
		-- calc balance by adding balances of sons (and previous balance)  
		DECLARE @Continue [INT], @Lv [INT]     
		SET @Continue = 1     
		SET @Lv = 0     
		WHILE @Continue <> 0   
		BEGIN     
			SET @Lv = @Lv + 1     
			INSERT INTO @BalanceTbl  
				SELECT     
					[Bal].[AccParent],      
					[acParent],     
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),     
					@Lv     
				FROM     
					@BalanceTbl AS [Bal]     
					INNER JOIN #Account_Tbl AS [AC]      
					ON [AC].[GUID] = [Bal].[AccParent]     
					INNER JOIN [vwAc]     
					ON [vwAc].[acGUID] = [AC].[GUID]     
				WHERE     
					[Lv] = @Lv - 1     
				GROUP BY     
					[Bal].[AccParent],     
					[acParent]     
			SET @Continue = @@ROWCOUNT      
		END	   
		IF EXISTS(SELECT * from ac000 WHERE GUID = @AccountGUID AND Type = 4)  
		BEGIN  
			INSERT INTO @BalanceTbl  
				SELECT @AccountGUID,0X00,  
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),  
					-1  
					FROM     
					@BalanceTbl AS [Bal]    INNER JOIN ci000 CI ON ci.SonGUID = [Bal].[AccGUID]  
							WHERE ci.ParentGUID =   @AccountGUID   
					  
					  
		END    
	END  
	-------------------------------------------------------------------------     
	-- now the final result  
	INSERT INTO [#Result] (      
					[AccGUID],      
					[acCode],  
					[acName],  
					[acLatinName],  
					[Path],      
					[enDebit],     
					[enCredit],     
					[enFixDebit],     
					[enFixCredit],     
					[PrevBalance],     
					[Type],
					[coSecurity],            
					[ceSecurity],      
					[accSecurity])     
				SELECT     
					[AC].[GUID],      
					[AC].[acCode],  
					[AC].[acName],  
					[AC].[acLatinName],  
					[AC].[Path],      
					0,     
					0,     
					SUM( [Bal].[FixDebit]),     
					SUM( [Bal].[FixCredit]),     
					SUM( [Bal].[PrevBalance]),     
					0,
					0, -- 23-3-2010     
					0, -- 0 it suggest hi security for entry       
					[acSecurity]     
				FROM     
					#Account_Tbl AS [AC]     
					INNER JOIN @BalanceTbl AS [Bal]     
					ON [AC].[GUID] = [Bal].[AccGUID]  
				GROUP BY     
					[AC].[GUID],      
					[acCode],  
					[acName],  
					[acLatinName],  
					[AC].[Path],      
					[acSecurity]     
				HAVING   
				(  
					 (@ShowEmptyBalances = 1) OR  
					 ( (@ShowEmptyBalances = 0) AND   
					   ( (SUM( [Bal].[FixDebit])>0 OR SUM( [Bal].[FixCredit])>0) OR ( @PrevBalance = 1 AND SUM( [Bal].[PrevBalance]) > 0)  
					    )  
					  )  
				)  
	--------------------------------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserGUID    
	
	----Filter Result by Security
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID) WHERE [IsSecViol] = 1 )
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 )
	
	--SET @NumOfSecViolated = @NumOfSecViolated + @@ROWCOUNT
	
	----Filter Result by Branches
	--DELETE FROM [#Result]
	--WHERE
	----Filter Accounts
	--[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts] (@UserGUID))
	--OR
	----Filter Costs
	--[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts](@UserGUID))
	--OR
	----Filter Ce
	--[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
	-------------------------------------------------------------------------------------------  
	IF @ShowUser > 0  
	BEGIN  
		UPDATE r SET UserName = ISNULL([LoginName],'') FROM #Result r   
		left join er000 er on r.ceguid = er.entryguid  
		LEFT JOIN    
			(SELECT a.[RecGuid],[LoginName] FROM lg000 a join  
				(  
				select max(logTime) as logTime,[RecGuid] from [LG000] WHERE  [RecGuid] <> 0X00 and repid = 0 group by  [RecGuid] ) b  
				ON a.[RecGuid] = b.[RecGuid]   
				INNER JOIN us000 u ON [USerGuid] = u.Guid  
				WHERE a.logTime = b.logTime ) v ON v.[RecGuid] =isnull( er.parentguid,r.[CeGUID] )  
	END  
	--------------------------------------------------------------------------------------------      
	CREATE TABLE #Res (     
		[Number] [INT] IDENTITY,
		[AccGuid] [UNIQUEIDENTIFIER],      
		[AccCode] [VARCHAR](200) COLLATE ARABIC_CI_AI,    
		[AccName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[AccLName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceGuid] [UNIQUEIDENTIFIER],      
		[enGuid] [UNIQUEIDENTIFIER] DEFAULT 0x0,      
		[ceNumber] [INT],      
		[ceDate] [DATETIME],   
		[enNumber] [INT],   
		[Debit] [FLOAT],      
		[Credit] [FLOAT], 
		[SubBalance] [FLOAT],     
		[curDebit] [FLOAT],      
		[curCredit] [FLOAT],      
		[CurGuid] [UNIQUEIDENTIFIER],      
		[CurVal] [FLOAT],      
		--ObverseGUID [UNIQUEIDENTIFIER],      
		[CostGUID] [UNIQUEIDENTIFIER],   
		[enNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceNotes] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseCode] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ObverseLName] [VARCHAR](250) COLLATE ARABIC_CI_AI,    
		[ceParentGUID] [UNIQUEIDENTIFIER],      
		[RepType] [INT],      
		[AccType] [INT],	-- 0 Main Account 1 Sub Account      
		[PrevBalance] [FLOAT],     
		[PATH] [VARCHAR](4000),    
		[ParentNumber] [INT],   
		[ParentName] [VARCHAR](250) COLLATE ARABIC_CI_AI,   
		[Level] [INT],   
		[IsCheck] [INT],  
		[Class] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[BranchGuid] [UNIQUEIDENTIFIER],  
		[Branch] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[LatinBranch] [VARCHAR](250) COLLATE ARABIC_CI_AI,  
		[UserName] [VARCHAR](100) COLLATE ARABIC_CI_AI	,[Posted] BIT)   
		--UserCheckGuid [UNIQUEIDENTIFIER] DEFAULT 0x0)   
		  
	-- delete any account not to be displayed  
	INSERT INTO #Res  
	(
		[AccGuid] ,      
		[AccCode] ,    
		[AccName] ,    
		[AccLName] ,    
		[ceGuid] ,      
		[enGuid] ,      
		[ceNumber] ,      
		[ceDate] ,   
		[enNumber] ,   
		[Debit] ,      
		[Credit] ,   
		[SubBalance],   
		[curDebit] ,      
		[curCredit] ,      
		[CurGuid] ,      
		[CurVal] ,      
		      
		[CostGUID] ,   
		[enNotes] ,    
		[ceNotes] ,    
		[ObverseCode] ,    
		[ObverseName] ,    
		[ObverseLName] ,    
		[ceParentGUID] ,      
		[RepType] ,      
		[AccType] ,	-- 0 Main Account 1 Sub Account      
		[PrevBalance] ,     
		[PATH] ,    
		[ParentNumber] ,   
		[ParentName],   
		[Level] ,   
		[IsCheck],  
		[Class],  
		[BranchGuid],  
		[Branch],  
		[LatinBranch] ,  
		[UserName] ,[Posted]
	)    
	SELECT       
		[RES].[AccGuid] AS [AccGuid],      
		[RES].[acCode] AS [AccCode],      
		[RES].[acName] AS [AccName],      
		[RES].[acLatinName] AS [AccLName],      
		[RES].[ceGuid] AS [ceGuid],      
		[RES].[enGuid] AS [enGuid],   
		[RES].[ceNumber] AS [ceNumber],      
		[RES].[ceDate] AS [ceDate],      
		[RES].[enNumber] AS [enNumber],   
		[RES].[enFixDebit]  AS [Debit],      
		[RES].[enFixCredit] AS [Credit], 
		[RES].[enFixDebit] - [RES].[enFixCredit] AS [SubBalance],     
		[RES].[enDebit] AS [curDebit],      
		[RES].[enCredit] AS [curCredit],      
		[RES].[enCurPtr] AS [CurGuid],      
		[RES].[enCurVal] AS [CurVal],      
		ISNULL( [RES].[CostGUID], 0x0) AS [CostGUID],   
		[RES].[enNotes] AS [enNotes],  
		[RES].[ceNotes],      
		ISNULL( [ObvacCode], '') AS [ObverseCode],   
		ISNULL( [ObvacName], '') AS [ObverseName],   
		ISNULL( [ObvacLatinName], '') AS [ObverseLName],       
		[RES].[ceParentGUID] AS [ceParentGUID],      
		[RES].[ceRecType] AS [RepType],      
		[RES].[Type] AS [AccType],	-- 0 Main Account 1 Sub Account      
		ISNULL( [RES].[PrevBalance], 0) AS [PrevBalance],     
		[RES].[Path],    
		[RES].[ParentNumber],   
		[RES].[ParentName],   
		CASE WHEN [RES].[ceGuid] IS NULL THEN [Level] ELSE [Level] + 1 END,   
		[IsCheck] ,  
		[Class],[Branch],'','',[UserName],[Posted]  
		--UserCheckGuid   
	FROM      
		[#Result] AS [RES] INNER JOIN #Account_Tbl AS [AC] ON [RES].[AccGUID] = [AC].[GUID]      
	WHERE    
		[RES].[Type] = 0 OR [RES].[enDebit] <> 0 OR [RES].[enCredit] <> 0 OR [RES].[PrevBalance] <> 0   
		ORDER BY [RES].[Path], [RES].[Type], dbo.fnGetDateFromTime([RES].[ceDate]) , [RES].[ceNumber], [RES].[enNumber]  
	-- End Result   
	-- return the final result  
	IF (@ShowBranch > 0)  
		UPDATE	[r] SET	[Branch] = br.[Name],[LatinBranch] = br.[LatinName]  
		FROM #Res [r] INNER JOIN [br000] br ON 	br.Guid = [BranchGuid]  
		
----------------------------------Prepare Subbalance-----------------------------
UPDATE MainRes SET MainRes.[SubBalance] = MainRes.[SubBalance] + (SELECT ISNULL(SUM(PartRes.[SubBalance]), 0) FROM #RES PartRes WHERE PartRes.Number<MainRes.Number AND PartRes.AccGUID = MainRes.AccGUID AND PartRes.AccType <> 0) + (SELECT [PrevBalance] FROM #RES ParentPrevBal WHERE ParentPrevBal.AccGUID = MainRes.AccGUID AND ParentPrevBal.AccType = 0)
FROM #RES MainRes WHERE MainRes.AccType <>0
---------------------------------------------------------------------------------
	IF Exists(Select * From #SecViol)
		SET @IsFullResult = 0
	ELSE
		SET @IsFullResult = 1
	
	DECLARE @SQL NVARCHAR (4000) 
	SET @SQL = 'SELECT #Res.[Number],  
		[AccGuid],  
		[AccCode],  
		[AccName],  
		[AccLName],  
		ISNULL( [ceGuid], 0x0) AS [ceGuid],  
		ISNULL( [enGuid], 0x0) AS [enGuid],  
		ISNULL( [ceNumber], 0) AS [ceNumber],  
		ISNULL( [ceDate],'''+ CAST (GetDate() AS VARCHAR(50))+''') AS [ceDate],  
		--ISNULL( enNumber,0) AS enNumber,  
		ISNULL( #Res.[Debit], 0) AS [Debit],  
		ISNULL( #Res.[Credit], 0) AS [Credit],
		ISNULL( #Res.[SubBalance], 0) AS [SubBalance],
		ISNULL( [curDebit], 0) AS [curDebit],  
		ISNULL( [curCredit], 0) AS [curCredit],  
		ISNULL( [CurGuid], 0x0) AS [CurGuid],  
		ISNULL( [CurVal], 0) AS [CurVal],
		ISNULL( [EvlCur].[Code], '''')			AS [EvlCurCode],
		ISNULL( [EvlCur].[Name], '''')			AS [EvlCurName],    
		ISNULL( [EvlCur].[LatinName], '''')		AS [EvlCurLatinName],
		ISNULL( [EvlCur].[PartName], '''')		AS [EvlCurPartName], 
		ISNULL( [EvlCur].[LatinPartName], '''') AS [EvlCurLatinPartName],        
		--@AccountGUID AS ObverseGUID,  
		ISNULL( [CostGUID], 0x0) AS [CostGUID],  
		ISNULL( [enNotes], '''') AS [enNotes],  
		--ISNULL( [ceNotes], '''') AS [ceNotes],  
		ISNULL( [ObverseCode], '''') AS [ObverseCode],  
		ISNULL( [ObverseName], '''') AS [ObverseName],  
		ISNULL( [ObverseLName], '''') AS [ObverseLName],  
		ISNULL( [ceParentGUID], 0x0) AS [ceParentGUID],  
		ISNULL( [RepType], 0) AS [RepType],  
		ISNULL( [AccType], 0) AS [AccType],  
		ISNULL( [PrevBalance], 0) AS [PrevBalance],  
		ISNULL( [ParentNumber], 0) AS [ParentNumber],  
		ISNULL( [ParentName], '''') AS [ParentName],  
		ISNULL( [IsCheck], 0) AS [IsCheck], ' 
	
	SET @SQL = @SQL + ' ISNULL( enNumber,0) AS enNumber, ' 
	SET @SQL = @SQL + '(CASE WHEN curDebit>0 THEN ' + '''[ ''' + ' + enCurr.CODE + ' + ''' ''' + ' + CAST(CurVal AS VARCHAR(100)) + ' + ''']''' + '+ CAST(curDebit/ISNULL(CurVal,1) AS VARCHAR(100)) ' + ' ELSE (CASE WHEN curCredit>0 THEN ' + '''[ ''' + ' + enCurr.CODE + ' + ''' ''' + ' + CAST(CurVal AS VARCHAR(100)) + ' + ''']''' + '+ CAST(curCredit/ISNULL(CurVal,1) AS VARCHAR(100)) ' +' ELSE ' +''' '''+ ' END) END) As OriginalCurrency, ' 	
	SET @SQL = @SQL + ' ISNULL(Cost.Name, '''') As CostName, ' 
	SET @SQL = @SQL + ' ISNULL( [ceNotes], '''') AS [ceNotes], '
				   

	--DebitExchangeVariations
	SET @SQL = @SQL + '(CASE WHEN #Res.CurGUID = ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' 
	SET @SQL = @SQL +      ' THEN #Res.Debit * (#Res.CurVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      ' ELSE ' 
	SET @SQL = @SQL + 		'(CASE WHEN #Res.CurGUID <> ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' + ' AND #Res.CurGUID <> 0x0'
	SET @SQL = @SQL +      		' THEN #Res.Debit * (EvlCur.CurrencyVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      		' ELSE 0.0 END) END) AS DebitExchangeVariations, ' 
	
	--CreditExchangeVariations
	SET @SQL = @SQL + '(CASE WHEN #Res.CurGUID = ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' 
	SET @SQL = @SQL +      ' THEN #Res.Credit * (#Res.CurVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      ' ELSE '
	SET @SQL = @SQL + 		'(CASE WHEN #Res.CurGUID <> ' + '''' + CAST(@CurrencyGUID AS VARCHAR(100)) + '''' + ' AND #Res.CurGUID <> 0x0'
	SET @SQL = @SQL +      		' THEN #Res.Credit * (EvlCur.CurrencyVal - ' + CAST(@CurVal AS VARCHAR(100)) + ') / ' + CAST(@CurVal AS VARCHAR(100))
	SET @SQL = @SQL +      		' ELSE 0.0 END) END) AS CreditExchangeVariations, ' 
	SET @SQL = @SQL + '(CASE WHEN #Res.[RepType] > 1 THEN ' 
	SET @SQL = @SQL + '#Res.[ParentName] + ' + ''': ''' + ' + CAST(#Res.[ParentNumber] AS VARCHAR(100))' + 'ELSE ' + '''''' +'END)AS OriginalCe,' 	 	
	SET @SQL = @SQL + 'ISNULL([Branch],'''') AS [BrName], '
	SET @SQL = @SQL + 'ISNULL([LatinBranch],'''') AS [BrLatinName], '
	
	SET @SQL = @SQL + '(CASE WHEN (#Res.[ObverseName]  <> '''' AND UPPER(SUBSTRING( ''' + @Lang + '''' + ', 1, 2))  = ''AR'') THEN #Res.[ObverseName] +' + '''-''' + ' + #Res.[ObverseCode] ELSE ' 
	SET @SQL = @SQL + '(CASE WHEN (#Res.[ObverseLName] <> '''' AND UPPER(SUBSTRING( ''' + @Lang + '''' + ', 1, 2))  = ''EN'') THEN #Res.[ObverseCode] +' + '''-''' + ' + #Res.[ObverseLName] ELSE '''' END) END) AS ContraAcc, '
	SET @SQL = @SQL + '[UserName], '
		
	SET @SQL = @SQL + 'ISNULL([Class],'''') AS [Class], ' 
		
	SET @SQL = @SQL + ' [Posted], ''' + CAST(@IsFullResult AS VARCHAR(100)) + '''' + ' AS NumOfSecViolated'
		  
	SET @SQL = @SQL + ' FROM  #Res LEFT JOIN MY000 enCurr ON #Res.CurGuid = enCurr.GUID '
	SET @SQL = @SQL + 	     ' LEFT JOIN MY000 EvlCur ON EvlCur.GUID = ' + '''' + CAST(@CurrencyGUID AS Varchar(1000)) + ''''
	SET @SQL = @SQL + 	     ' LEFT JOIN co000 Cost ON #Res.CostGUID = Cost.GUID ' 
	SET @SQL = @SQL + ' WHERE ( ' 
	SET @SQL = @SQL + CAST (@Level AS VARCHAR(4)) 
	SET @SQL = @SQL + ' = 0 OR [Level] < ' 
	SET @SQL = @SQL + CAST( @Level AS VARCHAR (4)) 
	SET @SQL = @SQL +' ) ORDER BY [Path], [AccType], dbo.fnGetDateFromTime([ceDate]) , [ceNumber], [enNumber] ' 
	EXEC (@SQL) 

	--prcFinalize_Environment 
	EXEC [prcFinilize_Environment] '[repGeneralLedger]'
#########################################################
CREATE PROCEDURE ARWA.repCPS_WithDetails
	@UserId			AS [UNIQUEIDENTIFIER],    
	@EndDate		AS [DATETIME],     
	@CurPtr			AS [UNIQUEIDENTIFIER],      
	@CurVal			AS [FLOAT],      
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz      
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d      
	@Contain		AS [VARCHAR](1000),      
	@NotContain		AS [VARCHAR](1000),      
	@UseChkDueDate	AS [INT],     
	@ShowChk		AS [INT],  
	@CostGuid		AS [UNIQUEIDENTIFIER],  
	@ShowAccMoved   AS [INT] = 0,  
	@StartBal		AS [INT] = 0,  
	@bUnmatched		AS [INT] = 1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowDiscExtDet AS [INT] = 0, 
	@ShowOppAcc		AS [INT] = 0
AS  
		SET NOCOUNT ON  
	DECLARE	        
		@ContainStr		[VARCHAR](1000),        
		@NotContainStr	[VARCHAR](1000)    
		   
	DECLARE @StDate [DATETIME]    
	-- prepare Parameters:	       
	SET @ContainStr = '%' + @Contain + '%'       
	SET @NotContainStr = '%' + @NotContain + '%'  
	      
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT) 
	INSERT INTO @Curr  
	SELECT DATE,CurrencyVal FROM mh000 WHERE CURRENCYGuid = @CurPtr AND DATE <= @EndDate 
	UNION ALL  
	SELECT  '1/1/1980',CurrencyVal FROM MY000 WHERE Guid = @CurPtr 
	         
	-- get CustAcc	       
	--SELECT  cu.Guid,AccountGUID FROM cu000 AS cu INNER JOIN CUST1 AS cu1 ON cu.GUID = cu1.nUMBER       
	-- 	INSERT BILLS MOVE   
	SELECT        
		[cu].[Number] AS [cuNumber],       
		[cu].[Security] AS [cuSecurity],       
		[buType],       
		[buSecurity],       
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
		[buGUID],       
		[buNumber],     
		[buDate],       
		[biNumber],        
		[buNotes],       
		CASE       
				WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0      
				ELSE 1 END  AS [IsCash] ,      
		CASE [btVatSystem] WHEN 2 THEN [BuTotal] ELSE ([BuTotal]+[BuVAT]) END * Factor AS [BillTotal],       
		CASE [btVatSystem] WHEN 2 THEN 0 ELSE [BuVAT] * Factor END [FixedBuVAT],       
		[buItemsDisc] * factor [FixedbuItemsDisc],  
		 [BuBonusDisc] * factor [FixedBuBonusDisc],   
		[buItemsExtra] * factor [FixedbuItemExtra],  
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
		[biMatPtr],       
		[St].[stName] AS [stName],     
		[biQty],       
		[biBonusQnt],       
		[biUnity],       
		[biQty2],       
		[biQty3],       
		[biExpireDate],       
		[biProductionDate],       
		[biCost_Ptr] [biCostPtr],       
		[biClassPtr],       
		[biLength],       
		[biWidth],       
		[biHeight],    
		[biCount],       
		([BiPrice] + CASE [btVatSystem] WHEN 2 THEN ([BiPrice] /*- (([FixedBiDiscount] + [FixedbiBonusDisc]) / [biQty])*/) * biVATRatio/100 ELSE 0 END) * Factor [FixedBiPrice],       
		[BiDiscount] * Factor [FixedBiDiscount],   
		[biBonusDisc] * Factor [FixedbiBonusDisc],      
		[biExtra]* Factor  [FixedbiExtra],       
		[biNotes],       
		[buSalesManPtr],   
		[buVendor],    
		[mtSecurity],  
		Factor [FixedCurrencyFactor],  
		[cu].[AccountGuid],  
		[BuTotal] * Factor [FixedBuTotal],  
		[btDirection],  
		[btType] AS [btBillType],  
		[buTextFld1],  
		[buTextFld2],  
		[buTextFld3],  
		[buTextFld4],  
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS     
		INTO [#Bill]	   
		FROM    
			(SELECT * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor  from [fn_bubi_FixedCps]( 0X00,0X00)) AS [bi]  
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
			INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]   
			INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
			INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
	WHERE        
		[buDate] <= @EndDate       
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)       
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
		AND NOT([btType] = 3 or [btType] = 4)  
	 
	INSERT INTO [#Bill]	 
	SELECT        
		[cu].[Number] AS [cuNumber],       
		[cu].[Security] AS [cuSecurity],       
		[buType],       
		[buSecurity],       
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		       
		[buGUID],       
		[buNumber],     
		[buDate],       
		[biNumber],        
		[buNotes],       
		0 [IsCash] ,      
		CASE [btVatSystem] WHEN 2 THEN [BuTotal] ELSE ([BuTotal]+[BuVAT]) END  * Factor AS [BillTotal],       
		[BuVAT] * Factor,       
		[buItemsDisc] * Factor,  
		[BuBonusDisc] * Factor,   
		[buItemsExtra] * Factor [FixedbuItemExtra],  
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],       
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],       
		[biMatPtr],       
		[St].[stName] AS [stName],     
		[biQty],       
		[biBonusQnt],       
		[biUnity],       
		[biQty2],       
		[biQty3],       
		[biExpireDate],       
		[biProductionDate],       
		[biCost_Ptr] [biCostPtr],       
		[biClassPtr],       
		[biLength],       
		[biWidth],       
		[biHeight],    
		[biCount],       
		[BiPrice] * Factor,       
		[BiDiscount] * Factor,   
		[biBonusDisc] * Factor,      
		[biExtra] * Factor,       
		[biNotes],       
		[buSalesManPtr],   
		[buVendor],    
		[mtSecurity],  
		Factor [FixedCurrencyFactor],  
		[cu].[AccountGuid],  
		[BuTotal] * Factor,  
		[btDirection],  
		[btType] AS [btBillType],  
		[buTextFld1],  
		[buTextFld2],  
		[buTextFld3],  
		[buTextFld4],  
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],  
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS     
		   
		FROM    
			(select * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor  from [fn_bubi_FixedCps]( 0X00,0X00)   ) AS [bi]  
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]   
			INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc]  
			INNER JOIN [vwSt] AS st ON [st].[stGUID] = [bi].[biStorePtr]   
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr]  
			INNER JOIN [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid]  
	WHERE        
		[buDate] <= @EndDate       
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)       
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))       
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))       
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))       
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))       
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
		AND ([btType] = 3 or [btType] = 4) 
	 
	 
	CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID])	  
	UPDATE b SET [BillTotal] = [BillTotal] - (V*[FixedCurrencyFactor]) from [#Bill] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [buGUID] where VS = 1  
	SELECT  SUM( CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount] /CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END)  
	 AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra] 
	INTO [#Disc]  
	FROM [di000] AS di2   
	INNER JOIN (SELECT DISTINCT 1/ [FixedCurrencyFactor] [FixedCurrencyFactor],[AccountGuid],[buGuid] FROM  [#Bill]) AS [b] ON [b].[buGuid] = [di2].[ParentGuid]  
	WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)  
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],       
		[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],       
		[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],       
		[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc])       
		SELECT        
			[cuNumber],       
			[CuSecurity],       
			[buType],       
			[buSecurity],       
			[btSecurity], 		       
			[buGUID],       
			[buNumber],     
			[buDate],       
			[biNumber],        
			[buNotes],       
			[IsCash],      
			[BillTotal],       
			[FixedBuVAT],       
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0),       
			[FixedbuItemExtra] + ISNULL([Extra],0),--FixedBuTotalExtra,       
			[FixedBuFirstPay],       
			[btReadPriceSecurity],       
			[biMatPtr],       
			[stName],     
			[biQty],       
			[biBonusQnt],       
			[biUnity],       
			[biQty2],       
			[biQty3],       
			[biExpireDate],       
			[biProductionDate],       
			[biCostPtr],       
			[biClassPtr],       
			[biLength],       
			[biWidth],       
			[biHeight],   
			[biCount],       
			[FixedBiPrice],       
			[FixedBiDiscount],       
			[FixedbiExtra],  
			[biNotes],       
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) )* CASE WHEN ([btBillType] = 3 OR [btBillType] = 4 OR [btBillType] = 2) THEN [btDirection] ELSE -[btDirection] END ), 0),   
			[buSalesManPtr],   
			[buVendor],    
			[mtSecurity],   
			[buTextFld1],  
			[buTextFld2],  
			[buTextFld3],  
			[buTextFld4],  
			2 -- Flag   
			,[buFormatedNumber],[buBranch] ,[FixedbiBonusDisc]    
		FROM    
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID]  
	 
	 
	
		UPDATE r SET [DueDate] = pt.[DueDate]  FROM [#Result] r INNER JOIN pt000 pt ON pt.RefGuid = r.[Guid]  
		WHERE Flag = 2 
		UPDATE r  
			SET CHGuid = b.Guid,CHTypGuid = b.TypeGuid,chNumber = b.Number,[DueDate] = b.[DueDate] 
			FROM [#Result] r 
			INNER JOIN  (SELECT Guid,TypeGuid,DueDate,ParentGuid,Number FROM vbch ch WHERE state = 0 AND  ParentGuid <> 0x00 AND DueDate = (select MIN(DueDate) DueDate FROM vbch cc WHERE cc.[State] = 0 AND  cc.ParentGuid = ch.ParentGuid)) b ON b.ParentGuid = r.[Guid]  
			WHERE Flag = 2 
	 
	
	-- INSERT ENTRY  
	IF (@ShowDiscExtDet <> 0)  
	BEGIN  
		SELECT  
			[cuNumber],       
			[CuSecurity],    
			[buType],   
			[buSecurity],  
			[btSecurity], 		   
			[buGUID] [BillGUID],   
			[buNumber],     
			[buDate],  
			[di2].[Notes] AS [buNotes],  
			[di2].[Discount]*[FixedCurrencyFactor] AS [Discount] ,  
			[di2].[Extra]*[FixedCurrencyFactor] AS [Extra],  
			[ac].[acCode] + '-' +[ac].[acName] AS [acCodeName],  
			[ac].[acGuid],  
			[ac].[acSecurity]  
			INTO [#DetDiscExt]  
			FROM [di000] AS [di2]   
			INNER JOIN (SELECT DISTINCT [cuNumber],[CuSecurity],[buType],[buSecurity],[btSecurity],[buNumber],[buDate],[FixedCurrencyFactor],[buGuid],[AccountGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]  
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] = [di2].[AccountGuid]  
			WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)  
		EXEC [prcCheckSecurity]  @result = '#DetDiscExt'  
		INSERT INTO #RESULT ([CustPtr],[CustSecurity],[MatPtr],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[BNotes],[EntryDebit],[EntryCredit],[OppAccName],[Flag])  
		SELECT  
			[cuNumber],       
			[CuSecurity],  
			[acGuid],   
			1,  
			[buType],   
			[buSecurity],  
			[btSecurity], 		   
			[BillGUID],   
			[buNumber],     
			[buDate],  
			[buNotes],  
			[Discount],  
			[Extra],  
			[acCodeName],  
			2  
		FROM #DetDiscExt  
			  
	END  
	SELECT       
		[cu].[Number] AS [cuNumber],       
		[Cu].[Security] AS [cuSecurity],        
		[f].[ceTypeGuid],   
		[f].[enGuid],    
		[f].[ceSecurity],        
		[t].[Security],       
		CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END [ceGuid],     
		[f].[ceNumber],     
		[f].[enDate],        
		[f].[enNumber],        
		[f].[ceNotes],        
		[f].enDebit * Factor [FixedEnDebit] ,        
		[f].[EnCredit] * Factor  [FixedEnCredit],        
		[f].[enNotes] ,        
		ISNULL(([f].enDebit - [f].[EnCredit]), 0) * Factor AS [Balance],       
		[enContraAcc],   
		CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END ELSE 1 END AS [FFLAG],    
		[er].[erParentType],  
		[t].[Flag],  
		ISNULL([er].[erParentGuid],0X00) [erParentGuid],  
		[f].[enAccount],  
		[f].[enCostPoint],  
		[ceBranch]  
	INTO [#ENTRY]  
	FROM        
		(SELECT *,1 / CASE WHEN enCurrencyPtr = @CurPtr  THEN enCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  endate  ORDER BY DATE DESC) END Factor FROM vwCeEn) AS [f]  
		INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] =[f].[enAccount]      
		LEFT JOIN [vwEr] AS [er]       
		ON [f].[ceGuid] = [er].[erEntryGuid]       
		INNER JOIN [#EntrySource] AS [t]       
		ON [f].[ceTypeGuid] = [t].[Type]     
	WHERE       
		 [f].[enDate] <= @EndDate  
		AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr) )       
		AND (( @NotContain = '') OR ( [f].[enNotes] NOT LIKE @NotContainStr) OR ( [f].[ceNotes] NOT LIKE @NotContainStr))       
 		  
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid])  
	INSERT INTO [#Result]  ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[biNumber], [BNotes],[UserReadPriceSecurity],[CostPtr],[ClassPtr],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[enGuid])       
		SELECT       
			[cuNumber],       
			[CuSecurity],  
			[ceTypeGuid],     
			[ceSecurity],        
			[#ENTRY].[Security],       
			[ceGuid],     
			[ceNumber],     
			[enDate],        
			[enNumber],        
			[ceNotes],        
			3,--	UserReadPriceSecurity       
			[enCostPoint],--	CostPtr,        
			'',--	ClassPtr,        
			[FixedEnDebit],  -- EntryDebit        
			[FixedEnCredit], -- EntryCredit,        
			[enNotes] ,        
			[Balance],       
			[enContraAcc],  
			[FFlag],  
			[ceBranch],[enGuid]  
		FROM  
			[#ENTRY]  
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid]  
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE       
			 (([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] in (6, 7, 8))) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )      
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  )))  
			OR ([Flag] = 3 and [erParentType] = 600) 
	  
	-- 	INSERT Normal Entry Move      
	  
	IF (@ShowOppAcc = 1)  
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]   
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]   
---------------------------------------------------------------------------       
	IF( @UseChkDueDate = 0)        
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[branch],[CostPtr],[buTextFld1])       
			SELECT        
				[cu].[Number],       
				[Cu].[Security],        
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDate],       
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor       
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor 
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor        
					ELSE -[ch].[chVal] * Factor       
					END), -- Balance    
				5,[chbranchGuid],[chCost1GUID]  ,chnum   
			FROM        
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]   
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]   
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]         
				      
			WHERE        
				 (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))       
				AND [chDate] <= @EndDate        
				AND [chState] != 0           
	ELSE IF ( @UseChkDueDate = 1)       
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])       
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chDueDate],       
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor  
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor     
					ELSE -[ch].[chVal]* Factor     
					END), -- Balance     
				5 ,chbranchGuid,[chCost1GUID] ,chnum    
			FROM        
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]            
			WHERE        
				(( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))       
				AND [chDueDate] <= @EndDate        
				AND [chState] != 0     
	ELSE        
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])        
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				[ch].[chColDate],       
				[ch].[chNotes],       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor      
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor     
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor       
					ELSE  -[ch].[chVal]  * Factor       
					END), -- Balance     
				5,chbranchGuid,[chCost1GUID],chnum   
			FROM        
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]            
			WHERE        
				(( @Contain = '') OR ([chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))       
				AND [chColDate] <= @EndDate        
				AND [chState] != 0           
-----------------------------------------------------------------------------------       
-----------------------------------------------------------------------------------       
	IF( @ShowChk > 0)        
		INSERT INTO        
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])         
			SELECT        
				[cu].[Number],       
				[Cu].[Security],      
				0,       
				[ch].[chType],       
				[ch].[chSecurity],       
				[nt].[Security],       
				[ch].[chGUID],       
				[ch].[chNumber],     
				CASE @UseChkDueDate  WHEN 1 THEN  [ch].[chDueDate] ELSE [chDate] END,       
				[ch].[chNotes],        
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] *  Factor    
					ELSE 0        
					END), -- EntryDebit       
				(Case        
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0        
					END), -- EntryCredit       
				(Case        
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor      
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1,chbranchGuid,[chCost1GUID] ,chnum    
			FROM        
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END  Factor FROM [vwCh]) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]   
			WHERE        
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)  
				AND [chState] = 0        
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))       
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))   
				  
----------------------------------------------------------------------  
--Delete  Check With No Edit Entry  
	IF (@ShwChWithEn = 1)  
		DELETE [#Result] WHERE ([Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] =5)  
----------------------------------------------------------------------        
	EXEC [prcCheckSecurity] @UserId       
	SELECT    SUM(ISNULL([Balance], 0)) AS [PriveBalance],[cu].[Number] as [CustPtr],  SUM(ISNULL([RBalance],0))  AS [RBalance]   INTO [#PREVBAL] FROM        
		(SELECT DISTINCT [Type], [Guid], [Balance], [flag] ,'' AS [Notes],[CustPtr]  ,0.00 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2    
			UNION ALL   
	     SELECT  [Type], [Guid], [Balance], [flag], [Notes], [CustPtr], 0 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <>2 ) AS [p]   
	RIGHT JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [p].[CustPtr]	  
	GROUP BY  
		[cu].[Number]      
	  
	IF @StartBal=1   
		UPDATE [#PREVBAL] SET [PriveBalance] = 0  
		       
	DELETE [#Result] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate]  
	   
	IF @bUnmatched =1   
		 UPDATE [#PREVBAL] SET [RBalance] = [dbo].[fnAccount_getBalance]([cu].[AccountGuid],@CurPtr,CASE @StartBal WHEN 0 THEN '1/1/1980' ELSE [cu].[FromDate]  END,@EndDate,@CostGuid)   
	 		 FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]   
			     
	IF (@ShowAccMoved=1)  
		DELETE [#PREVBAL] WHERE [CustPtr] NOT IN (SELECT DISTINCT [CustPtr] FROM [#RESULT])  
	  
	INSERT INTO [#Result]([CustPtr],[Date],[BuTotal],[Balance],[Flag]) SELECT [CustPtr], [cu].[FromDate], [PriveBalance], [RBalance], 0   FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [r].[CustPtr] 
#########################################################
CREATE PROCEDURE ARWA.repCPS_WithoutDetails
	@UserId			AS [UNIQUEIDENTIFIER],   
	@EndDate		AS [DATETIME],   
	@CurPtr			AS [UNIQUEIDENTIFIER],   
	@CurVal			AS [FLOAT],   
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz   
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d   
	@Contain		AS [VARCHAR](1000),   
	@NotContain		AS [VARCHAR](1000),   
	@UseChkDueDate	AS [INT],   
	@ShowChk		AS [INT],  
	@CostGuid		AS [UNIQUEIDENTIFIER],  
	@ShowAccMoved   AS [INT] = 0,  
	@StartBal		AS [INT] = 0,  
	@bUnmatched		AS [INT] =1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowOppAcc		AS [INT] = 0, 
	@haveAccOnly	[BIT] = 0
AS   
	SET NOCOUNT ON 
	DECLARE	       
		@ContainStr		[VARCHAR](1000),       
		@NotContainStr	[VARCHAR](1000)      
		 
	DECLARE @StDate  [DATETIME]  
	-- prepare Parameters:	      
	SET @ContainStr = '%' + @Contain + '%'      
	SET @NotContainStr = '%' + @NotContain + '%'      
	 
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT) 
	INSERT INTO @Curr  
	SELECT DATE,CurrencyVal FROM mh000 WHERE CURRENCYGuid = @CurPtr And DATE <= @EndDate 
	UNION ALL  
	SELECT  '1/1/1980',CurrencyVal FROM MY000 WHERE Guid = @CurPtr  
	-- get CustAcc	      
	-- 	INSERT BILLS MOVE   
	SELECT DISTINCT 
		[cu].[Number] AS [cuNumber],      
		[cu].[Security] AS [cuSecurity],      
		[buType],      
		[buSecurity],      
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		      
		[buGUID],      
		[buNumber],    
		[buDate],      
		[biNumber],       
		[buNotes],      
		CASE      
			WHEN [buCustAcc] = [cu].[AccountGuid]  THEN 0     
			ELSE 1 END    
		AS [IsCash] ,     
		CASE [btVatSystem] WHEN 2 THEN [BuTotal] ELSE ([BuTotal]+[BuVAT]) END * Factor AS [BillTotal],      
		[BuVAT] * Factor FixedbuVat,      
		[buItemsDisc] * Factor [FixedbuItemsDisc], 
		[BuBonusDisc] * Factor [FixedBuBonusDisc],  
		[buItemsExtra] * Factor [FixedbuItemExtra], 
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],      
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
		[buSalesManPtr],  
		[buVendor],   
		Factor [FixedCurrencyFactor], 
		[cu].[AccountGuid], 
		[BuTotal] * Factor [FixedBuTotal], 
		[btDirection], 
		[btType], 
		[bi].[buMatAcc], 
		CASE [btType] WHEN  3 THEN 1 WHEN 4 THEN 1 WHEN  2 THEN 1 ELSE -1 END AS [DIR], 
		[buTextFld1], 
		[buTextFld2], 
		[buTextFld3], 
		[buTextFld4], 
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],[biCostPtr], 
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS       
		INTO [#Bill]	  
		FROM   
		(SELECT * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor from [fn_bubi_FixedCps]( 0X00,0X00) ) AS [bi]  
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]  
		INNER JOIN [#CUST1] AS [cu] ON [cu].[Number] = [bi].[buCustPtr]  --OR ([cu].[AccountGuid] = [bi].[buMatAcc] ) 
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
	WHERE       
		[buDate] <= @EndDate      
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))      
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))      
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )      
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr))) 
		AND NOT([btType] = 3 or [btType] = 4)  
	INSERT INTO [#Bill]	  
	SELECT DISTINCT 
		[cu].[Number] AS [cuNumber],      
		[cu].[Security] AS [cuSecurity],      
		[buType],      
		[buSecurity],      
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END AS [btSecurity], 		      
		[buGUID],      
		[buNumber],    
		[buDate],      
		[biNumber],       
		[buNotes],      
		0 AS [IsCash] ,     
		CASE [btVatSystem] WHEN 2 THEN [BuTotal] ELSE ([BuTotal]+[BuVAT]) END  * Factor AS [BillTotal],      
		[BuVAT] * Factor [BuVAT],      
		[buItemsDisc] * Factor [FixedbuItemsDisc], 
		[BuBonusDisc]  * Factor [FixedBuBonusDisc],  
		[buItemsExtra]  * Factor [FixedbuItemExtra], 
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor  END AS [FixedBuFirstPay],      
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
		[buSalesManPtr],  
		[buVendor],   
		Factor, 
		[cu].[AccountGuid], 
		[BuTotal] * Factor, 
		[btDirection], 
		[btType], 
		[bi].[buMatAcc], 
		CASE [btType] WHEN  3 THEN 1 WHEN 4 THEN 1 WHEN  2 THEN 1 ELSE -1 END AS [DIR], 
		[buTextFld1], 
		[buTextFld2], 
		[buTextFld3], 
		[buTextFld4], 
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch],[biCostPtr], 
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS       
		 
		FROM   
		(SELECT * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor  from [fn_bubi_FixedCps]( 0X00,0X00)  ) AS [bi]  
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]  
		INNER JOIN [#CUST1] AS [cu] ON [cu].[AccountGuid] = [bi].[buMatAcc] 
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
	WHERE       
		[buDate] <= @EndDate      
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR [cu].[AccountGuid] <> [buCustAcc]))      
			OR( @Cash = 2 AND ([cu].[AccountGuid] = [buCustAcc] OR [cu].[AccountGuid] = [bi].[buMatAcc])))      
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )      
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr))) 
		AND ([btType] = 3 or [btType] = 4)  
    CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID]) 
	UPDATE b SET [BillTotal] = [BillTotal] - V from [#Bill] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [buGUID] where VS = 1 
	SELECT  SUM( CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount] /CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END)  
	 AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra] 
	INTO [#Disc]  
	FROM [di000] AS di2   
	INNER JOIN (SELECT DISTINCT 1/[FixedCurrencyFactor] [FixedCurrencyFactor],[AccountGuid],[buGuid] FROM  [#Bill]) AS [b] ON [b].[buGuid] = [di2].[ParentGuid]  
	WHERE [di2].[ContraAccGuid] = [B].[AccountGuid] OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0)  
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 
	    
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],      
		[Number],[Date],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuFirstPay],[UserReadPriceSecurity],      
		[Notes],[Balance],[SalesMan],[Vendor],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[CostPtr] )       
		SELECT DISTINCT       
			[cuNumber],      
			[CuSecurity],     
			[buType],      
			[buSecurity],      
			[btSecurity], 		      
			[buGUID],      
			[buNumber],      
			[buDate],      
			[buNotes],      
			[IsCash],      
			[BillTotal],      
			[FixedBuVAT],      
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0),      
			[FixedbuItemExtra] + ISNULL([Extra],0),--FixedBuTotalExtra,  
			[FixedBuFirstPay],      
			[btReadPriceSecurity],       
			'',      
			ISNULL((( [BillTotal]/*[FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) )* [DIR]*[btDirection] ), 0),  
			[buSalesManPtr],   
			[buVendor], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4],   
			2, -- Flag 
			[buFormatedNumber],[buBranch],[biCostPtr]       
		FROM   
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 
	
		UPDATE r SET [DueDate] = pt.[DueDate] FROM [#Result] r INNER JOIN pt000 pt ON pt.RefGuid = r.[Guid]  
		WHERE Flag = 2 
		 
		UPDATE r  
		SET CHGuid = b.Guid,CHTypGuid = b.TypeGuid,chNumber = b.Number,[DueDate] = b.[DueDate] 
		FROM [#Result] r 
		INNER JOIN  (SELECT Guid,TypeGuid,DueDate,ParentGuid,Number FROM vbch ch WHERE state = 0 AND  ParentGuid <> 0x00 AND DueDate = (select MIN(DueDate) DueDate FROM vbch cc WHERE cc.[State] = 0 AND  cc.ParentGuid = ch.ParentGuid)) b ON b.ParentGuid = r.[Guid]  
		WHERE Flag = 2 
	
	-- 	INSERT ENTRY MOVE  
	SELECT      
			[cu].[Number] AS [cuNumber],      
			[Cu].[Security] AS [cuSecurity],       
			[f].[ceTypeGuid], 
			[enGuid] , 
			[f].[ceSecurity],       
			[t].[Security],      
			CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END  [ceGuid],    
			[f].[ceNumber],    
			[f].[enDate],       
			[f].[enNumber],       
			[f].[ceNotes],       
			[f].[EnDebit]* Factor [FixedEnDebit],       
			[f].[EnCredit]* Factor [FixedEnCredit],       
			[f].[enNotes] ,       
			ISNULL(([f].[EnDebit] - [f].[EnCredit]), 0) * Factor AS [Balance],      
			[enContraAcc],  
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END  ELSE 1 END AS [FFLAG],   
			[er].[erParentType], 
			[t].[Flag], 
			ISNULL([er].[erParentGuid],0X00) [erParentGuid], 
			[f].[enAccount], 
			[f].[enCostPoint], 
			[ceBranch] 
		INTO [#ENTRY] 
		FROM       
			(SELECT *,1 / CASE WHEN enCurrencyPtr = @CurPtr  THEN enCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  endate  ORDER BY DATE DESC) END Factor FROM vwCeEn) AS [f] 
			INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] =[f].[enAccount]     
			LEFT JOIN [vwEr] AS [er]      
			ON [f].[ceGuid] = [er].[erEntryGuid]      
			INNER JOIN [#EntrySource] AS [t]      
			ON [f].[ceTypeGuid] = [t].[Type]    
			LEFT JOIN [vwAc] AS [Ac]  ON [Ac].[acGuid]=[f].[enContraAcc] 
		WHERE      
			 [f].[enDate] <= @EndDate 
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr)  )      
			AND (( @NotContain = '') OR ( [f].[enNotes] NOT LIKE @NotContainStr)  OR ( [f].[ceNotes] NOT LIKE @NotContainStr))  
			 
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid])       
	 INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date], [BNotes],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[CostPtr],[enGuid])      
		SELECT      
			[cuNumber],      
			[CuSecurity],     
			[ceTypeGuid],    
			[ceSecurity],       
			[#ENTRY].[Security],      
			[ceGuid],    
			[ceNumber],       
			[enDate],       
			[ceNotes],       
			[FixedEnDebit],  -- EntryDebit       
			[FixedEnCredit], -- EntryCredit,       
			[enNotes],       
			[Balance],      
			[enContraAcc],  
			[FFlag],[CeBranch],[enCostPoint],[enGuid] 
		FROM 
			[#ENTRY] 
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid] 
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE      
			([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] in (6, 7, 8))) OR ([Flag] = 3 AND((@haveAccOnly = 1) OR ( [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3)))))     
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  ))) 
			OR ([Flag] = 3 and [erParentType] = 600) 
	 IF (@ShowOppAcc = 1) 
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]  
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]  
---------------------------------------------------------------------------      
---------------------------------------------------------------------------      
	IF( @UseChkDueDate = 0)       
		INSERT INTO       
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])      
			SELECT       
				[cu].[Number],      
				[Cu].[Security],       
				0,      
				[ch].[chType],      
				[ch].[chSecurity],      
				[nt].[Security],      
				[ch].[chGUID],      
				[ch].[chNumber],    
				[ch].[chDate],      
				[ch].[chNotes],      
				(Case       
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor      
					ELSE 0       
					END), -- EntryDebit      
				(Case       
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor  
					ELSE 0       
					END), -- EntryCredit      
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor     
					ELSE -[ch].[chVal] * Factor  
					END), -- Balance   
				5 ,chbranchGuid,[chCost1GUID],chnum    
			FROM       
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh])AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]  
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] =[ch].[chAccount]  
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]        
				     
			WHERE       
				 (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))      
				AND [chDate] <= @EndDate       
				AND [chState] != 0          
	ELSE IF ( @UseChkDueDate = 1)      
		INSERT INTO       
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])      
			SELECT       
				[cu].[Number],      
				[Cu].[Security],     
				0,      
				[ch].[chType],      
				[ch].[chSecurity],      
				[nt].[Security],      
				[ch].[chGUID],      
				[ch].[chNumber],    
				[ch].[chDueDate],      
				[ch].[chNotes],      
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor     
					ELSE 0       
					END), -- EntryDebit      
				(Case       
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]  * Factor     
					ELSE 0       
					END), -- EntryCredit      
				(Case       
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor     
					ELSE  -[ch].[chVal] * Factor  
					END), -- Balance    
				5 ,chbranchGuid,[chCost1GUID],chnum     
			FROM       
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE       
				(( @Contain = '') OR ( [chNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))      
				AND [chDueDate] <= @EndDate       
				AND [chState] != 0    
	ELSE       
		INSERT INTO       
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[Costptr],[buTextFld1])       
			SELECT       
				[cu].[Number],      
				[Cu].[Security],     
				0,      
				[ch].[chType],      
				[ch].[chSecurity],      
				[nt].[Security],      
				[ch].[chGUID],      
				[ch].[chNumber],    
				[ch].[chDueDate],      
				[ch].[chNotes],      
				(Case       
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor    
					ELSE 0       
					END), -- EntryDebit      
				(Case       
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor  
					ELSE 0       
					END), -- EntryCredit      
				(Case       
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor      
					ELSE  -[ch].[chVal] * Factor   
					END), -- Balance    
				5 ,chbranchGuid,[chCost1GUID],chnum   
			FROM       
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE       
				(( @Contain = '') OR ([chNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))      
				AND [chColDate] <= @EndDate       
				AND [chState] != 0          
-----------------------------------------------------------------------------------      
-----------------------------------------------------------------------------------      
	IF( @ShowChk > 0)       
		INSERT INTO       
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date], [BNotes], [EntryDebit], [EntryCredit], [Balance],[Flag],[Branch],[CostPtr],[buTextFld1])        
			SELECT       
				[cu].[Number],      
				[Cu].[Security],     
				0,      
				[ch].[chType],      
				[ch].[chSecurity],      
				[nt].[Security],      
				[ch].[chGUID],      
				[ch].[chNumber],    
				CASE @UseChkDueDate  WHEN 1 THEN  [ch].[chDueDate] ELSE [chDate] END,    
				[ch].[chNotes],       
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor   
					ELSE 0       
					END), -- EntryDebit      
				(Case       
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor  
					ELSE 0       
					END), -- EntryCredit      
				(Case       
					WHEN [ch].[chDir] = 2 THEN[ch].[chVal] * Factor    
					ELSE  -[ch].[chVal] * Factor  
					END), -- Balance    
				-1,chbranchGuid ,[chCost1GUID],chnum        
			FROM       
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch]  
				INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type]   
				INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount]   
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]  
			WHERE       
				(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate) 
				AND [chState] = 0       
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))      
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))  
-----------------------------------------------------------------------	      
--Delete  Check With No Edit Entry 
	IF (@ShwChWithEn = 1) 
		DELETE [#Result] WHERE  ([Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] =5) 
----------------------------------------------------------------------       
	EXEC [prcCheckSecurity] @UserId      
	      
	DECLARE @PriveBalance [FLOAT]       
	      
	SELECT    SUM(ISNULL([Balance], 0)) AS [PriveBalance],[cu].[Number] as [CustPtr],  SUM(ISNULL([RBalance],0)) AS [RBalance]   INTO [#PREVBAL] FROM       
		(SELECT DISTINCT [Type], [Guid], [Balance], [flag] ,'' AS [Notes],[CustPtr]  ,0.00 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] = 2   
			UNION ALL  
	     SELECT  [Type], [Guid], [Balance], [flag], [Notes], [CustPtr], 0 AS [RBalance] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <>2 ) AS [p]  
	RIGHT JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [p].[CustPtr]	 
	GROUP BY 
		[cu].[Number]     
	 
	IF @StartBal=1  
		UPDATE [#PREVBAL] SET [PriveBalance] =0 
	     
	DELETE [#Result] FROM [#Result] [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  WHERE [Date] < [cu].[FromDate] 
	  
	IF @bUnmatched =1  
		 UPDATE [#PREVBAL] SET [RBalance] = [dbo].[fnAccount_getBalance]([cu].[AccountGuid], @CurPtr, CASE @StartBal WHEN 0 THEN '1/1/1980' ELSE [cu].[FromDate]  END,@EndDate,@CostGuid)  
	 		 FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]  
			     
	IF (@ShowAccMoved=1) 
		DELETE [#PREVBAL] WHERE [CustPtr] NOT IN (SELECT DISTINCT [CustPtr] FROM [#RESULT]) 
	 
	INSERT INTO [#Result]([CustPtr], [Date],[BuTotal],[Balance],[Flag]) SELECT [CustPtr],[cu].[FromDate],[PriveBalance],[RBalance],0   FROM [#PREVBAL] AS [r] INNER JOIN [#CUST1]  AS [cu] ON [cu].[Number] = [r].[CustPtr]    
#########################################################
CREATE PROCEDURE ARWA.repCPS_WithDetails_OneCust
	@UserId			AS [UNIQUEIDENTIFIER],  
	@StartDate		AS [DATETIME],  
	@EndDate		AS [DATETIME],  
	@CustPtr		AS [UNIQUEIDENTIFIER],  
	@CustSec		AS [INT],  
	@CurPtr			AS [UNIQUEIDENTIFIER],  
	@CurVal			AS [FLOAT],  
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz  
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d  
	@Contain		AS [VARCHAR](1000),  
	@NotContain		AS [VARCHAR](1000),  
	@UseChkDueDate	AS [INT],  
	@ShowChk		AS [INT], 
	@CostGuid		AS [UNIQUEIDENTIFIER], 
	@ShowAccMoved   AS [INT] = 0, 
	@StartBal		AS [INT] = 0, 
	@bUnmatched		AS [INT] =1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowDiscExtDet AS [INT] = 0, 
	@ShowOppAcc		AS [INT] = 0
AS   
	SET NOCOUNT ON   
	DECLARE	      
		--@UserId			[INT],       
		@ContainStr		[VARCHAR](1000),      
		@NotContainStr	[VARCHAR](1000),      
		@CustAcc		[UNIQUEIDENTIFIER]   
		   
	DECLARE @StDate  [DATETIME] 
	-- prepare Parameters:	     
	SET @ContainStr = '%' + @Contain + '%'     
	SET @NotContainStr = '%' + @NotContain + '%' 
	 
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT) 
	INSERT INTO @Curr  
	SELECT DATE,CurrencyVal FROM mh000 WHERE CURRENCYGuid = @CurPtr AND DATE <= @EndDate 
	UNION ALL  
	SELECT  '1/1/1980',CurrencyVal FROM MY000 WHERE Guid = @CurPtr      
	     
	-- get CustAcc	     
	SELECT @CustAcc = [AccountGUID] FROM [cu000] WHERE [GUID] = @CustPtr     
	-- 	INSERT BILLS MOVE     
	SELECT       
			[buType],      
			[buSecurity],      
			CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		      
			[buGUID],      
			[buNumber],    
			[buDate],      
			[biNumber],       
			[buNotes],      
			CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0 
			ELSE	CASE      
					WHEN [buCustAcc] = @CustAcc  THEN 0     
					ELSE 1 END    
			END AS [IsCash] ,     
			CASE [btVatSystem] WHEN 2 THEN [BuTotal] ELSE ([BuTotal]+[BuVAT]) END * Factor AS [BillTotal],      
			CASE [btVatSystem] WHEN 2 THEN 0 ELSE [BuVAT]* Factor END [FixedBuVAT],      
			[buItemsDisc]* Factor [FixedbuItemsDisc], 
			[BuBonusDisc]* Factor [FixedBuBonusDisc],  
			[buItemsExtra] * Factor [FixedbuItemExtra],  
		    CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],            
			[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
			[biMatPtr],      
			[St].[stName] AS [stName],    
			[biQty],      
			[biBonusQnt],      
			[biUnity],      
			[biQty2],      
			[biQty3],      
			[biExpireDate],      
			[biProductionDate],      
			[biCost_Ptr] [biCostPtr],      
			[biClassPtr],      
			[biLength],      
			[biWidth],      
			[biHeight],  
			[biCount],     
			[BiPrice] * Factor  
			 + CASE [btVatSystem] WHEN 2 THEN ([BiPrice] /*- (([FixedBiDiscount] + [FixedbiBonusDisc]) / [biQty])*/) * biVATRatio/100 * Factor  ELSE 0 END [BiPrice] ,      
			[BiDiscount]* Factor [FixedBiDiscount],  
			[biBonusDisc]* Factor [FixedbiBonusDisc],    
			[biExtra]* Factor [FixedbiExtra],      
			[biNotes],      
			[buSalesManPtr],  
			[buVendor],   
			[mtSecurity], 
			Factor [FixedCurrencyFactor], 
			[BuTotal]* Factor [FixedBuTotal], 
			[btDirection], 
			[btType] AS [btBillType], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4], 
			CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch], 
			CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS               
		INTO [#Bill]	  
		FROM   
			--[fn_bubi_FixedCps]( @CurPtr,@CustPtr,@CustAcc) AS [bi] 
			(SELECT * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor  from [fn_bubi_FixedCps]( @CustPtr,@CustAcc) ) AS [bi]  
			INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]        
			INNER JOIN [vwSt] AS [st] ON [st].[stGUID] = [bi].[biStorePtr]  
			INNER JOIN [#MatTbl] AS [mt] ON [mt]. [MatGuid] = [bi].[biMatPtr] 
			INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
		WHERE       
			[buDate] <= @EndDate  
			AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
				OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @CustAcc <> [buCustAcc]))      
				OR( @Cash = 2 AND (@CustAcc= [buCustAcc] OR @CustAcc = [bi].[buMatAcc])))      
			AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
			AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) OR ([biNotes] LIKE @ContainStr))      
			AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) AND ([biNotes] NOT LIKE @NotContainStr))) 
	CREATE  CLUSTERED INDEX [BillININDEX] ON [#Bill] ([buGUID]) 
	UPDATE b SET [BillTotal] = [BillTotal] - (V*[FixedCurrencyFactor]) from [#Bill] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [buGUID] where VS = 1 
	SELECT SUM( CASE WHEN [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra] 
	INTO [#Disc] 
	FROM [di000] AS [di2] INNER JOIN (SELECT DISTINCT 1/[FixedCurrencyFactor] [FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid] 
	WHERE [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 
	 
	CREATE  CLUSTERED INDEX [DiscININDEX] ON [#Disc] ([ParentGuid]) 
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],      
		[Number],[Date],[biNumber],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuFirstPay],[UserReadPriceSecurity],[MatPtr],      
		[Store],[Qty],[Bonus],[Unit],[biQty2],[biQty3],[ExpireDate],[ProductionDate],[CostPtr],[ClassPtr],[Length],[Width],[Height],[Count],[BiPrice],[BiDiscount],[BiExtra],      
		[Notes],[Balance],[SalesMan],[Vendor],[MatSecurity],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[biBonusDisc])     
		SELECT 
			@CustPtr, 
			@CustSec,  
			[buType],  
			[buSecurity],  
			[btSecurity], 		  
			[buGUID],  
			[buNumber],    
			[buDate],  
			[biNumber],   
			[buNotes],      
			[IsCash],     
			[BillTotal],      
			[FixedBuVAT],      
			([FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0)) ,      
			([FixedbuItemExtra] + ISNULL([Extra],0)),--FixedBuTotalExtra,      
			[FixedBuFirstPay],      
			[btReadPriceSecurity],      
			[biMatPtr],      
			[stName],    
			[biQty],      
			[biBonusQnt],      
			[biUnity],      
			[biQty2],      
			[biQty3],      
			[biExpireDate],      
			[biProductionDate],      
			[biCostPtr],      
			[biClassPtr],      
			[biLength],      
			[biWidth],      
			[biHeight], 
			[biCount],      
			[BiPrice],      
			[FixedBiDiscount],      
			[FixedbiExtra],      
			 
			[biNotes],      
			ISNULL((([BillTotal]/* [FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc]+ISNULL([Discount],0))  + [FixedbuItemExtra] + ISNULL([Extra],0) )* CASE WHEN ([btBillType] = 3 OR [btBillType] = 4 OR [btBillType] = 2) THEN [btDirection] ELSE -[btDirection] END ), 0),  
			[buSalesManPtr],  
			[buVendor],   
			[mtSecurity], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4],  
			2, -- Flag 
			[buFormatedNumber],[buBranch],[FixedbiBonusDisc] 
			  
		FROM   
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 
	
		UPDATE r SET [DueDate] = pt.[DueDate]  FROM [#Result] r INNER JOIN pt000 pt ON pt.RefGuid = r.[Guid]  
		WHERE Flag = 2 
		 
	UPDATE r  
		SET CHGuid = b.Guid,CHTypGuid = b.TypeGuid,chNumber = b.Number,[DueDate] = b.[DueDate] 
		FROM [#Result] r 
		INNER JOIN  (SELECT Guid,TypeGuid,DueDate,ParentGuid,Number FROM vbch ch WHERE state = 0 AND  ParentGuid <> 0x00 AND DueDate = (select MIN(DueDate) DueDate FROM vbch cc WHERE cc.[State] = 0 AND  cc.ParentGuid = ch.ParentGuid)) b ON b.ParentGuid = r.[Guid]  
		WHERE Flag = 2 

	-- Details of DisCounts and Extras 
	IF (@ShowDiscExtDet <> 0) 
	BEGIN 
		SELECT 
			[buType],  
			[buSecurity], 
			[btSecurity], 		  
			[buGUID] [BillGUID],  
			[buNumber],    
			[buDate], 
			[di2].[Notes] AS [buNotes], 
			[di2].[Discount]*[FixedCurrencyFactor] AS [Discount] , 
			[di2].[Extra]*[FixedCurrencyFactor] AS [Extra], 
			[ac].[acCode] + '-' +[ac].[acName] AS [acCodeName], 
			[ac].[acGuid], 
			[ac].[acSecurity] 
			INTO #DetDiscExt 
			FROM ([di000] AS [di2]  
			INNER JOIN (SELECT DISTINCT [buType],[buSecurity],[btSecurity],[buNumber],[buDate],[FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid]) 
			INNER JOIN [vwAc] AS [ac] ON [ac].[acGuid] = [di2].[AccountGuid] 
			WHERE [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 
		EXEC [prcCheckSecurity]  @result = '#DetDiscExt' 
		INSERT INTO #RESULT ([CustPtr],[CustSecurity],[MatPtr],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[BNotes],[EntryDebit],[EntryCredit],[OppAccName],[Flag]) 
		SELECT 
			@CustPtr, 
			@CustSec, 
			[acGuid],  
			1, 
			[buType],  
			[buSecurity], 
			[btSecurity], 		  
			[BillGUID],  
			[buNumber],    
			[buDate], 
			[buNotes], 
			[Discount], 
			[Extra], 
			[acCodeName], 
			2 
		FROM #DetDiscExt 
			 
	END 
	-- 	INSERT ENTRY MOVE 
	SELECT      
			[f].[ceTypeGuid],    
			[f].[ceSecurity],       
			[t].[Security],      
			CASE [t].[Flag] WHEN 1 THEN [er].[ParentGuid] ELSE  [f].[ceGuid] END  [ceGuid],    
			[f].[ceNumber], 
			[enGuid],    
			[f].[enDate],       
			[f].[enNumber],       
			[f].[ceNotes],       
			[f].enDebit * Factor [FixedEnDebit] ,       
			[f].[EnCredit] * Factor [FixedEnCredit],       
			[f].[enNotes] ,       
			ISNULL(([f].enDebit - [f].[EnCredit]), 0) * Factor AS [Balance],      
			[enContraacc], 
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[ParentType] WHEN 5 THEN 1 ELSE [er].[ParentType] END  ELSE 1 END AS [FFLAG],   
			[er].[ParentType] AS [erParentType], 
			[t].[Flag], 
			ISNULL([er].[ParentGuid], 0X00) AS [erParentGuid], 
			[f].[enAccount], 
			[f].[enCostPoint],[ceBranch] 
		INTO [#ENTRY] 
		FROM       
			(SELECT *,1 / CASE WHEN enCurrencyPtr = @CurPtr  THEN enCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  endate  ORDER BY DATE DESC) END Factor FROM vwCeEn)  AS [f] 
			LEFT JOIN [Er000] AS [er]      
			ON [f].[ceGuid] = [er].[EntryGuid]      
			INNER JOIN [#EntrySource] AS [t]      
			ON [f].[ceTypeGuid] = [t].[Type]    
		WHERE      
			[f].[enDate] <= @EndDate  
			AND ([f].[enAccount] =  @CustAcc)        
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr)  )      
			AND (( @NotContain = '') OR ( [f].[enNotes] NOT LIKE @NotContainStr) OR ( [f].[ceNotes] NOT LIKE @NotContainStr))         
	 CREATE  INDEX [enININDEX] ON [#ENTRY] ([enCostPoint],[erParentGuid]) 
	 INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date],[biNumber], [BNotes],[UserReadPriceSecurity],[CostPtr],[ClassPtr],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[enGuid])          
		SELECT      
			@CustPtr, 
			@CustSec,      
			[ceTypeGuid],    
			[ceSecurity],       
			[#ENTRY].[Security],      
			[ceGuid],    
			[ceNumber],    
			[enDate],       
			[enNumber],       
			[ceNotes],       
			3,--	UserReadPriceSecurity      
			 
			[enCostPoint],--	CostPtr,       
			'',--	ClassPtr,       
			[FixedEnDebit],  -- EntryDebit       
			[FixedEnCredit], -- EntryCredit,       
			[enNotes] ,       
			[Balance],      
			[enContraacc], 
			[FFlag], 
			[ceBranch],[enGuid] 
		FROM 
			[#ENTRY] 
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid] 
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE      
			 (([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] in (6, 7, 8))) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )     
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and [FixedEnDebit] > 0  ) or (chDir = 2 and [FixedEnCredit] > 0  ))) 
			OR ([Flag] = 3 and [erParentType] = 600) 
	-- 	INSERT Normal Entry Move    
	 
	 IF (@ShowOppAcc = 1) 
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]  
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID]   
---------------------------------------------------------------------------     
---------------------------------------------------------------------------     
	IF( @UseChkDueDate = 0)      
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor 
					ELSE -[ch].[chVal]* Factor 
					END), -- Balance     
				5 ,[chbranchGuid],[chCost1GUID],chnum   
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				 INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @CustAcc      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chDate] <= @EndDate      
				AND [chState] != 0     
	ELSE IF( @UseChkDueDate = 1)       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDueDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor     
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor     
					ELSE -[ch].[chVal]* Factor 
					END), -- Balance     
				5 ,[chbranchGuid],[chCost1GUID],chnum   
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				chAccount= @CustAcc      
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))     
				AND [chDueDate] <= @EndDate      
				AND [chState] != 0  
	ELSE       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chColDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN[ch].[chVal]  * Factor      
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor      
					ELSE -[ch].[chVal] * Factor    
					END), -- Balance     
				5 ,[chbranchGuid],[chCost1GUID],chnum 
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @CustAcc      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chColDate] <= @EndDate      
				AND [chState] != 0         
-----------------------------------------------------------------------------------     
-----------------------------------------------------------------------------------     
	IF( @ShowChk > 0)      
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				CASE @UseChkDueDate  WHEN 1 THEN  [ch].[chDueDate] ELSE [chDate] END,  
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor        
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor       
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal] * Factor        
					ELSE -[ch].[chVal] * Factor 
					END), -- Balance     
				-1 ,[chbranchGuid],[chCost1GUID] ,chnum  
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				 INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]          
			WHERE      
				[chAccount] = @CustAcc  
				AND(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate) 
				AND [chState] = 0      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))  
				 
---------------------------------------------------------------------- 
--Delete  Check With No Edit Entry 
	IF (@ShwChWithEn =1) 
		DELETE [#Result] WHERE  ( [Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] = 5)	     
----------------------------------------------------------------------      
	EXEC [prcCheckSecurity]      
	     
	DECLARE @PriveBalance [FLOAT]      
   
	IF @StartBal=0     
		SELECT @PriveBalance = ISNULL( SUM([Balance]), 0) FROM      
				(SELECT DISTINCT [Type], [Guid], [Balance], [flag], '' AS [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2  
			UNION ALL 
			SELECT  [Type], [Guid], [Balance], [flag], [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <>2 ) AS [p]     
	ELSE  
		SET @PriveBalance=0  
	    
	DELETE [#Result] WHERE [Date] < @StartDate  
	 
	IF (@StartBal=0) 
		SET @StDate = '1/1/1980' 
	ELSE 
		SET @StDate = @StartDate 
	DECLARE @RBalance AS [FLOAT] 
	IF @bUnmatched =1 
		SET  @RBalance = [dbo].[fnAccount_getBalance](@CustAcc,@CurPtr,@StDate,@EndDate,@CostGuid) 
	ELSE 
		SET @RBalance = 0 
			    
	IF (((@ShowAccMoved=1) AND EXISTS(SELECT * FROM #RESULT)) OR (@ShowAccmoved=0))  
		INSERT INTO [#Result]([CustPtr], [Date],[BuTotal],[Balance],[Flag]) VALUES ( @CustPtr, @StartDate - 1, @PriveBalance,@RBalance, 0)      
#########################################################
CREATE PROCEDURE ARWA.repCPS_WithoutDetails_OneCust
	@UserId			AS [UNIQUEIDENTIFIER],  
	@StartDate		AS [DATETIME],  
	@EndDate		AS [DATETIME],  
	@CustPtr		AS [UNIQUEIDENTIFIER],  
	@CustSec		AS [INT],  
	@CurPtr			AS [UNIQUEIDENTIFIER],  
	@CurVal			AS [FLOAT],  
	@Post			AS [INT],	-- 1: xxx, 2: yyy, 3: zzz  
	@Cash			AS [INT],	-- 0: a, 1: b, 2: c, c: d  
	@Contain		AS [VARCHAR](1000),  
	@NotContain		AS [VARCHAR](1000),  
	@UseChkDueDate	AS [INT],  
	@ShowChk		AS [INT], 
	@CostGuid		AS [UNIQUEIDENTIFIER], 
	@ShowAccMoved   AS [INT] = 0, 
	@StartBal		AS [INT] = 0, 
	@bUnmatched		AS [INT] =1, 
	@ShwChWithEn	AS [INT] = 0, 
	@ShowDiscExtDet AS [INT] = 0, 
	@ShowOppAcc		AS [INT] = 0
AS     
	SET NOCOUNT ON 
	 
	DECLARE	      
		--@UserId			[INT],       
		@ContainStr		[VARCHAR](1000),      
		@NotContainStr	[VARCHAR](1000),      
		@CustAcc		[UNIQUEIDENTIFIER]   
		   
	DECLARE @StDate  [DATETIME] 
	-- prepare Parameters:	     
	SET @ContainStr = '%' + @Contain + '%'     
	SET @NotContainStr = '%' + @NotContain + '%'  
	 
	DECLARE @Curr TABLE( DATE SMALLDATETIME,VAL FLOAT) 
	INSERT INTO @Curr  
	SELECT [DATE],CurrencyVal FROM mh000 WHERE CURRENCYGuid = @CurPtr AND [DATE] <= @EndDate 
	UNION ALL  
	SELECT  '1/1/1980',CurrencyVal FROM MY000 WHERE Guid = @CurPtr       
	     
	-- get CustAcc	     
	SELECT @CustAcc = [AccountGUID] FROM [cu000] WHERE [GUID] = @CustPtr     
	-- 	INSERT BILLS MOVE  
	SELECT DISTINCT 
		  
		[buType],      
		[buSecurity],      
		CASE [bi].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSecurity] END  AS [btSecurity], 		      
		[buGUID],      
		[buNumber],    
		[buDate],      
		[biNumber],       
		[buNotes],      
		CASE [btType] WHEN  3 THEN 0 WHEN  4 THEN 0 WHEN  2 THEN 0 
		ELSE	CASE      
				WHEN [buCustAcc] = @CustAcc  THEN 0      
				ELSE 1 END    
		END AS [IsCash] ,     
		CASE [btVatSystem] WHEN 2 THEN [BuTotal]* Factor ELSE ([BuTotal]+[BuVAT])* Factor END AS [BillTotal],      
		[BuVAT]* Factor [FixedBuVAT],      
		[buItemsDisc]* Factor  [FixedbuItemsDisc], 
		[BuBonusDisc]* Factor  [FixedBuBonusDisc],  
		[buItemsExtra]* Factor [FixedbuItemsExtra], 
		CASE [btType] WHEN  2  THEN 0 WHEN  3  THEN 0 WHEN  4  THEN 0 WHEN  2  THEN 0 ELSE [BuFirstPay] * Factor END AS [FixedBuFirstPay],      
		[bt].[ReadPriceSecurity] AS [btReadPriceSecurity],      
		[buSalesManPtr],  
		[buVendor],   
		Factor [FixedCurrencyFactor], 
		[BuTotal]* Factor [FixedBuTotal], 
		[btDirection], 
		[btType], 
		[bi].[buMatAcc], 
		CASE [btType] WHEN  3 THEN 1 WHEN 4 THEN 1 WHEN  2 THEN 1 ELSE -1 END AS [DIR], 
		[buTextFld1], 
		[buTextFld2], 
		[buTextFld3], 
		[buTextFld4], 
		CAST ([buNumber] AS [INT]) AS [buFormatedNumber],[buBranch] ,[biCostPtr], 
		CASE [btVatSystem] WHEN 2 THEN 1 else 0 END AS VS  
	INTO [#Bill]	  
	FROM   
		--[fn_bubi_FixedCps]( @CurPtr,@CustPtr,@CustAcc) AS [bi] 
		(SELECT * ,1 / CASE WHEN biCurrencyPtr = @CurPtr  THEN biCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  buDate  ORDER BY DATE DESC) END Factor  from [fn_bubi_FixedCps]( @CustPtr,@CustAcc)   ) AS [bi]  
		INNER JOIN [#BillTbl2] AS [bt] ON [bt].[Type] = [bi].[buType]      
		INNER JOIN  [#CostTbl] as [co] ON [biCostPtr] = [CO].[Guid] 
	WHERE       
		[buDate] <= @EndDate  
	--	AND ( @CustPtr= [bi].[buCustPtr]  OR (@CustAcc = [bi].[buMatAcc] and ([btType] = 3 or [btType] = 4) ))     
		AND (( @Cash > 2) OR( @Cash = 0 AND [buPayType] >= 2)      
			OR((@Cash = 1) AND ( ISNULL( [buCustPtr], 0x0) = 0x0 OR @CustPtr <> [buCustAcc]))      
			OR( @Cash = 2 AND (@CustAcc = [buCustAcc] OR @CustAcc = [bi].[buMatAcc])))      
		AND (( @Post = 3)OR( @Post = 2 AND [buIsPosted] = 0) OR( @Post = 1 AND [buIsPosted] = 1))      
		AND (( @Contain = '') OR ( [buNotes] LIKE @ContainStr) )      
		AND (( @NotContain = '') OR (( [buNotes] NOT LIKE @NotContainStr) ))  
		 
	UPDATE b SET [BillTotal] = [BillTotal] - V from [#Bill] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [buGUID] where VS = 1 
	SELECT  SUM( CASE WHEN [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Discount]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Discount],[ParentGuid],SUM(CASE WHEN [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) THEN [di2].[Extra]/CASE WHEN di2.CurrencyGuid = @CurPtr  THEN di2.[CurrencyVal] ELSE [FixedCurrencyFactor] END ELSE 0 END) AS [Extra] 
	INTO [#Disc] 
	FROM [di000] AS [di2] INNER JOIN (SELECT DISTINCT 1/[FixedCurrencyFactor] [FixedCurrencyFactor],[buGuid] FROM  [#Bill]) AS b ON [b].[buGuid] = [di2].[ParentGuid] 
	WHERE [di2].[ContraAccGuid] = @CustAcc OR (ISNULL([di2].[ContraAccGuid],0X0) =0X0) 
	GROUP BY [ParentGuid],[FixedCurrencyFactor] 
	 
	INSERT INTO [#Result]([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],      
		[Number],[Date],[BNotes],[IsCash],[BuTotal],[BuVAT],[BuDiscount],[BuExtra],[BuFirstPay],[UserReadPriceSecurity],      
		[Notes],[Balance],[SalesMan],[Vendor],[buTextFld1],[buTextFld2],[buTextFld3],[buTextFld4],[Flag],[FormatedNumber],[Branch],[CostPtr]) 
		SELECT DISTINCT  
			@CustPtr,     
			@CustSec,       
			[buType],      
			[buSecurity],      
			[btSecurity], 		      
			[buGUID],      
			[buNumber],      
			[buDate],      
			[buNotes],      
			[IsCash],      
			[BillTotal],      
			[FixedBuVAT],      
			([FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL([Discount],0)),      
			[FixedbuItemsExtra] + ISNULL([Extra],0),--FixedBuTotalExtra,  
			[FixedBuFirstPay] ,      
			[btReadPriceSecurity],       
			'',      
			ISNULL((( [BillTotal]/*[FixedBuTotal] + [FixedBuVAT]*/ - [FixedbuFirstPay] - ([FixedbuItemsDisc]+ [FixedBuBonusDisc] +ISNULL([Discount],0))  + [FixedbuItemsExtra] + ISNULL([Extra],0) )* [DIR]*[btDirection] ), 0),  
			[buSalesManPtr],   
			[buVendor], 
			[buTextFld1], 
			[buTextFld2], 
			[buTextFld3], 
			[buTextFld4],   
			2, -- Flag 
			[buFormatedNumber],[buBranch],[biCostPtr]       
		FROM   
			[#Bill] AS [b]  LEFT JOIN [#Disc] AS [d] ON [d].[ParentGuid] = [b].[buGUID] 
		
			UPDATE r SET [DueDate] = pt.[DueDate]  FROM [#Result] r INNER JOIN pt000 pt ON pt.RefGuid = r.[Guid]  
			WHERE Flag = 2 
		 
		UPDATE r  
		SET CHGuid = b.Guid,CHTypGuid = b.TypeGuid,chNumber = b.Number,[DueDate] = b.[DueDate] 
		FROM [#Result] r 
		INNER JOIN  (SELECT Guid,TypeGuid,DueDate,ParentGuid,Number FROM vbch ch WHERE state = 0 AND  ParentGuid <> 0x00 AND DueDate = (select MIN(DueDate) DueDate FROM vbch cc WHERE cc.[State] = 0 AND  cc.ParentGuid = ch.ParentGuid)) b ON b.ParentGuid = r.[Guid]  
		WHERE Flag = 2 
	
	-- 	INSERT ENTRY MOVE  
	SELECT      
			[f].[ceTypeGuid],    
			[f].[ceSecurity],       
			[t].[Security],      
			CASE [t].[Flag] WHEN 1 THEN [er].[erParentGuid] ELSE  [f].[ceGuid] END [ceGuid],    
			[f].[ceNumber], 
			[enGuid],   
			[f].[enDate],       
			[f].[enNumber],       
			[f].[ceNotes],       
			[f].[EnDebit]* Factor  [FixedEnDebit],       
			[f].[EnCredit]* Factor [FixedEnCredit],       
			[f].[enNotes] ,       
			ISNULL(([f].[EnDebit] - [f].[EnCredit]), 0) * Factor AS [Balance],     
			[enContraAcc],  
			CASE [t].[Flag] WHEN 1 THEN 4 WHEN 2 THEN CASE [er].[erParentType] WHEN 5 THEN 1 ELSE [er].[erParentType] END  ELSE 1 END AS [FFLAG],   
			[er].[erParentType], 
			[t].[Flag], 
			ISNULL([er].[erParentGuid],0X00) [erParentGuid], 
			[f].[enAccount], 
			[f].[enCostPoint], 
			[ceBranch] 
		INTO [#ENTRY] 
		FROM       
			(SELECT *,1 / CASE WHEN enCurrencyPtr = @CurPtr  THEN enCurrencyVal ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  endate  ORDER BY DATE DESC) END Factor FROM vwCeEn) AS [f] 
			LEFT JOIN [vwEr] AS [er]      
			ON [f].[ceGuid] = [er].[erEntryGuid]      
			INNER JOIN [#EntrySource] AS [t]      
			ON [f].[ceTypeGuid] = [t].[Type]    
		WHERE      
			 [f].[enDate] <= @EndDate  
			 AND ([f].[enAccount] =  @CustAcc)        
			AND (( @Contain = '') OR ([f].[enNotes] LIKE @ContainStr) OR ([f].[ceNotes] LIKE @ContainStr) )      
			AND (( @NotContain = '') OR ( [f].[enNotes] NOT LIKE @NotContainStr) OR ( [f].[ceNotes] NOT LIKE @NotContainStr))               
	CREATE CLUSTERED INDEX entryParentType ON [#ENTRY]([erParentGuid]) 
	INSERT INTO [#Result] ([CustPtr],[CustSecurity],[Type],[Security],[UserSecurity],[Guid],[Number],[Date], [BNotes],[EntryDebit],[EntryCredit],[Notes],[Balance],[ContraAcc],[Flag],[Branch],[CostPtr],[enGuid])             
		SELECT      
			@CustPtr,     
			@CustSec,     
			[ceTypeGuid],    
			[ceSecurity],       
			[#ENTRY].[Security],      
			[ceGuid],    
			[ceNumber],       
			[enDate],       
			[ceNotes],       
			[FixedEnDebit],  -- EntryDebit       
			[FixedEnCredit], -- EntryCredit,       
			[enNotes],       
			[Balance],      
			[enContraacc], 
			[FFlag],[ceBranch],[enCostPoint],[enGuid] 
		FROM 
			[#ENTRY] 
			INNER JOIN  [#CostTbl] AS [co] ON [enCostPoint] = [co].[Guid] 
			LEFT JOIN [vwBu] AS [bu] ON [erParentGuid] = [bu].[buGuid]  
			LEFT JOIN (select chGuid,chAccount,chDir from vwch) ch ON [erParentGuid] =  ch.chGuid   
		WHERE      
			(([Flag] = 1) OR ([Flag] = 4) OR ([Flag] = 9) OR (([Flag] = 2) AND ([erParentType] in (6, 7, 8))) OR ([Flag] = 3 AND [enAccount] <> [bu].[buCustAcc] AND ([bu].[buMatAcc] <>[enAccount] or ( [bu].[buMatAcc] =[enAccount] and btType <> 3 and  btType  <>  3))) )     
			OR ([Flag] = 2 AND [erParentType] = 5 AND ((chDir = 1 and ([FixedEnDebit] > 0 ) ) or (chDir = 2 and ([FixedEnCredit] > 0 ) ))) 
			OR ([Flag] = 3 and [erParentType] = 600) 
			 
	IF (@ShowOppAcc = 1) 
		UPDATE [res] SET [OppAccName]  = [acName],	[OppAccCode] = [acCode]  
		 FROM [#Result] AS [res] INNER JOIN [vwAc] ON [res].[ContraAcc] = [ACgUID] 
---------------------------------------------------------------------------     
---------------------------------------------------------------------------     
	IF( @UseChkDueDate = 0)      
		INSERT INTO      
			[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor     
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor   
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor  
					ELSE (-[ch].[chVal]  * FACTOR)  
					END), -- Balance     
				5,[chbranchGuid],[chCost1GUID],chNum   
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE      
				[chAccount] = @CustAcc      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))     
				AND [chDate] <= @EndDate      
				AND [chState] != 0      
	ELSE IF( @UseChkDueDate = 1)       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chDueDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor  
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]  * Factor  
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]  * Factor   
					ELSE -[ch].[chVal] * Factor   
					END), -- Balance     
				5,[chbranchGuid],[chCost1GUID],chnum  
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				--INNER JOIN [#CUST1]  AS [cu] ON [cu].[AccountGuid] = [ch].[chAccount] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE       
				[chAccount] = @CustAcc      
				AND (( @Contain = '') OR ( [chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ( [chNotes] NOT LIKE @NotContainStr))     
				AND [chDueDate] <= @EndDate      
				AND [chState] != 0  
	ELSE       
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				[ch].[chColDate],     
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal] * Factor     
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal]* Factor       
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor       
					ELSE -[ch].[chVal] * Factor       
					END), -- Balance     
				5,[chbranchGuid],[chCost1GUID]  ,chnum 
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE      
				[chAccount] = @CustAcc  
				AND(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)     
				AND [chState] = 0      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))   
-----------------------------------------------------------------------------------     
-----------------------------------------------------------------------------------     
	IF( @ShowChk > 0)      
		INSERT INTO      
				[#Result]([CustPtr],[CustSecurity],[OrderFlag],[Type],[Security],[UserSecurity],[Guid],[Number], [Date],[BNotes],[EntryDebit],[EntryCredit],[Balance],[Flag],[Branch],[CostPtr],[buTextFld1])     
			SELECT      
				@CustPtr,     
				@CustSec,     
				0,     
				[ch].[chType],     
				[ch].[chSecurity],     
				[nt].[Security],     
				[ch].[chGuid],     
				[ch].[chNumber],     
				CASE @UseChkDueDate  WHEN 1 THEN  [ch].[chDueDate] ELSE [chDate] END,      
				[ch].[chNotes],     
				(Case      
					WHEN [ch].[chDir] = 2 THEN [ch].[chVal]* Factor   
					ELSE 0      
					END), -- EntryDebit     
				(Case      
					WHEN [ch].[chDir] = 1 THEN [ch].[chVal] * Factor     
					ELSE 0      
					END), -- EntryCredit     
				(Case      
					WHEN [ch].[chDir] = 2 THEN  [ch].[chVal]* Factor   
					ELSE -[ch].[chVal]       
					END), -- Balance     
				-1,[chbranchGuid],[chCost1GUID],chnum    
			FROM      
				(SELECT *,1 / CASE WHEN [chCurrencyPtr] = @CurPtr  THEN [chCurrencyVal] ELSE (SELECT TOP 1 VAL FROM @Curr WHERE [DATE] <=  [chDate]  ORDER BY DATE DESC) END Factor FROM [vwCh]) AS [ch] INNER JOIN [#NotesTbl] AS [nt] ON [ch].[chType] = [nt].[Type] 
				INNER JOIN  [#CostTbl] AS [co] ON [chCost1GUID] = [co].[Guid]           
			WHERE      
				[chAccount] = @CustAcc  
				AND(CASE @UseChkDueDate WHEN 1 THEN [chDueDate] ELSE [chDate] END <= @EndDate)     
				AND [chState] = 0      
				AND (( @Contain = '') OR ([chNotes] LIKE @ContainStr))     
				AND (( @NotContain = '') OR ([chNotes] NOT LIKE @NotContainStr))  
				 
---------------------------------------------------------------------- 
--Delete  Check With No Edit Entry 
	IF (@ShwChWithEn =1) 
		DELETE [#Result] WHERE  ( [Flag] = 5) AND [Guid] NOT IN (SELECT [ParentGuid] FROM [er000] WHERE [ParentType] = 5) 
----------------------------------------------------------------------      
	EXEC [prcCheckSecurity] @UserId     
   
	DECLARE @PriveBalance [FLOAT]      
	     
	IF @StartBal=0     
		SELECT @PriveBalance = ISNULL( SUM([Balance]), 0) FROM      
				(SELECT DISTINCT [Type],[Guid],[Balance], [flag],'' AS [Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] =2  
			UNION ALL 
			SELECT  [Type],[Guid],[Balance],[flag],[Notes] FROM [#Result] WHERE [Date] < @StartDate AND [OrderFlag] = 0 AND [IsCash] = 0 AND [FLAG] <>2 ) AS [p]    
	ELSE  
		SET @PriveBalance=0  
	    
	DELETE [#Result] WHERE [Date] < @StartDate  
	 
	IF (@StartBal=0) 
		SET @StDate = '1/1/1980' 
	ELSE 
		SET @StDate = @StartDate 
	DECLARE @RBalance AS [FLOAT] 
	IF @bUnmatched =1 
		SET  @RBalance = [dbo].[fnAccount_getBalance](@CustAcc,@CurPtr,@StDate,@EndDate,@CostGuid) 
	ELSE 
		SET @RBalance = 0 
			    
	IF (((@ShowAccMoved=1) AND EXISTS(SELECT * FROM [#RESULT])) OR (@ShowAccmoved=0))  
		INSERT INTO [#Result]([CustPtr],[Date],[BuTotal],[Balance],[Flag]) VALUES ( @CustPtr, @StartDate - 1, @PriveBalance,@RBalance, 0) 
#########################################################
CREATE PROCEDURE ARWA.repCustomerStatement
	@StartDate							AS [DATETIME]			= '12/25/2009 0:0:0.0', -- „‰  «—ÌŒ
	@EndDate							AS [DATETIME]			= '12/18/2012 23:59:59.677', -- ≈·Ï  «—ÌŒ
	@AccountGUID						AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000',-- '00000000-0000-0000-0000-000000000000' ,-- «·Õ”«»
	@CustomerGUID						AS [UNIQUEIDENTIFIER]	= 'D8C71B64-480B-4989-8746-DF3645E6A729', -- «·“»Ê‰
	@CurrencyGUID						AS [UNIQUEIDENTIFIER]	= '0177FDF3-D3BB-4655-A8C9-9F373472715A',-- «·⁄„·…
	@ShowPosted							AS [BIT]				= 1,
	@ShowUnPosted						AS [BIT]				= 0,
	@ShowCash							AS [INT]				= 1, -- ≈ŸÂ«— «·›Ê« Ì— «·‰ﬁœÌ…
	@ShowLater							AS [INT]				= 1, -- ≈ŸÂ«— «·›Ê« Ì— «·√Ã·…
	@NotesContain						AS [VARCHAR](1000)		= '',-- Notes Contain
	@NotesNotContain					AS [VARCHAR](1000)		= '',-- Notes Not Contain
	@UseCheckDate						AS [bit]				= 0, -- „‰ √Œ— „ÿ«»ﬁ…
	@ShowBillDetails					AS [bit]				= 1, --  ›«’Ì· «·›Ê« Ì—
	@UseCheckDueDate					AS [int]				= 1, --
	/*
		1- «” Œœ«„  «—ÌŒ «·«” Õﬁ«ﬁ
		2- «” Œœ«„  «—ÌŒ «· Õ’Ì·
	*/  
	@ShowCheck							AS [bit]				= 1, -- ≈ŸÂ«— «·√Ê—«ﬁ «·„«·Ì… «·€Ì— „Õ’·…
	@JobCostGUID						AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000', -- „—ﬂ“ «·ﬂ·›…
	@ShowAccountMoved					AS [bit]				= 0, -- ≈ŸÂ«— ›ﬁÿ «·“»«∆‰ «· Ì  Õ—ﬂ  ›Ì «·„œ…
	@StartBalance						AS [bit]				= 0, --  ’›Ì— «·—’Ìœ ›Ì »œ«Ì… «·„œ…
	@ShowContraAccount					AS [bit]				= 0, -- ≈ŸÂ«— «·Õ”«» «·„ﬁ«»·
	@OrderType							AS [INT]				= 2,
	@ShowCheckWithEntry					AS [bit]				= 0, -- ≈ŸÂ«— «·√Ê—«ﬁ «·„«·Ì… «·„— »ÿ… »ﬁÌœ
	@ShowBillDetailsDiscountsAndExtras	AS [bit]				= 0, -- ≈ŸÂ«—  ›«’Ì· «·Õ”„Ì«  Ê «·≈÷«›« 
	@CheckDateLine						AS [bit]				= 0, -- ›«’· ⁄‰œ  «—ÌŒ «·„ÿ«»ﬁ…
	@ShowMatchNote						AS [BIT]				= 0, -- »Ì«‰  «—ÌŒ √Œ— „ÿ«»ﬁ…
	@CustomerCondition					AS VARCHAR(MAX)			= '', -- ‘—Êÿ «·“»«∆‰
	/*
	⁄‰œ„«  ﬂÊ‰ -1 Ì⁄Ìœ «·√ﬁ·«„ «·„œﬁﬁ… Ê €Ì— «·„œﬁﬁ…
	⁄‰œ„« ÌﬂÊ‰ 0 Ì⁄Ìœ «·√ﬁ·«„ „œﬁﬁ… ›ﬁÿ
	⁄‰œ„« ÌﬂÊ‰ 1 Ì⁄Ìœ «·√ﬁ·«„ «·€Ì— „œﬁﬁ… ›ﬁÿ
	*/ 
	@ShowBillDiscountsAndExtras			AS [BIT]				= 1, -- ≈ŸÂ«— «·Õ”„Ì«  Ê «·≈÷«›« 
	@ShowWeekLine						AS [BIT]				= 1, -- ≈ŸÂ«— ›«’· ﬂ· √”»Ê⁄
	@ShowMonthLine						AS [BIT]				= 1, -- ≈ŸÂ«— ›«’· ﬂ· ‘Â—
	@Lang								VARCHAR(100)			= 'ar',		--0 Arabic, 1 Latin
	@UserGUID							[UNIQUEIDENTIFIER]		= 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	--Guid Of Logining User
	@BranchMask							[BIGINT]				= -1, 
	-----------------Report Sources-----------------------
	@SourcesTypes						VARCHAR(MAX)			=  'A4FAD32E-4FCA-4B09-816A-D488B36B633A,2,8B40BBD2-BEEB-454E-B080-D61A9A907DC2,2',--'A7D1E04E-102F-4DAF-9792-1267DEB3591C,2,8C6A693B-5F7D-4570-917D-2E7941E195B3,2,CE2BC877-C6E1-4B9A-81F2-369147FEFD98,2,2FFBB4C2-8472-4333-9CF4-6342A1030682,2,FB256FE0-1883-4357-AD9F-8C28170D7460,2,70CC59C9-3EC5-4D5E-BB99-92DE3508EB06,2,D4F4933E-805E-47F7-9CD7-B25E7A78D4DA,2,8E899D39-FB88-46B5-BD08-B7D512DC4BA0,2,39ECA4D6-F63A-4FC3-B7EA-C6652BEF2142,2,55D1F1FC-68EB-47D3-BD5B-CECAF4A5F2D4,2,A4FAD32E-4FCA-4B09-816A-D488B36B633A,2,8B40BBD2-BEEB-454E-B080-D61A9A907DC2,2,484A7EEC-F3D8-4FAE-A90A-D8B9B0507337,2,011569AA-CB37-41C6-96A5-FC5700D5EA8F,2,34408B95-A1B8-481E-AFC0-FC8602555998,2,09F01BF2-69EB-4237-9DEE-0BC8332942FC,5,34401010-3A12-4F23-9509-1B7F6C6BAF82,5,164A5F82-A40A-41CB-AE17-15B57BD5BCFD,1,EA69BA80-662D-4FA4-90EE-4D2E1988A8EA,1,D36366BA-4079-4602-BE4A-7F4ADB2F4E5A,1,3DF31F7C-2CC4-464E-869B-B74FEAA4B301,1,426E158F-AEC7-4BE9-9492-C3E684D333BA,1,00000000-0000-0000-0000-000000000000,1'
	@ShowBalancedCustomers  [BIT]  = 0--«ŸÂ«— «·“»«∆‰ «·„—’œÌ‰
AS 	    
	SET NOCOUNT ON     
	
	Exec ARWA.prcInitialize_Environment @UserGUID, 'RepCps', @BranchMask
	
	DECLARE @Post INT
	SET @Post = 0
	IF(@ShowPosted = 1)
		SET @Post = 1
	IF(@ShowUnPosted = 1)
		SET @Post = @Post + 2
		
	DECLARE @Cash INT
	SET @Cash = 0
	IF(@ShowCash = 1)
		SET @Cash = 1
	IF(@ShowLater = 1)
		SET @Cash = @Cash + 2
	
	DECLARE @bUnmatched INT
	SET @bUnmatched = 1
	SELECT @bUnmatched = Value FROM op000 WHERE Name = 'AmnCfg_UnmatchedMsg'
		
	DECLARE @CurVal FLOAT
	DECLARE @CurCode VARCHAR(255)
	DECLARE @DefCurCode VARCHAR(255)
	
	SELECT @DefCurCode = Code FROM my000 WHERE Number = 1
	SELECT @CurCode = Code FROM my000 WHERE GUID = @CurrencyGUID
	SET @CurVal = (SELECT TOP 1 [CurrencyVal] FROM [mh000] 
						WHERE [CurrencyGUID] = @CurrencyGUID AND [Date] <= @EndDate 
						ORDER BY [Date] DESC) 
	
	DECLARE	     
		@c				CURSOR,     
		@UserID			[UNIQUEIDENTIFIER],      
		@CustSec		[INT],     
		@Str			[VARCHAR](255), 
		@buStr			[VARCHAR](1000),     
		@NormalEntry	[INT],
		@CustFromDate	[DATETIME],
		@cstCnt			[INT]
		
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [FromDate] [DATETIME])     
	CREATE TABLE [#CostTbl] ([Guid] [UNIQUEIDENTIFIER],[Security] [INT])     
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnpostedSecurity] [INT], [ReadPriceSecurity] [INT])       
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnpostedSecurity] [INT], [ReadPriceSecurity] [INT])       
	CREATE TABLE [#NotesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnpostedSecurity] [INT], [ReadPriceSecurity] [INT])       
	CREATE TABLE [#EntrySource]([Type] [UNIQUEIDENTIFIER], [Security] [INT],[Flag] [INT])   
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])     
	CREATE TABLE [#Result]     
		(   
			[CustPtr]					[UNIQUEIDENTIFIER],
			[CustSecurity]				[INT] DEFAULT	0,     
			[OrderFlag]					[INT] DEFAULT 0,     
			[Type]						[UNIQUEIDENTIFIER], -- ??? ?????     
			[Security]					[INT] DEFAULT 0, -- ?????? ??? ?????     
			[UserSecurity] 				[INT] DEFAULT 0, -- ?????? ???????? ??? ??? ?????     
	    	[Guid]						[UNIQUEIDENTIFIER], 
	    	[enGuid]					[UNIQUEIDENTIFIER],      
			[Number]					[INT],   
			[Date]						[DATETIME] DEFAULT '1/1/1980',      
			[biNumber]					[INT],      
			[BNotes]					[VARCHAR](500) COLLATE ARABIC_CI_AI DEFAULT '',      
			[ParentType]				[INT] DEFAULT 0,      
			[ParentNum]					[INT] DEFAULT 0,      
			[IsCash]					[INT] DEFAULT 0,      
			[BuTotal]					[FLOAT] DEFAULT 0,      
			[BuVAT]						[FLOAT] DEFAULT 0,     
			[BuDiscount]				[FLOAT] DEFAULT 0,     
			[BuExtra]					[FLOAT] DEFAULT 0,      
			[BuFirstPay]				[FLOAT] DEFAULT 0,      
			[UserReadPriceSecurity]		[INT] DEFAULT 3,     
			[MatPtr]					[UNIQUEIDENTIFIER],
			[Store]						[VARCHAR](300) COLLATE ARABIC_CI_AI,      
			[Qty]						[FLOAT],      
			[Bonus]						[FLOAT],      
			[Unit]						[INT],      
			[biQty2]					[FLOAT],      
			[biQty3]					[FLOAT],      
			[ExpireDate]				[DATETIME],      
			[ProductionDate]			[DATETIME],      
			[CostPtr]					[UNIQUEIDENTIFIER],      
			[ClassPtr]					[VARCHAR](300) COLLATE ARABIC_CI_AI ,       
			[Length]					[FLOAT],      
			[Width]						[FLOAT],      
			[Height]					[FLOAT],  
			[Count]						[FLOAT], 
			[BiPrice]					[FLOAT],      
			[BiDiscount]				[FLOAT],      
			[BiExtra]					[FLOAT],   
			[biBonusDisc]				[FLOAT],    
			[EntryDebit]				[FLOAT] DEFAULT 0,      
			[EntryCredit]				[FLOAT] DEFAULT 0,      
			[Notes]						[VARCHAR](500) COLLATE ARABIC_CI_AI DEFAULT '',     
			[Balance]					[FLOAT] DEFAULT 0,     
			[SalesMan]					[FLOAT] DEFAULT 0,  
			[Vendor]					[FLOAT] DEFAULT 0,    
			[ContraAcc]					[UNIQUEIDENTIFIER] DEFAULT 0X00, 
			[OppAccName]				[VARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[OppAccCode]				[VARCHAR](300) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld1]				[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld2]				[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld3]				[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
			[buTextFld4]				[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
			[MatSecurity]				[INT],  
			[Flag]						[INT] DEFAULT 0, 
			[FormatedNumber]			[INT], 
			[Branch]					[UNIQUEIDENTIFIER] DEFAULT 0X00, 
			[Checked]					[BIT],
			[DueDate]					SMALLDATETIME DEFAULT '1/1/1980',
			CHGuid						UNIQUEIDENTIFIER DEFAULT 0X00,
			CHTypGuid					UNIQUEIDENTIFIER DEFAULT 0X00,
			chNumber					INT
		)   
	CREATE TABLE  [#MatchNote]     
	(     
			[CustPtr]					[UNIQUEIDENTIFIER], 
			[Notes]						[VARCHAR](500) COLLATE ARABIC_CI_AI DEFAULT '' 
	) 
		    
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
	
	SET @UserId = @UserGUID
    
    INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM  @Types WHERE [TYPE] = 1
	
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM  @Types WHERE [TYPE] = 2
	
	INSERT INTO [#NotesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserId, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM  @Types WHERE [TYPE] = 5

	INSERT [#EntrySource] SELECT [Type],[Security],1 FROM [#EntryTbl] 
	INSERT [#EntrySource] SELECT [Type],[Security],2 FROM [#NotesTbl]  
	INSERT [#EntrySource] SELECT [Type],[Security],3 FROM [#BillTbl] 
		
	IF( ISNULL( @JobCostGUID, 0x0) = 0x0)  
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
		 
	INSERT INTO [#Cust]( [Number], [Security]) EXEC [prcGetCustsList] @CustomerGUID, @AccountGUID ,0x0, @CustomerCondition
	 
	SELECT [b].[Type],[Security], [ReadPriceSecurity],[UnpostedSecurity],[bt].[Type] AS [btType], [VatSystem] AS [btVatSystem]  
	,CASE [bisInput] WHEN 1 THEN 1 ELSE -1 END AS [btDirection]  
	INTO [#BillTbl2]  
	FROM [#BillTbl] AS [b] INNER JOIN [bt000] AS [bt] ON bt.[Guid] =  [b].[Type]   
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID  
	IF( @UseCheckDate = 0)     
		UPDATE [#Cust] SET [FromDate] = @StartDate   
	ELSE    
	BEGIN  
		SELECT [AccGUID],MAX([CheckedToDate]) AS [chDate] 
		INTO [#chkAcc]  
		FROM [dbo].[CheckAcc000]   
		WHERE  
		[CheckedToDate] <= @EndDate 
		AND [CostGUID] =  @JobCostGUID 
		GROUP BY [AccGUID]  
		UPDATE [#Cust] SET [FromDate] = ISNULL ( [va].[chDate] + 1,@StartDate)   
			FROM [#Cust] AS [c] INNER JOIN [cu000] AS [vc] ON [c].[Number] = [vc].[GUID]     
			LEFT JOIN [#chkAcc] AS [va] ON [vc].[AccountGuid] = [va].[accGUID] 
		IF @ShowMatchNote > 0 
			INSERT INTO  [#MatchNote] SELECT [c].[Number],ISNULL([cha].[Notes],'') 
					FROM [#Cust] AS [c] INNER JOIN [cu000] AS [vc] ON [c].[Number] = [vc].[GUID]     
					LEFT JOIN [#chkAcc] AS [va] ON [vc].[AccountGuid] = [va].[accGUID] 
					INNER JOIN [dbo].[CheckAcc000]  AS [cha] ON [cha].[CheckedToDate] = [va].[chDate] AND [cha].[AccGUID] = [va].[AccGUID] 
	END 
	IF ( @ShowBillDetails <> 0)  
	BEGIN  
		CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])   
		INSERT INTO [#MatTbl]	SELECT [mtGuid],[mtSecurity] FROM [vwMt] 
		CREATE CLUSTERED INDEX MTIND ON  [#MatTbl]([MatGUID]) 
	END 
	SELECT [Cu].[Number], [Cu].[Security], [Cu].[FromDate],[C].[AccountGuid] INTO [#CUST1] FROM [#Cust] AS [Cu] INNER JOIN [cu000] AS [C] ON [Cu].[Number] = [C].[guid]       
	SELECT NUMBER,AccountGuid ,0 AS FLAG INTO [#CUST2] FROM [#CUST1] 
	CREATE CLUSTERED INDEX COIND ON  [#CostTbl]([Guid]) 
	CREATE CLUSTERED INDEX BTIND ON  [#BillTbl2]([Type]) 
	TRUNCATE TABLE [#Result]     
	IF @CustomerGUID = 0X0  
	BEGIN 
		CREATE CLUSTERED INDEX cstind ON [#CUST1]([Number],[AccountGuid])   
		IF( @ShowBillDetails <> 0)     
			EXEC [repCPS_WithDetails] @UserID,  @EndDate, @CurrencyGUID, @CurVal, @Post, @Cash, @NotesContain, @NotesNotContain, @UseCheckDueDate, @ShowCheck, @JobCostGUID ,@ShowAccountMoved,@StartBalance,@bUnmatched,@ShowCheckWithEntry,@ShowBillDetailsDiscountsAndExtras,@ShowContraAccount
		ELSE     
			EXEC [repCPS_WithoutDetails] @UserID,  @EndDate,  @CurrencyGUID, @CurVal, @Post, @Cash, @NotesContain, @NotesNotContain, @UseCheckDueDate, @ShowCheck, @JobCostGUID,@ShowAccountMoved,@StartBalance,@bUnmatched,@ShowCheckWithEntry,@ShowContraAccount,0
		CREATE TABLE [#AccTbl]( [Number] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT]) 
		
		truncate table #CUST1 
		 
		INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccountGUID 
		IF @CustomerCondition = ''
			INSERT INTO [#CUST1] SELECT a.[Number],  a.[Security] ,@StartDate,a.[Number] FROM [#AccTbl] A  
		inner join ac000 ac on  ac.Guid = a.Number  
		left join cu000 cu on cu.accountGuid = ac.Guid 
		WHERE AC.NSONS = 0 AND cu.Guid IS NULL 
		SET @cstCnt = @@ROWCOUNT 
		 
		IF (@cstCnt > 0) AND @UseCheckDate > 0 
		BEGIN 
			UPDATE [#CUST1] SET [FromDate] = ISNULL ( [va].[chDate] + 1,@StartDate)   
			FROM [#CUST1] AS [c]   
			LEFT JOIN [#chkAcc] AS [va] ON [C].[AccountGuid] = [va].[accGUID] 
		END 
		IF @cstCnt > 0 
		BEGIN
			INSERT INTO [#CUST2] SELECT Number,AccountGuid,1 FROM #CUST1
			EXEC [repCPS_WithoutDetails] @UserID,  @EndDate,  @CurrencyGUID, @CurVal, @Post, @Cash, @NotesContain, @NotesNotContain, @UseCheckDueDate, @ShowCheck , @JobCostGUID,@ShowAccountMoved ,@StartBalance,@bUnmatched,@ShowCheckWithEntry,@ShowBillDetailsDiscountsAndExtras ,@ShowContraAccount
	 	END
	END 
	ELSE 
	BEGIN 
		SELECT @CustSec = [Security], @CustFromDate = [FromDate] FROM [#Cust] 
		IF( @ShowBillDetails <> 0)    
			EXEC [repCPS_WithDetails_OneCust] @UserID, @CustFromDate, @EndDate, @CustomerGUID, @CustSec, @CurrencyGUID , @CurVal, @Post, @Cash, @NotesContain, @NotesNotContain, @UseCheckDueDate, @ShowCheck, @JobCostGUID ,@ShowAccountMoved,@StartBalance,@bUnmatched,@ShowCheckWithEntry,@ShowBillDetailsDiscountsAndExtras,@ShowContraAccount
		ELSE    
			EXEC [repCPS_WithoutDetails_OneCust] @UserId,@StartDate,	@EndDate,@CustomerGUID ,@CustSec,@CurrencyGUID ,@CurVal,@Post,@Cash,@NotesContain,@NotesNotContain,@UseCheckDueDate ,@ShowCheck ,@JobCostGUID,@ShowAccountMoved ,@StartBalance ,@bUnmatched,@ShowCheckWithEntry  ,@ShowBillDetailsDiscountsAndExtras,@ShowContraAccount
	
	END 
	IF @CheckDateLine > 0 
		INSERT INTO [#Result] ([CustPtr],[Date],[Flag])	SELECT [cu].[Number],[CheckedToDate],10000 from ([#Cust1] AS [cu] INNER JOIN (SELECT DISTINCT [CustPtr] FROM [#Result]) AS [r] ON [CustPtr] = [cu].[Number]) INNER JOIN [dbo].[CheckAcc000]  AS [ch] ON [ch].[AccGUID] = [AccountGuid] 
	IF @ShowMatchNote > 0 
		UPDATE [r] SET [Notes] = [m].[Notes] FROM [#Result] AS [r] INNER JOIN  [#MatchNote] AS [m] ON [r].[CustPtr] = [m].[CustPtr] WHERE [Flag] = 0 
	
	-- ARWA 2
	--  „  ⁄ÿÌ· „Ì“… «· œﬁÌﬁ ≈·Ï √Ã· €Ì— „”„Ï
	
	/*IF @ShowChecked > 0 
	BEGIN 
		UPDATE [#Result] set [enGuid] = [Guid] WHERE [enGuid] IS NULL 
		UPDATE	r 
		SET	[Checked] = 1  
		FROM [#Result] [r] INNER JOIN rch000 a  ON r.[enGuid] = a.[ObjGUID] 
		WHERE a.Type = @Rid 
		 	AND( (@CheckForUsers = 1) OR ([a].[UserGUID] = @UserID)) 
		IF( @ItemChecked = 0)   
			DELETE FROM [#Result] WHERE [Checked] <> 1 OR  [Checked] IS NULL 
		ELSE IF( @ItemChecked = 1)   
				DELETE FROM [#Result] WHERE [Checked] = 1  
	END*/ 
	DECLARE @opDivideDiscount INT
	SET @opDivideDiscount = [dbo].[fnOption_GetValue]( 'AmnCfg_DivideDiscount', 1)
	
	SELECT 
  			[CustPtr]
  			,[CustSecurity]
  			,[fr].[Type]
  			,[fr].[Guid]
  			,[fr].[Number]
  			,CASE fr.Flag WHEN 0 THEN '' WHEN 1000 THEN '' ELSE [Date] END [Date]
  			,[ParentType]
  			,[ParentNum]
  			,[Balance]
  			,[IsCash]
  			,[BuTotal]
  			,[BuVAT]
  			,[BuDiscount]
  			,[BuExtra]
  			,[BuFirstPay]
  			,[MatPtr]
  			,[Store]
  			,[fr].[Qty]
  			,[fr].[Bonus]
  			,[Unit]
  			,[BiPrice]
  			,[BiDiscount]
  			,[BiExtra]
  			,[EntryDebit]
  			,[EntryCredit]
  			,[fr].[Notes]
  			,[fr].[Flag]
  			,[OrderFlag]
  			,[biBonusDisc]
  			,[biQty2]
  			,[biQty3]
  			,[Length]
  			,[Width]
  			,[Height]
  			,[Count]
  			,[ExpireDate]
  			,[ProductionDate]
  			,[CostPtr]
  			,[ClassPtr]
  			,[OppAccName]
  			,[OppAccCode]
			,[buTextFld1]
			,[buTextFld2]
			,[buTextFld3]
			,[buTextFld4]
			,[fr].[Vendor]
			,[SalesMan]
			,[FormatedNumber]
			,[BNotes]
			,[checked]
			,[enGuid]
			,CASE @Lang WHEN 'ar' THEN [Br].[Name] ELSE [Br].[LatinName] END AS [brName]
			,[DueDate]
			,CHGuid
			,CHTypGuid
			,chNumber
			,[mt].[Guid] mtGuid
			,[mt].[Code]
			,[mt].[Name]
			,[mt].[LatinName]
			,[mt].[BarCode]
			,[Unity],[Spec]
			,[High]
			,[Low]
			,[Origin]
			,[Company]
			,[Unit2]
			,[Unit2Fact]
			,[Unit3]
			,[Unit3Fact] 
		    ,[Pos]
		    ,[Dim]
		    ,[Color]
		    ,[Provenance]
		    ,[Quality]
		    ,[Model]
		    ,[mt].[Type] mtType
		    ,[GroupGUID]
		    ,[BarCode2]
		    ,[BarCode3]
		    ,cu.Number cuNumber
		    , isnull(cu.Guid,c.number) CuGuid
		    ,c.FLAG CuFlag
		    ,cu.Address
		    ,cu.Area
		    ,cu.BarCode cuBarCode
		    ,cu.Certificate
		    ,cu.CheckDate
		    ,cu.City
		    ,cu.Country
		    ,ISNULL(CASE @Lang WHEN 'ar' THEN cu.CustomerName ELSE cu.LatinName END, CASE @Lang WHEN 'ar' THEN [ac2].[Name] ELSE [ac2].[LatinName] END) CustomerName
		    ,cu.DateOfBirth
		    ,cu.DefPrice 
		    ,cu.DiscRatio
		    ,cu.EMail
		    ,cu.FAX
		    ,cu.Gender
		    ,cu.GLNFlag
		    ,cu.GPSX
		    ,cu.GPSY
		    ,cu.GPSZ
		    ,cu.HomePage
		    ,cu.Hoppies
		    ,cu.Job
		    ,cu.JobCategory
		    ,cu.Mobile
		    ,cu.Nationality
		    ,cu.Notes cuNotes
		    ,cu.Pager
		    ,cu.Phone1
		    ,cu.Phone2
		    ,cu.POBox
		    ,cu.Prefix
		    ,cu.State
		    ,cu.Street
		    ,cu.Suffix
		    ,cu.TELEX
		    ,cu.Type cuType
		    ,cu.UserFld1
		    ,cu.UserFld2
		    ,cu.UserFld3
		    ,cu.UserFld4
		    ,cu.ZipCode
		    ,c.number acGuid
		    ,ISNULL(AcCode, ac2.code ) AcCode
		    , CASE @Lang WHEN 'ar' THEN ISNULL(AcName, ac2.name ) ELSE ISNULL(AcLatinName, ac2.LatinName ) END AcName
		    -- New Added Fields In ARWA 2
			, CASE [fr].[Flag]
				WHEN -1 THEN Ch.Abbrev + ':' + CAST(Ch.Number AS VARCHAR(255))
				WHEN 1 THEN  '”‰œ:' + CAST(fr.Number AS VARCHAR(255))
				WHEN 2 THEN Bu.Abbrev + ':' + CAST(Bu.Number AS VARCHAR(255))
				WHEN 4 THEN Py.Abbrev + ':' + CAST(Py.Number AS VARCHAR(255))
				WHEN 5 THEN Ch.Abbrev + ':' + CAST(Ch.Number AS VARCHAR(255))
				WHEN 6 THEN Er.Abbrev + ':' + CAST(Er.Number AS VARCHAR(255))
				WHEN 7 THEN Er.Abbrev + ':' + CAST(Er.Number AS VARCHAR(255))
				END DocumentName
			, @opDivideDiscount opDivideDiscount
			, @CurVal CurrencyVal
			, @CurCode CurrencyCode
			, @DefCurCode DefCurCode
			, CASE 
				WHEN fr.Flag = 2 THEN  
					(
					CASE [Bu].[IsBillInput] 
						WHEN 1 THEN BuFirstPay 
						ELSE ABS( ( ( ( CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) + ( CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras = 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) ) * CASE [Bu].[IsBillInput] WHEN 1 THEN -1 ELSE 1 END )/* + CASE [Bu].[IsBillInput] WHEN 1 THEN BuFirstPay ELSE -BuFirstPay END*/ )
					END
					
					
					 + CASE [IsCash] 
						WHEN 1 THEN CASE [Bu].[IsBillInput] 
										WHEN 1 THEN CASE @ShowBillDiscountsAndExtras 
											WHEN 0 THEN (ABS ( ( ( ( CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras  WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) + ( CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras  = 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) ) * CASE [Bu].[IsBillInput] WHEN 1 THEN -1 ELSE 1 END ) + CASE [Bu].[IsBillInput] WHEN 1 THEN BuFirstPay ELSE -BuFirstPay END )) - BuFirstPay
											ELSE 0
										END
									ELSE 0
									END
						ELSE 0
						END
					 + CASE @ShowBillDiscountsAndExtras
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
					 + CASE @ShowBillDiscountsAndExtras
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
						)
						* 
						CASE [biNumber] WHEN 0 THEN 1 ELSE 0 END
				WHEN fr.Flag = -1 OR fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 5 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [EntryDebit]
				ELSE 0
			  END AS TotalDebit -- „Ã„Ê⁄ „œÌ‰
			, CASE
				WHEN fr.Flag = 2 THEN 
					(
					CASE [Bu].[IsBillInput] 
						WHEN 0 THEN BuFirstPay 
						ELSE ABS( ( ( ( CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) + ( CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras= 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) ) * CASE [Bu].[IsBillInput] WHEN 1 THEN -1 ELSE 1 END ) /*+ CASE [Bu].[IsBillInput] WHEN 1 THEN BuFirstPay ELSE -BuFirstPay END*/ )
					END
					+ CASE [IsCash] 
						WHEN 1 THEN CASE [Bu].[IsBillInput] 
										WHEN 0 THEN CASE @ShowBillDiscountsAndExtras 
											WHEN 0 THEN (ABS ( ( ( ( CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) + ( CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras = 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) ) * CASE [Bu].[IsBillInput] WHEN 1 THEN -1 ELSE 1 END ) + CASE [Bu].[IsBillInput] WHEN 1 THEN BuFirstPay ELSE -BuFirstPay END )) - BuFirstPay
											ELSE 0
										END
									ELSE 0
									END
						ELSE 0
						END
					+ CASE @ShowBillDiscountsAndExtras 
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN [BuDiscount]
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
					+ CASE @ShowBillDiscountsAndExtras 
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
						)
						*
						CASE [biNumber] WHEN 0 THEN 1 ELSE 0 END
				WHEN fr.Flag = -1 OR fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 5 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [EntryCredit]
				ELSE 0 
			  END AS TotalCredit -- „Ã„Ê⁄ œ«∆‰
			, CASE 
				WHEN fr.Flag = 2 THEN 
					CASE [IsCash] WHEN 0 THEN ( ( ( CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) + ( CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras= 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END ) ) * CASE [Bu].[IsBillInput] WHEN 1 THEN -1 ELSE 1 END ) + CASE [Bu].[IsBillInput] WHEN 1 THEN BuFirstPay ELSE -BuFirstPay END + CASE @ShowBillDiscountsAndExtras WHEN 1 THEN CASE [Bu].[bIsOutput] WHEN 1 THEN [BuExtra] - [BuDiscount] ELSE [BuDiscount] - [BuExtra] END ELSE 0 END ELSE 0 END
					*
					CASE [biNumber] WHEN 0 THEN 1 ELSE 0 END
				WHEN fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 5 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [EntryDebit] - [EntryCredit]
				ELSE 0
			  END AS Bal -- —’Ìœ «·Õ—ﬂ… ⁄‰œ„« ÌﬂÊ‰ „ÊÃ» ‰÷⁄Â „œÌ‰ Ê ⁄‰œ„« ÌﬂÊ‰ ”«·» ‰ﬁ·» ≈‘«— Â Ê ‰÷⁄Â œ«∆‰
			, CASE fr.Flag WHEN -1 THEN [EntryDebit] - [EntryCredit] ELSE 0 END AS ChkBalance -- —’Ìœ «·√Ê—«ﬁ «·„«·Ì… €Ì— «·„Õ’·… ⁄‰œ„« ÌﬂÊ‰ „ÊÃ» ‰÷⁄Â „œÌ‰ Ê ⁄‰œ„« ÌﬂÊ‰ ”«·» ‰⁄ﬂ” «·≈‘«—… Ê ‰÷⁄Â œ«∆‰
			, CASE 
				WHEN fr.Flag = 2 AND OrderFlag = 1 THEN EntryDebit
				WHEN fr.Flag = 2 THEN CASE [Bu].[IsBillInput] 
					WHEN 0 THEN 
						CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END
						+ CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras = 1 THEN CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ELSE 0 END
					ELSE 0
					END
					*
					CASE [biNumber] WHEN 0 THEN 1 ELSE 0 END
				WHEN fr.Flag = -1 OR fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 5 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [EntryDebit]
				ELSE 0
			END AS Debit-- „œÌ‰
			, CASE 
				WHEN fr.Flag = 2 AND OrderFlag = 1 THEN EntryCredit
				WHEN fr.Flag = 2 THEN CASE [Bu].[IsBillInput] 
					WHEN 1 THEN 
						CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END
						+ CASE WHEN [IsCash] = 1 AND @ShowBillDiscountsAndExtras = 1 THEN CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END ELSE 0 END
					ELSE 0
					END
					*
					CASE [biNumber] WHEN 0 THEN 1 ELSE 0 END
				
				WHEN fr.Flag = -1 OR fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 5 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [EntryCredit]
				ELSE 0
			END AS Credit --  œ«∆‰
			, CASE 
				WHEN fr.Flag = 0 THEN CASE WHEN @ShowMatchNote = 1 AND @UseCheckDate = 1 THEN [fr].[Notes] ELSE '' END
				WHEN fr.Flag = 1 OR fr.Flag = 4 OR fr.Flag = 6 OR fr.Flag = 7 OR fr.Flag = 8 THEN [fr].[Notes]
				--WHEN fr.Flag = -1 OR fr.Flag = 5 THEN [BNotes]
				-- [BNotes]
				-- «·«” ›«œ… „‰Â ›Ì —√” «·›« Ê—… Ê «·√Ê—«ﬁ «·„«·Ì… «·„Õ’·… Ê €Ì— «·„Õ’·…
				WHEN fr.Flag = 2 AND OrderFlag = 0 THEN CASE @Lang WHEN 'ar' THEN [mt].[Name] ELSE [mt].[LatinName] END
				WHEN fr.Flag = 2 AND OrderFlag = 1 THEN [OppAccName]
			  END AS FinalNotes
			  -- [repCPS] 
			, CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] ELSE 0 END  AS TotalTotal			
			,[Bu].[FldUnitPrice]
			,[Bu].[FldTotalPrice]
			, CASE ( [BuTotal] - CASE @opDivideDiscount WHEN 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END )
			  WHEN 0 THEN 0
			  ELSE  100 * ([BuDiscount] - [BuExtra]) / ( [BuTotal] - CASE @opDivideDiscount WHEN 1 THEN [BuExtra] - [BuDiscount] ELSE 0 END )
			 END AS [BuDiscExtPer]
			, CASE WHEN IsCash = 1 AND fr.Flag = 2 THEN CASE WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0 ELSE [BuTotal] END + CASE @ShowBillDiscountsAndExtras WHEN 0 THEN [BuExtra] - [BuDiscount] - BuFirstPay ELSE 0 END ELSE 0 END AS BuCashCredit
			,CASE @ShowBillDiscountsAndExtras 
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
					 + CASE @ShowBillDiscountsAndExtras 
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								END
							ELSE 0
						END AS BuExtDiscDebit
			, CASE @ShowBillDiscountsAndExtras
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN [BuDiscount]
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuDiscount]
										END
									ELSE 0
									END
								END
							ELSE 0
						END
					+ CASE @ShowBillDiscountsAndExtras 
							WHEN 1 THEN CASE [IsCash]
								WHEN 1 THEN CASE [Bu].[IsBillInput] 
									WHEN 0 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								ELSE CASE [Bu].[IsBillInput] 
									WHEN 1 THEN CASE 
										WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
										ELSE [BuExtra]
										END
									ELSE 0
									END
								END
							ELSE 0
						END AS BuExtDiscCredit
			, (SELECT ISNULL( COUNT(*), 1) FROM #Result WHERE Guid = fr.Guid) GuidRepeatance
			, CASE 
				WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
				ELSE [BuExtra]
			  END Extra
			, CASE 
				WHEN [Bu].[FldUnitPrice] <= 0 AND [Bu].[FldTotalPrice] <= 0 THEN 0
				ELSE [BuDiscount]
			  END Discount
			, biNumber
			, Gr.Name GroupName
			, Gr.LatinName GroupLatinName
			, CASE @Lang WHEN 'ar' THEN Che.Name ELSE Che.LatinName END + ':' + CAST( Che.Number AS VARCHAR(255) ) CheckName
			, CASE @Lang WHEN 'ar' THEN Co.Name ELSE Co.LatinName END CostName
			, CASE fr.Flag WHEN 0 THEN [BuTotal] ELSE 0 END InitBal
			, CAST( NULL AS FLOAT) BalanceInEachActivity
			, CAST( NULL AS FLOAT) TotalQtys
			, 0 RowOrder
		 INTO #FinalResult
		 FROM [#Result] fr 
			LEFT JOIN [BR000] br ON [Branch] = [br].[Guid] 
			LEFT JOIN [CU000] CU ON [CU].[GUID] = [CustPtr] 
			LEFT JOIN [#CUST2] c ON c.Number = [CustPtr] 
			LEFT JOIN [vwAc] ac ON [ac].[acGuid] = [cu].[AccountGuid] 
			LEFT JOIN [Ac000] ac2 ON [ac2].[Guid] = [fr].[CustPtr] 
			LEFT JOIN [mt000] AS [mt] ON [fr].[MatPtr] = [mt].[Guid] 
			LEFT JOIN [Gr000] AS [Gr] ON [Gr].[GUID] = [mt].[GroupGUID]
			LEFT JOIN 
			( 
				SELECT [Bu].[Guid], [Bu].[Number], [Bt].[Abbrev], [Bt].[LatinAbbrev], [Bt].[bIsOutput], [Bt].[bIsInput], [Bt].[FldUnitPrice], [Bt].[FldTotalPrice]
				, CASE [Bt].[Type] WHEN 3 THEN 1 WHEN 4 THEN 0 WHEN 2 THEN CASE [Bt].[bIsInput] WHEN 0 THEN 1 ELSE 0 END ELSE [Bt].[bIsInput] END AS IsBillInput FROM Bu000 Bu
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
			)Bu ON [Bu].[Guid] = [fr].[Guid]
			LEFT JOIN
			(
				SELECT [Py].[Guid], [Py].[Number], [Et].[Abbrev], [Et].[LatinAbbrev] FROM Py000 Py
				INNER JOIN Et000 Et ON Et.Guid = Py.TypeGuid
			)Py ON [Py].[Guid] = [fr].[Guid]
			LEFT JOIN
			(
				SELECT [Er].[EntryGuid], [Ch].[Number], [Nt].[Abbrev], [Nt].[LatinAbbrev] FROM Er000 Er 
				INNER JOIN Ch000 Ch ON Ch.Guid = Er.ParentGuid
				INNER JOIN Nt000 Nt ON Nt.Guid = Ch.TypeGuid
			)Er ON [Er].[EntryGuid] = [fr].[Guid] 
			LEFT JOIN
			(
				SELECT [Ch].[Guid], [Ch].[Number], [Nt].[Abbrev], [Nt].[LatinAbbrev] FROM Ch000 Ch
				INNER JOIN Nt000 Nt ON Nt.Guid = Ch.TypeGuid
			)Ch ON [Ch].[Guid] = [fr].[Guid]
			LEFT JOIN
			(
				SELECT [Ch].[Guid], [Ch].[Number], [Nt].[Name], [Nt].[LatinName] FROM Ch000 Ch
				INNER JOIN Nt000 Nt ON Nt.Guid = Ch.TypeGuid
			)Che ON [Che].[Guid] = [CHGuid]
			LEFT JOIN co000 Co ON Co.GUID = [CostPtr]
			
		WHERE CustPtr IN (SELECT DISTINCT CustPtr FROM #Result WHERE ISNULL(Type, 0x0) <> 0x0 )
		ORDER BY 
		
			CASE @OrderType WHEN 1 THEN [ac].[acCode] WHEN 2 THEN [ac].[acName] ELSE CAST( [CustPtr] AS VARCHAR(255) ) END
			,[Date]
			, [fr].[Flag]
			, CASE WHEN @ShowBillDetails <> 0 THEN [fr].[Type] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [fr].[Number] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [fr].[Guid] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [OrderFlag] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [biNumber] END
			, CASE WHEN @ShowBillDetails = 0 THEN [OrderFlag] END
			, CASE WHEN @ShowBillDetails = 0 THEN [fr].[Type] END
			, CASE WHEN @ShowBillDetails = 0 THEN [fr].[Number] END
			, CASE WHEN @ShowBillDetails = 0 THEN [fr].[Guid] END
	Declare @PrevGuid UNIQUEIDENTIFIER
	SET @PrevGuid = 0x0
	Declare @CPrevCustPtr UNIQUEIDENTIFIER
	SET @PrevGuid = 0x0
	
	Declare @PrevFlag INT
	SET @PrevFlag = 0x0
	
	Declare @CCustPtr UNIQUEIDENTIFIER      
	Declare @CGuid UNIQUEIDENTIFIER      
	Declare @CEnGuid UNIQUEIDENTIFIER      
	Declare @CType UNIQUEIDENTIFIER      
	Declare @CacCode VARCHAR (255) 		
	Declare @CacName VARCHAR (255) 		
	Declare @CVendor VARCHAR (255) 		
	Declare @CSalesMan VARCHAR (255) 		
	Declare @CbrName VARCHAR (255) 		
	Declare @CCheckName VARCHAR (255) 		
	Declare @CBNotes VARCHAR (255) 		
	Declare @CCostName VARCHAR (255) 		
	
	
	Declare @CDate DATETIME
	Declare @CDueDate DATETIME
	
	Declare @CBuVat FLOAT
	Declare @CBuFirstPay FLOAT
	Declare @CBuExtDiscDebit FLOAT
	Declare @CBuExtDiscCredit FLOAT
	Declare @CBuCashCredit FLOAT
	Declare @CExtra FLOAT
	Declare @CDiscount FLOAT
	Declare @CDebit FLOAT
	Declare @CCredit FLOAT
	Declare @CBal FLOAT
	Declare @CChkBalance FLOAT
	Declare @CInitBal FLOAT
	Declare @CBuDiscExtPer FLOAT
	
	Declare @CFlag INT
	Declare @CNumber INT
	Declare @CBiNumber INT
	Declare @COrderFlag INT
	Declare @CGuidRepeatance INT
	Declare @CCurrentGuidRepeatance INT
	SET @CCurrentGuidRepeatance = 0
	
	
	SELECT * INTO #FinalResult1 FROM #FinalResult
	
	DECLARE @BalanceInEachActivity FLOAT
	SET @BalanceInEachActivity = 0
	
	Declare SellCur Cursor   FORWARD_ONLY FOR    
    Select   
    	CustPtr 
    	,Guid
    	,EnGuid
    	,Date
		,acCode
		,acName
		,Flag
		,Number
		,Type
		,BiNumber
		,OrderFlag
		,BuVat
		,BuFirstPay
		,BuExtDiscDebit
		,BuExtDiscCredit
		,BuCashCredit
		,Discount
		,Extra
		,Debit
		,Credit
		,Vendor
		,SalesMan
		,Bal
		,ChkBalance
		,brName
		,CheckName
		,DueDate
		,BNotes
		,CostName
		,InitBal
		,BuDiscExtPer
		,GuidRepeatance
	FROM #FinalResult
	OPEN SellCur  
		FETCH NEXT FROM SellCur INTO   
			@CCustPtr
			,@CGuid
			,@CEnGuid
			,@CDate
			,@CacCode
			,@CacName
			,@CFlag
			,@CNumber
			,@CType
			,@CBiNumber
			,@COrderFlag
			,@CBuVat
			,@CBuFirstPay
			,@CBuExtDiscDebit
			,@CBuExtDiscCredit
			,@CBuCashCredit
			,@CDiscount
			,@CExtra
			,@CDebit
			,@CCredit
			,@CVendor
			,@CSalesMan
			,@CBal
			,@CChkBalance
			,@CbrName
			,@CCheckName
			,@CDueDate
			,@CBNotes
			,@CCostName
			,@CInitBal
			,@CBuDiscExtPer
			,@CGuidRepeatance
		WHILE @@FETCH_STATUS = 0  
    		BEGIN  
    			IF(@CCustPtr <> @CPrevCustPtr)
    				SET @BalanceInEachActivity = 0
    			SET @CPrevCustPtr = @CCustPtr
    			SET @BalanceInEachActivity = @BalanceInEachActivity + ISNULL(@CBal, 0) + ISNULL(@CChkBalance, 0) + ISNULL(@CInitBal, 0)
    			
    			IF(@CGuid <> @PrevGuid AND @CFlag = 2 )
    				INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type, BiNumber, OrderFlag, Debit, Credit, Vendor, SalesMan, BuCashCredit, Bal ,ChkBalance, brName, CheckName, DueDate, CostName, BuDiscExtPer, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType, @CBiNumber, @COrderFlag, @CDebit, @CCredit, @CVendor, @CSalesMan, @CBuCashCredit, @CBal ,@CChkBalance, @CbrName, @CCheckName, @CDueDate, @CCostName, @CBuDiscExtPer, @CBNotes,-1)
    				
				IF(@CGuid = @PrevGuid )
					SET @CCurrentGuidRepeatance = @CCurrentGuidRepeatance + 1
				ELSE 
					SET @CCurrentGuidRepeatance = 1
				IF(@CFlag = 2 AND @CCurrentGuidRepeatance = @CGuidRepeatance)
					BEGIN
						IF(@ShowBillDetails = 1 AND @CBuVat <> 0)
							INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Debit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CBuVat, 'ﬁÌ„… «·÷—Ì»… «·„÷«›…', 5)
						IF(@CBuFirstPay <> 0)
							INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Debit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CBuFirstPay, '«·œ›⁄… «·√Ê·Ï', 6)
						IF(@ShowBillDiscountsAndExtras = 1)
							BEGIN
								INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Credit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CBuExtDiscCredit, '≈Ã„«·Ì «·Õ”„Ì« ', 3)
								INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Debit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CBuExtDiscDebit, '≈Ã„«·Ì «·≈÷«›« ', 4)
							END
						IF(@CBuCashCredit <> 0)
							INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Credit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CBuCashCredit, 'ﬁÌ„… «·›« Ê—…', 7)
						IF( @ShowBillDiscountsAndExtras = 0 AND @ShowBillDetailsDiscountsAndExtras = 0 AND @ShowBillDetails = 1 AND @CDiscount <> 0 )
							INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Credit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CDiscount, '≈Ã„«·Ì «·Õ”„Ì« ', 1)
						IF( @ShowBillDiscountsAndExtras = 0 AND @ShowBillDetailsDiscountsAndExtras = 0 AND @ShowBillDetails = 1 AND @CExtra <> 0 )
							INSERT INTO #FinalResult1(CustPtr, Guid, Date, AcCode,AcName, Flag, Number, Type,  BiNumber, OrderFlag, Debit, FinalNotes, RowOrder) VALUES(@CCustPtr, @CGuid, @CDate, @CacCode, @CacName, @CFlag, @CNumber, @CType,  @CBiNumber, @COrderFlag, @CExtra, '≈Ã„«·Ì «·≈÷«›« ', 2)
					END
				SET @PrevGuid = ISNULL(@CGuid, 0x0)
				UPDATE #FinalResult1 
					SET BalanceInEachActivity = @BalanceInEachActivity 
					WHERE ISNULL(Guid, 0x0) = ISNULL(@CGuid , 0x0)
					  AND ISNULL(EnGuid, 0x0) = ISNULL(@CEnGuid, 0x0)
					  AND (Flag <> 2 OR RowOrder = -1)
					  AND Flag <> 0
				FETCH NEXT FROM SellCur INTO   
					@CCustPtr
					,@CGuid
					,@CEnGuid
					,@CDate
					,@CacCode
					,@CacName
					,@CFlag
					,@CNumber
					,@CType
					,@CBiNumber
					,@COrderFlag
					,@CBuVat
					,@CBuFirstPay
					,@CBuExtDiscDebit
					,@CBuExtDiscCredit
					,@CBuCashCredit
					,@CDiscount
					,@CExtra
					,@CDebit
					,@CCredit
					,@CVendor
					,@CSalesMan
					,@CBal
					,@CChkBalance
					,@CbrName
					,@CCheckName
					,@CDueDate
					,@CBNotes
					,@CCostName
					,@CInitBal
					,@CBuDiscExtPer
					,@CGuidRepeatance
			END  
	CLOSE SellCur
	DEALLOCATE SellCur
	
	DECLARE @FullResult BIT
	SET @FullResult = 1
	IF Exists(Select * from #SecViol)
		SET @FullResult = 0
	
	UPDATE #FinalResult1 SET TotalQtys = R1.Qty
	FROM #FinalResult1 R
	INNER JOIN ( SELECT Guid, SUM(Qty) Qty FROM #FinalResult1 GROUP BY Guid ) R1 ON R1.Guid = R.Guid
	WHERE Flag = 2 AND RowOrder = -1
	
	SELECT *, CASE @ShowWeekLine WHEN 1 THEN ( DAY(Date) / 7 ) ELSE 0 END WeekNumber, CASE @ShowMonthLine WHEN 1 THEN MONTH(Date) ELSE 0 END MonthNumber,  @FullResult FullResult FROM #FinalResult1
	ORDER BY 
			CASE @OrderType WHEN 1 THEN acCode WHEN 2 THEN acName ELSE CAST( [CustPtr] AS VARCHAR(255) ) END
			, Date
			, Flag
			, CASE WHEN @ShowBillDetails <> 0 THEN [Type] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [Number] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [Guid] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [OrderFlag] END
			, CASE WHEN @ShowBillDetails <> 0 THEN [biNumber] END
			, CASE WHEN @ShowBillDetails = 0 THEN [OrderFlag] END
			, CASE WHEN @ShowBillDetails = 0 THEN [Type] END
			, CASE WHEN @ShowBillDetails = 0 THEN [Number] END
			, CASE WHEN @ShowBillDetails = 0 THEN [Guid] END
			, RowOrder

	Exec ARWA.prcFinilize_Environment 'RepCps'
#########################################################
CREATE PROCEDURE ARWA.repCustomerActivityByBills
	-----------------Report Filters-----------------------
	@StartDate			AS [DATETIME]			= '1/1/2009 0:0:0.0' ,     
	@EndDate            AS [DATETIME]			= '1/1/2012 0:0:0.0',     
	@AccountGUID            AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000',     
	@GroupGUID              AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000',     
	@StoreGUID              AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000',     
	@JobCostGUID               AS [UNIQUEIDENTIFIER]	= '00000000-0000-0000-0000-000000000000',     
   	@CurrencyGUID       AS [UNIQUEIDENTIFIER]	= '0177FDF3-D3BB-4655-A8C9-9F373472715A',     
	@SortCollectType    AS [INT]				= 0,   
	@SortCollectBy      As [INT]				= 0,     
	@AccountLevel       AS [INT]				= 6,     
	@CollectByBillType   [BIT]				= 0 ,      --   Ã„Ì⁄ Õ”» ‰Ê⁄  «·›« Ê—…  
	@MergeExtraValue       [BIT]				= 1, 
	@ShowPosted			   [BIT]				= 1,
	@ShowUnPosted		   [BIT]				= 1,
	@Lang					VARCHAR(100)		= 'ar',		--0 Arabic, 1 Latin
	@UserGUID				[UNIQUEIDENTIFIER]	= 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	--Guid Of Logining User
	@BranchMask				BIGINT				= -1,
	-----------------Report Sources-----------------------
	@SourcesTypes		VARCHAR(MAX)			= 'D4F4933E-805E-47F7-9CD7-B25E7A78D4DA,2,39ECA4D6-F63A-4FC3-B7EA-C6652BEF2142,2,A4FAD32E-4FCA-4B09-816A-D488B36B633A,2,8B40BBD2-BEEB-454E-B080-D61A9A907DC2,2'
	------------------------------------------------------
		/*
		This Report is a cross tab report
		Crossing is done by tow fields:
		1- [AccName] OR [AccLatinName]   (Rows)
		2- [BillType] OR [LatinBillType] (Columns)
	*/
AS        
	------------------------------------------------------------------------------    
	
	SET NOCOUNT ON 
	
	Exec [prcSetSessionConnections] @UserGUID,@BranchMask
	DECLARE @CurVal FLOAT
	SELECT @CurVal = CurrencyVal FROM my000 WHERE GUID = @CurrencyGUID
	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])    
	CREATE TABLE [#Result](     
			[Acc] [UNIQUEIDENTIFIER],      
			[BillType] [UNIQUEIDENTIFIER],      
			[buNumber] [INT],      
			[Price] [FLOAT],    
			[Security] [INT],    
			[mtSecurity] [INT],    
			[CustSecurity] [INT],    
			[AccSecurity] [INT],    
			[userSecurity] [INT],   
			[CustGuid] [UNIQUEIDENTIFIER])    
	-------Bill Resource ---------------------------------------------------------      
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTypesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnPostedSec] [INT], [ReadPriceSecurity] [INT])       
    INSERT INTO [#BillTypesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	-------------------------------------------------------------------      
	CREATE TABLE [#Account_Tbl]( [GUID] [UNIQUEIDENTIFIER], [Level] [INT] , [Path] [VARCHAR](8000), [AccSecurity] [INT])      
	INSERT INTO [#Account_Tbl]       
		SELECT       
			[fn].[GUID],       
			[fn].[Level],       
			[fn].[Path],    
			[Acc].[acSecurity]    
		FROM       
			[dbo].[fnGetAccountsList]( @AccountGUID, 1) AS [Fn]    
			INNER JOIN [vwAc] AS [Acc] ON [Fn].[GUID] = [Acc].[acGUID]  
	IF @AccountGUID IN (SELECT [GUID] FROM [AC000] WHERE [TYPE] = 4) 
	BEGIN 
		UPDATE #Account_Tbl SET [Level] = [Level] - 1 
		DELETE a FROM #Account_Tbl a where path = (SELECT MIN(PATH) FROM #Account_Tbl b GROUP BY [GUID] HAVING COUNT(*) > 1 and b.[GUID] = a.[GUID] ) 
	END   
	-------------------------------------------------------------------------   
	--EXEC [dbo].[prcCheckSecurity] @result = '#Account_Tbl'      
	-------Mat Table----------------------------------------------------------      
	CREATE TABLE [#MatTbl]( [mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])        
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  NULL, @GroupGUID, -1, NULL    
	-------Store Table----------------------------------------------------------      
	DECLARE @StoreTbl TABLE( [Number] [UNIQUEIDENTIFIER])        
	INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @StoreGUID)        
	IF ISNULL( @StoreGUID,0x0) = 0x0      
		INSERT INTO @StoreTbl VALUES( 0x0)       
	------Cost Table----------------------------------------------------------      
	DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER])      
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @JobCostGUID)        
	IF ISNULL( @JobCostGUID, 0x0) = 0x0      
		INSERT INTO @CostTbl VALUES( 0x0)       
	--//////////////////////////////////////////////////////////      
	
	INSERT INTO [#Result]    
	SELECT    
		[AcTbl].[GUID] ,    
		[Bill].[buType],    
		[buNumber] AS [buNumber],    
		CASE WHEN [Src].[ReadPriceSecurity] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @MergeExtraValue WHEN 1 THEN [FixedBiTotal] ELSE [bill].[biBillQty] * [bill].[FixedBiPrice] END AS [VAL],    
		[bill].[buSecurity] AS [buSecurity],    
		[bill].[mtSecurity] AS [mtSecurity],    
		ISNULL( [cu].[cuSecurity], 0),    
		[AcTbl].[AccSecurity],   
		CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Security] ELSE [Src].[UnPostedSec] END, 
		ISNULL( [cu].[cuGuid] , 0x0)   
	FROM 
		[vwCu] AS [cu]    
		RIGHT JOIN [dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [bill] ON [Bill].[BuCustPtr] = [cu].[cuGuid]   
		INNER JOIN [#MatTbl] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtNumber]      
		INNER JOIN [#BillTypesTbl] AS [Src] ON [Bill].[buType] = [Src].[Type]      
		INNER JOIN @CostTbl AS [Co] ON [Bill].[BiCostPtr] = [Co].[Number]      
		INNER JOIN @StoreTbl AS [St] ON [Bill].[BiStorePtr] = [St].[Number]      
		INNER JOIN [#Account_Tbl] AS [AcTbl] ON [AcTbl].[GUID] = (CASE ISNULL( [Bill].[BuCustPtr], 0x0) WHEN 0x0 THEN [Bill].[BuCustAcc] ELSE [cu].[cuAccount] END)   
	WHERE   
		[bill].[buDate] between @StartDate AND @EndDate      
		AND ( ( @ShowPosted = 1  AND [bill].[buIsPosted] = 1) OR ( @ShowUnPosted = 1 AND [bill].[buIsPosted] = 0) )
	------------------------------------------------------------------    
	EXEC [dbo].[prcCheckSecurity]   
	DECLARE @FullResult BIT
	SET @FullResult = 1
	IF Exists(Select * from #SecViol)
		SET @FullResult = 0
	------------------------------------------------------------------    
	------ First Result Table and Total Result Table-----------------------------------------------------------    
	CREATE TABLE #ResultTbl (      
			[AccPtr] [UNIQUEIDENTIFIER],       
			[Path] [VARCHAR](4000),      
			[BillType] [UNIQUEIDENTIFIER],      
			[CountMove] [FLOAT],      
			[TotalCount] [FLOAT],
			[Val] [FLOAT],   
			[TotalVal] [FLOAT],
			[acParent] [UNIQUEIDENTIFIER],   
			[Lv] [INT], 
			[Type] [INT] DEFAULT 0) -- Type 1 ->  Main Account, 0 -> Sub Account 
	DECLARE @TotalResultTbl TABLE(      
			[BillType] [VARCHAR](40),     
			[CountMove] [FLOAT],     
			[Val] [FLOAT])      
	------ End Result Table Collected by Level---------------------------------      
	INSERT INTO #ResultTbl      
	SELECT      
		[Res].[Acc],      
		[AcTbl].[Path],    
		[Res].[BillType],    
		COUNT( Distinct([Res].[buNumber])) AS [CountMove],
		COUNT( Distinct([Res].[buNumber])) AS [TotalCount],
		SUM( [Res].[Price]) AS [Price],   
		SUM( [Res].[Price]) AS [TotalVal],
		[ac].[acParent],   
		0 AS [Level], 
		0 AS [Type] 
	FROM      
		[#Result] AS [Res] INNER JOIN [#Account_Tbl] AS [AcTbl]   
		ON [Res].[Acc] = [AcTbl].[GUID]   
		INNER JOIN [vwAc] AS [ac] ON [AcTbl].[GUID] = [ac].[acGuid]   
	GROUP BY      
		[Res].[Acc],      
		[AcTbl].[Path],      
		[Res].[BillType],   
		[ac].[acParent],   
		[AcTbl].[Level]   
	-- calc total result      
	INSERT INTO @TotalResultTbl      
		SELECT       
			CASE @CollectByBillType       
				WHEN 0 THEN CAST( [BillType]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,     
			SUM( CASE WHEN [Type] = 0 THEN [CountMove] ELSE 0 END) [CountMove],      
			SUM( CASE WHEN [Type] = 0 THEN [Val] ELSE 0 END) AS [Val]      
		FROM      
			#ResultTbl AS [Res] INNER JOIN [vwBt] AS [BT]       
			ON [Res].[BillType] = [BT].[btGUID]     
		GROUP BY     
			CASE @CollectByBillType     
				WHEN 0 THEN CAST( [BillType]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END     
	--------------------------------------------------------------------      
	DECLARE @Continue [INT], @Lv [INT]       
	SET @Continue = 1       
	SET @Lv = 0       
	WHILE @Continue <> 0     
	BEGIN       
		SET @Lv = @Lv + 1       
		INSERT INTO #ResultTbl    
			SELECT       
				[AcTbl].[GUID],   
				[AcTbl].[Path],   
				[Res].[BillType],       
				SUM( [Res].[CountMove]) AS [CountMove],      
				CASE WHEN @AccountLevel = Level + 1 THEN SUM( [Res].[CountMove]) ELSE 0.0 END AS [TotalCount],      
				SUM( [Res].[Val]) AS [Val],   
				CASE WHEN @AccountLevel = Level + 1 THEN SUM( [Res].[Val]) ELSE 0.0 END AS [TotalVal],      
				[ac].[acParent],   
				@Lv, 
				1 -- main Account 
			FROM       
				[#Account_Tbl] AS [AcTbl] INNER JOIN #ResultTbl AS [Res]    
				ON [AcTbl].[GUID] = [Res].[acParent]   
				INNER JOIN [vwAc] AS [ac]    
				ON [AcTbl].[GUID] = [ac].[acGuid]   
			WHERE   
				[Lv] = @Lv - 1       
			GROUP BY       
				[AcTbl].[GUID],   
				[AcTbl].[Path],   
				[AcTbl].[Level],
				[Res].[BillType],       
				[ac].[acParent]   
		SET @Continue = @@ROWCOUNT        
	END	       
	   
	DECLARE @Sql VARCHAR(8000), 
	@CF_Table VARCHAR(255) --Mapped Table for Custom Fields 
	IF( @SortCollectType = 0)      
	BEGIN    
		SET @Sql = 'DECLARE @AccLevel  [INT] , @CollectByBillType  [INT] ' 
		SET @Sql = @Sql + ' SET @AccLevel = '+ CONVERT(VARCHAR(5),@AccountLevel) + ' ' 
		SET @Sql = @Sql + ' SET @CollectByBillType = '+ CONVERT(VARCHAR(5),@CollectByBillType) + ' ' 
		SET @Sql = @Sql +  
		' SELECT      
			[AccPtr],
			[Res].[Path],      
			[Acc].[acCode] AS [AccCode],      
			[Acc].[acName] AS [AccName],      
			[Acc].[acDebit] - [Acc].[acCredit] AS [AccBalance], 
			[Acc].[acLatinName] AS [AccLatinName],      
			ISNULL ( [Cu].[cuGUID], 0x0) AS [CustPtr],    
			ISNULL ( [Cu].[cuNumber], 0) AS [CustNum],     
			ISNULL ( [Cu].[cuCustomerName], '''') AS [CustName],     
			ISNULL ( [Cu].[cuLatinName], '''') AS [CustLatinName],    
			ISNULL ( [Cu].[cuNationality], '''') AS [CustNationality],     
			ISNULL ( [Cu].[cuAddress], '''') AS [CustAddress],     
			ISNULL ( [Cu].[cuPhone1], '''') AS [CustPhone1],     
			ISNULL ( [Cu].[cuPhone2], '''') AS [CustPhone2],     
			ISNULL ( [Cu].[cuFax], '''') AS [CustFax],     
			ISNULL ( [Cu].[cuTelex], '''') AS [CustTelex],     
			ISNULL ( [Cu].[cuNotes], '''') AS [CustNotes],     
			ISNULL ( [Cu].[cuDiscRatio], 0) AS [CustDiscRatio],    
			ISNULL ( [Cu].[cuPrefix], '''') AS [CustPrefix],    
			ISNULL ( [Cu].[cuSuffix], '''') AS [CustSuffix],    
			ISNULL ( [Cu].[cuMobile], '''') AS [CustMobile],    
			ISNULL ( [Cu].[cuPager], '''') AS [CustPager],    
			ISNULL ( [Cu].[cuEmail], '''') AS [CustEmail],    
			ISNULL ( [Cu].[cuHomePage], '''') AS [CustHomePage],    
			ISNULL ( [Cu].[cuCountry], '''') AS [CustCountry],    
			ISNULL ( [Cu].[cuCity], '''') AS [CustCity],    
			ISNULL ( [Cu].[cuArea], '''') AS [CustArea],    
			ISNULL ( [Cu].[cuStreet], '''') AS [CustStreet],    
			ISNULL ( [Cu].[cuZipCode], '''') AS [CustZipCode],    
			ISNULL ( [Cu].[cuPOBox], '''') AS [CustPOBox],    
			ISNULL ( [Cu].[cuCertificate], '''') AS [CustCertificate],    
			ISNULL ( [Cu].[cuJob], '''') AS [CustJob],    
			ISNULL ( [Cu].[cuJobCategory], '''') AS [CustJobCategory],    
			ISNULL ( [Cu].[cuUserFld1], '''') AS [CustUserFld1],    
			ISNULL ( [Cu].[cuUserFld2], '''') AS [CustUserFld2],    
			ISNULL ( [Cu].[cuUserFld3], '''') AS [CustUserFld3],    
			ISNULL ( [Cu].[cuUserFld4], '''') AS [CustUserFld4],    
			ISNULL ( [Cu].[cuDateOfBirth], '''') AS [CustDateOfBirth],    
			ISNULL ( [Cu].[cuGender], '''') AS [CustGender],    
			ISNULL ( [Cu].[cuHobbies], '''') AS [CustHobbies],    			      
			CASE @CollectByBillType       
				WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END BillType,
			CASE @CollectByBillType       
				WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END LatinBillType,
			SUM( [CountMove]) [CountMove],      
			SUM(TotalCount) TotalCount,
			SUM( [Val]) AS [Val], 
			SUM(TotalVal) TotalVal,
			[acCurrencyptr],[acCurrencyVal] '      
		IF(@FullResult = 0)
			SET @Sql = @Sql + ', 0 [FullResult]'  
		ELSE 
			SET @Sql = @Sql + ', 1 [FullResult]'  
  
		
		SET @Sql = @Sql +  
		' FROM       
			#ResultTbl AS [Res]       
			INNER JOIN [#Account_Tbl] AS [acTbl]       
			ON [Res].[AccPtr] = [acTbl].[GUID]      
			INNER JOIN [vwBt] AS [BT]       
			ON [Res].[BillType] = [BT].[btGUID]      
			INNER JOIN [vwAc] AS [Acc]       
			ON [Res].[AccPtr] = [Acc].[acGuid]      
			LEFT JOIN [vwCu] AS [Cu]       
			ON [cu].[cuAccount] = [Acc].[acGuid] '     
		
		-------------------------------------------------------------------------------------------------------   
		SET @Sql = @Sql +  
		' WHERE      
			( @AccLevel = 0 OR [acTbl].[Level] < @AccLevel) '	      
		SET @Sql = @Sql + 
		' GROUP BY      
			[AccPtr],      
			[Res].[Path],      
			[Acc].[acCode],      
			[Acc].[acName],      
			[Acc].[acLatinName],    
			[Acc].[acDebit], 
			[Acc].[acCredit], 
			[Cu].[cuGUID],    
			[Cu].[cuNumber],     
			[Cu].[cuCustomerName] ,     
			[Cu].[cuLatinName],    
			[Cu].[cuNationality],     
			[Cu].[cuAddress],     
			[Cu].[cuPhone1],     
			[Cu].[cuPhone2],     
			[Cu].[cuFax],     
			[Cu].[cuTelex],     
			[Cu].[cuNotes],     
			ISNULL( [Cu].[cuDiscRatio], 0),  
			[Cu].[cuPrefix],    
			[Cu].[cuSuffix],    
			[Cu].[cuMobile],    
			[Cu].[cuPager],    
			[Cu].[cuEmail],    
			[Cu].[cuHomePage],    
			[Cu].[cuCountry],    
			[Cu].[cuCity],    
			[Cu].[cuArea],    
			[Cu].[cuStreet],    
			[Cu].[cuZipCode],    
			[Cu].[cuPOBox],    
			[Cu].[cuCertificate],    
			[Cu].[cuJob],    
			[Cu].[cuJobCategory],    
			[Cu].[cuUserFld1],    
			[Cu].[cuUserFld2],    
			[Cu].[cuUserFld3],    
			[Cu].[cuUserFld4],    
			[Cu].[cuDateOfBirth],    
			[Cu].[cuGender],    
			[Cu].[cuHobbies],    
			CASE @CollectByBillType       
				WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,
			CASE @CollectByBillType       
				WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
				ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END  
			,[acCurrencyptr],[acCurrencyVal] '  
	-------------------------------------------------------------------------------------------------------      
		SET @Sql = @Sql + 
		' ORDER BY       
			[Res].[Path] '   
		EXEC(@Sql)     
		      
	END      
	ELSE      
	BEGIN      
		IF( @SortCollectType = 1)      
		BEGIN      
		SET @Sql = 'DECLARE @AccLevel [INT] , @CollectByBillType [INT] ' 
		SET @Sql = @Sql + 'SET @AccLevel = '+ CONVERT(VARCHAR(5),@AccountLevel) + ' ' 
		SET @Sql = @Sql + 'SET @CollectByBillType = '+ CONVERT(VARCHAR(5),@CollectByBillType) + ' ' 
		SET @Sql = @Sql +  
		' SELECT      
				[AccPtr],
				[Res].[Path],      
				[Acc].[acCode] AS [AccCode],      
				[Acc].[acName] AS [AccName],      
				[Acc].[acLatinName] AS [AccLatinName],    
				[Acc].[acDebit] - [Acc].[acCredit] AS [AccBalance], 
				ISNULL ( [Cu].[cuGUID], 0x0) AS [CustPtr],    
				ISNULL ( [Cu].[cuNumber], 0) AS [CustNum],     
				ISNULL ( [Cu].[cuCustomerName], '''') AS [CustName],     
				ISNULL ( [Cu].[cuLatinName], '''') AS [CustLatinName],    
				ISNULL ( [Cu].[cuNationality], '''') AS [CustNationality],     
				ISNULL ( [Cu].[cuAddress], '''') AS [CustAddress],     
				ISNULL ( [Cu].[cuPhone1], '''') AS [CustPhone1],     
				ISNULL ( [Cu].[cuPhone2], '''') AS [CustPhone2],     
				ISNULL ( [Cu].[cuFax], '''') AS [CustFax],     
				ISNULL ( [Cu].[cuTelex], '''') AS [CustTelex],     
				ISNULL ( [Cu].[cuNotes], '''') AS [CustNotes],     
				ISNULL ( [Cu].[cuDiscRatio], 0) AS [CustDiscRatio],  
				ISNULL ( [Cu].[cuPrefix], '''') AS [CustPrefix],    
				ISNULL ( [Cu].[cuSuffix], '''') AS [CustSuffix],    
				ISNULL ( [Cu].[cuMobile], '''') AS [CustMobile],    
				ISNULL ( [Cu].[cuPager], '''') AS [CustPager],    
				ISNULL ( [Cu].[cuEmail], '''') AS [CustEmail],    
				ISNULL ( [Cu].[cuHomePage], '''') AS [CustHomePage],    
				ISNULL ( [Cu].[cuCountry], '''') AS [CustCountry],    
				ISNULL ( [Cu].[cuCity], '''') AS [CustCity],    
				ISNULL ( [Cu].[cuArea], '''') AS [CustArea],    
				ISNULL ( [Cu].[cuStreet], '''') AS [CustStreet],    
				ISNULL ( [Cu].[cuZipCode], '''') AS [CustZipCode],    
				ISNULL ( [Cu].[cuPOBox], '''') AS [CustPOBox],    
				ISNULL ( [Cu].[cuCertificate], '''') AS [CustCertificate],    
				ISNULL ( [Cu].[cuJob], '''') AS [CustJob],    
				ISNULL ( [Cu].[cuJobCategory], '''') AS [CustJobCategory],    
				ISNULL ( [Cu].[cuUserFld1], '''') AS [CustUserFld1],    
				ISNULL ( [Cu].[cuUserFld2], '''') AS [CustUserFld2],    
				ISNULL ( [Cu].[cuUserFld3], '''') AS [CustUserFld3],    
				ISNULL ( [Cu].[cuUserFld4], '''') AS [CustUserFld4],    
				ISNULL ( [Cu].[cuDateOfBirth], '''') AS [CustDateOfBirth],    
				ISNULL ( [Cu].[cuGender], '''') AS [CustGender],    
				ISNULL ( [Cu].[cuHobbies], '''') AS [CustHobbies],    
				
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END BillType,      
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END LatinBillType,      
				SUM( [CountMove]) [CountMove], 
				SUM(TotalCount) TotalCount,
				SUM(TotalVal) TotalVal,
				SUM( [Val]) AS [Val] 
				,[acCurrencyptr],[acCurrencyVal] '  
		IF(@FullResult = 0)
			SET @Sql = @Sql + ', 0 [FullResult]'  
		ELSE 
			SET @Sql = @Sql + ', 1 [FullResult]'
		------------------------------------------------------------------------------------------------------- 
		-- Checked if there are Custom Fields to View  	 
		------------------------------------------------------------------------------------------------------- 
		
		SET @Sql = @Sql +  
		' FROM       
				#ResultTbl AS [Res]       
				INNER JOIN [#Account_Tbl] AS [acTbl]       
				ON [Res].[AccPtr] = [acTbl].[GUID]      
				INNER JOIN [vwBt] AS [BT] ON [Res].[BillType] = [BT].[btGUID]      
				INNER JOIN [vwAc] AS [Acc]      
				ON [Res].[AccPtr] = [Acc].[acGuid]      
				LEFT JOIN [vwCu] AS [cu]      
				ON [Cu].[cuAccount] = [Acc].[acGuid] '     
		-------------------------------------------------------------------------------------------------------   
		SET @Sql = @Sql +  
		' WHERE      
				( @AccLevel = 0 OR [acTbl].[Level] < @AccLevel) '     
		SET @Sql = @Sql + 
		' GROUP BY       
				[AccPtr],      
				[Res].[Path],      
				[Acc].[acCode],      
				[Acc].[acName],      
				[Acc].[acLatinName],    
				[Acc].[acDebit], 
				[Acc].[acCredit], 
				[Cu].[cuGUID],    
				[Cu].[cuNumber],     
				[Cu].[cuCustomerName] ,     
				[Cu].[cuLatinName],    
				[Cu].[cuNationality],     
				[Cu].[cuAddress],     
				[Cu].[cuPhone1],     
				[Cu].[cuPhone2],     
				[Cu].[cuFax],     
				[Cu].[cuTelex],     
				[Cu].[cuNotes],     
				[Cu].[cuDiscRatio],    
				[Cu].[cuPrefix],    
				[Cu].[cuSuffix],    
				[Cu].[cuMobile],    
				[Cu].[cuPager],    
				[Cu].[cuEmail],    
				[Cu].[cuHomePage],    
				[Cu].[cuCountry],    
				[Cu].[cuCity],    
				[Cu].[cuArea],    
				[Cu].[cuStreet],    
				[Cu].[cuZipCode],    
				[Cu].[cuPOBox],    
				[Cu].[cuCertificate],    
				[Cu].[cuJob],    
				[Cu].[cuJobCategory],    
				[Cu].[cuUserFld1],    
				[Cu].[cuUserFld2],    
				[Cu].[cuUserFld3],    
				[Cu].[cuUserFld4],    
				[Cu].[cuDateOfBirth],    
				[Cu].[cuGender],    
				[Cu].[cuHobbies], 
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BillType]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END  
				,[acCurrencyptr],[acCurrencyVal] '      
		------------------------------------------------------------------------------------------------------- 
		-- Checked if there are Custom Fields to View  	 
		------------------------------------------------------------------------------------------------------- 
		
		SET @Sql = @Sql + 
		' ORDER BY      
				CASE  ' + CAST(@SortCollectBy AS VARCHAR(10)) + '  
					WHEN 0 THEN [Acc].[acName]      
					WHEN 1 THEN [cuCustomerName]    
					WHEN 2 THEN [cuAddress]    
					WHEN 3 THEN [cuNationality]    
					WHEN 4 THEN [cuPhone1]    
					WHEN 5 THEN [cuPhone2]    
					WHEN 6 THEN [cuFax]    
					WHEN 7 THEN [cuTelex]    
					WHEN 8 THEN [cuNotes]    
					WHEN 9 THEN CAST( [Cu].[cuDiscRatio] AS [VARCHAR](100)) 
					WHEN 10 THEN [Acc].[acCode] 
					WHEN 11 THEN [cuCountry] 
					WHEN 12 THEN [cuCity] 
					WHEN 13 THEN [cuArea] 
					WHEN 14 THEN [cuStreet] 
					ELSE ''''	END '   
		EXEC(@Sql)  
			     
		END      
		ELSE      
		BEGIN      
			SELECT      
				ISNULL ( CASE @SortCollectBy      
					WHEN 0 THEN [Acc].[acName]      
					WHEN 1 THEN [cuCustomerName]      
					WHEN 2 THEN [cuAddress]      
					WHEN 3 THEN [cuNationality]      
					WHEN 4 THEN [cuPhone1]     
					WHEN 5 THEN [cuPhone2]      
					WHEN 6 THEN [cuFax]      
					WHEN 7 THEN [cuTelex]      
					WHEN 8 THEN [cuNotes]      
					WHEN 9 THEN CAST ( ISNULL( [Cu].[cuDiscRatio], 0) AS [VARCHAR](40))      
					WHEN 10 THEN [Acc].[acCode] 
					WHEN 11 THEN [cuCountry] 
					WHEN 12 THEN [cuCity] 
					WHEN 13 THEN [cuArea] 
					WHEN 14 THEN [cuStreet] 
					ELSE ''	END , '')AS [CustStr],    
				CASE WHEN @SortCollectBy = 0 THEN [Res].[Path] ELSE '' END AS [Path],     
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuGUID], 0x0) ELSE 0x0 END AS [CustPtr],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN CAST ( ISNULL( [cuNumber],0) AS [VARCHAR](40)) ELSE '' END AS [CustNum],      
		  		CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [cuCustomerName], '') ELSE '' END AS [CustName],      
		  		CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [cuLatinName], '') ELSE '' END AS [CustLatinName],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuNationality], '') ELSE '' END AS [CustNationality],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuAddress],'') ELSE '' END AS [CustAddress],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuPhone1],'') ELSE '' END AS [CustPhone1],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuPhone2],'') ELSE '' END AS [CustPhone2],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuFax], '') ELSE '' END AS [CustFax],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuTelex],'') ELSE '' END AS [CustTelex],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuNotes], '') ELSE '' END AS [CustNotes],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN CAST ( ISNULL( [Cu].[cuDiscRatio], 0) AS [VARCHAR](40))  ELSE '' END AS [CustDiscRatio],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPrefix], '') ELSE '' END AS [CustPrefix],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuSuffix], '') ELSE '' END AS [CustSuffix],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuMobile], '') ELSE '' END AS [CustMobile],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPager], '') ELSE '' END AS [CustPager],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuEmail], '') ELSE '' END AS [CustEmail],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuHomePage], '') ELSE '' END AS [CustHomePage],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCountry], '') ELSE '' END AS [CustCountry],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCity], '') ELSE '' END AS [CustCity],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuArea], '') ELSE '' END AS [CustArea],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuStreet], '') ELSE '' END AS [CustStreet],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuZipCode], '') ELSE '' END AS [CustZipCode],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPOBox], '') ELSE '' END AS [CustPOBox],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCertificate], '') ELSE '' END AS [CustCertificate],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuJob], '') ELSE '' END AS [CustJob],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuJobCategory], '') ELSE '' END AS [CustJobCategory],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld1], '') ELSE '' END AS [CustUserFld1],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld2], '') ELSE '' END AS [CustUserFld2],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld3], '') ELSE '' END AS [CustUserFld3],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld4], '') ELSE '' END AS [CustUserFld4],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuDateOfBirth], '') ELSE '' END AS [CustDateOfBirth],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuGender], '') ELSE '' END AS [CustGender],    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuHobbies], '') ELSE '' END AS [CustHobbies],    
				CASE WHEN @SortCollectBy = 0 THEN [Res].[AccPtr] WHEN   @SortCollectBy = 1 THEN [cuAccount] ELSE NULL END AS [AccPtr],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCode] ELSE '' END AS [AccCode],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acName] ELSE '' END AS [AccName],      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acLatinName] ELSE '' END AS [AccLatinName],
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN  [Acc].[acDebit]   ELSE 0 END AS [acDebit], 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN  [Acc].[acCredit]   ELSE 0 END AS [acCredit], 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCurrencyptr] ELSE 0x00 END AS [acCurrencyptr], 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCurrencyVal]  ELSE 1 END AS [acCurrencyVal] , 
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END BillType,
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END LatinBillType,
				SUM( CASE WHEN [Type] = 0 THEN [CountMove] ELSE 0 END) [CountMove],      
				SUM(TotalCount) TotalCount,
				SUM( CASE WHEN [Type] = 0 THEN [Val] ELSE 0 END) AS [Val],
				SUM(TotalVal) TotalVal,
				@FullResult [FullResult]
			FROM       
				#ResultTbl AS [Res]       
				INNER JOIN [#Account_Tbl] AS [acTbl] ON [Res].[AccPtr] = [acTbl].[GUID]	      
				INNER JOIN [vwAc] AS [Acc] ON [Res].[AccPtr] = [Acc].[acGuid]      
				INNER JOIN [vwBt] AS [BT] ON [Res].[BillType] = [BT].[btGUID]      
				LEFT JOIN [vwCu] AS [cu] ON [Cu].[cuAccount] = [Acc].[acGuid]      
			WHERE       
				( @AccountLevel = 0 OR [acTbl].[Level] < @AccountLevel)      
				AND    
				CASE @SortCollectBy      
					WHEN 0 THEN [Acc].[acName]      
					WHEN 1 THEN [cuCustomerName]      
					WHEN 2 THEN [cuAddress]      
					WHEN 3 THEN [cuNationality]      
					WHEN 4 THEN [cuPhone1]      
					WHEN 5 THEN [cuPhone2]      
					WHEN 6 THEN [cuFax]      
					WHEN 7 THEN [cuTelex]      
					WHEN 8 THEN [cuNotes]      
					WHEN 9 THEN CAST ( ISNULL( [Cu].[cuDiscRatio], 0) AS [VARCHAR](40))    
					WHEN 10 THEN [Acc].[acCode] 
					WHEN 11 THEN [cuCountry] 
					WHEN 12 THEN [cuCity] 
					WHEN 13 THEN [cuArea] 
					WHEN 14 THEN [cuStreet] 
					ELSE ''	END IS NOT NULL    
			GROUP BY      
				ISNULL ( CASE @SortCollectBy      
					WHEN 0 THEN [Acc].[acName]      
					WHEN 1 THEN [cuCustomerName]      
					WHEN 2 THEN [cuAddress]      
					WHEN 3 THEN [cuNationality]      
					WHEN 4 THEN [cuPhone1]      
					WHEN 5 THEN [cuPhone2]      
					WHEN 6 THEN [cuFax]      
					WHEN 7 THEN [cuTelex]      
					WHEN 8 THEN [cuNotes]      
					WHEN 9 THEN CAST ( ISNULL( [Cu].[cuDiscRatio], 0) AS [VARCHAR](40))   
					WHEN 10 THEN [Acc].[acCode] 
					WHEN 11 THEN [cuCountry] 
					WHEN 12 THEN [cuCity] 
					WHEN 13 THEN [cuArea] 
					WHEN 14 THEN [cuStreet] 
					ELSE ''	END , ''),				CASE WHEN @SortCollectBy = 0 THEN [Res].[Path] ELSE '' END,     
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [cuGUID], 0x0) ELSE 0x0 END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN CAST ( ISNULL( [cuNumber],0) AS [VARCHAR](40)) ELSE '' END,      
		  		CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuCustomerName],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [cuLatinName], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuNationality],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuAddress],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuPhone1],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuPhone2],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuFax], '') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuTelex],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL( [Cu].[cuNotes],'') ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN CAST ( ISNULL( [Cu].[cuDiscRatio], 0) AS [VARCHAR](40))  ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 THEN [Res].[AccPtr] WHEN    @SortCollectBy = 1 THEN [Cu].[cuAccount] ELSE NULL END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCode] ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acName] ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acLatinName] ELSE '' END,      
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPrefix], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuSuffix], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuMobile], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPager], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuEmail], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuHomePage], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCountry], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCity], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuArea], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuStreet], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuZipCode], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuPOBox], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuCertificate], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuJob], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuJobCategory], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld1], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld2], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld3], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuUserFld4], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuDateOfBirth], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuGender], '') ELSE '' END,    
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN ISNULL ( [Cu].[cuHobbies], '') ELSE '' END,    
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BillType]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,  
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,
				CASE @CollectByBillType       
					WHEN 0 THEN CAST( [BT].[btLatinName]  AS [VARCHAR](40))      
					ELSE CAST( [BT].[btBillType] AS [VARCHAR](40)) END,
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN  [Acc].[acDebit] ELSE 0 END , 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN  [Acc].[acCredit]  ELSE 0 END, 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCurrencyptr] ELSE 0x00 END , 
				CASE WHEN @SortCollectBy = 0 OR  @SortCollectBy = 1 THEN [acCurrencyVal]  ELSE 1 END  
		ORDER BY     
				CASE WHEN @SortCollectBy = 0 THEN [Res].[Path] ELSE '' END     
		END      
			      
	END      
	DELETE [Connections] WHERE SPID = @@SPID
#########################################################
CREATE PROCEDURE ARWA.repCurrencyGeneralLedger
	@StartDate					[DATETIME] ='1-1-2000',				-- „‰  «—ÌŒ
	@EndDate					[DATETIME] ='1-12-2011',				-- ≈·Ï  «—ÌŒ
	@AccountGUID				[UNIQUEIDENTIFIER]='00000000-0000-0000-0000-000000000000',		-- «·Õ”«»
	@Currency1GUID				[UNIQUEIDENTIFIER] ='1471BBC3-7557-4DD1-A955-7577F30A1B9F',		-- «·⁄„·… «·√Ê·Ï
	@Currency2GUID				[UNIQUEIDENTIFIER]='00000000-0000-0000-0000-000000000000',		-- «·⁄„·… «·À«‰Ì…
	@Class						[VARCHAR](256)='',			-- ≈ŸÂ«— «·›∆…
	@ShowPosted 				[INT]=1,					-- ≈ŸÂ«— «·”‰œ«  «·„—Õ·…
	@ShowUnposted 				[INT]=0,					-- ≈ŸÂ«— «·”‰œ«  €Ì— «·„—Õ·…
	@ShowAllCurrencies			[BIT]=0,					-- ŒÌ«— ≈ŸÂ«— Ã„Ì⁄ «·⁄„·« 
	@ShowTwoCurrencies			[BIT]=0,					-- ŒÌ«— ≈ŸÂ«— «·⁄„· Ì‰
														-- 0 Show one currency
														-- 1 Show tow currency
	@ValueByTwoCurrencies		[BIT]=0,					-- ŒÌ«— ≈ŸÂ«— «·ﬁÌ„ »ﬂ·« «·⁄„· Ì‰
														-- 0 calc value by just one currency, its currency.
														-- 1 calc value by currency and second 
	@GroupAccountSameEntry		[INT]=0,					--  Ã„Ì⁄ «·Õ”«»«  ÷„‰ –«  «·”‰œ
	@FilterUserGUID				[UNIQUEIDENTIFIER] = 0X00,	-- Filter Result By @User
	@ShowInLocalCurrency		[BIT] = 0,					-- ≈ŸÂ«— «·⁄„·… «·„Õ·Ì…
	@JobCostGUID				[UNIQUEIDENTIFIER] = 0X00,	-- „—ﬂ“ «·ﬂ·›…
	@PreviousBalance			BIT = 0,					-- «·—’Ìœ «·”«»ﬁ
	@User						[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	-- Guid Of Logining User
	@Lang						VARCHAR(100) = 'ar',		
	@BranchMask					BIGINT = 9223372036854775807,-- Mask for current branches
	@ShowEntryNumber			[BIT] = 0,                  -- Show Entry Number
	@ShowOrginalCentry			[BIT] = 0,					-- ≈ŸÂ«— √’· «·”‰œ 
	@ShowClass					[BIT] = 0,					--≈ŸÂ«— «·›∆… 
	@AccountDescription			VARCHAR(MAX) = '',			-- Ê’› «·Õ”«»	
	@Currency1Description		VARCHAR(MAX) = '',			-- Ê’› «·⁄„·… «·√Ê·Ï				
	@Currency2Description		VARCHAR(MAX) = '',			-- Ê’› «·⁄„·… «·À«‰Ì…	
	@JobCostDescription			VARCHAR(MAX) = '',			-- Ê’› „—ﬂ“ «·ﬂ·›…		
	@FilterUserDescription      VARCHAR(MAX) = ''
AS   
	SET NOCOUNT ON
	--- 1 posted, 0 unposted -1 both       
	DECLARE @PostedType [INT],
			@LocalCurrencyName	VARCHAR(250),
			@LocalCurrencyCode	VARCHAR(200)
	
	SELECT 
			@LocalCurrencyName = CASE @Lang WHEN 'ar' THEN [Name] 
									ELSE 
									CASE [LatinName] WHEN '' THEN [LatinName] ELSE [Name] END
								END,	
			@LocalCurrencyCode = [Code]
	FROM My000 WHERE NUMBER = 1
						      
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 0))		         
		SET @PostedType = 1      
	IF( (@ShowPosted = 0) AND (@ShowUnposted = 1))         
		SET @PostedType = 0      
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 1))         
		SET @PostedType = -1      
	
	IF (@ShowAllCurrencies = 1)
	BEGIN
		SET @Currency1GUID = 0X0
		SET @Currency2GUID = 0X0
	END
	
	IF (@ShowTwoCurrencies = 0)
		SET @Currency2GUID = 0X0

	--DECLARE @UserSec [INT] 
	--SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@User, DEFAULT)
	
	EXEC [prcSetSessionConnections] @User, @BranchMask
	-- Accounts Table ---------------------------------------------------------------
	CREATE TABLE [#AccountsList]
	(
		[GUID]		[UNIQUEIDENTIFIER],
		[Security]	[INT],
		[level]		[INT]
	)
	
	DECLARE @StDate DATETIME
	IF @PreviousBalance = 0
		SET @StDate = @StartDate
	ELSE
		SET @StDate = '1/1/1980'
	
	CREATE TABLE [#CostTbl]	 ( [Cost] [UNIQUEIDENTIFIER], [CostSec] [INT])
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	IF @JobCostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	
	INSERT INTO [#AccountsList] EXEC [prcGetAccountsList] @AccountGUID,0
	CREATE CLUSTERED INDEX [accInd] ON [#AccountsList]([GUID])
	
	CREATE TABLE [#Result]
	(
		[enDate]			[DATETIME],   
		[CeGUID]			[UNIQUEIDENTIFIER],
		[CeNumber]			[INT],

		[Cur1Debit]			[FLOAT],
		[Cur1Credit]		[FLOAT],
		[Cur2Debit]			[FLOAT],
		[Cur2Credit]		[FLOAT],
		[enCurPtr]			[UNIQUEIDENTIFIER],
		[enNotes]			[VARCHAR](256) COLLATE ARABIC_CI_AI,		   
		[enNumber]			[INT],
		[AccName]			[VARCHAR](500) COLLATE ARABIC_CI_AI,		 
		[AccLatinName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,
		[AccGUID]			[UNIQUEIDENTIFIER],
		[ParentGUID] 		[UNIQUEIDENTIFIER],
		[ParentType]		[INT]	DEFAULT 0,
		[ParentNumber]		[INT]	DEFAULT 0,
		[ParentName]		[VARCHAR](250) COLLATE ARABIC_CI_AI	DEFAULT '', 
		[CostGuid]			[UNIQUEIDENTIFIER],
		[CurrGuid]			[UNIQUEIDENTIFIER],
		[Debit]				[FLOAT],
		[Credit]			[FLOAT],
		[Class]				[VARCHAR](256) COLLATE ARABIC_CI_AI,
		CurrName			[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		CurrLatinName		[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		CurrCode			[VARCHAR](100) COLLATE ARABIC_CI_AI DEFAULT '',
		Curr2Name			[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		Curr2LatinName		[VARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		--[UserSecurity] 		[INT],  -- for prcCheckSecurity, prcCheckSecurity_userSec
		[AccSecurity] 		[INT],	-- for prcCheckSecurity, prcCheckSecurity_browesSec
		[ceSecurity]		[INT],  
		[coSecurity]		[INT],

	)   
	DECLARE @MyCurVal1 AS [FLOAT]
	DECLARE @MyCurVal2 AS [FLOAT]

	--  ﬁÌÌ„ «·Õ—ﬂ«  »”⁄— «· ⁄«œ· «·„⁄—› ›Ì ÃœÊ· «·⁄„·« 
	SELECT @MyCurVal1 = [MyCurrencyVal] FROM [vwMy] WHERE [MyGUID] = @Currency1GUID
	SELECT @MyCurVal2 = [MyCurrencyVal] FROM [vwMy] WHERE [MyGUID] = @Currency2GUID
		
	INSERT INTO [#Result]([enDate],	[CeGUID], [CeNumber],  [Cur1Debit], [Cur1Credit],	
							[Cur2Debit], [Cur2Credit], [enCurPtr], [enNotes], [enNumber],
							[AccName],[AccLatinName], [AccGUID], [ParentGUID],[ParentType], 
							[CostGuid], [CurrGuid], [Debit], [Credit], [Class],
							CurrName, CurrLatinName, CurrCode, Curr2Name, Curr2LatinName,
							 [AccSecurity], [ceSecurity], [coSecurity])
	SELECT 
			[en].[enDate],   
			[en].[CeGUID],
			[en].[CeNumber],  
			
			--	Debit1
			CASE 
				WHEN [en].[EnCurrencyPtr] = @Currency1GUID OR  @Currency1GUID = 0X00 THEN 
								ISNULL([en].[enDebit] / [ARWA].[fnIszero]([en].[enCurrencyVal], 1), 0)
														--(CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END),0)
				ELSE
					CASE @ValueByTwoCurrencies 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enDebit] / [ARWA].[fnIszero](@MyCurVal1, 1), 0)
										--(CASE @MyCurVal1 WHEN 0 THEN 1 ELSE @MyCurVal1 END), 0)
					END
			END,
			--	Credit1
			CASE  
				WHEN [en].[EnCurrencyPtr] = @Currency1GUID OR @Currency1GUID = 0X00 THEN 
						ISNULL([en].[enCredit] / [ARWA].[fnIszero]([en].[enCurrencyVal], 1), 0)
											-- (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) ,0)
				ELSE
					CASE @ValueByTwoCurrencies 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enCredit] / [ARWA].[fnIszero](@MyCurVal1, 1), 0)
							--(CASE @MyCurVal1 WHEN 0 THEN 1 ELSE @MyCurVal1 END), 0)
					END
			END,
			--	Debit2
			CASE [en].[EnCurrencyPtr]
				WHEN @Currency2GUID THEN ISNULL([en].[enDebit] / [ARWA].[fnIszero]([en].[enCurrencyVal], 1), 0)
						-- (CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END) ,0)
				ELSE
					CASE @ValueByTwoCurrencies 
						WHEN 0 THEN	0
						ELSE ISNULL([en].[enDebit] / [ARWA].[fnIszero](@MyCurVal2, 1), 0)
							--1(CASE @MyCurVal2 WHEN 0 THEN 1 ELSE @MyCurVal2 END),0)
					END
			END,
			--	Credit2
			CASE [en].[EnCurrencyPtr] 
				WHEN @Currency2GUID THEN ISNULL([en].[enCredit] / [ARWA].[fnIszero]([en].[enCurrencyVal], 1), 0)
						--(CASE [en].[enCurrencyVal] WHEN 0 THEN 1 ELSE [en].[enCurrencyVal] END), 0)
			ELSE
				CASE @ValueByTwoCurrencies 
					WHEN 0 THEN	0
					ELSE ISNULL([en].[enCredit] / [ARWA].[fnIszero](@MyCurVal2, 1), 0)
					-- (CASE @MyCurVal2 WHEN 0 THEN 1 ELSE @MyCurVal2 END), 0)
				END
			END,
			[en].[EnCurrencyPtr],
			[enNotes],
			[enNumber],
			[en].[acCode] + '-' +[en].[acName],  
			[en].[acCode] + '-' +[en].[acLatinName], 
			[en].[acGUID],
			ISNULL(er.[ParentGUID], 0X0),
			ISNULL(er.[ParentType], 0),
			[co].[Cost],
			CASE @Currency1GUID WHEN 0X00 THEN [en].[EnCurrencyPtr] ELSE 0X00 END,
			[en].[enDebit],
			[en].[enCredit],
			[enClass],
			my1.Name,
			my1.LatinName,
			my1.Code,
			my2.Name,
			my2.LatinName,
			[ac].[Security],
			[en].[ceSecurity],
			[co].CostSec
		FROM
		-- „‰ «Ã· ‰Ê⁄ «·”‰œ
			[fnExtended_En_Fixed]( @Currency1GUID) AS [En] 
			INNER JOIN [#AccountsList] AS [ac] ON [acGUID] = [ac].[GUID]
			INNER JOIN [#CostTbl] [co] ON [enCostPoint] = [Cost]
			INNER JOIN my000 AS my1 ON my1.[GUID] = [en].[EnCurrencyPtr] 
			LEFT JOIN my000 AS my2 ON my2.GUID = @Currency2GUID
			LEFT JOIN  er000 [er] ON er.[EntryGuid] = [en].[ceGuid]
			
		WHERE   
			[endate] BETWEEN @StDate AND @EndDate
			AND (((@Currency1GUID = 0x00) OR ([EnCurrencyPtr] = @Currency1GUID) OR ([EnCurrencyPtr] = @Currency2GUID)))  -- Ì⁄—÷ ⁄„· Ì‰  
			AND (@Class = '' OR [enClass] = @Class)			 		
			AND (@PostedType = -1 OR @PostedType = [ceIsPosted]) -- ≈ŸÂ«— «·”‰œ«  «·€Ì— „—Õ·…  
			AND (@FilterUserGUID  = 0X00 OR ISNULL([ParentGuid], [ceGuid]) IN (SELECT [RecGUID] FROM [lg000] WHERE [UserGuid] = @FilterUserGUID))	
	
	-- Security Table --
	CREATE TABLE [#SecViol]
	(   
		[Type] 	[INT],   
		[Cnt] 	[INT]   
	)   

	EXEC [prcCheckSecurity] @User 
	
	DECLARE @NumOfSecViolated BIT
	SET  @NumOfSecViolated = 0
	IF EXISTS(SELECT * FROM #secviol)
		SET @NumOfSecViolated = 1

	IF( @ShowOrginalCentry = 1) 
	BEGIN   
			UPDATE [#Result] SET   
				[ParentGUID] = [er].[erParentGuid],    
				[ParentType] = [er].[erParentType],    
				[ParentNumber] = [er].[erParentNumber]  
			FROM  
				[#Result] AS [Res]   
				INNER JOIN [vwEr] AS [er]   
				ON [Res].[ceGuid] = [er].[erEntryGuid]    
			IF( @ShowOrginalCentry = 1) 
			BEGIN 
			------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [bt].[btAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwBt] AS [bt]   
				ON [Res].[ParentGuid] = [bt].[btGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET   
				[ParentName] = [et].[etAbbrev]  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwEt] AS [et]   
				ON [Res].[ParentGuid] = [et].[etGuid]  
			-------------------------------------------  
			UPDATE [#Result] SET  
				[ParentName] = ISNULL( CASE [nt].[ntAbbrev] WHEN '' THEN [nt].[ntName] ELSE [nt].[ntAbbrev] END, '')  
			FROM   
				[#Result] AS [Res] INNER JOIN [vwNt] AS [nt]  
				ON [Res].[ParentGuid] = [nt].[ntGuid]  
			-------------------------------------------  
			
			UPDATE [#Result] SET   
				[ParentName] = [et].[Abbrev]  
			FROM  
				TrnExchange000 as ex   
				INNER JOIN TrnExchangeTypes000 AS [et]  
					ON [ex].[TypeGuid] = [et].[Guid]  
			WHERE ParentType = 507  
			END 
			
	END 

	IF (@PreviousBalance > 0)
	BEGIN
		INSERT INTO [#Result]([enDate],[CeGUID],[CeNumber],[Cur1Debit],[Cur1Credit],[Cur2Debit],[Cur2Credit],[enCurPtr],		
		[enNotes],[enNumber],[AccName],[AccLatinName],[AccGUID],[ParentGUID],[ParentType],	
		[CurrGuid],[Debit],[Credit])
		SELECT '1/1/1980',0X00,0,SUM([Cur1Debit]),SUM([Cur1Credit]),SUM([Cur2Debit]),SUM([Cur2Credit]),[enCurPtr],		
			'',0,'','',0x00,0x00,0,	
			[CurrGuid],SUM([Debit]),SUM([Credit])
		FROM #RESULT WHERE [enDate] < @StartDate
		GROUP BY
			[enCurPtr],[CurrGuid]
		DELETE #RESULT WHERE [enDate] < @StartDate AND [enDate] > '1/1/1980'			
	END
	
	IF( @GroupAccountSameEntry = 1)
	BEGIN
		SELECT 
			[enDate],   
			[CeGUID],
			[CeNumber],
			ISNULL(SUM([Cur1Debit]), 0) AS [Cur1Debit],
			ISNULL(SUM([Cur1Credit]), 0) AS [Cur1Credit],
			ISNULL(SUM([Cur2Debit]), 0) AS [Cur2Debit],
			ISNULL(SUM([Cur2Credit]), 0) AS [Cur2Credit],
			[enCurPtr],
			CASE COUNT(*)
				WHEN 1 THEN (SELECT TOP 1 [enNotes] FROM [vwEn] AS [en] WHERE [enParent] = [CeGUID] AND [enAccount] = [AccGUID] AND [en].[enCurrencyptr] = [r].[enCurPtr] ) 
				ELSE '⁄œ… »‰Êœ'
			END AS [enNotes],	
			[AccName],		 
			[AccLatinName],	
			[AccGUID],
			[ParentGUID],
			[ParentType],
			[ParentName],
			[CurrGuid],
			@NumOfSecViolated  AS NumOfSecViolated,
			@LocalCurrencyName AS LocalCurrencyName,
			@LocalCurrencyCode AS LocalCurrencyCode
		FROM   
			[#Result] AS [r]
		GROUP BY 
			[enDate],   
			[CeGUID],
			[CeNumber],
			[enCurPtr],
			[AccName],	
			[AccLatinName],	 
			[AccGUID],
			[ParentGUID],
			[ParentType],[ParentName],[CurrGuid]
		ORDER BY  
			[CurrGuid],[enDate], [ParentType], [CeNumber]
	END
	ELSE
	BEGIN
		SELECT 
				*, 
				@NumOfSecViolated  AS NumOfSecViolated,
				@LocalCurrencyName AS LocalCurrencyName,
				@LocalCurrencyCode AS LocalCurrencyCode

		FROM   
			[#Result]
		ORDER BY  
			[CurrGuid],[enDate], [ParentType], [CeNumber], [enNumber]
	END
#########################################################
CREATE PROCEDURE ARWA.repCostGL
	@AccountGUID					UNIQUEIDENTIFIER,
	@AccountDescription				VARCHAR(250),
	@JobCostGUID					UNIQUEIDENTIFIER,
	@JobCostDescription				VARCHAR(250),
	@Class							VARCHAR(256),
	@StartDate						DATETIME,
	@EndDate						DATETIME,
	@CurrencyGUID					UNIQUEIDENTIFIER,
	@CurrencyDescription			VARCHAR(256),
	@HideDetails					BIT,	-- 0: With Details, 1: Without
	@EntryUserGUID					UNIQUEIDENTIFIER = 0x0,
	@ShowPreviousBalance			BIT = 0,
	@ShowPosted						BIT = 1,
	@ShowUnposted					BIT = 1,
	@ShowEveryJobCostInSeperatePage	BIT = 0, --ﬂ· „—ﬂ“ ﬂ·›… ⁄·Ï Ê—ﬁ…
	@ShowNotes						BIT = 0,
	@Lang							VARCHAR(100) = 'ar',
	@UserGUID						UNIQUEIDENTIFIER = 0x0,
	@BranchMask						BIGINT = 0
AS
	--  ﬁ—Ì— œ› — «” «– „—ﬂ“ ﬂ·›…
	SET NOCOUNT ON 

	EXEC [prcInitialize_Environment] @UserGUID, 'repCostGL', @BranchMask
	
	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT)
	
	DECLARE @UserEnSec INT = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)
	
	CREATE TABLE [#AccTbl](
		[GUID]		UNIQUEIDENTIFIER,
		[Security]	INT,
		Lvl			INT) 
			
	CREATE TABLE [#CostTbl](
		[GUID]		UNIQUEIDENTIFIER,
		[Security]	INT) 
			
	CREATE TABLE [#Result]( 
		JobCostGUID		UNIQUEIDENTIFIER, 
		CostSecurity	INT,
		AccountGUID		UNIQUEIDENTIFIER, 
		AccountSecurity	INT,
		ceGuid 			UNIQUEIDENTIFIER, 
		ceNumber 		INT, 
		[Date]			DATETIME, 
		Debit			FLOAT, 
		Credit			FLOAT, 
		Notes			VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Security]		INT, 
		UserSecurity	INT, 
		[PrevDebit]		FLOAT DEFAULT 0,
		[PrevCredit]	FLOAT DEFAULT 0)
			
	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] @AccountGUID
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	IF @JobCostGUID = 0x0
		INSERT INTO [#CostTbl] VALUES (0x0, 0)

	INSERT INTO [#Result]
	SELECT     
		ce.enCostPoint,
		co.[Security],
		ce.enAccount,
		ac.[Security],
		ce.ceGuid,
		ce.ceNumber,
		ce.enDate,
		(CASE
			WHEN ce.enDate < @StartDate THEN 0
			ELSE ce.FixedEnDebit
		END),
		(CASE
			WHEN ce.enDate < @StartDate THEN 0
			ELSE ce.FixedEnCredit
		END),
		ce.enNotes,
		ce.[ceSecurity],
		@UserEnSec,
		(CASE
			WHEN ce.enDate < @StartDate THEN ce.FixedEnDebit
			ELSE 0
		END),
		(CASE 
			WHEN ce.enDate < @StartDate THEN ce.FixedEnCredit
			ELSE 0
		END)
	FROM     
		[dbo].[fnExtended_En_Fixed](@CurrencyGUID) As [Ce]
		INNER JOIN [#AccTbl] AS [Ac] ON [ce].[enAccount] = [Ac].[GUID]
		INNER JOIN [#CostTbl] AS [Co] On [ce].[enCostPoint] = [Co].[GUID]
	WHERE    
		(@Class = '' OR @Class = [enClass])
		AND (([enDate] BETWEEN @StartDate AND @EndDate) OR ((@ShowPreviousBalance = 1) AND ([enDate] < @StartDate)))
		AND (@EntryUserGUID = 0x0 OR 
			[Ce].[ceGuid] IN (
				SELECT 
					[EntryGuid] 
				FROM 
					[ER000] AS [er]
					INNER JOIN [LG000] AS [Lg] ON [Lg].[RecGuid] = [er].[ParentGuid]
				WHERE 
					[lg].[USerGuid] = @EntryUserGUID
				UNION ALL 
				SELECT 
					[RecGuid]
				FROM 
					[LG000]
				WHERE 
					[USerGuid] = @EntryUserGUID 
					AND [RecGuid] <> 0X00))
		AND ((@ShowPosted = 1 AND ceIsPosted = 1) OR (@ShowUnposted = 1 AND ceIsPosted = 0))
	 
	EXEC [prcCheckSecurity] @UserGUID = @UserGUID
	
	DECLARE @NumOfSecViolated BIT
	SET @NumOfSecViolated = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1

	CREATE TABLE [#EndResult]( 
		JobCostGUID			UNIQUEIDENTIFIER,
		CostCode			VARCHAR(255) COLLATE ARABIC_CI_AI,
		CostName			VARCHAR(255) COLLATE ARABIC_CI_AI,
		AccountGUID			UNIQUEIDENTIFIER,
		AccountCode			VARCHAR(255) COLLATE ARABIC_CI_AI,
		AccountName			VARCHAR(255) COLLATE ARABIC_CI_AI,
		ceGuid 				UNIQUEIDENTIFIER,
		ceNumber 			INT, 
		[Date]				DATETIME, 
		Debit				FLOAT, 
		Credit				FLOAT, 
		Notes				VARCHAR(255) COLLATE ARABIC_CI_AI, 
		[PrevDebit]			FLOAT DEFAULT 0,
		[PrevCredit]		FLOAT DEFAULT 0,
		NumOfSecViolated	INT)

	--IF @HideDetails = 0
	--BEGIN
		INSERT INTO [#EndResult]
		SELECT
			JobCostGUID,
			co.Code,
			CASE @Lang
				WHEN 'ar' THEN co.Name
				ELSE CASE co.LatinName
						WHEN '' THEN co.Name
						ELSE co.LatinName
					END
			END, 
			AccountGUID,
			ac.Code,
			CASE @Lang
				WHEN 'ar' THEN ac.Name
				ELSE CASE ac.LatinName
						WHEN '' THEN ac.Name
						ELSE ac.LatinName
					END
			END,
			ceGuid,
			ceNumber,
			res.[Date],
			res.[Debit],
			res.[Credit],
			res.[Notes],
			[PrevDebit],
			[PrevCredit],
			@NumOfSecViolated
		FROM
			#Result [res]
			INNER JOIN ac000 ac ON ac.[GUID] = res.AccountGUID
			INNER JOIN (SELECT [GUID], Code, Name, LatinName FROM co000 UNION ALL SELECT 0x0, '', '', '') co ON co.[GUID] = res.JobCostGUID
	--END ELSE BEGIN
	--	SELECT
	--		(CASE @JobCostGUID
	--			WHEN 0x0 THEN 0x0
	--			ELSE JobCostGUID
	--		END) AS JobCostGUID,
	--		(CASE @AccountGUID 
	--			WHEN 0x0 THEN 0x0
	--			ELSE AccountGUID
	--		END) AS AccountGUID,
	--		SUM(Debit) AS Debit,
	--		SUM(Credit) AS Credit
	--	INTO 
	--		#Balances
	--	FROM
	--		#Result
	--	GROUP BY
	--		(CASE @JobCostGUID 
	--			WHEN 0x0 THEN 0x0
	--			ELSE JobCostGUID 
	--		END),
	--		(CASE @AccountGUID 
	--			WHEN 0x0 THEN 0x0
	--			ELSE AccountGUID 
	--		END)
			
	--	INSERT INTO [#EndResult](
	--		JobCostGUID,
	--		CostCode,
	--		CostName,
	--		AccountGUID,
	--		AccountCode,
	--		AccountName,
	--		Debit,
	--		Credit, 
	--		NumOfSecViolated)
	--	SELECT
	--		co.GUID,
	--		co.Code,
	--		CASE @Lang
	--			WHEN 'ar' THEN co.Name
	--			ELSE CASE co.LatinName
	--					WHEN '' THEN co.Name
	--					ELSE co.LatinName
	--				END
	--		END,
	--		ac.[GUID],
	--		ac.Code,
	--		CASE @Lang
	--			WHEN 'ar' THEN ac.Name
	--			ELSE CASE ac.LatinName
	--					WHEN '' THEN ac.Name
	--					ELSE ac.LatinName
	--				END
	--		END,
	--		bal.Debit,
	--		bal.Credit,
	--		@NumOfSecViolated
	--	FROM 
	--		[#Balances] [bal]
	--		INNER JOIN (SELECT [GUID], Code, Name, LatinName FROM co000 UNION ALL SELECT 0x0, '', '', '') co ON co.[GUID] = bal.JobCostGUID
	--		INNER JOIN (SELECT [GUID], Code, Name, LatinName FROM ac000 UNION ALL SELECT 0x0, '', '', '') ac ON ac.[GUID] = bal.AccountGUID
	--END
	
	SELECT * FROM [#EndResult]
	
	EXEC [prcFinilize_Environment] 'repCostGL'
	
/*
	
ALTER PROCEDURE ARWA.repCostGL
	@AccountGUID					UNIQUEIDENTIFIER,
	@AccountDescription				VARCHAR(250),
	@JobCostGUID					UNIQUEIDENTIFIER,
	@JobCostDescription				VARCHAR(250),
	@Class							VARCHAR(256),
	@StartDate						DATETIME,
	@EndDate						DATETIME,
	@CurrencyGUID					UNIQUEIDENTIFIER,
	@CurrencyDescription			VARCHAR(256),
	@HideDetails					BIT,	-- 0: With Details, 1: Without
	@EntryUserGUID					UNIQUEIDENTIFIER = 0x0,
	@ShowPreviousBalance			BIT = 0,
	@ShowPosted						BIT = 1,
	@ShowUnposted					BIT = 1,
	@ShowEveryJobCostInSeperatePage	BIT = 0, --ﬂ· „—ﬂ“ ﬂ·›… ⁄·Ï Ê—ﬁ…
	@ShowNotes						BIT = 0,
	@Lang							VARCHAR(100) = 'ar',
	@UserGUID						UNIQUEIDENTIFIER = 0x0,
	@BranchMask						BIGINT = 0
AS
	SET NOCOUNT ON 
	
	SELECT 
		0x0 as JobCostGUID	,
		'' as CostCode,
		'' as CostName,
		0x0 as AccountGUID		,
		'' as AccountCode			,
		'' as AccountName			,
		0x0 as ceGuid 			,
		0 as ceNumber 		, 
		getdate() as [Date]				, 
		0.0 as Debit				, 
		0.0 as Credit		, 
		'' as Notes	, 
		0.0 as [PrevDebit],
		0.0 as [PrevCredit],
		0 as NumOfSecViolated
		
	*/
#########################################################
CREATE PROCEDURE ARWA.repCostBalance
	@JobCostGUID 				[UNIQUEIDENTIFIER], 
	@AccountGUID 				[UNIQUEIDENTIFIER], 
	@StartDate				[DATETIME], 
	@EndDate				[DATETIME], 
	@PostedValue 				[INT] = -1 ,				-- 1 posted or 0 unposted -1 all posted & unposted 
	@CurrencyGUID				[UNIQUEIDENTIFIER], 
	@ShowBalancedJobCost		[INT] =0, 
	@ShowEmptyJobCost			[INT] =0, 
	-----------------Report Sources-----------------------
	@SourcesTypes			VARCHAR(MAX),
	------------------------------------------------------
	@UserGUID				[UNIQUEIDENTIFIER],			--Logining user
	--Show Options
	@ShowBalanceRatio		[BIT] = 0,					--≈ŸÂ«— ‰”»… «·—’Ìœ
	@ShowCurrentTotals		[BIT] = 1,					--«·„Ã«„Ì⁄ »«·‰”»… ··—’Ìœ «·Õ«·Ì
	@ShowCurrentBal			[BIT] = 0,					--«·«—’œ… »«·‰”»… ··—’Ìœ «·Õ«·Ì
	@ShowCurrentBalOfBal	[BIT] = 0,					--√—’œ… «·√—’œ… »«·‰”»… ··—’Ìœ «·Õ«·Ì
	@ShowPreviousBalance	[BIT] = 0,					--≈ŸÂ«— «·—’Ìœ «·”«»ﬁ	
	@ShowPreviousTotals			[BIT] = 1,					--«·„Ã«„Ì⁄ »«·‰”»… ··—’Ìœ «·”«»ﬁ
	@ShowPreviousBal			[BIT] = 0,					--«·√—’œ… »«·‰”»… ··—’Ìœ «·”«»ﬁ
	@ShowPreviousBalOfBal		[BIT] = 0,					--√—’œ… «·√—’œ… »«·‰”»… ··—’Ìœ «·”«»ﬁ
	@Lang					VARCHAR(100) = 'ar',		--0 Arabic, 1 Latin
	@BranchMask				BIGINT
	 
AS 
	--Session-Connection
	EXEC [prcSetSessionConnections] @UserGUID, @BranchMask
	
	SET NOCOUNT ON 
	
	--------------------------Prepare @CurVal--------------------------
	DECLARE @CurVal FLOAT
	SELECT TOP 1
		@CurVal = ISNULL(mh.CurrencyVal, my.CurrencyVal) 
	FROM my000 my 
		LEFT JOIN mh000 mh ON my.[GUID] = mh.CurrencyGUID 
	WHERE my.[GUID] = @CurrencyGUID 
	ORDER BY mh.[Date] DESC
	
	-------------------------------------------------------------------
	
	
	DECLARE	@ZeroValue [FLOAT],@str VARCHAR(2000)
	
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]() 
	DECLARE @Level [INT] 
	DECLARE @Admin [INT]
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#AccTbl]( [GUID] [UNIQUEIDENTIFIER], [Security] [INT], [Level] [INT]) 
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])     
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])     
	
	--------------------------------------------------------------------
	----------------------S O U R C E S---------------------------------
	--------------------------------------------------------------------  
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
	
	--INSERT INTO [#EntryTbl] EXEC [prcGetNotesTypesList]  @SrcGuid, @UserID
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] = 5	
		
	   
	--INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList] @SrcGuid, @UserID     
	--New way
	
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	--INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID  
	--New way
	
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] =  1
	 
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl] 
	
	--New way For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 3
	
	--New way For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 4			 
					 
	INSERT INTO [#AccTbl] SELECT * FROM [dbo].[fnGetAcDescList]( @AccountGUID) 
	 
	CREATE TABLE [#Result] 
	( 
		[CoGUID]			[UNIQUEIDENTIFIER], 
		[FixedEnDebit]		[FLOAT], 
		[FixedEnCredit]		[FLOAT], 
		[enDate]			[DATETIME], 
		[ceNumber]			[INT], 
		[ceSecurity]		[INT],
		[CoSecurity]		[INT] 
	) 
	CREATE TABLE [#t_Result] 
	( 
		[GUID]			[UNIQUEIDENTIFIER], 
		[PrevDebit]		[FLOAT] DEFAULT 0, 
		[PrevCredit]	[FLOAT] DEFAULT 0, 
		[PrevBalDebit]	[FLOAT] DEFAULT 0, 
		[PrevBalCredit]	[FLOAT] DEFAULT 0,		  
		[TotalDebit]	[FLOAT] DEFAULT 0, 
		[TotalCredit]	[FLOAT] DEFAULT 0, 
		[BalDebit]		[FLOAT] DEFAULT 0, 
		[BalCredit]		[FLOAT] DEFAULT 0, 
		[EndBalDebit]	[FLOAT] DEFAULT 0, 
		[EndBalCredit]	[FLOAT] DEFAULT 0, 
		[ParentGUID]	[UNIQUEIDENTIFIER], 
		[NSons]			[INT],  
		[Level]			[INT] DEFAULT 0, 
		[Balanced]		[INT], 
		[Security]		[INT],
		[Path]			VARCHAR(8000)  
	) 
	CREATE TABLE [#t_Bal] 
	( 
		[GUID] 			[UNIQUEIDENTIFIER], 
		[TotalDebit]	[FLOAT], 
		[TotalCredit]	[FLOAT] 
	) 
	-- report footer data: 
	CREATE TABLE [#Totals] 
	( 
		[TotalPrevDebit] [FLOAT] DEFAULT 0, 
		[TotalPrevCredit] [FLOAT] DEFAULT 0, 
		[TotalDebitTotal] [FLOAT] DEFAULT 0, 
		[TotalCreditTotal] [FLOAT] DEFAULT 0, 
		[TotalDebitBalance] [FLOAT] DEFAULT 0, 
		[TotalCreditBalance] [FLOAT] DEFAULT 0, 
		[TotalPrevBalDebit] [FLOAT] DEFAULT 0, 
		[TotalPrevBalCredit] [FLOAT] DEFAULT 0 
	) 
	INSERT INTO [#Result] 
	( 
		[coGUID], 
		[FixedEnDebit], 
		[FixedEnCredit], 
		[enDate], 
		[ceNumber], 
		[ceSecurity],
		[CoSecurity] 
	) 
	SELECT 
		[enCostPoint], 
		[FixedEnDebit], 
		[FixedEnCredit], 
		[enDate], 
		[ceNumber], 
		[ceSecurity],
		[Co].coSecurity  
	FROM 
		[dbo].[fnCeEn_Fixed](@CurrencyGUID) AS [f] 
		INNER JOIN [#AccTbl] AS [ac] ON [f].[enAccount] = [ac].[GUID] 
		INNER JOIN [#EntryTbl] AS [t]  ON [f].[ceTypeGuid] = [t].[Type]
		INNER JOIN [vwCo] AS [Co] ON [Co].coGUID = [f].[enCostPoint] 
	WHERE 
		((@PostedValue = -1) OR ( [ceIsPosted] = @PostedValue)) 
		 
	EXEC [prcCheckSecurity] @UserGUID
	
	INSERT INTO [#t_Bal] 
		SELECT 
			[coGUID], 
			SUM( [FixedEnDebit]) AS [TotalDebit], 
			SUM( [FixedEnCredit]) AS [TotalCredit] 
		FROM 
			[#Result] AS [fn1] 
		WHERE 
			[fn1].[enDate] BETWEEN @StartDate AND @EndDate 
		GROUP BY 
			[coGUID] 
	CREATE TABLE [#t_PrevBal] 
	( 
		[GUID] 		[UNIQUEIDENTIFIER], 
		[PrevDebit]	[FLOAT], 
		[PrevCredit][FLOAT] 
	) 
	
	INSERT INTO [#t_PrevBal] 
		SELECT 
			[coGUID], 
			SUM( [FixedEnDebit]) AS [PrevDebit], 
			SUM( [FixedEnCredit]) AS [PrevCredit] 
		FROM 
			[#Result] AS [fn1] 
		WHERE 
			[fn1].[enDate] < @StartDate --BETWEEN @PrevStartDate AND @PrevEndDate 
		GROUP BY 
			[coGUID] 
	--- fill #t_Result 
	INSERT INTO [#t_Result] 
	( 
		[GUID], 
		[ParentGUID], 
		[Level], 
		[Security],
		[Path] 
	) 
	SELECT 
		[f].[GUID], 
		[co].[coParent], 
		[f].[Level], 
		[co].[coSecurity],
		[f].[Path]
	FROM 
		[dbo].[fnGetCostsListWithLevel]( @JobCostGUID, 0) AS [f] 
		INNER JOIN [vwCo] AS [co] ON [f].[GUID] = [co].[coGUID] 

	UPDATE [#t_Result] SET 
		[TotalDebit] = ISNULL( [bl].[TotalDebit], 0), 
		[TotalCredit] = ISNULL( [bl].[TotalCredit],	0), 
		[PrevDebit]	= ISNULL( [bl].[PrevDebit], 0), 
		[PrevCredit] = ISNULL( [bl].[PrevCredit], 0) 
	FROM 
		[#t_Result] AS [tr] INNER JOIN 
		(SELECT			-- this is the balances result set 
			ISNULL([rs1].[GUID], [rs2].[GUID]) AS [GUID], 
			[rs1].[TotalDebit], 
			[rs1].[TotalCredit], 
			[rs2].[PrevDebit], 
			[rs2].[PrevCredit] 
		FROM 
			( 
			SELECT	-- this is the Totals result set 
				[GUID], 
				[TotalDebit], 
				[TotalCredit] 
			FROM 
				[#t_Bal] 
			) AS [rs1] 
			FULL JOIN -- between Totals and Prevs 
			( 
			SELECT	-- this is the Prevs result set 
				[GUID], 
				[PrevDebit], 
				[PrevCredit] 
			FROM 
				[#t_PrevBal] 
			) AS [rs2] 
			ON [rs1].[GUID] = [rs2].[GUID] -- continuing balances full join. 
			--ON rs1.Number = rs2.Number -- continuing balances full join. 
		) AS [bl] -- balances result set 
	ON [tr].[GUID] = [bl].[GUID] -- continuing original result set 

 
	UPDATE [#t_Result] SET [Balanced] = CASE WHEN ABS(([TotalDebit] - [TotalCredit])+( [PrevDebit] - [PrevCredit])) < @ZeroValue AND (([TotalDebit] + [TotalCredit])+( [PrevDebit] + [PrevCredit])) > @ZeroValue THEN 0  WHEN ABS(([TotalDebit] - [TotalCredit])+( [PrevDebit] - [PrevCredit])) > @ZeroValue THEN 1  ELSE NULL END 
	UPDATE [#t_Result] SET 
		[BalDebit] = ( [TotalDebit] - [TotalCredit]), 
		[BalCredit] = ( [TotalDebit] - [TotalCredit]),   
		[PrevBalDebit] = ( [PrevDebit] - [PrevCredit]),  
		[PrevBalCredit] = ( [PrevDebit] - [PrevCredit])  
	 
	UPDATE [#t_Result] SET   
		[BalDebit] = CASE WHEN [BalDebit] < 0 THEN 0 ELSE [BalDebit] END,   
		[BalCredit] = CASE WHEN [BalCredit] < 0 THEN - [BalCredit] ELSE 0 END,   
		[PrevBalDebit] = CASE WHEN [PrevBalDebit] < 0 THEN 0 ELSE [PrevBalDebit] END,  
		[PrevBalCredit] = CASE WHEN [PrevBalCredit] < 0 THEN - [PrevBalCredit] ELSE 0 END  
		 
	 

	---- Calc Totals  
	INSERT INTO [#Totals] 
	( 
		[TotalPrevDebit],  
		[TotalPrevCredit],  
		[TotalDebitTotal], 	 
		[TotalCreditTotal],  
		[TotalDebitBalance],  
		[TotalCreditBalance],  
		[TotalPrevBalDebit],  
		[TotalPrevBalCredit] 
	)  
	SELECT  
		SUM( [PrevDebit]), 
		SUM( [PrevCredit]), 
		SUM( [TotalDebit]), 
		SUM( [TotalCredit]), 
		SUM( [BalDebit]), 
		SUM( [BalCredit]), 
		SUM( [PrevBalDebit]), 
		SUM( [PrevBalCredit]) 
	FROM 
		[#t_Result] 
	--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@UserGUID,0x00) ) 
	IF @Admin = 0 
	BEGIN 
		DECLARE @CoSecurity [INT]	 
		SET @CoSecurity = [dbo].[fnGetUserCostSec_Browse](@UserGUID) 
		SET @Level = 1 
		WHILE @Level > 0 
		BEGIN 
			UPDATE [co] SET [ParentGuid] = [c].[ParentGuid],[Level] = [co].[Level] -1 FROM [#t_Result] AS [co] INNER JOIN [#t_Result] AS [c] ON [co].[ParentGuid] = [c].[Guid] WHERE [c].[Security] > @CoSecurity 
			SET @Level = @@RowCount 
		END 
		DELETE [#t_Result] WHERE [Security] > @CoSecurity 
	END 
-- 3rd. step: update parents balances: 
	SET @Level = (SELECT MAX([Level]) FROM [#t_Result]) 
	WHILE @Level >= 0 
	BEGIN 
		UPDATE [#t_Result] SET 
			[PrevDebit]	= [PrevDebit] + [SumPrevDebit], 
			[PrevCredit] = [PrevCredit] + [SumPrevCredit], 
			[TotalDebit] = [TotalDebit] + [SumTotalDebit], 
			[TotalCredit] = [TotalCredit] + [SumTotalCredit], 
			[BalDebit]	= [BalDebit] + [SumBalDebit], 
			[BalCredit]	= [BalCredit] + [SumBalCredit], 
		  
			[PrevBalDebit] = [PrevBalDebit] + [SumPrevBalDebit], 
			[PrevBalCredit] = [PrevBalCredit] + [SumPrevBalCredit], 
			[Balanced] = CASE WHEN [Balanced] > 0 THEN [Balanced] ELSE  [SumBalanced] END 
		FROM 
			[#t_Result] AS [Father] INNER JOIN 
				( 
				SELECT 
					[ParentGUID], 
					SUM([PrevDebit]) AS [SumPrevDebit], 
					SUM([PrevCredit]) AS [SumPrevCredit], 
					SUM([TotalDebit]) AS [SumTotalDebit], 
					SUM([TotalCredit]) AS [SumTotalCredit], 
					SUM([BalDebit]) AS [SumBalDebit], 
					SUM([BalCredit]) AS [SumBalCredit], 
					SUM([PrevBalDebit]) AS [SumPrevBalDebit], 
					SUM([PrevBalCredit]) AS [SumPrevBalCredit], 
					SUM([Balanced]) AS [SumBalanced] 
				FROM 
					[#t_Result] 
				WHERE 
					[Level] = @Level 
				GROUP BY 
					[ParentGUID] 
				) AS [Sons] -- sum sons 
			ON [Father].[GUID] = [Sons].[ParentGUID] 
	SET @Level = @Level - 1 
	END 
-----------+++ 
	IF @ShowBalancedJobCost = 0 
		DELETE [#t_Result] WHERE [Balanced] = 0  
	IF @ShowEmptyJobCost = 0 
		DELETE [#t_Result] WHERE [Balanced] IS NULL  
	  
	-- return result set	 
	DECLARE @TotalDebitBalance FLOAT, @TotalCreditBalance FLOAT, @IsFullResult BIT
	SET @TotalDebitBalance  = (SELECT TotalDebitBalance  FROM [#Totals])
	SET @TotalCreditBalance = (SELECT TotalCreditBalance FROM [#Totals])
	IF ( (SELECT ISNULL(SUM(Cnt), 0) FROM [#SecViol]) = 0 )
		SET @IsFullResult = 1
	ELSE
		SET @IsFullResult = 0
	
	
	SELECT  
		[r].[GUID] AS [coGUID], 
		[co].[coName],
		[co].[coLatinName],
		[co].[coCode], 
		[r].[PrevDebit]																									  AS PrevTotalDebit,			
		[r].[PrevCredit]																								  AS PrevTotalCredit, 
		[r].[PrevBalDebit], 
		[r].[PrevBalCredit],
		(CASE WHEN [r].[PrevBalDebit] - [r].[PrevBalCredit] > 0 THEN [r].[PrevBalDebit] - [r].[PrevBalCredit] ELSE 0 END) AS PrevDebit, 
		(CASE WHEN [r].[PrevBalCredit] - [r].[PrevBalDebit] > 0 THEN [r].[PrevBalCredit] - [r].[PrevBalDebit] ELSE 0 END) AS PrevCredit, 
		[r].[TotalDebit]																								  AS CurrentTotalDebit, 
		[r].[TotalCredit]																								  AS CurrentTotalCredit,
		[r].[BalDebit]																									  AS CurrentBalDebit,
		[r].[BalCredit]																							          AS CurrentBalCredit,
		(CASE WHEN [r].[BalDebit] - [r].[BalCredit] > 0 THEN [r].[BalDebit] - [r].[BalCredit] ELSE 0 END)				  AS CurrentDebit, 
		(CASE WHEN [r].[BalCredit] - [r].[BalDebit] > 0 THEN [r].[BalCredit] - [r].[BalDebit] ELSE 0 END)				  AS CurrentCredit, 
		[r].[PrevDebit]  + [r].[TotalDebit]																				  AS EndTotalDebit,
		[r].[PrevCredit] + [r].[TotalCredit]															                  AS EndTotalCredit,
		[r].[EndBalDebit], 
		[r].[EndBalCredit], 
		(CASE WHEN [r].[EndBalDebit] - [r].[EndBalCredit] > 0 THEN [r].[EndBalDebit] - [r].[EndBalCredit] ELSE 0 END)	  AS EndDebit, 
		(CASE WHEN [r].[EndBalCredit] - [r].[EndBalDebit]  > 0 THEN [r].[EndBalCredit] - [r].[EndBalDebit] ELSE 0 END)	  AS EndCredit, 
		[r].[ParentGUID], 
		[r].[Level],
		(CASE WHEN ([r].[BalDebit] = 0 AND [r].[BalCredit] = 0) THEN '' ELSE
			  (CASE WHEN (@TotalDebitBalance - @TotalCreditBalance <> 0) THEN CAST( (([r].[BalDebit] - [r].[BalCredit]) / (@TotalDebitBalance - @TotalCreditBalance)*100) AS VARCHAR(100) ) + '%' ELSE '100%'
			   End)
		 END) AS BalanceRatio,
		 @IsFullResult AS IsFullResult
	 FROM  
		[#t_Result] AS [r] 
		INNER JOIN [vwCo] AS [co] ON [r].[GUID] = [co].[coGUID]
#########################################################
CREATE PROCEDURE ARWA.repBuProfitsWithCost
	@StartDate 		[DATETIME], 
	@EndDate 		[DATETIME], 
	@SourcesTypes	VARCHAR(MAX),
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@CurrencyGUID 	[UNIQUEIDENTIFIER], 
	@CurrencyVal 	[FLOAT], 
	@Vendor 		[FLOAT], 
	@SalesMan 		[FLOAT], 
	@SortType		[INT], 
	@PayType		[INT] = -1, 
	@CheckGuid		[UNIQUEIDENTIFIER] = 0X0, 
	@CollectByCust	[BIT] = 0, 
	@InOutNeg		[INT] = 0, 
	@ShwMainAcc		[BIT] = 0,
	@Lang					VARCHAR(100) = 'ar',		--0 Arabic, 1 Latin
	@UserGuid				[UNIQUEIDENTIFIER] = 0X0	--Guid Of Logining User
AS 
	SET NOCOUNT ON 
	DECLARE @Level [INT] 
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	--CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	
	 -------Bill Resource ---------------------------------------------------------      
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTypesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnPostedSec] [INT], [ReadPriceSecurity] [INT])       
    INSERT INTO [#BillTypesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	--Filling temporary tables 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	CREATE TABLE [#Result] 
	( 
		[BuType] 				[UNIQUEIDENTIFIER], 
		[BuNumber] 				[UNIQUEIDENTIFIER], 
		[buNum]					[FLOAT], -- bu number for sort 
		[buFormatedNumber]		[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buLatinFormatedNumber]	[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buDirection]			[INT], 
		[buNotes] 				[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buDate] 				[DATETIME] NOT NULL DEFAULT '1/1/1990', 
		[buCustPtr] 			[UNIQUEIDENTIFIER], 
		[buCustName]			[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buCustLatinName]		[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[FixedBiPrice]			[FLOAT], 
		[biQty]					[FLOAT], 
		[MtUnitFact]			[FLOAT], 
		[FixedBuTotalDisc]		[FLOAT], 
		[FixedbuItemsDisc]		[FLOAT], 
		[FixedBuTotal]			[FLOAT], 
		[FixedBiDiscount]		[FLOAT], 
		[FixedbiVat]			[FLOAT], 
		[FixedBuTotalExtra]		[FLOAT], 
		[FixedBiProfits]		[FLOAT], 
		[Security]				[INT] DEFAULT 0 , 
		[UserSecurity] 			[INT] DEFAULT 0 , 
		[UserReadPriceSecurity]	[INT], 
		[VatSys]				[INT], 
		[AffectDisc]			[BIT], 
		[AffectExtra]			[BIT], 
		[AccountGuid]			[UNIQUEIDENTIFIER], 
		[Path]					[VARCHAR](7000) COLLATE ARABIC_CI_AI, 
		[Level]					[INT], 
		[PayType]				[INT], 
		[CheckTypeGuid]			[UNIQUEIDENTIFIER], 
		[CheckTypeName]			[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[bHasTTC]				BIT,
		[FullResult]			[INT]
	)
	INSERT INTO [#Result] 
		SELECT 
			[r].[buType], 
			[r].[buGUID], 
			[r].[buNumber],
			[r].[buFormatedNumber], 
			[r].[buLatinFormatedNumber],
			[r].[buDirection], 
			[r].[buNotes], 
			[r].[buDate], 
			[r].[buCustPtr], 
			ISNULL([Cu000].[CustomerName], ''),
			ISNULL([Cu000].[LatinName], ''),
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBiPrice] ELSE 0 END AS [FixedBiPrice], 
			[r].[biQty], 
			[r].[MtUnitFact] , 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalDisc] ELSE 0 END AS [FixedBuTotalDisc], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbuItemsDisc] ELSE 0 END AS [FixedbuItemsDisc], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal]  ELSE 0 END AS [FixedBuTotal],   
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBiDiscount] ELSE 0 END AS [FixedBiDiscount], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBiVat] ELSE 0 END AS [FixedBiVat], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalExtra] ELSE 0 END AS [FixedBuTotalExtra], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBiProfits] ELSE 0 END AS [FixedBiProfits], 
			 
			[r].[buSecurity], 
			CASE [r].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnPostedSec] END, 
			[bt].[ReadPriceSecurity], 
			[btVatSystem], 
			[btDiscAffectProfit]|[btDiscAffectCost],[btExtraAffectProfit]|[btExtraAffectCost]
			,[cu].[AccountGuid],'',0, 
			[buPayType]
			,[buCheckTypeGuid]
			,ISNULL([Nt].[Name], '')
			,CASE btVatSystem WHEN 2 THEN 1 ELSE 0 END  
			,1
			 
		FROM  
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [r] 
			INNER JOIN [#BillTypesTbl] AS [bt] ON [r].[buType] = [bt].[Type] 
			INNER JOIN [#CustTbl] AS [cu] ON [cu].[CustGuid] = [r].[buCustPtr] 
			LEFT JOIN [Cu000] ON [Cu000].Guid = [r].[buCustPtr]
			LEFT JOIN [Nt000] Nt ON Nt.Guid = [buCheckTypeGuid]
		WHERE 
			[buDate] BETWEEN @StartDate AND @EndDate  
			AND( ([BuVendor] = @Vendor) 				OR (@Vendor = 0 )) 
			AND( ([BuSalesManPtr] = @SalesMan) 		OR (@SalesMan = 0)) 
			AND( (@CostGUID = 0x0) 					OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl]))) 
			AND ((@PayType = -1)				OR ([buPayType] = @PayType)) 
			AND ((@CheckGuid = 0X0)				OR ([buCheckTypeGuid] = @CheckGuid)) 
	UPDATE b SET [FixedBuTotal] = [FixedBuTotal] - V from [#Result] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [BuNumber] where [bHasTTC] = 1 
	---check sec 
	EXEC [prcCheckSecurity] 
	IF Exists(Select * from #SecViol)
		Update #Result SET FullResult = 0
	IF @ShwMainAcc > 0 
	BEGIN 
		SELECT @Level = MAX([Level]) FROM [#Acc] 
		UPDATE [r] SET [Path] = [ac].[Path],[Level] = [AC].[Level] FROM [#Result] [r] INNER JOIN [#Acc] ac ON [ac].[Guid] = [AccountGuid] 
		WHILE @Level > 0 
		BEGIN 
			INSERT INTO [#Result] 
			( 
				[buDirection], 
				[buCustPtr], 
				[FixedBuTotal], 
				[FixedBiPrice], 
				[biQty], 
				[MtUnitFact], 
				[FixedBuTotalDisc], 
				[FixedBiDiscount], 
				[FixedbiVat], 
				[FixedBuTotalExtra], 
				[FixedBiProfits], 
				[VatSys],		 
				[AffectDisc],			 
				[AffectExtra],			 
				[AccountGuid],			 
				[Path],					 
				[Level],
				[FullResult]
			) 
			SELECT  
				[buDirection], 
				[ac].[Guid], 
				1, 
				SUM([FixedBiPrice]*[biQty]/[MtUnitFact]), 
				1, 
				1, 
				SUM(( [FixedBuTotalDisc] - [FixedbuItemsDisc]) * [FixedBiPrice] * [biQty] / [mtUnitFact] /  CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END  * [AffectDisc]), 
				SUM([FixedBiDiscount]* [AffectDisc]),			 
				0, 
				SUM(( [FixedBuTotalExtra] * [FixedBiPrice] * [biQty] / [mtUnitFact] /  CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END  ) *[AffectExtra]),		 
				SUM([FixedBiProfits]), 
				[VatSys],		 
				1,1, 
				[ac].[Guid], 
				[ac].[Path], 
				[ac].[Level],
				1
			FROM 	[#Result] AS [r] INNER JOIN [ac000] AS [c] ON [r].[AccountGuid] = [c].[Guid] INNER JOIN [#Acc] ac ON [c].[ParentGuid] = [ac].[Guid] 
			WHERE [r].[Level] = @Level 
			GROUP BY 
				[buDirection], 
				[ac].[Guid], 
				[ac].[Path], 
				[VatSys],	 
				[ac].[Level] 
			SET @Level = @Level - 1 
					 
		END 
	END 
	DECLARE @Fact	[VARCHAR](256) 
	IF @CollectByCust > 0 
		SET @Fact = ' *CASE ' + CAST( @InOutNeg AS [VARCHAR](2) ) + ' WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END*[buDirection] ' 
	ELSE  
		SET @Fact = '' 
	 
	--return result set 
	DECLARE @Str [VARCHAR](8000) 
	SET @Str = 'SELECT ' 
	IF @CollectByCust = 0 
		SET @Str = @Str + '[BuType],[BuNumber], 
		[buNum], [buFormatedNumber],[buLatinFormatedNumber],[buDirection],[buNotes],[buDate],' 
	SET @Str = @Str + '[buCustPtr], [buCustName], [buCustLatinName],[FullResult],' 
	SET @Str = @Str + '	SUM( ([FixedBiPrice] * [biQty] / [MtUnitFact] + FixedbiVat)' + @Fact + ')  AS [buTotal], 
			SUM(ISNULL(([FixedBuTotalDisc] - [FixedbuItemsDisc]) * [FixedBiPrice]*[biQty]/[mtUnitFact]/CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END+[FixedBiDiscount] ' + @Fact + ', 0))  AS [buTotalDisc], 
			SUM([FixedBuTotalExtra]*[FixedBiPrice]*[biQty]/[mtUnitFact]/ CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END  ' + @Fact + ')  AS [buTotalExtra], 
			SUM([FixedBiProfits]' + @Fact + ') AS [buProfits], 
			SUM ([FixedBiVAT]' + @Fact + ')  AS [buVat] ' 
	IF @CollectByCust > 0 
	BEGIN 
		SET @Str = @Str + ',ISNULL(' 
		IF @Lang = 'ar'
			SET @Str = @Str + ' [CustomerName]'  
		ELSE  
			SET @Str = @Str + 'CASE [LatinName] WHEN '''' THEN [CustomerName] ELSE [LatinName] END ' 
		SET @Str = @Str + ','''') AS [Name] , 
		SUM(ISNULL([FixedBuTotalDisc] ' + @Fact + '*[AffectDisc], 0) ) AS [DiscAffected], 
			SUM(ISNULL([FixedbuTotalExtra]' + @Fact + '*[AffectExtra], 0)) AS [ExtraAffected] 
		' 
	END 
	ELSE 
		SET @Str = @Str + ' ,[PayType] [buPayType],[CheckTypeGuid] [buCheckTypeGuid], [CheckTypeName],[AffectDisc],[AffectExtra]' 
	--SET @Str = @Str + ' ,[FixedBuTotal] + [FixedbuTotalExtra] - [FixedbuTotalDisc] NetSale' 
	SET @Str = @Str + ' INTO #tmp FROM [#Result] AS [r]' 
	 
	IF @CollectByCust > 0 OR @SortType = 2 
	BEGIN 
		IF @ShwMainAcc > 0 OR @SortType = 2 
			SET @Str = @Str + ' LEFT '  
		ELSE 
			SET @Str = @Str + ' LEFT ' 
		SET @Str = @Str + ' JOIN [cu000] AS [cu] ON [cu].[Guid] = [buCustPtr] ' 
	END 
	SET @Str = @Str + ' WHERE 
		[UserSecurity]>=[r].[Security] ' 
	IF @CollectByCust > 0 AND @ShwMainAcc > 0 
		SET @Str = @Str + ' AND [buCustPtr] IS NOT NULL ' 
	SET @Str = @Str + ' GROUP BY ' 
	IF @CollectByCust = 0 
		SET @Str = @Str + '[BuType],[BuNumber],[buNum],[buFormatedNumber],[buLatinFormatedNumber],[buDirection],[buNotes], [AffectDisc],[AffectExtra], 
		[buDate],' 
	IF @SortType = 2 
		SET @Str = @Str + ' [CustomerName],' 
	SET @Str = @Str + 	'[buCustPtr],[buCustName], [buCustLatinName],[Path], [FullResult]' 
	IF @CollectByCust > 0 
	BEGIN 
		IF @Lang = 'ar' 
			SET @Str = @Str + ' ,[CustomerName]'  
		ELSE  
			SET @Str = @Str + ',CASE [LatinName] WHEN '''' THEN [CustomerName] ELSE [LatinName] END ' 
	END 
	ELSE 
		SET @Str = @Str + ' ,[PayType],[CheckTypeGuid], [CheckTypeName]' 
	SET @Str = @Str + ' ORDER BY ' 
	IF @CollectByCust = 0 
	BEGIN 
		IF @SortType = 0 
			SET @Str = @Str + ' [buDate]' 
		ELSE IF @SortType = 1 
			SET @Str = @Str + ' [buNum]' 
		ELSE IF @SortType = 2 
			SET @Str = @Str + ' [CustomerName]' 
		ELSE  
			SET @Str = @Str + ' SUM([FixedBiProfits]' + @Fact + ')' 
	END 
	ELSE 
	BEGIN 
		SET @Str = @Str + ' [Path],	' 
		IF @Lang = 'ar' 
				SET @Str = @Str + ' [CustomerName]'  
			ELSE  
				SET @Str = @Str + 'CASE [LatinName] WHEN '''' THEN [CustomerName] ELSE [LatinName] END '  
	END 
	IF @CollectByCust = 0 
		SET @Str = @Str + ' SELECT tmp.[buFormatedNumber], tmp.[buLatinFormatedNumber], tmp.[buDate],CASE WHEN ISNULL([Ac].[Name], '''') = '''' THEN [buCustName] ELSE [Ac].[Name] END buCustName, CASE WHEN ISNULL([Ac].[LatinName], '''') = '''' THEN [buCustLatinName] ELSE [Ac].[LatinName] END [buCustLatinName], [CheckTypeName], [buPayType], [buTotal], [buTotalDisc], [buTotalExtra] '
	ELSE
		SET @Str = @Str + ' SELECT CASE WHEN ISNULL([Ac].[Name], '''') = '''' THEN [buCustName] ELSE [Ac].[Code] + ''-'' + [Ac].[Name] END buCustName, CASE WHEN ISNULL([Ac].[LatinName], '''') = '''' THEN [buCustLatinName] ELSE [Ac].[Code] + ''-'' + [Ac].[LatinName] END buCustLatinName, [buTotal], [buTotalDisc], [buTotalExtra] '
	SET @Str = @Str + ' ,[buTotal] + [buTotalExtra] - [buTotalDisc] NetSale'
	IF @CollectByCust = 0 
		SET @Str = @Str + ', ([buTotal] - [buProfits]) +  CASE [AffectExtra] WHEN 1 THEN [buTotalExtra] - [buVat] ELSE 0 END - CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END cost'
	ELSE
		SET @Str = @Str + ', ([buTotal] - [buProfits]) +  ([ExtraAffected] - [DiscAffected]) cost'
	IF @CollectByCust = 0 
		SET @Str = @Str + ', ([buProfits]) +  CASE [AffectExtra] WHEN 1 THEN -([buTotalExtra] - [buVat]) ELSE 0 END + CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END profit'
	ELSE
		SET @Str = @Str + ', ([buProfits]) -([ExtraAffected] - [DiscAffected]) profit'
		
	IF @CollectByCust = 0 
		SET @Str = @Str + ', ([buProfits]) +  CASE [AffectExtra] WHEN 1 THEN -([buTotalExtra] - [buVat]) ELSE 0 END + CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END '
	ELSE
		SET @Str = @Str + ', ([buProfits]) -([ExtraAffected] - [DiscAffected]) '
	SET @Str = @Str + ' +  [buTotalExtra] - ([buTotalDisc] + [buVat]) net'
	
	IF @CollectByCust = 0 
		SET @Str = @Str + ', (([buProfits]) +  CASE [AffectExtra] WHEN 1 THEN -([buTotalExtra] - [buVat]) ELSE 0 END + CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END '
	ELSE
		SET @Str = @Str + ', (([buProfits]) -([ExtraAffected] - [DiscAffected]) '
	SET @Str = @Str + ' +  [buTotalExtra] - ([buTotalDisc] + [buVat])) * 100 / CASE [buTotal] WHEN 0 THEN 1 ELSE [buTotal] END TotalProfitsPer '
		
	IF @CollectByCust = 0 
		SET @Str = @Str + ', (([buProfits]) +  CASE [AffectExtra] WHEN 1 THEN -([buTotalExtra] - [buVat]) ELSE 0 END + CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END '
	ELSE
		SET @Str = @Str + ', (([buProfits]) -([ExtraAffected] - [DiscAffected]) '
	SET @Str = @Str + ' +  [buTotalExtra] - ([buTotalDisc] + [buVat])) * 100 / CASE '
	
	IF @CollectByCust = 0 
		SET @Str = @Str + ' (([buTotal] - [buProfits]) +  CASE [AffectExtra] WHEN 1 THEN [buTotalExtra] - [buVat] ELSE 0 END - CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END) '
	ELSE
		SET @Str = @Str + ' (([buTotal] - [buProfits]) +  ([ExtraAffected] - [DiscAffected])) '
	SET @Str = @Str + '  WHEN 0 THEN 1 ELSE'
	
	IF @CollectByCust = 0 
		SET @Str = @Str + ' (([buTotal] - [buProfits]) +  CASE [AffectExtra] WHEN 1 THEN [buTotalExtra] - [buVat] ELSE 0 END - CASE [AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END) '
	ELSE
		SET @Str = @Str + ' (([buTotal] - [buProfits]) +  ([ExtraAffected] - [DiscAffected])) '
	SET @Str = @Str + '  END TotalProfitsCostPer'
	
	IF @CollectByCust = 1 
		SET @Str = @Str + ',[buTotal] TotalSale'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN -[buTotal] ELSE [buTotal] END TotalSale'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN [buTotal] ELSE -[buTotal] END TotalSale'
		ELSE
			SET @Str = @Str + ',[buTotal] TotalSale'
	IF @CollectByCust = 1 
		SET @Str = @Str + ',[buProfits] TotalProfit'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN -[buProfits] ELSE [buProfits] END TotalProfit'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN [buProfits] ELSE -[buProfits] END TotalProfit'
		ELSE
			SET @Str = @Str + ',[buProfits] TotalProfit'
	IF @CollectByCust = 1 
		SET @Str = @Str + ',[buTotalDisc] TotalDisc'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN -[buTotalDisc] ELSE [buTotalDisc] END TotalDisc'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN [buTotalDisc] ELSE -[buTotalDisc] END TotalDisc'
		ELSE
			SET @Str = @Str + ',[buTotalDisc] TotalDisc'
	IF @CollectByCust = 1 
		SET @Str = @Str + ',[buTotalExtra] TotalExtra'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN -[buTotalExtra] ELSE [buTotalExtra] END TotalExtra'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE [buDirection] WHEN 1 THEN [buTotalExtra] ELSE -[buTotalExtra] END TotalExtra'
		ELSE
			SET @Str = @Str + ',[buTotalExtra] TotalExtra'
	IF @CollectByCust = 1 
		SET @Str = @Str + ',CASE tmp.[AffectDisc] WHEN 1 THEN [DiscAffected] ELSE 0 END TotalDiscAffect'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE tmp.[AffectDisc] WHEN 1 THEN CASE [buDirection] WHEN 1 THEN -[buTotalDisc] ELSE [buTotalDisc] END ELSE 0 END TotalDiscAffect'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE tmp.[AffectDisc] WHEN 1 THEN CASE [buDirection] WHEN 1 THEN [buTotalDisc] ELSE -[buTotalDisc] END ELSE 0 END TotalDiscAffect'
		ELSE
			SET @Str = @Str + ',CASE tmp.[AffectDisc] WHEN 1 THEN [buTotalDisc] ELSE 0 END TotalDiscAffect'
	IF @CollectByCust = 1 
		SET @Str = @Str + ',CASE tmp.[AffectExtra] WHEN 1 THEN [ExtraAffected] ELSE 0 END TotalExtraAffect'
	ELSE
		IF(@InOutNeg = 2)
			SET @Str = @Str + ',CASE tmp.[AffectExtra] WHEN 1 THEN CASE [buDirection] WHEN 1 THEN -[buTotalExtra] ELSE [buTotalExtra] END ELSE 0 END TotalExtraAffect'
		ELSE IF(@InOutNeg = 1) 
			SET @Str = @Str + ',CASE tmp.[AffectExtra] WHEN 1 THEN CASE [buDirection] WHEN 1 THEN [buTotalExtra] ELSE -[buTotalExtra] END ELSE 0 END TotalExtraAffect'
		ELSE
			SET @Str = @Str + ',CASE tmp.[AffectExtra] WHEN 1 THEN [buTotalExtra] ELSE 0 END TotalExtraAffect'
	SET @Str = @Str + ' ,tmp.[AffectDisc],tmp.[AffectExtra],tmp.[FullResult] FROM #tmp tmp LEFT JOIN [Ac000] AS [Ac] ON [ac].[Guid] = [buCustPtr]'
	
	EXEC( @Str)
#########################################################
CREATE PROCEDURE ARWA.repBuProfitsNoCost
	@StartDate 		[DATETIME], 
	@EndDate 		[DATETIME], 
	@SourcesTypes	VARCHAR(MAX),
	@CurrencyGUID 	[UNIQUEIDENTIFIER], 
	@CurrencyVal 	[FLOAT], 
	@Vendor 		[FLOAT], 
	@SalesMan 		[FLOAT], 
	@SortType		[INT], 
	@PayType		[INT] = -1, 
	@CheckGuid		[UNIQUEIDENTIFIER] = 0X0, 
	@CollectByCust	[BIT] = 0, 
	@InOutNeg		[INT] = 0, 
	@ShwMainAcc		[BIT] = 0,
	@Lang					VARCHAR(100) = 'ar',		--0 Arabic, 1 Latin
	@UserGuid				[UNIQUEIDENTIFIER] = 0X0	--Guid Of Logining User
AS 
	SET NOCOUNT ON 
	DECLARE @Level [INT] 
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	
	-------Bill Resource ---------------------------------------------------------      
	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTypesTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [UnPostedSec] [INT], [ReadPriceSecurity] [INT])       
    INSERT INTO [#BillTypesTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_BrowseUnPosted](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])), [dbo].[fnGetUserBillSec_ReadPrice](@UserGuid, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	CREATE TABLE [#Result] 
	( 
		[BuType] 				[UNIQUEIDENTIFIER], 
		[BuNumber] 				[UNIQUEIDENTIFIER] , 
		[buFormatedNumber] 		[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buLatinFormatedNumber] [VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buNum]					[FLOAT],-- bu number for sort 
		[buDirection]			[INT], 
		[buNotes] 				[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buDate] 				[DATETIME] NOT NULL DEFAULT '1/1/1980', 
		[buCustPtr] 			[UNIQUEIDENTIFIER], 
		[buCustName] 			[VARCHAR](256) COLLATE ARABIC_CI_AI,
		[buCustLatinName]		[VARCHAR](256) COLLATE ARABIC_CI_AI,
		[buTotal]				[FLOAT], 
		[buTotalDisc]			[FLOAT],  
		[buTotalExtra]			[FLOAT], 
		[buProfits]				[FLOAT], 
		[Security]				[INT] DEFAULT 0, 
		[UserSecurity] 			[INT] DEFAULT 0, 
		[UserReadPriceSecurity]	[INT], 
		[buVat]					[FLOAT], 
		[AffectDisc]			[BIT], 
		[AffectExtra]			[BIT], 
		[AccountGuid]			[UNIQUEIDENTIFIER], 
		[Path]					[VARCHAR](4000) COLLATE ARABIC_CI_AI, 
		[Level]					[INT], 
		[PayType]				[INT], 
		[CheckTypeGuid]			[UNIQUEIDENTIFIER], 
		[CheckTypeName]			[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CheckTypeLatinName]	[VARCHAR](256) COLLATE ARABIC_CI_AI, 
		[bHasTTC]				BIT,
		[DiscAffectCost]			[BIT],
		[DiscAffectProfit]		[BIT],
		[ExtraAffectCost]		[BIT],
		[ExtraAffectProfit]		[BIT],
		[FullResult]			[INT]
	) 
	INSERT INTO [#Result] 
		SELECT 
			[r].[buType], 
			[r].[buGUID], 
			[r].[buFormatedNumber],
			[r].[buLatinFormatedNumber],
			[r].[buNumber], 
			[r].[buDirection], 
			[r].[buNotes], 
			[r].[buDate], 
			[r].[buCustPtr], 
			ISNULL([Cu000].[CustomerName], ''),
			ISNULL([Cu000].[LatinName], '') CustomerLatinName,
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotal]/* - CASE btVatSystem WHEN 2 THEN [r].[FixedBuVat] ELSE 0 END */ ELSE 0 END AS [buTotal], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalDisc] ELSE 0 END AS [buTotalDisc], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedBuTotalExtra]  ELSE 0 END AS [buTotalExtra], 
			CASE WHEN [ReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbuProfits] ELSE 0 END AS [buProfits], 
			[r].[buSecurity], 
			CASE [r].[buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [bt].[UnpostedSec] END, 
			[bt].[ReadPriceSecurity], 
			0, 
			[btDiscAffectProfit]|[btDiscAffectCost]
			,[btExtraAffectProfit]|[btExtraAffectCost]
			,[cu].[AccountGuid]
			,''
			,0, 
			[buPayType],
			[buCheckTypeGuid], 
			ISNULL([Nt].[Name], ''),
			ISNULL([Nt].[LatinName], ''),
			CASE btVatSystem WHEN 2 THEN 1 ELSE 0 END,
			[btDiscAffectCost],
			[btDiscAffectProfit],
			[btExtraAffectCost],
			[btExtraAffectProfit],
			1
		FROM 
			[fnBu_Fixed](@CurrencyGUID) AS [r]  
			INNER JOIN [#BillTypesTbl] AS [bt] ON [r].[buType] = [bt].[Type] 
			INNER JOIN [#CustTbl] AS [cu] ON [cu].[CustGuid] = [r].[buCustPtr] 
			LEFT JOIN [Cu000] ON [Cu000].Guid = [r].[buCustPtr]
			LEFT JOIN [Nt000] Nt ON Nt.Guid = [buCheckTypeGuid]
		WHERE 
			[buDate] BETWEEN @StartDate AND @EndDate 
			AND( ([BuVendor] = @Vendor) 				OR (@Vendor = 0 ))	 
			AND( ([BuSalesManPtr] = @SalesMan) 		OR (@SalesMan = 0)) 
			AND ((@PayType = -1)				OR ([buPayType] = @PayType)) 
			AND ((@CheckGuid = 0X0)				OR ([buCheckTypeGuid] = @CheckGuid)) 
	UPDATE b SET [buTotal] = [buTotal] - V from [#Result] [b] INNER JOIN (SELECT SUM((Discount + BonusDisc) * VATRatio/100) V,parentGuid from bi000 group by parentGuid) Q ON Q.parentGuid = [BuNumber] where [bHasTTC] = 1 
	---check sec 
	EXEC [prcCheckSecurity] 
	IF Exists(Select * from #SecViol)
		Update #Result SET FullResult = 0
	IF @ShwMainAcc > 0 
	BEGIN 
		SELECT @Level = MAX([Level]) FROM [#Acc] 
		UPDATE [r] SET [Path] = [ac].[Path],[Level] = [AC].[Level] FROM [#Result] [r] INNER JOIN [#Acc] ac ON [ac].[Guid] = [AccountGuid] 
		WHILE @Level > 0 
		BEGIN 
			INSERT INTO [#Result] 
			( 
				[buDirection], 
				[buCustPtr],
				[buTotal], 
				[buTotalDisc],  
				[buTotalExtra],			 
				[buProfits],				 
				[buVat],					 
				[AffectDisc],			 
				[AffectExtra],			 
				[AccountGuid],			 
				[Path],					 
				[Level],
				[FullResult]					 
			) 
			SELECT  
				[buDirection], 
				[ac].[Guid], 
				SUM([buTotal]), 
				SUM([buTotalDisc]*[AffectDisc]),  
				SUM([buTotalExtra]*[AffectExtra]),			 
				SUM([buProfits]),				 
				SUM([buVat]),1,1, 
				[ac].[Guid], 
				[ac].[Path], 
				[ac].[Level],
				1
			FROM 	[#Result] AS [r] INNER JOIN [ac000] AS [c] ON [r].[AccountGuid] = [c].[Guid] INNER JOIN [#Acc] ac ON [c].[ParentGuid] = [ac].[Guid] 
			WHERE [r].[Level] = @Level 
			GROUP BY 
				[buDirection], 
				[ac].[Guid], 
				[ac].[Path], 
				[ac].[Level] 
			SET @Level = @Level - 1 
					 
		END 
	END 
	
								   
	---return result set 
	SET @SortType = 2
	IF @CollectByCust = 0 
	BEGIN 
		IF @SortType = 2 
				SELECT 	[r].[buFormatedNumber]
						,[r].[buLatinFormatedNumber]
						,[r].[buDate] 
						,[r].[buCustName]
						,[r].[buCustLatinName]
						,[PayType]
						,[CheckTypeName]
						,[CheckTypeLatinName]
						,[r].[buTotal]
						,[r].[buTotalDisc]
						,[r].[buTotalExtra]
						,[r].[buTotal] + [r].[buTotalExtra] - [r].[buTotalDisc] NetSale
						,[r].[buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - [r].[buProfits] cost
						,[r].[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) profit						
						, [r].[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) + [r].[buTotalExtra] - ( [r].[buTotalDisc] + [r].[buVat] ) Net
						, ([r].[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) + [r].[buTotalExtra] - ( [r].[buTotalDisc] + [r].[buVat] )) 
							* 100
							/ CASE WHEN ([r].[buTotal] - [r].[buVat]) = 0 THEN 1 ELSE [r].[buTotal] - [r].[buVat] END [TotalProfitsPer]
						, ([r].[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) + [r].[buTotalExtra] - ( [r].[buTotalDisc] + [r].[buVat] ))
							* 100
							/ CASE WHEN ([r].[buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - [r].[buProfits]) = 0 THEN 1 ELSE ([r].[buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [r].[buTotalExtra] - [r].[buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [r].[buTotalDisc] ELSE 0 END) - [r].[buProfits]) END [TotalProfitsCostPer]
						
						,[BuType]
						,[BuNumber]	
						,[r].[buNum]
						,[r].[buDirection]
						,[r].[buNotes]
						,[r].[buCustPtr] 
						,[r].[buProfits]
						,[r].[buVat]
						,[CheckTypeGuid]
						,[r].[AffectDisc]
						,[r].[AffectExtra]
						, CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 THEN  -[r].[buTotal]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 THEN [r].[buTotal]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1  THEN -[r].[buTotal]
						    ELSE [r].[buTotal]
						  END TotalSale
						, CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 THEN  -[r].[buProfits]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 THEN [r].[buProfits]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1  THEN -[r].[buProfits]
						    ELSE [r].[buProfits]
						  END TotalProfit
						 -------------------------------------------- 
					    ,CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 THEN  -[r].[buTotalDisc]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 THEN [r].[buTotalDisc]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1  THEN -[r].[buTotalDisc]
						    ELSE [r].[buTotalDisc]
						  END TotalDisc
						  
						  ,CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 THEN  -[r].[buTotalExtra]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 THEN [r].[buTotalExtra]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1  THEN -[r].[buTotalExtra]
						    ELSE [r].[buTotalExtra]
						  END TotalExtra
						,CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 AND [r].[AffectDisc] = 1 THEN - [r].[buTotalDisc]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 AND [r].[AffectDisc] = 1 THEN [r].[buTotalDisc]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1 AND [r].[AffectDisc] = 1  THEN -[r].[buTotalDisc]
						    ELSE CASE  WHEN [r].[AffectDisc] = 1 THEN [r].[buTotalDisc] ELSE 0 END
						  END TotalDiscAffect
						,CASE 
						    WHEN @InOutNeg = 2 AND [r].[buDirection] = 1 AND [r].[AffectExtra] = 1 THEN - [r].[buTotalExtra]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] = 1 AND [r].[AffectExtra] = 1 THEN [r].[buTotalExtra]
						    WHEN @InOutNeg = 1 AND [r].[buDirection] <> 1 AND [r].[AffectExtra] = 1  THEN -[r].[buTotalExtra]
						    ELSE CASE  WHEN [r].[AffectExtra] = 1 THEN [r].[buTotalExtra] ELSE 0 END
						  END TotalExtraAffect
						  
						,[r].[FullResult]
						FROM [#Result] [r] 
						LEFT JOIN [cu000] [cu] ON [cu].[Guid] = [r].[buCustPtr] 
				WHERE [r].[UserSecurity] >= [r].[Security]	ORDER BY [cu].[customerName] 
			ELSE 
				SELECT [buFormatedNumber]
						,[buLatinFormatedNumber]
						,[buDate]
						,[buCustName]
						,[buCustLatinName]
						,[PayType]
						,[CheckTypeName]
						,[CheckTypeLatinName]
						,[buTotal]
						,[buTotalDisc]
						,[buTotalExtra]
						,[buTotal] + [buTotalExtra] - [buTotalDisc] NetSale
						,[buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - [buProfits] cost
						,[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) profit
						,[buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) + [buTotalExtra] - ( [buTotalDisc] + [buVat] ) Net
						, ([buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) + [buTotalExtra] - ( [buTotalDisc] + [buVat] ))
						   * 100
						   / CASE WHEN ( [buTotal] - [buVat] ) = 0 THEN 1 ELSE [buTotal] - [buVat] END [TotalProfitsPer]
						, ([buProfits] + (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) + [buTotalExtra] - ( [buTotalDisc] + [buVat] ))
							*100
							/CASE WHEN [buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - [buProfits] = 0 THEN 1 ELSE [buTotal] + (CASE WHEN [ExtraAffectCost] = 1 OR [ExtraAffectProfit] = 1 THEN [buTotalExtra] - [buVat] ELSE 0 END) - (CASE WHEN [DiscAffectCost] = 1 OR [DiscAffectProfit] = 1 THEN [buTotalDisc] ELSE 0 END) - [buProfits] END [TotalProfitsCostPer]
						
						,[BuType]
						,[BuNumber]
						,[buNum]
						,[buDirection]
						,[buNotes]
						,[buCustPtr]
						,[buProfits]
						,[buVat]
						,[CheckTypeGuid]
						,[AffectDisc]
						,[AffectExtra]
						, CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 THEN  -[buTotal]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 THEN [buTotal]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1  THEN -[buTotal]
						    ELSE [buTotal]
						  END TotalSale
						, CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 THEN  -[buProfits]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 THEN [buProfits]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1  THEN -[buProfits]
						    ELSE [buProfits]
						  END TotalProfit
						 
					    ,CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 THEN  -[buTotalDisc]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 THEN [buTotalDisc]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1  THEN -[buTotalDisc]
						    ELSE [buTotalDisc]
						  END TotalDisc
						  
						  ,CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 THEN  -[buTotalExtra]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 THEN [buTotalExtra]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1  THEN -[buTotalExtra]
						    ELSE [buTotalExtra]
						  END TotalExtra
						  
						  ,CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 AND [AffectDisc] = 1 THEN - [buTotalDisc]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 AND [AffectDisc] = 1 THEN [buTotalDisc]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1 AND [AffectDisc] = 1  THEN -[buTotalDisc]
						    ELSE CASE  WHEN [AffectDisc] = 1 THEN [buTotalDisc] ELSE 0 END
						  END TotalDiscAffect
						  ,CASE 
						    WHEN @InOutNeg = 2 AND [buDirection] = 1 AND [AffectExtra] = 1 THEN - [buTotalExtra]
						    WHEN @InOutNeg = 1 AND [buDirection] = 1 AND [AffectExtra] = 1 THEN [buTotalExtra]
						    WHEN @InOutNeg = 1 AND [buDirection] <> 1 AND [AffectExtra] = 1  THEN -[buTotalExtra]
						    ELSE CASE  WHEN [AffectExtra] = 1 THEN [buTotalExtra] ELSE 0 END
						  END TotalExtraAffect
						  
						,[FullResult]
				  FROM [#Result] WHERE [UserSecurity] >= [Security]	ORDER BY CASE @SortType WHEN 0 THEN [BuDate] WHEN 1 THEN [BuNum] WHEN 2 THEN [buCustName] ELSE [buProfits] END		 
	END 
	ELSE 
		SELECT 
			CASE WHEN ISNULL([Ac].[Name], '') = '' THEN [buCustName] ELSE [Ac].[Code] + '-' + [Ac].[Name] END [buCustName]
			,CASE WHEN ISNULL([Ac].[LatinName], '') = '' THEN [buCustLatinName] ELSE [Ac].[Code] + '-' + [Ac].[LatinName] END [buCustLatinName]
			,SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotal]
			,SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotalDisc] 
			,SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotalExtra]
			,SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				+ SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) 
				- SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) 
				AS [NetSale]
			, SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) + SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) - SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) - SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS cost
			, SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) + SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) AS profit
			, SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) 
			  + SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) + SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] )
				- ( SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				+ SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				) Net
			, (SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) 
			  + SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) + SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] )
				- ( SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				+ SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				))
				* 100
				/ CASE WHEN ( SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) ) = 0 THEN 1 ELSE ( SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) ) END [TotalProfitsPer]
			, (SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) 
			  + SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) - SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) + SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] )
				- ( SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				+ SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection])
				))
				* 100
				/ CASE WHEN SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) + SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) - SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) - SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) = 0 THEN 1 ELSE SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) + SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) - SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) - SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) END [TotalProfitsCostPer]
			,[buCustPtr]
			,SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buProfits],SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buVat]
			,SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) AS [DiscAffected]
			,SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) AS [ExtraAffected] 
			,SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) TotalSale
			,SUM([buProfits]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) as TotalProfit
			,SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS TotalDisc 
			,SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS TotalExtra
			,SUM( CASE WHEN AffectDisc = 1 THEN [buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc]  ELSE 0 END) AS [TotalDiscAffect] 
			,SUM( CASE WHEN AffectExtra = 1 THEN [buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra] ELSE 0 END) AS [TotalExtraAffect]
			,AVG([FullResult]) [FullResult]
		FROM [#Result] AS [r] 
		LEFT JOIN [Cu000] AS [Cu] ON [Cu].[Guid] = [buCustPtr] 
		LEFT JOIN [Ac000] AS [Ac] ON [ac].[Guid] = [buCustPtr] 
		WHERE [UserSecurity] >= [r].[Security]	AND [buCustPtr] IS NOT NULL 
		GROUP BY [buCustPtr],[buCustName], [buCustLatinName], [Ac].[Name], [Ac].[LatinName], [Ac].[Code],ISNULL(CASE @Lang WHEN 'ar' THEN [CustomerName] ELSE CASE [Cu].[LatinName] WHEN '' THEN [CustomerName] ELSE [Cu].[LatinName] END END,''),[Path] 
		ORDER BY [Path],ISNULL(CASE @Lang WHEN 'ar' THEN [CustomerName] ELSE CASE [Cu].[LatinName] WHEN '' THEN [CustomerName] ELSE [Cu].[LatinName] END END,'') 
#########################################################
CREATE PROCEDURE ARWA.repBuProfits
	-----------------Report Filters-----------------------
	@StartDate 		[DATETIME] = '1/1/2009 0:0:0.0' ,
	@EndDate 		[DATETIME] = '10/26/2012 23:59:36.257',
	@CustomerGUID 	[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@CostGUID 		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000',  
	@CurrencyGUID 	[UNIQUEIDENTIFIER] = '0177FDF3-D3BB-4655-A8C9-9F373472715A',
	@Vendor 		[FLOAT] = 0,  
	@SalesMan 		[FLOAT] = 0, 
	@SortType		[INT] = 0, 
	@AccountPtr		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@PayType		[INT] = -1, -- /* 0 ‰ﬁœ« n */  /* 1 √Ã· a */ /* 3 Ê—ﬁ… „«·Ì… „‰ Õﬁ· [CheckTypeName] OR [CheckTypeLatinName] */
	@CheckGuid		[UNIQUEIDENTIFIER] = '00000000-0000-0000-0000-000000000000', 
	@CustomerCond	VARCHAR(MAX) = '', 
	@CollectByCust	[BIT] = 0, --  Ã„Ì⁄ «·√—»«Õ Õ”» «·“»Ê‰
	@InOutNeg		[INT] = 0, 
	@ShwMainAccount	[BIT] = 0, -- ≈ŸÂ«— «·Õ”«»« 
	@Lang			VARCHAR(100) = 'ar',		--0 Arabic, 1 Latin
	@UserGuid		[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	--Guid Of Logining User
	@BranchMask		[BIGINT] = -1,
	-----------------Report Sources-----------------------
	@SourcesTypes	VARCHAR(MAX) = '8B40BBD2-BEEB-454E-B080-D61A9A907DC2,2',
	------------------------------------------------------
	@ShowTotalProfitsPer		[BIT] = 0,                  --Show [TotalProfitsPer]		‰”»… «·—»Õ «·≈Ã„«·Ì
	@ShowTotalProfitsCostPer	[BIT] = 0,                  --Show [TotalProfitsCostPer]	‰”»… «·—»Õ ·· ﬂ·›…
	@ShowBillNet				[BIT] = 0,				    --Show [Net]					’«›Ì «·›« Ê—…
	@ShowPayType				[BIT] = 0				    --Show [biPrice]				ÿ—Ìﬁ… «·œ›⁄
AS 
	SET NOCOUNT ON 
	 
	Exec [prcSetSessionConnections] @UserGuid,@Branchmask
	DECLARE @CurrencyVal FLOAT
	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE GUID = @CurrencyGUID
	CREATE TABLE [#Cust]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	INSERT INTO [#Cust]			EXEC [prcGetCustsList] 		@CustomerGUID, @AccountPtr, 0x0, @CustomerCond 
	IF ((@CustomerGUID = 0x0) AND (@AccountPtr =0X0) AND ( @CustomerCond ='')) 
		INSERT INTO [#Cust] VALUES (0X00,0) 
	SELECT [cu].*, ISNULL([AccountGuid],0X00) AS [AccountGuid]  INTO [#CustTbl] FROM [#Cust] AS [cu] LEFT JOIN [Cu000] AS [c] ON [cu].[CustGUID] = [c].[Guid] 
	IF @ShwMainAccount > 0 
		SELECT [f].[Guid],[f].[Level],[f].[Path] INTO [#Acc] FROM [dbo].[fnGetAccountsList](@AccountPtr,1) [f] 
	IF ISNULL(@CostGUID, 0x0) <> 0x0 
		EXEC [repBuProfitsWithCost] @StartDate, @EndDate, @SourcesTypes,  @CostGUID, @CurrencyGUID, @CurrencyVal, @Vendor, @SalesMan, @SortType ,@PayType,@CheckGuid,@CollectByCust,@InOutNeg,@ShwMainAccount 
	ELSE  
		EXEC [repBuProfitsNoCost]	@StartDate, @EndDate, @SourcesTypes, @CurrencyGUID, @CurrencyVal, @Vendor, @SalesMan, @SortType,@PayType,@CheckGuid,@CollectByCust,@InOutNeg,@ShwMainAccount 
	DELETE [Connections] WHERE SPID = @@SPID
#########################################################
CREATE PROCEDURE ARWA.RepBudget
	@StartDate 					DATETIME = '12/25/2000 0:0:0.0',			-- „‰  «—ÌŒ	
	@EndDate 					DATETIME = '12/18/2012 23:59:59.677',			-- ≈·Ï  «—ÌŒ
	@CurrencyGUID				UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',	-- «·⁄„·…	
	@JobCostGUID 				UNIQUEIDENTIFIER ='00000000-0000-0000-0000-000000000000',	-- „ﬂ—ﬂ“ «·ﬂ·›…
	@StoreGUID					UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',	-- «·„” Êœ⁄  	 
	@FinalAccount				UNIQUEIDENTIFIER ='68C4D21F-7019-4959-9E79-A03A29A140BD',	-- «·Õ”«» «·Œ «„Ì  
	@DetailSubStores			Bit =0,				--  ÷„Ì‰ «·„” Êœ⁄«  «·›—⁄Ì…
	@PriceType					INT =0,				-- «·”⁄—,
	--  ﬂ·›… 2, Ã„·… 4, ’› «·Ã„·… 8, «· ’œÌ— 16, «·„Ê“⁄ 32, «·„›—ﬁ 64,«·„” Â·ﬂ 128
	@PricePolicy				INT =0,				-- ”Ì«”…  ÕœÌœ ”⁄— «·»÷«⁄…
	-- «·”⁄— «·√⁄Ÿ„Ì 120, 121 «·Ê”ÿÌ, 122 «Œ— ‘—«¡, 124 «Œ— ‘—«¡ „⁄ «·Õ”„Ì«  Ê«·«÷«›« , 125 «·Ê«—œ √Ê·« ’«œ— √Ê·«, «› —«÷Ì 120
	@ShowFinalAccountDetails	BIT =0,				--  ›’Ì· «·Õ”«»«  «·Œ «„Ì…
	@ShowPosted					BIT =0,				-- ≈ŸÂ«— ”‰œ«  €Ì— «·„—Õ·…
	@ShowUnposted				BIT=0,				-- ≈ŸÂ«— ”‰œ«  €Ì— «·„—Õ·…
	@CurrencyRateType			INT = 0,			-- ‰Ê⁄ «· ⁄«œ·° 0 ﬂ·›…  «—ÌŒÌ…° 1 ﬂ·›… Õ«·Ì…
	@AccountLevel				INT = 0,			-- «·„” ÊÏ 
	@HavePriceBySN				BIT = 0,			--  ﬁÌÌ„ «·„Œ“Ê‰ Õ”» Ã—œ «·√—ﬁ«„ «· ”·”·Ì…
	@UserGUID					UNIQUEIDENTIFIER	= 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',	-- Guid Of Logining User
	@Lang						VARCHAR(100) = 'ar',		
	@BranchMask					BIGINT = 9223372036854775807-- Mask for current branches
	--@FinalAccountDescription	VARCHAR(MAX) = '',	-- Ê’› «·Õ”«»	
	--@CurrencyDescription		VARCHAR(MAX) = '',	-- Ê’› «·⁄„·… 			
	--@JobCostDescription			VARCHAR(MAX) = '',	-- Ê’› „—ﬂ“ «·ﬂ·›…		
	--@StoreDescription			VARCHAR(MAX) = ''	-- Ê’› «·„” Êœ⁄ 
AS     
	--- 1 posted, 0 unposted -1 both        
	DECLARE @CurrencyValue AS  Float 
	DECLARE @PostedType AS  INT 
	DECLARE @TypeAccGuid1  [UNIQUEIDENTIFIER] 
	DECLARE @TypeAccGuid2  [UNIQUEIDENTIFIER]  
	DECLARE @Level INT, @MaxLevel INT    
	DECLARE @FinalType	BIT  
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 0) )		          
		SET @PostedType = 1       
	IF( (@ShowPosted = 0) AND (@ShowUnposted = 1))          
		SET @PostedType = 0       
	IF( (@ShowPosted = 1) AND (@ShowUnposted = 1))          
		SET @PostedType = -1       
	SET NOCOUNT ON	  
	DECLARE  
		@UserSec  [INT], 
		@AccSec	  [INT], 
		@RecCnt	  [INT]     
	IF @CurrencyRateType = 1 
		SELECT TOP 1 @CurrencyGUID = [Guid] FROM [my000] WHERE CurrencyVal = 1 

	-- User Security on entries     
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)     
	-- User Security on Browse Account 
	SET @AccSec = dbo.fnGetUserAccountSec_Browse(@UserGUID)     
	 
	 EXEC [prcSetSessionConnections] @UserGUID, @BranchMask
	 
	-- Security Table ------------------------------------------------------------     
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)    
	DECLARE @NumOfSecViolated BIT
		SET  @NumOfSecViolated = 0
		
	--================================================================= 
	--  AccList Sorted     
	--================================================================= 
	CREATE TABLE [#AccountsList]     
	(     
		[guid]		[UNIQUEIDENTIFIER],      
		[level]		[INT],     
		[path]		[VARCHAR](5000) COLLATE ARABIC_CI_AI     
	)    
	--====================================================================  
	CREATE TABLE [#FinalResult] 
	(        
		[acGUID]			[UNIQUEIDENTIFIER],     
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		--[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acFinal]			[UNIQUEIDENTIFIER],     
		[acParent]			[UNIQUEIDENTIFIER],     
		[DebitOrCredit]		[BIT]	DEFAULT 0,  -- IsDebit   
		[acCurPtr]			[UNIQUEIDENTIFIER],     
		[acCurVal]			[FLOAT] DEFAULT 0, 	     
		[Debit] 			[FLOAT] DEFAULT 0,      
		[Credit] 			[FLOAT] DEFAULT 0,      
		[CurDebit] 			[FLOAT] DEFAULT 0,      
		[CurCredit] 		[FLOAT] DEFAULT 0,     
		[Level]				[INT]	DEFAULT 0,     
		[Path] 				[VARCHAR](5000) COLLATE ARABIC_CI_AI,    
		[RecType] 			[INT] DEFAULT 0, -- 0 Acc, 1 ParentAcc, 2 FinalAcc     
		[fn_AcLevel]		[INT],	-- OrderID for The FinalAcc 
		[FLAG]				[INT], 
		[IsFinalAccount]	[BIT] DEFAULT 0,
		--ParentAccountName	[VARCHAR](250) COLLATE ARABIC_CI_AI,
		FinalAccountName	[VARCHAR](250) COLLATE ARABIC_CI_AI,
		--[Id]				[INT]
		FinalAccountIdentity [INT]
	)      
	 
	CREATE TABLE [#EResult] 
	(        
		[acGUID]		[UNIQUEIDENTIFIER],     
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		--[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,     
		[acFinal]			[UNIQUEIDENTIFIER],     
		[acParent]			[UNIQUEIDENTIFIER],     
		[DebitOrCredit]		[INT]	DEFAULT 0,     
		[acCurPtr]			[UNIQUEIDENTIFIER],     
		[acCurVal]			[FLOAT] DEFAULT 0, 	     
		[Debit] 			[FLOAT] DEFAULT 0,      
		[Credit] 			[FLOAT] DEFAULT 0,      
		[CurDebit] 			[FLOAT] DEFAULT 0,      
		[CurCredit] 		[FLOAT] DEFAULT 0,     
		[Level]				[INT]	DEFAULT 0,     
		[Path] 				[VARCHAR](5000) COLLATE ARABIC_CI_AI,    
		[RecType] 			[INT] DEFAULT 0,	-- = 0 Acc  =1 ParentAcc = 2 FinalAcc     
		[Security]			[INT],     
		[AccSecurity]		[INT],     
		[UserSecurity] 		[INT], 
		[fn_AcLevel]		[INT],		-- OrderID for The FinalAcc 
		[Flag]				[INT], 
		[DFlag]				[INT], 
		[ID]				[INT] 
	) 
	--================================================================= 
	CREATE TABLE #FinalAccTbl 
	(  
		[ID]				[INT] IDENTITY(1,1), 
		[AcGuid]			[UNIQUEIDENTIFIER],  
		[AcCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,  
		[AcCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,  
		[AcFinal]			[UNIQUEIDENTIFIER],  
		[AcParent]			[UNIQUEIDENTIFIER],  
		[DebitOrCredit]		[INT],  
		--[Balance]			[FLOAT],
		[AcCurPtr] 			[UNIQUEIDENTIFIER],  
		[AcCurVal]			[FLOAT],  
		[AccSecurity]		[INT],  
		[Level]				[INT]	  
	)       
	--================================================================== 
	-- ·« Ì„ﬂ‰ «” Œœ«„ prcgetAccountslist     
	-- ·√‰Â ·« Ì√Œ– «·›—“     
	INSERT INTO #AccountsList     
	SELECT     
		[guid],     
		[level],     
		[path]     
	FROM      
		[fnGetAccountsList]( null, 1) 
	 
	--================================================================= 
	--====================== Calc Acc Goods =========================== 
	--================================================================= 
	DECLARE @ShowUnLinked INT, @UseUnit INT, @DetailsStores	INT  
	DECLARE @MatGUID UNIQUEIDENTIFIER, @GroupPtr  UNIQUEIDENTIFIER, @SrcTypes UNIQUEIDENTIFIER  
	DECLARE @MatType INT 
	DECLARE @FirstPeriodStGUID UNIQUEIDENTIFIER  
	 
	SET @MatGUID = 0x0 
	SET @GroupPtr = 0x0 
	SET @SrcTypes = 0x0 
	SET @MatType = 0 
	SET @ShowUnLinked = 0  
	SET @UseUnit = 0  
	SET @DetailsStores = 1  
	 
	-- Creating temporary tables  ----------------------------------------------------------  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#MatTbl2]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl]([StoreGUID] UNIQUEIDENTIFIER, [Security] INT)   
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)   
	 
	--Filling temporary tables   
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] @MatGUID, @GroupPtr,257  
	 
	IF  @HavePriceBySN > 0 
	BEGIN 
		INSERT INTO [#MatTbl2] SELECT *  from [#MatTbl] 
		DELETE [#MatTbl] FROM [#MatTbl] mt INNER JOIN mt000 m ON m.Guid = mt.[MatGUID] WHERE  m.SnFlag > 0 
		 
	END 
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypes 
	IF (@DetailSubStores = 1) 
		INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] @StoreGUID 
	ELSE 
		INSERT INTO [#StoreTbl] SELECT [stGuid],[stSecurity] FROM vwSt WHERE ISNULL(@StoreGUID,0X00) = 0X00 OR  [stGuid] = @StoreGUID 
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] @JobCostGUID   
	 
	--Get Qtys  
	CREATE TABLE [#t_Qtys]  
	(  
		[MatGUID] 	[UNIQUEIDENTIFIER],  
		[Qnt] 		[FLOAT],  
		[Qnt2] 		[FLOAT],  
		[Qnt3] 		[FLOAT],  
		[StoreGUID]	[UNIQUEIDENTIFIER]  
	)  
	 
	CREATE TABLE #t_AccGoods   
	(   
		[acGUID]			[UNIQUEIDENTIFIER],   
		[acQty]				[FLOAT], 
		[acPrice]			[FLOAT],	 
		[StoreGUID]			[UNIQUEIDENTIFIER], 
		[AccType]			[INT]		-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—…	   
	)   
	 
	CREATE TABLE [#t_Goods]   
	(   
		[acGUID]			[UNIQUEIDENTIFIER],   
		[acCodeName]		[VARCHAR](500) COLLATE ARABIC_CI_AI,   
		[acCodeLatinName]	[VARCHAR](500) COLLATE ARABIC_CI_AI,   
		[acFinal]			[UNIQUEIDENTIFIER],   
		[acParent]			[UNIQUEIDENTIFIER],   
		[acCurPtr]			[UNIQUEIDENTIFIER],   
		[acCurVal]			[FLOAT],   
		[Balance]			[FLOAT], 
		[AccType]			[INT],-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—… 
		[acSecurity]		[INT]			   
	)   
	 
	CREATE TABLE [#MatAccount]   
	( 
		[MatGUID]	UNIQUEIDENTIFIER,	   
		[MatAccGUID] UNIQUEIDENTIFIER, 
		[AccType]		INT 
	) 
	CREATE TABLE [#T_RESULT] 
	( 
		[acGUID] UNIQUEIDENTIFIER, 
		[Flag] INT DEFAULT 0 
	) 
	CREATE TABLE [#t_Prices]  
	(  
		[MatGUID] 	[UNIQUEIDENTIFIER],  
		[Price] 	[FLOAT]  
	)  
	CREATE TABLE #PricesQtys  
	(  
		[MatGUID]	[UNIQUEIDENTIFIER],  
		[Price]		[FLOAT],  
		[Qnt]		[FLOAT],  
		[StoreGUID]	[UNIQUEIDENTIFIER] 
	)  
	-- First Period 
	DECLARE @DelPrice [BIT],@FBDate	DATETIME,@StDate DATETIME 
	INSERT INTO [#FinalAccTbl] ([AcGuid],[AcCodeName],[AcCodeLatinName],[AcFinal],[AcParent],[DebitOrCredit],[AcCurPtr],[AcCurVal],[AccSecurity],[Level]) 
		SELECT  
			[acGUID],  
			[acCode] + '-'+ [acName],  
			[acCode] + '-'+ [acLatinName],  
			[acFinal],	  
			[acParent],  
			[acDebitOrCredit], 
			[acCurrencyPtr],    
			[acCurrencyVal],  
			[acSecurity],  
			[Level]  
		FROM  
			[fnGetAccountsList]( @FinalAccount,1) AS [al] INNER JOIN [vwAc]  
			ON [al].[GUID] = [acGUID]  
		ORDER BY [path]  
	--======================================================================== 
	 
	SELECT @FBDate = dbo.fnDate_Amn2Sql(value) FROM op000 WHERE NAME = 'AmnCfg_FPDate' 
	IF (@FBDate < @StartDate) 
	BEGIN 
		IF NOT EXISTS( SELECT * FROM BT000 where TYPE = 2 AND SORTNUM = 2) 
			SET @FinalType = 0 
		ELSE 
		BEGIN 
			INSERT INTO #MatAccount([MatAccGUID]) SELECT DefBillAccGUID FROM BT000 where TYPE = 2 AND SORTNUM = 2 AND DefBillAccGUID <> 0x00 
			INSERT INTO #MatAccount([MatAccGUID]) 
				SELECT [MatAccGUID] 	FROM [ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
						WHERE  	[ma].[Type] = 1  AND [btSortNum] = 2 AND [btType] = 2 AND  [MatAccGUID] <> 0X00 
			 
			IF NOT EXISTS( SELECT * FROM #MatAccount A inner join ac000 b on b.guid = [MatAccGUID] WHERE finalGuid = @FinalAccount )-- INNER JOIN [#FinalAccTbl] F ON f.acGuid = b.finalGuid) 
				SET @FinalType = 1 
			ELSE 
				SET @FinalType = 0 
			TRUNCATE TABLE #MatAccount 
		END  
	END  
	ELSE  
		SET  @FinalType = 0 
	SET @DelPrice = 1 
	DECLARE		@FPStDate DATETIME 
	SET @FPStDate = @StartDate 
	IF @FinalType = 1 
	BEGIN 
		SET @FPStDate = '1/1/1980' 
		SET @StDate = DATEADD(day,-1,@StartDate) 
		EXEC [prcGetQnt]  
			'1/1/1980',@StDate, 
			@MatGUID, @GroupPtr,  
			@StoreGUID, @JobCostGUID,  
			@MatType, @DetailsStores,  
			@SrcTypes, @ShowUnLinked  
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
			EXEC [prcGetLastPrice] '1/1/1980',@StDate, @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
			EXEC [prcGetMaxPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
			EXEC [prcGetAvgPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @ShowUnLinked, @UseUnit  
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
			EXEC [prcGetLastPrice] '1/1/1980',@StDate , @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType,	@CurrencyGUID, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
		ELSE IF @PriceType = 2 AND @PricePolicy = 125 
			EXEC [prcGetFirstInFirstOutPrise] '1/1/1980',@StDate,@CurrencyGUID	 
		ELSE 
		BEGIN  
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3 
			SET @DelPrice = 0 
		END  
		INSERT INTO [#PricesQtys] 
		SELECT  
			[q].[MatGUID],  
			ISNULL([p].[Price],0),  
			ISNULL([q].[Qnt],0),  
			[q].[StoreGUID]  
		FROM  
			[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID]  
		IF  @HavePriceBySN > 0 
		BEGIN 
			INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price])  
				EXEC repMatSNBSheet @CurrencyGUID, 0x00, '1/1/1980',@StDate 
		END 
		INSERT INTO #MatAccount		   		 
			SELECT					   		 
				[ObjGUID],			    
				[MatAccGUID], 
				0 
			FROM      
				[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
			WHERE   
				[ma].[Type] = 1    
				AND [btSortNum] = 1		-- »÷«⁄… √Ê· „œ… 
				AND [btType] = 2 
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 1  
		INSERT INTO #t_AccGoods 
		SELECT   
			ISNULL([mAcc].[MatAccGUID], @TypeAccGuid2), 
			[Pq].[Qnt], 
			[Pq].[Price], 
			0X00, 
			-1	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄«  
		FROM 
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc]  
			ON [Pq].[MatGUID] = [mAcc].[MatGUID]  
		INSERT INTO [#t_Goods]   
		SELECT  
			ISNULL([tg].[acGUID],0x0), 
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
			ISNULL([acFinal],0x0), 
			ISNULL([acParent],0x0), 
			ISNULL([acCurrencyPtr],0x0), 
			ISNULL([acCurrencyVal], 1)l, 
			SUM(ISNULL(acQty * acPrice, 0)), 
			0, 
			[acSecurity] 
		FROM  
			[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID] 
		GROUP BY 
			ISNULL([tg].[acGUID],0x00), 
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
			ISNULL([acFinal],0x00), 
			[acParent], 
			[acCurrencyPtr], 
			[acCurrencyVal], 
			[acSecurity] 
		INSERT INTO #MatAccount([MatAccGUID]) SELECT @TypeAccGuid2 
		 
	------------------------------------------------------ 
		EXEC [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods] 
		
		IF EXISTS(SELECT * FROM #secviol)
			SET @NumOfSecViolated = 1
		
		--»÷«⁄… √Ê· «·„œ… 
		INSERT INTO #EResult     
		SELECT       
			[t].[acGUID],     
			CASE @Lang WHEN 'ar' THEN [t].[AcCodeName] 
				ELSE CASE [t].[AcCodeLatinName] WHEN '' THEN [t].[AcCodeName] ELSE [t].[AcCodeLatinName] END 
			END,
			--[t].[AcCodeLatinName],     
			[t].[acFinal],     
			[t].[acParent], 
			0,  
			[t].[acCurPtr],      
			[t].[acCurVal],       
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END,  
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END,  
			0,0, 
			[al].[level] + 1,     
			[al].[path],     
			0,     
			1,      
			1,      
			@UserSec, 
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			CASE WHEN ([t].[acFinal] = @FinalAccount) OR (@ShowFinalAccountDetails = 1)  THEN 1 ELSE 0 END, 
			[f].[Id] 
		FROM     
			[#t_Goods] AS [t] 
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal] 
	 
		IF @DelPrice > 0  
			TRUNCATE TABLE 	[#t_Prices]  
		TRUNCATE TABLE  [#t_Qtys] 
		TRUNCATE TABLE  [#PricesQtys] 
		TRUNCATE TABLE #t_AccGoods 
		TRUNCATE TABLE [#t_Goods] 
	END	 
	 
	EXEC [prcGetQnt]  
	@FPStDate,@EndDate, 
	@MatGUID, @GroupPtr,  
	@StoreGUID, @JobCostGUID,  
	@MatType, @DetailsStores,  
	@SrcTypes, @ShowUnLinked  
	 
	--8 Get last Prices  
	 
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice  
		EXEC [prcGetLastPrice] @FPStDate,@EndDate, @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
		EXEC [prcGetMaxPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice  
		EXEC [prcGetAvgPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @ShowUnLinked, @UseUnit  
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount 
		EXEC [prcGetLastPrice] @FPStDate , @EndDate , @MatGUID, @GroupPtr, @StoreGUID, @JobCostGUID, @MatType,	@CurrencyGUID, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/ 
	ELSE IF @PriceType = 2 AND @PricePolicy = 125 
		EXEC [prcGetFirstInFirstOutPrise] @FPStDate , @EndDate,@CurrencyGUID	 
	ELSE  
	BEGIN 
		IF @FinalType = 0 
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurrencyGUID, @CurrencyValue, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3  
	END 
	 
	---- Get Qtys And Prices  
	 
	 
	-- you must use left join cause if details stores you have more than one record for each mat  
	INSERT INTO [#PricesQtys] 
	SELECT  
		[q].[MatGUID],  
		ISNULL([p].[Price],0),  
		ISNULL([q].[Qnt],0),  
		[q].[StoreGUID]  
	FROM  
		[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID]  
	IF  @HavePriceBySN > 0 
	BEGIN 
		INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price])   
			EXEC repMatSNBSheet @CurrencyGUID, 0x00, @FPStDate , @EndDate 
	END 
	 
	-- Add MatAccount in ma  
	-------------------------------------------------- 
	-- »÷«⁄… ¬Œ— „œ… («·„Ì“«‰Ì…) 
	-------------------------------------------------- 
	INSERT INTO #MatAccount 
		SELECT  
			[ObjGUID], 
			[MatAccGUID], 
			1 
		FROM      
			[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
		WHERE   
			[ma].[Type] = 1    
			AND [btSortNum] = 2		-- »÷«⁄… ¬Œ— „œ… 
			AND [btType] = 2 
	 
	-------------------------------------------------- 
	 -- »÷«⁄… ¬Œ— «·„œ… («·„ «Ã—…) 
	-------------------------------------------------- 
	INSERT INTO [#MatAccount] 
		SELECT  
			[ObjGUID], 
			[DiscAccGUID], 
			2		 
		FROM      
			[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
		WHERE   
			[ma].[Type] = 1   		-- Material Only 
			AND [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ… 
			AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ… 
	 
	INSERT INTO #t_AccGoods 
		SELECT   
			ISNULL([mAcc].[MatAccGUID], 0x0), 
			[Pq].[Qnt], 
			CASE ISNULL([AccType], 1) WHEN 1 THEN [Pq].[Price] 
			WHEN 2 THEN [Pq].[Price] * -1 END, 
			ISNULL([Pq].[StoreGUID], 0x0), 
			ISNULL([AccType], 0)	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄«  
		FROM 
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc]  
			ON [Pq].[MatGUID] = [mAcc].[MatGUID]  
	 
	 
	-- ”Ì „  ﬂ—«— ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… «·€Ì— „ÊÃÊœ… ›Ì Õ”«»«  «·„Ê«œ „‰ √Ã· «·„ «Ã—…  
	INSERT INTO [#t_AccGoods] 
		SELECT   
			[acGUID],   
			[acQty], 
			[acPrice],	 
			[StoreGUID], 
			-1 
		FROM  
			[#t_AccGoods] ac 
		WHERE [ac].[AccType] = 0 
	 
		 
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„ «Ã—… 
	IF (@DetailSubStores = 0 )-- AND (@StoreGUID <> 0X0) 
	BEGIN 
		UPDATE [t] 
		SET   
			[AcGUID] = ISNULL([st].[AccountGuid],0x00), 
			[acPrice] = -1 * [acPrice] 
		FROM  [#t_AccGoods] AS [t] INNER JOIN [st000] AS [st] ON [st].[Guid] = [t].[StoreGUID] 
		WHERE    
				[t].[AcGUID] = 0x00 AND [t].[AccType] = -1 AND ISNULL([st].[AccountGuid],0x00) <> 0x00 
		 
		 
	END  
	SELECT @TypeAccGuid1 = [bt].[btDefDiscAcc]  FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2  
	UPDATE [#t_AccGoods] 
		SET   
			[AcGUID] = @TypeAccGuid1,   
			 
			[acPrice] = -1 * [acPrice] 
		WHERE    
			[#t_AccGoods].[AcGUID] = 0x0 AND [#t_AccGoods].[AccType] = -1 
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2  
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„Ì“«‰Ì… 
		UPDATE [#t_AccGoods] 
		SET   
			[AcGUID] =  @TypeAccGuid2 
			 
		WHERE    
			[#t_AccGoods].[AcGUID] = 0x0 
	--================================================================= 
	--========================= END Calc AccGoods ===================== 
	--================================================================= 
	INSERT INTO [#t_Goods]   
	SELECT  
		ISNULL([tg].[acGUID],0x0), 
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
		ISNULL([acFinal],0x0), 
		ISNULL([acParent],0x0), 
		ISNULL([acCurrencyPtr],0x0), 
		ISNULL([acCurrencyVal], 1)l, 
		SUM(ISNULL(acQty * acPrice, 0)), 
		0, 
		[acSecurity] 
	FROM  
		[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID] 
	GROUP BY 
		[tg].[acGUID], 
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''), 
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''), 
		[acFinal], 
		[acParent], 
		[acCurrencyPtr], 
		[acCurrencyVal], 
		[acSecurity] 
	------------------------------------------------------ 
	EXEC [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods] 
	
	IF EXISTS(SELECT * FROM #secviol)
		SET @NumOfSecViolated = 1
	--================================================================= 
	--Get List of sorted final Accounts 
	 
	CREATE CLUSTERED INDEX [find] ON [#FinalAccTbl]([acGUID]) 
	--======================================================================== 
	EXEC [prcCheckSecurity] @UserGUID, 0, 0, [#FinalAccTbl]	 
	IF EXISTS(SELECT * FROM #secviol)
		SET @NumOfSecViolated = 1
	-- ÌÕÊÌ ‘Ã—… Õ”«»«  „— »…   «»⁄… ·Õ”«» ›—⁄Ì ÌŒ „ »«·Õ”«» «·Œ «„Ì «·„Õœœ     
	-- sotrted AccList contains parentAcc & SubAccount for a specific final Acc      
	 
	DECLARE @MinLevel INT 
	SELECT 	@MinLevel = MIN([level]) FROM   [#AccountsList] 
	if 	@MinLevel > 0 
		UPDATE [#AccountsList] SET [level] = [level] - @MinLevel 
	SELECT       
			[al].[GUID],		     
			[ac].[acCode] + '-' + [ac].[acName] AS [acCodeName],     
			[ac].[acCode] + '-' + [ac].[acLatinName] AS [acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			[al].[level] AS [acLevel],     
			[al].[path],     
			[ac].[acSecurity],     
			[f].[Level] AS fLevel,   -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
			[f].[Id] 
		INTO 	[#AccountsTree] 
		FROM 
			[#AccountsList] AS [al]   
			INNER JOIN [vwAc] AS [ac] ON [al].[GUID] = [ac].[acGUID] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [ac].[acFinal] 
	 
	CREATE CLUSTERED INDEX InAccTree ON [#AccountsTree]([GUID]) 
	--================================================================ 
	SELECT  
		[ce].[ceSecurity], 
		CASE @Lang WHEN 'ar' THEN [acCodeName] 
			ELSE CASE [acCodeLatinName] WHEN '' THEN [acCodeName] ELSE [acCodeLatinName] END
		END AS acCodeName, 
		--[acCodeLatinName],  
		[en].[AccountGuid],  
		[en].[Date] AS EnDate,  
		[en].[Debit] AS [EnDebit],  
		[en].[Credit]AS [EnCredit],  
		[en].[CurrencyGuid],  
		[en].[CurrencyVal], 
		[al].[acFinal],     
		[al].[acParent],  
		[al].[acDebitOrCredit],     
		[al].[acCurrencyPtr],     
		[al].[acCurrencyVal], 	     
		[al].[acLevel],     
		[al].[path],     
		[al].[fLevel], 
		[al].[acSecurity],  
		[dbo].[fnCurrency_fix](1, [en].[CurrencyGuid], [en].[CurrencyVal], @CurrencyGUID, [en].[Date]) AS [CurFact], 
		CASE [al].[acCurrencyPtr]      
				WHEN @CurrencyGUID THEN 0      
				ELSE       
					CASE [en].[CurrencyGuid]       
						WHEN [al].[acCurrencyPtr] THEN [en].[Debit] / [en].[CurrencyVal]    	         
						ELSE 0       
					END         
		END AS [DebitCurAcc],      
		CASE [al].[acCurrencyPtr]      
			WHEN @CurrencyGUID THEN 0     
			ELSE     
				CASE [en].[CurrencyGuid]       
					WHEN [al].[acCurrencyPtr]   THEN [en].[Credit] / [en].[CurrencyVal]      
					ELSE 0     
				END        
		END AS [CreditCurAcc], 
		CASE WHEN ([acFinal] = @FinalAccount) OR (@ShowFinalAccountDetails = 1)  THEN 1 ELSE 0 END AS [DFlag], 
		[ID]     
	INTO #RES2 
	FROM  
		[vwce] as [ce]  
		INNER JOIN [en000] AS en ON en.ParentGuid = ce.ceGuid 
		INNER JOIN [#AccountsTree] AS [al] ON [al].[GUID] = [en].[AccountGuid] 
	WHERE      
			[En].[Date] BETWEEN @StartDate AND @EndDate      
			AND ( (@JobCostGUID = 0x0) OR ([en].[CostGuid] IN (SELECT CostGUID FROM #CostTbl) ) )     			 
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND ceIsPosted = 1)        
				OR (@PostedType = 0 AND [ceIsPosted] = 0) )   
	--================================================================ 
	INSERT INTO [#EResult]     
		SELECT       
			[AccountGuid],     
			[acCodeName],     
			--[acCodeLatinName],     
			[acfinal],     
			[acParent],  
			[acDebitOrCredit],     
			[acCurrencyPtr],      
			[acCurrencyVal],       
			SUM([EnDebit]*[CurFact]),     
			SUM([EnCredit]*[CurFact]),     
			SUM([DebitCurAcc]),      
			SUM([CreditCurAcc]),      
			[aclevel] + 1,     
			[path],     
			0,     
			[ceSecurity],      
			[acSecurity],      
			@UserSec, 
			[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			[DFlag], 
			[ID]  
		FROM     
			[#Res2] 
		GROUP BY  
			[AccountGuid],     
			[acCodeName],     
			--[acCodeLatinName],     
			[acfinal],     
			[acParent],  
			[acDebitOrCredit],     
			[acCurrencyPtr],      
			[acCurrencyVal],       
			[aclevel],     
			[path],     
			[ceSecurity],      
			[acSecurity],      
			[fLevel], 
			[DFlag], 
			[ID]    
	--------------------------------------------------------------- 
	-- ≈÷«›… »÷«⁄… ¬Œ— «·„œ… 
	--------------------------------------------------------------- 
	INSERT INTO #EResult     
		SELECT       
			[t].[acGUID], 
			CASE @Lang WHEN 'ar' THEN [t].[AcCodeName] 
				ELSE CASE [t].[AcCodeLatinName] WHEN '' THEN [t].[AcCodeName] ELSE [t].[AcCodeLatinName] END 
				END,
			--[t].[AcCodeLatinName],     
			[t].[acFinal],     
			[t].[acParent], 
			0,  
			[t].[acCurPtr],      
			[t].[acCurVal],       
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END,  
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END,  
			0,0, 
			[al].[level] + 1,     
			[al].[path],     
			0,     
			1,      
			1,      
			@UserSec, 
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«» 
			0, 
			CASE WHEN ([t].[acFinal] = @FinalAccount) OR (@ShowFinalAccountDetails = 1)  THEN 1 ELSE 0 END, 
			[f].[Id] 
		FROM     
			[#t_Goods] AS [t] 
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid] 
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal] 
	 
	--======================================================================= 
			 
	INSERT INTO [#FinalResult]		 
	SELECT 
		finalAc.[AcGuid], 
		CASE WHEN @Lang = 'ar' 
			THEN finalAc.[acCodeName] 
			ELSE CASE WHEN finalAc.[acCodeLatinName] = '' THEN finalAc.[acCodeName] ELSE finalAc.[acCodeLatinName] END
		END,		 
		--finalAc.[acCodeName], 
		--finalAc.[acCodeLatinName], 
		0x0, 
		finalAc.[acParent], 
		finalAc.[DebitOrCredit], 
		finalAc.[AcCurPtr], 
		finalAc.[AcCurVal], 
		0,0,0,0,		  
		0, 0, 2, 
		finalAc.[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
		0, 
		1, -- IsFinalAccount
		--CASE WHEN @Lang = 'ar' THEN ac.[Name] ELSE ac.[LatinName] END,
		CASE WHEN @Lang = 'ar' THEN ISNULL(ac.[Name], '') ELSE ISNULL(ac.[LatinName], '') END,
		finalAc.[id] 
	FROM [#FinalAccTbl] AS finalAc
	--INNER JOIN ac000 AS ac ON ac.[GUID] = finalAc.AcGuid
	LEFT JOIN ac000 AS ac ON ac.[GUID] = finalAc.AcParent
	WHERE  
		[AcGuid] <> @FinalAccount 
	SELECT @MaxLevel = MAX([Level]) FROM [#EResult] WHERE [DFlag] =1 
	--Balnced Account 
	INSERT INTO [#T_RESULT] 
	SELECT [acGUID],CASE WHEN ABS(ISNULL(SUM([Debit]),0)- ISNULL(SUM(Credit),0))> dbo.fnGetZeroValuePrice() THEN 1 ELSE 0 END  
	FROM  [#EResult] 
	WHERE [DFlag] =1 
	GROUP BY [acGUID] 
	 
	UPDATE [#EResult] SET [Flag] = [t].[Flag] 
	FROM [#EResult] AS [r] INNER JOIN [#T_Result] AS [t] ON [r].[acGUID] =[t].[acGUID] 
	WHERE [r].[DFlag] =1  
	 
	SET @Level = @MaxLevel  
	------------------------------------------------------------ 
	EXEC [prcCheckSecurity] @Result = '#EResult'
	IF EXISTS(SELECT * FROM #secviol)
		SET @NumOfSecViolated = 1
	------------------------------------------------------------ 
	WHILE @Level >= 0 
	BEGIN  
		INSERT INTO [#EResult]      
		SELECT       
			[r].[acParent],		     
			CASE @Lang WHEN 'ar' THEN [ac].[acCodeName] 
				ELSE CASE [ac].acCodeLatinName WHEN '' THEN [ac].[acCodeName] ELSE [ac].acCodeLatinName END
			END,       
			--[ac].[acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			SUM(IsNULL([Debit],0)),      
			SUM(IsNULL([Credit],0)),      
			SUM(IsNULL([CurDebit],0)),      
			SUM(IsNULL([CurCredit],0)),     
			[ac].[aclevel] + 1,     
			[ac].[path],     
			1,     
			1,	-- ’·«ÕÌ… «·”‰œ«      
			[ac].[acSecurity],     
			@UserSec, 
			[ac].[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									     
			SUM([Flag]), 
			CASE WHEN ([ac].[acFinal] = @FinalAccount) OR (@ShowFinalAccountDetails = 1)  THEN 1 ELSE 0 END, 
			[ac].[id] 
		FROM 
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] = [ac].[acFinal]  
		WHERE  
			[r].[Level] = @Level AND [r].[DFlag] = 1   
		GROUP BY 
			[r].[acParent], 
			CASE @Lang WHEN 'ar' THEN [ac].[acCodeName] 
				ELSE CASE [ac].acCodeLatinName WHEN '' THEN [ac].[acCodeName] ELSE [ac].acCodeLatinName END
			END,       
			--[ac].[acCodeLatinName],     
			[ac].[acFinal],     
			[ac].[acParent],  
			[ac].[acDebitOrCredit],     
			[ac].[acCurrencyPtr],     
			[ac].[acCurrencyVal], 	     
			[ac].[aclevel],     
			[ac].[path],      
			[ac].[acSecurity], 
			[ac].[fLevel], 
			[ac].[id]  
		 
		UPDATE [r] 
			SET [Level] = @Level - 1,[acParent] = [ac].[acParent] 
		FROM 
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] <> [ac].[acFinal] 
		WHERE  
			[r].[Level] = @Level AND [r].[DFlag] = 1  
			  
		SET @Level = @Level - 1    
	END	 
	------------------------------------------------------------ 
	UPDATE [#EResult] SET [Level] = 1,[acParent] = 0X00 WHERE [acParent] <> 0X00 AND [acParent] NOT IN (SELECT  [GUID] FROM [#AccountsTree]) 
	SELECT @MaxLevel = ISNULL(MAX([ac].[Level]),0) 
	FROM 
			[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1 
		WHERE  
			[r].[DFlag] = 1    
	SET @Level = 0 
	IF @MaxLevel > 0 
	BEGIN 
		WHILE @Level <= @MaxLevel 
		BEGIN  
			UPDATE [r] 
				SET [Level] = [ac].[Level] + 1 
			FROM 
				[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1 
			WHERE  
				[ac].[Level] = @Level AND [r].[DFlag] = 1    
			SET @Level = @Level + 1    
		END	 
	END 
	------------------------------------------------------------ 
	INSERT INTO [#FinalResult] 
	SELECT     
		er.[acGUID],
		--CASE WHEN @Lang = 'ar' 
		--	THEN er.[acCodeName] 
		--	ELSE CASE WHEN er.[acCodeName] = '' THEN er.[acCodeName] ELSE er.[acCodeLatinName] END
		--END,		    
		er.[acCodeName],    
		--er.[acCodeLatinName],    
		er.[acFinal],    
		er.[acParent],  
		er.[DebitOrCredit],     
		er.[acCurPtr],     
		er.[acCurVal],     
		SUM( ISNULL(er.[Debit],0) ),    
		SUM( ISNULL(er.[Credit],0) ),    
		SUM( ISNULL(er.[CurDebit],0) ),     
		SUM( ISNULL(er.[CurCredit],0) ),    
		er.[Level] - 1 ,    
		er.[Path], 
		er.[RecType], 
		er.[fn_AcLevel], 
		SUM(er.[Flag]),
		0,
		--'',
		--CASE WHEN @Lang = 'ar' THEN ISNULL(parentAc.[Name], '') ELSE ISNULL(parentAc.[LatinName],'') END,
		CASE WHEN @Lang = 'ar' THEN finalAc.[Name] ELSE finalAc.[LatinName] END,
		er.[id]   
	FROM      
		[#EResult] AS er
		INNER JOIN ac000 AS finalAc ON finalAc.[GUID] = er.acFinal
		--LEFT JOIN ac000 AS parentAc ON parentAc.[GUID] = er.acParent
		WHERE er.[DFlag] = 1 AND er.[Level] <= @AccountLevel 
	GROUP BY      
		er.[acGUID],  
		er.[acCodeName],  
		--er.[acCodeLatinName],  
		er.[acFinal],  
		er.[acParent],  
		er.[DebitOrCredit],  
		er.[acCurPtr],  
		er.[acCurVal],  
		er.[Level],  
		er.[Path], 
		er.[RecType],    
		er.[fn_AcLevel], 
		--CASE WHEN @Lang = 'ar' THEN ISNULL(parentAc.[Name], '') ELSE ISNULL(parentAc.[LatinName],'') END,
		CASE WHEN @Lang = 'ar' THEN finalAc.[Name] ELSE finalAc.[LatinName] END,
		er.[id] 
		
		
	 
	INSERT INTO [#FinalResult] 
	SELECT 
		[f].[AcGuid], 
		--CASE @Lang WHEN 'ar' THEN [f].[acCodeName] 
		--		ELSE CASE [f].[acCodeName] WHEN '' THEN [f].[acCodeName] ELSE [f].[AcCodeLatinName] END 
		--END,
		[r].[acCodeName], 
		--[f].[acCodeLatinName], 
		0x0, 
		[f].[acParent], 
		[f].[DebitOrCredit], 
		[f].[AcCurPtr], 
		[f].[AcCurVal], 
		SUM( ISNULL([r].[Debit],0) ),    
		SUM( ISNULL([r].[Credit],0) ),    
		SUM( ISNULL([r].[CurDebit],0) ),     
		SUM( ISNULL([r].[CurCredit],0) ),    
		0, 0,  
		1, 
		[fn_AcLevel] , 
		SUM([r].[FLAG]), 
		0,
		--''
		--CASE WHEN @Lang = 'ar' THEN ISNULL(parentAc.[Name], '') ELSE ISNULL(parentAc.[LatinName],'') END,
		CASE WHEN @Lang = 'ar' THEN finalAc.[Name] ELSE finalAc.[LatinName] END,
		[f].[id]    
	FROM      
		[#EResult] AS [r]  
		INNER JOIN [#FinalAccTbl] AS [f] ON [r].[acFinal] = [f].[AcGuid] 
		INNER JOIN ac000 AS finalAc ON finalAc.[GUID] = r.acFinal
		LEFT JOIN ac000 AS parentAc ON parentAc.[GUID] = r.acParent
	WHERE ABS(ISNULL([r].[Debit],0) - ISNULL([r].[Credit],0))> 0 AND [r].[DFlag] = 0 
	GROUP BY  
		[f].[AcGuid], 
		--CASE @Lang WHEN 'ar' THEN [f].[acCodeName] 
		--		ELSE CASE [f].[acCodeName] WHEN '' THEN [f].[acCodeName] ELSE [f].[AcCodeLatinName] END 
		--END,
		[r].[acCodeName], 
		--[f].[acCodeLatinName], 
		[f].[acParent], 
		[f].[DebitOrCredit], 
		[f].[AcCurPtr], 
		[f].[AcCurVal], 
		[fn_AcLevel],
		--CASE WHEN @Lang = 'ar' THEN ISNULL(parentAc.[Name], '') ELSE ISNULL(parentAc.[LatinName],'') END,
		CASE WHEN @Lang = 'ar' THEN finalAc.[Name] ELSE finalAc.[LatinName] END,
		[f].[id]       
	 
	IF @CurrencyRateType = 1 
	BEGIN 
		IF @CurrencyValue = 0 
			SET @CurrencyValue = 1 
		UPDATE	[#FinalResult]  
			SET [Debit] = [Debit] / @CurrencyValue,[Credit] = [Credit] / @CurrencyValue 
	END 
	
	-- Fill DebitOrCredit Field
	UPDATE #finalResult	SET
		DebitOrCredit = ac.IsDebit
	FROM #finalResult AS f
	INNER JOIN (SELECT	fChild.acGUID AS AccountGuid,
						CASE WHEN fParent.Balance >= 0 THEN 1 ELSE 0 END AS IsDebit
					FROM 
						(SELECT acCodeName, acGuid, Debit - Credit AS Balance 
							FROM #finalResult 
							WHERE [Level] = 0 AND acParent = 0x0
							--fn_Aclevel = 0 
						)	
						AS fParent 
						CROSS APPLY fnGetAccountsList(fParent.acGUID, 1) AS Child
						INNER JOIN #finalResult AS fChild ON fChild.acGUID = Child.[GUID]
				) AS ac ON ac.AccountGuid = f.acGUID
	
	-- Fill total of Debit and total of Credit for final accounts
	UPDATE #finalResult	SET
		Debit = FinalAccBalance.SUMDebit,
		Credit = FinalAccBalance.SUMCredit
	FROM #finalResult AS f
	INNER JOIN (SELECT 
					CASE acfinal WHEN 0X0 THEN acParent ELSE acfinal END AS AccountGuid,
					SUM(Debit) AS SUMDebit,
					SUM(Credit) AS SUMCredit
				FROM #FinalResult 
				WHERE [Level] = 0
				GROUP BY
					CASE acfinal WHEN 0X0 THEN acParent ELSE acfinal END	
				) AS FinalAccBalance ON FinalAccBalance.AccountGuid = f.acGUID
	
	--SELECT * FROM #FinalResult
	--SELECT 
	--	CASE acfinal WHEN 0X0 THEN acParent ELSE acfinal END AS AccountGuid,
	--	SUM(Debit) AS Debit,
	--	SUM(Credit) AS Credit
	--INTO #FinalAccBalances	
	--FROM
	--	#FinalResult
	--GROUP BY
	--CASE acfinal WHEN 0X0 THEN acParent ELSE acfinal END		
	
	SELECT
		--d.acGUID,
		--ISNULL(d.number, 9999999) AS DNumber,
		--d.FinalAccountIdentity,
		--d.Debit,
		--d.Credit,
		--ISNULL(d.[Path],'9999') AS DebitPath,
		--c.acGUID,
		--c.Credit,
		--c.Credit,
		--c.[Level],
		--ISNULL(c.[Path],'9999') AS CreditPath,
		--ISNULL(c.number, 9999999) AS CNumber,
		--c.FinalAccountIdentity
		--ISNULL(d.number, 9999999) AS DNumber,
		ISNULL(d.acGuid, 0x0) AS DebitAccountGuid,
		ISNULL(d.acCodeName, '') AS DebitAccountCodeName,
		ISNULL(d.Debit - d.Credit, 0) AS DebitAccountBalance,
		ISNULL(d.[Level], 999) AS DebitAccountLevel,
		ISNULL(c.acGuid, 0x0) AS CrediAccountGuid,
		ISNULL(c.acCodeName, '') AS CreditAccountCodeName,
		ISNULL(c.Credit - C.Debit, 0) AS CreditAccountBalance,
		ISNULL(c.[Level], 999) AS CreditAccountLevel,
		CASE WHEN ISNULL(d.IsFinalAccount, 0) = 1 OR ISNULL(c.IsFinalAccount, 0) = 1
			THEN 1 ELSE 0 END AS IsFinalAccountRecord,

		CASE WHEN ISNULL(d.IsFinalAccount, 0) = 1 OR ISNULL(c.IsFinalAccount, 0) = 1
			THEN 
			ISNULL(d.acParent, ISNULL(c.acParent, 0x0))
			ELSE  0x0 END 
			AS ParentAccountGuid,
		
		CASE WHEN ISNULL(d.IsFinalAccount, 0) = 1 OR ISNULL(c.IsFinalAccount, 0) = 1 THEN
			ISNULL(d.acParent, ISNULL(c.acParent, 0x0))
		ELSE ISNULL(d.acFinal, ISNULL(c.acFinal, 0x0)) END
		AS FinalAccountGUID,
		
		
		@NumOfSecViolated AS NumOfSecViolated
	FROM
		(SELECT *, ROW_NUMBER() OVER(PARTITION BY FinalAccountIdentity, IsFinalAccount, DebitOrCredit ORDER BY FinalAccountIdentity, fn_AcLevel, [Path]) AS number  FROM #finalResult 
			WHERE DebitOrCredit = 1
			) AS d
		
		FULL JOIN 
		
		(SELECT *, ROW_NUMBER() OVER(PARTITION BY FinalAccountIdentity, IsFinalAccount, DebitOrCredit ORDER BY FinalAccountIdentity, fn_AcLevel, [Path]) AS number FROM #finalResult 
			WHERE DebitOrCredit = 0
			) AS c 

			ON c.acFinal = d.acFinal AND d.acGUID <> c.acGUID AND d.number = c.number
			
	ORDER BY ISNULL(d.FinalAccountIdentity,ISNULL(c.FinalAccountIdentity,9999)), ISNULL(d.number,ISNULL(c.Number,99999)), ISNULL(d.[Path], ISNULL(c.[Path], '99999'))

#########################################################
CREATE PROCEDURE ARWA.repAccountsBalance
	@StartDate				DATETIME,
	@EndDate				DATETIME,
	@AccountGUID			UNIQUEIDENTIFIER,
	@AccountDescription		VARCHAR(250),
	@CurrencyGUID			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@NotesContain			VARCHAR(200),
	@NotesNotContain		VARCHAR(200),
	@Type					TINYINT,	-- 0 All accounts, 1 Debit accounts only, 2 Credit accounts only, 3 Exceeded max balance accounts.
	@ShowBalance			BIT,
	@ShowPreviousBalance	BIT,
	@JobCostGUID			UNIQUEIDENTIFIER,
	@JobCostDescription		VARCHAR(250),
	@SourcesTypes			VARCHAR(MAX),
	@ShowAccountCode		BIT,
	@ShowAccountName		BIT,
	@ShowMaxBalance			BIT,
	@ShowTextNum			BIT,
	@Lang					VARCHAR(100) = 'ar', 
	@UserGUID				UNIQUEIDENTIFIER = 0X0,
	@BranchMask				BIGINT = -1
AS
	--  ﬁ—Ì— √—’œ… «·Õ”«»« 
	SET NOCOUNT ON
	
	EXEC [prcInitialize_Environment] @UserGUID, 'repAccountsBalance', @BranchMask
	
	CREATE TABLE [#SecViol]([Type] INT, [Cnt] INT)
	
	DECLARE @Types TABLE(
		[GUID]	VARCHAR(100), 
		[Type]	VARCHAR(100))

    INSERT INTO @Types SELECT * FROM [fnParseRepSources](@SourcesTypes)

	SELECT
		fn.[GUID] AS [GUID],
		ac.[acType] AS [Type],
		ac.acNsons AS Nsons,
		ac.acNotes AS Notes,
		ac.[acSecurity] AS AcSecurity
	INTO
		[#Accounts]
	FROM
		[dbo].[fnGetAcDescList](@AccountGUID) fn
		INNER JOIN vwac ac ON fn.[GUID] = ac.[acGUID]
	 
	DECLARE @Cost_Tbl TABLE( [GUID] UNIQUEIDENTIFIER)
	INSERT INTO @Cost_Tbl SELECT [GUID] FROM [dbo].[fnGetCostsList](@JobCostGUID)
	IF ISNULL(@JobCostGUID, 0x0) = 0x0
		INSERT INTO @Cost_Tbl VALUES(0x0)
 
	CREATE TABLE [#Result](
		[AccGUID]		UNIQUEIDENTIFIER,
		[CeGUID]		UNIQUEIDENTIFIER,
		[Date]			DateTime,
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[ceSecurity]	INT,
		[AccSecurity]	INT)
		
	CREATE TABLE [#EndResult](
		[AccGUID]		UNIQUEIDENTIFIER,
		[Debit]			FLOAT,
		[Credit]		FLOAT,
		[Balanc]		FLOAT,
		[PrevBalance]	FLOAT)

	INSERT INTO [#Result]
	SELECT
		[ac].[GUID],
		[en].[ceGUID],
		[en].[enDate],
		[dbo].[fnCurrency_fix]([en].[enDebit], [en].[enCurrencyPtr], [en].[enCurrencyVal], @CurrencyGUID, [en].[enDate]) AS [FixedEnDebit],
		[dbo].[fnCurrency_fix]([en].[enCredit], [en].[enCurrencyPtr], [en].[enCurrencyVal],  @CurrencyGUID, [en].[enDate]) AS [FixedEnCredit],
		[en].[ceSecurity],
		[ac].[acSecurity] AS [acSecurity]
	FROM 
	  	[vwExtended_en]	[en]
	  	INNER JOIN @Types [t] ON [t].[GUID] = en.ceTypeGUID
		INNER JOIN [#Accounts] [ac] ON [en].[enAccount] = [ac].[GUID]
		INNER JOIN @Cost_Tbl [Cost] ON [en].[enCostPoint] = [Cost].[GUID]
	WHERE 
		([en].[enDate] BETWEEN @StartDate AND @EndDate 
		AND [en].[ceIsPosted] = 1 
		AND [ac].[Type] <> 2 AND  [ac].[NSons] = 0 
		AND (@NotesContain = '' or [ac].[Notes] Like '%' + @NotesContain + '%') 
		AND (@NotesNotContain = '' or [ac].[Notes] NOT Like '%' + @NotesNotContain + '%'))
		OR 
		((@ShowPreviousBalance	<> 0) AND ([en].[enDate] < @StartDate) AND ([en].[ceIsPosted] = 1)) 
 
	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1
	
	DECLARE @NumOfSecViolated BIT
	SET @NumOfSecViolated = 0
	
	IF EXISTS(SELECT * FROM #SecViol)
		SET @NumOfSecViolated = 1
	
	INSERT INTO [#EndResult] 
	SELECT  
		[Res].[AccGUID], 
		SUM(CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Debit] END), 
		SUM(CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Credit] END), 
		CASE [ac].[acWarn]
			WHEN 2 THEN -(SUM( CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Debit] END) - SUM(CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Credit] END)) 
			ELSE SUM(CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Debit] END) - SUM(CASE WHEN [Res].[Date] < @StartDate THEN 0 ELSE [Res].[Credit] END)
		END AS [Balanc], 
		SUM(CASE WHEN [Res].[Date] < @StartDate THEN [Res].[Debit] ELSE 0 END) - SUM(CASE WHEN [Res].[Date] < @StartDate THEN [Res].[Credit] ELSE 0 END)
	FROM 
		[#Result] As [Res] 
		INNER JOIN [vwAc] AS [ac] ON [Res].[AccGUID] = [ac].[acGUID] 
	GROUP BY 
		[Res].[AccGUID], 
		[ac].[acWarn] 
	
	DELETE FROM #EndResult WHERE Debit = 0 AND Credit = 0

	SELECT 
		[Res].[AccGUID] AS [AccountGUID], 
		CASE @Lang
			WHEN 'ar' THEN [ac].[acName]
			ELSE [ac].[acLatinName] 
		END AS [AccountName],
		[ac].[acCode] AS [AccountCode], 
		CASE [ac].[acWarn]
			WHEN 0 THEN 0
			WHEN 1 THEN [dbo].[fnCurrency_fix]( [ac].[acMaxDebit], [ac].[acCurrencyPtr], [ac].[acCurrencyVal], @CurrencyGUID , @EndDate) 
			WHEN 2 THEN -[dbo].[fnCurrency_fix]( [ac].[acMaxDebit], [ac].[acCurrencyPtr], [ac].[acCurrencyVal], @CurrencyGUID , @EndDate) 
		END AS [AccountMaxDebit],
		[dbo].[fnCurrency_fix]([ac].[acMaxDebit], [ac].[acCurrencyPtr], [ac].[acCurrencyVal], @CurrencyGUID , @EndDate) AS [AccountMaxBalance],
		[ac].[acNotes] AS [AccountNotes],
		CASE
			WHEN [Res].[Debit] > [Res].[Credit] THEN ([Res].[Debit] - [Res].[Credit])
			ELSE 0
		END AS [SumDebit],
		(CASE
			WHEN [Res].[Debit] < [Res].[Credit] THEN -([Res].[Debit] - [Res].[Credit])
			ELSE 0
		END) AS [SumCredit],
		[Res].[PrevBalance]	AS [PreviousBalance],
		@NumOfSecViolated AS NumOfSecViolated
	FROM
		[#EndResult] AS [Res] 
		INNER JOIN [vwAc] AS [ac] ON [Res].[AccGUID] = [ac].[acGUID]
	WHERE
		(@Type = 0 AND ((@ShowBalance = 1) OR ((@ShowBalance = 0) AND (Res.Balanc <> 0))))
		OR (@Type = 1 AND ([Res].[Debit] - [Res].[Credit])  > 0 AND ((@ShowBalance = 1) OR ((@ShowBalance = 0) AND ([Res].[Balanc] <> 0))))
		OR (@type = 2 AND ([Res].[Debit] - [Res].[Credit])  < 0 AND ((@ShowBalance = 1) OR (@ShowBalance = 0 AND ([Res].[Balanc] <> 0))))
		OR (@type = 3 AND [ac].[acWarn] <> 0 AND [dbo].[fnCurrency_fix] ([ac].[acMaxDebit], [ac].[acCurrencyPtr], [ac].[acCurrencyVal], @CurrencyGUID, @EndDate) <= [Res].[Balanc])

	EXEC [prcFinilize_Environment] 'repAccountsBalance'

/*
ALTER PROCEDURE ARWA.repAccountsBalance
	@StartDate				DATETIME,
	@EndDate				DATETIME,
	@AccountGUID			UNIQUEIDENTIFIER,
	@AccountDescription		VARCHAR(250),
	@CurrencyGUID			UNIQUEIDENTIFIER,
	@CurrencyDescription	VARCHAR(250),
	@NotesContain			VARCHAR(200),
	@NotesNotContain		VARCHAR(200),
	@Type					TINYINT,	-- 0 All accounts, 1 Debit accounts only, 2 Credit accounts only, 3 Exceeded max balance accounts.
	@ShowBalance			BIT,
	@ShowPreviousBalance	BIT,
	@JobCostGUID			UNIQUEIDENTIFIER,
	@JobCostDescription		VARCHAR(250),
	@SourcesTypes			VARCHAR(MAX),
	@ShowAccountCode		BIT,
	@ShowAccountName		BIT,
	@ShowMaxBalance			BIT,
	@ShowTextNum			BIT,
	@Lang					VARCHAR(100) = 'ar', 
	@UserGUID				UNIQUEIDENTIFIER = 0X0,
	@BranchMask				BIGINT = -1
	
	
AS
	SET NOCOUNT ON
	
	SELECT 
		0x0 AS [AccountGUID], 
		'' AS [AccountName], 
		'' AS [AccountLName], 
		'' AS [AccountCode], 
		0 AS [AccountMaxDebit],
		0 AS [AccountMaxBalance],
		'' AS [AccountNotes],
		0 AS [SumDebit],
		0 as [SumCredit],
		0 AS [PreviousBalance],
		0 AS NumOfSecViolated
*/
#########################################################
CREATE PROCEDURE ARWA.repAccountMove
	@AccountGUID					[UNIQUEIDENTIFIER],				-- «·Õ”«»
	@CurrencyGUID					[UNIQUEIDENTIFIER],				-- «·⁄„·…
	@CurrencyValue						[FLOAT],						-- «· ⁄«œ·
	@StartDate					[DATETIME],						-- „‰  «—ÌŒ
	@EndDate					[DATETIME],						-- ≈·Ï  «—ÌŒ
	@PeriodType					[INT],							-- 1 Daily, 2 Weekly, 3 Monthly, 4 Quarter, 5 Yearly 
	@ShowDebit					[BIT],							-- ≈ŸÂ«— „œÌ‰
	@ShowCredit					[BIT],							-- ≈ŸÂ«— œ«∆‰
	@ShowBalance				[BIT],							-- ≈ŸÂ«—«·—’Ìœ
	--@ShowJobCost					[BIT],							-- ≈ŸÂ«— „—ﬂ“ «·ﬂ·›…
	@JobCostGUID					[UNIQUEIDENTIFIER] = 0x0,		-- „—ﬂ“ «·ﬂ·›…
	@SourcesTypes				VARCHAR(MAX),					-- „’«œ— «· ﬁ—Ì—
	@PeriodStr					[VARCHAR](MAX) = '',			-- «·› —…
	@ShowEmptyPeriods			[BIT] = 0,						-- ≈ŸÂ«— «·› —«  «·›«—€…° Â–« «·ŒÌ«— €Ì— „ÊÃÊœ ›Ì «·√„Ì‰
	@UserGUID					[UNIQUEIDENTIFIER] = 'D523D7F9-2C9C-4DBE-AC17-D583DEF908BB',		-- Guid Of Logining User
	@Lang						VARCHAR(100) = 'ar',		
	@BranchMask					BIGINT = 9223372036854775807,	--  Mask for current branches
	@AccountDescription				VARCHAR(MAX) = '',			-- Ê’› «·Õ”«»	
	@CurrencyDescription			VARCHAR(MAX) = '',			-- Ê’› «·⁄„·… 			
	@JobCostDescription			VARCHAR(MAX) = ''			-- Ê’› „—ﬂ“ «·ﬂ·›…		

AS 
	SET NOCOUNT ON
	
	EXEC [prcSetSessionConnections] @UserGUID, @BranchMask

	--DECLARING VARIABLES 
	DECLARE @EntrySec [INT]
	--SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() @UserGUID [UNIQUEIDENTIFIER],
	SET @EntrySec = [dbo].[fnGetUserEntrySec_Browse]( @UserGUID, DEFAULT) 

	DECLARE @Types Table ([Guid] VARCHAR(100), [Type] VARCHAR(100))  
    INSERT INTO @Types SELECT * FROM [fnParseRepSources]( @SourcesTypes) 
    
    CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT])        
    CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])    
	
	--New way
	INSERT INTO [#BillTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserBillSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])),
	[dbo].[fnGetUserBillSec_ReadPrice](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER])) 
	FROM   @Types WHERE [TYPE] = 2
	
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserEntrySec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] =  1
	
	INSERT INTO [#EntryTbl] SELECT [Type] , [Security]  FROM [#BillTbl]  
	
	-- ‘Ìﬂ« 	
	INSERT INTO [#EntryTbl]
	SELECT CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserNoteSec_Browse](@UserGUID, CAST([GUID] AS [UNIQUEIDENTIFIER]))
	FROM @Types WHERE [TYPE] = 5
	
	--New way For TrnStatementTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 3
	
	--New way For TrnExchangeTypes
	INSERT INTO [#EntryTbl]
	SELECT  CAST([GUID] AS [UNIQUEIDENTIFIER]), [dbo].[fnGetUserSec](@UserGUID, 0X2000F200, CAST([GUID] AS [UNIQUEIDENTIFIER]), 1, 1) 
	FROM    @Types WHERE [TYPE] = 4
	CREATE TABLE [#Result] ([AccGuid] [UNIQUEIDENTIFIER], [CostGuid] [UNIQUEIDENTIFIER], [CeGuid] [UNIQUEIDENTIFIER], [Security] [INT], [UserSecurity] [INT], 
							[coSecurity] [INT], [enDate] [DATETIME], [Debit] [FLOAT], [Credit] [FLOAT]) 
	CREATE TABLE [#hlpTbl]([Id] [UNIQUEIDENTIFIER], [enCostPoint] [UNIQUEIDENTIFIER], [Debit] [FLOAT], [Credit] [FLOAT], [Val] [FLOAT]) 
	--CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT]) 
	--FILLING THE TABLES 
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCostGUID
	IF @JobCostGUID = 0X00
		INSERT INTO [#CostTbl] VALUES(0X00,0)

	DECLARE @PERIOD TABLE  ([ID] [UNIQUEIDENTIFIER], [Period] [INT], [StartDate] [DATETIME], [EndDate] [DATETIME]) 
	IF @PeriodType <> 3 
		INSERT INTO @PERIOD SELECT NEWID(), [Period],[StartDate],[EndDate] FROM [dbo].[fnGetPeriod]( @PeriodType, @StartDate, @EndDate)
	ELSE
		INSERT INTO @PERIOD SELECT NEWID(), 0,[StartDate],[EndDate] FROM [dbo].[fnGetStrToPeriod] ( @PeriodStr )

	INSERT INTO [#Result]
	SELECT
		[en].[enAccount],
		[en].[enCostPoint],
		[en].[ceGuid],
		[en].[CESecurity], 
		@EntrySec,
		[co].[Security],
		[en].[enDate],
		[en].[FixedenDebit],
		[en].[FixedenCredit]
	FROM
		--[dbo].[fnExtended_En_Fixed_Src]( @Src,@CurrencyGUID )AS [e]
		[dbo].[fnceen_Fixed](@CurrencyGUID) AS [en]
		INNER JOIN [fnGetAcDescList](@AccountGUID ) AS [fnAcc] ON [en].[enAccount] = [fnAcc].[GUID] 
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGuid] = [en].[enCostPoint] 			
		LEFT JOIN [#EntryTbl] AS src ON en.ceTypeGuid = src.[Type]  
	WHERE 
		[en].[endate] BETWEEN @StartDate AND @EndDate

	/*
	DECLARE @NumOfSecViolated [INT]
	SET @NumOfSecViolated = 0
	DELETE FROM [#Result]
	WHERE
	--Filter Accounts
	[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID) WHERE [IsSecViol] = 1 )
	OR
	--Filter Costs
	[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID) WHERE [IsSecViol] = 1 )
	OR
	--Filter Ce
	[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID) WHERE [IsSecViol] = 1 )
	
	SET @NumOfSecViolated = @@ROWCOUNT
	
	--Filter Result by Branches
	DELETE FROM [#Result]
	WHERE
	--Filter Accounts
	[AccGUID] IN (SELECT [GUID] FROM [fnGetDeniedAccounts](@UserGUID))
	OR
	--Filter Costs
	[CostGUID] IN (SELECT [GUID] FROM [fnGetDeniedCosts] (@UserGUID))
	OR
	--Filter Ce
	[CeGUID] IN (SELECT [GUID] FROM [fnGetDeniedCentries] (@UserGUID))
	*/
	
	-- Security Table --
	CREATE TABLE [#SecViol]
	(   
		[Type] 	[INT],   
		[Cnt] 	[INT]   
	)   

	EXEC [prcCheckSecurity] @UserGUID 
	
	DECLARE @NumOfSecViolated BIT
	SET  @NumOfSecViolated = 0
	IF EXISTS(SELECT * FROM #secviol)
		SET @NumOfSecViolated = 1
	
	INSERT INTO [#hlpTbl] 
	SELECT  
		[period].[ID], 
		CASE WHEN (SUM( [r].[Debit]) <> 0) OR (SUM( [r].[Credit]) <> 0) THEN [r].[CostGUID] 
			ELSE 0X0 
			END, 
		CASE WHEN @ShowDebit = 1 THEN SUM ([r].[Debit]) ELSE 0 END,
		CASE WHEN @ShowCredit = 1 THEN SUM( [r].[Credit]) ELSE 0 END,
		CASE WHEN @ShowBalance = 1 THEN SUM( [r].[Debit] - [r].[Credit]) ELSE 0 END
	FROM 
		[#Result] AS [r] 
		INNER JOIN @period As [period] ON [r].[enDate] BETWEEN [period].[StartDate] AND [period].[EndDate]
	GROUP BY 
		[period].[ID], [r].[CostGUID]

		
	SELECT
		[P].[Period], 
		[P].[StartDate], 
		[P].[EndDate], 
		ISNULL([h].[Debit], 0) AS Debit, 
		ISNULL([h].[Credit], 0)	AS Credit, 
		ISNULL([h].[val], 0) AS Val, 
		ISNULL([Co].[coName], '') AS CostName,
		--ISNULL([Co].[coLatinName], '') AS CostLatinName,
		@NumOfSecViolated AS NumOfSecViolated
	FROM
		@period AS [P]
		LEFT JOIN [#hlpTbl] AS [h] ON [P].[Id] = [h].[Id]
		LEFT JOIN [vwCo] AS [Co] On [h].[enCostPoint] = [Co].[coGUID]
	WHERE 
		( @ShowEmptyPeriods = 0 
						AND ([h].[Debit] <> 0 OR [h].[Credit] <> 0)
		) OR @ShowEmptyPeriods = 1
#########################################################
#END
