###########################################################################
CREATE PROCEDURE repGetDateOfBirthsBefore
	@Lang		[BIT] = 0
AS
	SET NOCOUNT ON
	
	DECLARE @Date [DATETIME], @DateBefore [DATETIME],@DayBefore	[INT]
	DECLARE @ShowDateOfBirth [INT]
	SELECT @DayBefore = CAST ([Value] AS [INT]) FROM [Op000] WHERE [Name] = 'AmnCfg_DateOfBirthsBefore'
	SELECT @ShowDateOfBirth = CAST ([Value] AS [INT]) FROM [Op000] WHERE [Name] = 'AmnCfg_ShowDateOfBirths'

	SET  @DateBefore = [dbo].[fnGetDateFromDT](GETDATE())
	IF @DayBefore IS NULL
		SET @DayBefore = 0
	SET  @Date = DATEADD(dd,@DayBefore,@DateBefore)
	IF @ShowDateOfBirth IS NULL
		SET @ShowDateOfBirth = 0
	SELECT [cuGuid],CASE @Lang WHEN 0 THEN [cuCustomerName] ELSE CASE [cuLatinName] WHEN '' THEN [cuCustomerName] ELSE [cuLatinName] END  END AS [cuCustomerName], 
	DATEDIFF(DD,CAST(CAST(YEAR(@DateBefore) AS [NVARCHAR](4)) + '-' + CAST(MONTH([cuDateOFBirth]) AS [NVARCHAR](4)) + '-' + CAST(DAY([cuDateOFBirth]) AS [NVARCHAR](4)) AS [DATETIME]), @Date) AS DDefl,
	CAST(CAST(YEAR(@DateBefore) AS [NVARCHAR](4)) + '-' + CAST(MONTH([cuDateOFBirth]) AS [NVARCHAR](4)) + '-' + CAST(DAY([cuDateOFBirth]) AS [NVARCHAR](4)) AS [DATETIME]) AS [Date1],
	CAST(CAST(YEAR(@Date) AS [NVARCHAR](4)) + '-' + CAST(MONTH([cuDateOFBirth]) AS [NVARCHAR](4)) + '-' + CAST(DAY([cuDateOFBirth]) AS [NVARCHAR](4)) AS [DATETIME])  AS [Date2]
	,[cuDateOFBirth]
	INTO [#cu]
	FROM [vwCu] AS [cu]  
	WHERE 
		(CAST(CAST(YEAR(@DateBefore) AS [NVARCHAR](4)) + '-' + CAST(MONTH([cuDateOFBirth]) AS [NVARCHAR](4)) + '-' + CAST(DAY([cuDateOFBirth]) AS [NVARCHAR](4)) AS [DATETIME]) BETWEEN @DateBefore AND @Date
		OR CAST(CAST(YEAR(@Date) AS [NVARCHAR](4)) + '-' + CAST(MONTH([cuDateOFBirth]) AS [NVARCHAR](4)) + '-' + CAST(DAY([cuDateOFBirth]) AS [NVARCHAR](4)) AS [DATETIME]) BETWEEN @DateBefore AND @Date)
		AND [cuDateOFBirth] > '1/1/1901'
	SELECT @ShowDateOfBirth AS [ShowDateOfBirth]
	SELECT [cuGuid],[cuCustomerName], CASE WHEN DDefl <= ABS(CAST (@DayBefore AS FLOAT)) THEN [Date1] ELSE [Date2] END AS [BirthDay],[cuDateOFBirth] FROM [#cu] ORDER BY CASE WHEN DDefl <= ABS(CAST (@DayBefore AS FLOAT)) AND DDefl >= 0 THEN [Date1] ELSE [Date2] END
/*
	PRcCONNECTIONS_ADD2 '„œÌ—'
	EXEC repGetDateOfBirthsBefore 
	UPDATE [cu000] set dateofbirth = '11/10/1966' where guid = '4A9A2BA8-A7A8-4734-A120-19EFADEC7209'
*/
################################################################################
#END