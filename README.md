# Cloud PC on Pxxl

A Linux desktop (XFCE4) in your browser. It includes Chromium, a terminal, a file manager and a text editor, and it runs on Pxxl from this repo.

## Files in this repo

- `Dockerfile`: builds the desktop image. Pxxl detects it in the repo root.
- `entrypoint.sh`: starts the virtual display, desktop, VNC and noVNC on the `PORT` Pxxl gives it.
- `README.md`: this file.

## Deploy on Pxxl

1. Create a new GitHub repository and upload `Dockerfile`, `entrypoint.sh` and `README.md` to its root folder.
2. In Pxxl, open **Deploy**, choose **GitHub**, install the Pxxl GitHub App, and select this repository.
3. Pxxl detects the Dockerfile and fills in the build settings. Check them, then choose **Deploy Project**.
4. Before the first deploy, add an environment variable:
   - `VNC_PASSWORD`: your browser login. Use 8 characters or fewer, since VNC only checks the first 8.
   - `RESOLUTION` (optional): the screen size, e.g. `1280x800x24`.
5. When the build finishes, open your Pxxl URL and enter the VNC password. The desktop loads in the browser.

## Notes

- The first build downloads a lot and can take several minutes.
- The desktop and Chromium need a fair amount of memory. Pick the largest instance your Pxxl plan allows for this app.
- Some Pxxl deploy sources need a paid plan, so check your plan if the GitHub option is locked.
- Every push to the deploy branch redeploys the app.
- Files in the desktop's home folder are lost on redeploy unless you attach persistent storage.
