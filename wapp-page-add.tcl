proc dbedit-style-add-start {} {
    set tbl_name [wapp-param PATH_TAIL]
    wapp-trim {
        <link href="/static/css/forms.css" rel="stylesheet" type="text/css" />
        <link href="/static/css/vendor/select2/select2.min.css" rel="stylesheet" type="text/css" />
        <link href="/static/css/autocomplete.css" rel="stylesheet" type="text/css" />
        <script src="/static/js/vendor/jquery/jquery.min.js" type="text/javascript"></script>
        <script src="/static/js/vendor/select2/select2.full.min.js" type="text/javascript"></script>
        <script src="/static/js/jquery.init.js" type="text/javascript"></script>
        <script src="/static/js/autocomplete.js" type="text/javascript"></script>
        </head>
        <body class="add-form">
        <div class="breadcrumbs"><a href="/">Home </a><a href="%url(/table/$tbl_name)">&rsaquo; %html($tbl_name) </a>&rsaquo; Add</div>
    }
}


proc dbedit-style-add-end {} {
    wapp-subst {<div id="content" class="colM">}
}


# Serves the page to add database records.
# The url takes the form: /add/<table name>
proc wapp-page-add {} {
    dbedit-header
    set tbl_name [wapp-param PATH_TAIL]
    set id [wapp-param rowid NA]
    lassign [dbedit-form-fields $tbl_name add] fields widgets fieldsets
    # If the $id variable does not equal NA,
    # the save button was pressed and we need
    # to handle the POST'ed data.
    if {$id != "NA"} {
        foreach field [split $fields ","] {
            # Wrap each value in single quotes, otherwise character values
            # will be mistakenly interpreted as column names. SQLite will
            # implicitly convert the values to the appropriate storage class
            # base on column type affinity (if it is possible, otherwise it
            # will store the value as TEXT).
            set fieldval [wapp-param $field]
            if {$fieldval != ""} {
                lappend vals "'$fieldval'"
            } else {
                lappend vals NULL
            }
        }
        set vals [join $vals ","]
        if {[catch {db eval "INSERT INTO $tbl_name ($fields) VALUES ($vals)"} msg]} {
            set message "Insert unsuccessful. $msg"
            wapp-set-cookie messages [list error $message]
            wapp-redirect "/table/$tbl_name"
            dbedit-footer
            return
        }
        wapp-set-cookie messages {ok "New record successfully inserted!"}
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
    wapp-trim {
        <div class="form-row hidden">
        <div class="field-box hidden">
        <input type="hidden" name="rowid" value=''>
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
        dbedit-form-widget $tbl_name $field $type ''
    }
    wapp-trim {
        </fieldset>
        <div class="submit-row">
        <input type="submit" value="Save" class="default" name="_save" />
        </div>
        </div>
        </form>
        </div>
    }
    dbedit-footer
}
