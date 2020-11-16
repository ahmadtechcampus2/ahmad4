###########################################################################
CREATE PROCEDURE prcCheckDB_ac_NSons
	@Correct [INT] = 0
AS
	-- check NSons
	IF @Correct<> 1
		INSERT INTO [ErrorLog]([Type],  [g1], [c1], [c2], [i1])
			SELECT 0x7, [GUID], [Code], [Name], [NSons] FROM [ac000] WHERE [NSons] <> [dbo].[fnGetAccountNSons]([GUID])

	-- correct by updating, if necessary:
	IF @Correct <> 0
		UPDATE [ac000] SET [NSons] = [dbo].[fnGetAccountNSons]([ac].[GUID])
	 		FROM [ac000] AS [ac]
			WHERE [NSons] <>  [dbo].[fnGetAccountNSons]([ac].[GUID])

###########################################################################
#END