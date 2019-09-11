# This script implements a generic SQLite database editor
# using the Wapp web application framework (http://wapp.tcl.tk)
# and the static files from the Django admin project (
# https://docs.djangoproject.com/en/dev/ref/contrib/admin/).
#
# To use the program, create an alias like this:
#   alias dbedit='tclsh /path/to/dbedit.tcl'
#
# Then at a command prompt type,
#   dbedit -DDBFILE=</path/to/database>
# to start the program.
#
# As a convenience, this also works:
#   dbedit </path/to/database>
#
# Known limitations:
#   - Assumes correspondence between primary key and rowid, thus:
#      -- WITHOUT ROWID tables are not supported.
#      -- Multi-column primary keys are not supported.
#   - Assumes unix operating system
#   - Does not respect case-sensitive table/column names
#   - Column names with weird characters likely to fail
#
set DBEDIT_SCRIPT [file normalize $argv0]
set DBEDIT_ROOT [file dir $DBEDIT_SCRIPT]

package require sqlite3
source $DBEDIT_ROOT/dbedit-config.tcl
source $DBEDIT_ROOT/wapp-page-table.tcl
source $DBEDIT_ROOT/wapp-page-edit.tcl
source $DBEDIT_ROOT/wapp-page-add.tcl
source $DBEDIT_ROOT/wapp-page-delete.tcl
source $DBEDIT_ROOT/wapp-page-copy.tcl
source $DBEDIT_ROOT/wapp-page-query.tcl
source $DBEDIT_ROOT/wapp-page-backup.tcl
source $DBEDIT_ROOT/wapp-page-autocomplete.tcl
source $DBEDIT_ROOT/wapp.tcl

unset DBEDIT_SCRIPT
unset DBEDIT_ROOT

# Header to begin each page request
proc dbedit-header {} {
    wapp-trim {
        <html>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="content-type" content="text/html; charset=UTF-8">
        <head>
        <title>DBedit</title>
        <link href="/static/css/base.css" rel="stylesheet" type="text/css"/>
        <link href="/static/css/responsive.css" rel="stylesheet" type="text/css"/>
    }
    dbedit-style
    # open a database connection at the beginning of each request
    sqlite3 db $::DBFILE
    db timeout 1000
    db eval {PRAGMA foreign_keys = 1}
    db eval BEGIN
}


# Dispatch on the url head to set appropiate style sheets and
# html style attributes.
proc dbedit-style {} {
    set head [wapp-param PATH_HEAD]
    if {$head == ""} {
        dbedit-style-start
    } else {
        dbedit-style-$head-start
    }
    if {[wapp-param-exists messages]} {
        wapp-clear-cookie messages
        wapp-subst {<ul class="messagelist">}
        # The message list is a list with an even-number
        # of elements where each pair takes the form of {status message}.
        # Possible status levels are "ok", "warning", and "error"
        foreach {status message} [wapp-param messages] {
            if {$status == "ok"} {
                wapp-subst {<li>%html($message)</li>}
            } else {
                wapp-subst {<li class="%html($status)">%html($message)</li>}
            }
        }
        wapp-subst {</ul>}
    }
    if {$head == ""} {
        dbedit-style-end
    } else {
        dbedit-style-$head-end
    }
}


# Each page should have two functions called
# dbedit-style-XXXXX-start and dbedit-style-XXXXX-end
# that configure the page's style.
proc dbedit-style-start {} {
    wapp-trim {
        <link href="/static/css/dashboard.css" rel="stylesheet" type="text/css" />
        </head>
        <div id="header">
        <div id="branding">
        <h1 id="site-name">DBedit administration</h1>
        </div>
        <div id="user-tools">
        <a href="/backup">Backup</a>&nbsp;&nbsp;&nbsp;
        <a href="/query">Query</a>
        </div>
        </div>
        <body class="dashboard">
    }
}


proc dbedit-style-end {} {
    wapp-subst {<div id="content" class="colMS">}
}


