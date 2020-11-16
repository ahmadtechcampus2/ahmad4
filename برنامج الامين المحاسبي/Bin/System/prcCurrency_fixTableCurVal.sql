##############################################
CREATE proc prcCurrency_fixTableCurVal
	@table 		[NVARCHAR](128),
	@guidFld 	[NVARCHAR](128) = 'currencyGuid',
	@valFld 	[NVARCHAR](128) = 'currencyVal',
	@dateFld 	[NVARCHAR](128) = '[date]',
	@fld1 		[NVARCHAR](128) = '',
	@fld2 		[NVARCHAR](128) = '',
	@fld3 		[NVARCHAR](128) = '',
	@fld4 		[NVARCHAR](128) = '',
	@Condition	[NVARCHAR](128) = '',
	@IsNormalEntry	[BIT] = 0,
	@Where			[NVARCHAR](256) = ''
AS

	declare
		@sql [NVARCHAR](max),
		@updatedFields [NVARCHAR](max)


	if isnull(@fld1, '') = ''
		set @updatedFields = ''

	else begin
		set @updatedFields = ',
			%4 = (%4 / (CASE WHEN [x].%2 = 0 THEN 1 ELSE [x].%2 END)) * [t].[CurVal]'
	
		if isnull(@fld2, '') != ''
		begin
			set @updatedFields = @updatedFields + ',
				%5 = (%5 / (CASE WHEN [x].%2 = 0 THEN 1 ELSE [x].%2 END)) * [t].[CurVal]'

			if isnull(@fld3, '') != ''
			begin
				set @updatedFields = @updatedFields + ',
					%6 = (%6 / (CASE WHEN [x].%2 = 0 THEN 1 ELSE [x].%2 END)) * [t].[CurVal]'

				if isnull(@fld4, '') != ''
					set @updatedFields = @updatedFields + ',
						%7 = (%7 / (CASE WHEN [x].%2 = 0 THEN 1 ELSE [x].%2 END)) * [t].[CurVal]'
			end
		end
	end

	set @sql = '
		declare @t table([curGuid] [uniqueidentifier], [curDate] [datetime], [curVal] [float])

		insert into @t
			select distinct %1, %3, [dbo].[fnGetCurVal](%1, %3) FROM %0

		alter table %0 disable trigger all

		update %0 SET
				%2 = [t].[curVal]' + @updatedFields + '	
			FROM
				%0 [x] INNER JOIN @t [t]
				ON [x].%3 = [t].[curDate] AND [x].%1 = [t].[curGuid] '
		IF ISNULL(@Condition, '') <> ''
		BEGIN
			IF @table = 'ce000'
				set @sql = @sql + @Condition + ' [x].[TypeGuid]'
			ELSE IF @table = 'en000'
				set @sql = @sql + @Condition + ' [ce].[ceTypeGuid]'
		END
		IF @IsNormalEntry = 1
		BEGIN
			IF @table = 'en000'
				set @sql = @sql + @Condition + ' INNER JOIN [vwce] AS [ce] ON [x].[ParentGuid] = [ce].[ceGuid] AND [ce].[ceTypeGuid] = 0x0'
		END
			

	set @sql = @sql + '	WHERE [x].%2 <> [t].[CurVal] '
	IF ISNULL(@Where , '') <> ''
		IF @table = 'en000'		
			set @sql = @sql + '	AND [ce].[ceTypeGuid] <> 0x0 '
	IF @IsNormalEntry = 1
	BEGIN
		IF @table = 'ce000'		
			set @sql = @sql + '	AND [TypeGuid] = 0x0 '
	END
	ELSE IF @IsNormalEntry = 0
	BEGIN
		IF @table = 'ce000'		
			set @sql = @sql + '	AND [TypeGuid] <> 0x0 '
	END
	set @sql = @sql + '	alter table %0 enable trigger all'


	exec [prcExecuteSql] @sql, @table, @guidFld, @valFld, @dateFld, @fld1, @fld2, @fld3, @fld4

##########################################################
#END