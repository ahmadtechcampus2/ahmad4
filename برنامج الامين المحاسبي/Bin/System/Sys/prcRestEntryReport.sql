#########################################################
Create PROC prcRestEntryReport
	@StartDate [DATETIME], 
	@EndDate   [DATETIME], 	
	@AccountGUID [UNIQUEIDENTIFIER] = 0x0, 
	@Type [INT] = 2 
AS 
SET NOCOUNT ON 
   SELECT Ent.[Number],
		  Ent.[Type] AS EntryType,
		  acc.Name,
		  CashID,
		  my.Name AS CurrName,
		  Equal,
		  Value,
		  Ent.[Date],
		  Note
   FROM [RestEntry000] Ent
     INNER JOIN ac000 acc ON acc.[Guid] = Ent.AccID 
     INNER JOIN my000 my ON Ent.CurrencyID = my.[GUID]
     AND (@AccountGUID=0x0 OR Ent.AccId = @AccountGUID)
     AND ent.[Date] BETWEEN @StartDate AND @ENDDate 
     AND (@Type = 2 OR @Type = ent.[type]) 
   ORDER BY Ent.number
#########################################################
#END