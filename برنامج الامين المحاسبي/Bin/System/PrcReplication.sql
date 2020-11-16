###########################################################################
CREATE VIEW branchandmask
as
SELECT  DISTINCT b.GUID, b.Number, b.Code, a.branchMask, b.Name bname --, a.Name aname
FROM dbo.br000 b JOIN dbo.ac000 a
ON dbo.fnGetBranchMask (b.Number) & a.branchMask > 0
###########################################################################
CREATE PROCEDURE prc_Replication_AddSnapShotFolder
@distributionDB AS sysname,
@directory nvarchar(MAX)
as
Exec('use '+ @distributionDB+'
if (not exists (select * from sysobjects where name = ''UIProperties'' and type = ''U '')) 
	create table UIProperties(id int) 
if (exists (select * from ::fn_listextendedproperty(''SnapshotFolder'', ''user'', ''dbo'', ''table'', ''UIProperties'', null, null))) 
	EXEC sp_updateextendedproperty N''SnapshotFolder'','''+@directory+''', ''user'', dbo, ''table'', ''UIProperties'' 
else 
	EXEC sp_addextendedproperty N''SnapshotFolder'','''+@directory+''', ''user'', dbo, ''table'', ''UIProperties''
	')
###########################################################################
CREATE PROCEDURE prc_Replication_AddDistributor
-- Specify the Distributor name.
@distributor AS sysname,
-- Specify the replication working directory.
@directory nvarchar(MAX)
as
-- Install the Distributor and the distribution database And Specify the distribution database.
DECLARE @distributionDB AS sysname = N'AmeenDistribution';

EXEC master..sp_adddistributor @distributor = @distributor;
-- Create a new distribution database using the defaults, including
-- using Windows Authentication.
EXEC master..sp_adddistributiondb @database = @distributionDB, 
    @security_mode = 1; 

EXEC prc_Replication_AddSnapShotFolder @distributionDB,@directory

-- Create a Publisher and enable  for replication.
EXEC ('use '+@distributionDB+' 
			 exec sp_adddistpublisher @publisher ='''+@distributor+''', 
						   @distribution_db = '''+@distributionDB+''',
						   @security_mode = 1, 
						   @working_directory ='''+ @directory+'''')
###########################################################################
CREATE PROCEDURE prc_Replication_AddMergeActicle
	@publicationName  AS sysname,
	@articleName      AS sysname,
	@articleSubset_FilterClause  nvarchar(1000),
	@UploadOption INT = 0 ,-- 0 bi Direction, 1 Subscribers With Update, 2 Subscribers With Out Update,
	@verifyesolverSignature INT = 1,
	@articleResolver NVARCHAR(MAX)=NULL

AS
SET NOCOUNT ON

DECLARE @CompensateForErrors NVARCHAR(5) = (CASE @UploadOption WHEN 0 THEN N'true' ELSE N'false' END)

EXEC sp_addmergearticle 
			@publication = @publicationName,
			@article = @articleName, 
			@source_owner = N'dbo', 
			@source_object =@articleName, 
			@type = N'table', 
			@description = N'',
			@creation_script = N'', 
			@pre_creation_cmd = N'drop', 
			@schema_option = 0x000000010C034FD1, 
			@identityrangemanagementoption = N'none', 
			@destination_owner = N'dbo', 
			@force_reinit_subscription = 1, 
			@column_tracking = N'false', 
			@subset_filterclause = @articleSubset_FilterClause, 
	        @vertical_partition = N'false', 
			@verify_resolver_signature = @verifyesolverSignature, 
			@article_resolver = @articleResolver,
			@allow_interactive_resolver = N'false', 
			@fast_multicol_updateproc = N'true', 
			@check_permissions = 0, 
			@subscriber_upload_options = @UploadOption, 
			@delete_tracking = N'true', 
			@compensate_for_errors = @CompensateForErrors,
			@stream_blob_columns = N'true', 
			@partition_options = 0
####################################################################
CREATE PROCEDURE prcReplication_AddPublisherACCoreTable
@publicationDB  AS sysname,
@UploadOption	AS INT
AS
SET NOCOUNT ON

DECLARE @publicationCore AS SYSNAME = 'ACCoreTable'

 EXEC (' USE '+@publicationDB+' 
			 EXEC sp_addmergepublication 
			  @publication = '''+@publicationCore+''',
			  @description = N''Merge publication of '+@publicationDB+''',
			  @publication_compatibility_level  = N''100RTM'', 
			  @validate_subscriber_info = N''HOST_NAME()'',
			  @conflict_logging = N''both'',
			  @dynamic_filters = N''true'',
			  @keep_partition_changes = N''true'',
			  @use_partition_groups = N''false'',
			  @allow_partition_realignment = N''true'',
			  @replicate_ddl = 0,
			  @retention =0')

	EXEC prc_Replication_AddMergeActicle 
				@publicationCore, 
				N'ac000', 
				N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END
				AND (GUID IN (SELECT GUID FROM FUCTEAC(HOST_NAME())) 
	or (( Not Exists(select * from Repac000 where HostName = Host_Name())  AND (GUID in (select guid from ac000 where isnumeric(HOST_NAME()) <> 1)))))'

	
	EXEC prc_Replication_AddMergeActicle 
			@publicationCore,			
			N'ci000',
			N''


	EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'cu000',
			N''
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'AddressCountry000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'AddressCity000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'AddressArea000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'CustAddress000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'CustAddressWorkingDays000',
			N''


  EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCCustomerTax000',
			N'',
			@UploadOption

  exec sp_addmergefilter 
		@publication =@publicationCore, 
		@article = N'cu000', 
		@filtername = N'cu000_ac000', 
		@join_articlename = N'ac000', 
		@join_filterclause = N'[ac000].[GUID] = [cu000].[AccountGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
		
	exec sp_addmergefilter 
		@publication = @publicationCore, 
		@article = N'CustAddress000',
		@filtername = N'CustAddress000_ac000', 
		@join_articlename = N'cu000', 
		@join_filterclause = N'[cu000].[GUID] = [CustAddress000].[CustomerGUID]',
		@join_unique_key = 1,
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


	exec sp_addmergefilter 
		@publication = @publicationCore, 
		@article = N'AddressArea000',
		@filtername = N'AddressArea000_CustAddress000', 
		@join_articlename = N'CustAddress000', 
		@join_filterclause = N'[CustAddress000].[AreaGUID] = [AddressArea000].[GUID]',
		@join_unique_key = 1,
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

	exec sp_addmergefilter 
		@publication = @publicationCore, 
		@article = N'AddressCity000',
		@filtername = N'AddressArea000_AddressCity000', 
		@join_articlename = N'AddressArea000', 
		@join_filterclause = N'[AddressArea000].[ParentGUID] = [AddressCity000].[GUID]',
		@join_unique_key = 1,
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


	exec sp_addmergefilter 
		@publication = @publicationCore, 
		@article = N'AddressCountry000',
		@filtername = N'AddressCountry000_AddressCity000', 
		@join_articlename = N'AddressCity000', 
		@join_filterclause = N'[AddressCity000].[ParentGUID] = [AddressCountry000].[GUID]',
		@join_unique_key = 1,
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

	exec sp_addmergefilter 
		@publication = @publicationCore, 
		@article = N'CustAddressWorkingDays000',
		@filtername = N'CustAddressWorkingDays000_CustAddress000', 
		@join_articlename = N'CustAddress000', 
		@join_filterclause = N'[CustAddress000].[GUID] = [CustAddressWorkingDays000].[AddressGUID]',
		@join_unique_key = 1,
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


	exec sp_addmergefilter 
		@publication =@publicationCore, 
		@article = N'GCCCustomerTax000', 
		@filtername = N'GCCCustomerTax000_cu000', 
		@join_articlename = N'cu000', 
		@join_filterclause = N'[cu000].[GUID] = [GCCCustomerTax000].[CustGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

	EXEC sp_addmergefilter 
			@publication = @publicationCore, 
			@article = N'ci000',
			@filtername = N'ci000_ac000', 
			@join_articlename = N'ac000', 
			@join_filterclause = N'[ac000].[GUID] = [ci000].[ParentGUID]',
			@join_unique_key = 1,
			@filter_type = 1, 
			@force_invalidate_snapshot = 0, 
			@force_reinit_subscription = 0
####################################################################
CREATE PROCEDURE prcReplication_AddPublisherGRCoreTable
@publicationDB  AS sysname,
@UploadOption	AS INT
AS
SET NOCOUNT ON

DECLARE @publicationCore AS SYSNAME = 'GRCoreTable'

 EXEC (' USE '+@publicationDB+' 
			 EXEC sp_addmergepublication 
			  @publication = '''+@publicationCore+''',
			  @description = N''Merge publication of '+@publicationDB+''',
			  @publication_compatibility_level  = N''100RTM'', 
			  @validate_subscriber_info = N''HOST_NAME()'',
			  @conflict_logging = N''both'',
			  @dynamic_filters = N''true'',
			  @keep_partition_changes = N''true'',
			  @use_partition_groups = N''false'',
			  @allow_partition_realignment = N''true'',
			  @replicate_ddl = 0,
			  @retention =0')

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'gr000', 
			N' 0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END
				AND (GUID IN (SELECT GUID FROM FUCTEGR(HOST_NAME())) 
	or (( Not Exists(select * from Repgr000 where HostName = HOST_NAME())  AND (GUID in (select guid from gr000 where isnumeric(HOST_NAME()) <> 1)))))',
		     @UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'mt000',
			N' 0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END
				AND (GroupGUID IN (SELECT GUID FROM FUCTEGR(HOST_NAME())) 
	or (( Not Exists(select * from Repgr000 where HostName = HOST_NAME())  AND (GroupGUID in (select guid from gr000 where isnumeric(HOST_NAME()) <> 1)))))',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'Segments000',
			N'',
			@UploadOption
			
 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'SegmentElements000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MaterialsSegmentsManagement000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MaterialSegments000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MaterialSegmentElements000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MaterialElements000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GroupSegments000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GroupSegmentElements000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCMaterialTax000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'RecostMaterials000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MTDW000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'MatTargets000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle  @publicationCore,
				 N'MatExBarcode000' ,N'' ,
				 @UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'as000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'gri000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'md000',
			N'',
			@UploadOption


 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			'DrugCompositions000',
				N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			'DrugIndications000',
				N'',
			@UploadOption

			
exec sp_addmergefilter 
		@publication =@publicationCore, 
		@article = N'GCCMaterialTax000', 
		@filtername = N'GCCMaterialTax000_mt000', 
		@join_articlename = N'mt000', 
		@join_filterclause = N'[mt000].[GUID] = [GCCMaterialTax000].[MatGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'MaterialsSegmentsManagement000',
		@filtername = N'MaterialsSegmentsManagement000_GroupSegments000',
		@join_articlename = N'GroupSegments000',
		@join_filterclause = N'[GroupSegments000].[Id] = [MaterialsSegmentsManagement000].[SegmentId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'SegmentElements000',
		@filtername = N'SegmentElements000_MaterialElements000',
		@join_articlename = N'MaterialElements000',
		@join_filterclause = N'[MaterialElements000].[ElementId] = [SegmentElements000].[Id]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'MaterialSegmentElements000',
		@filtername = N'MaterialSegmentElements000_MaterialSegments000',
		@join_articlename = N'MaterialSegments000',
		@join_filterclause = N'[MaterialSegments000].[Id] = [MaterialSegmentElements000].[MaterialSegmentId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'Segments000',
		@filtername = N'Segments000_MaterialSegments000',
		@join_articlename = N'MaterialSegments000',
		@join_filterclause = N'[MaterialSegments000].[SegmentId] = [Segments000].[Id]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'MaterialElements000',
		@filtername = N'MaterialElements000_mt000',
		@join_articlename = N'mt000',
		@join_filterclause = N'[mt000].[GUID] = [MaterialElements000].[MaterialId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'MaterialSegments000',
		@filtername = N'MaterialSegments000_mt000',
		@join_articlename = N'mt000',
		@join_filterclause = N'[mt000].[GUID] = [MaterialSegments000].[MaterialId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'GroupSegmentElements000',
		@filtername = N'GroupSegmentElements000_SegmentElements000',
		@join_articlename = N'SegmentElements000',
		@join_filterclause = N'[SegmentElements000].[Id] = [GroupSegmentElements000].[ElementId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0

exec sp_addmergefilter @publication = @publicationCore,
		@article = N'GroupSegments000',
		@filtername = N'GroupSegments000_Segments000',
		@join_articlename = N'Segments000',
		@join_filterclause = N'[Segments000].[Id] = [GroupSegments000].[SegmentId]', 
		@join_unique_key = 1,
		@filter_type = 1,
		@force_invalidate_snapshot = 0,
		@force_reinit_subscription = 0
#################################################################################
CREATE PROCEDURE prcReplication_AddPublisherCoreTable
@publicationDB  AS sysname,
@UploadOption	AS INT
AS

SET NOCOUNT ON
-- Enable merge replication on the publication database, using defaults.
DECLARE @publicationCore AS SYSNAME = 'CoreTable'
EXEC master..sp_replicationdboption 
  @dbname=@publicationDB, 
  @optname=N'merge publish',
  @value = N'true'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 EXEC (' USE '+@publicationDB+' 
			 EXEC sp_addmergepublication 
			  @publication = '''+@publicationCore+''',
			  @description = N''Merge publication of '+@publicationDB+''',
			  @publication_compatibility_level  = N''100RTM'', 
			  @validate_subscriber_info = N''HOST_NAME()'',
			  @conflict_logging = N''both'',
			  @dynamic_filters = N''true'',
			  @keep_partition_changes = N''true'',
			  @use_partition_groups = N''false'',
			  @allow_partition_realignment = N''true'',
			  @replicate_ddl = 0,
			  @retention =0')




 EXEC prc_Replication_AddMergeActicle 
				@publicationCore, 
				N'et000',
				N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END
				AND (GUID IN (SELECT guid FROM Repet000 where HostName= Host_Name()) 
	or (( Not Exists(select * from Repet000 where HostName = Host_Name())  AND (GUID in (select guid from et000 where isnumeric(HOST_NAME()) <> 1)))))
			',
			@UploadOption




 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'mc000',
			N'[type] = 8',
			@UploadOption


 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'sh000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'CustomizePrint000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'RichDocument000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'RichDocumentCalculatedField000',
			N'',
			@UploadOption
 
 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,      
			N'op000',
			N'[Type] = 0',
			1

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,  
			N'st000',
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
			WHEN isnumeric(HOST_NAME()) = 0 THEN 1
			END',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'us000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'ui000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore, 
			N'RepServer000',
			N'',
			@UploadOption

 --EXEC prc_Replication_AddMergeActicle 
	--		@publicationCore,			
	--		N'ci000',
	--		N''
			

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,			
			N'co000',
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
			WHEN isnumeric(HOST_NAME()) = 0 THEN 1
			END',
			@UploadOption


 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'br000',
			N'',
			@UploadOption


 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'My000',
			N'',
			@UploadOption



 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'bp000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'ma000',
			N'[Type] <> 5',
			@UploadOption



 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'Cond000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'CondItems000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'bdp000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'mh000',
			N'',
			@UploadOption

 --EXEC prc_Replication_AddMergeActicle 
	--		@publicationCore,	
	--		N'cp000',
	--		N'',
	--		@UploadOption





 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'sti000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'DistCe000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'DistCustClasses000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'DistCustStates000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'DistMatShowingMethods000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'AB000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'ABD000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'CostItem000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCCustLocations000',
			N'',
			@UploadOption




 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCTaxAccounts000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCTaxCoding000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCTaxDurations000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCTaxSettings000',
			N'',
			@UploadOption

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,	
			N'GCCTaxTypes000',
			N'',
			@UploadOption

 

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'LC000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'LCEntries000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'LCExpenses000',
			N''
 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'LCMain000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCore,
			N'LCRelatedExpense000',
			N''

exec sp_addmergefilter 
		@publication =@publicationCore, 
		@article = N'LCRelatedExpense000', 
		@filtername = N'LCRelatedExpense000_LC000', 
		@join_articlename = N'LC000', 
		@join_filterclause = N'[LC000].[GUID] = [LCRelatedExpense000].[LCGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

exec sp_addmergefilter 
		@publication =@publicationCore, 
		@article = N'LCEntries000', 
		@filtername = N'LCEntries000_LC000', 
		@join_articlename = N'LC000', 
		@join_filterclause = N'[LC000].[GUID] = [LCEntries000].[LCGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


--exec sp_addmergefilter 
--		@publication =@publicationCore, 
--		@article = N'cu000', 
--		@filtername = N'cu000_ac000', 
--		@join_articlename = N'ac000', 
--		@join_filterclause = N'[ac000].[GUID] = [cu000].[AccountGUID]', 
--		@join_unique_key = 1, 
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0


--exec sp_addmergefilter 
--		@publication = @publicationCore, 
--		@article = N'ci000',
--		@filtername = N'ci000_ac000', 
--		@join_articlename = N'ac000', 
--		@join_filterclause = N'[ac000].[GUID] = [ci000].[ParentGUID]',
--		@join_unique_key = 1,
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0

######################################################################
CREATE PROCEDURE prcReplication_AddSubscription
	@publicationPub  NVARCHAR(250),
	@subscriberServer   NVARCHAR(250),
	@subscriberDb  NVARCHAR(250),
	@subscriptionPriority FLOAT,
	@hostName NVARCHAR(250),
	@UploadOption INT = 0,
	@synctype INT=0
AS
	SET NOCOUNT ON

	DECLARE @SubType NVARCHAR(10) = N'Local'--(CASE @UploadOption WHEN 0 THEN N'Global' ELSE N'Local' END)
	DECLARE @synctypeSTR NVARCHAR(250) = (CASE @synctype WHEN 0 THEN N'Automatic' ELSE N'none' END)

	IF @UploadOption > 0 
		SET @subscriptionPriority = 0

	EXEC sp_addmergesubscription
			@publication =@publicationPub,
			@subscriber=@subscriberServer,
			@subscriber_db=@subscriberDb,
			@subscription_type = N'Push',
			@sync_type=@synctypeSTR, 
			@subscriber_type = @SubType, 
			@subscription_priority = 0,--@subscriptionPriority,
			@description = null, 
			@use_interactive_resolver = N'False', 
			@hostname = @hostName
######################################################################
CREATE  PROCEDURE PrcRepGetSubscriptionServer
@ServerName  NVARCHAR(250)   
AS 
	SET NOCOUNT ON
	SELECT	
			*
	FROM
		RepServer000 rep where rep.ServerName=@ServerName
######################################################################
CREATE PROCEDURE  prcReplication_AddPublisherBill
@publicationDB  AS sysname 
as
DECLARE @publicationBill AS SYSNAME='Bill'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 Exec (' USE '+@publicationDB+' 
			EXEC sp_addmergepublication 
			  @publication ='''+@publicationBill+''',
			  @description = N''Merge publication of '+@publicationDB+''',
			  @publication_compatibility_level  = N''100RTM'', 
			  @validate_subscriber_info = N''HOST_NAME()'',
			  @conflict_logging = N''both'',
			  @dynamic_filters = N''true'',
			  @keep_partition_changes = N''true'',
			  @use_partition_groups = N''false'',
			  @allow_partition_realignment = N''true'',
			  @replicate_ddl=0,
			  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
				@publicationBill,
				N'BillColected000', 
				''

  EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'di000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'pt000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SalesTax000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'snc000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'snt000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'ti000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'ts000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'tt000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'ContractBillItems000', 
	''
	
  
  EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SOBillTypes000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SOConditionalDiscounts000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SOItems000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SOOfferedItems000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SOPeriodBudgetItem000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'SpecialOffers000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'bt000', 
	N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
                WHEN isnumeric(HOST_NAME()) = 0 THEN 1 END
	AND (GUID IN (SELECT guid FROM Repbt000 where HostName= Host_Name()) 
	or (( Not Exists(select * from Repbt000 where HostName = Host_Name())  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))'


 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'bu000', 
	N'([Branch] IN (SELECT GUID FROM br000 WHERE number = CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END) 
              AND TypeGUID IN (SELECT GUID FROM Repbt000 WHERE HostName = Host_Name())
       ) 
       OR 
       ((
              TypeGUID IN (SELECT GUID FROM Repbt000 WHERE HostName = Host_Name() AND ISNUMERIC(Host_Name()) <> 1)
       ) 
       OR
       (
              NOT EXISTS(SELECT * FROM Repbt000 WHERE HostName = Host_Name()) 
              AND TypeGUID IN (SELECT GUID FROM bt000)-- WHERE ISNUMERIC(2) <> 1)
       ))',
	   0,
	   0,
	   N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'


 EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'bi000', 
	'',
	 0,
	 0,
    N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'

EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'BillRel000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'AssemBill000', 
	''
EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'btStateOrder000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'AssemBillType000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'BillOperationState000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationBill,
	N'bmd000', 
	''


EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SalesTax000', 
		@filtername = N'SalesTax000_bt000', 
		@join_articlename = N'bt000', 
		@join_filterclause = N'[bt000].[GUID] = [SalesTax000].[BillTypeGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SOBillTypes000', 
		@filtername = N'SOBillTypes000_bt000', 
		@join_articlename = N'bt000', 
		@join_filterclause = N'[bt000].[GUID] = [SOBillTypes000].[BillTypeGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'tt000', 
		@filtername = N'tt000_bt000', 
		@join_articlename = N'bt000', 
		@join_filterclause = N'[bt000].[GUID] = [tt000].[InTypeGUID] OR [bt000].[GUID] = [tt000].[OutTypeGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'bi000', 
		@filtername = N'bi000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [bi000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'BillColected000', 
		@filtername = N'BillColected000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [BillColected000].[CollectedGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'di000', 
		@filtername = N'di000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [di000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'pt000', 
		@filtername = N'pt000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [pt000].[RefGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'snt000', 
		@filtername = N'snt000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [snt000].[buGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'ts000', 
		@filtername = N'ts000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [ts000].[InBillGUID] OR [bu000].[GUID] = [ts000].[OutBillGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'ti000', 
		@filtername = N'ti000_pt000', 
		@join_articlename = N'pt000', 
		@join_filterclause = N'[pt000].[GUID] = [ti000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'snc000', 
		@filtername = N'snc000_snt000', 
		@join_articlename = N'snt000', 
		@join_filterclause = N'[snt000].[ParentGUID] = [snc000].[GUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'ContractBillItems000', 
		@filtername = N'ContractBillItems000_SOItems000', 
		@join_articlename = N'SOItems000', 
		@join_filterclause = N'[SOItems000].[ItemGUID] = [ContractBillItems000].[ContractItemGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SOConditionalDiscounts000', 
		@filtername = N'SOConditionalDiscounts000_SpecialOffers000', 
		@join_articlename = N'SpecialOffers000', 
		@join_filterclause = N'[SpecialOffers000].[GUID] = [SOConditionalDiscounts000].[SpecialOfferGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SOItems000', 
		@filtername = N'SOItems000_SpecialOffers000', 
		@join_articlename = N'SpecialOffers000', 
		@join_filterclause = N'[SpecialOffers000].[GUID] = [SOItems000].[SpecialOfferGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SOOfferedItems000', 
		@filtername = N'SOOfferedItems000_SpecialOffers000', 
		@join_articlename = N'SpecialOffers000', 
		@join_filterclause = N'[SpecialOffers000].[GUID] = [SOOfferedItems000].[SpecialOfferGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'SOPeriodBudgetItem000', 
		@filtername = N'SOPeriodBudgetItem000_SpecialOffers000', 
		@join_articlename = N'SpecialOffers000', 
		@join_filterclause = N'[SpecialOffers000].[GUID] = [SOPeriodBudgetItem000].[SpecialOfferGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationBill, 
		@article = N'BillRel000', 
		@filtername = N'BillRel000_bu000', 
		@join_articlename = N'bu000', 
		@join_filterclause = N'[bu000].[GUID] = [BillRel000].[BillGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
#########################################################################
CREATE PROCEDURE prcReplication_AddPublisherLogFile
	@publicationDB  AS sysname 
AS

DECLARE @publicationLogFile AS SYSNAME = 'LogFile'


Exec (' USE ' + @publicationDB + ' 
		EXEC sp_addmergepublication 
			@publication =''' + @publicationLogFile + ''',
			@description = N''Merge publication of ' + @publicationDB + ''',
			@publication_compatibility_level  = N''100RTM'', 
			@validate_subscriber_info = null,
			@conflict_logging = N''both'',
			@dynamic_filters = N''false'',
			@keep_partition_changes = N''false'',
			@use_partition_groups = N''false'',
			@replicate_ddl=0,
			@retention =0')

EXEC prc_Replication_AddMergeActicle 
	@publicationLogFile,
	N'log000', 
	null
#########################################################################
CREATE PROCEDURE prcReplication_AddPublisherUserMessages
	@publicationDB  AS sysname 
AS

DECLARE @publicationUserMessages AS SYSNAME = 'UserMessages'

Exec (' USE ' + @publicationDB + ' 
		EXEC sp_addmergepublication 
			@publication =''' + @publicationUserMessages + ''',
			@description = N''Merge publication of ' + @publicationDB + ''',
			@publication_compatibility_level  = N''100RTM'', 
			@validate_subscriber_info = null,
			@conflict_logging = N''both'',
			@dynamic_filters = N''false'',
			@keep_partition_changes = N''false'',
			@use_partition_groups = N''false'',
			@replicate_ddl=0,
			@retention =0')

EXEC prc_Replication_AddMergeActicle 
	@publicationUserMessages,
	N'SentUserMessage000', 
	null

EXEC prc_Replication_AddMergeActicle 
	@publicationUserMessages,
	N'ReceivedUserMessage000', 
	null

EXEC prc_Replication_AddMergeActicle 
	@publicationUserMessages,
	N'UserMessagesLog000', 
	null
#########################################################################
CREATE PROCEDURE  prcReplication_AddPublisherEntry
@publicationDB  AS sysname 
AS

DECLARE @publicationEntry AS SYSNAME='Entries'

 Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationEntry+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @validate_subscriber_info = N''HOST_NAME()'',
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''true'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
	      @retention =0')

  EXEC prc_Replication_AddMergeActicle 
				@publicationEntry,
				N'ce000', 
				N'Branch IN (select guid from br000 where number = case when isnumeric(HOST_NAME())=1 then HOST_NAME() else number end) 
OR ((TypeGUID in (select guid from Repbt000 where HostName = HOST_NAME() and isnumeric(HOST_NAME()) <> 1) 
    OR (NOT EXISTS(select * from Repbt000 where  HostName=HOST_NAME()) 
              AND TypeGUID in (select guid from bt000)))
    OR(TypeGUID in (select guid from RepEt000 where HostName = HOST_NAME() and isnumeric(HOST_NAME()) <> 1) 
     OR(NOT EXISTS(select * from RepEt000 where HostName = HOST_NAME()) AND TypeGUID in (select guid from et000))) 
    OR (TypeGUID in (select guid from Repnt000 where HostName = HOST_NAME() and isnumeric(HOST_NAME()) <> 1) 
     OR (NOT EXISTS(select * from Repnt000 where HostName = HOST_NAME()) 
              AND TypeGUID in (select guid from nt000)))
    OR TypeGUID =0x0 AND ([Branch] IN (select guid from br000 where number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end) OR Branch = 0x0))',
	0,
	   0,
	   N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'


  EXEC prc_Replication_AddMergeActicle 
	@publicationEntry,
	N'en000', 
	'',
	0,
	0,
	N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'

	
	EXEC prc_Replication_AddMergeActicle 
	@publicationEntry,
	N'er000', 
	N'',
	0,
	0,
	N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'

 EXEC prc_Replication_AddMergeActicle 
	@publicationEntry,
	N'py000', 
	N'(
		[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END) 
		AND TypeGUID IN 
		(SELECT GUID FROM Repet000 WHERE HostName = Host_Name())
	) 
	OR 
	((
		TypeGUID IN 
		(SELECT GUID FROM Repet000 WHERE HostName = Host_Name() AND ISNUMERIC(Host_Name()) <> 1)
	) 
	OR
	(
		NOT EXISTS(SELECT * FROM Repet000 WHERE HostName = Host_Name()) 
		AND (TypeGUID IN (SELECT GUID FROM et000 ))
	))',
	0,
	   0,
	   N'Microsoft SQL Server Subscriber Always Wins Conflict Resolver'


EXEC sp_addmergefilter 
		@publication =@publicationEntry, 
		@article = N'en000', 
		@filtername = N'en000_ce000', 
		@join_articlename = N'ce000', 
		@join_filterclause = N'[ce000].[GUID] = [en000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationEntry, 
		@article = N'er000', 
		@filtername = N'er000_ce000', 
		@join_articlename = N'ce000', 
		@join_filterclause = N'[ce000].[GUID] = [er000].[EntryGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
#########################################################################
CREATE PROC prcRepGetSubscriberJobHistory
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX)
AS

DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @job_id1 UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName
	SET @subscriber_db = @subscriberDb

DECLARE @tmp_sp_help_jobhistory TABLE (
    instance_id INT NULL, 
    job_id UNIQUEIDENTIFIER NULL, 
    job_name SYSNAME NULL, 
    step_id INT NULL, 
    step_name SYSNAME NULL, 
    sql_message_id INT NULL, 
    sql_severity INT NULL, 
    message NVARCHAR(4000) NULL, 
    run_status INT NULL, 
    run_date INT NULL, 
    run_time INT NULL, 
    run_duration INT NULL, 
    operator_emailed SYSNAME NULL, 
    operator_netsent SYSNAME NULL, 
    operator_paged SYSNAME NULL, 
    retries_attempted INT NULL, 
    server SYSNAME NULL  
)

SELECT @job_id1 = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSmerge_agents 
	WHERE  publisher_db  = @publisher_db
		AND    Publication   = @Publication
		AND	   subscriber_db = @subscriber_db

INSERT INTO @tmp_sp_help_jobhistory 
EXEC msdb.dbo.sp_help_jobhistory 
    @job_id = @job_id1,
    @mode='FULL'

INSERT INTO @tmp_sp_help_jobhistory
SELECT  -1, @job_id1, sj.name, 0, 'Run agent.', 0, 0, '', 10,
CONVERT(VARCHAR(100),sja.run_requested_date,112 ), REPLACE(CONVERT(VARCHAR(100),sja.run_requested_date,108 ),':',''),
	0, NULL, NULL, NULL, 0, ''
	FROM msdb.dbo.sysjobactivity AS sja
	INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id
	WHERE sja.start_execution_date IS NOT NULL
	   AND sja.stop_execution_date IS NULL
	   AND sj.job_id = @job_id1
        
SELECT 
    CASE tshj.run_date WHEN 0 THEN NULL ELSE
    CONVERT(DATETIME, 
            STUFF(STUFF(CAST(tshj.run_date AS NCHAR(8)), 7, 0, '-'), 5, 0, '-') + N' ' + 
            STUFF(STUFF(SUBSTRING(CAST(1000000 + tshj.run_time AS NCHAR(7)), 2, 6), 5, 0, ':'), 3, 0, ':'), 
            120) END AS [RunDate],
	STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(tshj.run_duration AS VARCHAR(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS Duration,
    CASE WHEN tshj.run_status = 0 THEN 'Failed'
         WHEN tshj.run_status = 1 THEN 'Succeeded'
         WHEN tshj.run_status = 2 THEN 'Retry'
         WHEN tshj.run_status = 3 THEN 'Cancelled'
         WHEN tshj.run_status = 4 THEN 'InProgress' 
		 WHEN tshj.run_status = 10 THEN 'Running'
         ELSE 'Unknown'
	END JobOutcome,
	tshj.message
FROM @tmp_sp_help_jobhistory AS tshj
	WHERE tshj.step_id = 0
		ORDER BY RunDate DESC
###############################################################################
CREATE PROC prcRepGetPublisherJobHistory
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX)
AS

DECLARE @publisher_db SYSNAME, @publication SYSNAME, @job_id1 UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName

DECLARE @tmp_sp_help_jobhistory TABLE (
    instance_id INT NULL, 
    job_id UNIQUEIDENTIFIER NULL, 
    job_name SYSNAME NULL, 
    step_id INT NULL, 
    step_name SYSNAME NULL, 
    sql_message_id INT NULL, 
    sql_severity INT NULL, 
    message NVARCHAR(4000) NULL, 
    run_status INT NULL, 
    run_date INT NULL, 
    run_time INT NULL, 
    run_duration INT NULL, 
    operator_emailed SYSNAME NULL, 
    operator_netsent SYSNAME NULL, 
    operator_paged SYSNAME NULL, 
    retries_attempted INT NULL, 
    server SYSNAME NULL  
)

SELECT @job_id1 = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSsnapshot_agents 
	WHERE  publisher_db  = @publisher_db
		AND    Publication   = @Publication

INSERT INTO @tmp_sp_help_jobhistory 
EXEC msdb.dbo.sp_help_jobhistory 
    @job_id = @job_id1,
    @mode='FULL' 

INSERT INTO @tmp_sp_help_jobhistory
SELECT  -1, @job_id1, sj.name, 0, 'Run agent.', 0, 0, '', 10,
CONVERT(VARCHAR(100),sja.run_requested_date,112 ), REPLACE(CONVERT(VARCHAR(100),sja.run_requested_date,108 ),':',''),
	0, NULL, NULL, NULL, 0, ''
	FROM msdb.dbo.sysjobactivity AS sja
	INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id
	WHERE sja.start_execution_date IS NOT NULL
	   AND sja.stop_execution_date IS NULL
	   AND sj.job_id = @job_id1


SELECT sj.name AS [Job Name], --SJH.run_date, SJH.run_time, 
CONVERT(VARCHAR(10), MSDB.dbo.agent_datetime(SJH.run_date,SJH.run_time), 105) + ' ' + 
CONVERT(VARCHAR(10), MSDB.dbo.agent_datetime(SJH.run_date,SJH.run_time), 108) AS OperationDate,
STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(SJH.run_duration as varchar(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') Duration, 
    CASE WHEN SJH.run_status = 0 THEN 'Failed'
         WHEN SJH.run_status = 1 THEN 'Succeeded'
         WHEN SJH.run_status = 2 THEN 'Retry'
         WHEN SJH.run_status = 3 THEN 'Cancelled'
		 WHEN SJH.run_status = 10 THEN 'Running'
         ELSE 'Unknown'
 END JobOutcome,
 CASE WHEN SJH.run_status=0 THEN SJH.message
         ELSE ' ' 
    END Remark
FROM  @tmp_sp_help_jobhistory SJH JOIN MSDB..sysjobs SJ ON SJH.job_id=sj.job_id 
	WHERE SJH.step_id = 0 
		ORDER BY OperationDate DESC
###############################################################################
CREATE PROCEDURE  prcReplication_AddPublisherCheque
@publicationDB  AS sysname 
as
DECLARE @publicationCheque AS SYSNAME='Cheque'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationCheque+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @validate_subscriber_info = N''HOST_NAME()'',
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''true'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
		  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'Bank000', 
			N''			

  EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'ch000', 
			''
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'ChequeHistory000', 
			''

 EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'ChequesPortfolio000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'ColCh000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationCheque,
			N'nt000', 
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END 
				and (guid in (select guid from Repnt000 where Host_Name() = HostName) 
				or ((( NOT EXISTS(select * from Repnt000 where Host_Name() = HostName) and (GUID in (select guid from nt000 where isnumeric(HOST_NAME()) <> 1))) 
					 )))'


EXEC sp_addmergefilter 
		@publication =@publicationCheque, 
		@article = N'ChequeHistory000', 
		@filtername = N'ChequeHistory000_ch000', 
		@join_articlename = N'ch000', 
		@join_filterclause = N'[ch000].[GUID] = [ChequeHistory000].[ChequeGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationCheque, 
		@article = N'ColCh000', 
		@filtername = N'ColCh000_ch000', 
		@join_articlename = N'ch000', 
		@join_filterclause = N'[ch000].[GUID] = [ColCh000].[ChGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

		EXEC sp_addmergefilter 
		@publication =@publicationCheque, 
		@article = N'ch000', 
		@filtername = N'ch000_nt000', 
		@join_articlename = N'nt000', 
		@join_filterclause = N'[nt000].[GUID] = [ch000].[TypeGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
##############################################################################################
CREATE PROCEDURE  prcReplication_AddPublisherOrders
@publicationDB  AS sysname 
as
DECLARE @publicationOrders AS SYSNAME='Orders'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 Exec (' USE '+@publicationDB+' 
EXEC sp_addmergepublication 
  @publication ='''+@publicationOrders+''',
  @description = N''Merge publication of '+@publicationDB+''',
  @publication_compatibility_level  = N''100RTM'', 
  @validate_subscriber_info = N''HOST_NAME()'',
  @conflict_logging = N''both'',
  @dynamic_filters = N''true'',
  @keep_partition_changes = N''true'',
  @use_partition_groups = N''false'',
  @allow_partition_realignment = N''true'',
  @replicate_ddl=0,
			  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'oit000', 
			N''			

  EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OITVS000', 
			'[OTGUID]  in (select [bt000].[GUID] from bt000 
where (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END
) 

AND (GUID IN (SELECT guid FROM Repbt000 where   HostName =Host_Name()) 
or (( NOT EXISTS(select * from Repbt000 where   HostName = Host_Name())  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))
)'
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'ORADDINFO000', 
			'[ParentGuid] in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end) AND
 (TypeGUID in (select guid from Repbt000 where HostName =  Host_Name() ) 
or ((( NOT EXISTS(select * from Repbt000 where   HostName= Host_Name() ) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))))'

 EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderAlternativeUsers000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderAlternativeUserTypes000', 
			N'[OrderTypeGUID]  in (select [bt000].[GUID] from bt000 
where (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END
) 
AND (GUID IN (SELECT guid FROM Repbt000 where   HostName = Host_Name()) 
or (( NOT EXISTS(select * from Repbt000 where   HostName = Host_Name())  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))
)'

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderApprovals000', 
			N'[OrderGuid] in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end) AND
(TypeGUID in (select guid from Repbt000 where   HostName = Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where   HostName = Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))))'
EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderApprovalStates000', 
			N''


EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderPayments000', 
			N'[BillGuid]  in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and (TypeGUID in (select guid from Repbt000 where   HostName = Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where  HostName = Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))))'


EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrdersStatesDelays000', 
			N'[OrderGUID]  in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and  
 (TypeGUID in (select guid from Repbt000 where HostName= Host_Name() ) 
or ((( NOT EXISTS(select * from Repbt000 where HostName = Host_Name() ) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))
)'

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderTimeSchedule000', 
			N'[OrderTypeGUID]  in (select [bt000].[GUID] from bt000 
where (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END
)  and
(GUID IN (SELECT guid FROM Repbt000 where   HostName = Host_Name() ) 
or (( NOT EXISTS(select * from Repbt000 where HostName = Host_Name() )  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))
)'

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OrderTimeScheduleItems000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'ori000', 
			N'[POGUID]  in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and 
 (TypeGUID in (select guid from Repbt000 where  HostName = Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where  HostName = Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))
)'


EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'TrnOrdBu000', 
			N'[OrderGuid]  in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and
 (TypeGUID in (select guid from Repbt000 where  HostName = Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where  HostName = Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))
)'

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'OMSG000', 
			N'[ParentGuid]  in (select [bt000].[GUID] from bt000 
where (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END
) 
AND (GUID IN (SELECT guid FROM Repbt000 where HostName=Host_Name() ) 
or (( NOT EXISTS(select * from Repbt000 where HostName= Host_Name())  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))
)'

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'MaturityBills000', 
			N'[BillTypeGuid] in (select [bt000].[GUID] from bt000  
WHERE (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END )
AND (GUID IN (SELECT guid FROM Repbt000 where HostName=Host_Name()) 
or (( NOT EXISTS(select * from Repbt000 where HostName=Host_Name() )  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))'
			

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'ORREL000', 
			N'[ORGuid] in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and  
 (TypeGUID in (select guid from Repbt000 where  HostName =Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where  HostName =Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))
)'
			

EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'USRAPP000', 
			N'[ParentGuid] in (select [bt000].[GUID] from bt000 
where (0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
WHEN isnumeric(HOST_NAME()) = 0 THEN 1
 END
)  AND
(GUID IN (SELECT guid FROM Repbt000 where Host_Name() = HostName) 
or (( NOT EXISTS(select * from Repbt000 where Host_Name() = HostName)  AND (GUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1))))))'
			
			
EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'ppi000', 
			N'[SOGuid] in (select [bu000].[GUID] from bu000 
where [Branch] in (select guid from br000 WHERE number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
 and 
 (TypeGUID in (select guid from Repbt000 where HostName =Host_Name()) 
or ((( NOT EXISTS(select * from Repbt000 where HostName =Host_Name()) AND (TypeGUID in (select guid from bt000 where isnumeric(HOST_NAME()) <> 1)))))))'

 EXEC prc_Replication_AddMergeActicle 
			@publicationOrders,
			N'ppo000', 
			N''
			


EXEC sp_addmergefilter 
		@publication =@publicationOrders, 
		@article = N'oit000', 
		@filtername = N'oit000_OITVS000', 
		@join_articlename = N'OITVS000', 
		@join_filterclause = N'[OITVS000].[ParentGuid] = [oit000].[GUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationOrders, 
		@article = N'OrderAlternativeUsers000', 
		@filtername = N'OrderAlternativeUsers000_OrderAlternativeUserTypes000', 
		@join_articlename = N'OrderAlternativeUserTypes000', 
		@join_filterclause = N'[OrderAlternativeUserTypes000].[ParentGUID] = [OrderAlternativeUsers000].[GUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationOrders, 
		@article = N'OrderApprovalStates000', 
		@filtername = N'OrderApprovalStates000_OrderApprovals000', 
		@join_articlename = N'OrderApprovals000', 
		@join_filterclause = N'[OrderApprovals000].[GUID] = [OrderApprovalStates000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationOrders, 
		@article = N'OrderTimeScheduleItems000', 
		@filtername = N'OrderTimeScheduleItems000_OrderTimeSchedule000', 
		@join_articlename = N'OrderTimeSchedule000', 
		@join_filterclause = N'[OrderTimeSchedule000].[GUID] = [OrderTimeScheduleItems000].[OTSParent]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationOrders, 
		@article = N'ppo000', 
		@filtername = N'ppo000_ppi000', 
		@join_articlename = N'ppi000', 
		@join_filterclause = N'[ppi000].[PPOGuid] = [ppo000].[GUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
####################################################################################################
CREATE PROCEDURE prcReplication_AddPublisherPos
	@publicationDB  AS SYSNAME 
AS
DECLARE @publicationPos AS SYSNAME = 'Pos'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 EXEC (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationPos+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @validate_subscriber_info = N''HOST_NAME()'',
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''true'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
			  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'bg000', 
			N''			

  EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'Department000', 
			N'BranchID IN (SELECT guid FROM br000 WHERE number = CASE WHEN isnumeric(HOST_NAME()) = 1 THEN HOST_NAME() ELSE number END) OR isnumeric(HOST_NAME()) = 0'
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DepartmentGroups000', 
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountRange000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountTypes000', 
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountTypesCard000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountTypesItems000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'PosConfig000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSCurrencyItem000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'CheckAcc000',
			N'' 


EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSInfos000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestDepartment000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestEntry000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestKitchen000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestOrderItemNote000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestTaxes000',
			N''


EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'RestConfig000',
			N'' 

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'Salesman000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSOrder000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSOrderItems000', 
			N''


EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountCard000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'DiscountCardStatus000', 
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				 END'

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'OfferedItems000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'SpecialOffer000', 
			N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'SpecialOfferDetails000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'bgi000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSOfferDiscount000', 
			N''
			
EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'POSUserBills000', 
			N''
			
EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'SCCustomers000', 
			N'[CustomerSupplier] IN (
				SELECT guid
					FROM cu000 
					WHERE AccountGUID IN (SELECT guid 
					FROM [dbo].[ac000] 
					WHERE 0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
					WHEN isnumeric(HOST_NAME()) = 0 THEN 1
					 END ) )'

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'PcOP000', 
			N''

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'FileOP000', 
			N'',
			1

EXEC prc_Replication_AddMergeActicle 
			@publicationPos,
			N'UserOP000', 
			N''

--EXEC sp_addmergefilter
--		@publication =@publicationPos, 
--		@article = N'bg000', 
--		@filtername = N'bg000_PosConfig000', 
--		@join_articlename = N'PosConfig000', 
--		@join_filterclause = N'[PosConfig000].[Guid] = [bg000].[ConfigID]', 
--		@join_unique_key = 1, 
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'bgi000', 
		@filtername = N'bgi000_bg000', 
		@join_articlename = N'bg000', 
		@join_filterclause = N'[bg000].[Guid] = [bgi000].[ParentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'DepartmentGroups000', 
		@filtername = N'DepartmentGroups000_Department000', 
		@join_articlename = N'Department000', 
		@join_filterclause = N'[Department000].[GUID] = [DepartmentGroups000].[ParentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'Salesman000', 
		@filtername = N'Salesman000_Department000', 
		@join_articlename = N'Department000', 
		@join_filterclause = N'[Department000].[GUID] = [Salesman000].[DepartmentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'DiscountCard000', 
		@filtername = N'DiscountCard000_DiscountCardStatus000', 
		@join_articlename = N'DiscountCardStatus000', 
		@join_filterclause = N'[DiscountCardStatus000].[Guid] = [DiscountCard000].[State]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'DiscountRange000', 
		@filtername = N'DiscountRange000_DiscountTypes000', 
		@join_articlename = N'DiscountTypes000', 
		@join_filterclause = N'[DiscountTypes000].[GUID] = [DiscountRange000].[ParentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'DiscountTypesCard000', 
		@filtername = N'DiscountTypesCard000_DiscountTypes000', 
		@join_articlename = N'DiscountTypes000', 
		@join_filterclause = N'[DiscountTypes000].[GUID] = [DiscountTypesCard000].[DiscType]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'DiscountTypesItems000', 
		@filtername = N'DiscountTypesItems000_DiscountTypes000', 
		@join_articlename = N'DiscountTypes000', 
		@join_filterclause = N'[DiscountTypes000].[GUID] = [DiscountTypesItems000].[ParentGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'OfferedItems000', 
		@filtername = N'OfferedItems000_SpecialOffer000', 
		@join_articlename = N'SpecialOffer000', 
		@join_filterclause = N'[SpecialOffer000].[Guid] = [OfferedItems000].[ParentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationPos, 
		@article = N'SpecialOfferDetails000', 
		@filtername = N'SpecialOfferDetails000_SpecialOffer000', 
		@join_articlename = N'SpecialOffer000', 
		@join_filterclause = N'[SpecialOffer000].[Guid] = [SpecialOfferDetails000].[ParentID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
		
--EXEC sp_addmergefilter 
--		@publication =@publicationPos, 
--		@article = N'PcOP000', 
--		@filtername = N'PcOP000_PosConfig000', 
--		@join_articlename = N'PosConfig000', 
--		@join_filterclause = N'[PosConfig000].[HostName] = [PcOP000].[CompName]', 
--		@join_unique_key = 1, 
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0
		
--EXEC sp_addmergefilter 
--		@publication =@publicationPos, 
--		@article = N'POSUserBills000', 
--		@filtername = N'POSUserBills000_PosConfig000', 
--		@join_articlename = N'PosConfig000', 
--		@join_filterclause = N'[PosConfig000].[Guid] = [POSUserBills000].[ConfigID]', 
--		@join_unique_key = 1, 
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0
###############################################################################################
CREATE PROCEDURE DisableDistributor
@PublisherDb NVARCHAR(MAX)
AS
SET NOCOUNT ON
   
	DECLARE @p NVARCHAR(max);
	DECLARE db_cursor CURSOR FOR  
	SELECT publication FROM AmeenDistribution..MSpublications
			WHERE publisher_db=@PublisherDb

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @p   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

	   EXEC sp_dropmergesubscription  @publication=@p,@subscription_type='all',@subscriber='all'
	   EXEC sp_dropmergepublication @p;
	
	FETCH NEXT FROM db_cursor INTO @p   
	END   
	CLOSE db_cursor   
	DEALLOCATE db_cursor

	DELETE FROM RepDistributor000
	DELETE FROM RepServer000  
	DELETE FROM RepOp000
	DELETE FROM Repbt000
	DELETE FROM Repnt000
	DELETE FROM Repet000
	DELETE FROM Repac000
	DELETE FROM Repgr000
	DELETE FROM RepConflictsInfo000
	DELETE FROM RepFreezecolval000
	DELETE FROM RepSubscriberInfo000
	EXEC sp_removedbreplication @PublisherDb
###############################################################################################
CREATE  PROCEDURE PrcBackupMergeReplication
	@PublisherDb NVARCHAR(MAX)
AS
	SET NOCOUNT ON
	DECLARE @publisher_db SYSNAME, 
			@jobId UNIQUEIDENTIFIER

	SET @publisher_db  = @PublisherDb

	SELECT DISTINCT 
		pubs.name publication,
		subs.subscriber_server subscriber_name,
		subs.db_name subscriber_db,
		replinfo.hostname hostname,
		replinfo.merge_jobid Id
	INTO #JobsId
	FROM  dbo.sysmergesubscriptions        subs,
			dbo.MSmerge_replinfo        replinfo,
			dbo.sysmergepublications    pubs
	WHERE   subs.status <> 2 
			and pubs.pubid = subs.pubid
			and subs.pubid <> subs.subid
			and replinfo.repid = subs.subid
			and (suser_sname(suser_sid()) = replinfo.login_name OR is_member('db_owner')=1 OR is_srvrolemember('sysadmin') = 1)                   
			and (pubs.publisher_db = @publisher_db collate database_default)          
			and (subs.subscriber_type <> 3)

	INSERT INTO RepSubscriberInfo000
	SELECT	NEWID() GUID,	
			publication,
			subscriber_db,
			subscriber_name,
			hostname,
			freq_type,
			freq_interval,
			freq_subday_type,
			freq_subday_interval,
			freq_relative_interval,
			freq_recurrence_factor,
			active_start_date,
			active_end_date,
			active_start_time,
			active_end_time
		FROM
			msdb.dbo.sysjobschedules AS js
			INNER JOIN msdb.dbo.sysschedules AS s ON js.schedule_id = s.schedule_id
			INNER JOIN #JobsId j ON j.Id=js.job_id

	DECLARE @p NVARCHAR(max);
	DECLARE db_cursor CURSOR FOR  
	SELECT publication FROM AmeenDistribution..MSpublications
			WHERE publisher_db=@PublisherDb

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @p   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   

	  IF NOT EXISTS (select  Publication from RepSubscriberInfo000 where Publication=@p)
	BEGIN
		INSERT INTO RepSubscriberInfo000 (Guid,Publication) values(NEWID(),@p)
	END
	   EXEC sp_dropmergesubscription  @publication=@p,@subscription_type='all',@subscriber='all'
	   EXEC sp_dropmergepublication @p;
	
	FETCH NEXT FROM db_cursor INTO @p   
	END   
	CLOSE db_cursor   
	DEALLOCATE db_cursor
###############################################################################################
CREATE PROC prcRepRunSubscriberJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX)
AS
	DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @jobId UNIQUEIDENTIFIER , @JobName NVARCHAR(250)
		SET @publisher_db  = @PublisherDb
		SET @Publication   = @ArtcleName
		SET @subscriber_db = @subscriberDb

	SELECT CONVERT(UNIQUEIDENTIFIER, job_id ) AS Id,subscriber_db
		INTO #JobsId
		FROM Ameendistribution.dbo.MSmerge_agents 
			WHERE  publisher_db  = @publisher_db
				AND    (@Publication = '' OR Publication = @Publication)
				AND	 (@subscriber_db = '' OR  subscriber_db = @subscriber_db)

	WHILE EXISTS (SELECT 1 FROM #JobsId)
	BEGIN
	SELECT TOP 1
		@jobId = Id,
		@subscriber_db = subscriber_db
			FROM #JobsId

	EXEC prc_SJ_ExecuteJob @jobId

	DELETE #JobsId
			WHERE Id = @jobId
	END

	SET @JobName ='Conflict'+ @subscriberDb+'CoreTable'
	EXECUTE msdb.dbo.sp_start_job @job_name=@JobName
	
###############################################################################################
CREATE PROC prcRepRunPublisherJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX)
AS

DECLARE @publisher_db SYSNAME, @publication SYSNAME, @jobId UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName


SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSsnapshot_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication

EXEC prc_SJ_ExecuteJob @jobId
###############################################################################################
CREATE PROC prcCheckJob
		@ArtcleName NVARCHAR(MAX),
		@PublisherDb NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX)
AS
DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @jobId UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName
	SET @subscriber_db = @subscriberDb

IF @subscriber_db <> ''
BEGIN
SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSmerge_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication
			AND		subscriber_db = @subscriber_db
END
ELSE
BEGIN
SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSsnapshot_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication
END

IF @jobId is not null
	EXEC msdb.dbo.sp_help_job @execution_status = 1, @job_aspect ='JOB', @Job_id = @jobId
###############################################################################################
CREATE PROC prcRepStopPublisherJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX)
AS

DECLARE @publisher_db SYSNAME, @publication SYSNAME, @jobId UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName


SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSsnapshot_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication

EXEC msdb..sp_stop_job @job_id = @jobId
###############################################################################################
CREATE PROC prcRepStopSubscriberJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX)
AS
DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @jobId UNIQUEIDENTIFIER
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName
	SET @subscriber_db = @subscriberDb

