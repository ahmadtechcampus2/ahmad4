############################################################################################
CREATE PROCEDURE prcCheckDB_mt_Units
	@Correct INT = 0
AS
	IF @Correct <> 1
	BEGIN
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 
				0x0B, [mt].[GUID], [mt].[Code], [mt].[Name] 

			FROM 
				[mt000] AS [mt] 
			WHERE 
				(
					( Isnull( [Unity], '') = '') 
					and
					(
						( Isnull( [Unit2], '') <> '')
						OR 
						( Isnull( [Unit3], '') <> '')
					)
				)
				OR
				( 
					Isnull( [Unit2], '') = '' and Isnull( [Unit3], '') <> ''
				)
				OR
				(
					( Isnull( [Unit2], '') <> '' and [Unit2FactFlag] = 0 and Isnull( [Unit2Fact], 0) = 0)
					OR 
					( Isnull( [Unit3], '') <> '' and [Unit3FactFlag] = 0 and Isnull( [Unit3Fact], 0) = 0)
				)
				OR
				(
					( Isnull( [Unit2], '') = '' and Isnull( [Unit2Fact], 0) <> 0)
					OR 
					( Isnull( [Unit3], '') = '' and Isnull( [Unit3Fact], 0) <> 0)
				)
				OR
				(
					( ( Isnull( [Unit2], '') = '' OR ( [Unit2FactFlag] = 0 and Isnull( [Unit2Fact], 0) = 0) ) and [DefUnit] = 2)
					OR 
					( ( Isnull( [Unit3], '') = '' OR ( [Unit3FactFlag] = 0 and Isnull( [Unit3Fact], 0) = 0) ) and [DefUnit] = 3)
				)
				OR
				(
					(Isnull( [Unity], '') <> '' and Isnull( [Unit2], '') <> '' and Isnull( [Unity], '') = Isnull( [Unit2], ''))
					OR
					(Isnull( [Unity], '') <> '' and Isnull( [Unit3], '') <> '' and Isnull( [Unity], '') = Isnull( [Unit3], ''))
					OR
					(Isnull( [Unit2], '') <> '' and Isnull( [Unit3], '') <> '' and Isnull( [Unit2], '') = Isnull( [Unit3], ''))
					
				)

				OR 
				(
					ISNULL( [DefUnit], 0) = 0 OR ISNULL( [DefUnit], 0) > 3
				)
	END
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'mt000'
			UPDATE [mt000] SET [DefUnit] = 1 WHERE ISNULL( [DefUnit], 0) = 0 OR ISNULL( [DefUnit], 0) > 3
		ALTER TABLE [mt000] ENABLE TRIGGER ALL
	END
############################################################################################
#END