#########################################################
CREATE VIEW vtKM
AS
	SELECT * FROM [km000]

#########################################################
CREATE VIEW vbKM
AS
	SELECT [km].*
	FROM [vtKM] AS [km] INNER JOIN [vwBr] AS [br] ON [km].[BranchGuid] = [br].[brGUID]

#########################################################
CREATE VIEW vcKM
AS
	SELECT * FROM [vbKM]

#########################################################
CREATE VIEW vwKM 
AS 
	SELECT 
		[Number] as [kmNumber],
		[Code] as [kmCode],
		[Date] as [kmDate],
		[Notes] as [kmNotes],
		[TotalCtn] as [kmTotalCtn],
		[TotalQty] as [kmTotalQty],
		[Security] as [kmSecurity],
		[Num1] as [kmNum1],
		[Num2] as [kmNum2],
		[Num3] as [kmNum3],
		[Num4] as [kmNum4],
		[Num5] as [kmNum5],
		[Str1] as [kmStr1],
		[Str2] as [kmStr2],
		[Str3] as [kmStr3],
		[Str4] as [kmStr4],
		[Date1] as [kmDate1],
		[Date2] as [kmDate2],
		[Date3] as [kmDate3],
		[GUID] as [kmGUID],
		[BillGUID] as [kmBillGuid],
		[BranchGUID] as [kmBranchGuid]

	FROM 
		[vbKM]

#########################################################
#END 