SELECT CONVERT(UNIQUEIDENTIFIER, job_id ) AS Id
	INTO #JobsId
	FROM Ameendistribution.dbo.MSmerge_agents 
		WHERE  publisher_db  = @publisher_db
			AND    (@Publication = '' OR Publication = @Publication)
			AND	 (@subscriber_db = '' OR  subscriber_db = @subscriber_db)

WHILE EXISTS (SELECT 1 FROM #JobsId)
BEGIN
SELECT TOP 1
	@jobId = Id
		FROM #JobsId

EXEC msdb..sp_stop_job @job_id = @jobId

DELETE #JobsId
		WHERE Id = @jobId
END
###############################################################################################
CREATE PROCEDURE prcReplication_AddPublisherSameNodeAllTable
@publicationDB  AS sysname
as
DECLARE @publicationSameNode AS SYSNAME='SameNodeAllTable'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
EXEC master..sp_replicationdboption 
  @dbname=@publicationDB, 
  @optname=N'merge publish',
  @value = N'true'

Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationSameNode+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''false'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
			  @retention =0')
  -- Adding the merge articles


   EXEC prc_Replication_AddMergeActicle 
				@publicationSameNode, 
				N'ac000', 
				null

 EXEC prc_Replication_AddMergeActicle 
				@publicationSameNode, 
				N'et000',
				null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode, 
			N'gr000', 
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode, 
			N'mt000',
			null
 
 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,      
			N'op000',
			N'[Type] = 0'

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,  
			N'st000',
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode, 
			N'us000',
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode, 
			N'ui000',
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'cu000',
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,			
			N'ci000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'AddressCountry000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'AddressCity000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'AddressArea000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'CustAddress000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'CustAddressWorkingDays000',
			N''

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,			
			N'co000',
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode, 
			N'RepServer000',
			N''


 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,	
			N'br000',
			null


 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,	
			N'My000',
			null
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PosConfig000' ,null 

    EXEC prc_Replication_AddMergeActicle 
				@publicationSameNode,
				N'BillColected000', 
				null

  EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'di000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'pt000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SalesTax000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'snc000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'snt000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'ti000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'ts000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'tt000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'ContractBillItems000', 
	null
	
  
  EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SOBillTypes000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SOConditionalDiscounts000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SOItems000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SOOfferedItems000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SOPeriodBudgetItem000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'SpecialOffers000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'bt000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'bu000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'bi000', 
	null

   EXEC prc_Replication_AddMergeActicle 
				@publicationSameNode,
				N'ce000', 
				null			

  EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'en000', 
	null
	
 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'er000', 
	null

 EXEC prc_Replication_AddMergeActicle 
	@publicationSameNode,
	N'py000', 
	null

  
  EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'Bank000', 
			null			

  EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ch000', 
			null
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ChequeHistory000', 
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ChequesPortfolio000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ColCh000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'nt000', 
			null


   EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'oit000', 
			null			

  EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OITVS000', 
			null
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ORADDINFO000', 
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderAlternativeUsers000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderAlternativeUserTypes000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderApprovals000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderApprovalStates000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderPayments000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrdersStatesDelays000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderTimeSchedule000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OrderTimeScheduleItems000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ori000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'TrnOrdBu000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OMSG000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'MaturityBills000', 
			null
			

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ORREL000', 
			null
			

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'USRAPP000', 
			null
			
			
EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ppi000', 
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ppo000', 
			null
			


    EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'bg000', 
			null			

  EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'Department000', 
			null
	
 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DepartmentGroups000', 
			null

 EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountRange000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountTypes000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountTypesCard000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountTypesItems000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'Salesman000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountCard000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'DiscountCardStatus000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'OfferedItems000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'SpecialOffer000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'SpecialOfferDetails000', 
			null

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'bgi000', 
			null


EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'POSOfferDiscount000', 
			null
			

EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'SCCustomers000', 
			null


  EXEC prc_Replication_AddMergeActicle 
			@publicationSameNode,
			N'ab000', 
			null			

 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'abd000' , null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ad000' , null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Ages000' , null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AllocationEntries000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Allocations000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Allotment000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AlternativeMats000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AlternativeMatsItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AltMat000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'as000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssemBill000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssemBillType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetEmployee000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assetExclude000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assetExcludeDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetPossessionsForm000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetPossessionsFormItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetStartDatePossessions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetUtilizeContract000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportEntries000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ax000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BalSheet000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bap000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bdp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillCopied000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillOperationState000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillRel000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillRelations000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLItemsHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLMain000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bm000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bmd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BPOptions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BPOptionsDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'brt' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BTCF000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'btStateOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFFlds000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFGroup000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFMapping000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFMultiVal000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFSelFlds000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CheckAcc000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'checkDBProc' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Cond000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CondItems000' ,null 
 
 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Containers000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ContraTypeItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ContraTypes000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CorrectiveAccount000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CostBugetOrderCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CostItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'cp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CustomReport000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbc' ,null  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DBLog' ,null
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DesktopSchedule000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DesktopSchedulePanels000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DeviationReasons000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'df000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DirectLaborAllocation000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DirectLaborAllocationDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DirectMatRequestion000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DirectMatReturn000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DisGeneralTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistActiveLines000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DISTCalendar000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCC000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCe000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCg000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DisTChTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCommIncentive000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCommissionPrice000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCommPoint000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCommPointPeriods000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCompanies000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCoverageUpdate000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCtd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCuSt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustClasses000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustClassesTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustMatTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustStates000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistCustUpdates000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistDd000' ,null 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistDisc000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistDiscDistributor000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistDistributionLines000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistDistributorTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistExpenses000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistHi000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistHt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistLocationLog000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistLookup000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistMatCustTarget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistMatShowingMethods000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistMatTemplates000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistOrders000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistOrdersDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPaid000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPromotions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPromotionsBudget000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPromotionsCustType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPromotionsDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistPrPoint000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistQuestAnswers000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistQuestChoices000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistQuestionnaire000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistQuestQuestion000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistReqMatsDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistRequiredMaterials000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Distributor000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistSalesman000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistTargetByGroupOrDistributor000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistTargetByGroupOrDistributorDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistTargetByGroupOrDistributorQty000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistTCh000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistTr000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistVan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistVd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DistVi000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblComboValue' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocument' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentFieldValue' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentType' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentTypeField' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblField' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblFile' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblFileFormat' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblQuery' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblRelatedType' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DOCACH000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dp000' ,null 

 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DrugCompositions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DrugEquivalents000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DrugIndications000' ,null 
 

 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ds000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ei000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'es000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVC000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVM000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVMI000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVS000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVSI000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ex' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ExchangeProcessConditions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'expQtyRepDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'expQtyRepHdr000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'fa000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'FavAcc000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'FileOP000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'FM000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'fn000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'gbt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'GenMatOp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'gri000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hbt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnaCat000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnaDet000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysis000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnalysisLookUpValues000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisOrderDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnalysisResults000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosClinicalTests000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosCons000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosConsumed000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosConsumedMaster000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosEmployee000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosFDailyFollowing000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosFileFlds000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosFSurgery000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosGeneralOperation000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosGeneralTest000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosGroupSite000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosGuestCompanion000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosHabits000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosInsuranceCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosInsuranceCategoryCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosMiniCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosObservation000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosOperation000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatient000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatientAccounts000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatientHabits000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPerson000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPFile000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphy000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioGraphyMats000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyOrderDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioGraphyTemplate000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioOrderWorker000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosReservation000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosReservationDetails000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosReservationStatus000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSite000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteOut000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSitePrices000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSiteStatus000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosStay000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryMat000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryTimeCost000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryWorker000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosToDoAnalysis000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosTreatmentPlan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosTreatmentPlanDetails000' ,null 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'InvReconcileHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'InvReconcileItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'isrt' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'isx000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JobOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOM000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMInstance000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMProductionLines000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMRawMaterials000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMStages000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMStagesQuantities000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCGeneralCostItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCJobOrderStages000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCMaxCounterSerialNumber000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCProductionLineStages000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCProductionUnit000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCSerialNumberDesign000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCSerialNumberDesignField000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCStages000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JocTrans000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCWorkers000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCWorkHoursDistribution000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'lg000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ma000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlanDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlanItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProfitCenter000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaintenanceLog000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaintenanceLogItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'man_ActualStdAcc000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ManMachines000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ManOperationNumInPlan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Manufactory000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ManWorker000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialAlternatives000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialAlternativesCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialPriceHistory000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MatExBarcode000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MatTargets000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MB000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'mc000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'md000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MGRAPP000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'mh000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MI000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MISN000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MN000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MNPS000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlanDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlanItem000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ms000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MsgDetail000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MsgHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MTDW000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MultiFiles000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MX000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesJob000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesScheduling000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingGrid000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingSrcType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingUser000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillSrcType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillWelcomeEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSChecksCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSChecksSrcType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustBirthDayCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustomerGroup000' ,null 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustomerGroupCustomer000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntryCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntryEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntrySrcType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEvent000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSLog000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMailMessage000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMatMonitoringCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMatMonitoringEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMessage000' ,null 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMessageFields000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSNotification000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSObjectNotification000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSOrderCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSOrderSrcType000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSScheduleEventCondition000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSSmsMessage000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'oap000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'olg000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'OrdersDelaysPanelCustomization000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ORDOC000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ORDOCVS000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_Ac000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_CE000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_Device000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_EN000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Packages000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingListBis000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingLists000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingListsBills000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PcOP000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCCentersList000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCClosedDays000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCConnection000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCPostedDays000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCRelatedGroups000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCShipmentBill000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pl000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Plcosts000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSCheckItem000' ,null 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSInfos000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderAdded000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderAddedTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscount000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountCardTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderItemsTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentLink000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackage000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackageCheck000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackageCurrency000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPayRecieveTable000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSResetDrawer000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSResetDrawerItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSUserBills000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ppr000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'prh000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionLine000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionLineGroup000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlan000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlanApproval000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlanGroups000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProfitCenterOptionsRepSrcs000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'prs000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PSI000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rch000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N're000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReceivedUserMessage000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReconcileInOutBill000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RecostMaterials000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportDataSources000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportHeader000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportLayout000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportState000' ,null 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestAddress000' ,null 
 
 
-- EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestCommand000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestConfig000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestCustAddress000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDeletedOrderItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDeletedOrders000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDepartment000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDiscTax000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDiscTaxTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDriverAddress000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestEntry000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestKGR000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestKitchen000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrder000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderDiscountCard000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderDiscountCardTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderItemTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrdersFiltering000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTable000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTableTemp000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTemp000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestPeriod000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestResetDrawer000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestResetDrawerItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestTable000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestTaxes000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestVendor000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rg000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RichDocument000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RichDocumentCalculatedField000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rvState000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ScheduledJobOptions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ScheduledMaintenanceHistory000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SCPointes000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SCPurchases000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sd000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SentUserMessage000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sh000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sm000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'smBt000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SOContractPeriodEntries000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sti000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SubProfitCenter000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SubProfitCenterBill_EN_Type000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TempBillItems000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TempBills000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TransferConditions000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrDocType000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAccountsEvl000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAccountsEvlDetail000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAgentVoucherPay000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAutoNumber000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBank000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBankAccountNumber000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBankTrans000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBlackList000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBranch000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBranchsConfig000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCenter000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCloseCashier000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCloseCashierDetail000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCompany000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCompanyDestination000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyAcc000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyAccount000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyBalance000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyCatigories000' ,null                                        
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyCatigoriesDetails000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyClass000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyConstValue000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyFifo000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencySellsAcc000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyValRange000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCustomer000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDeposit000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDepositDetail000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDestination000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchange000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeCurrClass000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeDetail000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeTypes000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnGenerator000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnGroupCurrencyAccount000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnMh000' ,null 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnMhCurrencySort000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnNotify000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnOffice000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnOrdPayment000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnParticipator000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnRatio000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnReceiptPayAccounts000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnRoundSetting000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnSenderReceiver000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatement000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatementItems000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatementTypes000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferBankOrder000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferCompanyCard000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferVoucher000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserBalanceByCatigory000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserBalanceByCatigoryDetails000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TRNUSERCASH000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TRNUSERCASHCOST000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserConfig000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherPayeds000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherPayInfo000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherProc000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnWages000' ,null 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnWagesItem000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TypesGroup000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TypesGroupRepSrcs000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'uix' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMaxDiscounts000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMessagesLog000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMessagesProfile000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserOP000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'usx' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Workers000' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbcd' ,null 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbcdd' ,null 
###############################################################################################
CREATE PROCEDURE FillRepFreezecolval
as
INSERT INTO RepFreezecolval000 VALUES (newID(),'ac000', 'Debit', 'C');
INSERT INTO RepFreezecolval000 VALUES (newID(),'ac000', 'Credit', 'C');
INSERT INTO RepFreezecolval000 VALUES (newID(),'ac000', 'UseFlag', 'C');
INSERT INTO RepFreezecolval000 VALUES (newID(),'mt000', 'Qty', 'F');
INSERT INTO RepFreezecolval000 VALUES (newID(),'mt000', 'PrevQty', 'F');
INSERT INTO RepFreezecolval000 VALUES (newID(),'mt000', 'LastPriceDate', 'F');
INSERT INTO RepFreezecolval000 VALUES (newID(),'mt000', 'DisableLastPrice', 'F');
INSERT INTO RepFreezecolval000 VALUES (newID(),'co000', 'Debit', 'C');
INSERT INTO RepFreezecolval000 VALUES (newID(),'co000', 'Credit', 'C');
INSERT INTO RepFreezecolval000 VALUES (newID(),'Us000', 'Dirty', 'C');
###############################################################################################################
CREATE PROCEDURE SolveRepFreezecolval
	@publisher NVARCHAR(MAX),
	@publisher_db NVARCHAR(MAX),
	@PubName NVARCHAR(MAX),
	@SubsecriberServer NVARCHAR(MAX),
	@ServerDataLink NVARCHAR(MAX),
	@SubscriperDb NVARCHAR(MAX)
AS

DECLARE @ArtName NVARCHAR(250)

SELECT sma.name
		INTO #ArtName
	FROM   sysmergearticles sma INNER JOIN sysmergepublications smp
	ON     sma.pubid = smp.pubid
	WHERE smp.publisher    = @publisher
		AND   smp.publisher_db = @publisher_db
		AND   smp.name		   = @PubName
		AND EXISTS (SELECT 1 FROM RepFreezecolval000 WHERE tablename = sma.name)

DECLARE @conflict_table varchar(100), @V_rowguid varchar(36), @V_create_time varchar(100), @V_origin_datasource_id varchar(36), @sqlCommand varchar(MAX)
DECLARE @V_ColumnCount Int, @V_ColumnWhile Int, @columnName varchar(75), @columnType varchar(75)

DECLARE @V_name varchar(100), @V_loser varchar(255), @V_UpdateCommand varchar(MAX)
DECLARE @deleteconflictrow char(1)

CREATE TABLE #merge_conflicts 
	(conflict_table varchar(100), rowguid varchar(36), MSrepl_create_time varchar(100), origin_datasource_id varchar(255)) 

CREATE TABLE #resultcompare 
	(create_time varchar(100), rowguid varchar(36), name varchar(100), loser varchar(255), winner varchar(255)) 

WHILE EXISTS (SELECT 1 FROM #ArtName)
BEGIN
	-- Ã·» √Ê· ”Ã·
	SELECT TOP 1 
			@ArtName = name
	FROM #ArtName

	-- ‰Õœœ «·”Ã·«  «· Ì ›ÌÂ«  ÷«—» ‰ ÌÃ… «·„“«„‰… Ê‰Ê⁄ «· ÷«—»  ⁄œÌ·
	INSERT INTO #merge_conflicts
	SELECT s.conflict_table, c.rowguid, c.MSrepl_create_time, c.origin_datasource_id  
	FROM dbo.MSmerge_conflicts_info c
	JOIN sysmergearticles s
	ON c.tablenick = s.nickname
	WHERE s.name = @ArtName -- conflict_table
	AND c.origin_datasource = @SubsecriberServer+'.'+@SubscriperDb
	AND c.conflict_type = 1 --Update Conflict: The conflict is detected at the row level.
	AND s.pubid = (SELECT pubid
				   FROM   sysmergepublications
				   WHERE  publisher = @publisher
				   AND    publisher_db = @publisher_db
				   AND    name = @PubName)


	WHILE EXISTS (SELECT 1 FROM #merge_conflicts)
	BEGIN
		-- Ã·» ”Ã· «· ÷«—»
		SELECT TOP 1 
				@conflict_table = conflict_table, 
				@V_origin_datasource_id = origin_datasource_id, 
				@V_rowguid = CAST(rowguid AS VARCHAR(36)), 
				@V_create_time = convert(varchar(100), MSrepl_create_time, 21)
		FROM #merge_conflicts

		--  ÕœÌœ ⁄œœ Õﬁ· «·ÃœÊ·
		SELECT @V_ColumnWhile = 1, @V_ColumnCount = COUNT(*) 
		FROM   sys.columns
		WHERE  object_id = object_id(@ArtName)

		-- ·„ﬁ«—‰… ﬁÌ„ «·ÕﬁÊ· „«»Ì‰ ”Ã· «· ÷«—» Ê«·”Ã· «·‰Â«∆Ì «·„Œ“‰
		-- ›Ì Õ«· ﬂ«‰ Â‰«ﬂ «Œ ·«› »«·ﬁÌ„… Ì „ «œŒ«· »«·ÃœÊ· 
		WHILE @V_ColumnWhile <= @V_ColumnCount
		BEGIN
			SELECT @columnName = C.name
			FROM   sys.columns as C
			WHERE  C.object_id = object_id(@ArtName)	
			AND    c.column_id = @V_ColumnWhile

			SET @sqlCommand = 'INSERT INTO #resultcompare ' + 
							  'SELECT ''' + @V_create_time + ''', ''' + @V_rowguid + ''', '+'''' + @columnName + ''' as name, ' + 
							  'ctab.' + @columnName + ', ' + 'tab.' + @columnName + ' ' + 
							  'FROM [dbo].[' + @conflict_table + '] ctab ' +
							  'INNER JOIN ' + @ArtName + ' tab ON tab.guid = ctab.guid ' +
							  'WHERE tab.guid = ''' + @V_rowguid + ''' ' +
							  'AND ctab.origin_datasource_id = ''' + @V_origin_datasource_id + ''' ' + 
							  'AND ctab.' + @columnName + ' != tab.' + @columnName 

			EXEC (@sqlCommand)
			SET @V_ColumnWhile = @V_ColumnWhile + 1
		END

		SET @deleteconflictrow = 'T'

		DECLARE Cur CURSOR FOR
		SELECT rc.name, rc.loser 
		FROM #resultcompare rc 
		OPEN Cur 
		FETCH NEXT FROM Cur INTO @V_name, @V_loser
		WHILE ( @@FETCH_STATUS = 0 )
			BEGIN
				IF EXISTS (SELECT 1 FROM RepFreezecolval000 WHERE tablename = @ArtName AND columnname = @V_name ) 
				BEGIN
					SET @V_UpdateCommand = 'UPDATE ['+@ServerDataLink+'].['+@SubscriperDb+'].[dbo].['+ @ArtName + '] ' + 
											   'SET ' + @V_name + ' = ' + @V_loser + ' ' + 
											   'WHERE guid = ''' + @V_rowguid + ''' '
					EXEC (@V_UpdateCommand)
				END
				ELSE
					SET @deleteconflictrow = 'F'

				FETCH NEXT FROM Cur INTO @V_name, @V_loser
			END
		CLOSE Cur 
		DEALLOCATE Cur 

		--Purge conflict as "resolved"
		IF @deleteconflictrow = 'T' 
		BEGIN
			DECLARE @origin_datasourceSub NVARCHAR(250)=@SubsecriberServer+'.'+@SubscriperDb
				EXEC sp_deletemergeconflictrow
					@conflict_table = @conflict_table,        -- conflict table name from sysmergearticles
					@rowguid = @V_rowguid,                    -- row identifier from msmerge_conflicts_info
					@origin_datasource = @origin_datasourceSub -- origin of the conflict from msmerge_conflicts_info
		END
		DELETE #merge_conflicts
		WHERE CAST(rowguid AS VARCHAR(36)) = @V_rowguid

		DELETE #resultcompare
	END
			
	DELETE #ArtName 
	WHERE  name = @ArtName
END
DROP TABLE #ArtName 
DROP TABLE #resultcompare
DROP TABLE #merge_conflicts
################################################################################################################
CREATE PROCEDURE prc_SJ_AddJobConflicts 
	@JobName NVARCHAR(MAX),
	@JobStepName NVARCHAR(MAX),
	@connection NVARCHAR(MAX),
	@DBName NVARCHAR(MAX), 
	@SqlCommand NVARCHAR(MAX),
	@SubDBName NVARCHAR(MAX)
AS
	SET NOCOUNT ON
	
	IF EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [name] = @JobName) 
	BEGIN
		RAISERROR (N'SJ_E1201: There is already a job with this name.', 16, 1) 
		RETURN
	END

	IF NOT EXISTS(SELECT * FROM [msdb].[dbo].[syscategories] WHERE [name] = N'[Ameen RepSJ]')
		EXECUTE [msdb].[dbo].[sp_add_category] @name = N'[Ameen RepSJ]'

	DECLARE @JobID UNIQUEIDENTIFIER 
	SET @JobID = NULL 
	EXECUTE [msdb].[dbo].[sp_add_job] @job_id = @JobID OUTPUT , @job_name = @JobName , @owner_login_name = NULL, @description = N'Job added from Al-Ameen Program.', @category_name = N'[Ameen RepSJ]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0 
	
	DECLARE 
		@RetryNum INT,
		@RetryInter INT; 

	SET @RetryNum = 3;
	SET @RetryInter = 1;

	DECLARE 
		@jobstep_uid UNIQUEIDENTIFIER,
		@jobstep_id INT,
		@ConnectionCommand NVARCHAR(200) = N'update [' + @connection + '].' + @SubDBName + '.dbo.us000 SET DIRTY = 1';

	EXECUTE [msdb].[dbo].[sp_add_jobstep] 
		@job_id = @JobID, 
		@step_name = @JobStepName, 
		@database_name = @DBName, 
		-- @additional_parameters = @param,
		@on_success_action=3,
		@on_fail_action=3,
		@server = N'', 
		@database_user_name = N'', 
		@subsystem = N'TSQL', 
		@cmdexec_success_code = 0, 
		@flags = 0, 
		@retry_attempts = @RetryNum, 
		@retry_interval = @RetryInter, 
		@output_file_name = N'', 
		@on_success_step_id = 0, 
		@on_fail_step_id = 1, 
		@command=@SqlCommand,
		@step_uid = @jobstep_uid OUTPUT


		
	EXECUTE [msdb].[dbo].[sp_add_jobstep] 
		@job_id = @JobID, 
		@step_name = 'SETDirtyUS000', 
		@database_name = @DBName, 
		-- @additional_parameters = @param,
		@server = N'', 
		@database_user_name = N'', 
		@subsystem = N'TSQL', 
		@cmdexec_success_code = 0, 
		@on_success_action=1,
		@on_fail_action=2,
		@flags = 0, 
		@retry_attempts = @RetryNum, 
		@retry_interval = @RetryInter, 
		@output_file_name = N'', 
		@on_success_step_id = 0, 
		@on_fail_step_id = 0, 
		@command = @ConnectionCommand,
		@step_uid = @jobstep_uid OUTPUT


	EXECUTE [msdb].[dbo].[sp_add_jobschedule] 
			@job_id = @JobID, 
			@name = N'Schedule 1', 
			@enabled = 1 

   EXEC [msdb].[dbo].sp_add_jobserver
			@job_name=@JobName,
			@server_name="(local)"

	SELECT @JobID as jobID
################################################################################################################
CREATE PROC prcRepAlterSubscriberJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX),
		@JobConflictId UNIQUEIDENTIFIER
AS
DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @jobId UNIQUEIDENTIFIER, @JobCommand NVARCHAR(250)
	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName
	SET @subscriber_db = @subscriberDb
	SET @JobCommand = 'EXECUTE msdb.dbo.sp_start_job @job_id = ''' + CAST(@JobConflictId AS NVARCHAR(50)) + ''''

SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM   Ameendistribution.dbo.MSmerge_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication
			AND	   subscriber_db = @subscriber_db

EXECUTE [msdb].[dbo].[sp_add_jobstep] 
		@job_id = @jobId, 
		@step_name = 'ConflictJobStep', 
		@database_name = @PublisherDb, 
		@server = N'', 
		@database_user_name = N'', 
		@subsystem = N'TSQL', 
		@cmdexec_success_code = 0, 
		@flags = 0, 
		@retry_attempts = 3, 
		@retry_interval = 1, 
		@output_file_name = N'', 
		@on_success_step_id = 0, 
		@on_fail_step_id = 0, 
		@command = @JobCommand
################################################################################################################
CREATE PROCEDURE GetReplicationConflict
	@publisher NVARCHAR(MAX),
	@publisher_db NVARCHAR(MAX),
	@PubName NVARCHAR(MAX),
	@SubsecriberServer NVARCHAR(MAX),
	@SubscriperDb    NVARCHAR(MAX)
AS	
	SET NOCOUNT ON
	-- Ã·» Ã„Ì⁄ «·”Ã·«  «·„”Ã·…  ÷«—» Ê  »⁄ ··Õ“„… «·„Õœœ…
	SELECT s.name, c.rowguid, c.MSrepl_create_time, c.conflict_type --,c.*
	INTO #merge_conflicts
	FROM dbo.MSmerge_conflicts_info c
	JOIN sysmergearticles s
	ON c.tablenick = s.nickname
	WHERE c.origin_datasource =@SubsecriberServer+'.'+@SubscriperDb
	--AND c.conflict_type = @conflict_type 
	AND s.pubid = (SELECT pubid
				   FROM   sysmergepublications
				   WHERE  publisher = @publisher
				   AND    publisher_db = @publisher_db
				   AND    name = @PubName)


	DECLARE @conflictsCursor as CURSOR;
	DECLARE @ArtName sysname, @rowguid VARCHAR(36), @my_sql nvarchar(max), @descr nvarchar(75), @ConflictTime DATETIME,@ConflictType INT
	CREATE TABLE #conflicts_info (RowGuid UNIQUEIDENTIFIER, ConflictTime DATETIME, ConflictType int,rownumber int, type nvarchar(250), descr nvarchar(250))

	
	SET @conflictsCursor = CURSOR FOR SELECT*  FROM #merge_conflicts

	OPEN @conflictsCursor;
	FETCH NEXT FROM @conflictsCursor INTO @ArtName, @rowguid,@ConflictTime,@ConflictType

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT TOP 1 
				@ArtName = name, @rowguid = CAST(rowguid AS VARCHAR(36)), @ConflictTime = MSrepl_create_time,@ConflictType=conflict_type
		FROM #merge_conflicts
	
		SELECT @my_sql = 'INSERT INTO #conflicts_info SELECT ''' + CAST(@rowguid AS NVARCHAR(100)) + ''', ''' + 
						  CAST(@ConflictTime AS NVARCHAR(50)) + ''', ''' +CAST(@ConflictType as NVARCHAR(50)) +''' ,' + part1 + ', ''' + tabledesc + ''' ' + part2 + ' ' + part3 + ''''+@rowguid+'''', 
						  @descr = tabledesc
		FROM RepConflictsInfo000
		WHERE tablename = @ArtName
	
		EXEC (@my_sql)

		DELETE #merge_conflicts 
		WHERE  rowguid = @rowguid  AND Exists(select * from #conflicts_info where  rowguid = @rowguid )

	 FETCH NEXT FROM @conflictsCursor INTO @ArtName, @rowguid,@ConflictTime,@ConflictType
	END
	CLOSE @conflictsCursor;
	DEALLOCATE @conflictsCursor;


	INSERT INTO #conflicts_info
	SELECT rowguid, MSrepl_create_time,conflict_type,0,name,N'' FROM   #merge_conflicts 

	SELECT * FROM #conflicts_info

	DROP TABLE #merge_conflicts
	DROP TABLE #conflicts_info
################################################################################################################
CREATE PROCEDURE prcDeleteSubscriberInfo
@hostName NVARCHAR(MAX),
@article NVARCHAR(MAX)
AS 
 DELETE FROM Repbt000 where HostName=@hostName and @article='Bill'
 DELETE FROM Repnt000 where HostName=@hostName and @article='Cheque'
 DELETE FROM Repet000 where HostName=@hostName and @article='Entries'
 DELETE FROM Repgr000 where HostName=@hostName and @article='GRCoreTable'
 DELETE FROM Repac000 where HostName=@hostName and @article='ACCoreTable'
#################################################################################################################
CREATE PROCEDURE DeleteUniqueIndex
AS
	DECLARE @ind NVARCHAR(250),
			@Tb NVARCHAR(250),
			@sql NVARCHAR(MAX)
WHILE EXISTS (SELECT 1 FROM sys.indexes sysindexes INNER JOIN 
				sysobjects ON sysindexes.object_id = sysobjects.id 
					WHERE (sysobjects.name='ce000' or sysobjects.name='bu000')
									AND	(index_id > 1)               
									AND (sysobjects.[type] <> 'S')                           
									AND (sysobjects.[xtype] <> 'IT') 
									AND (sysindexes.is_unique = 1)
									AND (sysindexes.is_primary_key <> 1))
BEGIN 
	SELECT  TOP 1 @ind=sysindexes.name,@Tb=sysobjects.name
		FROM sys.indexes sysindexes INNER JOIN 
						sysobjects ON sysindexes.object_id = sysobjects.id 
							WHERE (sysobjects.name='ce000' or sysobjects.name='bu000')
											AND	(index_id > 1)              
											AND (sysobjects.[type] <> 'S')                           
											AND (sysobjects.[xtype] <> 'IT') 
											AND (sysindexes.is_unique = 1)
											AND (sysindexes.is_primary_key <> 1)

	SET @sql = 'DROP INDEX ' + @Tb + '.' + @ind 
        EXEC (@sql) 
END
#########################################################################################
CREATE PROCEDURE UpdateReplicationSchedule
	@PublisherDb NVARCHAR(MAX),
	@ArtcleName NVARCHAR(MAX),
	@subscriberDb NVARCHAR(MAX),
	@S_freq_type                INT,
	@S_freq_interval            INT,
	@S_freq_subday_type         INT,
	@S_freq_subday_interval     INT,
	@S_freq_relative_interval   INT,
	@S_freq_recurrence_factor   INT,
	@S_active_start_date        INT, 
	@S_active_end_date          INT,
	@S_active_start_time        INT,
	@S_active_end_time          INT
AS
DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @schedule_id INT

	SET @publisher_db  = @PublisherDb
	SET @Publication   = @ArtcleName
	SET @subscriber_db = @subscriberDb

SELECT @schedule_id = s.schedule_id FROM msdb.dbo.sysjobschedules s
	INNER JOIN msdb.dbo.sysschedules ss ON ss.schedule_id = s.schedule_id
	INNER JOIN (SELECT scj.job_id,MIN(sc.date_created) as max_date
	FROM msdb.dbo.sysschedules sc
		INNER JOIN msdb.dbo.sysjobschedules scj ON sc.schedule_id = scj.schedule_id
		GROUP BY scj.job_id)j
	ON s.job_id = j.job_id AND 
		j.max_date = ss.date_created
	WHERE s.job_id = (SELECT CONVERT(UNIQUEIDENTIFIER, job_id )
		FROM   Ameendistribution.dbo.MSmerge_agents 
		WHERE  publisher_db  = @publisher_db
			AND    Publication   = @Publication
			AND	   subscriber_db = @subscriber_db)

EXEC msdb.dbo.sp_update_schedule 
	@schedule_id=@schedule_id, 
	@freq_type              = @S_freq_type                ,
	@freq_interval          = @S_freq_interval            ,
	@freq_subday_type       = @S_freq_subday_type         ,
	@freq_subday_interval   = @S_freq_subday_interval     ,
	@freq_relative_interval = @S_freq_relative_interval   ,
	@freq_recurrence_factor = @S_freq_recurrence_factor   ,
	@active_start_date      = @S_active_start_date        , 
	@active_end_date        = @S_active_end_date          ,
	@active_start_time      = @S_active_start_time        ,
	@active_end_time        = @S_active_end_time          
################################################################################################################
CREATE PROC prcRepAlterPublisherArticalsJob
		@PublisherDb NVARCHAR(MAX),
		@ArtcleName NVARCHAR(MAX),
		@HelperTable NVARCHAR(MAX)
AS
DECLARE @publisher_db SYSNAME, @publication SYSNAME, @jobId UNIQUEIDENTIFIER, @SqlCommand NVARCHAR(200)
	SET @publisher_db = @PublisherDb
	SET @Publication = @ArtcleName
	SET @SqlCommand = REPLACE(N'Update x SET Name = Name',N'x',@HelperTable)

SELECT @jobId = CONVERT(UNIQUEIDENTIFIER, job_id )
	FROM Ameendistribution.dbo.MSsnapshot_agents 
		WHERE publisher_db = @publisher_db
			AND Publication = @Publication

EXECUTE [msdb].[dbo].[sp_add_jobstep]
		@job_id = @jobId,
		@step_name = 'UpdateHelperTable',
		@database_name = @PublisherDb,
		@server = N'',
		@database_user_name = N'',
		@subsystem = N'TSQL',
		@cmdexec_success_code = 0,
		@flags = 0,
		@retry_attempts = 3,
		@retry_interval = 1,
		@output_file_name = N'',
		@on_success_step_id = 0,
		@on_fail_step_id = 0,
		@command = @SqlCommand
######################################################################################
CREATE PROCEDURE GetReplicationJobsHistory
	@PublisherDb NVARCHAR(MAX) 
AS

;WITH Cte AS(
    SELECT 
    [sJOB].[job_id] AS [JobID]
    , [sJOB].[name] AS [JobName]
    , CASE 
        WHEN [sJOBH].[run_date] IS NULL OR [sJOBH].[run_time] IS NULL THEN NULL
        ELSE CAST(
                CAST([sJOBH].[run_date] AS CHAR(8))
                + ' ' 
                + STUFF(
                    STUFF(RIGHT('000000' + CAST([sJOBH].[run_time] AS VARCHAR(6)),  6)
                        , 3, 0, ':')
                    , 6, 0, ':')
                AS DATETIME)
      END AS [LastRunDateTime]
    , CASE [sJOBH].[run_status]
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'InProgress'
		WHEN 10 THEN 'Running'
      END AS [LastRunStatus]
    , STUFF(
            STUFF(RIGHT('000000' + CAST([sJOBH].[run_duration] AS VARCHAR(6)),  6)
                , 3, 0, ':')
            , 6, 0, ':') 
        AS [LastRunDuration (HH:MM:SS)]
    , [sJOBH].[message] AS [LastRunStatusMessage]
    , CASE [sJOBSCH].[NextRunDate]
        WHEN 0 THEN NULL
        ELSE CAST(
                CAST([sJOBSCH].[NextRunDate] AS CHAR(8))
                + ' ' 
                + STUFF(
                    STUFF(RIGHT('000000' + CAST([sJOBSCH].[NextRunTime] AS VARCHAR(6)),  6)
                        , 3, 0, ':')
                    , 6, 0, ':')
                AS DATETIME)
      END AS [NextRunDateTime]
FROM 
    [msdb].[dbo].[sysjobs] AS [sJOB]
    LEFT JOIN (
                SELECT
                    [job_id]
                    , MIN([next_run_date]) AS [NextRunDate]
                    , MIN([next_run_time]) AS [NextRunTime]
                FROM [msdb].[dbo].[sysjobschedules]
                GROUP BY [job_id]
            ) AS [sJOBSCH]
        ON [sJOB].[job_id] = [sJOBSCH].[job_id]
    LEFT JOIN (
                SELECT 
                    [job_id]
                    , [run_date]
                    , [run_time]
                    , [run_status]
                    , [run_duration]
                    , [message]
                    , ROW_NUMBER() OVER (
                                            PARTITION BY [job_id] 
                                            ORDER BY [run_date] DESC, [run_time] DESC
                      ) AS RowNumber
                FROM [msdb].[dbo].[sysjobhistory]
                WHERE [step_id] = 0
            ) AS [sJOBH]
        ON [sJOB].[job_id] = [sJOBH].[job_id]
        AND [sJOBH].[RowNumber] = 1
)
SELECT c.JobID AS JobID, d.publication AS Publication, d.publisher_db AS DB, @@SERVERNAME AS ServerName, 1 AS Level, c.[LastRunStatus] AS RunStatus , c.LastRunStatusMessage AS RunMessage, c.[LastRunDuration (HH:MM:SS)] AS RunDuration, c.LastRunDateTime AS RunDatetime, c.NextRunDateTime
	FROM Ameendistribution.dbo.MSsnapshot_agents AS d INNER JOIN Cte AS c ON d.job_id = c.JobID
		WHERE publisher_db = @PublisherDb
UNION
SELECT c.JobID AS JobID, d.publication AS Publication, d.subscriber_db AS DB, subscriber_name AS ServerName, 2 AS Level, c.[LastRunStatus] AS RunStatus ,c.LastRunStatusMessage AS RunMessage, c.[LastRunDuration (HH:MM:SS)] AS RunDuration, c.LastRunDateTime AS RunDatetime, c.NextRunDateTime
	FROM   Ameendistribution.dbo.MSmerge_agents AS d INNER JOIN Cte AS c ON d.job_id = c.JobID
		WHERE  publisher_db  = @PublisherDb
			ORDER BY d.publication, Level
#########################################################################################
CREATE PROCEDURE  prcReplication_AddPublisherManufacture
	@publicationDB  AS sysname 
AS

DECLARE @publicationManufacture AS SYSNAME='Manufacture'

 Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationManufacture+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @validate_subscriber_info = N''HOST_NAME()'',
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''true'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
			  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
				@publicationManufacture,
				N'AlternativeMats000', 
				N'1=1'			

  EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'AlternativeMatsItems000', 
	N''
	
 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'FM000', 
	N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME())) 
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'

 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'man_ActualStdAcc000', 
	N''

 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'ManMachines000', 
	N''


 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'Manufactory000', 
	N''


 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'ManWorker000', 
	N''


 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MB000', 
	N''

 EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MI000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MISN000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MN000', 
	N'(([BranchGUID] IN (select guid from br000 where number = case when isnumeric(HOST_NAME()) = 1 then HOST_NAME() else number end)
	OR isnumeric(HOST_NAME()) <> 1 	) AND Type= 1) 
	OR Type = 0'


EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MNPS000', 
	N'[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)
		OR 1=CASE WHEN ISNUMERIC( Host_Name() ) = 1 THEN 0 ELSE 1 END'


EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'MX000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'ManOperationNumInPlan000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'PSI000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationManufacture,
	N'Workers000', 
	N''


EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'AlternativeMatsItems000', 
		@filtername = N'AlternativeMatsItems000_AlternativeMats000', 
		@join_articlename = N'AlternativeMats000', 
		@join_filterclause =  N'[AlternativeMats000].[GUID] = [AlternativeMatsItems000].[AltMatsGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0


--EXEC sp_addmergefilter 
--		@publication =@publicationManufacture, 
--		@article = N'MN000', 
--		@filtername = N'MN000_FM000', 
--		@join_articlename = N'FM000', 
--		@join_filterclause = N'[FM000].[GUID] = [MN000].[FormGUID]', 
--		@join_unique_key = 1, 
--		@filter_type = 1, 
--		@force_invalidate_snapshot = 0, 
--		@force_reinit_subscription = 0


EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'MISN000', 
		@filtername = N'MISN000_MI000', 
		@join_articlename = N'MI000', 
		@join_filterclause = N'[MI000].[GUID] = [MISN000].[miGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'MB000', 
		@filtername = N'MB000_MN000', 
		@join_articlename = N'MN000', 
		@join_filterclause =  N'[MN000].[GUID] = [MB000].[ManGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'MI000', 
		@filtername = N'MI000_MN000', 
		@join_articlename = N'MN000', 
		@join_filterclause = N'[MN000].[GUID] = [MI000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'MX000', 
		@filtername = N'MX000_MN000', 
		@join_articlename = N'MN000', 
		@join_filterclause = N'[MN000].[GUID] = [MX000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'PSI000', 
		@filtername = N'PSI000_MNPS000', 
		@join_articlename = N'MNPS000', 
		@join_filterclause =  N'[MNPS000].[GUID] = [PSI000].[ParentGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationManufacture, 
		@article = N'ManOperationNumInPlan000', 
		@filtername = N'ManOperationNumInPlan000_MNPS000', 
		@join_articlename = N'MNPS000', 
		@join_filterclause =  N'[MNPS000].[GUID] = [ManOperationNumInPlan000].[PlanGuid]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0
###################################################################################################
CREATE PROCEDURE  prcReplication_AddPublisherDistributor
@publicationDB  AS sysname 
as
DECLARE @publicationDistributor AS SYSNAME='Distribution'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description
 Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationDistributor+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @validate_subscriber_info = N''HOST_NAME()'',
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''true'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0,
			  @retention =0')

  EXEC prc_Replication_AddMergeActicle 
				@publicationDistributor,
				N'DisGeneralTarget000', 
				N'[BranchGUID] IN 
						(SELECT GUID FROM br000 WHERE number = 
						CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)  
					OR ISNUMERIC(Host_Name()) = 0'

  EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistActiveLines000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DISTCalendar000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCC000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCg000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DisTChTarget000', 
	N'[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)  
	OR ISNUMERIC(Host_Name()) = 0'

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCommIncentive000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCommissionPrice000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCommPoint000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCommPointPeriods000', 
	''

  EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCompanies000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCoverageUpdate000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCt000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCtd000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCuSt000', 
	''

  EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCustTarget000', 
	''

   EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCustUpdates000', 
	''
  
   EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCm000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCustClassesTarget000', 
	N'[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)  
	OR ISNUMERIC(Host_Name()) = 0'

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistCustMatTarget000', 
	N'[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)  
	OR ISNUMERIC(Host_Name()) = 0'


 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistDd000', 
	''

 

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistDisc000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistDiscDistributor000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistDistributionLines000', 
	''


 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistDistributorTarget000', 
	N'[BranchGUID] IN 
		(SELECT GUID FROM br000 WHERE number = 
		CASE WHEN ISNUMERIC(Host_Name()) = 1 THEN Host_Name() ELSE number END)  
	OR ISNUMERIC(Host_Name()) = 0'


 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistExpenses000', 
	N''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistHi000', 
	N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'


 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistHt000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistLocationLog000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistLookup000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistMatCustTarget000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistMatTemplates000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistOrders000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistOrdersDetails000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPaid000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPromotions000', 
	' 0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				 WHEN isnumeric(HOST_NAME()) = 0 THEN 1
                 END'

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPromotionsBudget000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPromotionsCustType000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPromotionsDetail000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistPrPoint000', 
	''
 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistQuestAnswers000', 
	''
 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistQuestChoices000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistQuestionnaire000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistQuestQuestion000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistReqMatsDetails000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistRequiredMaterials000', 
	''

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'Distributor000', 
	N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'

 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistSalesman000', 
	' 0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				 WHEN isnumeric(HOST_NAME()) = 0 THEN 1
                 END'
 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistTargetByGroupOrDistributor000', 
	''
 EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistTargetByGroupOrDistributorDetails000', 
	''
EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistTargetByGroupOrDistributorQty000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistTCh000', 
	''



EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistTr000', 
	''

EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistVan000', 
	N'0 < CASE WHEN isnumeric(HOST_NAME()) = 1 THEN ([branchMask] & [dbo].[fnGetBranchMask](HOST_NAME()))
				WHEN isnumeric(HOST_NAME()) = 0 THEN 1
				END'

EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistVd000', 
	N''

EXEC prc_Replication_AddMergeActicle 
	@publicationDistributor,
	N'DistVi000', 
	N''

EXEC sp_addmergefilter 
		@publication =@publicationDistributor, 
		@article = N'DistPromotionsDetail000', 
		@filtername = N'DistPromotions000-DistPromotionsDetail000', 
		@join_articlename = N'DistPromotions000', 
		@join_filterclause = N'[DistPromotions000].[GUID] = [DistPromotionsDetail000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationDistributor, 
		@article = N'DistPromotionsCustType000', 
		@filtername = N'DistPromotions000-DistPromotionsCustType000', 
		@join_articlename = N'DistPromotions000', 
		@join_filterclause = N'[DistPromotions000].[GUID] = [DistPromotionsCustType000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationDistributor, 
		@article = N'DistPromotionsBudget000', 
		@filtername = N'DistPromotions000-DistPromotionsBudget000', 
		@join_articlename = N'DistPromotions000', 
		@join_filterclause = N'[DistPromotions000].[GUID] = [DistPromotionsBudget000].[ParentGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationDistributor, 
		@article = N'DistDd000', 
		@filtername = N'Distributor000-DistDd000', 
		@join_articlename = N'Distributor000', 
		@join_filterclause = N'[Distributor000].[GUID] = [DistDd000].[DistributorGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

EXEC sp_addmergefilter 
		@publication =@publicationDistributor, 
		@article = N'DistDistributionLines000', 
		@filtername = N'Distributor000-DistDistributionLines000', 
		@join_articlename = N'Distributor000', 
		@join_filterclause = N'[Distributor000].[GUID] = [DistDistributionLines000].[DistGUID]', 
		@join_unique_key = 1, 
		@filter_type = 1, 
		@force_invalidate_snapshot = 0, 
		@force_reinit_subscription = 0

##############################################################################################
CREATE PROCEDURE prcReplication_AddPublisherSameNode
@publicationDB  AS sysname
as
DECLARE @publicationSameNode AS SYSNAME='SameNode'
-- Create a new merge publication, explicitly setting the defaults.
-- These parameters are optional.
--@publication
-- optional parameters @description

Exec (' USE '+@publicationDB+' 
		EXEC sp_addmergepublication 
		  @publication ='''+@publicationSameNode+''',
		  @description = N''Merge publication of '+@publicationDB+''',
		  @publication_compatibility_level  = N''100RTM'', 
		  @conflict_logging = N''both'',
		  @dynamic_filters = N''false'',
		  @keep_partition_changes = N''true'',
		  @use_partition_groups = N''false'',
		  @allow_partition_realignment = N''true'',
		  @replicate_ddl=0, @allow_subscription_copy = N''false'',
		  @allow_subscriber_initiated_snapshot = N''false'',
			  @retention =0')
  -- Adding the merge articles	
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ad000' , N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Ages000' , N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AllocationEntries000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Allocations000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Allotment000' ,N'' 
  
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AltMat000' ,N'' 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssemBill000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssemBillType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetEmployee000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assetExclude000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assetExcludeDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetPossessionsForm000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetPossessionsFormItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetStartDatePossessions000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'AssetUtilizeContract000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportEntries000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'assTransferReportHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ax000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BalSheet000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bap000' ,N'' 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillCopied000' ,N'' 

 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillOperationState000' ,N'' 
 

 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BillRelations000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLItems000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLItemsHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BLMain000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bm000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'bmd000' ,N'' 
  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BPOptions000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BPOptionsDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'brt' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'BTCF000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'btStateOrder000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFFlds000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFGroup000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFMapping000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFMultiVal000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CFSelFlds000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CheckAcc000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'checkDBProc' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Containers000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ContraTypeItems000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ContraTypes000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CorrectiveAccount000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CostBugetOrderCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'CustomReport000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbc' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DBLog' ,N''
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dd000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DesktopSchedule000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DesktopSchedulePanels000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DeviationReasons000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'df000' ,N'' 

 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblComboValue' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocument' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentFieldValue' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentType' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblDocumentTypeField' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblField' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblFile' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblFileFormat' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblQuery' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DMSTblRelatedType' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'DOCACH000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dp000' ,N'' 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ds000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ei000' ,N'' 
  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'es000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVC000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVM000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVMI000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVS000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'EVSI000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ex' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ExchangeProcessConditions000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'expQtyRepDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'expQtyRepHdr000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'fa000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'FavAcc000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'FileOP000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'fn000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'gbt000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'GenMatOp000' ,N'' 
  
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hbt000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnaCat000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnaDet000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysis000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisItems000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnalysisLookUpValues000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisOrder000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosAnalysisOrderDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosAnalysisResults000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosClinicalTests000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosCons000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosConsumed000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosConsumedMaster000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosEmployee000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosFDailyFollowing000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosFileFlds000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosFSurgery000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosGeneralOperation000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosGeneralTest000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosGroupSite000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosGuestCompanion000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosHabits000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosInsuranceCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosInsuranceCategoryCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosMiniCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosObservation000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosOperation000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatient000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatientAccounts000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPatientHabits000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPerson000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosPFile000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphy000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioGraphyMats000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyOrder000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyOrderDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioGraphyTemplate000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosRadioGraphyType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosRadioOrderWorker000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosReservation000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosReservationDetails000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosReservationStatus000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSite000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteOut000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSitePrices000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSiteStatus000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosSiteType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'hosStay000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryMat000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryTimeCost000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosSurgeryWorker000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosToDoAnalysis000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosTreatmentPlan000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'HosTreatmentPlanDetails000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'InvReconcileHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'InvReconcileItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'isrt' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'isx000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JobOrder000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOM000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMInstance000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMProductionLines000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMRawMaterials000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMStages000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCBOMStagesQuantities000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCGeneralCostItems000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCJobOrderStages000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCMaxCounterSerialNumber000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCProductionLineStages000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCProductionUnit000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCSerialNumberDesign000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCSerialNumberDesignField000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCStages000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JocTrans000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCWorkers000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'JOCWorkHoursDistribution000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'lg000' ,N'' 

 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlan000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlanDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProductionPlanItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MainProfitCenter000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaintenanceLog000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaintenanceLogItem000' ,N'' 
   
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialAlternatives000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialAlternativesCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MaterialPriceHistory000' ,N'' 
 

 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'mc000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MGRAPP000' ,N'' 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlan000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlanDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ModifiedProductionPlanItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MsgDetail000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MsgHeader000' ,N'' 
  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'MultiFiles000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesJob000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesScheduling000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingGrid000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingSrcType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSAccountBalancesSchedulingUser000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillSrcType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSBillWelcomeEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSChecksCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSChecksSrcType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustBirthDayCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustomerGroup000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSCustomerGroupCustomer000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntryCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntryEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEntrySrcType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEvent000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSLog000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMailMessage000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMatMonitoringCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMatMonitoringEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMessage000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSMessageFields000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSNotification000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSObjectNotification000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSOrderCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSOrderSrcType000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSScheduleEventCondition000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'NSSmsMessage000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'oap000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'olg000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'OrdersDelaysPanelCustomization000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ORDOC000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ORDOCVS000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_Ac000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_CE000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_Device000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PA_EN000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Packages000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingListBis000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingLists000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PackingListsBills000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PcOP000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pd000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCCentersList000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCClosedDays000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCConnection000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCPostedDays000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCRelatedGroups000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'PFCShipmentBill000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pl000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'Plcosts000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSCheckItem000' ,N'' 
 
 

 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSInfos000' ,N'' 
 
 

 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderAdded000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderAddedTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscount000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountCardTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderDiscountTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderItemsTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSOrderTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentLink000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackage000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackageCheck000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPaymentsPackageCurrency000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSPayRecieveTable000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSResetDrawer000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSResetDrawerItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'POSUserBills000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'pp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ppr000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'prh000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionLine000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionLineGroup000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlan000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlanApproval000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProductionPlanGroups000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ProfitCenterOptionsRepSrcs000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'prs000' ,N''  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rch000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N're000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReceivedUserMessage000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReconcileInOutBill000' ,N'' 
 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportDataSources000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportHeader000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportLayout000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ReportState000' ,N'' 

 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestAddress000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestCommand000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestConfig000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestCustAddress000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDeletedOrderItems000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDeletedOrders000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDepartment000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDiscTax000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDiscTaxTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestDriverAddress000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestEntry000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestKGR000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestKitchen000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrder000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderDiscountCard000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderDiscountCardTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderItemTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrdersFiltering000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTable000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTableTemp000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestOrderTemp000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestPeriod000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestResetDrawer000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestResetDrawerItem000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestTable000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestTaxes000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RestVendor000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rg000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RichDocument000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'RichDocumentCalculatedField000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rt000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'rvState000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ScheduledJobOptions000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'ScheduledMaintenanceHistory000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SCPointes000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SCPurchases000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sd000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SentUserMessage000' ,N'' 
 
 
-- EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sh000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'sm000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'smBt000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SOContractPeriodEntries000' ,N'' 
  
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SubProfitCenter000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'SubProfitCenterBill_EN_Type000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TempBillItems000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TempBills000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TransferConditions000' ,N'' 
 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrDocType000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAccountsEvl000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAccountsEvlDetail000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAgentVoucherPay000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnAutoNumber000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBank000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBankAccountNumber000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBankTrans000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBlackList000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBranch000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnBranchsConfig000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCenter000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCloseCashier000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCloseCashierDetail000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCompany000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCompanyDestination000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyAcc000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyAccount000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyBalance000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyCatigories000' ,N''                                        
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyCatigoriesDetails000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyClass000' ,N'' 
 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyConstValue000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyFifo000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencySellsAcc000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCurrencyValRange000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnCustomer000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDeposit000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDepositDetail000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnDestination000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchange000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeCurrClass000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeDetail000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnExchangeTypes000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnGenerator000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnGroupCurrencyAccount000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnMh000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnMhCurrencySort000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnNotify000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnOffice000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnOrdPayment000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnParticipator000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnRatio000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnReceiptPayAccounts000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnRoundSetting000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnSenderReceiver000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatement000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatementItems000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnStatementTypes000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferBankOrder000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferCompanyCard000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnTransferVoucher000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserBalanceByCatigory000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserBalanceByCatigoryDetails000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TRNUSERCASH000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TRNUSERCASHCOST000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnUserConfig000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherPayeds000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherPayInfo000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnVoucherProc000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnWages000' ,N'' 
 
 --EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TrnWagesItem000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TypesGroup000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'TypesGroupRepSrcs000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'uix' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMaxDiscounts000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMessagesLog000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserMessagesProfile000' ,N'' 
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'UserOP000' ,N''  
 
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'usx' ,N'' 

 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbcd' ,N'' 
  
 EXEC prc_Replication_AddMergeActicle  @publicationSameNode, N'dbcdd' ,N''  
##############################################################################################
CREATE PROCEDURE prc_SJ_DeleteJobReplication 
	@Job NVARCHAR(MAX) 
AS 
	SET NOCOUNT ON

	IF (EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [name] = @Job))
	EXECUTE [msdb].[dbo].[sp_delete_job] @job_name = @Job
##############################################################################################
CREATE PROCEDURE PrcDropMergeSubscription
	@PublisherDb NVARCHAR(MAX)
AS
	SET NOCOUNT ON
   
	DECLARE @p NVARCHAR(max);
	DECLARE db_cursor CURSOR FOR  
	SELECT publication FROM AmeenDistribution..MSpublications
			WHERE publisher_db=@PublisherDb

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @p   
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
	   EXEC sp_dropmergesubscription  @publication=@p,@subscription_type='all',@subscriber='all'
	FETCH NEXT FROM db_cursor INTO @p   
	END   
	CLOSE db_cursor   
	DEALLOCATE db_cursor
##############################################################################################
CREATE PROCEDURE PrcBackupMergeSubscription
	@PublisherDb NVARCHAR(MAX)
AS
	SET NOCOUNT ON
	DECLARE @publisher_db SYSNAME, 
			@jobId UNIQUEIDENTIFIER

	SET @publisher_db  = @PublisherDb

	SELECT DISTINCT 
		pubs.name publication,
		subs.subscriber_server subscriber_name,
		subs.db_name subscriber_db,
		replinfo.hostname hostname,
		replinfo.merge_jobid Id
	INTO #JobsId
	FROM  dbo.sysmergesubscriptions        subs,
			dbo.MSmerge_replinfo        replinfo,
			dbo.sysmergepublications    pubs
	WHERE   subs.status <> 2 
			and pubs.pubid = subs.pubid
			and subs.pubid <> subs.subid
			and replinfo.repid = subs.subid
			and (suser_sname(suser_sid()) = replinfo.login_name OR is_member('db_owner')=1 OR is_srvrolemember('sysadmin') = 1)                   
			and (pubs.publisher_db = @publisher_db collate database_default)          
			and (subs.subscriber_type <> 3)

	INSERT INTO RepSubscriberInfo000
	SELECT	NEWID() GUID,	
			publication,
			subscriber_db,
			subscriber_name,
			hostname,
			freq_type,
			freq_interval,
			freq_subday_type,
			freq_subday_interval,
			freq_relative_interval,
			freq_recurrence_factor,
			active_start_date,
			active_end_date,
			active_start_time,
			active_end_time
		FROM
			msdb.dbo.sysjobschedules AS js
			INNER JOIN msdb.dbo.sysschedules AS s ON js.schedule_id = s.schedule_id
			INNER JOIN #JobsId j ON j.Id=js.job_id

	EXEC PrcDropMergeSubscription @PublisherDb
##############################################################################################
CREATE PROCEDURE DeleteMetaDataSubscription
AS
	SET NOCOUNT ON
	DECLARE @publisherServer SYSNAME,
			@Publisherdb     SYSNAME,
			@SubPublication  SYSNAME

	 CREATE TABLE #Info_subscriptions (
							publisher            SYSNAME NOT NULL,
							publisher_db         SYSNAME NOT NULL,
							publication          SYSNAME NULL,
							replication_type     INT NOT NULL,
							subscription_type    INT NOT NULL,
							last_updated         DATETIME NULL,
							subscriber_db        SYSNAME NOT NULL,
							update_mode          SMALLINT NULL,
							last_sync_status     INT NULL,
							last_sync_summary    SYSNAME NULL,
							last_sync_time       DATETIME NULL
							)

	INSERT INTO #Info_subscriptions
	EXEC sp_MSenumsubscriptions

	while (EXISTS(SELECT  TOP 1 * FROM #Info_subscriptions))
	BEGIN
		SELECT Top 1 @publisherServer=publisher,@Publisherdb=publisher_db,@SubPublication=publication FROM #Info_subscriptions

		EXEC sp_mergesubscription_cleanup @publisher = @publisherServer
				,  @publisher_db = @Publisherdb
				,  @publication = @SubPublication

		DELETE FROM #Info_subscriptions where  @publisherServer=publisher AND @Publisherdb=publisher_db AND @SubPublication=publication
	END
##############################################################################################
CREATE PROCEDURE PrcReplicationTransferSettings
@old NVARCHAR(MAX)
AS
	SET NOCOUNT ON
	DECLARE @Str NVARCHAR(MAX)


	EXEC  FillRepFreezecolval

	SET @Str='INSERT INTO RepServer000
				SELECT * FROM '+@old+'..RepServer000'
	EXEC (@Str)

	SET @Str='INSERT INTO RepDistributor000
				SELECT * FROM '+@old+'..RepDistributor000'
	EXEC (@Str)

	SET @Str='INSERT INTO RepOp000
				SELECT * FROM '+@old+'..RepOp000'
	EXEC (@Str)

	SET @Str='INSERT INTO RepConflictsInfo000
				SELECT * FROM '+@old+'..RepConflictsInfo000'
	EXEC (@Str)
#############################################################################################
CREATE PROCEDURE prcMergeConflictRows
    @publication    SYSNAME = '%',
    @conflict_table SYSNAME,
    @publisher		SYSNAME = NULL,
    @publisher_db	SYSNAME = NULL,
	@artical_name	NVARCHAR(250),
	@Conf_Type INT
AS 
	SET NOCOUNT ON

    DECLARE @pubid          UNIQUEIDENTIFIER
    DECLARE @cmd            NVARCHAR(MAX)  
    DECLARE @retcode        INT
	DECLARE @result_table	SYSNAME
    DECLARE @pubidstr       NVARCHAR(38)
	DECLARE @guid			UNIQUEIDENTIFIER

    -- Security check
    IF 1 <> IS_MEMBER('db_owner') AND
	   (1 <> IS_MEMBER('replmonitor') OR IS_MEMBER('replmonitor') IS NULL)
	BEGIN    
		RAISERROR (15247, 11, -1)
		RETURN
	END

    SELECT @guid = NEWID()

    IF @publisher IS NULL
    	SELECT @publisher = PUBLISHINGSERVERNAME()
    	
    IF @publisher_db IS NULL
	    SELECT @publisher_db = DB_NAME()

	SELECT @cmd = 'select '
	SELECT @cmd = @cmd + ' ct.GUID, ''' + @conflict_table + ''', '''+ @artical_name + ''', '
    SELECT @cmd = @cmd + ' m.origin_datasource, m.conflict_type, m.reason_code, m.reason_text, m.pubid, m.MSrepl_create_time from' 
    SELECT @cmd = @cmd + QUOTENAME(@conflict_table) + ' ct, MSmerge_conflicts_info m where ct.origin_datasource_id=m.origin_datasource_id
    			and m.conflict_type <> 4 and ct.rowguidcol = m.rowguid AND m.conflict_type = ' + CAST(@Conf_Type AS NVARCHAR(4))

    IF @publication <> '%'

    BEGIN
        /*
        ** Parameter Check:  @publication.
        ** Make sure that the publication exists.
        */
        SELECT @pubid = pubid FROM dbo.sysmergepublications 
        	WHERE name = @publication AND 
        		LOWER(publisher) = LOWER(@publisher) AND
        		publisher_db = @publisher_db
        IF @pubid IS NULL
            BEGIN
                RAISERROR (20026, 16, -1, @publication)
                RETURN
            END

	    SET @pubidstr = '''' + CONVERT(NCHAR(36), @pubid) + '''' 
        SELECT @cmd = @cmd + ' and m.pubid = ' + @pubidstr
    END
    EXEC (@cmd)
#############################################################################################
CREATE FUNCTION fnReplicationConflictsCount(
        @DBName NVARCHAR(250), 
	    @PubName NVARCHAR(250)
) RETURNS [INT]
AS
BEGIN  
	RETURN (
		   SELECT COUNT(*) 
		   FROM dbo.MSmerge_conflicts_info c
		   JOIN sysmergearticles s
		   ON c.tablenick = s.nickname
		   WHERE s.pubid = (SELECT pubid
										   FROM   sysmergepublications
										   WHERE  name = @PubName
											 AND    publisher_db = @DBName)
		)
END
#############################################################################################
CREATE PROCEDURE GetConflictByType
	@PublicationName NVARCHAR(250),
	@Publisher NVARCHAR(250),
	@PublisherDB NVARCHAR(250),
	@ConfType INT
AS

SET NOCOUNT ON

CREATE TABLE #Conflict(
	id						INT IDENTITY (1,1),
	article					SYSNAME COLLATE database_default,
	source_owner			SYSNAME COLLATE database_default,
	source_object			SYSNAME COLLATE database_default,
	conflict_table			SYSNAME COLLATE database_default,
	guidcolname				SYSNAME COLLATE database_default,
	centralized_conflicts	INT
)

CREATE TABLE #ConflictDetails(
	GUID UNIQUEIDENTIFIER,
	tableName NVARCHAR(250),
	articalName NVARCHAR(250),
	origin_datasource NVARCHAR(250),
	conflict_type INT,
	reason_code INT,
	reason_text NVARCHAR(MAX),
	pubid UNIQUEIDENTIFIER, 
	MSrepl_create_time DATETIME
)

INSERT INTO #Conflict
	EXEC sp_helpmergearticleconflicts @publication = @PublicationName, @publisher = @Publisher, @publisher_db = @PublisherDB

WHILE EXISTS (SELECT * FROM #Conflict)
BEGIN
	DECLARE @rowId INT = (SELECT TOP 1 id FROM #Conflict ORDER BY id)

	DECLARE @conflictTable NVARCHAR(250), @SourceObject NVARCHAR(250), @ArticlName NVARCHAR(250)

	SELECT @conflictTable = conflict_table, @SourceObject = '[' + source_owner + '].[' + source_object + ']', @ArticlName = article FROM #Conflict WHERE id = @rowId

	IF @ConfType IN (4, 7, 8)
	BEGIN
	INSERT INTO #ConflictDetails
		exec sp_helpmergedeleteconflictrows @publication = @PublicationName, @source_object = @SourceObject, @publisher = @Publisher, @publisher_db = @PublisherDB
	END
	
	INSERT INTO #ConflictDetails
		EXEC prcMergeConflictRows @conflict_table = @conflictTable, @publication = @PublicationName, @publisher = @Publisher, @publisher_db = @PublisherDB, @artical_name = @ArticlName, @Conf_Type = @ConfType

	DELETE #Conflict WHERE id = @rowId
END

SELECT * FROM #ConflictDetails

DROP TABLE #ConflictDetails
DROP TABLE #Conflict
#############################################################################################
CREATE PROCEDURE GetReplicationConflictData
	 @ArtName NVARCHAR(250),
	 @ArtNameconflict NVARCHAR(250),
	 @ArtGuid NVARCHAR(250)
AS

DECLARE @V_ColumnCount INT, @V_ColumnWhile INT, @sqlCommand VARCHAR(MAX), @columnName VARCHAR(75)

CREATE TABLE #resultcompare (
	id INT,
	Column_Name VARCHAR(100),
	ConflictWinner NVARCHAR(MAX),
	ConflictLoser NVARCHAR(MAX)
)

SELECT @V_ColumnWhile = 1, @V_ColumnCount = COUNT(*)
	FROM   syscolumns
		WHERE  id = object_id(@ArtName)

WHILE @V_ColumnWhile <= @V_ColumnCount
BEGIN
       SELECT @columnName = C.name
		FROM syscolumns as C
		WHERE  C.id = object_id(@ArtName) AND c.colid = @V_ColumnWhile

       INSERT INTO #resultcompare (id, Column_Name) VALUES (@V_ColumnWhile, @columnName)

       SET @sqlCommand = 'UPDATE #resultcompare SET ConflictWinner ' +
                            ' = (SELECT ' + @columnName + ' FROM ' + @ArtName + 
                            ' WHERE GUID = ''' + @ArtGuid + ''' ), ConflictLoser = (SELECT ' + @columnName + ' FROM ' + @ArtNameconflict + 
                            ' WHERE GUID = ''' + @ArtGuid + ''' ) ' + 
                            ' WHERE id = ' + CAST(@V_ColumnWhile AS VARCHAR(10)) 
       
       EXEC (@sqlCommand)

       SET @V_ColumnWhile = @V_ColumnWhile + 1
END

SELECT * FROM #resultcompare

DROP TABLE #resultcompare
#############################################################################################
CREATE PROCEDURE prcCheckReplicationService
AS
SET NOCOUNT ON

DECLARE @installed int;

EXEC @installed = sys.sp_MS_replication_installed;

SELECT @installed as installed;
#############################################################################################
CREATE FUNCTION FUCTEAC (@HostName Varchar(100))
RETURNS TABLE
AS 
        RETURN    
                (
                WITH n(guid) 
                                AS 
                           (
                                        SELECT guid 
                                        FROM Repac000 
                                        WHERE HostName = @HostName
                                        UNION ALL
                                        SELECT nplus1.guid
                                        FROM ac000 as nplus1, n
                                        WHERE n.guid = nplus1.ParentGUID
                                )
                        SELECT distinct guid FROM n
                )
###########################################################################################
CREATE FUNCTION FUCTEGR (@HostName Varchar(100))
RETURNS TABLE
AS 
        RETURN    
                (
                WITH n(guid) 
                                AS 
                           (
                                        SELECT guid 
                                        FROM Repgr000 
                                        WHERE HostName = @HostName
                                        UNION ALL
                                        SELECT nplus1.guid
                                        FROM gr000 as nplus1, n
                                        WHERE n.guid = nplus1.ParentGUID
                                )
                        SELECT distinct guid FROM n
                )
#############################################################################################
CREATE PROC RunAllJobSub
		@PublisherDb NVARCHAR(MAX),
		@subscriberDb NVARCHAR(MAX)
AS
	DECLARE @publisher_db SYSNAME, @publication SYSNAME, @subscriber_db SYSNAME, @jobId UNIQUEIDENTIFIER , @JobName NVARCHAR(250)
		SET @publisher_db  = @PublisherDb
		SET @subscriber_db = @subscriberDb

	SELECT CONVERT(UNIQUEIDENTIFIER, job_id ) AS Id,subscriber_db
		INTO #JobsId
		FROM Ameendistribution.dbo.MSmerge_agents 
			WHERE  publisher_db  = @publisher_db
				AND	 (@subscriber_db = '' OR  subscriber_db = @subscriber_db)

	WHILE EXISTS (SELECT 1 FROM #JobsId)
	BEGIN
	SELECT TOP 1
		@jobId = Id,
		@subscriber_db = subscriber_db
			FROM #JobsId

	EXEC prc_SJ_ExecuteJob @jobId

	DELETE #JobsId
			WHERE Id = @jobId
	END
######################################################################################
#END