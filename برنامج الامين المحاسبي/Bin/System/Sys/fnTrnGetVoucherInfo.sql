#################################################
CREATE FUNCTION fnTrnGetVoucherEntriesMenu
	(
		@VoucherGuid uniqueidentifier,
		@BranchGuid uniqueidentifier = 0x0
	)

	RETURNS @Result Table (ERType int, Branch uniqueidentifier)
AS	
Begin 
	insert into @Result
	select 
		er.ParentType, 
		Ce.Branch
	From Er000 as Er
	INNER JOIN Ce000 as ce on Ce.Guid = er.EntryGuid
 	where  Er.ParentGuid = @VoucherGuid
	AND (@BranchGuid = 0x0 OR Ce.Branch = @BranchGuid)
		
				
Return
end
#################################################
#END