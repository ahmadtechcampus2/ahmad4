##########################################################################
CREATE PROCEDURE prcAddLookupGUIDFld
	@Table					[NVARCHAR](128),
	@GUIDFld				[NVARCHAR](128),
	@Fld1					[NVARCHAR](128) = NULL,
	@Fld2					[NVARCHAR](128) = NULL,
	@LookupTable			[NVARCHAR](128) = NULL,
	@LookupFld1				[NVARCHAR](128) = 'Number',
	@LookupFld2				[NVARCHAR](128) = NULL,
	@Criteria				[NVARCHAR](512) = NULL,
	@DropLookupFlds			[BIT] = 1,
	@PostScript				[NVARCHAR](max) = NULL
AS
	SET NOCOUNT ON
	DECLARE
		@SQL [NVARCHAR](max),
		@RetVal AS [INT]

	-- add GUIDFld:
	-- disable tables' triggers:
	EXEC [prcExecuteSQL] 'ALTER TABLE %0 DISABLE TRIGGER ALL', @table

	-- repair @LookupTable guids, just in case:
	EXEC [prcExecuteSQL] '
				ALTER TABLE %0 DISABLE TRIGGER ALL
				UPDATE %0 SET [guid] = newid() WHERE [guid] IS NULL
				ALTER TABLE %0 ENABLE TRIGGER ALL
			', @lookupTable

	EXECUTE @RetVal = [prcAddGUIDFld] @Table, @GUIDFld

	-- map:
	IF ISNULL(@Fld1, '') <> ''
	BEGIN
		IF [dbo].[fnObjectExists](@Table + '.' + @Fld1) <> 0
		BEGIN
			SET @SQL = '
				UPDATE ' + @Table + ' SET ' + @GUIDFld
				+ ' = ISNULL([lu].[GUID], 0x0) FROM ' + @Table + ' INNER JOIN ' + @LookupTable + ' AS [lu] ON '
				+ @Table + '.' + @Fld1 + ' = [lu].' + @LookupFld1

			-- double map:
			IF [dbo].[fnObjectExists](@Table + '.' + @Fld2) <> 0 AND [dbo].[fnObjectExists](@Table + '.' + @LookupFld2) <> 0
				IF ISNULL(@Fld2, '') <> ''
					SET @SQL = @SQL + ' AND ' + @Table + '.' + @Fld2 + ' = [lu].' + @LookupFld2

			-- check for criteria:
			IF ISNULL(@Criteria, '') <> ''
				SET @SQL = @SQL + ' WHERE ' + @Criteria

			EXEC (@SQL)
		END
	END

	-- execute post-script, if any:
	IF @PostScript IS NOT NULL
		EXEC (@PostScript)

	-- drop old lookup fields:
	IF @DropLookupFlds <> 0
	BEGIN
		IF ISNULL(@Fld1, '') <> '' EXEC [prcDropFld] @Table, @Fld1
		IF ISNULL(@Fld2, '') <> '' EXEC [prcDropFld] @Table, @Fld2
	END

	-- enable table triggers:
	EXEC [prcExecuteSQL] 'ALTER TABLE %0 ENABLE TRIGGER ALL', @table

	RETURN 1

##########################################################################
#END