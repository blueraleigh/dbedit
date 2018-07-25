proc dbedit-style-backup-start {} {}


proc dbedit-style-backup-end {} {}


# Duplicate a record and redirect to the new edit page
proc wapp-page-backup {} {
    dbedit-header

    if {[info exists ::BACKUPTO]} {
        if {[catch {db backup $::BACKUPTO} msg]} {
            set message "Backup unsuccessful. $msg"
            wapp-set-cookie messages [list error $message]
            wapp-redirect "/"
            dbedit-footer
            return
        }
    } else {
        set message "No backup location available."
        wapp-set-cookie messages [list warning $message]
        wapp-redirect "/"
        dbedit-footer
        return
    }
    set message "Backup successful!"
    wapp-set-cookie messages [list ok $message]
    wapp-redirect "/"
    dbedit-footer
    return
}
