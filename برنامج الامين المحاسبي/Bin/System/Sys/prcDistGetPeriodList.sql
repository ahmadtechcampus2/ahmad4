########################################
CREATE PROCEDURE prcGetPeriodList
	@PeriodGuid UNIQUEIDENTIFIER = 0x0,
	@Desc	INT =0,
	@Tree INT = -1
AS 
	IF (@Desc = 0)
	BEGIN
		IF (@Tree = 0)
			SELECT [Name],[Code],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END AS [LatinName],[NSons],p.Guid,[StartDate],[EndDate] 
			FROM [vwPeriods] AS [p] INNER JOIN [fnGetPeriodList](@PeriodGuid,0) AS [f] ON [p].[Guid] = [f].[Guid]
			WHERE [NSons] = 0
			ORDER BY [StartDate],[EndDate]
		ELSE
			SELECT [Name],[Code],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName]  END AS [LatinName],[NSons],p.Guid,[StartDate],[EndDate] 
			FROM vwPeriods AS p INNER JOIN fnGetPeriodList(@PeriodGuid,0) AS f ON p.Guid = f.Guid
			WHERE (@Tree = -1) OR ((@Tree =1)AND(([NSons] <> 0)OR(ISNULL([ParentGuid],0X00)= 0X00)))
			ORDER BY [Path],[EndDate] 
	END
	ELSE
	BEGIN
		IF (@Tree = 0)
			SELECT [Name],[Code],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName]  END AS [LatinName] ,[NSons],p.Guid,[StartDate],[EndDate] 
			FROM vwPeriods AS p INNER JOIN fnGetPeriodList(@PeriodGuid,1) AS f ON p.Guid = f.Guid
			WHERE [NSons] = 0
			ORDER BY [StartDate] DESC,[EndDate] DESC
		ELSE
			SELECT [Name],[Code],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END AS [LatinName],[NSons],p.Guid,[StartDate],[EndDate] 
			FROM vwPeriods AS p INNER JOIN fnGetPeriodList(@PeriodGuid,1) AS f ON p.Guid = f.Guid
				WHERE (@Tree = -1)  OR ((@Tree = 1)AND(([NSons] <> 0)OR(ISNULL([ParentGuid],0X00)= 0X00)))
			ORDER BY [Path]  ,[EndDate] DESC
	END
--EXEC prcGetPeriodList  0x0,1,0,0
#############################
#END