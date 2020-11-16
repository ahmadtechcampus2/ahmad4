################################################
CREATE  FUNCTION fnDelSubStr(@Str1 [NVARCHAR](255),@Str2 [NVARCHAR](255)) 
	RETURNS  [NVARCHAR](255)
AS BEGIN 
/* 
this function: 
	- returns Str1 deleted from it @str2
*/ 
	DECLARE @StrIndex INT, @StrIndex2 INT
	SET @StrIndex = CHARINDEX (@Str2,@Str1,0)
	SET @StrIndex2 = @StrIndex+ LEN(@Str2) + 1
	IF @StrIndex = 0
		SET @StrIndex2 = @StrIndex + 1
	RETURN SUBSTRING(@Str1,0,@StrIndex)+ SUBSTRING(@Str1,@StrIndex2,LEN(@Str1))
END 
################################################
CREATE PROCEDURE prcReGenerateMatCodeAndName
	@Code 		[NVARCHAR](1000),
	@Name 		[NVARCHAR](1000)
AS
	DECLARE @str [NVARCHAR](max)
	--SET @Name =  @Name + ' ' + '[tName]'

	CREATE TABLE [#MTALE]([Guid] [UNIQUEIDENTIFIER], [Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI, [Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI,ID [INT] IDENTITY(1,1))
	CREATE TABLE [#MTALE2]([Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI, [Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI)
	CREATE TABLE [#t]
	(
		[Guid]				[UNIQUEIDENTIFIER],
		[GroupGuid]			[UNIQUEIDENTIFIER],
		[tName]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tDIM]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tORIGIN]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tPOS]				[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tCOMPANY]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tGROUP]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tCOLOR]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tPROVENANCE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tQUALITY]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[tMODEL]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		
		[DIM_CODE]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[ORIGIN_CODE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[POS_CODE]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[COMPANY_CODe]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[GROUP_CODE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[COLOR_CODE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[PROVENANCE_CODE]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[QUALITY_CODE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MODEL_CODE]		[NVARCHAR](255) COLLATE ARABIC_CI_AI
	)
	INSERT INTO [#t]
	(
		[Guid],
		[GroupGuid],
		[tName],
		[tDIM],
		[tORIGIN],
		[tPOS],
		[tCOMPANY],
		[tGroup],
		[tCOLOR],
		[tPROVENANCE],
		[tQUALITY],
		[tMODEL],
		
		[DIM_CODE],
		[ORIGIN_CODE],
		[POS_CODE],
		[COMPANY_CODe],
		[Group_Code],
		[COLOR_CODE],
		[PROVENANCE_CODE],
		[QUALITY_CODE],
		[MODEL_CODE]
	)
	SELECT 
		[Guid], 
		[GroupGuid],
		[dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([dbo].[fnDelSubStr]([Name],[Color2]),[ORIGIN2]),[POS2]),[COMPANY2]),[PROVENANCE2]),[QUALITY2]),[MODEL2]),[Dim2]),
		[DIM],
		[ORIGIN],
		[POS],
		[COMPANY],
		'',--group
		[COLOR],
		[PROVENANCE],
		[QUALITY],
		[MODEL],
		'',-- DIM_CODE,
		'',-- ORIGIN_CODE,
		'',-- POS_CODE,
		'',-- COMPANY_CODe,
		'',-- group code
		'',-- COLOR_CODE,
		'',-- PROVENANCE_CODE,
		'',-- QUALITY_CODE,
		''-- MODEL_CODE
	FROM [mt000] AS [mt] 
	INNER JOIN [#MatTbl] As [m] ON [mt].[guid] = [m].[matGuid]
	INNER JOIN [#MT2]AS [m2] ON [mt].[guid] = [m2].[Guid2]
	
	UPDATE [#t] SET [tgroup] = [gr].[name] FROM [#t] AS t inner join [gr000] AS [gr] on [t].[GroupGuid] = [gr].[Guid] 

	UPDATE [#t] SET [DIM_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tDim] = [op].[name] and [op].[type] = 3
	UPDATE [#t] SET [ORIGIN_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[torigin] = [op].[name] and [op].[type] = 11
	UPDATE [#t] SET [POS_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tpos] = [op].[name] and [op].[type] = 12
	UPDATE [#t] SET [COMPANY_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tcompany] = [op].[name] and [op].[type] = 13
	UPDATE [#t] SET [Group_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tGroup] = [op].[name] and [op].[type] = 14
	UPDATE [#t] SET [COLOR_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tcolor] = [op].[name] and [op].[type] = 15
	UPDATE [#t] SET [PROVENANCE_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tprovenance] = [op].[name] and [op].[type] = 16
	UPDATE [#t] SET [QUALITY_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tquality] = [op].[name] and [op].[type] = 17
	UPDATE [#t] SET [MODEL_CODE] = [op].[code] FROM [#t] AS [t] inner join [genmatop000] AS [op] on [t].[tmodel] = [op].[name] and [op].[type] = 18



	SET @str = 'INSERT INTO [#MTALE]  ([Guid],[Code],[Name]) SELECT [M].[Guid],[DIM_CODE]+[ORIGIN_CODE]+ [POS_CODE] +  [COMPANY_CODE],' + @Name + '   FROM [mt000] [m] inner join [#t] [t] on [m].[guid] = [t].[guid] INNER JOIN [vwGr] ON [grGuid] = [m].[GroupGuid] ORDER by  [m].[Number]'
	EXEC( @str)
	DECLARE @Guid [UNIQUEIDENTIFIER], @Code2 [NVARCHAR](256), @Name2 [NVARCHAR](256), @Id [INT], @Cnt [INT]
	DECLARE @Duplecate INT  
	IF EXISTS(SELECT [Value] FROM [OP000] WHERE [NAME] ='AmnCfg_CanDuplicateMatName' AND [Value] = '1')
		SET @Duplecate = 1
	ELSE
		SET @Duplecate = 0
	SET @Id = 1
	SELECT @Cnt = COUNT(*) FROM [#MTALE]
	WHILE @ID <= @Cnt
	BEGIN 
		SELECT @Guid = [GUID], @Code2 = [CODE], @Name2 = [NAME] FROM [#MTALE] WHERE [ID] =@Id
		IF NOT(EXISTS(SELECT [CODE] FROM [MT000] WHERE [CODE] = @Code2 OR (@Duplecate = 0 AND [Name] = @Name2)))
				UPDATE [MT000] SET  [Name] = @Name2, [Code] =  @Code2  WHERE [GUID] = @Guid 
		ELSE
			INSERT INTO [#MTALE2] SELECT [Name],[CODE] FROM [MT000] WHERE [GUID] = @Guid
		SET @Id = @Id + 1

	END

--SET @str = 'UPDATE mt000 SET Name = ' + @Name + ', Code = ' + @Code + ' FROM mt000 m inner join #t t on m.guid = t.guid WHERE m.GUID NOT IN (SELECT GUID FROM #MTALE)'

--EXEC( @str)
	SELECT * FROM [#MTALE2]

/*
EXEC prcModifyMats '', '', '', '', '', '', '', '', '', '', '', '', '', 'ÈÑÊÞÇáí', 1, 'color_code+quality_code+model_code+company_code+Dim_CODE', 'color + '' '' +  quality + '' '' +  model + '' '' +  company + '' '' +  Dim'

*/

########################################
#END
