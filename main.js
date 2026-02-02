const { app, BrowserWindow, powerSaveBlocker, ipcMain } = require('electron');
const path = require('path');

// 🛡️ FIX 1: FORCE WORKING DIRECTORY
if (app.isPackaged) {
    process.chdir(path.dirname(process.execPath));
}

// 🛡️ FIX 2: SINGLE INSTANCE LOCK
// This stops the "Double App" issue after updates
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
    app.quit();
} else {
    // If a second instance launches, focus the existing one
    app.on('second-instance', () => {
        const windows = BrowserWindow.getAllWindows();
        if (windows.length) {
            if (windows[0].isMinimized()) windows[0].restore();
            windows[0].focus();
        }
    });
}

let autoUpdater = null;

function createWindow() {
    const win = new BrowserWindow({
        fullscreen: true,
        autoHideMenuBar: true,
        backgroundColor: '#000000',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            autoplayPolicy: 'no-user-gesture-required',
            additionalArguments: [
                `--userDataPath=${app.getPath('userData')}`,
                `--appVersion=${app.getVersion()}` 
            ]
        }
    });

    win.loadFile(path.join(__dirname, 'player.html'));
}

ipcMain.on('trigger-update', () => {
    if (autoUpdater) {
        console.log("Renderer requested update check...");
        autoUpdater.checkForUpdatesAndNotify();
    }
});

// Only continue if we have the Single Instance Lock
if (gotTheLock) {
    app.whenReady().then(() => {
        powerSaveBlocker.start('prevent-display-sleep');
        createWindow();

        // 🛡️ FIX 3: LAZY LOAD UPDATER
        // Wait 10 seconds to ensure Kiosk environment is stable
        setTimeout(() => {
            try {
                autoUpdater = require('electron-updater').autoUpdater;
                autoUpdater.autoDownload = true;

                autoUpdater.on('update-downloaded', () => {
                    console.log('Update downloaded. Installing...');
                    // force=true, isSilent=true
                    autoUpdater.quitAndInstall(true, true); 
                });

                autoUpdater.on('error', (err) => {
                    console.log('Update Error: ' + err);
                });

                console.log("Updater initialized.");
            } catch (e) {
                console.log('Updater failed to load:', e);
            }
        }, 10000); 
    });

    app.on('window-all-closed', () => {
        if (process.platform !== 'darwin') app.quit();
    });
}