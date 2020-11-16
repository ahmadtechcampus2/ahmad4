###########################################################################
CREATE FUNCTION fnOption_Get(@Option [VARCHAR](250), @Default [NVARCHAR](2000) = '')
	RETURNS [NVARCHAR](2000)
AS BEGIN
	RETURN ISNULL((SELECT TOP 1 [Value] FROM [op000] WHERE [Name] = @Option), @Default)
END

###########################################################################
#END