################################################################################
CREATE view vwDiscountTypes
AS
SELECT [Number] AS [discountTypesNumber]
      ,[GUID] AS [discountTypesGUID]
      ,[SortNum] AS [discountTypesSortNum]
      ,[Name] AS [discountTypesName]
      ,[Abbrev] AS [discountTypesAbbrev]
      ,[LatinName] AS [discountTypesLatinName]
      ,[LatinAbbrev] AS [discountTypesLatinAbbrev]
      ,[DonateCond] AS [discountTypesDonateCond]
      ,[BeginDate] AS [discountTypesBeginDate]
      ,[EndDate] AS [discountTypesEndDate]
      ,[Account] AS [discountTypesAccount]
      ,[Type] AS [discountTypesType]
      ,[Value] AS [discountTypesValue]
      ,[Security] AS [discountTypesSecurity]
      ,[Detailed] AS [discountTypesDetailed]
  FROM vbDiscountTypes
################################################################################
#END