#########################################################
##
## flags are set and reset and checked for existance in mc000.
## flags are records in mc000 using TYPE 24, with varing NUMBER corresponding to approved meanings.
## flag IDs are explained in prcFlag_set
##

#include prcFlag_reset.sql
#include prcFlag_set.sql
#include fnFlag_IsSet.sql
#include vwDbFlags.sql

########################################################
#END
