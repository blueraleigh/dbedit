proc dbedit-style-edit-start {} {
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name rowid
    wapp-trim {
        <link href="/static/css/forms.css" rel="stylesheet" type="text/css" />
        <link href="/static/css/vendor/select2/select2.min.css" rel="stylesheet" type="text/css" />
        <link href="/static/css/autocomplete.css" rel="stylesheet" type="text/css" />
        <script src="/static/js/vendor/jquery/jquery.min.js" type="text/javascript"></script>
        <script src="/static/js/vendor/select2/select2.full.min.js" type="text/javascript"></script>
        <script src="/static/js/jquery.init.js" type="text/javascript"></script>
        <script src="/static/js/autocomplete.js" type="text/javascript"></script>
        </head>
        <body class="change-form">
        <div class="breadcrumbs"><a href="/">Home </a><a href="%url(/table/$tbl_name)">&rsaquo; %html($tbl_name) </a>&rsaquo; %html($rowid)</div>
    }
}


proc dbedit-style-edit-end {} {
    wapp-subst {<div id="content" class="colM">}
}


# Serves the page to edit database records.
# This is the 'changeform' in Django parlance.
# The url takes the form: /edit/<table name>/<rowid>
proc wapp-page-edit {} {
    dbedit-header
    lassign [split [wapp-param PATH_TAIL] "/"] tbl_name rowid
    set id [wapp-param rowid]
    lassign [dbedit-form-fields $tbl_name edit] fields widgets fieldsets
    # If the $id variable has a value that means
    # the save button was pressed and we need
    # to handle the POST'ed data.
    if {$id != ""} {
        foreach field [split $fields ","] {
            # Wrap each value in single quotes, otherwise character values
            # will be mistakenly interpreted as column names. SQLite will
            # implicitly convert the values to the appropriate storage class
            # base on column type affinity (if it is possible, otherwise it
            # will store the value as TEXT).
            set fieldval [wapp-param $field]
            if {$fieldval != ""} {
                lappend vals "$field = '$fieldval'"
            } else {
                lappend vals "$field = NULL"
            }
        }
        set vals [join $vals ","]
        if {[catch {db eval "UPDATE $tbl_name SET $vals WHERE rowid=$id"} msg]} {
            set message "Update unsuccessful. $msg"
            wapp-set-cookie messages [list error $message]
            wapp-redirect "/table/$tbl_name"
            dbedit-footer
            return
        }
        wapp-set-cookie messages {ok "Update successful!"}
        wapp-redirect "/table/$tbl_name"
        dbedit-footer
        return
    }
    set cfs [lindex $fieldsets 0]
    wapp-trim {
        <div id="content-main">
        <form method="POST" id='%html($tbl_name)_form'>
        <div>
        <fieldset class="module aligned">
    }
    if {$cfs != ""} {
        wapp-subst {<h2>%html($cfs)</h2>}
    }
    db eval "SELECT rowid,$fields FROM $tbl_name WHERE rowid=$rowid" result {
        set pk [lindex $result(*) 0]
        set val $result($pk)
        wapp-trim {
            <div class="form-row hidden">
            <div class="field-box hidden">
            <input type="hidden" name="rowid" value='%unsafe($val)'>
            </div>
            </div>
        }
        foreach field [split $fields ","] type $widgets fieldset $fieldsets {
            if {$fieldset != $cfs} {
                set cfs $fieldset
                wapp-trim {
                    </fieldset>
                    <fieldset class="module aligned">
                }
                if {$cfs != ""} {
                    wapp-subst {<h2>%html($cfs)</h2>}
                }
            }
            set val $result($field)
            dbedit-form-widget $tbl_name $field $type $val
        }
    }
    wapp-trim {
        </fieldset>
        <div class="submit-row">
        <p class="deletelink-box"><a href="%url(/delete/$tbl_name/$rowid)" class="deletelink">Delete</a></p>
        <p class="copylink-box"><a href="%url(/copy/$tbl_name/$rowid)" class="copylink">Duplicate</a></p>
        <input type="submit" value="Save" class="default" name="_save" />
        </div>
        </div>
        </form>
        </div>
    }
    dbedit-footer
}
