#########################################################
CREATE VIEW vwFa
AS
SELECT
	[GUID] AS [faGUID],
	[ParentGUID] AS [faParentGUID],
	[Type] AS [faType],
	[Value] AS [faValue],
	[Text] AS [faText]
FROM
	[fa000]

#########################################################
#END