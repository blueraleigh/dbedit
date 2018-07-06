proc dbedit-style-table-start {} {
    set tbl_name [wapp-param PATH_TAIL]
    wapp-trim {
        <link href="/static/css/changelists.css" rel="stylesheet" type="text/css" />
        </head>
        <body class="change-list">
        <div class="breadcrumbs"><a href="/">Home </a>&rsaquo; %html($tbl_name)</div>
    }
}


proc dbedit-style-table-end {} {
    wapp-subst {<div id="content" class="flex">}
}


# Serves the page to list data for individual tables.
# This is the 'changelist' in Django parlance.
# The url format is: /table/<table name>?o=[<ordering>]&q=[<search term>]&page=[<page number>]
proc wapp-page-table {} {
    dbedit-header
    set tbl_name [wapp-param PATH_TAIL]
    set page [wapp-param page 1]
    set offset 0
    set q [wapp-param q]    ; # query term
    if {$page > 1} {
        set offset [expr {100 * ($page-1)}]
    }
    if {$tbl_name == ""} {
        wapp-redirect /
        dbedit-footer
        return
    }
    if {[db exists {SELECT 1 FROM dbedit_searchfields WHERE tbl_name LIKE $tbl_name}]} {
        set disabled ""
    } else {
        set disabled disabled
    }
    db eval "SELECT COUNT(rowid) AS rowcount FROM $tbl_name" {}
    if {$rowcount == 1} {
        set results result
    } else {
        set results results
    }
    wapp-trim {
        <h1>Select record to change</h1>
        <div id="content-main">
        <ul class="object-tools">
        <li>
        <a href="%url(/add/$tbl_name)" class="addlink">Add</a>
        </li>
        </ul>
        <div id="changelist" class="module">
        <div id="toolbar"><form id="changelist-search" method="GET">
        <div>
        <label for="searchbar"><img src="/static/img/search.svg" alt="Search" /></label>
        <input type="text" size="40" name="q" value="%unsafe($q)" id="searchbar" %html($disabled)/>
        <input type="submit" value="Search" %html($disabled)/>
        <span class="small quiet">%html($rowcount $results)</span>
        </div>
        </form></div>
        <div class="results">
        <table id="result_list">
        <thead>
        <tr>
    }
    set fields [dbedit-list-fields $tbl_name]
    foreach field [split $fields ","] {
        wapp-trim {
            <th scope="col">
            <div class="text">
            <span>%html($field)</span>
            </div>
            <div class="clear"></div>
            </th>
        }
    }
    wapp-subst {</tr></thead><tbody>}
    set where ""
    if {$q != ""} {
        db eval "SELECT field FROM dbedit_searchfields WHERE tbl_name LIKE '$tbl_name'" {
            set where [string cat $where "$field LIKE '%$q%' OR "]
        }
        set where [string trimright $where " OR "]
    }
    if {$where != ""} {
        set where [string cat "WHERE " $where]
    }
    db eval "
        SELECT rowid,$fields
        FROM $tbl_name
        $where ORDER BY rowid DESC LIMIT 100 OFFSET $offset" result {
        set pk [lindex $result(*) 0]
        set rowid $result($pk)
        set first 1
        foreach field [split $fields ","] {
            if {$first} {
                set val $result($field)
                wapp-subst {<td><a href="%url(/edit/$tbl_name/$rowid)">%unsafe($val)</a></td>}
                set first 0
            } else {
                set val $result($field)
                wapp-subst {<td>%unsafe($val)</td>}
            }
        }
        wapp-subst {</tr>}
    }
    wapp-subst {</tbody></table></div>}
    if {$rowcount > 100} {
        set prev [expr {max(1,$page-1)}]
        set next [expr {min(int(ceil($rowcount/100.)), $page+1)}]
        wapp-subst {<div class="paginator">}
        if {$q == ""} {
            wapp-subst {<a href="%url(/table/$tbl_name?page=)%qp($prev)">Prev</a> }
        } else {
            wapp-subst {<a href="%url(/table/$tbl_name?q=)%qp($q)&page=%qp($prev)">Prev</a> }
        }
        wapp-content-security-policy "default-src 'self'; style-src 'self' 'unsafe-inline'"
        wapp-trim {
            <form action="%url(/table/$tbl_name)" method="GET" style="display: inline-block;">
            <input type="hidden" name="q" value='%unsafe($q)'>
            <input type="text" size="5" name="page" value=%html($page)>
            </form>
        }
        if {$q == ""} {
            wapp-subst { <a href="%url(/table/$tbl_name?page=)%qp($next)">Next</a>}
        } else {
            wapp-subst { <a href="%url(/table/$tbl_name?q=)%qp($q)&page=%qp($next)">Next</a>}
        }
        wapp-subst {</div>}
    }
    wapp-subst {</div></div>}
    dbedit-footer
}
