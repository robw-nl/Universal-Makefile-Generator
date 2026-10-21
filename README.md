Smart Makefile bash script and code diff generator (makefile_gen.sh).
It fully autonomously discovers headers and other includes, creates a compile_flags.txt, **and** on each build updates your local source diff (daily_ledger.md) so no GitGub needed e.g. if you're a solo programmer.

daily_ledger.md and the .source folder to calculate all diffs ate recreated each day on the first build. Everything resides _(non-destructive)_, in your project folder.

Invoke the generator at each build. I do that in Kate, makefile_gen.sh is linked to a Kate External Tool and associated shortcut but every configurable editor should be able to work with this.


Use this for your clang C builds.


**Code diff example:**

## Transaction: CBT-20261020-181645 | Time: 18:16:45
**Task:** REGULAR MERGE
### File: ui_transport.c | In: `static void start_recording_execution(vo`
**--- OLD CODE ---**
```c
                    break;
                }
            }
        }

        backup_track_to_ledger(rec_track);

        if (atomic_load_explicit(&video_is_armed, memory_order_acquire)) {
            if (media_has_video(ui_state.selected_track_path)) {
                video_start_frame = 0;
```
**--- NEW CODE ---**
```c
                    break;
                }
            }
        }

        // Ensure new/recorded tracks have unity gain (1.0f) so they are audible in mixdowns
        atomic_store_explicit(&master_tracks[rec_track].gain, 1.0f, memory_order_relaxed);

        backup_track_to_ledger(rec_track);

        if (atomic_load_explicit(&video_is_armed, memory_order_acquire)) {
            if (media_has_video(ui_state.selected_track_path)) {
                video_start_frame = 0;
```

## Transaction: CBT-20261020-221004 | Time: 22:10:04
**Task:** REGULAR MERGE

### File: ui_settings.c | In: `void on_settings_clicked(GtkButton *butt`
**--- OLD CODE ---**
```c
    gtk_widget_set_margin_end(vid_grid, 10);
    gtk_widget_set_margin_bottom(vid_grid, 15);

    GtkWidget *vh_size = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_size), "<b>Size</b>");
    GtkWidget *vh_def = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_def), "<b>Default</b>");
    GtkWidget *vh_exp = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_exp), "<b>Expanded</b>");
    gtk_widget_set_halign(vh_size, GTK_ALIGN_START);

    gtk_grid_attach(GTK_GRID(vid_grid), vh_size, 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(vid_grid), vh_def, 1, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(vid_grid), vh_exp, 2, 0, 1, 1);
```
**--- NEW CODE ---**
```c
    gtk_widget_set_margin_end(vid_grid, 10);
    gtk_widget_set_margin_bottom(vid_grid, 15);

    GtkWidget *vh_size = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_size), "<b>Size</b>");
    GtkWidget *vh_def = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_def), "<b>Default</b>");
    GtkWidget *vh_exp = gtk_label_new(NULL); gtk_label_set_markup(GTK_LABEL(vh_exp), "<b>Toggled</b>");
    gtk_widget_set_halign(vh_size, GTK_ALIGN_START);

    gtk_grid_attach(GTK_GRID(vid_grid), vh_size, 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(vid_grid), vh_def, 1, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(vid_grid), vh_exp, 2, 0, 1, 1);
```

**Required directory structure (project root (QJams) and code directory (source) are mandatory.**
You can of course update the script to your needs.
/home/_USER_/Files/C/_PROJECT-ROOT_/source/
Use the _project name_ for _PROJECT-ROOT_



