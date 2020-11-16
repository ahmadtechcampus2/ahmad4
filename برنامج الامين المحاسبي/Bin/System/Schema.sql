#########################################################
#include constants.sql
#include options.sql
#include flags.sql
#include fnObjectExists.sql
#include fnGetTableColumns.sql
#include fnGetTableColumns_inAString.sql
#include fnColumnsToBitMask.sql
#include prcColumnsToBigInts.sql
#include fnExtProp.sql

##include prcRaisError.sql


#include fnDatabase_size.sql
#include fnDatabase_inUse.sql
#include fnDatabase_serverName.sql
#include fnDatabase_qualifiedName.sql

#include fnFormatString.sql
#include prcExecuteSQL.sql
#include prcExecuteSqlScript.sql
#include prcDropFldConstraints.sql
#include prcDropFldIndex.sql
#include prcDropFld.sql
#include prcDropTrigger.sql
#include prcDropFunction.sql
#include prcDropProcedure.sql
#include prcDropView.sql
#include prcDropTable.sql
#include prcAddFld.sql
#include prcAddFloatFld.sql
#include prcAddBitFld.sql
#include prcAddDateFld.sql
#include prcAddCharFld.sql
#include prcAddGUIDFld.sql
#include prcAddROWGUIDCOLFld.sql
#include prcAddIntFld.sql
#include prcAddBigIntFld.sql
#include prcAddBlobFld.sql
#include prcAddLookupGUIDFld.sql
#include prcAlterFld.sql
#include prcRenameFld.sql
#include prcRenameTable.sql
##include prcLog_clear.sql -- moved to init.sql
#include prcLog.sql
#include prcEnableDisableTriggers.sql

#include prcTable_dataToInsertScript.sql

#include prcDatabase_copyTo.sql
#include prcDatabase_exportToDB.sql
#########################################################
##
## Unicode conversion functions - Bassam Najeeb
##
#########################################################
#include prcDeleteTableDefaultValueConstraints.sql
#include prcDeleteTableIndexes.sql
#include prcGetTableDefaultValueConstraints.sql
#include prcGetTableIndexes.sql
#include prcRestoreTableDefaultValueConstraints.sql
#include prcRestoreTableIndexes.sql
#include prcGetTablesToBeConvertedUnicode.sql
#include prcGetTableStringColumns.sql
#include prcConvertTableToUnicode.sql
#include prcConvertDBToUnicode.sql

#END