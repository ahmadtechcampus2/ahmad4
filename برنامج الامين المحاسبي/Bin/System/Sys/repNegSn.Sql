#########################################################
CREATE PROCEDURE repNegSn
	@FromDate	[DATETIME],
	@ToDate		[DATETIME],
	@MatGuid [UNIQUEIDENTIFIER],
	@GroupGuid	[UNIQUEIDENTIFIER],
	@IN_SN NVARCHAR(100),
	@Lang		[INT] = 0,
	@MatCondGuid [UNIQUEIDENTIFIER] =0X00,
	@IsPosted	[INT] = -1
AS
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])  
	CREATE TABLE [#MatTbl](	[GUID] [UNIQUEIDENTIFIER] , [Security] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [BillType] [UNIQUEIDENTIFIER] , [BillBrowseSec] [INT], [ReadPriceSec] [INT])  
	-------------------------------
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,257 ,@MatCondGuid
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] 0x00
	------------------------------------
	CREATE TABLE [#Result]	( 
		[buGuid] [UNIQUEIDENTIFIER] ,
		[buType] [UNIQUEIDENTIFIER] ,
		[snGuid] [UNIQUEIDENTIFIER] , 
		[buStorePtr] [UNIQUEIDENTIFIER] ,
		[buNumber] [INT],
		[Security] [INT],
		[buDate]  [DATETIME],
		[UserSecurity] [INT],
		[biMatPtr] [UNIQUEIDENTIFIER] ,
		[buUserGuid] [UNIQUEIDENTIFIER] ,
		[MatSecurity] [INT],
		[SN] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtCode] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtName] [NVARCHAR](256) COLLATE ARABIC_CI_AI
		)   
	SELECT [sn].[Guid] AS [snGuid], [biGuid],[SN] INTO [#SN] FROM [VCSNS] AS [sn] INNER JOIN [#MatTbl] AS [mt] ON [mt].[Guid] = [sn].[MatGuid] WHERE @IN_SN = '' OR [Sn] = @IN_SN
	
	SELECT [Code] AS [mtCode],CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE  [LatinName] END END AS [mtName],[m].[GUID],[m].[Security] INTO [#MatTbl2] FROM [#MatTbl] AS [M] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [m].[Guid]  
	
	DECLARE @buGuid [UNIQUEIDENTIFIER],@buType [UNIQUEIDENTIFIER],@buStorePtr [UNIQUEIDENTIFIER],@buNumber [INT],
		@buSecurity [INT],@buDate [DATETIME],
		@buUserGuid [UNIQUEIDENTIFIER],@biMatPtr [UNIQUEIDENTIFIER],@mtSecurity [INT],
		@BillBrowseSec [INT],@mtName [NVARCHAR](100),@SN [NVARCHAR](100),@mtCode [NVARCHAR](100),@buDirection [INT],
		@c_bi CURSOR, @MatGuid2 [UNIQUEIDENTIFIER],@StroreGuid [UNIQUEIDENTIFIER],@SN2  [NVARCHAR](100),@Cnt [INT]
	SET @c_bi = CURSOR FAST_FORWARD FOR  
	SELECT 
		[buGuid],[buType],[biStorePtr],[buNumber],
		[buSecurity],[buDate],
		[buUserGuid],[biMatPtr],[mt].[Security],
		[BillBrowseSec],[mtName],[SN],[mtCode],[buDirection]
	FROM [vwbubi]  AS [bu] 
	INNER JOIN [#MatTbl2] AS [mt] ON [mt].[Guid] =  [bu].[biMatPtr]
	INNER JOIN [#SN] AS [sn]  ON [sn].[biGuid] = [bu].[biGuid]
	INNER JOIN [#BillsTypesTbl] AS [bt] ON [bu].[buType] = [BillType]
	WHERE 
		@IsPosted = -1 OR [buIsPosted] = @IsPosted 
	ORDER BY [biMatPtr],[buStorePtr],[snGuid],[buDate],[buSortFlag],[buNumber],[biNumber]
	SET @MatGuid2 = 0X00
	SET @StroreGuid = 0X00
	SET @SN2 = 0X00
	OPEN @c_bi FETCH FROM @c_bi INTO 
		@buGuid,@buType,@buStorePtr,@buNumber,@buSecurity,@buDate,
		@buUserGuid,@biMatPtr,@mtSecurity,@BillBrowseSec,@mtName,
		@SN,@mtCode,@buDirection
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
 
		IF @MatGuid2 <> @biMatPtr OR @StroreGuid <> @buStorePtr  OR @SN2<> @SN
		BEGIN
			SET @Cnt = 0
			SET @MatGuid2 = @biMatPtr
			SET @StroreGuid = @buStorePtr
			SET @SN2 = @SN
		END 
		SET @Cnt = @Cnt + @buDirection
		IF @Cnt < 0 AND @buDate BETWEEN @FromDate AND @ToDate
			INSERT INTO [#Result]( 
					[buGuid],
					[buType],
					[buStorePtr] ,
					[buNumber],
					[Security],
					[buDate],
					[UserSecurity],
					[biMatPtr],
					[buUserGuid] ,
					[MatSecurity],
					[SN],
					[mtCode],
					[mtName]
					)
				VALUES
					(
					@buGuid,@buType,@buStorePtr,@buNumber,@buSecurity,@buDate,@BillBrowseSec,
					@biMatPtr,@buUserGuid,@mtSecurity,@SN,@mtCode,@mtName
					) 
			FETCH FROM @c_bi INTO 
			@buGuid,@buType,@buStorePtr,@buNumber,@buSecurity,@buDate,
			@buUserGuid,@biMatPtr,@mtSecurity,@BillBrowseSec,@mtName,
			@SN,@mtCode,@buDirection 
		
	END 
	CLOSE @c_bi  
	DEALLOCATE @c_bi
	
	EXEC [prcCheckSecurity]
	SELECT [buGuid],[buStorePtr] ,[buNumber],	[buDate],
			[biMatPtr],[LoginName] AS [UserName] ,	[SN],
					[mtCode],[mtName],[stCode] +'-' + [stName] AS [Store],
		CASE @Lang WHEN 0 THEN [bt].[Name] ELSE CASE [bt].[LatinName] WHEN '' THEN [bt].[Name] ELSE  [bt].[LatinName] END END	AS [btName]
	FROM [#Result] AS [r]
	INNER JOIN [bt000] AS [bt] ON [bt].[Guid] = [buType]
	INNER JOIN [vwSt] AS st ON [st].[stGuid] = [buStorePtr]
	INNER JOIN [US000] AS [us] ON [us].[Guid] = [buUserGuid]
	ORDER BY [mtCode],[buDate],LEN([SN]),[SN],[buNumber]
	
	SELECT * FROM [#SecViol]

/*
	prcConnections_add2 'ãÏíÑ'
	exec repNegSn '1/1/2004','12/31/2007',0x00,0x00,'',0,0x00

*/
######################################################## 
#END