################################################################################ 
#include fnBranch_getDefaultGuid.sql
#include fnBranch_getDefaultMask.sql
#include fnGetNewBranchNumber.sql

## -- the following function are included in connections.sql due to calling orders:
## -- fnBranch_getCurrentUserReadMask.sql
## -- fnBranch_getCurrentUserReadMask_scalar.sql
## -- fnBranch_getCurrentUserWriteMask.sql
## -- fnBranch_getCurrentUserWriteMask_scalar.sql

#include prcBranch_installBRTs.sql
#include prcBranch_applyToDescendants.sql
#include prcBranch_optimize.sql
#include prcBranch_fix.sql
#include prcBranch_tree.sql
#include prcBranch_enable.sql
#include prcBranch_dedicateDB.sql
#include prcBranch_createDatabase.sql
#include prcBranch_createDatabases.sql

#include prcItemSecurityExtended_AddISRT.sql
#include prcItemSecurityExtended_InstallISRTs.sql
#include prcItemSecurityExtended_InstallTable.sql
#include prcItemSecurityExtended_Optimize.sql
#include prcItemSecurityExtended_enable.sql
#include prcBranchesCTE.sql
################################################################################