# Footer to end each page request
proc dbedit-footer {} {
    # close the database connection at the end of each request
    if {[catch {db eval COMMIT} msg]} {}
    db close
    wapp-subst {<br class="clear"></div></body></html>}
}


# Looks for an application table that determines the
# table fields to display on the list page created by
# wapp-page-table.
#
# If the table does not exist, or no entries exist in the
# table all table fields are displayed.
proc dbedit-list-fields {tbl_name} {
    if {[db exists {
        SELECT 1 FROM sqlite_master WHERE tbl_name='dbedit_listfields'
    }]} {
        if {[db exists {
            SELECT 1 FROM dbedit_listfields WHERE tbl_name LIKE $tbl_name
        }]} {
            db eval {
                SELECT DISTINCT field
                FROM dbedit_listfields
                WHERE tbl_name LIKE $tbl_name AND idx > 0
                ORDER BY idx
            } {
                lappend fields $field
            }
        } else {
            db eval "PRAGMA table_info($tbl_name)" {
                lappend fields $name
            }
        }
    } else {
        db eval "PRAGMA table_info($tbl_name)" {
            lappend fields $name
        }
    }
    return [join $fields ","]
}


# Looks for an application table that determines the
# table fields to display on the form page created by
# wapp-page-edit and wapp-page-add.
#
# If the table does not exist, or no entries exist in the
# table all table fields are displayed (except integer primary
# keys).
proc dbedit-form-fields {tbl_name context} {
    if {[db exists {
        SELECT 1 FROM sqlite_master WHERE tbl_name='dbedit_formfields'
    }]} {
        if {[db exists {
            SELECT 1 FROM dbedit_formfields WHERE tbl_name LIKE $tbl_name
        }]} {
            db eval "
                SELECT field,${context}_widget,fieldset
                FROM dbedit_formfields
                WHERE tbl_name LIKE '$tbl_name' AND idx > 0
                ORDER BY idx" result {
                lappend fields $result(field)
                lappend widgets $result(${context}_widget)
                lappend fieldsets $result(fieldset)
            }
        } else {
            db eval "PRAGMA table_info($tbl_name)" {
                if {$type == "INTEGER" && $pk == 1} {
                    # Ignore integer primary keys
                } else {
                    lappend fields $name
                    lappend widgets $type
                    lappend fieldsets ""
                }
            }
        }
    } else {
        db eval "PRAGMA table_info($tbl_name)" {
            if {$type == "INTEGER" && $pk == 1} {
                # Ignore integer primary keys
            } else {
                lappend fields $name
                lappend widgets $type
                lappend fieldsets ""
            }
        }
    }
    return [list [join $fields ","] $widgets $fieldsets]
}


# Default mapping of form fields to html widgets
proc dbedit-form-widget {table field type val} {
    set field [string tolower $field]
    wapp-trim {
        <div class="form-row">
        <div class="field-box">
        <label for='%unsafe($field)_id'>%unsafe($field)</label>
    }
    switch -nocase -glob $type {
        varchar* -
        numeric -
        {} -
        text {
            wapp-trim {
                <input type="text" id='%unsafe($field)_id' name='%unsafe($field)' value='%unsafe($val)'>
            }
        }
        integer {
            wapp-trim {
                <input type="number" step="1" id='%unsafe($field)_id' name='%unsafe($field)' value='%unsafe($val)'>
            }
        }
        float -
        real {
            wapp-trim {
                <input type="number" step="0.0000001" id='%unsafe($field)_id' name='%unsafe($field)' value='%unsafe($val)'>
            }
        }
        boolean {
            if {$val == "" || $val == "''"} {
                set checked ""
            } else {
                set checked "checked"
            }
            wapp-trim {
                <input type="checkbox" id='%unsafe($field)_id' name='%unsafe($field)' value=1 %html($checked)>
            }
        }
        textarea {
            if {$val == "" || $val == "''"} {
                wapp-trim {
                    <textarea rows="10" cols="100" id='%unsafe($field)_id' name='%unsafe($field)'></textarea>
                }
            } else {
                wapp-trim {
                    <textarea rows="10" cols="100" id='%unsafe($field)_id' name='%unsafe($field)'>%unsafe($val)</textarea>
                }
            }
        }
        default {
            # custom types should implement their own procedure
            dbedit-form-$type-widget $table $field $val
        }
    }
    wapp-trim {
        </div>
        </div>
    }
}


