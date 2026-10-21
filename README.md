Smart Makefile bash script and code diff generator (makefile_gen.sh).
It fully autonomously includes discovery header, creates a compile_flags.txt, **and** on each build generates your local source diff (daily_ledger.md) so no GitGub needed e.g. if you're a solo programmer.

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
Required directory structure (project root (QJams) and code directory (source) are mandatory.
But you can of course update the script to your needs.

.
├── -additional files
│   ├── GitHub_downloads.sh
│   ├── QJ-480x480.png
│   └── QJams screenshots
│       ├── 10-playlist-presets.png
│       ├── 12-track recorder.png
│       ├── a.png
│       ├── audiobar_buttons.png
│       ├── audiobar.png
│       ├── b.png
│       ├── composite-tracks.png
│       ├── c.png
│       ├── edit-waveform.png
│       ├── FB.png
│       ├── file-controls.png
│       ├── help.png
│       ├── input source selector.png
│       ├── playlists.png
│       ├── QJams-audio-workspace-edit.png
│       ├── QJams-audio-workspace.png
│       ├── QJams  recordings folder.png
│       ├── ram_table.png
│       ├── red-dot.png
│       ├── settings.png
│       ├── telemetry.png
│       ├── timeline_xl.png
│       ├── track-edit.png
│       ├── video-mode.png
│       ├── vid-rec-2track-session.png
│       ├── waveform.png
│       └── waves.png
├── build_generic_appimage.sh
├── build_optimized_appimage.sh
├── cluster_usage_guide.sh
├── -documents
│   ├── AI_HANDOVER.txt
│   ├── CBT (Communicate, Build, Track).md
│   ├── cluster_guide.md
│   ├── doxygen_manifest_prompt.txt
│   ├── Gemini-coding-rules.txt
│   ├── Old files
│   │   ├── 1a. Implementation - Migration Plan.txt
│   │   ├── 1b. Post-Migration Forensic Verification Protocol.txt
│   │   ├── 2. refactor GTask Architecture.txt
│   │   ├── 3. refactor Session Management.txt
│   │   ├── 4. refactor Zero-Latency Pre-Rolling.txt
│   │   ├── 5. refactor Copy-on-Write Chunked Memory Architecture.txt
│   │   └── tot-chatgpt.md
│   ├── QJams AppImage Build Workflow.txt
│   ├── RC1_CHANGELOG.txt
│   └── source-explainer.txt
├── inject_doxygen.sh
├── lines.sh
├── linuxdeploy-plugin-gtk.sh
├── QJams_source_map_full.md
├── QJams_source_map.md
├── source
│   ├── audio_core.c
│   ├── audio_core.h
│   ├── audio_internal.h
│   ├── audio_memory.c
│   ├── audio_memory.h
│   ├── audio_nle.c
│   ├── audio_nle.h
│   ├── audio_routing.c
│   ├── audio_routing.h
│   ├── compile_flags.txt
│   ├── config.c
│   ├── config.h
│   ├── default_build.txt
│   ├── encoder.c
│   ├── encoder.h
│   ├── gui.c
│   ├── install_desktop.sh
│   ├── ledger.mk
│   ├── makefile
│   ├── makefile_gen.sh
│   ├── media_io.c
│   ├── media_io.h
│   ├── QJams_optimized
│   ├── replace.sh
│   ├── resources
│   │   ├── QJ-480x480.png
│   │   ├── qjams.gresource.xml
│   │   └── ui
│   │       ├── command_post.ui
│   │       ├── dashboard.ui
│   │       ├── main_window.ui
│   │       ├── multitrack.ui
│   │       ├── playlist.ui
│   │       └── waveforms.ui
│   ├── resources.c
│   ├── ringbuffer.h
│   ├── run.sh
│   ├── scanner.c
│   ├── scanner.h
│   ├── ui_command_post.c
│   ├── ui_command_post.h
│   ├── ui_dashboard.c
│   ├── ui_dashboard.h
│   ├── ui_globals.h
│   ├── ui_lifecycle.c
│   ├── ui_lifecycle.h
│   ├── ui_multitrack.c
│   ├── ui_multitrack.h
│   ├── ui_playlist.c
│   ├── ui_playlist.h
│   ├── ui_settings.c
│   ├── ui_settings.h
│   ├── ui_shortcuts.c
│   ├── ui_shortcuts.h
│   ├── ui_transport.c
│   ├── ui_transport.h
│   ├── ui_waveforms.c
│   ├── ui_waveforms.h
│   ├── video_engine.c
│   ├── video_engine.h
│   └── video_ringbuffer.h
├── -source_before_kimi
│   ├── audio_core.c
│   ├── audio_core.h
│   ├── audio_internal.h
│   ├── audio_memory.c
│   ├── audio_memory.h
│   ├── audio_nle.c
│   ├── audio_nle.h
│   ├── audio_routing.c
│   ├── audio_routing.h
│   ├── compile_flags.txt
│   ├── config.c
│   ├── config.h
│   ├── default_build.txt
│   ├── encoder.c
│   ├── encoder.h
│   ├── gui.c
│   ├── install_desktop.sh
│   ├── ledger.mk
│   ├── makefile
│   ├── makefile_gen.sh
│   ├── media_io.c
│   ├── media_io.h
│   ├── QJams_optimized
│   ├── replace.sh
│   ├── resources
│   │   ├── QJ-480x480.png
│   │   ├── qjams.gresource.xml
│   │   └── ui
│   │       ├── command_post.ui
│   │       ├── dashboard.ui
│   │       ├── main_window.ui
│   │       ├── multitrack.ui
│   │       ├── playlist.ui
│   │       └── waveforms.ui
│   ├── resources.c
│   ├── ringbuffer.h
│   ├── run.sh
│   ├── scanner.c
│   ├── scanner.h
│   ├── ui_command_post.c
│   ├── ui_command_post.h
│   ├── ui_dashboard.c
│   ├── ui_dashboard.h
│   ├── ui_globals.h
│   ├── ui_lifecycle.c
│   ├── ui_lifecycle.h
│   ├── ui_multitrack.c
│   ├── ui_multitrack.h
│   ├── ui_playlist.c
│   ├── ui_playlist.h
│   ├── ui_settings.c
│   ├── ui_settings.h
│   ├── ui_shortcuts.c
│   ├── ui_shortcuts.h
│   ├── ui_transport.c
│   ├── ui_transport.h
│   ├── ui_waveforms.c
│   ├── ui_waveforms.h
│   ├── video_engine.c
│   ├── video_engine.h
│   └── video_ringbuffer.h
├── -test plans
│   ├── Background lifecycles.txt
│   └── Functional tests.txt
└── tree.txt

12 directories, 173 files
