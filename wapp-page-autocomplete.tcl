# Autocomplete select2 widgets send AJAX requests
# to url's of the form:
#    /autocomplete/<table name>/<field name>?term=[<search term>]&page=[<page number>]
#
# select2 expects JSON response object like
#  {
#    "results": [{"id": "123", "text": "foo"}],
#    "pagination": {"more": true}
#  }
#
# Looks for an application table that determines the
# autocomplete fields to display on the form page created by
# wapp-page-edit and/or wapp-page-add.
#
# If the table does not exist, an application error will be
# raised.
proc wapp-page-autocomplete {} {
    sqlite3 db $::DBFILE
    db timeout 1000
    db eval BEGIN
    wapp-mimetype text/json
    wapp-unsafe "{\"results\": \["
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name field
    set q [wapp-param term]
    set page [wapp-param page 1]
    set forward [split [wapp-param forward] "|"]
    if {[llength $forward] == 2 && [lindex $forward 0] != ""} {
        foreach {i j} $forward {
            set source_filter $i
            set target_link $j
        }
    }
    set offset 0
    if {$page > 1} {
        set offset [expr {20 * ($page-1)}]
    }
    db eval "
        SELECT target_tbl,target_value,target_displ
        FROM dbedit_autocompletefields
        WHERE source_tbl LIKE '$tbl_name' AND source_field LIKE '$field'" {}
    if {$q == ""} {
        if {[info exists source_filter]} {
            set sql "
                SELECT
                    t.$target_value,t.$target_displ,c.rowcount
                FROM $target_tbl AS t, (
                    SELECT COUNT(*) rowcount FROM $target_tbl WHERE $target_link='$source_filter') AS c
                WHERE t.$target_link='$source_filter'
                LIMIT 20 OFFSET $offset"
        } else {
            set sql "
                SELECT
                    t.$target_value,t.$target_displ,c.rowcount
                FROM $target_tbl AS t, (
                    SELECT COUNT(*) rowcount FROM $target_tbl) AS c
                LIMIT 20 OFFSET $offset"
        }
        db eval $sql result {
            set v $result($target_value)
            set d $result($target_displ)
            wapp-unsafe "{"
            wapp-subst {"id": "%string($v)",}
            wapp-subst {"text": "%string($d)"}
            wapp-unsafe "},"
        }
        wapp-set-param .reply [string trimright [wapp-param .reply] ,]
    } else {
        if {[info exists source_filter]} {
            set sql "
                SELECT
                    t.$target_value,t.$target_displ,c.rowcount
                FROM $target_tbl AS t, (
                    SELECT COUNT(*) AS rowcount FROM $target_tbl WHERE $target_link='$source_filter' AND $target_displ LIKE '$q%') AS c
                WHERE t.$target_link='$source_filter' AND t.$target_displ LIKE '$q%'
                ORDER BY t.$target_displ='$q' DESC, t.$target_displ LIKE '$q%' DESC
                LIMIT 20 OFFSET $offset"
        } else {
            set sql "
                SELECT
                    t.$target_value,t.$target_displ,c.rowcount
                FROM $target_tbl AS t, (
                    SELECT COUNT(*) AS rowcount FROM $target_tbl WHERE $target_displ LIKE '$q%') AS c
                WHERE t.$target_displ LIKE '$q%'
                ORDER BY t.$target_displ='$q' DESC, t.$target_displ LIKE '$q%' DESC
                LIMIT 20 OFFSET $offset"
        }
        db eval $sql result {
            set v $result($target_value)
            set d $result($target_displ)
            wapp-unsafe "{"
            wapp-subst {"id": "%string($v)",}
            wapp-subst {"text": "%string($d)"}
            wapp-unsafe "},"
        }
        wapp-set-param .reply [string trimright [wapp-param .reply] ,]
    }
    wapp-unsafe "\], \"pagination\": {\"more\": "
    if {[array size result] == 1} {
        wapp-unsafe "false"
    } else {
        # rowcount is created by the db eval command
        if {$result(rowcount) > ($offset+20)} {
            wapp-unsafe "true"
        } else {
            wapp-unsafe "false"
        }
    }
    wapp-unsafe "}}"
    db eval COMMIT
    db close
}
