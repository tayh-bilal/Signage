const { app, BrowserWindow, powerSaveBlocker, ipcMain } = require('electron');
const path = require('path');

// 🛡️ FIX: FORCE WORKING DIRECTORY
// This fixes the "Cannot find module" error in Kiosk mode by forcing the app
// to look in its own folder instead of System32.
if (app.isPackaged) {
    process.chdir(path.dirname(process.execPath));
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

app.whenReady().then(() => {
    powerSaveBlocker.start('prevent-display-sleep');
    createWindow();

    // 🛡️ FIX: LAZY LOAD UPDATER
    // Wait 10 seconds before initializing the updater to avoid boot crashes.
    setTimeout(() => {
        try {
            autoUpdater = require('electron-updater').autoUpdater;
            autoUpdater.autoDownload = true;

            autoUpdater.on('update-downloaded', () => {
                console.log('Update downloaded. Rebooting...');
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