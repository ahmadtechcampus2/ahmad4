##############################
CREATE  function fnHosSite( @Guid UNIQUEIDENTIFIER)
RETURNS  @Result TABLE 
(
	[Number]	NVARCHAR(250) COLLATE ARABIC_CI_AI ,  
	[GUID]		UNIQUEIDENTIFIER,   
	[Code]		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
	[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
	[LatinName] NVARCHAR(250) COLLATE ARABIC_CI_AI ,  
	[ParentGUID]UNIQUEIDENTIFIER,  
	[TypeGUID]	UNIQUEIDENTIFIER,  
	[State]		INT,  
	[Security]	INT, 
	Status		NVARCHAR(250) COLLATE ARABIC_CI_AI,
	[Desc]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	stGuid		UNIQUEIDENTIFIER, 
	stCode		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	stName		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	stLatinName NVARCHAR(250) COLLATE ARABIC_CI_AI,
	stNotes		NVARCHAR(250) COLLATE ARABIC_CI_AI,
	stSecurity	INT

)
AS 
BEGIN

	DECLARE @AutoBlock  NVARCHAR(256) , 
	@ManualBlock  NVARCHAR(256) , 
	@Occupied  NVARCHAR(256) , 
	@Vacant  NVARCHAR(256) , 
	@OuOfOrder  NVARCHAR(256)
	
	SELECT @AutoBlock = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'AutoBlock' ELSE N'محجوزة مؤقتاً' END	
	SELECT @ManualBlock  = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'ManualBlock' ELSE N'محجوزة' END	
	SELECT @Occupied = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'ManualBlock' ELSE N'مشغولة' END	
	SELECT @Vacant = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'Vacant' ELSE N'فارغة' END	
	SELECT @OuOfOrder = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'OuOfOrder' ELSE N'خارج الخدمة' END	
INSERT @Result SELECT 
			S.[Number],  
			S.[GUID],  
			S.[Code],  
			S.[Name],  
			S.[LatinName],  
			S.[ParentGUID],  
			S.[TypeGUID],  
			S.[State],  
			S.[Security], 
			Case WHEN state = 0 THEN @AutoBlock
			     WHEN state = 1 THEN @ManualBlock
			     WHEN state = 2 THEN @Occupied
			     WHEN state = 3 THEN @Vacant
			ELSE
			     @AutoBlock 
			END Status,
			s.[Desc], 
			t.[Guid]		AS stGuid, 
			t.[Code]		AS stCode, 
			t.[Name]		AS stName, 
			t.[LatinName]	AS   stLatinName, 
			t.[Notes]		AS stNotes, 
			t.[Security]	AS stSecurity
	FROM [HosSite000] S LEFT JOIN  HosSiteType000 t On S.TypeGuid = t.Guid
	WHERE ( @Guid = 0x0)
RETURN
END
######################################################
#END