##########################################################################
CREATE PROC prcBillReNumber @TypeGuid uniqueidentifier, @StartDate datetime, @MergeNum INT = 0,@LgGuid UNIQUEIDENTIFIER=0x0
AS
begin
	SET NOCOUNT ON
	
	create table [#Src] ( [Type] uniqueidentifier, [Sec] int, [ReadPrice] int)
	insert into [#Src] exec [prcGetBillsTypesList] @TypeGuid
	DECLARE @Guid UNIQUEIDENTIFIER
	DECLARE @Parms NVARCHAR(2000)
	
	EXEC  prcsetSrcStringLog @Parms OUTPUT
	SET @Parms = 'Src:'+ @Parms + 'SatrtDate:' + CAST(@StartDate AS NVARCHAR(30)) + CHAR(13) + 'MergeNum:' + CAST(@MergeNum AS NVARCHAR(7))
	EXEC prcCreateMaintenanceLog 2,@LgGuid OUTPUT,@Parms
	
	declare @BaseNumber int
	declare @BG uniqueidentifier
    declare @TG uniqueidentifier
    declare @BuGuid uniqueidentifier
	declare @g int
	EXEC prcDisableTriggers 'BU000', 0    
	/* Repeat for all branches */
    declare c_branches cursor for select [BrGuid] from vwbr
    open c_branches
    fetch next from c_branches into @BG
    declare @no_more_branches int
    set @no_more_branches=@@fetch_status
    if @no_more_branches<>0
    begin
        set @no_more_branches=0
        set @BG=0x0
    end

    while @no_more_branches=0
	begin
    /* Branches Loop */
        set @g=0	

        if @MergeNum =1
        begin
            select @BaseNumber = max( [Number])
            from [bu000] inner join [#Src] on [TypeGuid] =[#Src].[Type]
            where [Date] < @StartDate and ([Branch]=@BG or @BG=0x0)
            set @BaseNumber = isnull( @BaseNumber, 0)
        end

        declare c_BTL cursor for select [Type] from [#Src]
    	open c_BTL
    	
    	fetch next from c_BTL into @TG

    	while @@fetch_status=0
    	begin
        /* Bill Types Loop */
            if @MergeNum <>1
            begin
                select @BaseNumber = max( [Number])
                             from [bu000]
                             where [Date] < @StartDate
                                    and [TypeGuid] = @TG
                                    and ([Branch]=@BG or @BG=0x0)
                set @BaseNumber = isnull( @BaseNumber, 0)
                set @g=0
            end
        	      

            --update [bu000]
            declare c_budn cursor for
            --set [Number]=@g+@BaseNumber, @g=@g+1
            select [guid] from [bu000]
            where			
                    [TypeGuid] =@TG and [Date]>=@StartDate and ([Branch]=@BG or @BG=0x0)
            order by [Date],[Number]

            open c_budn

            fetch next from c_budn into @BuGuid

            while @@fetch_status=0
            begin
                /* generates sequence of negative numbers to prevent unique index 415 violation */
                update bu000
                set [Number]=-(@g+@BaseNumber), @g=@g+1
                where [guid]=@BuGuid
                fetch next from c_budn into @BuGuid
            end
            close c_budn
            deallocate c_budn	

    		/* New «processing er000» */
       		update [er]
         	set [er].[ParentNumber]=-[bu].[Number]
            from
                [bu000][bu] inner join [er000][er] on [bu].[Guid]= [er].[ParentGuid]
    		where
                [bu].[TypeGUID] =@TG and [Date]>=@StartDate and ([bu].[Branch]=@BG or @BG=0x0)
    		/* End «processing er000» */
    		
    		fetch next from c_BTL into @TG
        /* End Bill Types Loop */
    	end

    	close c_BTL
    	deallocate c_BTL	
    	fetch next from c_branches into @BG
    	set @no_more_branches=@@fetch_status
    /* End Branches Loop */
    end
    close c_branches
    deallocate c_branches
   
    /* reverse negatives */
    update bu000
    set [Number]=-[Number]
    where [Number]<0
     EXEC prcEnableTriggers 'BU000'
     EXEC prcCloseMaintenanceLog @LgGuid
end
##########################################################################
#END