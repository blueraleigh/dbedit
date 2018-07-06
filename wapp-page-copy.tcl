proc dbedit-style-copy-start {} {}


proc dbedit-style-copy-end {} {}


# Duplicate a record and redirect to the new edit page
proc wapp-page-copy {} {
    dbedit-header
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name rowid

    set fields [list]
    db eval "PRAGMA table_info($tbl_name)" {
        if {$pk == 0} {
            lappend fields $name
        }
    }
    set fields [join $fields ,]

    if {[catch {db eval "INSERT INTO $tbl_name ($fields) SELECT $fields FROM $tbl_name WHERE rowid=$rowid"} msg]} {
        set message "Duplication error. $msg"
        wapp-set-cookie messages [list error $message]
        wapp-redirect "/edit/$tbl_name/$rowid"
        dbedit-footer
        return
    }
    set newrowid [db eval {SELECT last_insert_rowid()}]
    wapp-set-cookie messages {ok "Success! You may edit the duplicated record below."}
    wapp-redirect "/edit/$tbl_name/$newrowid"
    dbedit-footer
}
