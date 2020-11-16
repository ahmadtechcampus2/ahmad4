#########################################################
CREATE VIEW vtPy
AS
	SELECT * FROM [py000]

#########################################################
CREATE VIEW vbPy
AS
	SELECT [py].*
	FROM [vtpy] AS [py] INNER JOIN [vwBr] AS [br] ON [py].[BranchGUID] = [br].[brGUID]

#########################################################
CREATE VIEW vcPy
AS
	SELECT * FROM [vbPy]

#########################################################
CREATE VIEW vwPy
AS
	SELECT
		[GUID] AS [pyGUID],
		[TypeGUID] AS [pyTypeGUID],
		[Number] AS [pyNumber],
		[AccountGUID] AS [pyAccountGUID],
		[Date] AS [pyDate],
		[Notes] AS [pyNotes],
		[CurrencyGUID] AS [pyCurrencyGUID],
		[CurrencyVal] AS [pyCurrencyVal],
		[Skip] AS [pySkip],
		[Security] AS [pySecurity],
		[Num1] AS [pyNum1],
		[Num2] AS [pyNum2]
	FROM
		[vbPy]

#########################################################
CREATE FUNCTION fcPy
	( @Type [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS
	RETURN (SELECT * FROM [vcPy] WHERE [TypeGUID] = @Type)
#########################################################
CREATE FUNCTION fcPyCe
	( @Type [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS
	RETURN (
		SELECT py.*, ce.IsPosted 
		FROM 
			fcPy(@Type) py
			INNER JOIN er000 er ON py.GUID = er.ParentGUID
			INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID 
		)
#########################################################
#END