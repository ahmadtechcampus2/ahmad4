#########################################################
CREATE VIEW vtAc
AS
	SELECT * FROM [ac000]

#########################################################
CREATE VIEW vbAc
AS
	SELECT [v].*
	FROM [vtAc] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcAc
AS
	SELECT * FROM [vbAc]
#########################################################
CREATE VIEW vwAcCu
AS
	SELECT 
		ac.*,
		(SELECT COUNT(*) AS Cnt FROM cu000 WHERE AccountGUID = ac.GUID) AS CustomersCount
	FROM 
		[vbAc] ac
#########################################################
CREATE VIEW vwAc
AS
	SELECT
		[GUID] AS [acGUID],
		[Number] AS [acNumber],
		[Name] AS [acName],
		CASE WHEN [LatinName] = '' OR [LatinName] IS NULL THEN [Name] ELSE [LatinName] END AS [acLatinName],
		[Code] AS [acCode],
		[CDate] AS [acCDate],
		[ParentGUID] AS [acParent],
		[FinalGUID] AS [acFinal],
		CostGuid AS acCostGuid,
		AddedValueAccGUID AS acAddedValueAccGUID,
		[NSons] AS [acNSons],
		[Debit] AS [acDebit],
		[Credit] AS [acCredit],
		[InitDebit] AS [acInitDebit],
		[InitCredit] AS [acInitCredit], 
		[UseFlag] AS [acUseFlag], 
		[MaxDebit] AS [acMaxDebit], 
		[Notes] AS [acNotes], 
		[CurrencyVal] AS [acCurrencyVal], 
		[CurrencyGUID] AS [acCurrencyPtr], 
		[Warn] AS [acWarn], 
		[CheckDate] AS [acCheckDate], 
		[Security] AS [acSecurity], 
		[DebitOrCredit] AS [acDebitOrCredit], 
		[Type] AS [acType], 
		[State] AS [acState], 
		[Num1] AS [acNum1], 
		[Num2] AS [acNum2], 
		[BranchGUID] AS [acBranchGUID],
		[BranchMask] AS [acBranchMask],
		[IsUsingAddedValue] AS [IsUsingAddedValue],
		[IsSync],
		DefaultAddedValue AS acDefaultAddedValue,
		IsDefaultAddedValueFixed AS acIsDefaultAddedValueFixed,
		IncomeType,
		CashFlowType,
		BalSheetGuid,
		AccMenuName,
		AccMenuLatinName
	FROM 
		[vbAc]
#########################################################
CREATE VIEW vwAcDetailed
AS
	SELECT 
		A.*,
		MY.Code AS CurrencyCode,
		MY.Name AS CurrencyName,
		MY.LatinName AS CurrencyLatinName,
		ISNULL(P.acCode, N'') AS MainAccCode,
		ISNULL(P.acName, N'') AS MainAccName,
		ISNULL(P.acLatinName, N'') AS MainAccLatinName,
		F.acCode AS FinalAccCode,
		F.acName AS FinalAccName,
		F.acLatinName AS FinalAccLatinName,
		ISNULL(CO.Code, N'') AS CostCode,
		ISNULL(CO.Name, N'') AS CostName,
		ISNULL(CO.LatinName, N'') AS CostLatinName,
		ISNULL(CHK.CheckedToDate, N'') LastCheckDate,
		ISNULL(CHK.Debit - CHK.Credit, 0) LastCheckBalance,
		ISNULL(
			CASE
				WHEN CHK.Debit - CHK.Credit > 0 THEN 0 -- Debit
				WHEN CHK.Debit - CHK.Credit < 0 THEN 1 -- Credit
				WHEN CHK.Debit - CHK.Credit = 0 THEN 2 -- Balanced OR 3 Then there is no check
			END, 3) AS LastCheckBalanceType,
		ISNULL(TaxAc.acCode, N'') AS TaxAccCode,
		ISNULL(TaxAc.acName, N'') AS TaxAccName,
		ISNULL(TaxAc.acLatinName, N'') AS TaxAccLatinName,
		BS.Name AS BalSheetName,
		BS.LatinName AS BalSheetLatinName
	FROM 
		vwAc AS A
		LEFT JOIN vwAc AS P ON A.acParent = P.acGUID
		LEFT JOIN vwAc AS F ON A.acFinal = F.acGUID
		LEFT JOIN vwAc AS TaxAc ON A.acAddedValueAccGUID = TaxAc.acGUID
		LEFT JOIN my000 AS MY ON A.acCurrencyPtr = MY.GUID
		LEFT JOIN co000 AS CO ON CO.GUID = A.acCostGuid
		LEFT JOIN BalSheet000 AS BS ON BS.[GUID] = A.BalSheetGuid
		-- ÇÎÑ ãØÇÈÞÉ ááÍÓÇÈ
		OUTER APPLY (SELECT TOP 1 [CheckedToDate], [Notes], Debit, Credit FROM [dbo].[CheckAcc000] WHERE AccGUID = A.acGUID ORDER BY [CheckedToDate] DESC) CHK
#########################################################		
CREATE VIEW vwCuDetails
AS 
	SELECT 
		cu.*,
		ac.CurrencyVal AS acCurrencyVal
	FROM 
		cu000 cu
		INNER JOIN ac000 ac ON cu.AccountGUID = ac.GUID 
#########################################################
#END
