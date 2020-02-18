import sys
import re

def get_all_occurrences(substr, line):
    # substr is used for generating the pattern, escape those special chars in regexp
    if substr is None or line is None or len(substr) > len(line):
        return None
    return [m.start() for m in re.finditer('(?=%s)' % substr, line)]


def get_table_info(line):
    """
    It's complex to split when table name/schema name/user name/ tablespace name
    contains full context of one of others', which is very unlikely, but in
    case it happens, return None.

    Since we only care about table name, type, and schema name, strip the input
    is safe here.

    line: contains the true (un-escaped) schema name, table name, and user name.
    """

    COMMENT_EXPR = '-- Name: '
    TYPE_EXPR = '; Type: '
    SCHEMA_EXPR = '; Schema: '
    OWNER_EXPR = '; Owner: '
    TABLESPACE_EXPR = '; Tablespace: '

    temp = line.strip('\n')
    type_start = get_all_occurrences(TYPE_EXPR, temp)
    schema_start = get_all_occurrences(SCHEMA_EXPR, temp)
    owner_start = get_all_occurrences(OWNER_EXPR, temp)
    tblspace_start = get_all_occurrences(TABLESPACE_EXPR, temp)
    if len(type_start) != 1 or len(schema_start) != 1 or len(owner_start) != 1:
        return (None, None, None, None)
    name = temp[len(COMMENT_EXPR) : type_start[0]]
    type = temp[type_start[0] + len(TYPE_EXPR) : schema_start[0]]
    schema = temp[schema_start[0] + len(SCHEMA_EXPR) : owner_start[0]]
    if not tblspace_start:
        tblspace_start.append(None)
    owner = temp[owner_start[0] + len(OWNER_EXPR) : tblspace_start[0]]
    return (name, type, schema, owner)


if (sys.argv)<3 :
   print "ERROR: 2 parameters needed"
   exit(1)
ddl_filename=sys.argv[1]
backup_timestamp=sys.argv[2]
try :
   f = open(ddl_filename, "r")
except IOError:
   print "ERROR: cannot open file "+ddl_filename
   exit(1)

while True:
    # Get next line from file
    line = f.readline()
    # If line is empty then end of file reached
    if not line :
        break;
    if line.startswith("-- Name: "):
        table, table_type, schema, owner = get_table_info(line)
        if table_type == "TABLE":
            print backup_timestamp+'|'+schema+'.'+table
f.close()
