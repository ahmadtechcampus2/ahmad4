########################################################## 
CREATE PROCEDURE prcRefreshViews
AS
	SET NOCOUNT ON

	DECLARE views_cursor CURSOR FOR

	SELECT name
	FROM sysobjects
	WHERE type = 'V' AND name NOT LIKE 'MSmerge_%'

	OPEN views_cursor

	CREATE TABLE #tempview(Id INT IDENTITY (1,1), [Name] NVARCHAR(500))

	DECLARE @view NVARCHAR(500)

	FETCH NEXT FROM views_cursor INTO @view

	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY
			EXEC sp_refreshview @view
		END TRY
		BEGIN CATCH
			INSERT INTO #tempview VALUES (@view)
		END CATCH

		FETCH NEXT FROM views_cursor INTO @view
	END

	CLOSE views_cursor
	DEALLOCATE views_cursor
	DECLARE @Cnt INT  = 0;

	WHILE EXISTS(SELECT 1 FROM #tempview)
	BEGIN
		SELECT TOP 1 @view = name
		FROM #tempview
		ORDER BY id

		BEGIN TRY
			IF @Cnt < 3
			BEGIN
				EXEC sp_refreshview @view
				PRINT 1
			END

			DELETE #tempview WHERE name = @view
			SET @Cnt = 0;
		END TRY
		BEGIN CATCH
			SET @Cnt = @Cnt + 1;
		END CATCH
	END
 
	EXEC prcBranch_InstallBRTs
#########################################################
#END
