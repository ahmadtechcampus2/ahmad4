#########################################################
CREATE VIEW vtCe
AS
	SELECT * FROM [ce000]

#########################################################
CREATE VIEW vbCe
AS
	SELECT [ce].*
	FROM [vtCe] AS [ce] INNER JOIN [vwBr] AS [br] ON [ce].[Branch] = [br].[brGUID]

#########################################################
CREATE VIEW vcCe
AS
	SELECT * FROM [vbCe]

#########################################################
CREATE VIEW vwCe 
AS 
	SELECT 
		[GUID] AS [ceGUID], 
		[Type] AS [ceType], 
		[Number] AS [ceNumber], 
		[Date] AS [ceDate], 
		[Debit] AS [ceDebit], 
		[Credit] AS [ceCredit], 
		[Notes] AS [ceNotes], 
		[CurrencyVal] AS [ceCurrencyVal], 
		[CurrencyGUID] AS [ceCurrencyPtr], 
		[IsPosted] AS [ceIsPosted], 
		[State] AS [ceState], 
		[Security] AS [ceSecurity], 
		[Branch] AS [ceBranch],
		[TypeGUID] AS [ceTypeGUID],
		[PostDate] AS [cePostDate],
		[CreateUserGuid] AS [ceCreateUserGuid],
		[CreateDate] AS [ceCreateDate]
	FROM 
		[vbCe]


#########################################################
#END