#########################################################
CREATE proc prcDeleteRawMat	@Guid Uniqueidentifier 
AS
  Delete from man_form_rawMat000 where parentForm = @Guid
#########################################################	                      
#END