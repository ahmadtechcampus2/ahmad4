#########################################################
create function fnGetTableColumns_inAString (@tableName [NVARCHAR](128), @excludedColumns [NVARCHAR](2000) = '') 
	returns [NVARCHAR](2000)
as begin

	declare
		@c cursor,
		@column [NVARCHAR](128),
		@result [NVARCHAR](2000)

	declare @t table([excludedColumn] [NVARCHAR](128) collate arabic_ci_ai)

	insert into @t select cast([data] as [NVARCHAR](128)) from [fnTextToRows](@excludedColumns)

	set @c = cursor fast_forward for select [name] from [fnGetTableColumns](@tableName) where [name] not in (select [excludedColumn] from @t)

	open @c fetch from @c into @column

	set @result = ''

	while @@fetch_status = 0
	begin
		set @result = @result + @column
		fetch from @c into @column
		if @@fetch_status = 0
			set @result = @result + ', '
	end
	CLOSE @c 
	DEALLOCATE @c
	return @result
end


--  select dbo.fnGetTableColumns_inAString ('ce000', 'type')

#########################################################
CREATE FUNCTION FnStrToGuid(@input nvarchar(max))
RETURNS uniqueidentifier
AS
BEGIN
/*
Author: Ibrahim Elsayed Ibrahim
Purposes:This function is used to convert from string to Guid 
if it fail to convert the input  guid it return 00000000-0000-0000-0000-000000000000
*/
  IF NOT EXISTS (SELECT
      'This Is Guid'
    WHERE @input LIKE REPLACE('00000000-0000-0000-0000-000000000000', '0', '[0-9a-fA-F]'))
    RETURN ('00000000-0000-0000-0000-000000000000')
  RETURN @input
END
##############################################
#END