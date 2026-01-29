# VICE Patches for Framebuffer Capture

This document provides patches to add framebuffer capture support to VICE emulator.

## Method 1: Remote Monitor Protocol Extension

Add a custom `screendata` command to VICE remote monitor that returns frame data.

### File: `src/monitor/mon_command.c`

Add to command table (around line 700):

```c
static const mon_cmds_t mon_cmd_array[] = {
    // ... existing commands ...
    
    { "screendata", "sd",
      "Export current screen data as binary",
      "Export current screen data in BGRA8888 format\n"
      "Returns: SCREEN:<size>\\n followed by binary pixel data",
      NULL, mon_screendata, NULL, NULL },
    
    // ... rest of commands ...
};
```

### File: `src/monitor/mon_command.h`

Add function declaration (around line 100):

```c
void mon_screendata(void);
```

### File: `src/monitor/mon_export.c`

Add new function at end of file:

```c
#include "video.h"
#include "videoarch.h"

void mon_screendata(void)
{
    video_canvas_t *canvas;
    unsigned char *buffer;
    int width, height;
    int i, j;
    
    /* Get the active video canvas */
    canvas = video_canvas_get_active();
    if (!canvas || !canvas->videoconfig) {
        mon_out("ERROR: No active video canvas\n");
        return;
    }
    
    /* Get dimensions */
    width = canvas->draw_buffer->visible_width;
    height = canvas->draw_buffer->visible_height;
    
    /* Allocate buffer for BGRA8888 */
    int size = width * height * 4;
    buffer = (unsigned char *)malloc(size);
    if (!buffer) {
        mon_out("ERROR: Memory allocation failed\n");
        return;
    }
    
    /* Convert video buffer to BGRA8888 */
    for (j = 0; j < height; j++) {
        for (i = 0; i < width; i++) {
            int src_idx = j * canvas->draw_buffer->draw_buffer_width + i;
            int dst_idx = (j * width + i) * 4;
            
            /* Get pixel from draw buffer */
            uint8_t pixel = canvas->draw_buffer->draw_buffer[src_idx];
            
            /* Convert palette index to RGB */
            uint32_t color = canvas->videoconfig->color_tables.physical_colors[pixel];
            
            /* BGRA8888 format */
            buffer[dst_idx + 0] = (color >> 16) & 0xFF; // B
            buffer[dst_idx + 1] = (color >> 8) & 0xFF;  // G
            buffer[dst_idx + 2] = color & 0xFF;          // R
            buffer[dst_idx + 3] = 0xFF;                   // A
        }
    }
    
    /* Send header */
    mon_out("SCREEN:%d\n", size);
    
    /* Send binary data */
    fwrite(buffer, 1, size, mon_output);
    fflush(mon_output);
    
    free(buffer);
}
```

### Apply the patch

```bash
cd third_party/vice/vice
patch -p1 < ../../../build/vice/patches/remote-monitor-screendata.patch
```

## Method 2: Shared Memory Support

Add shared memory framebuffer export to VICE video rendering.

### File: `src/arch/shared/video_shm.h` (NEW FILE)

```c
#ifndef VICE_VIDEO_SHM_H
#define VICE_VIDEO_SHM_H

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

typedef struct video_shm_s {
    char name[256];
    void *buffer;
    int size;
#ifdef _WIN32
    HANDLE hMapFile;
#else
    int fd;
#endif
} video_shm_t;

/* Initialize shared memory for framebuffer */
int video_shm_init(video_shm_t *shm, int width, int height);

/* Update shared memory with current frame */
void video_shm_update(video_shm_t *shm, unsigned char *data, int size);

/* Cleanup shared memory */
void video_shm_destroy(video_shm_t *shm);

#endif
```

### File: `src/arch/shared/video_shm.c` (NEW FILE)

```c
#include "video_shm.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
int video_shm_init(video_shm_t *shm, int width, int height)
{
    DWORD pid = GetCurrentProcessId();
    sprintf(shm->name, "VICE_Framebuffer_%lu", pid);
    shm->size = width * height * 4;
    
    shm->hMapFile = CreateFileMapping(
        INVALID_HANDLE_VALUE,
        NULL,
        PAGE_READWRITE,
        0,
        shm->size,
        shm->name);
    
    if (shm->hMapFile == NULL) {
        return -1;
    }
    
    shm->buffer = MapViewOfFile(
        shm->hMapFile,
        FILE_MAP_ALL_ACCESS,
        0,
        0,
        shm->size);
    
    if (shm->buffer == NULL) {
        CloseHandle(shm->hMapFile);
        return -1;
    }
    
    return 0;
}

void video_shm_update(video_shm_t *shm, unsigned char *data, int size)
{
    if (shm->buffer && data) {
        memcpy(shm->buffer, data, (size < shm->size) ? size : shm->size);
    }
}

void video_shm_destroy(video_shm_t *shm)
{
    if (shm->buffer) {
        UnmapViewOfFile(shm->buffer);
        shm->buffer = NULL;
    }
    if (shm->hMapFile) {
        CloseHandle(shm->hMapFile);
        shm->hMapFile = NULL;
    }
}

#else /* POSIX */

int video_shm_init(video_shm_t *shm, int width, int height)
{
    sprintf(shm->name, "/VICE_Framebuffer_%d", getpid());
    shm->size = width * height * 4;
    
    /* Create shared memory object */
    shm->fd = shm_open(shm->name, O_CREAT | O_RDWR, 0666);
    if (shm->fd == -1) {
        return -1;
    }
    
    /* Set size */
    if (ftruncate(shm->fd, shm->size) == -1) {
        close(shm->fd);
        shm_unlink(shm->name);
        return -1;
    }
    
    /* Map it */
    shm->buffer = mmap(NULL, shm->size, PROT_READ | PROT_WRITE, MAP_SHARED, shm->fd, 0);
    if (shm->buffer == MAP_FAILED) {
        close(shm->fd);
        shm_unlink(shm->name);
        return -1;
    }
    
    return 0;
}

void video_shm_update(video_shm_t *shm, unsigned char *data, int size)
{
    if (shm->buffer && data) {
        memcpy(shm->buffer, data, (size < shm->size) ? size : shm->size);
    }
}

void video_shm_destroy(video_shm_t *shm)
{
    if (shm->buffer) {
        munmap(shm->buffer, shm->size);
        shm->buffer = NULL;
    }
    if (shm->fd >= 0) {
        close(shm->fd);
        shm_unlink(shm->name);
        shm->fd = -1;
    }
}

#endif
```

