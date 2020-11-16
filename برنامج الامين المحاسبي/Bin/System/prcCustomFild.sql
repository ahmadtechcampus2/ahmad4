################################################################################
CREATE PROCEDURE rep_GetCustomField 
@GroupGuid uniqueidentifier
as
SELECT Custom_Field000.Guid, Custom_Field000.Name, Custom_Field000.LatinName,    
       Custom_Field000.SortNumber, Custom_Field000.Mandatory,  
       Custom_Field_Format000.Guid AS FormatGuid,Custom_Field_Format000.Number AS FormatNumber,
       Custom_Field_Format000.Name AS FormatName,Custom_Field_Format000.LatinName AS FormatLatinName, 
       Custom_Field_Group000.Guid AS GroupGuid, Custom_Field_Group000.Name AS GroupName,   
       Custom_Field_Group000.LatinName AS GroupLatinName,   
       Custom_Field_Type000.Guid AS TypeGuid, Custom_Field_Type000.Name AS TypeName,  
       Custom_Field_Type000.LatinName AS TypeLatinName,Custom_Field_Type000.Number AS TypeNumber  
FROM   Custom_Field000 INNER JOIN Custom_Field_Format000 ON Custom_Field000.FormatGuid= Custom_Field_Format000.Guid 
                       INNER JOIN Custom_Field_Type000   ON Custom_Field000.TypeGuid = Custom_Field_Type000.Guid  
                       INNER JOIN Custom_Field_Group000  ON Custom_Field000.GGuid = Custom_Field_Group000.Guid  
WHERE     (Custom_Field000.GGuid = @GroupGuid)  
order by  Custom_Field000.SortNumber
			
################################################################################
CREATE PROCEDURE rep_GetCustomFieldFormat 
@TypeGuid uniqueidentifier
as
SELECT     Guid, Name, LatinName,Number 
FROM         Custom_Field_Format000 
where TypeGuid = @TypeGuid 
	
################################################################################
CREATE PROCEDURE  prc_CopyCustomField
@OldGroupGuid uniqueidentifier,
@NewGroupGuid uniqueidentifier,
@Name NVARCHAR(1000),
@LatinName NVARCHAR(1000)
as
insert into Custom_Field_Group000(Guid,Name,LatinName) 
                        values(@NewGroupGuid,@Name,@LatinName) 
INSERT INTO Custom_Field000 
                      (GGuid,TypeGuid, Name, LatinName, FormatGuid, SortNumber, Mandatory) 
SELECT     @NewGroupGuid,TypeGuid, Name, LatinName, FormatGuid, SortNumber, Mandatory 
FROM         Custom_Field000 CF 
where CF.GGuid=@OldGroupGuid 
###################################################################################
#END 	