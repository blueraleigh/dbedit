proc dbedit-style-query-start {} {
    wapp-trim {
        <link href="/static/css/changelists.css" rel="stylesheet" type="text/css" />
        <script src="/formsubmit.js" type="text/javascript"></script>
        </head>
        <body class="change-list">
        <div class="breadcrumbs"><a href="/">Home </a>&rsaquo; Query</div>
    }
}


proc dbedit-style-query-end {} {
    wapp-subst {<div id="content" class="flex">}
}


# Serves the page for general SQL queries.
# The url format is: /query
proc wapp-page-query {} {
    dbedit-header
    set page [wapp-param page 1]
    set query [wapp-param query]
    wapp-clear-cookie query ;# in case we're redirected back here because of evaluation error
    set offset 0
    if {$page > 1} {
        set offset [expr {100 * ($page-1)}]
    }
    wapp-trim {
        <h1>Evaluate raw SQL</h1>
        <div id="content-main">
        <div id="changelist" class="module">
        <div id="toolbar"><form name="sqlform" id="sql-query" method="POST">
        <div>
        <textarea name="query" id="querybox" rows=3 cols=50>%unsafe($query)</textarea>
        <input type="hidden" name="page" value="%unsafe($page)"/>
        <input type="submit" value="Run"/>
        </div>
        </form></div>
        <div class="results">
        <table id="result_list">
        <thead>
        <tr>
    }
    set method [wapp-param REQUEST_METHOD]
    set rowcount 0
    if {$method == "POST"} {
        if {$query != "" && [string toupper [lindex $query 0]] != "SELECT"} {
            set message "Evaluation error. Only SELECT statements are allowed."
            wapp-set-cookie messages [list error $message]
            wapp-set-cookie query $query ;# set a cookie so we don't lose the query body in the redirect
            wapp-reply-code {303 Redirect}  ;# the default wapp-redirect uses 307 which doesn't alter the request method to GET
            wapp-reply-extra Location "/query"
            dbedit-footer
            return
        }
        set query_limit [string cat $query " LIMIT 100 OFFSET $offset"]
        set first 1
        if {$query != "" && [catch {db eval $query_limit result {
            if {$first} {
                foreach field $result(*) {
                    lappend fields $field
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
                set first 0
            }
            wapp-subst {<tr>}
            foreach field $fields {
                set val $result($field)
                wapp-subst {<td>%unsafe($val)</td>}
            }
            wapp-subst {</tr>}
            incr rowcount
        }} msg]} {
            set message "Evaluation error. $msg"
            wapp-set-cookie messages [list error $message]
            wapp-set-cookie query $query ;# set a cookie so we don't lose the query body in the redirect
            wapp-reply-code {303 Redirect}  ;# the default wapp-redirect uses 307 which doesn't alter the request method to GET
            wapp-reply-extra Location "/query"
            dbedit-footer
            return
        }
    } else {
        # do nothing
    }
    wapp-subst {</tbody></table></div>}
    if {$rowcount == 1} {
        set results result
    } else {
        set results results
    }
    wapp-subst {<span class="small quiet">%html($rowcount $results)</span>}
    if {$rowcount == 100} {
        set prev [expr {max(1,$page-1)}]
        set next [expr {min(int(ceil($rowcount/100.)), $page+1)}]
        wapp-content-security-policy "
            default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' "
        wapp-trim {
            <div class="paginator">
            <a href="javascript:void(0)" onclick="formsubmit('prev')">Prev</a>
            <form method="POST" style="display: inline-block;">
            <input type="hidden" name="query" value='%unsafe($query)'>
            <input type="text" size="5" name="page" value=%html($page)>
            </form>
            <a href="javascript:void(0)" onclick="formsubmit('next')">Next</a>
            </div>
        }
    }
    wapp-subst {</div></div>}
    dbedit-footer
}


proc wapp-page-formsubmit.js {} {
    wapp-mimetype text/javascript
    wapp-cache-control max-age=3600
    wapp-trim {
        var formsubmit = function(arg) {
            var form = document.forms.sqlform;
            var page = parseInt(form.elements.page.value);
            if (arg === 'next')
                form.elements.page.value = page + 1;
            else if (arg === 'prev')
                form.elements.page.value = Math.max(1, page - 1);
            document.getElementById("sql-query").submit();
        }
    }
}
