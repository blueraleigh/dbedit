# dbedit

This script implements a generic SQLite database editor using the [Wapp](http://wapp.tcl.tk) web application framework and the static files from the [Django](https://docs.djangoproject.com/en/dev/ref/contrib/admin/) admin project.

To use the program, create an alias like this:
   ```alias dbedit='tclsh /path/to/dbedit.tcl'```

Then at a command prompt type,
   ```dbedit -DDBFILE=</path/to/database>```
to start the program.

As a convenience, this also works:
   ```dbedit </path/to/database>```

Known limitations:
   - Assumes correspondence between primary key and rowid, thus:
      * WITHOUT ROWID tables are not supported.
      * Multi-column primary keys are not supported.
   - Assumes unix operating system
   - Does not respect case-sensitive table/column names
   - Column names with weird characters likely to fail