proc dbedit-form-select2-widget {table field val} {
    set field [string tolower $field]
    set table [string tolower $table]
    wapp-trim {
        <select name='%unsafe($field)' id='%unsafe($field)_id' class="admin-autocomplete"
            data-ajax--cache="true" data-ajax--type="GET"
            data-ajax--url="%url(/autocomplete/$table/$field)"
            data-ajax--theme="admin-autocomplete"
            data-allow-clear="true"
            data-placeholder=""
    }
    db eval "SELECT forward FROM dbedit_autocompletefields
             WHERE source_tbl LIKE '$table' AND source_field LIKE '$field'" {}
    foreach {src trg} $forward {
        wapp-subst {
            data-forward--%html($trg)="%html($src)_id"
        }
    }
    wapp-subst {>}
    if {$val != ""} {
        db eval "
            SELECT target_tbl,target_value,target_displ
            FROM dbedit_autocompletefields
            WHERE source_tbl LIKE '$table' AND source_field LIKE '$field'" {}
        db eval "SELECT $target_displ FROM $target_tbl WHERE $target_value='$val'" result {}
        if {[array size result] > 1} {
            set label $result($target_displ)
        } else {
            set label ""
        }
        wapp-subst {<option value='%unsafe($val)'>%unsafe($label)</option>}
    }
    wapp-subst {</select>}
}


# Calculate the database file size and return a
# pretty representation.
proc dbedit-dbsize {} {
    set dbsize [file size [file normalize $::DBFILE]]
    set kb [expr {$dbsize / 1000.}]
    set mb [expr {$dbsize / (1000. * 1000.)}]
    set gb [expr {$dbsize / (1000. * 1000. * 1000.)}]
    if {$dbsize < 1000} {
        set dbsize [format "%.f" $dbsize]
        return [list $dbsize bytes]
    } elseif {$kb < 1000} {
        set kb [format "%.f" $kb]
        return [list $kb KB]
    } elseif {$mb < 1000} {
        set mb [format "%.1f" $mb]
        return [list $mb MB]
    } else {
        set gb [format "%.2f" $gb]
        return [list $gb GB]
    }
}


