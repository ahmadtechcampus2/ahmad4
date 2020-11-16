###########################################################################
CREATE PROCEDURE prcCheckDB_ac_Types
	@Correct [INT] = 0
AS
	-- check types
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2])
			SELECT 0x3, [GUID], [Code], [Name]  FROM [ac000] WHERE [Type] NOT IN(1, 2, 4, 8)

###########################################################################
#END