### File: `src/video/video-canvas.c`

Add at top:

```c
#include "video_shm.h"

static video_shm_t *global_video_shm = NULL;
static int shm_enabled = 0;
```

Add to initialization function (around line 200):

```c
void video_canvas_init(void)
{
    // ... existing code ...
    
    /* Initialize shared memory if requested */
    if (getenv("VICE_SHM_FRAMEBUFFER")) {
        global_video_shm = malloc(sizeof(video_shm_t));
        if (video_shm_init(global_video_shm, 384, 272) == 0) {
            shm_enabled = 1;
            printf("VICE: Shared memory framebuffer enabled\n");
        } else {
            free(global_video_shm);
            global_video_shm = NULL;
        }
    }
}
```

Add to refresh function (around line 500):

```c
void video_canvas_refresh(video_canvas_t *canvas,
                         unsigned int xs, unsigned int ys,
                         unsigned int xi, unsigned int yi,
                         unsigned int w, unsigned int h)
{
    // ... existing rendering code ...
    
    /* Update shared memory if enabled */
    if (shm_enabled && global_video_shm) {
        unsigned char *buffer = malloc(384 * 272 * 4);
        if (buffer) {
            /* Convert current frame to BGRA8888 */
            for (int j = 0; j < 272; j++) {
                for (int i = 0; i < 384; i++) {
                    int src_idx = j * canvas->draw_buffer->draw_buffer_width + i;
                    int dst_idx = (j * 384 + i) * 4;
                    
                    uint8_t pixel = canvas->draw_buffer->draw_buffer[src_idx];
                    uint32_t color = canvas->videoconfig->color_tables.physical_colors[pixel];
                    
                    buffer[dst_idx + 0] = (color >> 16) & 0xFF; // B
                    buffer[dst_idx + 1] = (color >> 8) & 0xFF;  // G
                    buffer[dst_idx + 2] = color & 0xFF;          // R
                    buffer[dst_idx + 3] = 0xFF;                   // A
                }
            }
            
            video_shm_update(global_video_shm, buffer, 384 * 272 * 4);
            free(buffer);
        }
    }
}
```

### Apply shared memory support

```bash
# Set environment variable before starting VICE
export VICE_SHM_FRAMEBUFFER=1  # Linux/macOS
set VICE_SHM_FRAMEBUFFER=1     # Windows

# Then run VICE
x64sc -remotemonitor
```

## Build with Patches

### Option 1: Manual patching

```bash
cd third_party/vice/vice

# Copy new files
cp ../../../build/vice/patches/video_shm.h src/arch/shared/
cp ../../../build/vice/patches/video_shm.c src/arch/shared/

# Apply patches
patch -p1 < ../../../build/vice/patches/mon-screendata.patch
patch -p1 < ../../../build/vice/patches/video-shm.patch

# Rebuild
make clean
./configure --enable-gtk3ui
make -j16
```

### Option 2: Automated via build script

Update `build/vice/build-mingw64.sh` to apply patches automatically:

```bash
# Apply patches before configure
if [ -d "../../../build/vice/patches" ]; then
    echo "Applying VICE patches..."
    for patch in ../../../build/vice/patches/*.patch; do
        if [ -f "$patch" ]; then
            echo "  Applying $(basename $patch)..."
            patch -p1 < "$patch" || echo "  Warning: patch may have already been applied"
        fi
    done
fi
```

## Testing the Implementations

### Test Remote Monitor Protocol

```bash
# Start VICE with remote monitor
x64sc -remotemonitor -remotemonitoraddress 127.0.0.1:6510

# In another terminal, connect with telnet
telnet 127.0.0.1 6510

# At monitor prompt, type:
screendata

# Should output:
# SCREEN:418816
# [binary data follows]
```

### Test Shared Memory

```bash
# Set environment variable
export VICE_SHM_FRAMEBUFFER=1

# Start VICE
x64sc -remotemonitor

# Check shared memory exists (Linux)
ls -l /dev/shm/VICE_Framebuffer_*

# Check shared memory exists (Windows)
# Use Process Explorer or similar tool to view shared memory segments
```

## Choosing a Method

**Remote Monitor Protocol:**
- ✅ Cross-platform
- ✅ Works over network
- ✅ No special permissions needed
- ⚠️ Higher latency (~10-20ms)
- ⚠️ Network overhead

**Shared Memory:**
- ✅ Lowest latency (~1-2ms)
- ✅ Best performance
- ✅ No network overhead
- ⚠️ Platform-specific
- ⚠️ Process must run on same machine

**Recommendation:** Start with **Remote Monitor Protocol** for initial development, then add **Shared Memory** support for production use.

## Next Steps

1. Choose and apply patches to VICE
2. Rebuild VICE with patches
3. Test capture methods independently
4. Integrate with C64OS IDE
5. Optimize frame rate and latency
