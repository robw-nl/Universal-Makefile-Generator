Smart makefile generator and code diff generator bash script (makefile_gen.sh).
It fully autonomously discovers headers and other includes, creates a compile_flags.txt, **and** on each build updates your local source diff (daily_ledger.md) so no GitGub needed e.g. if you're a solo programmer or work fully local (like I do).

daily_ledger.md and the .source folder to calculate all diffs are recreated each day on the first build. Everything resides _(non-destructive)_, in your project folder.

Invoke the generator at each build. I do that in Kate, makefile_gen.sh is linked to a Kate External Tool and associated shortcut but every configurable editor should be able to work with this.

Use this for your clang C builds.

**Code diff example:**
## Transaction: CBT-20261106-105536 | Time: 10:55:36
**Task:** REGULAR MERGE

### File: audio_memory.c
**--- OLD CODE ---**
```c
#include "video_engine.h"
#include <fcntl.h>
#include <gtk/gtk.h>
#include <pthread.h>
#include <rubberband/rubberband-c.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
```
**--- NEW CODE ---**
```c
#include "video_engine.h"
#include <fcntl.h>
#include <gtk/gtk.h>
#include <pthread.h>
#include <rubberband/rubberband-c.h>
#ifndef RubberBandOptionEngineFiner
#define RubberBandOptionEngineFiner 0
#endif
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
```

### File: media_io.c | In: `int load_qjams_session(const char *filep`
**--- OLD CODE ---**
```c
                }
                fclose(vf);
                video_restored = true;
            }
        }
    } while (archive_read_next_header(a, &entry) == ARCHIVE_OK);
    archive_read_close(a);
    archive_read_free(a);
    if (!header_loaded || strncmp(header.magic, QJAMS_MAGIC, 4) != 0 ||
        (header.version < 3 || header.version > 6)) {
        for (int i = 0; i < QJ_MAX_TRACKS; i++) {
            if (track_vios[i].data)
                free(track_vios[i].data);
            if (parity_vios[i].data)
                free(parity_vios[i].data);
```
**--- NEW CODE ---**
```c
                }
                fclose(vf);
                video_restored = true;
            }
        }
    } while (archive_read_next_header(a, &entry) == ARCHIVE_OK);
    archive_read_close(a);
    archive_read_free(a);
    if (!header_loaded || strncmp(header.magic, QJAMS_MAGIC, 4) != 0 ||
        (header.version < 3 || header.version > QJAMS_VERSION)) {
        for (int i = 0; i < QJ_MAX_TRACKS; i++) {
            if (track_vios[i].data)
                free(track_vios[i].data);
            if (parity_vios[i].data)
                free(parity_vios[i].data);
```

**Required directory structure (project root (QJams) and code directory (source) are mandatory.**
You can of course update the script to your needs.
/home/_USER_/Files/C/_PROJECT-ROOT_/source/
Use the _project name_ for _PROJECT-ROOT_



