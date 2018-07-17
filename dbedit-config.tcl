# Application tables. These are required for some of
# the functions that follow to work properly.
proc dbedit-config {} {
    set init [expr {1 - [db exists {SELECT 1 FROM sqlite_master WHERE tbl_name='dbedit_listfields'}]}]
    db eval {
        CREATE TABLE IF NOT EXISTS dbedit_autocompletefields (
            source_tbl      TEXT,    -- the table from which the foreign key originates
            target_tbl      TEXT,    -- the table to which foreign key points
            source_field    TEXT,    -- the field in the source table from which the foreign key originates
            target_value    TEXT,    -- the field in the reference table to which the foreign key points
            target_displ    TEXT,    -- the field in the reference table to search against and to display in the form widget
            forward         TEXT     -- field from the source table to pass through filter field in the reference table. i.e. source_field filter_field
        );
        CREATE TRIGGER IF NOT EXISTS delete_autocompletefield_add_trig
        AFTER DELETE ON dbedit_autocompletefields
        WHEN EXISTS (SELECT 1 FROM dbedit_formfields WHERE field=OLD.source_field AND add_widget='select2')
        BEGIN
            UPDATE dbedit_formfields
            SET add_widget='text'
            WHERE field=OLD.source_field;
        END;
        CREATE TRIGGER IF NOT EXISTS delete_autocompletefield_edit_trig
        AFTER DELETE ON dbedit_autocompletefields
        WHEN EXISTS (SELECT 1 FROM dbedit_formfields WHERE field=OLD.source_field AND edit_widget='select2')
        BEGIN
            UPDATE dbedit_formfields
            SET edit_widget='text'
            WHERE field=OLD.source_field;
        END;
    }
    db eval {
        CREATE TABLE IF NOT EXISTS dbedit_listfields (
            tbl_name TEXT,     -- the table name
            field    TEXT,     -- the field name
            idx      TEXT      -- the column display index. a negative number means hide.
        )
    }
    db eval {
        CREATE TABLE IF NOT EXISTS dbedit_formfields (
            tbl_name    TEXT,    -- the table name
            field       TEXT,    -- the field name
            add_widget  TEXT,    -- the type of widget to use in the form field when adding a new record
            edit_widget TEXT,    -- the type of widget to use in the form field when editing an existing record
            fieldset    TEXT,    -- the fieldset is a group name to identify related fields.
            idx         TEXT     -- the form display index. a negative number means hide.
        );
        CREATE TRIGGER IF NOT EXISTS update_formfield_add_trig
        BEFORE UPDATE OF add_widget ON dbedit_formfields
        WHEN NEW.add_widget='select2' AND NOT EXISTS (
            SELECT 1 FROM dbedit_autocompletefields WHERE source_field=NEW.field)
        BEGIN
            SELECT RAISE(ABORT, "The select2 widget requires an entry for the field in dbedit_autocompletefields.");
        END;
        CREATE TRIGGER IF NOT EXISTS update_formfield_edit_trig
        BEFORE UPDATE OF edit_widget ON dbedit_formfields
        WHEN NEW.edit_widget='select2' AND NOT EXISTS (
            SELECT 1 FROM dbedit_autocompletefields WHERE source_field=NEW.field)
        BEGIN
            SELECT RAISE(ABORT, "The select2 widget requires an entry for the field in dbedit_autocompletefields.");
        END;
        CREATE TRIGGER IF NOT EXISTS insert_formfield_trig
        BEFORE INSERT ON dbedit_formfields
        WHEN (NEW.add_widget='select2' OR NEW.edit_widget='select2') AND NOT EXISTS (
            SELECT 1 FROM dbedit_autocompletefields WHERE source_field=NEW.field)
        BEGIN
            SELECT RAISE(ABORT, "The select2 widget requires an entry for the field in dbedit_autocompletefields.");
        END
    }
    db eval {
        CREATE TABLE IF NOT EXISTS dbedit_searchfields (
            tbl_name TEXT,    -- the table name
            field    TEXT     -- the field name
        )
    }
    db eval {
        CREATE TABLE IF NOT EXISTS dbedit_loadhooks (
            fp TEXT            -- file path of tcl script to source with api procs
        )
    }
    db eval {SELECT fp FROM dbedit_loadhooks} {
        source $fp
    }
    if {$init} {
        set tables [db eval {
            SELECT tbl_name
            FROM sqlite_master
            WHERE (type='table' OR type='view') AND (tbl_name NOT LIKE 'dbedit%' AND tbl_name NOT LIKE 'sqlite%')
            ORDER BY LOWER(tbl_name)
        }]
        foreach table $tables {
            set i 1
            catch {db eval "PRAGMA table_info($table)" {
                if {$type == "INTEGER" && $pk == 1} {
                    # Ignore integer primary keys in forms
                    db eval "INSERT INTO dbedit_listfields VALUES ('$table', '$name', '$i')"
                } else {
                    db eval "INSERT INTO dbedit_listfields VALUES ('$table', '$name', '$i')"
                    db eval "INSERT INTO dbedit_formfields VALUES ('$table', '$name', 'text', 'text', '', '$i')"
                }
                incr i
            }}
        }
    }
}
