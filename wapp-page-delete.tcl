proc dbedit-style-delete-start {} {
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name rowid
    wapp-trim {
        </head>
        <body class="delete-confirmation">
        <div class="breadcrumbs"><a href="/">Home </a><a href="%url(/table/$tbl_name)">&rsaquo; %html($tbl_name) </a><a href="%url(/edit/$tbl_name/$rowid)">&rsaquo; %html($rowid) </a>&rsaquo; Delete</div>
    }
}


proc dbedit-style-delete-end {} {
    wapp-subst {<div id="content" class="colM">}
}


# Serves the confirmation page for deleting a record.
# The url takes the form /delete/<table name>/<rowid>
proc wapp-page-delete {} {
    dbedit-header
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name rowid
    set delete [wapp-param post 0]
    if {$delete} {
        if {[catch {db eval "DELETE FROM $tbl_name WHERE rowid=$rowid"} msg]} {
            set message "Delete unsuccessful. $msg"
            wapp-set-cookie messages [list error $message]
            wapp-redirect "/edit/$tbl_name/$rowid"
            dbedit-footer
            return
        }
        wapp-set-cookie messages {ok "Record successfully deleted."}
        wapp-redirect "/table/$tbl_name"
        dbedit-footer
        return
    }
    wapp-trim {
        <p>Are you sure you want to delete this record?</p>
        <form method="POST">
        <div>
        <input type="hidden" name="post" value="1" />
        <input type="submit" value="Yes, I'm sure" />
        <a href="%url(/edit/$tbl_name/$rowid)" class="button cancel-link">No, take me back</a>
        </div>
        </form>
    }
    dbedit-footer
}