# Serves the page to list database tables.
# This is the appindex/applist in Django parlance.
# The url form is : /
proc wapp-default {} {
    dbedit-header
    if {[llength [info procs dbedit-config]]} {
        dbedit-config
        rename dbedit-config {}
    }
    set dbfile [lindex [split $::DBFILE "/"] end]
    lassign [dbedit-dbsize] dbsize unit
    wapp-trim {
        <h1>%unsafe($dbfile)&nbsp&nbsp&nbsp&nbsp%unsafe($dbsize) %unsafe($unit)</h1>
        <div id="content-main">
        <div id="dbedit-config-list" class="module">
        <table>
        <caption>
        <a href="#" class="section">Config</a>
        </caption>
    }
    db eval {
        SELECT LOWER(tbl_name) AS tbl_name
        FROM sqlite_master
        WHERE type='table' AND tbl_name LIKE 'dbedit%'
        ORDER BY tbl_name
    } {
        wapp-trim {
            <tr class="%html(model-$tbl_name)">
                <th scope="row">
                    <a href="%url(/table/$tbl_name)">%html($tbl_name)</a>
                </th>
                <td>
                    <a href="%url(/add/$tbl_name)" class="addlink">Add</a>
                </td>
                <td>
                    <a href="%url(/table/$tbl_name)" class="changelink">Change</a>
                </td>
            </tr>
        }
    }
    wapp-trim {
        </table>
        </div>
        <div id="admin-table-list" class="module">
        <table>
        <caption>
        <a href="#" class="section">Tables</a>
        </caption>
    }
    db eval {
        SELECT LOWER(tbl_name) AS tbl_name
        FROM sqlite_master
        WHERE type='table' AND (tbl_name NOT LIKE 'dbedit%' AND tbl_name NOT LIKE 'sqlite%')
        ORDER BY tbl_name
    } {
        wapp-trim {
            <tr class="%html(model-$tbl_name)">
                <th scope="row">
                    <a href="%url(/table/$tbl_name)">%html($tbl_name)</a>
                </th>
                <td>
                    <a href="%url(/add/$tbl_name)" class="addlink">Add</a>
                </td>
                <td>
                    <a href="%url(/table/$tbl_name)" class="changelink">Change</a>
                </td>
            </tr>
        }
    }
    wapp-trim {
        </table>
        </div>
    }
    if {[db exists {SELECT 1 FROM sqlite_master WHERE type='view'}]} {
        wapp-trim {
            <div id="admin-view-list" class="module">
            <table>
            <caption>
            <a href="#" class="section">Views</a>
            </caption>
        }
        db eval {
            SELECT LOWER(name) AS tbl_name
            FROM sqlite_master
            WHERE type='view' AND (tbl_name NOT LIKE 'dbedit%' AND tbl_name NOT LIKE 'sqlite%')
            ORDER BY tbl_name
        } {
            wapp-trim {
                <tr class="%html(model-$tbl_name)">
                    <th scope="row">
                        <a href="%url(/table/$tbl_name)">%html($tbl_name)</a>
                    </th>
                </tr>
            }
        }
        wapp-subst {</table></div>}
    }
    wapp-subst {</div>}
    dbedit-footer
}


proc wapp-page-env {} {
    wapp-allow-xorigin-params
    wapp-trim {
        <h1>Wapp Environment</h1>
        <pre>%html([wapp-debug-env])</pre>
    }
}


# Serves the static files from Django's admin.
# They are verbatim from Djando 2.0.2 except
# that the roboto web font uri's were
# converted to lowercase. All static url's have
# the form /static/<directory>/<filename>.
proc wapp-page-static {} {
    set top [wapp-param DOCUMENT_ROOT]
    set filename [lindex [split [wapp-param PATH_TAIL] "/"] end]
    wapp-cache-control max-age=3600
    set filepath [join [list $top static [wapp-param PATH_TAIL]] "/"]
    set mime [lindex [split $filename "."] end]
    switch $mime {
        txt {
            wapp-mimetype text/plain
            set fd [open $filepath r]
        }
        html {
            wapp-mimetype text/html
            set fd [open $filepath r]
        }
        htm {
            wapp-mimetype text/html
            set fd [open $filepath r]
        }
        css {
            wapp-mimetype text/css
            set fd [open $filepath r]
        }
        js {
            wapp-mimetype text/javascript
            set fd [open $filepath r]
        }
        jpg {
            wapp-mimetype image/jpeg
            set fd [open $filepath rb]
        }
        jpeg {
            wapp-mimetype image/jpeg
            set fd [open $filepath rb]
        }
        png {
            wapp-mimetype image/png
            set fd [open $filepath rb]
        }
        gif {
            wapp-mimetype image/gif
            set fd [open $filepath rb]
        }
        svg {
            wapp-mimetype image/svg+xml
            set fd [open $filepath rb]
        }
        woff {
            wapp-mimetype font/woff
            set fd [open $filepath rb]
        }
        default {
            return
        }
    }
    wapp-unsafe [read $fd]
    close $fd
}


proc wapp-page-favicon.ico {} {
    wapp-redirect /static/favicon/favicon.png
}


if {[string index [lindex $argv 0] 0] != "-"} {
    set argv [lreplace $argv 0 0 -DDBFILE=[lindex $argv 0]]
}

wapp-start $argv
